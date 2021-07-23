/** @module : tb_regFile
 *  @author : Adaptive & Secure Computing Systems (ASCS) Laboratory
 *  Copyright (c) 2018 BRISC-V (ASCS/ECE/BU)
 */

module tb_regFile (); 

reg clk, reset; 
reg [4:0] read1_sel, read2_sel, write_sel; 
reg wEn; 
reg [31:0] write_data; 
wire[31:0]  read_data1, read_data2; 

//regFile #(parameter REG_DATA_WIDTH = 32, REG_SEL_BITS = 5)
regFile #(32, 5)U (
                clk, reset, read1_sel, read2_sel,
                wEn, write_sel, write_data, 
                read_data1, read_data2
);     

// Clock generator
always #1 clk = ~clk;

always @ (posedge clk) begin 
        $display ("Read1 Sel [%d], Read1 Data [%h]",read1_sel, read_data1); 
        $display ("Read2 Sel [%d], Read2 Data [%h]",read2_sel, read_data2); 
end

initial begin
  $dumpfile ("regFile.vcd");
  $dumpvars();
  clk = 0;
  reset = 1;
  wEn = 0;
  #10 reset = 0; 
  $display (" --- Start --- ");
  repeat (1) @ (posedge clk);
  
  write_data <= 32'h0000_0000_0000_0002;
  write_sel  <= 5'b00001;  
  wEn        <= 1'b1;
  repeat (1) @ (posedge clk);
  
  write_data <= 32'h0000_0000_0000_0005;
  write_sel  <= 5'b00011;  
  wEn        <= 1'b1;
  repeat (1) @ (posedge clk);
  
  write_data <= 32'h0000_0000_0000_0009;
  write_sel  <= 5'b00111;  
  wEn        <= 1'b1;
  repeat (1) @ (posedge clk);
  
  write_data <= 32'h0000_0000_0000_0007;
  write_sel  <= 5'b00000;  
  wEn        <= 1'b1;
  repeat (1) @ (posedge clk);
  
  write_data <= 32'h0000_0000_0000_000A;
  write_sel  <= 5'b00101;  
  wEn        <= 1'b1;
  read1_sel  <= 5'b00101; 
  repeat (1) @ (posedge clk);

  write_data <= 32'h0000_0000_0000_000A;
  write_sel  <= 5'b00101;  
  wEn        <= 1'b0;
  read1_sel  <= 5'b00101; 
  repeat (1) @ (posedge clk);
 
  write_data <= 32'h0000_0000_0000_000A;
  write_sel  <= 5'b00101;  
  wEn        <= 1'b0;
  read1_sel  <= 5'b00101; 
  read2_sel  <= 5'b00101; 
  repeat (1) @ (posedge clk);
 
  read1_sel  <= 5'b00111; 
  read2_sel  <= 5'b00111; 
  repeat (1) @ (posedge clk);
  
  read1_sel  <= 5'b00011; 
  read2_sel  <= 5'b00001; 
  repeat (1) @ (posedge clk);
 
  read1_sel  <= 5'b00000; 
  read2_sel  <= 5'b00001; 
  repeat (1) @ (posedge clk);          
  end
  
endmodule
