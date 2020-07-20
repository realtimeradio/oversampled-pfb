`timescale 1ns/1ps
`default_nettype none

parameter PERIOD = 10;
parameter WIDTH = 16;

/*
  Simple ADC module with FFT testbench
*/
module testbench;

logic clk, rst, en;
axis #(.WIDTH(2*WIDTH)) m_axis();

logic event_frame_started;
logic event_tlast_unexpected;
logic event_tlast_missing;
logic event_data_in_channel_halt;
logic vip_full;

top #(
  .WIDTH(WIDTH)
) DUT (
  .clk(clk),
  .rst(rst),
  .en(en),
  .event_frame_started(event_frame_started),
  .event_tlast_unexpected(event_tlast_unexpected),
  .event_tlast_missing(event_tlast_missing),
  .event_data_in_channel_halt(event_data_in_channel_halt),
  .vip_full(vip_full)
);

task wait_cycles(int cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

int simcycles;
initial begin
  clk <= 0; simcycles = 0;
  forever #(PERIOD/2) begin
    clk = ~clk;
    simcycles += (1 & clk) & ~rst;
  end
end

parameter SAMPLES = 32;
logic signed [2*WIDTH-1:0] samps [SAMPLES];
int i;
task capture;
  i=0;
  fork
    forever begin
      @(posedge clk);
      if (m_axis.tvalid) begin
        samps[i++] <= m_axis.tdata;
      end
    end
  join_none
endtask
    
    

// main block
initial begin

  // create file to dump data
  int fp;
  fp = $fopen("fft_data.bin", "wb");
  if (!fp) begin
    $display("could not create file...");
    $finish;
  end

  // reset and initialize hardware 
  rst <= 1; en <= 0;
  wait_cycles(10); // fft reset requires at least 2 cycles
  @(posedge clk);
  @(negedge clk); rst = 0; en = 1; m_axis.tready = 1;

  // wait until we have captured the required number of frames
  // note: not using axis tlast, could possibly use that instead of a full signal
  while (~vip_full) begin
    wait_cycles(1);
  end

  // write formatted binary
  for (int i=0; i < SAMPLES; i++) begin
    $fwrite(fp, "%u", DUT.vip_inst.ram[i]); // writes 4 bytes in native endian format
  end


  $finish;
end

endmodule


