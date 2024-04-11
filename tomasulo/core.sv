`define OPCODE_SIZE 6

typedef enum logic[2:0] {
    S0 = 3'b000,
    S1 = 3'b001,
    S2 = 3'b010,
    S3 = 3'b011,
    S4 = 3'b100,
    S5 = 3'b101
} states;

typedef enum logic[5:0] {
    PLUS_OP,    // vala + (valb << valhw)
    MINUS_OP,   // vala - (valb << valhw)
    INV_OP,     // vala | (~valb)
    OR_OP,      // vala | valb
    EOR_OP,     // vala ^ valb
    AND_OP,     // vala & valb
    MOV_OP,     // vala | (valb << valhw)
    LSL_OP,     // vala << (valb & 0x3FUL)
    LSR_OP,     // vala >>L (valb & 0x3FUL)
    ASR_OP,     // vala >>A (valb & 0x3FUL)
    PASS_A_OP,  // vala
    CSEL_OP,     // EC: used for csel
    CSINV_OP,    // EC: used for csinv
    CSINC_OP,    // EC: used for csinc
    CSNEG_OP,    // EC: used for csneg
    CBZ_OP,      // EC: used for cbz
    CBNZ_OP     // EC: used for cbnz
} alu_op_t;

typedef enum logic[`OPCODE_SIZE-1:0] {
    OP_LDUR,
    OP_LDP,
    OP_STUR,
    OP_STP,
    OP_MOVK,
    OP_MOVZ,
    OP_ADR,
    OP_ADRP,
    OP_CINC,
    OP_CINV,
    OP_CNEG,
    OP_CSEL,
    OP_CSET,
    OP_CSETM,
    OP_CSINC,
    OP_CSINV,
    OP_CSNEG,
    OP_ADD,
    OP_ADDS,
    OP_SUB,
    OP_SUBS,
    OP_CMP,
    OP_MVN,
    OP_ORR,
    OP_EOR,
    OP_AND,
    OP_ANDS,
    OP_TST,
    OP_LSL,
    OP_LSR,
    OP_SBFM,
    OP_UBFM,
    OP_ASR,
    OP_B,
    OP_BR,
    OP_B_COND,
    OP_BL,
    OP_BLR,
    OP_CBNZ,
    OP_CBZ,
    OP_RET,
    OP_NOP,
    OP_HLT,
    OP_ERR
} opcode_t;

typedef enum logic [4:0] {
    ALU_OP_PLUS,    // vala + valb
    ALU_OP_MINUS,   // vala - valb
    ALU_OP_INVALID,     // vala | (~valb)
    ALU_OP_OR,      // vala | valb
    ALU_OP_EOR,     // vala ^ valb
    ALU_OP_AND,     // vala & valb
    ALU_OP_MOV,     // vala | (valb << valhw)
    ALU_OP_LSL,     // vala << (valb & 0x3FUL)
    ALU_OP_LSR,     // vala >>L (valb & 0x3FUL)
    ALU_OP_ASR,     // vala >>A (valb & 0x3FUL)
    ALU_OP_PASS_A,  // vala
    ALU_OP_CSEL,
    ALU_OP_CSINV,
    ALU_OP_CSINC,
    ALU_OP_CSNEG,
    ALU_OP_CBZ,
    ALU_O,
    ERROR_OP
} alu_op;

typedef enum logic [3:0] {
    C_EQ,
    C_NE,
    C_CS,
    C_CC,
    C_MI,
    C_PL,
    C_VS,
    C_VC,
    C_HI,
    C_LS,
    C_GE,
    C_LT,
    C_GT,
    C_LE,
    C_AL,
    C_NV
} cond_t;

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
    input logic [3:0] nzcv,
    output logic cond_holds
);
    logic N = nzcv[3];
    logic Z = nzcv[2];
    logic C = nzcv[1];
    logic V = nzcv[0];

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
    input logic clk,       // Clock
    input logic rst,       // Reset
    input logic start,     // Start signal to initiate the operation
    input logic [4:0] ALUop,
    input logic [63:0] alu_vala,
    input logic [63:0] alu_valb,
    input logic [5:0] alu_valhw,
    input logic set_CC,
    input logic [4:0] cond,
    output logic cond_val,
    output logic [63:0] res,
    output logic [3:0] nzcv,
    output logic done    // Done signal indicating operation completion
);


    logic [2:0] curreOP_RET_TSTate, nexOP_TSTate;
    logic [63:0] result_reg;
    logic N, Z, C, V;

    always_comb begin : main_switch
        casez(ALUop)
            PLUS_OP: result_reg = alu_vala + alu_valb;
            MINUS_OP: result_reg = alu_vala - alu_valb;
            INV_OP: result_reg = alu_vala | (~alu_valb);
            OR_OP: result_reg = alu_vala | alu_valb;
            EOR_OP: result_reg = alu_vala ^ alu_valb;
            AND_OP: result_reg = alu_vala & alu_valb;
            MOV_OP: result_reg = alu_vala | (alu_valb << alu_valhw);
            CSNEG_OP: result_reg = ~alu_valb + 1;
            CSINC_OP: result_reg = alu_valb + 1;
            CSINV_OP: result_reg = ~alu_valb;
            CSEL_OP: result_reg = alu_valb;
            PASS_A_OP: result_reg = alu_vala;
            default: result_reg = 0;
        endcase
        res = result_reg;
        if(set_CC) begin
            N = ((res & 64'h8000_0000_0000_0000) != 0);
            Z = (res == 0); 
            if(ALUop == PLUS_OP) begin
                C = (res < alu_vala) || (res < alu_valb);
            end
            if(ALUop == MINUS_OP) begin
                C = alu_vala >= alu_valb;
            end
            if(ALUop == PLUS_OP) begin
                V = !(alu_vala & 64'h8000_0000_0000_0000) && !(alu_valb & 64'h8000000000000000) && N;
                V |= (alu_vala & 64'h8000_0000_0000_0000) && (alu_valb & 64'h8000000000000000) && !N;
            end
            if(ALUop == MINUS_OP) begin
                V = !(alu_vala & 64'h8000_0000_0000_0000) && (alu_valb & 64'h8000000000000000) && N;
                V |= (alu_vala & 64'h8000_0000_0000_0000) && !(alu_valb & 64'h8000000000000000) && !N;
            end

            nzcv = {N, Z, C, V};
        end
    end
    
endmodule

module OP_UBFM_module(
    input logic [63:0] i_val_a,
    input logic clk,
    input logic rst,
    input logic [5:0] imms,
    input logic [5:0] immr,
    output logic [63:0] res
);

    always_ff @(posedge clk) begin : main_switch
        if (!rst) begin
            res <= 0;
        end else if (imms >= immr) begin
            res = (i_val_a >> immr) & ((1 << (imms - immr + 1)) - 1);
        end else begin
            res = (i_val_a & ((1 << (imms + 1)) - 1)) << immr;
        end
    end

endmodule

module OP_SBFM_module(
    input logic signed [63:0] val_a,
    input logic clk,
    input logic rst,
    input logic signed [5:0] imms,
    input logic signed [5:0] immr,
    output logic signed [63:0] res
);

    always_ff @(posedge clk) begin : main_switch
        if (!rst) begin
            res <= 0;
        end else if (imms >= immr) begin
            res = (val_a >> immr) & ((1 << (imms - immr + 1)) - 1);
        end else begin
            res = (val_a & ((1 << (imms + 1)) - 1)) << immr;
        end
    end

endmodule