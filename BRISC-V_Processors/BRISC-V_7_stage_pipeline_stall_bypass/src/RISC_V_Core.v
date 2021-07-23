/** @module : RISC_V_Core
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
 *
 */

module RISC_V_Core #(
  parameter CORE = 0,
  parameter DATA_WIDTH = 32,
  parameter INDEX_BITS = 6,
  parameter OFFSET_BITS = 3,
  parameter ADDRESS_BITS = 12,
  parameter PRINT_CYCLES_MIN = 0,
  parameter PRINT_CYCLES_MAX = 15,
  parameter PROGRAM = "../software/applications/binaries/short_mandelbrot.vmh"
) (
  input clock,

  input reset,
  input start,
  input [ADDRESS_BITS-1:0] prog_address,

  // For I/O funstions
  input [1:0] from_peripheral,
  input [31:0] from_peripheral_data,
  input from_peripheral_valid,

  output reg [1:0] to_peripheral,
  output reg [31:0] to_peripheral_data,
  output reg to_peripheral_valid,

  // In-System Programmer Interface
  input [ADDRESS_BITS-1:0] isp_address,
  input [DATA_WIDTH-1:0] isp_data,
  input isp_write,

  input report, // performance reporting
  output [ADDRESS_BITS-1:0] current_PC
);

// TODO: Break up wire declarations by module/stage
wire [31:0]  instruction_fetch1; // output of i_mem_interface
wire [31:0]  instruction_fetch2; // output of fetch unit
wire [31:0]  instruction_decode;
// For Debug
wire [31:0]  instruction_execute;
wire [31:0]  instruction_memory1;
wire [31:0]  instruction_writeback;

wire [ADDRESS_BITS-1: 0] inst_PC_fetch;
wire [ADDRESS_BITS-1: 0] inst_PC_decode;
wire valid_fetch2;
wire ready_fetch2;
wire valid_memory2;
wire ready_memory2;
wire [4:0] rs1_decode;
wire [4:0] rs2_decode;
wire stall;
wire [ADDRESS_BITS-1: 0] JAL_target_decode;
wire [ADDRESS_BITS-1: 0] JAL_target_execute;
wire [ADDRESS_BITS-1: 0] JALR_target_execute;
wire [ADDRESS_BITS-1: 0] branch_target_decode;
wire [ADDRESS_BITS-1: 0] branch_target_execute;

wire  write_writeback;
wire  [4:0]  write_reg_writeback;
wire  [DATA_WIDTH-1:0] write_data_writeback;

wire [DATA_WIDTH-1:0]  rs1_data_decode;
wire [DATA_WIDTH-1:0]  rs2_data_decode;
wire [4:0]  rd_decode;
wire [6:0]  opcode_decode;
wire [6:0]  funct7_decode;
wire [2:0]  funct3_decode;

wire [DATA_WIDTH-1:0]  rs1_data_execute;
wire [DATA_WIDTH-1:0]  rs2_data_execute;
wire [DATA_WIDTH-1:0]  rs2_data_memory1;
wire [4:0]   rd_execute;

wire [ADDRESS_BITS-1: 0] PC_execute;
wire [6:0]  opcode_execute;
wire [6:0]  opcode_memory1;
wire [6:0]  funct7_execute;
wire [2:0]  funct3_execute;

wire memRead_decode;
wire memRead_execute;
wire memRead_memory1;
wire memRead_writeback;

wire [4:0]  rd_memory1;
wire [4:0]  rd_memory2;
wire [4:0]  rd_writeback;
wire memtoReg;
wire [2:0] ALUOp_decode;
wire [2:0] ALUOp_execute;
wire branch_op_decode;
wire branch_op_execute;
wire [1:0] next_PC_select_decode;
wire [1:0] next_PC_select_execute;
wire [1:0] next_PC_select_memory1;
wire [1:0] next_PC_select_memory2;
wire [1:0] next_PC_select_writeback; // TODO: MAke this memory2 when extra memory stage is added
wire [1:0] operand_A_sel_decode;
wire [1:0] operand_A_sel_execute;
wire operand_B_sel_decode;
wire operand_B_sel_execute;
wire [1:0] extend_sel_decode;
wire [DATA_WIDTH-1:0]  extend_imm_decode;
wire [DATA_WIDTH-1:0]  extend_imm_execute;

wire memWrite_decode;
wire memWrite_execute;
wire memWrite_memory1;
wire regWrite_decode;
wire regWrite_execute;
wire regWrite_memory1;
wire regWrite_memory2;
wire regWrite_writeback;

wire branch_execute;
wire [DATA_WIDTH-1:0]   ALU_result_execute;
wire [DATA_WIDTH-1:0]   ALU_result_memory1;
wire [DATA_WIDTH-1:0]   ALU_result_writeback;
wire [ADDRESS_BITS-1:0] generated_addr = ALU_result_memory1; // the case the address is not 32-bit

wire zero; // Have not done anything with this signal

wire [DATA_WIDTH-1:0]    memory_data_memory2;
wire [DATA_WIDTH-1:0]    memory_data_writeback;
wire [DATA_WIDTH-1:0]    bypass_data_memory2;
wire [ADDRESS_BITS-1: 0] memory_addr_memory2; // To use to check the address coming out the memory stage

wire [2:0] rs1_data_bypass;
wire [2:0] rs2_data_bypass;

// Memory Hierarchy Wires - Instruction Memory Interface
wire i_mem_read;
wire [ADDRESS_BITS-1:0] i_mem_read_address;
wire [DATA_WIDTH-1:0] i_mem_in_data;
wire [ADDRESS_BITS-1:0] i_mem_out_addr;
wire [DATA_WIDTH-1:0] i_mem_out_data;
wire i_mem_valid;
wire i_mem_ready;

// Memory Hierarchy Wires - Data Memory Interface
wire [ADDRESS_BITS-1:0] d_mem_out_addr;
wire [DATA_WIDTH-1:0] d_mem_out_data;
wire d_mem_valid;
wire d_mem_ready;
wire [ADDRESS_BITS-1:0] d_mem_address;
wire [DATA_WIDTH-1:0] d_mem_in_data;
wire d_mem_read;
wire d_mem_write;


// Assignments to make debugging easier
assign current_PC         = inst_PC_fetch;
assign instruction_fetch1 = i_mem_out_data;

memory_hierarchy #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .INDEX_BITS(INDEX_BITS),
  .OFFSET_BITS(OFFSET_BITS),
  .ADDRESS_BITS(ADDRESS_BITS),
  .PROGRAM(PROGRAM)
) mem_hierarchy_inst (
  .clock(clock),
  .reset(reset),

  // Instruction Memory Interface
  .i_mem_read(i_mem_read),
  .i_mem_read_address(i_mem_read_address),
  .i_mem_in_data(i_mem_in_data),
  .i_mem_out_addr(i_mem_out_addr),
  .i_mem_out_data(i_mem_out_data),
  .i_mem_valid(i_mem_valid),
  .i_mem_ready(i_mem_ready),

  // Data Memory Interface
  .d_mem_address(d_mem_address),
  .d_mem_read(d_mem_read),
  .d_mem_write(d_mem_write),
  .d_mem_in_data(d_mem_in_data),
  .d_mem_out_addr(d_mem_out_addr),
  .d_mem_out_data(d_mem_out_data),
  .d_mem_valid(d_mem_valid),
  .d_mem_ready(d_mem_ready),

  // In-System Programmer Interface
  .isp_address(isp_address),
  .isp_data(isp_data),
  .isp_write(isp_write),

  .report(report)

);

fetch_unit #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .INDEX_BITS(INDEX_BITS),
  .OFFSET_BITS(OFFSET_BITS),
  .ADDRESS_BITS(ADDRESS_BITS),
  .PROGRAM(PROGRAM),
  .PRINT_CYCLES_MIN(PRINT_CYCLES_MIN),
  .PRINT_CYCLES_MAX(PRINT_CYCLES_MAX)
) IF (
  .clock(clock),
  .reset(reset),
  .start(start),
  .stall(stall),
  .next_PC_select_execute(next_PC_select_execute),
  .program_address(prog_address),
  .JAL_target(JAL_target_execute),
  .JALR_target(JALR_target_execute),
  .branch(branch_execute),
  .branch_target(branch_target_execute),

  // Instruction Memory Interface
  .i_mem_read(i_mem_read),
  .i_mem_read_address(i_mem_read_address),
  .i_mem_out_addr(i_mem_out_addr),
  .i_mem_out_data(i_mem_out_data),
  .i_mem_valid(i_mem_valid),
  .i_mem_ready(i_mem_read),

  .instruction(instruction_fetch2),
  .inst_PC(inst_PC_fetch),
  .valid(valid_fetch2), // Unused in 7 stage BRAM
  .ready(ready_fetch2), // Unused in 7 stage BRAM
  .report(report),

  .inst_PC_decode(inst_PC_decode)

);

fetch_pipe_unit #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) IF_ID (
  .clock(clock),
  .reset(reset),
  .stall(stall),
  .instruction_fetch(instruction_fetch2),
  .inst_PC_fetch(inst_PC_fetch),

  .instruction_decode(instruction_decode),
  .inst_PC_decode(inst_PC_decode)
 );

decode_unit #(
  .CORE(CORE),
  .ADDRESS_BITS(ADDRESS_BITS),
  .DATA_WIDTH(DATA_WIDTH),
  .PRINT_CYCLES_MIN(PRINT_CYCLES_MIN),
  .PRINT_CYCLES_MAX(PRINT_CYCLES_MAX)
) ID (
  .clock(clock),
  .reset(reset),
  .PC(inst_PC_decode),
  .instruction(instruction_decode),

  .extend_sel(extend_sel_decode),
  .write(write_writeback),
  .write_reg(write_reg_writeback),
  .write_data(write_data_writeback),
  .rs1_data_bypass(rs1_data_bypass),
  .rs2_data_bypass(rs2_data_bypass),
  .ALU_result_execute(ALU_result_execute),
  .ALU_result_memory1(ALU_result_memory1),
  .ALU_result_memory2(bypass_data_memory2),
  .ALU_result_writeback(write_data_writeback),

  .opcode(opcode_decode),
  .funct3(funct3_decode),
  .funct7(funct7_decode),
  .rs1_data(rs1_data_decode),
  .rs2_data(rs2_data_decode),
  .rd(rd_decode),
  .extend_imm(extend_imm_decode),
  .branch_target(branch_target_decode),
  .JAL_target(JAL_target_decode),
  .rs1(rs1_decode),
  .rs2(rs2_decode),
  .report(report)
);

stall_and_bypass_control_unit ID_SB (
  .clock(clock),
  .rs1(rs1_decode),
  .rs2(rs2_decode),
  .regwrite_execute(regWrite_execute),
  .regwrite_memory1(regWrite_memory1),
  .regwrite_memory2(regWrite_memory2),
  .regwrite_writeback(regWrite_writeback),
  .rd_execute(rd_execute),
  .rd_memory1(rd_memory1),
  .rd_memory2(rd_memory2),
  .rd_writeback(rd_writeback),
  .opcode_execute(opcode_execute),
  .opcode_memory1(opcode_memory1),

  .rs1_data_bypass(rs1_data_bypass),
  .rs2_data_bypass(rs2_data_bypass),
  .stall(stall)
);

control_unit #(
  .CORE(CORE),
  .PRINT_CYCLES_MIN(PRINT_CYCLES_MIN),
  .PRINT_CYCLES_MAX(PRINT_CYCLES_MAX)
) CU (
  .clock(clock),
  .reset(reset),

  .opcode(opcode_decode),
  .branch_op(branch_op_decode),
  .memRead(memRead_decode),
  .memtoReg(memtoReg),
  .ALUOp(ALUOp_decode),
  .memWrite(memWrite_decode),
  .next_PC_sel(next_PC_select_decode),
  .operand_A_sel(operand_A_sel_decode),
  .operand_B_sel(operand_B_sel_decode),
  .extend_sel(extend_sel_decode),
  .regWrite(regWrite_decode),

  .report(report)
);

decode_pipe_unit #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) ID_EU (
  .clock(clock),
  .reset(reset),
  .stall(stall),
  .rs1_data_decode(rs1_data_decode),
  .rs2_data_decode(rs2_data_decode),
  .funct7_decode(funct7_decode),
  .funct3_decode(funct3_decode),
  .rd_decode(rd_decode),
  .opcode_decode(opcode_decode),
  .extend_imm_decode(extend_imm_decode),
  .branch_target_decode(branch_target_decode),
  .JAL_target_decode(JAL_target_decode),
  .PC_decode(inst_PC_decode),
  .branch_op_decode(branch_op_decode),
  .memRead_decode(memRead_decode),
  .ALUOp_decode(ALUOp_decode),
  .memWrite_decode(memWrite_decode),
  .next_PC_select_decode(next_PC_select_decode),
  .next_PC_select_memory1(next_PC_select_memory1),
  .next_PC_select_memory2(next_PC_select_memory2),
  .operand_A_sel_decode(operand_A_sel_decode),
  .operand_B_sel_decode(operand_B_sel_decode),
  .regWrite_decode(regWrite_decode),
  // For Debug
  .instruction_decode(instruction_decode),

  .rs1_data_execute(rs1_data_execute),
  .rs2_data_execute(rs2_data_execute),
  .funct7_execute(funct7_execute),
  .funct3_execute(funct3_execute),
  .rd_execute(rd_execute),
  .opcode_execute(opcode_execute),
  .extend_imm_execute(extend_imm_execute),
  .branch_target_execute(branch_target_execute),
  .JAL_target_execute(JAL_target_execute),
  .PC_execute(PC_execute),
  .branch_op_execute(branch_op_execute),
  .memRead_execute(memRead_execute),
  .ALUOp_execute(ALUOp_execute),
  .memWrite_execute(memWrite_execute),
  .next_PC_select_execute(next_PC_select_execute),
  .operand_A_sel_execute(operand_A_sel_execute),
  .operand_B_sel_execute(operand_B_sel_execute),
  .regWrite_execute(regWrite_execute),
  // For Debug
  .instruction_execute(instruction_execute)
);



execution_unit #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS),
  .PRINT_CYCLES_MIN(PRINT_CYCLES_MIN),
  .PRINT_CYCLES_MAX(PRINT_CYCLES_MAX)
) EU (
  .clock(clock),
  .reset(reset),
  .stall(stall),

  .ALU_Operation(ALUOp_execute),
  .funct3(funct3_execute),
  .funct7(funct7_execute),
  .branch_op(branch_op_execute),
  .PC(PC_execute),
  .ALU_ASrc(operand_A_sel_execute),
  .ALU_BSrc(operand_B_sel_execute),
  .regRead_1(rs1_data_execute),
  .regRead_2(rs2_data_execute),
  .extend(extend_imm_execute),
  .ALU_result(ALU_result_execute),
  .zero(zero),
  .branch(branch_execute),
  .JALR_target(JALR_target_execute),

  .report(report)
);

execute_pipe_unit #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) EU_MU (
  .clock(clock),
  .reset(reset),
  //.stall(stall),
  .ALU_result_execute(ALU_result_execute),
  .store_data_execute(rs2_data_execute),
  .rd_execute(rd_execute),
  .opcode_execute(opcode_execute),
  .memWrite_execute(memWrite_execute),
  .memRead_execute(memRead_execute),
  .next_PC_select_execute(next_PC_select_execute),
  .regWrite_execute(regWrite_execute),
  // For Debug
  .instruction_execute(instruction_execute),

  .ALU_result_memory1(ALU_result_memory1),
  .store_data_memory1(rs2_data_memory1),
  .rd_memory1(rd_memory1),
  .opcode_memory1(opcode_memory1),
  .memWrite_memory1(memWrite_memory1),
  .memRead_memory1(memRead_memory1),
  .next_PC_select_memory1(next_PC_select_memory1),
  .regWrite_memory1(regWrite_memory1),
  // For Debug
  .instruction_memory1(instruction_memory1)
);

memory_unit #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .INDEX_BITS(INDEX_BITS),
  .OFFSET_BITS(OFFSET_BITS),
  .ADDRESS_BITS(ADDRESS_BITS),
  .PRINT_CYCLES_MIN(PRINT_CYCLES_MIN),
  .PRINT_CYCLES_MAX(PRINT_CYCLES_MAX)
) MU (
  .clock(clock),
  .reset(reset),
  .stall(stall),

  // Connections to/from pipeline stages
  .load(memRead_memory1),
  .store(memWrite_memory1),
  .address(generated_addr),
  .store_data(rs2_data_memory1),
  //.ALU_result(ALU_result_memory),
  .data_addr(memory_addr_memory2),
  .load_data(memory_data_memory2),
  //.bypass_data(bypass_data_memory),
  .valid(valid_memory2), // Unused in 7 stage BRAM
  .ready(ready_memory2), // Unused in 7 stage BRAM

  // Data Memory Interface 
  .d_mem_out_addr(d_mem_out_addr),
  .d_mem_out_data(d_mem_out_data),
  .d_mem_valid(d_mem_valid),
  .d_mem_ready(d_mem_ready),

  .d_mem_address(d_mem_address),
  .d_mem_in_data(d_mem_in_data),
  .d_mem_read(d_mem_read),
  .d_mem_write(d_mem_write),

  .report(report)
);
memory_pipe_unit #(
  .DATA_WIDTH(DATA_WIDTH),
  .ADDRESS_BITS(ADDRESS_BITS)
) MU_WB (
  .clock(clock),
  .reset(reset),

  .ALU_result_memory1(ALU_result_memory1),
  .load_data_memory2(memory_data_memory2), // memory_data_memory1 is the bram register
  .opwrite_memory1(regWrite_memory1),
  .opSel_memory1(memRead_memory1),
  .opReg_memory1(rd_memory1),
  .next_PC_select_memory1(next_PC_select_memory1),
  // For Debug
  .instruction_memory1(instruction_memory1),

  .ALU_result_writeback(ALU_result_writeback),
  .load_data_writeback(memory_data_writeback),
  .opwrite_writeback(regWrite_writeback),
  .opSel_writeback(memRead_writeback),
  .opReg_writeback(rd_writeback),
  .next_PC_select_writeback(next_PC_select_writeback),
  // For Debug
  .instruction_writeback(instruction_writeback),

  .bypass_data_memory2(bypass_data_memory2),
  .next_PC_select_memory2(next_PC_select_memory2),
  .opwrite_memory2(regWrite_memory2),
  .opReg_memory2(rd_memory2)
);

writeback_unit #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .PRINT_CYCLES_MIN(PRINT_CYCLES_MIN),
  .PRINT_CYCLES_MAX(PRINT_CYCLES_MAX)
) WB (
  .clock(clock),
  .reset(reset),
  .stall(stall),

  // TODO: Rename op* ports. It is not clear what op means. they also
  // violate the naming convention of using underscores and lower case.
  .opWrite(regWrite_writeback),
  .opSel(memRead_writeback),
  .opReg(rd_writeback),
  .ALU_Result(ALU_result_writeback),
  .memory_data(memory_data_writeback),
  .write(write_writeback),
  .write_reg(write_reg_writeback),
  .write_data(write_data_writeback),

  .report(report)
);



//Register s2-s11 [$x18-$x27] are saved across calls ... Using s2-s9 [x18-x25] for final results
always @ (posedge clock) begin
         //if (write && ((write_reg >= 18) && (write_reg <= 25)))  begin
         if (write_writeback && ((write_reg_writeback >= 10) && (write_reg_writeback <= 17)))  begin
              to_peripheral       <= 0;
              to_peripheral_data  <= write_data_writeback;
              to_peripheral_valid <= 1;
              //$display (" Core [%d] Register [%d] Value = %d", CORE, write_reg_fetch, write_data_fetch);
         end
         else to_peripheral_valid <= 0;
end

endmodule
