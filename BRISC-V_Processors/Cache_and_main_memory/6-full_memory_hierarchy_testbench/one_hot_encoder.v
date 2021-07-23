/******************************************************************************
* Parameterized one hot encoder.
******************************************************************************/ 

module one_hot_encoder #(
parameter WIDTH = 8	// Width of the encoded output
) (
decode, encode
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

input [log2(WIDTH)-1 : 0] decode;
output [WIDTH-1 : 0] encode;

genvar i;

generate
	for(i=0; i<WIDTH; i=i+1)begin : ENCODED_BITS
		assign encode[i] = (decode == i)? 1'b1 : 1'b0;
	end
endgenerate

endmodule
