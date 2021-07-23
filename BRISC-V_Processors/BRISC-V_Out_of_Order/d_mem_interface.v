/** @module : d_memory_interface
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

module d_mem_interface #(
    parameter CORE = 0,
    parameter DATA_WIDTH = 32,
    parameter INDEX_BITS = 6,
    parameter OFFSET_BITS = 3,
    parameter ADDRESS_BITS = 20
) (
    input clock,
    input reset,
    input stall,
    input read,
    input write,
    input [ADDRESS_BITS-1:0] address,
    input [DATA_WIDTH-1:0] in_data,


    output [ADDRESS_BITS-1:0] out_addr,
    output [DATA_WIDTH-1:0] out_data,
    output valid,
    output ready,
    input  report
);



wire [DATA_WIDTH-1:0] bsram_out_data;
wire bsram_select;

// bug present here. register the valid signal like instruction memory
assign out_data =  read ? bsram_out_data : {DATA_WIDTH{1'b0}};
assign out_addr = read ? address : 1'b0;
assign valid    = (read | write)? 1'b1 : 1'b0;
assign ready    = (read | write)? 1'b0 : 1'b1; // Just for testing now

BSRAM #(
    .CORE(CORE),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDRESS_BITS)
) RAM (
    .clock(clock),
    .reset(reset),
    .readEnable(read),
    .readAddress(address),
    .readData(bsram_out_data),

    .writeEnable(write),
    .writeAddress(address),
    .writeData(in_data),

    .report(1'b0)
);


reg [31: 0] cycles;
always @ (posedge clock) begin
    cycles <= reset? 0 : cycles + 1;
    if (report)begin
        $display ("------ Core %d Memory Interface - Current Cycle %d --", CORE, cycles);

        $display ("| Address     [%h]", address);
        $display ("| Read        [%b]", read);
        $display ("| Write       [%b]", write);
        $display ("| Out Data    [%h]", out_data);
        $display ("| In Data     [%h]", in_data);
        $display ("| Ready       [%b]", ready);
        $display ("| Valid       [%b]", valid);
        $display ("----------------------------------------------------------------------");
    end
end

endmodule

