`timescale 1ns / 1ps

// CODE SOURCE: https://github.com/vipinkmenon/ZynqOLED
// Based on tutorial: https://www.youtube.com/playlist?list=PLpZTg2luX5lg1mydl0sKW77uP96yaeM3a
// MODIFIED to use counter instead of clock divider

// Module to communicate with the OLED using Serial Peripheral Interface (SPI)
module spiControl(
    input  clock, //On-board Zynq clock (100 MHz)
    input  reset,
    input [7:0] data_in,
    input  load_data, //Signal indicates new data for transmission
    output reg done_send,//Signal indicates data has been sent over spi interface
    output     spi_clock,//10MHz max
    output reg spi_data
);
    
    reg [3:0] counter = 0; 
    reg [2:0] dataCount;
    reg [7:0] shiftReg;
    reg [1:0] state;
    reg CE;
    
    // 10MHz Enable Pulse Generation
    always @(posedge clock) begin
        if (reset)
            counter <= 0;
        else if (counter == 9)
            counter <= 0;
        else
            counter <= counter + 1;
    end
    
    wire tick = (counter == 9);
    
    // SPI Clock Generation
    assign spi_clock = (CE) ? ((counter < 5) ? 1'b0 : 1'b1) : 1'b1;
    
    localparam IDLE = 'd0,
               SEND = 'd1,
               DONE = 'd2;
    
    always @(posedge clock) begin
        if(reset) begin
            state <= IDLE;
            dataCount <= 0;
            done_send <= 1'b0;
            CE <= 0;
            spi_data <= 1'b1;
        end
        else begin
            if (tick) begin 
                case(state)
                    IDLE: begin
                        if(load_data) begin
                            shiftReg <= data_in;
                            state <= SEND;
                            dataCount <= 0;
                        end
                    end
                    SEND: begin
                        spi_data <= shiftReg[7];
                        shiftReg <= {shiftReg[6:0], 1'b0};
                        CE <= 1;
                        if(dataCount != 7)
                            dataCount <= dataCount + 1;
                        else
                            state <= DONE;
                    end
                    DONE: begin
                        CE <= 0;
                        done_send <= 1'b1;
                        if(!load_data) begin
                            done_send <= 1'b0;
                            state <= IDLE;
                        end
                    end
                endcase
            end
        end
    end   
    
endmodule