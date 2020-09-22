`timescale 1ns/1ps
`default_nettype none

// Complex Multiplier (pr+i.pi) = (ar+i.ai)*(br+i.bi)

// uses three multipler structure resulting in the inference of 3 DSPs. If a faster clock freq
// is required a 4  multipler structure would be preferred

module cmult_sv #(
  parameter AWIDTH = 16,
  parameter BWIDTH = 18
) (
  input wire logic clk,
  input wire logic signed [AWIDTH-1:0] ar, ai,
  input wire logic signed [BWIDTH-1:0] br, bi,
  output logic signed [AWIDTH+BWIDTH:0] pr, pi
);

logic signed [AWIDTH-1:0] ai_d, ai_dd, ai_ddd, ai_dddd; 
logic signed [AWIDTH-1:0] ar_d, ar_dd, ar_ddd, ar_dddd; 
logic signed [BWIDTH-1:0] bi_d, bi_dd, bi_ddd, br_d, br_dd, br_ddd; 
logic signed [AWIDTH:0]  addcommon; 
logic signed [BWIDTH:0]  addr, addi; 
logic signed [AWIDTH+BWIDTH:0] mult0, multr, multi, pr_int, pi_int; 
logic signed [AWIDTH+BWIDTH:0] common, commonr1, commonr2; 
  
always_ff @(posedge clk) begin
  ar_d   <= ar;
  ar_dd  <= ar_d;
  ai_d   <= ai;
  ai_dd  <= ai_d;
  br_d   <= br;
  br_dd  <= br_d;
  br_ddd <= br_dd;
  bi_d   <= bi;
  bi_dd  <= bi_d;
  bi_ddd <= bi_dd;
end
 
// Common factor (ar ai) x bi, shared for the calculations of the real and imaginary final
// products
always_ff @(posedge clk) begin
  addcommon <= ar_d - ai_d;
  mult0     <= addcommon * bi_dd;
  common    <= mult0;
end

// Real product
always_ff @(posedge clk) begin
  ar_ddd   <= ar_dd;
  ar_dddd  <= ar_ddd;
  addr     <= br_ddd - bi_ddd;
  multr    <= addr * ar_dddd;
  commonr1 <= common;
  pr_int   <= multr + commonr1;
end

// Imaginary product
always_ff @(posedge clk) begin
  ai_ddd   <= ai_dd;
  ai_dddd  <= ai_ddd;
  addi     <= br_ddd + bi_ddd;
  multi    <= addi * ai_dddd;
  commonr2 <= common;
  pi_int   <= multi + commonr2;
end

assign pr = pr_int;
assign pi = pi_int;
   
endmodule : cmult_sv
