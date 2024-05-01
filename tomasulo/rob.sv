`include "data_structures.sv"


module rob_module (
    // Timing
    input logic in_rst,
    input logic in_clk,
    // Inputs from FU (to broadcast)
    input logic in_fu_done,
    input logic [`ROB_IDX_SIZE-1:0] in_fu_dst_rob_index,
    input logic [`GPR_SIZE-1:0] in_fu_value,
    input logic in_fu_set_nzcv,
    input nzcv_t in_fu_nzcv,
    input logic in_fu_is_mispred,
    // Inputs from regfile (to forward to rs)
    input logic in_reg_done,  // NOTE(Nate): Is this stall?
    input logic in_reg_src1_valid,
    input logic in_reg_src2_valid,
    input logic in_reg_nzcv_valid,
    input logic [`GPR_IDX_SIZE-1:0] in_reg_dst,
    input logic [`ROB_IDX_SIZE-1:0] in_reg_src1_rob_index,
    input logic [`ROB_IDX_SIZE-1:0] in_reg_src2_rob_index,
    input logic [`ROB_IDX_SIZE-1:0] in_reg_nzcv_rob_index,
    input logic [`GPR_SIZE-1:0] in_reg_src1_value,
    input logic [`GPR_SIZE-1:0] in_reg_src2_value,
    input logic in_reg_set_nzcv,
    input nzcv_t in_reg_nzcv,
    input fu_t in_reg_fu_id,
    input fu_op_t in_reg_fu_op,
    input cond_t in_reg_cond_codes,
    input logic in_reg_instr_uses_nzcv,
    input logic in_reg_mispredict,
    input logic in_reg_bcond,

    // Outputs for RS
    output cond_t out_rs_cond_codes,  // CE ???
    output logic out_rs_done,  // A
    output fu_t out_rs_fu_id,  // AA
    output fu_op_t out_rs_fu_op,  // AB
    output logic out_rs_alu_val_a_valid,  // AC
    output logic out_rs_alu_val_b_valid,  // AD
    output logic out_rs_nzcv_valid,  // AE
    output logic [`GPR_SIZE-1:0] out_rs_alu_val_a_value,  // ACA
    output logic [`GPR_SIZE-1:0] out_rs_alu_val_b_value,  // ADA
    output logic out_rs_instr_uses_nzcv,  // AE
    output nzcv_t out_rs_nzcv,  // AEA
    output logic out_rs_set_nzcv,  // AF
    output logic [`ROB_IDX_SIZE-1:0] out_rs_alu_val_a_rob_index,  // ACB
    output logic [`ROB_IDX_SIZE-1:0] out_rs_alu_val_b_rob_index,  // ADB
    output logic [`ROB_IDX_SIZE-1:0] out_rs_alu_dst_rob_index,  // AG
    output logic [`ROB_IDX_SIZE-1:0] out_rs_nzcv_rob_index,  // AH
    // Outputs for RS (on broadcast... resultant from FU)
    output logic out_rs_broadcast_done,  // B
    output logic [`ROB_IDX_SIZE-1:0] out_rs_broadcast_index,  // BA
    output logic [`GPR_SIZE-1:0] out_rs_broadcast_value,  // BB
    output logic out_rs_broadcast_set_nzcv,  // BC
    output nzcv_t out_rs_broadcast_nzcv,  // BCA
    output logic out_rs_is_mispred,
    // Outputs for regfile (for commits)
    output logic out_reg_commit_done,  // C
    output logic out_reg_set_nzcv,  // CA
    output nzcv_t out_reg_nzcv,  // CAA
    output logic [`GPR_SIZE-1:0] out_reg_commit_value,  // CB
    output logic [`GPR_IDX_SIZE-1:0] out_reg_index,  // CC
    output logic [`ROB_IDX_SIZE-1:0] out_reg_commit_rob_index,  // CD
    // Output for regfile (for the next ROB insertion)
    output logic [`ROB_IDX_SIZE-1:0] out_reg_next_rob_index,  // D
    // // Outputs for dispatch
    // output logic [`ROB_IDX_SIZE-1:0] out_next_rob_index,
    // output logic [`ROB_IDX_SIZE-1:0] out_delete_mispred_index[`MISSPRED_SIZE]
    // Outputs for Fetch
    output logic out_fetch_mispredict,
    output logic [`GPR_SIZE-1:0] out_fetch_new_PC
);
  // Internal state
  rob_entry_t [`ROB_SIZE-1:0] rob;
  logic [`ROB_IDX_SIZE-1:0] commit_ptr;  // Next entry to be commited
  logic [`ROB_IDX_SIZE-1:0] next_ptr;  // Next rob index

  // Buffered data
  logic reg_done;
  logic [`GPR_SIZE-1:0] reg_src1_value;
  logic [`GPR_SIZE-1:0] reg_src2_value;
  nzcv_t reg_nzcv;
  logic [`ROB_IDX_SIZE-1:0] reg_src1_rob_index;
  logic [`ROB_IDX_SIZE-1:0] reg_src2_rob_index;
  logic [`ROB_IDX_SIZE-1:0] reg_nzcv_rob_index;
  logic reg_nzcv_valid;
  logic reg_src1_valid;
  logic reg_src2_valid;
  logic reg_instr_uses_nzcv;
  logic [`ROB_IDX_SIZE-1:0] fu_dst;
  logic fu_done;
  // Timing
  logic delayed_clk;
  logic delayed_clk_2;
  logic last_commit_was_mispredict;
  logic [`GPR_SIZE-1:0] mispredict_new_PC;

  always_ff @(posedge in_clk, negedge in_clk) begin
    delayed_clk   <= #1 in_clk;
    delayed_clk_2 <= #2 in_clk;
  end

  // Update from FU and copy signals
  always_ff @(posedge in_clk or negedge in_clk) begin
  if (in_clk) begin: on_posedge
    if (in_rst) begin
      `DEBUG(("(rob) Resetting"));
      fu_done <= 0;
      commit_ptr <= 0;
      next_ptr <= 0;
      reg_done <= 0;
      for (int i = 0; i < `ROB_SIZE; i++) begin
        rob[i].valid <= 0;
      end
    end else begin : not_reset
      // Update state from FU
      if (in_fu_done) begin
        if (rob[in_fu_dst_rob_index].bcond) begin
          `DEBUG(("(rob) !!! DETECTED BCOND !!!"));
          // if alu condition is true, mark mispredict as true and set PC. DO
          // NOT broadcast state.
        end
        `DEBUG(("(rob) Received result from FU. ROB[%0d] -> %0d + valid", in_fu_dst_rob_index,
               $signed(in_fu_value)));
        // Validate the line which the FU has updated
        if (rob[in_fu_dst_rob_index].controlflow_valid) begin
          rob[in_fu_dst_rob_index].value <= in_fu_value;
          rob[in_fu_dst_rob_index].valid <= 1;
          if (in_fu_set_nzcv) begin
            rob[in_fu_dst_rob_index].nzcv <= in_fu_nzcv;
          end
        end else `DEBUG(("(rob) !! not updating rob for previous result. control flow invalid !!"));
      end
      // Update regfile
      if (in_reg_done) begin
        `DEBUG(("(rob) Inserting new entry @ ROB[%0d] for dst GPR[%0d]", next_ptr, in_reg_dst));
        `DEBUG(("(rob) \tuse_nzcv: %b, next_ptr: %0d -> %0d", in_reg_instr_uses_nzcv, next_ptr,
               (next_ptr + 1) % `ROB_SIZE));
        // Add a new entry to the ROB and update the regfile
        rob[next_ptr].gpr_index <= in_reg_dst;
        rob[next_ptr].set_nzcv <= in_reg_set_nzcv;
        rob[next_ptr].nzcv <= in_reg_nzcv;
        rob[next_ptr].valid <= 0;
        rob[next_ptr].mispredict <= in_reg_mispredict;
        rob[next_ptr].bcond <= in_reg_bcond;
        rob[next_ptr].controlflow_valid <= 1;
        next_ptr <= (next_ptr + 1) % `ROB_SIZE;
      end
      if (rob[commit_ptr].valid) begin : remove_commit
        commit_ptr <= (commit_ptr + 1) % `ROB_SIZE;
        last_commit_was_mispredict <= rob[commit_ptr].mispredict;
        mispredict_new_PC <= rob[commit_ptr].value;
        `DEBUG(("(rob) Detected branch mispredict. About to commit branch instruction."));
        `DEBUG(("(rob) Commit was sent on posedge of this cycle. Incrementing cptr to %0d",
               (commit_ptr + 1) % `ROB_SIZE));
        `DEBUG((
            "(rob) \tcommit_ptr:%0d, rob[cptr].gpr_index: %0d, rob[cptr].value: %0d, rob[cptr].set_nzcv: %b, rob[cptr].nzcv %b",
            commit_ptr, rob[commit_ptr].gpr_index, $signed(rob[commit_ptr].value),
            rob[commit_ptr].set_nzcv, rob[commit_ptr].nzcv));
      end : remove_commit
      // Buffer the incoming state
      reg_done <= in_reg_done;
      reg_src1_value <= in_reg_src1_value;
      reg_src1_valid <= in_reg_src1_valid;
      reg_nzcv <= in_reg_nzcv;
      reg_src2_value <= in_reg_src2_value;
      reg_src2_valid <= in_reg_src2_valid;
      reg_nzcv_valid <= in_reg_nzcv_valid;
      reg_src1_rob_index <= in_reg_src1_rob_index;
      reg_src2_rob_index <= in_reg_src2_rob_index;
      reg_nzcv_rob_index <= in_reg_nzcv_rob_index;
      reg_instr_uses_nzcv <= in_reg_instr_uses_nzcv;
      fu_dst <= in_fu_dst_rob_index;
      fu_done <= in_fu_done;
      // Copy over unused signals for RS
      out_rs_fu_op <= in_reg_fu_op;
      out_rs_fu_id <= in_reg_fu_id;
      out_rs_set_nzcv <= in_reg_set_nzcv;
      out_rs_cond_codes <= in_reg_cond_codes;
      out_rs_instr_uses_nzcv <= in_reg_instr_uses_nzcv;
      out_rs_alu_val_a_rob_index <= in_reg_src1_rob_index;
      out_rs_alu_val_b_rob_index <= in_reg_src2_rob_index;
      out_rs_nzcv_rob_index <= in_reg_nzcv_rob_index;
      // Set dst
      out_rs_alu_dst_rob_index <= next_ptr;
    end : not_reset
  end: on_posedge
  else begin: on_negedge
    if (last_commit_was_mispredict) begin
      `DEBUG(("(rob) emitting mispredict directive."));
      rob <= 0;
      out_fetch_new_PC <= 252;
      out_fetch_mispredict <= 1;
      last_commit_was_mispredict <= 0;
    end else out_fetch_mispredict <= 0;
  end: on_negedge
end

  // Some printout or sumn
  // always_ff @(posedge delayed_clk) begin
  // end

  // Process buffered state
  always_comb begin
    // Outputs to RS (pipeline progression)
    out_rs_done = reg_done;
    out_reg_next_rob_index = next_ptr;

    out_rs_alu_val_a_valid = reg_src1_valid | rob[reg_src1_rob_index].valid;
    out_rs_alu_val_b_valid = reg_src2_valid | rob[reg_src2_rob_index].valid;
    out_rs_nzcv_valid = reg_nzcv_valid | rob[reg_nzcv_rob_index].valid;
    out_rs_alu_val_a_value = reg_src1_valid ? reg_src1_value : rob[reg_src1_rob_index].value; // NOTE(Nate): This logic is goofy but works!
    out_rs_alu_val_b_value = reg_src2_valid ? reg_src2_value : rob[reg_src2_rob_index].value;
    out_rs_nzcv = reg_nzcv_valid ? reg_nzcv : rob[reg_nzcv_rob_index].nzcv;

    // Broadcast (output) values to the rs after the fu has finished
    out_rs_broadcast_done = fu_done;
    out_rs_broadcast_index = fu_dst;
    out_rs_broadcast_value = rob[fu_dst].value;
    out_rs_broadcast_set_nzcv = rob[fu_dst].set_nzcv;
    out_rs_broadcast_nzcv = rob[fu_dst].nzcv;

    // Commits
    out_reg_commit_done = rob[commit_ptr].valid;
    out_reg_commit_value = rob[commit_ptr].value;
    out_reg_set_nzcv = rob[commit_ptr].set_nzcv;
    out_reg_nzcv = rob[commit_ptr].nzcv;
    out_reg_commit_value = rob[commit_ptr].value;
    out_reg_index = rob[commit_ptr].gpr_index;
    out_reg_commit_rob_index = commit_ptr;
  end
endmodule
