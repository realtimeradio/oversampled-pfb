`timescale 1ns/1ps
`default_nettype none

/*********************************
  TYPE DEFINITIONS
**********************************/

parameter int WIDTH = 4;

typedef logic signed [WIDTH-1:0] sample_t;
typedef logic signed [WIDTH+WIDTH:0] mac_t;

/**********************************
  Multiply add
***********************************/

module alpaca_multadd (
  input wire logic clk,
  input wire logic rst,

  input wire sample_t a_in,
  input wire sample_t b_in,
  input wire sample_t c_in,

  output mac_t dout
);

localparam BP = 3;
localparam MULT_LAT = 2;
localparam ADD_LAT = 2+1;

sample_t [MULT_LAT-1:0] a_delay, b_delay;
sample_t [ADD_LAT-1:0] c_delay;
sample_t a, b;

mac_t c;
mac_t m_reg;  // register intermediate multiplication output
mac_t multadd;

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
    a_delay <= {a_delay[MULT_LAT-2:0], a_in};
    b_delay <= {b_delay[MULT_LAT-2:0], b_in};
    c_delay <= {c_delay[ADD_LAT-2:0], c_in};

    a <= a_delay[MULT_LAT-1];
    b <= a_delay[MULT_LAT-1];
    c <= (c_delay[ADD_LAT-1] <<< BP); // align binary point for addition

    m_reg <= a*b;
    multadd <= m_reg + c;
  end

  assign dout = multadd;

endmodule : alpaca_multadd

/******************
  TESTBENCH
******************/

// display constants
parameter string RED = "\033\[0;31m";
parameter string GRN = "\033\[0;32m";
parameter string MGT = "\033\[0;35m";
parameter string RST = "\033\[0m";

parameter int PERIOD = 10;
parameter int DUT_LAT = 5;
parameter int END = 20;

parameter real WL = 8;                // word length
parameter real IWL = 2;               // integer word length (bits left of decimal)
parameter real FWL = WL-IWL;          // fractional length (bits right of decimal)
parameter real lsb_scale = 2**(-FWL); // weight of a single fractional bit

module multadd_tb();

logic clk, rst;

sample_t a_in, b_in, c_in;
mac_t dout;

clk_generator #(.PERIOD(PERIOD)) clk_gen_int (.*);
alpaca_multadd DUT (.*);

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
  sample_t start_val;

  real tb_start_val;
  real a_tb, b_tb, c_tb;
  real expected;

  // this tb still doesn't get it right because the moudle will roll over but the real values
  // will not. so this is only good for a few steps.
  tb_start_val = 1.0/2**(3);
  start_val = 1;

  rst <= 1;
  a_in <= start_val; b_in <= start_val; c_in <= start_val;
  @(posedge clk);
  @(negedge clk); rst = 0;
  a_tb = tb_start_val; b_tb = tb_start_val; c_tb = tb_start_val; expected = 0;

  for (int i=0; i<DUT_LAT; i++) begin
    wait_cycles();
    if (dout != expected | dout === 'x) begin
      errors++;
      $display("%sT=%4d: {expected: 0x%0X, observed: 0x%0X}%s",
                RED, simcycles, expected, dout, RST);
    end else begin
      $display("%sT=%4d: {expected: 0x%0X, observed: 0x%0X}%s",
                GRN, simcycles, expected, dout, RST);
    end

    @(negedge clk);
    a_in += 1; b_in+=1; c_in+=1;

  end

  expected = a_tb*a_tb + c_tb;
  for (int i=0; i < END; i++) begin
    wait_cycles();
    $display("{dout bits: 0x%8X}, fp: %f", dout, $itor(dout)*lsb_scale);
    $display("{expected bits: 0x%8X}, fp: %f", $rtoi(expected/lsb_scale), expected);
    
    @(negedge clk);
    a_in += 1; b_in+=1; c_in+=1;
    a_tb += tb_start_val; b_tb+=tb_start_val; c_tb+=tb_start_val;
    expected = a_tb*b_tb + c_tb;
  end

  $display("*** Simulation complete: Errors=%4d ***", errors);
  $finish;

end

endmodule : multadd_tb


/****************
****************/
//module alpaca_multadd_axis (
//  input wire logic clk,
//  input wire logic rst
//);
//
//typedef s_axis.data_t operand_t;
//typedef m_axis.data_t result_t;
//
//localparam AXIS_LAT = MULT_LAT+1;
//
//logic [AXIS_LAT-1:0][1:0] axis_delay; // {tvalid, tlast}
//logic [AXIS_LAT-1:0][$bits(s_axis.tuser)-1:0] axis_tuser_delay;
//
//always_ff @(posedge clk)
//  if (rst)
//    axis_delay <= '0;
//  else
//    axis_delay <= {axis_delay[AXIS_LAT-2:0], {s_axis.tvalid, s_axis.tlast}};
//    axis_tuser_delay <= {axis_tuser_delay[AXIS_LAT-2:0], s_axis.tuser};
//
//// tready???
//  assign m_axis.tdata = multadd;
//  assign m_axis.tvalid = axis_delay[AXIS_LAT-1][1];
//  assign m_axis.tlast = axis_delay[AXIS_LAT-1][0];
//  assign m_axis.tuser = axis_tuser_delay[AXIS_LAT-1];
//
//
//endmodule : alpaca_multadd_axis
