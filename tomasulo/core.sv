`include "data_structures.sv"

module core(

);
endmodule

module instruction_parser(
    input logic [10:0] opcode_bits,
    output opcode_t opcode
);
    always_comb begin
        casez(opcode_bits)
            11'b11111000010: opcode = OP_LDUR;
            11'b1010100011x: opcode = OP_LDP;
            11'b11111000000: opcode = OP_STUR;
            11'b1010100100x: opcode = OP_STP;
            11'b111100101xx: opcode = OP_MOVK;
            11'b0xx10000xxx: opcode = OP_ADR;
            11'b1xx10000xxx: opcode = OP_ADRP;
            11'b10011010100: opcode = OP_CINC; //cset and OP_CSEL and OP_CSINC
            11'b11011010100: opcode = OP_CINV; //also for OP_CSNEG, OP_CSNEG and csetm and OP_CSINV
            11'b1001000100x: opcode = OP_ADD;
            11'b10101011000: opcode = OP_ADDS;
            11'b1101000100x: opcode = OP_SUB;
            11'b11101011000: opcode = OP_SUBS; //OP_CMP
            11'b10101010001: opcode = OP_MVN;
            11'b10101010000: opcode = OP_ORR;
            11'b11001010000: opcode = OP_EOR;
            11'b1001001000x: opcode = OP_AND; //cant have and its a built in module
            11'b11101010000: opcode = OP_ANDS; //also for OP_TST
            11'b110100110xx: opcode = OP_UBFM; //OP_LSL and OP_LSR has an extra 1 in its opcode  what do we do about that
            11'b100100111xx: opcode = OP_SBFM;
            11'b1001001101x: opcode = OP_ASR;
            11'b000101xxxxx: opcode = OP_B;
            11'b11010110000: opcode = OP_BR;
            11'b01010100xxx: opcode = OP_B_COND; //verilog doesnt like b.cond
            11'b100101xxxxx: opcode = OP_BL;
            11'b11010110001: opcode = OP_BLR;
            11'b10110101xxx: opcode = OP_CBNZ;
            11'b10110100xxx: opcode = OP_CBZ;
            11'b11010110010: opcode = OP_RET;
            11'b11010101000: opcode = OP_NOP;
            11'b11010100010: opcode = OP_HLT;
            default: opcode = OP_ERR; //cant set it 0 causing errors
        endcase
    end

endmodule

// module instr_format_decoder (
//     input opcode op
//     output instr ;
// );
// always_comb begin : decode
//     // casez(opcode)

//     // endcase
// end

// endmodule

module cond_holds (
    input cond_t cond,
    input nzcv_t nzcv,
    output logic cond_holds
);
    logic N, Z, C, V;
    assign N = nzcv.N;
    assign Z = nzcv.Z;
    assign C = nzcv.C;
    assign V = nzcv.V;

always_comb begin
    casez(cond)
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


module ArithmeticExecuteUnit(
    input alu_op_t in_alu_op,
    input logic [`GPR_SIZE-1:0] in_val_a,
    input logic [`GPR_SIZE-1:0] in_val_b,
    input logic [5:0] in_alu_val_hw,
    input logic in_set_CC,
    input cond_t in_cond,
    input nzcv_t in_prev_nzcv,
    output logic out_cond_val,
    output logic [`GPR_SIZE-1:0] out_res,
    output nzcv_t out_nzcv,
    output logic out_done    // Done signal indicating operation completion
);

    logic [`GPR_SIZE-1:0] result_reg;
    nzcv_t nzcv;

    logic cond_val;
    cond_holds c_holds(.cond(in_cond), .nzcv(in_prev_nzcv), .cond_holds(cond_val));

    always_comb begin : main_switch
        casez(in_alu_op)
            ALU_OP_PLUS: result_reg = in_val_a + in_val_b;
            ALU_OP_MINUS: result_reg = in_val_a - in_val_b;
            ALU_OP_ORN: result_reg = in_val_a | (~in_val_b);
            ALU_OP_OR: result_reg = in_val_a | in_val_b;
            ALU_OP_EOR: result_reg = in_val_a ^ in_val_b;
            ALU_OP_AND: result_reg = in_val_a & in_val_b;
            ALU_OP_MOV: result_reg = in_val_a | (in_val_b << in_alu_val_hw);
            ALU_OP_CSNEG: result_reg = in_val_b + 1;
            ALU_OP_CSINC: result_reg = in_val_b + 1;
            ALU_OP_CSINV: result_reg = in_val_b;
            ALU_OP_CSEL: result_reg = in_val_b;
            ALU_OP_PASS_A: result_reg = in_val_a;
            default: result_reg = 0;
        endcase
        if(in_set_CC) begin
            nzcv.N = result_reg[`GPR_SIZE-1];
            nzcv.Z = result_reg == 0;
            casez (in_alu_op) /* Setting carry flag */
                ALU_OP_PLUS: nzcv.C = (result_reg < in_val_a) | (result_reg < in_val_b);
                ALU_OP_MINUS: nzcv.C = in_val_a >= in_val_b;
                default: out_nzcv.C = 0;
            endcase
            casez (in_alu_op) /* Setting overflow flag */
                ALU_OP_PLUS: nzcv.V = (~in_val_a[`GPR_SIZE-1] & ~in_val_b[`GPR_SIZE-1] & nzcv.N) | (in_val_a[`GPR_SIZE-1] & in_val_b[`GPR_SIZE-1] & ~nzcv.N);
                ALU_OP_MINUS: nzcv.V = (~in_val_a[`GPR_SIZE-1] & in_val_b[`GPR_SIZE-1] & nzcv.N) | (in_val_a[`GPR_SIZE-1] & ~in_val_b[`GPR_SIZE-1] & ~nzcv.N);
                default: nzcv.V = 0;
            endcase
        end
        out_nzcv = nzcv;
        if(in_alu_op == ALU_OP_CSEL || in_alu_op == ALU_OP_CSNEG || in_alu_op == ALU_OP_CSINC || in_alu_op == ALU_OP_CSINV) begin
            if(cond_val == 0) begin
                out_res = result_reg;
            end
            else begin
                out_res = in_val_a;
            end
        end
        else begin
            out_res = result_reg;
        end
    end
endmodule

module OP_UBFM_module(
    input logic [63:0] in_val_a,
    input logic [5:0] in_imms,
    input logic [5:0] in_immr,
    output logic [63:0] out_res
);

    always_comb begin
        if (in_imms >= in_immr) begin
            out_res = (in_val_a >> in_immr) & ((1 << (in_imms - in_immr + 1)) - 1);
        end else begin
            out_res = (in_val_a & ((1 << (in_imms + 1)) - 1)) << in_immr;
        end
    end

endmodule

module OP_SBFM_module(
    input logic signed [63:0] in_val_a,
    input logic signed [5:0] in_imms,
    input logic signed [5:0] in_immr,
    output logic signed [63:0] out_res
);

    always_comb begin
        if (in_imms >= in_immr) begin
            out_res = (in_val_a >> in_immr) & ((1 << (in_imms - in_immr + 1)) - 1);
        end else begin
            out_res = (in_val_a & ((1 << (in_imms + 1)) - 1)) << in_immr;
        end
    end

endmodule