`include "processor_specific_macros.h"

module slli_tb();

parameter CORE = 0;
parameter DATA_WIDTH = 32;
parameter INDEX_BITS = 6;
parameter OFFSET_BITS = 3;
parameter ADDRESS_BITS = 12;
parameter ZEROS4096 = "../software/applications/binaries/zeros4096.dat";
parameter ZEROS32 = "../software/applications/binaries/zeros32.dat";
parameter PROGRAM = "../software/applications/binaries/instruction_tests/slli.vmh";
parameter TEST_LENGTH = 100;
parameter TEST_NAME = "SLLI";
parameter LOG_FILE = "instruction_test_results.txt";

genvar i;
integer x;
integer log_file;

reg clock;
reg reset;
reg start;
reg [19:0] prog_address;
reg report; // performance reporting

wire [31:0] expected_reg_file [31:0];
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

assign expected_reg_file[0]  = 32'h00000000;
assign expected_reg_file[1]  = 32'h00000000;
assign expected_reg_file[2]  = 32'h00000000;
assign expected_reg_file[3]  = 32'h00000000;
assign expected_reg_file[4]  = 32'h00000000;
assign expected_reg_file[5]  = 32'h00000000;
assign expected_reg_file[6]  = 32'h00000000;
assign expected_reg_file[7]  = 32'h00000000;
assign expected_reg_file[8]  = 32'h00000000;
assign expected_reg_file[9]  = 32'h00000000;
assign expected_reg_file[10] = 32'h00000001; // a0
assign expected_reg_file[11] = 32'h00000003; // a1
assign expected_reg_file[12] = 32'h00001000; // a2
assign expected_reg_file[13] = 32'h7ffff000; // a3
assign expected_reg_file[14] = 32'h00002000; // a4
assign expected_reg_file[15] = 32'h00008000; // a5
assign expected_reg_file[16] = 32'hffffe000; // a6
assign expected_reg_file[17] = 32'hffff8000; // a7
assign expected_reg_file[18] = 32'h00000000;
assign expected_reg_file[19] = 32'h00000000;
assign expected_reg_file[20] = 32'h00000000;
assign expected_reg_file[21] = 32'h00000000;
assign expected_reg_file[22] = 32'h00000000;
assign expected_reg_file[23] = 32'h00000000;
assign expected_reg_file[24] = 32'h00000000;
assign expected_reg_file[25] = 32'h00000000;
assign expected_reg_file[26] = 32'h00000000;
assign expected_reg_file[27] = 32'h00000000;
assign expected_reg_file[28] = 32'h00000000;
assign expected_reg_file[29] = 32'h00000000;
assign expected_reg_file[30] = 32'h00000000;
assign expected_reg_file[31] = 32'h00000000;

generate
for(i=0; i<32; i=i+1) begin : match_loop
  assign reg_match[i] = expected_reg_file[i] == `REGISTER_FILE[i];
end
endgenerate

assign test_passed = &reg_match;

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
  #10//repeat (10) @ (posedge clock);

  #1
  reset = 0;
  start = 1;
  #1 //repeat (1) @ (posedge clock);

  start = 0;
  //repeat (1) @ (posedge clock);

  #TEST_LENGTH

  log_file = $fopen(LOG_FILE,"a+");
  if(!log_file) begin
    $display("Could not open log file... Exiting!");
    $finish();
  end

  if(test_passed) begin
    $display("%s: Test Passed!", TEST_NAME);
    $fdisplay(log_file, "%s: Test Passed!", TEST_NAME);
  end else begin
    $display("%s: Test Failed!", TEST_NAME);
    $display("Dumping expected and actual reg file states:");
    $display("Reg Index: Expected Value, Actual Value");

    $fdisplay(log_file, "%s: Test Failed!", TEST_NAME);
    $fdisplay(log_file, "Dumping expected and actual reg file states:");
    $fdisplay(log_file, "Reg Index: Expected Value, Actual Value");

    for( x=0; x<32; x=x+1) begin
      $display("%d: %h, %h", x, expected_reg_file[x], `REGISTER_FILE[x]);
      $fdisplay(log_file, "%d: %h, %h", x, expected_reg_file[x], `REGISTER_FILE[x]);
    end

    $display("");
    $fdisplay(log_file, "");

  end
  $fclose(log_file);
  $stop();

end

endmodule
