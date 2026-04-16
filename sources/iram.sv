`timescale 1ns / 1ps

// Instruction RAM with 4 programs loaded
module iram (
    input wire clock,
    input wire reset,
    input wire [1:0] prog_select,  
    input wire [7:0] address,
    inout wire [7:0] data,
    input wire read_enable,
    input wire write_enable
);

    reg [1:0] active_prog;

    // Latch prog_select on reset
    always @(posedge clock) begin
        if (reset) begin
            active_prog <= prog_select;
        end
    end

    reg [7:0] bank0 [0:255];
    reg [7:0] bank1 [0:255];
    reg [7:0] bank2 [0:255];
    reg [7:0] bank3 [0:255];

    initial begin
        $readmemh("prog0.mem", bank0);
        $readmemh("prog1.mem", bank1);
        $readmemh("prog2.mem", bank2);
        $readmemh("prog3.mem", bank3);
    end

    // Write logic
    always @(posedge clock) begin
        if (write_enable) begin
            case (active_prog)
                2'b00: bank0[address] <= data;
                2'b01: bank1[address] <= data;
                2'b10: bank2[address] <= data;
                2'b11: bank3[address] <= data;
            endcase
        end
    end

    // Read logic
    reg [7:0] mem_out;
    always @(*) begin
        case (active_prog)
            2'b00: mem_out = bank0[address];
            2'b01: mem_out = bank1[address];
            2'b10: mem_out = bank2[address];
            2'b11: mem_out = bank3[address];
        endcase
    end

    // Tristate Bus Driver
    assign data = (read_enable) ? mem_out : 8'bz;

endmodule