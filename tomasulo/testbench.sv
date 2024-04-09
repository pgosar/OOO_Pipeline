module ubfm_testbench;

    // Inputs
    logic clk;
    logic [63:0] i_val_a;
    logic [5:0] imms;
    logic [5:0] immr;
    logic rst;

    // Outputs
    logic [63:0] res;

    // Instantiate UBFM module
    ubfm_module dut (
        .i_val_a(i_val_a),
        .clk(clk),
        .rst(rst),
        .imms(imms),
        .immr(immr),
        .res(res)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    initial begin
        $dumpfile("ubfm.vcd"); 
        $dumpvars(0, ubfm_testbench); 

        // Reset
        @(posedge clk);
        i_val_a = 0;
        imms = 0;
        immr = 0;

        // Test case 1
        i_val_a = 64'hFF; 
        imms = 3; 
        immr = 1;
        @(posedge clk);
        if (res !== 64'h7) begin
            $display("Test case 1 failed. Expected: 64'h7, Got: %h", res);
            $finish;
        end else begin
            $display("Test case 1 passed.");
        end


        $finish;
    end

endmodule
