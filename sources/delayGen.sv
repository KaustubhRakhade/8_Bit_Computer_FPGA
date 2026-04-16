`timescale 1ns / 1ps

// CODE SOURCE: https://github.com/vipinkmenon/ZynqOLED
// based on tutorial: https://www.youtube.com/playlist?list=PLpZTg2luX5lg1mydl0sKW77uP96yaeM3a

module delayGen(
    input clock,
    input delayEn,
    output reg delayDone
);
    
    reg [17:0] counter;    

    always @(posedge clock)
    begin
        if(delayEn & counter != 200000)
            counter <= counter+1;
        else
            counter <= 0;
    end

    always @(posedge clock)
    begin
        if(delayEn & counter == 200000)
            delayDone <= 1'b1;
        else
            delayDone <= 1'b0;
    end
    
endmodule