module BindFiles;
  bind DelayBuf sr_if #(
                  .WIDTH(WIDTH),
                  .SRLEN(1)
                ) probe (
                  .shiftReg(headReg)
                );

  bind SRLShiftReg sr_if #(
                    .WIDTH(WIDTH),
                    .SRLEN(DEPTH) // DEPTH really SRLEN in SRLShiftReg
                   ) probe (
                    .shiftReg(shiftReg)
                   );

  bind PE pe_if #(
            .WIDTH(WIDTH),
            .COEFF_WID(COEFF_WID)
          ) probe (
            .h(h),
            .a(a)
          );

/*
  bind src_ctr src_if #(
                 .MAX_CNT(MAX_CNT)
               ) probe (
                 .clk(clk),
                 .dout(ctr)
               );
*/          
endmodule
