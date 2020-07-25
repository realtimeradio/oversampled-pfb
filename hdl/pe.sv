`timescale 1ns/1ps
`default_nettype none

module OSPFB #(
  parameter WIDTH=16,
  parameter COEFF_WID=16,
  parameter FFT_LEN=32,
  parameter DEC_FAC=24,
  parameter SRT_PHA=23,  // (DEC_FAC-1) modtimer decimation phase start (which port delivered first)
  parameter PTAPS=8,
  parameter SRLEN=8,
  parameter CONF_WID=8
) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,  // TODO: evaluate the need and use of this signal the signal

  // TODO: wanting to implement m_axis tready as a debug to make sure we are always accepting a
  // sample each cycle as noted in the AMBA AXIS recommendation for tready implementation
  axis.SLV s_axis,                      // upstream input data

  axis.MST m_axis_fir,                  // TODO: temporary m_axis for fir data to test adding fft.
  axis.MST m_axis_fft_status,           // FFT status for overflow
  axis.MST m_axis_data,                 // OSPFB result data
  output logic m_axis_data_tlast,
  output logic [7:0] m_axis_data_tuser,

  output logic event_frame_started,
  output logic event_tlast_unexpected,
  output logic event_tlast_missing,
  output logic event_fft_overflow,
  output logic event_data_in_channel_halt
);

// fft is reset low
logic aresetn;
assign aresetn = ~rst;

// for controlling samples
logic [$clog2(FFT_LEN)-1:0] modtimer;           // decimator phase
logic [$clog2(FFT_LEN)-1:0] rst_val = SRT_PHA;  // starting decimator phase (which port gets first sample)

logic vin;
logic signed [WIDTH-1:0] din_re;
logic signed [WIDTH-1:0] din_im;

logic signed [WIDTH-1:0] pc_in_re;
logic signed [WIDTH-1:0] pc_in_im;

logic vout_re;
logic vout_im;
logic signed [WIDTH-1:0] dout_re;
logic signed [WIDTH-1:0] dout_im;
logic signed [WIDTH-1:0] sout_re;
logic signed [WIDTH-1:0] sout_im;

/*
s_axis_fft_data todo's
  TODO (tready): In the xfft playground I ignored the s_axis_fft_data.tready siganl at the adc
  model.  The reason being that since the FFT starts its first frame on the single buffered sample
  after tready comes back those dropped samples are just dropped samples. And since the ADC cannot
  accept back pressure and we are indifferent to the exact starting antenna voltage it would have
  been safe to ignore tready.

  However, the ospfb as a whole is not indifferent. The FFT needs to remain in lock step with
  the phase compensation buffer (oversampled case) and the polyphase branch outputs (critically
  sampled case).

  My current approach to over come this will be to reset the circuit as planned to propagate
  zeros through the polyphase FIR, then release the reset but hold the other

  TODO (tlast): with this hardwired to 0 there will `even_tlast_unexpected` triggered. However,
  since we need everything to be in lockstep the tlast should be easily computed then we can
  continue to have good ways to know if we get out of sync somehow
*/

axis #(.WIDTH(2*WIDTH)) s_axis_fft_data();
logic s_axis_fft_data_tlast;

assign s_axis_fft_data.tdata = {sout_im, sout_re};
assign s_axis_fft_data_tlast = 1'b0;

// hold reset to fir components until fft is ready so we remain in step with the correct phase
logic hold_rst;
//assign hold_rst = rst | ~s_axis_fft_data.tready;

// TODO: can leaving unconnected remove the ports in synthesis because I don't think we will
// every use any of the configuration options
axis #(.WIDTH(CONF_WID)) s_axis_config();
assign s_axis_config.tdata = 1'b0;
assign s_axis_config.tvalid = 1'b0;

always_ff @(posedge clk)
  if (hold_rst)
    modtimer <= rst_val;
  else if (en)
    modtimer <= modtimer + 1;
  else
    modtimer <= modtimer;

/*
  TODO: With SRL32s there is no real state machine for pop/push into the delay lines because
  they are implemented now as a true SR fifo and not a bram fifo with circular address
  pointers. The only state machine for now is therefore this top one that is used for debugging
  and implementing AXIS. Hoping it is not too much overhead. The debugging on AXIS came from
  ARM AXIS recommendation to implement tready even if the IP always needs to be ready as a way
  to debug and that if it isn't the signal is monitored more as an error.
*/

datapath #(
  .WIDTH(WIDTH),
  .COEFF_WID(COEFF_WID),
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .PTAPS(PTAPS),
  .SRLEN(SRLEN)
) fir_re (
  .clk(clk),
  .rst(hold_rst),
  .en(en), //TODO: how much longer do I carry this around...
  .vin(vin),
  .din(din_re),
  .vout(vout_re),
  .dout(dout_re),
  .sout(pc_in_re)
);

PhaseComp #(
  .WIDTH(WIDTH),
  .DEPTH(2*FFT_LEN),
  .DEC_FAC(DEC_FAC)
) phasecomp_re_inst (
  .clk(clk),
  .rst(hold_rst),
  .din(pc_in_re),
  .dout(sout_re)
);

datapath #(
  .WIDTH(WIDTH),
  .COEFF_WID(COEFF_WID),
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .PTAPS(PTAPS),
  .SRLEN(SRLEN)
) fir_im (
  .clk(clk),
  .rst(hold_rst),
  .en(en), //TODO: how much longer do I carry this around...
  .vin(vin),
  .din(din_im),
  .vout(vout_im),
  .dout(dout_im),
  .sout(pc_in_im)
);

PhaseComp #(
  .WIDTH(WIDTH),
  .DEPTH(2*FFT_LEN),
  .DEC_FAC(DEC_FAC)
) phasecomp_im_inst (
  .clk(clk),
  .rst(hold_rst),
  .din(pc_in_im),
  .dout(sout_im)
);

xfft_0 fft_inst (
  .aclk(clk),                                             // input wire aclk
  .aresetn(aresetn),                                      // input wire aresetn

  .s_axis_config_tdata(s_axis_config.tdata),              // input wire [15 : 0] s_axis_config_tdata
  .s_axis_config_tvalid(s_axis_config.tvalid),            // input wire s_axis_config_tvalid
  .s_axis_config_tready(s_axis_config.tready),            // output wire s_axis_config_tready

  .s_axis_data_tdata(s_axis_fft_data.tdata),              // input wire [31 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(s_axis_fft_data.tvalid),            // input wire s_axis_data_tvalid
  .s_axis_data_tready(s_axis_fft_data.tready),            // output wire s_axis_data_tready
  .s_axis_data_tlast(s_axis_fft_data_tlast),              // input wire s_axis_data_tlast

  .m_axis_data_tdata(m_axis_data.tdata),                  // output wire [31 : 0] m_axis_data_tdata
  .m_axis_data_tvalid(m_axis_data.tvalid),                // output wire m_axis_data_tvalid
  .m_axis_data_tlast(m_axis_data_tlast),                  // output wire m_axis_data_tlast
  .m_axis_data_tuser(m_axis_data_tuser),                  // output wire [7 : 0] m_axis_data_tuser

  .m_axis_status_tdata(m_axis_fft_status.tdata),          // output wire [7 : 0] m_axis_status_tdata
  .m_axis_status_tvalid(m_axis_fft_status.tvalid),        // output wire m_axis_status_tvalid

  .event_frame_started(event_frame_started),              // output wire event_frame_started
  .event_tlast_unexpected(event_tlast_unexpected),        // output wire event_tlast_unexpected
  .event_tlast_missing(event_tlast_missing),              // output wire event_tlast_missing
  .event_fft_overflow(event_fft_overflow),                // output wire event_fft_overflow
  .event_data_in_channel_halt(event_data_in_channel_halt) // output wire event_data_in_channel_halt
);

typedef enum logic [1:0] {INIT, WAITFFT, FORWARD, FEEDBACK, ERR='X} stateType;
stateType cs, ns;

// FSM state register
always_ff @(posedge clk)
  cs <= ns;

always_comb begin
  // default values to prevent latch inferences
  ns = ERR;
  din_re = 32'haabbccdd; //should never see this value, if so it is an error
  din_im = 32'hddccaabb; //should never see this value, if so it is an error
  hold_rst = 1'b1;

  // ospfb.py top-level equivalent producing the vin to start the process
  // why modtimer < dec_fac and not dec_fac-1 like in src counter pass through?
  s_axis.tready = 1'b0;

  m_axis_fir.tvalid = (vout_re & vout_im);
  m_axis_fir.tdata  = {sout_im, sout_re};

  s_axis_fft_data.tvalid = 1'b0;
  /*
  TODO: where to use m_axis_data.tready for debug monitoring of slave. If m_axis_data.tready
    isn't used for anything meaningful vivado synthesis throws a warning but may not be an issue.
    Will get unexpected synthesis behavior if I don't remove this when testing it
  */
  vin = (s_axis.tready & s_axis.tvalid) ? 1'b1: 1'b0;

  /*
  TODO: supporting arbitrary dec fac
    This is a simple fsm made for the early development but now that I have start thinking about
    processing parallel samples this fsm would be the perfect (and really only place) where such a
    complicated operation would take place to handle general arbitrary os ratios
  */
  if (rst) begin
    ns = INIT;
  end else begin
    case (cs)
      INIT: begin
        ns = WAITFFT;
        s_axis_fft_data.tvalid = 1'b1; // indicate to the FFT we'd like to start
        hold_rst = 1'b1;
      end

      WAITFFT: begin
        if (s_axis_fft_data.tready) begin
          hold_rst = 1'b0;
          s_axis_fft_data.tvalid = 1'b1;
          s_axis.tready = (modtimer < DEC_FAC) ? 1'b1 : 1'b0;
          ns = FORWARD;
        end else begin
          // I think I want to add a hold_rst=1'b1; here to be explicit for now until I am happy
          // with the state machines
          s_axis.tready = 1'b0;
          s_axis_fft_data.tvalid = 1'b0;
          ns = WAITFFT;
        end
      end

      FORWARD: begin
        hold_rst = 1'b0;
        s_axis_fft_data.tvalid = 1'b1;
        s_axis.tready = (modtimer < DEC_FAC) ? 1'b1 : 1'b0;
        vin = (s_axis.tready & s_axis.tvalid) ? 1'b1: 1'b0;
        din_re = s_axis.tdata[WIDTH-1:0];
        din_im = s_axis.tdata[2*WIDTH-1:WIDTH];
        if (modtimer == DEC_FAC-1)
          ns = FEEDBACK;
        else
          ns = FORWARD;
      end

      FEEDBACK: begin
        hold_rst = 1'b0;
        s_axis_fft_data.tvalid = 1'b1;
        s_axis.tready = (modtimer < DEC_FAC) ? 1'b1 : 1'b0;
        vin = (s_axis.tready & s_axis.tvalid) ? 1'b1: 1'b0;
        din_re = 32'hdeadbeef; // bogus data for testing
        din_im = 32'hbeefdead;
        if (modtimer == FFT_LEN-1)
          ns = FORWARD;
        else
          ns = FEEDBACK;
      end
    endcase // case
  end
end

endmodule



// TODO: do we need a data type parameter so SRLShiftReg can be signed and unsigned?
module datapath #( // less phasecomp...
  parameter WIDTH=16,
  parameter COEFF_WID=16,
  parameter FFT_LEN=32,
  parameter DEC_FAC=24, // TODO: does this need to be a logic type if used for comparison?
  parameter PTAPS=8,
  parameter SRLEN=8
) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,

  input wire logic                    vin,
  input wire logic signed [WIDTH-1:0] din,

  // TODO: should dout/vout be here, they are internal pe signals and don't go into phasecomp
  output logic vout,
  output logic signed [WIDTH-1:0] dout,
  output logic signed [WIDTH-1:0] sout
);

logic signed [0:PTAPS-1][WIDTH-1:0] pe_sout;
logic signed [0:PTAPS-1][WIDTH-1:0] pe_dout;
logic [0:PTAPS-1] pe_vout; // valid are single bit, no width param

PE #(
  .WIDTH(WIDTH),
  .COEFF_WID(COEFF_WID),
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .COF_SRT(0),
  .SRLEN(SRLEN)
) pe[0:PTAPS-1] (
  .clk(clk),
  .rst(rst),
  .en(en),
  .vin({vin, pe_vout[0:PTAPS-2]}),
  .din({din, pe_dout[0:PTAPS-2]}),
  .sin({{WIDTH{1'b0}},  pe_sout[0:PTAPS-2]}),
  .vout(pe_vout),
  .dout(pe_dout),
  .sout(pe_sout)
);

assign vout = pe_vout[PTAPS-1];
assign dout = pe_dout[PTAPS-1];
assign sout = pe_sout[PTAPS-1];

endmodule


module PE #(
  parameter WIDTH=16,
  parameter COEFF_WID=16,
  parameter FFT_LEN=64,
  parameter DEC_FAC=48,
  parameter COF_SRT=0,
  parameter SRLEN=8
) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en, // TODO: should this be vin (a valid signal), or remove?
  input wire logic vin,
  input wire logic signed [WIDTH-1:0] din,
  input wire logic signed [WIDTH-1:0] sin,
  output logic vout,
  output logic signed [WIDTH-1:0] dout,
  output logic signed [WIDTH-1:0] sout
);

// TODO: does this need to be a logic val?
localparam M_D = FFT_LEN-DEC_FAC;

logic signed [(COEFF_WID-1):0] coeff_ram[FFT_LEN];
logic [$clog2(FFT_LEN)-1:0] coeff_ctr;
logic [$clog2(FFT_LEN)-1:0] coeff_rst = COF_SRT;

// TODO: for simple simulations, need to initialize with the actual coeff
initial begin
  for (int i=0; i<FFT_LEN; i++) begin
    coeff_ram[i] = i; //{{COEFF_WID-1{1'b0}}, {1'b1}};
  end
end

// MAC operation signals
logic signed [WIDTH-1:0] a;       // sin + din*h TODO: verilog gotchas to extend and determine
logic signed [(COEFF_WID-1):0] h; // coeff tap value
logic signed [(WIDTH-1):0] mac;   // TODO: need correct width and avoid verilog gotchas (sign/ext)

// buffer connection signals
logic signed [WIDTH-1:0] loopbuf_out;

// TODO: I had a rollover condition: if (coeff_ctr == (FFT_LEN-1)) coeff_ctr <= '0;
// but I cannot remember why if the RAM is always $clog2(FFT_LEN) number of address bits deep a
// natrual rollover shouldn't be a problem
always_ff @(posedge clk)
  if (rst)
    coeff_ctr <= coeff_rst;
  else if (en)
    coeff_ctr <= coeff_ctr - 1;
  else
    coeff_ctr <= coeff_ctr;

assign h = coeff_ram[coeff_ctr];

// pull from input or reuse from delay line
always_comb begin
  if (vin)
    a = din;
  else
    a = loopbuf_out;
end

assign mac = sin + a*h;

DelayBuf #(
  .DEPTH(M_D),
  .SRLEN(SRLEN),
  .WIDTH(WIDTH)
) loopbuf (
  .clk(clk),
  .rst(rst),
  .en(en),
  .din(a),
  .dout(loopbuf_out)
);

DelayBuf #(
  .DEPTH(2*FFT_LEN),
  .SRLEN(SRLEN),
  .WIDTH(WIDTH)
) databuf (
  .clk(clk),
  .rst(rst),
  .en(en),
  .din(loopbuf_out),
  .dout(dout)
);

DelayBuf #(
  .DEPTH(FFT_LEN),
  .SRLEN(SRLEN),
  .WIDTH(WIDTH)
) sumbuf (
  .clk(clk),
  .rst(rst),
  .en(en),
  .din(mac),
  .dout(sout)
);

DelayBuf #(        // TODO: it is real now... do we use an extra bit for the valid in the data?
  .DEPTH(FFT_LEN), // what was the right len again?
  .SRLEN(SRLEN),
  .WIDTH(1)        // the module should have no problem with 1 right? could test with the clk
) validbuf (
  .clk(clk),
  .rst(rst),
  .en(en),
  .din(vin),
  .dout(vout)
);

endmodule
