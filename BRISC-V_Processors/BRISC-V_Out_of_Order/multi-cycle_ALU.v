/** @module : ALU
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

module ALU #(parameter DATA_WIDTH = 32, CYCLE_TIME = 4, ADDRESS_BITS = 20, 
                        NUMBER_OF_ACTIVE_INSTRUCTIONS = 2, RD_BITS = 5 )(
    input reset,
    input start,
    input clock,
    input [5:0] ALU_Control,
    input [DATA_WIDTH-1:0] rs2_bypass,
    input [DATA_WIDTH-1:0]  operand_A,
    input [DATA_WIDTH-1:0]  operand_B,
    input [RD_BITS-1 :0] rd,
    input [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] instruction_ID,
    input [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] decode_packet,
    input [DATA_WIDTH-1:0] JALR_regRead1,
    
    output delayed_zero, delayed_branch, valid, ready,
    output [DATA_WIDTH-1:0] delayed_ALU_result,
    output [RD_BITS-1 :0] delayed_rd,
    output [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] delayed_instruction_ID,
    output [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] delayed_packet,
    output [DATA_WIDTH-1:0] delayed_rs1_data_bypass,
    output [DATA_WIDTH-1:0] delayed_rs2_data_bypass

);
 // TODO: Update start and valid logics for piplined varible cycle ALU

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

//localparam RD_BITS = 5;

wire [DATA_WIDTH-1:0] ALU_result;
wire [4:0] shamt = operand_B [4:0];     // I_immediate[4:0];
wire [(DATA_WIDTH*2)-1:0] arithmatic_shift;
wire zero;
wire branch;

reg  [DATA_WIDTH-1:0] shift_register     [CYCLE_TIME-1 :0];
reg  [DATA_WIDTH-1:0] rs1_shift_register [CYCLE_TIME-1 :0];
reg  [DATA_WIDTH-1:0] rs2_shift_register [CYCLE_TIME-1 :0];
reg  [RD_BITS-1 :0]   rd_shift_register  [CYCLE_TIME-1 :0]; 
reg  [CYCLE_TIME-1:0] valid_register;
reg  [CYCLE_TIME-1:0] branch_register;
reg  [CYCLE_TIME-1:0] zero_register;

reg  [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] packet_shift_register   [CYCLE_TIME-1 :0];
reg  [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS):0]      instruction_ID_register [CYCLE_TIME-1 :0];

// TODO: add ALU fixes from 5 cycle (signed operations)
assign zero   = (ALU_result==0);
assign branch = ((ALU_Control[4:3] == 2'b10) & (ALU_result == 1'b1))? 1'b1 : 1'b0;
// Signed shift
assign arithmatic_shift = ({ {DATA_WIDTH{operand_A[DATA_WIDTH-1]}}, operand_A }) >> shamt;

assign ALU_result   =
            (ALU_Control == 6'b000_000)? operand_A + operand_B:                       /* ADD, ADDI*/
            (ALU_Control == 6'b001_000)? operand_A - operand_B:                       /* SUB */
            (ALU_Control == 6'b000_100)? operand_A ^ operand_B:                       /* XOR, XORI*/
            (ALU_Control == 6'b000_110)? operand_A | operand_B:                       /* OR, ORI */
            (ALU_Control == 6'b000_111)? operand_A & operand_B:                       /* AND, ANDI */
            (ALU_Control == 6'b000_010)? operand_A < operand_B:                       /* SLT, SLTI */
            (ALU_Control == 6'b000_011)? operand_A < operand_B:                       /* SLTU, SLTIU */
            (ALU_Control == 6'b000_001)? operand_A << shamt:                          /* SLL, SLLI => 0's shifted in from right */
            (ALU_Control == 6'b000_101)? operand_A >> shamt:                          /* SRL, SRLI => 0's shifted in from left */
            (ALU_Control == 6'b001_101)? arithmatic_shift[DATA_WIDTH-1:0]:            /* SRA, SRAI => sign bit shifted in from left */
            (ALU_Control == 6'b011_111)? operand_A:                                   /* operand_A = PC+4 for JAL   and JALR */
            (ALU_Control == 6'b010_000)? (operand_A == operand_B):                    /* BEQ */
            (ALU_Control == 6'b010_001)? (operand_A != operand_B):                    /* BNE */
            (ALU_Control == 6'b010_100)? (operand_A < operand_B):                     /* BLT */
            (ALU_Control == 6'b010_101)? (operand_A >= operand_B):                    /* BGE */
            (ALU_Control == 6'b010_110)? (operand_A < operand_B):                     /* BLTU */
            (ALU_Control == 6'b010_111)? (operand_A >= operand_B): {DATA_WIDTH{1'b0}};/* BGEU */

//assign last slot in the delay shift registers to the output of ALU
assign delayed_ALU_result      = shift_register          [CYCLE_TIME-1];
assign valid                   = valid_register          [CYCLE_TIME-1];
assign delayed_branch          = branch_register         [CYCLE_TIME-1];
assign delayed_zero            = zero_register           [CYCLE_TIME-1];
assign delayed_rd              = rd_shift_register       [CYCLE_TIME-1];
assign delayed_instruction_ID  = instruction_ID_register [CYCLE_TIME-1];
assign delayed_packet          = packet_shift_register   [CYCLE_TIME-1];
assign delayed_rs1_data_bypass = rs1_shift_register      [CYCLE_TIME-1];
assign delayed_rs2_data_bypass = rs2_shift_register      [CYCLE_TIME-1];
assign ready                   = ~| valid_register; // ready if nothing in the ALU 



                                                   // TODO: Update for piplined ALU

//first location in delay shift registers is the input
    always @(posedge clock) begin
        if(reset)begin
             zero_register[0]           <= 1'b0;  
             valid_register[0]          <= 1'b0;
             shift_register[0]          <= {DATA_WIDTH{1'b0}};   
             branch_register[0]         <= 1'b0;            
             rd_shift_register[0]       <= {RD_BITS{1'b0}};
             rs1_shift_register[0]      <= {DATA_WIDTH{1'b0}};   
             rs2_shift_register[0]      <= {DATA_WIDTH{1'b0}};   
             packet_shift_register[0]   <= {(DATA_WIDTH + (ADDRESS_BITS*3) + 38){130'b0}};
             instruction_ID_register[0] <= {log2(NUMBER_OF_ACTIVE_INSTRUCTIONS){1'b0}};
             
        end
        else begin
             zero_register[0]           <= zero;
             valid_register[0]          <= start;
             shift_register[0]          <= ALU_result;  
             branch_register[0]         <= branch;
             rd_shift_register[0]       <= rd;
             rs1_shift_register[0]      <= JALR_regRead1;
             rs2_shift_register[0]      <= rs2_bypass;
             packet_shift_register[0]   <= decode_packet;
             instruction_ID_register[0] <= instruction_ID;
             
        end                
    end

//for each cycle of alu add a register and have its output shift outward
genvar i;
generate 
    for(i=1; i < CYCLE_TIME; i= i+1)begin
    always @(posedge clock) begin
            if(reset)begin
                zero_register[i]           <= 1'b0;
                valid_register[i]          <= 1'b0;
                shift_register[i]          <= {DATA_WIDTH{1'b0}};              
                branch_register[i]         <= 1'b0;
                rd_shift_register[i]       <= {RD_BITS{1'b0}}; 
                rs1_shift_register[i]      <= {DATA_WIDTH{1'b0}};      
                rs2_shift_register[i]      <= {DATA_WIDTH{1'b0}};      
                packet_shift_register[i]   <= {(DATA_WIDTH + (ADDRESS_BITS*3) + 38){130'b0}};
                instruction_ID_register[i] <= {log2(NUMBER_OF_ACTIVE_INSTRUCTIONS){1'b0}};   
            end
            else begin
                zero_register[i]           <= zero_register[i-1];
                valid_register[i]          <= valid_register[i-1];
                shift_register[i]          <= shift_register[i-1];
                branch_register[i]         <= branch_register[i-1];
                rd_shift_register[i]       <= rd_shift_register[i-1];
                rs1_shift_register[i]      <= rs1_shift_register[i-1]; 
                rs2_shift_register[i]      <= rs2_shift_register[i-1]; 
                packet_shift_register[i]   <= packet_shift_register[i-1];
                instruction_ID_register[i] <= instruction_ID_register[i-1];
            end
        end
    end    
endgenerate
            
endmodule