`default_nettype none

import alpaca_ospfb_ix_pkg::*;
import alpaca_ospfb_utils_pkg::*;

interface delayline_ix #(WIDTH) (
  input wire logic clk
);
  logic rst, en;
  logic [WIDTH-1:0] din, dout;
endinterface

interface axis #(WIDTH) ();
  logic [WIDTH-1:0] tdata;
  logic tvalid, tready;

  modport MST (input tready, output tdata, tvalid);
  modport SLV (input tdata, tvalid, output tready);

  function string print();
    automatic string s = $psprintf("{tvalid: 0b%s, tready:0b%s, tdata:0x%s}",
                                    BINFMT, BINFMT, DATFMT);
    return $psprintf(s, tvalid, tready, tdata);
  endfunction
endinterface

/*
  Shift register monitoring interface
*/
interface sr_if #(
  parameter WIDTH,
  parameter SRLEN
) (
  input wire logic [SRLEN*WIDTH-1:0] shiftReg
);

  class sr_probe #(
    parameter WIDTH,
    parameter SRLEN
  ) extends probe #(
    .WIDTH(WIDTH),
    .DEPTH(SRLEN)
  );

    string srfmt;

    function new();
      // what to do about sample size WIDTH
      this.srfmt = $psprintf("0x%%%0d%0s", SRLEN, "X");
    endfunction

    function string peek();
      return $psprintf(srfmt, get_sr());
    endfunction

    function string poke();
      return "I am a shift register monitor";
    endfunction

    function logic [SRLEN*WIDTH-1:0] get_sr();
      return shiftReg;
    endfunction

  endclass

  sr_probe #(.WIDTH(WIDTH), .SRLEN(SRLEN)) monitor = new;

endinterface

/*
  PE monitoring interface
*/
interface pe_if #(
  parameter WIDTH,
  parameter COEFF_WID
) (
  input wire logic signed [COEFF_WID-1:0] h,
  input wire logic signed [WIDTH-1:0] a
);

  class pe_probe extends vpe;

    string macfmt;
    string unknown;

    function new();
      this.macfmt = "h%0d%0s";
      this.unknown = "*";
    endfunction

    function string peek(int idx, int fft_len);
      int hi = h;
      int symh = idx*FFT_LEN + hi;

      string syma;
      if (a === 'x)
        syma = unknown;
      else
        syma = $psprintf("x%0d", a);

      return $psprintf(macfmt, symh, syma);
    endfunction

  endclass

  pe_probe monitor = new;

endinterface

/*
  Source monitoring interface
*/
interface src_if #(
  parameter MAX_CNT=32
) (
  input wire logic clk,
  input wire logic [$clog2(MAX_CNT)-1:0] dout
);

  class src_probe extends vsrc;

    int frameCtr; // counts number of roll-over events mod MAX_CNT (e.g., FFT_LEN) at source

    function new();
      this.frameCtr = 0;
    endfunction

    function string peek();
      return "watching the source...";
    endfunction

    function int get_frameCtr();
      return frameCtr;
    endfunction

    function void incFrameCtr;
      frameCtr++;
    endfunction;

    task run;
      fork
        forever monitorRollOver;
      join_none // why join_none?
    endtask

    task monitorRollOver;
      @(posedge clk);
      $display("src clk edge monitor, %0b, %0b", dout, &(~dout));
        if (&(~dout))
          incFrameCtr();
    endtask

  endclass

  src_probe monitor = new;

endinterface



/*
  interface delayline_ix #(WIDTH) (
    input wire logic clk
  );

  logic [WIDTH-1:0] din, dout;
  logic rst, en;

  class delayline_probe extends probe;
    string id;
    string binfmt;
    string datfmt;
    string dispfmt;

    function new();
      this.binfmt = $psprintf("%%%0d%0s", 1, "b");
      this.datfmt = $psprintf("%%%0d%0s", WIDTH, "X");
      this.dispfmt = $psprintf("{rst: 0b%s, en: 0b%s, din: 0x%s, dout: 0x%s}",
                                  binfmt, binfmt, datfmt, datfmt);
    endfunction

    function string get_id();
      return id;
    endfunction

    function string poke();
      string s;
      s = $psprintf(this.dispfmt, rst, en, din, dout);
      return s;
    endfunction
  endclass  // delayline_probe

  delayline_probe dp = new;
  endinterface
*/
