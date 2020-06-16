`default_nettype none

interface delayline_ix #(WIDTH) (
  input wire logic clk
);

logic rst, en;
logic [WIDTH-1:0] din, dout;

endinterface

interface axis #(WIDTH) (
  input wire logic clk
);

  logic [WIDTH-1:0] tdata;
  logic tvalid, tready, tlast;
  logic rst;

  modport MST (input clk, rst, tready, output tdata, tvalid, tlast);
  modport SLV (input clk, rst, tdata, tvalid, tlast, output tready);

endinterface
