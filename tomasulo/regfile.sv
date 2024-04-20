`include "data_structures.sv"

module regfile_module (
    // Clock
    input logic in_clk,
    input logic in_rst,
    // Inputs from ROB
    input logic in_rob_should_commit,
    input logic [`GPR_SIZE-1:0] in_rob_commit_value,
    input logic [`GPR_IDX_SIZE-1:0] in_rob_regfile_index,
    // Inputs from Dispatch
    input logic in_dispatch_should_read,  // UNUSED: But this would be good for energy
    input logic [`GPR_IDX_SIZE-1:0] in_d_op1,
    input logic [`GPR_IDX_SIZE-1:0] in_d_op2,
    // Outputs for Dispatch
    output logic [`GPR_SIZE-1:0] out_d_op1,
    output logic [`GPR_SIZE-1:0] out_d_op2
);

  gpr_entry_t [`GPR_SIZE-1:0] gprs;

  integer i;
  always_latch begin
    if (in_rst) begin
`ifdef DEBUG_PRINT
      $display("(regfile) Resetting");
`endif
      for (i = 0; i < `GPR_SIZE; i += 1) begin
        gprs[i] = 0;
      end
    end else begin
      if (in_dispatch_should_read) begin
        gpr_entry_t gpr1;
        gpr_entry_t gpr2;
`ifdef DEBUG_PRINT
        $display("(regfile) Dispatch read GPR[%0d] = %0d", in_d_op1, gprs[in_d_op1]);
`endif
        gpr1 = gprs[in_d_op1];
        gpr2 = gprs[in_d_op2];
        if (gpr1.valid) begin
          out_d_op1 = gpr1.value;
`ifdef DEBUG_PRINT
          $display("(regfile) Dispatch read GPR[%0d] (valid) = %0d", in_d_op1, gpr1.value);
`endif
        end
        if (gpr2.valid) begin
          out_d_op2 = gpr2.value;
`ifdef DEBUG_PRINT
          $display("(regfile) Dispatch read GPR[%0d] (valid) = %0d", in_d_op2, gpr2.value);
`endif

        end
      end
      if (in_rob_should_commit) begin
        gpr_entry_t gpr;
        gpr = gprs[in_rob_regfile_index];
        gpr.value = in_rob_commit_value;
`ifdef DEBUG_PRINT
        $display("(regfile) Committing to GPR[%0d] = %0d", in_rob_regfile_index,
                 in_rob_commit_value);
`endif
      end
    end
  end

endmodule
