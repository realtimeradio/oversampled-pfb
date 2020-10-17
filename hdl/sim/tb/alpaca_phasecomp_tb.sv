`timescale 1ns/1ps
`default_nettype none

import alpaca_constants_pkg::*;
import alpaca_sim_constants_pkg::*;
import alpaca_dtypes_pkg::*;

module alpaca_phasecomp_top #(
  parameter int FFT_LEN=32,
  parameter int DEC_FAC=24,
  parameter int SAMP_PER_CLK=2
) (
  input wire logic clk,
  input wire logic rst,
  alpaca_data_pkt_axis.MST m_axis
);

alpaca_data_pkt_axis #(.dtype(sample_t), .SAMP_PER_CLK(SAMP_PER_CLK), .TUSER(1)) s_axis();

impulse_generator6 #(
  .FFT_LEN(FFT_LEN),
  .IMPULSE_PHA(0),
  .IMPULSE_VAL(256)
) impulse_gen_inst (
  .clk(clk),
  .rst(rst),
  .m_axis(s_axis)
);

alpaca_phasecomp #(.DEPTH(2*FFT_LEN), .DEC_FAC(DEC_FAC)) phasecomp_inst (.*);

endmodule : alpaca_phasecomp_top

// TESTBENCH
parameter int TB_FFT_LEN = 8;
parameter int TB_DEC_FAC = 6;
parameter int TB_SAMP_PER_CLK = 1;

parameter int FRAMES = 4;
module alpaca_phasecomp_tb();

logic clk, rst;
alpaca_data_pkt_axis #(.dtype(sample_t), .SAMP_PER_CLK(TB_SAMP_PER_CLK), .TUSER(1)) m_axis();

clk_generator #(.PERIOD(ADC_PERIOD)) clk_gen_inst (.*);
alpaca_phasecomp_top #(
  .FFT_LEN(TB_FFT_LEN),
  .DEC_FAC(TB_DEC_FAC),
  .SAMP_PER_CLK(TB_SAMP_PER_CLK)
) DUT (.*);

task wait_cycles(input int cycles=1);
  repeat (cycles)
    @(posedge clk);
endtask

// main initial
initial begin
  virtual alpaca_data_pkt_axis #(.dtype(sample_t), .SAMP_PER_CLK(TB_SAMP_PER_CLK), .TUSER(1)) s_axis;

  $display("Source ram contents");
  for (int i=0; i<TB_FFT_LEN/TB_SAMP_PER_CLK; i++) begin
    $display("(ram: 0x%0p", DUT.impulse_gen_inst.ram[i]);
  end
 $display("");

  s_axis = DUT.s_axis;
  rst <= 1;
  wait_cycles(3);
  @(posedge clk);
  @(negedge clk); rst=0;

  @(posedge m_axis.tvalid);

  for (int j=0; j<FRAMES; j++) begin
    $display("FRAME %0d:", j);
    for (int i=0; i<TB_FFT_LEN; i++) begin
      wait_cycles();
      $display({"in : ", s_axis.print()});
      $display({"out: ", m_axis.print(), "\n"});
    end
  end

  $finish;
end

endmodule : alpaca_phasecomp_tb
