`timescale 1ns / 1ps

module keypad_scanner (
    input wire clock,
    input wire [3:0] row,
    output reg [3:0] col,
    output reg [3:0] key_val,   // decoded key value
    output reg key_pressed
);

    localparam TIME_20MS   = 21'd2_000_000;
    localparam TIME_SETTLE = 21'd100;

    localparam SCAN       = 2'd0,
               DEBOUNCE_P = 2'd1,
               ACTIVE     = 2'd2,
               DEBOUNCE_R = 2'd3;

    reg [1:0] state = SCAN;
    reg [20:0] timer = 0;
    reg [1:0] col_idx = 0;
    reg [3:0] captured_row = 0;

    // Column Scan
    always @(*) begin
        case (col_idx)
            2'd0: col = 4'b0001;
            2'd1: col = 4'b0010;
            2'd2: col = 4'b0100;
            2'd3: col = 4'b1000;
            default: col = 4'b0000;
        endcase
    end

    // Key Decoding
    reg [3:0] raw_key_val;
    always @(*) begin
        case (col_idx)
            2'd0: case(captured_row) 
                    4'b0001: raw_key_val = 4'h1;
                    4'b0010: raw_key_val = 4'h4;
                    4'b0100: raw_key_val = 4'h7;
                    4'b1000: raw_key_val = 4'hE;
                    default: raw_key_val = 4'h0;
                  endcase
            2'd1: case(captured_row) 
                    4'b0001: raw_key_val = 4'h2;
                    4'b0010: raw_key_val = 4'h5;
                    4'b0100: raw_key_val = 4'h8;
                    4'b1000: raw_key_val = 4'h0;
                    default: raw_key_val = 4'h0;
                  endcase
            2'd2: case(captured_row) 
                    4'b0001: raw_key_val = 4'h3;
                    4'b0010: raw_key_val = 4'h6;
                    4'b0100: raw_key_val = 4'h9;
                    4'b1000: raw_key_val = 4'hF;
                    default: raw_key_val = 4'h0;
                  endcase
            2'd3: case(captured_row) 
                    4'b0001: raw_key_val = 4'hA;
                    4'b0010: raw_key_val = 4'hB;
                    4'b0100: raw_key_val = 4'hC;
                    4'b1000: raw_key_val = 4'hD;
                    default: raw_key_val = 4'h0;
                  endcase
            default: raw_key_val = 4'h0;
        endcase
    end

    // FSM and Debounce logic
    always @(posedge clock) begin
        case(state)
            SCAN: begin
                key_pressed <= 1'b0;
                if (timer < TIME_SETTLE) begin
                    timer <= timer + 1;
                end else begin
                    timer <= 0;
                    if (row != 4'b0000) begin
                        // A press is detected
                        captured_row <= row;
                        state <= DEBOUNCE_P;
                    end else begin
                        col_idx <= col_idx + 1;
                    end
                end
            end

            DEBOUNCE_P: begin
                if (timer < TIME_20MS) begin
                    timer <= timer + 1;
                end else begin
                    timer <= 0;
                    if (row == captured_row) begin
                        // Switch is stable
                        state <= ACTIVE;
                        key_pressed <= 1'b1;
                        key_val <= raw_key_val;
                    end else begin
                        // Switch is unstable
                        state <= SCAN;
                    end
                end
            end

            ACTIVE: begin
                if (row == 4'b0000) begin
                    state <= DEBOUNCE_R;
                    timer <= 0;
                end
            end

            DEBOUNCE_R: begin
                if (timer < TIME_20MS) begin
                    timer <= timer + 1;
                    if (row != 4'b0000) begin
                        // Switch is unstable
                        state <= ACTIVE;
                    end
                end else begin
                    key_pressed <= 1'b0;
                    state <= SCAN;
                    timer <= 0;
                end
            end

            default: state <= SCAN;
        endcase
    end

endmodule