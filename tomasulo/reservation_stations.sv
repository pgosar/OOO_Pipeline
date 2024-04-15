`include "data_structures.sv"

module reservation_station # (
    parameter RS_SIZE = 8
) (
    input logic op1_valid,
    input logic op2_valid,
    input logic [`ROB_IDX_SIZE-1:0] op1_rob_index,
    input logic [`ROB_IDX_SIZE-1:0] op2_rob_index,
    input logic [`GPR_SIZE-1:0] op1_value,
    input logic [`GPR_SIZE-1:0] op2_value
);

    rs_entry [`RS_SIZE-1:0] rs;

endmodule

module rob #(
    parameter GPR_SIZE = 64,
    parameter ROB_SIZE = 16,
    parameter ROB_IDX_SIZE = 4,
    parameter GPR_IDX_SIZE = 5
) (
    // Clocks
    input logic in_clk,
    input logic in_rst,
    // Inputs from FU
    input logic in_fu_done,
    input logic [GPR_SIZE-1:0] in_fu_value,
    input logic [ROB_IDX_SIZE-1:0] in_fu_rob_idx,
    input logic in_fu_set_nzcv,
    input nzcv_t in_fu_nzcv,
    // Inputs from dispatch
    input logic [GPR_IDX_SIZE-1:0] in_gpr_idx,
    input logic in_is_nop,
    // Outputs for regfile
    output logic out_regfile_should_commit,
    // Outputs for dispatch
    output logic [ROB_IDX_SIZE-1:0] out_next_rob_idx
);
    // Internal state
    rob_entry [ROB_SIZE-1:0] rob;
    logic [ROB_IDX_SIZE-1:0] commit_ptr;
    logic will_commit;

    function integer get_rob_idx(integer fu_rob_idx);
        get_rob_idx = fu_rob_idx;
    endfunction

    // Initial inputs
    always_ff @(posedge in_clk) begin
        commit_ptr = 0;
        if (in_rst) begin
            // integer i;
            // for (i = 0; i < GPR_SIZE; i += 1) begin
            //     rob[i] = 0;
            // end
        end else if (!in_is_nop) begin
            // Write to ROB upon FU completing
            if (in_fu_done) begin
                rob[0 +: in_fu_rob_idx].value <= in_fu_value;
                rob[in_fu_rob_idx].valid <= 1;
                if (in_fu_set_nzcv) begin
                    rob[in_fu_rob_idx].set_nzcv <= 1;
                    rob[in_fu_rob_idx].nzcv <= in_fu_nzcv;
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

module regfile(
    // Clock
    input logic in_clk,
    input logic in_rst,
    // Inputs from ROB
    input logic in_rob_should_commit,
    input logic [`GPR_SIZE-1:0] in_rob_commit_value,
    input logic [`GPR_IDX_SIZE-1:0] in_rob_regfile_index,
    // Inputs from Dispatch
    input logic in_dispatch_should_read, // UNUSED: But this would be good for energy
    input logic [`GPR_IDX_SIZE-1:0] in_d_op1,
    input logic [`GPR_IDX_SIZE-1:0] in_d_op2,
    // Outputs for Dispatch
    output logic [`GPR_SIZE-1:0] out_d_op1,
    output logic [`GPR_SIZE-1:0] out_d_op2
);

    gpr_entry [`GPR_SIZE-1:0] gprs;
    integer i;
    always_ff @(posedge in_clk) begin
        if (in_rst) begin
            for (i = 0; i < `GPR_SIZE; i += 1) begin
                gprs[i] = 0;
            end
        end else begin
            if (in_dispatch_should_read) begin
                gpr_entry gpr1;
                gpr_entry gpr2;
                gpr1 = gprs[in_d_op1];
                gpr2 = gprs[in_d_op2];
                if (gpr1.valid) begin
                    out_d_op1 = gpr1.value;
                end
                if (gpr2.valid) begin
                    out_d_op2 = gpr2.value;
                end
            end
            if (in_rob_should_commit) begin
                gpr_entry gpr;
                gpr = gprs[in_rob_regfile_index];
                gpr.value = in_rob_commit_value;
            end
        end
    end

endmodule
