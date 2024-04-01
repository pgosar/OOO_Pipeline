typedef enum logic[2:0] {
    S0 = 3'b000,
    S1 = 3'b001,
    S2 = 3'b010,
    S3 = 3'b011,
    S4 = 3'b100,
    S5 = 3'b101
} states_t;

typedef enum logic[5:0] {
    ldur   = 6'b000000, 
    ldp    = 6'b000001, 
    stur   = 6'b000010, 
    stp    = 6'b000011, 
    movk   = 6'b000100,
    movz   = 6'b000101,
    adr    = 6'b000110,
    adrp   = 6'b000111,
    cinc   = 6'b001000,
    cinv   = 6'b001001,
    csneg  = 6'b001010,
    csel   = 6'b001011,
    cset   = 6'b001100,
    csetiv = 6'b001101,
    csinc  = 6'b001110,
    csinv  = 6'b001111,
    cneg   = 6'b010000,
    add    = 6'b010001,
    adds   = 6'b010010,
    sub    = 6'b010011,
    subs   = 6'b010100,
    cmp    = 6'b010101,
    mvn    = 6'b010110,
    orr    = 6'b010111,
    eor    = 6'b011000,
    andOp  = 6'b011001, //have to do it this way because and is built in
    ands   = 6'b011010,
    tst    = 6'b011011,
    lsl    = 6'b011100,
    lsr    = 6'b011101,
    sbfm   = 6'b011110,
    ubfm   = 6'b011111,
    asr    = 6'b100000,
    b      = 6'b100001,
    br     = 6'b100010,
    b_cond = 6'b100011, //verilog doesnt like b.cond
    bl     = 6'b100100,
    blr    = 6'b100101,
    cbnz   = 6'b100110,
    cbz    = 6'b100111,
    ret    = 6'b101000,
    nop    = 6'b101001,
    hlt    = 6'b101010   
} opcodes;

module instruction_parser(
    input logic [31:0] insnbits,
    input logic clk_in,
    output logic [5:0] opcode
);



assign top11 = insnbits[31:21];

always_ff @(posedge clk_in) begin : main_controller
    case(top11)
        11'b11111000010: begin
            opcode = ldur;
        end
        11'b1010100011x: begin
            opcode = ldp;
        end
        11'b11111000000: begin
            opcode = stur;
        end
        11'b1010100010x: begin
            opcode = stp;
        end
        11'b111100101xx: begin
            opcode = movk;
        end
        11'b0xx10000xxx: begin
            opcode = adr;
        end
        11'b1xx10000xxx: begin  
            opcode = adrp;
        end
        11'b10011010100: begin
            opcode = cinc; //cset and csel and csinc
        end
        11'b11011010100: begin
            opcode = cinv; //also for csneg, cneg and csetm and csinv
        end
        11'b1001000100x: begin
            opcode = add;
        end
        11'b10101011000: begin
            opcode = adds;
        end
        11'b1101000100x: begin
            opcode = sub;
        end
        11'b11101011000: begin
            opcode = subs; //cmp
        end
        11'b10101010001: begin
            opcode = mvn;
        end
        11'b10101010000: begin
            opcode = orr;
        end
        11'b11001010000: begin
            opcode = eor;
        end
        11'b1001001000x: begin
            opcode = andOp; //cant have and its a built in module
        end
        11'b11101010000: begin
            opcode = ands; //also for tst
        end
        11'b110100110xx: begin
            opcode = ubfm; //lsl and lsr has an extra 1 in its opcode  what do we do about that
        end
        11'b100100111xx: begin
            opcode = sbfm;
        end
        11'b1001001101x: begin
            opcode = asr;
        end
        11'b000101xxxxx: begin
            opcode = b;
        end
        11'b11010110000: begin
            opcode = br;
        end
        11'b01010100xxx: begin
            opcode = b_cond; //verilog doesnt like b.cond
        end
        11'b100101xxxxx: begin
            opcode = bl;
        end
        11'b11010110001: begin
            opcode = blr;
        end
        11'b10110101xxx: begin
            opcode = cbnz;
        end
        11'b10110100xxx: begin
            opcode = cbz;
        end
        11'b11010110010: begin
            opcode = ret;
        end
        11'b11010101000: begin
            opcode = nop;
        end
        11'b11010100010: begin
            opcode = hlt;
        end
        default: begin
            opcode = 6'b0; 
        end
    endcase
end

endmodule
