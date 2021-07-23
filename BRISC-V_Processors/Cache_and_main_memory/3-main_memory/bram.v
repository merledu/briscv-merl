module bram #(
parameter DATA_WIDTH = 32,
          ADDR_WIDTH = 32,
	      DEPTH      = 6,
          INIT_FILE  = "./memory.mem"
)(
input clock, 
input we0, we1,
input [DATA_WIDTH-1 : 0] data_in0, data_in1,
input [ADDR_WIDTH-1 : 0] address0, address1,
output [DATA_WIDTH-1 : 0] data_out0, data_out1
);

reg [DATA_WIDTH-1 : 0] data_reg0, data_reg1;

//(* ramstyle = "M4K,no_rw_check" *) reg [DATA_WIDTH-1 : 0] mem [0 : DEPTH-1];
reg [DATA_WIDTH-1 : 0] mem [0 : DEPTH-1];

initial begin
    $readmemh(INIT_FILE, mem);
end

always @(posedge clock)begin
	if(we0)
		mem[address0] <= data_in0;
	data_reg0 <= mem[address0];	
end
always @(posedge clock)begin
	if(we1)
		mem[address1] <= data_in1;
	data_reg1 <= mem[address1];	
end

assign data_out0 = data_reg0;
assign data_out1 = data_reg1;

endmodule
