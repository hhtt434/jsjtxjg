`timescale 1ns/1ps

module tb_imm_gen;
    reg  [31:0] instr;
    wire [31:0] imm;
    integer errors;

    imm_gen dut (
        .instr(instr),
        .imm  (imm)
    );

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

        // ori x5, x6, -1
        instr = 32'hFFF3_6293;
        check_imm("i_negative", 32'hFFFF_FFFF);

        // lw x5, 8(x6)
        instr = 32'h0083_2283;
        check_imm("i_positive", 32'd8);

        // sw x5, 8(x6)
        instr = 32'h0053_2423;
        check_imm("s_positive", 32'd8);

        // beq x1, x2, +16
        instr = 32'h0020_8863;
        check_imm("b_positive", 32'd16);

        // bne x1, x2, -8
        instr = 32'hFE20_9CE3;
        check_imm("b_negative", 32'hFFFF_FFF8);

        // lui x5, 0x12345
        instr = 32'h1234_52B7;
        check_imm("u_immediate", 32'h1234_5000);

        // auipc x5, 0x12345
        instr = 32'h1234_5297;
        check_imm("auipc_immediate", 32'h1234_5000);

        // jal x1, +16
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

