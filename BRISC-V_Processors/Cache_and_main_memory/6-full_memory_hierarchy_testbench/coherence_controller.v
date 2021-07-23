/******************************************************************************
* Module: coherence controller
******************************************************************************/

module coherence_controller #(
parameter STATUS_BITS    = 2,
          COHERENCE_BITS = 2,
          OFFSET_BITS    = 2,
          DATA_WIDTH     = 8,
	      ADDRESS_WIDTH  = 12,
	      MSG_BITS       = 3,
	      NUM_CACHES     = 4
)(
clock, reset,
// main bus
cache2mem_data_in,
cache2mem_address_in,
cache2mem_msg_in,
cache2mem_data_out,
cache2mem_address_out,
cache2mem_msg_out,
mem2cache_msgs,
// coherence bus
coherence_msg_in,
coherence_data_in,
coherence_msg_out,
coherence_address
);

//Define the log2 function
function integer log2;
   input integer num;
   integer i, result;
   begin
       for(i = 0; 2 ** i < num; i = i + 1)
           result = i + 1;
       log2 = result;
   end
endfunction

// Local parameters //
localparam WORDS_PER_LINE = 1 << OFFSET_BITS;
localparam BUS_WIDTH = STATUS_BITS + COHERENCE_BITS + (DATA_WIDTH * WORDS_PER_LINE);

// states
localparam IDLE            = 0,
	       WAIT_EN         = 1,
	       COHERENCE_WB    = 2,
	       GRANT_ACCESS    = 3,
	       WAIT_CUR_ACCESS = 4,
	       COHERENCE_FLUSH = 5,
	       COHERENCE_INVLD = 6,
	       WRITE_SHARED    = 7;

`include "./params.v"
//`include "/home/sahanb/Documents/1-Projects/1-adaptive_cache/1-workspace/28-coherence/params.v"

input clock, reset;
input [(NUM_CACHES * BUS_WIDTH)-1 : 0] cache2mem_data_in;
input [(NUM_CACHES * ADDRESS_WIDTH)-1 : 0] cache2mem_address_in;
input [(NUM_CACHES * MSG_BITS)-1 : 0] cache2mem_msg_in;

output [(NUM_CACHES * BUS_WIDTH)-1 : 0] cache2mem_data_out;
output [(NUM_CACHES * ADDRESS_WIDTH)-1 : 0] cache2mem_address_out;
output [(NUM_CACHES * MSG_BITS)-1 : 0] cache2mem_msg_out;

input [(NUM_CACHES * MSG_BITS)-1 : 0] mem2cache_msgs;

input [(NUM_CACHES * MSG_BITS)-1 : 0] coherence_msg_in;
input [(NUM_CACHES * BUS_WIDTH)-1 : 0] coherence_data_in;
output [(NUM_CACHES * MSG_BITS)-1 : 0] coherence_msg_out;
output [ADDRESS_WIDTH-1 : 0] coherence_address;


genvar i;
integer j;
reg [3:0] state;

reg current_accesses [NUM_CACHES-1 : 0];
reg [MSG_BITS-1 : 0] pending_action;
reg [MSG_BITS-1 : 0] t_coherence_msg_out [NUM_CACHES-1 : 0];
reg [ADDRESS_WIDTH-1 : 0] t_coherence_address;


wire [NUM_CACHES-1 : 0] requests;
wire [MSG_BITS-1 : 0] w_msg_in [NUM_CACHES-1 : 0];
wire [BUS_WIDTH-1 : 0] w_data_in [NUM_CACHES-1 : 0];
wire [ADDRESS_WIDTH-1 : 0] w_address_in [NUM_CACHES-1 : 0];
wire [log2(NUM_CACHES)-1 : 0] serve_next;

wire [MSG_BITS-1 : 0]      w_msg_out [NUM_CACHES-1 : 0];
wire [BUS_WIDTH-1 : 0]     w_data_out [NUM_CACHES-1 : 0];
wire [ADDRESS_WIDTH-1 : 0] w_address_out [NUM_CACHES-1 : 0];

wire [MSG_BITS-1 : 0] w_mem2cache_msgs [NUM_CACHES-1 : 0];

wire [MSG_BITS-1 : 0] w_coherence_msg_in [NUM_CACHES-1 : 0];
wire [BUS_WIDTH-1 : 0] w_coherence_data_in [BUS_WIDTH-1 : 0];

wire [NUM_CACHES-1 : 0] tr_en_access, tr_coherence_wb, tr_coherence_flush, tr_coherence_invld;
wire [log2(NUM_CACHES)-1 : 0] coherence_wb_cache, coherence_flush_cache, coherence_invld_cache;
wire coherence_wb_valid, coherence_flush_valid, coherence_invld_valid;

generate
	for(i=0; i<NUM_CACHES; i=i+1)begin : INPUTS
		assign w_msg_in[i]         = cache2mem_msg_in  [i*MSG_BITS +: MSG_BITS];
		assign w_data_in[i]        = cache2mem_data_in  [i*BUS_WIDTH +: BUS_WIDTH];
		assign w_address_in[i]     = cache2mem_address_in  [i*ADDRESS_WIDTH +: ADDRESS_WIDTH];
		assign w_mem2cache_msgs[i] = mem2cache_msgs  [i*MSG_BITS +: MSG_BITS];
	end
endgenerate

generate
	for(i=0; i<NUM_CACHES; i=i+1)begin : REQUESTS
		assign requests[i] = (((w_msg_in[i] == R_REQ) | ((w_msg_in[i] == FLUSH) & (w_mem2cache_msgs[i] != REQ_FLUSH)) | 
			                 (w_msg_in[i] == INVLD) | (w_msg_in[i] == WS_BCAST) |
				             (w_msg_in[i] == RFO_BCAST)) & (w_msg_out[i] == NO_REQ))? 1 : 0;
	end
endgenerate

generate
	for(i=0; i<NUM_CACHES; i=i+1)begin : ASSIGN_OUTPUT
		assign cache2mem_msg_out[i*MSG_BITS +: MSG_BITS]               = w_msg_out[i];
		assign cache2mem_data_out[i*BUS_WIDTH +: BUS_WIDTH]            = w_data_out[i];
		assign cache2mem_address_out[i*ADDRESS_WIDTH +: ADDRESS_WIDTH] = w_address_out[i];
	end
endgenerate

generate
	for(i=0; i<NUM_CACHES; i=i+1)begin : INTERMEDIATE_OUTPUTS
		assign w_msg_out[i]     = (current_accesses[i]) ? 
			                      (((state == COHERENCE_WB) & (coherence_wb_cache == i)) |
					              ((state == COHERENCE_FLUSH) & (coherence_flush_cache == i)) |
					              ((state == COHERENCE_INVLD) & (coherence_invld_cache == i))) ?
					              w_coherence_msg_in[i] : w_msg_in[i] : NO_REQ;

		assign w_data_out[i]    = (current_accesses[i]) ? 
			                      (((state == COHERENCE_WB) & (coherence_wb_cache == i)) |
					              ((state == COHERENCE_FLUSH) & (coherence_flush_cache == i)) |
					              ((state == COHERENCE_INVLD) & (coherence_invld_cache == i))) ?
					              w_coherence_data_in[i] : w_data_in[i] : 0;

		assign w_address_out[i] = (current_accesses[i]) ? 
			                      (((state == COHERENCE_WB) & (coherence_wb_cache == i)) |
					              ((state == COHERENCE_FLUSH) & (coherence_flush_cache == i)) |
					              ((state == COHERENCE_INVLD) & (coherence_invld_cache == i))) ?
                        		  coherence_address : w_address_in[i] : 0;
	end
endgenerate

generate
	for(i=0; i<NUM_CACHES; i=i+1)begin : COHERENCE_INPUTS
		assign w_coherence_msg_in[i]  = coherence_msg_in[i*MSG_BITS +: MSG_BITS];
		assign w_coherence_data_in[i] = coherence_data_in[i*BUS_WIDTH +: BUS_WIDTH];
	end
endgenerate

generate
	for(i=0; i<NUM_CACHES; i=i+1)begin : COHERENCE_OUTPUTS
		assign coherence_msg_out[i*MSG_BITS +: MSG_BITS]  = t_coherence_msg_out[i];
	end
endgenerate

generate
	for(i=0; i<NUM_CACHES; i=i+1)begin : TRACK_C_MSGS
		assign tr_en_access[i]       = (serve_next == i) ? 1 
			                         : (w_coherence_msg_in[i] == C_EN_ACCESS) ? 1
                                     : (w_address_in[i] == coherence_address) & (w_msg_in[i] != w_msg_out[i]) ? 1
                                     : 0;
		assign tr_coherence_wb[i]    = (w_coherence_msg_in[i] == C_WB) ? 1 : 0;
		assign tr_coherence_flush[i] = (w_coherence_msg_in[i] == C_FLUSH) ? 1 : 0;
		assign tr_coherence_invld[i] = (w_coherence_msg_in[i] == C_INVLD) ? 1 : 0;
	end
endgenerate



assign coherence_address = t_coherence_address;


// Instantiate arbiter
fifo_arbiter #(NUM_CACHES) arbiter_2 (clock, reset, requests, serve_next);

// Instantiate one-hot-decoders
one_hot_decoder #(NUM_CACHES) coherence_wb_decode (tr_coherence_wb, coherence_wb_cache, coherence_wb_valid);
one_hot_decoder #(NUM_CACHES) coherence_flush_decode (tr_coherence_flush, coherence_flush_cache, coherence_flush_valid);
one_hot_decoder #(NUM_CACHES) coherence_invld_decode (tr_coherence_invld, coherence_invld_cache, coherence_invld_valid);


// control logic
always @(posedge clock)begin
	if(reset)begin
		t_coherence_address <= 0;
		for(j=0; j<NUM_CACHES; j=j+1)begin
			t_coherence_msg_out[j] <= C_NO_REQ;
		end
		pending_action <= NO_REQ;
		state          <= IDLE;
	end
	else begin
		case(state)
			IDLE:begin
				if(|requests & w_msg_out[serve_next] == NO_REQ)begin
					case(w_msg_in[serve_next])
						R_REQ:begin
							t_coherence_address <= w_address_in[serve_next];
							for(j=0; j<NUM_CACHES; j=j+1)begin
								if(j != serve_next)
									t_coherence_msg_out[j] <= C_RD_BCAST;
								else
									t_coherence_msg_out[j] <= C_NO_REQ;
							end
							state <= WAIT_EN;
						end
						FLUSH:begin
							t_coherence_address <= w_address_in[serve_next];
							pending_action      <= FLUSH;
							for(j=0; j<NUM_CACHES; j=j+1)begin
								if(j != serve_next)
									t_coherence_msg_out[j] <= C_FLUSH_BCAST;
								else
									t_coherence_msg_out[j] <= C_NO_REQ;
							end
							state <= WAIT_EN;
						end
						INVLD:begin
							t_coherence_address <= w_address_in[serve_next];
							for(j=0; j<NUM_CACHES; j=j+1)begin
								if(j != serve_next)
									t_coherence_msg_out[j] <= C_INVLD_BCAST;
								else
									t_coherence_msg_out[j] <= C_NO_REQ;
							end
							state <= WAIT_EN;
						end
						WS_BCAST:begin
							t_coherence_address <= w_address_in[serve_next];
							for(j=0; j<NUM_CACHES; j=j+1)begin
								if(j != serve_next)
									t_coherence_msg_out[j] <= C_WS_BCAST;
								else
									t_coherence_msg_out[j] <= C_NO_REQ;
							end
							state <= WAIT_EN;
						end
						RFO_BCAST:begin
							t_coherence_address <= w_address_in[serve_next];
							for(j=0; j<NUM_CACHES; j=j+1)begin
								if(j != serve_next)
									t_coherence_msg_out[j] <= C_RFO_BCAST; 
								else
									t_coherence_msg_out[j] <= C_NO_REQ;
							end
							state <= WAIT_EN;
						end
						default: state <= IDLE;
					endcase
				end
				else
					state <= IDLE;
			end
			WAIT_EN:begin
				if(coherence_wb_valid)begin
					if(w_msg_out[coherence_wb_cache] != NO_REQ)begin
						pending_action <= WB_REQ;
						state <= WAIT_CUR_ACCESS;
					end
					else
						state <= COHERENCE_WB;
				end
				else if(coherence_flush_valid)begin
					if(w_msg_out[coherence_flush_cache] != NO_REQ)begin
						pending_action  <= FLUSH;
						state <= WAIT_CUR_ACCESS;
					end
					else
						state <= COHERENCE_FLUSH;
				end
				else if(coherence_invld_valid)begin
					if(w_msg_out[coherence_invld_cache] != NO_REQ)begin
						pending_action  <= INVLD;
						state <= WAIT_CUR_ACCESS;
					end
					else
						state <= COHERENCE_INVLD;
				end
				else if(&tr_en_access)begin
					if(w_msg_in[serve_next] == WS_BCAST)begin
						state <= WRITE_SHARED;
						for(j=0; j<NUM_CACHES; j=j+1)begin
							if(j == serve_next)
								t_coherence_msg_out[j] <= ENABLE_WS;
							else
								t_coherence_msg_out[j] <= C_NO_REQ;
						end
					end
					else
						state <= GRANT_ACCESS;
				end
				else
					state <= WAIT_EN;
			end
			WAIT_CUR_ACCESS:begin
				if((w_msg_out[coherence_wb_cache] == NO_REQ) & (pending_action == WB_REQ))
					state <= COHERENCE_WB;
				else if((w_msg_out[coherence_flush_cache] == NO_REQ) & (pending_action == FLUSH))
					state <= COHERENCE_FLUSH;
				else if((w_msg_out[coherence_invld_cache] == NO_REQ) & (pending_action == INVLD))
					state <= COHERENCE_INVLD;
				else
					state <= WAIT_CUR_ACCESS;
			end
			GRANT_ACCESS:begin
				for(j=0; j<NUM_CACHES; j=j+1)begin
					t_coherence_msg_out[j] <= C_NO_REQ;
				end
				state <= IDLE;
			end
			COHERENCE_WB:begin
				if(w_mem2cache_msgs[coherence_wb_cache] == MEM_READY)
					state <= GRANT_ACCESS;
				else
					state <= COHERENCE_WB;
			end
			COHERENCE_FLUSH:begin
				if(w_mem2cache_msgs[coherence_flush_cache] == M_RECV)
					state <= GRANT_ACCESS;
				else
					state <= COHERENCE_FLUSH;
			end
			COHERENCE_INVLD:begin
				if(w_mem2cache_msgs[coherence_invld_cache] == M_RECV)
					state <= GRANT_ACCESS;
				else
					state <= COHERENCE_INVLD;
			end
			WRITE_SHARED:begin
				if(w_msg_in[serve_next] == NO_REQ)begin
					t_coherence_msg_out[serve_next] <= C_NO_REQ;
					state <= IDLE;
				end
				else
					state <= WRITE_SHARED;
			end
			default: state <= IDLE;
		endcase
	end
end

/** Record current accesses **/
generate
	for(i=0; i<NUM_CACHES; i=i+1)begin : CURRENT_ACCESS
		always@(posedge clock)begin
			if(reset)
				current_accesses[i] <= 0;
			else if((state == GRANT_ACCESS) & (serve_next == i))
				current_accesses[i] <= 1;
			else if((w_msg_in[i] == NO_REQ) & current_accesses[i] & 
				~((coherence_wb_cache == i) & (coherence_wb_valid)) &
				~((coherence_flush_cache == i) & (coherence_flush_valid)) &
				~((coherence_invld_cache == i) & (coherence_invld_valid)))
				current_accesses[i] <= 0;
			else if((state == COHERENCE_WB) & (coherence_wb_cache == i) & (w_mem2cache_msgs[i] != MEM_READY))
				current_accesses[i] <= 1;
			else if((state == COHERENCE_WB) & (w_mem2cache_msgs[i] == MEM_READY) & (coherence_wb_cache == i))
				current_accesses[i] <= 0;
			else if((state == COHERENCE_FLUSH) & (coherence_flush_cache == i) & (w_mem2cache_msgs[i] != M_RECV))
				current_accesses[i] <= 1;
			else if((state == COHERENCE_FLUSH) & (w_mem2cache_msgs[i] == M_RECV) & (coherence_flush_cache == i))
				current_accesses[i] <= 0;
			else if((state == COHERENCE_INVLD) & (coherence_invld_cache == i) & (w_mem2cache_msgs[i] != M_RECV))
				current_accesses[i] <= 1;
			else if((state == COHERENCE_INVLD) & (w_mem2cache_msgs[i] == M_RECV) & (coherence_invld_cache == i))
				current_accesses[i] <= 0;
			else if((w_msg_in[i] == WB_REQ) & (w_msg_out[i] == NO_REQ))
				current_accesses[i] <= 1;
			else if((w_msg_in[i] == NO_FLUSH) & (w_mem2cache_msgs[i] == REQ_FLUSH))
				current_accesses[i] <= 1;
            else if((w_msg_in[i] == FLUSH) & (w_mem2cache_msgs[i] == REQ_FLUSH))
                current_accesses[i] <= 1;
			else
				current_accesses[i] <= current_accesses[i];
		end
	end
endgenerate
/** Record current accesses **/

endmodule
