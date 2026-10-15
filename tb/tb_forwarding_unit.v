`timescale 1ns/1ps

/*
 * 测试功能：验证转发单元的优先级和 Load 例外。
 * 实现方式：组合驱动 EX、EX/MEM、MEM/WB 的寄存器编号和写使能，
 * 检查 forward_a、forward_b、forward_acc 三组选择信号。
 */
module tb_forwarding_unit;
    reg  [4:0] ex_rs1;
    reg  [4:0] ex_rs2;
    reg  [4:0] ex_rd_old;
    reg        ex_use_rs1;
    reg        ex_use_rs2;
    reg        ex_use_rd;
    reg  [4:0] exmem_rd;
    reg  [4:0] memwb_rd;
    reg        exmem_reg_write;
    reg        exmem_mem_read;
    reg        memwb_reg_write;
    wire [1:0] forward_a;
    wire [1:0] forward_b;
    wire [1:0] forward_acc;
    integer    errors;

    // 实例化被测转发单元。
    forwarding_unit dut (
        .ex_rs1          (ex_rs1),
        .ex_rs2          (ex_rs2),
        .ex_rd_old       (ex_rd_old),
        .ex_use_rs1      (ex_use_rs1),
        .ex_use_rs2      (ex_use_rs2),
        .ex_use_rd       (ex_use_rd),
        .exmem_rd        (exmem_rd),
        .exmem_reg_write (exmem_reg_write),
        .exmem_mem_read  (exmem_mem_read),
        .memwb_rd        (memwb_rd),
        .memwb_reg_write (memwb_reg_write),
        .forward_a       (forward_a),
        .forward_b       (forward_b),
        .forward_acc     (forward_acc)
    );

    // 比较任务：检查三组转发选择是否全部符合预期。
    task check_forwards;
        input [255:0] name;
        input [1:0] expected_a;
        input [1:0] expected_b;
        input [1:0] expected_acc;
        begin
            #1;
            if ((forward_a !== expected_a) ||
                (forward_b !== expected_b) ||
                (forward_acc !== expected_acc)) begin
                $display("FAIL: %0s a=%b b=%b acc=%b", name,
                         forward_a, forward_b, forward_acc);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;
        ex_rs1 = 5'd1;
        ex_rs2 = 5'd2;
        ex_rd_old = 5'd3;
        ex_use_rs1 = 1;
        ex_use_rs2 = 1;
        ex_use_rd = 1;
        exmem_rd = 5'd5;
        exmem_reg_write = 0;
        exmem_mem_read = 0;
        memwb_rd = 5'd6;
        memwb_reg_write = 0;
        // 初始场景：没有任何目的寄存器匹配，应使用寄存器堆原值。
        check_forwards("no_forward", 2'b00, 2'b00, 2'b00);

        // EX/MEM 与 rs1 匹配时，A 口选择 EX/MEM 结果。
        exmem_rd = ex_rs1;
        exmem_reg_write = 1;
        check_forwards("forward_exmem_a", 2'b01, 2'b00, 2'b00);

        // MEM/WB 与 rs2 匹配时，B 口选择写回数据。
        exmem_rd = 5'd5;
        memwb_rd = ex_rs2;
        memwb_reg_write = 1;
        check_forwards("forward_memwb_b", 2'b00, 2'b10, 2'b00);

        // 两个流水级同时匹配时，较新的 EX/MEM 结果优先。
        exmem_rd = ex_rs1;
        exmem_reg_write = 1;
        memwb_rd = ex_rs1;
        memwb_reg_write = 1;
        check_forwards("exmem_priority_a", 2'b01, 2'b00, 2'b00);

        // 验证 mac 旧 rd 的独立累加器转发。
        exmem_rd = ex_rd_old;
        exmem_reg_write = 1;
        memwb_rd = ex_rd_old;
        memwb_reg_write = 1;
        check_forwards("forward_acc", 2'b00, 2'b00, 2'b01);

        // EX/MEM 是 Load 时数据尚未产生，禁止从该级转发。
        exmem_mem_read = 1;
        memwb_reg_write = 0;
        check_forwards("do_not_forward_load_exmem", 2'b00, 2'b00, 2'b00);

        if (errors == 0) begin
            $display("TEST PASS: tb_forwarding_unit");
        end else begin
            $display("TEST FAIL: tb_forwarding_unit (%0d errors)", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule
