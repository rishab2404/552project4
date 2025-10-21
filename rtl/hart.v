module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Instruction fetch goes through a read only instruction memory (imem)
    // port. The port accepts a 32-bit address (e.g. from the program counter)
    // per cycle and combinationally returns a 32-bit instruction word. This
    // is not representative of a realistic memory interface; it has been
    // modeled as more similar to a DFF or SRAM to simplify phase 3. In
    // later phases, you will replace this with a more realistic memory.
    //
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr,
    // Instruction word fetched from memory, available on the same cycle.
    input  wire [31:0] i_imem_rdata,
    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle. Reads are combinational - values are available immediately after
    // updating the address and asserting read enable. Writes occur on (and
    // are visible at) the next clock edge.
    //
    // Read/write address for the data memory. This should be 32-bit aligned
    // (i.e. the two LSB should be zero). See `o_dmem_mask` for how to perform
    // half-word and byte accesses at unaligned addresses.
    output wire [31:0] o_dmem_addr,
    // When asserted, the memory will perform a read at the aligned address
    // specified by `i_addr` and return the 32-bit word at that address
    // immediately (i.e. combinationally). It is illegal to assert this and
    // `o_dmem_wen` on the same cycle.
    output wire        o_dmem_ren,
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    //
    // To perform a half-word read at address 0x00001002, align `o_dmem_addr`
    // to 0x00001000, assert `o_dmem_ren`, and set the mask to 0b1100 to
    // indicate that only the upper two bytes should be read. Only the upper
    // two bytes of `i_dmem_rdata` can be assumed to have valid data; to
    // calculate the final value of the `lh[u]` instruction, shift the rdata
    // word right by 16 bits and sign/zero extend as appropriate.
    //
    // To perform a byte write at address 0x00002003, align `o_dmem_addr` to
    // `0x00002000`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction left by 24 bits to place it in the
    // appropriate byte lane.
    output wire [ 3:0] o_dmem_mask,
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // this will immediately reflect the contents of memory at the specified
    // address, for the bytes enabled by the mask. When read enable is not
    // asserted, or for bytes not set in the mask, the value is undefined.
    input  wire [31:0] i_dmem_rdata,
	// The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire        o_retire_valid,
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt,
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs1_raddr,
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs2_raddr,
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata,
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata,
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr,
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);
    // Fill in your implementation here.
   
     //====================================================
    // 1. Program Counter
    //====================================================
    wire [31:0] pc_curr;
    wire [31:0] pc_next;

    pc #(.RESET_ADDR(RESET_ADDR)) u_pc (
        .clk     (i_clk),
        .rst     (i_rst),
        .pc_next (pc_next),
        .pc_curr (pc_curr)
    );

    assign o_imem_raddr = pc_curr;
    assign o_retire_pc  = pc_curr;

    //====================================================
    // 2. Decode Stage
    //====================================================
    wire [6:0]  opcode;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    wire [4:0]  rs1_addr, rs2_addr, rd_addr;
    wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    decoder u_decoder (
        .inst   (i_imem_rdata),
        .opcode (opcode),
        .funct3 (funct3),
        .funct7 (funct7),
        .rs1    (rs1_addr),
        .rs2    (rs2_addr),
        .rd     (rd_addr),
        .imm_i  (imm_i),
        .imm_s  (imm_s),
        .imm_b  (imm_b),
        .imm_u  (imm_u),
        .imm_j  (imm_j)
    );

    //====================================================
    // 3. Register File
    //====================================================
    wire [31:0] rs1_data, rs2_data, rd_data;
    wire        reg_write_en;

    rf u_rf (
        .clk    (i_clk),
        .rst    (i_rst),
        .wen    (reg_write_en),
        .waddr  (rd_addr),
        .wdata  (rd_data),
        .raddr1 (rs1_addr),
        .raddr2 (rs2_addr),
        .rdata1 (rs1_data),
        .rdata2 (rs2_data)
    );

    // Retire interface mapping for testbench
    assign o_retire_rs1_raddr = rs1_addr;
    assign o_retire_rs1_rdata = rs1_data;
    assign o_retire_rs2_raddr = rs2_addr;
    assign o_retire_rs2_rdata = rs2_data;
    assign o_retire_rd_waddr  = rd_addr;
    assign o_retire_rd_wdata  = rd_data;

    //====================================================
    // 4. Control Unit
    //====================================================
    wire [3:0] alu_ctrl;
    wire       reg_write, mem_read, mem_write, mem_to_reg;
    wire       alu_src, branch, jump;

    control u_control (
        .i_opcode    (opcode),
        .i_funct3    (funct3),
        .i_funct7    (funct7),
        .o_alu_ctrl  (alu_ctrl),
        .o_reg_write (reg_write),
        .o_mem_read  (mem_read),
        .o_mem_write (mem_write),
        .o_mem_to_reg(mem_to_reg),
        .o_alu_src   (alu_src),
        .o_branch    (branch),
        .o_jump      (jump)
    );

    //====================================================
    // 5. Immediate Generator
    //====================================================
    wire [31:0] imm_out;

    imm_gen u_imm_gen (
        .i_instr (i_imem_rdata),
        .o_imm   (imm_out)
    );

    //====================================================
    // 6. ALU + Operand MUX
    //====================================================
    wire [31:0] alu_op2;
    wire [31:0] alu_result;
    wire        alu_zero;

    assign alu_op2 = (alu_src) ? imm_out : rs2_data;

    alu u_alu (
        .i_op1      (rs1_data),
        .i_op2      (alu_op2),
        .i_alu_ctrl (alu_ctrl),
        .o_result   (alu_result),
        .o_zero     (alu_zero)
    );

    //====================================================
    // 7. Data Memory Interface
    //====================================================
    assign o_dmem_addr  = alu_result;
    assign o_dmem_wdata = rs2_data;
    assign o_dmem_ren   = mem_read;
    assign o_dmem_wen   = mem_write;
    assign o_dmem_mask  = 4'b1111; // full 32-bit access for now

    //====================================================
    // 8. Writeback Stage
    //====================================================
    assign rd_data       = (mem_to_reg) ? i_dmem_rdata : alu_result;
    assign reg_write_en  = reg_write;

    //====================================================
    // 9. Branch / Jump / Next PC Logic
    //====================================================
    wire [31:0] pc_plus_4      = pc_curr + 32'd4;
    wire [31:0] branch_target  = pc_curr + imm_out;

    assign pc_next = (jump)                    ? branch_target :
                     (branch && alu_zero)      ? branch_target :
                     pc_plus_4;

    assign o_retire_next_pc = pc_next;

    //====================================================
    // 10. Retire / Halt / Trap
    //====================================================
    assign o_retire_inst  = i_imem_rdata;
    assign o_retire_valid = 1'b1;
    assign o_retire_trap  = 1'b0;
    assign o_retire_halt  = (opcode == 7'b1110011); // ebreak detection



endmodule

`default_nettype wire
