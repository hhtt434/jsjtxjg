`include "riscv_defs.vh"

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

    assign product_low = a * b;
    assign zero = (result == 32'd0);
    assign lt_signed = ($signed(a) < $signed(b));
    assign lt_unsigned = (a < b);

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

