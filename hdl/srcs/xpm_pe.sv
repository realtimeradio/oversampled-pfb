`timescale 1ns/1ps
`default_nettype none

import alpaca_constants_pkg::*;
import alpaca_dtypes_pkg::*;

/******************************************************
  tap rom for a single PE
*******************************************************/

module tap_rom #(
  parameter FFT_LEN=2048,
  parameter SAMP_PER_CLK=2,
  parameter COF_SRT=0,
  parameter branch_taps_t TAPS
) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,

  output coeff_pkt_t h
);

  localparam mem_depth = FFT_LEN/SAMP_PER_CLK;
  coeff_pkt_t coeff_ram[mem_depth] = TAPS;

  logic [$clog2(mem_depth)-1:0] coeff_ctr;
  logic [$clog2(mem_depth)-1:0] coeff_rst = COF_SRT;

  always_ff @(posedge clk)
    if (rst)
      coeff_ctr <= coeff_rst;
    else if (en)
      coeff_ctr <= coeff_ctr - 1;

  assign h = coeff_ram[coeff_ctr];

endmodule : tap_rom

/*******************************************************
  XPM CX FIR
*******************************************************/

module xpm_cx_fir #(
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

  alpaca_data_pkt_axis.SLV s_axis,    // adc samples in, tuser=vin to be applied to sum axis
  alpaca_data_pkt_axis.MST m_axis_im, // polyphase fir sums out, tuser=vout
  alpaca_data_pkt_axis.MST m_axis_re
);

localparam samp_per_clk = s_axis.samp_per_clk;

alpaca_data_pkt_axis #(
  .dtype(sample_t),
  .SAMP_PER_CLK(samp_per_clk),
  .TUSER(1)
) axis_pe_data_im[PTAPS+1](), axis_pe_data_re[PTAPS+1](); // tuser not used

alpaca_data_pkt_axis #(
  .dtype(sample_t),
  .SAMP_PER_CLK(samp_per_clk),
  .TUSER(1)
) axis_pe_sum_im[PTAPS+1](), axis_pe_sum_re[PTAPS+1](); // tuser for vin

coeff_pkt_t h[PTAPS];

// connect first PE with inputs
genvar jj;
generate
  for (jj=0; jj < samp_per_clk; jj++) begin : route_cx_to_re
    assign axis_pe_data_im[0].tdata[jj] = s_axis.tdata[jj].im;
    assign axis_pe_data_re[0].tdata[jj] = s_axis.tdata[jj].re;
  end
endgenerate

assign axis_pe_data_im[0].tvalid = s_axis.tvalid;
assign axis_pe_data_re[0].tvalid = s_axis.tvalid;

assign s_axis.tready = (axis_pe_data_re[0].tready & axis_pe_sum_re[0].tready);

assign axis_pe_sum_im[0].tdata = '0;
assign axis_pe_sum_re[0].tdata = '0;
assign axis_pe_sum_im[0].tvalid = s_axis.tvalid;
assign axis_pe_sum_re[0].tvalid = s_axis.tvalid;
assign axis_pe_sum_im[0].tuser = s_axis.tuser;
assign axis_pe_sum_re[0].tuser = s_axis.tuser;

// connect last PE with outputs
assign m_axis_im.tdata = axis_pe_sum_im[PTAPS].tdata;
assign m_axis_re.tdata = axis_pe_sum_re[PTAPS].tdata;
assign m_axis_im.tvalid = axis_pe_sum_im[PTAPS].tvalid;
assign m_axis_re.tvalid = axis_pe_sum_re[PTAPS].tvalid;
assign m_axis_im.tuser = axis_pe_sum_im[PTAPS].tuser;
assign m_axis_re.tuser = axis_pe_sum_re[PTAPS].tuser;

assign axis_pe_data_im[PTAPS].tready = m_axis_im.tready;
assign axis_pe_data_re[PTAPS].tready = m_axis_re.tready;
assign axis_pe_sum_im[PTAPS].tready = m_axis_im.tready;
assign axis_pe_sum_re[PTAPS].tready = m_axis_re.tready;

// Generate the chain of PE's and wire them together
genvar ii;
generate
  for (ii=0; ii < PTAPS; ii++) begin : gen_pe
    localparam branch_taps_t taps=TAPS[ii*(FFT_LEN/samp_per_clk):(ii+1)*(FFT_LEN/samp_per_clk)-1];
    xpm_pe #(
      .FFT_LEN(FFT_LEN),
      .DEC_FAC(DEC_FAC),
      .TAPS(taps)
    ) pe_re (
      .clk(clk),
      .rst(rst),
      .h(h[ii]),
      .s_axis_data(axis_pe_data_re[ii]),
      .m_axis_data(axis_pe_data_re[ii+1]),

      .s_axis_sum(axis_pe_sum_re[ii]),   // tuser=vin
      .m_axis_sum(axis_pe_sum_re[ii+1])  // tuser=vout
    );

    tap_rom #(
      .FFT_LEN(FFT_LEN),
      .SAMP_PER_CLK(samp_per_clk),
      .COF_SRT(0),
      .TAPS(taps)
    ) pe_taps (
      .clk(clk),
      .rst(rst),
      .en(axis_pe_sum_re[ii].tvalid), // default to real data for control
      .h(h[ii])
    );

    xpm_pe #(
      .FFT_LEN(FFT_LEN),
      .DEC_FAC(DEC_FAC),
      .TAPS(taps)
    ) pe_im (
      .clk(clk),
      .rst(rst),
      .h(h[ii]),
      .s_axis_data(axis_pe_data_im[ii]),
      .m_axis_data(axis_pe_data_im[ii+1]),

      .s_axis_sum(axis_pe_sum_im[ii]),   // tuser=vin
      .m_axis_sum(axis_pe_sum_im[ii+1])  // tuser=vout
    );
  end
endgenerate

endmodule : xpm_cx_fir

/*******************************************************
  XPM FIR
*******************************************************/

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

endmodule : xpm_fir

/*
  A PE based on the XPM Delaybuf

  *not* complex samples but multiple real (or imag), supports multiple samples per clock in this
  polyphase fir framework not sure how it would extend to a more general FIR and correclty align
  the filter coefficients with the correct time sample.

  This PE implments a simple multiply-add (din*h + sin), which would be a single partial sum used in the full
  multiply accumulate operation of an FIR filter.

  The only control within the PE is the decision to pull from the loopback buffer or not using
  the tuser (vin) signal based on the commutator counter from the top level state machine. When
  the coefficient rom was part of the PE the address counter was advanced by the axis_sum valid
  signal that indicated the next valid partial sum input was ready and that a multiply-accumulate
  should start. Now, the axis_sum valid still controls the address counter but the ROM is one
  level higher to share between real/imaginary fir processing. So the control is not apparaent
  and so the PE really is always accepting inputs and computing.

  Since the address counter for each PE is controlled we can just take the coefficient `h` in
  without logic.  But it seems like it won't cost me too much to just zero out the outputs (unless
  the axis valid signal has long routing nets.
*/

module xpm_pe #(
  parameter FFT_LEN=64,
  parameter DEC_FAC=48,
  parameter LOOPBUF_MEM_TYPE="auto",
  parameter DATABUF_MEM_TYPE="auto",
  parameter SUMBUF_MEM_TYPE="auto",
  parameter branch_taps_t TAPS
) (
  input wire logic clk,
  input wire logic rst,

  input wire coeff_pkt_t h,

  alpaca_data_pkt_axis.SLV s_axis_data,
  alpaca_data_pkt_axis.MST m_axis_data,

  alpaca_data_pkt_axis.SLV s_axis_sum, //tuser=vin, expecting TUSER WIDTH to be 1
  alpaca_data_pkt_axis.MST m_axis_sum  //tuser=vout
);
typedef s_axis_data.data_pkt_t data_pkt_t;
localparam samp_per_clk = s_axis_data.samp_per_clk;

localparam M_D = FFT_LEN-DEC_FAC;

// connection signals
alpaca_data_pkt_axis #(
  .dtype(sample_t),
  .SAMP_PER_CLK(samp_per_clk),
  .TUSER(1)
) s_axis_loopbuf(), m_axis_loopbuf(), axis_sumbuf(), axis_databuf();
// tusers not driven on loopbuf interfaces vivado synthesis should complain
// tuser in the sumbuf interface represents valid in (vin)

// MAC operation signals
fir_pkt_t a;
fir_pkt_t mac;
coeff_pkt_t hin;
fir_pkt_t din;
fir_pkt_t sin;
fir_pkt_t loopbuf_out;

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

  //hin = s_axis_sum.tvalid ? h : '0; // zero coeff to zero mult-acc
  hin = h; // could safely do this if needed for efficiency, otherwise could provide zero outputs
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
// may want the convergent round to be its own block to support dynamic scaling
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
