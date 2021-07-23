/******************************************************************************
* Finds the lowest bit in the input array which is zero.
* valid - At least one bit is zero
******************************************************************************/

module empty_way_select #(
parameter NUMBER_OF_WAYS = 4
) (
ways_in_use,
next_empty_way,
valid
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

input [NUMBER_OF_WAYS-1:0] ways_in_use;
output [NUMBER_OF_WAYS-1:0] next_empty_way;
output valid;

wire [NUMBER_OF_WAYS-1:0] invert, plusone;

assign invert = ~ways_in_use;
assign plusone = ways_in_use + 1;
assign next_empty_way = invert & plusone;
assign valid = |invert;

endmodule
