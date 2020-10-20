`timescale 1ns/1ps
`default_nettype none

import alpaca_dtypes_pkg::*;

/**********************************
  Multiply add
***********************************/

module alpaca_multadd (
  input wire logic clk,
  input wire logic rst,

  fp_data.I a_in,
  fp_data.I b_in,
  fp_data.I c_in,

  fp_data.O dout
);

// gather fixed point parameters to perform and check calculation widths
typedef a_in.data_t a_data_t;
typedef b_in.data_t b_data_t;
typedef c_in.data_t c_data_t;

typedef dout.data_t result_t; 

localparam aw = a_in.w;
localparam af = a_in.f;

localparam bw = b_in.w;
localparam bf = b_in.f;

localparam cw = c_in.w;
localparam cf = c_in.f;

localparam doutw = dout.w;
localparam doutf = dout.f;

localparam mult_result_w = aw + bw;
localparam mult_result_f = af + bf;

localparam multadd_result_w = mult_result_w + 1; // multiplication plus one bit for the addition
localparam multadd_result_f = mult_result_f;

initial begin
  assert (multadd_result_w== doutw) begin
    $display("module arithmitec res=%0d, outw=%0d", multadd_result_w, doutw);
    $display("mult add binary point adjust: %0d", mult_result_f - cf);
  end else
    $display("module arithmitec res=%0d, outw=%0d", multadd_result_w, doutw);
end

////////////

localparam ALIGN_BP = mult_result_f - cf;
localparam MULT_LAT = 2;
localparam ADD_LAT = MULT_LAT+1;

a_data_t [MULT_LAT-1:0] a_delay;
b_data_t [MULT_LAT-1:0] b_delay;
c_data_t [ADD_LAT-1:0] c_delay;

a_data_t a;
b_data_t b;

result_t c;
result_t m_reg;  // register intermediate multiplication output
result_t multadd;

always_ff @(posedge clk)
  if (rst) begin
    a_delay <= '0;
    b_delay <= '0;
    c_delay <= '0;

    a <= '0;
    b <= '0;
    c <= '0;
    m_reg <= '0;
    multadd <= '0;

  end else begin
    a_delay <= {a_delay[MULT_LAT-2:0], a_in.data};
    b_delay <= {b_delay[MULT_LAT-2:0], b_in.data};
    c_delay <= {c_delay[ADD_LAT-2:0], c_in.data};

    a <= a_delay[MULT_LAT-1];
    b <= b_delay[MULT_LAT-1];
    c <= c_delay[ADD_LAT-1] <<< ALIGN_BP; // align binary point for addition

    m_reg <= a*b;
    multadd <= m_reg + c;
  end

assign dout.data = multadd;

endmodule : alpaca_multadd

/****************************************************
  test synth top
****************************************************/
import alpaca_constants_pkg::*;

module alpaca_multadd_top (
  input wire logic clk,
  input wire logic rst,
  input wire sample_t a,
  input wire phase_t  b,
  input wire sample_t c,

  output phase_mac_t d
);

fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) a_in(), c_in();
fp_data #(.dtype(phase_t), .W(PHASE_WIDTH), .F(PHASE_FRAC_WIDTH)) b_in();
fp_data #(.dtype(phase_mac_t), .W(WIDTH+PHASE_WIDTH+1), .F(FRAC_WIDTH+PHASE_FRAC_WIDTH)) dout();

assign a_in.data = a;
assign b_in.data = b;
assign c_in.data = c;

assign d = dout.data;

alpaca_multadd DUT (.*);

endmodule : alpaca_multadd_top

