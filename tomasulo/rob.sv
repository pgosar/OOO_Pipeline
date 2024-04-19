`include "data_structures.sv"

module rob_module (
    // Clocks
    input logic in_rst,
    input logic in_clk,
    // Inputs from FU
    input logic in_fu_done,
    input logic [`GPR_SIZE-1:0] in_fu_value,
    input logic [`ROB_IDX_SIZE-1:0] in_fu_rob_idx,
    input logic in_fu_set_nzcv,
    input nzcv_t in_fu_nzcv,
    input logic in_is_mispred,
    // Inputs from dispatch
    input logic [`GPR_IDX_SIZE-1:0] in_gpr_idx,
    input logic in_is_nop,
    // Outputs for regfile
    output logic out_regfile_should_commit,
    // Outputs for dispatch
    output logic [`ROB_IDX_SIZE-1:0] out_next_rob_idx,
    output logic [`ROB_IDX_SIZE-1:0] out_delete_mispred_idx [`MISSPRED_SIZE]
);
    // TODO in_gpr_idx, out_regfile_should_commit, out_next_rob_idx, out_delete_mispred_idx unused
    // Internal state
    rob_entry_t [`ROB_SIZE-1:0] rob;
    logic [`ROB_IDX_SIZE-1:0] commit_ptr;
    logic [`NZCV_SIZE-1:0] prev_nzcv;
    logic will_commit;

    // todo branch misprediction
    always_ff @(negedge in_clk) begin
        if (in_is_mispred) begin
            `ifdef DEBUG_PRINT
                $display("(rob) Deleting mispredicted instructions");
            `endif
            // will_commit <= 0;
            // remove last 3 indexes (fetch, decode, execute)
            // to fix wraparound, add rob_size and mod by rob_size
            // commit_ptr <= (commit_ptr + `ROB_SIZE - 3) % `ROB_SIZE;
            // rob[in_fu_rob_idx] <= 0;
            // rob[in_fu_rob_idx - 1] <= 0;
            // rob[in_fu_rob_idx - 2] <= 0;
            // out_delete_mispred_idx[0] <= (in_fu_rob_idx + `ROB_SIZE) % `ROB_SIZE;
            // out_delete_mispred_idx[1] <= (in_fu_rob_idx - 1 + `ROB_SIZE) % `ROB_SIZE;
            // out_delete_mispred_idx[2] <= (in_fu_rob_idx - 2 + `ROB_SIZE) % `ROB_SIZE;
        end
    end

    // Initial inputs
    always_latch begin
        commit_ptr = 0;
        if (in_rst) begin
            integer i;
            for (i = 0; i < `GPR_SIZE; i += 1) begin
                rob[i] = 0;
            end
            `ifdef DEBUG_PRINT
                $display("(rob) Resetting");
            `endif
        end else if (!in_is_nop) begin
            `ifdef DEBUG_PRINT
                $display("(rob) not nop Adding new entry");
            `endif
            // Write to ROB upon FU completing
            if (in_fu_done) begin
                `ifdef DEBUG_PRINT
                    $display("(rob) FU done");
                `endif
                rob[in_fu_rob_idx].value = in_fu_value;
                rob[in_fu_rob_idx].valid = 1;
                if (in_fu_set_nzcv) begin
                    `ifdef DEBUG_PRINT
                        $display("(rob) Setting nzcv");
                    `endif
                    rob[in_fu_rob_idx].set_nzcv = 1;
                    rob[in_fu_rob_idx].nzcv = in_fu_nzcv;
                    prev_nzcv = in_fu_nzcv;
                end else begin
                    `ifdef DEBUG_PRINT
                        $display("(rob) getting previous nzcv value");
                    `endif
                    rob[in_fu_rob_idx].set_nzcv = 0;
                    rob[in_fu_rob_idx].nzcv = prev_nzcv;
                end
            end
            // Write to ROB from Dispatch
            // if (accepting_input) begin
            //     rob[next_rob_idx].gpr_idx <= in_gpr_idx;
            //     commit_ptr <= in_next_rob_idx;
            // end
        end
    end

endmodule
