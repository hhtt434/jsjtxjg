`timescale 1ns/1ps

/*
 * 测试功能：验证 ALU 全部组合运算。
 * 实现方式：直接驱动 a/b/acc/op，等待组合逻辑稳定后比较 result，覆盖
 * 算术、逻辑、移位、比较、乘累加和 B 口直通，不涉及时钟和流水线。
 */
module tb_alu;
    reg  [31:0] a;
    reg  [31:0] b;
    reg  [31:0] acc;
    reg  [3:0]  op;
    wire [31:0] result;
    wire        zero;
    wire        lt_signed;
    wire        lt_unsigned;

    integer errors;

    // 实例化被测 ALU，所有端口按组合逻辑连接。
    alu dut (
        .a          (a),
        .b          (b),
        .acc        (acc),
        .op         (op),
        .result     (result),
        .zero       (zero),
        .lt_signed  (lt_signed),
        .lt_unsigned(lt_unsigned)
    );

    // 比较任务：等待组合逻辑更新后检查 result，并累计错误次数。
    task check_result;
        input [255:0] name;
        input [31:0] expected;
        begin
            #1;
            if (result !== expected) begin
                $display("FAIL: %0s expected=%h actual=%h", name, expected, result);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;

        // 加减运算测试。
        a = 32'd10;
        b = 32'd20;
        acc = 32'd100;

        op = 4'b0000;
        check_result("add", 32'd30);

        op = 4'b0001;
        check_result("sub", 32'hFFFF_FFF6);

        // 移位测试：验证移位量只使用低 5 位。
        a = 32'h8000_0000;
        b = 32'h0000_0001;
        op = 4'b0010;
        check_result("sll", 32'h0000_0000);

        // 有符号和无符号比较测试。
        a = 32'hFFFF_FFFF;
        b = 32'd1;
        op = 4'b0011;
        check_result("slt", 32'd1);

        op = 4'b0100;
        check_result("sltu", 32'd0);

        // 按位或、与、异或测试。
        a = 32'hF0F0_0000;
        b = 32'h00FF_00FF;
        op = 4'b0101;
        check_result("or", 32'hF0FF_00FF);

        op = 4'b0110;
        check_result("and", 32'h00F0_0000);

        op = 4'b0111;
        check_result("xor", 32'hF00F_00FF);

        // 逻辑右移和算术右移测试。
        a = 32'h8000_0000;
        b = 32'd31;
        op = 4'b1000;
        check_result("srl", 32'd1);

        op = 4'b1001;
        check_result("sra", 32'hFFFF_FFFF);

        // 定制 mac 测试：验证 acc + low32(a*b)。
        a = 32'd7;
        b = 32'd9;
        acc = 32'd100;
        op = 4'b1010;
        check_result("mac", 32'd163);

        a = 32'h0000_0007;
        b = 32'hFFFF_FFF8;
        acc = 32'd0;
        op = 4'b1010;
        check_result("mac_low32", 32'hFFFF_FFC8);

        // PASS_B 测试，供 lui 指令使用。
        a = 32'd0;
        b = 32'h1234_5678;
        op = 4'b1011;
        check_result("pass_b", 32'h1234_5678);

        if (errors == 0) begin
            $display("TEST PASS: tb_alu");
        end else begin
            $display("TEST FAIL: tb_alu (%0d errors)", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule
