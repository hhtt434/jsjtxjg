/*
 * 模块功能：32 个 32 位通用寄存器堆，支持两路普通读取和一路累加器读取。
 * 实现方式：组合逻辑异步读寄存器，时钟上升沿执行写回；x0 始终固定为 0，
 * 第三路 rs3 专门供定制 mac 指令读取旧 rd 作为累加值。
 */
module regfile (
    input  wire        clk,
    input  wire        rst,
    input  wire        we,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rs3,
    input  wire [4:0]  rd,
    input  wire [31:0] wdata,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2,
    output wire [31:0] rdata3
);
    reg [31:0] regs [0:31];
    integer i;

    // 三路组合读口：普通 rs1、rs2，以及 mac 需要的旧 rd。
    assign rdata1 = (rs1 == 5'd0) ? 32'b0 : regs[rs1];
    assign rdata2 = (rs2 == 5'd0) ? 32'b0 : regs[rs2];
    assign rdata3 = (rs3 == 5'd0) ? 32'b0 : regs[rs3];

    // 仿真开始时初始化所有寄存器，避免出现未知初值。
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            regs[i] = 32'b0;
        end
    end

    // 复位同步清零；否则在写使能有效且目的寄存器不是 x0 时写入。
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'b0;
            end
        end else if (we && (rd != 5'd0)) begin
            regs[rd] <= wdata;
        end
    end
endmodule
