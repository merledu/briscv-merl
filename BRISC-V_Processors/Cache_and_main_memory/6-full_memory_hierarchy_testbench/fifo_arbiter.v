module fifo_arbiter #(
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

integer i;
reg [WIDTH-1 : 0] mask;

wire [WIDTH-1 : 0] diff;
wire [log2(WIDTH)-1 : 0] encoded_diff;
wire valid_diff;
wire read_fifo, write_fifo, fifo_empty, fifo_full;
wire [log2(WIDTH)-1 : 0] fifo_in, fifo_out;

// Instantiate one hot decoder
priority_encoder #(WIDTH, "LSB") encode_diff (diff, encoded_diff, valid_diff);

//Instantiate FIFO buffer
fifo #(log2(WIDTH), WIDTH) fifo_buffer (clock, reset, read_fifo, write_fifo,
                           fifo_in, fifo_out, fifo_empty, fifo_full);

always @(posedge clock)begin
    if(reset)
        mask <= 0;
    else if(valid_diff)begin
        if(requests[encoded_diff])
            mask[encoded_diff] <= 1;
        else
            mask[encoded_diff] <= 0;
    end
    else
        for(i=0; i<WIDTH; i=i+1)begin
            if(i != grant & requests[i] == 0)
                mask[i] <= 0;
        end
end

assign diff = mask ^ requests;
assign read_fifo  = ~reset & ~fifo_empty & (valid_diff & (requests[grant] == 0) & (mask[grant] == 1) | ~valid_diff & (requests[grant] == 0));
assign write_fifo = ~reset & valid_diff & requests[encoded_diff];
assign fifo_in    = encoded_diff;
assign grant      = fifo_out;

endmodule
