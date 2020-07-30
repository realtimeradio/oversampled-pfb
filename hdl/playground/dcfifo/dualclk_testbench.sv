`timescale 1ns/1ps
`default_nettype none

parameter int  WIDTH = 16;

parameter int  FFT_LEN = 32;               // (M)   polyphase branches
parameter real OSRATIO = 3.0/4.0;          // oversampling ratio
                                           // (M/D) (dsp -> adc domain)
                                           // (D/M) (adc -> dsp domain)

parameter int  DEC_FAC = FFT_LEN*OSRATIO;  // (D)   decimation factor 

// determine ADC clk period given the DSP clk
parameter real ADC_PERIOD = 12;
parameter real DSP_PERIOD = OSRATIO*ADC_PERIOD;

parameter int FIFO_DEPTH = 128; // Minimum depth is 16
parameter int SAMP = FFT_LEN;

module dualclk_testbench();

logic adc_clk, dsp_clk, rst;
logic vip_full, almost_empty, almost_full, prog_empty, prog_full;
logic [$clog2(FIFO_DEPTH)-1:0] rd_count, wr_count;

dualclk_ctr_top #(
  .SAMP(SAMP),
  .TDATA_WIDTH(WIDTH),
  .FIFO_DEPTH(FIFO_DEPTH)
) DUT (
  .clka(adc_clk),
  .clkb(dsp_clk),
  .rst(rst),
  .vip_full(vip_full),

  // examining axis fifo signals
  .almost_empty_axis(almost_empty),
  .almost_full_axis(almost_full),
  .prog_empty_axis(prog_empty),
  .prog_full_axis(prog_full),
  .rd_data_count_axis(rd_count),
  .wr_data_count_axis(wr_count)
);

// DSP clock generator
int dsp_cycles;
initial begin
  dsp_clk <= 0; dsp_cycles=0;
  forever #(DSP_PERIOD/2) begin
    dsp_clk = ~dsp_clk;  
    dsp_cycles += (1 & dsp_clk) & ~rst;
  end
end

// ADC clock generator
int adc_cycles;
initial begin
  adc_clk <= 0; adc_cycles=0;
  forever #(ADC_PERIOD/2) begin
    adc_clk = ~adc_clk;  
    adc_cycles += (1 & adc_clk) & ~rst;
  end
end


// tasks to wait for a cycle in each clock domain

task wait_adc_cycles(int cycles=1);
  repeat(cycles)
    @(posedge adc_clk);
endtask

task wait_dsp_cycles(int cycles=1);
  repeat(cycles)
    @(posedge adc_clk);
endtask

// main block
initial begin

  // create file to dump data
    int fp;
    fp = $fopen("data_capture.bin", "wb");
    if (!fp) begin
      $display("could not create file...");
      $finish;
    end

    // reset and initialize hardware 
    rst <= 0;
    #100ns;
    rst <= 1;
    wait_adc_cycles(10);
    @(posedge adc_clk);
    @(negedge adc_clk); rst = 0;

    // wait until we have captured the required number of frames
    // note: not using axis tlast, could possibly use that instead of a full signal
    while (~vip_full) begin
      wait_dsp_cycles(1);
    end

    // write formatted binary
    for (int i=0; i < SAMP; i++) begin
      $fwrite(fp, "%u", DUT.vip_inst.ram[i]); // writes 4 bytes in native endian format
    end


    $finish;
  end


endmodule
