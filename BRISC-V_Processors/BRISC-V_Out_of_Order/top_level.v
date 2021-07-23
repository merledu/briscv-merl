
module top_level #(parameter DATA_WIDTH = 32, NUMBER_OF_FUNCTIONAL_UNITS = 2, 
                               NUMBER_OF_ACTIVE_INSTRUCTIONS = 2, RD_BITS = 5, 
                                INSTRUCTION_QUEUE_SIZE = 4, RDS_IN_SCHEDULDER = 2,
                                ALU1_CYCLES = 4, ALU2_CYCLES = 4, NUMBER_OF_QUEUED_INSTRUCTIONS = 2,
                                COMMIT_BACKLOG_LENGTH = 2, ADDRESS_BITS = 22, CORE =0,
                                PRINT_CYCLES_MAX = 100, PRINT_CYCLES_MIN = 10, INDEX_BITS = 6,
                                OFFSET_BITS = 3, REGISTER_BITS = 5,
                                PROGRAM = "/home/dkava/Documents/ec513/ec513-project/binaries/gdc_mem/instructions.dat"
                                                                                                                       )(
    input clock,
    input reset,
    
    output [DATA_WIDTH-1:0] scheduled_instruction,
    output [ADDRESS_BITS-1:0] scheduled_instruction_PC,
    output [31: 0] cycle_count,
    output scheduler_valid,
    output [REGISTER_BITS-1 :0] register_writeback,
    output [DATA_WIDTH-1:0] writeback_register_data,
    output [INSTRUCTION_QUEUE_SIZE-1:0] hazard_table_TB,     
    output [INSTRUCTION_QUEUE_SIZE-1:0] inner_hazard_table_TB,
    output [INSTRUCTION_QUEUE_SIZE-1:0] queue_table_in_use_TB
    
    );
 
//localparam REGISTER_BITS = 5;  

//  define the log2 function
function integer log2;
    input integer num;
    integer i, result;
    begin
        for (i = 0; 2 ** i < num; i = i + 1)
            result = i + 1;
        log2 = result;
    end
endfunction

localparam regWrite_bit              = 0,  
           operand_B_selbit          = 1,  
           memWrite_bit              = 2,  
           memtoReg_bit              = 3,  
           memRead_bit               = 4,  
           branch_op_bit             = 5,  
           operand_A_sel_start_bit   = 6,  
           operand_A_sel_end_bit     = 7,  
           next_PC_select_start_bit  = 8,  
           next_PC_select_end_bit    = 9,  
           ALUOp_start_bit           = 10, 
           ALUOp_end_bit             = 12, 
           funct7_start_bit          = 13, 
           funct7_end_bit            = 19, 
           funct3_start_bit          = 20, 
           funct3_end_bit            = 22, 
           opcode_start_bit          = 23, 
           opcode_end_bit            = 29,         
           extend_sel_start_bit      = 30, 
           extend_sel_end_bit        = 31,     
           //address bits     
           inst_PC_start_bit         = 32, 
           inst_PC_end_bit           = 32  +    (ADDRESS_BITS - 1), 
           JAL_target_start_bit      = 32  +     ADDRESS_BITS, 
           JAL_target_end_bit        = 32  + ((2*ADDRESS_BITS) - 1), 
           branch_target_start_bit   = 32  +  (2*ADDRESS_BITS), 
           branch_target_end_bit     = 32  + ((3*ADDRESS_BITS) - 1),  
           // data width
           extend_imm_start_bit      = 32  +  (3*ADDRESS_BITS),  
           extend_imm_end_bit        = 32  +  (3*ADDRESS_BITS + DATA_WIDTH -1);          
           
wire   ready;
wire [DATA_WIDTH-1:0] instruction_to_system;
wire [log2(NUMBER_OF_FUNCTIONAL_UNITS)-1:0] unit;
wire [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] instruction_id;
wire   valid_to_system;
wire [REGISTER_BITS-1 :0] rs1; 
wire [REGISTER_BITS-1 :0] rs2;
wire [REGISTER_BITS-1 :0] ALU1_rd; 
wire [REGISTER_BITS-1 :0] ALU2_rd; 
wire [DATA_WIDTH-1:0] rs1_data;
wire [DATA_WIDTH-1:0] rs2_data;    
wire   ALU1_branch;
wire   ALU2_branch;
wire   ALU1_valid;
wire   ALU2_valid;
wire   ALU1_ready;
wire   ALU2_ready;
wire   ALU1_zero;
wire   ALU2_zero;
wire  [DATA_WIDTH-1:0] ALU1_result;  
wire  [DATA_WIDTH-1:0] ALU2_result;  
wire  [DATA_WIDTH-1:0] instruction_to_scheduler;  
wire  [DATA_WIDTH-1:0] commited_instruction;    
wire  [DATA_WIDTH-1:0] instruction_execute;
wire  [(REGISTER_BITS*RDS_IN_SCHEDULDER)-1:0] rd_bits_in_scheduler;
wire  [REGISTER_BITS-1 :0] rd_writeback;
wire  [REGISTER_BITS-1 :0] rd_writeback_commit;
wire  [REGISTER_BITS-1 :0] rd;
wire   valid_queue_instruction;
wire   valid_instruction_bit;
wire  [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] finished_instruction_ID;
wire  [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] ALU1_instruction_ID;
wire  [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] ALU2_instruction_ID;

wire [DATA_WIDTH-1:0] instruction_decode;
wire [DATA_WIDTH-1:0] instruction_fetch_to_decode;
wire [DATA_WIDTH-1:0] extend_imm_decode;  
wire [DATA_WIDTH-1:0] instruction_fetch;  
wire [ADDRESS_BITS-1:0] branch_target_decode; 
wire [ADDRESS_BITS-1:0] JAL_target_decode;    
wire [ADDRESS_BITS-1:0] inst_PC_decode;
wire [1:0] extend_sel_decode;
wire [6:0] opcode_decode;
wire [2:0] funct3_decode;
wire [6:0] funct7_decode;
wire [2:0] ALUOp_decode;
wire [1:0] next_PC_select_decode;
wire [1:0] operand_A_sel_decode;

wire [1:0] next_PC_select_execute;
wire [ADDRESS_BITS-1:0] JAL_target_execute;   

wire branch_op_decode;
wire memRead_decode;
wire memtoReg;
wire memWrite_decode;
wire operand_B_sel_decode;
wire regWrite_decode;

wire [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1 : 0] control_and_decode_packet_decode =

                                               {extend_imm_decode, branch_target_decode,
                                                 JAL_target_decode, 
                                                 inst_PC_decode, 
                                                 extend_sel_decode, opcode_decode,
                                                 funct3_decode, funct7_decode, ALUOp_decode,
                                                 next_PC_select_decode, operand_A_sel_decode,
                                                 branch_op_decode, memRead_decode, memtoReg,
                                                 memWrite_decode,  operand_B_sel_decode,
                                                 regWrite_decode};

wire [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] control_and_decode_packet_queue;
wire [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] queued_decode_packet;     
wire [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] scheduled_packet;                                                         
wire [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] ALU1_packet;                                                         
wire [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] ALU2_packet;                                                         

wire regWrite_commit;
wire memWrite_commit;
wire [ADDRESS_BITS-1:0] generated_address_commit;
wire [DATA_WIDTH-1:0] rs2_data_store_commit;
wire [DATA_WIDTH-1:0] ALU_result_writeback_commit;
wire regWrite_writeback;
wire memWrite_memory;
wire memRead_memory;
wire [ADDRESS_BITS-1:0] generated_address_memory;
wire [DATA_WIDTH-1:0] rs2_data_store_memory;
wire [DATA_WIDTH-1:0] ALU_result_writeback;
wire write;
wire [4:0] write_register;
wire [DATA_WIDTH-1:0] register_write_data;
wire valid_register_writeback;
wire valid_commit_writeback;
wire [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] writeback_instruction_ID;
wire memory_valid;
wire commit_memory_valid;
wire  report;
wire [DATA_WIDTH-1:0] ALU1_rs2_data_bypass;
wire [DATA_WIDTH-1:0] ALU2_rs2_data_bypass;
wire [ADDRESS_BITS-1:0] inst_PC_fetch;
wire [ADDRESS_BITS-1:0] JALR_target_execute;     
wire [ADDRESS_BITS-1:0] branch_target_execute;
wire i_valid;
wire valid_decode;
wire valid_execute;
wire JAL_detected;
wire branch;
wire [ADDRESS_BITS-1:0] branch_target;
wire [ADDRESS_BITS-1:0] JALR_target;
wire [1:0] next_PC_select;
wire [DATA_WIDTH-1:0] load_data_memory;
wire queue_ready;
wire [1:0] PC_select_commit_to_writeback;
wire [1:0] PC_select_writeback;
wire [1:0] PC_select_writeback_to_fetch;
wire [ADDRESS_BITS-1:0] JALR_target_commit_to_writeback;
wire [ADDRESS_BITS-1:0] JALR_target_writeback;
wire [ADDRESS_BITS-1:0] branch_target_commit_to_writeback;
wire [ADDRESS_BITS-1:0] branch_target_writeback;
wire branch_detected;
wire branch_bit;
wire memory_ready_commmit;  
wire store_pause;    
wire [ADDRESS_BITS-1:0] store_PC;       
reg  [31: 0] cycles;

assign rs1 =  instruction_to_system[19:15]; 
assign rs2 =  instruction_to_system[24:20];
assign rd  =  instruction_to_system[11:7];  
assign commited_instruction_result = commited_instruction;

// Test bench
assign scheduled_instruction     = instruction_to_system;
assign scheduled_instruction_PC  = scheduled_packet[inst_PC_end_bit : inst_PC_start_bit ];
assign cycle_count               = cycles;
assign scheduler_valid           = valid_to_system; 
assign register_writeback        = rd_writeback;
assign writeback_register_data   = register_write_data;

fetch_unit #(CORE, DATA_WIDTH, INDEX_BITS, OFFSET_BITS, ADDRESS_BITS, PROGRAM,
              PRINT_CYCLES_MIN, PRINT_CYCLES_MAX ) IF (
        .clock(clock),
        .reset(reset),
        .start(3'b100),
        .stall(~queue_ready),
        .next_PC_select_execute(next_PC_select_execute),          
        .program_address(20'b0),    
        .JAL_target(JAL_target_execute),
        .JALR_target(JALR_target),
        .branch(branch_bit),
        .branch_target(branch_target),
        .JAL_detected(JAL_detected),
        .store_pause(store_pause),
        .store_PC(store_PC),

        .instruction(instruction_fetch),
        .inst_PC(inst_PC_fetch),
        .valid(i_valid),
        .ready(i_ready),
        .report(1'b0)
);

fetch_pipe_unit #(DATA_WIDTH, ADDRESS_BITS) IF_ID(
        .clock(clock),
        .reset(reset),
        .stall(1'b0),                 //stall needed for cache
        .instruction_fetch(instruction_fetch),
        .inst_PC_fetch(inst_PC_fetch),
        .valid_fetch(i_valid),
        .JAL_detected(JAL_detected),
      
        .instruction_decode(instruction_fetch_to_decode),
        .inst_PC_decode(inst_PC_decode),
        .valid_decode(valid_decode)
 );
 
decode_unit #(CORE, ADDRESS_BITS, DATA_WIDTH, PRINT_CYCLES_MIN,
              PRINT_CYCLES_MAX) ID (
        .clock(clock),
        .reset(reset),
        .PC(inst_PC_decode),
        .instruction(instruction_fetch_to_decode),        
        .extend_sel(extend_sel_decode),

        .opcode(opcode_decode),
        .funct3(funct3_decode),
        .funct7(funct7_decode),
        .extend_imm(extend_imm_decode),
        .branch_target(branch_target_decode),
        .JAL_target(JAL_target_decode),
        .instruction_decode(instruction_decode),
        .report(1'b0)
);

control_unit #(CORE, PRINT_CYCLES_MIN, PRINT_CYCLES_MAX ) CU (
        .clock(clock),
        .reset(reset),

        .opcode(opcode_decode),
        .branch_op(branch_op_decode),
        .memRead(memRead_decode),
        .memtoReg(memtoReg),
        .ALUOp(ALUOp_decode),
        .memWrite(memWrite_decode),
        .next_PC_sel(next_PC_select_decode),
        .operand_A_sel(operand_A_sel_decode),
        .operand_B_sel(operand_B_sel_decode),
        .extend_sel(extend_sel_decode),
        .regWrite(regWrite_decode),
        .JAL_detected(JAL_detected),
        .report(1'b0)
);

decode_pipe_unit #(DATA_WIDTH, ADDRESS_BITS) ID_EU(
        .clock(clock),
        .reset(reset),
        
        .valid_decode(valid_decode),
        .packet_decode(control_and_decode_packet_decode),
        .instruction_decode(instruction_decode),
        .next_PC_select_decode(next_PC_select_decode),
        .JAL_target_decode(JAL_target_decode),
        .next_PC_select_writeback(PC_select_writeback_to_fetch),
              
        .valid_execute(valid_execute),
        .instruction_execute(instruction_execute),
        .next_PC_select_packet(), // for troubleshooting
        .next_PC_select_fetch(next_PC_select_execute),
        .JAL_target_execute(JAL_target_execute),
        .packet_queue(control_and_decode_packet_queue)
       
);


instruction_queue #(DATA_WIDTH, REGISTER_BITS, RDS_IN_SCHEDULDER,
                          INSTRUCTION_QUEUE_SIZE, ADDRESS_BITS ) IQ (
                          
        .clock(clock),
        .reset(reset),
        .instruction(instruction_execute),
        .fetch_valid(valid_execute),
        .rd_bits_in_scheduler(rd_bits_in_scheduler),
        .decode_packet(control_and_decode_packet_queue),
        .scheduler_ready(ready),
        .branch_writeback(branch_detected),
        .memory_ready(memory_ready_commmit),
        
        .ready(queue_ready),
        .queued_instruction(instruction_to_scheduler),
        .queued_decode_packet(queued_decode_packet),
        .store_PC(store_PC),
        .store_pause(store_pause),
        .valid_instruction_bit(valid_queue_instruction),
        //test bench
        .hazard_table_TB(hazard_table_TB),      
        .inner_hazard_table_TB(inner_hazard_table_TB),
        .queue_table_in_use_TB(queue_table_in_use_TB)
);  
         
scheduler #(DATA_WIDTH, NUMBER_OF_FUNCTIONAL_UNITS, NUMBER_OF_ACTIVE_INSTRUCTIONS,
                           REGISTER_BITS, ADDRESS_BITS) SCH (
              
        .clock(clock),
        .reset(reset),
        .instruction(instruction_to_scheduler),
        .queue_valid(valid_queue_instruction),
        .writeback_instruction_id(writeback_instruction_ID),
        .decode_packet(queued_decode_packet),
        .writeback_valid(valid_register_writeback),
        .ALU1_ready(ALU1_ready),
        .ALU2_ready(ALU2_ready),
        
        .scheduled_instruction(instruction_to_system),
        .instruction_id(instruction_id),
        .unit(unit),
        .rds_in_scheduler(rd_bits_in_scheduler),
        .scheduled_packet(scheduled_packet),
        .ready(ready),                           
        .valid_instruction(valid_to_system)
       
);

regFile #(DATA_WIDTH, REGISTER_BITS) regfile (
       
        .clock(clock),
        .reset(reset),
        .read_sel1(rs1), 
        .read_sel2(rs2),
        .wEn(write), 
        .write_sel(rd_writeback), 
        .write_data(register_write_data), 
        .read_data1(rs1_data),
        .read_data2(rs2_data)                                                    
); 

execution_unit #(CORE, DATA_WIDTH, ADDRESS_BITS,
                 PRINT_CYCLES_MIN, PRINT_CYCLES_MAX, ALU1_CYCLES,
                 ALU2_CYCLES, NUMBER_OF_ACTIVE_INSTRUCTIONS) EU (
        .clock(clock),
        .reset(reset),
        .scheduled_packet(scheduled_packet),
        .regRead_1(rs1_data),
        .regRead_2(rs2_data),
        .unit(unit),
        .start(valid_to_system),
        .instruction_ID(instruction_id),
        .rd(rd),
          
        .ALU1_rd(ALU1_rd),
        .ALU1_zero(ALU1_zero),
        .ALU1_valid(ALU1_valid),
        .ALU1_branch(ALU1_branch),
        .ALU1_result(ALU1_result),
        .ALU1_instruction_ID(ALU1_instruction_ID),
        .ALU1_packet(ALU1_packet),
        .ALU1_rs2_data_bypass(ALU1_rs2_data_bypass),
        
        .ALU2_rd(ALU2_rd),
        .ALU2_zero(ALU2_zero),
        .ALU2_valid(ALU2_valid),
        .ALU2_branch(ALU2_branch),
        .ALU2_result(ALU2_result),
        .ALU2_instruction_ID(ALU2_instruction_ID),
        .ALU2_packet(ALU2_packet),
        .ALU2_rs2_data_bypass(ALU2_rs2_data_bypass),

        .ALU1_ready(ALU1_ready),
        .ALU2_ready(ALU2_ready),
        .branch(branch),
        .branch_target(branch_target_execute),
        .JALR_target(JALR_target_execute),
        .next_PC_select(next_PC_select),
        .report(1'b0)
);

commit #(DATA_WIDTH, NUMBER_OF_QUEUED_INSTRUCTIONS,REGISTER_BITS, ADDRESS_BITS,
                     COMMIT_BACKLOG_LENGTH, NUMBER_OF_ACTIVE_INSTRUCTIONS)  commit (

        .clock(clock),
        .reset(reset),
        
        .ALU1_rd(ALU1_rd),
        .ALU1_zero(ALU1_zero),
        .ALU1_valid(ALU1_valid),
        .ALU1_branch(ALU1_branch),
        .ALU1_result(ALU1_result),
        .ALU1_instruction_ID(ALU1_instruction_ID),
        .ALU1_packet(ALU1_packet),
        .ALU1_rs2_data_bypass(ALU1_rs2_data_bypass),
        
        .ALU2_rd(ALU2_rd),
        .ALU2_zero(ALU2_zero),
        .ALU2_valid(ALU2_valid),
        .ALU2_branch(ALU2_branch),
        .ALU2_result(ALU2_result),
        .ALU2_instruction_ID(ALU2_instruction_ID),
        .ALU2_packet(ALU2_packet),
        .ALU2_rs2_data_bypass(ALU2_rs2_data_bypass),
         
        .JALR_target_execute(JALR_target_execute),
        .branch_target_execute(branch_target_execute),       
        .load_data(load_data_memory),
        .ready_memory(ready_memory),
        .valid_memory(valid_memory),
        
        .memory_ready_commit(memory_ready_commmit),        
        .commited_instruction(commited_instruction),
        .commit_instruction_ID(finished_instruction_ID),
        .writeback_rd(rd_writeback_commit),
        .valid_commit_bit(valid_instruction_bit),
        .regWrite(regWrite_commit),
        .memWrite(memWrite_commit),
        .memRead_memory(memRead_memory_commit),
        .generated_address(generated_address_commit),
        .rs2_data_store(rs2_data_store_commit),
        .ALU_result_writeback(ALU_result_writeback_commit),
        .commit_memory_valid(commit_memory_valid),
        .PC_select(PC_select_commit_to_writeback),
        .JALR_target(JALR_target_commit_to_writeback),
        .branch_target(branch_target_commit_to_writeback),
        .branch(branch_commit_to_writeback)      
                  
);

commit_pipe_unit #(DATA_WIDTH, ADDRESS_BITS, NUMBER_OF_ACTIVE_INSTRUCTIONS) CM_WB_MEM (

         .clock(clock),
         .reset(reset),
         
         .commit_writeback_valid(valid_instruction_bit),
         .commit_memory_valid(commit_memory_valid),
         .ALU_result_commit(ALU_result_writeback_commit),
         .generated_address_commit(generated_address_commit),
         .opwrite_commit(regWrite_commit),
         .opsel_commit(memRead_memory_commit),
         .opReg_commit(rd_writeback_commit),
         .memWrite_commit(memWrite_commit),
         .commit_instruction_ID(finished_instruction_ID),
         .store_data_commit(rs2_data_store_commit),
         .memRead_commit(memRead_memory_commit),
         .regWrite_commit(regWrite_commit),
         .PC_select_commit(PC_select_commit_to_writeback),
         .JALR_target_commit(JALR_target_commit_to_writeback),
         .branch_target_commit(branch_target_commit_to_writeback),
         .branch_commit(branch_commit_to_writeback),
         
         .generated_address_memory(generated_address_memory),
         .store_data_memory(rs2_data_store_memory),
         .memWrite_memory(memWrite_memory),
         .memRead_memory(memRead_memory),
         .valid_commit_memory(memory_valid),

         .regWrite_writeback(regWrite_writeback),
         .ALU_result_writeback(ALU_result_writeback),
         .opwrite_writeback(),
         .opReg_writeback(write_register),
         .valid_commit_writeback(valid_commit_writeback),
         .writeback_instruction_ID(commit_instruction_ID),
         .PC_select_writeback(PC_select_writeback),
         .JALR_target_writeback(JALR_target_writeback),
         .branch_target_writeback(branch_target_writeback),
         .branch_writeback(branch_writeback)
);
       
memory_unit #(CORE, DATA_WIDTH, INDEX_BITS, OFFSET_BITS, ADDRESS_BITS,
              PRINT_CYCLES_MIN, PRINT_CYCLES_MAX ) MU (
        .clock(clock),
        .reset(reset),

        .load(memRead_memory),
        .store(memWrite_memory),
        .opSel(memRead_memory),
        .address(generated_address_memory),
        .store_data(rs2_data_store_memory),
        .valid_address(memory_valid),
        
        .data_addr(data_addr_memory),
        .load_data(load_data_memory),
        .valid_load(valid_memory),
        .ready(ready_memory),

        .report(1'b0)
);

writeback_unit #(CORE, DATA_WIDTH, PRINT_CYCLES_MIN, PRINT_CYCLES_MAX,
                   NUMBER_OF_ACTIVE_INSTRUCTIONS,  NUMBER_OF_QUEUED_INSTRUCTIONS, ADDRESS_BITS
                                                                    ) WB (
        .clock(clock),
        .reset(reset),
        .valid_commit(valid_commit_writeback),
        .commit_instruction_ID(commit_instruction_ID),
        .opReg(write_register),
        .ALU_Result(ALU_result_writeback),
        .opWrite(regWrite_writeback),
        .PC_select_commit(PC_select_writeback),
        .JALR_target_commit(JALR_target_writeback),
        .branch_target_commit(branch_target_writeback),
        .branch_commit(branch_writeback),
        
        .write(write),
        .write_reg(rd_writeback),
        .write_data(register_write_data),
        .valid(valid_register_writeback),
        .writeback_instruction_ID(writeback_instruction_ID),
        .PC_select_writeback(PC_select_writeback_to_fetch),
        .JALR_target_writeback(JALR_target),
        .branch_target_writeback(branch_target),
        .branch_writeback(branch_bit),
        .branch_detected_writeback(branch_detected),
        
        .report(1'b0)
);

//reg [31: 0] cycles; 
always @ (posedge clock) begin 
    cycles <= reset? 0 : cycles + 1; 
end

endmodule
