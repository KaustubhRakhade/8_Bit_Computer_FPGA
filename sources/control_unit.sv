`timescale 1ns / 1ps

// Control unit generates and times control signals based on the opcodes
module control_unit (
    input wire clock,
    input wire reset,
    input wire btn_resume,
    input wire [7:0] ir_value,
    input wire carry_flag,
    input wire dr_zero_flag,
    input wire [2:0] compare_flags, // A >=< R
    
    // Outputs
    output reg pr_we,
    output reg inp_re,
    output reg inp_flush,
    output reg ir_we, iram_re,
    output reg pc_inc, pc_as_op1,
    output reg pc_we, pc_re,
    output reg dr_we, dr_re,
    output reg a_we, a_re,
    output reg [7:0] rb_we, rb_re,
    output reg [3:0] alu_op,
    output reg alu_re,
    output reg [2:0] status
);

    `include "include.sv"

    // State definitions
    localparam T_0 = 3'd0;
    localparam T_1 = 3'd1;
    localparam T_2 = 3'd2;
    localparam T_3 = 3'd3;
    localparam T_4 = 3'd4;

    localparam CLK_FREQ     = 100_000_000;
    localparam CYCLES_10MS  = CLK_FREQ / 100;

    // Opcode Definitions
    // The '?' acts as a wildcard (don't care) bit
    localparam OP_ADD_A_R     = 8'b0000_0???; // ADD A, Rr
    localparam OP_ADD_A_DATA  = 8'b0000_1010; // ADD A, #data
    localparam OP_ADDC_A_R    = 8'b0001_0???; // ADDC A, Rr
    localparam OP_ADDC_A_DATA = 8'b0001_1010; // ADDC A, #data
    localparam OP_SUBB_A_R    = 8'b0010_0???; // SUBB A, Rr
    localparam OP_SUBB_A_DATA = 8'b0010_1010; // SUBB A, #data
    localparam OP_AND_A_R     = 8'b0011_0???; // AND A, Rr
    localparam OP_AND_A_DATA  = 8'b0011_1010; // AND A, #data
    localparam OP_OR_A_R      = 8'b0100_0???; // OR A, Rr
    localparam OP_OR_A_DATA   = 8'b0100_1010; // OR A, #data
    localparam OP_XOR_A_R     = 8'b0101_0???; // XOR A, Rr
    localparam OP_XOR_A_DATA  = 8'b0101_1010; // XOR A, #data

    localparam OP_CMP_A_R     = 8'b1010_0???; // CMP A, Rr
    localparam OP_CMP_A_DATA  = 8'b1010_1010; // CMP A, #data

    localparam OP_JEQ         = 8'b1010_1000; // JEQ
    localparam OP_JNEQ        = 8'b1010_1001; // JNEQ
    localparam OP_JGT         = 8'b1010_1100; // JGT
    localparam OP_JNGT        = 8'b1010_1101; // JNGT
    localparam OP_JLT         = 8'b1010_1110; // JLT
    localparam OP_JNLT        = 8'b1010_1111; // JNLT

    localparam OP_INC_R       = 8'b0110_0???; // INC Rr
    localparam OP_INC_A       = 8'b0110_1010; // INC A
    localparam OP_DEC_R       = 8'b0111_0???; // DEC Rr
    localparam OP_DEC_A       = 8'b0111_1010; // DEC A
    localparam OP_CML_R       = 8'b1000_0???; // CML Rr
    localparam OP_CML_A       = 8'b1000_1010; // CML A

    localparam OP_SL_A        = 8'b1001_0001; // SL A
    localparam OP_SR_A        = 8'b1001_0010; // SR A

    localparam OP_JNC         = 8'b1001_0100; // JNC #data
    localparam OP_JC          = 8'b1001_0101; // JNC #data
    localparam OP_JMP         = 8'b1001_0110; // JNC #data

    localparam OP_JRZ_R       = 8'b1011_0???; // JRZ Rr, #data
    localparam OP_JRZ_A       = 8'b1011_1010; // JRZ A, #data
    localparam OP_JRNZ_R      = 8'b1100_0???; // JRNZ Rr, #data
    localparam OP_JRNZ_A      = 8'b1100_1010; // JRNZ A, #data

    localparam OP_MOV_R_DATA  = 8'b1101_0???; // MOV Rr, #data
    localparam OP_MOV_A_DATA  = 8'b1101_1010; // MOV A, #data
    localparam OP_MOV_R_A     = 8'b1110_0???; // MOV Rr, A
    localparam OP_PRINT_A     = 8'b1110_1010; // PRINT A
    localparam OP_MOV_A_R     = 8'b1111_0???; // MOV A, Rr

    localparam OP_WAIT        = 8'b1111_1100; // WAIT #data * 10ms
    localparam OP_HALT        = 8'b1111_1101; // HALT execution
    localparam OP_PAUSE       = 8'b1111_1110; // PAUSE execution
    localparam OP_INPUT       = 8'b1111_1111; // INPUT from user
    
    // For waiting
    reg [31:0] wait_counter;
    reg [7:0] wait_data;
    reg is_waiting;
    wire [7:0] active_ir = is_waiting ? OP_WAIT : ir_value;
    
    reg [2:0] state;
    reg reset_state = 0;
    
    wire [2:0] reg_idx     = ir_value[2:0]; // The register index (0-7)
    wire [3:0] alu_opcode  = ir_value[7:4]; // The ALU opcodes (0-8)

    // State Sequencerr
    always @(posedge clock or posedge reset) begin
        if (reset || reset_state) begin
            state <= T_0;
            wait_counter <= 0;
            is_waiting <= 0;
        end else begin
            if (is_waiting) begin
                // ir_value currently holds #data fetched during T_1
                // We use + 1 to prevent underflow issues if #data is 0
                if (wait_counter + 1 >= (CYCLES_10MS * ir_value)) begin
                    state <= state + 1; // Move to T_3
                    wait_counter <= 0;
                end else begin
                    wait_counter <= wait_counter + 1;
                end
            end else begin
                // ADDED: Block the state from incrementing if paused and button isn't pressed
                if (active_ir == OP_PAUSE && state == T_1 && !btn_resume) begin
                    state <= T_1;
                end
                else if (active_ir == OP_INPUT && state == T_2 && !btn_resume) begin
                    state <= T_2;
                end
                else if (active_ir == OP_HALT && state == T_1) begin
                    state <= T_1;
                end else begin
                    state <= state + 1;
                    
                    // Trigger the wait state when transitioning out of T_1 for OP_WAIT
                    if (active_ir == OP_WAIT && state == T_1) begin
                        is_waiting <= 1;
                    end
                end
            end
        end
    end

    always @(*) begin
        case (active_ir)
            OP_HALT:  status = STATUS_EXIT;
            OP_PAUSE: status = STATUS_PAUSE;
            OP_INPUT: status = STATUS_INPUT;
            OP_WAIT:  status = STATUS_WAIT;
            default:  status = STATUS_RUN;
        endcase
    end


    // Combinatorial Control Logic
    always @(*) begin
        // Set Defaults
        pr_we = 0;
        inp_flush = 0; inp_re = 0;
        ir_we = 0; iram_re = 0;
        pc_inc = 0; pc_as_op1 = 0;
        pc_we = 0; pc_re = 0;
        dr_we = 0; dr_re = 0;
        a_we = 0; a_re = 0;
        rb_we = 0; rb_re = 0;
        alu_op = ALU_NOP; alu_re = 0;
        reset_state = 0; // Default loop back to reset/fetch

        // Instruction Fetch
        if (state == T_0) begin // IR <- IRAM[PC]; PC++
            iram_re = 1;
            ir_we = 1;
            pc_inc = 1;
        end 
        
        else begin
            casez (active_ir)
                
                // 2 operand ALU operation b/w A and R
                OP_ADD_A_R,
                OP_ADDC_A_R,
                OP_SUBB_A_R,
                OP_AND_A_R,
                OP_OR_A_R,
                OP_XOR_A_R,
                OP_CMP_A_R:
                begin 
                    case (state)
                        T_1: begin // DR <- Rr
                            dr_we = 1;
                            rb_re[reg_idx] = 1;
                        end
                        T_2: begin // A <- ALU(A, DR)
                            alu_op = alu_opcode;
                            a_we = 1;
                            alu_re = 1;
                            reset_state = 1;
                        end
                    endcase
                end

                // 2 operand ALU operation b/w A and #data
                OP_ADD_A_DATA,
                OP_ADDC_A_DATA,
                OP_SUBB_A_DATA,
                OP_AND_A_DATA,
                OP_OR_A_DATA,
                OP_XOR_A_DATA,
                OP_CMP_A_DATA:
                begin 
                    case (state)
                        T_1: begin // DR <- IRAM[PC]
                            iram_re = 1;
                            dr_we = 1; 
                        end
                        T_2: begin // A <- ALU(A, DR); PC++
                            pc_inc = 1;
                            alu_op = alu_opcode;
                            a_we = 1;
                            alu_re = 1;
                            reset_state = 1;
                        end
                    endcase
                end

                // 1 operand ALU operation on A
                OP_INC_A,
                OP_DEC_A,
                OP_CML_A:
                begin 
                    case (state)
                        T_1: begin
                            a_re = 1;
                            dr_we = 1;
                        end
                        T_2: begin
                            alu_op = alu_opcode;
                            alu_re = 1;
                            a_we = 1;
                            reset_state = 1;
                        end
                    endcase
                end

                // 1 operand ALU operation on R
                OP_INC_R,
                OP_DEC_R,
                OP_CML_R:
                begin 
                    case (state)
                        T_1: begin
                            rb_re[reg_idx] = 1;
                            dr_we = 1;
                        end
                        T_2: begin
                            alu_op = alu_opcode;
                            alu_re = 1;
                            rb_we[reg_idx] = 1;
                            reset_state = 1;
                        end
                    endcase
                end

                OP_SL_A,
                OP_SR_A:
                begin
                    alu_op = (ir_value == OP_SL_A) ? ALU_SL : ALU_SR;
                    alu_re = 1;
                    a_we = 1;
                    reset_state = 1;
                end

                OP_WAIT: begin
                    case (state)
                        T_1: begin
                            iram_re = 1;
                            ir_we = 1;
                        end
                        T_2: begin
                            // Waiting state
                        end
                        T_3: begin 
                            pc_inc = 1;
                            reset_state = 1;
                        end
                    endcase
                end

                OP_PAUSE: begin
                    case (state)
                        T_1: begin
                            // Waiting state
                        end
                        T_2: begin
                            // Button was pressed
                            reset_state = 1;
                        end
                    endcase
                end

                OP_HALT: begin
                    // Waiting state
                end

                OP_INPUT: begin
                    case (state)
                        T_1: begin
                            inp_flush = 1;
                            inp_re = 1; // for the diplay on OLED
                        end
                        T_2: begin
                            inp_re = 1; // for the diplay on OLED
                            // Waiting state
                        end
                        T_3: begin
                            // Button was pressed
                            inp_re = 1;
                            a_we = 1;
                            reset_state = 1;
                        end
                    endcase
                end

                OP_JMP: begin // PC <- IRAM[PC]
                    iram_re = 1;
                    pc_we = 1;
                    reset_state = 1;
                end

                OP_JNC: begin // PC <- IRAM[PC]
                    iram_re = 1;
                    pc_we = !carry_flag;
                    pc_inc = carry_flag;
                    reset_state = 1;
                end

                OP_JC: begin // PC <- IRAM[PC]
                    iram_re = 1;
                    pc_we = carry_flag;
                    pc_inc = !carry_flag;
                    reset_state = 1;
                end

                OP_JNEQ: begin // PC <- IRAM[PC]
                    iram_re = 1;
                    pc_we = !compare_flags[1];
                    pc_inc = compare_flags[1];
                    reset_state = 1;
                end

                OP_JEQ: begin // PC <- IRAM[PC]
                    iram_re = 1;
                    pc_we = compare_flags[1];
                    pc_inc = !compare_flags[1];
                    reset_state = 1;
                end

                OP_JNGT: begin // PC <- IRAM[PC]
                    iram_re = 1;
                    pc_we = !compare_flags[0];
                    pc_inc = compare_flags[0];
                    reset_state = 1;
                end

                OP_JGT: begin // PC <- IRAM[PC]
                    iram_re = 1;
                    pc_we = compare_flags[0];
                    pc_inc = !compare_flags[0];
                    reset_state = 1;
                end

                OP_JNLT: begin // PC <- IRAM[PC]
                    iram_re = 1;
                    pc_we = !compare_flags[2];
                    pc_inc = compare_flags[2];
                    reset_state = 1;
                end

                OP_JLT: begin // PC <- IRAM[PC]
                    iram_re = 1;
                    pc_we = compare_flags[2];
                    pc_inc = !compare_flags[2];
                    reset_state = 1;
                end

                OP_JRZ_R: begin
                    case (state)
                        T_1: begin
                            rb_re[reg_idx] = 1;
                            dr_we = 1;
                        end
                        T_2: begin
                            iram_re = 1;
                            pc_we = dr_zero_flag;
                            pc_inc = !dr_zero_flag;
                            reset_state = 1;
                        end
                    endcase
                end

                OP_JRNZ_R: begin
                    case (state)
                        T_1: begin
                            rb_re[reg_idx] = 1;
                            dr_we = 1;
                        end
                        T_2: begin
                            iram_re = 1;
                            pc_we = !dr_zero_flag;
                            pc_inc = dr_zero_flag;
                            reset_state = 1;
                        end
                    endcase
                end

                OP_JRZ_A: begin
                    case (state)
                        T_1: begin
                            a_re = 1;
                            dr_we = 1;
                        end
                        T_2: begin
                            iram_re = 1;
                            pc_we = dr_zero_flag;
                            pc_inc = !dr_zero_flag;
                            reset_state = 1;
                        end
                    endcase
                end

                OP_JRNZ_A: begin
                    case (state)
                        T_1: begin
                            a_re = 1;
                            dr_we = 1;
                        end
                        T_2: begin
                            iram_re = 1;
                            pc_we = !dr_zero_flag;
                            pc_inc = dr_zero_flag;
                            reset_state = 1;
                        end
                    endcase
                end

                // MOV Rr, #data
                OP_MOV_R_DATA: begin
                    case (state)
                        T_1: begin
                            iram_re = 1;
                            rb_we[reg_idx] = 1;
                        end
                        T_2: begin // PC++
                            pc_inc = 1;
                            reset_state = 1;
                        end
                    endcase
                end

                // MOV A, #data
                OP_MOV_A_DATA: begin 
                    case (state)
                        T_1: begin
                            iram_re = 1;
                            a_we = 1;
                        end
                        T_2: begin // PC++
                            pc_inc = 1;
                            reset_state = 1;
                        end
                    endcase
                end

                // MOV A, Rr
                OP_MOV_A_R: begin 
                    rb_re[reg_idx] = 1;
                    a_we = 1;
                    reset_state = 1;
                end

                // MOV Rr, A
                OP_MOV_R_A: begin 
                    a_re = 1;
                    rb_we[reg_idx] = 1;
                    reset_state = 1;
                end

                OP_PRINT_A: begin 
                    a_re = 1;
                    pr_we = 1;
                    reset_state = 1;
                end

                // UNKNOWN / NOP
                default: begin
                    reset_state = 1;
                end
            endcase
        end
    end
endmodule