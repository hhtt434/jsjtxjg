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
    assign load_use_stall =
        id_ex_mem_read &&
        (id_ex_rd != 5'd0) &&
        ((if_id_use_rs1 && (id_ex_rd == if_id_rs1)) ||
         (if_id_use_rs2 && (id_ex_rd == if_id_rs2)) ||
         (if_id_use_rd  && (id_ex_rd == if_id_rd)));
endmodule

