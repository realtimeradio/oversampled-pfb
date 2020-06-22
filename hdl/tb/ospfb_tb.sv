`timescale 1ns/1ps
`default_nettype none

// TODO: we are now in OSPFB territory meaning we will want some sort of better simulation with
// clock domain crossing by having two clocks generating and processing data

import alpaca_ospfb_utils_pkg::*;

parameter PERIOD = 10;

parameter WIDTH = 16;

parameter FFT_LEN = 32;
parameter DEC_FAC = 24;
parameter PTAPS = 3;
parameter COEFF_WID = 16;

parameter SRLEN = 8;
parameter string binfmt = $psprintf("%%%0d%0s",1, "b");
parameter string datfmt = $psprintf("%%%0d%0s",WIDTH, "X");
parameter string regfmt = $psprintf("%%%0d%0s",SRLEN, "X");
parameter string hedfmt = $psprintf("%%%0d%0s",1, "X");


// TODO: should we take the monitor from delaybuf_tb and call that DelayBuf_Monitor and then
// create a PE_monitor that contains the 4 DelayBuf_Monitors?

// TODO: The names on these are not very descriptive or helpful probably should start to clean
// them up.
// typedef virtual delayline_ix #(.WIDTH(WIDTH)) dbX_t;
// typedef virtual srif #(.DEPTH(SRLEN-1), .WIDTH(WIDTH)) headX_t;
// typedef virtual srif #(.DEPTH(SRLEN), .WIDTH(WIDTH)) srX_t;
// typedef virtual srif #(.DEPTH(DEPTH), .WIDTH(WIDTH)) reX_t;

module ospfb_tb();

logic clk, rst, en;
logic [WIDTH-1:0] din, dout;

axis #(.WIDTH(WIDTH)) mst(), slv();

OSPFB #(
  .WIDTH(WIDTH),
  .COEFF_WID(COEFF_WID),
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .PTAPS(PTAPS),
  .SRLEN(SRLEN)
) DUT (
  .clk(clk),
  .rst(rst),
  .en(en),
  .m_axis(mst),
  .s_axis(slv)
);

bind SRLShiftReg srif #(
                    .DEPTH(DEPTH),
                    .WIDTH(WIDTH)
                 ) ifsr (.sr(shiftReg), .clk);

bind DelayBuf srif #(
                  .DEPTH(DEPTH),
                  .WIDTH(WIDTH)
              ) dbif (.hr(headReg), .clk);

task wait_cycles(input int cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

int simcycles;
initial begin
  clk <= 0; simcycles=0;
  forever #(PERIOD/2) begin
    clk = ~clk;
    simcycles += (1 & clk);
  end
end

initial begin
  Source src;
  int errors;

  src = new(FFT_LEN);
  errors = 0;

  $display("Cycle=%4d: **** Starting OSPFB test bench ****", simcycles);
  // reset circuit
  rst <= 1; din <= src.createSample();
  @(posedge clk);
  @(negedge clk) rst = 0; en = 1;

  $display("Cycle=%4d: Finished init...", simcycles);
  wait_cycles(1);

  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;

end

endmodule
