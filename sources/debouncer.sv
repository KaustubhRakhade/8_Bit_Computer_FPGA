`timescale 1ns / 1ps

module debouncer(
    input wire clock,     // 10MHz Clock
    input wire btn_in,  // Noisy physical button
    output reg btn_out  // Clean, debounced signal
);  
    reg [16:0] counter = 0;
    reg [15:0] history = 0;

    always @(posedge clock) begin
        // Sample every 1 ms = 100000 clock cycles
        if (counter == 99999) begin
            // button is ON if been held cleanly for 16ms
            btn_out <= (history == 16'hFFFF);
            history <= {history[14:0], btn_in};
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end
    end

endmodule