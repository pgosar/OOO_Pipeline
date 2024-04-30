`include "data_structures.sv"

module decode_instruction (
    input logic [`INSNBITS_SIZE-1:0] in_insnbits,
    output opcode_t opcode
);
  always_comb begin
    casez (in_insnbits)
      // All references in this decode are made to the Arm Architecture
      // Reference Manual version K.a released 2024-03-20
      // // C6.2.221 - 64-bit unscaled load.
      // C6.2.389 - 64-bit unscaled store.
      32'b1111_1000_000?_????_????_00??_????_????: opcode = OP_STUR;
      // C6.2.388 - 64-bit unscaled load.
      32'b1111_1000_010?_????_????_00??_????_????: opcode = OP_LDUR;
      // C6.2.186 - 64-bit paired load.
      32'b1010_1000_11??_????_????_????_????_????: opcode = OP_LDP;
      // C6.2.364 - 64-bit paired store.
      32'b1010_1001_00??_????_????_????_????_????: opcode = OP_STP;
      // C6.2.243 - 64-bit move with zeros
      32'b1101_0010_1???_????_????_????_????_????: opcode = OP_MOVZ;
      // C6.2.246 - 64-bit move with keep
      32'b1111_0010_1???_????_????_????_????_????: opcode = OP_MOVK;
      // C6.2.11  - Form PC relative address
      32'b0??1_0000_????_????_????_????_????_????: opcode = OP_ADR;
      // C6.2.12  - Form PC relative page
      32'b1??1_0000_????_????_????_????_????_????: opcode = OP_ADRP;
      // C6.2.111 - 64-bit conditional select or increment. Used by aliases CINC, CSET.
      32'b1001_1010_100?_????_????_01??_????_????: opcode = OP_CSINC;
      // C6.2.112 - 64-bit conditional select or inverse. Used by aliases CINV, CSETM.
      32'b1101_1010_100?_????_????_00??_????_????: opcode = OP_CSINV;
      // C6.2.113 - 64-bit conditional select or negate. Used by alias CNEG.
      32'b1101_1010_100?_????_????_01??_????_????: opcode = OP_CSNEG;
      // C6.2.108 - 64-bit conditional select.
      32'b1001_1010_100?_????_????_00??_????_????: opcode = OP_CSEL;
      // C6.2.5   - 64-bit add with out_reg_imm. Beware of sh.
      32'b1001_0001_0???_????_????_????_????_????: opcode = OP_ADD;
      // C6.2.10  - 64-bit add with !(shifted) reg. Sets NZCV.
      32'b1010_1011_000?_????_????_????_????_????: opcode = OP_ADDS;
      // C6.2.400 - 64-bit sub with immedaite. Beware of sh.
      32'b1101_0001_0???_????_????_????_????_????: opcode = OP_SUB;
      // C6.2.407 - 64-bit sub with !(shifted) reg. Sets NZCV. Used by alias CMP.
      32'b1110_1011_000?_????_????_????_????_????: opcode = OP_SUBS;
      // C6.2.260 - 64-bit or with complement of shifted reg. Used by alias MVN.
      32'b1010_1010_001?_????_????_????_????_????: opcode = OP_ORN;
      // C6.2.262 - 64-bit or with !(shifted) register. Used by alias MOV (register).
      32'b1010_1010_000?_????_????_????_????_????: opcode = OP_ORR;
      // C6.2.126 - 64-bit xor with !(shifted) register.
      32'b1100_1010_000?_????_????_????_????_????: opcode = OP_EOR;
      // C6.2.13  - 64-bit and with out_reg_imm.
      32'b1001_0010_00??_????_????_????_????_????: opcode = OP_AND;
      // C6.2.16  - 64-bit and with !(shifted) register. Sets NZCV. Used by alias TST (shifted regsiter).
      32'b1110_1010_000?_????_????_????_????_????: opcode = OP_ANDS;
      // C6.2.432 - Does something idk. Used by alias LSL and LSR.
      32'b1101_0011_01??_????_????_????_????_????: opcode = OP_UBFM;
      // C6.2.306 - Does something idk. Used by alias ASR.
      32'b1001_0011_01??_????_????_????_????_????: opcode = OP_SBFM;
      // C6.2.26  - Unconditional branch.
      32'b0001_01??_????_????_????_????_????_????: opcode = OP_B;
      // C6.2.27  - Conditional branch.
      32'b0101_0100_????_????_????_????_???0_????: opcode = OP_B_COND;
      // C6.2.35  - Unconditional branch with link.
      32'b1001_01??_????_????_????_????_????_????: opcode = OP_BL;
      // C6.2.36  - Unconditional branch with link to register.
      32'b1101_0110_0011_1111_0000_00??_???0_0000: opcode = OP_BLR;
      // C6.2.38  - Unconditional branch to register.
      32'b1101_0110_0001_1111_0000_00??_???0_0000: opcode = OP_BR;
      // C6.2.47  - 64-bit compare and branch on nonzero.
      32'b1011_0101_????_????_????_????_????_????: opcode = OP_CBNZ;
      // C6.2.48  - 64-bit compare and branch on zero
      32'b1011_0100_????_????_????_????_????_????: opcode = OP_CBZ;
      // C6.2.291 - Unconditional branch to register.
      32'b1101_0110_0101_1111_0000_00??_???0_0000: opcode = OP_RET;
      // C6.2.259 - Do nothing!
      32'b1101_0101_0000_0011_0010_0000_0001_1111: opcode = OP_NOP;
      // C6.2.142 - Halt! Used to generate Halt debug events
      32'b1101_0100_010?_????_????_????_???0_0000: opcode = OP_HLT;
      // Homemade! If you see this appear in the pipeline, direct complaints to Kavya Rathod.
      default: opcode = OP_ERR;
    endcase
  end

endmodule : decode_instruction

module extract_immval (
    input logic [`INSNBITS_SIZE-1:0] in_insnbits,
    input opcode_t opcode,
    output logic [63:0] out_reg_imm
);

  // TODO(Nate): Add AND, STP, LDP. Probably remove shifts to aid in synthesis.
  //             Could these assignments result in floating values because we
  //             haven't assigned every bit? idk
  always_comb begin
    case (opcode)
      OP_LDUR, OP_STUR: out_reg_imm = {55'd0, in_insnbits[20:12]};
      OP_ADD, OP_SUB, OP_UBFM, OP_SBFM: out_reg_imm = {52'd0, in_insnbits[21:10]};
      OP_MOVK, OP_MOVZ: out_reg_imm = {48'd0, in_insnbits[20:5]};
      OP_ADRP: out_reg_imm = {31'd0, in_insnbits[23:5], in_insnbits[30:29], 12'h000};
      OP_B, OP_BL: out_reg_imm = ({38'd0, in_insnbits[25:0]}) * 4;
      OP_B_COND, OP_CBNZ, OP_CBZ: out_reg_imm = ({45'd0, in_insnbits[23:5]}) * 4;


      default: out_reg_imm = 0;
    endcase
  end

endmodule : extract_immval

module extract_reg (
    input logic [`INSNBITS_SIZE-1:0] in_insnbits,
    input opcode_t opcode,
    output logic [`GPR_IDX_SIZE-1:0] out_reg_src1,
    output logic [`GPR_IDX_SIZE-1:0] out_reg_src2,
    output logic [`GPR_IDX_SIZE-1:0] out_reg_dst
);
  always_comb begin
    //out_reg_dst
    if (opcode != OP_B & opcode != OP_BR & opcode != OP_B_COND &  //branch dont need out_reg_dst
        opcode != OP_BL & opcode != OP_BLR & opcode != OP_RET &  //branch dont need out_reg_dst
        opcode != OP_NOP & opcode != OP_HLT &  //S format
        opcode != OP_CBZ & opcode != OP_CBNZ) begin  //i something format
      out_reg_dst = in_insnbits[4:0];
    end else if (opcode == OP_BL) begin
      out_reg_dst = 5'd30;
    end else begin
      out_reg_dst = 0;
    end

    //out_reg_src1
    if (opcode != OP_MOVK & opcode != OP_MOVZ & opcode != OP_ADR | opcode != OP_ADRP |
            opcode != OP_B & opcode != OP_BR & opcode != OP_B_COND & opcode != OP_BL & opcode
            != OP_BLR & opcode != OP_NOP & opcode != OP_HLT
            & opcode != OP_CBZ & opcode != OP_CBNZ) begin
      out_reg_src1 = in_insnbits[9:5];
    end else if (opcode == OP_CBZ | opcode == OP_CBNZ) begin
      out_reg_src1 = in_insnbits[4:0];
    end else begin
      out_reg_src1 = 0;
    end

    //out_reg_src2
    if (opcode == OP_STUR) begin
      out_reg_src2 = in_insnbits[4:0];
    end else if (opcode == OP_ADDS | opcode == OP_SUBS | opcode == OP_ORN | opcode == OP_ORR | opcode == OP_EOR | opcode == OP_ANDS | opcode == OP_CSEL | opcode == OP_CSINV | opcode == OP_CSINC | opcode == OP_CSNEG) begin
      out_reg_src2 = in_insnbits[20:16];
    end else begin
      out_reg_src2 = 0;
    end
  end
endmodule

module decide_alu (
    input  opcode_t opcode,
    output fu_op_t  out_reg_fu_op
);
  // TODO op_cmp, op_tst def commented out in opcode_t
  always_comb begin
    casez (opcode)
      OP_LDP, OP_STP, OP_ADD, OP_ADDS, OP_ADR, OP_ADRP: out_reg_fu_op = FU_OP_PLUS;
      OP_LDUR: out_reg_fu_op = FU_OP_LDUR;
      OP_STUR: out_reg_fu_op = FU_OP_STUR;
      OP_SUB, OP_SUBS: out_reg_fu_op = FU_OP_MINUS;
      OP_ORN: out_reg_fu_op = FU_OP_ORN;
      OP_ORR: out_reg_fu_op = FU_OP_OR;
      OP_EOR: out_reg_fu_op = FU_OP_EOR;
      OP_ANDS: out_reg_fu_op = FU_OP_AND;
      OP_UBFM: out_reg_fu_op = FU_OP_UBFM;
      OP_SBFM: out_reg_fu_op = FU_OP_SBFM;
      OP_MOVK, OP_MOVZ: out_reg_fu_op = FU_OP_MOV;
      OP_CSEL: out_reg_fu_op = FU_OP_CSEL;
      OP_CSINC: out_reg_fu_op = FU_OP_CSINC;
      OP_CSINV: out_reg_fu_op = FU_OP_CSINV;
      default: out_reg_fu_op = FU_OP_PLUS;  //plus for now i will add an error op later
    endcase
  end

endmodule

module pipeline_control (
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

    valb_sel = (op == OP_ADDS  | op == OP_ANDS  | op == OP_SUBS
                            | op == OP_ORR
                            | op == OP_EOR  | op == OP_ORN
                            | op == OP_CSEL | op == OP_CSINV | op == OP_CSINC | op == OP_CSNEG);
    set_CC = (op == OP_ADDS | op == OP_ANDS | op == OP_SUBS);

    dmem_read = (op == OP_LDUR);
    dmem_write = (op == OP_STUR);

    dst_sel = (op == OP_BL | op == OP_BLR);
    wval_sel = (op == OP_LDUR);
    w_enable = !(op == OP_STUR | op == OP_B
                            | op == OP_B_COND | op == OP_RET | op == OP_NOP
                            | op == OP_HLT
                            | op == OP_CBZ | op == OP_CBNZ | op == OP_BR);
  end

endmodule

module fu_decider (
    input opcode_t opcode,
    output fu_t out_reg_fu_id
);
  always_comb begin
    if (opcode == OP_STUR | opcode == OP_LDUR | opcode == OP_LDP | opcode == OP_STP) begin
      out_reg_fu_id = FU_LS;
    end else begin
      out_reg_fu_id = FU_ALU;
    end
  end

endmodule

module sets_nzcv (
    input opcode_t opcode,
    output logic out_reg_set_nzcv
);

  always_comb begin
    if (opcode == OP_ADDS | opcode == OP_SUBS | opcode == OP_ANDS) begin : g_set_nzcv
      out_reg_set_nzcv = 1;
    end else begin : g_no_set_nzcv
      out_reg_set_nzcv = 0;
    end : g_no_set_nzcv
  end

endmodule

module use_out_reg_imm (
    input opcode_t opcode,
    output logic out_reg_use_imm
);

  always_comb begin
    if(opcode == OP_LDUR | opcode == OP_STUR | opcode == OP_LDP | opcode == OP_STP | opcode == OP_MOVK | opcode == OP_MOVZ |
   opcode == OP_ADR | opcode == OP_ADRP | opcode == OP_SUB | opcode == OP_ADD | opcode == OP_AND | opcode == OP_UBFM |
   opcode == OP_SBFM | opcode == OP_B | opcode == OP_BR | opcode == OP_B_COND | opcode == OP_BL | opcode == OP_BLR) begin
      out_reg_use_imm = 1;
    end else begin
      out_reg_use_imm = 0;
    end
  end

endmodule

module find_cond_code (
    input opcode_t in_opcode,
    input [`INSNBITS_SIZE-1:0] in_insnbits,
    output cond_t out_reg_cond_codes
);

  always_comb begin
    if (in_opcode == OP_B_COND) begin
      out_reg_cond_codes = cond_t'(in_insnbits[3:0]);
    end else if (in_opcode == OP_CSEL | in_opcode == OP_CSINC | in_opcode == OP_CSINV | in_opcode == OP_CSNEG) begin
      out_reg_cond_codes = cond_t'(in_insnbits[15:12]);
    end else begin
      out_reg_cond_codes = cond_t'(0);
    end
  end

endmodule

module uses_nzcv (
    input opcode_t in_opcode,
    output logic op_uses_nzcv
);

  always_comb begin
    if (in_opcode == OP_B_COND | in_opcode == OP_CSINV | in_opcode == OP_CSINV | in_opcode == OP_CSNEG |
        in_opcode == OP_CSEL) begin
      op_uses_nzcv = 1;
    end else begin
      op_uses_nzcv = 0;
    end
  end
endmodule

module dispatch (
    // Inputs from core
    input logic in_rst,
    input logic in_clk,
    input logic in_stall,
    // Inputs from fetch
    input logic [`INSNBITS_SIZE-1:0] in_fetch_insnbits,
    input logic in_fetch_done,
    // Outputs to regfile. This will (asynchronously) cause the regfile to send
    // signals to the ROB. We assume that this will occur within the same
    // cycle.
    output logic out_reg_done,
    output logic out_reg_set_nzcv,
    output logic out_reg_use_imm,
    output logic [`IMMEDIATE_SIZE-1:0] out_reg_imm,
    output logic [`GPR_IDX_SIZE-1:0] out_reg_src1,
    output logic [`GPR_IDX_SIZE-1:0] out_reg_src2,
    output fu_t out_reg_fu_id,
    output fu_op_t out_reg_fu_op,
    output logic [`GPR_IDX_SIZE-1:0] out_reg_dst,
    output cond_t out_reg_cond_codes,
    output logic out_reg_instr_uses_nzcv
    // Outputs to be broadcasted.
    // output logic out_stalled
);

  opcode_t opcode;
  logic [`INSNBITS_SIZE-1:0] insnbits;

  decode_instruction op_decoder (
      .*,
      .in_insnbits(insnbits)
  );
  extract_immval imm_extractor (
      .*,
      .in_insnbits(insnbits)
  );
  extract_reg reg_extractor (
      .*,
      .in_insnbits(insnbits)
  );

  find_cond_code cond_holds (
      .*,
      .in_opcode  (opcode),
      .in_insnbits(insnbits)
  );

  uses_nzcv instr_uses_nzcv (
      .in_opcode(opcode),
      .op_uses_nzcv(out_reg_instr_uses_nzcv)
  );
  use_out_reg_imm imm_selector (.*);
  decide_alu alu_decider (.*);  // decides alu op
  fu_decider fu (.*);
  sets_nzcv nzcv_setter (.*);

  always_ff @(posedge in_clk) begin
    if (in_rst) begin
      `DEBUG(("(dec) Resetting"));
      out_reg_done <= 0;
    end else begin
      out_reg_done <= ~in_rst & in_fetch_done;
      if (in_fetch_done) begin
        insnbits <= in_fetch_insnbits;
      end
    end
  end

  // Print statements only in here
  always_ff @(posedge in_clk) begin
    if (in_fetch_done & ~in_rst) begin
      #1 `DEBUG(("(dec) Decoding: %b", insnbits))
      `DEBUG(
          ("(dec)\tfu_id: %s, opcode: %s, fu_op: %s", out_reg_fu_id.name, opcode.name,
               out_reg_fu_op.name));
      `DEBUG(
          ("(dec)\tdst: X%0d, src1: X%0d, src2: X%0d, imm: %0d, use_imm: %b", out_reg_dst,
               out_reg_src1, out_reg_src2, out_reg_imm, out_reg_use_imm));
      `DEBUG(("(dec)\tsets_nzcv: %0b, uses_nzcv: %0b", out_reg_set_nzcv, out_reg_instr_uses_nzcv))
      `DEBUG(("(dec) cond codes %0b", out_reg_cond_codes))
    end
  end

endmodule : dispatch
