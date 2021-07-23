`include "processor_specific_macros.h"

module hanoi_tb();

parameter CORE = 0;
parameter DATA_WIDTH = 32;
parameter INDEX_BITS = 6;
parameter OFFSET_BITS = 3;
parameter ADDRESS_BITS = 12;
parameter ZEROS4096 = "../software/applications/binaries/zeros4096.dat";
parameter ZEROS32 = "../software/applications/binaries/zeros32.dat";
parameter PROGRAM = "../software/applications/binaries/basic_tests/hanoi.vmh";
parameter TEST_LENGTH = 10000;
parameter TEST_NAME = "FACTORIAL";
parameter LOG_FILE = "basic_test_results.txt";

genvar i;
integer x;
integer log_file;

reg clock;
reg reset;
reg start;
reg [19:0] prog_address;
reg report; // performance reporting

wire [31:0] reg_match;

// For I/O funstions
reg [1:0]    from_peripheral;
reg [31:0]   from_peripheral_data;
reg          from_peripheral_valid;

wire [1:0]  to_peripheral;
wire [31:0] to_peripheral_data;
wire        to_peripheral_valid;

RISC_V_Core #(
  .CORE(CORE),
  .DATA_WIDTH(DATA_WIDTH),
  .INDEX_BITS(INDEX_BITS),
  .OFFSET_BITS(OFFSET_BITS),
  .ADDRESS_BITS(ADDRESS_BITS)
) core0 (
  .clock(clock),
  .reset(reset),
  .start(start),
  .prog_address(prog_address),

  .isp_write(1'b0),
  .isp_address({ADDRESS_BITS{1'b0}}),
  .isp_data({DATA_WIDTH{1'b0}}),

  .from_peripheral(from_peripheral),
  .from_peripheral_data(from_peripheral_data),
  .from_peripheral_valid(from_peripheral_valid),
  .to_peripheral(to_peripheral),
  .to_peripheral_data(to_peripheral_data),
  .to_peripheral_valid(to_peripheral_valid),

  .report(report)
);

// Clock generator
always #1 clock = ~clock;

// Initialize program memory
initial begin
  $readmemh(ZEROS4096, `PROGRAM_MEMORY );
  $readmemh(ZEROS32, `REGISTER_FILE);
  $readmemh(PROGRAM, `PROGRAM_MEMORY);
end

initial begin
  clock  = 0;
  reset  = 1;
  report = 0;
  start = 0;
  prog_address = {ADDRESS_BITS{1'b0}};
  #10

  #1
  reset = 0;
  start = 1;
  #1

  start = 0;

  #TEST_LENGTH

  log_file = $fopen(LOG_FILE,"a+");
  if(!log_file) begin
    $display("Could not open log file... Exiting!");
    $finish();
  end

  if(`REGISTER_FILE[9] == 32'h0000000f ) begin
    $display("%s: Test Passed!", TEST_NAME);
    $fdisplay(log_file, "%s: Test Passed!", TEST_NAME);
  end else begin
    $display("%s: Test Failed!", TEST_NAME);
    $display("Dumping reg file states:");
    $display("Reg Index, Value");
    for( x=0; x<32; x=x+1) begin
      $display("%d: %h", x, `REGISTER_FILE[x]);
      $fdisplay(log_file, "%d: %h", x, `REGISTER_FILE[x]);
    end
    $display("");
    $fdisplay(log_file, "");
  end // pass/fail check

  $fclose(log_file);
  $stop();

end

endmodule
