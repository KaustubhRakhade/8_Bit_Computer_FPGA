`timescale 1ns / 1ps

// Arithmetic Logical Unit (ALU)
module alu (
    input wire clock,
    input wire reset,
    input wire [7:0] operand1, // Accumulator or Program Counter
    input wire [7:0] operand2, // Data Register
    input wire [3:0] opcode,
    output wire [7:0] result,
    input wire read_enable,
    output reg carry,
    output reg [2:0] compare_flags
);

    `include "include.sv"

    reg [8:0] internal_result; // 9 bits to capture Carry/Borrow
    reg [7:0] alu_out;

    always @(*) begin
        case(opcode)
            // Arithmetic
            ALU_ADD:  internal_result = {1'b0, operand1} + {1'b0, operand2};
            ALU_ADDC: internal_result = {1'b0, operand1} + {1'b0, operand2} + carry;
            ALU_SUBB: internal_result = {1'b0, operand1} - {1'b0, operand2} - carry;
            ALU_INC:  internal_result = {1'b0, operand2} + 1; // Increment Op2
            ALU_DEC:  internal_result = {1'b0, operand2} - 1; // Decrement Op2

            // Logic
            ALU_AND:  internal_result = {1'b0, operand1 & operand2};
            ALU_OR:   internal_result = {1'b0, operand1 | operand2};
            ALU_XOR:  internal_result = {1'b0, operand1 ^ operand2};
            ALU_CML:  internal_result = {1'b0, ~operand2};     // Complement Op2
            ALU_SL:   internal_result = {1'b0, operand1 << 1}; // Shift Left Op1
            ALU_SR:   internal_result = {1'b0, operand1 >> 1}; // Shift Right Op1
            
            default:  internal_result = {1'b0, operand1};
        endcase

        alu_out = internal_result[7:0];
    end

    // Logic for carry and compare flags
    always @(posedge clock or posedge reset) begin
        if (reset || opcode == ALU_CLRC) begin
            carry <= 0;
        end 
        else if (opcode == ALU_ADD || opcode == ALU_ADDC || opcode == ALU_SUBB) begin
            carry <= internal_result[8];
        end
        else if (opcode == ALU_SETC) begin
            carry <= 1;
        end
        else if (opcode == ALU_CMP) begin
            if      (operand1 >  operand2) compare_flags <= 3'b001;
            else if (operand1 == operand2) compare_flags <= 3'b010;
            else if (operand1 <  operand2) compare_flags <= 3'b100;
        end
        // Else retain the old carry value & compare flags
    end

    // Tristate Bus Driver
    assign result = (read_enable) ? alu_out : 8'bz;

endmodule