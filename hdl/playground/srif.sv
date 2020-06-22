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
  input wire logic [DEPTH*WIDTH-1:0] sr // internal signals
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
virtual class abs_delaybuf_itf #(
  parameter DEPTH=32,
  parameter SRLEN=8,
  parameter WIDTH=16,
  parameter NUM=(DEPTH/SRLEN)-1
);
  pure virtual function logic [WIDTH-1:0] get_hr();
  //pure virtual function logic [0:NUM-1][WIDTH-1:0] get_sr();
  pure virtual task run();
endclass
endpackage

interface delaybuf_itf #(
  parameter DEPTH=32,
  parameter SRLEN=8,
  parameter WIDTH=16,
  parameter NUM=(DEPTH/SRLEN)-1
) (
  input wire logic clk,
  input wire logic [WIDTH-1:0] hr,
  input wire logic [(SRLEN-1)*WIDTH-1:0] hsr
);

  clocking cb@(posedge clk);
    output hr; // directions are relative to the test bench
  endclocking

  import abstract_cls::*;
  class intf_monitor #(
    parameter DEPTH=32,
    parameter SRLEN=8,
    parameter WIDTH=16,
    parameter NUM=(DEPTH/SRLEN)-1
  ) extends abs_delaybuf_itf #(
    .DEPTH(DEPTH),
    .SRLEN(SRLEN),
    .WIDTH(WIDTH)
  );

    function logic [WIDTH-1:0] get_hr();
      return hr;
    endfunction

    //function logic [0:NUM-1][WIDTH-1:0] get_sr();
    //  return sr;
    //endfunction

    task run;
      fork
      forever
        @(cb) $display("hr: 0x%01X", get_hr());
      join_none
    endtask
  endclass

  // to over come the id issue is there a way to a base class here and then instantiate
  // an extended class in the tb?
  //abs_delaybuf_itf #(.WIDTH(WIDTH)) base = new;
  intf_monitor #(.DEPTH(DEPTH), .SRLEN(SRLEN), .WIDTH(WIDTH)) ifm = new;

endinterface
