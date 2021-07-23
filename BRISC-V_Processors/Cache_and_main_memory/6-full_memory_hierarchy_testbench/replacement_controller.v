module replacement_controller #(
parameter NUMBER_OF_WAYS = 8
) (
clock, reset,
ways_in_use,
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
input replacement_policy_select;	/* 1-LRU  0-Random */
input [NUMBER_OF_WAYS-1:0] current_access;	// One hot encoded signal
input access_valid;
input report;
output [NUMBER_OF_WAYS-1:0] selected_way;

wire [NUMBER_OF_WAYS-1:0] lru_way, random_way, next_empty_way;
wire [log2(NUMBER_OF_WAYS)-1 : 0] current_access_binary;
wire valid_decode, valid_empty_way;

// decode current access to binary
one_hot_decoder #(NUMBER_OF_WAYS) decode_curr_access (.encoded(current_access), .decoded(current_access_binary), .valid(valid_decode));

// Instantiate LRU
LRU #(NUMBER_OF_WAYS) lru_inst (clock, reset, current_access_binary, (access_valid & valid_decode), lru_way);

// Instantiate empty way select module
empty_way_select #(NUMBER_OF_WAYS) empty_way_sel_inst (ways_in_use, next_empty_way, valid_empty_way);

assign selected_way = valid_empty_way ? next_empty_way : (replacement_policy_select)? lru_way : random_way;



// Performance data
reg [31 : 0] cycles;

always @ (posedge clock) begin
        if (reset) begin
                cycles           <= 0;
        end
        else begin
                cycles           <= cycles + 1;
                if (report) begin
                        $display ("-------------------------- Replacement controller: ----------------------------");
                        $display ("LRU selection [%b]\t| Empty way selection [%b]\t| valid empty way [%b]\t| Replacement selection [%b]", 
								lru_way,
								next_empty_way,
								valid_empty_way,
								selected_way
				 );
                        $display ("-------------------------------------------------------------------------------");
                end
        end
end



endmodule
