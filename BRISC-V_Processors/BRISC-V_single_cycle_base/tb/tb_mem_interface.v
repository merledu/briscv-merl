/** @module : tb_mem_interface
 *  @author : Adaptive & Secure Computing Systems (ASCS) Laboratory
 *  Copyright (c) 2018 BRISC-V (ASCS/ECE/BU)
 */

module tb_mem_interface (); 

reg clk, reset; 
reg read, write;
reg [7:0] address;
reg [31:0]in_data;
wire valid, ready;
wire[7:0] out_addr;
wire[31:0]out_data;
reg report; 

//mem_interface #(parameter CORE = 0, DATA_WIDTH = 32, INDEX_BITS = 6, 
//                OFFSET_BITS = 3, ADDRESS_BITS = 20)
mem_interface #(0, 32, 4, 3, 8)U (
                     clk, reset,  
                     read, write, address, in_data, 
                     out_addr, out_data, valid, ready,
                     report
);     

// Clock generator
always #1 clk = ~clk;

initial begin
  $dumpfile ("mem_interface.vcd");
  $dumpvars();
  clk   = 0;
  reset = 1;
  read  = 0; 
  write = 0; 
  address = 0;
  report  = 1;   
  
  #10 reset = 0; 
  $display (" --- Start --- ");
  repeat (1) @ (posedge clk);
  
  address    <= 0; 
  in_data    <= 32'h0000_0000_0000_0002; 
  write      <= 1'b1;
  repeat (1) @ (posedge clk);
  
  address    <= 2; 
  in_data    <= 32'h0000_0000_0000_0008; 
  write      <= 1'b1;
  repeat (1) @ (posedge clk);
  
  address    <= 4; 
  in_data    <= 32'h0000_0000_0000_0002; 
  write      <= 1'b1;
  repeat (1) @ (posedge clk);
  
  address    <= 6; 
  in_data    <= 32'h0000_0000_0000_0008; 
  write      <= 1'b1;
  repeat (1) @ (posedge clk);
  
  write      <= 1'b0;
  repeat (1) @ (posedge clk);
  
  address    <= 0; 
  read       <= 1'b1;
  repeat (1) @ (posedge clk);
  
  address    <= 4; 
  read       <= 1'b1;
  repeat (1) @ (posedge clk);
  
  address    <= 8; 
  read       <= 1'b1;
  repeat (1) @ (posedge clk);
  
  address    <= 2; 
  read       <= 1'b1;
  repeat (1) @ (posedge clk);
  end
  
endmodule

