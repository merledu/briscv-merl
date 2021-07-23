/*  @author : Adaptive & Secure Computing Systems (ASCS) Laboratory

 *  Copyright (c) 2018 BRISC-V (ASCS/ECE/BU)
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 z
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 *
 *
 */

/*********************************************************************************
*                              stallControl.v                                    *
*********************************************************************************/


module stall_and_bypass_control_unit (
  input clock,
  input [4:0] rs1,
  input [4:0] rs2,
  input regwrite_execute,
  input regwrite_memory1,
  input regwrite_memory2,
  input regwrite_writeback,
  input [4:0] rd_execute,
  input [4:0] rd_memory1,
  input [4:0] rd_memory2,
  input [4:0] rd_writeback,
  input [6:0] opcode_execute,
  input [6:0] opcode_memory1,

  output [2:0] rs1_data_bypass,
  output [2:0] rs2_data_bypass,
  output stall
);


wire rs1_stall_detected;
wire rs2_stall_detected;
wire stall_detected;

wire rs1_hazard_execute;
wire rs1_hazard_memory1;
wire rs1_hazard_memory2;
wire rs1_hazard_writeback;
wire rs1_load_hazard_execute;
wire rs1_load_hazard_memory1;
wire rs1_load_hazard;

wire rs2_hazard_execute;
wire rs2_hazard_memory1;
wire rs2_hazard_memory2;
wire rs2_hazard_writeback;
wire rs2_load_hazard_execute;
wire rs2_load_hazard_memory1;
wire rs2_load_hazard;

wire load_opcode_in_execute;
wire load_opcode_in_memory1;

localparam [6:0] LOAD = 7'b0000011;

// Detect hazards between decode and other stages
assign load_opcode_in_execute = opcode_execute == LOAD;
assign load_opcode_in_memory1 = opcode_memory1 == LOAD;

assign rs1_hazard_execute     = (rs1 == rd_execute   ) &  regwrite_execute  ;
assign rs1_hazard_memory1     = (rs1 == rd_memory1   ) &  regwrite_memory1  ;
assign rs1_hazard_memory2     = (rs1 == rd_memory2   ) &  regwrite_memory2  ;
assign rs1_hazard_writeback   = (rs1 == rd_writeback ) &  regwrite_writeback;

assign rs2_hazard_execute     = (rs2 == rd_execute   ) &  regwrite_execute  ;
assign rs2_hazard_memory1     = (rs2 == rd_memory1   ) &  regwrite_memory1  ;
assign rs2_hazard_memory2     = (rs2 == rd_memory2   ) &  regwrite_memory2  ;
assign rs2_hazard_writeback   = (rs2 == rd_writeback ) &  regwrite_writeback;

// TODO: Add read enable to detect true reads. Not every instruction reads
// both registers.
assign rs1_load_hazard_execute = rs1_hazard_execute & load_opcode_in_execute;
assign rs1_load_hazard_memory1 = rs1_hazard_memory1 & load_opcode_in_memory1;
assign rs1_load_hazard         = rs1_load_hazard_execute | rs1_load_hazard_memory1 ;
assign rs1_stall_detected      = rs1_load_hazard & (rs1 != 5'd0);

assign rs2_load_hazard_execute = rs2_hazard_execute & load_opcode_in_execute;
assign rs2_load_hazard_memory1 = rs2_hazard_memory1 & load_opcode_in_memory1;
assign rs2_load_hazard         = rs2_load_hazard_execute | rs2_load_hazard_memory1 ;
assign rs2_stall_detected      = rs2_load_hazard & (rs2 != 5'd0);

//stall on a loadword and rd overlap
assign stall_detected = rs1_stall_detected | rs2_stall_detected;

// The "Bonus" stall cycle has been removed.
assign stall = stall_detected;

//data bypassing to decode rs mux
assign rs1_data_bypass = (rs1_hazard_execute   & !stall) ? 3'b001 :
                         (rs1_hazard_memory1   & !stall) ? 3'b010 :
                         (rs1_hazard_memory2   & !stall) ? 3'b011 :
                         (rs1_hazard_writeback & !stall) ? 3'b100 :
                         3'b000;

assign rs2_data_bypass = (rs2_hazard_execute   & !stall) ? 3'b001 :
                         (rs2_hazard_memory1   & !stall) ? 3'b010 :
                         (rs2_hazard_memory2   & !stall) ? 3'b011 :
                         (rs2_hazard_writeback & !stall) ? 3'b100 :
                         3'b000;

endmodule
