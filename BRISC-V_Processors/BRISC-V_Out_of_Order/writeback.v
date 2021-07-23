/** @module : writeback
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
 module writeback_unit #(parameter  CORE = 0, DATA_WIDTH = 32,
                            PRINT_CYCLES_MIN = 1, PRINT_CYCLES_MAX = 1000,
                            NUMBER_OF_ACTIVE_INSTRUCTIONS = 2 , NUMBER_OF_QUEUED_INSTRUCTIONS = 4, ADDRESS_BITS = 20    )(
      clock, reset,
      valid_commit,
      commit_instruction_ID,
      opReg, 
      opWrite,
      ALU_Result, 
      PC_select_commit,
      JALR_target_commit,
      branch_target_commit,
      branch_commit,
     
      write, write_reg, write_data, 
      valid,
      writeback_instruction_ID,
      PC_select_writeback,
      JALR_target_writeback,
      branch_target_writeback,
      branch_writeback,
      branch_detected_writeback,
      report
); 

 //  define the log2 function
function integer log2;
    input integer num;
    integer i, result;
    begin
        for (i = 0; 2 ** i < num; i = i + 1)
            result = i + 1;
        log2 = result;
    end
endfunction

input  clock; 
input  reset; 
input  valid_commit;
input  [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] commit_instruction_ID;
input  opWrite;

input  [4:0]  opReg;
input  [DATA_WIDTH-1:0] ALU_Result;
input  [1:0] PC_select_commit;
input  [ADDRESS_BITS-1:0] JALR_target_commit;
input  [ADDRESS_BITS-1:0] branch_target_commit;
input  branch_commit;

output  write;
output  [4:0]  write_reg;
output  [DATA_WIDTH-1:0] write_data;
output  valid;
output  [log2(NUMBER_OF_ACTIVE_INSTRUCTIONS)-1:0] writeback_instruction_ID;
output  [1:0] PC_select_writeback;
output  [ADDRESS_BITS-1:0] JALR_target_writeback;
output  [ADDRESS_BITS-1:0] branch_target_writeback;
output  branch_writeback;
output  branch_detected_writeback;
input   report;


reg [1:0] PC_select_writeback_to_fetch;
reg [ADDRESS_BITS-1:0] JALR_target_writeback_to_fetch;
reg [ADDRESS_BITS-1:0] branch_target_writeback_to_fetch;
reg branch_writeback_to_fetch;


assign write_data         = ALU_Result; 
assign write_reg          = opReg; 
assign write              = (valid_commit)? opWrite: 1'b0; 
assign valid              = valid_commit;

assign branch_detected_writeback =  (PC_select_commit == 2'b01)? 1'b1: //branch
                                    (PC_select_commit == 2'b11)? 1'b1: //JALR
                                                                 1'b0;        
assign writeback_instruction_ID  = commit_instruction_ID;
assign JALR_target_writeback     = JALR_target_writeback_to_fetch;
assign PC_select_writeback       = PC_select_writeback_to_fetch;
assign branch_writeback          = branch_writeback_to_fetch;
assign branch_target_writeback   = branch_target_writeback_to_fetch;

// register output for branches 
always @(posedge clock) begin
    if (reset) begin
        PC_select_writeback_to_fetch      <= 1'b0;
        JALR_target_writeback_to_fetch    <= {ADDRESS_BITS{1'b0}};
        branch_target_writeback_to_fetch  <= {ADDRESS_BITS{1'b0}};
        branch_writeback_to_fetch         <= 1'b0;  
    end
    else begin
        PC_select_writeback_to_fetch      <= PC_select_commit;                                 
        JALR_target_writeback_to_fetch    <= JALR_target_commit;                 
        branch_target_writeback_to_fetch  <= branch_target_commit;                 
        branch_writeback_to_fetch         <= branch_commit;                                         
    end
end


reg [31: 0] cycles; 
always @ (posedge clock) begin 
    cycles <= reset? 0 : cycles + 1; 
    //if (report & ((cycles >=  PRINT_CYCLES_MIN) & (cycles < PRINT_CYCLES_MAX +1)))begin
    if (report)begin
        $display ("------ Core %d Writeback Unit - Current Cycle %d ----", CORE, cycles); 
        //$display ("| opSel       [%b]", opSel);
        $display ("| opReg       [%b]", opReg);
        $display ("| ALU_Result  [%d]", ALU_Result);
       // $display ("| Memory_data [%d]", memory_data);
        $display ("| write       [%b]", write);
        $display ("| write_reg   [%d]", write_reg);
        $display ("| write_data  [%d]", write_data);
        $display ("----------------------------------------------------------------------");
    end
end

endmodule

 
