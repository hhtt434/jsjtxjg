`timescale 1ns/1ps

/*
 * 测试功能：CPU 转发和 Load-use 冒险集成测试。
 * 实现方式：加载 hazards.hex 连续依赖程序，统计 load_use_stall 次数，
 * 并在运行结束后检查寄存器堆和数据存储器，验证转发与阻塞结果。
 */
module tb_cpu_hazards;
    reg clk;
    reg rst;
    integer errors;
    integer stall_count;
    integer flush_count;
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

    // 实例化 CPU，并加载连续依赖和 Load-use 测试程序。
    riscv_cpu #(
        .IMEM_INIT_FILE("tb/programs/hazards.hex"),
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

    // 每个有效时钟沿统计 Load-use 阻塞和控制流冲刷次数。
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

    // 比较任务：检查 DUT 内部寄存器结果。
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

    // 测试主流程：复位后运行足够周期，检查寄存器、内存和阻塞次数。
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

        // 检查连续 add 的转发链结果。
        check_reg(5'd1,  32'd5);
        check_reg(5'd2,  32'd10);
        check_reg(5'd3,  32'd15);
        check_reg(5'd4,  32'd20);
        check_reg(5'd5,  32'd35);
        check_reg(5'd6,  32'd35);
        check_reg(5'd7,  32'd40);
        check_reg(5'd8,  32'd35);
        check_reg(5'd9,  32'd35);
        // 检查 Load 后 mac、旧 rd 累加和算术依赖结果。
        check_reg(5'd10, 32'd175);
        check_reg(5'd11, 32'd60);
        check_reg(5'd12, 32'd32);
        check_reg(5'd13, 32'd37);
        check_reg(5'd14, 32'd1369);
        check_reg(5'd15, 32'd2738);
        check_reg(5'd16, 32'd2738);
        check_reg(5'd17, 32'd13690);

        // 检查 Store 写入和 Load 读出的数据一致性。
        if (dut.dmem[0] !== 32'd35) begin
            $display("FAIL: dmem[0] expected=00000023 actual=%h", dut.dmem[0]);
            errors = errors + 1;
        end
        if (dut.dmem[1] !== 32'd2738) begin
            $display("FAIL: dmem[1] expected=00000ab2 actual=%h", dut.dmem[1]);
            errors = errors + 1;
        end
        // 测试程序特意构造三次紧邻 Load-use，阻塞次数必须精确为 3。
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

