`default_nettype none

//====================================================
// Immediate Generator for RV32I
//====================================================
// Generates the 32-bit immediate value for different
// instruction formats based on the opcode.
//====================================================
module imm_gen (
    input  wire [31:0] i_instr,     // full instruction word
    output reg  [31:0] o_imm        // sign-extended immediate
);

    wire [6:0] opcode;
    assign opcode = i_instr[6:0];

    always @(*) begin
        case (opcode)
            // I-type: imm[11:0] = instr[31:20]
            7'b0000011, // LOAD
            7'b0010011, // ALU immediate (ADDI, SLTI, etc.)
            7'b1100111: // JALR
                o_imm = {{20{i_instr[31]}}, i_instr[31:20]};

            // S-type: imm[11:0] = {instr[31:25], instr[11:7]}
            7'b0100011: // STORE
                o_imm = {{20{i_instr[31]}}, i_instr[31:25], i_instr[11:7]};

            // B-type: imm[12:1] = {instr[31], instr[7], instr[30:25], instr[11:8], 0}
            7'b1100011: // BRANCH
                o_imm = {{19{i_instr[31]}}, i_instr[31], i_instr[7],
                         i_instr[30:25], i_instr[11:8], 1'b0};

            // U-type: imm[31:12] = instr[31:12]
            7'b0110111, // LUI
            7'b0010111: // AUIPC
                o_imm = {i_instr[31:12], 12'd0};

            // J-type: imm[20:1] = {instr[31], instr[19:12], instr[20], instr[30:21], 0}
            7'b1101111: // JAL
                o_imm = {{11{i_instr[31]}}, i_instr[31], i_instr[19:12],
                         i_instr[20], i_instr[30:21], 1'b0};

            default:
                o_imm = 32'd0;
        endcase
    end

endmodule

`default_nettype wire
