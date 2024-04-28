`ifndef DATA_STRUCTURES
`define DATA_STRUCTURES

`define RS_SIZE 8
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
`define MISSPRED_SIZE 3

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

typedef enum logic [2:0] {
  S0,
  S1,
  S2,
  S3,
  S4,
  S5
} states_t;

typedef enum logic [5:0] {
  ALU_OP_MINUS,   // val_a - (val_b << valhw)
  ALU_OP_PLUS,    // val_a + (val_b << valhw)
  ALU_OP_ORN,     // val_a | (~val_b)
  ALU_OP_OR,      // val_a | val_b
  ALU_OP_EOR,     // val_a ^ val_b
  ALU_OP_AND,     // val_a & val_b
  ALU_OP_MOV,     // val_a | (val_b << valhw)
  ALU_OP_UBFM,
  ALU_OP_SBFM,
  ALU_OP_PASS_A,  // val_a
  ALU_OP_CSEL,    // EC: used for csel
  ALU_OP_CSINV,   // EC: used for csinv
  ALU_OP_CSINC,   // EC: used for csinc
  ALU_OP_CSNEG,   // EC: used for csneg
  ALU_OP_CBZ,     // EC: used for cbz
  ALU_OP_CBNZ     // EC: used for cbnz
} alu_op_t;

typedef enum logic [`OPCODE_SIZE-1:0] {
  OP_LDUR,
  OP_LDP,
  OP_STUR,
  OP_STP,
  OP_MOVK,
  OP_MOVZ,
  OP_ADR,
  OP_ADRP,
  // OP_CINC,  // alias of CSINC
  // OP_CINV,  // alias of CSINV
  // OP_CNEG,  // alias of SCNEG
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
  logic nzcv_valid;
  nzcv_t nzcv;
  alu_op_t op;
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
} rob_entry_t;

typedef struct packed {
  rs_entry_t [`RS_SIZE-1:0] rs;
  logic [`ROB_SIZE-1:0] rob;
} debug_info_t;

`endif  // data_structures
