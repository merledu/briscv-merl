/******************************************************************************
* Parameterized priority encoder
* Finds the index of the MSB/LSB bit set to high
* Accepts an array decode of size WIDTH (WIDTH is a power of 2),
* and sets:
*    (1) encode to the index of the highest/lowest bit which is set to high.
*    (2) valid to 1 if there is at least one bit high.
******************************************************************************/

module priority_encoder #(
parameter 	WIDTH = 8,
		PRIORITY = "MSB"
) (
decode,
encode,
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

input [WIDTH-1 : 0] decode;
output [log2(WIDTH)-1 : 0] encode;
output valid;

generate
	wire encoded_half_valid;
	wire half_has_one;

	if (WIDTH==2)begin
		assign valid = decode[1] | decode [0];
		assign encode = ((PRIORITY == "LSB") & decode[0]) ? 0 : decode[1];
	end
	else begin
		assign half_has_one = (PRIORITY == "LSB") ? |decode[(WIDTH/2)-1 : 0] : | decode[WIDTH-1 : WIDTH/2];
		assign encode[log2(WIDTH)-1] = ((PRIORITY == "MSB") & half_has_one) ? 1 
						: ((PRIORITY == "LSB") & ~half_has_one & valid) ? 1
						: 0;
		assign valid = half_has_one | encoded_half_valid;

		if(PRIORITY == "MSB")
		priority_encoder #((WIDTH/2), PRIORITY) decode_half (.decode(half_has_one ? decode[WIDTH-1 : WIDTH/2] : decode[(WIDTH/2)-1 : 0]),
							.encode(encode[log2(WIDTH)-2 : 0]),
							.valid(encoded_half_valid)	);

		else
		priority_encoder #((WIDTH/2), PRIORITY) decode_half (.decode(half_has_one ? decode[(WIDTH/2)-1 : 0] : decode[WIDTH-1 : WIDTH/2]),
							.encode(encode[log2(WIDTH)-2 : 0]),
							.valid(encoded_half_valid)	);
	end
endgenerate


endmodule
