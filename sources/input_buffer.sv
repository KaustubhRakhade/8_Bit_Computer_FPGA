`timescale 1ns / 1ps

// stores the last 2 keys pressed on the keypad
module input_buffer (
    input wire clock,
    input wire flush,          // to clear the buffer
    input wire read_en,
    input wire [3:0] row, 
    output wire [3:0] col,
    output wire [7:0] buffer
);

    wire key_pressed;
    reg prev_key_pressed = 1'b0;
    
    wire [3:0] current_key_val;
    reg [7:0] internal_buffer = 8'h00;

    keypad_scanner scanner_inst (
        .clock(clock),
        .row(row),
        .col(col),
        .key_val(current_key_val),
        .key_pressed(key_pressed)
    );

    always @(posedge clock) begin
        // to detect the rising edge
        prev_key_pressed <= key_pressed;

        if (flush) begin
            internal_buffer <= 8'b0000_0000;
        end else if (key_pressed == 1'b1 && prev_key_pressed == 1'b0) begin
            // shift the buffer
            internal_buffer <= {internal_buffer[3:0], current_key_val};
        end
    end

    assign buffer = read_en ? internal_buffer : 8'bzzzz_zzzz;

endmodule