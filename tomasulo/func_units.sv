`ifndef FUNC_UNITS
`define FUNC_UNITS

`include "data_structures.sv"

// TODO(Nate): If a load store happens out of order, how do you undo state
// Solution: Do not allow a stur to complete in the pipeline if the core is
// currently in a mispredicted branch state
// Real solution: We have a writeback buffer. Read values from the writeback
// before dmem. Commit stuff from the writeback buffer on commit.

module func_units (
    // Timing
    input logic in_clk,
    // inputs from RS (ALU)
    input logic in_rs_alu_start,
    input fu_op_t in_rs_alu_fu_op,
    input logic [`GPR_SIZE-1:0] in_rs_alu_val_a,
    input logic [`GPR_SIZE-1:0] in_rs_alu_val_b,
    input logic [`ROB_IDX_SIZE-1:0] in_rs_alu_dst_rob_index,
    input logic in_rs_alu_set_nzcv,
    input nzcv_t in_rs_alu_nzcv,
    input cond_t in_rob_alu_cond_codes,
    // Inputs from RS (LS)
    input logic in_rs_commit_done,
    input logic in_rs_ls_start,
    input fu_op_t in_rs_ls_fu_op,
    input logic [`GPR_SIZE-1:0] in_rs_ls_val_a,
    input logic [`GPR_SIZE-1:0] in_rs_ls_val_b,
    input logic [`ROB_IDX_SIZE-1:0] in_rs_ls_dst_rob_index,

    // Outputs for RS (ALU)
    output logic out_rs_alu_ready,
    // Outputs for RS (LS)
    output logic out_rs_ls_ready,
    // Outputs for ROB (singular output)
    output logic out_rob_done,
    output logic [`ROB_IDX_SIZE-1:0] out_rob_dst_rob_index,
    output logic [`GPR_SIZE-1:0] out_rob_value,
    output logic out_rob_set_nzcv,
    output nzcv_t out_rob_nzcv,
    output logic out_alu_condition  // TODO this needs to be wired up
    // output logic out_rob_is_mispred
);

  fu_op_t fu_op;
  logic [`GPR_SIZE-1:0] val_a;
  logic [`GPR_SIZE-1:0] val_b;
  logic [`GPR_SIZE-1:0] alu_value;
  logic [`GPR_SIZE-1:0] ls_value;
  cond_t cond_codes;
  // Buffered state (for clocking ALU)
  logic rs_alu_set_nzcv;
  nzcv_t rs_alu_nzcv;
  logic [`ROB_IDX_SIZE-1:0] rs_alu_dst_rob_index;
  logic [`ROB_IDX_SIZE-1:0] rs_ls_dst_rob_index;
  // ALU specific buffers
  logic alu_out_set_nzcv;
  logic alu_start;

  always_comb begin : select_output
    out_rob_value = alu_start ? alu_value : ls_value;

  end : select_output

  // Buffer inputs
  always_ff @(posedge in_clk) begin
    // $display("wtf alu op: %s", in_rs_alu_fu_op.name);
    // $display("wtf ls op: %s", in_rs_ls_fu_op.name);
    out_rob_done <= in_rs_alu_start | in_rs_ls_start;
    out_rob_dst_rob_index <= in_rs_alu_start ? in_rs_alu_dst_rob_index : in_rs_ls_dst_rob_index;
    out_rs_alu_ready <= !in_rs_alu_start;
    out_rs_ls_ready <= !in_rs_ls_start;
    alu_start <= in_rs_alu_start;
    `DEBUG(("ALU start: %0d, LS start: %0d", in_rs_alu_start, in_rs_ls_start));
    if (in_rs_alu_start) begin
      // buffered state (so that it is clocked)
      val_a <= in_rs_alu_val_a;
      val_b <= in_rs_alu_val_b;
      rs_alu_dst_rob_index <= in_rs_alu_dst_rob_index;
      rs_alu_set_nzcv <= in_rs_alu_set_nzcv;
      rs_alu_nzcv <= in_rs_alu_nzcv;
      fu_op <= in_rs_alu_fu_op;
      cond_codes <= in_rob_alu_cond_codes;
      #1
      `DEBUG(
          ( "(ALU) %s calculated: %0d for dst ROB[%0d] val_a: %0d, val_b: %0d, nzcv = %4b, condition = %0d",
      fu_op.name, $signed(
              alu_value
          ), rs_alu_dst_rob_index, $signed(
              val_a
          ), $signed(
              val_b), out_rob_nzcv, out_alu_condition));
    end else if (in_rs_ls_start) begin
      // buffered state (so that it is clocked)
      val_a <= in_rs_ls_val_a;
      val_b <= in_rs_ls_val_b;
      rs_ls_dst_rob_index <= in_rs_ls_dst_rob_index;
      fu_op <= in_rs_ls_fu_op;
      #1
      `DEBUG(
          ( "(LS) %s executed: %0d for dst ROB[%0d], val_a: %0d, val_b: %0d, nzcv = %4b", fu_op.name, $signed(
              ls_value
          ), rs_ls_dst_rob_index, $signed(
              val_a
          ), $signed(
              val_b), out_rob_nzcv));
    end
  end

  // TODO(Nate): This is getting executed a cycle later than it should.
  // Furthermore, there should be two cycles which can run dmem. (1),
  // from the rob on commit. (2) from ldurs if there are no sturs. (3)
  // We need some sort of writeback buffer to read new values from while
  // waiting for sturs to complete. This can be the ROB.

  // logic dmem_clk = in_clk & in_rs_ls_start;
  dmem dmem_module (
      .clk(in_clk),
      .in_addr(val_a),
      .w_enable(fu_op == FU_OP_STUR  /* & in_rs_commit_done*/),
      .wval(val_b),
      .data(ls_value)
  );

  alu_module alu (
      .in_cond(cond_codes),
      .in_op(fu_op),
      .in_alu_val_a(val_a),
      .in_alu_val_b(val_b),
      .in_set_nzcv(rs_alu_set_nzcv),
      .in_nzcv(rs_alu_nzcv),
      .out_alu_condition(out_alu_condition),
      .out_value(alu_value),
      .out_nzcv(out_rob_nzcv),
      .out_set_nzcv(alu_out_set_nzcv)
  );

endmodule


// TODO output to RS if ready or not
module alu_module (
    input cond_t in_cond,
    input fu_op_t in_op,
    input logic [`GPR_SIZE-1:0] in_alu_val_a,
    input logic [`GPR_SIZE-1:0] in_alu_val_b,
    input nzcv_t in_nzcv,
    input logic in_set_nzcv,
    // TODO(Nate): We need to include input condition codes
    output logic out_alu_condition,
    output logic [`GPR_SIZE-1:0] out_value,
    output nzcv_t out_nzcv,
    output logic out_set_nzcv
);

  logic [`GPR_SIZE:0] result;  // add 1 bit for easy carry calculations
  logic val_a_negative;
  logic val_b_negative;
  logic set_nzcv;
  nzcv_t nzcv;  // TODO why?
  logic delayed_clk;
  logic [`GPR_SIZE:0] val_a;
  logic [`GPR_SIZE:0] val_b;

  assign out_value = result[`GPR_SIZE-1:0];
  assign val_a = {1'b0, in_alu_val_a};
  assign val_b = {1'b0, in_alu_val_b};

  // Useful wires
  assign val_a_negative = val_a[`GPR_SIZE-1];
  assign val_b_negative = val_b[`GPR_SIZE-1];

  // TODO(Nate): Conditions are wacky in general rn
  cond_holds c_holds (
      .cond(in_cond),
      .nzcv(in_nzcv),
      .cond_holds(out_alu_condition)
  );


  logic result_negative;
  always_comb begin
    // $display("ALU_OP: %s", in_op.name);
    casez (in_op)
      FU_OP_ADRX, FU_OP_PLUS: result = val_a + val_b;
      FU_OP_MINUS: result = val_a - val_b;
      FU_OP_ORN: result = val_a | (~val_b);
      FU_OP_OR: result = val_a | val_b;
      FU_OP_EOR: result = val_a ^ val_b;
      FU_OP_AND: result = val_a & val_b;
      FU_OP_CSNEG: result = out_alu_condition == 0 ? ~val_b + 1 : val_a;
      FU_OP_CSINC: result = out_alu_condition == 0 ? val_b + 1 : val_a;
      FU_OP_CSINV: result = out_alu_condition == 0 ? ~val_b : val_a;
      FU_OP_CSEL: result = out_alu_condition == 0 ? val_b : val_a;
      FU_OP_MOV: result = val_a | val_b;
      FU_OP_PASS_A: result = val_a;
      default: result = 0;
    endcase

    result_negative = result[`GPR_SIZE-1];
    if (in_set_nzcv) begin
      out_nzcv.N = result_negative;
      out_nzcv.Z = result[`GPR_SIZE-1:0] == 0;
      out_nzcv.C = result[`GPR_SIZE] & val_a > val_b;
      out_nzcv.V = (val_a_negative ^ val_b_negative) ? 0 : (result_negative ^ val_a_negative);
    end else begin
      out_nzcv = in_nzcv;
    end
  end
endmodule

// set w_enable and w_val if writing, else just set in_addr. should be
// really easy to integrate since addr is 64 bit
module dmem #(
    parameter int PAGESIZE = 4096
)  // AKA load-store
(
    input wire [63:0] in_addr,
    input wire clk,
    input wire w_enable,
    input wire [63:0] wval,
    output logic [63:0] data
);

  // read-only instruction memory module.
  localparam bits_amt = PAGESIZE * 4;  // 64 bit access
  localparam fname = "mem/dmem.txt";
  logic [7:0] mem[bits_amt];

  initial begin : mem_init
    $readmemb(fname, mem);
  end : mem_init

  logic [63:0] buffer;
  logic [$clog2(PAGESIZE*4)-1:0] addr;
  always_ff @(posedge clk) begin : mem_access
    buffer <= wval;
    addr   <= in_addr[$clog2(PAGESIZE*4)-1:0];
    if (w_enable) begin
      #1 `DEBUG(("(LS) Here is the wval: %0d", buffer));
      mem[addr+7] <= buffer[63:56];
      mem[addr+6] <= buffer[55:48];
      mem[addr+5] <= buffer[47:40];
      mem[addr+4] <= buffer[39:32];
      mem[addr+3] <= buffer[31:24];
      mem[addr+2] <= buffer[23:16];
      mem[addr+1] <= buffer[15:8];
      mem[addr]   <= buffer[7:0];
    end
  end : mem_access

  always_comb begin
    data = {
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
