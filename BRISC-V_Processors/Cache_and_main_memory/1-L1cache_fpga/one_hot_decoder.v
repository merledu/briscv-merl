/******************************************************************************
* Parameterized one hot decoder
*	Accepts an array 'encoded' of size WIDTH, which is one hot encoded
*	sets:
*	1) output decoded to binary value corresponding to one hot encoded input
*	2) valid if at least one input bit is high
******************************************************************************/

module one_hot_decoder #(
parameter WIDTH = 16
) (
encoded,
decoded,
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

input [WIDTH-1 : 0] encoded;
output [log2(WIDTH)-1 : 0] decoded;
output valid;

generate
	wire decoded_half_valid;
	wire top_half_has_one;

	if (WIDTH==2)begin
		assign valid = encoded[1] | encoded [0];
		assign decoded = encoded[1];
	end
	else begin
		assign top_half_has_one = |encoded[WIDTH-1 : WIDTH/2];
		assign decoded[log2(WIDTH)-1] = top_half_has_one;
		assign valid = top_half_has_one | decoded_half_valid;

		one_hot_decoder #(WIDTH/2) decode_half (.encoded(top_half_has_one ? encoded[WIDTH-1 : WIDTH/2] : encoded[(WIDTH/2)-1 : 0]),
							.decoded(decoded[log2(WIDTH)-2 : 0]),
							.valid(decoded_half_valid)	);
	end
endgenerate


endmodule
