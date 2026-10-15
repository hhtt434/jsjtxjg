`timescale 1ns/1ps

/*
 * 测试功能：验证 I/S/B/U/J 型立即数拼接和符号扩展。
 * 实现方式：向组合逻辑 imm_gen 输入各种寄存器数量级指令，逐项比较 imm。
 */
module tb_imm_gen;
    reg  [31:0] instr;
    wire [31:0] imm;
    integer errors;

    // 实例化被测立即数生成器。
    imm_gen dut (
        .instr(instr),
        .imm  (imm)
    );

    // 比较任务：检查立即数是否与预期 32 位值完全一致。
    task check_imm;
        input [255:0] name;
        input [31:0] expected;
        begin
            #1;
            if (imm !== expected) begin
                $display("FAIL: %0s expected=%h actual=%h", name, expected, imm);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;

        // I 型负立即数：验证最高位符号扩展到 32 位。
        instr = 32'hFFF3_6293;
        check_imm("i_negative", 32'hFFFF_FFFF);

        // I 型正立即数：验证 Load 偏移量。
        instr = 32'h0083_2283;
        check_imm("i_positive", 32'd8);

        // S 型立即数：验证 Store 偏移量字段重排。
        instr = 32'h0053_2423;
        check_imm("s_positive", 32'd8);

        // B 型正偏移：验证分支立即数位序。
        instr = 32'h0020_8863;
        check_imm("b_positive", 32'd16);

        // B 型负偏移：验证分支符号扩展。
        instr = 32'hFE20_9CE3;
        check_imm("b_negative", 32'hFFFF_FFF8);

        // U 型立即数：低 12 位补零。
        instr = 32'h1234_52B7;
        check_imm("u_immediate", 32'h1234_5000);

        // auipc 与 lui 共用 U 型立即数格式。
        instr = 32'h1234_5297;
        check_imm("auipc_immediate", 32'h1234_5000);

        // J 型跳转偏移：验证 J 型字段交叉重排。
        instr = 32'h0100_00EF;
        check_imm("j_positive", 32'd16);

        if (errors == 0) begin
            $display("TEST PASS: tb_imm_gen");
        end else begin
            $display("TEST FAIL: tb_imm_gen (%0d errors)", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule

