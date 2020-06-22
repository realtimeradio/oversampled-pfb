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
endmodule
