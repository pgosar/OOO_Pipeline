`include "data_structures.sv"

module reg_module (
    // Timing
    input logic in_clk,
    input logic in_rst,
    // Inputs from decode (consumed in decode)
    input decode_interface in_d_sigs,
    // Inputs from ROB (for a commit)
    input rob_commit_interface in_rob_commit_sigs,
    // Inputs from ROB (to show which ROB entry an invalid GPR is in)
    input logic [`ROB_IDX_SIZE-1:0] in_rob_next_rob_index,
    // Outputs for ROB
    output reg_interface out_rob_sigs
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
  // Buffered inputs (from rob)
  logic [`ROB_IDX_SIZE-1:0] rob_next_rob_index;
  logic [`ROB_IDX_SIZE-1:0] src1_rob_index;
  logic [`ROB_IDX_SIZE-1:0] src2_rob_index;
  // Buffered inputs (from decode)
  logic d_done;
  logic d_set_nzcv;
  logic [`IMMEDIATE_SIZE-1:0] d_imm;
  logic [`GPR_IDX_SIZE-1:0] d_src1;
  reg_status_t d_src1_status;
  logic [`GPR_IDX_SIZE-1:0] d_src2;
  reg_status_t d_src2_status;
  fu_t d_fu_id;
  fu_op_t d_fu_op;
  logic [`GPR_IDX_SIZE-1:0] d_dst;
  reg_status_t d_dst_status;
  cond_t d_cond_codes;
  logic d_uses_nzcv;
  logic d_mispredict;
  logic [`GPR_SIZE-1:0] d_pc;

  decode_interface d_sigs ();


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
      d_done <= in_d_sigs.done;
      // Buffer inputs
      if (in_d_sigs.done) begin
        `DEBUG(("(regfile) buffering inputs from decode"))
        // Buffered inputs (from d)
        d_set_nzcv <= in_d_sigs.set_nzcv;
        d_imm <= in_d_sigs.imm;
        d_src1 <= in_d_sigs.src1;
        d_src1_status <= in_d_sigs.src1_status;
        d_src2 <= in_d_sigs.src2;
        d_src2_status <= in_d_sigs.src2_status;
        d_fu_op <= in_d_sigs.fu_op;
        d_dst <= in_d_sigs.dst;
        d_dst_status <= in_d_sigs.dst_status;
        d_cond_codes <= in_d_sigs.cond_codes;
        d_mispredict <= in_d_sigs.mispredict;
        d_uses_nzcv <= in_d_sigs.uses_nzcv;
        // Copy over
        out_rob_sigs.pc <= in_d_sigs.pc;
        out_rob_sigs.fu_id <= in_d_sigs.fu_id;
      end
      // Update validity of previous cycle's dst.
      if (d_done) begin
        `DEBUG(("(regfile) updating prev cycle's dst"))
        gprs[d_dst].valid <= 0;
        gprs[d_dst].rob_index <= in_rob_next_rob_index;
        if (d_set_nzcv) begin
          nzcv_valid <= 0;
          nzcv_rob_index <= in_rob_next_rob_index;
        end
      end
      // Commit
      if (in_rob_commit_sigs.done & (in_rob_commit_sigs.rob_index == gprs[in_rob_commit_sigs.reg_index].rob_index)) begin : rob_commit
        gprs[in_rob_commit_sigs.reg_index].value <= in_rob_commit_sigs.value;
        gprs[in_rob_commit_sigs.reg_index].valid <= 1;
        if (in_rob_commit_sigs.set_nzcv) begin
          `DEBUG(("Setting nzcv %4b", in_rob_commit_sigs.nzcv));
          nzcv <= in_rob_commit_sigs.nzcv;
          nzcv_valid <= 1;
        end
        `DEBUG(
            ("(regfile) Request to commit to GPR[%0d] -> %0d", in_rob_commit_sigs.reg_index, $signed(
            in_rob_commit_sigs.value)));
        `DEBUG(
            ("(regfile) \tGPR ROB: %0d, Sending ROB: %0d", in_rob_commit_sigs.rob_index,
               gprs[in_rob_commit_sigs.reg_index].rob_index));
      end : rob_commit
    end
  end

  always_ff @(posedge in_clk) begin
    #1
    // Buffer old rob indices first....
    src1_rob_index <= gprs[d_src1].rob_index;
    src2_rob_index <= gprs[d_src2].rob_index;
  end

  // Some print statemnts 
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
      `DEBUG((
        "(regfile) src1 read from GPR[%0d] = %0d, valid: %0d, rob_index: %0d, status: %s", 
        d_src1, out_rob_sigs.src1_value, out_rob_sigs.src1_valid, out_rob_sigs.src1_rob_index, d_src1_status.name));

      if (d_src2_status == REG_IS_IMMEDATE) begin
        `DEBUG(("(regfile) src2 using immediate: %0d", d_imm));
      end else begin
        `DEBUG(("(regfile) src2 wanted from GPR[%0d] = %0d, valid: %0d, rob_index: %0d, status: %s", 
            d_src2,
            gprs[d_src2].value, gprs[d_src2].valid,
            d_src2 == d_dst ? src2_rob_index : gprs[d_src2].rob_index,
            d_src2_status.name
        ));
      end
      `DEBUG(("(regfile) Dispatch dest GPR[%0d] renamed to ROB[%0d]", d_dst, in_rob_next_rob_index));
      `DEBUG(("(regfile) NZCV: used: %0d,  valid: %0d, nzcv: %4b, rob_index: %0d", d_uses_nzcv, nzcv_valid, nzcv, nzcv_rob_index));
    end
  end

  // Set outputs
  always_comb begin
    out_rob_sigs.done = d_done;
    out_rob_sigs.fu_op = d_fu_op;

    // Src 1 - With LDUR/STUR, src1 contains base address. If src1 is not
    // available
    out_rob_sigs.src1_valid = gprs[d_src1].valid | (d_src1_status == REG_IS_UNUSED);
    out_rob_sigs.src1_rob_index = (d_dst == d_src1) ? src1_rob_index : gprs[d_src1].rob_index;
    if (d_src1_status == REG_IS_XZR) begin
      out_rob_sigs.src1_valid = 1;
      out_rob_sigs.src1_value = 0;
    end else if (d_fu_op == FU_OP_STUR | d_fu_op == FU_OP_STUR) begin
      if (gprs[d_src1].valid) begin
        out_rob_sigs.src1_value = gprs[d_src1].value + d_imm;
      end else begin
        out_rob_sigs.src1_value = d_imm;
      end
    end else if (d_fu_op == FU_OP_B_COND) begin
      out_rob_sigs.src1_value = d_pc;
      out_rob_sigs.src1_valid = 1;
    end else if (d_fu_op == FU_OP_ADRX) begin
      out_rob_sigs.src1_valid = 1;
      out_rob_sigs.src1_value = d_pc;
    end else begin
      out_rob_sigs.src1_value = gprs[d_src1].value;
    end



    // Src2 - With LDUR, the immediate is the offset.
    //      - With STUR, src2 contains value to st    ore. immediate contains the offset

    if (d_src2_status == REG_IS_XZR) begin
      out_rob_sigs.src2_valid = 1;
      out_rob_sigs.src2_value = 0;
    end else if (d_src2_status == REG_IS_IMMEDATE) begin  // TODO(Nate): This imm is messed up with STUR??
      out_rob_sigs.src2_valid = 1;
      out_rob_sigs.src2_value = d_imm;
    end else begin
      out_rob_sigs.src2_valid = gprs[d_src2].valid | (d_src2_status == REG_IS_UNUSED);
      out_rob_sigs.src2_value = gprs[d_src2].value;
    end
    out_rob_sigs.src2_rob_index = (d_dst == d_src2) ? src2_rob_index : gprs[d_src2].rob_index;

    // NZCV
    out_rob_sigs.nzcv_valid = nzcv_valid;
    // out_rob_sigs.src2_rob_index = d_dst == d_src2 ? dst_rob_index : gprs[d_src2].rob_index;
    out_rob_sigs.nzcv_rob_index = nzcv_rob_index;
    out_rob_sigs.nzcv = nzcv;
    out_rob_sigs.set_nzcv = d_set_nzcv;
    out_rob_sigs.uses_nzcv = d_uses_nzcv;
    // Dst
    out_rob_sigs.dst = d_dst;
  end

endmodule

