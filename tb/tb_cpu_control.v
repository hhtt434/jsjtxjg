`timescale 1ns/1ps

module tb_cpu_control;
    reg clk;
    reg rst;
    integer errors;

    riscv_cpu #(
        .IMEM_INIT_FILE("tb/programs/control.hex"),
        .DMEM_INIT_FILE("")
    ) dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

    task check_reg;
        input [4:0]  index;
        input [31:0] expected;
        begin
            if (dut.regfile_i.regs[index] !== expected) begin
                $display("FAIL: x%0d expected=%h actual=%h", index, expected,
                         dut.regfile_i.regs[index]);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        errors = 0;
        repeat (2) @(posedge clk);
        rst = 0;
        repeat (70) @(posedge clk);
        #1;

        check_reg(5'd1, 32'd1);
        check_reg(5'd2, 32'd2);
        check_reg(5'd3, 32'd3);
        check_reg(5'd4, 32'd0);
        check_reg(5'd5, 32'd5);
        check_reg(5'd6, 32'd6);
        check_reg(5'd7, 32'd44);
        check_reg(5'd8, 32'd0);

        if (errors == 0) begin
            $display("TEST PASS: tb_cpu_control");
        end else begin
            $display("TEST FAIL: tb_cpu_control (%0d errors)", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule

