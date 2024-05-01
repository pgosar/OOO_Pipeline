`include "data_structures.sv"

module reg_module (
    // Timing
    input logic in_clk,
    input logic in_rst,
    // Inputs from decode (consumed in decode)
    input logic in_d_done,
    // Inputs from decode (passed through or used)
    input logic in_d_set_nzcv,
    input logic in_d_use_imm,
    input logic [`IMMEDIATE_SIZE-1:0] in_d_imm,
    input logic [`GPR_IDX_SIZE-1:0] in_d_src1,
    input logic [`GPR_IDX_SIZE-1:0] in_d_src2,
    input logic [`GPR_IDX_SIZE-1:0] in_d_dst,
    input fu_t in_d_fu_id,
    input fu_op_t in_d_fu_op,
    input logic in_d_instr_uses_nzcv,
    input cond_t in_d_cond_codes,
    // Inputs from ROB (for a commit)
    input logic in_rob_should_commit,
    input logic in_rob_set_nzcv,
    input nzcv_t in_rob_nzcv,
    input logic [`GPR_SIZE-1:0] in_rob_commit_value,
    input logic [`GPR_IDX_SIZE-1:0] in_rob_reg_index,
    input logic [`ROB_IDX_SIZE-1:0] in_rob_commit_rob_index,
    // Inputs from ROB (to show which ROB entry an invalid GPR is in)
    input logic [`ROB_IDX_SIZE-1:0] in_rob_next_rob_index,
    // Outputs for ROB
    output logic out_rob_done,  // A
    output logic out_rob_src1_valid,  // AA
    output logic out_rob_src2_valid,  // AB
    output logic out_rob_nzcv_valid,  // AC
    output logic [`GPR_IDX_SIZE-1:0] out_rob_dst,  // AD
    output logic [`ROB_IDX_SIZE-1:0] out_rob_src1_rob_index,  // AAA
    output logic [`ROB_IDX_SIZE-1:0] out_rob_src2_rob_index,  // ABA
    output logic [`ROB_IDX_SIZE-1:0] out_rob_nzcv_rob_index,  // ACA
    output logic [`GPR_SIZE-1:0] out_rob_src1_value,  // AAB
    output logic [`GPR_SIZE-1:0] out_rob_src2_value,  // ABB
    output logic out_rob_instr_uses_nzcv,  // AE
    output nzcv_t out_rob_nzcv,  // AEA
    output logic out_rob_set_nzcv,  // AF
    output fu_t out_rob_fu_id,  // AG
    // Outputs for FU (rob)
    output fu_op_t out_rob_fu_op,  // AH
    output cond_t out_rob_cond_codes

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
  logic d_done;
  logic [`GPR_IDX_SIZE-1:0] d_src1;
  logic [`GPR_IDX_SIZE-1:0] d_src2;
  logic [`GPR_IDX_SIZE-1:0] d_dst;
  logic [`GPR_IDX_SIZE-1:0] rob_next_rob_index;
  logic d_set_nzcv;
  logic [`GPR_SIZE-1:0] d_imm;
  logic d_use_imm;
  logic [`GPR_IDX_SIZE-1:0] src1_rob_index;
  logic [`GPR_IDX_SIZE-1:0] src2_rob_index;
  fu_op_t d_fu_op;

  // Commit & buffer inputs
  always_ff @(posedge in_clk) begin
    if (in_rst) begin
      `DEBUG(("(regfile) Resetting"));
      // Reset root control signal
      d_done <= 0;
      // Reset internal state
      nzcv_valid <= 1;
      for (int i = 0; i < `GPR_COUNT; i++) begin
        gprs[i].valid <= 1;
      end
    end else begin
      d_done <= in_d_done;
      if (in_d_done) begin
        // Buffer inputs
        d_src1 <= in_d_src1;
        d_src2 <= in_d_src2;
        d_dst <= in_d_dst;
        d_set_nzcv <= in_d_set_nzcv;
        d_imm <= in_d_imm;
        d_use_imm <= in_d_use_imm;
        d_fu_op <= in_d_fu_op;
        rob_next_rob_index <= in_rob_next_rob_index;
        // Copy unused signals
        out_rob_fu_op <= in_d_fu_op;
        out_rob_fu_id <= in_d_fu_id;
        out_rob_instr_uses_nzcv <= in_d_instr_uses_nzcv;
        out_rob_cond_codes <= in_d_cond_codes;
      end
      if (d_done) begin
        // update validity of previous cycle's dst.
        gprs[d_dst].valid <= 0;
        gprs[d_dst].rob_index <= in_rob_next_rob_index;
        if (d_set_nzcv) begin
          nzcv_valid <= 0;
          nzcv_rob_index <= in_rob_next_rob_index;
        end
      end
      // Commit
      if (in_rob_should_commit & (in_rob_commit_rob_index == gprs[in_rob_reg_index].rob_index)) begin : rob_commit
        gprs[in_rob_reg_index].value <= in_rob_commit_value;
        gprs[in_rob_reg_index].valid <= 1;
        if (in_rob_set_nzcv) begin
          `DEBUG(("Setting nzcv %4b", in_rob_nzcv));
          nzcv <= in_rob_nzcv;
          nzcv_valid <= 1;
        end

        `DEBUG(("(regfile) Request to commit to GPR[%0d] -> %0d", in_rob_reg_index, $signed(
               in_rob_commit_value)));
        `DEBUG(
            ("(regfile) \tGPR ROB: %0d, Sending ROB: %0d", in_rob_commit_rob_index,
               gprs[in_rob_reg_index].rob_index));
      end : rob_commit
    end
  end

  always_ff @(posedge in_clk) begin
    #1
    // Buffer old rob indices first....
    src1_rob_index <= gprs[d_src1].rob_index;
    src2_rob_index <= gprs[d_src2].rob_index;
  end

  // Update internal state using external inputs
  always_ff @(posedge in_clk) begin
    #5  // Ugh, Verilator doees not signals to be driven on both the posedge
        // and negedge clk. the bastard.
    if (d_done) begin
      // gprs[d_dst].valid <= 0;
      // gprs[d_dst].rob_index <= in_rob_next_rob_index;
      // if (d_set_nzcv) begin
      //   nzcv_valid <= 0;
      //   nzcv_rob_index <= in_rob_next_rob_index;
      // end


      `DEBUG(
          ("(regfile) src1 wanted from GPR[%0d] = %0d, valid: %0d, rob_index: %0d", d_src1,
             out_rob_src1_value, out_rob_src1_valid, out_rob_src1_rob_index));
      if (d_use_imm) begin
        `DEBUG(("(regfile) src2 using immediate: %0d", d_imm));
      end else begin
        `DEBUG(
            ("(regfile) src2 wanted from GPR[%0d] = %0d, valid: %0d, rob_index: %0d", d_src2,
               gprs[d_src2].value, gprs[d_src2].valid,
               d_src2 == d_dst ? src2_rob_index : gprs[d_src2].rob_index));
      end
      `DEBUG(
          ("(regfile) Dispatch dest GPR[%0d] renamed to ROB[%0d]", d_dst, in_rob_next_rob_index));
    end
  end

  // Set outputs
  always_comb begin
    out_rob_done = d_done;
    // Src 1 - With LDUR/STUR, src1 contains base address. If src1 is not
    // available
    out_rob_src1_valid = gprs[d_src1].valid;
    out_rob_src1_rob_index = (d_dst == d_src1) ? src1_rob_index : gprs[d_src1].rob_index;
    if (d_fu_op == FU_OP_STUR | d_fu_op == FU_OP_STUR) begin
      if (gprs[d_src1].valid) begin
        out_rob_src1_value = gprs[d_src1].value + d_imm;
      end else begin
        out_rob_src1_value = d_imm;
      end
    end else begin
      out_rob_src1_value = gprs[d_src1].value;
    end
    // Src2 - With LDUR, the immediate is the offset.
    //      - With STUR, src2 contains value to store. immediate contains the offset
    if (d_use_imm) begin
      out_rob_src2_value = d_imm;
      out_rob_src2_valid = 1;
    end else begin
      out_rob_src2_valid = gprs[d_src2].valid;
      out_rob_src2_value = gprs[d_src2].value;
    end
    out_rob_src2_rob_index = (d_dst == d_src2) ? src2_rob_index : gprs[d_src2].rob_index;
    // NZCV
    out_rob_nzcv_valid = nzcv_valid;
    // out_rob_src2_rob_index = d_dst == d_src2 ? dst_rob_index : gprs[d_src2].rob_index;
    out_rob_nzcv_rob_index = nzcv_rob_index;
    out_rob_nzcv = nzcv;
    out_rob_set_nzcv = d_set_nzcv;
    // Dst
    out_rob_dst = d_dst;
  end

endmodule
