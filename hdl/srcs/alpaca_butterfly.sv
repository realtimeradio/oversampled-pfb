`timescale 1ns/1ps
`default_nettype none

import alpaca_constants_pkg::*; // if I import this here I don't need the module params(twiddle file,fftlen)
import alpaca_dtypes_pkg::*;

module alpaca_butterfly #(
  parameter int FFT_LEN=16,
  parameter TWIDDLE_FILE=""
) (
  input wire logic clk,
  input wire logic rst,
  alpaca_xfft_data_axis.SLV x1,
  alpaca_xfft_data_axis.SLV x2,

  alpaca_data_pkt_axis.MST Xk
  // mst tready not implemented
  // possible idea for an error check is to create an output and have
  // that driven by when the mst is valid and the mst (slv) not ready
);

//logic signed [$bits(wk_t)-1:0] twiddle [FFT_LEN/2];
wk_t twiddle [FFT_LEN/2];
logic [$clog2(FFT_LEN/2)-1:0] ctr;

initial begin
  $readmemh(TWIDDLE_FILE, twiddle);
end

wk_t Wk;
cx_t Xkhi, Xklo;

always_ff @(posedge clk)
  if (rst)
    ctr <= '0;
  else if (x2.tvalid)
    ctr <= ctr + 1;

assign Wk = twiddle[ctr];

// The fully pipelined cmult latency is 6 cycles, right now the add is probably not right as it
// is done in the next cycle, maybe cross/boundry synthesis will optimize this into the dsp, and
// but so we may need to add more for better fclk. Also may want to add more to clock the
// twiddle factor out.
// cmult latency + final add/sub + convergent round (may need more, see above note)
localparam AXIS_LAT = 9; // mult+add/sub=7, rnd=2
logic [AXIS_LAT-1:0][1:0] axis_delay; // {tvalid, tlast}

logic [AXIS_LAT-1:0][$bits(Xk.tuser)-1:0] axis_tuser_delay; // concatenate x1/x2 tuser as {x1,x2}

// opting for x2 last/valid propagation
always_ff @(posedge clk) begin
  axis_delay <= {axis_delay[AXIS_LAT-2:0], {x2.tvalid, x2.tlast}};
  axis_tuser_delay <= {axis_tuser_delay[AXIS_LAT-2:0] , {x1.tuser, x2.tuser}};
end

// unfortunate that all of this work to have "scalable" interfaces but still have to have the
// parameters here. More work would need to be done to figure out how to get them here because
// the AXI interface cant have another interface so we would need to also incorporate this in
// the AXI or some other way
fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) ar_in(), ai_in(), cr_in(), ci_in();
fp_data #(.dtype(phase_t), .W(PHASE_WIDTH), .F(PHASE_FRAC_WIDTH)) br_in(), bi_in();
fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) add_dout_re(), add_dout_im();
fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) sub_dout_re(), sub_dout_im();

assign ar_in.data = x2.tdata.re;
assign ai_in.data = x2.tdata.im;
assign br_in.data = Wk.re;
assign bi_in.data = Wk.im;
assign cr_in.data = x1.tdata.re;
assign ci_in.data = x1.tdata.im;

assign Xklo.re = add_dout_re.data;
assign Xklo.im = add_dout_im.data;
assign Xkhi.re = sub_dout_re.data;
assign Xkhi.im = sub_dout_im.data;

alpaca_cx_multadd_convrnd cmult_inst (.*);

assign Xk.tdata = {Xkhi, Xklo}; //may need to do another one register for dsp slice clock efficiency?
assign Xk.tvalid = axis_delay[AXIS_LAT-1][1];
assign Xk.tlast = axis_delay[AXIS_LAT-1][0];
assign Xk.tuser = axis_tuser_delay[AXIS_LAT-1];

assign x1.tready = ~rst;
assign x2.tready = ~rst;

endmodule : alpaca_butterfly
