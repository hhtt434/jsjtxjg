`timescale 1ns/1ps

/*
 * 测试功能：验证控制单元对各种指令产生的控制信号。
 * 实现方式：输入手工编码的指令，等待组合逻辑稳定后检查 ALU 操作码、
 * 寄存器写、访存、分支、跳转和源操作数使用标志。
 */
module tb_control_unit;
    reg  [31:0] instr;
    wire        reg_write;
    wire        mem_read;
    wire        mem_write;
    wire        alu_src_a;
    wire        alu_src_b;
    wire        mem_to_reg;
    wire        branch;
    wire        jump;
    wire        use_rs1;
    wire        use_rs2;
    wire        use_rd;
    wire [3:0]  alu_op;
    integer     errors;

    // 实例化被测控制单元。
    control_unit dut (
        .instr     (instr),
        .reg_write (reg_write),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .alu_src_a (alu_src_a),
        .alu_src_b (alu_src_b),
        .mem_to_reg(mem_to_reg),
        .branch    (branch),
        .jump      (jump),
        .use_rs1   (use_rs1),
        .use_rs2   (use_rs2),
        .use_rd    (use_rd),
        .alu_op    (alu_op)
    );

    // 比较任务：一次性检查本测试关心的所有控制输出。
    task check_control;
        input [255:0] name;
        input [3:0] expected_alu;
        input expected_reg_write;
        input expected_mem_read;
        input expected_mem_write;
        input expected_alu_src_a;
        input expected_alu_src_b;
        input expected_mem_to_reg;
        input expected_branch;
        input expected_jump;
        input expected_use_rd;
        begin
            #1;
            if ((alu_op !== expected_alu) ||
                (reg_write !== expected_reg_write) ||
                (mem_read !== expected_mem_read) ||
                (mem_write !== expected_mem_write) ||
                (alu_src_a !== expected_alu_src_a) ||
                (alu_src_b !== expected_alu_src_b) ||
                (mem_to_reg !== expected_mem_to_reg) ||
                (branch !== expected_branch) ||
                (jump !== expected_jump) ||
                (use_rd !== expected_use_rd)) begin
                $display("FAIL: %0s alu=%b rw=%b mr=%b mw=%b asa=%b asb=%b mtr=%b br=%b jp=%b urd=%b",
                         name, alu_op, reg_write, mem_read, mem_write, alu_src_a,
                         alu_src_b, mem_to_reg, branch, jump, use_rd);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;

        // R 型 add：写 rd、使用 rs1/rs2、ALU 执行加法。
        instr = 32'h0020_81B3;
        check_control("add", 4'b0000, 1, 0, 0, 0, 0, 0, 0, 0, 0);

        // R 型 sra：funct7 区分算术右移和逻辑右移。
        instr = 32'h4052_51B3;
        check_control("sra", 4'b1001, 1, 0, 0, 0, 0, 0, 0, 0, 0);

        // I 型 ori：第二操作数选择立即数。
        instr = 32'hFFF3_6293;
        check_control("ori", 4'b0101, 1, 0, 0, 0, 1, 0, 0, 0, 0);

        // Load：产生读内存、写回寄存器和 mem_to_reg 信号。
        instr = 32'h0083_2283;
        check_control("lw", 4'b0000, 1, 1, 0, 0, 1, 1, 0, 0, 0);

        // Store：产生写内存信号，不写寄存器。
        instr = 32'h0053_2423;
        check_control("sw", 4'b0000, 0, 0, 1, 0, 1, 0, 0, 0, 0);

        // 分支：产生 branch 控制，ALU 执行减法以生成比较标志。
        instr = 32'h0020_8863;
        check_control("beq", 4'b0001, 0, 0, 0, 0, 0, 0, 1, 0, 0);

        // jal：同时产生跳转和寄存器写回信号。
        instr = 32'h0100_00EF;
        check_control("jal", 4'b0000, 1, 0, 0, 0, 0, 0, 0, 1, 0);

        // auipc：ALU A 口选择 PC，B 口选择立即数。
        instr = 32'h1234_5297;
        check_control("auipc", 4'b0000, 1, 0, 0, 1, 1, 0, 0, 0, 0);

        // addi：I 型立即数加法。
        instr = 32'hFFF3_0293;
        check_control("addi", 4'b0000, 1, 0, 0, 0, 1, 0, 0, 0, 0);

        // mac：额外置位 use_rd，并选择 ALU_MAC。
        instr = 32'h0020_818B;
        check_control("mac", 4'b1010, 1, 0, 0, 0, 0, 0, 0, 0, 1);

        if (errors == 0) begin
            $display("TEST PASS: tb_control_unit");
        end else begin
            $display("TEST FAIL: tb_control_unit (%0d errors)", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule
