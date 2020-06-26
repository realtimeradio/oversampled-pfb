`timescale 1ns/1ps
`default_nettype none
/*
  TODO: we are now in OSPFB territory meaning we will want some sort of better simulation with
  clock domain crossing by having two clocks generating and processing data
*/

import alpaca_ospfb_monitor_pkg::*;
import alpaca_ospfb_utils_pkg::*;

parameter DEPTH = FFT_LEN;
parameter NUM = DEPTH/SRLEN - 1;
parameter LOOP_NUM = (FFT_LEN-DEC_FAC)/SRLEN - 1;
parameter DATA_NUM = 2*DEPTH/SRLEN-1;

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

BindFiles bf();

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


pe_t pe_h[PTAPS];
/*
  TODO: Why do I need the packed array? I know it has to do with references (pointers in a C
  sense) but why can I not use a single array to hold the reference to pass to the constructor.
  Instead to get the correct handle I needed to create a packed array to store all the handles
  at one time.
*/
sr_probe_t sr_sumbuf_h[PTAPS][NUM];
sr_probe_t sr_databuf_h[PTAPS][DATA_NUM];
sr_probe_t sr_loopbuf_h[PTAPS][LOOP_NUM];

genvar pp;
genvar mm;
generate
  for (pp=0; pp < PTAPS; pp++) begin
    for (mm=0; mm < NUM; mm++) begin
      initial begin
        sr_sumbuf_h[pp][mm] = DUT.fir.pe[pp].sumbuf.gen_delay.sr[mm].probe.monitor;
      end
    end

    for (mm=0; mm < DATA_NUM; mm++) begin
      initial begin
        sr_databuf_h[pp][mm] = DUT.fir.pe[pp].databuf.gen_delay.sr[mm].probe.monitor;
      end
    end

    for (mm=0; mm < LOOP_NUM; mm++) begin
      initial begin
        sr_loopbuf_h[pp][mm] = DUT.fir.pe[pp].loopbuf.gen_delay.sr[mm].probe.monitor;

      end
    end

    initial begin
      pe_h[pp] = new;
      pe_h[pp].sumbuf = new(DUT.fir.pe[pp].sumbuf.probe.monitor,
                            DUT.fir.pe[pp].sumbuf.headSR.probe.monitor,
                            sr_sumbuf_h[pp]);

      pe_h[pp].databuf = new(DUT.fir.pe[pp].databuf.probe.monitor,
                             DUT.fir.pe[pp].databuf.headSR.probe.monitor,
                             sr_databuf_h[pp]);

      pe_h[pp].loopbuf = new(DUT.fir.pe[pp].loopbuf.probe.monitor,
                             DUT.fir.pe[pp].loopbuf.headSR.probe.monitor,
                             sr_loopbuf_h[pp]);

    end
  end
endgenerate

parameter string cycfmt = $psprintf("%%%0d%0s",4, "d");
parameter string binfmt = $psprintf("%%%0d%0s",1, "b");
parameter string datfmt = $psprintf("%%%0d%0s",4, "X");
parameter string regfmt = $psprintf("%%%0d%0s ",SRLEN, "X");
parameter string hedfmt = $psprintf("%%%0d%0s",1, "X");

string logfmt = $psprintf("%%sCycle=%s:\n\tSLV: %%s\n\tMST: %%s%%s\n", cycfmt);
initial begin
  ospfb_t ospfb;
  Source src;
  
  int errors;

  ospfb = new(pe_h);
  src = new(FFT_LEN);
  
  errors = 0;

  $display("Cycle=%4d: **** Starting OSPFB test bench ****", simcycles);
  // reset circuit
  rst <= 1; slv.tdata <= src.createSample();
  @(posedge clk);
  @(negedge clk) rst = 0; en = 1; slv.tvalid = en;

  $display("Cycle=%4d: Finished init...", simcycles);
  for (int i=0; i < FFT_LEN; i++) begin
    wait_cycles(1);
    #(1ns); // move off edge to monitor (or is it really we move off to drive)?
    //$display(logfmt, GRN, simcycles, rst, en, slv.tdata, mst.tdata, RST);
    $display(logfmt, GRN, simcycles, slv.print(), mst.print(), RST);
    //ospfb.monitor();
    slv.tdata = src.createSample();
  end

  wait_cycles(1);
  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;
end

endmodule
