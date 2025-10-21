`timescale 1ns / 1ps
`default_nettype none

module decoder (
    input  wire [31:0] inst,       // full instruction word

    output wire [6:0]  opcode,     // bits [6:0]
    output wire [2:0]  funct3,     // bits [14:12]
    output wire [6:0]  funct7,     // bits [31:25]
    output wire [4:0]  rs1,        // bits [19:15]
    output wire [4:0]  rs2,        // bits [24:20]
    output wire [4:0]  rd,         // bits [11:7]
    output wire [31:0] imm_i,      // sign-extended immediate for I-type
    output wire [31:0] imm_s,      // sign-extended immediate for S-type
    output wire [31:0] imm_b,      // sign-extended immediate for B-type
    output wire [31:0] imm_u,      // sign-extended immediate for U-type
    output wire [31:0] imm_j       // sign-extended immediate for J-type
);

    //-------------------------------------------------
    // basic field extraction
    //-------------------------------------------------
    assign opcode = inst[6:0];
    assign rd     = inst[11:7];
    assign funct3 = inst[14:12];
    assign rs1    = inst[19:15];
    assign rs2    = inst[24:20];
    assign funct7 = inst[31:25];

    //-------------------------------------------------
    // immediates (sign-extended)
    //-------------------------------------------------
    assign imm_i = {{20{inst[31]}}, inst[31:20]};

    assign imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};

    assign imm_b = {{19{inst[31]}}, inst[31], inst[7],
                    inst[30:25], inst[11:8], 1'b0};

    assign imm_u = {inst[31:12], 12'd0};

    assign imm_j = {{11{inst[31]}}, inst[31],
                    inst[19:12], inst[20], inst[30:21], 1'b0};

endmodule
`default_nettype wire
