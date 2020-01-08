`timescale 1ns / 1ps
`default_nettype none

module dpfifo #(DEPTHA=512, DEPTHB=1024, WIDTH=16) (
  input wire logic clk,
  input wire logic rst,
  input wire logic [(WIDTH-1):0] dina, // data in for delay line
  input wire logic [(WIDTH-1):0] dinb, // partial sum in
  output logic [(WIDTH-1):0] douta,    // data out from delay line
  output logic [(WIDTH-1):0] doutb
);

typedef enum logic {WAIT, PUSHPOP, ERR='X} stateType;
stateType csa, csb, nsa, nsb;

logic [$clog2(DEPTHA)-1:0] wAddra, rAddra;
logic [$clog2(DEPTHB)-1:0] wAddrb, rAddrb;

logic wena, wenb, rena, renb;

logic [(WIDTH-1):0] ram [(DEPTHA+DEPTHB)];

always_ff @(posedge clk)
  csa <= nsb;

always_ff @(posedge clk)
  if (rst)
    wAddra <= '0;
  else begin
    if (wena) begin
      ram[wAddra] <= dina;
      if (wAddra == (DEPTHA-1))
        wAddra <= '0;
      else
        wAddra <= wAddra + 1;
    end

    if (rena)
      douta <= ram[rAddra];
  end

always_ff @(posedge clk)
  if (rst)
   wAddrb <= '0;
  else begin
    if (wenb) begin
      ram[(DEPTHA+wAddrb)] <= dinb;
      if (wAddrb == (DEPTHB-1))
        wAddrb <= '0;
      else
        wAddrb <= wAddrb + 1;
    end

    if (renb)
      doutb <= ram[(DEPTHA+wAddrb)];
  end

always_comb begin
  nsa = WAIT;
  wena = 0;
  rena = 0;

  if (rst)
    nsa = WAIT;
  else
    case (csa)
      WAIT: begin
        wena = 1;
        if (wAddra == (DEPTHA-1))
          nsa = PUSHPOP;
      end
      PUSHPOP: begin
        wena = 1;
        rena = 1;
        nsa = PUSHPOP;
      end
    endcase // csb
end

always_comb begin
  nsb = WAIT;
  wenb = 0;
  renb = 0;

  if (rst)
    nsb = WAIT;
  else
    case (csb)
      WAIT: begin
        wenb = 1;
        if (wAddrb == (DEPTHB-1))
          nsb = PUSHPOP;
      end
      PUSHPOP: begin
        wenb = 1;
        renb = 1;
        nsb = PUSHPOP;
      end
    endcase // csb
end

endmodule






