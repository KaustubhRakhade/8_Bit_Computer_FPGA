`timescale 1ns / 1ps

// top module but in verilog instead of system verilog for block design
module top_verilog(
    input  clock, //100MHz onboard clock
    input  reset,

    input [1:0] prog_select,
    output [1:0] prog_leds,
    input btn_resume,
    output led_resume,

    //oled interface
    output oled_spi_clk,
    output oled_spi_data,
    output oled_vdd,
    output oled_vbat,
    output oled_reset_n,
    output oled_dc_n,

    input  [3:0] key_row,      // Inputs from keypad rows
    output [3:0] key_col       // Outputs to keypad columns
);

    top TOP(
        .clock(clock),
        .reset(reset),
        .prog_select(prog_select),
        .prog_leds(prog_leds),
        .btn_resume(btn_resume),
        .led_resume(led_resume),
        .oled_spi_clk(oled_spi_clk),
        .oled_spi_data(oled_spi_data),
        .oled_vdd(oled_vdd),
        .oled_vbat(oled_vbat),
        .oled_reset_n(oled_reset_n),
        .oled_dc_n(oled_dc_n),
        .key_row(key_row),
        .key_col(key_col)
    );

endmodule