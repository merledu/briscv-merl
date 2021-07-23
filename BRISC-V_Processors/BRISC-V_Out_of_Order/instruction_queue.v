
module instruction_queue  # (parameter DATA_WIDTH = 32, RD_BITS = 5, RDS_IN_SCHEDULDER = 4,
                                       INSTRUCTION_QUEUE_SIZE = 4, ADDRESS_BITS = 20 )(
    input clock, 
    input reset, 
    input [DATA_WIDTH-1:0] instruction,
    input fetch_valid,
    input [( RD_BITS*RDS_IN_SCHEDULDER)-1:0] rd_bits_in_scheduler,
    input [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] decode_packet,
    input scheduler_ready,
    input branch_writeback, // both store and branch high in writeback
    input memory_ready,
       
    output ready,  
    output [DATA_WIDTH-1:0] queued_instruction,
    output [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] queued_decode_packet,
    output [ADDRESS_BITS-1:0] store_PC,
    output store_pause,
    output valid_instruction_bit,       
    
    // test bench
    output [INSTRUCTION_QUEUE_SIZE-1:0] hazard_table_TB,
    output [INSTRUCTION_QUEUE_SIZE-1:0] inner_hazard_table_TB,
    output [INSTRUCTION_QUEUE_SIZE-1:0] queue_table_in_use_TB

    );
         
    // TODO: add a way to handle interrupts
          
//  define the log2 function
function integer log2;
    input integer num;
    integer i, result;
    begin
        for (i = 0; 2 ** i < num; i = i + 1)
            result = i + 1;
        log2 = result;    end
endfunction
    
localparam NOP = 32'h00000013;    
           
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
                 STORE   = 7'b0100011,
                 LOAD    = 7'b0000011,
                 BRANCH  = 7'b1100011;
 
wire branch_store_writeback;
wire branch_instruction;                                 
wire queued_memory_access_instruction;                                       
wire queued_branch_instruction;
wire is_valid;                                                                                  
wire store_instruction; 
wire branch_store_instruction;    
wire [1:0] next_PC_select_IQ;
wire [4:0]  rs1;
wire [4:0]  rs2;         
                                                                                                            
wire [DATA_WIDTH-1:0] instruction_valid_mux;
wire in_use_valid_mux;
wire [INSTRUCTION_QUEUE_SIZE-1:0]  hazard_detected_table;
wire [INSTRUCTION_QUEUE_SIZE-1:0]  inner_hazard_detected_table;
wire [INSTRUCTION_QUEUE_SIZE-1:0]  external_hazard_detected_table;
wire [RDS_IN_SCHEDULDER-1:0]       rs1_hazard_detected       [INSTRUCTION_QUEUE_SIZE-1:0];
wire [RDS_IN_SCHEDULDER-1:0]       rs2_hazard_detected       [INSTRUCTION_QUEUE_SIZE-1:0]; 
wire [INSTRUCTION_QUEUE_SIZE-1:0]  inner_rs1_hazard_detected [INSTRUCTION_QUEUE_SIZE-1:0];
wire [INSTRUCTION_QUEUE_SIZE-1:0]  inner_rs2_hazard_detected [INSTRUCTION_QUEUE_SIZE-1:0];
wire [RDS_IN_SCHEDULDER-1:0]       hazard_detected           [INSTRUCTION_QUEUE_SIZE-1:0];
wire [INSTRUCTION_QUEUE_SIZE-1:0]  inner_hazard_detected     [INSTRUCTION_QUEUE_SIZE-1:0];
wire [RD_BITS-1:0]                 rd                        [0:RDS_IN_SCHEDULDER-1];
wire [RD_BITS-1:0]                 inner_rd                  [0:INSTRUCTION_QUEUE_SIZE-1];

wire [log2(INSTRUCTION_QUEUE_SIZE)-1:0] scheduler_selected;
wire [log2(INSTRUCTION_QUEUE_SIZE)-1:0] scheduler_selected_mux          [0:INSTRUCTION_QUEUE_SIZE-1];
wire [log2(INSTRUCTION_QUEUE_SIZE)-1:0] buffer_selected;
wire [log2(INSTRUCTION_QUEUE_SIZE)-1:0] buffer_selected_mux             [0:INSTRUCTION_QUEUE_SIZE-1];
wire [DATA_WIDTH-1:0]                   selected_instruction_mux        [0:INSTRUCTION_QUEUE_SIZE-1];

wire [(DATA_WIDTH + (ADDRESS_BITS*3) -1 + 38): 0]  selected_packet_mux  [0:INSTRUCTION_QUEUE_SIZE-1];

wire final_hazard_check;
wire single_memory_access;
wire valid;

reg [log2(INSTRUCTION_QUEUE_SIZE)-1:0]  buffer_location      [0:INSTRUCTION_QUEUE_SIZE-1]; 
reg [DATA_WIDTH-1:0]                    stored_instructions  [0:INSTRUCTION_QUEUE_SIZE-1]; 
reg [0:4]                               stored_rs1           [0:INSTRUCTION_QUEUE_SIZE-1];
reg [0:4]                               stored_rs2           [0:INSTRUCTION_QUEUE_SIZE-1];

reg [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] stored_packet  [0:INSTRUCTION_QUEUE_SIZE-1];
reg [INSTRUCTION_QUEUE_SIZE-1:0]  hazard_table;
reg [INSTRUCTION_QUEUE_SIZE-1:0]  inner_hazard_table;
reg [INSTRUCTION_QUEUE_SIZE-1:0]  table_row_in_use; 

reg [log2(INSTRUCTION_QUEUE_SIZE)-1:0] scheduler_selected_old; 
reg [log2(INSTRUCTION_QUEUE_SIZE)-1:0] buffer_selected_old;
reg [log2(INSTRUCTION_QUEUE_SIZE)-1:0] fetch_count;
reg branch_store_out;      // high once detected branch store is sent out.
reg branch_store_detected; // check if PC_select is a JALR or Branch insturction, or store. 
                           // Stop being ready until branch_writeback/ store is recieved.
                           // not as safe at the branch detected.
reg one_cycle_ready;
reg memory_busy;
reg empty_after_store;
reg branch_detected; // on branch no valid insturctions allowed in, until branch is finished. 
reg valid_old;
reg [log2(INSTRUCTION_QUEUE_SIZE)-1:0]  buffer_selected_reg;
reg [DATA_WIDTH-1:0] instruction_old;
reg [INSTRUCTION_QUEUE_SIZE-1:0] inner_hazard_reg;
reg [INSTRUCTION_QUEUE_SIZE-1:0] external_hazard_reg;
reg [INSTRUCTION_QUEUE_SIZE-1:0] hazard_reg;

assign branch_store_writeback           =   (branch_writeback | memory_ready);

assign branch_instruction               =   ((decode_packet[opcode_end_bit:opcode_start_bit] == JALR) || 
                                             (decode_packet[opcode_end_bit:opcode_start_bit] == BRANCH))? 1'b1: 1'b0 ;
                                          
assign queued_memory_access_instruction =   ((queued_decode_packet[opcode_end_bit:opcode_start_bit] == STORE) || 
                                             (queued_decode_packet[opcode_end_bit:opcode_start_bit] == LOAD))? 1'b1: 1'b0 ; 
                                          
assign queued_branch_instruction        =   ((queued_decode_packet[opcode_end_bit:opcode_start_bit] == JALR) || 
                                             (queued_decode_packet[opcode_end_bit:opcode_start_bit] == BRANCH))? 1'b1: 1'b0 ;  

assign is_valid                         =   (branch_store_detected  && ~table_row_in_use[scheduler_selected_old])? 1'b0 : 1'b0 ; 
                                                                                  
assign store_instruction                =   (decode_packet[opcode_end_bit:opcode_start_bit] == STORE)? 1'b1: 1'b0 ;  
 
assign branch_store_instruction         =   branch_instruction || store_instruction;   
  
assign next_PC_select_IQ                =   decode_packet[next_PC_select_end_bit:next_PC_select_start_bit];  
assign rs1                              =   instruction_valid_mux[19:15];
assign rs2                              =   instruction_valid_mux[24:20];     
assign single_memory_access             =   ~(queued_memory_access_instruction && memory_busy);
assign final_hazard_check               =   (hazard_table[scheduler_selected_old] == 1'b0)? 1'b1: 1'b0;
//  muxs for filling the queue with the incoming instruction provided it is valid
assign instruction_valid_mux            =   (valid)? instruction : NOP;
assign in_use_valid_mux                 =   (valid)? 1'b1 : 1'b0;
//  provided the buffer is not full of hazards, or the queue is full the queue is ready
assign ready                            =   (branch_store_detected | empty_after_store| branch_detected)? 1'b0  : 
                                                                              one_cycle_ready ; 
                                                                 // Keep this the same but add one more layer 
                                                                  // for empty queue after store instruction finished.
                                                                  // branch_store_detected OR with a bit called empty_after_store
                                                 
// empty_after_store should go high when a store instruction comes in and stay high until the branch_store_instruction returns 
// and the result of OR table_row_in_use returns zero.  
                                                                                                              
assign queued_instruction    = (|table_row_in_use)? stored_instructions[scheduler_selected_old]: NOP;
assign queued_decode_packet  = (|table_row_in_use)? stored_packet[scheduler_selected_old]: 130'b0;
assign buffer_selected       = buffer_selected_mux[0];
assign scheduler_selected    = scheduler_selected_mux[0];
assign hazard_table_TB       = hazard_table;
assign inner_hazard_table_TB = inner_hazard_table;
assign queue_table_in_use_TB = table_row_in_use;
 

assign valid_instruction_bit = (scheduler_ready && final_hazard_check     && 
                                single_memory_access && ~branch_store_out && 
                                table_row_in_use[scheduler_selected_old])?     1'b1 :
                                
                               (branch_store_detected                     && 
                                table_row_in_use[scheduler_selected_old]  && 
                                final_hazard_check && scheduler_ready)?        1'b1 : 
                                                                               1'b0 ;
                                                                               
assign store_PC              = (store_instruction && valid)?   decode_packet[inst_PC_end_bit:inst_PC_start_bit] :   
                                                               {ADDRESS_BITS {1'b0}}                            ;
                                                               
assign store_pause           = (store_instruction && valid)? store_instruction: 1'b0 ;  

assign valid                 = (empty_after_store | branch_store_detected | branch_detected)?  1'b0 : 
                                                                                               fetch_valid ;

// !hazards and !in_use mux chain to select next instruction spot in buffer
// !hazard and in_use_mux chain to select output instruction
genvar h;
generate 
    for (h=0; h<INSTRUCTION_QUEUE_SIZE; h=h+1) begin
         if(h<INSTRUCTION_QUEUE_SIZE-1)begin
            assign buffer_selected_mux[h]       =  (~table_row_in_use[h]) ?           buffer_location[h]        :   
                                                                                      buffer_selected_mux[h+1]  ;
            assign selected_instruction_mux[h]  =  ((table_row_in_use[h]) &&
                                                    (~hazard_table[h])    &&
                                                    (buffer_selected_old != h)) ?     stored_instructions [h]       :
                                                                                      selected_instruction_mux[h+1] ;
                                                   
            assign selected_packet_mux[h]       =  ((table_row_in_use[h]) &
                                                    (~hazard_table[h])    &&
                                                   (buffer_selected_old != h)) ?      stored_packet[h]         :
                                                                                      selected_packet_mux[h+1] ;  
                                                                                      
            assign scheduler_selected_mux[h]    =  ((table_row_in_use[h]) &&
                                                   (~hazard_table[h])     &&
                                                   (scheduler_selected_old != h)) ?   buffer_location[h]          :   
                                                                                      scheduler_selected_mux[h+1] ;                                                                   
         end 
         else begin
            assign buffer_selected_mux[h]        = (~table_row_in_use[h]) ?            buffer_location[h]   :   
                                                                                      ~buffer_selected_old ;
                                                                           
            assign selected_instruction_mux[h]   = ((table_row_in_use[h]) &&
                                                    (~hazard_table[h]))?              stored_instructions[h] :
                                                                                      stored_instructions[h] ;
                                                                                               
            assign selected_packet_mux[h]        = ((table_row_in_use[h]) &&
                                                    (~hazard_table[h])) ?             stored_packet[h] :
                                                                                      130'b0           ; 
                                                                                                
            assign scheduler_selected_mux[h]    =  ((table_row_in_use[h]) &&
                                                    (~hazard_table[h])) ?             buffer_location[h]          :   
                                                   (scheduler_selected_old != 0) ?    (scheduler_selected_old -1) :
                                                                                      INSTRUCTION_QUEUE_SIZE-1    ;                                                                                                                                                                                                                                     
       end
    end 
endgenerate          

// connect input rd to individual rds
genvar r;
generate
     for (r=0; r<RDS_IN_SCHEDULDER; r=r+1) begin
        assign rd[r] = rd_bits_in_scheduler[((RD_BITS*r) + (RD_BITS-1)) : (RD_BITS*r)];
     end
endgenerate

// compare buffered instructions rs1 and rs2 to all rd's down the pipe
genvar i;
genvar j;
genvar d;
generate
    for (i=0; i<INSTRUCTION_QUEUE_SIZE; i=i+1) begin
        assign inner_rd[i] = (table_row_in_use[i])? stored_instructions[i][11:7]: 5'b0;
        for (j=0; j<RDS_IN_SCHEDULDER; j=j+1) begin
            assign rs1_hazard_detected[i][j] = ((stored_rs1[i] == rd[j]) && (rd[j] !=5'b0))? 1'b1 : 1'b0;
            assign rs2_hazard_detected[i][j] = ((stored_rs2[i] == rd[j]) && (rd[j] !=5'b0))? 1'b1 : 1'b0;
            assign hazard_detected[i][j]     = (rs1_hazard_detected[i] | rs2_hazard_detected[i])? 1'b1 : 1'b0;
        end
        for (d=0; d<INSTRUCTION_QUEUE_SIZE; d = d+1) begin
             assign inner_rs1_hazard_detected[i][d] = ((stored_rs1[i] == inner_rd[d]) && (inner_rd[d] !=5'b0) && (d != i))? 1'b1 : 1'b0;
             assign inner_rs2_hazard_detected[i][d] = ((stored_rs2[i] == inner_rd[d]) && (inner_rd[d] !=5'b0) && (d != i))? 1'b1 : 1'b0;
             assign inner_hazard_detected[i][d]     = (inner_rs1_hazard_detected[i] | inner_rs2_hazard_detected[i])? 1'b1 : 1'b0;
        end
            assign hazard_detected_table [i]         =  (|hazard_detected[i]) || (|inner_hazard_detected[i]);
            assign inner_hazard_detected_table [i]   =  (|inner_hazard_detected[i]);
            assign external_hazard_detected_table[i] =  (|hazard_detected[i]);
    end    
endgenerate

// Stores the instructions and stored packets based on which buffer location is selected.
// TODO: move one_cycle_ready down to fetch requests
always @(posedge clock) begin 
    if(reset)begin
        hazard_table             <= {log2(INSTRUCTION_QUEUE_SIZE){1'b0}}; 
        inner_hazard_table       <= {log2(INSTRUCTION_QUEUE_SIZE){1'b0}}; 
        buffer_selected_old      <= {log2(INSTRUCTION_QUEUE_SIZE){1'b0}}; 
        scheduler_selected_old   <= {log2(INSTRUCTION_QUEUE_SIZE){1'b0}}; 
        inner_hazard_reg         <= {log2(INSTRUCTION_QUEUE_SIZE){1'b0}}; 
        external_hazard_reg      <= {log2(INSTRUCTION_QUEUE_SIZE){1'b0}}; 
        hazard_reg               <= {log2(INSTRUCTION_QUEUE_SIZE){1'b0}}; 
        one_cycle_ready          <= 1'b0;
        instruction_old          <=   NOP;
     
    end    
    else begin                                      
        stored_instructions[buffer_selected]     <= (valid)?   instruction_valid_mux                :
                                                               stored_instructions[buffer_selected] ;
        stored_packet[buffer_selected]           <= (valid)?   decode_packet                  : 
                                                               stored_packet[buffer_selected] ;
                                                               
        buffer_selected_old                      <= (buffer_selected_old == buffer_selected) ?        ~table_row_in_use: 
                                                                                                      buffer_selected  ;
                                                                                               
        scheduler_selected_old                   <= (scheduler_selected_old == scheduler_selected) ?  ~table_row_in_use  : 
                                                                                                      scheduler_selected ;                                    
        one_cycle_ready                          <= ((one_cycle_ready)                          && 
                                                    (fetch_count == (INSTRUCTION_QUEUE_SIZE-2)) &&
                                                     (~branch_store_detected)) ?                     1'b0:  
                                                    ((INSTRUCTION_QUEUE_SIZE-1) != fetch_count) ?    1'b1: 
                                                                                                     1'b0;
       instruction_old                          <=   (valid)? instruction :instruction_old;
       inner_hazard_reg                         <= inner_hazard_detected_table;
       external_hazard_reg                      <= external_hazard_detected_table;
       hazard_reg                               <= hazard_detected_table;
                                                                                      
    end
end

// keep count number of fetch requests due to delay between queue and fecth unit.
// updates ready.
always @(posedge clock) begin
    if (reset)begin
        fetch_count                <=   2'b0; 
        branch_store_detected      <=   1'b0;
        memory_busy                <=   1'b0;
        empty_after_store          <=   1'b0;
        branch_store_out           <=   1'b0;
        branch_detected            <=   1'b0;
        valid_old                  <=   1'b0;
        buffer_selected_reg        <=   1'b0;

    end
    else if ((INSTRUCTION_QUEUE_SIZE-1) == fetch_count)begin
    
        fetch_count            <=   (~valid && valid_instruction_bit)?      (fetch_count -1) :
                                    (branch_store_writeback)?               fetch_count      :
                                                                            fetch_count      ;
                                                                             
        branch_store_detected  <=   ((branch_instruction && valid)  || 
                                    (store_instruction && valid))?          1'b1 : 
                                    ((queued_branch_instruction)    &&
                                    (valid_instruction_bit))?                1'b1 :
                                    (branch_store_writeback)?                1'b0 :
                                                                             branch_store_detected ;                      
        
        memory_busy            <=   ((queued_memory_access_instruction)&& 
                                     (valid_instruction_bit))?               1'b1 :
                                     (memory_ready)?                         1'b0 :
                                                                             memory_busy ;
                                                                             
        empty_after_store      <=   (store_instruction)      ?               1'b1 :
                                    (~|table_row_in_use)     ?               1'b0 :
                                                                             empty_after_store ;
                                                                
        branch_store_out       <=  ((branch_store_detected)            && 
                                   ((queued_memory_access_instruction) ||
                                    (queued_branch_instruction))       && 
                                   (valid_instruction_bit))?                 1'b1 : 
                                                                             1'b0 ;
                                                                                                          
        branch_detected        <=  ((branch_instruction && valid))?          1'b1 : 
                                     branch_writeback?                       1'b0 :
                                                                             branch_detected ;
        valid_old              <=    valid;
        buffer_selected_reg    <=    buffer_selected; 
    end
    else begin
      fetch_count             <=  (valid && ready)?                          fetch_count      :
                                  (valid && ~ready)?                         (fetch_count +1) :
                                  (~valid && valid_instruction_bit)?         (fetch_count -1) :
                                  (~valid && ready)?                         (fetch_count +1) :
                                                                             fetch_count      ;
      branch_store_detected   <=  ((branch_instruction && valid)      || 
                                   (store_instruction && valid))?            1'b1 :
                                  ((queued_branch_instruction)        && 
                                   valid_instruction_bit)?                   1'b1 : 
                                  (branch_store_writeback)?                  1'b0 :
                                                                             branch_store_detected ;   
                                                                                   
      memory_busy             <=  (queued_memory_access_instruction   && 
                                   (valid_instruction_bit))?                 1'b1 :
                                   (memory_ready)?                           1'b0 :
                                                                             memory_busy ;
                                                                                   
      empty_after_store        <=  (store_instruction)?                      1'b1 :
                                   (~|table_row_in_use)?                     1'b0 :
                                                                             empty_after_store;
                                           
      branch_store_out         <= ((branch_store_detected)            && 
                                  ((queued_memory_access_instruction) ||
                                   (queued_branch_instruction))       && 
                                   (valid_instruction_bit))?                 1'b1 : 
                                                                             1'b0 ;
                                   
      branch_detected          <=  ((branch_instruction && valid))?          1'b1 : 
                                     branch_writeback?                       1'b0 :
                                                                             branch_detected ;
      valid_old              <= valid;   
      buffer_selected_reg    <= buffer_selected;                                                                                                        
    end
end

// generate for items in table not updated by buffer selected
genvar k;
generate 
    for (k=0; k<INSTRUCTION_QUEUE_SIZE; k=k+1) begin
    always@ (posedge clock) begin 
        if(reset) begin
           stored_rs1[k]           <= 5'b1;
           stored_rs2[k]           <= 5'b1;
           stored_packet[k]        <= 130'b0;
           buffer_location[k]      <= k;
           table_row_in_use[k]     <= 1'b0;   
           stored_instructions[k]  <= NOP;              
        end
        else begin    // clear old rs1, and rs2 also free row once an instruction leaves the queue 
            hazard_table[k]        <=  ((inner_hazard_reg == hazard_reg && hazard_reg != 4'b0) && 
                                        (external_hazard_reg == 4'b0))? inner_hazard_table[k] :
                                                                                 hazard_detected_table [k];                                            
            //ToDo: rename this so its reflects that its resolving hazard deadlocks
            inner_hazard_table[k]  <= ((valid_old) && (buffer_selected_reg == k) //breaks hazard deadlocks.
                                       && (instruction_old == stored_instructions[buffer_selected_reg]))? inner_hazard_detected_table[k]:
                                       (valid_instruction_bit && (scheduler_selected_old == k))?   1'b0:                                                   
                                      inner_hazard_table[k];
                                                                                                                  
            table_row_in_use[k]    <=  ((buffer_selected == k) && valid)?                         valid               :   
                                       ((scheduler_selected_old == k)  && 
                                       (valid_instruction_bit))?                                  1'b0                :
                                                                                                  table_row_in_use[k] ;

            stored_rs1[k]          <=  ((buffer_selected == k) && valid)?                         rs1             :        
                                       ((scheduler_selected_old == k) && valid_instruction_bit)?  {RD_BITS{1'b0}} :    
                                                                                                  stored_rs1[k]   ;        
                                                                                                   
            stored_rs2[k]          <=  (buffer_selected == k)?                                     rs2             :       
                                        ((scheduler_selected_old == k) && valid_instruction_bit)?  {RD_BITS{1'b0}} :      
                                                                                                   stored_rs2[k]   ;       
                                                                                        
        end                                
    end
end
endgenerate

endmodule