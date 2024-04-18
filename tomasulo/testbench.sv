`include "data_structures.sv"

// module ubfm_testbench;

//     // Inputs
//     logic clk;
//     logic [63:0] i_val_a;
//     logic [5:0] imms;
//     logic [5:0] immr;
//     logic rst;

//     // Outputs
//     logic [63:0] res;

//     // Instantiate UBFM module
//     ubfm_module dut (
//         .i_val_a(i_val_a),
//         .clk(clk),
//         .rst(rst),
//         .imms(imms),
//         .immr(immr),
//         .res(res)
//     );

//     initial begin
//         clk = 0;
//         forever #5 clk = ~clk;
//     end

//     initial begin
//         $dumpfile("ubfm.vcd");
//         $dumpvars(0, ubfm_testbench);

//         // Reset
//         @(posedge clk);
//         i_val_a = 0;
//         imms = 0;
//         immr = 0;

//         // Test case 1
//         i_val_a = 64'hFF;
//         imms = 3;
//         immr = 1;
//         @(posedge clk);
//         if (res !== 64'h7) begin
//             $display("Test case 1 failed. Expected: 64'h7, Got: %h", res);
//             $finish;
//         end else begin
//             $display("Test case 1 passed.");
//         end


//         $finish;
//     end

// endmodule

module rob_module_tb;
  // clock
  logic in_clk;
  logic in_rst;
  // from FU
  logic in_fu_done;
  logic [`GPR_SIZE-1:0] in_fu_value;
  logic [`ROB_IDX_SIZE-1:0] in_fu_rob_idx;
  logic in_fu_set_nzcv;
  nzcv_t in_fu_nzcv;
  logic in_is_mispred;
  // from dispatch
  logic [`GPR_IDX_SIZE-1:0] in_gpr_idx;
  logic in_is_op;
  // for regfile
  logic out_regfile_should_commit;
  // for dispatch
  logic [`ROB_IDX_SIZE-1:0] out_next_rob_idx;
  logic [`ROB_IDX_SIZE-1:0] out_delete_mispred_idx [`MISSPRED_SIZE];

endmodule

module regfile_module_tb;
  // clock
  logic in_clk;
  logic in_rst;
  logic in_rob_should_commit;
  logic [`GPR_SIZE-1:0] in_rob_commit_value;
  logic [`GPR_IDX_SIZE-1:0] in_rob_regfile_index;
  // Inputs from Dispatch
  logic in_dispatch_should_read;
  logic [`GPR_IDX_SIZE-1:0] in_d_op1;
  logic [`GPR_IDX_SIZE-1:0] in_d_op2;
  // Outputs for Dispatch
  logic [`GPR_SIZE-1:0] out_d_op1;
  logic [`GPR_SIZE-1:0] out_d_op2;

endmodule

module reservation_station_module_tb;
  logic in_rst;
  logic in_clk;
  // from dispatch
  logic in_op1_valid;
  logic in_op2_valid;
  logic [`ROB_IDX_SIZE-1:0] in_op1_rob_index;
  logic [`ROB_IDX_SIZE-1:0] in_op2_rob_index;
  logic [`GPR_SIZE-1:0] in_op1_value;
  logic [`GPR_SIZE-1:0] in_op2_value;
  logic [`GPR_IDX_SIZE-1:0] in_dst;
  logic in_set_nzcv;
  // from ROB
  logic in_rob_broadcast_done;
  logic [`ROB_IDX_SIZE-1:0] in_rob_broadcast_index;
  logic [`GPR_SIZE-1:0] in_rob_broadcast_val;
  logic in_rob_is_mispred;
  // from FU
  logic in_fu_ready;
  logic in_fu_done;
  // for FU
  logic [`RS_IDX_SIZE:0] out_ready_index;

endmodule


module ArithmeticExecuteUnit_tb;
    logic clk;
    logic rst;
    logic start;
    alu_op_t ALUop;
    logic [63:0] alu_vala;
    logic [63:0] alu_valb;
    logic [5:0] alu_val_hw;

    logic [63:0] res;
    logic done;
    logic set_CC;
    cond_t cond;
    logic cond_val;
    nzcv_t nzcv;
    nzcv_t in_nzcv;

    ArithmeticExecuteUnit dut (
        .in_alu_op(ALUop),
        .in_val_a(alu_vala),
        .in_val_b(alu_valb),
        .in_alu_val_hw(alu_val_hw),
        .in_set_CC(set_CC),
        .in_cond(cond),
        .in_prev_nzcv(in_nzcv),
        .out_cond_val(cond_val),
        .out_res(res),
        .out_nzcv(nzcv),
        .out_done(done)
    );

    initial begin
        clk = 0;
        for (int i = 0; i < 250; i+=1)
            #5 clk = ~clk; // 100 MHz clock
    end

    initial begin
        $dumpfile("ArithmeticExecuteUnit.vcd"); // Dump waveform to VCD file
        $dumpvars(0, ArithmeticExecuteUnit_tb); // Dump all signals

        // Reset
        rst = 1;
        #10;
        rst = 0;
        #10;

        // Test case 1 - posedge clock
        @(negedge clk);
        start = 1;
        ALUop = ALU_OP_PLUS;
        alu_vala = 64'h0000000000000001;
        alu_valb = 64'h0000000000000001;
        alu_val_hw = 6'h0;
        set_CC = 1;
        cond_val = 0;
        cond = C_EQ;
        #10
        start = 0;
        #10
        if (res != 64'h0000000000000002) begin
            $display("Test case 1 failed. Expected: 64'h0000000000000002, Got: %h", res);
            $finish;
        end else begin
            $display("Test case 1 passed.");
        end

        if(nzcv != 0) begin
            $display("Test nzcv failed. Expected: 0, Got: %h", nzcv);
            $finish;
        end else begin
            $display("Test nzcv passed.");
        end
        $finish;
    end

endmodule
