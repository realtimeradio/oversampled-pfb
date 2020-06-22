`default_nettype none

// START HERE
/*
    I have decided to use the abstract class approach over the virtual interface partly because
while the amount of code is similar it so far looks cleaner and does feel more like OOP by
grouping functionality in the same place.

So I have two versions of the delaybuf tb, one using virtual interfaces and the current one I am
testing the new functionality on. I should either commit the virtual interfaces version or move
it somewhere to cleanup the code base

*/

package alpaca_ospfb_ix_pkg;

virtual class probe #(parameter WIDTH, parameter DEPTH);
  pure virtual function string peek();
  pure virtual function string poke();
  pure virtual function logic[DEPTH*WIDTH-1:0]  get_sr();
endclass

//virtual class template_probe #(parameter WIDTH, type T=logic[WIDTH-1:0]);
//  pure virtual function string poke();
//endclass

endpackage

package alpaca_ospfb_monitor_pkg;
  import alpaca_ospfb_utils_pkg::*;
  import alpaca_ospfb_ix_pkg::*;

  typedef probe #(.WIDTH(WIDTH), .DEPTH(SRLEN))   sr_probe_t;
  typedef probe #(.WIDTH(WIDTH), .DEPTH(SRLEN-1)) hsr_probe_t;
  typedef probe #(.WIDTH(WIDTH), .DEPTH(1))       hr_probe_t;

  class DelayBufMonitor #(parameter DEPTH, parameter SRLEN);
    sr_probe_t  sr_h[DEPTH/SRLEN-1]; // handle for NUM-1 shift registers
    hsr_probe_t hsr_h;  // handle for SRLShiftReg for head reg
    hr_probe_t  hr_h;   // handle for delay buf head reg 

    function new(hr_probe_t headReg,
                 hsr_probe_t headShiftReg,
                 sr_probe_t shiftRegs[]);
      this.hr_h  = headReg;
      this.hsr_h = headShiftReg;
      this.sr_h  = shiftRegs;
    endfunction

    function void print_reg();
      string regs;
      for (int i=$size(sr_h)-1; i >= 0; i--) begin
        regs = {regs, " ", sr_h[i].peek()};
        // $psprintf(" 0x%016X", sr_h[i].get_sr())};
      end
      regs = {regs, " ", hsr_h.peek(), " ", hr_h.peek()};
      //$psprintf(" 0x%015X", hsr_h.get_sr()), $psprintf(" 0x%01X", hr_h.get_sr())};
      //$display(logfmt, simcycles, mainX_h.rst, mainX_h.en, mainX_h.din, mainX_h.dout);
      $display({regs, "\n"});
    endfunction

  endclass

  typedef DelayBufMonitor #(
      .DEPTH(2*FFT_LEN),
      .SRLEN(SRLEN)
    ) delaybuf_t;

  typedef DelayBufMonitor #(
      .DEPTH(FFT_LEN),
      .SRLEN(SRLEN)
    ) sumbuf_t;

  typedef DelayBufMonitor #(
      .DEPTH(FFT_LEN),
      .SRLEN(SRLEN)
    ) vldbuf_t;

  class OSPFBMonitor #(
    parameter FFT_LEN,
    parameter DEC_FAC,
    parameter PTAPS,
    parameter SRLEN
  );

    delaybuf_t delaybuf;
    sumbuf_t sumbuf;
    vldbuf_t vldbuf;
    function new(delaybuf_t d, sumbuf_t s, vldbuf_t v);
      this.delaybuf = d;
      this.sumbuf = s;
      this.vldbuf = v;
    endfunction
  endclass

endpackage
