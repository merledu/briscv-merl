module commit # ( parameter DATA_WIDTH = 32, NUMBER_OF_QUEUED_INSTRUCTIONS = 4, RD_BITS = 5, ADDRESS_BITS = 20, 
                            COMMIT_BACKLOG_LENGTH = 4, NUMBER_OF_ACTIVE_INSTRUCTIONS = 2                    )(
    input clock,
    input reset,
    //input speculated_bit,
    //input interrupt_bit,
    input [RD_BITS-1:0] ALU1_rd,    // add rs2_data pass through
    input ALU1_zero,
    input ALU1_valid,
    input ALU1_branch,
    input [DATA_WIDTH-1:0] ALU1_result,
    input [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] ALU1_instruction_ID,    
    input [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] ALU1_packet,     
    input [DATA_WIDTH-1:0] ALU1_rs2_data_bypass,
    
    input [RD_BITS-1:0] ALU2_rd,           
    input ALU2_zero,
    input ALU2_valid,          
    input ALU2_branch,        
    input [DATA_WIDTH-1:0] ALU2_result,        
    input [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] ALU2_instruction_ID,
    input [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] ALU2_packet,   
    input [DATA_WIDTH-1:0] ALU2_rs2_data_bypass,  
    
    input [ADDRESS_BITS-1:0] JALR_target_execute,
    input [ADDRESS_BITS-1:0] branch_target_execute,
    input [DATA_WIDTH-1:0] load_data,
    input ready_memory,
    input valid_memory,
    
    output memory_ready_commit,
    output [DATA_WIDTH-1:0] commited_instruction,
    output [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] commit_instruction_ID,
    output [RD_BITS-1:0] writeback_rd,
    output valid_commit_bit,
    output regWrite,
    output memWrite,
    output memRead_memory,
    output [ADDRESS_BITS-1:0] generated_address,
    output [DATA_WIDTH-1:0] rs2_data_store,
    output [DATA_WIDTH-1:0] ALU_result_writeback,
    output commit_memory_valid,
    output [1:0] PC_select,
    output [ADDRESS_BITS-1:0] JALR_target,
    output [ADDRESS_BITS-1:0] branch_target,
    output branch
);

// module is set as a pass through for now allowing for basic instructions with out hazards to out of order commit.
 
// TODO: add logic for interrupt logic
// TODO: set up backlog 
// TODO: Parameterize ALU_rlogicd, ALU_zero, Alu_valid, ALU_branch, Alu-result, and ALU_instruction_ID 
// TODO: change commited instruction to commited_instruction_data
// TODO: change valid_instruction_bit to valid_data_bit
// TODO: FP_ALUs inputs and logic for their commit
// TODO: In order commit

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
           
localparam [6:0] JALR    = 7'b1100111,
                 BRANCH  = 7'b1100011;
           
wire ALU1_branch_detected;                             
wire ALU2_branch_detected;
wire memRead_decoded; 
wire memWrite_decoded;
wire [ADDRESS_BITS-1:0] address_decoded;
wire valid_mem;
                                                                                                                         
reg [NUMBER_OF_QUEUED_INSTRUCTIONS-1 :0]         table_row_in_use;
reg [log2(NUMBER_OF_QUEUED_INSTRUCTIONS):0]      instruction_ID_table [NUMBER_OF_QUEUED_INSTRUCTIONS-1 :0];
reg [DATA_WIDTH-1:0]                             instruction_table    [NUMBER_OF_QUEUED_INSTRUCTIONS-1 :0];
reg [RD_BITS-1:0]                                rd_table             [NUMBER_OF_QUEUED_INSTRUCTIONS-1 :0];
reg [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] packet_store         [NUMBER_OF_QUEUED_INSTRUCTIONS-1 :0];  
reg [ADDRESS_BITS-1: 0]                          JALR_store           [NUMBER_OF_QUEUED_INSTRUCTIONS-1 :0];  
reg valid_bit;
reg [NUMBER_OF_QUEUED_INSTRUCTIONS-1 :0]          branch_store;

// Same cycle ALU valid register store.
reg [RD_BITS-1:0] ALU2_rd_store;           
reg ALU2_zero_store;
reg ALU2_valid_store;          
reg ALU2_branch_store;        
reg [DATA_WIDTH-1:0] ALU2_result_store;        
reg [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] ALU2_instruction_ID_store;
reg [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] ALU2_packet_store;
reg [DATA_WIDTH-1:0] ALU2_rs2_data_bypass_store;
reg ALU2_branch_detected_store; 
reg [ADDRESS_BITS-1: 0] JALR_target_execute_store;

// memory store
reg [RD_BITS-1:0] ALU2_rd_memory;           
reg ALU2_zero_memory;
reg valid_memory_store;          
reg ALU2_branch_memory;        
reg [DATA_WIDTH-1:0] ALU2_result_memory;        
reg [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] ALU2_instruction_ID_memory;
reg [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] ALU2_packet_memory;

assign ALU1_branch_detected   =  ((ALU1_packet[opcode_end_bit:opcode_start_bit] == JALR) || 
                                  (ALU1_packet[opcode_end_bit:opcode_start_bit] == BRANCH))? 1'b1: 1'b0;
                              
assign ALU2_branch_detected   =  ((ALU2_packet[opcode_end_bit:opcode_start_bit] == JALR) || 
                                  (ALU2_packet[opcode_end_bit:opcode_start_bit] == BRANCH))? 1'b1: 1'b0;

assign memRead_decoded        =  (ALU1_valid)?                 ALU1_packet[memRead_bit]        :  
                                 (ALU2_valid && ~ALU1_valid)?  ALU2_packet[memRead_bit]        :
                                 (ALU2_valid_store)?           ALU2_packet_store[memRead_bit]  :
                                                               1'b0                            ;
                                                                
assign memWrite_decoded       =  (ALU1_valid)?                 ALU1_packet[memWrite_bit]       :
                                 (ALU2_valid && ~ALU1_valid)?  ALU2_packet[memWrite_bit]       :
                                 (ALU2_valid_store)?           ALU2_packet_store[memWrite_bit] :
                                                               1'b0                            ; 
                                                               
assign address_decoded        =  (ALU1_valid)?                 ALU1_result        :
                                 (ALU2_valid && ~ALU1_valid)?  ALU2_result        :
                                 (ALU2_valid_store)?           ALU2_result_store  :
                                                               {DATA_WIDTH{1'b0}} ;
  
assign valid_mem = (ALU1_valid && (memRead_decoded |memWrite_decoded))?        ALU1_valid       :                  
                   (ALU2_valid && (memRead_decoded |memWrite_decoded))?        ALU2_valid       :                  
                   (ALU2_valid_store && (memRead_decoded |memWrite_decoded))?  ALU2_valid_store : 
                                                                               1'b0             ;   
//branch outputs
assign JALR_target     = JALR_store[0];
assign branch_target   = packet_store[0][branch_target_end_bit  : branch_target_start_bit];
assign PC_select       = packet_store[0][next_PC_select_end_bit : next_PC_select_start_bit];

assign regWrite        = packet_store[0][regWrite_bit];
assign branch          = branch_store[0];

assign memory_ready_commit = valid_memory; //may be too soon and need a register.

//not implemented yet
// reg [NUMBER_OF_QUEUED_INSTRUCTIONS-1 :0] speculated_bit_table;
// reg [NUMBER_OF_QUEUED_INSTRUCTIONS-1 :0] interrupt_bit_table;

assign ALU_result_writeback     =  (valid_memory)? load_data: instruction_table [0];
assign commited_instruction     =  instruction_table [0];
assign commit_instruction_ID    =  instruction_ID_table[0];
assign writeback_rd             =  rd_table[0];
assign valid_commit_bit         =  valid_bit;


// memory access assignment
assign memRead_memory      = memRead_decoded;
assign memWrite            = memWrite_decoded;
assign generated_address   = address_decoded;
assign commit_memory_valid = valid_mem;
assign rs2_data_store      = (ALU1_valid)? ALU1_rs2_data_bypass : 
                             (ALU2_valid)? ALU2_rs2_data_bypass :
                             (ALU2_valid_store)? ALU2_rs2_data_bypass_store  :
                                                         {DATA_WIDTH{1'b0}}  ; 

// right now all intructions are commited in the order them came in even if 
// out of order from the scheduler, Will work because hazards affected have been resolved in queue.
// in order will be better for the future with interrupts

// Branch is either JALR, or branch. JAL are handled in the decode pipe.

always@(posedge clock) begin
    if(reset)begin
        table_row_in_use            <= {NUMBER_OF_QUEUED_INSTRUCTIONS-1{1'b0}};
       
        valid_bit                   <= 1'b0;
         ALU2_rd_store              <= {RD_BITS{1'b0}};                                          
         ALU2_zero_store            <= 1'b0;                                
         ALU2_valid_store           <= 1'b0;                                   
         ALU2_branch_store          <= 1'b0;                                   
         ALU2_result_store          <= {DATA_WIDTH{1'b0}};                                   
         ALU2_packet_store          <= 130'b0;                                  
         ALU2_rs2_data_bypass_store <= {DATA_WIDTH{1'b0}};                                                                      
         ALU2_instruction_ID_store  <= {log2(NUMBER_OF_QUEUED_INSTRUCTIONS){1'b0}};  
         ALU2_branch_detected_store <= 1'b0;    
         ALU2_rd_memory             <= {RD_BITS{1'b0}}; 
         ALU2_zero_memory           <= 1'b0;     
         valid_memory_store         <= 1'b0;     
         ALU2_branch_memory         <= 1'b0;     
         ALU2_result_memory         <= {DATA_WIDTH{1'b0}}; 
         ALU2_packet_memory         <= 130'b0;
         ALU2_instruction_ID_memory <= {log2(NUMBER_OF_QUEUED_INSTRUCTIONS){1'b0}};  
    end
    else begin
         //if both ALUs ready at the same time store ALU2 results
         ALU2_rd_store               <= (ALU1_valid && ALU2_valid)? ALU2_rd     : 
                                                            {RD_BITS{1'b0}}     ;                   
         ALU2_zero_store             <= (ALU1_valid && ALU2_valid)? ALU2_zero   : 
                                                                         1'b0   ;           
         ALU2_valid_store            <= (ALU1_valid && ALU2_valid)? ALU2_valid  :
                                                                         1'b0   ;
         ALU2_branch_store           <= (ALU1_valid && ALU2_valid)? ALU2_branch :
                                                                         1'b0   ;
         ALU2_result_store           <= (ALU1_valid && ALU2_valid)? ALU2_result :
                                                             {DATA_WIDTH{1'b0}} ; 
         ALU2_packet_store           <= (ALU1_valid && ALU2_valid)? ALU2_packet :
                                                                         130'b0 ;
                                                                         
         ALU2_rs2_data_bypass_store  <= (ALU1_valid && ALU2_valid)? ALU2_rs2_data_bypass :
                                                                      {DATA_WIDTH{1'b0}} ; 
                                                                                                                                       
         ALU2_instruction_ID_store   <= (ALU1_valid && ALU2_valid)? ALU2_instruction_ID :
                                            {log2(NUMBER_OF_QUEUED_INSTRUCTIONS){1'b0}} ;
                                                     
         ALU2_branch_detected_store  <= (ALU1_valid && ALU2_valid)? ALU2_branch_detected :
                                                                                    1'b0 ;
         JALR_target_execute_store   <= (ALU1_valid && ALU2_valid)?   JALR_target_execute :
                                                                     {ADDRESS_BITS{1'b0}} ; 
         //store memory access instruction data                                                                          //TODO: remove ALU2 in front
         valid_memory_store            <= ((ALU1_valid | ALU2_valid) && valid_memory)? valid_memory :  
                                                                                       1'b0 ;  
         ALU2_rd_memory               <= ((memRead_decoded |memWrite_decoded) & ALU1_valid && ~valid_memory)? ALU1_rd :
                                         ((memRead_decoded |memWrite_decoded) & ALU2_valid && ~valid_memory)? ALU2_rd :
                                                                                                              ALU2_rd_memory ;    
                                                                                               
         ALU2_zero_memory             <= ((memRead_decoded |memWrite_decoded) && ALU1_valid)? ALU1_zero   :
                                         ((memRead_decoded |memWrite_decoded) && ALU2_valid)? ALU2_zero   :          
                                                                                        ALU2_zero_memory  ;        
       
         ALU2_branch_memory           <= ((memRead_decoded |memWrite_decoded) && ALU1_valid)? ALU1_branch :
                                         ((memRead_decoded |memWrite_decoded) && ALU2_valid)? ALU2_branch :  
                                                                                       ALU2_branch_memory ;        
         ALU2_result_memory           <=   (valid_memory) ? load_data : 
                                                   ALU2_result_memory ;        
                                                   
         ALU2_packet_memory           <= ((memRead_decoded |memWrite_decoded) && ALU1_valid && ~valid_memory)? ALU1_packet :
                                         ((memRead_decoded |memWrite_decoded) && ALU2_valid && ~valid_memory)? ALU2_packet :
                                                                                                        ALU2_packet_memory ;
                                                                                                        
         ALU2_instruction_ID_memory   <= ((memRead_decoded |memWrite_decoded) && ALU1_valid && ~valid_memory)? ALU1_instruction_ID :
                                         ((memRead_decoded |memWrite_decoded) && ALU2_valid && ~valid_memory)? ALU2_instruction_ID :
                                                                                                        ALU2_instruction_ID_memory ;
                                                                                                                                                       
         table_row_in_use[0]          <= 1'b1;
         
         valid_bit                    <= (ALU1_valid)? ALU1_valid :
                                         (ALU2_valid)? ALU2_valid :
                                         (ALU2_valid_store)? ALU2_valid_store: 1'b0;
    end
end

// picking the output if stored
genvar i;
generate
    for(i=0; i <NUMBER_OF_QUEUED_INSTRUCTIONS; i= i+1) begin
        always@(posedge clock)begin
            if(reset)begin
                instruction_ID_table[i] <=  {log2(NUMBER_OF_QUEUED_INSTRUCTIONS){1'b0}};
                instruction_table   [i] <=  {DATA_WIDTH{1'b0}}; 
                rd_table            [i] <=  {RD_BITS{1'b0}};
                packet_store        [i] <=  130'b0;     
                JALR_store          [i] <=  {ADDRESS_BITS{1'b0}}; 
                branch_store        [i] <=  1'b0;
                
            end
            else begin // this is for inorder commit when there can be muliple items in commit to choose from.
                instruction_ID_table[i] <=   (ALU1_valid)?                   ALU1_instruction_ID         :
                                             (ALU2_valid && ~ALU1_valid)?    ALU2_instruction_ID         : 
                                             (ALU2_valid_store)?             ALU2_instruction_ID_store   :
                                             (valid_memory && ~ALU1_valid)?  ALU2_instruction_ID_memory  : 
                                             (valid_memory_store)?           ALU2_instruction_ID_memory  :
                                                                             {log2(NUMBER_OF_ACTIVE_INSTRUCTIONS){1'b0}} ;
                                             
                instruction_table[i]    <=   (ALU1_valid)?                   ALU1_result        :                         
                                             (ALU2_valid && ~ALU1_valid)?    ALU2_result        :
                                             (ALU2_valid_store)?             ALU2_result_store  :
                                             (valid_memory && ~ALU1_valid)?  load_data          :
                                             (valid_memory_store)?           ALU2_result_memory :
                                                                             {DATA_WIDTH{1'b0}} ;  
                                              
                rd_table[i]              <=  (ALU1_valid)?                   ALU1_rd         :
                                             (ALU2_valid && ~ALU1_valid)?    ALU2_rd         : 
                                             (ALU2_valid_store)?             ALU2_rd_store   :
                                             (valid_memory && ~ALU1_valid)?  ALU2_rd_memory  :
                                             (valid_memory_store)?           ALU2_rd_memory  :
                                                                             {RD_BITS{1'b0}} ;                            
                                                    
                packet_store[i]          <=  (ALU1_valid)?                   ALU1_packet        :                         
                                             (ALU2_valid && ~ALU1_valid)?    ALU2_packet        :
                                             (ALU2_valid_store)?             ALU2_packet_store  :
                                             (valid_memory && ~ALU1_valid)?  ALU2_packet_memory :    
                                             (valid_memory_store)?           ALU2_packet_memory :        
                                                                                         130'b0 ;               
                                              
                JALR_store[i]            <=  (ALU1_valid)?                   JALR_target_execute :                         
                                             (ALU2_valid && ~ALU1_valid)?    JALR_target_execute :
                                             (ALU2_valid_store)?             JALR_target_execute_store :
                                                                                  {ADDRESS_BITS{1'b0}} ;
                                                                          
                branch_store [i]         <=  (ALU1_valid)?                   ALU1_branch       :                         
                                             (ALU2_valid && ~ALU1_valid)?    ALU2_branch       :
                                             (ALU2_valid_store)?             ALU2_branch_store :
                                                                                          1'b0 ;        
            end
        end
    end
endgenerate

endmodule