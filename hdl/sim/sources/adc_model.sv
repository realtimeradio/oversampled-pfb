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
  parameter int BITS=12
) (
  input wire logic clk,
  input wire rst,
  input wire en,
  alpaca_data_pkt_axis.MST m_axis
);
  localparam int samp_per_clk = m_axis.samp_per_clk;

  localparam real PI = 3.14159265358979323846264338327950288;
  localparam real VPK = FSV/2;                   // peak voltage
  localparam real lsb_weight = FSV/(2**BITS);    // LSB
  localparam real adc_scale = FSV/(2**(BITS-1)); // [volts / bit]
  localparam real bit_width = (2**BITS)/2;       // half bits range

  localparam real ADC_PERIOD = PERIOD/samp_per_clk;
  localparam real F_SAMP = 1/ADC_PERIOD;
  localparam real argf = 2.0*PI*(F_SOI_NORM*F_SAMP);

  real vi [samp_per_clk-1:0];
  real tmpscale [samp_per_clk-1:0];
  integer tmp [samp_per_clk-1:0];

  real vq [samp_per_clk-1:0];
  real tmpscale_q [samp_per_clk-1:0];
  integer tmp_q [samp_per_clk-1:0];

  // QUESTA SIM BUG
  //typedef m_axis.data_pkt_t data_pkt_t;
  //data_pkt_t dout;
  //assign dout[0][15:0] = 16'hbeef;
  //assign dout[0][31:16] = 16'hdead;
  //assign dout[1].re = 16'hbeef;
  //assign dout[1].im = 16'hdead;

  genvar ii;
  generate
  for (ii=0; ii<samp_per_clk; ii++) begin
    always_ff @(posedge clk) begin
      vi[ii] <= GAIN*$cos(argf*($time+(ADC_PERIOD*ii)));
      vq[ii] <= GAIN*$sin(argf*($time+(ADC_PERIOD*ii)));
    end
  end

  for (ii=0; ii<samp_per_clk; ii++) begin
    always_comb begin
      //tmp = $realtobits(v-bit_width)*(in_scale_lsb);
      tmpscale[ii] = vi[ii]/adc_scale;
      tmp[ii] = $rtoi(vi[ii]/adc_scale);
      m_axis.tdata[ii].re = tmp[ii];
      // TODO: need to round...?

      //tmp = $realtobits(vq-bit_width)*(in_scale_lsb);
      tmpscale_q[ii] = vq[ii]/adc_scale;
      tmp_q[ii] = $rtoi(vq[ii]/adc_scale);
      m_axis.tdata[ii].im = tmp_q[ii];
      // TODO: need to round...?
    end
  end
  endgenerate

  //assign m_axis.tdata = dout;
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
  parameter real F_SOI_NORM=0.27
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

  adc_model #(.PERIOD(PERIOD), .BITS(BITS), .F_SOI_NORM(F_SOI_NORM)) adc_inst (.*);

  parallel_axis_vip #(.DEPTH(MEM_DEPTH)) vip_inst (.*, .s_axis(m_axis), .full(vip_full));

endmodule : adc_top

/**************************************************
  ADC model test bench
***************************************************/
parameter int PERIOD = 10;
parameter int ADC_BITS = 8;
parameter real F_SOI_NORM=0.08;//0.27;
parameter int SAMP_PER_CLK = 2;
parameter int SAMPLES = 128;

module adc_test();

  localparam real ADC_PERIOD = PERIOD/SAMP_PER_CLK;

  logic clk, rst, en;
  logic vip_full;

  clk_generator #(.PERIOD(PERIOD)) clk_gen_inst (.*);

  adc_top #(
    .PERIOD(PERIOD),
    .SAMP_PER_CLK(SAMP_PER_CLK),
    .SAMPLES(SAMPLES),
    .BITS(ADC_BITS),
    .F_SOI_NORM(F_SOI_NORM)
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



