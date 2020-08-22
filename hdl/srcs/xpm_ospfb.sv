`timescale 1ns/1ps
`default_nettype none

module xpm_ospfb #(
  parameter WIDTH=16,
  parameter COEFF_WID=16,
  parameter BASE_COEF_FILE="",
  parameter FFT_LEN=32,
  parameter DEC_FAC=24,
  parameter SRT_PHA=23,  // (DEC_FAC-1) modtimer decimation phase start (which port delivered first)
  parameter PTAPS=8,
  parameter SRLEN=8,
  parameter LOOPBUF_MEM_TYPE="auto",
  parameter DATABUF_MEM_TYPE="auto",
  parameter SUMBUF_MEM_TYPE="auto",
  parameter CONF_WID=8,
  parameter TUSER_WID=8
) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,  // TODO: evaluate the need and use of this signal the signal

  // TODO: wanting to implement m_axis tready as a debug to make sure we are always accepting a
  // sample each cycle as noted in the AMBA AXIS recommendation for tready implementation
  axis.SLV s_axis,                      // upstream input data

  axis.MST m_axis_fft_status,           // FFT status for overflow
  axis.MST m_axis_data,                 // OSPFB output data
  output logic m_axis_data_tlast,
  output logic [TUSER_WID-1:0] m_axis_data_tuser,

  output logic event_frame_started,
  output logic event_tlast_unexpected,
  output logic event_tlast_missing,
  output logic event_fft_overflow,
  output logic event_data_in_channel_halt
);

// fft and xpm_fifo is reset low
logic aresetn;
assign aresetn = ~rst;

// may not need anymore with everything on axis?... ah, but the phasecomp isn't yet
logic hold_rst;

// for controlling samples
logic [$clog2(FFT_LEN)-1:0] modtimer;           // decimator phase
logic [$clog2(FFT_LEN)-1:0] rst_val = SRT_PHA;  // starting decimator phase (which port gets first sample)

logic vin;
logic signed [WIDTH-1:0] din_re;
logic signed [WIDTH-1:0] din_im;

logic signed [WIDTH-1:0] pc_in_re;
logic signed [WIDTH-1:0] pc_in_im;

//logic vout_re;
//logic vout_im;
//logic signed [WIDTH-1:0] dout_re;
//logic signed [WIDTH-1:0] dout_im;
logic signed [WIDTH-1:0] sout_re;
logic signed [WIDTH-1:0] sout_im;

logic s_axis_tuser, m_axis_tuser_re, m_axis_tuser_im;
assign s_axis_tuser = vin;

axis #(.WIDTH(WIDTH)) s_axis_fir_re(), s_axis_fir_im();
axis #(.WIDTH(WIDTH)) m_axis_fir_re(), m_axis_fir_im();

assign s_axis_fir_re.tdata = din_re;
assign s_axis_fir_re.tvalid = s_axis.tvalid;

assign s_axis_fir_im.tdata = din_im;
assign s_axis_fir_im.tvalid = s_axis.tvalid;

assign pc_in_re = (m_axis_fir_re.tready & m_axis_fir_re.tvalid) ? m_axis_fir_re.tdata : '0;
assign pc_in_im = (m_axis_fir_im.tready & m_axis_fir_im.tvalid) ? m_axis_fir_im.tdata : '0;
// since the upstream slave is the phase comp and phasecomp isn't ready until after hold_rst
// this seems to make sense
assign m_axis_fir_re.tready = ~hold_rst;
assign m_axis_fir_im.tready = ~hold_rst;
/*
  s_axis_fft_data todo's
  TODO (tlast): with this hardwired to 0 there will `even_tlast_unexpected` triggered. However,
  since we need everything to be in lockstep the tlast should be easily computed then we can
  continue to have good ways to know if we get out of sync somehow
*/
axis #(.WIDTH(2*WIDTH)) s_axis_fft_data();
logic s_axis_fft_data_tlast;

// To configure the inverse transform and scaling schedule
axis #(.WIDTH(CONF_WID)) s_axis_config();

always_ff @(posedge clk)
  if (hold_rst)
    modtimer <= rst_val;
  else if (en)
    modtimer <= modtimer + 1;
  else
    modtimer <= modtimer;

xpm_datapath #(
  .WIDTH(WIDTH),
  .COEFF_WID(COEFF_WID),
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .PTAPS(PTAPS),
  .BASE_COEF_FILE(BASE_COEF_FILE),
  .LOOPBUF_MEM_TYPE(LOOPBUF_MEM_TYPE),
  .DATABUF_MEM_TYPE(DATABUF_MEM_TYPE),
  .SUMBUF_MEM_TYPE(SUMBUF_MEM_TYPE)
) fir_re (
  .clk(clk),
  .rst(rst),
  .s_axis(s_axis_fir_re),
  .s_axis_tuser(s_axis_tuser), // vin
  .m_axis(m_axis_fir_re),
  .m_axis_tuser(m_axis_tuser_re)  // vout
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

xpm_datapath #(
  .WIDTH(WIDTH),
  .COEFF_WID(COEFF_WID),
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .PTAPS(PTAPS),
  .BASE_COEF_FILE(BASE_COEF_FILE),
  .LOOPBUF_MEM_TYPE(LOOPBUF_MEM_TYPE),
  .DATABUF_MEM_TYPE(DATABUF_MEM_TYPE),
  .SUMBUF_MEM_TYPE(SUMBUF_MEM_TYPE)
) fir_im (
  .clk(clk),
  .rst(rst),
  .s_axis(s_axis_fir_im),
  .s_axis_tuser(s_axis_tuser),
  .m_axis(m_axis_fir_im),
  .m_axis_tuser(m_axis_tuser_im)
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

// TODO: is this going to interfer with the dc fifo out front? It will if this comes out of
// reset later than dcfifo. Or the state machine now has to watch both of these
logic xfft_delay_fifo_tready;
xpm_fifo_axis #(
  .CLOCKING_MODE("common_clock"),
  .FIFO_DEPTH(16),// In simulation shown we only need two because of FFT slave wait state at beginning
  .FIFO_MEMORY_TYPE("auto"),
  .SIM_ASSERT_CHK(0),
  .TDATA_WIDTH(2*WIDTH)
) xfft_delay_fifo_inst (
  .m_axis_tdata(s_axis_fft_data.tdata),
  .m_axis_tlast(s_axis_fft_data_tlast),
  .m_axis_tvalid(s_axis_fft_data.tvalid),
  .s_axis_tready(xfft_delay_fifo_tready),

  .m_aclk(clk),

  .m_axis_tready(s_axis_fft_data.tready),

  .s_aclk(clk),

  .s_aresetn(aresetn),

  // TODO: this concatenation and ~ of a signal is easy in simulation but I am not sure of the
  // implementation cause and could cause timing problems that may suggest to pipeline
  .s_axis_tdata({sout_im, sout_re}),
  .s_axis_tlast(1'b0),
  .s_axis_tvalid(~hold_rst) // idea being we come out of hold_rst and the ospfb is streaming
);

xfft_0 fft_inst (
  .aclk(clk), 
  .aresetn(aresetn),
  // Confguration channel to set inverse transform and scaling schedule
  // (width dependent on configuration and selected optional features)
  .s_axis_config_tdata(s_axis_config.tdata),
  .s_axis_config_tvalid(s_axis_config.tvalid),
  .s_axis_config_tready(s_axis_config.tready),

  .s_axis_data_tdata(s_axis_fft_data.tdata),
  .s_axis_data_tvalid(s_axis_fft_data.tvalid),
  .s_axis_data_tready(s_axis_fft_data.tready),
  .s_axis_data_tlast(s_axis_fft_data_tlast),

  .m_axis_data_tdata(m_axis_data.tdata),
  .m_axis_data_tvalid(m_axis_data.tvalid),
  .m_axis_data_tlast(m_axis_data_tlast),
  .m_axis_data_tuser(m_axis_data_tuser),
  // Status channel for overflow information and optional Xk index
  // (width dependent on configuration and selected optional features)
  .m_axis_status_tdata(m_axis_fft_status.tdata),
  .m_axis_status_tvalid(m_axis_fft_status.tvalid),

  .event_frame_started(event_frame_started),
  .event_tlast_unexpected(event_tlast_unexpected),
  .event_tlast_missing(event_tlast_missing),
  .event_fft_overflow(event_fft_overflow),
  .event_data_in_channel_halt(event_data_in_channel_halt)
);

/*
  TODO: With SRL32s there is no real state machine for pop/push into the delay lines because
  they are implemented now as a true SR fifo and not a bram fifo with circular address
  pointers. The only state machine for now is therefore this top one that is used for debugging
  and implementing AXIS. Hoping it is not too much overhead. The debugging on AXIS came from
  ARM AXIS recommendation to implement tready even if the IP always needs to be ready as a way
  to debug and that if it isn't the signal is monitored more as an error.
*/

typedef enum logic [1:0] {WAIT_FIFO, FORWARD, FEEDBACK, ERR='X} stateType;
stateType cs, ns;

// FSM state register
always_ff @(posedge clk)
  cs <= ns;

always_comb begin
  // default values to prevent latch inferences
  ns = ERR;
  din_re = 32'haabbccdd; //should never see these values, if so, it is an error
  din_im = 32'hddccaabb;
  hold_rst = 1'b1;

  // ospfb.py top-level equivalent producing the vin to start the process
  // why modtimer < dec_fac and not dec_fac-1 like in src counter pass through?
  s_axis.tready = 1'b0;
  /*
  TODO: where to use m_axis_data.tready for debug monitoring of slave. If m_axis_data.tready
    isn't used for anything meaningful vivado synthesis throws a warning but may not be an issue.
    Will get unexpected synthesis behavior if I don't remove this when testing it
  */
  vin = 1'b0;

  // TODO: only set once but should be parameterized so that I don't forget it when moving
  // between M for testing
  // default configuration values {pad (if needed), scale_sched, fwd/inv xform}
  //s_axis_config.tdata = {1'b0, 2'b10, 2'b10, 2'b10, 1'b0};
  s_axis_config.tdata = {3'b0, 2'b00, 2'b10, 2'b10, 2'b10, 2'b10, 2'b10, 1'b0};
  s_axis_config.tvalid = 1'b0;

  /*
  TODO: supporting arbitrary dec fac
    This is a simple fsm made for the early development but now that I have start thinking about
    processing parallel samples this fsm would be the perfect (and really only place) where such a
    complicated operation would take place to handle general arbitrary os ratios
  */
  if (rst) begin
    ns = WAIT_FIFO;
  end else begin
    case (cs)
      WAIT_FIFO: begin
        if (s_axis.tvalid) begin
          hold_rst = 1'b0;
          s_axis_config.tvalid = 1'b1;   // load the inverse transform and scaling schedule

          s_axis.tready = (modtimer < DEC_FAC) ? 1'b1 : 1'b0;
          vin = (s_axis.tready & s_axis.tvalid) ? 1'b1: 1'b0; // shouldn't this be in my states as well?
          // move first to FEEDBACK. Although we are loading one sample now this is the last
          // sample of a FORWARD state operation (loading at port 0 then wrapping to port D-1)
          din_re = s_axis.tdata[WIDTH-1:0];
          din_im = s_axis.tdata[2*WIDTH-1:WIDTH];
          ns = FEEDBACK;
        end else begin
          ns = WAIT_FIFO;
        end
      end

      FORWARD: begin
        hold_rst = 1'b0;

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
        s_axis.tready = (modtimer < DEC_FAC) ? 1'b1 : 1'b0;
        vin = (s_axis.tready & s_axis.tvalid) ? 1'b1: 1'b0;
        din_re = 32'hdeadbeef; // bogus data for testing, should not be accepted to delaybufs
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
