
`timescale 1ns/1ps
`default_nettype none


module awgn (
  input wire logic clk,
  output logic [31:0] n
);

always_ff @(posedge clk)
  n <= $dist_normal($urandom(), 10, 4);

endmodule


module test;

  parameter PERIOD=10;

  logic clk;
  logic [31:0] n;

  task wait_cycles(int cycle);
    repeat (cycle)
      @(posedge clk);
  endtask

  initial begin
    clk <=0;
    forever #(PERIOD/2) begin
      clk = ~clk;
    end
  end

  awgn DUT(.*);

  initial begin
    string s;
    for (int i=0; i < 20; i++) begin
      wait_cycles(1);
      #1;
      s = {$psprintf("%04d",n), s};
    end
    $display(s);
    $finish;
  end



endmodule


