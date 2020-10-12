`timescale 1ns/1ps
`default_nettype none

import cx_types_pkg::*;
/****************************************************
  TESTBENCH
****************************************************/

typedef struct {
  real re;
  real im;
} tb_cx_t;

function tb_cx_t cx_mult(real ar, ai, br, bi);
  tb_cx_t z;
  z.re = ar*br - ai*bi;
  z.im = ar*bi + ai*br;
  return z;
endfunction

parameter int DUT_LAT = 7;

parameter real WL = (WIDTH+PHASE_WIDTH)+1;          // result word len (growth due to multiplication and one add)
parameter real FWL = (FRAC_WIDTH+PHASE_FRAC_WIDTH); // fractional length (bits right of decimal)
parameter real IWL = WL-FWL;                        // integer word length (bits left of decimal)
parameter real lsb_scale = 2**(-FWL);               // weight of a single fractional bit

module cx_multadd_tb();

logic clk, rst;

fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) ar_in(), ai_in(), cr_in(), ci_in();
fp_data #(.dtype(phase_t), .W(PHASE_WIDTH), .F(PHASE_FRAC_WIDTH)) br_in(), bi_in();
fp_data #(.dtype(phase_mac_t), .W(WIDTH+PHASE_WIDTH+1), .F(FRAC_WIDTH+PHASE_FRAC_WIDTH)) add_dout_re(), add_dout_im();
fp_data #(.dtype(phase_mac_t), .W(WIDTH+PHASE_WIDTH+1), .F(FRAC_WIDTH+PHASE_FRAC_WIDTH)) sub_dout_re(), sub_dout_im();

clk_generator #(.PERIOD(PERIOD)) clk_gen_int (.*);
alpaca_cx_multadd DUT (.*);

task wait_cycles(int cycles=1);
  repeat(cycles)
    @(posedge clk);
endtask

int simcycles;
initial begin
  simcycles=0;
  forever @(posedge clk)
    simcycles += (1 & clk);// & ~rst;
end

// main initial block
initial begin
  int errors;
  sample_t start_val_re;
  sample_t start_val_im;

  real tb_data_start_val;
  real tb_phase_start_val;
  tb_cx_t tmp;
  tb_cx_t a_tb, b_tb, c_tb;
  tb_cx_t add_expected;
  tb_cx_t sub_expected;

  // this tb still doesn't get it right because the moudle will roll over but the real values
  // will not. so this is only good for a few steps.
  tb_data_start_val  = 1.0/2**(FRAC_WIDTH);
  tb_phase_start_val = 1.0/2**(PHASE_FRAC_WIDTH);
  //tb_start_val = 1.0/2**(FRAC_WIDTH);

  start_val_re = 1;
  start_val_im = 1;

  rst <= 1;
  ar_in.data <= start_val_re; br_in.data <= start_val_re; cr_in.data <= start_val_re;
  ai_in.data <= start_val_im; bi_in.data <= start_val_im; ci_in.data <= start_val_im;
  @(posedge clk);
  @(negedge clk); rst = 0;
  a_tb.re = tb_data_start_val; b_tb.re = tb_phase_start_val; c_tb.re = tb_data_start_val; add_expected.re = 0; sub_expected.re = 0;
  a_tb.im = tb_data_start_val; b_tb.im = tb_phase_start_val; c_tb.im = tb_data_start_val; add_expected.im = 0; sub_expected.im = 0;

  for (int i=0; i<DUT_LAT; i++) begin
    wait_cycles();
    if (add_dout_re.data != add_expected.re | add_dout_re.data === 'x) begin
      errors++;
      $display("%sT=%4d: {add_expected: 0x%0X, observed: 0x%0X}%s",
                RED, simcycles, add_expected.re, add_dout_re.data, RST);
    end else begin
      $display("%sT=%4d: {add_expected: 0x%0X, observed: 0x%0X}%s",
                GRN, simcycles, add_expected.re, add_dout_re.data, RST);
    end

    @(negedge clk);
    ar_in.data += 1; br_in.data+=1; cr_in.data+=1;
    ai_in.data += 1; bi_in.data+=1; ci_in.data+=1;

  end

  tmp = cx_mult(a_tb.re, a_tb.im, b_tb.re, b_tb.im);
  add_expected.re = tmp.re + c_tb.re;
  add_expected.im = tmp.im + c_tb.im;
  sub_expected.re = tmp.re - c_tb.re;
  sub_expected.im = tmp.im - c_tb.im;

  for (int i=0; i < END; i++) begin
    wait_cycles();
    $display({$psprintf("T=%4d", simcycles), ": add testbench: {real: ", add_dout_re.print_data_fp(), ", imag: ", add_dout_im.print_data_fp()}, "}");
    $display( "T=%4d: add expected:  {real: %f, imag: %f}\n", simcycles, add_expected.re, add_expected.im);
    $display({$psprintf("T=%4d", simcycles), ": sub testbench: {real: ", sub_dout_re.print_data_fp(), ", imag: ", sub_dout_im.print_data_fp()}, "}");
    $display( "T=%4d: sub expected:  {real: %f, imag: %f}\n", simcycles, sub_expected.re, sub_expected.im);
    //0x%9X , $rtoi(expected.re/lsb_scale)
    @(negedge clk);
    ar_in.data += 1; br_in.data+=1; cr_in.data+=1;
    ai_in.data += 1; bi_in.data+=1; ci_in.data+=1;
    a_tb.re += tb_data_start_val; b_tb.re+=tb_phase_start_val; c_tb.re+=tb_data_start_val;
    a_tb.im += tb_data_start_val; b_tb.im+=tb_phase_start_val; c_tb.im+=tb_data_start_val;

    tmp = cx_mult(a_tb.re, a_tb.im, b_tb.re, b_tb.im);
    add_expected.re = tmp.re + c_tb.re;
    add_expected.im = tmp.im + c_tb.im;
    sub_expected.re = tmp.re - c_tb.re;
    sub_expected.im = tmp.im - c_tb.im;

  end

  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;

end

endmodule : cx_multadd_tb


