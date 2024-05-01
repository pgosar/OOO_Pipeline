`ifndef DATA_STRUCTURES
`define DATA_STRUCTURES

`define RS_SIZE 16
`define RS_IDX_SIZE $clog2(`RS_SIZE)
`define ROB_SIZE ((`RS_SIZE)*2+2)
`define ROB_IDX_SIZE $clog2(`ROB_SIZE)
`define GPR_COUNT 32
`define INSNBITS_SIZE 32
`define GPR_IDX_SIZE $clog2(`GPR_COUNT)
`define GPR_SIZE 64 //IDK WHAT ITS SUPPOSED TO DO
`define IMMEDIATE_SIZE 64
`define NZCV_SIZE 4
`define COND_SIZE 4
`define NUM_OPCODES 43
`define OPCODE_SIZE $clog2(`NUM_OPCODES)
`define LS_DELAY 3

`define DEBUG(ARGS) \
`ifdef DEBUG_PRINT \
    $display ARGS; \
`endif

`define ASSERT(ARGS) \
  if(ARGS == 0) $stop; \
  $finish;

typedef struct packed {logic src2_sel;} d_ctl_sigs_t;

typedef struct packed {
  logic valb_sel;
  logic set_CC;
} x_ctl_sigs_t;

typedef struct packed {
  logic dmem_read;
  logic dmem_write;
} m_ctl_sigs_t;

typedef struct packed {
  logic dst_sel;
  logic wval_sel;
  logic w_enable;
} w_ctl_sigs_t;

typedef enum logic [5:0] {
  FU_OP_MINUS,   // val_a - (val_b << valhw)
  FU_OP_PLUS,    // val_a + (val_b << valhw)
  FU_OP_ORN,     // val_a | (~val_b)
  FU_OP_OR,      // val_a | val_b
  FU_OP_EOR,     // val_a ^ val_b
  FU_OP_AND,     // val_a & val_b
  FU_OP_MOV,     // val_a | (val_b << valhw)
  FU_OP_UBFM,
  FU_OP_SBFM,
  FU_OP_PASS_A,  // val_a
  FU_OP_CSEL,    // EC: used for csel
  FU_OP_CSINV,   // EC: used for csinv
  FU_OP_CSINC,   // EC: used for csinc
  FU_OP_CSNEG,   // EC: used for csneg
  FU_OP_CBZ,     // EC: used for cbz
  FU_OP_CBNZ,    // EC: used for cbnz
  FU_OP_LDUR,
  FU_OP_STUR,
  FU_OP_B_COND,
  FU_OP_NOP,
  FU_OP_ADRX
} fu_op_t;

typedef enum logic [`OPCODE_SIZE-1:0] {
  OP_LDUR,
  OP_LDP,
  OP_STUR,
  OP_STP,
  OP_MOVK,
  OP_MOVZ,
  OP_ADR,
  OP_ADRP,
  OP_CINC,  // alias of CSINC
  OP_CINV,  // alias of CSINV
  OP_CNEG,  // alias of SCNEG
  OP_CSEL,
  // OP_CSET,  // alias of ??
  // OP_CSETM, // alias of ??
  OP_CSINC,
  OP_CSINV,
  OP_CSNEG,
  OP_ADD,
  OP_ADDS,
  OP_SUB,
  OP_SUBS,
  // OP_CMP, // alias of SUBS
  OP_ORN,  // aliased by MVN
  OP_ORR,
  OP_EOR,
  OP_AND,
  OP_ANDS,
  // OP_TST, // alias of ANDS
  // OP_LSL, // alias of UBFM
  // OP_LSR, // alias of UBFM
  OP_SBFM,
  OP_UBFM,
  // OP_ASR, // alias of SBFM
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

typedef enum logic [`INSNBITS_SIZE-1:0] {
  INSNBITS_STUR = 32'b1111_1000_0000_0000_0000_0000_0000_0000,
  INSNBITS_LDUR = 32'b1111_1000_0100_0000_0000_0000_0000_0000,
  INSNBITS_LDP = 32'b1010_1000_1100_0000_0000_0000_0000_0000,
  INSNBITS_STP = 32'b1010_1001_0000_0000_0000_0000_0000_0000,
  INSNBITS_MOVZ = 32'b1101_0010_1000_0000_0000_0000_0000_0000,
  INSNBITS_MOVK = 32'b1111_0010_1000_0000_0000_0000_0000_0000,
  INSNBITS_ADR = 32'b0001_0000_0000_0000_0000_0000_0000_0000,
  INSNBITS_ADRP = 32'b1001_0000_0000_0000_0000_0000_0000_0000,
  INSNBITS_CSINC = 32'b1001_1010_1000_0000_0000_0100_0000_0000,
  INSNBITS_CSINV = 32'b1101_1010_1000_0000_0000_0000_0000_0000,
  INSNBITS_CSNEG = 32'b1101_1010_1000_0000_0000_0100_0000_0000,
  INSNBITS_CSEL = 32'b1001_1010_1000_0000_0000_0000_0000_0000,
  INSNBITS_ADD = 32'b1001_0001_0000_0000_0000_0000_0000_0000,
  INSNBITS_ADDS = 32'b1010_1011_0000_0000_0000_0000_0000_0000,
  INSNBITS_SUB = 32'b1101_0001_0000_0000_0000_0000_0000_0000,
  INSNBITS_SUBS = 32'b1110_1011_0000_0000_0000_0000_0000_0000,
  INSNBITS_ORN = 32'b1010_1010_0010_0000_0000_0000_0000_0000,
  INSNBITS_ORR = 32'b1010_1010_0000_0000_0000_0000_0000_0000,
  INSNBITS_EOR = 32'b1100_1010_0000_0000_0000_0000_0000_0000,
  INSNBITS_AND = 32'b1001_0010_0000_0000_0000_0000_0000_0000,
  INSNBITS_ANDS = 32'b1110_1010_0000_0000_0000_0000_0000_0000,
  INSNBITS_UBFM = 32'b1101_0011_0100_0000_0000_0000_0000_0000,
  INSNBITS_SBFM = 32'b1001_0011_0100_0000_0000_0000_0000_0000,
  INSNBITS_B = 32'b0001_0100_0000_0000_0000_0000_0000_0000,
  INSNBITS_B_COND = 32'b0101_0100_0000_0000_0000_0000_0000_0000,
  INSNBITS_BL = 32'b1001_0100_0000_0000_0000_0000_0000_0000,
  INSNBITS_BLR = 32'b1101_0110_0011_1111_0000_0000_0000_0000,
  INSNBITS_BR = 32'b1101_0110_0001_1111_0000_0000_0000_0000,
  INSNBITS_CBNZ = 32'b1011_0101_0000_0000_0000_0000_0000_0000,
  INSNBITS_CBZ = 32'b1011_0100_0000_0000_0000_0000_0000_0000,
  INSNBITS_RET = 32'b1101_0110_0101_1111_0000_0000_0000_0000,
  INSNBITS_NOP = 32'b1101_0101_0000_0011_0010_0000_0001_1111,
  INSNBITS_HLT = 32'b1101_0100_0100_0000_0000_0000_0000_0000
} insnbits_t;

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

typedef enum logic [2:0] {
  REG_IS_UNUSED,
  REG_IS_USED,
  REG_IS_XZR,
  REG_IS_SP,
  REG_IS_STUR
} reg_status_t;

typedef enum logic {
  FU_ALU,  // Arithmetic & Logic Unit
  FU_LS    // Load / Store Unit
} fu_t;

typedef struct packed {
  logic valid;
  logic [`ROB_IDX_SIZE-1:0] rob_index;
  logic [`GPR_SIZE-1:0] value;
} rs_op_t;

typedef struct packed {
  logic N;
  logic Z;
  logic C;
  logic V;
} nzcv_t;

typedef struct packed {
  rs_op_t op1;  // TODO(Nate): lmao this CANNOT be called op1 & op2 anymore
  rs_op_t op2;
  logic [`ROB_IDX_SIZE-1:0] dst_rob_index;
  logic entry_valid;
  logic [`ROB_IDX_SIZE-1:0] nzcv_rob_index;
  logic set_nzcv;
  logic uses_nczv;
  logic nzcv_valid;
  nzcv_t nzcv;
  fu_op_t op;
} rs_entry_t;

typedef struct packed {
  logic valid;
  logic [`ROB_IDX_SIZE-1:0] rob_index;
  logic [`GPR_SIZE-1:0] value;
  logic [`GPR_IDX_SIZE-1:0] gpr_index;
} gpr_entry_t;

typedef struct packed {
  logic [`GPR_IDX_SIZE-1:0] gpr_index;
  logic valid;  // True iff this contains a value.
  logic [`GPR_SIZE-1:0] value;
  logic set_nzcv;
  nzcv_t nzcv;
  logic mispredict;
  logic bcond;
} rob_entry_t;

typedef struct packed {
  rs_entry_t [`RS_SIZE-1:0] rs;
  logic [`ROB_SIZE-1:0] rob;
} debug_info_t;

typedef enum logic {
  LOAD,
  STORE
} ls_op_t;

interface fetch_interface ();
  logic done;
  logic [`INSNBITS_SIZE-1:0] insnbits;
  logic [`GPR_SIZE-1:0] pc;
endinterface

interface decode_interface ();
  logic done;
  logic set_nzcv;
  logic use_imm;
  logic [`IMMEDIATE_SIZE-1:0] imm;
  logic [`GPR_IDX_SIZE-1:0] src1;
  reg_status_t src1_status;
  logic [`GPR_IDX_SIZE-1:0] src2;
  reg_status_t src2_status;
  fu_t fu_id;
  fu_op_t fu_op;
  logic [`GPR_IDX_SIZE-1:0] dst;
  reg_status_t dst_status;
  cond_t cond_codes;
  logic uses_nzcv;
  logic mispredict; // NOTE(Nate): This is used to indicate that a branch is always mispredicted. Honestly, could be part of the   logic bcond,
  logic [`GPR_SIZE-1:0] pc;
endinterface

interface reg_interface ();
  logic done;
  logic src1_valid;
  logic src2_valid;
  logic nzcv_valid;
  logic [`GPR_IDX_SIZE-1:0] dst;
  logic [`ROB_IDX_SIZE-1:0] src1_rob_index;
  logic [`ROB_IDX_SIZE-1:0] src2_rob_index;
  logic [`ROB_IDX_SIZE-1:0] nzcv_rob_index;
  logic [`GPR_SIZE-1:0] src1_value;
  logic [`GPR_SIZE-1:0] src2_value;
  logic uses_nzcv;
  nzcv_t nzcv;
  logic set_nzcv;
  fu_t fu_id;
  logic mispredict;
  logic bcond;
  // Outputs for FU (rob)
  fu_op_t fu_op;
  cond_t cond_codes;
endinterface

interface rob_commit_interface ();
  logic done;
  logic set_nzcv;
  nzcv_t nzcv;
  logic [`GPR_SIZE-1:0] value;
  logic [`GPR_IDX_SIZE-1:0] reg_index;
  logic [`ROB_IDX_SIZE-1:0] rob_index;
endinterface

interface rob_broadcast_interface ();
  logic done;
  logic [`ROB_IDX_SIZE-1:0] index;
  logic [`GPR_SIZE-1:0] value;
  logic set_nzcv;
  nzcv_t nzcv;
endinterface

interface rob_interface ();
integer stur_counter;
  cond_t cond_codes;
  logic done;
  fu_t fu_id;
  fu_op_t fu_op;
  logic val_a_valid;
  logic val_b_valid;
  logic nzcv_valid;
  logic [`GPR_SIZE-1:0] val_a_value;
  logic [`GPR_SIZE-1:0] val_b_value;
  logic uses_nzcv;
  nzcv_t nzcv;
  logic set_nzcv;
  logic [`ROB_IDX_SIZE-1:0] val_a_rob_index;
  logic [`ROB_IDX_SIZE-1:0] val_b_rob_index;
  logic [`ROB_IDX_SIZE-1:0] dst_rob_index;
  logic [`ROB_IDX_SIZE-1:0] nzcv_rob_index;
  logic commit_done;
endinterface

interface rs_interface ();
  logic start;
  fu_op_t fu_op;
  logic [`GPR_SIZE-1:0] val_a;
  logic [`GPR_SIZE-1:0] val_b;
  logic [`ROB_IDX_SIZE-1:0] dst_rob_index;
endinterface

interface rs_interface_alu_ext ();
  logic  set_nzcv;
  nzcv_t nzcv;
  cond_t cond_codes;
endinterface

interface fu_interface ();
  logic done;
  logic [`ROB_IDX_SIZE-1:0] dst_rob_index;
  logic [`GPR_SIZE-1:0] value;
  fu_op_t fu_op;
endinterface

interface fu_interface_alu_ext ();
  logic  set_nzcv;
  nzcv_t nzcv;
  logic  is_mispred;
  logic  condition;
endinterface

`endif  // data_structures
