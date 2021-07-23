
//////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////

module commit_pipe_unit #(parameter  DATA_WIDTH = 32,
                          ADDRESS_BITS = 20, NUMBER_OF_ACTIVE_INSTRUCTIONS = 2  )(

    input clock,reset,
    input commit_writeback_valid,
    input commit_memory_valid,
    input [DATA_WIDTH-1:0] ALU_result_commit,
    input [ADDRESS_BITS-1:0] generated_address_commit,
    input opwrite_commit,
    input opsel_commit,
    input [4:0] opReg_commit,
    input memWrite_commit,
    input [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] commit_instruction_ID,
    input [DATA_WIDTH-1:0] store_data_commit,
    input memRead_commit,
    input regWrite_commit,
    input  [1:0] PC_select_commit,
    input  [ADDRESS_BITS-1:0] JALR_target_commit,
    input  [ADDRESS_BITS-1:0] branch_target_commit,
    input  branch_commit,


    output [ADDRESS_BITS-1:0] generated_address_memory,
    output [DATA_WIDTH-1:0] store_data_memory,
    output memWrite_memory,
    output memRead_memory,
    output valid_commit_memory,
    
    output regWrite_writeback,   
    output [DATA_WIDTH-1:0] ALU_result_writeback,
    output opwrite_writeback,
   // output opsel_writeback,
    output [4:0] opReg_writeback,
    output valid_commit_writeback,
    output [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] writeback_instruction_ID,
    output [1:0] PC_select_writeback,
    output [ADDRESS_BITS-1:0] JALR_target_writeback,
    output [ADDRESS_BITS-1:0] branch_target_writeback,
    output branch_writeback
    );

localparam NOP = 32'h00000013;

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

// writeback registers
reg    commit_valid_to_writeback;
reg    [DATA_WIDTH-1:0] ALU_result_commit_to_writeback;
reg    opwrite_commit_to_writeback;
reg    opsel_commit_to_writeback;
reg    [4:0] opReg_commit_to_writeback;
reg    memWrite_commit_to_memory;
reg    [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0]  commit_instruction_ID_to_writeback;
reg    [1:0] PC_select_commit_to_writeback;
reg    [ADDRESS_BITS-1:0] JALR_target_commit_to_writeback;
reg    [ADDRESS_BITS-1:0] branch_target_commit_to_writeback;
reg    branch_commit_to_writeback;
reg    branch_detected_commit_to_writeback;
reg    regWrite_commit_to_writeback;

// memory registers
reg    [DATA_WIDTH-1:0] ALU_result_commit_to_memory;
reg    [DATA_WIDTH-1:0] store_data_commit_to_memory;
reg    memRead_commit_to_memory;
reg    commit_valid_to_commit_memory;
reg    [ADDRESS_BITS-1:0] generated_address_commit_to_memory;

//assign output to writeback
assign ALU_result_writeback       = ALU_result_commit_to_writeback;
assign opwrite_writeback          = opwrite_commit_to_writeback;
assign opsel_writeback            = opsel_commit_to_writeback;
assign opReg_writeback            = opReg_commit_to_writeback;
assign valid_commit_writeback     = commit_valid_to_writeback;
assign writeback_instruction_ID   = commit_instruction_ID_to_writeback;
assign PC_select_writeback        = PC_select_commit_to_writeback; 
assign JALR_target_writeback      = JALR_target_commit_to_writeback;
assign branch_target_writeback    = branch_target_commit_to_writeback;
assign branch_writeback           = branch_commit_to_writeback;
assign regWrite_writeback         = regWrite_commit_to_writeback;

// assign output to memory 
assign generated_address_memory   = generated_address_commit_to_memory; 
assign store_data_memory          = store_data_commit_to_memory;
assign memWrite_memory            = memWrite_commit_to_memory;
assign memRead_memory             = memRead_commit_to_memory; 
assign valid_commit_memory        = commit_valid_to_commit_memory;

always @(posedge clock) begin
    if(reset) begin
        // clear registers on reset
        ALU_result_commit_to_writeback      <= {DATA_WIDTH{1'b0}};
        opwrite_commit_to_writeback         <= 1'b0;
        opsel_commit_to_writeback           <= 1'b0;
        opReg_commit_to_writeback           <= 5'b0;
        commit_valid_to_writeback           <= 1'b0;
        commit_instruction_ID_to_writeback  <= {log2(NUMBER_OF_ACTIVE_INSTRUCTIONS){1'b0}};
        regWrite_commit_to_writeback        <= 1'b0;
        ALU_result_commit_to_memory         <= {DATA_WIDTH{1'b0}};
        store_data_commit_to_memory         <= {DATA_WIDTH{1'b0}};
        memWrite_commit_to_memory           <= 1'b0;
        memRead_commit_to_memory            <= 1'b0;
        commit_valid_to_commit_memory       <= 1'b0;
        PC_select_commit_to_writeback       <= 2'b0;
        JALR_target_commit_to_writeback     <= {ADDRESS_BITS{1'b0}};
        branch_target_commit_to_writeback   <= {ADDRESS_BITS{1'b0}};
        branch_commit_to_writeback          <= 1'b0;   
        branch_detected_commit_to_writeback <= 1'b0;        
        generated_address_commit_to_memory  <= {ADDRESS_BITS{1'b0}};                   
    end
    else begin
        ALU_result_commit_to_writeback      <= ALU_result_commit;
        opsel_commit_to_writeback           <= opsel_commit;
        opReg_commit_to_writeback           <= opReg_commit;
        regWrite_commit_to_writeback        <= regWrite_commit;
        commit_valid_to_writeback           <= commit_writeback_valid;
        commit_instruction_ID_to_writeback  <= commit_instruction_ID;
        ALU_result_commit_to_memory         <= ALU_result_commit;
        store_data_commit_to_memory         <= store_data_commit;
        memWrite_commit_to_memory           <= memWrite_commit;
        memRead_commit_to_memory            <= memRead_commit;
        commit_valid_to_commit_memory       <= commit_memory_valid;
        PC_select_commit_to_writeback       <= PC_select_commit;
        JALR_target_commit_to_writeback     <= JALR_target_commit;
        branch_target_commit_to_writeback   <= branch_target_commit;
        branch_commit_to_writeback          <= branch_commit;
        generated_address_commit_to_memory  <= generated_address_commit;        
   end
end
endmodule