/** @module : i_memory_interface
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

module test_wrapper #(
    parameter CORE = 0,
    parameter DATA_WIDTH = 32,
    parameter INDEX_BITS = 6,
    parameter OFFSET_BITS = 3,
    parameter ADDRESS_BITS = 11,
    parameter PROGRAM = "../software/applications/binaries/<your_program>"
) (

    input clock,
    input reset,

    input read,
    input write,
    input [ADDRESS_BITS-1:0] read_address,
    input [ADDRESS_BITS-1:0] write_address,
    input [DATA_WIDTH-1:0] in_data,

    output reg [DATA_WIDTH-1:0] out_data


);

reg read_reg;
reg write_reg;
reg [ADDRESS_BITS-1:0] read_address_reg;
reg [ADDRESS_BITS-1:0] write_address_reg;
reg [DATA_WIDTH-1:0] in_data_reg;

BRAM #(
//BRAM_ADDRESS_STALL #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDRESS_BITS),
    .INIT_FILE(PROGRAM)
) RAM (
        .clock(clock),
        .readEnable(read_reg),
        .readAddress(read_address_reg),
        .readData(out_data_wire),

        .writeEnable(write_reg),
        .writeAddress(write_address_reg),
        .writeData(in_data_reg)
);


always@(posedge clock) begin
  read_reg <= read;
  write_reg <= write;
  read_address_reg <= read_address;
  out_data <= out_data_wire;
  write_reg <= write;
  write_address_reg <= write_address;
  in_data_reg <= in_data;
end

endmodule

