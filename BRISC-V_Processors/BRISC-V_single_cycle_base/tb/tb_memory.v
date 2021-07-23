
/** @module : tb_memory_unit
 *  @author : Adaptive & Secure Computing Systems (ASCS) Laboratory
 *  Copyright (c) 2018 BRISC-V (ASCS/ECE/BU)
 */


module tb_memory_unit (); 

reg clk, reset; 

reg load, store; 
reg [7:0] address;
reg [31:0]store_data;
reg report;

wire [31:0]   load_data;
wire [7:0]    data_addr;  
wire valid; 
wire ready; 

//module memory_unit #(parameter CORE = 0, DATA_WIDTH = 32, INDEX_BITS = 6, 
//                     OFFSET_BITS = 3, ADDRESS_BITS = 20)
                     
memory_unit #(0, 32, 4, 3, 8) DM (
        clk, reset, 
        load, store,
        address, 
        store_data,
        data_addr, 
        load_data,
        valid,
        ready,
        report
); 


// Clock generator
always #1 clk = ~clk;

initial begin
  $dumpfile ("memory_unit.vcd");
  $dumpvars();
  clk   = 0;
  reset = 1;
  load  = 0; 
  store = 0; 
  address     = 0; 
  store_data  = 0; 
  report      = 1; 
  
  #10 reset = 0; 
  $display (" --- Start --- ");
  repeat (1) @ (posedge clk);
  
  load  = 0; 
  store = 1; 
  address     = 4; 
  store_data  = 9; 
  repeat (1) @ (posedge clk);
  
  load  = 0; 
  store = 1; 
  address     = 8; 
  store_data  = 5;
  repeat (1) @ (posedge clk);
  
  load  = 1; 
  store = 0; 
  address     = 8; 
  store_data  = 0;
  repeat (1) @ (posedge clk);
  
  load  = 1; 
  store = 1; 
  address     = 12; 
  store_data  = 9;
  repeat (1) @ (posedge clk);
  
  load  = 1; 
  store = 0; 
  address     = 4; 
  store_data  = 0;
  repeat (1) @ (posedge clk);
 
  end

endmodule
