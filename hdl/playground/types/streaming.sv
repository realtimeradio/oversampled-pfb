`timescale 1ns/1ps

module bit_reverse #(
  parameter WIDTH=3
) (
  input wire logic clk,
  input wire logic rst,
  input wire logic [WIDTH-1:0] k,
  output logic [WIDTH-1:0] kr
);

always_ff @(posedge clk)
  if (rst)
    kr <= '0;
  else
    kr <= { << {k}};

endmodule

parameter PERIOD = 10;
parameter FFT_LEN = 8;

module stream_tb();

logic clk, rst;
logic [$clog2(FFT_LEN)-1:0] k;
logic [$clog2(FFT_LEN)-1:0] kr;

clk_generator #(.PERIOD(PERIOD)) clk_gen_inst (.*);

bit_reverse #(.WIDTH($clog2(FFT_LEN))) DUT (.*);

task wait_cycles(input cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

initial begin
  
  rst <= 0; k <= 0;
  @(posedge clk);
  @(negedge clk); rst = 0;

  wait_cycles(1);
  for (int i=0; i<2*FFT_LEN; i++) begin
    $display("(k: 0x%0X, kr: 0x%0X)", k, kr);
    @(negedge clk);
    k = k+1;
    wait_cycles(1);
  end
  $finish; 

  //for (int i=0; i<FFT_LEN; i++) begin
  //k = i;
  //kr = { << {k}};
  //$display("(k: 0x%0X, kr: 0x%0X)", k, kr);
  //end
end

endmodule
