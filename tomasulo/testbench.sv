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


module ArithmeticExecuteUnit_tb;

    logic clk;
    logic rst;
    logic start;
    logic [4:0] ALUop;
    logic [63:0] alu_vala;
    logic [63:0] alu_valb;
    logic [5:0] alu_valhw;

\    logic [63:0] res;
    logic done;

    ArithmeticExecuteUnit dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .ALUop(ALUop),
        .alu_vala(alu_vala),
        .alu_valb(alu_valb),
        .alu_valhw(alu_valhw),
        .res(res),
        .done(done)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock
    end

    initial begin
        $dumpfile("ArithmeticExecuteUnit.vcd"); // Dump waveform to VCD file
        $dumpvars(0, ArithmeticExecuteUnit_tb); // Dump all signals

        // Reset
        // rst = 1;
        // #10;
        rst = 0;
        // #10;

        // Test case 1 - posedge clock
        @(posedge clk);
        start = 1;
        ALUop = 3'b000; 
        alu_vala = 64'h0000000000000001; 
        alu_valb = 64'h0000000000000001; 
        alu_valhw = 6'h00;
        @(posedge clk);
        start = 0;
        @(posedge clk);
        if (res !== 64'h0000000000000002) begin
            $display("Test case 1 failed. Expected: 64'h0000000000000002, Got: %h", res);
            $finish;
        end else begin
            $display("Test case 1 passed.");
        end

        // Test case 2 - negedge clock
        // @(posedge clk);
        // start = 1;
        // ALUop = 3'b001; // MINUS_OP
        // alu_vala = 64'hFFFFFFFFFFFFFFFF; // input value
        // alu_valb = 64'h0000000000000001; // input value
        // alu_valhw = 6'h00;
        // @(posedge clk);
        // start = 0;
        // @(posedge clk);
        // if (res !== 64'hFFFFFFFFFFFFFFFF) begin
        //     $display("Test case 2 failed. Expected: 64'hFFFFFFFFFFFFFFFF, Got: %h", res);
        //     $finish;
        // end else begin
        //     $display("Test case 2 passed.");
        // end

        // Add more test cases here...

        $finish;
    end

endmodule
