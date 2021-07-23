/** @module : execute
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
 
// 32-bit Exection 
module execution_unit #(parameter CORE = 0, DATA_WIDTH = 32, ADDRESS_BITS = 20,
                         PRINT_CYCLES_MIN = 1, PRINT_CYCLES_MAX = 1000,
                         ALU1_CYCLES = 5, ALU2_CYCLES =4 , 
                         NUMBER_OF_ACTIVE_INSTRUCTIONS = 2 )(
        clock, reset, 
        scheduled_packet,
        regRead_1, regRead_2, unit, 
        start, instruction_ID, rd,   
         
        ALU1_rd, ALU1_zero, ALU1_valid,
        ALU1_branch, 
        ALU1_result, ALU1_instruction_ID,
        ALU1_packet,
        ALU1_rs2_data_bypass,
        
        ALU2_rd, ALU2_zero, ALU2_valid,
        ALU2_branch, 
        ALU2_result, ALU2_instruction_ID,
        ALU2_packet,
        ALU2_rs2_data_bypass,
        ALU1_ready, ALU2_ready,
        branch, branch_target,    
        JALR_target, next_PC_select,
         
        report
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

localparam RD_BITS = 5;

input  clock; 
input  reset;  
input [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] scheduled_packet; 
input [DATA_WIDTH-1:0]  regRead_1 ;
input [DATA_WIDTH-1:0]  regRead_2 ;
input unit; 
input start;
input [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] instruction_ID;
input [RD_BITS-1 :0] rd;

        
output [RD_BITS-1:0] ALU1_rd;
output ALU1_zero;
output ALU1_valid;
output ALU1_branch;
output [DATA_WIDTH-1:0] ALU1_result;
output [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] ALU1_instruction_ID;
output [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] ALU1_packet; 
output [DATA_WIDTH-1:0] ALU1_rs2_data_bypass;

output [RD_BITS-1:0] ALU2_rd;
output ALU2_zero;
output ALU2_valid;
output ALU2_branch;
output [DATA_WIDTH-1:0] ALU2_result;
output [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] ALU2_instruction_ID;
output [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] ALU2_packet; 
output [DATA_WIDTH-1:0] ALU2_rs2_data_bypass;

output  ALU1_ready, ALU2_ready;
output  branch;
output  [ADDRESS_BITS-1:0] branch_target;
output  [ADDRESS_BITS-1:0] JALR_target;
output  [1:0] next_PC_select;
input report;



localparam [6:0] JALR  = 7'b1100111;
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
        
reg old_stall;
reg [ADDRESS_BITS-1:0] old_JALR_target;

wire [2:0] ALU_Operation    = scheduled_packet [ALUOp_end_bit : ALUOp_start_bit]  ;          
wire [6:0] funct7; 
wire [2:0] funct3;
wire [ADDRESS_BITS-1:0]  PC = scheduled_packet [inst_PC_end_bit : inst_PC_start_bit] ;
wire [1:0] ALU_ASrc; 
wire ALU_BSrc;

wire [DATA_WIDTH-1:0]  extend;

wire [5:0] ALU_Control = (ALU_Operation == 3'b011)? 
                         6'b011_111 :      //pass for JAL and JALR
                         (ALU_Operation == 3'b010)? 
                         {3'b010,funct3} : //branches

                         //R Type instructions
                         ({ALU_Operation, funct7} == {3'b000, 7'b0000000})? 
                         {3'b000,funct3} : 
                         ({ALU_Operation, funct7} == {3'b000, 7'b0100000})? 
                         {3'b001,funct3} :
                         (ALU_Operation == 3'b000)?                  
                         {3'b000,funct3} :

                         //I Type instructions
                         ({ALU_Operation, funct3, funct7} == {3'b001, 3'b101, 7'b0000000})? 
                         {3'b000,funct3} : 
                         ({ALU_Operation, funct3, funct7} == {3'b001, 3'b101, 7'b0100000})? 
                         {3'b001,funct3} : 
                         ({ALU_Operation, funct3} == {3'b001, 3'b101})? 
                         {3'b000,funct3} : 
                         (ALU_Operation == 3'b001)?                  
                         {3'b000,funct3} :
                         6'b000_000;      //addition

wire [DATA_WIDTH-1:0]  operand_A  =  (ALU_ASrc == 2'b01)? PC : 
                                     (ALU_ASrc == 2'b10)? (PC + 4) :
                                      regRead_1;

wire [DATA_WIDTH-1:0]  operand_B  =   (ALU_BSrc) ? extend : regRead_2;
wire   ALU1_data_valid;
wire   ALU2_data_valid;   
wire [DATA_WIDTH-1:0] ALU1_regRead_1;
wire [DATA_WIDTH-1:0] ALU2_regRead_1;
wire JARL1_ins  = ALU1_valid & (JALR == ALU1_packet[opcode_end_bit:opcode_start_bit]);      
wire JARL2_ins  = ALU2_valid & (JALR == ALU2_packet[opcode_end_bit:opcode_start_bit]);
wire [ADDRESS_BITS-1:0] ALU1_delayed_extend = ALU1_packet[extend_imm_end_bit:extend_imm_start_bit];
wire [ADDRESS_BITS-1:0] ALU2_delayed_extend = ALU2_packet[extend_imm_end_bit:extend_imm_start_bit];
// break up decode package into needed signals

assign funct7        = scheduled_packet [funct7_end_bit        : funct7_start_bit] ; 
assign funct3        = scheduled_packet [funct3_end_bit        : funct3_start_bit] ;
assign PC            = scheduled_packet [inst_PC_end_bit       : inst_PC_start_bit] ;
assign extend        = scheduled_packet [extend_imm_end_bit    : extend_imm_start_bit]  ;
assign ALU_ASrc      = scheduled_packet [operand_A_sel_end_bit : operand_A_sel_start_bit] ; 
assign ALU_BSrc      = scheduled_packet [operand_B_selbit];

// Output assignment, outputs values to commit when ALU signals a valid result. 

assign branch  =  (ALU1_valid && ALU1_branch && ALU1_packet[branch_op_bit])? 1'b1 :
                  (ALU2_valid && ALU2_branch && ALU2_packet[branch_op_bit])? 1'b1 : 1'b0;
                  
assign branch_target = (ALU1_valid && ALU1_branch)? ALU1_packet[branch_target_end_bit:branch_target_start_bit] :
                       (ALU2_valid && ALU2_branch)? ALU2_packet[branch_target_end_bit:branch_target_start_bit] :
                                                                                          {ADDRESS_BITS{1'b0}} ;          

/* Only JALR Target. JAL happens in the decode unit*/
assign JALR_target = (ALU1_valid)?  ({ALU1_regRead_1 + ALU1_delayed_extend} & 32'hffff_fffe) :
                     (ALU2_valid)?  ({ALU2_regRead_1 + ALU2_delayed_extend} & 32'hffff_fffe) : 
                                                                          {DATA_WIDTH{1'b0}} ;   
                                                                                                     
assign next_PC_select =  (branch | JARL1_ins)?  ALU1_packet[next_PC_select_end_bit:next_PC_select_start_bit] :
                         (branch | JARL2_ins)?  ALU2_packet[next_PC_select_end_bit:next_PC_select_start_bit] :                                                                                                        2'b00 ;
                                                                                                       
// ALU start bit assginment
assign ALU1_data_valid = (unit == 0)? start: 1'b0;
assign ALU2_data_valid = (unit == 1)? start: 1'b0;

ALU #(DATA_WIDTH, ALU1_CYCLES, ADDRESS_BITS, NUMBER_OF_ACTIVE_INSTRUCTIONS) ALU3_Cycle (
        
        .reset(reset),
        .start(ALU1_data_valid),
        .clock(clock),
        .ALU_Control(ALU_Control), 
        .rs2_bypass(regRead_2),
        .operand_A(operand_A), .operand_B(operand_B), 
        .rd(rd),
        .instruction_ID(instruction_ID),
        .decode_packet(scheduled_packet),
        .JALR_regRead1(regRead_1),
        
        .delayed_zero(ALU1_zero), 
        .delayed_branch(ALU1_branch),
        .valid(ALU1_valid), .ready(ALU1_ready),
        .delayed_ALU_result(ALU1_result),
        .delayed_rd(ALU1_rd),
        .delayed_instruction_ID(ALU1_instruction_ID),
        .delayed_packet(ALU1_packet),
        .delayed_rs1_data_bypass(ALU1_regRead_1),
        .delayed_rs2_data_bypass(ALU1_rs2_data_bypass)
); 

ALU #(DATA_WIDTH, ALU2_CYCLES, ADDRESS_BITS, NUMBER_OF_ACTIVE_INSTRUCTIONS) ALU2_cyle (
       
        .reset(reset),
        .start(ALU2_data_valid),
        .clock(clock),
        .ALU_Control(ALU_Control),
        .rs2_bypass(regRead_2), 
        .operand_A(operand_A), .operand_B(operand_B),
        .rd(rd),
        .instruction_ID(instruction_ID),
        .decode_packet(scheduled_packet),
        .JALR_regRead1(regRead_1),
                 
        .delayed_zero(ALU2_zero),
        .delayed_branch(ALU2_branch),
        .valid(ALU2_valid), .ready(ALU2_ready),
        .delayed_ALU_result(ALU2_result),
        .delayed_rd(ALU2_rd),
        .delayed_instruction_ID(ALU2_instruction_ID),
        .delayed_packet(ALU2_packet), 
        .delayed_rs1_data_bypass(ALU2_regRead_1),
        .delayed_rs2_data_bypass(ALU2_rs2_data_bypass)
); 

always@(posedge clock) begin
    if(reset) begin
        old_JALR_target <= 32'h00000000;
        old_stall       <= 1'b0;
    end else begin
        old_JALR_target <= JALR_target;
    end
end

reg [31: 0] cycles; 
always @ (posedge clock) begin 
    cycles <= reset? 0 : cycles + 1; 
    //if (report & ((cycles >=  PRINT_CYCLES_MIN) & (cycles < PRINT_CYCLES_MAX +1)))begin
    if (report)begin
        $display ("------ Core %d Execute Unit - Current Cycle %d ------", CORE, cycles); 
        $display ("| ALU_Operat  [%b]", ALU_Operation);
        $display ("| funct7      [%b]", funct7); 
        $display ("| funct3      [%b]", funct3);
        $display ("| ALU_Control [%b]", ALU_Control);
        $display ("| operand_A   [%h]", operand_A); 
        $display ("| operand_B   [%h]", operand_B);
       // $display ("| Zero        [%b]", zero);
        $display ("| Branch      [%b]", branch);
        //$display ("| ALU_result  [%h]", ALU_result);
        $display ("| JALR_taget  [%h]", JALR_target);
        $display ("----------------------------------------------------------------------");
    end
end

endmodule
