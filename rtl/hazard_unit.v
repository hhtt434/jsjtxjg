/*
 * 模块功能：Load-use 数据冒险检测。
 * 实现方式：如果 ID/EX 中是一条 Load，而当前 IF/ID 指令马上使用该 Load
 * 的 rd，则输出阻塞信号。mac 的旧 rd 也被作为隐式源操作数参与比较。
 */
module hazard_unit (
    input  wire [4:0] id_ex_rd,
    input  wire       id_ex_mem_read,
    input  wire [4:0] if_id_rs1,
    input  wire [4:0] if_id_rs2,
    input  wire [4:0] if_id_rd,
    input  wire       if_id_use_rs1,
    input  wire       if_id_use_rs2,
    input  wire       if_id_use_rd,
    output wire       load_use_stall
);
    // Load 结果在 MEM 阶段之后才可用，因此紧邻消费者必须停顿一拍。
    assign load_use_stall =
        id_ex_mem_read &&
        (id_ex_rd != 5'd0) &&
        ((if_id_use_rs1 && (id_ex_rd == if_id_rs1)) ||
         (if_id_use_rs2 && (id_ex_rd == if_id_rs2)) ||
         (if_id_use_rd  && (id_ex_rd == if_id_rd)));
endmodule

