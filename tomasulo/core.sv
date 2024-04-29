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
  logic in_fu_is_mispred;
  // Inputs from regfile (as part of decode)
  logic in_reg_done;  // NOTE(Nate): Is this stall?
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
  fu_t out_rs_fu_id;  // NOTE(Nate): Shouldn't this just go to the RS for this functional unit?
  fu_op_t out_rs_fu_op;
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
  cond_t out_rs_cond_codes;
  logic out_rs_instr_uses_nzcv;
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
  // Outputs for regfile (invalid GPR)
  logic [`ROB_IDX_SIZE-1:0] out_reg_next_rob_index;

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
  nzcv_t rs_in_rob_nzcv;
  logic rs_in_rob_set_nzcv;
  logic [`ROB_IDX_SIZE-1:0] in_rob_val_a_rob_index;
  logic [`ROB_IDX_SIZE-1:0] in_rob_val_b_rob_index;
  logic [`GPR_IDX_SIZE-1:0] in_rob_dst_rob_index;
  logic [`GPR_IDX_SIZE-1:0] in_rob_nzcv_rob_index;
  logic in_rob_broadcast_done;
  logic [`ROB_IDX_SIZE-1:0] in_rob_broadcast_index;
  logic [`GPR_SIZE-1:0] in_rob_broadcast_value;
  logic in_rob_broadcast_set_nzcv;
  nzcv_t in_rob_broadcast_nzcv;
  logic in_rob_is_mispred;
  logic in_fu_ls_ready;
  logic in_fu_alu_ready;  // ready to receive inputs
  cond_t rs_in_rob_cond_codes;
  logic in_rob_instr_uses_nzcv;
  // Outputs for FU
  logic out_fu_alu_start;
  logic out_fu_ls_start;
  fu_op_t out_fu_fu_op;
  logic [`GPR_SIZE-1:0] out_fu_val_a;
  logic [`GPR_SIZE-1:0] out_fu_val_b;
  logic [`ROB_IDX_SIZE-1:0] out_fu_dst_rob_index;
  logic out_fu_alu_set_nzcv;
  nzcv_t out_fu_alu_nzcv;
  cond_t out_fu_cond_codes;
  fu_op_t out_rob_fu_op;
  logic out_fu_alu_ready;
  logic out_fu_ls_ready;
  logic out_fu_instr_uses_nzcv;

  // FUNC UNITS
  logic in_rs_alu_start;
  logic in_rs_ls_start;
  fu_op_t in_rs_fu_op;
  logic [`GPR_SIZE-1:0] in_rs_val_a;
  logic [`GPR_SIZE-1:0] in_rs_val_b;
  logic [`ROB_IDX_SIZE-1:0] in_rs_dst_rob_index;
  logic in_rs_alu_set_nzcv;
  nzcv_t in_rs_alu_nzcv;
  cond_t in_rob_cond_codes;
  logic in_rs_instr_uses_nzcv;


  // Outputs for RS
  logic out_rs_ls_ready;
  logic out_rs_alu_ready;
  // Outputs for ROB
  logic fu_out_rob_done;  // Used for both ROB and FU
  logic [`ROB_IDX_SIZE-1:0] out_rob_dst_rob_index;
  logic [`GPR_SIZE-1:0] out_rob_value;
  logic fu_out_rob_set_nzcv;
  nzcv_t fu_out_rob_nzcv;
  logic out_rob_is_mispred;
  logic out_alu_condition;

  // for now just run a single cycle
  int i;
  initial begin
    in_clk = 0;
    for (i = 1; i <= 25; i += 1) begin
      $display("\n>>>>> CYCLE COUNT: %0d <<<<<", i);
      #1 in_clk = ~in_clk;  // 100 MHz clock
      #5 in_clk = ~in_clk;
      #4;
    end
  end

  initial begin
    in_rst = 1;
    in_fetch_done = 0;
    #10 in_rst = 0;
    $display("RESET DONE === BEGIN TEST");
    in_fetch_done = 1;
    in_fetch_insnbits = 32'b1001000100_111111111111_00001_00001;  // add x1, x1, #0xfff -> x1 = 4095
    #10
    in_fetch_insnbits = 32'b10101011000_00001_000000_00001_00010;  // adds x2, x1, x1 -> x2 = 8190
    #10
    in_fetch_insnbits = 32'b10101011000_00001_000000_00001_00010;  // adds x2, x1, x1 -> x2 = 8190
    #10
    in_fetch_insnbits = 32'b11101011000_00001_000000_00001_00011;  // subs x3, x1, x1 set zero flag -> x3 = 0
    #10
    in_fetch_insnbits = 32'b11101011000_00001_000000_00011_00011;  // subs x3, x3, x1 set neg flag -> x3 = -4095
    #10
    in_fetch_insnbits = 32'b11101011000_00001_000000_00011_00011;  // subs x3, x3, x1 set neg flag -> x3 = -8190
    #10
    in_fetch_insnbits = 32'b11011010100_00001_0000_00_00011_00111; // csinv x7, x3, x1, eq -> ffffffffffff0000
    #10
    // #10 in_fetch_insnbits = 32'b1101_0101_0000_0011_0010_0000_0001_1111;  // NOP
    in_fetch_done = 0;

    // #10;
    // while (in_fetch_insnbits != 0) begin
    //   $display("itr");
    //   $display("*******insnbits: %x", in_fetch_insnbits);
    //   #10;
    // end
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

  // ROB TO REGFILE (on COMMIT) regfile inputs = rob outputs
  assign in_rob_should_commit = out_reg_commit_done;
  assign reg_in_rob_set_nzcv = rob_out_reg_set_nzcv;
  assign reg_in_rob_nzcv = out_reg_nzcv;
  assign in_rob_commit_value = out_reg_commit_value;
  assign in_rob_reg_index = out_reg_index;
  assign in_rob_commit_rob_index = out_reg_commit_rob_index;
  assign in_rob_next_rob_index = out_reg_next_rob_index;
  assign in_rob_cond_codes = out_reg_cond_codes;

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
  assign in_rob_done = out_rs_done;
  assign in_rob_fu_id = out_rs_fu_id;
  assign in_rob_fu_op = out_rs_fu_op;
  assign in_rob_val_a_valid = out_rs_val_a_valid;
  assign in_rob_val_b_valid = out_rs_val_b_valid;
  assign in_rob_nzcv_valid = out_rs_nzcv_valid;
  assign in_rob_val_a_value = out_rs_val_a_value;
  assign in_rob_val_b_value = out_rs_val_b_value;
  assign rs_in_rob_nzcv = out_rs_nzcv;
  assign rs_in_rob_set_nzcv = out_rs_set_nzcv;
  assign in_rob_val_a_rob_index = out_rs_val_a_rob_index;
  assign in_rob_val_b_rob_index = out_rs_val_b_rob_index;
  assign in_rob_dst_rob_index = out_rs_dst_rob_idx;
  assign in_rob_nzcv_rob_index = out_rs_nzcv_rob_idx;
  assign in_rob_broadcast_done = out_rs_broadcast_done;
  assign in_rob_broadcast_index = out_rs_broadcast_index;
  assign in_rob_broadcast_value = out_rs_broadcast_value;
  assign rs_in_rob_cond_codes = out_rs_cond_codes;
  assign in_rob_instr_uses_nzcv = out_rs_instr_uses_nzcv;

  // FU TO ROB rob inputs = fu outputs
  assign in_fu_done = fu_out_rob_done;
  assign in_fu_dst_rob_index = out_rob_dst_rob_index;
  assign in_fu_value = out_rob_value;
  assign in_fu_set_nzcv = out_rob_set_nzcv;
  assign in_fu_nzcv = out_rob_nzcv;
  assign in_fu_is_mispred = out_rob_is_mispred;

  // FU TO RS rs inputs = fu outputs
  assign in_fu_ls_ready = out_rs_ls_ready;
  assign in_fu_alu_ready = out_rs_alu_ready;

  // RS TO FU fu inputs = rs outputs
  assign in_rs_alu_start = out_fu_alu_start;
  assign in_rs_ls_start = out_fu_ls_start;
  assign in_rs_fu_op = out_fu_fu_op;
  assign in_rs_val_a = out_fu_val_a;
  assign in_rs_val_b = out_fu_val_b;
  assign in_rs_dst_rob_index = out_fu_dst_rob_index;
  assign in_rs_alu_set_nzcv = out_fu_alu_set_nzcv;
  assign in_rs_alu_nzcv = out_fu_alu_nzcv;

  // assign out_fu_alu_ready = out_fu_alu_start;
  // assign out_fu_ls_ready = out_fu_ls_start;

  assign out_fu_alu_ready = in_fu_alu_ready;
  assign out_fu_ls_ready = in_fu_ls_ready;

  // RS to FU
  assign out_fu_cond_codes = in_rob_cond_codes;
  assign out_fu_instr_uses_nzcv = in_rs_instr_uses_nzcv;

  // modules
  // fetch f (.*);

  dispatch dp (
      .*,
      .out_reg_set_nzcv(dispatch_out_reg_set_nzcv)
  );
  reg_module regfile (
      .*,
      .in_rob_nzcv(reg_in_rob_nzcv),
      .in_rob_set_nzcv(reg_in_rob_set_nzcv),
      .out_rob_done(reg_out_rob_done)
  );
  rob_module rob (
      .*,
      .out_reg_set_nzcv(rob_out_reg_set_nzcv)
  );
  reservation_stations rs (
      .*,
      .in_rob_cond_codes(rs_in_rob_cond_codes),
      .in_rob_nzcv(rs_in_rob_nzcv),
      .in_rob_set_nzcv(rs_in_rob_set_nzcv)
  );
  func_units fu (
      .*,
      .out_rob_set_nzcv(fu_out_rob_set_nzcv),
      .out_rob_nzcv(fu_out_rob_nzcv),
      .out_rob_done(fu_out_rob_done)
  );

endmodule


// module testbehhcn(

// );

// endmodule
