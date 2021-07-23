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


module memory_pipe_unit #(parameter  DATA_WIDTH = 32,
                          ADDRESS_BITS = 20)(

    input clock,reset,
    input [DATA_WIDTH-1:0] ALU_result_memory,
    input [DATA_WIDTH-1:0] load_data_memory,
    input opwrite_memory,
    input opsel_memory,
    input [4:0] opReg_memory,
    input [DATA_WIDTH-1:0] instruction_memory,

    output [DATA_WIDTH-1:0] ALU_result_writeback,
    output [DATA_WIDTH-1:0] load_data_writeback,
    output opwrite_writeback,
    output opsel_writeback,
    output [4:0] opReg_writeback,
    output [DATA_WIDTH-1:0] instruction_writeback
    );

localparam NOP = 32'h00000013;

reg    [DATA_WIDTH-1:0] ALU_result_memory_to_writeback;
reg    [DATA_WIDTH-1:0] load_data_memory_to_writeback;
reg    opwrite_memory_to_writeback;
reg    opsel_memory_to_writeback;
reg    [4:0] opReg_memory_to_writeback;
reg    [DATA_WIDTH-1:0] instruction_memory_to_writeback;

assign ALU_result_writeback = ALU_result_memory_to_writeback;
assign load_data_writeback  = load_data_memory_to_writeback;
assign opwrite_writeback    = opwrite_memory_to_writeback;
assign opsel_writeback      = opsel_memory_to_writeback;
assign opReg_writeback      = opReg_memory_to_writeback;
assign instruction_writeback= instruction_memory_to_writeback;

always @(posedge clock) begin
    if(reset) begin
        ALU_result_memory_to_writeback  <= {DATA_WIDTH{1'b0}};
        load_data_memory_to_writeback   <= {DATA_WIDTH{1'b0}};
        opwrite_memory_to_writeback     <= 1'b0;
        opsel_memory_to_writeback       <= 1'b0;
        opReg_memory_to_writeback       <= 5'b0;
        instruction_memory_to_writeback <= NOP;
    end
    else begin
        ALU_result_memory_to_writeback  <= ALU_result_memory;
        load_data_memory_to_writeback   <= load_data_memory;
        opwrite_memory_to_writeback     <= opwrite_memory;
        opsel_memory_to_writeback       <= opsel_memory;
        opReg_memory_to_writeback       <= opReg_memory;
        instruction_memory_to_writeback <= instruction_memory;
   end
end
endmodule
