
/** @module : tb_writeback_unit
 *  @author : Adaptive & Secure Computing Systems (ASCS) Laboratory
 *  Copyright (c) 2018 BRISC-V (ASCS/ECE/BU)
 */


module tb_writeback_unit (); 

reg clk, reset;  
reg  opWrite; 
reg  opSel; 
reg  [4:0]  opReg;
reg  [31:0] ALU_Result;
reg  [31:0] memory_data; 

wire  write;
wire  [4:0]  write_reg;
wire  [31:0] write_data;

reg  report; 

writeback_unit #(0, 32) WB (
      clk, reset, 
      opWrite,
      opSel, 
      opReg, 
      ALU_Result, 
      memory_data, 
      write, write_reg, write_data, 
      report
);

// Clock generator
always #1 clk = ~clk;

initial begin
  $dumpfile ("writeback.vcd");
  $dumpvars();
  clk   = 0;
  reset = 1;
  opWrite       = 0; 
  opSel         = 0; 
  opReg         = 0; 
  ALU_Result    = 0; 
  memory_data   = 0; 
  report        = 1; 
  
  #10 reset = 0; 
  $display (" --- Start --- ");
  repeat (1) @ (posedge clk);
  
  opWrite       = 1; 
  opSel         = 0; 
  opReg         = 3; 
  ALU_Result    = 5; 
  memory_data   = 9; 
  repeat (1) @ (posedge clk);
  
  opWrite       = 0; 
  opSel         = 1; 
  opReg         = 0; 
  ALU_Result    = 4; 
  memory_data   = 8;
  repeat (1) @ (posedge clk);
  
  end

endmodule
