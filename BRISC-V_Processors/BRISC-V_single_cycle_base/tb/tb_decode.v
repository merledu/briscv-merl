/** @module : tb_decode_unit
 *  @author : Adaptive & Secure Computing Systems (ASCS) Laboratory
 *  Copyright (c) 2018 BRISC-V (ASCS/ECE/BU)
 */

module tb_decode_unit (); 

reg clk, reset;  

reg  [31:0] PC;
reg  [31:0] instruction; 
reg  [1:0] extend_sel; 
reg  write;
reg  [4:0]  write_reg;
reg  [31:0] write_data;
reg  report; 

wire [31:0]  rs1_data; 
wire [31:0]  rs2_data;
wire [4:0]   rd;  
wire [31:0] branch_target; 
wire [31:0] JAL_target;

wire [6:0]  opcode;
wire [6:0]  funct7; 
wire [2:0]  funct3;
wire [31:0] extend_imm;

decode_unit #(0, 32) decode (
      clk, reset, 
      PC, instruction, 
      extend_sel,
      write, write_reg, write_data, 
      
      opcode, funct3, funct7,
      rs1_data, rs2_data, rd, 
      extend_imm, 
      branch_target, 
      JAL_target, 
      report
); 

// Clock generator
always #1 clk = ~clk;

initial begin
  $dumpfile ("decode.vcd");
  $dumpvars();
  clk   = 0;
  reset = 1;
  PC            = 0; 
  instruction   = 0; 
  extend_sel    = 0; 
  write         = 0; 
  write_data    = 0; 
  write_reg     = 0;
  report        = 1; 
  
  #10 reset = 0; 
  $display (" --- Start --- ");
  repeat (1) @ (posedge clk);
  
  PC            <= 4; 
  instruction   <= 32'hfe010113; 
  write         <= 0; 
  write_data    <= 0; 
  write_reg     <= 0;
  repeat (1) @ (posedge clk);
  
  PC            <= 8; 
  instruction   <= 32'h00112e23; 
  write         <= 0; 
  write_data    <= 0; 
  write_reg     <= 0;
  repeat (1) @ (posedge clk);
  
  PC            <= 32'h0C; 
  instruction   <= 32'h00812c23; 
  write         <= 0; 
  write_data    <= 0; 
  write_reg     <= 0;
  repeat (1) @ (posedge clk);
  
  PC            <= 32'h10; 
  instruction   <= 32'h02010413; 
  write         <= 0; 
  write_data    <= 0; 
  write_reg     <= 0;
  repeat (1) @ (posedge clk);
  
  PC            <= 32'h14; 
  instruction   <= 32'h00400793; 
  write         <= 0; 
  write_data    <= 0; 
  write_reg     <= 0;
  repeat (1) @ (posedge clk);
  
  PC            <= 32'h18; 
  instruction   <= 32'hfef42623; 
  write         <= 0; 
  write_data    <= 0; 
  write_reg     <= 0;
  repeat (1) @ (posedge clk);
  end

endmodule
