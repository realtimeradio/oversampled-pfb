`timescale 1ns/1ps
`default_nettype none

module adc_model #(
  parameter real PERIOD = 10,
  parameter string DTYPE = "CX",             // real or complex valued
  parameter real F_SOI_NORM = 0.73,   // normalized frequency to generate SOI, [0 <= fnorm < 1]
  parameter real VCM = 1.27,          // Voltage common mode [V]
  parameter real FSV = 1.00,          // Full-scale voltage  [V]
  parameter int BITS = 12,
  parameter int TWID = 16
) (
  input wire logic clk,
  input wire rst,
  input wire en,
  axis.MST m_axis
);

  localparam real PI = 3.14159265358979323846264338327950288;
  localparam real VPK = FSV/2;                   // peak voltage
  localparam real lsb_weight = FSV/(2**BITS);    // LSB
  localparam real adc_scale = FSV/(2**(BITS-1)); // [volts / bit]
  localparam real bit_width = (2**BITS)/2;       // half bits range

  localparam real F_SAMP = 1/PERIOD;
  localparam real argf = 2.0*PI*(F_SOI_NORM*F_SAMP);

  real vi;
  real tmpscale;
  //logic signed [63:0] tmp;
  integer tmp;

  logic signed [TWID-1:0] dout;

  always_ff @(posedge clk)
    if (rst)
      vi <= '0;
    else
      vi <= $cos(argf*$time);

  always_comb begin
    //tmp = $realtobits(v-bit_width)*(in_scale_lsb);
    tmpscale = vi/adc_scale;
    tmp = $rtoi(vi/adc_scale);
    dout = tmp;//{{(TWID-BITS){1'b0}}, tmp[63:(63-BITS+1)]};
    // TODO: need to round...
  end

generate
  if (DTYPE == "CX") begin
    real vq;
    real tmpscale_q;
    //logic signed [63:0] tmp;
    integer tmp_q;

    logic signed [TWID-1:0] dout_q;

    always_ff @(posedge clk)
      if (rst)
        vq <= '0;
      else
        vq <= $sin(argf*$time);

    always_comb begin
      //tmp = $realtobits(vq-bit_width)*(in_scale_lsb);
      tmpscale_q = vq/adc_scale;
      tmp_q = $rtoi(vq/adc_scale);
      dout_q = tmp_q;//{{(TWID-BITS){1'b0}}, tmp[63:(63-BITS+1)]};
      // TODO: need to round...
    end

    assign m_axis.tdata = {dout_q, dout};

  end else begin
    assign m_axis.tdata = dout;

  end
endgenerate

    assign m_axis.tvalid = ~rst & en;
endmodule

/*
  ADC model test bench
*/
parameter PERIOD = 10;
parameter TDATA = 16;

module adc_test;

logic clk, rst;

axis #(.WIDTH(2*TDATA)) mst();

adc_model #(
  .PERIOD(PERIOD),
  .TWID(TDATA),
  .DTYPE("CX")
) DUT (.clk(clk), .rst(rst), .m_axis(mst));

initial begin
  clk <= 0;
  forever #(PERIOD/2)
    clk = ~clk;
end

task wait_cycles(input int cycles);
  repeat(cycles)
    @(posedge clk);
endtask

parameter SAMPLES = 128;

initial begin
  // create file to dump data
  int fp;
  logic signed [2*TDATA-1:0] samps [SAMPLES];

  fp = $fopen("adc_data.bin", "wb");
  if (!fp) begin
    $display("could not create file...");
    $finish;
  end

  rst <= 1;
  @(posedge clk);
  @(negedge clk); rst = 0; mst.tready = 1;

  for (int i=0; i < SAMPLES; i++) begin
    wait_cycles(1);
    $display(mst.print());
    samps[i] = mst.tdata;
  end

  // write formatted binary
  for (int i=0; i < SAMPLES; i++) begin
    //$display("%0d, %0d", samps[i][31:16], samps[i][15:0]);
    //$fwrite(fp, "%c%c", samps[i][15:8], samps[i][7:0]);
    $fwrite(fp, "%u", samps[i]); // writes 4 bytes in native endian format
  end

  // write as a memory file
  //$writememh("adc_hex.bin", samps);
  //$writememb("adc_bin.bin", samps);

  $finish;
end

endmodule



