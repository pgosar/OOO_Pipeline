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

typedef enum logic [4:0] {
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
    CSEL_OP,    
    CSINV_OP,   
    CSINC_OP,   
    CSNEG_OP,   
    CBZ_OP,     
    CBNZ_OP,   
    ERROR_OP
} alu_op_t;


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


logic [2:0] currentstate, nextstate;
logic [63:0] result_reg;


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
        default: result_reg = 64'b0; // Default behavior, assuming no operation
    endcase
    res = result_reg;

    if(set_CC) begin
        N = ((res & 0x8000000000000000) != 0); // Assign value to N
        Z = (res == 0); // Assign value to Z
    end

end




endmodule

module ubfm_module(
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

module sbfm_module(
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



module regfile(
    input logic [4:0] read_reg1, // Input read register 1 index
    input logic [4:0] read_reg2, // Input read register 2 index
    input logic [4:0] write_reg, // Input write register index
    input logic [63:0] write_data, // Input data to be written
    input logic write_enable, // Write enable signal
    input logic reset,
    input logic clk,
    output logic [63:0] read_data1, // Output read data 1
    output logic [63:0] read_data2 // Output read data 2
);

logic [63:0] registers [63:0]; // Array of 32 64-bit registers
integer i;
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        // Reset all registers to zero
        for (i = 0; i < 32; i = i + 1) begin
            registers[i] <= 64'h0000000000000000;
        end
    end
    else begin
        // Read data from registers
        read_data1 <= registers[read_reg1];
        read_data2 <= registers[read_reg2];
        
        // Write data to register if write_enable is high
        if (write_enable) begin
            registers[write_reg] <= write_data;
        end
    end
end

endmodule
