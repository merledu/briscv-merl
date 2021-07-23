




module scheduler # (parameter DATA_WIDTH = 32, NUMBER_OF_FUNCTIONAL_UNITS = 2, 
                               NUMBER_OF_ACTIVE_INSTRUCTIONS = 2, RD_BITS = 5,
                               ADDRESS_BITS = 20 )( 
    input clock, 
    input reset,                   
    input [DATA_WIDTH-1:0] instruction,
    input queue_valid,
    input [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] writeback_instruction_id,
    input [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] decode_packet,
    input writeback_valid,
    input ALU1_ready,
    input ALU2_ready,
    
    output [DATA_WIDTH-1:0] scheduled_instruction,
    output [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] instruction_id, 
    output [log2(NUMBER_OF_FUNCTIONAL_UNITS)-1:0] unit,  
    output [(NUMBER_OF_FUNCTIONAL_UNITS*RD_BITS)-1:0] rds_in_scheduler,  
    output [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] scheduled_packet,      
    output ready,
    output valid_instruction
    
);

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

// TODO: Add the ability to have a pipelined ALU so active instructions and functional units
//  do not have to be equal. 

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

// define decoded opcode                //functional unit//
localparam [6:0] R_TYPE  = 7'b0110011,  // alu
                 I_TYPE  = 7'b0010011,  // alu
                 STORE   = 7'b0100011,  // memory
                 LOAD    = 7'b0000011,  // memory
                 BRANCH  = 7'b1100011,  // alu
                 JALR    = 7'b1100111,  // alu
                 JAL     = 7'b1101111,  // not sure yet, memory for testing
                 AUIPC   = 7'b0010111,  // alu
                 LUI     = 7'b0110111,  // alu
                 FENCES  = 7'b0001111,  // not sure yet, memory for testing
                 SYSCALL = 7'b1110011;  // not sure yet, memory for testing
            
localparam NOP = 32'h00000013;

wire [DATA_WIDTH-1:0]                          instructions_mux   [0:NUMBER_OF_ACTIVE_INSTRUCTIONS-1];
wire [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] instruction_id_mux [0:NUMBER_OF_ACTIVE_INSTRUCTIONS-1]; 
wire [6:0] opcode;
wire [DATA_WIDTH-1:0] instruction_valid_mux;

//  register table
reg [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0]    instruction_IDs [0:NUMBER_OF_ACTIVE_INSTRUCTIONS-1];  
reg [log2(NUMBER_OF_FUNCTIONAL_UNITS)-1:0]       units_needed    [0:NUMBER_OF_FUNCTIONAL_UNITS-1];  //equal to number of active instructions
reg [DATA_WIDTH-1:0]                             instructions    [0:NUMBER_OF_ACTIVE_INSTRUCTIONS-1];
reg [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] packets         [0:NUMBER_OF_ACTIVE_INSTRUCTIONS-1];

reg [NUMBER_OF_ACTIVE_INSTRUCTIONS-1:0] table_row_in_use;              
reg [NUMBER_OF_ACTIVE_INSTRUCTIONS-1:0] table_row_sent_out; 
reg past_unit;

assign opcode =  instruction_valid_mux[6:0];
assign instruction_valid_mux = (queue_valid)? instruction : NOP;
     
//  ready is high as long as aviliable execution unit and table z is not full
assign ready = ~&table_row_sent_out;

//  valid bit output given buffer has data 
assign valid_instruction = ~&table_row_sent_out;

//  outputs           
assign instruction_id          =  unit; //instructin id equals functional unit for now as they only support 1 instruction at a time
assign scheduled_instruction   = (queue_valid)? instruction : NOP;
assign scheduled_packet        = (queue_valid)? decode_packet : 130'b0;
assign unit                    = (ALU1_ready & (~ALU2_ready))? 1'b0: 
                                 ((ALU2_ready & ~ALU1_ready) | (ALU2_ready & past_unit == 1'b0))? 1'b1: 1'b0;

//  chain connected muxes for instruction ID and instruction output
genvar h;
generate 
    for (h=0; h < NUMBER_OF_ACTIVE_INSTRUCTIONS; h=h+1) begin
        //  take the rd from each instruction 
        //  if sw consider rs1 the stored address an rd for hazards. 
  
        assign  rds_in_scheduler[(RD_BITS*h) + RD_BITS-1 : (RD_BITS*h)] = instructions[h][11:7];  

        if(h < NUMBER_OF_ACTIVE_INSTRUCTIONS-1)begin
            assign instruction_id_mux[h]  = (table_row_in_use[h] & ~table_row_sent_out[h])  ?
                                                                    instruction_IDs[h]      :    
                                                                    instruction_id_mux[h+1] ;  
                                                                          
            assign instructions_mux[h]    = (table_row_in_use[h] & ~table_row_sent_out[h])  ? 
                                                                    instructions[h]         :    
                                                                    instructions_mux[h+1]   ;  
        end
        else begin
            assign instruction_id_mux[h]  = (table_row_in_use[h] & ~table_row_sent_out[h]) ? 
                                                                       instruction_IDs[h]  :    
                                              {log2(NUMBER_OF_ACTIVE_INSTRUCTIONS){1'b0}}  ; 
                                              
            assign instructions_mux[h]    = (table_row_in_use[h] & ~table_row_sent_out[h]) ? 
                                                                          instructions[h]  :  
                                                                                      NOP  ;                                                                       
        end
    end  
endgenerate
 
// filling in table units based on incoming, writeback_id, instruction, and valid    
always @(posedge clock) begin 
       if(reset)begin
            table_row_in_use        <=   {{log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1 {1'b0}} ,1'b1};
            table_row_sent_out      <=   {log2(NUMBER_OF_ACTIVE_INSTRUCTIONS){1'b0}};
            past_unit               <= 1'b0;
       end
       else begin         
            //  fill in table based on incoming writeback and new instruction
            instructions[unit]                            <= (~valid_instruction)?  instructions[writeback_instruction_id] :
                                                                                                    instruction_valid_mux  ;
            packets[unit]                                 <=  (~valid_instruction)?      packets[writeback_instruction_id] :
                                                                                                            decode_packet  ;                                                                                      
 
            units_needed[writeback_instruction_id]        <= (~writeback_valid) ? units_needed[writeback_instruction_id]    :
                                                             ((opcode == R_TYPE) | (opcode == I_TYPE) | (opcode == BRANCH)  
                                                              |(opcode == JALR)  | (opcode == AUIPC)   | (opcode == LUI))    ? 1:0;      
                                                                       
            table_row_in_use[writeback_instruction_id]    <=  table_row_sent_out[writeback_instruction_id]; 
                                                                                                                                                              
            table_row_sent_out[writeback_instruction_id]  <= (writeback_valid)? 1'b0: 
                                                             ((writeback_instruction_id == instruction_id ) && valid_instruction )?  1'b1:
                                                              table_row_sent_out[writeback_instruction_id];
                                                                 
            table_row_sent_out[instruction_id]            <=  (valid_instruction)? 1'b1 : 
                                                              ((writeback_instruction_id == instruction_id) && writeback_valid )?  1'b0:
                                                              table_row_sent_out[instruction_id] ;  
            past_unit                                     <=  unit;

        end      
end

// clear instructions and fill instruction ID table
genvar i;
generate 
    for (i=0; i<NUMBER_OF_ACTIVE_INSTRUCTIONS; i=i+1) begin
    always@ (posedge clock) begin 
        if(reset) begin
            instructions[i]     <= NOP;
            instruction_IDs[i]  <= i;      
        end
        else begin    
        end   
    end
end
endgenerate                             
endmodule
