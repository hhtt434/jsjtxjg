`timescale 1ns/1ps

module tb_regfile;
    reg         clk;
    reg         rst;
    reg         we;
    reg  [4:0]  rs1;
    reg  [4:0]  rs2;
    reg  [4:0]  rs3;
    reg  [4:0]  rd;
    reg  [31:0] wdata;
    wire [31:0] rdata1;
    wire [31:0] rdata2;
    wire [31:0] rdata3;
    integer     errors;

    regfile dut (
        .clk   (clk),
        .rst   (rst),
        .we    (we),
        .rs1   (rs1),
        .rs2   (rs2),
        .rs3   (rs3),
        .rd    (rd),
        .wdata (wdata),
        .rdata1(rdata1),
        .rdata2(rdata2),
        .rdata3(rdata3)
    );

    task check_read;
        input [255:0] name;
        input [31:0] expected1;
        input [31:0] expected2;
        input [31:0] expected3;
        begin
            #1;
            if ((rdata1 !== expected1) ||
                (rdata2 !== expected2) ||
                (rdata3 !== expected3)) begin
                $display("FAIL: %0s r1=%h r2=%h r3=%h",
                         name, rdata1, rdata2, rdata3);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        errors = 0;
        rst = 1;
        we = 0;
        rs1 = 0;
        rs2 = 0;
        rs3 = 0;
        rd = 0;
        wdata = 0;
        #12;

        rst = 0;
        we = 1;
        rd = 5'd5;
        wdata = 32'hDEAD_BEEF;
        @(posedge clk);
        #1;
        we = 0;
        rs1 = 5'd5;
        rs3 = 5'd5;
        check_read("write_read", 32'hDEAD_BEEF, 32'd0, 32'hDEAD_BEEF);

        we = 1;
        rd = 5'd0;
        wdata = 32'hFFFF_FFFF;
        @(posedge clk);
        #1;
        we = 0;
        rs1 = 5'd0;
        rs3 = 5'd0;
        check_read("x0_remains_zero", 32'd0, 32'd0, 32'd0);

        if (errors == 0) begin
            $display("TEST PASS: tb_regfile");
        end else begin
            $display("TEST FAIL: tb_regfile (%0d errors)", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule
