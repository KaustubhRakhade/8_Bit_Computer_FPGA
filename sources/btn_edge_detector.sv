`timescale 1ns / 1ps

module btn_edge_detector (
    input wire clock,     // 100MHz clock
    input wire btn_in,    // Raw button input
    output reg click_out  // Clean, 1-cycle wide pulse
);

    reg prev_btn_out = 0;
    wire btn_out;

    debouncer btn_debouncer(
        .clock(clock),
        .btn_in(btn_in),
        .btn_out(btn_out)
    );

    always @(posedge clock) begin
        prev_btn_out <= btn_out;
        click_out <= (btn_out == 1'b1 && prev_btn_out == 1'b0);
    end

endmodule