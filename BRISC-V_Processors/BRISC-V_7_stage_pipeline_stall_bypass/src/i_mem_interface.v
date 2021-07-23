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

module i_mem_interface #(
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

  output valid,
  output ready,
  output [ADDRESS_BITS-1:0] out_addr,
  output [DATA_WIDTH-1:0] out_data,

  input  report

);

reg [ADDRESS_BITS-1:0] read_address_reg;

BSRAM #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDR_WIDTH(ADDRESS_BITS),
  .INIT_FILE(PROGRAM)
) RAM (
  .clock(clock),
  // Read
  .readEnable(1'b1), // Read signal checked at addr reg
  .readAddress(read_address_reg),
  .readData(out_data),
  // Write
  .writeEnable(write),
  .writeAddress(write_address),
  .writeData(in_data),

  .report(report)
);

assign out_addr = read_address_reg;

// TODO: Remove write condition from valid/ready signals
assign valid =  (read | write);
assign ready = !(read | write); // Just for testing now

// This logic stalls read address when readEnable is low. This is opposed to
// the old version which did not stall read address and set readData to 0.
// Stalling read address (and therefore readData) allows the pipeline to
// stall the whole BRAM memory stage.
always@(posedge clock) begin
  if(reset) begin
    read_address_reg <= {ADDRESS_BITS{1'b0}};
  end else begin
    read_address_reg <= read ? read_address : read_address_reg;
  end
end

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  if (report)begin
    $display ("------ Core %d Memory Interface - Current Cycle %d --", CORE, cycles);
    $display ("| Rd Address  [%h]", read_address);
    $display ("| Wr Address  [%h]", write_address);
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

