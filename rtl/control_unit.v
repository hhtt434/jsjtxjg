`include "riscv_defs.vh"

/*
 * 模块功能：主控制单元和 ALU 控制译码器。
 * 实现方式：先根据 instr[6:0] 判断指令大类，再结合 funct3、funct7 区分
 * 具体操作，产生寄存器写、访存、分支、跳转、源操作数使用标志和 ALU 操作码。
 */
module control_unit (
    input  wire [31:0] instr,
    output reg         reg_write,
    output reg         mem_read,
    output reg         mem_write,
    output reg         alu_src_a,
    output reg         alu_src_b,
    output reg         mem_to_reg,
    output reg         branch,
    output reg         jump,
    output reg         use_rs1,
    output reg         use_rs2,
    output reg         use_rd,
    output reg  [3:0]  alu_op
);
    wire [2:0] funct3;
    wire [6:0] funct7;

    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    // 默认所有控制信号无效，确保未识别指令退化为不会修改体系结构的空操作。
    always @* begin
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        alu_src_a  = 1'b0;
        alu_src_b  = 1'b0;
        mem_to_reg = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
        use_rs1    = 1'b0;
        use_rs2    = 1'b0;
        use_rd     = 1'b0;
        alu_op     = `ALU_ADD;

        // 按主操作码分派到 R/I/Load/Store/Branch/JAL/LUI/AUIPC/MAC 指令组。
        case (instr[6:0])
            // R 型指令：两个源寄存器参与 ALU 运算，结果写 rd。
            `OPCODE_RTYPE: begin
                reg_write = 1'b1;
                use_rs1  = 1'b1;
                use_rs2  = 1'b1;
                case (funct3)
                    3'b000: alu_op = `ALU_ADD;
                    3'b001: alu_op = `ALU_SLL;
                    3'b010: alu_op = `ALU_SLT;
                    3'b011: alu_op = `ALU_SLTU;
                    3'b100: alu_op = `ALU_XOR;
                    3'b101: alu_op = (funct7 == 7'b0100000) ? `ALU_SRA : `ALU_SRL;
                    3'b110: alu_op = `ALU_OR;
                    3'b111: alu_op = `ALU_AND;
                    default: begin
                        reg_write = 1'b0;
                        use_rs1 = 1'b0;
                        use_rs2 = 1'b0;
                    end
                endcase
            end

            // I 型 ALU 指令：rs1 与立即数运算，结果写 rd。
            `OPCODE_ITYPE: begin
                reg_write = 1'b1;
                alu_src_b = 1'b1;
                use_rs1   = 1'b1;
                case (funct3)
                    3'b000: alu_op = `ALU_ADD;
                    3'b001: alu_op = `ALU_SLL;
                    3'b101: alu_op = (funct7 == 7'b0100000) ? `ALU_SRA : `ALU_SRL;
                    3'b110: alu_op = `ALU_OR;
                    default: begin
                        reg_write = 1'b0;
                        alu_src_b = 1'b0;
                        use_rs1 = 1'b0;
                    end
                endcase
            end

            // lw：计算访存地址，MEM 阶段读数据，WB 阶段写回 rd。
            `OPCODE_LOAD: begin
                if (funct3 == 3'b010) begin
                    reg_write  = 1'b1;
                    mem_read   = 1'b1;
                    alu_src_b  = 1'b1;
                    mem_to_reg = 1'b1;
                    use_rs1    = 1'b1;
                end
            end

            // sw：计算访存地址，EX/MEM 中保存 rs2 数据，MEM 阶段写入内存。
            `OPCODE_STORE: begin
                if (funct3 == 3'b010) begin
                    mem_write = 1'b1;
                    alu_src_b = 1'b1;
                    use_rs1   = 1'b1;
                    use_rs2   = 1'b1;
                end
            end

            // B 型分支：EX 阶段比较 rs1/rs2，命中时修改 PC，不写寄存器。
            `OPCODE_BRANCH: begin
                if ((funct3 == 3'b000) ||
                    (funct3 == 3'b001) ||
                    (funct3 == 3'b100) ||
                    (funct3 == 3'b101)) begin
                    branch  = 1'b1;
                    use_rs1 = 1'b1;
                    use_rs2 = 1'b1;
                    alu_op  = `ALU_SUB;
                end
            end

            // jal：无条件跳转，同时把 PC+4 写回 rd。
            `OPCODE_JAL: begin
                reg_write = 1'b1;
                jump      = 1'b1;
            end

            // lui：把 U 型立即数直接送入 rd，因此 ALU 选择直通 B。
            `OPCODE_LUI: begin
                reg_write = 1'b1;
                alu_src_b = 1'b1;
                alu_op    = `ALU_PASS_B;
            end

            // auipc：把当前 PC 与 U 型立即数相加后写入 rd。
            `OPCODE_AUIPC: begin
                reg_write = 1'b1;
                alu_src_a = 1'b1;
                alu_src_b = 1'b1;
            end

            // 定制 mac：custom-0 编码，额外使用旧 rd 作为乘累加初值。
            `OPCODE_MAC: begin
                if ((funct3 == 3'b000) && (funct7 == 7'b0000000)) begin
                    reg_write = 1'b1;
                    use_rs1   = 1'b1;
                    use_rs2   = 1'b1;
                    use_rd    = 1'b1;
                    alu_op    = `ALU_MAC;
                end
            end

            default: begin
            end
        endcase
    end
endmodule

