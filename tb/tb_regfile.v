`timescale 1ns/1ps

/*
 * 测试功能：验证寄存器堆的三路读口、同步写口和 x0 固定为零。
 * 实现方式：时钟写回寄存器后，通过 rs1、rs2、rs3 组合读口比较输出。
 */
module tb_regfile;
    reg         clk;
    reg         rst;
    reg         we;
    reg  [4:0]  rs1;
    reg  [4:0]  rs2;
    reg  [4:0]  rs3;
    reg  [4:0]  rd;
    reg  [31:0] wdata;
    wire [31:0] rdata1;
    wire [31:0] rdata2;
    wire [31:0] rdata3;
    integer     errors;

    // 实例化被测寄存器堆。
    regfile dut (
        .clk   (clk),
        .rst   (rst),
        .we    (we),
        .rs1   (rs1),
        .rs2   (rs2),
        .rs3   (rs3),
        .rd    (rd),
        .wdata (wdata),
        .rdata1(rdata1),
        .rdata2(rdata2),
        .rdata3(rdata3)
    );

    // 比较任务：一次检查三路读口是否符合预期。
    task check_read;
        input [255:0] name;
        input [31:0] expected1;
        input [31:0] expected2;
        input [31:0] expected3;
        begin
            #1;
            if ((rdata1 !== expected1) ||
                (rdata2 !== expected2) ||
                (rdata3 !== expected3)) begin
                $display("FAIL: %0s r1=%h r2=%h r3=%h",
                         name, rdata1, rdata2, rdata3);
                errors = errors + 1;
            end
        end
    endtask

    // 生成 10ns 周期时钟，DUT 在上升沿写寄存器。
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        errors = 0;
        rst = 1;
        we = 0;
        rs1 = 0;
        rs2 = 0;
        rs3 = 0;
        rd = 0;
        wdata = 0;
        #12;

        // 先复位，再写入 x5，验证正常写读和第三读口。
        rst = 0;
        // 尝试写 x0，随后确认 x0 仍然保持 0。
        we = 1;
        rd = 5'd5;
        wdata = 32'hDEAD_BEEF;
        @(posedge clk);
        #1;
        we = 0;
        rs1 = 5'd5;
        rs3 = 5'd5;
        check_read("write_read", 32'hDEAD_BEEF, 32'd0, 32'hDEAD_BEEF);

        we = 1;
        rd = 5'd0;
        wdata = 32'hFFFF_FFFF;
        @(posedge clk);
        #1;
        we = 0;
        rs1 = 5'd0;
        rs3 = 5'd0;
        check_read("x0_remains_zero", 32'd0, 32'd0, 32'd0);

        if (errors == 0) begin
            $display("TEST PASS: tb_regfile");
        end else begin
            $display("TEST FAIL: tb_regfile (%0d errors)", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule
