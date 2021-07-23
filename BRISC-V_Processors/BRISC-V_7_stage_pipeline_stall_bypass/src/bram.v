/** @module : BRAM
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

(* ram_style = "block" *) // Xilinx Synthesis Attrubute
module BRAM #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 8,
  parameter INIT_FILE = "../software/applications/binaries/<your_program>"
) (
  input clock,
  // Read Signals
  input readEnable,
  input [ADDR_WIDTH-1:0] readAddress,
  output [DATA_WIDTH-1:0] readData,
  // Write Signals
  input writeEnable,
  input [ADDR_WIDTH-1:0] writeAddress,
  input [DATA_WIDTH-1:0]writeData

);

localparam MEM_DEPTH = 1 << ADDR_WIDTH;

reg [ADDR_WIDTH-1:0] readAddress_reg;
reg [DATA_WIDTH-1:0] ram [0:MEM_DEPTH-1];

// Even with assign statment, reads are still synchronous because of
// registered readAddress. Quartus still infers BRAM with this.
assign readData = (writeEnable & (readAddress == writeAddress))?
                writeData : ram[readAddress_reg];

// This logic stalls read address when readEnable is low. This is opposed to
// the old version which did not stall read address and set readData to 0.
// Stalling read address (and therefore readData) allows the pipeline to
// stall the whole BRAM memory stage.
always@(posedge clock) begin : RAM_READ
  if (readEnable) begin
    readAddress_reg <= readAddress;
  end else begin
    readAddress_reg <= readAddress_reg;
  end
end

// Write Logic
always@(posedge clock) begin : RAM_WRITE
  if(writeEnable)
    ram[writeAddress] <= writeData;
end

initial begin
  $readmemh(INIT_FILE, ram);
end

/*
always @ (posedge clock) begin
  if(readEnable | writeEnable) begin
    $display ("-------------------------------BRAM-------------------------------------------");
    $display ("Read [%b]\t\t\tWrite [%b]", readEnable, writeEnable);
    $display ("Read Address [%h] \t\t Write Address [%h]", readAddress, writeAddress);
    $display ("Read Data [%h]", readData);
    $display ("Write Data [%h]",writeData);
    $display ("-----------------------------------------------------------------------------");
    end
 end
*/
endmodule

