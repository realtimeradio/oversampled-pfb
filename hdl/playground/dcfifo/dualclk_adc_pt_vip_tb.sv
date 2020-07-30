`timescale 1ns/1ps // NOTE: may need finer time scale for simulations such as 27/32 
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

parameter int SAMP = 256; //FFT_LEN;  // number of samples to capture in the vip

parameter int FIFO_DEPTH = 32; // Minimum depth is 16
parameter int PROG_EMPTY_THRESH = 16;
parameter int PROG_FULL_THRESH = 16;

/*
  Testbench to analyze to verify that once started the FIFO will never become empty.

  The DUT has a passthrough module that imitates the front end logic of the ospfb to simulate
  the resampling periods when data cannot be accepted on the input. The goal was to show that the
  FIFO once started would never become empty and that this structure accurately implements the up
  sampling required by the ospfb with the correct clock domain crossing handshake.

  It was shown that the FIFO does not go empty. However, there is still a major concern that
  this is practical. With this testbench it shows that it can be achieved in simulation. But
  notice that just prior to the beginning of the resample period that the almost empty flag is
  present showing that there is only one sample left in the FIFO.

  The practical concern is that in order to gurantee that the FIFO will never be empty the DSP
  clock must be able to be created EXACTLY from the ADC clock at the oversample ratio. If there is
  any skew (slow or fast) this may eventually cause the clocks to drift apart. In the case that
  the DSP clock is slightly faster than the perfect ratio the FIFO will be emptied after a
  certain number of iterations. In the case that the DSP is slightly slower then the FIFO will
  eventually fill up. Of the two scenarios the better one would be to have a slightly slower
  clock with a really deep fifo in hopes that the system can be restarted.
*/

module dualclk_adc_pt_vip_tb();

logic adc_clk, dsp_clk, rst, adc_en;
logic vip_full, almost_empty, almost_full, prog_empty, prog_full;
logic [$clog2(FIFO_DEPTH)-1:0] rd_count, wr_count;

//dualclk_adc_pt_vip_top #(
//  .PERIOD(ADC_PERIOD),
//  .SAMP(SAMP),
//  .FFT_LEN(FFT_LEN),
//  .DEC_FAC(DEC_FAC),
//  .SRT_PHA(DEC_FAC-1),
//  .TDATA_WIDTH(WIDTH),
//  .FIFO_DEPTH(FIFO_DEPTH),
//  .PROG_EMPTY_THRESH(PROG_EMPTY_THRESH),
//  .PROG_FULL_THRESH(PROG_FULL_THRESH)
//) DUT (
//  .clka(adc_clk),
//  .clkb(dsp_clk),
//  .rst(rst),
//  .adc_en(adc_en),
//  .vip_full(vip_full),
//
//  // examining axis fifo signals
//  .almost_empty_axis(almost_empty),
//  .almost_full_axis(almost_full),
//  .prog_empty_axis(prog_empty),
//  .prog_full_axis(prog_full),
//  .rd_data_count_axis(rd_count),
//  .wr_data_count_axis(wr_count)
//);

dualclk_adc_vip_top #(
  .PERIOD(ADC_PERIOD),
  .SAMP(SAMP),
  .TDATA_WIDTH(WIDTH),
  .FIFO_DEPTH(FIFO_DEPTH),
  .PROG_EMPTY_THRESH(PROG_EMPTY_THRESH),
  .PROG_FULL_THRESH(PROG_FULL_THRESH)
) DUT (
  .clka(adc_clk),
  .clkb(dsp_clk),
  .rst(rst),
  .adc_en(adc_en),
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
    @(posedge dsp_clk);
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
    @(negedge adc_clk); rst = 0; adc_en = 1;

    // wait until we have captured the required number of frames
    // note: not using axis tlast, could possibly use that instead of a full signal
    while (~vip_full) begin
      wait_dsp_cycles(1);
    end

    // write formatted binary
    for (int i=0; i < SAMP; i++) begin
      $fwrite(fp, "%u", DUT.vip_inst.ram[i]); // writes 4 bytes in native endian format
    end
    $fclose(fp);


    $finish;
  end


endmodule
