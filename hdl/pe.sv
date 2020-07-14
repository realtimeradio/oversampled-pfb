`timescale 1ns/1ps
`default_nettype none

module OSPFB #(
  parameter WIDTH=16,
  parameter COEFF_WID=16,
  parameter FFT_LEN=32,
  parameter DEC_FAC=24,
  parameter SRT_PHA=23,  // modtimer decimation phase start (which port delivered first)
  parameter PTAPS=8,
  parameter SRLEN=8
) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,  // TODO: evaluate the need and use of this signal the signal
  // TODO: wanting to implement tready as a debug to make sure we are always accepting a sample
  // each cycle as noted in the AMBA AXIS recommendation for tready implementation
  axis.MST m_axis,
  axis.SLV s_axis
);

// for controlling samples
logic [$clog2(FFT_LEN)-1:0] modtimer;           // decimator phase
logic [$clog2(FFT_LEN)-1:0] rst_val = SRT_PHA;  // starting decimator phase (which port gets first sample)

logic vin;
logic signed [WIDTH-1:0] din;

logic signed [WIDTH-1:0] pc_in;

logic vout;
logic signed [WIDTH-1:0] dout;
logic signed [WIDTH-1:0] sout;

always_ff @(posedge clk)
  if (rst)
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
) fir (
  .clk(clk),
  .rst(rst),
  .en(en), //TODO: how much longer do I carry this around...
  .vin(vin),
  .din(din),
  .vout(vout),
  .dout(dout),
  .sout(pc_in)
);

PhaseComp #(
  .WIDTH(WIDTH),
  .DEPTH(2*FFT_LEN),
  .DEC_FAC(DEC_FAC)
) phasecomp_inst (
  .clk(clk),
  .rst(rst),
  .din(pc_in),
  .dout(sout)
);

typedef enum logic {FORWARD, FEEDBACK, ERR='X} stateType;
stateType cs, ns;

// FSM state register
always_ff @(posedge clk)
  cs <= ns;

always_comb begin
  // default values to prevent latch inferences
  ns = ERR;
  din = 32'haabbccdd; //should never see this value, if so it is an error

  // ospfb.py top-level equivalent producing the vin to start the process
  // why modtimer < dec_fac and not dec_fac-1 like in src counter pass through?
  s_axis.tready = (modtimer < DEC_FAC) ? 1'b1 : 1'b0;

  // TODO: what is the right thing to do here... for the output
  m_axis.tvalid = vout;
  m_axis.tdata  = sout;

  /*
     TODO: where to use m_axis.tready for debug monitoring of slave. If m_axis.tready isn't used
     for anything meaningful vivado synthesis throws a warning but may not be an issue. Will get
     unexpected synthesis behavior if I don't remove this when testing it
  */
  vin = (s_axis.tready & s_axis.tvalid) ? 1'b1: 1'b0;

  if (rst)
    ns = FORWARD; // always start by processing
  else
    case (cs)
      FORWARD: begin
        din = s_axis.tdata;
        if (modtimer == DEC_FAC-1)
          ns = FEEDBACK;
        else
          ns = FORWARD;
      end

      FEEDBACK: begin
        din = 32'hdeadbeef; // bogus data for testing
        if (modtimer == FFT_LEN-1)
          ns = FORWARD;
        else
          ns = FEEDBACK;
      end
    endcase // case
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
