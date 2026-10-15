`ifndef RISCV_DEFS_VH
`define RISCV_DEFS_VH

`define ALU_ADD       4'b0000
`define ALU_SUB       4'b0001
`define ALU_SLL       4'b0010
`define ALU_SLT       4'b0011
`define ALU_SLTU      4'b0100
`define ALU_OR        4'b0101
`define ALU_AND       4'b0110
`define ALU_XOR       4'b0111
`define ALU_SRL       4'b1000
`define ALU_SRA       4'b1001
`define ALU_MAC       4'b1010
`define ALU_PASS_B    4'b1011

`define OPCODE_RTYPE  7'b0110011
`define OPCODE_ITYPE  7'b0010011
`define OPCODE_LOAD   7'b0000011
`define OPCODE_STORE  7'b0100011
`define OPCODE_BRANCH 7'b1100011
`define OPCODE_JAL    7'b1101111
`define OPCODE_LUI    7'b0110111
`define OPCODE_AUIPC  7'b0010111
`define OPCODE_MAC    7'b0001011

`endif

