`timescale 1ns/1ps
`default_nettype none

import alpaca_constants_pkg::WIDTH; // TODO: TEMPORARY UNTIL ROUNDING IS RIGHT
import alpaca_dtypes_pkg::*;

module xpm_fir #(
  parameter int FFT_LEN=64,
  parameter int DEC_FAC=48,
  parameter int PTAPS=8,
  parameter LOOPBUF_MEM_TYPE="auto",
  parameter DATABUF_MEM_TYPE="auto",
  parameter SUMBUF_MEM_TYPE="auto",
  parameter fir_taps_t TAPS
  //parameter logic signed [COEFF_WID-1:0] TAPS [PTAPS*FFT_LEN]
) (
  input wire logic clk,
  input wire logic rst,

  alpaca_data_pkt_axis.SLV s_axis, // adc samples in, tuser=vin to be applied to sum axis
  alpaca_data_pkt_axis.MST m_axis  // polyphase fir sums out, tuser=vout
  // expected that sum output be rounded, scaled width (not full bit growth)
);

localparam samp_per_clk = s_axis.samp_per_clk;

alpaca_data_pkt_axis #(.dtype(sample_t), .SAMP_PER_CLK(samp_per_clk), .TUSER(1)) axis_pe_data[PTAPS+1](); // tuser not used
alpaca_data_pkt_axis #(.dtype(sample_t), .SAMP_PER_CLK(samp_per_clk), .TUSER(1)) axis_pe_sum[PTAPS+1](); // tuser for vin

assign axis_pe_data[0].tdata = s_axis.tdata;
assign axis_pe_data[0].tvalid = s_axis.tvalid;

assign s_axis.tready = (axis_pe_data[0].tready & axis_pe_sum[0].tready);

assign axis_pe_sum[0].tdata = '0;//{WIDTH{1'b0}};
assign axis_pe_sum[0].tvalid = s_axis.tvalid;
assign axis_pe_sum[0].tuser = s_axis.tuser;

assign m_axis.tdata = axis_pe_sum[PTAPS].tdata;
assign m_axis.tvalid = axis_pe_sum[PTAPS].tvalid;
assign m_axis.tuser = axis_pe_sum[PTAPS].tuser;

assign axis_pe_data[PTAPS].tready = m_axis.tready;
assign axis_pe_sum[PTAPS].tready = m_axis.tready;

// Generate the chain of PE's and wire them together
genvar ii;
generate
  for (ii=0; ii < PTAPS; ii++) begin : gen_pe
    //localparam logic signed [COEFF_WID-1:0] taps [FFT_LEN] = TAPS[ii*FFT_LEN:(ii+1)*FFT_LEN-1];
    localparam branch_taps_t taps=TAPS[ii*(FFT_LEN/samp_per_clk):(ii+1)*(FFT_LEN/samp_per_clk)-1];
    xpm_pe #(
      .FFT_LEN(FFT_LEN),
      .DEC_FAC(DEC_FAC),
      .COF_SRT(0),
      .TAPS(taps)
    ) pe (
      .clk(clk),
      .rst(rst),
      .s_axis_data(axis_pe_data[ii]),
      .m_axis_data(axis_pe_data[ii+1]),

      .s_axis_sum(axis_pe_sum[ii]),   // tuser=vin
      .m_axis_sum(axis_pe_sum[ii+1])  // tuser=vout
    );
  end
endgenerate

endmodule

/*
  A PE based on the XPM Delaybuf
*/

module xpm_pe #(
  parameter FFT_LEN=64,
  parameter DEC_FAC=48,
  parameter COF_SRT=0,
  parameter LOOPBUF_MEM_TYPE="auto",
  parameter DATABUF_MEM_TYPE="auto",
  parameter SUMBUF_MEM_TYPE="auto",
  parameter branch_taps_t TAPS
  //parameter logic signed [COEFF_WID-1:0] TAPS [FFT_LEN]
) (
  input wire logic clk,
  input wire logic rst,

  alpaca_data_pkt_axis.SLV s_axis_data,
  alpaca_data_pkt_axis.MST m_axis_data,

  alpaca_data_pkt_axis.SLV s_axis_sum, //tuser=vin, expecting TUSER WIDTH to be 1 right?
  alpaca_data_pkt_axis.MST m_axis_sum  //tuser=vout
);
typedef s_axis_data.data_pkt_t data_pkt_t;
localparam samp_per_clk = s_axis_data.samp_per_clk;

localparam M_D = FFT_LEN-DEC_FAC;
localparam mem_depth = FFT_LEN/samp_per_clk;

coeff_pkt_t coeff_ram[mem_depth] = TAPS; // TODO: fix for synthesis with $bits(coeff_pkt_t)
logic [$clog2(mem_depth)-1:0] coeff_ctr;
// TODO: make note how starting phase also would be important to get right here
logic [$clog2(mem_depth)-1:0] coeff_rst = COF_SRT;

// MAC operation signals
fir_pkt_t a;        // note: *not* complex samples but multiple real (or imag), sin + din*h TODO: verilog gotchas to extend and determine
coeff_pkt_t h;      // coeff tap value, stores `samp_per_clk` coeff {hx, hy}
fir_pkt_t mac;      // TODO:need correct width and avoid verilog gotchas (sign/ext)
mac_pkt_t tmp_mac;  // note: this is the full growth required (1 mult and 1 add) TODO:need correct width and avoid verilog gotchas (sign/ext)

// connection signals
alpaca_data_pkt_axis #(
  .dtype(sample_t),
  .SAMP_PER_CLK(samp_per_clk),
  .TUSER(1)
) s_axis_loopbuf(), m_axis_loopbuf(), axis_sumbuf();
// tusers not driven on loopbuf interfaces vivado synthesis should complain
// tuser in the sumbuf interface represents valid in (vin)
// TODO: need to get data width correct on sumbuf to avoid sv gotchas with sign extension, etc.

fir_pkt_t din;
fir_pkt_t sin;
fir_pkt_t loopbuf_out;
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
  axis_sumbuf.tuser = s_axis_sum.tuser; //vin

  en_sum = s_axis_sum.tvalid; //(s_axis_sum.tready & s_axis_sum.tvalid);

  en = en_sum;//(en_sum & en_data);
  din = s_axis_data.tdata;
  sin = s_axis_sum.tdata;

  loopbuf_out = m_axis_loopbuf.tdata;
end

// pull from input or reuse from delay line
always_comb begin
  if (s_axis_sum.tuser) // vin
    a = din;
  else
    a = loopbuf_out;
end

// MAC
always_comb begin
  tmp_mac[1] = sin[1] + a[1]*h[1];
  tmp_mac[0] = sin[0] + a[0]*h[0];

  mac[1] = $signed(tmp_mac[1][WIDTH-1:0]);
  mac[0] = $signed(tmp_mac[0][WIDTH-1:0]);
end

// width now determined internal based on s_axis interface
xpm_delaybuf #(
  .FIFO_DEPTH(M_D/samp_per_clk),
  .TUSER(1),
  .MEM_TYPE(LOOPBUF_MEM_TYPE)
) loopbuf (
  .clk(clk),
  .rst(rst),
  .s_axis(s_axis_loopbuf), // input data from pe interface, tuser not used here
  .m_axis(m_axis_loopbuf)  // output of loopbuf resampler, tuser not used here
);

// width now determined internal based on s_axis interface
xpm_delaybuf #(
  .FIFO_DEPTH(2*(FFT_LEN/samp_per_clk)),
  .TUSER(1),
  .MEM_TYPE(DATABUF_MEM_TYPE)
) databuf (
  .clk(clk),
  .rst(rst),
  .s_axis(m_axis_loopbuf), // input data to databuf from loopbuf, tuser not used here
  .m_axis(m_axis_data)     // output data to next pe, tuser not used here
);

xpm_delaybuf #(
  .FIFO_DEPTH(FFT_LEN/samp_per_clk),
  .TUSER(1),
  .MEM_TYPE(SUMBUF_MEM_TYPE)
) sumbuf (
  .clk(clk),
  .rst(rst),
  .s_axis(axis_sumbuf), // input partial fir sum, tuser used to represent vin
  .m_axis(m_axis_sum)   // output partial fir sum to next pe, tuser to represent vout
);

endmodule
