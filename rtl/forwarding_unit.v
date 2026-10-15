module forwarding_unit (
    input  wire [4:0] ex_rs1,
    input  wire [4:0] ex_rs2,
    input  wire [4:0] ex_rd_old,
    input  wire       ex_use_rs1,
    input  wire       ex_use_rs2,
    input  wire       ex_use_rd,
    input  wire [4:0] exmem_rd,
    input  wire       exmem_reg_write,
    input  wire       exmem_mem_read,
    input  wire [4:0] memwb_rd,
    input  wire       memwb_reg_write,
    output reg  [1:0] forward_a,
    output reg  [1:0] forward_b,
    output reg  [1:0] forward_acc
);
    always @* begin
        forward_a   = 2'b00;
        forward_b   = 2'b00;
        forward_acc = 2'b00;

        if (ex_use_rs1) begin
            if (exmem_reg_write && !exmem_mem_read &&
                (exmem_rd != 5'd0) &&
                (exmem_rd == ex_rs1)) begin
                forward_a = 2'b01;
            end else if (memwb_reg_write && (memwb_rd != 5'd0) &&
                         (memwb_rd == ex_rs1)) begin
                forward_a = 2'b10;
            end
        end

        if (ex_use_rs2) begin
            if (exmem_reg_write && !exmem_mem_read &&
                (exmem_rd != 5'd0) &&
                (exmem_rd == ex_rs2)) begin
                forward_b = 2'b01;
            end else if (memwb_reg_write && (memwb_rd != 5'd0) &&
                         (memwb_rd == ex_rs2)) begin
                forward_b = 2'b10;
            end
        end

        if (ex_use_rd) begin
            if (exmem_reg_write && !exmem_mem_read &&
                (exmem_rd != 5'd0) &&
                (exmem_rd == ex_rd_old)) begin
                forward_acc = 2'b01;
            end else if (memwb_reg_write && (memwb_rd != 5'd0) &&
                         (memwb_rd == ex_rd_old)) begin
                forward_acc = 2'b10;
            end
        end
    end
endmodule
