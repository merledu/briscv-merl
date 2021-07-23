/*  @author : Adaptive & Secure Computing Systems (ASCS) Laboratory

 *  Copyright (c) 2018 BRISC-V (ASCS/ECE/BU)
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 z
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 *
 *
 */

/*********************************************************************************
*                              stallControl.v                                    *
*********************************************************************************/


module stall_control_unit  (
    input clock,
    input [4:0] rs1,
    input [4:0] rs2,
    input regwrite_decode,
    input regwrite_execute,
    input regwrite_memory,
    input regwrite_writeback,
    input [4:0] rd_execute,
    input [4:0] rd_memory,
    input [4:0] rd_writeback,

    output stall_needed
);

reg stall;
wire stall_interupt;
wire rs1_hazard_execute;
wire rs1_hazard_memory;
wire rs1_hazard_writeback;
wire rs2_hazard_execute;
wire rs2_hazard_memory;
wire rs2_hazard_writeback;
wire rs1_hazard_detected;
wire rs2_hazard_detected;

// Detect hazards between decode and other stages
assign rs1_hazard_execute   = (rs1 == rd_execute   ) & regwrite_execute  ;
assign rs1_hazard_memory    = (rs1 == rd_memory    ) & regwrite_memory   ;
assign rs1_hazard_writeback = (rs1 == rd_writeback ) & regwrite_writeback;

assign rs2_hazard_execute   = (rs2 == rd_execute   ) & regwrite_execute  ;
assign rs2_hazard_memory    = (rs2 == rd_memory    ) & regwrite_memory   ;
assign rs2_hazard_writeback = (rs2 == rd_writeback ) & regwrite_writeback;

// TODO: Add read enable to detect true reads. Not every instruction reads
// both registers.
assign rs1_hazard_detected = (rs1_hazard_execute    |
                              rs1_hazard_memory     |
                              rs1_hazard_writeback) & (rs1 != 5'd0);

assign rs2_hazard_detected = (rs2_hazard_execute    |
                              rs2_hazard_memory     |
                              rs2_hazard_writeback) & (rs2 != 5'd0);

assign stall_interupt = (rs1_hazard_detected | rs2_hazard_detected)?  1'b1 : 1'b0;

//needed extra stall cycle
assign stall_needed = stall_interupt | stall;

always @(posedge clock) begin
    stall <= stall_interupt;
end

endmodule
