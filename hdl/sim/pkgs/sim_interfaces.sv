`default_nettype none

import alpaca_ospfb_ix_pkg::*;
import alpaca_constants_pkg::*;

interface delayline_ix #(WIDTH) (
  input wire logic clk
);
  logic rst, en;
  logic [WIDTH-1:0] din, dout;
endinterface

//interface axis #(WIDTH) ();
//  logic [WIDTH-1:0] tdata;
//  logic tvalid, tready;
//
//  modport MST (input tready, output tdata, tvalid);
//  modport SLV (input tdata, tvalid, output tready);
//
//  function string print();
//    automatic string s = $psprintf("{tvalid: 0b%s, tready:0b%s, tdata:0x%s}",
//                                    BINFMT, BINFMT, DATFMT);
//    return $psprintf(s, tvalid, tready, tdata);
//  endfunction
//endinterface

// TODO: food for thought...
//typedef logic [WIDTH-1:0] thingy_t [SRLEN];
//
//interface p_if #(
//  type T
//) (
//  input wire T thingy
//);
//
//  class p_probe extends poker #(T);
//
//    function T getter();
//      return thingy;
//    endfunction
//  endclass
//
//endinterface

typedef logic [WIDTH-1:0] ram_t [2*FFT_LEN];

interface ram_if #(
  parameter WIDTH,
  parameter DEPTH
) (
  input wire clk,
  input wire ram_t ram,
  input wire phasecomp_state_t state,

  input wire logic [WIDTH-1:0] din,

  input wire logic [$clog2(DEPTH)-1:0] cs_wAddr,
  //input wire logic [$clog2(DEPTH)-1:0] ns_wAddr,
  input wire logic [$clog2(DEPTH)-1:0] cs_rAddr,
  //input wire logic [$clog2(DEPTH)-1:0] ns_rAddr,

  //input wire logic wen,
  //input wire logic ren,

  input wire logic [$clog2(DEPTH/2)-1:0] shiftOffset,
  input wire logic incShift

);

  //clocking cb @(posedge clk);
  //  output ram;
  //endclocking

  class ram_probe #(
    parameter WIDTH,
    parameter DEPTH
  ) extends probe #(
    .WIDTH(WIDTH),
    .DEPTH(DEPTH)
  );

    string ramfmt;

    function new();
      string bitfmt = (WIDTH==1) ? "b" : "X";
      string bitid  = (WIDTH==1) ? "b" : "h";
      this.ramfmt = $psprintf("0%s%%%0d%0s ", bitid, 0, bitfmt);
    endfunction

    function string peek();
      return format_ram();
    endfunction

    function string poke();
      return "that tickles";
    endfunction

    function string format_ram();

      string info = "{State: %8s, din: 0h%04X, cs_wAddr: 0h%04X, cs_rAddr: 0h%04X, shiftOffset=0h%04X, incShift=0b%1b}\n         ";
      string mem = $psprintf(info, state.name, din, cs_wAddr, cs_rAddr, shiftOffset, incShift);
      mem = {mem, MGT};
      for (int i=0; i < DEPTH; i++) begin
        mem = {mem, " ", $psprintf(ramfmt, ram[i])};
        if ((i+1)%4==0)
          mem = {mem, "\n         "};
      end
      mem = {mem, RST};
      return mem;
    endfunction
  endclass

  ram_probe #(.WIDTH(WIDTH), .DEPTH(DEPTH)) monitor = new;

  //always @cb
  //  $display(monitor.peek());

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
      string bitfmt = (WIDTH==1) ? "b" : "X";
      string bitid  = (WIDTH==1) ? "b" : "h";
      // what to do about sample size WIDTH
      this.srfmt = $psprintf("0%s%%%0d%0s ", bitid, SRLEN, bitfmt);
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

      // if there are any unknown logic values substitue for a single character
      // instead of xxxxxx for visual debug help
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

  The goal of this source monitoring interface was to provide any help possible to the OSPFB
  monitor class to have an eye into the source needed to help verify outputs. For example, just
  with the python verification model the main loop buffered samples to run against the golden
  model at the end of a frame. This class could ideally do the same type of thing.

  In its current form there was thinking that I needed something to count rollovers of the src
  counter but soon realized after implementation that it wasn't going to work that way. But this
  framework is at least in place if it was needing to be reused.

  A class would have an instance of member that is the virtual class and then in the main intial
  block this class would start the run task.
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
*/

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
