`timescale 1ns/1ps
`default_nettype none

import alpaca_ospfb_monitor_pkg::*;
import alpaca_ospfb_utils_pkg::*;

// TODO: I am not liking SRLEN and DEPTH being thrown around... starting to cause errors
// and confusion... 
parameter DEPTH = FFT_LEN;
parameter NUM = DEPTH/SRLEN-1;

module delaybuf_tb();

logic clk, rst, en;
logic [WIDTH-1:0] din, dout;

delayline_ix #(.WIDTH(WIDTH)) dix(.clk(clk)); 

DelayBuf #(
  .DEPTH(DEPTH),
  .SRLEN(SRLEN),
  .WIDTH(WIDTH)
) DUT (.clk(clk),
       .rst(dix.rst),
       .en(dix.en),
       .din(dix.din),
       .dout(dix.dout)
);

// bind to DUTs
BindFiles bf();

parameter string cycfmt = $psprintf("%%%0d%0s",4, "d");
parameter string binfmt = $psprintf("%%%0d%0s",1, "b");
parameter string datfmt = $psprintf("%%%0d%0s",WIDTH, "X");
parameter string regfmt = $psprintf("%%%0d%0s",SRLEN, "X");
parameter string hedfmt = $psprintf("%%%0d%0s",1, "X");

task wait_cycles(input int cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

// start clk and cycle counter
int simcycles;
initial begin
  clk <= 0; simcycles=0;
  forever #(PERIOD/2) begin
    clk = ~clk;
    simcycles += (1 & clk);
  end
end

sr_probe_t sr_h[NUM];
genvar mm;
generate
  for (mm=0; mm < NUM; mm++) begin
    initial begin
      sr_h[mm] = DUT.gen_delay.sr[mm].probe.monitor;
    end
  end
endgenerate

string vstr = "%sCycle=%4d: {expected: 0x%04X, observed: 0x%04X}%s\n";
initial begin
  Source src;
  Source sink;
  DelayBufMonitor #(.DEPTH(DEPTH), .SRLEN(SRLEN)) m;

  int errors;
  logic [WIDTH-1:0] truth;

  src = new(DEPTH);
  sink = new(DEPTH);
  m = new(DUT.probe.monitor, DUT.headSR.probe.monitor, sr_h);

  errors = 0;

  $display("Cycle=%4d: **** Starting PE_ShiftReg test bench ****", simcycles);
  $display("NUM=%0d", NUM);

  // reset circuit
  dix.rst <= 1; dix.din <= src.createSample();
  @(posedge clk);
  @(negedge clk) dix.rst = 0; dix.en = 1;

  $display("Cycle=%4d: Finished init...", simcycles);
  m.print_reg();
  // DEPTH-1 gets us to the DEPTH cycle when the first sample should be on its way out (right?)
  for (int i=0; i < DEPTH-1; i++) begin
    wait_cycles(1);
    #(1ns); // move off edge to monitor (or is it really we move off to drive)?
    m.print_reg();
    dix.din = src.createSample();
  end

  $display("Cycle=%4d: beginning to verify results...", simcycles);
  // from here the sink should produce the same samples as we read out
  for (int i=0; i < 2*DEPTH; i++) begin
    wait_cycles(1);
    #(1ns);
    m.print_reg();
    dix.din = src.createSample();
    truth = sink.createSample();
    if (truth != dix.dout) begin
      errors++;
      $display(vstr, RED, simcycles, truth, dix.dout, RST);
    end else begin
      $display(vstr, GRN, simcycles, truth, dix.dout, RST);
    end
  end

  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;
end

endmodule


