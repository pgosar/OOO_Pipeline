`include "data_structures.sv"

module cond_holds (
    input  cond_t cond,
    input  nzcv_t nzcv,
    output logic  cond_holds
);
  logic N, Z, C, V;
  assign N = nzcv.N;
  assign Z = nzcv.Z;
  assign C = nzcv.C;
  assign V = nzcv.V;

  always_comb begin
    casez (cond)
      C_EQ: cond_holds = Z;
      C_NE: cond_holds = ~Z;
      C_CS: cond_holds = C;
      C_CC: cond_holds = ~C;
      C_MI: cond_holds = N;
      C_PL: cond_holds = ~N;
      C_VS: cond_holds = V;
      C_VC: cond_holds = ~V;
      C_HI: cond_holds = C & Z;
      C_LS: cond_holds = ~(C & Z);
      C_GE: cond_holds = N == V;
      C_LT: cond_holds = !(N == V);
      C_GT: cond_holds = (N == V) & (Z == 0);
      C_LE: cond_holds = !((N == V) & (Z == 0));
      C_AL: cond_holds = 1;
      C_NV: cond_holds = 1;
    endcase
  end

endmodule

module OP_UBFM_module (
    input  logic [63:0] in_alu_val_a,
    input  logic [ 5:0] in_imms,
    input  logic [ 5:0] in_immr,
    output logic [63:0] out_value
);

  always_comb begin
    if (in_imms >= in_immr) begin
      out_value = (in_alu_val_a >> in_immr) & ((1 << (in_imms - in_immr + 1)) - 1);
    end else begin
      out_value = (in_alu_val_a & ((1 << (in_imms + 1)) - 1)) << in_immr;
    end
  end

endmodule

module OP_SBFM_module (
    input  logic signed [63:0] in_alu_val_a,
    input  logic signed [ 5:0] in_imms,
    input  logic signed [ 5:0] in_immr,
    output logic signed [63:0] out_value
);

  always_comb begin
    if (in_imms >= in_immr) begin
      out_value = (in_alu_val_a >> in_immr) & ((1 << (in_imms - in_immr + 1)) - 1);
    end else begin
      out_value = (in_alu_val_a & ((1 << (in_imms + 1)) - 1)) << in_immr;
    end
  end

endmodule
