// we separate imem and dmem to clock both of them and access at the same time.
//
// Note: the imem is combinational to make accessing memory super easy.
//
module imem # (parameter int PAGESIZE)
  (
  input wire [63:0] in_addr,
  output logic [31:0] data
  );
  // read-only instruction memory module.
  localparam bits_amt = PAGESIZE;
  localparam fname = "imem.txt";
  logic [7:0] mem [bits_amt];
  logic [$clog2(PAGESIZE) - 1:0] addr;

  initial begin: mem_init
    $readmemb(fname, mem);
  end: mem_init

  always_comb begin: mem_access
    addr = in_addr[$clog2(PAGESIZE) - 1:0];
    data = {mem[addr + 3], mem[addr + 2], mem[addr + 1], mem[addr]};
  end: mem_access
  
endmodule: imem

module dmem # (parameter int PAGESIZE)
  (
  input wire [63:0] in_addr,
  input wire clk,
  input wire w_enable,
  input wire [63:0] wval,
  output logic [63:0] data
  );
  // read-only instruction memory module.
  localparam bits_amt = PAGESIZE * 4; // 64 bit access
  localparam fname = "dmem.txt";
  logic [7:0] mem [bits_amt];

  initial begin: mem_init
    $readmemb(fname, mem);
  end: mem_init

  always_ff @(posedge clk) begin: mem_access
    localparam addr = in_addr[$clog2(PAGESIZE * 4) - 1:0];
    if (w_enable) begin
      mem[addr + 7] <= wval[63:56];
      mem[addr + 6] <= wval[55:48];
      mem[addr + 5] <= wval[47:40];
      mem[addr + 4] <= wval[39:32];
      mem[addr + 3] <= wval[31:24];
      mem[addr + 2] <= wval[23:16];
      mem[addr + 1] <= wval[15:8];
      mem[addr] <= wval[7:0];
      data <= wval;
    end else begin
      data <= {mem[addr + 7], mem[addr + 6], mem[addr + 5], mem[addr + 4], mem[addr + 3], mem[addr + 2], mem[addr + 1], mem[addr]};
    end
  end: mem_access
  
endmodule: dmem

module fetch # (parameter int PAGESIZE)
  (
   input wire clk,
   output logic [31:0] insnbits
  );
  // steps: 
  // 1. select PC (?) assuming no mispredictions for now
  // 2. access IMEM with correct PC
  // 3. potentially fix instruction aliases?
  // 4. predict new PC
  // 5. any status updates needed

  // select PC: no-op as of now

  // access IMEM
  logic [31:0] data;
  // PC is an internal register to fetch.
  logic [63:0] PC_load [0:0]; // to make verilog see it as a memory
  logic [63:0] PC;

  initial begin: init_PC
    $readmemb("entry.txt", PC_load);
    PC = PC_load[0];
  end: init_PC

  imem #(PAGESIZE) mem(PC, data);

  always_ff @(posedge clk) begin: fetch_logic
    // fix instruction alias?
    // predict new PC?
    // status updates?
    insnbits <= data;
    PC <= PC + 4;
  end: fetch_logic
endmodule

module fetch_tb();
  logic clk;
  initial begin
      clk <= 0;
      forever #5 clk = ~clk;
      //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
  end
  
  logic [63:0] addr;
  logic [63:0] test [0:0];
  logic [31:0] insnbits;
  fetch # (4096) dut(clk, insnbits);
  initial begin: tb
    #10;
    while (insnbits != 0) begin
      $display("%b", insnbits);
      #10;
    end
    $finish;
  end: tb

endmodule

//module mem_tb ();
//  logic clk;
//  initial begin
//      clk <= 0;
//      forever #5 clk = ~clk;
//      //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
//  end
//
//  localparam PAGESIZE = 4096;
//  logic [31:0] data;
//  logic [63:0] ddata;
//  logic [11:0] addr;
//  logic [13:0] daddr;
//  logic [63:0] wval;
//  logic w_enable;
//  fetch dut()
//  dmem #(PAGESIZE) odut (daddr, clk, w_enable, wval, ddata);
//  initial begin: mem_init
//    #10;
//    for (int i = 0; i < 10; i++) begin
//      addr = i;
//      #10;
//      $display("%b", data);
//      #10;
//    end
//  addr = 232;
//  #10;
//  $display("***ENTRY*** %b", data);
//  daddr = 305;
//  w_enable = 0;
//  #10;
//  $display("DMEM test: %b", ddata);
//  w_enable = 1;
//  wval = 'hdeadbeef;
//  #10;
//  $display("DMEM test 2: %b", ddata);
//  w_enable = 0;
//  wval = 'h000000000;
//  #10;
//  $display("DMEM test 3: %b", ddata);
//  daddr = 16375;
//  w_enable = 1;
//  wval = 'hfaceface;
//  #10;
//  $display("DMEM test 4: %x", ddata);
//  $finish;
//  
//  $finish;
//  end: mem_init
//endmodule: mem_tb
