`timescale 1ns/1ps

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

        // add x3, x1, x2
        instr = 32'h0020_81B3;
        check_control("add", 4'b0000, 1, 0, 0, 0, 0, 0, 0, 0, 0);

        // sra x3, x4, x5
        instr = 32'h4052_51B3;
        check_control("sra", 4'b1001, 1, 0, 0, 0, 0, 0, 0, 0, 0);

        // ori x5, x6, -1
        instr = 32'hFFF3_6293;
        check_control("ori", 4'b0101, 1, 0, 0, 0, 1, 0, 0, 0, 0);

        // lw x5, 8(x6)
        instr = 32'h0083_2283;
        check_control("lw", 4'b0000, 1, 1, 0, 0, 1, 1, 0, 0, 0);

        // sw x5, 8(x6)
        instr = 32'h0053_2423;
        check_control("sw", 4'b0000, 0, 0, 1, 0, 1, 0, 0, 0, 0);

        // beq x1, x2, +16
        instr = 32'h0020_8863;
        check_control("beq", 4'b0001, 0, 0, 0, 0, 0, 0, 1, 0, 0);

        // jal x1, +16
        instr = 32'h0100_00EF;
        check_control("jal", 4'b0000, 1, 0, 0, 0, 0, 0, 0, 1, 0);

        // auipc x5, 0x12345
        instr = 32'h1234_5297;
        check_control("auipc", 4'b0000, 1, 0, 0, 1, 1, 0, 0, 0, 0);

        // addi x5, x6, -1
        instr = 32'hFFF3_0293;
        check_control("addi", 4'b0000, 1, 0, 0, 0, 1, 0, 0, 0, 0);

        // mac x3, x1, x2
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
