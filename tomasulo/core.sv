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



module tomasulo_execute (
    input clk,                 // Clock signal
    input reset,               // Reset signal
    input [5:0] opcode,        // Operation code are we changing it to ALUop like se
    input [4:0] src1,           // Source register 1
    input [4:0] src2,           // Source register 2
    input [6:0] imm,           // Immediate value
    input [1:0] dst_res_station,       // Destination reservation station
    input ready_or_not,             // Reservation station busy signal
    input [1:0] dest,          // Destination register
    input [31:0] result_in,    // Input result from functional unit
    output reg busy,           // Execute stage busy signal
    output reg [31:0] result_out, // Output result
    output reg write_enable        // Write enable for reservation station
);

// Define states for the execution stage
parameter S_IDLE = 2'b00;
parameter S_EXECUTING = 2'b01;

// Internal signals
reg [1:0] state;
reg [63:0] result;

always @ (posedge clk or posedge reset) begin
    if (reset) begin
        state <= S_IDLE;
        result <= 32'b0;
        busy <= 1'b0;
    end
    else begin
        case (state)
            S_IDLE: begin
                // Check if reservation station is available
                if (!ready_or_not) begin
                    // Start execution
                    state <= S_EXECUTING;
                    busy <= 1'b1;
                    // Perform operation based on opcode
                    
                end
            end
            S_EXECUTING: begin
                // Wait for functional unit result
                
            end
        endcase
    end
end

endmodule


module regfile(
    input wire [4:0] read_reg1, // Input read register 1 index
    input wire [4:0] read_reg2, // Input read register 2 index
    input wire [4:0] write_reg, // Input write register index
    input wire [31:0] write_data, // Input data to be written
    input wire write_enable, // Write enable signal
    input wire reset,
    input wire clk,
    output reg [31:0] read_data1, // Output read data 1
    output reg [31:0] read_data2 // Output read data 2
);

reg [31:0] registers [31:0]; // Array of 32 32-bit registers
integer i;
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        // Reset all registers to zero
        for (i = 0; i < 32; i = i + 1) begin
            registers[i] <= 32'h00000000;
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
