`timescale 1ns/1ps

module tb_cpu_base;
    reg clk;
    reg rst;
    integer errors;

    riscv_cpu #(
        .IMEM_INIT_FILE("tb/programs/base.hex"),
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
        repeat (100) @(posedge clk);
        #1;

        check_reg(5'd1,  32'd10);
        check_reg(5'd2,  32'd20);
        check_reg(5'd3,  32'd30);
        check_reg(5'd4,  32'd0);
        check_reg(5'd5,  32'd1);
        check_reg(5'd6,  32'h0000_07FF);
        check_reg(5'd7,  32'hFFFF_FFFF);
        check_reg(5'd8,  32'd0);
        check_reg(5'd9,  32'd1);
        check_reg(5'd10, 32'd5);
        check_reg(5'd11, 32'd40);
        check_reg(5'd12, 32'h0FFF_FFFF);
        check_reg(5'd13, 32'hFFFF_FFFF);
        check_reg(5'd14, 32'h0000_0040);
        check_reg(5'd15, 32'h1234_5000);
        check_reg(5'd16, 32'd60);
        check_reg(5'd17, 32'd30);
        check_reg(5'd18, 32'd0);
        check_reg(5'd19, 32'd0);
        check_reg(5'd20, 32'd0);
        check_reg(5'd21, 32'd7);
        check_reg(5'd22, 32'd108);
        check_reg(5'd23, 32'd0);
        check_reg(5'd24, 32'd24);
        check_reg(5'd25, 32'd88);
        check_reg(5'd26, 32'd9);
        check_reg(5'd27, 32'd81);
        check_reg(5'd28, 32'd1);
        check_reg(5'd29, 32'd32);
        check_reg(5'd30, 32'h07FF_FFFF);
        check_reg(5'd31, 32'hFFFF_FFFF);

        if (dut.dmem[2] !== 32'd30) begin
            $display("FAIL: dmem[2] expected=0000001e actual=%h", dut.dmem[2]);
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("TEST PASS: tb_cpu_base");
        end else begin
            $display("TEST FAIL: tb_cpu_base (%0d errors)", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule
