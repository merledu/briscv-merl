/** @module : ALU
 *  @author : Adaptive & Secure Computing Systems (ASCS) Laboratory
 *  Copyright (c) 2018 BRISC-V (ASCS/ECE/BU)
 */
 
module tb_ALU (); 
 
reg    clock; 
reg [5:0]   ALU_Control; 
reg [31:0]  operand_A ;
reg [31:0]  operand_B ;
wire zero, branch; 
wire [31:0] ALU_result;

 
ALU DUT (
        .ALU_Control(ALU_Control), 
        .operand_A(operand_A), .operand_B(operand_B), 
        .ALU_result(ALU_result), .zero(zero), .branch(branch)
); 

// Clock generator
always #1 clock = ~clock;

initial begin
  clock = 0;
  $display (" --- Start --- ");
  repeat (1) @ (posedge clock);
  
  operand_A   <= 32'h0000_0000_0000_0002;
  operand_B   <= 32'h0000_0000_0000_0004;
  ALU_Control <= 6'b001_000;  
  repeat (1) @ (posedge clock);
  
  operand_A   <= 32'h0000_0000_0000_0002;
  operand_B   <= 32'h0000_0000_0000_0004;
  ALU_Control <= 6'b000_110;  
  repeat (1) @ (posedge clock);
  
  operand_A   <= 32'h0000_0000_0000_000A;
  operand_B   <= 32'h0000_0000_0000_0004;
  ALU_Control <= 6'b001_101;  
  repeat (1) @ (posedge clock);
  
  operand_A   <= 32'h0000_0000_0000_0002;
  operand_B   <= 32'h0000_0000_0000_0004;
  ALU_Control <= 6'b000_010;  
  repeat (1) @ (posedge clock);
  
  operand_A   <= 32'h0000_0000_0000_0002;
  operand_B   <= 32'h0000_0000_0000_0004;
  ALU_Control <= 6'b010_111;  
  repeat (1) @ (posedge clock);
end
  
always @ (posedge clock) begin 
        $display ("ALU_Control [%b], operand_A [%d] operand_B [%d]", ALU_Control, operand_A, operand_B); 
        $display ("ALU_result [%d] zero  [%b] branch  [%b]",ALU_result,zero, branch); 
end
     
endmodule
