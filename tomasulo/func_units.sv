module func_units (
    // inputs from RS
    input logic in_rs_alu_start,
    input alu_op_t in_rs_alu_op,
    input logic [`GPR_SIZE-1:0] in_rs_alu_val_a,
    input logic [`GPR_SIZE-1:0] in_rs_alu_val_b,
    input logic [`ROB_IDX_SIZE-1:0] in_rs_alu_dst_rob_index,
    input logic in_rs_alu_set_nzcv,
    input nzcv_t in_rs_alu_nzcv,
    // Outputs for RS
    output logic out_rs_alu_ready,
    // Outputs for ROB (singular output)
    output logic out_rob_done,
    output logic [`ROB_IDX_SIZE-1:0] out_rob_dst_rob_index,
    output logic [`GPR_SIZE-1:0] out_rob_value,
    output logic out_rob_set_nzcv,
    output nzcv_t out_rob_nzcv,
    output logic out_rob_is_mispred,
);

  // Logic to handle structural hazards when L/S and ALU are both done

  logic ls_done; // Placeholder
  assign ls_done = 0;
  logic stall_ls;

  always_comb begin
    if (ls_done & alu_done) begin
      stall_ls = 1;

    end else begin
      stall_ls = 0;
    end
  end

  alu_module alu (
      .in_start(in_rs_alu_start),
      .in_op(in_rs_alu_op),
      .in_val_a(in_rs_alu_val_a),
      .in_val_b(in_rs_alu_val_b),
      .in_dst_rob_index(in_rs_alu_dst_rob_index),
      .in_nzcv(in_rs_alu_nzcv),
      .in_set_nzcv(in_rs_alu_set_nzcv),
      .in_nzcv(in_rs_alu_nzcv),
      .in_out_done(in_rs_alu_nzcv),  // Done signal indicating operation completion
      .out_condition(out_alu_condition),
      .out_value(out_alu_value),
      .out_nzcv(out_alu_nzcv),
      .out_set_nzcv(out_alu_set_nzcv),
      .out_dst_rob_index(out_alu_dst_rob_index),
  );

  // TODO LDUR STUR
endmodule


// TODO output to RS if ready or not
module alu_module (
    input logic in_start,
    input alu_op_t in_op,
    input logic [`GPR_SIZE-1:0] in_val_a,
    input logic [`GPR_SIZE-1:0] in_val_b,
    input logic [`ROB_IDX_SIZE-1:0] in_dst_rob_index,
    input nzcv_t in_nzcv,
    input logic in_set_nzcv,
    // input logic in_uses_nzcv,  // TODO(Nate): use me here, and in the rest of the pipeline
    input nzcv_t in_nzcv,
    output logic out_done,  // Done signal indicating operation completion
    output logic out_condition,
    output logic [`GPR_SIZE-1:0] out_value,
    output nzcv_t out_nzcv,
    output logic out_set_nzcv,
    output logic [`ROB_IDX_SIZE-1:0] out_dst_rob_index
);

  logic [`GPR_SIZE-1:0] result_reg;
  nzcv_t nzcv;

  cond_holds c_holds (
      .cond(in_cond),
      .nzcv(in_prev_nzcv),
      .cond_holds(out_cond_val)
  );

  always_comb begin : main_switch
    casez (in_op)
      ALU_OP_PLUS: result_reg = in_val_a + in_val_b;
      ALU_OP_MINUS: result_reg = in_val_a - in_val_b;
      ALU_OP_ORN: result_reg = in_val_a | (~in_val_b);
      ALU_OP_OR: result_reg = in_val_a | in_val_b;
      ALU_OP_EOR: result_reg = in_val_a ^ in_val_b;
      ALU_OP_AND: result_reg = in_val_a & in_val_b;
      // ALU_OP_MOV: result_reg = in_val_a | (in_val_b << in_alu_val_hw);
      ALU_OP_CSNEG: result_reg = in_val_b + 1;  // NOTE(Nate): Is this correct?
      ALU_OP_CSINC: result_reg = in_val_b + 1;
      ALU_OP_CSINV: result_reg = in_val_b;
      ALU_OP_CSEL: result_reg = in_val_b;
      // ALU_OP_PASS_A: result_reg = in_val_a; // NOTE(Nate): No longer required
      default: result_reg = 0;
    endcase
    if (in_set_nzcv) begin
      nzcv.N = result_reg[`GPR_SIZE-1];
      nzcv.Z = result_reg == 0;
      casez (in_op)  /* Setting carry flag */
        ALU_OP_PLUS: nzcv.C = (result_reg < in_val_a) | (result_reg < in_val_b);
        ALU_OP_MINUS: nzcv.C = in_val_a >= in_val_b;
        default: out_alu_nzcv.C = 0;
      endcase
      casez (in_op)  /* Setting overflow flag */
        ALU_OP_PLUS:
        nzcv.V = (~in_val_a[`GPR_SIZE-1] & ~in_val_b[`GPR_SIZE-1] & nzcv.N) |
                  (in_val_a[`GPR_SIZE-1] & in_val_b[`GPR_SIZE-1] & ~nzcv.N);
        ALU_OP_MINUS:
        nzcv.V = (~in_val_a[`GPR_SIZE-1] & in_val_b[`GPR_SIZE-1] & nzcv.N) |
                  (in_val_a[`GPR_SIZE-1] & ~in_val_b[`GPR_SIZE-1] & ~nzcv.N);
        default: nzcv.V = 0;
      endcase
    end
    out_alu_nzcv = nzcv;
    if(in_op == ALU_OP_CSEL || in_op == ALU_OP_CSNEG || in_op == ALU_OP_CSINC ||
                                       in_op == ALU_OP_CSINV) begin
      if (out_cond_val == 0) begin
        out_value = result_reg;
      end else begin
        out_value = in_val_a;
      end
    end else begin
      out_value = result_reg;
    end
`ifdef DEBUG_PRINT
    $display("ALU: out_value = %d, out_alu_nzcv = %d, out_cond_val = %d", out_value, out_alu_nzcv,
             out_cond_val);
`endif
    out_alu_done = 1;
  end
endmodule
