`include "data_structures.sv"

module decode_instruction (
    input logic [31:0] in_insn,
    output opcode_t out_opcode
);
    always_comb begin
        casez(in_insn)
            // All references in this decode are made to the Arm Architecture
            // Reference Manual version K.a released 2024-03-20
            32'b1111_1000_010?_????_????_00??_????_????: out_opcode = OP_LDUR;   // C6.2.221 - 64-bit unscaled load.
            32'b1111_1000_000?_????_????_00??_????_????: out_opcode = OP_STUR;   // C6.2.389 - 64-bit unscaled store
            32'b1010_1000_11??_????_????_????_????_????: out_opcode = OP_LDP;    // C6.2.186 - 64-bit paired load.
            32'b1010_1001_00??_????_????_????_????_????: out_opcode = OP_STP;    // C6.2.364 - 64-bit paired store.
            32'b1111_0010_1???_????_????_????_????_????: out_opcode = OP_MOVK;   // C6.2.244 - 64-bit move with keep
            32'b0??1_0000_????_????_????_????_????_????: out_opcode = OP_ADR;    // C6.2.11  - Form PC relative address
            32'b1??1_0000_????_????_????_????_????_????: out_opcode = OP_ADRP;   // C6.2.12  - Form PC relative page
            32'b1001_1010_100?_????_????_01??_????_????: out_opcode = OP_CSINC;  // C6.2.111 - 64-bit conditional select or increment. Used by aliases CINC, CSET.
            32'b1101_1010_100?_????_????_00??_????_????: out_opcode = OP_CSINV;  // C6.2.112 - 64-bit conditional select or inverse. Used by aliases CINV, CSETM.
            32'b1101_1010_100?_????_????_01??_????_????: out_opcode = OP_CSNEG;  // C6.2.113 - 64-bit conditional select or negate. Used by alias CNEG.
            32'b1001_1010_100?_????_????_00??_????_????: out_opcode = OP_CSEL;   // C6.2.108 - 64-bit conditional select.
            32'b1001_0001_0???_????_????_????_????_????: out_opcode = OP_ADD;    // C6.2.5   - 64-bit add with immediate. Beware of sh.
            32'b1010_1011_000?_????_????_????_????_????: out_opcode = OP_ADDS;   // C6.2.10  - 64-bit add with !(shifted) reg. Sets NZCV.
            32'b1101_0001_0???_????_????_????_????_????: out_opcode = OP_SUB;    // C6.2.400 - 64-bit sub with immedaite. Beware of sh.
            32'b1110_1011_000?_????_????_????_????_????: out_opcode = OP_SUBS;   // C6.2.407 - 64-bit sub with !(shifted) reg. Sets NZCV. Used by alias CMP.
            32'b1010_1010_001?_????_????_????_????_????: out_opcode = OP_ORN;    // C6.2.260 - 64-bit or with complement of shifted reg. Used by alias MVN.
            32'b1010_1010_000?_????_????_????_????_????: out_opcode = OP_ORR;    // C6.2.262 - 64-bit or with !(shifted) register. Used by alias MOV (register).
            32'b1100_1010_000?_????_????_????_????_????: out_opcode = OP_EOR;    // C6.2.126 - 64-bit xor with !(shifted) register.
            32'b1001_0010_00??_????_????_????_????_????: out_opcode = OP_AND;    // C6.2.13  - 64-bit and with immediate.
            32'b1110_1010_000?_????_????_????_????_????: out_opcode = OP_ANDS;   // C6.2.16  - 64-bit and with !(shifted) register. Sets NZCV. Used by alias TST (shifted regsiter).
            32'b1101_0011_01??_????_????_????_????_????: out_opcode = OP_UBFM;   // C6.2.432 - Does something idk. Used by alias LSL and LSR.
            32'b1001_0011_01??_????_????_????_????_????: out_opcode = OP_SBFM;   // C6.2.306 - Does something idk. Used by alias ASR.
            32'b0001_01??_????_????_????_????_????_????: out_opcode = OP_B;      // C6.2.26  - Unconditional branch.
            32'b0101_0100_????_????_????_????_???0_????: out_opcode = OP_B_COND; // C6.2.27  - Conditional branch.
            32'b1001_01??_????_????_????_????_????_????: out_opcode = OP_BL;     // C6.2.35  - Unconditional branch with link.
            32'b1101_0110_0011_1111_0000_00??_???0_0000: out_opcode = OP_BLR;    // C6.2.36  - Unconditional branch with link to register.
            32'b1101_0110_0001_1111_0000_00??_???0_0000: out_opcode = OP_BR;     // C6.2.38  - Unconditional branch to register.
            32'b1011_0101_????_????_????_????_????_????: out_opcode = OP_CBNZ;   // C6.2.47  - 64-bit compare and branch on nonzero.
            32'b1011_0100_????_????_????_????_????_????: out_opcode = OP_CBZ;    // C6.2.48  - 64-bit compare and branch on zero
            32'b1101_0110_0101_1111_0000_00??_???0_0000: out_opcode = OP_RET;    // C6.2.291 - Unconditional branch to register.
            32'b1101_0101_0000_0011_0010_0000_0001_1111: out_opcode = OP_NOP;    // C6.2.259 - Do nothing!
            32'b1101_0100_010?_????_????_????_???0_0000: out_opcode = OP_HLT;    // C6.2.142 - Halt! Used to generate Halt debug events
            default: out_opcode = OP_ERR; // Homemade! If you see this appear in the pipeline, direct complaints to Kavya Rathod.
        endcase
    end

endmodule : decode_instruction

module extract_immval (
    input [31:0] in_insnbits,
    input opcode_t in_op,
    output logic [63:0] out_imm
);

// TODO(Nate): Add AND, STP, LDP. Probably remove shifts to aid in synthesis.
//             Could these assignments result in floating values because we
//             haven't assigned every bit? idk
always_comb begin
    case (in_op)
        OP_LDUR, OP_STUR: out_imm = {55'd0, in_insnbits[20:12]};
        OP_ADD, OP_SUB, OP_UBFM, OP_SBFM: out_imm = {52'd0, in_insnbits[21:10]};
        OP_MOVK, OP_MOVZ: out_imm = {48'd0, in_insnbits[20:5]};
        OP_ADRP: out_imm = {31'd0, in_insnbits[23:5],in_insnbits[30:29],12'h000};
        default: out_imm = 0;
    endcase
end

endmodule : extract_immval

module extract_reg(
    input logic [31:0] in_insnbits,
    input opcode_t in_op,
    output logic [`GPR_IDX_SIZE-1:0] out_src1,
    output logic [`GPR_IDX_SIZE-1:0] out_src2,
    output logic [`GPR_IDX_SIZE-1:0] out_dst
);
    always_comb begin
        //out_dst
        if (in_op != OP_B && in_op != OP_BR && in_op != OP_B_COND && //branch dont need out_dst
            in_op != OP_BL && in_op != OP_BLR && in_op != OP_RET && //branch dont need out_dst
            in_op != OP_NOP && in_op != OP_HLT &&  //S format
            in_op != OP_CBZ && in_op != OP_CBNZ ) begin //i something format
                out_dst = in_insnbits[4:0];
        end else if (in_op == OP_BL) begin
            out_dst = 5'd30;
        end

        //out_src1
        if (in_op != OP_MOVK && in_op != OP_MOVZ && in_op != OP_ADR || in_op != OP_ADRP ||
            in_op != OP_B && in_op != OP_BR && in_op != OP_B_COND && in_op != OP_BL && in_op != OP_BLR &&
            in_op != OP_NOP && in_op != OP_HLT
            && in_op != OP_CBZ && in_op != OP_CBNZ) begin
            out_src1 = in_insnbits[9:5];
        end else if(in_op == OP_CBZ || in_op == OP_CBNZ) begin
            out_src1 = in_insnbits[4:0];
        end

        //out_src2
        if (in_op == OP_STUR) begin
            out_src2 = in_insnbits[4:0];
        end else if (in_op == OP_ADDS || in_op == OP_SUBS || in_op == OP_ORN ||
                        in_op == OP_ORR || in_op == OP_EOR || in_op == OP_ANDS ||
                        in_op == OP_CSEL || in_op == OP_CSINV || in_op == OP_CSINC || in_op == OP_CSNEG) begin // extra credit checks
            out_src2 = in_insnbits[20:16];
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
            OP_ORN:                                                             out_alu_op = ALU_OP_ORN;
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
    always_comb begin
        src2_sel = (op == OP_STUR);

        valb_sel = (op == OP_ADDS  || op == OP_ANDS  || op == OP_SUBS
                            || op == OP_ORR
                            || op == OP_EOR  || op == OP_ORN
                            || op == OP_CSEL || op == OP_CSINV || op == OP_CSINC || op == OP_CSNEG);
        set_CC = (op == OP_ADDS  || op == OP_ANDS  || op == OP_SUBS);

        dmem_read = (op == OP_LDUR);
        dmem_write = (op == OP_STUR);

        dst_sel = (op == OP_BL || op == OP_BLR);
        wval_sel = (op == OP_LDUR);
        w_enable = !(op == OP_STUR || op == OP_B
                            || op == OP_B_COND || op == OP_RET || op == OP_NOP
                            || op == OP_HLT
                            || op == OP_CBZ || op == OP_CBNZ || op == OP_BR);
    end

endmodule

module dispatch (
    // Inputs from core
    input logic in_clk,
    input logic in_stall,
    // Inputs from fetch
    input logic [31:0] in_insnbits,
    input logic in_fetch_done,
    // Outputs to regfile. This will (asynchronously) cause the regfile to send
    // signals to the ROB. We assume that this will occur within the same
    // cycle.
    output logic [`GPR_IDX_SIZE-1:0] out_src1,
    output logic [`GPR_IDX_SIZE-1:0] out_src2,
    output func_unit out_fu,
    output logic [`GPR_IDX_SIZE-1:0] out_dst,
    // Outputs to be broadcasted.
    output logic out_stalled
);

    always_ff @(posedge in_clk) begin
        if (!in_stall) begin
        end
    end

    opcode_t opcode;
    logic [63:0] immediate;

    decode_instruction op_decoder(.in_insn(in_insnbits), .out_opcode(opcode));
    extract_immval imm_extractor (.in_insnbits(in_insnbits), .in_op(opcode), .out_imm(immediate));
    extract_reg reg_extractor (
        .in_insnbits(in_insnbits),
        .in_op(opcode),
        .out_src1(out_src1),
        .out_src2(out_src2),
        .out_dst(out_dst)
    );
    // TODO(Nate): Could use a module to decide which functional unit to go to based on opcode.


endmodule : dispatch
