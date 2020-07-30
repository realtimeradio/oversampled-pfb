`timescale 1ns/1ps
`default_nettype none

/* synthesis analysis notes

  Both the generate and instance array methods shown below synthesize to the same result. Both
  are able to synthesize parameterized up to ALPACA 2M=4096 deep (granted 1 sample wide -- would
  be another question if we have to process more samples to accomodate fclk).

  However, both of these still use the rst/en signals that would be split every instance and there
  are 64 instances at the ALPACA spec.
*/
module PE_delaybuf #(NUM=64, DEPTH=64, WIDTH=16) (
  input wire logic clk,
  input wire logic rst,
  input wire logic en,
  input wire logic [WIDTH-1:0] din,
  output logic [WIDTH-1:0] dout
);


logic [WIDTH*NUM-1:0] peout;
// note: if there is unconnected hardware synthesis will not pick up the generates and discard
assign dout = peout[WIDTH*NUM-1:WIDTH*(NUM-1)];

genvar i;
generate 
  for (i=1; i<=NUM; i++) begin : generate_delayline
    if (i==1) begin
      PE_ShiftReg #(
        .DEPTH(DEPTH),
        .WIDTH(WIDTH)
      ) pe (
        .clk(clk),
        .rst(rst),
        .en(en),
        .din(din),
        .dout(peout[i*WIDTH-1:(i-1)*WIDTH])
      );
    end
    else begin
      PE_ShiftReg #(
        .DEPTH(DEPTH),
        .WIDTH(WIDTH)
      ) pe (
        .clk(clk),
        .rst(rst),
        .en(en),
        .din(peout[(i-1)*WIDTH-1:(i-2)*WIDTH]),
        .dout(peout[i*WIDTH-1:(i-1)*WIDTH])
      );
    end
  end
endgenerate

// logic [0:NUM-1][WIDTH-1:0] tmpout;
// 
// PE_ShiftReg #(
//   .DEPTH(DEPTH),
//   .WIDTH(WIDTH)
// ) pe[0:NUM-1] (
//   .clk(clk),
//   .rst(rst),
//   .en(en),
//   .din({din, tmpout[0:NUM-2]}),
//   .dout(tmpout)
// );
// 
// assign dout = tmpout[NUM-1];

/* not sure how to make this syntax work since dout needs to be connected to previous din */
// PE_ShiftReg #(
//   .DEPTH(64),
//   .WIDTH(WIDTH)
// ) head (
//   .clk(clk),
//   .rst(rst),
//   .en(en),
//   .din(din),
//   .dout(peout[WIDTH*4-1:WIDTH*3])
// );
// 
// PE_ShiftReg #(
//   .DEPTH(64),
//   .WIDTH(WIDTH)
// ) pe [2:0] (
//   .clk(clk),
//   .rst(rst),
//   .en(en),
//   .din(din),
//   .dout(peout)
// );

// logic [WIDTH-1:0] pe1out;
// logic [WIDTH-1:0] pe2out;
// logic [WIDTH-1:0] pe3out;
// 
// PE_ShiftReg #(
//   .DEPTH(64),
//   .WIDTH(WIDTH)
// ) pe1 (
//   .clk(clk),
//   .rst(rst),
//   .en(en),
//   .din(din),
//   .dout(pe1out)
// );
// 
// PE_ShiftReg #(
//   .DEPTH(64),
//   .WIDTH(WIDTH)
// ) pe2 (
//   .clk(clk),
//   .rst(rst),
//   .en(en),
//   .din(pe1out),
//   .dout(pe2out)
// );
// 
// PE_ShiftReg #(
//   .DEPTH(64),
//   .WIDTH(WIDTH)
// ) pe3 (
//   .clk(clk),
//   .rst(rst),
//   .en(en),
//   .din(pe2out),
//   .dout(pe3out)
// );
// 
// PE_ShiftReg #(
//   .DEPTH(64),
//   .WIDTH(WIDTH)
// ) pe4 (
//   .clk(clk),
//   .rst(rst),
//   .en(en),
//   .din(pe3out),
//   .dout(dout)
// );
endmodule
