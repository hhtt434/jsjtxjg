`timescale 1ns/1ps

module tb_hazard_unit;
    reg  [4:0] id_ex_rd;
    reg        id_ex_mem_read;
    reg  [4:0] if_id_rs1;
    reg  [4:0] if_id_rs2;
    reg  [4:0] if_id_rd;
    reg        if_id_use_rs1;
    reg        if_id_use_rs2;
    reg        if_id_use_rd;
    wire       load_use_stall;
    integer    errors;

    hazard_unit dut (
        .id_ex_rd       (id_ex_rd),
        .id_ex_mem_read (id_ex_mem_read),
        .if_id_rs1      (if_id_rs1),
        .if_id_rs2      (if_id_rs2),
        .if_id_rd       (if_id_rd),
        .if_id_use_rs1  (if_id_use_rs1),
        .if_id_use_rs2  (if_id_use_rs2),
        .if_id_use_rd   (if_id_use_rd),
        .load_use_stall (load_use_stall)
    );

    task check_stall;
        input [255:0] name;
        input expected;
        begin
            #1;
            if (load_use_stall !== expected) begin
                $display("FAIL: %0s expected=%b actual=%b", name,
                         expected, load_use_stall);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;
        id_ex_mem_read = 1;
        id_ex_rd = 5'd5;
        if_id_rs1 = 5'd1;
        if_id_rs2 = 5'd2;
        if_id_rd = 5'd3;
        if_id_use_rs1 = 1;
        if_id_use_rs2 = 1;
        if_id_use_rd = 0;
        check_stall("no_match", 1'b0);

        if_id_rs1 = 5'd5;
        check_stall("rs1_match", 1'b1);

        if_id_rs1 = 5'd1;
        if_id_rs2 = 5'd5;
        check_stall("rs2_match", 1'b1);

        if_id_rs2 = 5'd2;
        if_id_rd = 5'd5;
        if_id_use_rd = 1;
        check_stall("mac_acc_match", 1'b1);

        if_id_rd = 5'd3;
        id_ex_rd = 5'd0;
        if_id_rs1 = 5'd0;
        check_stall("x0_is_not_dependency", 1'b0);

        id_ex_mem_read = 0;
        check_stall("not_load", 1'b0);

        if (errors == 0) begin
            $display("TEST PASS: tb_hazard_unit");
        end else begin
            $display("TEST FAIL: tb_hazard_unit (%0d errors)", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule

