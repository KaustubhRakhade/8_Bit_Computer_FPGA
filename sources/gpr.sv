`timescale 1ns / 1ps

// General Purpose Register (for Accumulator, Data Register, etc.)
module gpr (
    input wire clock,
    input wire reset,
    input wire read_enable,
    input wire write_enable,
    inout wire [7:0] data,   // Bi-directional Bus
    output reg [7:0] value   // Permanent output
);

    always @(posedge clock or posedge reset) begin
        if (reset) value <= 0;
        else if (write_enable) value <= data;
    end

    // Tristate Bus Driver
    assign data = (read_enable) ? value : 8'bz;

endmodule