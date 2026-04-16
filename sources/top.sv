`timescale 1ns / 1ps

module top(
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

    `include "include.sv"
    
    // 4 rows of 21 characters (84 characters total for the 6-pixel wide font)
    // Row 1: "Design Lab  |  E&ECE " (21 chars)
    // Row 2: "                     " (21 chars)
    // Row 3: "Enter value: 00 (000)" (21 chars)
    // Row 4: "CPU Out: 000         " (21 chars)
    //                    "[                   ][                   ][                   ][                   ]"
    localparam myString = "Design Lab  |  E&ECE                                           CPU Out: 000         ";   
    localparam StringLen = 84;

    localparam run_str   = "Running...           ";
    localparam wait_str  = "Sleeping...          ";
    localparam exit_str  = "Program finished.    ";
    localparam pause_str = "Press > to continue  ";
    localparam input_str = "Enter value: 00 (000)";

    wire inp_flush;
    wire inp_re;
    wire [7:0] bus;
    wire [2:0] status;
 
    reg [1:0] state;
    reg [7:0] sendData;
    reg sendDataValid;
    reg [6:0] byteCounter;
    wire sendDone;
 
    localparam IDLE = 'd0,
               SEND = 'd1,
               DONE = 'd2;

    wire [7:0] print_reg;

    wire resume_btn_click;

    btn_edge_detector resume_btn_edge (
        .clock(clock),
        .btn_in(btn_resume),
        .click_out(resume_btn_click)
    );
    
    assign led_resume = btn_resume;
    assign prog_leds = prog_select;

    cpu my_cpu (
        .clock(clock),
        .reset(reset),
        .prog_select(prog_select),
        .btn_resume(resume_btn_click),
        .print_reg(print_reg),
        .inp_re(inp_re),
        .inp_flush(inp_flush),
        .bus(bus),
        .status(status)
    );

    input_buffer INP (
        .clock(clock),
        .row(key_row),
        .col(key_col),
        .flush(inp_flush),
        .read_en(inp_re),
        .buffer(bus)
    );
    
    reg [7:0] prev_print_reg = 0;
    reg [2:0] prev_status = STATUS_RUN;
    reg [7:0] display_val = 0;
    reg [7:0] prev_bus = 0;
    reg [7:0] display_bus = 0;
    
    // Decimal digits for the print register value
    wire [7:0] ascii_hundreds = (display_val / 100) + 8'h30;
    wire [7:0] ascii_tens     = ((display_val % 100) / 10) + 8'h30;
    wire [7:0] ascii_ones     = (display_val % 10) + 8'h30;

    // Hex and decimal digits for the hex input (which is connected to bus)
    wire [7:0] bus_ascii_hex_msb  = (display_bus[7:4] > 9) ? (display_bus[7:4] + 8'h37) : (display_bus[7:4] + 8'h30);
    wire [7:0] bus_ascii_hex_lsb  = (display_bus[3:0] > 9) ? (display_bus[3:0] + 8'h37) : (display_bus[3:0] + 8'h30);
    wire [7:0] bus_ascii_hundreds = (display_bus / 100) + 8'h30;
    wire [7:0] bus_ascii_tens     = ((display_bus % 100) / 10) + 8'h30;
    wire [7:0] bus_ascii_ones     = (display_bus % 10) + 8'h30;
 
    always @(posedge clock) begin
        if(reset) begin
            state <= IDLE;
            byteCounter <= StringLen;
            sendDataValid <= 1'b0;
            prev_print_reg <= 0;
            prev_status <= STATUS_RUN;
            display_val <= 0;
        end
        else begin
            case(state)
                IDLE: begin
                    if(!sendDone) begin
                        // Inject dynamic ASCII into the string

                        // text for row 3
                        if (byteCounter > 21 && byteCounter <= 42) begin
                            if (prev_status == STATUS_INPUT && byteCounter == 29) sendData <= bus_ascii_hex_msb;
                            else if (prev_status == STATUS_INPUT && byteCounter == 28) sendData <= bus_ascii_hex_lsb;
                            else if (prev_status == STATUS_INPUT && byteCounter == 25) sendData <= bus_ascii_hundreds;
                            else if (prev_status == STATUS_INPUT && byteCounter == 24) sendData <= bus_ascii_tens;
                            else if (prev_status == STATUS_INPUT && byteCounter == 23) sendData <= bus_ascii_ones;
                            else begin
                                case (prev_status)
                                    STATUS_WAIT:  sendData <= wait_str[(byteCounter*8-169)-:8];
                                    STATUS_EXIT:  sendData <= exit_str[(byteCounter*8-169)-:8];
                                    STATUS_INPUT: sendData <= input_str[(byteCounter*8-169)-:8];
                                    STATUS_PAUSE: sendData <= pause_str[(byteCounter*8-169)-:8];
                                    default:      sendData <= run_str[(byteCounter*8-169)-:8];
                                endcase
                            end
                        end

                        // "000" is located at indices 12, 11, and 10.
                        else if (byteCounter == 12)
                            sendData <= ascii_hundreds;
                        else if (byteCounter == 11)
                            sendData <= ascii_tens;
                        else if (byteCounter == 10)
                            sendData <= ascii_ones;

                        // Default to static string
                        else
                            sendData <= myString[(byteCounter*8-1)-:8];

                        sendDataValid <= 1'b1;
                        state <= SEND;
                    end
                end
                
                SEND: begin
                    if(sendDone) begin
                        sendDataValid <= 1'b0;
                        if(byteCounter != 1) begin
                            byteCounter <= byteCounter - 1;
                            state <= IDLE;
                        end else begin
                            state <= DONE;
                        end
                    end
                end
                
                DONE: begin
                    // Trigger a screen redraw ONLY when something changes
                    if (print_reg != prev_print_reg || status != prev_status || (status == STATUS_INPUT && bus != prev_bus)) begin
                        prev_print_reg <= print_reg;
                        prev_status <= status;
                        prev_bus <= bus;
                        
                        display_val <= print_reg;
                        display_bus <= bus;           
                        display_val <= print_reg;      
                        byteCounter <= StringLen;      
                        state <= IDLE;                  
                    end
                end
            endcase
        end
    end
 
    oledControl OC(
        .clock(clock),
        .reset(reset),
        .oled_spi_clk(oled_spi_clk),
        .oled_spi_data(oled_spi_data),
        .oled_vdd(oled_vdd),
        .oled_vbat(oled_vbat),
        .oled_reset_n(oled_reset_n),
        .oled_dc_n(oled_dc_n),
        .sendData(sendData),
        .sendDataValid(sendDataValid),
        .sendDone(sendDone)
    );    
    
endmodule