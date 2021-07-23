/******************************************************************************
* Module: main_memory
* Description: Main memory module capable of serving arbitrary number of
* caches/network interfaces with round robin arbitration.
*******************************************************************************/

module main_memory #(
parameter DATA_WIDTH    = 32,
          ADDRESS_WIDTH = 32,
          MSG_BITS      = 3,
          INDEX_BITS    = 15,   //1Mb memory (FMax=243.9MHz)
          NUM_PORTS     = 2,
          INIT_FILE     = "./memory.mem"
)(
clock, reset,
msg_in,
address,
data_in,
msg_out,
address_out,
data_out
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
input [NUM_PORTS*MSG_BITS-1 : 0] msg_in;
input [NUM_PORTS*ADDRESS_WIDTH-1 : 0]address;
input [NUM_PORTS*DATA_WIDTH-1 : 0]data_in;
output [NUM_PORTS*MSG_BITS-1 : 0] msg_out;
output [NUM_PORTS*ADDRESS_WIDTH-1 : 0] address_out;
output [NUM_PORTS*DATA_WIDTH-1 : 0] data_out;

localparam MEM_DEPTH = 1 << INDEX_BITS;
localparam IDLE     = 0,
           SERVING  = 1,
           READ_OUT = 2;

`include "./params.v"

genvar i;
integer j;

reg [1:0] state;
reg [log2(NUM_PORTS)-1 : 0] serving;
reg [MSG_BITS-1 : 0] t_msg_out [NUM_PORTS-1 : 0];
reg [ADDRESS_WIDTH-1 : 0] t_address_out [NUM_PORTS-1 : 0];
reg [MSG_BITS-1 : 0] t_msg;
reg [ADDRESS_WIDTH-1 : 0] t_address;
reg [DATA_WIDTH-1 : 0] t_data;

wire [NUM_PORTS-1 : 0] requests;
wire [log2(NUM_PORTS)-1 : 0] serv_next;
wire [MSG_BITS-1 : 0] w_msg_in [NUM_PORTS-1 : 0];
wire [ADDRESS_WIDTH-1 : 0] w_address_in [NUM_PORTS-1 : 0];
wire [DATA_WIDTH-1 : 0] w_data_in [NUM_PORTS-1 : 0];
wire [DATA_WIDTH-1 : 0] w_data_out [NUM_PORTS-1 : 0];
wire we0, we1;
wire [DATA_WIDTH-1 : 0] data_in0, data_in1;
wire [ADDRESS_WIDTH-1 : 0] address0, address1;
wire [DATA_WIDTH-1 : 0] data_out0, data_out1;

generate
    for(i=0;i<NUM_PORTS; i=i+1)begin : SPLIT_INPUTS
        assign w_msg_in[i]     = msg_in[i*MSG_BITS +: MSG_BITS];
        assign w_data_in[i]    = data_in[i*DATA_WIDTH +: DATA_WIDTH];
        assign w_address_in[i] = address[i*ADDRESS_WIDTH +: ADDRESS_WIDTH];
        assign requests[i]     = (w_msg_in[i] == R_REQ) | (w_msg_in[i] == WB_REQ); 
    end
endgenerate

assign address0 = (state == SERVING) ? t_address : 0;
assign address1 = 0;
assign data_in0 = (state == SERVING) ? t_data : 0;
assign data_in1 = 0;
assign we0      = (state == SERVING) & (t_msg == WB_REQ);
assign we1      = 0;

// Instantiate round-robin arbitrator
arbiter #(NUM_PORTS) arbitrtor_1 (clock, reset, requests, serv_next);

// Instantiate BRAM
bram #(DATA_WIDTH, ADDRESS_WIDTH, MEM_DEPTH, INIT_FILE) BRAM (clock, we0, we1,
    data_in0, data_in1, address0, address1, data_out0, data_out1);

// controller FSM
always @(posedge clock)begin
    if(reset)begin
        for(j=0; j<NUM_PORTS; j=j+1)begin
            t_msg_out[j]     <= MEM_NO_MSG;
            t_address_out[j] <= 0;
        end
        state <= IDLE;
    end
    else begin
        case(state)
            IDLE:begin
                if(|requests)begin
                    t_msg     <= w_msg_in[serv_next];
                    t_address <= w_address_in[serv_next];
                    t_data    <= w_data_in[serv_next];
                    serving   <= serv_next;
                    if(w_msg_in[serv_next] == WB_REQ)begin
                        t_msg_out[serving]     <= MEM_READY;
                        t_address_out[serving] <= w_address_in[serv_next];
                    end
                    state     <= SERVING;
                end
                else
                    state <= IDLE;
            end
            SERVING:begin
                if(t_msg == R_REQ)begin
                    t_msg_out[serving] <= MEM_SENT;
                    state              <= READ_OUT;
                end
                else if(t_msg == WB_REQ)begin
                    t_msg_out[serving] <= MEM_NO_MSG;
                    state              <= IDLE;
                end 
            end
            READ_OUT:begin
                t_msg_out[serving] <= MEM_NO_MSG;
                state <= IDLE;
            end
            default: state <= IDLE;
        endcase
    end
end

// Drive outputs
generate
    for(i=0; i<NUM_PORTS; i=i+1)begin : OUTPUTS
        assign w_data_out[i]  = (i==serving) & (state==READ_OUT) ? data_out0 : 0;
        assign msg_out[i*MSG_BITS +: MSG_BITS ]              = t_msg_out[i];
        assign address_out[i*ADDRESS_WIDTH +: ADDRESS_WIDTH] = t_address_out[i];
        assign data_out[i*DATA_WIDTH +: DATA_WIDTH]          = w_data_out[i];
    end
endgenerate

endmodule
