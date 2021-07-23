module arbiter #(
parameter WIDTH = 4
) (
clock, reset,
requests,
grant
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
input [WIDTH-1 : 0] requests;
output [log2(WIDTH)-1 : 0] grant;

integer j;
reg [WIDTH-1 : 0] mask;
wire [WIDTH-1 : 0] masked_requests;
wire masked_valid, unmasked_valid;
wire [log2(WIDTH)-1 : 0] masked_encoded, unmasked_encoded;


// Instantiate two priority encoders
priority_encoder #(WIDTH, "LSB") masked_encoder(masked_requests, masked_encoded, masked_valid);
priority_encoder #(WIDTH, "LSB") unmasked_encoder(requests, unmasked_encoded, unmasked_valid);

always @(posedge clock)begin
	if(reset)
		mask       <= {WIDTH{1'b1}};
	else begin
		for(j=0; j<WIDTH; j=j+1)begin
			mask[j] <= (j < grant) ? 0 : 1;
		end
	end
end

assign masked_requests = requests & mask;
assign grant = (masked_requests == 0) ? unmasked_encoded : masked_encoded;

endmodule
