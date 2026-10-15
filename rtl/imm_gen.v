`include "riscv_defs.vh"

/*
 * 模块功能：RISC-V 立即数生成器。
 * 实现方式：根据主操作码判断 I/S/B/U/J 型编码，完成字段重排和符号扩展，
 * 输出统一的 32 位 imm，供 ID 阶段随流水线传递到 EX 阶段。
 */
module imm_gen (
    input  wire [31:0] instr,
    output reg  [31:0] imm
);
    // 组合逻辑立即数译码：不同指令格式的立即数片段位置不同。
    always @* begin
        case (instr[6:0])
            `OPCODE_ITYPE,
            `OPCODE_LOAD,
            `OPCODE_JAL: begin
                imm = {{20{instr[31]}}, instr[31:20]};
            end
            `OPCODE_STORE: begin
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            end
            `OPCODE_BRANCH: begin
                imm = {{19{instr[31]}}, instr[31], instr[7],
                       instr[30:25], instr[11:8], 1'b0};
            end
            `OPCODE_LUI,
            `OPCODE_AUIPC: begin
                imm = {instr[31:12], 12'b0};
            end
            default: begin
                imm = 32'b0;
            end
        endcase
    end
endmodule

