`timescale 1ns/1ps
`default_nettype none

interface axis #(WIDTH) ();
  logic [WIDTH-1:0] tdata;
  logic tready, tvalid;

  modport MST (input tready, output tdata, tvalid);
  modport SLV (input tdata, tvalid, output tready);

  parameter string CYCFMT = $psprintf("%%%0d%0s",4, "d");
  parameter string BINFMT = $psprintf("%%%0d%0s",1, "b");
  parameter string DATFMT = $psprintf("%%%0d%0s",0, "d");

  function string print();
    automatic string s = $psprintf("{tvalid: 0b%s, tready:0b%s, tdata:0x%s}",
                                    BINFMT, BINFMT, DATFMT);
    return $psprintf(s, tvalid, tready, tdata);
  endfunction
endinterface

/*
  Simple shift reg module to test synchrnous and asynchronous
  output timing on an AXIS interface.

  As far as a shift register goes a shift register does not entirely
  map to why you would choose asynch vs. synch. But this does model the
  timing behavior you would expect.

  BRAMs/URAMs/other memory elements are where asynhc vs. synch become more
  of a discussion point to improve timing. With synchrnous output pipelining
  registers in favor of asynchronous reads as to imporve timing by by-passing
  the timing for values to load and settle from a memory element.
*/
module ShiftReg #(
  parameter WIDTH=16,
  parameter DEPTH=4,
  parameter MODE="synch"
) (
  input wire logic clk,
  input wire logic rst,
  axis.MST m_axis,
  axis.SLV s_axis
);

  logic [DEPTH-1:0][WIDTH-1:0] q;

  always_ff @(posedge clk)
    if (rst)
      q <= '0;
    else if (m_axis.tready & s_axis.tvalid)
      q <= {q[DEPTH-2:0], s_axis.tdata};
    else
      q <= q;

  assign s_axis.tready = 1'b1;
  assign m_axis.tvalid = (s_axis.tvalid & s_axis.tready);

  generate
    if (MODE=="synch") begin
      always_ff @(posedge clk)
        if (rst)
          m_axis.tdata <= '0;
        else
          m_axis.tdata <= q[DEPTH-1];

    end else begin
      assign m_axis.tdata = q[DEPTH-1];

    end
  endgenerate

endmodule

/*
  Top module wrapping a the counter source and two shift register
  instances one doing a synchronous output and the other asynchronous.
*/
module synch_asynch_top #(
  parameter WIDTH=16
) (
  input wire logic clk,
  input wire logic rst,
  axis.MST m_axis_asynch,
  axis.MST m_axis_synch
);

  axis #(.WIDTH(WIDTH)) src_axis();
  axis #(.WIDTH(WIDTH)) s_axis_asynch();
  axis #(.WIDTH(WIDTH)) s_axis_synch();

  src_ctr #(
    .WIDTH(WIDTH),
    .MAX_CNT(4),
    .ORDER("natural")
  ) src_ctr_inst (
    .clk(clk),
    .rst(rst),
    .m_axis(src_axis)
  );

  assign s_axis_asynch.tdata = src_axis.tdata;
  assign s_axis_synch.tdata = src_axis.tdata;

  assign s_axis_asynch.tvalid = src_axis.tvalid;
  assign s_axis_synch.tvalid = src_axis.tvalid;

  assign src_axis.tready = (s_axis_asynch.tready & s_axis_synch.tready);

  ShiftReg #(
    .WIDTH(WIDTH),
    .DEPTH(4),
    .MODE("asynch")
  ) asynch_inst (
    .clk(clk),
    .rst(rst),
    .m_axis(m_axis_asynch),
    .s_axis(s_axis_asynch)
  );

  ShiftReg #(
    .WIDTH(WIDTH),
    .DEPTH(4),
    .MODE("synch")
  ) synch_inst (
    .clk(clk),
    .rst(rst),
    .m_axis(m_axis_synch),
    .s_axis(s_axis_synch)
  );

endmodule

parameter PERIOD = 10;
parameter WIDTH = 16;

module testbench();

logic clk, rst;
axis #(.WIDTH(WIDTH)) m_axis_asynch(), m_axis_synch();

synch_asynch_top #(
  .WIDTH(WIDTH)
) DUT (
  .clk(clk),
  .rst(rst),
  .m_axis_asynch(m_axis_asynch),
  .m_axis_synch(m_axis_synch)
);

task wait_cycles(int cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

int simcycles;
initial begin
  clk <= 0; simcycles=0;
  forever #(PERIOD/2) begin
    clk = ~clk;
    simcycles += (1 & clk) & ~rst;
  end
end


// main block
initial begin
  rst <= 1;
  @(posedge clk);
  @(negedge clk); rst = 0; m_axis_asynch.tready = 1; m_axis_synch.tready = 1;

  for (int i=0; i<10; i++) begin
    wait_cycles();
    $display({"asynch: ", m_axis_asynch.print()});
    $display({"synch:  ", m_axis_synch.print()});
    $display();
  end
  $finish;

end

endmodule

