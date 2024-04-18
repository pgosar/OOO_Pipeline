// we separate imem and dmem to clock both of them and access at the same time.
//
//
module imem # (parameter int PAGESIZE)
  (
  input wire [$clog2(PAGESIZE) - 1:0] addr,
  input wire clk,
  output logic [31:0] data
  );
  // read-only instruction memory module.
  localparam bits_amt = PAGESIZE;
  localparam fname = "imem.txt";
  logic [7:0] mem [bits_amt];

  initial begin: mem_init
    $readmemb(fname, mem);
  end: mem_init

  always_ff @(posedge clk) begin: mem_access
    data <= {mem[addr], mem[addr + 1], mem[addr + 2], mem[addr + 3]};
  end: mem_access
  
endmodule: imem

module dmem # (parameter int PAGESIZE)
  (
  input wire [$clog2(PAGESIZE * 4) - 1:0] addr,
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
    if (w_enable) begin
      mem[addr] <= wval[63:56];
      mem[addr + 1] <= wval[55:48];
      mem[addr + 2] <= wval[47:40];
      mem[addr + 3] <= wval[39:32];
      mem[addr + 4] <= wval[31:24];
      mem[addr + 5] <= wval[23:16];
      mem[addr + 6] <= wval[15:8];
      mem[addr + 7] <= wval[7:0];
      data <= wval;
    end else begin
      data <= {mem[addr], mem[addr + 1], mem[addr + 2], mem[addr + 3], mem[addr + 4], mem[addr + 5], mem[addr + 6], mem[addr + 7]};
    end
  end: mem_access
  
endmodule: dmem

module mem_tb ();

  logic clk;
  initial begin
      clk <= 0;
      forever #5 clk = ~clk;
      //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
  end

  localparam PAGESIZE = 4096;
  logic [31:0] data;
  logic [63:0] ddata;
  logic [11:0] addr;
  logic [13:0] daddr;
  logic [63:0] wval;
  logic w_enable;
  imem #(PAGESIZE) dut (addr, clk, data);
  dmem #(PAGESIZE) odut (daddr, clk, w_enable, wval, ddata);
  initial begin: mem_init
    #10;
    for (int i = 0; i < 10; i++) begin
      addr = i;
      #10;
      $display("%b", data);
      #10;
    end
  addr = 232;
  #10;
  $display("***ENTRY*** %b", data);
  daddr = 305;
  w_enable = 0;
  #10;
  $display("DMEM test: %b", ddata);
  w_enable = 1;
  wval = 'hdeadbeef;
  #10;
  $display("DMEM test 2: %b", ddata);
  w_enable = 0;
  wval = 'h000000000;
  #10;
  $display("DMEM test 3: %b", ddata);
  daddr = 16375;
  w_enable = 1;
  wval = 'hfaceface;
  #10;
  $display("DMEM test 4: %x", ddata);
  $finish;
  
  $finish;
  end: mem_init
endmodule: mem_tb
