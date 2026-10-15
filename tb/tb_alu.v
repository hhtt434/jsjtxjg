`timescale 1ns/1ps

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

        a = 32'd10;
        b = 32'd20;
        acc = 32'd100;

        op = 4'b0000;
        check_result("add", 32'd30);

        op = 4'b0001;
        check_result("sub", 32'hFFFF_FFF6);

        a = 32'h8000_0000;
        b = 32'h0000_0001;
        op = 4'b0010;
        check_result("sll", 32'h0000_0000);

        a = 32'hFFFF_FFFF;
        b = 32'd1;
        op = 4'b0011;
        check_result("slt", 32'd1);

        op = 4'b0100;
        check_result("sltu", 32'd0);

        a = 32'hF0F0_0000;
        b = 32'h00FF_00FF;
        op = 4'b0101;
        check_result("or", 32'hF0FF_00FF);

        op = 4'b0110;
        check_result("and", 32'h00F0_0000);

        op = 4'b0111;
        check_result("xor", 32'hF00F_00FF);

        a = 32'h8000_0000;
        b = 32'd31;
        op = 4'b1000;
        check_result("srl", 32'd1);

        op = 4'b1001;
        check_result("sra", 32'hFFFF_FFFF);

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
