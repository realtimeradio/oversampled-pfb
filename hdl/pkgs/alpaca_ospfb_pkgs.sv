`default_nettype none

package alpaca_ospfb_ix_pkg;

virtual class probe #(parameter WIDTH, parameter DEPTH);
  pure virtual function string peek();
  pure virtual function string poke();
  pure virtual function logic[DEPTH*WIDTH-1:0]  get_sr();
endclass

virtual class vpe;
  pure virtual function string peek(int idx, int fft_len);
endclass

//virtual class template_probe #(parameter WIDTH, type T=logic[WIDTH-1:0]);
//  pure virtual function string poke();
//endclass

endpackage

package alpaca_ospfb_monitor_pkg;
  import alpaca_ospfb_utils_pkg::*;
  import alpaca_ospfb_ix_pkg::*;

  parameter LINE_WIDTH=8;

  typedef probe #(.WIDTH(WIDTH), .DEPTH(SRLEN))   sr_probe_t;
  typedef probe #(.WIDTH(WIDTH), .DEPTH(SRLEN-1)) hsr_probe_t;
  typedef probe #(.WIDTH(WIDTH), .DEPTH(1))       hr_probe_t;

  class DelayBufMonitor #(parameter DEPTH, parameter SRLEN); //parameter WIDTH);
    //probe #(.WIDTH(WIDTH), .DEPTH(SRLEN)) sr_h[DEPTH/SRLEN-1];
    //probe #(.WIDTH(WIDTH), .DEPTH(SRLEN-1)) hsr_h;
    //probe #(.WIDTH(WIDTH), .DEPTH(1)) hr_h;

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

    function string print_reg();
      string regs;
      for (int i=$size(this.sr_h)-1; i >= 0; i--) begin
        regs = {regs, " ", this.sr_h[i].peek()};
        if ((i+1)%LINE_WIDTH==0)
          regs = {regs,"\n         "};
      end
      regs = {regs, " ", this.hsr_h.peek(), " ", this.hr_h.peek()};
      return regs;
    endfunction

  endclass

  typedef DelayBufMonitor #(
      .DEPTH(2*FFT_LEN),
      .SRLEN(SRLEN)
    ) databuf_t;


  typedef DelayBufMonitor #(
      .DEPTH(FFT_LEN-DEC_FAC),
      .SRLEN(SRLEN)
  ) loopbuf_t;

  typedef DelayBufMonitor #(
      .DEPTH(FFT_LEN),
      .SRLEN(SRLEN)
    ) sumbuf_t;

  typedef DelayBufMonitor #(
      .DEPTH(FFT_LEN),
      .SRLEN(SRLEN)
    ) vldbuf_t;

  class PeMonitor #(
    parameter FFT_LEN,
    parameter DEC_FAC,
    parameter SRLEN
  );

    databuf_t databuf;
    loopbuf_t loopbuf;
    sumbuf_t sumbuf;
    vldbuf_t vldbuf;

    vpe mac;
    //function new(databuf_t d, loopbuf_t l, sumbuf_t s, vldbuf_t v);
    //  this.databuf = d;
    //  this.loopbuf = l;
    //  this.sumbuf = s;
    //  this.vldbuf = v;
    //endfunction

    function string print_databuf();
      return databuf.print_reg();
    endfunction

    function string print_sumbuf();
      return sumbuf.print_reg();
    endfunction

    function string print_loopbuf();
      return loopbuf.print_reg();
    endfunction

    function string get_mac(int idx);
      return mac.peek(idx, FFT_LEN);
    endfunction

  endclass

  typedef PeMonitor #(
    .FFT_LEN(FFT_LEN),
    .DEC_FAC(DEC_FAC),
    .SRLEN(SRLEN)
  ) pe_t;

  class OspfbMonitor #(
    parameter FFT_LEN,
    parameter DEC_FAC,
    parameter PTAPS,
    parameter SRLEN
  );

    pe_t pe_monitors[PTAPS];

    function new(pe_t pe[]);
      this.pe_monitors = pe;
    endfunction


    function void monitor();
      string macstr = "";
      for (int i=0; i < $size(pe_monitors); i++) begin
        // Show delay buffer contents
        //$display("PE #%0d", i);
        //$display({"loopbuf: ", pe_monitors[i].print_loopbuf()});
        //$display({"databuf: ", pe_monitors[i].print_databuf()});
        //$display({"sumbuf : ", pe_monitors[i].print_sumbuf(), "\n"});

        // Format symbolic polyphase fir summation string
        if (i==0)
          macstr = {macstr, pe_monitors[i].get_mac(i)};
        else
          macstr = {macstr, " + ", pe_monitors[i].get_mac(i)};
      end
      $display("%s\n", macstr);
    endfunction

  endclass

  typedef OspfbMonitor #(
    .FFT_LEN(FFT_LEN),
    .DEC_FAC(DEC_FAC),
    .PTAPS(PTAPS),
    .SRLEN(SRLEN)
  ) ospfb_t;
  
endpackage
