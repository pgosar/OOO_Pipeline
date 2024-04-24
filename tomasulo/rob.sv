`include "data_structures.sv"

module rob_module (
    // Clocks
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
    input logic in_regfile_ready,  // NOTE(Nate): Is this stall?
    input logic [`GPR_IDX_SIZE-1:0] in_regfile_dst,
    input logic [`GPR_IDX_SIZE-1:0] in_regfile_src1,
    input logic [`GPR_IDX_SIZE-1:0] in_regfile_src2,
    input logic [`GPR_SIZE-1:0] in_regfile_src1_value,
    input logic [`GPR_SIZE-1:0] in_regfile_src2_value,
    input logic in_regfile_src1_valid,
    input logic in_regfile_src2_valid,
    input logic in_regfile_set_nzcv,
    input logic in_is_nop,  // NOTE(Nate): I don't remember what this is for
    input logic [`ROB_IDX_SIZE-1:0] in_last_nzcv_rob_idx,
    // Outputs for RS
    // TODO: Pipe through a func_unit_t which is generated in
    output logic out_rs_val_a_valid,
    output logic out_rs_val_b_valid,
    output logic [`GPR_SIZE-1:0] out_rs_val_a_value,
    output logic [`GPR_SIZE-1:0] out_rs_val_b_value,
    output logic [`ROB_IDX_SIZE-1:0] out_rs_val_a_rob_index,
    output logic [`ROB_IDX_SIZE-1:0] out_rs_val_b_rob_index,
    output logic [`ROB_IDX_SIZE-1:0] out_rs_dst_rob_idx,
    output logic out_rs_should_broadcast,
    output logic [`ROB_IDX_SIZE-1:0] out_rs_broadcast_index,
    output logic [`GPR_SIZE-1:0] out_rs_broadcast_value,
    // Outputs for regfile
    output logic out_regfile_should_commit,
    output logic [`GPR_IDX_SIZE-1:0] out_regfile_gpr_index,
    output logic [`GPR_SIZE-1:0] out_regfile_value,
    output logic out_regfile_set_nzcv,
    output logic [3:0] out_regfile_nzcv
    // // Outputs for dispatch
    // output logic [`ROB_IDX_SIZE-1:0] out_next_rob_idx,
    // output logic [`ROB_IDX_SIZE-1:0] out_delete_mispred_idx[`MISSPRED_SIZE]
);
  // TODO in_gpr_idx, out_regfile_should_commit, out_next_rob_idx, out_delete_mispred_idx unused
  // Internal state
  rob_entry_t [`ROB_SIZE-1:0] rob;
  logic [`ROB_IDX_SIZE-1:0] commit_ptr;  // Next entry to be commited
  logic [`ROB_IDX_SIZE-1:0] next_ptr;  // Next rob index
  logic [`NZCV_SIZE-1:0] prev_nzcv;  // NOTE(Nate): Why do we need this???

  // Buffered data
  logic [`GPR_IDX_SIZE-1:0] regfile_src1;
  logic [`GPR_IDX_SIZE-1:0] regfile_src2;
  logic [`GPR_SIZE-1:0] regfile_src1_value;
  logic [`GPR_SIZE-1:0] regfile_src2_value;
  logic regfile_src1_valid;
  logic regfile_src2_valid;
  logic [`ROB_IDX_SIZE-1:0] fu_dst;
  logic fu_done;

  // Update modified state
  always_ff @(posedge in_clk) begin
    if (in_rst) begin
`ifdef DEBUG_PRINT
      $display("(rob) Resetting");
`endif
      rob <= 0;  // TODO(Nate): Make sure this actually works
    end else begin : modify_rob
      fu_done <= fu_done;
      if (in_fu_done) begin
`ifdef DEBUG_PRINT
        $display("(rob) [in_fu_done] FU complete. Modifying values:");
        $display("\tin_fu_dst_rob_index: %d, in_fu_value: %d", in_fu_dst_rob_index, in_fu_value);
`endif
        // Modify the line which the FU has updated
        rob[in_fu_dst_rob_index].value <= in_fu_value;
        rob[in_fu_dst_rob_index].valid <= 1;
        fu_dst <= in_fu_dst_rob_index;
      end
      if (in_regfile_ready) begin
`ifdef DEBUG_PRINT
        $display("(rob) Regfile has values from decode. Modifying by adding new entry");
        $display("\tin_regfile_dst: %d, in_regfile_set_nzcv: %d", in_regfile_dst,
                 in_regfile_set_nzcv);
`endif
        // Add the new destination from the regfile
        rob[next_ptr].gpr_index <= in_regfile_dst;
        rob[next_ptr].set_nzcv <= in_regfile_set_nzcv;
        rob[next_ptr].valid <= 0;
        // Read the source regfile indices into a buffer. Any code which needs
        // to index into the rob must be buffered until the modifications are,
        // complete since the values in the rob could be modified.
        regfile_src1 <= in_regfile_src1;
        regfile_src2 <= in_regfile_src2;
        regfile_src1_value <= in_regfile_src1_value;
        regfile_src1_valid <= in_regfile_src1_valid;
        regfile_src2_value <= in_regfile_src2_value;
        regfile_src2_valid <= in_regfile_src2_valid;
      end
    end : modify_rob
  end

  // We are assuming that input values can only be read on the posedge of the
  // clock. Therefore this always block CANNOT use input values.
  always @(posedge in_clk) begin
    #1  // Assume that the sets which occur on the posedge will
    // TODO(Nate): Some of these should not happen if we are stalled
    // Output srcs to rs
    out_rs_val_a_valid = regfile_src1_valid ? regfile_src1_valid : rob[regfile_src1].valid;
    out_rs_val_a_value = regfile_src1_valid ? regfile_src1_value : rob[regfile_src1].value;

    out_rs_val_b_valid = regfile_src2_valid ? regfile_src2_valid : rob[regfile_src2].valid;
    out_rs_val_b_value = regfile_src2_valid ? regfile_src2_value : rob[regfile_src2].value;

    // Output dst rob index to rs
    out_rs_dst_rob_idx = next_ptr;

    // Broadcast (output) values to the rs after the fu has finished
    if (fu_done) begin : rob_broadcast
      out_rs_broadcast_index = fu_dst;
      out_rs_broadcast_value = rob[fu_dst].value;
    end : rob_broadcast

    // Output commit values to regfile
    if (rob[commit_ptr].valid) begin : rob_commit
`ifdef DEBUG_PRINT
      $display("(rob) Commiting to regfile");
      $display(
          "\tcommit_ptr:%d, rob[cptr].gpr_index: %d, rob[cptr].value: %d, rob[cptr].set_nzcv: %d, rob[cptr].nzcv",
          rob[commit_ptr].gpr_index, rob[commit_ptr].value, rob[commit_ptr].set_nzcv,
          rob[commit_ptr].nzcv);
`endif
      out_regfile_should_commit = 1;
      out_regfile_gpr_index = rob[commit_ptr].gpr_index;
      out_regfile_value = rob[commit_ptr].value;
      out_regfile_set_nzcv = rob[commit_ptr].set_nzcv;
      out_regfile_nzcv = rob[commit_ptr].nzcv;
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

  /*
  // Initial inputs
  always_latch begin
    out_regfile_should_commit = 0;
    if (in_rst) begin
      integer i;
      for (i = 0; i < `GPR_SIZE; i += 1) begin
        rob[i] = 0;
      end
    end else if (!in_is_nop) begin
      `ifdef DEBUG_PRINT
      $display("(rob) not nop Adding new entry");
      $display("in_gpr_idx: %d", in_gpr_idx);
      $display("commit_ptr: %d", commit_ptr);
      `endif
      // Write to ROB upon FU completing
      if (in_fu_done) begin : fu_done
        rob[in_fu_dst_rob_index].value = in_fu_value;
        rob[in_fu_dst_rob_index].valid = 1;
        `ifdef DEBUG_PRINT
        $display("(rob) FU done, setting value to %d", in_fu_value);
        `endif
        if (in_fu_set_nzcv) begin
          `ifdef DEBUG_PRINT
          $display("(rob) Setting nzcv");
          `endif
          rob[in_fu_dst_rob_index].set_nzcv = 1;
          rob[in_fu_dst_rob_index].nzcv = in_fu_nzcv;
          prev_nzcv = in_fu_nzcv;
        end else begin
          `ifdef DEBUG_PRINT
          $display("(rob) getting previous nzcv value");
          `endif
          rob[in_fu_dst_rob_index].set_nzcv = 0;
          rob[in_fu_dst_rob_index].nzcv = prev_nzcv;
        end
        // fu done
        commit_ptr = in_fu_dst_rob_index;
        out_next_rob_idx = (in_fu_dst_rob_index + 1) % `ROB_SIZE;
        out_regfile_should_commit = 1;
        `ifdef DEBUG_PRINT
        $display("(rob) commit_ptr: %d, out_next_rob_idx: %d", commit_ptr, out_next_rob_idx);
        `endif
      end : fu_done
      // Write to ROB from Dispatch
      // if (accepting_input) begin
      //     rob[next_rob_idx].gpr_idx <= in_gpr_idx;
      //     commit_ptr <= in_next_rob_idx;
      // end
    end
  end
  */
endmodule
