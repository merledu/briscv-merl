module fifo #(
parameter DATA_WIDTH = 8,
          DEPTH      = 8
)(
input clock, reset,
input read, write,
input [DATA_WIDTH-1 : 0] data_in,
output [DATA_WIDTH-1 : 0] data_out,
output empty, full
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

localparam ADDRESS_WIDTH = log2(DEPTH);

//local variables
integer i;

reg [DATA_WIDTH-1 : 0] ram [0 : DEPTH-1];
reg [ADDRESS_WIDTH-1 : 0] read_ptr, write_ptr;
reg read_ptr_bit, write_ptr_bit;

always @(posedge clock)begin : READ_PTR
    if(reset)begin
        read_ptr     <= 0;
        read_ptr_bit <= 0;
    end
    else begin
        if(read)begin
            if(read_ptr == DEPTH-1)begin
                read_ptr     <= 0;
                read_ptr_bit <= ~read_ptr_bit;
            end
            else
                read_ptr     <= read_ptr + 1;
        end
    end
end

always @(posedge clock)begin : WRITE_PTR
    if(reset)begin
        write_ptr     <= 0;
        write_ptr_bit <= 0;
    end
    else begin
        if(write)begin
            if(write_ptr == DEPTH-1)begin
                write_ptr     <= 0;
                write_ptr_bit <= ~write_ptr_bit;
            end
            else
                write_ptr     <= write_ptr + 1;
        end
    end
end

always @(posedge clock)begin
    if(reset)
        for(i=0; i<DEPTH; i=i+1)begin
            ram[i]         <= 0;
        end
    if(write)
        ram[write_ptr] <= data_in;
end

assign empty = read_ptr == write_ptr & read_ptr_bit == write_ptr_bit;
assign full  = read_ptr == write_ptr & read_ptr_bit != write_ptr_bit;
assign data_out = (reset | empty) ? 0 : ram[read_ptr];

endmodule
