`timescale 1ns/1ps
`default_nettype none

/*********************************
  TYPE DEFINITIONS
**********************************/

parameter int WIDTH = 16;
parameter int FRAC_WIDTH = WIDTH-1;

typedef logic signed [WIDTH-1:0] sample_t;
typedef logic signed [WIDTH+WIDTH:0] mac_t;

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
  localparam lsb_scale = 1.0/2**(f);
  localparam DATFMT = $psprintf("%%%0d%0s",$ceil(W/4.0), "X");
  localparam FPFMT = "%f";

  dtype data;

  modport I (input data);
  modport O (output data);

  function string print();
    automatic string s = $psprintf("{data: 0x%s, fp:%s}", DATFMT, FPFMT);
    return $psprintf(s, data, $itor(data)*lsb_scale);
  endfunction

endinterface : fp_data

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
typedef a_in.data_t data_t;
typedef dout.data_t result_t; 

localparam aw = a_in.w;
localparam af = a_in.f;

localparam bw = b_in.w;
localparam bf = b_in.f;

localparam cw = c_in.w;
localparam cf = c_in.f;

localparam doutw = dout.w;
localparam doutf = dout.f;

localparam mult_result_w = a_in.w + b_in.w;
localparam mult_result_f = b_in.f + b_in.f;

localparam module_result_w = mult_result_w + 1; // multiplication plus one bit for the addition
localparam module_result_f = mult_result_f;

initial begin
  assert (module_result_w== doutw)
    $display("module arithmitec res=%0d, outw=%0d", module_result_w, doutw);
  else
    $display("module arithmitec res=%0d, outw=%0d", module_result_w, doutw);
end

////////////

localparam ALIGN_BP = mult_result_f - cf;
localparam MULT_LAT = 2;
localparam ADD_LAT = 2+1;

data_t [MULT_LAT-1:0] a_delay, b_delay;
data_t [ADD_LAT-1:0] c_delay;
data_t a, b;

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
    b <= a_delay[MULT_LAT-1];
    c <= c_delay[ADD_LAT-1] <<< ALIGN_BP; // align binary point for addition

    m_reg <= a*b;
    multadd <= m_reg + c;
  end

assign dout.data = multadd;

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

parameter real WL = 2*WIDTH+1;       // result word len (growth due to multiplication and one add)
parameter real FWL = FRAC_WIDTH*2;   // fractional length (bits right of decimal)
parameter real IWL = WL-FWL;         // integer word length (bits left of decimal)
parameter real lsb_scale = 2**(-FWL);// weight of a single fractional bit

module multadd_tb();

logic clk, rst;

fp_data #(.dtype(sample_t), .W(WIDTH), .F(FRAC_WIDTH)) a_in(), b_in(), c_in();
fp_data #(.dtype(mac_t), .W(WIDTH*2+1), .F(FRAC_WIDTH*2)) dout();

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
  tb_start_val = 1.0/2**(FRAC_WIDTH);
  start_val = 1;

  rst <= 1;
  a_in.data <= start_val; b_in.data <= start_val; c_in.data <= start_val;
  @(posedge clk);
  @(negedge clk); rst = 0;
  a_tb = tb_start_val; b_tb = tb_start_val; c_tb = tb_start_val; expected = 0;

  for (int i=0; i<DUT_LAT; i++) begin
    wait_cycles();
    if (dout.data != expected | dout.data === 'x) begin
      errors++;
      $display("%sT=%4d: {expected: 0x%0X, observed: 0x%0X}%s",
                RED, simcycles, expected, dout.data, RST);
    end else begin
      $display("%sT=%4d: {expected: 0x%0X, observed: 0x%0X}%s",
                GRN, simcycles, expected, dout.data, RST);
    end

    @(negedge clk);
    a_in.data += 1; b_in.data+=1; c_in.data+=1;

  end

  expected = a_tb*a_tb + c_tb;
  for (int i=0; i < END; i++) begin
    wait_cycles();
    //$display("{dout bits: 0x%8X}, fp: %f", dout.data, $itor(dout.data)*lsb_scale);
    $display(dout.print());
    $display("{expected: 0x%9X}, fp: %f", $rtoi(expected/lsb_scale), expected);
    
    @(negedge clk);
    a_in.data += 1; b_in.data+=1; c_in.data+=1;
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
