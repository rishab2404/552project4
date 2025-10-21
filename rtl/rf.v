`timescale 1ns / 1ps
`default_nettype none
//-----------------------------------------------------
// Register File  (32 x 32-bit)
//-----------------------------------------------------
// • Two combinational read ports (rs1, rs2)
// • One synchronous write port (rd)
// • Register x0 is always hard-wired to 0
//-----------------------------------------------------
module rf (
    input  wire        clk,          // clock
    input  wire        rst,          // synchronous active-high reset
    input  wire        wen,          // write enable
    input  wire [4:0]  waddr,        // write register index (rd)
    input  wire [31:0] wdata,        // data to write
    input  wire [4:0]  raddr1,       // read address 1 (rs1)
    input  wire [4:0]  raddr2,       // read address 2 (rs2)
    output wire [31:0] rdata1,       // read data 1
    output wire [31:0] rdata2        // read data 2
);

    // 32 × 32-bit register array
    reg [31:0] mem [0:31];
    integer i;

    // synchronous write and reset
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                mem[i] = 32'd0;
        end else if (wen && (waddr != 5'd0)) begin
            mem[waddr] = wdata;      // writes rd ≠ x0 only
        end
    end

    // combinational read ports
    assign rdata1 = (raddr1 == 5'd0) ? 32'd0 : mem[raddr1];
    assign rdata2 = (raddr2 == 5'd0) ? 32'd0 : mem[raddr2];

endmodule
`default_nettype wire
