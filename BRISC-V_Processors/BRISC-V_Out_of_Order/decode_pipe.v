/** @module : decode_pipe_unit
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

module decode_pipe_unit #(parameter  DATA_WIDTH = 32,
                            ADDRESS_BITS = 20)(
    input clock, reset, 
    input valid_decode,
    input [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] packet_decode,
    input [DATA_WIDTH-1:0] instruction_decode,
    input [1:0] next_PC_select_decode, // JAL/JALR/Brnch bits handled in decode. 
    input [ADDRESS_BITS-1:0] JAL_target_decode,
    input [1:0] next_PC_select_writeback,

    output valid_execute,
    output [1:0] next_PC_select_packet, 
    output [1:0] next_PC_select_fetch,
    output [ADDRESS_BITS-1:0] JAL_target_execute,
    output [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] packet_queue,
    output [DATA_WIDTH-1:0] instruction_execute
);

localparam NOP = 32'h00000013;

reg [(DATA_WIDTH + (ADDRESS_BITS*3) + 38) -1: 0] packet_decode_to_queue;
reg [ADDRESS_BITS-1:0] JAL_target_decode_to_execute;
reg [DATA_WIDTH-1:0] instruction_decode_to_execute;
reg [1:0] next_PC_select_decode_to_execute;
reg valid_decode_to_execute;

assign  instruction_execute    = instruction_decode_to_execute;
assign  packet_queue           = packet_decode_to_queue;
assign  valid_execute          = valid_decode_to_execute;
assign  next_PC_select_packet  = next_PC_select_decode_to_execute;
assign  JAL_target_execute     = JAL_target_decode_to_execute;

assign  next_PC_select_fetch   = (next_PC_select_decode_to_execute == 2'b10)?   next_PC_select_decode_to_execute : // JAL
                                 (next_PC_select_writeback == 2'b01 )?          next_PC_select_writeback : // branch    
                                 (next_PC_select_writeback == 2'b11 )?          next_PC_select_writeback : //JALR
                                                                                                    2'b0 ;   

always @(posedge clock) begin
    if(reset) begin
        instruction_decode_to_execute     <= NOP;
        valid_decode_to_execute           <= 1'b0;
        JAL_target_decode_to_execute      <= {ADDRESS_BITS{1'b0}};
        next_PC_select_decode_to_execute  <= 2'b0;
        packet_decode_to_queue            <= 130'b0;
    end
    else begin
        valid_decode_to_execute           <= valid_decode;
        packet_decode_to_queue            <= packet_decode;
        instruction_decode_to_execute     <= instruction_decode;
        JAL_target_decode_to_execute      <= JAL_target_decode;
        next_PC_select_decode_to_execute  <= next_PC_select_decode; // PC select to fetch is split for JAL        
     end
end
endmodule





