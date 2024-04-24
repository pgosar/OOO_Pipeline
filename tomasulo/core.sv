`include "data_structures.sv"

module core (
    input logic in_reset,
    input logic in_start
    //input logic in_clk
);
  initial begin
`ifdef DEBUG_PRINT
    $dumpfile("core.vcd");  // Dump waveform to VCD file
    $dumpvars(0, core);  // Dump all signals
`endif
  end
  // ROB
  logic in_clk;
  logic in_rst;
  // Inputs from FU
  logic in_fu_done;
  logic [`ROB_IDX_SIZE-1:0] in_fu_dst_rob_index;
  logic [`GPR_SIZE-1:0] in_fu_value;
  logic in_fu_set_nzcv;
  nzcv_t in_fu_nzcv;
  logic in_fu_is_mispred;
  // Inputs from regfile (as part of decode)
  logic in_regfile_ready;
  logic [`GPR_IDX_SIZE-1:0] in_regfile_dst;
  logic [`GPR_SIZE-1:0] in_regfile_src1_value;
  logic [`GPR_SIZE-1:0] in_regfile_src2_value;
  logic [`GPR_IDX_SIZE-1:0] in_regfile_src1;
  logic [`GPR_IDX_SIZE-1:0] in_regfile_src2;
  logic in_regfile_src1_valid;
  logic in_regfile_src2_valid;
  logic in_regfile_set_nzcv;
  logic in_is_nop;
  logic [`ROB_IDX_SIZE-1:0] in_last_nzcv_rob_idx;
  // Outputs for RS
  logic out_rs_val_a_valid;
  logic out_rs_val_b_valid;
  logic [`GPR_SIZE-1:0] out_rs_val_a_value;
  logic [`GPR_SIZE-1:0] out_rs_val_b_value;
  logic [`ROB_IDX_SIZE-1:0] out_rs_val_a_rob_index;
  logic [`ROB_IDX_SIZE-1:0] out_rs_val_b_rob_index;

  logic [`ROB_IDX_SIZE-1:0] out_rs_dst_rob_idx;
  logic [`ROB_IDX_SIZE-1:0] out_rs_broadcast_index;
  logic [`GPR_SIZE-1:0] out_rs_broadcast_value;
  logic out_rs_should_broadcast;
  // Outputs for regfile
  logic out_regfile_should_commit;
  logic [`GPR_IDX_SIZE-1:0] out_regfile_gpr_index;
  logic [`GPR_SIZE-1:0] out_regfile_value;
  logic out_regfile_set_nzcv;
  logic [`NZCV_SIZE-1:0] out_regfile_nzcv;

  // Regfile
  // from ROB
  logic in_rob_should_commit;
  logic [`GPR_SIZE-1:0] in_rob_commit_value;
  logic [`GPR_IDX_SIZE-1:0] in_rob_regfile_index;
  // logic in_is_mispred;
  // logic [ROB_IDX_SIZE-1:0] out_delete_mispred_idx [2:0];
  // from dispatch
  logic in_dispatch_should_read = 1;  // TODO: just set to true for now
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
  // from ROB
  logic in_rob_set_nzcv;
  nzcv_t in_rob_nzcv;
  logic in_rob_val_a_valid;
  logic in_rob_val_b_valid;
  logic [`GPR_SIZE-1:0] in_rob_val_a_value;
  logic [`GPR_SIZE-1:0] in_rob_val_b_value;
  logic [`ROB_IDX_SIZE-1:0] in_rob_val_a_rob_index;
  logic [`ROB_IDX_SIZE-1:0] in_rob_val_b_rob_index;
  logic [`GPR_IDX_SIZE-1:0] in_rob_dst_rob_idx;
  logic in_rob_should_broadcast;
  logic [`ROB_IDX_SIZE-1:0] in_rob_broadcast_index;
  logic [`GPR_SIZE-1:0] in_rob_broadcast_value;
  logic in_rob_is_mispred;

  // from FU
  logic in_fu_ready;
  // logic in_fu_done;
  // Reservation station outputs
  // to FU
  logic [`GPR_SIZE-1:0] out_fu_val_a;
  logic [`GPR_SIZE-1:0] out_fu_val_b;
  logic [`ROB_IDX_SIZE-1:0] out_fu_dst;
  logic [`NZCV_SIZE-1:0] out_fu_nzcv;
  logic out_fu_set_nzcv;


  // dispatch
  // from core
  logic in_stall;
  // from fetch
  logic [31:0] in_insnbits;

  logic in_fetch_done;
  // for regfile
  logic [`GPR_IDX_SIZE-1:0] out_src1;
  logic [`GPR_IDX_SIZE-1:0] out_src2;
  func_unit_t out_fu;
  logic [`GPR_IDX_SIZE-1:0] out_dst;
  logic out_stalled;

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
    for (int i = 0; i < 10; i += 1) #5 in_clk = ~in_clk;  // 100 MHz clock
  end

  initial begin
    in_rst = 1;
    #10 in_rst = 0;
    in_insnbits = 32'b1001000100_111111111111_00001_00001;  // add x1, x1, #0xfff
    #10 in_insnbits = 'b1101_0101_0000_0011_0010_0000_0001_1111;  // NOP

  end

  // pipe state over
  // TODO: We could probably just really simplify our signals?
  always_comb begin
    // regfile takes inputs from decode
    in_d_op1 = out_src1;
    in_d_op2 = out_src2;
`ifdef DEBUG_PRINT
    $display("core: out_src1 = r%d, out_src2 = r%d", out_src1, out_src2);
`endif
    in_fu_done = out_fu_done;
    in_fu_value = out_res;
    in_fu_nzcv = out_nzcv;
    in_rob_should_commit = out_regfile_should_commit;
  end

  // modules
  dispatch dp (.*);
  ArithmeticExecuteUnit alu (.*);
  regfile_module regfile (.*);
  rob_module rob (.*);
  reservation_station_module reservation_stations (.*);

endmodule
