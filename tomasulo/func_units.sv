`ifndef FUNC_UNITS
`define FUNC_UNITS

`include "data_structures.sv"

// TODO(Nate): If a load store happens out of order, how do you undo state
// Solution: Do not allow a stur to complete in the pipeline if the core is
// currently in a mispredicted branch state
// Real solution: We have a writeback buffer. Read values from the writeback
// before dmem. Commit stuff from the writeback buffer on commit.
// TODO(Nate): Have an extra bit 'write_on_commit' in the ROB

module func_units (
    // Timing
    input logic in_rst,
    input logic in_clk,
    // inputs from RS (ALU)
    input rs_interface in_rs_alu_sigs,
    input rs_interface_alu_ext in_rs_alu_sigs_ext,
    // Inputs from RS (LS)
    input rs_interface in_rs_ls_sigs,
    // Input direct from ROB
    input logic in_rob_commit_done,  // Used for in_w_enable

    // Outputs for RS (ALU)
    output logic out_rs_alu_ready,
    // Outputs for RS (LS)
    output logic out_rs_ls_ready,
    // Outputs for ROB (singular output)
    output fu_interface out_rob_sigs,
    output fu_interface_alu_ext out_rob_alu_sigs
);

  // Structural hazards are resolved in the reservation
  // stations.

  // LS output wires
  fu_interface ls_results ();
  // ALU output wires
  fu_interface alu_results ();
  fu_interface_alu_ext alu_results_ext ();

  // NOTE(Nate): Apologies for the hardcoded assignments
  assign out_rs_alu_ready = 1;
  assign out_rs_ls_ready  = 1;

  // Decide which output should be run. This is normally
  // trivial, since only one FU can run at a time.
  always_comb begin
    out_rob_sigs.done = alu_results.done | ls_results.done;
    if (alu_results.done) begin
      out_rob_sigs.dst_rob_index = alu_results.dst_rob_index;
      out_rob_sigs.value = alu_results.value;
    end else begin
      out_rob_sigs.dst_rob_index = ls_results.dst_rob_index;
      out_rob_sigs.value = ls_results.value;
    end
    // Extensions
    out_rob_alu_sigs.set_nzcv = alu_results_ext.set_nzcv;
    out_rob_alu_sigs.nzcv = alu_results_ext.nzcv;
    out_rob_alu_sigs.condition = alu_results_ext.condition;
  end

  rs_interface rs_alu_sigs ();
  rs_interface_alu_ext rs_alu_sigs_ext ();
  rs_interface rs_ls_sigs ();

  // Prints
  always_ff @(posedge in_clk) begin
    rs_alu_sigs <= in_rs_alu_sigs;
    rs_alu_sigs_ext <= in_rs_alu_sigs_ext;
    rs_ls_sigs <= rs_ls_sigs;
    `ASSERT((~(alu_results.done & ls_results.done)));
    if (in_rs_alu_sigs.start) begin
      // #1
      // `DEBUG(
      //     ( "(ALU) %s calculated: %0d for dst ROB[%0d] val_a: %0d, val_b: %0d, nzcv = %4b, condition = %0d", rs_alu_sigs.fu_op.name, $signed(
      //         alu_results
      //     ), rs_alu_sigs.rs_alu_dst_rob_index, $signed(
      //         rs_alu_sigs.val_a
      //     ), $signed(
      //         rs_alu_sigs.val_b), out_rob_alu_sigs.nzcv, out_rob_alu_sigs.condition));
    end
    if (in_rs_ls_sigs.start) begin
      // #1
      // `DEBUG(
      //     ( "(LS) %s executed: %0d for dst ROB[%0d], val_a: %0d, val_b: %0d", rs_ls_sigs.fu_op.name, $signed(
      //         ls_results
      //     ), rs_ls_sigs.dst_rob_index, $signed(
      //         rs_ls_sigs.val_a
      //     ), $signed(
      //         rs_ls_sigs.val_b)));
    end
  end

  // logic dmem_clk = in_clk & in_rs_ls_sigs.start;
  dmem dmem_module (
      .in_clk,
      .in_addr(in_rs_ls_sigs.val_a),
      .in_w_enable(in_rs_ls_sigs.fu_op == FU_OP_STUR),
      .in_wval(in_rs_ls_sigs.val_b),
      .out_data(ls_results.value)
  );

  alu_module alu (
      .in_clk,
      .in_alu_sigs(in_rs_alu_sigs),
      .in_alu_sigs_ext(in_rs_alu_sigs_ext),
      .out_alu_sigs(alu_results),
      .out_alu_sigs_ext(alu_results_ext)
  );

endmodule

module alu_module (
    input in_clk,
    input rs_interface in_alu_sigs,
    input rs_interface_alu_ext in_alu_sigs_ext,
    output fu_interface out_alu_sigs,
    output fu_interface_alu_ext out_alu_sigs_ext
);

  // ALU buffered inputs
  logic start;
  fu_op_t alu_fu_op;
  logic [`GPR_SIZE-1:0] alu_val_a;
  logic [`GPR_SIZE-1:0] alu_val_b;
  logic alu_set_nzcv;
  nzcv_t alu_nzcv;
  cond_t alu_cond_codes;
  // Useful rename
  logic condition;

  always_ff @(posedge in_clk) begin
    // Update input signals if started
    start <= in_alu_sigs.start;
    if (in_alu_sigs.start) begin
      alu_fu_op <= in_alu_sigs.fu_op;
      alu_val_a <= in_alu_sigs.val_a;
      alu_val_b <= in_alu_sigs.val_b;
      alu_set_nzcv <= in_alu_sigs_ext.set_nzcv;
      alu_nzcv <= in_alu_sigs_ext.nzcv;
      alu_cond_codes <= in_alu_sigs_ext.cond_codes;
    end
  end

  cond_holds c_holds (
      .cond(alu_cond_codes),
      .nzcv(alu_nzcv),
      .cond_holds(condition)
  );

  logic [`GPR_SIZE:0] val_a;
  logic [`GPR_SIZE:0] val_b;
  logic result_negative;
  logic val_a_negative;
  logic val_b_negative;
  logic [`GPR_SIZE:0] result;
  assign val_a = {1'b0, alu_val_a};
  assign val_b = {1'b0, alu_val_b};

  always_comb begin
    out_alu_sigs_ext.condition = condition;

    val_a_negative = val_a[`GPR_SIZE-1];
    val_b_negative = val_b[`GPR_SIZE-1];

    casez (alu_fu_op)
      FU_OP_ADRX, FU_OP_PLUS: result = val_a + val_b;
      FU_OP_MINUS: result = val_a - val_b;
      FU_OP_ORN: result = val_a | ~val_b;
      FU_OP_OR: result = val_a | val_b;
      FU_OP_EOR: result = val_a ^ val_b;
      FU_OP_AND: result = val_a & val_b;
      FU_OP_CSNEG: result = condition == 1 ? val_a : ~val_b + 1;
      FU_OP_CSINC: result = condition == 1 ? val_a : val_b + 1;
      FU_OP_CSINV: result = condition == 1 ? val_a : ~val_b;
      FU_OP_CSEL: result = condition == 1 ? val_a : val_b;
      FU_OP_MOV: result = val_a | val_b;
      FU_OP_PASS_A: result = val_a;
      default: result = 0;
    endcase
    out_alu_sigs.value = result[`GPR_SIZE-1:0];

    result_negative = result[`GPR_SIZE-1];
    out_alu_sigs_ext.nzcv.N = result_negative;
    out_alu_sigs_ext.nzcv.Z = result[`GPR_SIZE-1:0] == 0;
    out_alu_sigs_ext.nzcv.C = result[`GPR_SIZE] & val_a > val_b;
    out_alu_sigs_ext.nzcv.V = (val_a_negative ^ val_b_negative) ? 0 : (result_negative ^ val_a_negative);

    out_alu_sigs.done = start;
  end
endmodule

// set in_w_enable and w_val if writing, else just set in_addr. should be
// really easy to integrate since addr is 64 bit
module dmem #(
    parameter int PAGESIZE = 4096
)  // AKA load-store
(
    input wire [63:0] in_addr,
    input wire in_clk,
    input wire in_w_enable,
    input wire [63:0] in_wval,
    output logic [63:0] out_data
);
  // read-only instruction memory module.
  localparam bits_amt = PAGESIZE * 4;  // 64 bit access
  localparam fname = "mem/dmem.txt";
  logic [7:0] mem[bits_amt];

  initial begin : mem_init
    $readmemb(fname, mem);
  end : mem_init

  logic [$clog2(PAGESIZE*4)-1:0] addr;
  always_ff @(posedge in_clk) begin : mem_access
    addr <= in_addr[$clog2(PAGESIZE*4)-1:0];
    if (in_w_enable) begin
      #1 mem[addr+7] <= in_wval[63:56];
      mem[addr+6] <= in_wval[55:48];
      mem[addr+5] <= in_wval[47:40];
      mem[addr+4] <= in_wval[39:32];
      mem[addr+3] <= in_wval[31:24];
      mem[addr+2] <= in_wval[23:16];
      mem[addr+1] <= in_wval[15:8];
      mem[addr]   <= in_wval[7:0];
    end
  end : mem_access

  always_comb begin
    out_data = {
      mem[addr+7],
      mem[addr+6],
      mem[addr+5],
      mem[addr+4],
      mem[addr+3],
      mem[addr+2],
      mem[addr+1],
      mem[addr]
    };
  end

endmodule : dmem

`endif  // func_units

