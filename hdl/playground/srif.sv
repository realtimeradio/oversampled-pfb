`default_nettype none

/*
  General interface (no internal signals connected for whitebox verification)
*/
interface data_intf #(WIDTH=16) (
  input wire logic clk
);
  logic [WIDTH-1:0] din, dout;
  logic rst, en;

  modport DUT (input clk, din, rst, en, output dout);
  modport MON (input clk, din, rst, en, dout);
endinterface


// could just have one giant monitoring module with an interface everything connects to
module mon (data_intf.MON monif);
  always @(posedge monif.clk)
    $display("{en: 0b%1b, din: 0x%04X, dout: 0x%04X, rst: 0b%1b}",
          monif.en, monif.din, monif.dout, monif.rst);
endmodule

/*
  SRL32 interface for whitebox testing internal shiftReg signal
*/
interface srif #(DEPTH=8, WIDTH=16) (
  input wire logic clk,
  input wire logic [DEPTH*WIDTH-1:0] sr, // internal signals
  input wire logic [WIDTH-1:0] hr
);

clocking cb @(posedge clk);
  output sr; // directions are relative to the test bench
endclocking

//always @cb
//  $display("%0X", sr);

function logic[DEPTH*WIDTH-1:0] get_sr();
  return sr;
endfunction

endinterface

/*
  Abstract interface/class approach example

  ok... which way do we go....
*/
package abstract_cls;
virtual class abs_delaybuf_itf #(WIDTH=16);
  pure virtual function logic [WIDTH-1:0] get_hr();
  pure virtual function string get_id();
  pure virtual task run();
endclass
endpackage

interface delaybuf_itf #(WIDTH=16, string id) (
  input wire logic clk,
  input wire logic [WIDTH-1:0] hr
);

  clocking cb@(posedge clk);
    output hr; // directions are relative to the test bench
  endclocking

  import abstract_cls::*;
  class intf_monitor #(WIDTH=16) extends abs_delaybuf_itf #(.WIDTH(WIDTH));
    string id;

    function new (string id);
      this.id = id;
    endfunction

    function logic [WIDTH-1:0] get_hr();
      return hr;
    endfunction

    function string get_id();
      return id;
    endfunction

    task run;
      fork
      forever
        @(cb) $display("hr:  %0d, 0x%01X", id, get_hr());
      join_none
    endtask
  endclass

  // to over come the id issue is there a way to a base class here and then instantiate
  // an extended class in the tb?
  //abs_delaybuf_itf #(.WIDTH(WIDTH)) base = new;
  intf_monitor #(.WIDTH(WIDTH)) ifm = new(id);

endinterface
