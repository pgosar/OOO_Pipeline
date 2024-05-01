`include "data_structures.sv"

module rob_module (
    // Timing
    input logic in_rst,
    input logic in_clk,
    // Inputs from FU (to update ROB entry)
    input fu_interface in_fu_sigs,
    input fu_interface_alu_ext in_alu_sigs,
    // Inputs from regfile (to forward to rs)
    input reg_interface in_reg_sigs,

    // Outputs for RS
    output rob_interface out_rs_sigs,
    // Outputs for RS (on broadcast... resultant from FU)
    output rob_broadcast_interface out_rs_broadcast_sigs,

    // Outputs for regfile (for commits)
    output rob_commit_interface out_reg_commit_sigs,
    // Output for regfile (for the next ROB insertion)
    output logic [`ROB_IDX_SIZE-1:0] out_reg_next_rob_index,
    // Outputs for Mispred (broadcast)
    output logic [`GPR_SIZE-1:0] out_fetch_new_PC,
    output logic out_is_mispredict,
    // Outputs for RS
    output integer out_rs_pending_stur_count
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
  logic reg_uses_nzcv;
  logic [`ROB_IDX_SIZE-1:0] fu_dst;
  logic fu_done;
  fu_op_t fu_op;
  // Timing
  logic delayed_clk;
  logic delayed_clk_2;
  logic last_commit_was_mispredict;
  logic [`GPR_SIZE-1:0] mispredict_new_PC;

  integer fd;
  initial begin
    fd = $fopen("log.txt", "w");
  end

  always_ff @(posedge in_clk, negedge in_clk) begin
    delayed_clk   <= #1 in_clk;
    delayed_clk_2 <= #2 in_clk;
  end

  // Update from FU and copy signals
  always_ff @(posedge in_clk or negedge in_clk) begin
    if (in_clk) begin : on_posedge
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
        if (in_fu_sigs.done) begin
          if (rob[in_fu_sigs.dst_rob_index].bcond) begin
            `DEBUG(("(rob) !!! DETECTED BCOND !!!"));
            // if alu condition is true, mark mispredict as true and set PC. DO
            // NOT broadcast state.
          end
          if (in_reg_sigs.fu_op == OP_STUR) begin
            `DEBUG(("(rob) STUR detected. Incrementing STUR counter."));
            out_rs_pending_stur_count <= out_rs_pending_stur_count + 1;
          end
          `DEBUG(
              ("(rob) Received result from FU. ROB[%0d] -> %0d + valid", in_fu_sigs.dst_rob_index,
               $signed(
              in_fu_sigs.value)));
          // Validate the line which the FU has updated
          /*if (rob[in_fu_sigs.dst_rob_index].controlflow_valid) begin
            rob[in_fu_sigs.dst_rob_index].value <= in_fu_sigs.value;
            rob[in_fu_sigs.dst_rob_index].valid <= 1;
            if (in_alu_sigs.set_nzcv) begin
              rob[in_fu_sigs.dst_rob_index].nzcv <= in_alu_sigs.nzcv;
            end
          end*/ if(0) begin end else begin
            `DEBUG(("(rob) !! not updating rob for previous result. control flow invalid !!"));
          end
        end
        // Update ROB
        if (in_reg_sigs.done) begin
          `DEBUG(
              ("(rob) Inserting new entry @ ROB[%0d] for dst GPR[%0d]", next_ptr, in_reg_sigs.dst));
          `DEBUG(
              ("(rob) \tuse_nzcv: %b, next_ptr: %0d -> %0d", in_reg_sigs.uses_nzcv, next_ptr,
               (next_ptr + 1) % `ROB_SIZE));
          if (in_reg_sigs.fu_op == OP_STUR) begin
            `DEBUG(("(rob) STUR detected. Incrementing STUR counter."));
            out_rs_pending_stur_count <= out_rs_pending_stur_count + 1;
          end
          // Add a new entry to the ROB and update the regfile
          rob[next_ptr].gpr_index <= in_reg_sigs.dst;
          rob[next_ptr].set_nzcv <= in_reg_sigs.set_nzcv;
          rob[next_ptr].nzcv <= in_reg_sigs.nzcv;
          rob[next_ptr].valid <= 0;
          rob[next_ptr].mispredict <= in_reg_sigs.mispredict;
          rob[next_ptr].bcond <= in_reg_sigs.bcond;
          next_ptr <= (next_ptr + 1) % `ROB_SIZE;
        end
        if (rob[commit_ptr].valid) begin : remove_commit
          commit_ptr <= (commit_ptr + 1) % `ROB_SIZE;
          last_commit_was_mispredict <= rob[commit_ptr].mispredict;
          mispredict_new_PC <= rob[commit_ptr].value;
          if (rob[commit_ptr].mispredict)
            `DEBUG(("(rob) Detected branch mispredict. About to commit branch instruction."));
          `DEBUG(
              ("(rob) Commit was sent on posedge of this cycle. Incrementing cptr to %0d",
               (commit_ptr + 1) % `ROB_SIZE));
          `DEBUG(
              (
            "(rob) \tcommit_ptr:%0d, rob[cptr].gpr_index: %0d, rob[cptr].value: %0d, rob[cptr].set_nzcv: %b, rob[cptr].nzcv %b",
            commit_ptr, rob[commit_ptr].gpr_index, $signed(
              rob[commit_ptr].value), rob[commit_ptr].set_nzcv, rob[commit_ptr].nzcv));
        end : remove_commit
        // Buffer the incoming state
        fu_op <= in_reg_sigs.fu_op;
        reg_done <= in_reg_sigs.done;
        reg_src1_value <= in_reg_sigs.src1_value;
        reg_src1_valid <= in_reg_sigs.src1_valid;
        reg_nzcv <= in_reg_sigs.nzcv;
        reg_src2_value <= in_reg_sigs.src2_value;
        reg_src2_valid <= in_reg_sigs.src2_valid;
        reg_nzcv_valid <= in_reg_sigs.nzcv_valid;
        reg_src1_rob_index <= in_reg_sigs.src1_rob_index;
        reg_src2_rob_index <= in_reg_sigs.src2_rob_index;
        reg_nzcv_rob_index <= in_reg_sigs.nzcv_rob_index;
        reg_uses_nzcv <= in_reg_sigs.uses_nzcv;
        fu_dst <= in_fu_sigs.dst_rob_index;
        fu_done <= in_fu_sigs.done;
        // Copy over unused signals for RS
        out_rs_sigs.fu_op <= in_reg_sigs.fu_op;
        out_rs_sigs.fu_id <= in_reg_sigs.fu_id;
        out_rs_sigs.set_nzcv <= in_reg_sigs.set_nzcv;
        out_rs_sigs.cond_codes <= in_reg_sigs.cond_codes;
        out_rs_sigs.uses_nzcv <= in_reg_sigs.uses_nzcv;
        out_rs_sigs.val_a_rob_index <= in_reg_sigs.src1_rob_index;
        out_rs_sigs.val_b_rob_index <= in_reg_sigs.src2_rob_index;
        out_rs_sigs.nzcv_rob_index <= in_reg_sigs.nzcv_rob_index;
        // Set dst
        out_rs_sigs.dst_rob_index <= next_ptr;
      end : not_reset
    end : on_posedge
    else begin : on_negedge
      if (last_commit_was_mispredict) begin
        `DEBUG(("(rob) emitting mispredict directive."));
        // TODO(Nate): Misdirects must broadcast across the system
        rob <= 0;
        commit_ptr <= 0;
        next_ptr <= 0;
        out_fetch_new_PC <= mispredict_new_PC;
        out_is_mispredict <= 1;
        last_commit_was_mispredict <= 0;
      end else out_is_mispredict <= 0;
    end : on_negedge
  end

  // Process buffered state
  always_comb begin
    // Outputs to RS (pipeline progression)
    out_rs_sigs.done = reg_done;
    out_reg_next_rob_index = next_ptr;

    out_rs_sigs.val_a_valid = reg_src1_valid | rob[reg_src1_rob_index].valid;
    out_rs_sigs.val_b_valid = reg_src2_valid | rob[reg_src2_rob_index].valid;
    out_rs_sigs.nzcv_valid = reg_nzcv_valid | rob[reg_nzcv_rob_index].valid;
    out_rs_sigs.val_a_value = reg_src1_valid ? reg_src1_value : rob[reg_src1_rob_index].value; // NOTE(Nate): This logic is goofy but works!
    out_rs_sigs.val_b_value = reg_src2_valid ? reg_src2_value : rob[reg_src2_rob_index].value;
    out_rs_sigs.nzcv = reg_nzcv_valid ? reg_nzcv : rob[reg_nzcv_rob_index].nzcv;

    // Broadcast (output) values to the rs after the fu has finished
    out_rs_broadcast_sigs.done = fu_done;
    out_rs_broadcast_sigs.index = fu_dst;
    out_rs_broadcast_sigs.value = rob[fu_dst].value;
    out_rs_broadcast_sigs.set_nzcv = rob[fu_dst].set_nzcv;
    out_rs_broadcast_sigs.nzcv = rob[fu_dst].nzcv;

    // Commits
    out_reg_commit_sigs.done = rob[commit_ptr].valid;
    out_reg_commit_sigs.set_nzcv = rob[commit_ptr].set_nzcv;
    out_reg_commit_sigs.nzcv = rob[commit_ptr].nzcv;
    out_reg_commit_sigs.value = rob[commit_ptr].value;
    out_reg_commit_sigs.reg_index = rob[commit_ptr].gpr_index;
    out_reg_commit_sigs.rob_index = commit_ptr;

    // Tells the L/S to writeback during this commit
    out_rs_sigs.commit_done = rob[commit_ptr].valid;
  end

  //testing dont hate on me
  always_ff @(negedge in_clk) begin
    $fwrite(fd, "out_reg_commit_sigs.value: %d\n", out_reg_commit_sigs.value);
  end

endmodule

