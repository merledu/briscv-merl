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
wire [LRU_MEM_WIDTH-1 : 0] c_order;
wire we0, we1;

dual_port_ram #(LRU_MEM_WIDTH, INDEX_BITS, INDEX_BITS, "NEW_DATA") 
    lru_bram (clock, we0, we1, data_in0, data_in1, address0, address1,
    data_out0, data_out1);
// Port 0 is used for writing. Port 1 is for reading.

generate
    for(i=0; i<WIDTH; i=i+1)begin : ASSIGNS
        assign init_data[i*log2(WIDTH) +: log2(WIDTH)] = i;
		assign w_order[i] = data_out0[i*log2(WIDTH) +: log2(WIDTH)];
    end
    for(i=0; i<WIDTH; i=i+1)begin:C_ORDER
        assign c_order[i*log2(WIDTH) +: log2(WIDTH)] = 
            access_valid ? (access == i) ? 0
            : (w_order[access] > w_order[i]) ? w_order[i] + 1
            : w_order[i] : 0;
    end
endgenerate

assign we1      = reset ? 1 : 0;
assign data_in1 = reset ? init_data : 0;
assign address1 = current_index;

assign we0      = access_valid ? 1 : 0;
assign data_in0 = c_order;
assign address0 = current_index;

generate
    for(i=0; i<WIDTH; i=i+1)begin:LUR
        assign lru[i] = w_order[i] == (WIDTH-1);
    end
endgenerate

endmodule
