`timescale 1ns/1ps

module tb_cpu_hazards;
    reg clk;
    reg rst;
    integer errors;
    integer stall_count;
    integer flush_count;

    riscv_cpu #(
        .IMEM_INIT_FILE("tb/programs/hazards.hex"),
        .DMEM_INIT_FILE("")
    ) dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!rst) begin
            if (dut.load_use_stall) begin
                stall_count = stall_count + 1;
            end
            if (dut.flush_if_id || dut.flush_id_ex) begin
                flush_count = flush_count + 1;
            end
        end
    end

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
        stall_count = 0;
        flush_count = 0;
        repeat (2) @(posedge clk);
        rst = 0;
        repeat (110) @(posedge clk);
        #1;

        check_reg(5'd1,  32'd5);
        check_reg(5'd2,  32'd10);
        check_reg(5'd3,  32'd15);
        check_reg(5'd4,  32'd20);
        check_reg(5'd5,  32'd35);
        check_reg(5'd6,  32'd35);
        check_reg(5'd7,  32'd40);
        check_reg(5'd8,  32'd35);
        check_reg(5'd9,  32'd35);
        check_reg(5'd10, 32'd175);
        check_reg(5'd11, 32'd60);
        check_reg(5'd12, 32'd32);
        check_reg(5'd13, 32'd37);
        check_reg(5'd14, 32'd1369);
        check_reg(5'd15, 32'd2738);
        check_reg(5'd16, 32'd2738);
        check_reg(5'd17, 32'd13690);

        if (dut.dmem[0] !== 32'd35) begin
            $display("FAIL: dmem[0] expected=00000023 actual=%h", dut.dmem[0]);
            errors = errors + 1;
        end
        if (dut.dmem[1] !== 32'd2738) begin
            $display("FAIL: dmem[1] expected=00000ab2 actual=%h", dut.dmem[1]);
            errors = errors + 1;
        end
        if (stall_count != 3) begin
            $display("FAIL: load-use stalls expected=3 actual=%0d", stall_count);
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("TEST PASS: tb_cpu_hazards");
        end else begin
            $display("TEST FAIL: tb_cpu_hazards (%0d errors)", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule

