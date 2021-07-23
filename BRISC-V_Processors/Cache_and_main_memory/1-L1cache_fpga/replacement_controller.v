module replacement_controller #(
parameter NUMBER_OF_WAYS = 8,
          INDEX_BITS     = 8
) (
clock, reset,
ways_in_use,
current_index,
replacement_policy_select,
current_access, access_valid,
report,
selected_way
);

//Define the log2 function
function integer log2;
   input integer num;
   integer i, result;
   begin
       for (i = 0; 2 ** i < num; i = i + 1)
           result = i + 1;
       log2 = result;
   end
endfunction

input clock, reset;
input [NUMBER_OF_WAYS-1:0] ways_in_use;
input [INDEX_BITS-1 : 0] current_index;
input replacement_policy_select;	/* 1-LRU  0-Random */
input [log2(NUMBER_OF_WAYS)-1:0] current_access;
//input [NUMBER_OF_WAYS-1:0] current_access;	// One hot encoded signal
input access_valid;
input report;
output [NUMBER_OF_WAYS-1:0] selected_way;

wire [NUMBER_OF_WAYS-1:0] lru_way, random_way, next_empty_way;
wire [log2(NUMBER_OF_WAYS)-1 : 0] current_access_binary;
wire valid_decode, valid_empty_way;

// Instantiate LRU
LRU #(NUMBER_OF_WAYS, INDEX_BITS) 
	lru_inst (clock, reset, current_index, current_access, 
	access_valid, lru_way);

// Instantiate empty way select module
empty_way_select #(NUMBER_OF_WAYS) empty_way_sel_inst (ways_in_use, next_empty_way, valid_empty_way);

assign random_way = 0; //temporary assignment

assign selected_way = valid_empty_way ? next_empty_way : (replacement_policy_select)? lru_way : random_way;

endmodule
