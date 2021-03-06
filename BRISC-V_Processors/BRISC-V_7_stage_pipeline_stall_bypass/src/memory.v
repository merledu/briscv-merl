/** @module : memory
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

module memory_unit #(
  parameter CORE = 0,
  parameter DATA_WIDTH = 32,
  parameter INDEX_BITS = 6,
  parameter OFFSET_BITS = 3,
  parameter ADDRESS_BITS = 20,
  parameter PRINT_CYCLES_MIN = 1,
  parameter PRINT_CYCLES_MAX = 1000
) (
  input clock,
  input reset,

  // Connections from previous (Execute) pipeline stage
  input stall,
  input load,
  input store,
  input [ADDRESS_BITS-1:0] address,
  input [DATA_WIDTH-1:0] store_data,

  // Connections to next (Writeback) pipeline stage
  output [ADDRESS_BITS-1:0] data_addr,
  output [DATA_WIDTH-1:0] load_data,
  output valid,
  output ready,


  // Data Memory Interface
  input [ADDRESS_BITS-1:0] d_mem_out_addr,
  input [DATA_WIDTH-1:0]   d_mem_out_data,
  input d_mem_valid,
  input d_mem_ready,

  output [ADDRESS_BITS-1:0] d_mem_address,
  output [DATA_WIDTH-1:0]   d_mem_in_data,
  output d_mem_read,
  output d_mem_write,

  input report
);

// Connect Pipeline Inputs/Ouputs to Data Memory Interface
assign load_data     = d_mem_out_data;
assign data_addr     = d_mem_out_addr;
assign valid         = d_mem_valid;
assign ready         = d_mem_ready;
assign d_mem_address = address;
assign d_mem_in_data = store_data;
assign d_mem_read    = load;
assign d_mem_write   = store;

reg [31: 0] cycles;
always @ (posedge clock) begin
  cycles <= reset? 0 : cycles + 1;
  //if (report & ((cycles >=  PRINT_CYCLES_MIN) & (cycles < PRINT_CYCLES_MAX +1)))begin
  if (report)begin
    $display ("------ Core %d Memory Unit - Current Cycle %d -------", CORE, cycles);
    $display ("| Address     [%h]", address);
    $display ("| Load        [%b]", load);
    $display ("| Data Address[%h]", data_addr);
    $display ("| Load Data   [%h]", load_data);
    $display ("| Store       [%b]", store);
    $display ("| Store Data  [%h]", store_data);
    $display ("| Ready       [%b]", ready);
    $display ("| Valid       [%b]", valid);
    $display ("----------------------------------------------------------------------");
  end
end

endmodule
