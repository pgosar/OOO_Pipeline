`include "data_structures.sv"

module extract_immval(
    input [31:0] insnbits,
    input opcode_t in_op,
    input in_clk,
    output logic [63:0] imm
);

always_ff @(posedge in_clk) begin
    case (in_op)
        OP_LDUR, OP_STUR: imm = insnbits[20:12];
        OP_ADD, OP_SUB, OP_UBFM, OP_ASR: imm = insnbits[21:10];
        OP_MOVK, OP_MOVZ: imm = insnbits[20:5];
        OP_ADRP: imm = (insnbits[23:5] << 14) | (insnbits[31:29] << 12);
        default: imm = 0;
    endcase
end

endmodule

module extract_reg(
    input logic [31:0] insnbits,
    input opcode_t op,
    input logic clk,
    output logic [`GPR_IDX_SIZE-1:0] src1,
    output logic [`GPR_IDX_SIZE-1:0] src2,
    output logic [`GPR_IDX_SIZE-1:0] dst
);

    always_ff @(posedge clk) begin

        //dst
        if (op != OP_B && op != OP_BR && op != OP_B_COND && //branch dont need dst
            op != OP_BL && op != OP_BLR && op != OP_RET && //branch dont need dst
            op != OP_NOP && op != OP_HLT &&  //S format
            op != OP_CBZ && op != OP_CBNZ ) begin //i something format
                dst = insnbits[4:0];
        end else if (op == OP_BL) begin
            dst = 30;
        end

        //src1
        if (op != OP_MOVK && op != OP_MOVZ && op != OP_ADR || op != OP_ADRP ||
            op != OP_B && op != OP_BR && op != OP_B_COND && op != OP_BL && op != OP_BLR &&
            op != OP_NOP && op != OP_HLT
            && op != OP_CBZ && op != OP_CBNZ) begin
            src1 = insnbits[9:5];
        end else if(op == OP_CBZ || op == OP_CBNZ) begin
            src1 = insnbits[5:0];
        end

        //src2
        if (op == OP_STUR) begin
            src2 = insnbits[4:0];
        end else if (op == OP_ADDS || op == OP_SUBS || op == OP_CMP || op == OP_MVN ||
                     op == OP_ORR || op == OP_EOR || op == OP_ANDS ||
                     op == OP_TST || op == OP_CINC || op == OP_CINV || op == OP_CNEG || op == OP_CSET ||
                     op == OP_CSETM || op == OP_CSINC || op == OP_CSINV ||
                     op == OP_CSEL || op == OP_CSINV || op == OP_CSINC || op == OP_CSNEG) begin // extra credit checks
            src2 = insnbits[21:16];
        end

    end

endmodule

module decide_alu (
    input opcode_t in_opcode,
    output alu_op_t out_alu_op
);

    always_comb begin
        casez(in_opcode)
            OP_LDUR, OP_LDP, OP_STUR, OP_STP, OP_ADD, OP_ADDS, OP_ADR, OP_ADRP: out_alu_op = ALU_OP_PLUS;
            OP_SUB, OP_SUBS, OP_CMP:                                            out_alu_op = ALU_OP_MINUS;
            OP_MVN:                                                             out_alu_op = ALU_OP_ORN;
            OP_ORR:                                                             out_alu_op = ALU_OP_OR;
            OP_EOR:                                                             out_alu_op = ALU_OP_EOR;
            OP_ANDS, OP_TST:                                                    out_alu_op = ALU_OP_AND;
            OP_UBFM:                                                            out_alu_op = ALU_OP_UBFM;
            OP_SBFM:                                                            out_alu_op = ALU_OP_SBFM;
            OP_MOVK, OP_MOVZ:                                                   out_alu_op = ALU_OP_MOV;
            OP_CSEL:                                                            out_alu_op = ALU_OP_CSEL;
            OP_CSINC:                                                           out_alu_op = ALU_OP_CSINC;
            OP_CSINV:                                                           out_alu_op = ALU_OP_CSINV;
            default: out_alu_op = ALU_OP_PLUS; //plus for now i will add an error op later
        endcase
    end

endmodule

module pipeline_control(
    input opcode_t op,
    input d_ctl_sigs_t D_sigs_in,
    input x_ctl_sigs_t X_sigs_in,
    input m_ctl_sigs_t M_sigs_in,
    input w_ctl_sigs_t W_sigs_in,
    output logic src2_sel,
    output logic valb_sel,
    output logic set_CC,
    output logic dmem_read,
    output logic dmem_write,
    output logic dst_sel,
    output logic wval_sel,
    output logic w_enable
);

    // Generate control signals based on opcode
    always @* begin
        src2_sel = (op == OP_STUR);

        valb_sel = (op == OP_ADDS  || op == OP_ANDS  || op == OP_SUBS
                            || op == OP_CMP  || op == OP_TST  || op == OP_ORR
                            || op == OP_EOR  || op == OP_MVN
                            || op == OP_CSEL || op == OP_CSINV || op == OP_CSINC || op == OP_CSNEG);
        set_CC = (op == OP_ADDS  || op == OP_ANDS  || op == OP_SUBS
                        || op == OP_CMP  || op == OP_TST );

        dmem_read = (op == OP_LDUR);
        dmem_write = (op == OP_STUR);

        dst_sel = (op == OP_BL || op == OP_BLR);
        wval_sel = (op == OP_LDUR);
        w_enable = !(op == OP_STUR || op == OP_B
                            || op == OP_B_COND || op == OP_RET || op == OP_NOP
                            || op == OP_HLT || op == OP_CMP  || op == OP_TST
                            || op == OP_CBZ || op == OP_CBNZ || op == OP_BR);
    end

endmodule
