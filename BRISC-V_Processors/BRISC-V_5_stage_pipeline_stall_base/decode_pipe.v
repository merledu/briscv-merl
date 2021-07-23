/** @module : decode_pipe_unit
 *  @author : Adaptive & Secure Computing Systems (ASCS) Laboratory
 
 *  Copyright (c) 2018 BRISC-V (ASCS/ECE/BU)
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.

 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 */
//////////////////////////////////////////////////////////////////////////////////

module decode_pipe_unit #(parameter  DATA_WIDTH = 32,
                            ADDRESS_BITS = 20)(
    input clock, reset, stall,
    input [DATA_WIDTH-1:0] rs1_data_decode,
    input [DATA_WIDTH-1:0] rs2_data_decode,
    input [6:0] funct7_decode,
    input [2:0] funct3_decode,
    input [4:0] rd_decode,
    input [6:0] opcode_decode,
    input [DATA_WIDTH-1:0] extend_imm_decode,
    input [ADDRESS_BITS-1:0] branch_target_decode,
    input [ADDRESS_BITS-1:0] JAL_target_decode,
    input [ADDRESS_BITS-1:0] PC_decode,
    input branch_op_decode,
    input memRead_decode,
    input [2:0] ALUOp_decode,
    input memWrite_decode,
    input [1:0] next_PC_select_decode,
    input [1:0] next_PC_select_memory,
    input [1:0] operand_A_sel_decode,
    input operand_B_sel_decode,
    input regWrite_decode,
    input [DATA_WIDTH-1:0] instruction_decode,

    output [DATA_WIDTH-1:0] rs1_data_execute,
    output [DATA_WIDTH-1:0] rs2_data_execute,
    output [6:0] funct7_execute,
    output [2:0] funct3_execute,
    output [4:0] rd_execute,
    output [6:0] opcode_execute,
    output [DATA_WIDTH-1:0] extend_imm_execute,
    output [ADDRESS_BITS-1:0] branch_target_execute,
    output [ADDRESS_BITS-1:0] JAL_target_execute,
    output [ADDRESS_BITS-1:0] PC_execute,
    output branch_op_execute,
    output memRead_execute,
    output [2:0] ALUOp_execute,
    output memWrite_execute,
    output [1:0] next_PC_select_execute,
    output [1:0] operand_A_sel_execute,
    output operand_B_sel_execute,
    output regWrite_execute,
    output [DATA_WIDTH-1:0] instruction_execute
);

localparam NOP = 32'h00000013;

reg [DATA_WIDTH-1:0] rs1_data_decode_to_execute;
reg [DATA_WIDTH-1:0] rs2_data_decode_to_execute;
reg [6:0] funct7_decode_to_execute;
reg [2:0] funct3_decode_to_execute;
reg [4:0] rd_decode_to_execute;
reg [6:0] opcode_decode_to_execute;
reg [DATA_WIDTH-1:0] extend_imm_decode_to_execute;
reg [ADDRESS_BITS-1:0] branch_target_decode_to_execute;
reg [ADDRESS_BITS-1:0] JAL_target_decode_to_execute;
reg [ADDRESS_BITS-1:0] PC_decode_to_execute;
reg branch_op_decode_to_execute;
reg memRead_decode_to_execute;
reg [2:0] ALUOp_decode_to_execute;
reg memWrite_decode_to_execute;
reg [1:0] next_PC_select_decode_to_execute;
reg [1:0] operand_A_sel_decode_to_execute;
reg operand_B_sel_decode_to_execute;
reg regWrite_decode_to_execute;
reg [DATA_WIDTH-1:0] instruction_decode_to_execute;


assign  rs1_data_execute       = rs1_data_decode_to_execute;
assign  rs2_data_execute       = rs2_data_decode_to_execute;
assign  funct7_execute         = funct7_decode_to_execute;
assign  funct3_execute         = funct3_decode_to_execute;
assign  rd_execute             = rd_decode_to_execute;
assign  opcode_execute         = opcode_decode_to_execute;
assign  extend_imm_execute     = extend_imm_decode_to_execute;
assign  branch_target_execute  = branch_target_decode_to_execute;
assign  JAL_target_execute     = JAL_target_decode_to_execute;
assign  PC_execute             = PC_decode_to_execute;
assign  branch_op_execute      = branch_op_decode_to_execute;
assign  memRead_execute        = memRead_decode_to_execute;
assign  ALUOp_execute          = ALUOp_decode_to_execute;
assign  memWrite_execute       = memWrite_decode_to_execute;
assign  next_PC_select_execute    = next_PC_select_decode_to_execute;
assign  operand_A_sel_execute  = operand_A_sel_decode_to_execute;
assign  operand_B_sel_execute  = operand_B_sel_decode_to_execute;
assign  regWrite_execute       = regWrite_decode_to_execute;
assign  instruction_execute    = instruction_decode_to_execute;

always @(posedge clock) begin
    if(reset) begin
        rs1_data_decode_to_execute       <= {DATA_WIDTH{1'b0}};
        rs2_data_decode_to_execute       <= {DATA_WIDTH{1'b0}};
        funct7_decode_to_execute         <= 7'b0;
        funct3_decode_to_execute         <= 3'b0;
        rd_decode_to_execute             <= 5'b0;
        opcode_decode_to_execute         <= 7'b0;
        extend_imm_decode_to_execute     <= {DATA_WIDTH{1'b0}};
        branch_target_decode_to_execute  <= {ADDRESS_BITS{1'b0}};
        JAL_target_decode_to_execute     <= {ADDRESS_BITS{1'b0}};
        PC_decode_to_execute             <= {ADDRESS_BITS{1'b0}};
        branch_op_decode_to_execute      <= 1'b0;
        memRead_decode_to_execute        <= 1'b0;
        ALUOp_decode_to_execute          <= 3'b0;
        memWrite_decode_to_execute       <= 1'b0;
        next_PC_select_decode_to_execute <= 2'b0;
        operand_A_sel_decode_to_execute  <= 2'b0;
        operand_B_sel_decode_to_execute  <= 1'b0;
        regWrite_decode_to_execute       <= 1'b0;
        instruction_decode_to_execute    <= NOP;
    end
    else if(stall) begin
         // Send ADDI zero zero 0
         rs1_data_decode_to_execute       <= 5'd0;
         rs2_data_decode_to_execute       <= 5'd0;
         funct7_decode_to_execute         <= 7'd0;
         funct3_decode_to_execute         <= 3'd0;
         rd_decode_to_execute             <= 5'd0;
         opcode_decode_to_execute         <= 7'h13; // ADDi
         branch_target_decode_to_execute  <= branch_target_decode; // pass through target, held by holding inst_PC
         JAL_target_decode_to_execute     <= JAL_target_decode; // pass through target, held by holding inst_PC
         branch_op_decode_to_execute      <= 1'b0;
         memRead_decode_to_execute        <= 1'b0;
         ALUOp_decode_to_execute          <= 3'd1; // I type
         memWrite_decode_to_execute       <= 1'b0;
         next_PC_select_decode_to_execute <= next_PC_select_execute; // hold PC select
         operand_A_sel_decode_to_execute  <= 2'd0;
         operand_B_sel_decode_to_execute  <= 1'b1; // 1 for I type
         regWrite_decode_to_execute       <= 1'b1; // Decoded as 1, regfile prevents actual write
         extend_imm_decode_to_execute     <= {DATA_WIDTH{1'b0}};
         PC_decode_to_execute             <= {ADDRESS_BITS{1'b0}}; // should be held constant in fetch
         instruction_decode_to_execute    <= NOP;
    end
    else if( (next_PC_select_execute != 2'b00) || (next_PC_select_memory != 2'b00) ) begin
         // Send ADDI zero zero 0
         rs1_data_decode_to_execute       <= 5'd0;
         rs2_data_decode_to_execute       <= 5'd0;
         funct7_decode_to_execute         <= 7'd0;
         funct3_decode_to_execute         <= 3'd0;
         rd_decode_to_execute             <= 5'd0;
         opcode_decode_to_execute         <= 7'h13; // ADDi
         branch_target_decode_to_execute  <= {ADDRESS_BITS{1'b0}};
         JAL_target_decode_to_execute     <= {ADDRESS_BITS{1'b0}};
         branch_op_decode_to_execute      <= 1'b0;
         memRead_decode_to_execute        <= 1'b0;
         ALUOp_decode_to_execute          <= 3'd1; // I type
         memWrite_decode_to_execute       <= 1'b0;
         next_PC_select_decode_to_execute <= 2'd0;
         operand_A_sel_decode_to_execute  <= 2'd0;
         operand_B_sel_decode_to_execute  <= 1'b1; // 1 for I type
         regWrite_decode_to_execute       <= 1'b1; // Decoded as 1, regfile prevents actual write
         extend_imm_decode_to_execute     <= {DATA_WIDTH{1'b0}};
         PC_decode_to_execute             <= {ADDRESS_BITS{1'b0}}; // should be held constant in fetch
         instruction_decode_to_execute    <= NOP;
    end
    else begin
        rs1_data_decode_to_execute       <= rs1_data_decode;
        rs2_data_decode_to_execute       <= rs2_data_decode;
        funct7_decode_to_execute         <= funct7_decode;
        funct3_decode_to_execute         <= funct3_decode;
        rd_decode_to_execute             <= rd_decode;
        opcode_decode_to_execute         <= opcode_decode;
        branch_target_decode_to_execute  <= branch_target_decode;
        JAL_target_decode_to_execute     <= JAL_target_decode;
        branch_op_decode_to_execute      <= branch_op_decode;
        memRead_decode_to_execute        <= memRead_decode;
        ALUOp_decode_to_execute          <= ALUOp_decode;
        memWrite_decode_to_execute       <= memWrite_decode;
        next_PC_select_decode_to_execute <= next_PC_select_decode;
        operand_A_sel_decode_to_execute  <= operand_A_sel_decode;
        operand_B_sel_decode_to_execute  <= operand_B_sel_decode;
        regWrite_decode_to_execute       <= regWrite_decode;
        extend_imm_decode_to_execute     <= extend_imm_decode;
        PC_decode_to_execute             <= PC_decode;
        // For Debugging
        instruction_decode_to_execute    <= instruction_decode;
     end
end
endmodule





