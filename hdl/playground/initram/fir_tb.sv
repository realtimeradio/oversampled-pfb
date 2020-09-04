`timescale 1ns/1ps
`default_nettype none

/*
*/
parameter PERIOD = 10;
parameter WIDTH = 16;
parameter NTAPS = 8;

module fir_test();

logic clk, rst;

axis #(.WIDTH(WIDTH)) s_axis_data(), s_axis_sum(), m_axis_data(), m_axis_sum();

top_fir DUT (
  .clk(clk),
  .rst(rst),
  .s_axis_data_tdata(s_axis_data.tdata),
  .s_axis_data_tvalid(s_axis_data.tvalid),
  .s_axis_data_tready(s_axis_data.tready),
  .s_axis_sum_tdata(s_axis_sum.tdata),
  .s_axis_sum_tvalid(s_axis_sum.tvalid),
  .s_axis_sum_tready(s_axis_sum.tready),
  .m_axis_data_tdata(m_axis_data.tdata),
  .m_axis_data_tvalid(m_axis_data.tvalid),
  .m_axis_data_tready(m_axis_data.tready),
  .m_axis_sum_tdata(m_axis_sum.tdata),
  .m_axis_sum_tvalid(m_axis_sum.tvalid),
  .m_axis_sum_tready(m_axis_sum.tready)
);

initial begin
  clk <= 0;
  forever #(PERIOD/2) clk = ~clk;
end

initial begin
  rst <= 1;
  @(posedge clk);
  @(negedge clk); rst = 0;

  @(posedge clk);
  $display("TESTBENCH TAPS");
  $display("PE0");
  for (int i = 0; i < NTAPS; i++) begin
    $display("0x%0X", DUT.gen_pe[0].pe.coeff_ram[i]);
  end
  $display("PE1");
  for (int i = 0; i < NTAPS; i++) begin
    $display("0x%0X", DUT.gen_pe[1].pe.coeff_ram[i]);
  end
  $display("PE2");
  for (int i = 0; i < NTAPS; i++) begin
    $display("0x%0X", DUT.gen_pe[2].pe.coeff_ram[i]);
  end
  $display("PE3");
  for (int i = 0; i < NTAPS; i++) begin
    $display("0x%0X", DUT.gen_pe[3].pe.coeff_ram[i]);
  end
  $finish;
end
  
  
endmodule
