`timescale 1ns / 1ps

// CPU, everything is connected together here to the control unit and bus
module cpu (
    input wire clock,
    input wire reset,
    input wire [1:0] prog_select,
    input wire btn_resume,
    output reg [7:0] print_reg,
    output wire inp_re,
    output wire inp_flush,
    inout wire [7:0] bus,    // The System Bus
    output wire [2:0] status
);

    // Control Signals
    wire pr_we;
    wire ir_we, iram_re;
    wire pc_inc, pc_we, pc_re;
    wire dr_we, dr_re;
    wire a_we, a_re;
    wire [7:0] rb_we;
    wire [7:0] rb_re;
    wire [3:0] alu_op;
    wire alu_re;
    wire carry_flag;
    wire pc_as_op1; // program_counter as operand 1 (instead of acc)

    wire [7:0] pc_val;
    wire [7:0] ir_val_to_cu;
    wire [7:0] acc_value;
    wire [7:0] dr_val_to_alu;
    wire dr_zero_flag = ~|dr_val_to_alu;

    wire [7:0] operand1 = pc_as_op1 ? pc_val : acc_value;

    wire [2:0] compare_flags;


    program_counter ProgramCounter (
        .clock(clock), .reset(reset),
        .read_enable(pc_re), .write_enable(pc_we), .increment(pc_inc),
        .data(bus),
        .value(pc_val) // Hardwired to IRAM address
    );

    iram InstructionRAM (
        .clock(clock),
        .reset(reset),
        .prog_select(prog_select),
        .address(pc_val),
        .read_enable(iram_re),
        .write_enable(1'b0),
        .data(bus)
    );

    gpr InstructionRegister (
        .clock(clock), .reset(reset),
        .read_enable(1'b0), // IR never puts data ON bus in this design
        .write_enable(ir_we),
        .data(bus),
        .value(ir_val_to_cu) // Hardwired to CU
    );

    gpr PrintRegister (
        .clock(clock), .reset(reset),
        .read_enable(1'b0), // PR never puts data ON bus in this design
        .write_enable(pr_we),
        .data(bus),
        .value(print_reg) // Hardwired to output
    );

    control_unit ControlUnit (
        .clock(clock), .reset(reset),
        .btn_resume(btn_resume),
        .ir_value(ir_val_to_cu),
        .carry_flag(carry_flag),
        .dr_zero_flag(dr_zero_flag),
        .compare_flags(compare_flags),

        .pr_we(pr_we),
        .inp_flush(inp_flush), .inp_re(inp_re),  
        .ir_we(ir_we), .iram_re(iram_re),
        .pc_inc(pc_inc), .pc_as_op1(pc_as_op1),
        .pc_we(pc_we), .pc_re(pc_re),
        .dr_we(dr_we), .dr_re(dr_re),
        .a_we(a_we), .a_re(a_re),
        .rb_we(rb_we), .rb_re(rb_re),
        .alu_op(alu_op), .alu_re(alu_re),
        .status(status)
    );

    rbank RegisterBank (
        .clock(clock), .reset(reset),
        .read_enable(rb_re), .write_enable(rb_we),
        .data(bus)
    );

    // Data Register (DR) - Second ALU Operand
    gpr DataRegister (
        .clock(clock), .reset(reset),
        .read_enable(dr_re),
        .write_enable(dr_we),
        .data(bus),
        .value(dr_val_to_alu) // Hardwired to ALU Op2
    );

    // Accumulator (A) - First ALU Operand
    gpr Accumulator (
        .clock(clock), .reset(reset),
        .read_enable(a_re),
        .write_enable(a_we),
        .data(bus),
        .value(acc_value)
    );

    alu ALU (
        .clock(clock), .reset(reset),
        .operand1(operand1),
        .operand2(dr_val_to_alu),
        .opcode(alu_op),
        .read_enable(alu_re),
        .result(bus),
        .carry(carry_flag),
        .compare_flags(compare_flags)
    );

endmodule