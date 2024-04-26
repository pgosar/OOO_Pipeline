`include "data_structures.sv"

module reg_module (
    // Timing
    input logic in_clk,
    input logic in_rst,
    // Inputs from decode (consumed in decode)
    input logic in_d_ready,
    // Inputs from decode (passed through or used)
    input logic in_d_set_nzcv,
    input logic in_d_use_imm,
    input logic [`IMMEDIATE_SIZE-1:0] in_d_imm,
    input logic [`GPR_IDX_SIZE-1:0] in_d_src1,
    input logic [`GPR_IDX_SIZE-1:0] in_d_src2,
    input fu_t in_d_fu_id,
    input alu_op_t in_d_fu_op,
    input logic [`GPR_IDX_SIZE-1:0] in_d_dst,
    // Inputs from ROB (for a commit)
    input logic in_rob_should_commit,
    input logic in_rob_set_nzcv,
    input nzcv_t in_rob_nzcv,
    input logic [`GPR_SIZE-1:0] in_rob_commit_value,
    input logic [`GPR_IDX_SIZE-1:0] in_rob_reg_index,
    input logic [`ROB_IDX_SIZE-1:0] in_rob_commit_rob_index,
    // Outputs for ROB
    output logic out_rob_ready,
    output logic out_rob_src1_valid,
    output logic out_rob_src2_valid,
    output logic out_rob_nzcv_valid,
    output logic [`GPR_IDX_SIZE-1:0] out_rob_dst,  // gpr
    output logic [`ROB_IDX_SIZE-1:0] out_rob_src1_rob_index,
    output logic [`ROB_IDX_SIZE-1:0] out_rob_src2_rob_index,
    output logic [`ROB_IDX_SIZE-1:0] out_rob_nzcv_rob_index,
    output logic [`GPR_SIZE-1:0] out_rob_src1_value,
    output logic [`GPR_SIZE-1:0] out_rob_src2_value,
    output logic out_rob_set_nzcv,
    output nzcv_t out_rob_nzcv,
    // Outputs for RS (rob)
    output fu_t out_rob_fu_id,
    // Outputs for FU (rob)
    output alu_op_t out_rob_fu_op
);

  // TODO(Nate): Add support for setting the output of immediate values or the
  //             zero register. These should always result in a valid value.

  // Commit updates state. Must happen before processing outputs.
  // Must buffer input values.

  // Internal state
  gpr_entry_t [`GPR_SIZE-1:0] gprs;
  nzcv_t nzcv;
  logic nzcv_valid;
  logic [`ROB_IDX_SIZE-1:0] nzcv_rob_index;
  // Buffered inputs
  logic d_ready;
  logic [`GPR_IDX_SIZE-1:0] d_src1;
  logic [`GPR_IDX_SIZE-1:0] d_src2;
  logic [`GPR_IDX_SIZE-1:0] d_dst;
  logic d_set_nzcv;
  logic [`GPR_SIZE-1:0] d_imm;
  logic d_use_imm;
  fu_t fu_id;
  logic delayed_clk;

  always_ff @(posedge in_clk, negedge in_clk) begin
    delayed_clk <= #1 in_clk;
  end

  // Commit & buffer inputs
  always_ff @(posedge in_clk) begin
    if (in_rst) begin
`ifdef DEBUG_PRINT
      $display("(regfile) Resetting");
`endif
      d_ready <= 0;
      gprs <= 0;
    end else begin
      if (in_d_ready) begin
        // Copy over unused signals
        out_rob_dst <= in_d_dst;
        out_rob_set_nzcv <= in_d_set_nzcv;
        out_rob_fu_op <= in_d_fu_op;
        // Commit
        if (in_rob_should_commit && (in_rob_commit_rob_index == gprs[in_rob_reg_index].rob_index)) begin : rob_commit
          gprs[in_rob_reg_index].value <= in_rob_commit_value;
          gprs[in_rob_reg_index].valid <= 1;
          if (in_rob_set_nzcv) begin
            nzcv <= in_rob_nzcv;
            nzcv_valid <= 1;
          end
`ifdef DEBUG_PRINT
          $display("(regfile) Committing to GPR[%0d] = %0d", in_rob_reg_index, in_rob_commit_value);
`endif
        end : rob_commit
      end
      // Buffer unused state
      d_ready <= in_d_ready;
      d_src1 <= in_d_src1;
      d_src2 <= in_d_src2;
      d_dst <= in_d_dst;
      d_set_nzcv <= in_d_set_nzcv;
      d_imm <= in_d_imm;
      d_use_imm <= in_d_use_imm;
      fu_id <= in_d_fu_id;
    end
  end
  // Process buffered state
  always_ff @(posedge delayed_clk) begin

    out_rob_ready <= d_ready;  // Not necessary to buffer, but makes logical sense to wait.
    if (d_ready) begin
`ifdef DEBUG_PRINT
      $display("(regfile) Dispatch read GPR[%0d] = %p", d_src1, gprs[d_src1]);
      $display("(regfile) Dispatch read GPR[%0d] = %p", d_src2, gprs[d_src2]);
`endif

      // Src 1
      out_rob_src1_valid <= gprs[d_src1].valid;
      if (gprs[d_src1].valid) begin
        out_rob_src1_value <= gprs[d_src1].value;
`ifdef DEBUG_PRINT
        $display("(regfile) Dispatch read GPR[%0d] (valid) = %0d", d_src1, gprs[d_src1].value);
`endif
      end else begin
        out_rob_src1_rob_index <= gprs[d_src1].rob_index;
      end

      // Src 2
      out_rob_src1_valid <= gprs[d_src1].valid;
      if (gprs[d_src2].valid) begin
        out_rob_src2_value <= gprs[d_src2].value;
`ifdef DEBUG_PRINT
        $display("(regfile) Dispatch read GPR[%0d] (valid) = %0d", d_src2, gprs[d_src2].value);
`endif
      end else begin
        out_rob_src2_rob_index <= gprs[d_src2].rob_index;
      end

      // nzcv
      out_rob_nzcv_valid <= nzcv_valid;
      if (nzcv_valid) begin
        out_rob_nzcv <= nzcv;
      end else begin
        out_rob_nzcv_rob_index <= nzcv_rob_index;
      end
    end
  end

endmodule
