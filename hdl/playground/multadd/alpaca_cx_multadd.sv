`timescale 1ns/1ps
`default_nettype none

/*********************************
  TYPE DEFINITIONS
**********************************/

parameter int WIDTH = 8;
parameter int FRAC_WIDTH = WIDTH-1;

parameter int PHASE_WIDTH = 15;
parameter int PHASE_FRAC_WIDTH = PHASE_WIDTH-1;

typedef logic signed [WIDTH-1:0] sample_t;
typedef logic signed [PHASE_WIDTH-1:0] phase_t;

typedef logic signed [WIDTH+PHASE_WIDTH:0] mac_t;

interface fp_data #(
  parameter type dtype = sample_t,
  parameter int W=WIDTH,
  parameter int F=FRAC_WIDTH
) ();

  // information for derived modules
  localparam w=W;
  localparam f=F;
  typedef dtype data_t;

  // display parameters
  localparam real lsb_scale = 1.0/(2**f);
  localparam DATFMT = $psprintf("%%%0d%0s",$ceil(W/4.0), "X");
  localparam FPFMT = "%f";

  // interface signals
  dtype data;

  // modports
  modport I (input data);
  modport O (output data);

  // convenience functions for testbench

  // return bits and scaled fixed-point interpretation of the data
  function string print_all();
    automatic string s = $psprintf("{data: 0x%s, fp:%s}", DATFMT, FPFMT);
    return $psprintf(s, data, $itor(data)*lsb_scale);
  endfunction

  // return fixed-point interpretation of the data
  function string print_data_fp();
    automatic string s = $psprintf("%s", FPFMT);
    return $psprintf(s, $itor(data)*lsb_scale);
  endfunction

endinterface : fp_data

/*******************************************************************
  Multiply add

  perform a complex multiplication followed by an addition
  dout = A*B + C
  Where A,B and C are complex numbers
********************************************************************/

module alpaca_cx_multadd (
  input wire logic clk,
  input wire logic rst,
  fp_data.I ar_in, ai_in,
  fp_data.I br_in, bi_in,
  fp_data.I cr_in, ci_in,

  fp_data.O dout_re, dout_im
);

// gather fixed point parameters to perform and check calculation widths
typedef ar_in.data_t a_data_t;
typedef br_in.data_t b_data_t;
typedef cr_in.data_t c_data_t;

typedef dout_re.data_t result_t; 

localparam aw = ar_in.w;
localparam af = ar_in.f;

localparam bw = br_in.w;
localparam bf = br_in.f;

localparam cw = cr_in.w;
localparam cf = cr_in.f;

localparam doutw = dout_re.w;
localparam doutf = dout_re.f;

localparam mult_result_w = aw + bw;
localparam mult_result_f = af + bf;

localparam multadd_result_w = mult_result_w + 1; // multiplication plus one bit for the addition
localparam multadd_result_f = mult_result_f;

// check widths of input interfaces
initial begin
  assert (multadd_result_w== doutw) begin
    $display("module arithmitec res=%0d, outw=%0d", multadd_result_w, doutw);
    $display("binary point adjust: %0d", mult_result_f - cf);
  end else
    $display("module arithmitec res=%0d, outw=%0d", multadd_result_w, doutw);
end
///////////////////////////////////

localparam ALIGN_BP = mult_result_f - cf;
localparam A_LAT = 4;
localparam B_LAT = A_LAT-1;
localparam C_LAT = A_LAT+1;

a_data_t [A_LAT-1:0] ar_delay, ai_delay;
b_data_t [B_LAT-1:0] br_delay, bi_delay;
c_data_t [C_LAT-1:0] cr_delay, ci_delay;

logic signed [bw:0] add_re, add_im;
logic signed [aw:0] addcommon;

result_t m_reg_common, m_reg_common_d;
result_t common_im, common_re;
result_t m_reg_re, m_reg_im;  // register intermediate multiplication output

result_t c_re, c_im;

result_t cxmult_re, cxmult_im;
result_t multadd_re, multadd_im;

// generate common factor for 3 dsp slice implementation
always_ff @(posedge clk) begin
  if (rst) begin
    addcommon <= '0;
    m_reg_common <= '0;
    m_reg_common_d <= '0;
  end else begin
    addcommon <= ar_delay[0] - ai_delay[0];

    m_reg_common <= addcommon * bi_delay[B_LAT-2];
    m_reg_common_d <= m_reg_common;
  end
end

// real products
always_ff @(posedge clk) begin
  if (rst) begin
    ar_delay <= '0; br_delay <= '0; cr_delay <= '0;
    add_re <= '0;
    m_reg_re <= '0;
    common_re <= '0;
    cxmult_re <= '0;
    c_re <= '0;
    multadd_re <= '0;
  end else begin
    ar_delay <= {ar_delay[A_LAT-2:0], ar_in.data};
    br_delay <= {br_delay[B_LAT-2:0], br_in.data};
    cr_delay <= {cr_delay[C_LAT-2:0], cr_in.data};

    add_re <= br_delay[B_LAT-1] - bi_delay[B_LAT-1];

    m_reg_re <= ar_delay[A_LAT-1]*add_re;
    common_re <= m_reg_common_d;

    cxmult_re <= m_reg_re + common_re;
    c_re <= cr_delay[C_LAT-1] <<< ALIGN_BP; // align binary point for addition

    multadd_re <= cxmult_re + c_re;
  end
end

// imaginary products
always_ff @(posedge clk) begin
  if (rst) begin
    ai_delay <= '0; bi_delay <= '0; ci_delay <= '0;
    add_im <= '0;
    m_reg_im <= '0;
    common_im <= '0;
    cxmult_im <= '0;
    c_im <= '0;
    multadd_im <= '0;

  end else begin
    ai_delay <= {ai_delay[A_LAT-2:0], ai_in.data};
    bi_delay <= {bi_delay[B_LAT-2:0], bi_in.data};
    ci_delay <= {ci_delay[C_LAT-2:0], ci_in.data};

    add_im <= bi_delay[B_LAT-1] + bi_delay[B_LAT-1];

    m_reg_im <= ai_delay[A_LAT-1]*add_im;
    common_im <= m_reg_common_d;

    cxmult_im <= m_reg_im + common_im;
    c_im <= ci_delay[C_LAT-1] <<< ALIGN_BP; // align binary point for addition

    multadd_im <= cxmult_im + c_im;
  end
end

assign dout_re.data = multadd_re;
assign dout_im.data = multadd_im;

endmodule : alpaca_cx_multadd

/******************
  TESTBENCH
******************/

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

// display constants
parameter string RED = "\033\[0;31m";
parameter string GRN = "\033\[0;32m";
parameter string MGT = "\033\[0;35m";
parameter string RST = "\033\[0m";

parameter int PERIOD = 10;
parameter int DUT_LAT = 7;
parameter int END = 20;

parameter real WL = (WIDTH+PHASE_WIDTH)+1;          // result word len (growth due to multiplication and one add)
parameter real FWL = (FRAC_WIDTH+PHASE_FRAC_WIDTH); // fractional length (bits right of decimal)
parameter real IWL = WL-FWL;                        // integer word length (bits left of decimal)
parameter real lsb_scale = 2**(-FWL);               // weight of a single fractional bit

module cx_multadd_tb();

logic clk, rst;

fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) ar_in(), ai_in(), cr_in(), ci_in();
fp_data #(.dtype(sample_t), .W(PHASE_WIDTH), .F(PHASE_FRAC_WIDTH)) br_in(), bi_in();
fp_data #(.dtype(mac_t), .W(WIDTH+PHASE_WIDTH+1), .F(FRAC_WIDTH+PHASE_FRAC_WIDTH)) dout_re(), dout_im();

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
  tb_cx_t expected;

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
  a_tb.re = tb_data_start_val; b_tb.re = tb_phase_start_val; c_tb.re = tb_data_start_val; expected.re = 0;
  a_tb.im = tb_data_start_val; b_tb.im = tb_phase_start_val; c_tb.im = tb_data_start_val; expected.im = 0;

  for (int i=0; i<DUT_LAT; i++) begin
    wait_cycles();
    if (dout_re.data != expected.re | dout_re.data === 'x) begin
      errors++;
      $display("%sT=%4d: {expected: 0x%0X, observed: 0x%0X}%s",
                RED, simcycles, expected.re, dout_re.data, RST);
    end else begin
      $display("%sT=%4d: {expected: 0x%0X, observed: 0x%0X}%s",
                GRN, simcycles, expected.re, dout_re.data, RST);
    end

    @(negedge clk);
    ar_in.data += 1; br_in.data+=1; cr_in.data+=1;
    ai_in.data += 1; bi_in.data+=1; ci_in.data+=1;

  end

  tmp = cx_mult(a_tb.re, a_tb.im, b_tb.re, b_tb.im);
  expected.re = tmp.re + c_tb.re;
  expected.im = tmp.im + c_tb.im;
  for (int i=0; i < END; i++) begin
    wait_cycles();
    $display({$psprintf("T=%4d", simcycles), ": testbench: {real: ", dout_re.print_data_fp(), ", imag: ", dout_im.print_data_fp()}, "}");
    $display( "T=%4d: expected:  {real: %f, imag: %f}\n", simcycles, expected.re, expected.im);
    //0x%9X , $rtoi(expected.re/lsb_scale)
    @(negedge clk);
    ar_in.data += 1; br_in.data+=1; cr_in.data+=1;
    ai_in.data += 1; bi_in.data+=1; ci_in.data+=1;
    a_tb.re += tb_data_start_val; b_tb.re+=tb_phase_start_val; c_tb.re+=tb_data_start_val;
    a_tb.im += tb_data_start_val; b_tb.im+=tb_phase_start_val; c_tb.im+=tb_data_start_val;

    tmp = cx_mult(a_tb.re, a_tb.im, b_tb.re, b_tb.im);
    expected.re = tmp.re + c_tb.re;
    expected.im = tmp.im + c_tb.im;
  end

  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;

end

endmodule : cx_multadd_tb


