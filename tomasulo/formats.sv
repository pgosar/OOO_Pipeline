typedef struct packed {
  logic [10:0] op;
  logic [8:0]  simm9;
  logic [1:0]  _;
  logic [4:0]  rn;
  logic [4:0]  rt;
} m_format;

typedef struct packed {
  logic [9:0] op;
  logic [6:0] simm7;
  logic [4:0] rt2;
  logic [4:0] rn;
  logic [4:0] rt;
} m2_format;

typedef struct packed {
  logic [8:0]  op;
  logic [1:0]  hw;
  logic [15:0] imm16;
  logic [4:0]  rd;
} i1_format;

typedef struct packed {
  logic [7:0]  op;
  logic [18:0] simm19;
  logic [4:0]  rd;
} i2_format;

typedef struct packed {
  logic [7:0] op;
  logic [2:0] _1;
  logic [4:0] rm;
  logic [3:0] cond;
  logic [1:0] _2;
  logic [4:0] rn;
  logic [4:0] rd;
} rc_format;

typedef struct packed {
  logic [7:0] op;
  logic [2:0] _1;
  logic [4:0] rm;
  logic [5:0] _2;
  logic [4:0] rn;
  logic [4:0] rd;
} rr_format;

typedef struct packed {
  logic [8:0] op;
  logic _;
  logic [11:0] imm12;
  logic [4:0] rn;
  logic [4:0] rd;
} ri_format;

typedef struct packed {
  logic [5:0]  op;
  logic [25:0] simm26;
} b1_format;

typedef struct packed {
  logic [7:0] op;
  logic [18:0] simm19;
  logic _;
  logic [3:0] cond;
} b2_format;

typedef struct packed {
  logic [10:0] op;
  logic [10:0] _1;
  logic [4:0]  rn;
  logic [4:0]  _2;
} b3_format;

typedef struct packed {
  logic [10:0] op;
  logic [20:0] _;
} s_format;

typedef union packed {
  m_format  m;
  m2_format m2;
  i1_format i1;
  i2_format i2;
  rc_format rc;
  rr_format rr;
  ri_format ri;
  b1_format b1;
  b2_format b2;
  b3_format b3;
  s_format  s;
} instr;
