`timescale 1ns/1ps
`default_nettype none

module xpm_fir #(
  parameter int WIDTH=16,
  parameter int COEFF_WID=16,
  parameter int FFT_LEN=64,
  parameter int DEC_FAC=48,
  parameter int PTAPS=8,
  parameter LOOPBUF_MEM_TYPE="auto",
  parameter DATABUF_MEM_TYPE="auto",
  parameter SUMBUF_MEM_TYPE="auto",
  parameter logic signed [COEFF_WID-1:0] TAPS [PTAPS*FFT_LEN]
) (
  input wire logic clk,
  input wire logic rst,

  axis.SLV s_axis,               // adc samples in
  input wire logic s_axis_tuser, // vin

  axis.MST m_axis,               // polyphase fir sums out
  output logic m_axis_tuser      // vout
);

axis #(.WIDTH(WIDTH)) axis_pe_data[PTAPS+1]();
axis #(.WIDTH(WIDTH)) axis_pe_sum[PTAPS+1]();

logic [PTAPS:0] axis_pe_tuser;

assign axis_pe_data[0].tdata = s_axis.tdata;
assign axis_pe_data[0].tvalid = s_axis.tvalid;

assign s_axis.tready = (axis_pe_data[0].tready & axis_pe_sum[0].tready);

assign axis_pe_sum[0].tdata = {WIDTH{1'b0}};
assign axis_pe_sum[0].tvalid = s_axis.tvalid;

assign axis_pe_tuser[0] = s_axis_tuser;

assign m_axis.tdata = axis_pe_sum[PTAPS].tdata;
assign m_axis.tvalid = axis_pe_sum[PTAPS].tvalid;
assign m_axis_tuser = axis_pe_tuser[PTAPS];

assign axis_pe_data[PTAPS].tready = m_axis.tready;
assign axis_pe_sum[PTAPS].tready = m_axis.tready;

// Generate the chain of PE's and wire them together
genvar ii;
generate
  for (ii=0; ii < PTAPS; ii++) begin : gen_pe
    localparam logic signed [COEFF_WID-1:0] taps [FFT_LEN] = TAPS[ii*FFT_LEN:(ii+1)*FFT_LEN-1];
    xpm_pe #(
      .WIDTH(WIDTH),
      .COEFF_WID(COEFF_WID),
      .FFT_LEN(FFT_LEN),
      .DEC_FAC(DEC_FAC),
      .COF_SRT(0),
      .TAPS(taps)
    ) pe (
      .clk(clk),
      .rst(rst),
      .s_axis_data(axis_pe_data[ii]),
      .m_axis_data(axis_pe_data[ii+1]),

      .s_axis_sum(axis_pe_sum[ii]),
      .s_axis_sum_tuser(axis_pe_tuser[ii]),  // vin

      .m_axis_sum(axis_pe_sum[ii+1]),
      .m_axis_sum_tuser(axis_pe_tuser[ii+1]) // vout
    );
  end
endgenerate

endmodule

/*
  A PE based on the XPM Delaybuf
*/

module xpm_pe #(
  parameter WIDTH=16,
  parameter COEFF_WID=16,
  parameter FFT_LEN=64,
  parameter DEC_FAC=48,
  parameter COF_SRT=0,
  parameter LOOPBUF_MEM_TYPE="auto",
  parameter DATABUF_MEM_TYPE="auto",
  parameter SUMBUF_MEM_TYPE="auto",
  parameter logic signed [COEFF_WID-1:0] TAPS [FFT_LEN]
) (
  input wire logic clk,
  input wire logic rst,

  axis.SLV s_axis_data,
  axis.MST m_axis_data,

  axis.SLV s_axis_sum,
  input wire logic s_axis_sum_tuser,

  axis.MST m_axis_sum,
  output logic m_axis_sum_tuser
);

localparam M_D = FFT_LEN-DEC_FAC;

logic signed [(COEFF_WID-1):0] coeff_ram[FFT_LEN] = TAPS;
logic [$clog2(FFT_LEN)-1:0] coeff_ctr;
// TODO: make note how starting phase also would be important to get right here
logic [$clog2(FFT_LEN)-1:0] coeff_rst = COF_SRT;

// MAC operation signals
logic signed [WIDTH-1:0] a;          //sin + din*h TODO: verilog gotchas to extend and determine
logic signed [(COEFF_WID-1):0] h;    //coeff tap value
logic signed [(WIDTH-1):0] mac;      //TODO:need correct width and avoid verilog gotchas (sign/ext)
logic signed [(2*WIDTH-1):0] tmp_mac;//TODO:need correct width and avoid verilog gotchas (sign/ext)

// connection signals
axis #(.WIDTH(WIDTH)) s_axis_loopbuf(), m_axis_loopbuf();
axis #(.WIDTH(WIDTH)) axis_sumbuf();//TODO:need to extend to correct width to avoid sv gotchas

logic signed [WIDTH-1:0] din;
logic signed [WIDTH-1:0] sin;
logic signed [WIDTH-1:0] loopbuf_out;
logic vin;
logic en;
logic en_data;
logic en_sum;

// coeff ctr
always_ff @(posedge clk)
  if (rst)
    coeff_ctr <= coeff_rst;
  else if (en)
    coeff_ctr <= coeff_ctr - 1;
  else
    coeff_ctr <= coeff_ctr;

assign h = coeff_ram[coeff_ctr];

always_comb begin
  s_axis_data.tready = s_axis_loopbuf.tready;
  s_axis_loopbuf.tvalid = s_axis_data.tvalid;
  s_axis_loopbuf.tdata = a;

  en_data = s_axis_data.tvalid; //(s_axis_data.tready & s_axis_data.tvalid);

  s_axis_sum.tready = axis_sumbuf.tready;
  axis_sumbuf.tvalid = s_axis_sum.tvalid;
  axis_sumbuf.tdata = mac;

  en_sum = s_axis_sum.tvalid; //(s_axis_sum.tready & s_axis_sum.tvalid);

  en = en_sum;//(en_sum & en_data);
  vin = s_axis_sum_tuser;
  din = s_axis_data.tdata;
  sin = s_axis_sum.tdata;

  loopbuf_out = m_axis_loopbuf.tdata;
end

// pull from input or reuse from delay line
always_comb begin
  if (vin)
    a = din;
  else
    a = loopbuf_out;
end

// MAC
always_comb begin
  tmp_mac = sin + a*h;
  mac = $signed(tmp_mac[WIDTH-1:0]);
end

xpm_delaybuf #(
  .WIDTH(WIDTH),
  .FIFO_DEPTH(M_D),
  .TUSER_WIDTH(1),
  .MEM_TYPE(LOOPBUF_MEM_TYPE)
) loopbuf (
  .clk(clk),
  .rst(rst),
  .s_axis(s_axis_loopbuf), // input data from pe interface
  .s_axis_tuser(1'b0),     // not used here - hopefully removed
  .m_axis(m_axis_loopbuf), // output of loopbuf resampler
  .m_axis_tuser()          // not used here
);

xpm_delaybuf #(
  .WIDTH(WIDTH),
  .FIFO_DEPTH(2*FFT_LEN),
  .TUSER_WIDTH(1),
  .MEM_TYPE(DATABUF_MEM_TYPE)
) databuf (
  .clk(clk),
  .rst(rst),
  .s_axis(m_axis_loopbuf), // input data to databuf from loopbuf
  .s_axis_tuser(1'b0),     // not used here - hopefully removed
  .m_axis(m_axis_data),    // output data to next pe
  .m_axis_tuser()          // not used here - hopefully removed
);

xpm_delaybuf #(
  .WIDTH(WIDTH),
  .FIFO_DEPTH(FFT_LEN),
  .TUSER_WIDTH(1),
  .MEM_TYPE(SUMBUF_MEM_TYPE)
) sumbuf (
  .clk(clk),
  .rst(rst),
  .s_axis(axis_sumbuf),            // input partial fir sum
  .s_axis_tuser(vin),              // vin
  .m_axis(m_axis_sum),             // output partial fir sum to next pe
  .m_axis_tuser(m_axis_sum_tuser)  // vout
);

endmodule
