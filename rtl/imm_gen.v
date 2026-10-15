`include "riscv_defs.vh"

module imm_gen (
    input  wire [31:0] instr,
    output reg  [31:0] imm
);
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

