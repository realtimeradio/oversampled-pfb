`default_nettype none

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

endinterface
