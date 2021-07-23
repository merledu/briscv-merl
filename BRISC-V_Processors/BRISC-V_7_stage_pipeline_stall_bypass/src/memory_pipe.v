/** @module : memory_pipe_unit
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


module memory_pipe_unit #(
  parameter DATA_WIDTH   = 32,
  parameter ADDRESS_BITS = 20
) (
  input clock,
  input reset,

  input [DATA_WIDTH-1:0] ALU_result_memory1,
  input [DATA_WIDTH-1:0] load_data_memory2,
  input opwrite_memory1,
  input opSel_memory1,
  input [4:0] opReg_memory1,
  input [1:0] next_PC_select_memory1,
  input [DATA_WIDTH-1:0] instruction_memory1,

  output reg [DATA_WIDTH-1:0] ALU_result_writeback,
  output reg [DATA_WIDTH-1:0] load_data_writeback,
  output reg opwrite_writeback,
  output reg opSel_writeback,
  output reg [4:0] opReg_writeback,
  output reg [1:0] next_PC_select_writeback,
  output reg [DATA_WIDTH-1:0] instruction_writeback,

  output [DATA_WIDTH-1:0] bypass_data_memory2,
  output reg [1:0] next_PC_select_memory2,
  output reg opwrite_memory2,
  output reg [4:0] opReg_memory2
);

localparam NOP = 32'h00000013;

reg opSel_memory2;
reg [DATA_WIDTH-1:0] ALU_result_memory2;
reg [DATA_WIDTH-1:0] instruction_memory2;

assign bypass_data_memory2 = opSel_memory2 ? load_data_memory2 : ALU_result_memory2;

always @(posedge clock) begin
  if(reset) begin
    ALU_result_memory2       <= {DATA_WIDTH{1'b0}};
    opwrite_memory2          <= 1'b0;
    opSel_memory2            <= 1'b0;
    opReg_memory2            <= 5'b0;
    next_PC_select_memory2   <= 2'b00;
    instruction_memory2      <= NOP;

    ALU_result_writeback     <= {DATA_WIDTH{1'b0}};
    load_data_writeback      <= {DATA_WIDTH{1'b0}};
    opwrite_writeback        <= 1'b0;
    opSel_writeback          <= 1'b0;
    opReg_writeback          <= 5'b0;
    next_PC_select_writeback <= 2'b00;
    instruction_writeback    <= NOP;
  end else begin
    ALU_result_memory2       <= ALU_result_memory1;
    opwrite_memory2          <= opwrite_memory1;
    opSel_memory2            <= opSel_memory1;
    opReg_memory2            <= opReg_memory1;
    next_PC_select_memory2   <= next_PC_select_memory1;
    instruction_memory2      <= instruction_memory1;

    ALU_result_writeback     <= ALU_result_memory2;
    load_data_writeback      <= load_data_memory2;
    opwrite_writeback        <= opwrite_memory2;
    opSel_writeback          <= opSel_memory2;
    opReg_writeback          <= opReg_memory2;
    next_PC_select_writeback <= next_PC_select_memory2;
    instruction_writeback    <= instruction_memory2;
 end
end

endmodule
