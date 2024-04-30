`ifndef FUNC_UNITS
`define FUNC_UNITS

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
    output logic out_alu_condition // TODO this needs to be wired up
    // output logic out_rob_is_mispred
);

  fu_op_t fu_op;
  logic [`GPR_SIZE-1:0] val_a;
  logic [`GPR_SIZE-1:0] val_b;
  logic [`GPR_SIZE-1:0] out_value;
  // Buffered state (for clocking ALU)
  logic rs_alu_set_nzcv;
  nzcv_t rs_alu_nzcv;
  logic [`ROB_IDX_SIZE-1:0] rs_alu_dst_rob_index;
  logic [`ROB_IDX_SIZE-1:0] rs_ls_dst_rob_index;
  // ALU specific buffers
  logic alu_out_set_nzcv;

  // Decide on whether LS or ALU should run
  assign out_rob_value = out_value;
  assign out_rs_alu_ready = 1;
  assign out_rob_dst_rob_index = rs_alu_dst_rob_index;
  always_comb begin $display("FU trying to execute: %s", fu_op.name); end
  // always_comb begin
  //   out_rob_value = out_value;
  //   if (in_rs_ls_start) begin
  //     out_rs_alu_ready = 0;
  //     out_rs_ls_ready = 1;
  //     out_rob_dst_rob_index = rs_alu_dst_rob_index;
  //   end else begin
  //     out_rs_alu_ready = 1;
  //     out_rs_ls_ready = 0;
  //     out_rob_dst_rob_index = rs_ls_dst_rob_index;
  //   end
  // end

  // Buffer inputs
  always_ff @(posedge in_clk) begin
    out_rob_done <= in_rs_alu_start;
    if (in_rs_alu_start) begin
      // buffered state (so that it is clocked)
      fu_op <= in_rs_alu_fu_op;
      val_a <= in_rs_alu_val_a;
      val_b <= in_rs_alu_val_b;
      rs_alu_dst_rob_index <= in_rs_alu_dst_rob_index;
      rs_alu_set_nzcv <= in_rs_alu_set_nzcv;
      rs_alu_nzcv <= in_rs_alu_nzcv;
`ifdef DEBUG_PRINT
      #1
      $display(
          "(ALU) %s calculated: %0d for dst ROB[%0d] val_a: %0d, val_b: %0d, nzcv = %4b, condition = %0d",
          fu_op.name,
          $signed(
              out_value
          ),
          rs_alu_dst_rob_index,
          $signed(
              val_a
          ),
          $signed(
              val_b
          ),
          out_rob_nzcv,
          out_alu_condition
      );
`endif
    end else if (in_rs_ls_start) begin
      // buffered state (so that it is clocked)
      fu_op <= in_rs_ls_fu_op;
      val_a <= in_rs_alu_val_a;
      val_b <= in_rs_alu_val_b;
      rs_ls_dst_rob_index <= in_rs_ls_dst_rob_index;
`ifdef DEBUG_PRINT
      #2
      $display(
          "(LS) %s executed: %0d for dst ROB[%0d], val_a: %0d, val_b: %0d, nzcv = %4b",
          fu_op.name,
          $signed(
              out_value
          ),
          rs_ls_dst_rob_index,
          $signed(
              val_a
          ),
          $signed(
              val_b
          ),
          out_rob_nzcv
      );
`endif
    end
  end

  logic dmem_clk = in_clk & in_rs_ls_start;
  dmem dmem_module (
      .clk(dmem_clk),
      .in_addr(in_rs_alu_val_a),
      .w_enable(in_rs_ls_fu_op == FU_OP_STUR),
      .wval(in_rs_alu_val_b),
      .data(out_value)
  );

  alu_module alu (
      .in_cond(in_rob_alu_cond_codes),
      .in_op(fu_op),
      .in_alu_val_a(val_a),
      .in_alu_val_b(val_b),
      .in_set_nzcv(rs_alu_set_nzcv),
      .in_nzcv(rs_alu_nzcv),
      .out_alu_condition(out_alu_condition),
      .out_value(out_value),
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
    casez (in_op)
      FU_OP_PLUS: result = val_a + val_b;
      FU_OP_MINUS: result = val_a - val_b;
      FU_OP_ORN: result = val_a | (~val_b);
      FU_OP_OR: result = val_a | val_b;
      FU_OP_EOR: result = val_a ^ val_b;
      FU_OP_AND: result = val_a & val_b;
      FU_OP_CSNEG: result = out_alu_condition == 0 ? ~val_b + 1 : val_a;
      FU_OP_CSINC: result = out_alu_condition == 0 ? val_b + 1 : val_a;
      FU_OP_CSINV: result = out_alu_condition == 0 ? ~val_b : val_a;
      FU_OP_CSEL: result = out_alu_condition == 0 ? val_b : val_a;
      FU_OP_MOV: result = val_a | (val_b <<  /*in_alu_val_hw*/ 0);  // TODO pass through val_hw
      // FU_OP_PASS_A: result = val_a; // NOTE(Nate): No longer required
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


// Note: the imem is combinational to make accessing memory super easy.
//
module imem #(
    parameter int PAGESIZE = 4096
) (
    input  wire  [63:0] in_addr,
    output logic [31:0] data
);
  // read-only instruction memory module.
  localparam bits_amt = PAGESIZE;
  localparam fname = "mem/imem.txt";
  logic [7:0] mem[bits_amt];
  logic [$clog2(PAGESIZE) - 1:0] addr;

  initial begin : mem_init
    $readmemb(fname, mem);
  end : mem_init

  always_comb begin : mem_access
    addr = in_addr[$clog2(PAGESIZE)-1:0];
    data = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]};
  end : mem_access

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

  logic [$clog2(PAGESIZE*4)-1:0] addr;
  always_ff @(posedge clk) begin : mem_access
    addr <= in_addr[$clog2(PAGESIZE*4)-1:0];
    #1
    if (w_enable) begin
      mem[addr+7] <= wval[63:56];
      mem[addr+6] <= wval[55:48];
      mem[addr+5] <= wval[47:40];
      mem[addr+4] <= wval[39:32];
      mem[addr+3] <= wval[31:24];
      mem[addr+2] <= wval[23:16];
      mem[addr+1] <= wval[15:8];
      mem[addr] <= wval[7:0];
      data <= wval;
    end else begin
      data <= {
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
  end : mem_access

endmodule : dmem

`endif  // func_units
