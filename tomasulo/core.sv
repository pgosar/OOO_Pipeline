`include "data_structures.sv"

// TODO(Nate): Our nzcv logic is flawed. We currently base a lot of logic based
// on whether we the current instruction will set the nzcv flags or not. This
// is incorrect. A value does not need to wait for the nzcv if it sets nzcv
// flags. It only waits if its operation's result is DEPENDANT upon the current
// nzcv flags. We need extra inputs for this.

module core (
    // input logic in_rst,
    // input logic in_start
    //input logic in_clk
);
  initial begin
    $dumpfile("core.vcd");  // Dump waveform to VCD file
    $dumpvars(0, core);  // Dump all signals
  end

  logic in_rst;
  logic in_clk;

  // FETCH
  logic in_rob_mispredict;
  logic [`GPR_SIZE-1:0] in_rob_new_PC;
  logic out_d_done;
  logic [`INSNBITS_SIZE-1:0] out_d_insnbits;
  logic [`GPR_SIZE-1:0] out_d_pc;

  // DISPATCH
  logic in_fetch_done;
  logic [`INSNBITS_SIZE-1:0] in_fetch_insnbits;
  logic [`GPR_SIZE-1:0] in_fetch_pc;
  logic out_reg_done;
  logic d_out_reg_set_nzcv;
  logic out_reg_use_imm;
  logic [`IMMEDIATE_SIZE-1:0] out_reg_imm;
  logic [`GPR_IDX_SIZE-1:0] out_reg_src1;
  logic out_reg_src1_used;
  reg_status_t out_reg_src1_status;
  logic [`GPR_IDX_SIZE-1:0] out_reg_src2;
  logic out_reg_src2_used;
  reg_status_t out_reg_src2_status;
  fu_t out_reg_fu_id;
  fu_op_t out_reg_fu_op;
  logic [`GPR_IDX_SIZE-1:0] out_reg_dst;
  reg_status_t out_reg_dst_status;
  cond_t out_reg_cond_codes;
  logic out_reg_uses_nzcv;
  logic out_reg_mispredict;
  logic [`GPR_SIZE-1:0] out_reg_pc;
  logic out_reg_uses_signed_immediate;
  opcode_t out_reg_opcode;

  // REGFILE

  logic in_d_uses_signed_immediate;
  logic in_d_done;
  logic in_d_set_nzcv;
  logic in_d_use_imm;
  logic [`IMMEDIATE_SIZE-1:0] in_d_imm;
  logic [`GPR_IDX_SIZE-1:0] in_d_src1;
  reg_status_t in_d_src1_status;
  logic [`GPR_IDX_SIZE-1:0] in_d_src2;
  reg_status_t in_d_src2_status;
  fu_t in_d_fu_id;
  fu_op_t in_d_fu_op;
  logic [`GPR_IDX_SIZE-1:0] in_d_dst;
  reg_status_t in_d_dst_status;
  logic in_d_uses_nzcv;
  logic in_d_mispredict;
  logic [`GPR_SIZE-1:0] in_d_pc;
  logic in_d_bcond;
  cond_t in_d_cond_codes;
  logic [`GPR_SIZE-1:0] in_d_branch_PC;
  opcode_t in_d_opcode;
  logic in_rob_should_commit;
  logic reg_in_rob_set_nzcv;
  nzcv_t reg_in_rob_nzcv;
  logic [`GPR_SIZE-1:0] in_rob_commit_value;
  logic [`GPR_IDX_SIZE-1:0] in_rob_reg_index;
  logic [`ROB_IDX_SIZE-1:0] in_rob_commit_rob_index;
  logic [`ROB_IDX_SIZE-1:0] in_rob_next_rob_index;
  logic reg_out_rob_done;
  logic out_rob_src1_valid;
  logic out_rob_src2_valid;
  logic out_rob_nzcv_valid;
  logic [`GPR_IDX_SIZE-1:0] out_rob_dst;
  logic [`ROB_IDX_SIZE-1:0] out_rob_src1_rob_index;
  logic [`ROB_IDX_SIZE-1:0] out_rob_src2_rob_index;
  logic [`ROB_IDX_SIZE-1:0] out_rob_nzcv_rob_index;
  logic [`GPR_SIZE-1:0] out_rob_src1_value;
  logic signed [`GPR_SIZE-1:0] out_rob_src2_value;
  logic out_rob_uses_nzcv;
  nzcv_t reg_out_rob_nzcv;
  logic reg_out_rob_set_nzcv;
  fu_t out_rob_fu_id;
  fu_op_t out_rob_fu_op;
  cond_t out_rob_cond_codes;
  logic out_rob_mispredict;
  logic out_rob_bcond;

  // ROB

  logic in_fu_done;
  logic in_fu_alu_condition;
  logic [`ROB_IDX_SIZE-1:0] in_fu_dst_rob_index;
  logic [`GPR_SIZE-1:0] in_fu_value;
  logic in_fu_set_nzcv;
  nzcv_t in_fu_nzcv;
  logic in_fu_is_mispred;
  logic in_reg_done;
  logic in_reg_src1_valid;
  logic in_reg_src2_valid;
  logic in_reg_nzcv_valid;
  logic in_reg_mispredict;
  logic in_reg_bcond;
  logic [`GPR_IDX_SIZE-1:0] in_reg_dst;
  logic [`ROB_IDX_SIZE-1:0] in_reg_src1_rob_index;
  logic [`ROB_IDX_SIZE-1:0] in_reg_src2_rob_index;
  logic [`ROB_IDX_SIZE-1:0] in_reg_nzcv_rob_index;
  logic [`GPR_SIZE-1:0] in_reg_src1_value;
  logic signed[`GPR_SIZE-1:0] in_reg_src2_value;
  logic in_reg_set_nzcv;
  nzcv_t in_reg_nzcv;
  fu_t in_reg_fu_id;
  fu_op_t in_reg_fu_op;
  cond_t in_reg_cond_codes;
  logic in_reg_uses_nzcv;
  cond_t out_rs_cond_codes;
  logic out_rs_done;
  fu_t out_rs_fu_id;
  integer out_rs_stur_counter;
  fu_op_t out_rs_fu_op;
  logic out_rs_alu_val_a_valid;
  logic out_rs_alu_val_b_valid;
  logic out_rs_nzcv_valid;
  logic [`GPR_SIZE-1:0] out_rs_alu_val_a_value;
  logic [`GPR_SIZE-1:0] out_rs_alu_val_b_value;
  logic out_rs_uses_nzcv;
  nzcv_t out_rs_nzcv;
  logic out_rs_set_nzcv;
  logic [`ROB_IDX_SIZE-1:0] out_rs_alu_val_a_rob_index;
  logic [`ROB_IDX_SIZE-1:0] out_rs_alu_val_b_rob_index;
  logic [`ROB_IDX_SIZE-1:0] out_rs_alu_dst_rob_index;
  logic [`ROB_IDX_SIZE-1:0] out_rs_nzcv_rob_index;
  logic [`ROB_IDX_SIZE-1:0] out_reg_next_rob_index;
  logic out_rs_broadcast_done;
  logic [`ROB_IDX_SIZE-1:0] out_rs_broadcast_index;
  logic [`GPR_SIZE-1:0] out_rs_broadcast_value;
  logic out_rs_broadcast_set_nzcv;
  nzcv_t out_rs_broadcast_nzcv;
  logic out_rs_is_mispred;
  logic out_rs_commit_done;
  logic out_reg_commit_done;
  logic rob_out_reg_set_nzcv;
  nzcv_t out_reg_nzcv;
  logic [`GPR_SIZE-1:0] out_reg_commit_value;
  logic [`GPR_IDX_SIZE-1:0] out_reg_index;
  logic [`ROB_IDX_SIZE-1:0] out_reg_commit_rob_index;

  // RESERVATION STATIONS

  cond_t rs_in_rob_alu_cond_codes;
  logic in_rob_commit_done;
  logic in_rob_done;
  fu_t in_rob_fu_id;
  fu_op_t in_rob_fu_op;
  integer in_rob_stur_counter;
  logic in_rob_alu_val_a_valid;
  logic in_rob_alu_val_b_valid;
  logic in_rob_nzcv_valid;
  logic [`GPR_SIZE-1:0] in_rob_alu_val_a_value;
  logic [`GPR_SIZE-1:0] in_rob_alu_val_b_value;
  nzcv_t rs_in_rob_nzcv;
  logic rs_in_rob_set_nzcv;
  logic [`ROB_IDX_SIZE-1:0] in_rob_alu_val_a_rob_index;
  logic [`ROB_IDX_SIZE-1:0] in_rob_alu_val_b_rob_index;
  logic [`ROB_IDX_SIZE-1:0] in_rob_dst_rob_index;
  logic [`ROB_IDX_SIZE-1:0] in_rob_nzcv_rob_index;
  logic in_rob_broadcast_done;
  logic [`ROB_IDX_SIZE-1:0] in_rob_broadcast_index;
  logic [`GPR_SIZE-1:0] in_rob_broadcast_value;
  logic in_rob_broadcast_set_nzcv;
  nzcv_t in_rob_broadcast_nzcv;
  logic in_rob_is_mispred;
  logic in_rob_uses_nzcv;
  logic in_fu_ls_ready;
  logic in_fu_alu_ready;
  logic out_fu_alu_start;
  fu_op_t out_fu_op;
  logic [`GPR_SIZE-1:0] out_fu_alu_val_a;
  logic [`GPR_SIZE-1:0] out_fu_alu_val_b;
  logic [`ROB_IDX_SIZE-1:0] out_fu_dst_rob_index;
  logic out_fu_alu_set_nzcv;
  nzcv_t out_fu_alu_nzcv;
  cond_t out_fu_cond_codes;
  logic out_fu_ls_start;
  fu_op_t out_fu_ls_op;
  logic [`GPR_SIZE-1:0] out_fu_ls_val_a;
  logic [`GPR_SIZE-1:0] out_fu_ls_val_b;
  logic [`ROB_IDX_SIZE-1:0] out_fu_ls_dst_rob_index;
  logic [`GPR_SIZE-1:0] out_fetch_new_PC;
  logic out_fetch_mispredict;
  logic out_fu_commit_done;

  // FUNC UNITS

  logic in_rs_alu_start;
  fu_op_t in_rs_alu_fu_op;
  logic [`GPR_SIZE-1:0] in_rs_alu_val_a;
  logic [`GPR_SIZE-1:0] in_rs_alu_val_b;
  logic [`ROB_IDX_SIZE-1:0] in_rs_alu_dst_rob_index;
  logic in_rs_alu_set_nzcv;
  nzcv_t in_rs_alu_nzcv;
  cond_t fu_in_rob_alu_cond_codes;
  logic in_rs_ls_start;
  fu_op_t in_rs_ls_fu_op;
  logic in_rs_commit_done;
  logic [`GPR_SIZE-1:0] in_rs_ls_val_a;
  logic [`GPR_SIZE-1:0] in_rs_ls_val_b;
  logic [`ROB_IDX_SIZE-1:0] in_rs_ls_dst_rob_index;
  logic out_rs_alu_ready;
  logic out_rs_ls_ready;
  logic fu_out_rob_done;
  logic [`ROB_IDX_SIZE-1:0] out_rob_dst_rob_index;
  logic [`GPR_SIZE-1:0] out_rob_value;
  logic fu_out_rob_set_nzcv;
  nzcv_t fu_out_rob_nzcv;
  logic out_alu_condition;


  // for now just run a single cycle
  int i;
  initial begin
    in_clk = 0;
    for (i = 1; i <= 40; i += 1) begin
      `DEBUG(("\n>>>>> CYCLE COUNT: %0d <<<<<", i));
      #1 in_clk = ~in_clk;  // 100 MHz clock
      #5 in_clk = ~in_clk;
      #4;
    end
  end

  initial begin
    in_rst = 1;
    #10;
    in_rst = 0;
    `DEBUG(("RESET DONE === BEGIN TEST"));
  end

  // FETCH to DISPATCH dispatch inputs = fetch outputs
  assign in_fetch_done = out_d_done;
  assign in_fetch_insnbits = out_d_insnbits;
  assign in_fetch_pc = out_d_pc;

  // DISPATCH to REG reg inputs = dispatch outputs
  assign in_d_done = out_reg_done;
  assign in_d_set_nzcv = d_out_reg_set_nzcv;
  assign in_d_use_imm = out_reg_use_imm;
  assign in_d_imm = out_reg_imm;
  assign in_d_src1 = out_reg_src1;
  assign in_d_src1_status = out_reg_src1_status;
  assign in_d_src2 = out_reg_src2;
  assign in_d_src2_status = out_reg_src2_status;
  assign in_d_fu_id = out_reg_fu_id;
  assign in_d_fu_op = out_reg_fu_op;
  assign in_d_dst = out_reg_dst;
  assign in_d_dst_status = out_reg_dst_status;
  assign in_d_cond_codes = out_reg_cond_codes;
  assign in_d_uses_nzcv = out_reg_uses_nzcv;
  assign in_d_mispredict = out_reg_mispredict;
  assign in_d_uses_signed_immediate = out_reg_uses_signed_immediate;
  // assign in_d_bcond = out_reg_bcond;
  assign in_d_pc = out_reg_pc;
  assign in_d_opcode = out_reg_opcode;

  // ROB to REG reg inputs = rob outputs
  assign in_rob_should_commit = out_reg_commit_done;
  assign reg_in_rob_set_nzcv = rob_out_reg_set_nzcv;
  assign reg_in_rob_nzcv = out_reg_nzcv;
  assign in_rob_commit_value = out_reg_commit_value;
  assign in_rob_reg_index = out_reg_index;
  assign in_rob_commit_rob_index = out_reg_commit_rob_index;
  assign in_rob_next_rob_index = out_reg_next_rob_index;

  // REG to ROB rob inputs = reg outputs
  assign in_reg_done = reg_out_rob_done;
  assign in_reg_src1_valid = out_rob_src1_valid;
  assign in_reg_src2_valid = out_rob_src2_valid;
  assign in_reg_nzcv_valid = out_rob_nzcv_valid;
  assign in_reg_dst = out_rob_dst;
  assign in_reg_src1_rob_index = out_rob_src1_rob_index;
  assign in_reg_src2_rob_index = out_rob_src2_rob_index;
  assign in_reg_nzcv_rob_index = out_rob_nzcv_rob_index;
  assign in_reg_src1_value = out_rob_src1_value;
  assign in_reg_src2_value = out_rob_src2_value;
  assign in_reg_set_nzcv = reg_out_rob_set_nzcv;
  assign in_reg_nzcv = reg_out_rob_nzcv;
  assign in_reg_fu_id = out_rob_fu_id;
  assign in_reg_fu_op = out_rob_fu_op;
  assign in_reg_cond_codes = out_rob_cond_codes;
  assign in_reg_uses_nzcv = out_rob_uses_nzcv;
  assign in_reg_mispredict = out_rob_mispredict;
  assign in_reg_bcond = out_rob_bcond;

  // ROB to RS rs inputs = rob outputs
  assign in_rob_stur_counter = out_rs_stur_counter;
  assign rs_in_rob_alu_cond_codes = out_rs_cond_codes;
  assign in_rob_done = out_rs_done;
  assign in_rob_fu_id = out_rs_fu_id;
  assign in_rob_fu_op = out_rs_fu_op;
  assign in_rob_commit_done = out_rs_commit_done;
  assign in_rob_alu_val_a_valid = out_rs_alu_val_a_valid;
  assign in_rob_alu_val_b_valid = out_rs_alu_val_b_valid;
  assign in_rob_nzcv_valid = out_rs_nzcv_valid;
  assign in_rob_alu_val_a_value = out_rs_alu_val_a_value;
  assign in_rob_alu_val_b_value = out_rs_alu_val_b_value;
  assign rs_in_rob_nzcv = out_rs_nzcv;
  assign rs_in_rob_set_nzcv = out_rs_set_nzcv;
  assign in_rob_alu_val_a_rob_index = out_rs_alu_val_a_rob_index;
  assign in_rob_alu_val_b_rob_index = out_rs_alu_val_b_rob_index;
  assign in_rob_dst_rob_index = out_rs_alu_dst_rob_index;
  assign in_rob_nzcv_rob_index = out_rs_nzcv_rob_index;
  assign in_rob_broadcast_done = out_rs_broadcast_done;
  assign in_rob_broadcast_index = out_rs_broadcast_index;
  assign in_rob_broadcast_value = out_rs_broadcast_value;
  assign in_rob_broadcast_set_nzcv = out_rs_broadcast_set_nzcv;
  assign in_rob_broadcast_nzcv = out_rs_broadcast_nzcv;
  assign in_rob_is_mispred = out_rs_is_mispred;
  assign in_rob_uses_nzcv = out_rs_uses_nzcv;

  // RS to FUNC UNITS fu inputs = rs outputs
  assign in_rs_alu_start = out_fu_alu_start;
  assign in_rs_alu_fu_op = out_fu_op;
  assign in_rs_alu_val_a = out_fu_alu_val_a;
  assign in_rs_alu_val_b = out_fu_alu_val_b;
  assign in_rs_alu_dst_rob_index = out_fu_dst_rob_index;
  assign in_rs_alu_set_nzcv = out_fu_alu_set_nzcv;
  assign in_rs_alu_nzcv = out_fu_alu_nzcv;
  assign fu_in_rob_alu_cond_codes = out_fu_cond_codes;

  assign in_rs_ls_start = out_fu_ls_start;
  assign in_rs_commit_done = out_fu_commit_done;
  assign in_rs_ls_fu_op = out_fu_ls_op;
  assign in_rs_ls_val_a = out_fu_ls_val_a;
  assign in_rs_ls_val_b = out_fu_ls_val_b;
  assign in_rs_ls_dst_rob_index = out_fu_ls_dst_rob_index;

  // FUNC UNITS to RS rs inputs = fu outputs
  assign in_fu_alu_ready = out_rs_alu_ready;
  assign in_fu_ls_ready = out_rs_ls_ready;

  // FUNC UNITS to ROB rob inputs = fu outputs
  assign in_fu_done = fu_out_rob_done;
  assign in_fu_dst_rob_index = out_rob_dst_rob_index;
  assign in_fu_value = out_rob_value;
  assign in_fu_set_nzcv = fu_out_rob_set_nzcv;
  assign in_fu_nzcv = fu_out_rob_nzcv;
  assign in_fu_alu_condition = out_alu_condition;

  // ROB to FETCH fetch inputs = rob outputs
  assign in_rob_mispredict = out_fetch_mispredict;
  assign in_rob_new_PC = out_fetch_new_PC;

  logic reset_for_mispred;
  always_ff @(negedge in_clk) begin
    reset_for_mispred = out_fetch_mispredict;
  end

  // modules
  fetch f (
      .*
      // .in_rob_mispredict(in_rob_mispredict),
      // .in_rob_new_PC(in_rob_new_PC),
      // .out_d_sigs(fetch_sigs)
  );

  dispatch dp (
      .*,
      .out_reg_set_nzcv(d_out_reg_set_nzcv)
  );

  reg_module regfile (
      .*,
      .in_rob_nzcv(reg_in_rob_nzcv),
      .in_rob_set_nzcv(reg_in_rob_set_nzcv),
      .out_rob_done(reg_out_rob_done),
      .out_rob_set_nzcv(reg_out_rob_set_nzcv),
      .out_rob_nzcv(reg_out_rob_nzcv)
  );

  rob_module rob (
      .*,
      .out_reg_set_nzcv(rob_out_reg_set_nzcv)
  );

  reservation_stations rs (
      .in_rst(in_rst | reset_for_mispred),
      .*,
      .in_rob_alu_cond_codes(rs_in_rob_alu_cond_codes),
      .in_rob_set_nzcv(rs_in_rob_set_nzcv),
      .in_rob_nzcv(rs_in_rob_nzcv)
  );

  func_units fu (
      .*,
      .out_rob_done(fu_out_rob_done),
      .out_rob_set_nzcv(fu_out_rob_set_nzcv),
      .out_rob_nzcv(fu_out_rob_nzcv),
      .in_rob_alu_cond_codes(fu_in_rob_alu_cond_codes)
  );

endmodule
