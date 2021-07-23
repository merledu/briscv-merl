/******************************************************************************
* Module: main_memory_interface
* Description: Interfaces the Last level cache to the main memory and network
* interface. Main memory bandwidth is assumed to be one data word while the
* cache line is multiple words. This module receives the requests from last
* level cache, serializes the access and sends to main memory/network
* interface. After receiveing all the responses, it concatenates the responses
* to fit the cache line size and signals the LLC.
******************************************************************************/
module main_memory_interface #(
parameter STATUS_BITS           = 3,	// Valid bit + Dirty bit + inclusion bit
	      COHERENCE_BITS        = 2,
	      OFFSET_BITS           = 2,
	      DATA_WIDTH            = 8,
          ADDRESS_WIDTH         = 12,
	      MSG_BITS              = 3
)(
clock, reset,

cache2interface_msg,
cache2interface_address,
cache2interface_data,

interface2cache_msg,
interface2cache_address,
interface2cache_data,

network2interface_msg,
network2interface_address,
network2interface_data,

interface2network_msg,
interface2network_address,
interface2network_data,

mem2interface_msg,
mem2interface_address,
mem2interface_data,

interface2mem_msg,
interface2mem_address,
interface2mem_data
);

localparam WORDS_PER_LINE = 1 << OFFSET_BITS;
localparam BUS_WIDTH = STATUS_BITS + COHERENCE_BITS + DATA_WIDTH*WORDS_PER_LINE;
localparam IDLE          = 0,
           READ_MEMORY   = 1,
           WRITE_MEMORY  = 2,
           RESPOND       = 3;

//`include "./params.v"
// memory to cache messages
localparam MEM_NO_MSG = 0,
	       MEM_READY  = 1,
	       MEM_SENT   = 2,
	       REQ_FLUSH  = 3,
	       M_RECV     = 4;

// cache to memory messages
localparam NO_REQ     = 0,
           WB_REQ     = 1,
           R_REQ      = 2,
	       FLUSH      = 3,
	       NO_FLUSH   = 4,
	       INVLD      = 5,
	       WS_BCAST   = 6,
           RFO_BCAST  = 7;	//TODO// change READ_ST state of L1 to support this.

// L1 cache to coherence controller messages
localparam C_NO_RESP   = 0,
	       C_WB        = 1,
	       C_EN_ACCESS = 2,
           C_FLUSH     = 3,
           C_INVLD     = 5; //to match cache messages

// coherence controller to cache messages
localparam C_NO_REQ      = 0,
	       C_RD_BCAST    = 1,
	       ENABLE_WS     = 2,	//TODO// change CACHE_ACCESS state of L1 to wait for this signal on write hit for a shared line.
           C_FLUSH_BCAST = 3,
	       C_INVLD_BCAST = 4,
	       C_WS_BCAST    = 5,
	       C_RFO_BCAST   = 6;
// coherence states
localparam INVALID   = 2'b00,
           EXCLUSIVE = 2'b01,
           SHARED    = 2'b11,
           MODIFIED  = 2'b10;

input clock, reset;
input [MSG_BITS-1 : 0] cache2interface_msg;
input [ADDRESS_WIDTH-1 : 0] cache2interface_address;
input [BUS_WIDTH-1 : 0] cache2interface_data;

output [MSG_BITS-1 : 0] interface2cache_msg;
output [ADDRESS_WIDTH-1 : 0] interface2cache_address;
output [BUS_WIDTH-1 : 0] interface2cache_data;

input [MSG_BITS-1 : 0] network2interface_msg;
input [ADDRESS_WIDTH-1 : 0] network2interface_address;
input [DATA_WIDTH-1 : 0] network2interface_data;

output [MSG_BITS-1 : 0] interface2network_msg;
output [ADDRESS_WIDTH-1 : 0] interface2network_address;
output [DATA_WIDTH-1 : 0] interface2network_data;

input [MSG_BITS-1 : 0] mem2interface_msg;
input [ADDRESS_WIDTH-1 : 0] mem2interface_address;
input [DATA_WIDTH-1 : 0] mem2interface_data;

output [MSG_BITS-1 : 0] interface2mem_msg;
output [ADDRESS_WIDTH-1 : 0] interface2mem_address;
output [DATA_WIDTH-1 : 0] interface2mem_data;


genvar i;
integer j;
reg [2:0] state;
reg [DATA_WIDTH-1 : 0] t_intf2cache_data [WORDS_PER_LINE-1 : 0];
reg [MSG_BITS-1 : 0] t_intf2cache_msg;
reg [ADDRESS_WIDTH-1 : 0] t_intf2cache_address;
reg [DATA_WIDTH-1 : 0] from_intf_data;
reg [MSG_BITS-1 : 0] from_intf_msg;
reg [ADDRESS_WIDTH-1 : 0] from_intf_address;
reg [OFFSET_BITS : 0] word_counter;

wire local_address = 1; //temporary value. Update logic for this to support a
                        //distributed memory system.
wire [DATA_WIDTH-1 : 0] w_cache2intf_data [WORDS_PER_LINE-1 : 0];
wire line_valid, line_dirty;
wire [MSG_BITS-1 : 0] to_intf_msg;
wire [ADDRESS_WIDTH-1 : 0] to_intf_address;
wire [DATA_WIDTH-1 : 0] to_intf_data;



generate
    for(i=0; i<WORDS_PER_LINE; i=i+1)begin : SPLIT_INPUTS
        assign w_cache2intf_data[i] = cache2interface_data[i*DATA_WIDTH +: DATA_WIDTH];
    end
endgenerate

assign line_valid = cache2interface_data[BUS_WIDTH-1];
assign line_dirty = cache2interface_data[BUS_WIDTH-2];
assign to_intf_msg = local_address ? mem2interface_msg : network2interface_msg;
assign to_intf_address = local_address ? mem2interface_address : network2interface_address;
assign to_intf_data = local_address ? mem2interface_data : network2interface_data;

//assign outputs
assign interface2cache_msg = t_intf2cache_msg;
assign interface2cache_address = t_intf2cache_address;
generate
    for(i=0; i<WORDS_PER_LINE; i=i+1)begin
        assign interface2cache_data[i*DATA_WIDTH +: DATA_WIDTH] = t_intf2cache_data[i];
    end
endgenerate
assign interface2cache_data[BUS_WIDTH-1 -: (STATUS_BITS+COHERENCE_BITS)] =
            {1'b1, {(STATUS_BITS-1){1'b0}}, {COHERENCE_BITS{1'b0}}};

assign interface2network_msg = local_address ? 0 : from_intf_msg;
assign interface2network_address = local_address? 0 : from_intf_address;
assign interface2network_data = local_address ? 0 : from_intf_data;

assign interface2mem_msg = local_address ? from_intf_msg : 0;
assign interface2mem_address = local_address ? from_intf_address : 0;
assign interface2mem_data = local_address ? from_intf_data : 0;


always @(posedge clock)begin
    if(reset)begin
        t_intf2cache_msg     <= MEM_NO_MSG;
        t_intf2cache_address <= 0;
        from_intf_msg        <= NO_REQ;
        from_intf_address    <= 0;
        from_intf_data       <= 0;
        for(j=0; j<WORDS_PER_LINE; j=j+1)begin
            t_intf2cache_data[j] <= 0;
        end
        state <= IDLE;
    end
    else begin
        case(state)
            IDLE:begin
                if(cache2interface_msg == R_REQ)begin
                    word_counter         <= 0;
                    from_intf_msg        <= R_REQ;
                    from_intf_address    <= cache2interface_address;
                    t_intf2cache_address <= cache2interface_address;
                    state                <= READ_MEMORY;
                end
                else if(((cache2interface_msg == FLUSH | cache2interface_msg == INVLD)
                    & line_dirty) | cache2interface_msg == WB_REQ)begin
                    word_counter         <= 0;
                    from_intf_msg        <= WB_REQ;
                    from_intf_address    <= cache2interface_address;
                    from_intf_data       <= w_cache2intf_data[0];
                    t_intf2cache_address <= cache2interface_address;
                    state                <= WRITE_MEMORY;
                end
                else
                    state <= IDLE;
            end
            READ_MEMORY:begin
                if((to_intf_msg == MEM_SENT) & (word_counter < WORDS_PER_LINE-1))begin
                    t_intf2cache_data[word_counter] <= to_intf_data;
                    word_counter                    <= word_counter + 1;
                    from_intf_address               <= from_intf_address + 1; 
                    from_intf_msg                   <= R_REQ;
                end
                else if((to_intf_msg == MEM_SENT) &
                (word_counter == WORDS_PER_LINE-1))begin
                    t_intf2cache_data[word_counter] <= to_intf_data;
                    from_intf_address               <= 0; 
                    from_intf_msg                   <= NO_REQ;
                    t_intf2cache_msg                <= MEM_SENT;
                    state                           <= RESPOND;
                end
                else
                    state <= READ_MEMORY;
            end
            WRITE_MEMORY:begin
                if((to_intf_msg == MEM_READY) & (word_counter < WORDS_PER_LINE-1))begin
                    from_intf_data    <= w_cache2intf_data[word_counter + 1];
                    word_counter      <= word_counter + 1;
                    from_intf_address <= from_intf_address + 1; 
                    from_intf_msg     <= WB_REQ;
                end
                else if((to_intf_msg == MEM_READY) &
                (word_counter == WORDS_PER_LINE-1))begin
                    from_intf_data    <= 0;
                    from_intf_address <= 0; 
                    from_intf_msg     <= NO_REQ;
                    t_intf2cache_msg  <= (cache2interface_msg == FLUSH |
                                         cache2interface_msg == INVLD) ? M_RECV
                                       : MEM_READY;
                    state             <= RESPOND;
                end
                else
                    state <= WRITE_MEMORY;
            end
            RESPOND:begin
                t_intf2cache_address <= 0;
                t_intf2cache_msg     <= MEM_NO_MSG;
                state                <= IDLE;
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule
