/** @module : fetch_unit
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

module fetch_unit #(parameter CORE = 0, DATA_WIDTH = 32, INDEX_BITS = 6,
                     OFFSET_BITS = 3, ADDRESS_BITS = 20, 
                     PROGRAM = "/home/dkava/Documents/ec513/ec513-project/binaries/gdc_mem/instructions.dat",
                     PRINT_CYCLES_MIN = 1, PRINT_CYCLES_MAX = 1000 ) (
 
        clock, reset, start, stall,
        next_PC_select_execute,
        program_address,
        JAL_target,
        JALR_target,
        branch,
        branch_target,
        JAL_detected,
        store_pause,
        store_PC,
        report,

        instruction,
        inst_PC,
        valid,
        ready
       
);

input clock, reset, start, stall;
input [1:0] next_PC_select_execute;
input [ADDRESS_BITS-1:0] program_address;
input [ADDRESS_BITS-1:0] JAL_target;
input [ADDRESS_BITS-1:0] JALR_target;
input branch;
input [ADDRESS_BITS-1:0] branch_target;
input JAL_detected;
input store_pause;
input [ADDRESS_BITS-1:0] store_PC;
input report;


output [DATA_WIDTH-1:0]   instruction;
output [ADDRESS_BITS-1:0] inst_PC;
output valid;
output ready;

reg fetch;
reg [ADDRESS_BITS-1:0] old_PC;
reg  [ADDRESS_BITS-1:0] PC_reg;
reg  JAL_detected_old;
reg  [ADDRESS_BITS-1:0] inst_addr_reg;
// PC Must be registered to prevent combinational loop with cache stall
wire [ADDRESS_BITS-1:0] PC;
wire [ADDRESS_BITS-1:0] PC_plus4;
// Adjustment to be word addressable instruction addresses
wire [ADDRESS_BITS-1:0] inst_addr;
wire [ADDRESS_BITS-1:0] out_addr;

assign PC = reset ? program_address : PC_reg;
assign PC_plus4 = PC + 4;
assign inst_addr = PC >> 2;
assign inst_PC = (JAL_detected )? old_PC : inst_addr_reg;

//fetch is consindered valid address
i_mem_interface #(
    .CORE(CORE),
    .DATA_WIDTH(DATA_WIDTH),
    .INDEX_BITS(INDEX_BITS),
    .OFFSET_BITS(OFFSET_BITS),
    .ADDRESS_BITS(ADDRESS_BITS),
    .PROGRAM(PROGRAM)
) i_mem_interface0 (
    .clock(clock),
    .reset(reset),
    .read(fetch),
    .write(1'b0),
    .address(inst_addr),
    .in_data(0),
    .stall(stall),
    .out_addr(out_addr),
    .out_data(instruction),
    .valid(valid),
    .ready(ready),
    .report(1'b0)
);

always @ (posedge clock) begin
    if (reset) begin
        fetch        <= 0;
        PC_reg       <= 0;
        old_PC       <= 0;
    end
    else begin
        if (start) begin
            fetch            <= 1;
            PC_reg           <= program_address;
            old_PC           <= program_address;
            JAL_detected_old <= 1'b0;
            inst_addr_reg    <= program_address;
        end 
        else if(stall && ~JAL_detected_old) begin 
            fetch            <= (next_PC_select_execute == 2'b11)? 1'b1: 1'b0 ;
           
            PC_reg           <= (next_PC_select_execute == 2'b11)?            JALR_target   :
                                (next_PC_select_execute == 2'b10)?            JAL_target    :
                                (next_PC_select_execute == 2'b01) & branch ?  branch_target :
                                (next_PC_select_execute == 2'b01) & ~branch?  PC_reg+4      :
                                (store_pause)?                                store_PC      :                       
                                                                              PC_reg        ;                                
            old_PC           <= (store_pause)? (store_PC - 4) : old_PC ;
            JAL_detected_old <= JAL_detected;
            inst_addr_reg    <= out_addr << 2;
        end 
        else if(JAL_detected_old) begin //JAL_detected is brought in to stop PC old is used for the JAL.
            fetch            <= 1;
            PC_reg           <= (next_PC_select_execute == 2'b11)?              JALR_target   :
                                (next_PC_select_execute == 2'b10)?              JAL_target    :
                                ((next_PC_select_execute == 2'b01) & branch)?   branch_target :
                                ((next_PC_select_execute == 2'b01) & ~branch)?  PC_reg +4     :
                                PC_plus4;
            old_PC           <= PC_reg;
            JAL_detected_old <= JAL_detected;
            inst_addr_reg    <= out_addr << 2;
        end   
        else begin
            fetch            <= 1;
            PC_reg           <= (next_PC_select_execute == 2'b11)?              JALR_target   :
                                (next_PC_select_execute == 2'b10)?              JAL_target    :
                                ((next_PC_select_execute == 2'b01) & branch)?   branch_target :
                                ((next_PC_select_execute == 2'b01) & ~branch)?  PC_reg+4      :
                                (store_pause)?                                  store_PC      :
                                                                                PC_plus4      ;
            old_PC           <= (store_pause)? (store_PC - 4)  : PC_reg;
            JAL_detected_old <= JAL_detected;
            inst_addr_reg    <= out_addr << 2;
        end
    end
end

reg [31: 0] cycles;
always @ (posedge clock) begin
    cycles <= reset? 0 : cycles + 1;
    //if (report & ((cycles >=  PRINT_CYCLES_MIN) & (cycles < PRINT_CYCLES_MAX +1)))begin
    if (report)begin
        $display ("------ Core %d Fetch Unit - Current Cycle %d --------", CORE, cycles);
        $display ("| Prog_Address[%h]", program_address);
        $display ("| next_PC_select_execute[%b]", next_PC_select_execute);
        $display ("| PC          [%h]", PC);
        $display ("| old_PC      [%h]", old_PC);
        $display ("| PC_plus4    [%h]", PC_plus4);
        $display ("| JAL_target  [%h]", JAL_target);
        $display ("| JALR_target [%h]", JALR_target);
        $display ("| Branch      [%b]", branch);
        $display ("| branchTarget[%h]", branch_target);
        $display ("| Read        [%b]", fetch);
        $display ("| instruction [%h]", instruction);
        $display ("| inst_PC     [%h]", inst_PC);
        $display ("| Ready       [%b]", ready);
        $display ("| Valid       [%b]", valid);
        $display ("----------------------------------------------------------------------");
    end
end

endmodule
