`timescale 1ns/1ps
`default_nettype none

import alpaca_constants_pkg::*;
import alpaca_dtypes_pkg::*;

module xpm_fir #(
  parameter int FFT_LEN=64,
  parameter int DEC_FAC=48,
  parameter int PTAPS=8,
  parameter LOOPBUF_MEM_TYPE="auto",
  parameter DATABUF_MEM_TYPE="auto",
  parameter SUMBUF_MEM_TYPE="auto",
  parameter fir_taps_t TAPS
) (
  input wire logic clk,
  input wire logic rst,

  alpaca_data_pkt_axis.SLV s_axis, // adc samples in, tuser=vin to be applied to sum axis
  alpaca_data_pkt_axis.MST m_axis  // polyphase fir sums out, tuser=vout
);

localparam samp_per_clk = s_axis.samp_per_clk;

alpaca_data_pkt_axis #(.dtype(sample_t), .SAMP_PER_CLK(samp_per_clk), .TUSER(1)) axis_pe_data[PTAPS+1](); // tuser not used
alpaca_data_pkt_axis #(.dtype(sample_t), .SAMP_PER_CLK(samp_per_clk), .TUSER(1)) axis_pe_sum[PTAPS+1](); // tuser for vin

assign axis_pe_data[0].tdata = s_axis.tdata;
assign axis_pe_data[0].tvalid = s_axis.tvalid;

assign s_axis.tready = (axis_pe_data[0].tready & axis_pe_sum[0].tready);

assign axis_pe_sum[0].tdata = '0;
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

  *not* complex samples but multiple real (or imag), supports multiple samples per clock in this
  polyphase fir framework not sure how it would extend to a more general FIR and correclty align
  the filter coefficients with the correct time sample.

  This PE implments a simple multiply-add (din*h + sin), which would be a single partial sum used in the full
  multiply accumulate operation of an FIR filter.
*/

module xpm_pe #(
  parameter FFT_LEN=64,
  parameter DEC_FAC=48,
  parameter COF_SRT=0,
  parameter LOOPBUF_MEM_TYPE="auto",
  parameter DATABUF_MEM_TYPE="auto",
  parameter SUMBUF_MEM_TYPE="auto",
  parameter branch_taps_t TAPS
) (
  input wire logic clk,
  input wire logic rst,

  alpaca_data_pkt_axis.SLV s_axis_data,
  alpaca_data_pkt_axis.MST m_axis_data,

  alpaca_data_pkt_axis.SLV s_axis_sum, //tuser=vin, expecting TUSER WIDTH to be 1
  alpaca_data_pkt_axis.MST m_axis_sum  //tuser=vout
);
typedef s_axis_data.data_pkt_t data_pkt_t;
localparam samp_per_clk = s_axis_data.samp_per_clk;

localparam M_D = FFT_LEN-DEC_FAC;
localparam mem_depth = FFT_LEN/samp_per_clk;

// TODO: fix for synthesis with $bits(coeff_pkt_t)
coeff_pkt_t coeff_ram[mem_depth] = TAPS;
logic [$clog2(mem_depth)-1:0] coeff_ctr;
// TODO: make note how starting phase also would be important to get right here
logic [$clog2(mem_depth)-1:0] coeff_rst = COF_SRT;

// MAC operation signals
fir_pkt_t a;
fir_pkt_t mac;
coeff_pkt_t h;

// connection signals
alpaca_data_pkt_axis #(
  .dtype(sample_t),
  .SAMP_PER_CLK(samp_per_clk),
  .TUSER(1)
) s_axis_loopbuf(), m_axis_loopbuf(), axis_sumbuf(), axis_databuf();
// tusers not driven on loopbuf interfaces vivado synthesis should complain
// tuser in the sumbuf interface represents valid in (vin)

fir_pkt_t din;
fir_pkt_t sin;
fir_pkt_t loopbuf_out;
logic en;

// coeff ctr
always_ff @(posedge clk)
  if (rst)
    coeff_ctr <= coeff_rst;
  else if (en)
    coeff_ctr <= coeff_ctr - 1;
  else
    coeff_ctr <= coeff_ctr;

assign h = coeff_ram[coeff_ctr];

localparam MULT_LAT = 7; // mult=5 + rnd=2
fir_pkt_t [MULT_LAT-1:0] databuf_data_delay;
logic [MULT_LAT-1:0][1:0] sumbuf_axis_delay, databuf_axis_delay;
logic [MULT_LAT-1:0] sumbuf_tuser_delay;

always_ff @(posedge clk) begin
  sumbuf_axis_delay <= {sumbuf_axis_delay[MULT_LAT-2:0], {s_axis_sum.tvalid, s_axis_sum.tlast}};
  sumbuf_tuser_delay <= {sumbuf_tuser_delay[MULT_LAT-2:0], s_axis_sum.tuser};

  databuf_data_delay <= {databuf_data_delay[MULT_LAT-2:0], m_axis_loopbuf.tdata};
  databuf_axis_delay <= {databuf_axis_delay[MULT_LAT-2:0], {m_axis_loopbuf.tvalid, m_axis_loopbuf.tlast}};
end

always_comb begin
  s_axis_loopbuf.tdata = a;
  s_axis_loopbuf.tvalid = s_axis_data.tvalid;
  s_axis_data.tready = s_axis_loopbuf.tready;

  axis_sumbuf.tdata = mac;
  axis_sumbuf.tvalid = sumbuf_axis_delay[MULT_LAT-1][1];
  axis_sumbuf.tlast = sumbuf_axis_delay[MULT_LAT-1][0];
  axis_sumbuf.tuser = sumbuf_tuser_delay[MULT_LAT-1]; //vin
  s_axis_sum.tready = axis_sumbuf.tready;

  en = s_axis_sum.tvalid;
  din = s_axis_data.tdata;
  sin = s_axis_sum.tdata;

  loopbuf_out = m_axis_loopbuf.tdata;

  axis_databuf.tdata = databuf_data_delay[MULT_LAT-1];
  axis_databuf.tvalid = databuf_axis_delay[MULT_LAT-1][1];
  axis_databuf.tlast = databuf_axis_delay[MULT_LAT-1][0];
  m_axis_loopbuf.tready = axis_databuf.tready;
end

// pull from input or reuse from delay line
always_comb begin
  if (s_axis_sum.tuser) // vin
    a = din;
  else
    a = loopbuf_out;
end

// MAC and convergent round
// potentially may want to have the convergent round be its own block as to support
// seperate the functionality for if we need dynamic scaling
fp_data #(
  .dtype(sample_t),
  .W(WIDTH),
  .F(FRAC_WIDTH)
) a_in[SAMP_PER_CLK](), c_in[SAMP_PER_CLK](), dout[SAMP_PER_CLK]();

fp_data #(
  .dtype(coeff_t),
  .W(COEFF_WID),
  .F(COEFF_FRAC_WID)
) b_in[SAMP_PER_CLK]();

//fp_data #(
//  .dtype(mac_t),
//  .W(WIDTH+COEFF_WID+1),
//  .F(FRAC_WIDTH+COEFF_FRAC_WID)
//) dout[SAMP_PER_CLK]();

genvar ii;
generate
  for (ii=0; ii<SAMP_PER_CLK; ii++) begin
    assign a_in[ii].data = a[ii];
    assign b_in[ii].data = h[ii];
    assign c_in[ii].data = sin[ii];
    alpaca_multadd_convrnd pe_multadd (
      .clk(clk),
      .rst(rst),
      .a_in(a_in[ii]),
      .b_in(b_in[ii]),
      .c_in(c_in[ii]),
      .dout(dout[ii])
    );

    assign mac[ii] = dout[ii].data;
  end
endgenerate

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

xpm_delaybuf #(
  .FIFO_DEPTH(2*(FFT_LEN/samp_per_clk)),
  .TUSER(1),
  .MEM_TYPE(DATABUF_MEM_TYPE)
) databuf (
  .clk(clk),
  .rst(rst),
  .s_axis(axis_databuf), // input data to databuf from loopbuf, tuser not used here
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

endmodule : xpm_pe
