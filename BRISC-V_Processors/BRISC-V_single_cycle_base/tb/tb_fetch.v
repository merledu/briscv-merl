
/** @module : tb_fetch_unit
 *  @author : Adaptive & Secure Computing Systems (ASCS) Laboratory
 *  Copyright (c) 2018 BRISC-V (ASCS/ECE/BU)
 */

module tb_fetch_unit (); 

reg clk, reset, start; 
reg [1:0] PC_select;

reg [7:0] program_address;
reg [7:0] JAL_target;
reg [7:0] JALR_target;
reg branch; 
reg [7:0] branch_target;
reg report;

wire [31:0]   instruction;
wire [7:0]    inst_PC;  
wire valid; 
wire ready; 

//module fetch_unit #(parameter CORE = 0, DATA_WIDTH = 32, INDEX_BITS = 6, 
//                     OFFSET_BITS = 3, ADDRESS_BITS = 20)
                     
fetch_unit #(0, 32, 4, 3, 8) IF (
        clk, reset, start,
        
        PC_select,
        program_address, 
        JAL_target,
        JALR_target,
        branch,
        branch_target, 
        
        instruction, 
        inst_PC,
        valid,
        ready,
        report
); 

// Clock generator
always #1 clk = ~clk;

initial begin
  $dumpfile ("fetch_unit.vcd");
  $dumpvars();
  clk   = 0;
  reset = 1;
  start = 1;
  
  program_address = 0; 
  JAL_target      = 0; 
  JALR_target     = 0; 
  branch          = 0; 
  branch_target   = 2; 
  PC_select       = 0; 
  report          = 1; 
  
  #8  reset = 0; 
  #10 start = 0;
  $display (" --- Start --- ");
  repeat (1) @ (posedge clk);
  
  PC_select<= 1;
  repeat (1) @ (posedge clk);
  
  PC_select<= 2;
  repeat (1) @ (posedge clk);
  
  PC_select<= 3;
  repeat (1) @ (posedge clk);
  
  PC_select<= 4;
  repeat (1) @ (posedge clk);
  
  PC_select<= 5;
  repeat (1) @ (posedge clk);
  
  PC_select<= 1;
  repeat (1) @ (posedge clk);
  end

endmodule
