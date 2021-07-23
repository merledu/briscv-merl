/** @module : decode
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

// TODO: Remove all '=' from wire declarations.
// 32-bit Decoder
module decode_unit #(
  parameter CORE = 0,
  parameter ADDRESS_BITS = 20,
  parameter DATA_WIDTH = 32,
  parameter PRINT_CYCLES_MIN = 1,
  parameter PRINT_CYCLES_MAX = 1000
) (

  input  clock,
  input  reset,
  input  [ADDRESS_BITS-1:0] PC,
  input  [DATA_WIDTH-1:0] instruction,
  input  [1:0] extend_sel,
  input  write,
         // TODO: rename write_reg to write_sel to match read_sel signals. This
         // is more clear. -Alan
  input  [4:0]  write_reg,
  input  [DATA_WIDTH-1:0] write_data,
  input  [2:0] rs1_data_bypass,
  input  [2:0] rs2_data_bypass,
  input  [DATA_WIDTH-1:0] ALU_result_execute,
  input  [DATA_WIDTH-1:0] ALU_result_memory1,
  input  [DATA_WIDTH-1:0] ALU_result_memory2,
  input  [DATA_WIDTH-1:0] ALU_result_writeback,

  output [DATA_WIDTH-1:0] rs1_data,
  output [DATA_WIDTH-1:0] rs2_data,
  output [4:0]  rd,
  output [6:0]  opcode,
  output [6:0]  funct7,
  output [2:0]  funct3,
  output [DATA_WIDTH-1:0] extend_imm,
  output [ADDRESS_BITS-1:0] branch_target,
  output [ADDRESS_BITS-1:0] JAL_target,
  output [4:0] rs1,
  output [4:0] rs2,

  input report

); 
 
wire[DATA_WIDTH-1:0] rs1_data_decode;
wire[DATA_WIDTH-1:0] rs2_data_decode;
wire[11:0] i_imm      = instruction[31:20];
wire[6:0]  s_imm_msb  = instruction[31:25];
wire[4:0]  s_imm_lsb  = instruction[11:7];
wire[19:0] u_imm      = instruction[31:12];
wire[11:0] i_imm_orig = instruction[31:20]; 
wire[19:0] uj_imm     = {instruction[31],instruction[19:12],instruction[20],instruction[30:21]};

//Forming the s immediate value from the two msb and lsb parts of the s immediate
wire[11:0] s_imm_orig  = {s_imm_msb,s_imm_lsb};
wire[12:0] sb_imm_orig = {s_imm_msb[6],s_imm_lsb[0],s_imm_msb[5:0],s_imm_lsb[4:1],1'b0};

// Read registers
assign  rs2           = instruction[24:20];
assign  rs1           = instruction[19:15];

/* Instruction decoding */
assign opcode        = instruction[6:0];
assign funct7        = instruction[31:25];
assign funct3        = instruction[14:12];

/* Write register */
assign  rd           = instruction[11:7];

/* Only workig with BEQ at the moment */
wire[31:0] sb_imm_32 = {{19{sb_imm_orig[12]}}, sb_imm_orig};
assign branch_target = PC + sb_imm_32;

/* Extensions */
wire[31:0] u_imm_32  = {u_imm,12'b0};
wire[31:0] i_imm_32  = {{20{i_imm_orig[11]}}, i_imm_orig[11:0] };
wire[31:0] s_imm_32  = {{20{s_imm_orig[11]}}, s_imm_orig};

assign extend_imm    = (extend_sel == 2'b01)? s_imm_32 :
                       (extend_sel == 2'b10)? u_imm_32 : i_imm_32;

/* Only JAL Target. JALR happens in the execution unit*/
wire[31:0] uj_imm_32 = {{11{uj_imm[19]}},uj_imm[19:0],1'b0};
assign JAL_target    = uj_imm_32 + PC;

//mux's select for data bypassing
assign rs1_data      = (rs1_data_bypass == 3'b000)? rs1_data_decode      :
                       (rs1_data_bypass == 3'b001)? ALU_result_execute   :
                       (rs1_data_bypass == 3'b010)? ALU_result_memory1   :
                       (rs1_data_bypass == 3'b011)? ALU_result_memory2   :
                       (rs1_data_bypass == 3'b100)? ALU_result_writeback :
                       {DATA_WIDTH{1'b0}};

assign rs2_data      = (rs2_data_bypass == 3'b000)? rs2_data_decode      :
                       (rs2_data_bypass == 3'b001)? ALU_result_execute   :
                       (rs2_data_bypass == 3'b010)? ALU_result_memory1   :
                       (rs2_data_bypass == 3'b011)? ALU_result_memory2   :
                       (rs2_data_bypass == 3'b100)? ALU_result_writeback :
                       {DATA_WIDTH{1'b0}};

regFile #(32, 5) registers (
                .clock(clock),
                .reset(reset),
                .read_sel1(rs1),
                .read_sel2(rs2),
                .wEn(write),
                .write_sel(write_reg),
                .write_data(write_data),
                .read_data1(rs1_data_decode),
                .read_data2(rs2_data_decode)
);

reg [31: 0] cycles;
always @ (posedge clock) begin
    cycles <= reset? 0 : cycles + 1;
    //if (report & ((cycles >=  PRINT_CYCLES_MIN) & (cycles < PRINT_CYCLES_MAX +1)))begin
    if (report)begin
        $display ("------ Core %d Decode Unit - Current Cycle %d -------", CORE, cycles);
        $display ("| PC          [%h]", PC);
        $display ("| Instruction [%h]", instruction);
        $display ("| rs1         [%d]", rs1);
        $display ("| rs1_data    [%d]", rs1_data);
        $display ("| rs2         [%d]", rs2);
        $display ("| rs2_data    [%d]", rs2_data);
        $display ("| rsd         [%d]", rd);
        $display ("| jumpTarget  [%h]", JAL_target);
        $display ("| branchTarget[%h]", branch_target);
        $display ("| Opcode      [%b]    Funct3 [%b]      Funct7  [%b]", opcode, funct3, funct7);
        $display ("| Immediate   [%d] Hex    [%h] Bin     [%b]", extend_imm, extend_imm, extend_imm[7:0]);
        $display ("| write       [%b]", write);
        $display ("| write_reg   [%d]", write_reg);
        $display ("| write_data  [%d]", write_data);
        $display ("----------------------------------------------------------------------");
    end
end

endmodule
