/** @module : tb_control_unit
 *  @author : Adaptive & Secure Computing Systems (ASCS) Laboratory
 *  Copyright (c) 2018 BRISC-V (ASCS/ECE/BU)
 */

module tb_control_unit (); 

reg clk, reset; 
reg report;

reg [6:0] opcode;
    
wire branch_op;
wire memRead; 
wire memtoReg; 
wire [2:0] ALUOp; 
wire memWrite;
wire [1:0] next_PC_sel;
wire [1:0] operand_A_sel; 
wire operand_B_sel; 
wire [1:0] extend_sel; 
wire regWrite;

control_unit #(0) CU (
    clk, reset, 
        
    opcode,
    branch_op, memRead, 
    memtoReg, ALUOp, 
    next_PC_sel, 
    operand_A_sel, operand_B_sel,
    extend_sel,
    memWrite, regWrite, 
    report
); 


// Clock generator
always #1 clk = ~clk;

initial begin
  $dumpfile ("control_unit.vcd");
  $dumpvars();
  clk     = 0;
  reset   = 1;
  opcode  = 0;  
  report  = 1; 
  
  #10 reset = 0; 
  $display (" --- Start --- ");
  repeat (1) @ (posedge clk);
  
  opcode <= 7'b0110011;
  repeat (1) @ (posedge clk);
  
  opcode <= 7'b1100011;
  repeat (1) @ (posedge clk);
  
  opcode <= 7'b0000011;
  repeat (1) @ (posedge clk);
  
  opcode <= 7'b0100011;
  repeat (1) @ (posedge clk);
  
  opcode <= 7'b1101111;
  repeat (1) @ (posedge clk);
  
  opcode <= 7'b011011;
  repeat (1) @ (posedge clk);
  end
                    
endmodule
