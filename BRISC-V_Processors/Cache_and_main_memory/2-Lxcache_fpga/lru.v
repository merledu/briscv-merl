// LRU module accepts the clock and reset, along with:
//      access       - specifying which way is getting accessed 
//      access_valid - high when a way is getting accessed
//
// The module outputs a one-hot array 'lru', where 1 means that this way is the least recently used.

module LRU #( 
    parameter WIDTH      = 4,
			  INDEX_BITS = 8
) (
    input clock,
    input reset,
	input [INDEX_BITS-1 : 0] current_index,
    input [log2(WIDTH)-1:0] access,
    input access_valid,
    output [WIDTH-1:0] lru
);
    
    //define the log2 function
    function integer log2;
      input integer num;
      integer i, result;
      begin
          for (i = 0; 2 ** i < num; i = i + 1)
              result = i + 1;
          log2 = result;
      end
    endfunction
	
localparam CACHE_DEPTH = 1 << INDEX_BITS;
localparam LRU_MEM_WIDTH = log2(WIDTH)*WIDTH;

genvar i;
integer j;

wire [LRU_MEM_WIDTH-1 : 0] data_in0, data_in1, data_out0, data_out1, init_data;
wire [INDEX_BITS-1 : 0] address0, address1;
wire [log2(WIDTH)-1:0] w_order [WIDTH-1 : 0];
wire [LRU_MEM_WIDTH-1:0] c_order;
wire we0, we1;

reg state;
reg [INDEX_BITS-1 : 0] valid_index;
reg [LRU_MEM_WIDTH-1 : 0] updated_order;
reg [log2(WIDTH)-1:0] order [WIDTH-1 : 0];

dual_port_ram #(LRU_MEM_WIDTH, INDEX_BITS, INDEX_BITS, "OLD_DATA") 
    lru_bram (clock, we0, we1, data_in0, data_in1, address0, address1,
    data_out0, data_out1);

assign we0      = reset ? 1 : 0;
assign data_in0 = reset ? {init_data} : 0;
assign address0 = current_index;
assign we1      = state ? 1 : 0;
assign data_in1 = state ? c_order : 0;
assign address1 = state ? valid_index : 0;

generate
    for(i=0; i<WIDTH; i=i+1)begin : ASSIGNS
        assign init_data[i*log2(WIDTH) +: log2(WIDTH)] = i;
		assign w_order[i]     = data_out0[i*log2(WIDTH) +: log2(WIDTH)];
		assign c_order[i*log2(WIDTH) +: log2(WIDTH)] = order[i];
    end
endgenerate

always @(posedge clock)begin
	if(reset)begin
		valid_index <= 0;
		state       <= 0;
	end
	else if(access_valid)begin
		valid_index <= current_index;
		state       <= 1;
	end
	else
		state <= 0;
end

always @(posedge clock)begin
	if(reset)begin
		for(j=0; j<WIDTH; j=j+1)begin
			order[j] <= j;
		end
	end
	else begin
		for(j=0; j<WIDTH; j=j+1)begin
			if(access_valid)begin
				if(access == j)
					order[j] <= 0;
				else if(w_order[access] > w_order[j])
					order[j] <= w_order[j] + 1;
				else
					order[j] <= w_order[j];
			end
		end
	end
end

generate
	for(i=0; i<WIDTH; i=i+1)begin : LRU
		assign lru[i] = w_order[i] == (WIDTH - 1);
	end
endgenerate

endmodule
