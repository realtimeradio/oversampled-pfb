`timescale 1ns/1ps
`default_nettype none

import alpaca_dtypes_pkg::*;

/*********************************************************
combinational circuits for combining the fir packet data
back to complex data packets for the fft
**********************************************************/

// using alpaca data axis interface
module re_to_cx_axis (
  alpaca_data_pkt_axis.SLV s_axis_re,
  alpaca_data_pkt_axis.SLV s_axis_im,

  alpaca_data_pkt_axis.MST m_axis_cx
);

localparam samp_per_clk = s_axis_re.samp_per_clk;

genvar ii;
generate
  for (ii=0; ii<samp_per_clk; ii++) begin : route_to_cx
    assign m_axis_cx.tdata[ii].im = s_axis_im.tdata[ii];
    assign m_axis_cx.tdata[ii].re = s_axis_re.tdata[ii];
  end
endgenerate

// slv passthrough on real, imag not used, synthesis should complain about s_axis_im not connected
assign m_axis_cx.tvalid = s_axis_re.tvalid;
assign m_axis_cx.tlast  = s_axis_re.tlast;

assign s_axis_re.tready = m_axis_cx.tready;
assign s_axis_im.tready = m_axis_cx.tready;

endmodule : re_to_cx_axis

//
module cx_to_re_axis (
  alpaca_data_pkt_axis.SLV s_axis_cx,

  alpaca_data_pkt_axis.MST m_axis_im,
  alpaca_data_pkt_axis.MST m_axis_re
);

localparam samp_per_clk = s_axis_cx.samp_per_clk;

genvar ii;
generate
  for (ii=0; ii < samp_per_clk; ii++) begin : route_to_re
    assign m_axis_im.tdata[ii] = s_axis_cx.tdata[ii].im;
    assign m_axis_re.tdata[ii] = s_axis_cx.tdata[ii].re;
  end
endgenerate

// slv passthrough, default to real for control, synthesis could complain about unconnected
assign m_axis_im.tvalid = s_axis_cx.tvalid;
assign m_axis_im.tlast  = s_axis_cx.tlast;
assign m_axis_re.tvalid = s_axis_cx.tvalid;
assign m_axis_re.tlast  = s_axis_cx.tlast;

assign s_axis_cx.tready = m_axis_re.ready;

endmodule : cx_to_re_axis


/*********************************************************
  ospfb datapath
**********************************************************/

module xpm_ospfb_fir_only_datapath #(
  parameter FFT_LEN=32,
  parameter DEC_FAC=24,
  parameter SRT_PHA=23,  // (DEC_FAC-1) modtimer decimation phase start (which port delivered first)
  parameter PTAPS=8,
  parameter fir_taps_t TAPS,
  parameter LOOPBUF_MEM_TYPE="auto",
  parameter DATABUF_MEM_TYPE="auto",
  parameter SUMBUF_MEM_TYPE="auto"
) (
  input wire logic clk,
  input wire logic rst,

  alpaca_data_pkt_axis.SLV s_axis,                // upstream input data, pkts of complex data
  alpaca_data_pkt_axis.MST m_axis_data            // OSPFB FIR output data, to be fed into external FFT

);

localparam width = $bits(cx_pkt_t);
localparam samp_per_clk = s_axis.samp_per_clk;

// xpm fifos are reset low
logic aresetn;
assign aresetn = ~rst;

// TODO: not used, but consider a core reset gated by tvalid and rst
logic hold_rst;

// for controlling samples -- for parallel samples this steps down multiple input ports when
// thinking about commutating samples in a parallel device paradigm
logic [$clog2(FFT_LEN/samp_per_clk)-1:0] modtimer;           // decimator phase
logic [$clog2(FFT_LEN/samp_per_clk)-1:0] rst_val = SRT_PHA;  // starting decimator phase (which port gets first sample)

logic vin;
cx_pkt_t din;

alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(samp_per_clk), .TUSER(1)) s_axis_fir();
alpaca_data_pkt_axis #(.dtype(sample_t), .SAMP_PER_CLK(samp_per_clk), .TUSER(1) ) m_axis_fir_im(), m_axis_fir_re();

alpaca_data_pkt_axis #(.dtype(sample_t), .SAMP_PER_CLK(samp_per_clk), .TUSER(1)) fir_re_to_cx(), fir_im_to_cx();
alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(samp_per_clk), .TUSER(1)) xfft_delay_fifo_axis();

assign s_axis_fir.tdata = din;
assign s_axis_fir.tvalid = s_axis.tvalid;
assign s_axis_fir.tuser = vin;

//TODO (tlast): is now implemented with new interface... needs to be verifed
alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(samp_per_clk), .TUSER(1)) s_axis_fft_data();// tuser not on xfft input

always_ff @(posedge clk)
  if (rst)
    modtimer <= rst_val;
  else if (s_axis.tvalid)
    modtimer <= modtimer + 1;
  else
    modtimer <= modtimer;

xpm_cx_fir #(
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .PTAPS(PTAPS),
  .LOOPBUF_MEM_TYPE(LOOPBUF_MEM_TYPE),
  .DATABUF_MEM_TYPE(DATABUF_MEM_TYPE),
  .SUMBUF_MEM_TYPE(SUMBUF_MEM_TYPE),
  .TAPS(TAPS)
) fir_inst (
  .clk(clk),
  .rst(rst),
  .s_axis(s_axis_fir),       // tuser=vin
  .m_axis_im(m_axis_fir_im), // tuser=vout, so far unused after last PE
  .m_axis_re(m_axis_fir_re)  // tuser=vout, so far unused after last PE
);

alpaca_phasecomp #(
  .DEPTH(2*(FFT_LEN/samp_per_clk)),
  .DEC_FAC(DEC_FAC/samp_per_clk) // may be a good idea to divide by samp_per_clk here too avoid confusion
) phasecomp_re_inst (
  .clk(clk),
  .rst(rst),
  .s_axis(m_axis_fir_re),
  .m_axis(fir_re_to_cx)
);

alpaca_phasecomp #(
  .DEPTH(2*(FFT_LEN/samp_per_clk)),
  .DEC_FAC(DEC_FAC/samp_per_clk)
) phasecomp_im_inst (
  .clk(clk),
  .rst(rst),
  .s_axis(m_axis_fir_im),
  .m_axis(fir_im_to_cx)
);

re_to_cx_axis re_to_cx_axis_inst (
  .s_axis_re(fir_re_to_cx),
  .s_axis_im(fir_im_to_cx),
  .m_axis_cx(m_axis_data)
);


/*
  Datapath state machine controller
*/

typedef enum logic [1:0] {WAIT_FIFO, FORWARD, FEEDBACK, ERR='X} stateType;
stateType cs, ns;

// FSM state register
always_ff @(posedge clk)
  cs <= ns;

always_comb begin
  // default values to prevent latch inferences
  ns = ERR;
  din = {32'hddccaabb, 32'haabbccdd}; //should never see these values, if so, it is an error
  hold_rst = 1'b1;

  // ospfb.py top-level equivalent producing the vin to start the process
  // why modtimer < dec_fac and not dec_fac-1 like in src counter pass through?
  s_axis.tready = 1'b0;
  /*
    TODO: wanting to implement m_axis tready as a debug to make sure we are always accepting a
    sample each cycle as noted in the AMBA AXIS recommendation for tready implementation
    the question is where and how do I use m_axis_data.tready for debug monitoring of slave.
    If m_axis_data.tready isn't used for anything meaningful vivado synthesis throws a warning
    but may not be an issue.  Will get unexpected synthesis behavior if I don't remove this when
    testing it
  */
  vin = 1'b0;

  // fsm cases
  if (rst) begin
    ns = WAIT_FIFO;
  end else begin
    case (cs)
      WAIT_FIFO: begin
        if (s_axis.tvalid) begin
          hold_rst = 1'b0;

          s_axis.tready = (modtimer < (DEC_FAC/samp_per_clk)) ? 1'b1 : 1'b0;
          vin = (s_axis.tready & s_axis.tvalid) ? 1'b1: 1'b0; // shouldn't this be in my states as well?
          // move first to FEEDBACK. Although we are loading one sample now this is the last
          // sample of a FORWARD state operation (loading at port 0 then wrapping to port D-1)
          din = s_axis.tdata;
          ns = FEEDBACK;
        end else begin
          ns = WAIT_FIFO;
        end
      end

      FORWARD: begin
        hold_rst = 1'b0;

        s_axis.tready = (modtimer < (DEC_FAC/samp_per_clk)) ? 1'b1 : 1'b0; // *NOTE*: DEC_FAC must be divisiable by `samp_per_clk`
        vin = (s_axis.tready & s_axis.tvalid) ? 1'b1: 1'b0;
        din = s_axis.tdata;
        if (modtimer == (DEC_FAC/samp_per_clk)-1)
          ns = FEEDBACK;
        else
          ns = FORWARD;
      end

      FEEDBACK: begin
        hold_rst = 1'b0;
        s_axis.tready = (modtimer < (DEC_FAC/samp_per_clk)) ? 1'b1 : 1'b0; // *NOTE*: DEC_FAC must be divisiable by `samp_per_clk`
        vin = (s_axis.tready & s_axis.tvalid) ? 1'b1: 1'b0;
        din = {32'hbeefdead, 32'hdeadbeef}; // bogus data for testing, should not be accepted to delaybufs
        if (modtimer == (FFT_LEN/samp_per_clk)-1)
          ns = FORWARD;
        else
          ns = FEEDBACK;
      end

      default:
        ns = ERR;
    endcase // case
  end
end

endmodule : xpm_ospfb_fir_only_datapath
