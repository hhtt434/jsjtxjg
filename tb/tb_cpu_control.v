`timescale 1ns/1ps

/*
 * 测试功能：CPU 分支、跳转和控制冒险集成测试。
 * 实现方式：加载 control.hex 程序，检查分支条件、jal 返回地址，以及
 * 控制流命中后被冲刷的错误路径指令没有写入寄存器。
 */
module tb_cpu_control;
    reg clk;
    reg rst;
    integer errors;
    wire [31:0] debug_pc;
    wire [31:0] debug_instr;
    wire [31:0] debug_alu_result;
    wire [31:0] debug_mem_read_data;
    wire [31:0] debug_wb_write_data;
    wire [31:0] debug_rs1_data;
    wire [31:0] debug_rs2_data;
    wire        debug_reg_write;
    wire        debug_mem_write;
    wire        debug_load_use_stall;
    wire        debug_control_taken;

    // 实例化 CPU，并加载分支和跳转测试程序。
    riscv_cpu #(
        .IMEM_INIT_FILE("tb/programs/control.hex"),
        .DMEM_INIT_FILE("")
    ) dut (
        .clk(clk),
        .rst(rst),
        .debug_pc(debug_pc),
        .debug_instr(debug_instr),
        .debug_alu_result(debug_alu_result),
        .debug_mem_read_data(debug_mem_read_data),
        .debug_wb_write_data(debug_wb_write_data),
        .debug_rs1_data(debug_rs1_data),
        .debug_rs2_data(debug_rs2_data),
        .debug_reg_write(debug_reg_write),
        .debug_mem_write(debug_mem_write),
        .debug_load_use_stall(debug_load_use_stall),
        .debug_control_taken(debug_control_taken)
    );

    // 生成周期为 10ns 的仿真时钟。
    always #5 clk = ~clk;

    // 比较任务：检查控制流执行后的寄存器值。
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

    // 测试主流程：复位、执行控制流程序并检查错误路径是否被正确清除。
    initial begin
        clk = 0;
        rst = 1;
        errors = 0;
        repeat (2) @(posedge clk);
        rst = 0;
        repeat (70) @(posedge clk);
        #1;

        // 检查正常执行路径上的结果。
        check_reg(5'd1, 32'd1);
        check_reg(5'd2, 32'd2);
        check_reg(5'd3, 32'd3);
        // x4 和 x8 位于错误路径，应始终保持 0，证明冲刷生效。
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

