`include "data_structures.sv"

module core (
    input logic in_rst,
    input logic in_start
    //input logic in_clk
);
  initial begin
`ifdef DEBUG_PRINT
    $dumpfile("core.vcd");  // Dump waveform to VCD file
    $dumpvars(0, core);  // Dump all signals
`endif
  end

  // DISPATCH

    logic in_clk;
    logic in_stall;
    // Inputs from fetch
    logic [31:0] in_fetch_insnbits;
    logic in_fetch_done;
    // Outputs to regfile
    logic out_reg_ready;
    logic out_reg_set_nzcv; // DUPLICATE
    logic out_reg_use_imm;
    logic [`IMMEDIATE_SIZE-1:0] out_reg_imm;
    logic [`GPR_IDX_SIZE-1:0] out_reg_src1;
    logic [`GPR_IDX_SIZE-1:0] out_reg_src2;
    fu_t out_reg_fu_id;
    alu_op_t out_reg_fu_op;
    logic [`GPR_IDX_SIZE-1:0] out_reg_dst;

    // REGFILE

    // Inputs from decode (consumed in decode)
    logic in_d_ready;
    // Inputs from decode (passed through or used)
    logic [`GPR_IDX_SIZE-1:0] in_d_src1;
    logic [`GPR_IDX_SIZE-1:0] in_d_src2;
    logic [`GPR_IDX_SIZE-1:0] in_d_dst;
    logic in_d_set_nzcv;
    logic [`GPR_SIZE-1:0] in_d_imm;
    logic in_d_use_imm;
    fu_t in_d_fu_id;
    alu_op_t in_d_fu_op;
    // Inputs from ROB (for a commit)
    logic in_rob_should_commit;
    logic in_rob_set_nzcv; // DUPLICATE
    nzcv_t in_rob_nzcv; // DUPLICATE
    logic [`GPR_SIZE-1:0] in_rob_commit_value;
    logic [`GPR_IDX_SIZE-1:0] in_rob_reg_index;
    logic [`ROB_IDX_SIZE-1:0] in_rob_commit_rob_index;
    // Outputs for ROB
    logic out_rob_ready;
    logic out_rob_src1_valid;
    logic out_rob_src2_valid;
    logic out_rob_nzcv_valid;
    logic [`GPR_IDX_SIZE-1:0] out_rob_dst;  // gpr
    logic [`ROB_IDX_SIZE-1:0] out_rob_src1_rob_index'
    logic [`ROB_IDX_SIZE-1:0] out_rob_src2_rob_index'
    logic [`ROB_IDX_SIZE-1:0] out_rob_nzcv_rob_index'
    logic [`GPR_SIZE-1:0] out_rob_src1_value'
    logic [`GPR_SIZE-1:0] out_rob_src2_value'
    logic out_rob_set_nzcv;
    nzcv_t out_rob_nzcv;
    // Outputs for RS
    fu_t out_rob_fu_id;
    // Outputs for FU
    alu_op_t out_rob_fu_op;

    // ROB

    // Inputs from FU
    logic in_fu_done;
    logic [`ROB_IDX_SIZE-1:0] in_fu_dst_rob_index;
    logic [`GPR_SIZE-1:0] in_fu_value;
    logic in_fu_set_nzcv;
    nzcv_t in_fu_nzcv;
    logic in_fu_is_mispred;
    // Inputs from regfile (as part of decode)
    logic in_reg_ready,  // NOTE(Nate): Is this stall?
    logic in_reg_src1_valid;
    logic in_reg_src2_valid;
    logic in_reg_nzcv_valid;
    logic [`GPR_IDX_SIZE-1:0] in_reg_dst;
    logic [`ROB_IDX_SIZE-1:0] in_reg_src1_rob_index;
    logic [`ROB_IDX_SIZE-1:0] in_reg_src2_rob_index;
    logic [`ROB_IDX_SIZE-1:0] in_reg_nzcv_rob_index;
    logic [`GPR_SIZE-1:0] in_reg_src1_value;
    logic [`GPR_SIZE-1:0] in_reg_src2_value;
    logic in_reg_set_nzcv;
    nzcv_t in_reg_nzcv;
    fu_t in_reg_fu_id;
    alu_op_t in_reg_fu_op;
    // Outputs for RS
    logic out_rs_ready;
    fu_t out_rs_fu_id; // NOTE(Nate): Shouldn't this just go to the RS for this functional unit?
    alu_op_t out_rs_fu_op;
    logic out_rs_val_a_valid;
    logic out_rs_val_b_valid;
    logic out_rs_nzcv_valid;
    logic [`GPR_SIZE-1:0] out_rs_val_a_value;
    logic [`GPR_SIZE-1:0] out_rs_val_b_value;
    nzcv_t out_rs_nzcv;
    logic out_rs_set_nzcv;
    logic [`ROB_IDX_SIZE-1:0] out_rs_val_a_rob_index;
    logic [`ROB_IDX_SIZE-1:0] out_rs_val_b_rob_index;
    logic [`ROB_IDX_SIZE-1:0] out_rs_dst_rob_idx;
    logic [`ROB_IDX_SIZE-1:0] out_rs_nzcv_rob_idx;
    // Outputs for RS (on broadcast... resultant from FU)
    logic out_rs_should_broadcast;
    logic [`ROB_IDX_SIZE-1:0] out_rs_broadcast_index;
    logic [`GPR_SIZE-1:0] out_rs_broadcast_value;
    logic out_rs_broadcast_set_nzcv;
    nzcv_t out_rs_broadcast_nzcv;
    // Outputs for regfile (for commits)
    logic out_reg_should_commit;
    logic out_reg_set_nzcv;
    nzcv_t out_reg_nzcv;
    logic [`GPR_SIZE-1:0] out_reg_commit_value;
    logic [`GPR_IDX_SIZE-1:0] out_reg_index;
    logic [`ROB_IDX_SIZE-1:0] out_reg_commit_rob_index;

    // RESERVATION STATIONS

    // Inputs From ROB (sourced from either regfile or ROB)
     alu_op_t in_rob_fu_op;
     fu_t in_rob_fu_id;
     logic in_rob_val_a_valid;
     logic in_rob_val_b_valid;
     logic in_rob_nzcv_valid;
     logic [`GPR_SIZE-1:0] in_rob_val_a_value;
     logic [`GPR_SIZE-1:0] in_rob_val_b_value;
     nzcv_t in_rob_nzcv;
     logic in_rob_set_nzcv;
     logic [`ROB_IDX_SIZE-1:0] in_rob_val_a_rob_index;
     logic [`ROB_IDX_SIZE-1:0] in_rob_val_b_rob_index;
     logic [`GPR_IDX_SIZE-1:0] in_rob_dst_rob_idx;
     logic in_rob_should_broadcast;
     logic [`ROB_IDX_SIZE-1:0] in_rob_broadcast_index;
     logic [`GPR_SIZE-1:0] in_rob_broadcast_value;
    // input logic in_rob_is_mispred,
    // Inputs from FU
    logic in_fu_ready;  // ready to receive inputs
    // Outputs for FU
    logic [`GPR_SIZE-1:0] out_fu_val_a;
    logic [`GPR_SIZE-1:0] out_fu_val_b;
    logic [`ROB_IDX_SIZE-1:0] out_fu_dst_rob_index;
    logic out_fu_set_nzcv;
    nzcv_t out_fu_nzcv;

    // ALU

    alu_op_t in_alu_op;
    logic [`GPR_SIZE-1:0] in_val_a;
    logic [`GPR_SIZE-1:0] in_val_b;
    logic [5:0] in_alu_val_hw;
    logic in_set_CC;
    cond_t in_cond;
    nzcv_t in_prev_nzcv;
    logic out_cond_val;
    logic [`GPR_SIZE-1:0] out_res;
    nzcv_t out_nzcv;
    logic out_fu_done;

  // for now just run a single cycle
  initial begin
    in_clk = 0;
    for (int i = 0; i < 3; i += 1) #5 in_clk = ~in_clk;  // 100 MHz clock
  end

  initial begin
    in_rst = 1;
    #10 in_rst = 0;
    in_fetch_insnbits = 32'b1001000100_111111111111_00001_00001;  // add x1, x1, #0xfff
    #10 in_fetch_insnbits = 'b1101_0101_0000_0011_0010_0000_0001_1111;  // NOP
  end

  // DISPATCH TO REGFILE
  assign in_d_ready = out_reg_ready;
  assign in_d_set_nzcv = out_reg_set_nzcv;
  assign in_d_use_imm = out_reg_use_imm;
  assign in_d_imm = out_reg_imm;
  assign in_d_src1 = out_reg_src1;
  assign in_d_src2 = out_reg_src2;
  assign in_d_fu_id = out_reg_fu_id;
  assign in_d_fu_op = out_reg_fu_op;
  assign in_d_dst = out_reg_dst;

  // ROB TO REGFILE
  assign in_rob_should_commit = out_reg_should_commit;
  assign in_rob_set_nzcv = out_reg_set_nzcv;
  assign in_rob_nzcv = out_reg_nzcv;
  assign in_rob_commit_value = out_reg_commit_value;
  assign in_rob_reg_index = out_reg_index;
  assign in_rob_commit_rob_index = out_reg_commit_rob_index;

  // REGFILE TO ROB
  assign out_rob_ready = in_reg_ready;
  assign out_rob_src1_valid = in_reg_src1_valid;
  assign out_rob_src2_valid = in_reg_src2_valid;
  assign out_rob_nzcv_valid = in_reg_nzcv_valid;
  assign out_rob_dst = in_reg_dst;
  assign out_rob_src1_rob_index = in_reg_src1_rob_index;
  assign out_rob_src2_rob_index = in_reg_src2_rob_index;
  assign out_rob_nzcv_rob_index = in_reg_nzcv_rob_index;
  assign out_rob_src1_value = in_reg_src1_value;
  assign out_rob_src2_value = in_reg_src2_value;
  assign out_rob_set_nzcv = in_reg_set_nzcv;
  assign out_rob_nzcv = in_reg_nzcv;
  assign out_rob_fu_id = in_reg_fu_id;
  assign out_rob_fu_op = in_reg_fu_op;

  // FU TO ROB


  // modules
  dispatch dp (.*);
  reg_module regfile (.*);
  rob_module rob (.*);
  reservation_stations rs (.*);
  ArithmeticExecuteUnit alu (.*);

endmodule
