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

interface pe_if #(
  parameter WIDTH,
  parameter COEFF_WID
) (
  input wire signed [COEFF_WID-1:0] h,
  input wire signed [WIDTH-1:0] a
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
*
* interface delayline_ix #(WIDTH) (
*   input wire logic clk
* );
* 
* logic [WIDTH-1:0] din, dout;
* logic rst, en;
* 
* class delayline_probe extends probe;
*   string id;
*   string binfmt;
*   string datfmt;
*   string dispfmt;
* 
*   function new();
*     this.binfmt = $psprintf("%%%0d%0s", 1, "b");
*     this.datfmt = $psprintf("%%%0d%0s", WIDTH, "X");
*     this.dispfmt = $psprintf("{rst: 0b%s, en: 0b%s, din: 0x%s, dout: 0x%s}",
*                                 binfmt, binfmt, datfmt, datfmt);
*   endfunction
* 
*   function string get_id();
*     return id;
*   endfunction 
* 
*   function string poke();
*     string s;
*     s = $psprintf(this.dispfmt, rst, en, din, dout);
*     return s;
*   endfunction
* endclass  // delayline_probe
* 
* delayline_probe dp = new;
* endinterface
*/
