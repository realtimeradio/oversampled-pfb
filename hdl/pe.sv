`timescale 1ns/1ps
`default_nettype none

// TODO: do we need a data type parameter so SRLShiftReg can be signed and unsigned?
module datapath #( // less phasecomp... and fft...
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
// TODO: make note how starting phase also would be important to get right here
logic [$clog2(FFT_LEN)-1:0] coeff_rst = COF_SRT;

// MAC operation signals
logic signed [WIDTH-1:0] a;       // sin + din*h TODO: verilog gotchas to extend and determine
logic signed [(COEFF_WID-1):0] h; // coeff tap value
logic signed [(WIDTH-1):0] mac;   // TODO: need correct width and avoid verilog gotchas (sign/ext)
logic signed [(2*WIDTH-1):0] tmp_mac;   // TODO: need correct width and avoid verilog gotchas (sign/ext)

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

always_comb begin
  tmp_mac = sin + a*h;
  mac = $signed(tmp_mac[WIDTH-1:0]);
  //mac = $signed(tmp_mac[26:11]);
  //mac = $signed(tmp_mac[2*WIDTH-1:WIDTH]);
end
//assign mac = sin + a*h;

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
