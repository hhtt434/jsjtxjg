`include "riscv_defs.vh"

module riscv_cpu #(
    parameter IMEM_WORDS = 256,
    parameter DMEM_WORDS = 256,
    parameter IMEM_INIT_FILE = "",
    parameter DMEM_INIT_FILE = ""
) (
    input wire clk,
    input wire rst
);
    localparam [31:0] NOP = 32'h0000_0013;

    reg [31:0] imem [0:IMEM_WORDS-1];
    reg [31:0] dmem [0:DMEM_WORDS-1];
    integer init_index;

    initial begin
        for (init_index = 0; init_index < IMEM_WORDS; init_index = init_index + 1) begin
            imem[init_index] = NOP;
        end
        for (init_index = 0; init_index < DMEM_WORDS; init_index = init_index + 1) begin
            dmem[init_index] = 32'b0;
        end
        if (IMEM_INIT_FILE != "") begin
            $readmemh(IMEM_INIT_FILE, imem);
        end
        if (DMEM_INIT_FILE != "") begin
            $readmemh(DMEM_INIT_FILE, dmem);
        end
    end

    reg [31:0] pc;
    wire [31:0] pc_plus4;
    wire [31:0] if_instr;
    wire [31:0] if_mem_index;

    assign pc_plus4 = pc + 32'd4;
    assign if_mem_index = {22'b0, pc[9:2]};
    assign if_instr = imem[if_mem_index];

    // IF/ID pipeline register.
    reg [31:0] if_id_pc;
    reg [31:0] if_id_instr;
    reg        if_id_valid;

    // MEM/WB pipeline register. Declared here because the register file
    // writeback port consumes these values.
    reg        mem_wb_valid;
    reg [31:0] mem_wb_result;
    reg [31:0] mem_wb_mem_data;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_reg_write;
    reg        mem_wb_mem_to_reg;
    wire [31:0] mem_wb_write_data;

    wire [4:0] id_rs1;
    wire [4:0] id_rs2;
    wire [4:0] id_rd;
    wire [2:0] id_funct3;
    wire [31:0] id_imm;
    wire [31:0] id_rs1_data_reg;
    wire [31:0] id_rs2_data_reg;
    wire [31:0] id_rd_old_data_reg;
    wire [31:0] id_rs1_data;
    wire [31:0] id_rs2_data;
    wire [31:0] id_rd_old_data;

    wire id_ctrl_reg_write;
    wire id_ctrl_mem_read;
    wire id_ctrl_mem_write;
    wire id_ctrl_alu_src_a;
    wire id_ctrl_alu_src_b;
    wire id_ctrl_mem_to_reg;
    wire id_ctrl_branch;
    wire id_ctrl_jump;
    wire id_ctrl_use_rs1;
    wire id_ctrl_use_rs2;
    wire id_ctrl_use_rd;
    wire [3:0] id_alu_op;

    assign id_rs1 = if_id_instr[19:15];
    assign id_rs2 = if_id_instr[24:20];
    assign id_rd = if_id_instr[11:7];
    assign id_funct3 = if_id_instr[14:12];

    wire id_use_rs1 = if_id_valid && id_ctrl_use_rs1;
    wire id_use_rs2 = if_id_valid && id_ctrl_use_rs2;
    wire id_use_rd  = if_id_valid && id_ctrl_use_rd;

    imm_gen imm_gen_i (
        .instr(if_id_instr),
        .imm  (id_imm)
    );

    control_unit control_unit_i (
        .instr     (if_id_instr),
        .reg_write (id_ctrl_reg_write),
        .mem_read  (id_ctrl_mem_read),
        .mem_write (id_ctrl_mem_write),
        .alu_src_a (id_ctrl_alu_src_a),
        .alu_src_b (id_ctrl_alu_src_b),
        .mem_to_reg(id_ctrl_mem_to_reg),
        .branch    (id_ctrl_branch),
        .jump      (id_ctrl_jump),
        .use_rs1   (id_ctrl_use_rs1),
        .use_rs2   (id_ctrl_use_rs2),
        .use_rd    (id_ctrl_use_rd),
        .alu_op    (id_alu_op)
    );

    regfile regfile_i (
        .clk   (clk),
        .rst   (rst),
        .we    (mem_wb_valid && mem_wb_reg_write),
        .rs1   (id_rs1),
        .rs2   (id_rs2),
        .rs3   (id_rd),
        .rd    (mem_wb_rd),
        .wdata (mem_wb_write_data),
        .rdata1(id_rs1_data_reg),
        .rdata2(id_rs2_data_reg),
        .rdata3(id_rd_old_data_reg)
    );

    // The register file writes on the clock edge while ID/EX captures the
    // operands. Bypass the WB value so an instruction in ID observes a
    // writeback that occurs in the same cycle.
    assign id_rs1_data =
        (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 5'd0) &&
         (mem_wb_rd == id_rs1)) ?
        mem_wb_write_data : id_rs1_data_reg;
    assign id_rs2_data =
        (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 5'd0) &&
         (mem_wb_rd == id_rs2)) ?
        mem_wb_write_data : id_rs2_data_reg;
    assign id_rd_old_data =
        (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 5'd0) &&
         (mem_wb_rd == id_rd)) ?
        mem_wb_write_data : id_rd_old_data_reg;

    // ID/EX pipeline register.
    reg        id_ex_valid;
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_rs1_data;
    reg [31:0] id_ex_rs2_data;
    reg [31:0] id_ex_rd_old_data;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [4:0]  id_ex_rd;
    reg [2:0]  id_ex_funct3;
    reg        id_ex_reg_write;
    reg        id_ex_mem_read;
    reg        id_ex_mem_write;
    reg        id_ex_alu_src_a;
    reg        id_ex_alu_src_b;
    reg        id_ex_mem_to_reg;
    reg        id_ex_branch;
    reg        id_ex_jump;
    reg        id_ex_use_rs1;
    reg        id_ex_use_rs2;
    reg        id_ex_use_rd;
    reg [3:0]  id_ex_alu_op;

    wire load_use_stall;
    wire [1:0] forward_a;
    wire [1:0] forward_b;
    wire [1:0] forward_acc;
    reg [31:0] ex_rs1_forwarded;
    reg [31:0] ex_rs2_forwarded;
    reg [31:0] ex_rd_old_forwarded;
    wire [31:0] ex_alu_a;
    wire [31:0] ex_alu_b;
    wire [31:0] ex_alu_result;
    wire ex_zero;
    wire ex_lt_signed;
    wire ex_lt_unsigned;
    reg ex_branch_condition;
    wire ex_control_taken;
    wire [31:0] ex_control_target;

    hazard_unit hazard_unit_i (
        .id_ex_rd        (id_ex_rd),
        .id_ex_mem_read  (id_ex_mem_read),
        .if_id_rs1       (id_rs1),
        .if_id_rs2       (id_rs2),
        .if_id_rd        (id_rd),
        .if_id_use_rs1   (id_use_rs1),
        .if_id_use_rs2   (id_use_rs2),
        .if_id_use_rd    (id_use_rd),
        .load_use_stall  (load_use_stall)
    );

    // EX/MEM pipeline register.
    reg        ex_mem_valid;
    reg [31:0] ex_mem_result;
    reg [31:0] ex_mem_store_data;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_reg_write;
    reg        ex_mem_mem_read;
    reg        ex_mem_mem_write;
    reg        ex_mem_mem_to_reg;

    forwarding_unit forwarding_unit_i (
        .ex_rs1          (id_ex_rs1),
        .ex_rs2          (id_ex_rs2),
        .ex_rd_old       (id_ex_rd),
        .ex_use_rs1      (id_ex_use_rs1),
        .ex_use_rs2      (id_ex_use_rs2),
        .ex_use_rd       (id_ex_use_rd),
        .exmem_rd        (ex_mem_rd),
        .exmem_reg_write (ex_mem_reg_write),
        .exmem_mem_read  (ex_mem_mem_read),
        .memwb_rd        (mem_wb_rd),
        .memwb_reg_write (mem_wb_reg_write),
        .forward_a       (forward_a),
        .forward_b       (forward_b),
        .forward_acc     (forward_acc)
    );

    always @* begin
        ex_rs1_forwarded = id_ex_rs1_data;
        ex_rs2_forwarded = id_ex_rs2_data;
        ex_rd_old_forwarded = id_ex_rd_old_data;

        case (forward_a)
            2'b01: ex_rs1_forwarded = ex_mem_result;
            2'b10: ex_rs1_forwarded = mem_wb_write_data;
            default: ex_rs1_forwarded = id_ex_rs1_data;
        endcase
        case (forward_b)
            2'b01: ex_rs2_forwarded = ex_mem_result;
            2'b10: ex_rs2_forwarded = mem_wb_write_data;
            default: ex_rs2_forwarded = id_ex_rs2_data;
        endcase
        case (forward_acc)
            2'b01: ex_rd_old_forwarded = ex_mem_result;
            2'b10: ex_rd_old_forwarded = mem_wb_write_data;
            default: ex_rd_old_forwarded = id_ex_rd_old_data;
        endcase
    end

    assign ex_alu_a = id_ex_alu_src_a ? id_ex_pc : ex_rs1_forwarded;
    assign ex_alu_b = id_ex_alu_src_b ? id_ex_imm : ex_rs2_forwarded;

    alu alu_i (
        .a          (ex_alu_a),
        .b          (ex_alu_b),
        .acc        (ex_rd_old_forwarded),
        .op         (id_ex_alu_op),
        .result     (ex_alu_result),
        .zero       (ex_zero),
        .lt_signed  (ex_lt_signed),
        .lt_unsigned(ex_lt_unsigned)
    );

    always @* begin
        case (id_ex_funct3)
            3'b000: ex_branch_condition = ex_zero;
            3'b001: ex_branch_condition = !ex_zero;
            3'b100: ex_branch_condition = ex_lt_signed;
            3'b101: ex_branch_condition = !ex_lt_signed;
            default: ex_branch_condition = 1'b0;
        endcase
    end

    assign ex_control_taken =
        id_ex_valid &&
        ((id_ex_branch && ex_branch_condition) || id_ex_jump);
    assign ex_control_target = id_ex_pc + id_ex_imm;

    // MEM/WB pipeline register.
    wire [31:0] data_mem_index;
    wire [31:0] data_mem_read_data;

    assign mem_wb_write_data =
        mem_wb_mem_to_reg ? mem_wb_mem_data : mem_wb_result;
    assign data_mem_index = {22'b0, ex_mem_result[9:2]};
    assign data_mem_read_data = dmem[data_mem_index];

    wire flush_if_id;
    wire flush_id_ex;
    assign flush_if_id = ex_control_taken;
    assign flush_id_ex = ex_control_taken || load_use_stall;

    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'b0;
        end else if (load_use_stall) begin
            pc <= pc;
        end else if (ex_control_taken) begin
            pc <= ex_control_target;
        end else begin
            pc <= pc_plus4;
        end
    end

    always @(posedge clk) begin
        if (rst || flush_if_id) begin
            if_id_pc <= 32'b0;
            if_id_instr <= NOP;
            if_id_valid <= 1'b0;
        end else if (!load_use_stall) begin
            if_id_pc <= pc;
            if_id_instr <= if_instr;
            if_id_valid <= 1'b1;
        end
    end

    always @(posedge clk) begin
        if (rst || flush_id_ex) begin
            id_ex_valid <= 1'b0;
            id_ex_pc <= 32'b0;
            id_ex_rs1_data <= 32'b0;
            id_ex_rs2_data <= 32'b0;
            id_ex_rd_old_data <= 32'b0;
            id_ex_imm <= 32'b0;
            id_ex_rs1 <= 5'b0;
            id_ex_rs2 <= 5'b0;
            id_ex_rd <= 5'b0;
            id_ex_funct3 <= 3'b0;
            id_ex_reg_write <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_alu_src_a <= 1'b0;
            id_ex_alu_src_b <= 1'b0;
            id_ex_mem_to_reg <= 1'b0;
            id_ex_branch <= 1'b0;
            id_ex_jump <= 1'b0;
            id_ex_use_rs1 <= 1'b0;
            id_ex_use_rs2 <= 1'b0;
            id_ex_use_rd <= 1'b0;
            id_ex_alu_op <= `ALU_ADD;
        end else begin
            id_ex_valid <= if_id_valid;
            id_ex_pc <= if_id_pc;
            id_ex_rs1_data <= id_rs1_data;
            id_ex_rs2_data <= id_rs2_data;
            id_ex_rd_old_data <= id_rd_old_data;
            id_ex_imm <= id_imm;
            id_ex_rs1 <= id_rs1;
            id_ex_rs2 <= id_rs2;
            id_ex_rd <= id_rd;
            id_ex_funct3 <= id_funct3;
            id_ex_reg_write <= id_ctrl_reg_write;
            id_ex_mem_read <= id_ctrl_mem_read;
            id_ex_mem_write <= id_ctrl_mem_write;
            id_ex_alu_src_a <= id_ctrl_alu_src_a;
            id_ex_alu_src_b <= id_ctrl_alu_src_b;
            id_ex_mem_to_reg <= id_ctrl_mem_to_reg;
            id_ex_branch <= id_ctrl_branch;
            id_ex_jump <= id_ctrl_jump;
            id_ex_use_rs1 <= id_ctrl_use_rs1;
            id_ex_use_rs2 <= id_ctrl_use_rs2;
            id_ex_use_rd <= id_ctrl_use_rd;
            id_ex_alu_op <= id_alu_op;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            ex_mem_valid <= 1'b0;
            ex_mem_result <= 32'b0;
            ex_mem_store_data <= 32'b0;
            ex_mem_rd <= 5'b0;
            ex_mem_reg_write <= 1'b0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_write <= 1'b0;
            ex_mem_mem_to_reg <= 1'b0;
        end else begin
            ex_mem_valid <= id_ex_valid;
            ex_mem_result <= id_ex_jump ? (id_ex_pc + 32'd4) : ex_alu_result;
            ex_mem_store_data <= ex_rs2_forwarded;
            ex_mem_rd <= id_ex_rd;
            ex_mem_reg_write <= id_ex_reg_write;
            ex_mem_mem_read <= id_ex_mem_read;
            ex_mem_mem_write <= id_ex_mem_write;
            ex_mem_mem_to_reg <= id_ex_mem_to_reg;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            mem_wb_valid <= 1'b0;
            mem_wb_result <= 32'b0;
            mem_wb_mem_data <= 32'b0;
            mem_wb_rd <= 5'b0;
            mem_wb_reg_write <= 1'b0;
            mem_wb_mem_to_reg <= 1'b0;
        end else begin
            mem_wb_valid <= ex_mem_valid;
            mem_wb_result <= ex_mem_result;
            mem_wb_mem_data <= data_mem_read_data;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_reg_write <= ex_mem_reg_write;
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
        end
    end

    always @(posedge clk) begin
        if (ex_mem_valid && ex_mem_mem_write) begin
            dmem[data_mem_index] <= ex_mem_store_data;
        end
    end

`ifdef CPU_DEBUG
    always @(posedge clk) begin
        if (!rst && id_ex_valid &&
            ((id_ex_rd == 5'd12) || (id_ex_rs1 == 5'd12) || (id_ex_rs2 == 5'd12))) begin
            $display("DEBUG rd=%0d rs1=%0d rs2=%0d op=%b rs1_data=%h rs2_data=%h exmem_rd=%0d exmem=%h memwb_rd=%0d memwb=%h fwd_a=%b fwd_b=%b fwd_acc=%b alu_result=%h",
                     id_ex_rd, id_ex_rs1, id_ex_rs2, id_ex_alu_op,
                     id_ex_rs1_data, id_ex_rs2_data, ex_mem_rd, ex_mem_result,
                     mem_wb_rd, mem_wb_write_data, forward_a, forward_b,
                     forward_acc, ex_alu_result);
        end
    end
`endif
endmodule
