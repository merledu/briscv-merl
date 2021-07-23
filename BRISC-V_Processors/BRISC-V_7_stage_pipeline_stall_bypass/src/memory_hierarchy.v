module memory_hierarchy #(
  parameter CORE = 0,
  parameter DATA_WIDTH = 32,
  parameter INDEX_BITS = 6,
  parameter OFFSET_BITS = 3,
  parameter ADDRESS_BITS = 11,
  parameter PROGRAM = "../software/applications/binaries/<your_program>"
) (

  input clock,
  input reset,

  // Instruction Memory Interface
  input i_mem_read,
  input [ADDRESS_BITS-1:0] i_mem_read_address,
  input [DATA_WIDTH-1:0] i_mem_in_data,
  output [ADDRESS_BITS-1:0] i_mem_out_addr,
  output [DATA_WIDTH-1:0] i_mem_out_data,
  output i_mem_valid,
  output i_mem_ready,

  // In-System Programmer Interface
  input [ADDRESS_BITS-1:0] isp_address,
  input [DATA_WIDTH-1:0] isp_data,
  input isp_write,


  output [ADDRESS_BITS-1:0] d_mem_out_addr,
  output [DATA_WIDTH-1:0] d_mem_out_data,
  output d_mem_valid,
  output d_mem_ready,
  input [ADDRESS_BITS-1:0] d_mem_address,
  input [DATA_WIDTH-1:0] d_mem_in_data,
  input d_mem_read,
  input d_mem_write,

  input report

);

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
  .write(isp_write),
  .write_address(isp_address),
  .in_data(isp_data),
  .read(i_mem_read),
  .read_address(i_mem_read_address),
  .out_addr(i_mem_out_addr),
  .out_data(i_mem_out_data),
  .valid(i_mem_valid),
  .ready(i_mem_ready),
  .report(report)
);


d_mem_interface #(
    .CORE(CORE),
    .DATA_WIDTH(DATA_WIDTH),
    .INDEX_BITS(INDEX_BITS),
    .OFFSET_BITS(OFFSET_BITS),
    .ADDRESS_BITS(ADDRESS_BITS)
) d_mem_interface0 (
    .clock(clock),
    .reset(reset),
    .read(d_mem_read),
    .write(d_mem_write),
    .address(d_mem_address),
    .in_data(d_mem_in_data),
    .out_addr(d_mem_out_addr),
    .out_data(d_mem_out_data),
    .valid(d_mem_valid),
    .ready(d_mem_ready),
    .report(report)
);

endmodule
