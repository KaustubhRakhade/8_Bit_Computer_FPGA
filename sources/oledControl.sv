`timescale 1ns / 1ps

// CODE SOURCE: https://github.com/vipinkmenon/ZynqOLED
// Based on tutorial: https://www.youtube.com/playlist?list=PLpZTg2luX5lg1mydl0sKW77uP96yaeM3a
// MODIFIED to remove some bugs, clear stray pixels and use 8*6 bitmaps

// Module to start the OLED and provide an interface to display text (21*4 = 84 chars)
module oledControl(
    input  clock, //100MHz onboard clock
    input  reset,
    //oled interface
    output wire oled_spi_clk,
    output wire oled_spi_data,
    output reg oled_vdd,
    output reg oled_vbat,
    output reg oled_reset_n,
    output reg oled_dc_n,
    //
    input [7:0] sendData,
    input       sendDataValid,
    output reg  sendDone
);

    localparam charWidth = 6;
    localparam charsInARow = 128 / charWidth;
    localparam wrapColumnAddr = charWidth * charsInARow;

    reg [4:0] state;
    reg [4:0] nextState;
    reg startDelay;
    reg [7:0] spiData;
    reg spiLoadData;
    wire delayDone;
    wire spiDone;
    reg [1:0] currPage;
    wire [charWidth*8-1:0] charBitMap;
    reg [7:0] columnAddr;
    reg [3:0] byteCounter;

    reg [1:0] clearPage;
    reg [6:0] clearCol;


    localparam  IDLE  = 'd0,
                DELAY = 'd1,
                INIT  = 'd2,
                RESET = 'd3,
                CHRG_PUMP = 'd4,
                CHRG_PUMP1 = 'd5,
                WAIT_SPI = 'd6,
                PRE_CHRG = 'd7,
                PRE_CHRG1 = 'd8,
                VBAT_ON = 'd9,
                CONTRAST = 'd10,
                CONTRAST1 = 'd11,
                SEG_REMAP = 'd12,
                SCAN_DIR = 'd13,
                COM_PIN = 'd14,
                COM_PIN1 = 'd15,
                DISPLAY_ON = 'd16,
                FULL_DISPLAY = 'd17,
                DONE = 'd18,
                PAGE_ADDR = 'd19,
                PAGE_ADDR1 = 'd20,
                PAGE_ADDR2 = 'd21,
                COLUMN_ADDR = 'd22,
                COLUMN_ADDR1 = 'd23,
                SEND_DATA = 'd24,
                CLEAR_PAGE = 'd25,
                CLEAR_PAGE1 = 'd26,
                CLEAR_PAGE2 = 'd27,
                CLEAR_COL = 'd28,
                CLEAR_COL1 = 'd29,
                CLEAR_DATA = 'd30;


    always @(posedge clock)
    begin
        if (reset)
        begin
            state <= IDLE;
            nextState <= IDLE;
            oled_vdd <= 1'b1;
            oled_vbat <= 1'b1;
            oled_reset_n <= 1'b1;
            oled_dc_n <= 1'b1;
            startDelay <= 1'b0;
            spiData <= 8'd0;
            spiLoadData <= 1'b0;
            currPage <= 0;
            sendDone <= 0;
            columnAddr <= 0;
            clearPage <= 0;
            clearCol <= 0; 
        end
        else
        begin
            case(state)
                IDLE: begin
                    oled_vbat <= 1'b1;
                    oled_reset_n <= 1'b1;
                    oled_dc_n <= 1'b0;
                    oled_vdd <= 1'b0;
                    state <= DELAY;
                    nextState <= INIT;
                end
                DELAY: begin
                    startDelay <= 1'b1;
                    if (delayDone)
                    begin
                        state <= nextState;
                        startDelay <= 1'b0;
                    end
                end
                INIT: begin
                    spiData <= 'hAE;
                    spiLoadData <= 1'b1;
                    if (spiDone)
                    begin
                        spiLoadData <= 1'b0;
                        oled_reset_n <= 1'b0;
                        state <= DELAY;
                        nextState <= RESET;
                    end
                end
                RESET: begin
                    oled_reset_n <= 1'b1;
                    state <= DELAY;
                    nextState <= CHRG_PUMP;
                end
                CHRG_PUMP: begin
                    spiData <= 'h8D;
                    spiLoadData <= 1'b1;
                    if (spiDone)
                    begin
                        spiLoadData <= 1'b0;
                        state <= WAIT_SPI;
                        nextState <= CHRG_PUMP1;
                    end
                end
                WAIT_SPI: begin
                    if (!spiDone)
                    begin
                        state <= nextState;
                    end
                end
                CHRG_PUMP1: begin
                    spiData <= 'h14;
                    spiLoadData <= 1'b1;
                    if (spiDone)
                    begin
                        spiLoadData <= 1'b0;
                        state <= WAIT_SPI;
                        nextState <= PRE_CHRG;
                    end
                end
                PRE_CHRG: begin
                    spiData <= 'hD9;
                    spiLoadData <= 1'b1;
                    if (spiDone)
                    begin
                        spiLoadData <= 1'b0;
                        state <= WAIT_SPI;
                        nextState <= PRE_CHRG1;
                    end
                end
                PRE_CHRG1: begin
                spiData <= 'hF1;
                spiLoadData <= 1'b1;
                if (spiDone)
                begin
                    spiLoadData <= 1'b0;
                    state <= WAIT_SPI;
                    nextState <= VBAT_ON;
                end
                end            
                VBAT_ON: begin
                    oled_vbat <= 1'b0;
                    state <= DELAY;
                    nextState <= CONTRAST;
                end
                CONTRAST: begin
                spiData <= 'h81;
                spiLoadData <= 1'b1;
                if (spiDone)
                begin
                    spiLoadData <= 1'b0;
                    state <= WAIT_SPI;
                    nextState <= CONTRAST1;
                end
                end  
                CONTRAST1: begin
                spiData <= 'hFF;
                spiLoadData <= 1'b1;
                if (spiDone)
                begin
                    spiLoadData <= 1'b0;
                    state <= WAIT_SPI;
                    nextState <= SEG_REMAP;
                end
                end            
                SEG_REMAP: begin
                spiData <= 'hA0;
                spiLoadData <= 1'b1;
                if (spiDone)
                begin
                    spiLoadData <= 1'b0;
                    state <= WAIT_SPI;
                    nextState <= SCAN_DIR;
                end
                end 
                SCAN_DIR: begin
                spiData <= 'hC0;
                spiLoadData <= 1'b1;
                if (spiDone)
                begin
                    spiLoadData <= 1'b0;
                    state <= WAIT_SPI;
                    nextState <= COM_PIN;
                end
                end 
                COM_PIN: begin
                spiData <= 'hDA;
                spiLoadData <= 1'b1;
                if (spiDone)
                begin
                    spiLoadData <= 1'b0;
                    state <= WAIT_SPI;
                    nextState <= COM_PIN1;
                end
                end
                COM_PIN1: begin
                spiData <= 'h00;
                spiLoadData <= 1'b1;
                if (spiDone)
                begin
                    spiLoadData <= 1'b0;
                    state <= WAIT_SPI;
                    nextState <= DISPLAY_ON;
                end
                end  
                DISPLAY_ON: begin
                    spiData <= 'hAF;
                    spiLoadData <= 1'b1;
                    if (spiDone)
                    begin
                        spiLoadData <= 1'b0;
                        state <= WAIT_SPI;
                        nextState <= CLEAR_PAGE;
                    end
                end
                CLEAR_PAGE: begin
                    spiData <= 'h22;
                    spiLoadData <= 1'b1;
                    oled_dc_n <= 1'b0;
                    if (spiDone) begin
                        spiLoadData <= 1'b0;
                        state <= WAIT_SPI;
                        nextState <= CLEAR_PAGE1;
                    end
                end
                
                CLEAR_PAGE1: begin
                    spiData <= {6'b0, clearPage};
                    spiLoadData <= 1'b1;
                    if (spiDone) begin
                        spiLoadData <= 1'b0;
                        state <= WAIT_SPI;
                        nextState <= CLEAR_PAGE2;
                    end
                end
                
                CLEAR_PAGE2: begin
                    spiData <= {6'b0, clearPage};
                    spiLoadData <= 1'b1;
                    if (spiDone) begin
                        spiLoadData <= 1'b0;
                        state <= WAIT_SPI;
                        nextState <= CLEAR_COL;
                    end
                end
                
                CLEAR_COL: begin
                    spiData <= 'h10;
                    spiLoadData <= 1'b1;
                    if (spiDone) begin
                        spiLoadData <= 1'b0;
                        state <= WAIT_SPI;
                        nextState <= CLEAR_COL1;
                    end
                end
                
                CLEAR_COL1: begin
                    spiData <= 'h00;
                    spiLoadData <= 1'b1;
                    if (spiDone) begin
                        spiLoadData <= 1'b0;
                        state <= WAIT_SPI;
                        nextState <= CLEAR_DATA;
                    end
                end
                
                CLEAR_DATA: begin
                    spiData <= 8'h00;
                    spiLoadData <= 1'b1;
                    oled_dc_n <= 1'b1;
                    if (spiDone) begin
                        spiLoadData <= 1'b0;
                        state <= WAIT_SPI;
                        
                        if (clearCol != 127) begin
                            clearCol <= clearCol + 1;
                            nextState <= CLEAR_DATA;
                        end 
                        else begin
                            clearCol <= 0;
                            if (clearPage != 3) begin
                                clearPage <= clearPage + 1;
                                nextState <= CLEAR_PAGE;
                            end 
                            else begin
                                nextState <= PAGE_ADDR;
                            end
                        end
                    end
                end
                PAGE_ADDR: begin
                    spiData <= 'h22;
                    spiLoadData <= 1'b1;
                    oled_dc_n <= 1'b0;
                    if (spiDone)
                    begin
                        spiLoadData <= 1'b0;
                        state <= WAIT_SPI;
                        nextState <= PAGE_ADDR1;
                    end
                end
           
                PAGE_ADDR1: begin
                    spiData <= currPage; // Start page address
                    spiLoadData <= 1'b1;
                    if (spiDone)
                    begin
                        spiLoadData <= 1'b0;
                        state <= WAIT_SPI;
                        nextState <= PAGE_ADDR2;
                    end
                end  
                
                PAGE_ADDR2: begin
                    spiData <= currPage; // Start page address
                    spiLoadData <= 1'b1;
                    if (spiDone)
                    begin
                        spiLoadData <= 1'b0;
                        state <= WAIT_SPI;
                        currPage <= currPage+1;
                        nextState <= COLUMN_ADDR;
                    end
                end
                COLUMN_ADDR: begin
                    spiData <= 'h10;
                    spiLoadData <= 1'b1;
                    if (spiDone)
                    begin
                        spiLoadData <= 1'b0;
                        state <= WAIT_SPI;
                        nextState <= COLUMN_ADDR1;
                    end
                end
                COLUMN_ADDR1: begin
                    spiData <= 'h00;
                    spiLoadData <= 1'b1;
                    if (spiDone)
                    begin
                        spiLoadData <= 1'b0;
                        state <= WAIT_SPI;
                        nextState <= DONE;
                    end
                end      
                DONE: begin
                    sendDone <= 1'b0;
                    if (sendDataValid & columnAddr != wrapColumnAddr & !sendDone)
                    begin
                        state <= SEND_DATA;
                        byteCounter <= charWidth;
                    end
                    else if (sendDataValid & columnAddr == wrapColumnAddr & !sendDone)
                    begin
                        state <= PAGE_ADDR;
                        columnAddr <= 0;
                        byteCounter <= charWidth;
                    end
                end   
                SEND_DATA: begin
                    spiData <= charBitMap[(byteCounter*8-1)-:8];
                    spiLoadData <= 1'b1;
                    oled_dc_n <= 1'b1;
                    if (spiDone)
                    begin
                        columnAddr <= columnAddr + 1;
                        spiLoadData <= 1'b0;
                        state <= WAIT_SPI;
                        if (byteCounter != 1)
                        begin
                            byteCounter <= byteCounter - 1;
                            nextState <= SEND_DATA;
                        end
                        else
                        begin
                            nextState <= DONE;
                            sendDone <= 1'b1;
                        end
                    end
                end                   
            endcase
        end
    end
    
    
    delayGen DG(
        .clock(clock),
        .delayEn(startDelay),
        .delayDone(delayDone)
    ); 
        
        
    spiControl SC(
        .clock(clock), //On-board Zynq clock (100 MHz)
        .reset(reset),
        .data_in(spiData),
        .load_data(spiLoadData), //Signal indicates new data for transmission
        .done_send(spiDone),//Signal indicates data has been sent over spi interface
        .spi_clock(oled_spi_clk),//10MHz max
        .spi_data(oled_spi_data)
    );    
        
        
    charRom CR(
        .addr(sendData),
        .data(charBitMap) 
    );
    
endmodule