`timescale 1ns/1ps
`default_nettype none

module adc_model #(
  parameter F_SAMP = 2.048, // [Gsps]
  parameter F_SOI = 0.512,  // [GHz]
  parameter VCM = 1.27,     // Voltage common mode [V]
  parameter FSV = 1.00,     // Full-scale voltage  [V]
  parameter BITS = 12,
  parameter TWID = 16
) (
  input wire logic clk,
  input wire rst,
  output logic signed [TWID-1:0] dout
);

  localparam PI = 3.14159265358979323846264338327950288;
  localparam VPK = FSV/2;                   // peak voltage
  localparam lsb_weight = FSV/(2**BITS);    // LSB
  localparam adc_scale = FSV/(2**(BITS-1)); // [volts / bit]
  localparam bit_width = (2**BITS)/2;       // half bits range

  real v;
  real tmpscale;
  //logic signed [63:0] tmp;
  integer tmp;

  always_ff @(posedge clk)
    if (rst)
      v <= '0;
    else
      v <= $cos(2.0*PI*F_SOI*$time);

  always_comb begin
    //tmp = $realtobits(v-bit_width)*(in_scale_lsb);
    tmpscale = v/adc_scale;
    tmp = $rtoi(v/adc_scale);
    dout = tmp;//{{(TWID-BITS){1'b0}}, tmp[63:(63-BITS+1)]};
    // TODO: need to round...
  end

endmodule

/*
  ADC model test bench
*/
parameter PERIOD = 10;
parameter TDATA = 16;

module adc_test;

logic clk, rst;
logic signed [TDATA-1:0] dout;

adc_model DUT (.clk(clk), .rst(rst), .dout(dout));

initial begin
  clk <= 0;
  forever #(PERIOD/2)
    clk = ~clk;
end

task wait_cycles(input int cycles);
  repeat(cycles)
    @(posedge clk);
endtask

initial begin
  rst <= 1;
  @(posedge clk);
  @(negedge clk); rst = 0;

  for (int i=0; i < 128; i++) begin
    wait_cycles(1);
    #1ns;
    $display(dout);
  end

  $finish;
end

endmodule



