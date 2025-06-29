`timescale 1ps/1ps

module regs(input clk,
    input [3:0]raddr0_, output [15:0]rdata0,
    input [3:0]raddr1_, output [15:0]rdata1,
    input wen, input [3:0]waddr, input [15:0]wdata);

    reg [15:0]data[0:15];

    reg [3:0]raddr0;
    reg [3:0]raddr1;

    assign rdata0 = data[raddr0];
    assign rdata1 = data[raddr1];

    //data for testing only
    wire [15:0]r0 = data[0];
    wire [15:0]r1 = data[1];
    wire [15:0]r2 = data[2];
    wire [15:0]r3 = data[3];
    wire [15:0]r4 = data[4];
    wire [15:0]r5 = data[5];
    wire [15:0]r6 = data[6];
    wire [15:0]r7 = data[7];
    wire [15:0]r8 = data[8];
    wire [15:0]r9 = data[9];
    wire [15:0]r10 = data[10];
    wire [15:0]r11 = data[11];
    wire [15:0]r12 = data[12];
    wire [15:0]r13 = data[13];
    wire [15:0]r14 = data[14];
    wire [15:0]r15 = data[15];

    always @(posedge clk) begin
        raddr0 <= raddr0_;
        raddr1 <= raddr1_;
        if (wen) begin
            data[waddr] <= wdata;
        end
    end

endmodule
