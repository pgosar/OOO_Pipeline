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
`ifdef DEBUG_PRINT
    $dumpfile("core.vcd");  // Dump waveform to VCD file
    $dumpvars(0, core);  // Dump all signals
`endif
  end

  // DISPATCH
  logic in_rst;
  logic in_clk;
  logic in_stall;
  // Inputs from fetch
  logic [31:0] in_fetch_insnbits;
  logic in_fetch_done;
  // Outputs to regfile
  logic out_reg_done;
  logic dispatch_out_reg_set_nzcv;
  logic out_reg_use_imm;
  logic [`IMMEDIATE_SIZE-1:0] out_reg_imm;
  logic [`GPR_IDX_SIZE-1:0] out_reg_src1;
  logic [`GPR_IDX_SIZE-1:0] out_reg_src2;
  fu_t out_reg_fu_id;
  fu_op_t out_reg_fu_op;
  logic [`GPR_IDX_SIZE-1:0] out_reg_dst;
  cond_t out_reg_cond_codes;
  logic out_reg_instr_uses_nzcv;

  // REGFILE

  // Inputs from decode (consumed in decode)
  logic in_d_done;
  // Inputs from decode (passed through or used)
  logic [`GPR_IDX_SIZE-1:0] in_d_src1;
  logic [`GPR_IDX_SIZE-1:0] in_d_src2;
  logic [`GPR_IDX_SIZE-1:0] in_d_dst;
  logic in_d_set_nzcv;
  logic [`GPR_SIZE-1:0] in_d_imm;
  logic in_d_use_imm;
  fu_t in_d_fu_id;
  fu_op_t in_d_fu_op;
  logic in_d_instr_uses_nzcv;
  // Inputs from ROB (for a commit)
  logic in_rob_should_commit;
  logic reg_in_rob_set_nzcv;
  nzcv_t reg_in_rob_nzcv;
  logic [`GPR_SIZE-1:0] in_rob_commit_value;
  logic [`GPR_IDX_SIZE-1:0] in_rob_reg_index;
  logic [`ROB_IDX_SIZE-1:0] in_rob_commit_rob_index;
  // Inputs from ROB (invalid GPR)
  logic [`ROB_IDX_SIZE-1:0] in_rob_next_rob_index;
  // Outputs for ROB
  logic reg_out_rob_done;
  logic out_rob_src1_valid;
  logic out_rob_src2_valid;
  logic out_rob_nzcv_valid;
  fu_op_t out_rob_fu_op;
  logic [`GPR_IDX_SIZE-1:0] out_rob_dst;  // gpr
  logic [`ROB_IDX_SIZE-1:0] out_rob_src1_rob_index;
  logic [`ROB_IDX_SIZE-1:0] out_rob_src2_rob_index;
  logic [`ROB_IDX_SIZE-1:0] out_rob_nzcv_rob_index;
  logic [`GPR_SIZE-1:0] out_rob_src1_value;
  logic [`GPR_SIZE-1:0] out_rob_src2_value;
  logic out_rob_set_nzcv;
  nzcv_t out_rob_nzcv;
  cond_t out_rob_cond_codes;
  fu_t out_rob_fu_id;
  logic out_rob_instr_uses_nzcv;

  // ROB
  // Inputs from FU
  logic in_fu_done;
  logic [`ROB_IDX_SIZE-1:0] in_fu_dst_rob_index;
  logic [`GPR_SIZE-1:0] in_fu_value;
  logic in_fu_set_nzcv;
  nzcv_t in_fu_nzcv;
  // logic in_fu_is_mispred;
  // Inputs from regfile (as part of decode)
  logic in_reg_done;
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
  fu_op_t in_reg_fu_op;
  cond_t in_reg_cond_codes;
  logic in_reg_instr_uses_nzcv;
  // Outputs for RS
  logic out_rs_done;
  fu_t out_rs_fu_id;
  fu_op_t out_rs_fu_op;
  logic out_rs_val_a_valid;
  logic out_rs_val_b_valid;
  logic out_rs_nzcv_valid;
  logic [`GPR_SIZE-1:0] out_rs_val_a_value;
  logic [`GPR_SIZE-1:0] out_rs_val_b_value;
  logic out_rs_instr_uses_nzcv;
  nzcv_t out_rs_nzcv;
  logic out_rs_set_nzcv;
  logic [`ROB_IDX_SIZE-1:0] out_rs_val_a_rob_index;
  logic [`ROB_IDX_SIZE-1:0] out_rs_val_b_rob_index;
  logic [`ROB_IDX_SIZE-1:0] out_rs_dst_rob_index;
  logic [`ROB_IDX_SIZE-1:0] out_rs_nzcv_rob_index;
  cond_t out_rs_cond_codes;
  // Output for regfile (for the next ROB insertion)
  logic [`ROB_IDX_SIZE-1:0] out_reg_next_rob_index;
  // Outputs for RS (on broadcast... resultant from FU)
  logic out_rs_broadcast_done;
  logic [`ROB_IDX_SIZE-1:0] out_rs_broadcast_index;
  logic [`GPR_SIZE-1:0] out_rs_broadcast_value;
  logic out_rs_broadcast_set_nzcv;
  nzcv_t out_rs_broadcast_nzcv;
  // Outputs for regfile (for commits)
  logic out_reg_commit_done;
  logic rob_out_reg_set_nzcv;
  nzcv_t out_reg_nzcv;
  logic [`GPR_SIZE-1:0] out_reg_commit_value;
  logic [`GPR_IDX_SIZE-1:0] out_reg_index;
  logic [`ROB_IDX_SIZE-1:0] out_reg_commit_rob_index;


  // RESERVATION STATIONS
  // Inputs From ROB (sourced from either regfile or ROB)
  logic in_rob_done;
  fu_t in_rob_fu_id;
  fu_op_t in_rob_fu_op;
  logic in_rob_val_a_valid;
  logic in_rob_val_b_valid;
  logic in_rob_nzcv_valid;
  logic [`GPR_SIZE-1:0] in_rob_val_a_value;
  logic [`GPR_SIZE-1:0] in_rob_val_b_value;
  logic in_rob_instr_uses_nzcv;
  nzcv_t in_rob_nzcv;
  logic in_rob_set_nzcv;
  logic [`ROB_IDX_SIZE-1:0] in_rob_val_a_rob_index;
  logic [`ROB_IDX_SIZE-1:0] in_rob_val_b_rob_index;
  logic [`GPR_IDX_SIZE-1:0] in_rob_dst_rob_index;
  logic [`GPR_IDX_SIZE-1:0] in_rob_nzcv_rob_index;
  cond_t in_rob_cond_codes;
  // Inputs from ROB (for broadcast)
  logic in_rob_broadcast_done;
  logic [`ROB_IDX_SIZE-1:0] in_rob_broadcast_index;
  logic [`GPR_SIZE-1:0] in_rob_broadcast_value;
  logic in_rob_broadcast_set_nzcv;
  nzcv_t in_rob_broadcast_nzcv;
  // Inputs from FU (mispred)
  // logic in_rob_is_mispred;
  // Inputs from FU (ALU)
  logic in_fu_alu_ready;
  // Outputs for FU (ALU)
  logic out_fu_alu_start;
  fu_op_t out_fu_alu_op;
  logic [`GPR_SIZE-1:0] out_fu_alu_val_a;
  logic [`GPR_SIZE-1:0] out_fu_alu_val_b;
  logic [`ROB_IDX_SIZE-1:0] out_fu_alu_dst_rob_index;
  logic out_fu_alu_set_nzcv;
  nzcv_t out_fu_alu_nzcv;
  cond_t out_fu_alu_cond_codes;
  // Inputs from FU (LS)
  logic in_fu_ls_ready;
  // Outputs for FU (LS)
  logic out_fu_ls_start;
  fu_op_t out_fu_ls_op;
  logic [`GPR_SIZE-1:0] out_fu_ls_val_a;
  logic [`GPR_SIZE-1:0] out_fu_ls_val_b;
  logic [`ROB_IDX_SIZE-1:0] out_fu_ls_dst_rob_index;


  // FUNC UNITS
  logic in_rs_alu_start;
  fu_op_t in_rs_alu_op;
  fu_op_t in_rs_ls_op;
  logic [`GPR_SIZE-1:0] in_rs_alu_val_a;
  logic [`GPR_SIZE-1:0] in_rs_alu_val_b;
  logic [`ROB_IDX_SIZE-1:0] in_rs_alu_dst_rob_index;
  logic in_rs_alu_set_nzcv;
  nzcv_t in_rs_alu_nzcv;
  logic in_rs_instr_uses_nzcv;
  cond_t in_rs_alu_cond_codes;
  // Inputs for FU (LS)
  logic in_rs_ls_start;
  logic [`GPR_SIZE-1:0] in_rs_ls_val_a;
  logic [`GPR_SIZE-1:0] in_rs_ls_val_b;
  logic [`ROB_IDX_SIZE-1:0] in_rs_ls_dst_rob_index;

  // Outputs for RS
  logic out_rs_ls_ready;
  logic out_rs_alu_ready;
  // Outputs for ROB
  logic fu_out_rob_done;  // Used for both ROB and FU
  logic [`ROB_IDX_SIZE-1:0] out_rob_dst_rob_index;
  logic [`GPR_SIZE-1:0] out_rob_value;
  logic fu_out_rob_set_nzcv;
  nzcv_t fu_out_rob_nzcv;
  logic out_fu_instr_uses_nzcv;
  logic out_rob_is_mispred;
  logic out_alu_condition;

  int i;
  initial begin
    in_clk = 0;
    for (i = 1; i <= 25; i += 1) begin
      `DEBUG(("\n>>>>> CYCLE COUNT: %0d <<<<<", i))
      #1 in_clk = ~in_clk;  // 100 MHz clock
      #5 in_clk = ~in_clk;
      #4;
    end
  end

  initial begin
    in_rst = 1;
    #10;
    in_rst = 0;
    `DEBUG(("RESET DONE === BEGIN TEST"))
    while (in_fetch_insnbits != 0) begin
      `DEBUG(("itr"))
      `DEBUG(("*******insnbits: %b", in_fetch_insnbits))
      #10;
    end
  end

  // DISPATCH TO REGFILE (copy args) regfile inputs = dispatch outputs
  assign in_d_done = out_reg_done;
  assign in_d_set_nzcv = dispatch_out_reg_set_nzcv;
  assign in_d_use_imm = out_reg_use_imm;
  assign in_d_imm = out_reg_imm;
  assign in_d_src1 = out_reg_src1;
  assign in_d_src2 = out_reg_src2;
  assign in_d_fu_id = out_reg_fu_id;
  assign in_d_fu_op = out_reg_fu_op;
  assign in_d_dst = out_reg_dst;
  assign in_d_instr_uses_nzcv = out_reg_instr_uses_nzcv;

  // // ROB TO REGFILE (on COMMIT) regfile inputs = rob outputs
  assign in_rob_should_commit = out_reg_commit_done;
  assign reg_in_rob_set_nzcv = rob_out_reg_set_nzcv;
  assign reg_in_rob_nzcv = out_reg_nzcv;
  assign in_rob_commit_value = out_reg_commit_value;
  assign in_rob_reg_index = out_reg_index;
  assign in_rob_commit_rob_index = out_reg_commit_rob_index;
  assign in_rob_next_rob_index = out_reg_next_rob_index;

  // REGFILE TO ROB rob inputs = regfile outputs
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
  assign in_reg_set_nzcv = out_rob_set_nzcv;
  assign in_reg_nzcv = out_rob_nzcv;
  assign in_reg_fu_id = out_rob_fu_id;
  assign in_reg_fu_op = out_rob_fu_op;
  assign in_reg_cond_codes = out_rob_cond_codes;
  assign in_reg_instr_uses_nzcv = out_rob_instr_uses_nzcv;

  // ROB TO RS rs inputs = rob outputs
  // Inputs From ROB (sourced from either regfile or ROB)
  assign in_rob_done = out_rs_done;
  assign in_rob_fu_id = out_rs_fu_id;
  assign in_rob_fu_op = out_rs_fu_op;
  assign in_rob_val_a_valid = out_rs_val_a_valid;
  assign in_rob_val_b_valid = out_rs_val_b_valid;
  assign in_rob_nzcv_valid = out_rs_nzcv_valid;
  assign in_rob_val_a_value = out_rs_val_a_value;
  assign in_rob_val_b_value = out_rs_val_b_value;
  assign in_rob_instr_uses_nzcv = out_rs_instr_uses_nzcv;
  assign in_rob_nzcv = out_rs_nzcv;
  assign in_rob_set_nzcv = out_rs_set_nzcv;
  assign in_rob_val_a_rob_index = out_rs_val_a_rob_index;
  assign in_rob_val_b_rob_index = out_rs_val_b_rob_index;
  assign in_rob_dst_rob_index = out_rs_dst_rob_index;
  assign in_rob_nzcv_rob_index = out_rs_nzcv_rob_index;
  assign in_rob_cond_codes = out_rs_cond_codes;

  // Inputs from ROB (for broadcast)
  assign in_rob_broadcast_done = out_rs_broadcast_done;
  assign in_rob_broadcast_index = out_rs_broadcast_index;
  assign in_rob_broadcast_value = out_rs_broadcast_value;
  assign in_rob_broadcast_set_nzcv = out_rs_broadcast_set_nzcv;
  assign in_rob_broadcast_nzcv = out_rs_broadcast_nzcv;
  // Inputs from FU (ALU)
  assign in_fu_alu_ready = out_rs_alu_ready;

  // Outputs for FU (ALU) FU inputs = RS outputs
  assign in_rs_alu_start = out_fu_alu_start;
  assign in_rs_alu_op = out_fu_alu_op;
  assign in_rs_alu_val_a = out_fu_alu_val_a;
  assign in_rs_alu_val_b = out_fu_alu_val_b;
  assign in_rs_alu_dst_rob_index = out_fu_alu_dst_rob_index;
  assign in_rs_alu_set_nzcv = out_fu_alu_set_nzcv;
  assign in_rs_alu_nzcv = out_fu_alu_nzcv;
  assign in_rs_alu_cond_codes = out_fu_alu_cond_codes;

  // Inputs from FU (LS)
  assign in_fu_ls_ready = out_rs_ls_ready;
  // Outputs for FU (LS)

  assign in_rs_ls_start = out_fu_ls_start;
  assign in_rs_ls_op = out_fu_ls_op;
  assign in_rs_ls_val_a = out_fu_ls_val_a;
  assign in_rs_ls_val_b = out_fu_ls_val_b;
  assign in_rs_ls_dst_rob_index = out_fu_ls_dst_rob_index;

  // FU TO ROB rob inputs = fu outputs
  assign in_fu_done = fu_out_rob_done;
  assign in_fu_dst_rob_index = out_rob_dst_rob_index;
  assign in_fu_value = out_rob_value;
  assign in_fu_set_nzcv = out_rob_set_nzcv;
  assign in_fu_nzcv = out_rob_nzcv;
  // assign in_fu_is_mispred = out_rob_is_mispred;

  // modules
  fetch f (
    .in_clk,
    .in_rst,
    .out_d_sigs(fetch_sigs)
  );

  fetch_interface fetch_sigs();

  dispatch dp (
      .in_clk,
      .in_rst,
      .in_fetch_sigs(fetch_sigs),
      .out_reg_sigs(d_sigs)
  );

  decode_interface d_sigs();

  reg_module regfile (
      .*,
      .in_d_sigs(d_sigs),
      .in_rob_nzcv(reg_in_rob_nzcv),
      .in_rob_set_nzcv(reg_in_rob_set_nzcv),
      .out_rob_done(reg_out_rob_done)
  );

  rob_module rob (
      .*,
      .out_reg_set_nzcv(rob_out_reg_set_nzcv)
  );
  reservation_stations rs (.*);
  func_units fu (
      .*,
      .out_rob_set_nzcv(fu_out_rob_set_nzcv),
      .out_rob_nzcv(fu_out_rob_nzcv),
      .out_rob_done(fu_out_rob_done)
  );

endmodule