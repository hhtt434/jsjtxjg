`include "riscv_defs.vh"

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

        case (instr[6:0])
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

            `OPCODE_LOAD: begin
                if (funct3 == 3'b010) begin
                    reg_write  = 1'b1;
                    mem_read   = 1'b1;
                    alu_src_b  = 1'b1;
                    mem_to_reg = 1'b1;
                    use_rs1    = 1'b1;
                end
            end

            `OPCODE_STORE: begin
                if (funct3 == 3'b010) begin
                    mem_write = 1'b1;
                    alu_src_b = 1'b1;
                    use_rs1   = 1'b1;
                    use_rs2   = 1'b1;
                end
            end

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

            `OPCODE_JAL: begin
                reg_write = 1'b1;
                jump      = 1'b1;
            end

            `OPCODE_LUI: begin
                reg_write = 1'b1;
                alu_src_b = 1'b1;
                alu_op    = `ALU_PASS_B;
            end

            `OPCODE_AUIPC: begin
                reg_write = 1'b1;
                alu_src_a = 1'b1;
                alu_src_b = 1'b1;
            end

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

