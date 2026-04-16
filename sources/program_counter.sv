`timescale 1ns / 1ps

// Program counter supports increment and jumps (using write)
module program_counter (
    input wire clock,
    input wire reset,
    input wire read_enable,  // Output to Bus
    input wire write_enable, // Input from Bus (Jump)
    input wire increment,
    inout wire [7:0] data,   // Bi-directional Bus
    output reg [7:0] value   // Permanent output
);

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            value <= 0;
        end else if (write_enable) begin
            value <= data;
        end else if (increment) begin
            value <= value + 1;
        end
    end

    assign data = (read_enable) ? value : 8'bz;

endmodule