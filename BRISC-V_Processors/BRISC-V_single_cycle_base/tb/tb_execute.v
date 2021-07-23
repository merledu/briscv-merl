
/** @module : tb_execution_unit
 *  @author : Adaptive & Secure Computing Systems (ASCS) Laboratory
 *  Copyright (c) 2018 BRISC-V (ASCS/ECE/BU)
 */


module tb_execution_unit (); 

reg  clk, reset;  
reg [2:0] ALU_Operation; 
reg [6:0] funct7; 
reg [2:0] funct3;
reg [19:0]  PC;
reg [1:0] ALU_ASrc; 
reg ALU_BSrc;
reg branch_op;
reg [31:0]  regRead_1 ;
reg [31:0]  regRead_2 ; 
reg [31:0]  extend;

wire zero, branch; 
wire [31:0] ALU_result;
wire [19:0]JALR_target;

reg report; 

execution_unit #(0,32,20) execute (
	clk, reset, 
	ALU_Operation, 
	funct3, funct7,
	PC, ALU_ASrc, ALU_BSrc,
	branch_op,	
	regRead_1, regRead_2, 
	extend,
	ALU_result, zero, branch, 
	JALR_target,	
	report
);

// Clock generator
always #1 clk = ~clk;

initial begin
  $dumpfile ("execute.vcd");
  $dumpvars();
  clk   = 0;
  reset = 1;
  ALU_Operation = 0; 
  funct3        = 0; 
  funct7        = 0; 
  branch_op     = 0; 
  regRead_1     = 0; 
  regRead_2     = 0; 
  report        = 1; 
  
  #10 reset = 0; 
  $display (" --- Start --- ");
  repeat (1) @ (posedge clk);
  
  ALU_Operation <= 3'b000; 
  funct3        <= 3'b101; 
  funct7        <= 7'b0000000; 
  regRead_1     <= 5; 
  regRead_2     <= 7; 
  repeat (1) @ (posedge clk);
  
  ALU_Operation <= 3'b000; 
  funct3        <= 3'b000; 
  funct7        <= 7'b0100000; 
  regRead_1     <= 5; 
  regRead_2     <= 7; 
  repeat (1) @ (posedge clk);
  
  ALU_Operation <= 3'b001; 
  funct3        <= 3'b000; 
  funct7        <= 7'b0000000; 
  regRead_1     <= 5; 
  regRead_2     <= 7;
  repeat (1) @ (posedge clk);
  end

endmodule
