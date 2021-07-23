/** @module : regFile
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

// Parameterized register file
module regFile #(
  parameter REG_DATA_WIDTH = 32,
  parameter REG_SEL_BITS   = 5
) (
  input clock,
  input reset,
  input wEn,
  input [REG_DATA_WIDTH-1:0] write_data,
  input [REG_SEL_BITS-1:0] read_sel1,
  input [REG_SEL_BITS-1:0] read_sel2,
  input [REG_SEL_BITS-1:0] write_sel,
  output [REG_DATA_WIDTH-1:0] read_data1,
  output [REG_DATA_WIDTH-1:0] read_data2


);

(* ram_style = "distributed" *)
reg [REG_DATA_WIDTH-1:0] register_file[0:(1<<REG_SEL_BITS)-1];

always @(posedge clock) begin
  if(reset==1)
    register_file[0] <= 0;
  else
    if (wEn & write_sel != 0) register_file[write_sel] <= write_data;
end

//----------------------------------------------------
// Drive the outputs
//----------------------------------------------------
assign read_data1 = register_file[read_sel1];
assign read_data2 = register_file[read_sel2];

// Note: This was for debugging with signal tap. It has been kept because
// removing it hurt synthesis results in Quartus Prime Lite 17.1. Without
// these lines the zero registers are not removed by the optimizations and the
// Fmax of the design is hurt because of the larger register file.
wire [31:0] r1;
assign r1 = register_file[1];
wire [31:0] r14;
assign r14 = register_file[14];
wire [31:0] r15;
assign r15 = register_file[15];

endmodule
