/*
 * 模块功能：EX 阶段数据转发选择单元。
 * 实现方式：分别比较 EX 的 rs1、rs2 和旧 rd 与 EX/MEM、MEM/WB 的目的
 * 寄存器。EX/MEM 结果更新，因此优先级更高；Load 在 EX/MEM 时不可转发。
 */
module forwarding_unit (
    input  wire [4:0] ex_rs1,
    input  wire [4:0] ex_rs2,
    input  wire [4:0] ex_rd_old,
    input  wire       ex_use_rs1,
    input  wire       ex_use_rs2,
    input  wire       ex_use_rd,
    input  wire [4:0] exmem_rd,
    input  wire       exmem_reg_write,
    input  wire       exmem_mem_read,
    input  wire [4:0] memwb_rd,
    input  wire       memwb_reg_write,
    output reg  [1:0] forward_a,
    output reg  [1:0] forward_b,
    output reg  [1:0] forward_acc
);
    // 组合逻辑产生三组选择信号：00 用寄存器堆，01 用 EX/MEM，10 用 MEM/WB。
    always @* begin
        forward_a   = 2'b00;
        forward_b   = 2'b00;
        forward_acc = 2'b00;

        // 为 A 操作数选择最新且可用的 rs1 结果。
        if (ex_use_rs1) begin
            if (exmem_reg_write && !exmem_mem_read &&
                (exmem_rd != 5'd0) &&
                (exmem_rd == ex_rs1)) begin
                forward_a = 2'b01;
            end else if (memwb_reg_write && (memwb_rd != 5'd0) &&
                         (memwb_rd == ex_rs1)) begin
                forward_a = 2'b10;
            end
        end

        // 为 B 操作数选择最新且可用的 rs2 结果。
        if (ex_use_rs2) begin
            if (exmem_reg_write && !exmem_mem_read &&
                (exmem_rd != 5'd0) &&
                (exmem_rd == ex_rs2)) begin
                forward_b = 2'b01;
            end else if (memwb_reg_write && (memwb_rd != 5'd0) &&
                         (memwb_rd == ex_rs2)) begin
                forward_b = 2'b10;
            end
        end

        // mac 指令的旧 rd 是隐式第三源操作数，需要独立转发。
        if (ex_use_rd) begin
            if (exmem_reg_write && !exmem_mem_read &&
                (exmem_rd != 5'd0) &&
                (exmem_rd == ex_rd_old)) begin
                forward_acc = 2'b01;
            end else if (memwb_reg_write && (memwb_rd != 5'd0) &&
                         (memwb_rd == ex_rd_old)) begin
                forward_acc = 2'b10;
            end
        end
    end
endmodule
