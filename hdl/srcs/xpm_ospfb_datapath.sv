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

endmodule : re_to_cx_axis

// using alpaca data types since the phase comp buffer is not yet axis
// ...I want it to be but I am afraid of changing too much, then when simulation inevitably
// fails be unsure about what to test and check
module re_to_cx #(
  parameter int SAMP_PER_CLK=2
) (
  input wire fir_pkt_t im,
  input wire fir_pkt_t re,
  output cx_pkt_t cx
);

genvar ii;
  generate
    for (ii=0; ii<SAMP_PER_CLK; ii++) begin : route_to_cx
      assign cx[ii].im = im[ii];
      assign cx[ii].re = re[ii];
    end
  endgenerate

endmodule : re_to_cx

/*********************************************************
  ospfb datapath
**********************************************************/

module xpm_ospfb_datapath #(
  parameter FFT_LEN=32,
  parameter DEC_FAC=24,
  parameter SRT_PHA=23,  // (DEC_FAC-1) modtimer decimation phase start (which port delivered first)
  parameter PTAPS=8,
  parameter fir_taps_t TAPS,
  parameter TWIDDLE_FILE="",
  parameter LOOPBUF_MEM_TYPE="auto",
  parameter DATABUF_MEM_TYPE="auto",
  parameter SUMBUF_MEM_TYPE="auto"
) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,  // TODO: seemed to now only be used to control the modtimer counter
                        // shouldn't be too hard to remove now
  alpaca_data_pkt_axis.SLV s_axis,                // upstream input data, pkts of complex data
  alpaca_data_pkt_axis.MST m_axis_data,           // OSPFB output data, now Xk from parallel_xfft, not a xilinx fft

  alpaca_xfft_status_axis.MST m_axis_fft_status_x2,  // XFFT status for overflow
  alpaca_xfft_status_axis.MST m_axis_fft_status_x1,  // XFFT status for overflow
  output logic [1:0] event_frame_started,
  output logic [1:0] event_tlast_unexpected,
  output logic [1:0] event_tlast_missing,
  output logic [1:0] event_fft_overflow,
  output logic [1:0] event_data_in_channel_halt
);

localparam width = $bits(cx_pkt_t);
localparam samp_per_clk = s_axis.samp_per_clk;

// fft and xpm_fifo is reset low
logic aresetn;
assign aresetn = ~rst;

// may not need anymore with everything on axis?... ah, but the phasecomp isn't yet
logic hold_rst;

// for controlling samples -- for parallle samples this steps down multiple input ports when 
// thinking about commutating samples in a parallel device paradigm
logic [$clog2(FFT_LEN/samp_per_clk)-1:0] modtimer;           // decimator phase
logic [$clog2(FFT_LEN/samp_per_clk)-1:0] rst_val = SRT_PHA;  // starting decimator phase (which port gets first sample)

logic vin;
fir_pkt_t din_re;
fir_pkt_t din_im;

fir_pkt_t pc_in_re;
fir_pkt_t pc_in_im;

fir_pkt_t sout_re;
fir_pkt_t sout_im;

alpaca_data_pkt_axis #(
  .dtype(sample_t),
  .SAMP_PER_CLK(samp_per_clk),
  .TUSER(1)
) s_axis_fir_im(), s_axis_fir_re(), m_axis_fir_im(), m_axis_fir_re();

assign s_axis_fir_re.tdata = din_re;
assign s_axis_fir_re.tvalid = s_axis.tvalid;
assign s_axis_fir_re.tuser = vin;

assign s_axis_fir_im.tdata = din_im;
assign s_axis_fir_im.tvalid = s_axis.tvalid;
assign s_axis_fir_im.tuser = vin;

assign pc_in_re = (m_axis_fir_re.tready & m_axis_fir_re.tvalid) ? m_axis_fir_re.tdata : '0;
assign pc_in_im = (m_axis_fir_im.tready & m_axis_fir_im.tvalid) ? m_axis_fir_im.tdata : '0;
// since the upstream slave is the phase comp and phasecomp isn't ready until after hold_rst
// this seems to make sense
assign m_axis_fir_re.tready = ~hold_rst;
assign m_axis_fir_im.tready = ~hold_rst;

//TODO (tlast): is now implemented with new interface... needs to be verifed
alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(samp_per_clk), .TUSER(1)) s_axis_fft_data(); // tuser not used

// To configure the inverse transform and scaling schedule
alpaca_xfft_config_axis s_axis_fft_config_x1(), s_axis_fft_config_x2();

always_ff @(posedge clk)
  if (hold_rst)
    modtimer <= rst_val;
  else if (en)
    modtimer <= modtimer + 1;
  else
    modtimer <= modtimer;

xpm_fir #(
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .PTAPS(PTAPS),
  .LOOPBUF_MEM_TYPE(LOOPBUF_MEM_TYPE),
  .DATABUF_MEM_TYPE(DATABUF_MEM_TYPE),
  .SUMBUF_MEM_TYPE(SUMBUF_MEM_TYPE),
  .TAPS(TAPS)
) fir_re (
  .clk(clk),
  .rst(rst),
  .s_axis(s_axis_fir_re), // tuser=vin
  .m_axis(m_axis_fir_re) // tuser=vout, so far unused
);

PhaseComp #(
  .DEPTH(2*(FFT_LEN/samp_per_clk)),
  .DEC_FAC(DEC_FAC),
  .SAMP_PER_CLK(samp_per_clk)
) phasecomp_re_inst (
  .clk(clk),
  .rst(hold_rst),
  .din(pc_in_re),
  .dout(sout_re)
);

xpm_fir #(
  .FFT_LEN(FFT_LEN),
  .DEC_FAC(DEC_FAC),
  .PTAPS(PTAPS),
  .LOOPBUF_MEM_TYPE(LOOPBUF_MEM_TYPE),
  .DATABUF_MEM_TYPE(DATABUF_MEM_TYPE),
  .SUMBUF_MEM_TYPE(SUMBUF_MEM_TYPE),
  .TAPS(TAPS)
) fir_im (
  .clk(clk),
  .rst(rst),
  .s_axis(s_axis_fir_im), // tuser=vin
  .m_axis(m_axis_fir_im)  // tuser=vout, so far unused
);

PhaseComp #(
  .DEPTH(2*(FFT_LEN/samp_per_clk)),
  .DEC_FAC(DEC_FAC),
  .SAMP_PER_CLK(samp_per_clk)
) phasecomp_im_inst (
  .clk(clk),
  .rst(hold_rst),
  .din(pc_in_im),
  .dout(sout_im)
);

//alpaca_data_pkt_axis #(.dtype(cx_t), .SAMP_PER_CLK(samp_per_clk). TUSER()) fir_to_cx();
cx_pkt_t xfft_delay_fifo_data;
re_to_cx #(
  .SAMP_PER_CLK(samp_per_clk)
) re_to_cx_inst (
  .im(sout_im),
  .re(sout_re),
  .cx(xfft_delay_fifo_data)
);

// TODO: is this going to interfer with the dc fifo out front? It will if this comes out of
// reset later than dcfifo. Or the state machine now has to watch both of these
logic xfft_delay_fifo_tready;
xpm_fifo_axis #(
  .CLOCKING_MODE("common_clock"),
  .FIFO_DEPTH(16),//simulation shown we only need two because of FFT slave wait state at beginning
  .FIFO_MEMORY_TYPE("auto"),
  .SIM_ASSERT_CHK(0),
  .TDATA_WIDTH(width)
) xfft_delay_fifo_inst (
  // TODO: hopefully ports are removed in synthesis if not connected or driven
  .almost_empty_axis(),
  .almost_full_axis(),

  .dbiterr_axis(),

  .m_axis_tdata(s_axis_fft_data.tdata),
  .m_axis_tdest(),
  .m_axis_tid(),
  .m_axis_tkeep(),
  .m_axis_tlast(s_axis_fft_data.tlast),
  .m_axis_tstrb(),
  .m_axis_tuser(),
  .m_axis_tvalid(s_axis_fft_data.tvalid),

  .prog_empty_axis(),
  .prog_full_axis(),

  .rd_data_count_axis(),

  .s_axis_tready(xfft_delay_fifo_tready),

  .sbiterr_axis(),

  .wr_data_count_axis(),

  .injectdbiterr_axis(1'b0),
  .injectsbiterr_axis(1'b0),

  .m_aclk(clk),
  .m_axis_tready(s_axis_fft_data.tready),

  .s_aclk(clk),
  .s_aresetn(aresetn),

  .s_axis_tdata(xfft_delay_fifo_data),
  .s_axis_tdest('0),
  .s_axis_tid('0),
  .s_axis_tkeep('0),
  .s_axis_tlast(1'b0),
  .s_axis_tstrb('0),
  .s_axis_tuser('0),
  .s_axis_tvalid(~hold_rst) // idea being we come out of hold_rst and the ospfb is streaming
);

parallel_xfft #(
  .FFT_LEN(FFT_LEN),
  .TWIDDLE_FILE(TWIDDLE_FILE)
) p_xfft_inst (
  .clk(clk),
  .rst(rst),
  .s_axis(s_axis_fft_data),
  .s_axis_config_x2(s_axis_fft_config_x2),
  .s_axis_config_x1(s_axis_fft_config_x1),

  .m_axis_Xk(m_axis_data), // output data from OSPFB, cpx_pkt_t

  .m_axis_fft_status_x2(m_axis_fft_status_x2),
  .m_axis_fft_status_x1(m_axis_fft_status_x1),

  .event_frame_started(event_frame_started),
  .event_tlast_unexpected(event_tlast_unexpected),
  .event_tlast_missing(event_tlast_missing),
  .event_fft_overflow(event_fft_overflow),
  .event_data_in_channel_halt(event_data_in_channel_halt)
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
  din_re = 32'haabbccdd; //should never see these values, if so, it is an error
  din_im = 32'hddccaabb;
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

  // TODO: only set once but should be parameterized so that I don't forget it when moving
  // between M for testing
  // default configuration values {pad (if needed), scale_sched, fwd/inv xform}
  s_axis_fft_config_x2.tdata = {1'b0, 2'b10, 2'b10, 2'b10, 1'b0}; // N=64 (ospfb fft len/2)
  s_axis_fft_config_x1.tdata = {1'b0, 2'b10, 2'b10, 2'b10, 1'b0};
  //s_axis_fft_config_x1.tdata = {3'b0, 2'b00, 2'b10, 2'b10, 2'b10, 2'b10, 2'b10, 1'b0};
  s_axis_fft_config_x2.tvalid = 1'b0;
  s_axis_fft_config_x1.tvalid = 1'b0;

  // fsm cases
  if (rst) begin
    ns = WAIT_FIFO;
  end else begin
    case (cs)
      WAIT_FIFO: begin
        if (s_axis.tvalid) begin
          hold_rst = 1'b0;
          s_axis_fft_config_x2.tvalid = 1'b1;   // load the inverse transform and scaling schedule
          s_axis_fft_config_x1.tvalid = 1'b1;   // load the inverse transform and scaling schedule

          s_axis.tready = (modtimer < (DEC_FAC/samp_per_clk)) ? 1'b1 : 1'b0; // *NOTE*: DEC_FAC must be divisiable by `samp_per_clk`
          vin = (s_axis.tready & s_axis.tvalid) ? 1'b1: 1'b0; // shouldn't this be in my states as well?
          // move first to FEEDBACK. Although we are loading one sample now this is the last
          // sample of a FORWARD state operation (loading at port 0 then wrapping to port D-1)
          din_re = {s_axis.tdata[1].re, s_axis.tdata[0].re};
          din_im = {s_axis.tdata[1].im, s_axis.tdata[0].im};
          ns = FEEDBACK;
        end else begin
          ns = WAIT_FIFO;
        end
      end

      FORWARD: begin
        hold_rst = 1'b0;

        s_axis.tready = (modtimer < (DEC_FAC/samp_per_clk)) ? 1'b1 : 1'b0; // *NOTE*: DEC_FAC must be divisiable by `samp_per_clk`
        vin = (s_axis.tready & s_axis.tvalid) ? 1'b1: 1'b0;
        din_re = {s_axis.tdata[1].re, s_axis.tdata[0].re};
        din_im = {s_axis.tdata[1].im, s_axis.tdata[0].im};
        if (modtimer == (DEC_FAC/samp_per_clk)-1)
          ns = FEEDBACK;
        else
          ns = FORWARD;
      end

      FEEDBACK: begin
        hold_rst = 1'b0;
        s_axis.tready = (modtimer < (DEC_FAC/samp_per_clk)) ? 1'b1 : 1'b0; // *NOTE*: DEC_FAC must be divisiable by `samp_per_clk`
        vin = (s_axis.tready & s_axis.tvalid) ? 1'b1: 1'b0;
        din_re = 32'hdeadbeef; // bogus data for testing, should not be accepted to delaybufs
        din_im = 32'hbeefdead;
        if (modtimer == (FFT_LEN/samp_per_clk)-1)
          ns = FORWARD;
        else
          ns = FEEDBACK;
      end
    endcase // case
  end
end

endmodule : xpm_ospfb_datapath
