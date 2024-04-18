`include "data_structures.sv"

module core(
    input logic in_reset,
    input logic in_start,
    input logic in_clk
);
    // ROB
    // from FU
    logic in_fu_done;
    logic [`GPR_SIZE-1:0] in_fu_value;
    logic [`ROB_IDX_SIZE-1:0] in_fu_rob_idx;
    logic in_fu_set_nzcv;
    nzcv_t in_fu_nzcv;
    logic in_is_mispred;
    // from dispatch
    logic [`GPR_IDX_SIZE-1:0] in_gpr_idx;
    logic in_is_nop;
    // for regfile
    logic out_regfile_should_commit;
    // for dispatch
    logic [`ROB_IDX_SIZE-1:0] out_next_rob_idx;
    logic [`ROB_IDX_SIZE-1:0] out_delete_mispred_idx [`MISSPRED_SIZE];

    // Regfile
    // from ROB
    logic in_rob_should_commit;
    logic [`GPR_SIZE-1:0] in_rob_commit_value;
    logic [`GPR_IDX_SIZE-1:0] in_rob_regfile_index;
    // logic in_is_mispred;
    // logic [ROB_IDX_SIZE-1:0] out_delete_mispred_idx [2:0];
    // from dispatch
    logic in_dispatch_should_read;
    logic [`GPR_IDX_SIZE-1:0] in_d_op1;
    logic [`GPR_IDX_SIZE-1:0] in_d_op2;
    // Regfile outputs
    // for dispatch
    logic [`GPR_SIZE-1:0] out_d_op1;
    logic [`GPR_SIZE-1:0] out_d_op2;

    // Reservation station
    // from dispatch
    logic in_op1_valid;
    logic in_op2_valid;
    logic [`ROB_IDX_SIZE-1:0] in_op1_rob_index;
    logic [`ROB_IDX_SIZE-1:0] in_op2_rob_index;
    logic [`GPR_SIZE-1:0] in_op1_value;
    logic [`GPR_SIZE-1:0] in_op2_value;
    logic [`GPR_IDX_SIZE-1:0] in_dst;
    logic in_set_nzcv;
    // from ROB
    logic in_rob_broadcast_done;
    logic [`ROB_IDX_SIZE-1:0] in_rob_broadcast_index;
    logic [`GPR_SIZE-1:0] in_rob_broadcast_val;
    logic in_rob_is_mispred; // different than above?
    // from FU
    logic in_fu_ready;
    // logic in_fu_done;
    // Reservation station outputs
    // to FU
    logic [`RS_IDX_SIZE:0] out_ready_index;

    // dispatch
    // from core
    logic in_stall;
    // from fetch
    logic [31:0] in_insnbits;
    logic in_fetch_done;
    logic [`GPR_IDX_SIZE-1:0] out_src1;
    logic [`GPR_IDX_SIZE-1:0] out_src2;
    func_unit out_fu;
    logic [`GPR_IDX_SIZE-1:0] out_dst;
    logic out_stalled;


    // modules
    regfile_module regfile (
        .in_clk(in_clk),
        .in_rst(in_reset),
        .in_rob_should_commit(in_rob_should_commit),
        .in_rob_commit_value(in_rob_commit_value),
        .in_rob_regfile_index(in_rob_regfile_index),
        .in_dispatch_should_read(in_dispatch_should_read),
        .in_d_op1(in_d_op1),
        .in_d_op2(in_d_op2),
        .out_d_op1(out_d_op1),
        .out_d_op2(out_d_op2)
    );

    rob_module rob (
        .in_clk(in_clk),
        .in_rst(in_reset),
        .in_fu_done(in_fu_done),
        .in_fu_value(in_fu_value),
        .in_fu_rob_idx(in_fu_rob_idx),
        .in_fu_set_nzcv(in_fu_set_nzcv),
        .in_fu_nzcv(in_fu_nzcv),
        .in_is_mispred(in_is_mispred), // we aren't set on this right now
        .in_gpr_idx(in_gpr_idx),
        .in_is_nop(in_is_nop),
        .out_regfile_should_commit(out_regfile_should_commit),
        .out_next_rob_idx(out_next_rob_idx),
        .out_delete_mispred_idx(out_delete_mispred_idx)
    );

    reservation_station_module reservation_stations (
        .in_clk(in_clk),
        .in_rst(in_reset),
        .in_op1_valid(in_op1_valid),
        .in_op2_valid(in_op2_valid),
        .in_op1_rob_index(in_op1_rob_index),
        .in_op2_rob_index(in_op2_rob_index),
        .in_op1_value(in_op1_value),
        .in_op2_value(in_op2_value),
        .in_dst(in_dst),
        .in_set_nzcv(in_set_nzcv),
        .in_rob_broadcast_done(in_rob_broadcast_done),
        .in_rob_broadcast_index(in_rob_broadcast_index),
        .in_rob_broadcast_val(in_rob_broadcast_val),
        .in_rob_is_mispred(in_rob_is_mispred),
        .in_fu_ready(in_fu_ready),
        .in_fu_done(in_fu_done),
        .out_ready_index(out_ready_index)
    );

    //TODO()

    // todo dispatch
    dispatch dp (
        .in_clk(in_clk),
        .in_stall(in_stall),
        .in_insnbits(in_insnbits),
        .in_fetch_done(in_fetch_done),
        .out_src1(out_src1),
        .out_src2(out_src2),
        .out_fu(out_fu),
        .out_dst(out_dst),
        .out_stalled(out_stalled)
    );

endmodule
