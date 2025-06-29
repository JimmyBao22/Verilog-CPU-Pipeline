`timescale 1ps/1ps

module main();

    initial begin
        // express the state of the world before the simulation starts
        $dumpfile("cpu.vcd"); // dumps the signal values to a file
        // after we run it through the simulator, a file will be created
        // and it will contain the values of the signals as they change over time
        $dumpvars(0, main);
    end

    // clock
    wire clk;
    clock c0(clk);

    reg halt = 0;

    counter ctr(halt, clk);
        
    ///////////////
    // F0 STAGE  //
    ///////////////
    reg [15:0]f0_pc = 16'h0000;
    reg f0_valid = 1;
    always @(posedge clk) begin
        f0_pc <= execute_flush ? execute_result + 2 :
                 execute_self_modify_flush ? execute_pc + 2 :
                 decode_stall ? f0_pc :
                 f1_misaligned_pc ? f0_pc :
                 load_misaligned_memory ? f0_pc :
                 f0_pc + 2;
    end

    ///////////////
    // F1 STAGE  //
    ///////////////
    reg [15:0]f1_pc;
    reg f1_valid = 0;
    always @(posedge clk) begin
        f1_pc <= execute_flush ? execute_result :
                 decode_stall ? f1_pc :
                 f0_pc;
        f1_valid <= f0_valid & ~execute_self_modify_flush & ~load_misaligned_memory;
    end

    // check for misaligned pc
    wire f1_misaligned_pc = f1_valid & f1_pc[0] == 1 & ~decode_misaligned_pc;

    //////////////////
    // Decode STAGE //
    //////////////////

    // save all wires needed in load stage
    reg decode_misaligned_pc = 0;

    always @(posedge clk) begin
        decode_misaligned_pc <= f1_misaligned_pc & ~execute_flush;
    end

    reg [15:0]decode_pc;
    reg decode_valid = 0;
    always @(posedge clk) begin
        decode_pc <= f1_pc;
        decode_valid <= f1_valid & ~execute_flush & ~execute_self_modify_flush & ~f1_misaligned_pc;
    end

    wire [15:0]decode_ins;

    // edit instruction for misaligned pc
    wire [15:0]updated_ins = decode_valid & load_misaligned_pc ? { decode_ins[7:0], load_ins[15:8] } :
                             decode_ins;

    wire [3:0]opcode = updated_ins[15:12];
    wire [3:0]decode_reg_A = updated_ins[11:8];
    wire [3:0]decode_reg_B = updated_ins[7:4];
    wire [3:0]decode_reg_T = updated_ins[3:0];
    wire [7:0]decode_i = updated_ins[11:4];

    // instructions
    wire decode_is_sub = opcode == 'b0000;
    wire decode_is_move_l = opcode == 'b1000;
    wire decode_is_move_h = opcode == 'b1001;
    wire decode_is_jump = opcode == 'b1110;
    wire decode_is_ldst = opcode == 'b1111;

    // more specific instructions
    wire decode_is_jump_jz = decode_is_jump & decode_reg_B == 'b0000;
    wire decode_is_jump_jnz = decode_is_jump & decode_reg_B == 'b0001;
    wire decode_is_jump_js = decode_is_jump & decode_reg_B == 'b0010;
    wire decode_is_jump_jns = decode_is_jump & decode_reg_B == 'b0011;
    wire decode_is_ld = decode_is_ldst & decode_reg_B == 'b0000;
    wire decode_is_st = decode_is_ldst & decode_reg_B == 'b0001;

    wire [3:0]decode_second_reg = decode_is_sub ? decode_reg_B : decode_reg_T;
    wire decode_is_unknown = ~(decode_is_sub | decode_is_move_l | decode_is_move_h | decode_is_jump_jz | decode_is_jump_jnz | 
                            decode_is_jump_js | decode_is_jump_jns | decode_is_ld | decode_is_st);

    // check for stalling
    wire decode_stall = decode_valid & decode_is_ld & load_valid & load_is_ld & load_reg_T == decode_reg_A & ~load_stall & ~execute_flush;

    ////////////////
    // Load STAGE //
    ////////////////

    // save all wires needed in load stage
    reg [15:0]load_ins;
    reg load_misaligned_pc = 0;
    reg load_is_sub;
    reg load_is_move_l;
    reg load_is_move_h;
    reg load_is_ldst;
    reg load_is_unknown;
    reg load_is_jump_jz;
    reg load_is_jump_jnz;
    reg load_is_jump_js;
    reg load_is_jump_jns;
    reg load_is_ld;
    reg load_is_st;
    reg [3:0]load_reg_A;
    reg [3:0]load_reg_B;
    reg [3:0]load_reg_T;
    reg [7:0]load_i;
    reg load_stall;

    always @(posedge clk) begin
        if (~load_stall) begin      // stall values: keep the current load stage values
            load_ins <= decode_ins;
            load_misaligned_pc <= decode_misaligned_pc & ~execute_flush;
            load_is_sub <= decode_is_sub;
            load_is_move_l <= decode_is_move_l;
            load_is_move_h <= decode_is_move_h;
            load_is_ldst <= decode_is_ldst;
            load_is_unknown <= decode_is_unknown;
            load_is_jump_jz <= decode_is_jump_jz;
            load_is_jump_jnz <= decode_is_jump_jnz;
            load_is_jump_js <= decode_is_jump_js;
            load_is_jump_jns <= decode_is_jump_jns;
            load_is_ld <= decode_is_ld;
            load_is_st <= decode_is_st;
            load_reg_A <= decode_reg_A;
            load_reg_B <= decode_second_reg;
            load_reg_T <= decode_reg_T;
            load_i <= decode_i;
        end

        load_stall <= decode_stall;
    end

    reg [15:0]load_pc;
    reg load_valid = 0;
    always @(posedge clk) begin
        load_pc <= load_stall ? load_pc : decode_pc;
        load_valid <= decode_valid & ~execute_flush & ~execute_self_modify_flush;
    end

    wire [15:0]load_reg_A_val_OG;
    wire [15:0]load_reg_B_val_OG;

    // Forward Values
    wire load_forward_reg_A_val_from_execute = load_reg_A == execute_reg_T & execute_valid & execute_write_to_regs;
    wire load_forward_reg_A_val_from_wb = load_reg_A == wb_reg_T & wb_valid & wb_write_to_regs;
    wire [15:0]load_reg_A_val = load_reg_A == 'b0000 ? 0 : 
                                load_forward_reg_A_val_from_execute ? execute_result :
                                load_forward_reg_A_val_from_wb ? wb_write :
                                load_reg_A_val_OG;

    wire load_forward_reg_B_val_from_execute = load_reg_B == execute_reg_T & execute_valid & execute_write_to_regs;
    wire load_forward_reg_B_val_from_wb = load_reg_B == wb_reg_T & wb_valid & wb_write_to_regs;
    wire [15:0]load_reg_B_val = load_reg_B == 'b0000 ? 0 : 
                                load_forward_reg_B_val_from_execute ? execute_result :
                                load_forward_reg_B_val_from_wb ? wb_write :
                                load_reg_B_val_OG;

    // check for a misaligned load instruction
    wire load_misaligned_memory = load_valid & load_reg_A_val[0] == 1 & load_is_ld & ~load_stall & ~execute_flush;

    ///////////////////
    // Execute STAGE //
    ///////////////////

    // save all wires needed in execute stage
    reg execute_is_sub;
    reg execute_is_move_l;
    reg execute_is_move_h;
    reg execute_is_ldst;
    reg execute_is_unknown;
    reg execute_is_jump_jz;
    reg execute_is_jump_jnz;
    reg execute_is_jump_js;
    reg execute_is_jump_jns;
    reg execute_is_ld;
    reg execute_is_st;
    reg [3:0]execute_reg_A;
    reg [3:0]execute_reg_B;
    reg [3:0]execute_reg_T;
    reg [7:0]execute_i;
    reg [15:0]execute_reg_A_val;
    reg [15:0]execute_reg_B_val;
    reg execute_stall;
    reg execute_misaligned_memory;

    always @(posedge clk) begin
        execute_is_sub <= load_is_sub;
        execute_is_move_l <= load_is_move_l;
        execute_is_move_h <= load_is_move_h;
        execute_is_ldst <= load_is_ldst;
        execute_is_unknown <= load_is_unknown;
        execute_is_jump_jz <= load_is_jump_jz;
        execute_is_jump_jnz <= load_is_jump_jnz;
        execute_is_jump_js <= load_is_jump_js;
        execute_is_jump_jns <= load_is_jump_jns;
        execute_is_ld <= load_is_ld;
        execute_is_st <= load_is_st;
        execute_reg_A <= load_reg_A;
        execute_reg_B <= load_reg_B;
        execute_reg_T <= load_reg_T;
        execute_i <= load_i;
        execute_reg_A_val <= load_reg_A_val;
        execute_reg_B_val <= load_reg_B_val;
        execute_stall <= load_stall;
        execute_misaligned_memory <= load_misaligned_memory;
    end

    reg [15:0]execute_pc;
    reg execute_valid = 0;
    always @(posedge clk) begin
        execute_pc <= load_pc;
        execute_valid <= load_valid & ~execute_flush & ~load_stall & ~execute_self_modify_flush;
    end

    // Forwarded values
    wire execute_forward_reg_A_val_from_wb = execute_reg_A == wb_reg_T & wb_valid & wb_write_to_regs;
    wire [15:0]execute_reg_A_updated_val = execute_reg_A == 'b0000 ? 0 :
                                           execute_forward_reg_A_val_from_wb ? wb_write :
                                           execute_reg_A_val;
                                        
    wire execute_forward_reg_B_val_from_wb = execute_reg_B == wb_reg_T & wb_valid & wb_write_to_regs;
    wire [15:0]execute_reg_B_updated_val = execute_reg_B == 'b0000 ? 0 :
                                           execute_forward_reg_B_val_from_wb ? wb_write :
                                           execute_reg_B_val;                             

    // calculate result
    wire [15:0]execute_result = execute_is_sub ? execute_reg_A_updated_val - execute_reg_B_updated_val :
                        execute_is_move_l ? { {8{execute_i[7]}}, execute_i[7:0] } :
                        execute_is_move_h ? (execute_reg_B_updated_val & 'h00ff) | (execute_i << 8) :
                        (execute_is_jump_jz & execute_reg_A_updated_val == 0) ? execute_reg_B_updated_val :
                        (execute_is_jump_jnz & execute_reg_A_updated_val != 0) ? execute_reg_B_updated_val :
                        (execute_is_jump_js & execute_reg_A_updated_val[15] == 1) ? execute_reg_B_updated_val :
                        (execute_is_jump_jns & execute_reg_A_updated_val[15] == 0) ? execute_reg_B_updated_val :
                        execute_is_st ? execute_reg_B_updated_val :
                        0;

    // check extra conditions
    wire execute_write_to_regs = execute_is_sub | execute_is_move_l | execute_is_move_h | execute_is_ld;
    wire execute_write_to_mem = execute_is_st;
    wire execute_is_jump = (execute_is_jump_jz & execute_reg_A_val == 0) | (execute_is_jump_jnz & execute_reg_A_val != 0) |
                    (execute_is_jump_js & execute_reg_A_val[15] == 1) | (execute_is_jump_jns & execute_reg_A_val[15] == 0);
    
    wire execute_is_r0 = execute_reg_T == 'b0000;
    
    // determine if flushing is necessary
    wire execute_flush = execute_valid & execute_is_jump;

    // flushing for self modifying code
    wire execute_self_modify_1 = execute_reg_A_updated_val > execute_pc;
    wire execute_self_modify_2 = execute_reg_A_updated_val <= execute_pc + 'h0008;
    wire execute_self_modify_flush = execute_valid & execute_is_st & execute_self_modify_1 & execute_self_modify_2;

    //////////////////////
    // Write Back STAGE //
    //////////////////////

    wire [15:0]wb_mem_a;

    // save all registers needed in write back stage
    reg wb_is_unknown;
    reg wb_is_jump;
    reg wb_is_ld;
    reg [15:0]wb_result;
    reg wb_write_to_regs;
    reg wb_write_to_mem;
    reg [3:0]wb_reg_T;
    reg [15:0]wb_reg_A_val;
    reg [15:0]wb_reg_B_val;
    reg wb_is_r0;
    reg wb_misaligned_memory;

    always @(posedge clk) begin
        wb_is_unknown <= execute_is_unknown;
        wb_is_jump <= execute_is_jump;
        wb_is_ld <= execute_is_ld;
        wb_result <= execute_result;
        wb_write_to_regs <= execute_write_to_regs;
        wb_write_to_mem <= execute_write_to_mem;
        wb_reg_T <= execute_reg_T;
        wb_reg_A_val <= execute_reg_A_updated_val;
        wb_reg_B_val <= execute_reg_B_updated_val;
        wb_is_r0 <= execute_is_r0;
        wb_misaligned_memory <= execute_misaligned_memory;
    end

    reg [15:0]wb_pc;
    reg wb_valid = 0;
    always @(posedge clk) begin
        wb_pc <= execute_pc;
        wb_valid <= execute_valid & ~execute_flush & ~execute_self_modify_flush;
    end

    wire [15:0]wb_write = wb_misaligned_memory ? { decode_ins[7:0], wb_mem_a[15:8] } :
                          wb_is_ld ? wb_mem_a :
                          wb_result;

    // write to output
    always @(posedge clk) begin
        // if (wb_write_to_regs & wb_valid & wb_is_r0) $write("%c %00h", wb_write[7:0], wb_write[7:0]);
        if (wb_write_to_regs & wb_valid & wb_is_r0) $write("%s", wb_write[7:0]);
    end

    // check if this is an invalid instruction to end program
    always @(posedge clk) begin
        // if (wb_is_unknown & wb_valid) $finish();
        if (execute_is_unknown & execute_valid) halt = 1;
    end

    // memory
    wire mem_wen = execute_write_to_mem & execute_valid;
    mem mem(clk, execute_flush ? execute_result[15:1] : 
                 load_misaligned_memory ? load_reg_A_val[15:1] + 15'b1 :
                 decode_stall ? f1_pc[15:1] : 
                 f0_pc[15:1], 
                decode_ins, load_reg_A_val[15:1], 
                wb_mem_a, mem_wen, execute_reg_A_val[15:1], execute_result);

    // registers
    wire regs_wen = wb_valid & wb_write_to_regs & ~wb_is_r0;
    regs regs(clk, decode_reg_A, load_reg_A_val_OG, decode_second_reg, load_reg_B_val_OG, 
                regs_wen, wb_reg_T, wb_write);

endmodule