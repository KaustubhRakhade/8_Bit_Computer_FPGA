`timescale 1ns / 1ps

// 8 x 8-bit Register Bank
module rbank (
    input wire clock,
    input wire reset,
    input wire [7:0] read_enable,  // One-hot encoded
    input wire [7:0] write_enable, // One-hot encoded
    inout wire [7:0] data
);

    reg [7:0] registers [0:7];
    integer i;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            for (i=0; i<8; i=i+1) registers[i] <= 8'd0;
        end else begin
            for (i=0; i<8; i=i+1) begin
                if (write_enable[i]) registers[i] <= data;
            end
        end
    end

    // Tristate Read Logic
    assign data = (read_enable[0]) ? registers[0] :
                  (read_enable[1]) ? registers[1] :
                  (read_enable[2]) ? registers[2] :
                  (read_enable[3]) ? registers[3] :
                  (read_enable[4]) ? registers[4] :
                  (read_enable[5]) ? registers[5] :
                  (read_enable[6]) ? registers[6] :
                  (read_enable[7]) ? registers[7] : 8'bz;

endmodule