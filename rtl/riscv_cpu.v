`include "riscv_defs.vh"

/*
 * 模块功能：五级流水线 RISC-V CPU 顶层。
 * 实现方式：把 IF、ID、EX、MEM、WB 五级组合逻辑与时序流水寄存器连接起来，
 * 实例化 ALU、控制单元、立即数生成器和寄存器堆，并实现转发、Load-use
 * 阻塞、分支跳转冲刷、访存和写回。
 */
module riscv_cpu #(
    parameter IMEM_WORDS = 256,
    parameter DMEM_WORDS = 256,
    parameter IMEM_INIT_FILE = "",
    parameter DMEM_INIT_FILE = ""
) (
    input wire clk,
    input wire rst,
    // 可观察调试输出：防止整个 CPU 在综合优化时因没有顶层输出而被删除。
    // 这些端口也便于综合后查看 PC、执行、访存、写回和冒险状态。
    output wire [31:0] debug_pc,
    output wire [31:0] debug_instr,
    output wire [31:0] debug_alu_result,
    output wire [31:0] debug_mem_read_data,
    output wire [31:0] debug_wb_write_data,
    output wire [31:0] debug_rs1_data,
    output wire [31:0] debug_rs2_data,
    output wire        debug_reg_write,
    output wire        debug_mem_write,
    output wire        debug_load_use_stall,
    output wire        debug_control_taken
);
    localparam [31:0] NOP = 32'h0000_0013;

    reg [31:0] imem [0:IMEM_WORDS-1];
    reg [31:0] dmem [0:DMEM_WORDS-1];
    integer init_index;

    // 初始化指令和数据存储器；测试平台通过参数指定 $readmemh 程序文件。
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

    // IF 阶段：PC 加 4 形成顺序地址，PC 字地址索引指令存储器。
    assign pc_plus4 = pc + 32'd4;
    assign if_mem_index = {22'b0, pc[9:2]};
    assign if_instr = imem[if_mem_index];

    // IF/ID 流水寄存器：保存取出的指令、对应 PC 和有效标志。
    reg [31:0] if_id_pc;
    reg [31:0] if_id_instr;
    reg        if_id_valid;

    // MEM/WB 流水寄存器提前声明，因为寄存器堆写回端口会在下方直接使用这些信号。
    reg        mem_wb_valid;
    reg [31:0] mem_wb_result;
    reg [31:0] mem_wb_mem_data;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_reg_write;
    reg        mem_wb_mem_to_reg;
    wire [31:0] mem_wb_write_data;

    // 从 IF/ID 指令中拆分字段，供寄存器读取、控制译码和冒险检测使用。
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

    // 只有有效指令实际使用的源寄存器才参与 Load-use 和转发判断。
    wire id_use_rs1 = if_id_valid && id_ctrl_use_rs1;
    wire id_use_rs2 = if_id_valid && id_ctrl_use_rs2;
    wire id_use_rd  = if_id_valid && id_ctrl_use_rd;

    // ID 阶段立即数生成器：把不同指令格式转换为统一的 32 位立即数。
    imm_gen imm_gen_i (
        .instr(if_id_instr),
        .imm  (id_imm)
    );

    // ID 阶段控制单元：根据指令编码产生各级控制信号和 ALU 操作码。
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

    // 寄存器堆：两路普通读口加一路旧 rd 读口，写口来自 WB 阶段。
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

    // WB 到 ID 的同拍旁路：寄存器堆写发生在时钟边沿，而 ID/EX 也在同一
    // 边沿采样，因此当前 ID 指令需要直接观察本周期 WB 的写回数据。
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

    // ID/EX 流水寄存器：保存译码后的源数据、立即数、寄存器编号和控制信号。
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

    // EX 阶段转发选择、ALU 操作数、执行结果和分支跳转控制信号。
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

    // Load-use 检测：判断 ID 阶段指令是否依赖 EX 阶段尚未返回的 Load 数据。
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

    // EX/MEM 流水寄存器：保存执行结果、存储数据、目的寄存器和 MEM/WB 控制。
    reg        ex_mem_valid;
    reg [31:0] ex_mem_result;
    reg [31:0] ex_mem_store_data;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_reg_write;
    reg        ex_mem_mem_read;
    reg        ex_mem_mem_write;
    reg        ex_mem_mem_to_reg;

    // 转发单元：比较 EX 源寄存器与 EX/MEM、MEM/WB 目的寄存器，选择最新数据。
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

    // 根据 forward_a、forward_b、forward_acc 选择 EX 实际使用的三个操作数。
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

    // A 口可选择 rs1 或 PC，B 口可选择 rs2 或立即数。
    assign ex_alu_a = id_ex_alu_src_a ? id_ex_pc : ex_rs1_forwarded;
    assign ex_alu_b = id_ex_alu_src_b ? id_ex_imm : ex_rs2_forwarded;

    // EX 执行单元：完成算术、逻辑、比较、移位和定制乘累加。
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

    // 根据分支 funct3 把 ALU 的零标志、有符号比较结果转换成分支条件。
    always @* begin
        case (id_ex_funct3)
            3'b000: ex_branch_condition = ex_zero;
            3'b001: ex_branch_condition = !ex_zero;
            3'b100: ex_branch_condition = ex_lt_signed;
            3'b101: ex_branch_condition = !ex_lt_signed;
            default: ex_branch_condition = 1'b0;
        endcase
    end

    // 分支命中或 jal 命中时，控制流重定向到 PC 与立即数之和。
    assign ex_control_taken =
        id_ex_valid &&
        ((id_ex_branch && ex_branch_condition) || id_ex_jump);
    assign ex_control_target = id_ex_pc + id_ex_imm;

    // MEM 阶段访存地址和读数据，以及 WB 阶段写回数据选择。
    wire [31:0] data_mem_index;
    wire [31:0] data_mem_read_data;

    assign mem_wb_write_data =
        mem_wb_mem_to_reg ? mem_wb_mem_data : mem_wb_result;
    assign data_mem_index = {22'b0, ex_mem_result[9:2]};
    assign data_mem_read_data = dmem[data_mem_index];

    // 控制冒险命中时冲刷错误路径；Load-use 时只清空 ID/EX 插入气泡。
    wire flush_if_id;
    wire flush_id_ex;
    assign flush_if_id = ex_control_taken;
    assign flush_id_ex = ex_control_taken || load_use_stall;

    // PC 时序更新：复位清零，Load-use 保持，控制流命中跳转，否则顺序加 4。
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

    // IF/ID 时序更新：控制流命中时清空，Load-use 时保持，否则锁存新指令。
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

    // ID/EX 时序更新：复位、控制流冲刷或 Load-use 气泡时清空，否则锁存译码信息。
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

    // EX/MEM 时序更新：保存执行结果、转发的存储数据和控制信号。
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

    // MEM/WB 时序更新：选择 Load 数据或 ALU 结果，并保留写回控制信息。
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

    // 数据存储器写端口：仅当 EX/MEM 中是有效 sw 指令时写入。
    always @(posedge clk) begin
        if (ex_mem_valid && ex_mem_mem_write) begin
            dmem[data_mem_index] <= ex_mem_store_data;
        end
    end

`ifdef CPU_DEBUG
    // 可选调试输出：只有定义 CPU_DEBUG 时才打印 x12 相关流水线信号。
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

    /*
     * 功能：把内部关键信号连接到顶层调试端口。
     * 实现方式：直接观测 PC、当前指令、ALU 结果、访存、写回、源操作数和
     * 冒险状态。这样综合工具不会把“没有输出”的整个处理器优化为空设计。
     */
    assign debug_pc = pc;
    assign debug_instr = if_instr;
    assign debug_alu_result = ex_alu_result;
    assign debug_mem_read_data = data_mem_read_data;
    assign debug_wb_write_data = mem_wb_write_data;
    assign debug_rs1_data = id_rs1_data;
    assign debug_rs2_data = id_rs2_data;
    assign debug_reg_write = mem_wb_valid && mem_wb_reg_write;
    assign debug_mem_write = ex_mem_valid && ex_mem_mem_write;
    assign debug_load_use_stall = load_use_stall;
    assign debug_control_taken = ex_control_taken;
endmodule
