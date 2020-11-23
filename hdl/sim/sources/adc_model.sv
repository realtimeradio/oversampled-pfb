`timescale 1ns/1ps
`default_nettype none

import alpaca_dtypes_pkg::*;

// when converting to parallel samples per clock the ability to do real samples only was removed
// for simplicity as sto just have something that worked. It would be possible to add that back
// if needed.

module adc_model #(
  parameter real PERIOD=10,
  parameter string DTYPE="CX",      // real or complex valued
  parameter real F_SOI_NORM=0.27,   // normalized frequency to generate SOI, [0 <= fnorm < 1]
  parameter real VCM=1.27,          // Voltage common mode [V]
  parameter real FSV=1.00,          // Full-scale voltage  [V]
  parameter real GAIN=1.0,
  parameter int BITS=12,
  parameter int SIGMA_BIT=6
) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,  // to model another mechanism to mark rfdc data as valid
  alpaca_data_pkt_axis.MST m_axis
);
  typedef m_axis.data_t axis_t;
  typedef logic signed [BITS-1:0] adc_t;

  localparam int samp_per_clk = m_axis.samp_per_clk;
  localparam int width = $bits(axis_t)/2; // right now, adc m_axis is a cx_t

  // MSB align the to the AXI width to model RFDC
  localparam int MSB_ALIGN = width-BITS;
  
  localparam real PI = 3.14159265358979323846264338327950288;
  localparam real VPK = FSV/2;                   // peak voltage
  localparam real adc_scale = FSV/(2**(BITS-1)); // [volts / bit]

  localparam real max_val = 2**(BITS-1)-1;
  localparam real min_val = -2**(BITS-1);

  localparam real ADC_PERIOD = PERIOD/samp_per_clk;
  localparam real F_SAMP = 1/ADC_PERIOD;
  localparam real argf = 2.0*PI*(F_SOI_NORM*F_SAMP);

  // show some info
  initial begin
    $display("adc bits=%0d, axi bits=%0d, shift=%0d", BITS, width, MSB_ALIGN);
    $display("max_val=%0f, min_val=%0f", max_val, min_val);
  end

  real vi [samp_per_clk-1:0];
  real tmpscale [samp_per_clk-1:0];
  integer tmp [samp_per_clk-1:0];
  adc_t adc_re[samp_per_clk-1:0];
  axis_t axis_re[samp_per_clk-1:0];

  real vq [samp_per_clk-1:0];
  real tmpscale_q [samp_per_clk-1:0];
  integer tmp_q [samp_per_clk-1:0];
  adc_t adc_im[samp_per_clk-1:0];
  axis_t axis_im[samp_per_clk-1:0];

  // QUESTA SIM BUG
  //typedef m_axis.data_pkt_t data_pkt_t;
  //data_pkt_t dout;
  //assign dout[0][15:0] = 16'hbeef;
  //assign dout[0][31:16] = 16'hdead;
  //assign dout[1].re = 16'hbeef;
  //assign dout[1].im = 16'hdead;

  alpaca_data_pkt_axis #(
    .dtype(adc_t),
    .SAMP_PER_CLK(SAMP_PER_CLK),
    .TUSER(1)
  ) awgn_axis_re[SAMP_PER_CLK](), awgn_axis_im[SAMP_PER_CLK]();

  adc_t noise [samp_per_clk-1:0];
  adc_t noise_q [samp_per_clk-1:0];

  genvar ii;
  generate
  for (ii=0; ii<samp_per_clk; ii++) begin
    always_ff @(posedge clk) begin
      vi[ii] <= GAIN*$cos(argf*($time+(ADC_PERIOD*ii)));
      vq[ii] <= GAIN*$sin(argf*($time+(ADC_PERIOD*ii)));
    end
  end

  for (ii=0; ii<samp_per_clk; ii++) begin
    awgn #(
      .SEED(ii+1),
      .SIGMA_BIT(SIGMA_BIT),
      .BITS(BITS)
    ) awgn_inst_re (
      .clk(clk),
      .rst(rst),
      .m_axis(awgn_axis_re[ii])
    );

    awgn #(
      .SEED((ii+1)*10),
      .SIGMA_BIT(SIGMA_BIT),
      .BITS(BITS)
    ) awgn_inst_im (
      .clk(clk),
      .rst(rst),
      .m_axis(awgn_axis_im[ii])
    );

    assign noise[ii] = awgn_axis_re[ii].tdata;
    assign noise_q[ii] = awgn_axis_im[ii].tdata;
  end

  for (ii=0; ii<samp_per_clk; ii++) begin
    always_comb begin
      // compute real part
      // scale
      tmpscale[ii] = vi[ii]/adc_scale;
      tmpscale[ii] = tmpscale[ii] + noise[ii]; // right place to do this
      // saturate
      if (tmpscale[ii] > max_val)
        tmpscale[ii] = max_val;
      if (tmpscale[ii] < min_val)
        tmpscale[ii] = min_val;

      //round
      tmp[ii] = int'(tmpscale[ii]); // LRM 1800-2017 states casting will round, conversion with rtoi truncates

      // intermediate assignment to an adc width word, shift up to match rfdc and assign out
      adc_re[ii] = tmp[ii];
      axis_re[ii] = adc_re[ii] <<< MSB_ALIGN;
      m_axis.tdata[ii].re = axis_re[ii];

      // compute imaginary part
      // scale
      tmpscale_q[ii] = vq[ii]/adc_scale;
      tmpscale_q[ii] = tmpscale_q[ii] + noise_q[ii];
      // saturate
      if (tmpscale_q[ii] > max_val)
        tmpscale_q[ii] = max_val;
      if (tmpscale_q[ii] < min_val)
        tmpscale_q[ii] = min_val;

      //round
      tmp_q[ii] = int'(tmpscale_q[ii]); // LRM 1800-2017 states casting will round, conversion with rtoi truncates

      // intermediate assignment to an adc width word, shift up to match rfdc and assign out
      adc_im[ii] = tmp_q[ii];
      axis_im[ii] = adc_im[ii] <<< MSB_ALIGN;
      m_axis.tdata[ii].im = axis_im[ii];
    end
  end
  endgenerate

  assign m_axis.tvalid = ~rst & en;
endmodule

/**************************************************
  TOP
***************************************************/

module adc_top #(
  parameter int PERIOD=10,
  parameter int SAMP_PER_CLK=2,
  parameter int SAMPLES=128,
  parameter int BITS=8,
  parameter real F_SOI_NORM=0.27,
  parameter real GAIN=1.0,
  parameter int SIGMA_BIT=3
) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,
  output wire vip_full
);

  localparam MEM_DEPTH = SAMPLES/SAMP_PER_CLK;

  alpaca_data_pkt_axis #(
    .dtype(cx_t),
    .SAMP_PER_CLK(SAMP_PER_CLK),
    .TUSER(1)
  ) m_axis();

  adc_model #(
    .PERIOD(PERIOD),
    .BITS(BITS),
    .F_SOI_NORM(F_SOI_NORM),
    .GAIN(GAIN),
    .SIGMA_BIT(SIGMA_BIT)
  ) adc_inst (.*);

  parallel_axis_vip #(.DEPTH(MEM_DEPTH)) vip_inst (.*, .s_axis(m_axis), .full(vip_full));

endmodule : adc_top

/**************************************************
  ADC model test bench
***************************************************/
import alpaca_constants_pkg::*;
parameter int SAMPLES = 4096 ;

module adc_test();

  logic clk, rst, en;
  logic vip_full;

  clk_generator #(.PERIOD(PERIOD)) clk_gen_inst (.*);

  adc_top #(
    .PERIOD(PERIOD),
    .SAMP_PER_CLK(SAMP_PER_CLK),
    .SAMPLES(SAMPLES),
    .BITS(ADC_BITS),
    .F_SOI_NORM(F_SOI_NORM),
    .GAIN(ADC_GAIN),
    .SIGMA_BIT(SIGMA_BIT)
  ) DUT (.*);

  task wait_cycles(input int cycles);
    repeat(cycles)
      @(posedge clk);
  endtask

  // main
  initial begin
    rst <= 1;
    @(posedge clk);
    @(negedge clk); rst = 0; en = 1;

    while (~vip_full)
      wait_cycles(1);

    // write capture contents for processing
    //$writememh("adc_capture_hex.txt", DUT.vip_inst.ram);
    $writememb("adc_capture_bin.txt", DUT.vip_inst.ram);

    $finish;
  end

endmodule : adc_test



