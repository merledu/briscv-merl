/*****************************************
* Module: dual_port_RAM
* Author: Sahan Bandara
* Not Byte addressable
*****************************************/

module dual_port_ram
#(
parameter
DATA_WIDTH    = 32,
ADDRESS_WIDTH = 32,
INDEX_BITS    = 6,
CROSS_PORT    = "OLD_DATA"
)
(
input clock,
input we0, we1,
input [DATA_WIDTH-1:0] data_in0, 
input [DATA_WIDTH-1:0] data_in1, 
input [ADDRESS_WIDTH-1:0] address0,
input [ADDRESS_WIDTH-1:0] address1,
output [DATA_WIDTH-1:0] data_out0,
output [DATA_WIDTH-1:0] data_out1
);
	
localparam RAM_DEPTH = 1 << INDEX_BITS;

reg [DATA_WIDTH-1:0] mem [0:RAM_DEPTH-1];

reg [DATA_WIDTH-1:0] data_reg0;
reg [DATA_WIDTH-1:0] data_reg1;

// port A
always@(posedge clock)
begin
	if(we0) begin
		mem[address0] <= data_in0;
		data_reg0     <= data_in0;
	end
    else
        data_reg0 <= mem[address0];
end



// port B
always@(posedge clock)
begin
	if(we1) begin
		mem[address1] <= data_in1;
		data_reg1     <= data_in1;
	end
    else
        data_reg1 <= mem[address1];
end

assign data_out0 = (we1 & (address0 == address1) & (CROSS_PORT == "NEW_DATA")) ?
                   data_reg1 : data_reg0;
assign data_out1 = (we0 & (address0 == address1) & (CROSS_PORT == "NEW_DATA")) ?
                   data_reg0 : data_reg1;

endmodule
