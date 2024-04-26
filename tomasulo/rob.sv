`include "data_structures.sv"

module rob_module (
    // Timing
    input logic in_rst,
    input logic in_clk,
    // Inputs from FU
    input logic in_fu_done,
    input logic [`ROB_IDX_SIZE-1:0] in_fu_dst_rob_index,
    input logic [`GPR_SIZE-1:0] in_fu_value,
    input logic in_fu_set_nzcv,
    input nzcv_t in_fu_nzcv,
    input logic in_fu_is_mispred,
    // Inputs from regfile (as part of decode)
    input logic in_reg_ready,  // NOTE(Nate): Is this stall?
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

    // Outputs for RS
    output logic out_rs_ready,
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
    output logic out_rs_should_broadcast,
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
    output logic [`ROB_IDX_SIZE-1:0] out_reg_commit_rob_index
    // // Outputs for dispatch
    // output logic [`ROB_IDX_SIZE-1:0] out_next_rob_idx,
    // output logic [`ROB_IDX_SIZE-1:0] out_delete_mispred_idx[`MISSPRED_SIZE]
);
  // Internal state
  rob_entry_t [`ROB_SIZE-1:0] rob;
  logic [`ROB_IDX_SIZE-1:0] commit_ptr;  // Next entry to be commited
  logic [`ROB_IDX_SIZE-1:0] next_ptr;  // Next rob index

  // Buffered data
  logic reg_ready;
  logic [`GPR_SIZE-1:0] reg_src1_value;
  logic [`GPR_SIZE-1:0] reg_src2_value;
  logic [`ROB_IDX_SIZE-1:0] reg_src1_rob_index;
  logic [`ROB_IDX_SIZE-1:0] reg_src2_rob_index;
  logic [`ROB_IDX_SIZE-1:0] reg_nzcv_rob_index;
  logic reg_src1_valid;
  logic reg_src2_valid;
  logic [`ROB_IDX_SIZE-1:0] fu_dst;
  logic fu_done;
  logic delayed_clk;

  always_ff @(posedge in_clk, negedge in_clk) begin
    delayed_clk <= #1 in_clk;
  end

  // Update from FU and copy signals
  always_ff @(posedge in_clk) begin
    if (in_rst) begin
`ifdef DEBUG_PRINT
      $display("(rob) Resetting");
`endif
      rob <= 0;  // TODO(Nate): Make sure this actually works
    end else begin : modify_rob
      // Copy over unused signals for RS
      out_rs_fu_op <= in_reg_fu_op;
      out_rs_fu_id <= in_reg_fu_id;
      out_rs_set_nzcv <= in_reg_set_nzcv;
      // Update state from FU
      if (in_fu_done) begin
`ifdef DEBUG_PRINT
        $display("(rob) [in_fu_done] FU complete. Modifying values:");
        $display("\tin_fu_dst_rob_index: %d, in_fu_value: %d", in_fu_dst_rob_index, in_fu_value);
`endif
        // Modify the line which the FU has updated
        rob[in_fu_dst_rob_index].value <= in_fu_value;
        rob[in_fu_dst_rob_index].valid <= 1;
        if (in_fu_set_nzcv) begin
          rob[in_fu_dst_rob_index].nzcv <= in_fu_nzcv;
        end
      end
      // Update regfile
      if (in_reg_ready) begin
`ifdef DEBUG_PRINT
        $display("(rob) Regfile has values from decode. Modifying by adding new entry");
        $display("\tin_reg_dst: %d, in_reg_set_nzcv: %d", in_reg_dst, in_reg_set_nzcv);
`endif
        // Add a new entry to the ROB and update the regfile
        rob[next_ptr].gpr_index <= in_reg_dst;
        rob[next_ptr].set_nzcv <= in_reg_set_nzcv;
        rob[next_ptr].nzcv <= in_reg_nzcv;
        rob[next_ptr].valid <= 0;
      end
      // Buffer the incoming state
      reg_ready <= in_reg_ready;
      reg_src1_value <= in_reg_src1_value;
      reg_src1_valid <= in_reg_src1_valid;
      reg_src2_value <= in_reg_src2_value;
      reg_src2_valid <= in_reg_src2_valid;
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
    out_rs_ready <= reg_ready;
    // Input
    if (reg_ready) begin
      // Output srcs to rs
      out_rs_val_a_valid <= reg_src1_valid ? reg_src1_valid : rob[reg_src1_rob_index].valid;
      out_rs_val_a_value <= reg_src1_valid ? reg_src1_value : rob[reg_src1_rob_index].value; // NOTE(Nate): This logic is goofy but works!

      out_rs_val_b_valid <= reg_src2_valid ? reg_src2_valid : rob[reg_src2_rob_index].valid;
      out_rs_val_b_value <= reg_src2_valid ? reg_src2_value : rob[reg_src2_rob_index].value;

      out_rs_nzcv_valid <= nzcv_valid ? reg_src2_valid : rob[reg_nzcv_rob_index].valid;
      out_rs_nzcv <= nzcv_valid ? nzcv_value : rob[reg_nzcv_rob_index].value;

      // Output dst rob index to rs
      out_rs_dst_rob_idx <= next_ptr;
      next_ptr <= (next_ptr + 1) % `ROB_SIZE;
    end
    // Broadcast (output) values to the rs after the fu has finished
    if (fu_done) begin : rob_broadcast
      out_rs_should_broadcast = 1;
      out_rs_broadcast_index = fu_dst;
      out_rs_broadcast_value = rob[fu_dst].value;
      out_rs_broadcast_set_nzcv = rob[fu_dst].set_nzcv;
      out_rs_broadcast_nzcv = rob[fu_dst].nzcv;
    end : rob_broadcast

    // Commit rob entry to regfile
    if (rob[commit_ptr].valid) begin : rob_commit
`ifdef DEBUG_PRINT
      $display("(rob) Commiting to regfile");
      $display(
          "\tcommit_ptr:%d, rob[cptr].gpr_index: %d, rob[cptr].value: %d, rob[cptr].set_nzcv: %d, rob[cptr].nzcv",
          rob[commit_ptr].gpr_index, rob[commit_ptr].value, rob[commit_ptr].set_nzcv,
          rob[commit_ptr].nzcv);
`endif
      out_reg_should_commit = 1;
      out_reg_commit_value = rob[commit_ptr].value;
      out_reg_set_nzcv = rob[commit_ptr].set_nzcv;
      out_reg_nzcv = rob[commit_ptr].nzcv;
      out_reg_commit_value = rob[commit_ptr].value;
      out_reg_index = rob[commit_ptr].gpr_index;
      out_reg_commit_rob_index = commit_ptr;
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
