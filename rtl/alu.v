`include "riscv_defs.vh"

/*
 * 模块功能：32 位组合逻辑 ALU。
 * 实现方式：根据 op 选择加减、移位、比较、逻辑运算和定制乘累加，并同时
 * 输出零标志、有符号比较结果和无符号比较结果，供分支判断和 slt 使用。
 */
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [31:0] acc,
    input  wire [3:0]  op,
    output reg  [31:0] result,
    output wire        zero,
    output wire        lt_signed,
    output wire        lt_unsigned
);
    wire [31:0] product_low;

    // 乘法结果只保留低 32 位，作为 mac 指令的乘法部分。
    assign product_low = a * b;
    assign zero = (result == 32'd0);
    assign lt_signed = ($signed(a) < $signed(b));
    assign lt_unsigned = (a < b);

    // 组合逻辑选择 ALU 输出。case 默认值保证非法 op 产生确定的 0。
    always @* begin
        case (op)
            `ALU_ADD:    result = a + b;
            `ALU_SUB:    result = a - b;
            `ALU_SLL:    result = a << b[4:0];
            `ALU_SLT:    result = {31'b0, lt_signed};
            `ALU_SLTU:   result = {31'b0, lt_unsigned};
            `ALU_OR:     result = a | b;
            `ALU_AND:    result = a & b;
            `ALU_XOR:    result = a ^ b;
            `ALU_SRL:    result = a >> b[4:0];
            `ALU_SRA:    result = $signed(a) >>> b[4:0];
            `ALU_MAC:    result = acc + product_low;
            `ALU_PASS_B: result = b;
            default:     result = 32'b0;
        endcase
    end
endmodule

