/** @module : execute_pipe_unit
 *  @author : Adaptive & Secure Computing Systems (ASCS) Laboratory

 *  Copyright (c) 2018 BRISC-V (ASCS/ECE/BU)
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.

 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 */
//////////////////////////////////////////////////////////////////////////////////


module execute_pipe_unit #(parameter  DATA_WIDTH = 32,
                             ADDRESS_BITS = 20)(

    input clock, reset, stall,
    input [DATA_WIDTH-1:0]   ALU_result_execute,
    input [DATA_WIDTH-1:0]   store_data_execute,
    input [4:0] rd_execute,
    input [1:0] next_PC_select_execute,
    input memRead_execute,
    input memWrite_execute,
    input regWrite_execute,
    input [DATA_WIDTH-1:0] instruction_execute,

    output [DATA_WIDTH-1:0]   ALU_result_memory,
    output [DATA_WIDTH-1:0]   store_data_memory,
    output [4:0] rd_memory,
    output [1:0] next_PC_select_memory,
    output memRead_memory,
    output memWrite_memory,
    output regWrite_memory,
    output [DATA_WIDTH-1:0] instruction_memory
);

localparam NOP = 32'h00000013;

reg  [DATA_WIDTH-1:0]   ALU_result_execute_to_memory;
reg  [DATA_WIDTH-1:0]   store_data_execute_to_memory;
reg  [4:0] rd_execute_to_memory;
reg  memRead_execute_to_memory;
reg  memWrite_execute_to_memory;
reg  [1:0] next_PC_select_execute_to_memory;
reg  regWrite_execute_to_memory;
reg  [DATA_WIDTH-1:0] instruction_execute_to_memory;

assign ALU_result_memory      = ALU_result_execute_to_memory;
assign store_data_memory      = store_data_execute_to_memory;
assign rd_memory              = rd_execute_to_memory;
assign memRead_memory         = memRead_execute_to_memory;
assign memWrite_memory        = memWrite_execute_to_memory;
assign next_PC_select_memory  = next_PC_select_execute_to_memory;
assign regWrite_memory        = regWrite_execute_to_memory;
assign instruction_memory     = instruction_execute_to_memory;

always @(posedge clock) begin
   if(reset) begin
      ALU_result_execute_to_memory      <= {DATA_WIDTH{1'b0}};
      store_data_execute_to_memory      <= {DATA_WIDTH{1'b0}};
      rd_execute_to_memory              <= 5'b0;
      memRead_execute_to_memory         <= 1'b1;
      memWrite_execute_to_memory        <= 1'b0;
      next_PC_select_execute_to_memory  <= 2'b0;
      regWrite_execute_to_memory        <= 1'b0;
      instruction_execute_to_memory     <= NOP;
   end
   else if(stall) begin
      // flush all but PC_select
      ALU_result_execute_to_memory      <= ALU_result_execute;
      store_data_execute_to_memory      <= store_data_execute;
      rd_execute_to_memory              <= rd_execute;
      memRead_execute_to_memory         <= memRead_execute;
      memWrite_execute_to_memory        <= memWrite_execute;
      next_PC_select_execute_to_memory  <= next_PC_select_execute_to_memory; // hold during stall
      regWrite_execute_to_memory        <= regWrite_execute;
      instruction_execute_to_memory     <= instruction_execute;
   end
   else begin
      ALU_result_execute_to_memory      <= ALU_result_execute;
      store_data_execute_to_memory      <= store_data_execute;
      rd_execute_to_memory              <= rd_execute;
      memRead_execute_to_memory         <= memRead_execute;
      memWrite_execute_to_memory        <= memWrite_execute;
      next_PC_select_execute_to_memory  <= next_PC_select_execute;
      regWrite_execute_to_memory        <= regWrite_execute;
      instruction_execute_to_memory     <= instruction_execute;
   end
end
endmodule
