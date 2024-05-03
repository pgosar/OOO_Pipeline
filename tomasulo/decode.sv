`ifndef DECODE
`define DECODE

`include "data_structures.sv"


module decode_instruction (
    input logic [`INSNBITS_SIZE-1:0] in_insnbits,
    output opcode_t out_opcode
);
  always_comb begin
    casez (in_insnbits)
      // All references in this decode are made to the Arm Architecture
      // Reference Manual version K.a released 2024-03-20
      // C6.2.389 - 64-bit unscaled store.
      32'b1111_1000_000?_????_????_00??_????_????: out_opcode = OP_STUR;
      // C6.2.388 - 64-bit unscaled load.
      32'b1111_1000_010?_????_????_00??_????_????: out_opcode = OP_LDUR;
      // C6.2.186 - 64-bit paired load.
      32'b1010_1000_11??_????_????_????_????_????: out_opcode = OP_LDP;
      // C6.2.364 - 64-bit paired store.
      32'b1010_1001_00??_????_????_????_????_????: out_opcode = OP_STP;
      // C6.2.243 - 64-bit move with zeros
      32'b1101_0010_1???_????_????_????_????_????: out_opcode = OP_MOVZ;
      // C6.2.246 - 64-bit move with keep
      32'b1111_0010_1???_????_????_????_????_????: out_opcode = OP_MOVK;
      // C6.2.11  - Form PC relative address
      32'b0??1_0000_????_????_????_????_????_????: out_opcode = OP_ADR;
      // C6.2.12  - Form PC relative page
      32'b1??1_0000_????_????_????_????_????_????: out_opcode = OP_ADRP;
      // C6.2.111 - 64-bit conditional select or increment. Used by aliases CINC, CSET.
      32'b1001_1010_100?_????_????_01??_????_????: out_opcode = OP_CSINC;
      // C6.2.112 - 64-bit conditional select or inverse. Used by aliases CINV, CSETM.
      32'b1101_1010_100?_????_????_00??_????_????: out_opcode = OP_CSINV;
      // C6.2.113 - 64-bit conditional select or negate. Used by alias CNEG.
      32'b1101_1010_100?_????_????_01??_????_????: out_opcode = OP_CSNEG;
      // C6.2.108 - 64-bit conditional select.
      32'b1001_1010_100?_????_????_00??_????_????: out_opcode = OP_CSEL;
      // C6.2.5   - 64-bit add with out_reg_imm. Beware of sh.
      32'b1001_0001_0???_????_????_????_????_????: out_opcode = OP_ADD;
      // C6.2.10  - 64-bit add with !(shifted) reg. Sets NZCV.
      32'b1010_1011_000?_????_????_????_????_????: out_opcode = OP_ADDS;
      // C6.2.400 - 64-bit sub with immedaite. Beware of sh.
      32'b1101_0001_0???_????_????_????_????_????: out_opcode = OP_SUB;
      // C6.2.407 - 64-bit sub with !(shifted) reg. Sets NZCV. Used by alias CMP.
      32'b1110_1011_000?_????_????_????_????_????: out_opcode = OP_SUBS;
      // C6.2.260 - 64-bit or with complement of shifted reg. Used by alias MVN.
      32'b1010_1010_001?_????_????_????_????_????: out_opcode = OP_ORN;
      // C6.2.262 - 64-bit or with !(shifted) register. Used by alias MOV (register).
      32'b1010_1010_000?_????_????_????_????_????: out_opcode = OP_ORR;
      // C6.2.126 - 64-bit xor with !(shifted) register.
      32'b1100_1010_000?_????_????_????_????_????: out_opcode = OP_EOR;
      // C6.2.13  - 64-bit and with out_reg_imm.
      32'b1001_0010_00??_????_????_????_????_????: out_opcode = OP_AND;
      // C6.2.16  - 64-bit and with !(shifted) register. Sets NZCV. Used by alias TST (shifted regsiter).
      32'b1110_1010_000?_????_????_????_????_????: out_opcode = OP_ANDS;
      // C6.2.432 - Does something idk. Used by alias LSL and LSR.
      32'b1101_0011_01??_????_????_????_????_????: out_opcode = OP_UBFM;
      // C6.2.306 - Does something idk. Used by alias ASR.
      32'b1001_0011_01??_????_????_????_????_????: out_opcode = OP_SBFM;
      // C6.2.26  - Unconditional branch.
      32'b0001_01??_????_????_????_????_????_????: out_opcode = OP_B;
      // C6.2.27  - Conditional branch.
      32'b0101_0100_????_????_????_????_???0_????: out_opcode = OP_B_COND;
      // C6.2.35  - Unconditional branch with link.
      32'b1001_01??_????_????_????_????_????_????: out_opcode = OP_BL;
      // C6.2.36  - Unconditional branch with link to register.
      32'b1101_0110_0011_1111_0000_00??_???0_0000: out_opcode = OP_BLR;
      // C6.2.38  - Unconditional branch to register.
      32'b1101_0110_0001_1111_0000_00??_???0_0000: out_opcode = OP_BR;
      // C6.2.47  - 64-bit compare and branch on nonzero.
      32'b1011_0101_????_????_????_????_????_????: out_opcode = OP_CBNZ;
      // C6.2.48  - 64-bit compare and branch on zero
      32'b1011_0100_????_????_????_????_????_????: out_opcode = OP_CBZ;
      // C6.2.291 - Unconditional branch to register.
      32'b1101_0110_0101_1111_0000_00??_???0_0000: out_opcode = OP_RET;
      // C6.2.259 - Do nothing!
      32'b1101_0101_0000_0011_0010_0000_0001_1111: out_opcode = OP_NOP;
      // C6.2.142 - Halt! Used to generate Halt debug events
      32'b1101_0100_010?_????_????_????_???0_0000: out_opcode = OP_HLT;
      // Homemade! If you see this appear in the pipeline, direct complaints to Kavya Rathod.
      default: out_opcode = OP_ERR;
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
      OP_LDUR, OP_STUR: out_reg_imm = {{55{in_insnbits[20]}}, in_insnbits[20:12]};
      OP_ADD, OP_SUB, OP_UBFM: out_reg_imm = {52'b0, in_insnbits[21:10]};
      OP_SBFM: out_reg_imm = {{52{in_insnbits[21]}}, in_insnbits[21:10]};
      OP_MOVK, OP_MOVZ: out_reg_imm = {48'd0, in_insnbits[20:5]};
      OP_ADRP: out_reg_imm = {{31{in_insnbits[23]}}, in_insnbits[23:5], in_insnbits[30:29], 12'h000};
      OP_ADR: out_reg_imm = {{43{in_insnbits[30]}}, in_insnbits[23:5], in_insnbits[30:29]};
      OP_B, OP_BL: out_reg_imm = {{36{in_insnbits[25]}}, in_insnbits[25:0], 2'b0};
      OP_B_COND, OP_CBNZ, OP_CBZ: out_reg_imm = {{43{in_insnbits[23]}}, in_insnbits[23:5], 2'b0};
      default: out_reg_imm = 0;
    endcase
  end

endmodule : extract_immval

module extract_reg (
    input logic [`INSNBITS_SIZE-1:0] in_insnbits,
    input opcode_t opcode,
    output logic [`GPR_IDX_SIZE-1:0] out_reg_src1,
    output reg_status_t out_reg_src1_status,
    output logic [`GPR_IDX_SIZE-1:0] out_reg_src2,
    output reg_status_t out_reg_src2_status,
    output logic [`GPR_IDX_SIZE-1:0] out_reg_dst,
    output reg_status_t out_reg_dst_status
);
  always_comb begin
    //out_reg_dst
    casez (opcode)
      OP_B, OP_BR, OP_B_COND, OP_CBZ, OP_CBNZ, OP_RET, OP_NOP, OP_HLT, OP_ERR: begin
        out_reg_dst = 31;
        out_reg_dst_status = REG_IS_UNUSED;
      end
      OP_STUR: begin
        out_reg_dst = 31;
        out_reg_dst_status = REG_IS_STUR;
      end
      OP_BL, OP_BLR: begin
        out_reg_dst = 30;
        out_reg_dst_status = REG_IS_USED;
      end
      default: begin
        out_reg_dst = in_insnbits[4:0];
        out_reg_dst_status = REG_IS_USED;
      end
    endcase

    //out_reg_src1
    if (opcode != OP_MOVK & opcode != OP_MOVZ & opcode != OP_ADR & opcode != OP_ADRP &
            opcode != OP_B & opcode != OP_B_COND & opcode != OP_BL & opcode != OP_NOP & opcode != OP_HLT
            & opcode != OP_CBZ & opcode != OP_CBNZ) begin
      out_reg_src1 = in_insnbits[9:5];
      out_reg_src1_status = REG_IS_USED;
    end else if (opcode == OP_BR | opcode == OP_BLR | opcode == OP_B_COND) begin
      out_reg_src1 = 31;
      out_reg_src1_status = REG_IS_PC;
    end else if (opcode == OP_CBZ | opcode == OP_CBNZ) begin
      out_reg_src1 = in_insnbits[4:0];
      out_reg_src1_status = REG_IS_USED;
    end else begin
      out_reg_src1 = 31;
      out_reg_src1_status = REG_IS_UNUSED;
    end


    //out_reg_src2
    if (opcode == OP_STUR) begin
      out_reg_src2 = in_insnbits[4:0];
      out_reg_src2_status = REG_IS_USED;
    end else if (
        opcode == OP_ADDS | opcode == OP_SUBS | opcode == OP_ORN |
        opcode == OP_ORR | opcode == OP_EOR | opcode == OP_ANDS |
        opcode == OP_CSEL | opcode == OP_CSINV | opcode == OP_CSINC | 
        opcode == OP_CSNEG
    ) begin
      out_reg_src2 = in_insnbits[20:16];
      out_reg_src2_status = REG_IS_USED;
    end else if(
        opcode == OP_LDUR | opcode == OP_STUR | opcode == OP_LDP |
        opcode == OP_STP | opcode == OP_MOVK | opcode == OP_MOVZ |
        opcode == OP_ADR | opcode == OP_ADRP | opcode == OP_SUB | 
        opcode == OP_ADD | opcode == OP_AND | opcode == OP_UBFM |
        opcode == OP_SBFM | opcode == OP_B | opcode == OP_B_COND |
        opcode == OP_BL
    ) begin
      out_reg_src2 = 31;
      out_reg_src2_status = REG_IS_IMMEDATE;
    end else begin
      out_reg_src2 = 31;
      out_reg_src2_status = REG_IS_UNUSED;
    end
  end
endmodule

module decide_alu (
    input opcode_t opcode,
    output fu_op_t out_reg_fu_op,
    output logic out_reg_mispredict,  // TODO(Nate): This could be done with just the opcode.
    output logic out_reg_is_branching
);
  // TODO op_cmp, op_tst def commented out in opcode_t
  always_comb begin
    casez (opcode)
      OP_LDP, OP_STP, OP_ADD, OP_ADDS: out_reg_fu_op = FU_OP_PLUS;
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
      OP_BR, OP_BLR: out_reg_fu_op = FU_OP_PASS_A;
      OP_B_COND: out_reg_fu_op = FU_OP_B_COND;
      OP_ADR, OP_ADRP: out_reg_fu_op = FU_OP_ADRX;
      default: out_reg_fu_op = FU_OP_PASS_A;  //plus for now i will add an error op later
    endcase

    // For branch predictor
    // out_reg_is_branching = OP_B | OP_BR | OP_BLR | OP_B_COND | OP_RET;
    casez (opcode)
      OP_BR, OP_BLR, OP_RET: begin
        out_reg_mispredict = 1;
        out_reg_is_branching = 0;
      end
      OP_B_COND: begin
        out_reg_mispredict = 0;
        out_reg_is_branching = 1;
      end
      default: begin
        out_reg_mispredict = 0;
        out_reg_is_branching = 0;
      end
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
    output logic out_op_uses_nzcv
);

  always_comb begin
    if (in_opcode == OP_B_COND | in_opcode == OP_CSINV | in_opcode == OP_CSINV | in_opcode == OP_CSNEG | in_opcode == OP_CSEL) begin
      out_op_uses_nzcv = 1;
    end else begin
      out_op_uses_nzcv = 0;
    end
  end
endmodule

module dispatch (
    // Inputs from core
    input logic in_rst,
    input logic in_clk,
    // input logic in_stall,
    // Inputs from fetch
    input fetch_interface in_fetch_sigs,
    // Outputs to regfile. This will (asynchronously) cause the regfile to send
    // signals to the ROB. We assume that this will occur within the same
    // cycle.
    output decode_interface out_reg_sigs
    // Outputs to be broadcasted.
    // output logic out_stalled
);


  opcode_t opcode;
  logic [`INSNBITS_SIZE-1:0] insnbits;

  decode_instruction op_decoder (
      .in_insnbits(insnbits),
      .out_opcode (opcode)
  );
  extract_immval imm_extractor (
      .opcode,
      .in_insnbits(insnbits),
      .out_reg_imm(out_reg_sigs.imm)
  );
  extract_reg reg_extractor (
      .opcode,
      .in_insnbits(insnbits),
      .out_reg_src1(out_reg_sigs.src1),
      .out_reg_src2(out_reg_sigs.src2),
      .out_reg_src1_status(out_reg_sigs.src1_status),
      .out_reg_src2_status(out_reg_sigs.src2_status),
      .out_reg_dst(out_reg_sigs.dst),
      .out_reg_dst_status(out_reg_sigs.dst_status)
  );

  find_cond_code cond_holds (
      .in_opcode(opcode),
      .in_insnbits(insnbits),
      .out_reg_cond_codes(out_reg_sigs.cond_codes)
  );

  uses_nzcv uses_nzcv (
      .in_opcode(opcode),
      .out_op_uses_nzcv(out_reg_sigs.uses_nzcv)
  );
  decide_alu alu_decider (
      .opcode,
      .out_reg_fu_op(out_reg_sigs.fu_op),
      .out_reg_mispredict(out_reg_sigs.mispredict),
      .out_reg_is_branching(out_reg_sigs.is_branching)
  );
  fu_decider fu (
      .opcode,
      .out_reg_fu_id(out_reg_sigs.fu_id)
  );
  sets_nzcv nzcv_setter (
      .opcode,
      .out_reg_set_nzcv(out_reg_sigs.set_nzcv)
  );


  logic fetch_done;
  always_comb begin
    out_reg_sigs.done = fetch_done;
  end

  always_ff @(posedge in_clk) begin
    if (in_rst) begin
      `DEBUG(("(dec) Resetting"));
      fetch_done <= 0;
    end else begin
      fetch_done <= in_fetch_sigs.done;
      if (in_fetch_sigs.done) begin
        insnbits <= in_fetch_sigs.insnbits;
        out_reg_sigs.pc <= in_fetch_sigs.pc;
      end
    end
  end

  // Print statements only in here
  always_ff @(posedge in_clk) begin
    if (in_fetch_sigs.done & ~in_rst) begin
      #1 
      `DEBUG(("(dec) Decoding: %b, done: %0b, rst: %0b", insnbits, out_reg_sigs.done, in_rst))
      `DEBUG(("(dec) \tfu_id: %s, opcode: %s, fu_op: %s",
          out_reg_sigs.fu_id.name, opcode.name, out_reg_sigs.fu_op.name));
      `DEBUG(("(dec) \tdst: X%0d, src1: X%0d, src2: X%0d, imm: %0d",
          out_reg_sigs.dst, out_reg_sigs.src1, out_reg_sigs.src2, out_reg_sigs.imm))
      `DEBUG(("(dec) \tdst: %s, src1: %s, src2: %s",
          out_reg_sigs.dst_status.name, out_reg_sigs.src1_status.name, out_reg_sigs.src2_status.name))
      `DEBUG(("(dec) \tsets_nzcv: %0b, uses_nzcv: %0b", out_reg_sigs.set_nzcv, out_reg_sigs.uses_nzcv))
      `DEBUG(("(dec) \tcond codes %s", out_reg_sigs.cond_codes.name))
    end
  end

endmodule : dispatch
`endif  // decode

