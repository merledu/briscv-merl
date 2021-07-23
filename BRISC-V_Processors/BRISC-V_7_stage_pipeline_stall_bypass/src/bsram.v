/** @module : BSRAM
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

//Same cycle read memory access

 (* ram_style = "block" *)
module BSRAM #(
  parameter CORE = 0,
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 8,
  parameter INIT_FILE = "../software/applications/binaries/zeros4096.dat",   //  memory needs to be prefilled with zeros
  parameter PRINT_CYCLES_MIN = 1,
  parameter PRINT_CYCLES_MAX = 1000
) (
  input clock,
  input readEnable,
  input [ADDR_WIDTH-1:0]   readAddress,
  output [DATA_WIDTH-1:0]  readData,
  input writeEnable,
  input [ADDR_WIDTH-1:0]   writeAddress,
  input [DATA_WIDTH-1:0]   writeData,
  input report
);

localparam MEM_DEPTH = 1 << ADDR_WIDTH;

reg [DATA_WIDTH-1:0] sram [0:MEM_DEPTH-1];

assign readData = (readEnable & writeEnable & (readAddress == writeAddress))?
                  writeData : readEnable? sram[readAddress] : 0;

initial begin
    $readmemh(INIT_FILE, sram);
end

always@(posedge clock) begin : RAM_WRITE
  if(writeEnable)
    sram[writeAddress] <= writeData;
end

/*
always @ (posedge clock) begin
  //if (report & ((cycles >=  PRINT_CYCLES_MIN) & (cycles < PRINT_CYCLES_MAX +1)))begin
  if (report)begin
    $display ("------ Core %d SBRAM Unit - Current Cycle %d --------", CORE, cycles);
    $display ("| Read        [%b]", readEnable);
    $display ("| Read Address[%h]", readAddress);
    $display ("| Read Data   [%h]", readData);
    $display ("| Write       [%b]", writeEnable);
    $display ("| Write Addres[%h]", writeAddress);
    $display ("| Write Data  [%h]", writeData);
    $display ("----------------------------------------------------------------------");
  end
end
*/

endmodule

