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
    input alu_op_t in_reg_fu_op,
    input cond_t in_reg_cond_codes,
    input logic in_reg_instr_uses_nzcv,

    // Outputs for RS
    output logic out_rs_done,
    output fu_t out_rs_fu_id, // NOTE(Nate): Shouldn't this just go to the RS for this functional unit?
    output alu_op_t out_rs_fu_op,
    output logic out_rs_val_a_valid,
    output logic out_rs_val_b_valid,
    output logic out_rs_nzcv_valid,
    output logic [`GPR_SIZE-1:0] out_rs_val_a_value,
    output logic [`GPR_SIZE-1:0] out_rs_val_b_value,
    output nzcv_t out_rs_nzcv,
    output logic out_rs_set_nzcv,
    output logic [`ROB_IDX_SIZE-1:0] out_rs_val_a_rob_index,
    output logic [`ROB_IDX_SIZE-1:0] out_rs_val_b_rob_index,
    output logic [`ROB_IDX_SIZE-1:0] out_rs_dst_rob_idx,
    output logic [`ROB_IDX_SIZE-1:0] out_rs_nzcv_rob_idx,
    // Outputs for RS (on broadcast... resultant from FU)
    output logic out_rs_broadcast_done,
    output logic [`ROB_IDX_SIZE-1:0] out_rs_broadcast_index,
    output logic [`GPR_SIZE-1:0] out_rs_broadcast_value,
    output logic out_rs_broadcast_set_nzcv,
    output nzcv_t out_rs_broadcast_nzcv,
    // Outputs for regfile (for commits)
    output logic out_reg_should_commit,
    output logic out_reg_set_nzcv,
    output nzcv_t out_reg_nzcv,
    output logic [`GPR_SIZE-1:0] out_reg_commit_value,
    output logic [`GPR_IDX_SIZE-1:0] out_reg_index,
    output logic [`ROB_IDX_SIZE-1:0] out_reg_commit_rob_index,
    output cond_t out_rs_cond_codes,
    output logic out_rs_instr_uses_nzcv,
    // Output for regfile (for the next ROB insertion)
    output logic [`ROB_IDX_SIZE-1:0] out_reg_next_rob_index
    // // Outputs for dispatch
    // output logic [`ROB_IDX_SIZE-1:0] out_next_rob_idx,
    // output logic [`ROB_IDX_SIZE-1:0] out_delete_mispred_idx[`MISSPRED_SIZE]
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
  logic [`ROB_IDX_SIZE-1:0] fu_dst;
  logic fu_done;
  logic delayed_clk;
  logic delayed_clk_2;

  always_ff @(posedge in_clk, negedge in_clk) begin
    delayed_clk   <= #1 in_clk;
    delayed_clk_2 <= #2 in_clk;
  end

  // Update from FU and copy signals
  always_ff @(posedge in_clk) begin
    if (in_rst) begin
`ifdef DEBUG_PRINT
      $display("(rob) Resetting");
`endif
      reg_done <= 0;
      for (int i = 0; i < `ROB_SIZE; i++) begin
        rob[i].valid <= 0;
      end
    end else begin : modify_rob
      // Copy over unused signals for RS
      out_rs_fu_op <= in_reg_fu_op;
      out_rs_fu_id <= in_reg_fu_id;
      out_rs_set_nzcv <= in_reg_set_nzcv;
      out_rs_cond_codes <= in_reg_cond_codes;
      out_rs_instr_uses_nzcv <= in_reg_instr_uses_nzcv;
      // Update state from FU
      if (in_fu_done) begin
`ifdef DEBUG_PRINT
        $display("(rob) Received result from FU. ROB[%0d] -> %0d", in_fu_dst_rob_index,
                 in_fu_value);
`endif
        // Modify the line which the FU has updated
        rob[in_fu_dst_rob_index].value <= in_fu_value;
        rob[in_fu_dst_rob_index].valid <= 1;
        if (in_fu_set_nzcv) begin
          rob[in_fu_dst_rob_index].nzcv <= in_fu_nzcv;
        end
      end
      // Update regfile
      if (in_reg_done) begin
`ifdef DEBUG_PRINT
        $display("(rob) Inserting new entry @ ROB[%0d] -> use_nzcv: N/a", in_reg_dst);
`endif
        // Add a new entry to the ROB and update the regfile
        rob[next_ptr].gpr_index <= in_reg_dst;
        rob[next_ptr].set_nzcv <= in_reg_set_nzcv;
        rob[next_ptr].nzcv <= in_reg_nzcv;
        rob[next_ptr].valid <= 0;
      end
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
      fu_dst <= in_fu_dst_rob_index;
      fu_done <= in_fu_done;
    end : modify_rob
  end

  // Process buffered state
  always_ff @(posedge delayed_clk) begin
    // TODO(Nate): Some of these should not happen if we are stalled
    out_rs_done <= reg_done;
    out_reg_next_rob_index <= reg_done ? (next_ptr + 1) % `ROB_SIZE : next_ptr;
    // Input
    if (reg_done) begin
      // Output srcs to rs
      out_rs_val_a_valid <= reg_src1_valid ? reg_src1_valid : rob[reg_src1_rob_index].valid;
      out_rs_val_a_value <= reg_src1_valid ? reg_src1_value : rob[reg_src1_rob_index].value; // NOTE(Nate): This logic is goofy but works!

      out_rs_val_b_valid <= reg_src2_valid ? reg_src2_valid : rob[reg_src2_rob_index].valid;
      out_rs_val_b_value <= reg_src2_valid ? reg_src2_value : rob[reg_src2_rob_index].value;

      out_rs_nzcv_valid <= reg_nzcv_valid ? reg_src2_valid : rob[reg_nzcv_rob_index].valid;
      out_rs_nzcv <= reg_nzcv_valid ? reg_nzcv : rob[reg_nzcv_rob_index].nzcv;

      // Output dst rob index to rs
      out_rs_dst_rob_idx <= next_ptr;
      next_ptr <= (next_ptr + 1) % `ROB_SIZE;
      $display("(rob) Setting outputs: [src1_valid: %b], [src2_valid: %b], [nzcv_valid: %b]",
               reg_src1_valid, reg_src2_valid, reg_nzcv_valid);
    end
    // Broadcast (output) values to the rs after the fu has finished
    out_rs_broadcast_done <= fu_done;
    if (fu_done) begin : rob_broadcast
      out_rs_broadcast_index <= fu_dst;
      out_rs_broadcast_value <= rob[fu_dst].value;
      out_rs_broadcast_set_nzcv <= rob[fu_dst].set_nzcv;
      out_rs_broadcast_nzcv <= rob[fu_dst].nzcv;
    end : rob_broadcast

  end

  always_ff @(posedge delayed_clk_2) begin
    // Commit rob entry to regfile
    out_reg_should_commit = rob[commit_ptr].valid;
    if (rob[commit_ptr].valid) begin : rob_commit
`ifdef DEBUG_PRINT
      $display("(rob) Sending commit to regfile");
      $display(
          "\tcommit_ptr:%0d, rob[cptr].gpr_index: %0d, rob[cptr].value: %0d, rob[cptr].set_nzcv: %b, rob[cptr].nzcv %b",
          commit_ptr, rob[commit_ptr].gpr_index, rob[commit_ptr].value, rob[commit_ptr].set_nzcv,
          rob[commit_ptr].nzcv);
`endif
      out_reg_commit_value <= rob[commit_ptr].value;
      out_reg_set_nzcv <= rob[commit_ptr].set_nzcv;
      out_reg_nzcv <= rob[commit_ptr].nzcv;
      out_reg_commit_value <= rob[commit_ptr].value;
      out_reg_index <= rob[commit_ptr].gpr_index;
      out_reg_commit_rob_index <= commit_ptr;
      commit_ptr <= (commit_ptr + 1) % `ROB_SIZE;
    end : rob_commit
  end

  // TODO branch misprediction
  always_ff @(negedge in_clk) begin
    if (in_fu_is_mispred) begin
`ifdef DEBUG_PRINT
      $display("(rob) NOT IMPLEMENTED: Deleting mispredicted instructions");
`endif
      // remove last 3 indexes (fetch, decode, execute)
      // to fix wraparound, add rob_size and mod by rob_size
      // commit_ptr <= (commit_ptr + `ROB_SIZE - 3) % `ROB_SIZE;
      // rob[in_fu_dst_rob_index] <= 0;
      // rob[in_fu_dst_rob_index - 1] <= 0;
      // rob[in_fu_dst_rob_index - 2] <= 0;
      // out_delete_mispred_idx[0] <= (in_fu_dst_rob_index + `ROB_SIZE) % `ROB_SIZE;
      // out_delete_mispred_idx[1] <= (in_fu_dst_rob_index - 1 + `ROB_SIZE) % `ROB_SIZE;
      // out_delete_mispred_idx[2] <= (in_fu_dst_rob_index - 2 + `ROB_SIZE) % `ROB_SIZE;
    end
  end

endmodule
