/******************************************************************************
* 	Lxcache
* Lx cache serves n L(x-1) caches with round robin arbitration.
******************************************************************************/
/******************************************************************************
* Fixes
* - After a write back is completed, invalidate the way in question. Now the
*   state machine can start from IDLE and serve a write back request from
*   level above because now there is an empty way.
	*   To make sure data flushed from level above is not lost, write that
	*   data to the way after FLUSH_WAIT state.
		*   To do this, set is changed to ensure correct LRU
		*   evaluation.
			*   Also change way to accomodate signalling with
			*   invalidate signal during a write.
* - In write back, way is invalidated only after getting MEM_READY signal from
*   lower level.
* - In flush way is completely flushed only after getting MEM_NO_MSG signal
*   from lower level.
*  - After SERV_FLUSH_REQ, flush is set only when next state is IDLE which
*  happens when serving a request from level below.
*  - Set invalidate signal when transitioning from WAIT_INVLD to IDLE so that
*  the line is invalidate only after its invalidated in the downstream caches.
	*

	**V5**
* Same as V4. Only changes are to the testbench.

    ** Coherence V1 **
* - Changes to bus widths
* - FLUSH_C and INVLD_C not used anymore, Utilize additional status bits sent
*   with data.
* - Honour RFO_BCAST messages from L1 and treat them as reads.
******************************************************************************/

module Lxcache #(
parameter STATUS_BITS           = 3,	// Valid bit + Dirty bit + inclusion bit
	      COHERENCE_BITS        = 2,
	      OFFSET_BITS           = 2,
	      DATA_WIDTH            = 8,
	      NUMBER_OF_WAYS        = 4,
	      REPLACEMENT_MODE_BITS = 1,
	      ADDRESS_WIDTH         = 12,
	      INDEX_BITS            = 6,
	      MSG_BITS              = 3,
	      NUM_CACHES            = 2,	// Number of caches served.
	      CACHE_LEVEL           = 2
) (
clock, reset,
address,
data_in,
msg_in,
report,
data_out,
out_address,
msg_out,

mem2cache_msg,
mem2cache_address,
mem2cache_data,
cache2mem_msg,
cache2mem_address,
cache2mem_data
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

// Local parameters
localparam WORDS_PER_LINE = 1 << OFFSET_BITS;
localparam TAG_BITS = ADDRESS_WIDTH - OFFSET_BITS - INDEX_BITS;
localparam LINE_WIDTH = WORDS_PER_LINE*DATA_WIDTH + TAG_BITS + COHERENCE_BITS + STATUS_BITS;    //(words_per_line*number_of_bits_per_word + number_of_tag_bits + coherence_bits + status_bits)
localparam BUS_WIDTH_DOWN = WORDS_PER_LINE*DATA_WIDTH + COHERENCE_BITS + STATUS_BITS;
localparam BUS_WIDTH_UP = (CACHE_LEVEL == 2) ? BUS_WIDTH_DOWN-1 : BUS_WIDTH_DOWN;
localparam WAY_BITS = log2(NUMBER_OF_WAYS);
localparam CACHE_DEPTH = 1 << INDEX_BITS;

localparam IDLE           = 0,
	       SERVING        = 1,
	       READ_OUT       = 2,
	       WRITE          = 3,
	       READ_ST        = 4,
	       WRITE_BACK     = 5,
	       UPDATE         = 6,
	       FLUSH_WAIT     = 7,
	       SERV_FLUSH_REQ = 8,
	       NO_FLUSH_RESP  = 9,
	       SERV_INVLD     = 10,
	       WAIT_INVLD     = 11;

`include "./params.v"
//`include "/home/sahanb/Documents/1-Projects/1-adaptive_cache/1-workspace/28-coherence/params.v"


input clock, reset;
input [ADDRESS_WIDTH*NUM_CACHES-1 : 0] address;
input [BUS_WIDTH_UP*NUM_CACHES-1 : 0] data_in;
input [MSG_BITS*NUM_CACHES-1 : 0] msg_in;
input report;
output [BUS_WIDTH_UP*NUM_CACHES-1 : 0] data_out;
output [ADDRESS_WIDTH*NUM_CACHES-1 : 0] out_address;
output [MSG_BITS*NUM_CACHES-1 : 0] msg_out;

input [MSG_BITS-1 : 0]       mem2cache_msg;
input [ADDRESS_WIDTH-1 : 0]  mem2cache_address;
input [BUS_WIDTH_DOWN-1 : 0] mem2cache_data;
output reg [MSG_BITS-1 : 0]      cache2mem_msg;
output reg [ADDRESS_WIDTH-1 : 0] cache2mem_address;
output reg [BUS_WIDTH_DOWN-1 : 0] cache2mem_data;

// Performance data
reg [31 : 0] cycles;

always @ (posedge clock) begin
        if (reset) begin
                cycles           <= 0;
        end
        else begin
                cycles           <= cycles + 1;
                if (report) begin
                        $display ("------------------------------- Lx cache Level:%1d -------------------------------------", CACHE_LEVEL);
                        //$display ("---------------------------------------------------------------------------------------");
                end
        end
end

genvar i;
integer j;

wire [OFFSET_BITS-1 : 0] zero_offset = 0;

wire [ADDRESS_WIDTH-1 : 0] w_address [0 : NUM_CACHES-1];
wire [BUS_WIDTH_UP-1 : 0] w_data_in [0 : NUM_CACHES-1];
wire [MSG_BITS-1 : 0] w_msg_in [0 : NUM_CACHES-1];

reg [BUS_WIDTH_UP-1 : 0]    t_data_out [0 : NUM_CACHES-1];
reg [ADDRESS_WIDTH-1 : 0] t_out_address [0 : NUM_CACHES-1];
reg [MSG_BITS-1 : 0]      t_msg_out [0 : NUM_CACHES-1];

reg [3:0] state;
reg [log2(NUM_CACHES)-1 : 0] serving;
reg flush_anyway, flush_mem_req, issued_flush_req;
reg [2:0] counter;

wire [NUM_CACHES-1 : 0]       requests, msgs;
wire [log2(NUM_CACHES)-1 : 0] serve_next;
wire [NUM_CACHES-1 : 0]       flush_ready, no_flush;
wire [log2(NUM_CACHES)-1 : 0] flush_ready_cache;
wire flush_ready_valid;

wire [CACHE_DEPTH-1 : 0] write_set, read_set, flush_set, invalidate_set;
wire [LINE_WIDTH-1 : 0]  line_in [CACHE_DEPTH-1 : 0];
wire [TAG_BITS-1 : 0]    tag_in [CACHE_DEPTH-1 : 0];
wire [WAY_BITS-1 : 0]    way_select [CACHE_DEPTH-1 : 0];
wire [CACHE_DEPTH-1 : 0] way_select_valid;
wire [LINE_WIDTH-1 : 0]  line_out [CACHE_DEPTH-1 : 0];
wire [WAY_BITS-1 : 0]    matched_way [CACHE_DEPTH-1 : 0];
wire [CACHE_DEPTH-1 : 0] valid_read;

reg read, write, invalidate, flush;
reg [LINE_WIDTH-1 : 0] new_line;
reg [BUS_WIDTH_UP-1 : 0] t_data_in;
reg [ADDRESS_WIDTH-1 : 0] t_address;
reg [MSG_BITS-1 : 0] t_msg;
reg [LINE_WIDTH-1 : 0] t_current_line;
reg [WAY_BITS-1 : 0] t_matched_way;
reg t_valid_read;

wire [INDEX_BITS-1 : 0] current_index;
wire [TAG_BITS-1 : 0]   current_tag;
wire hit, dirty_bit, inclusion_bit, valid_bit;
wire [TAG_BITS-1 : 0]   evicted_tag;

generate
	for(i=0; i<CACHE_DEPTH; i=i+1) begin : READ_SET
		assign read_set[i] = (((state == SERVING) | (state == READ_OUT)) & (i == current_index)) ? 1 : 0;
	end
endgenerate

generate
	for(i=0; i<CACHE_DEPTH; i=i+1) begin : WRITE_SET
		assign write_set[i] = (i == current_index) ? write : 0;
	end
endgenerate

generate
	for(i=0; i<CACHE_DEPTH; i=i+1) begin : INVALIDATE_SET
		assign invalidate_set[i] = (i == current_index) ? invalidate : 0;
	end
endgenerate

generate
	for(i=0; i<CACHE_DEPTH; i=i+1) begin : FLUSH_SET
		assign flush_set[i] = (i == current_index) ? flush : 0;
	end
endgenerate

generate
	for(i=0; i<CACHE_DEPTH; i=i+1) begin : LINE_IN
		assign line_in[i] = (i == current_index) ? new_line : 0;
	end
endgenerate

generate
	for(i=0; i<CACHE_DEPTH; i=i+1) begin : TAG_IN
		assign tag_in[i] = (i == current_index)? current_tag : 0;
	end
endgenerate

generate
	for(i=0; i<CACHE_DEPTH; i=i+1) begin : WAY_SELECT
		assign way_select[i]       = ((i == current_index) & ((state == IDLE) | (t_msg == REQ_FLUSH) | (t_msg == FLUSH) 
		                             | (t_msg == INVLD)) & t_valid_read)? t_matched_way : 0;
		assign way_select_valid[i] = ((i == current_index) & ((state == IDLE) | (t_msg == REQ_FLUSH) | (t_msg == FLUSH) 
		                             | (t_msg == INVLD)) & t_valid_read) ? 1 : 0;
	end
endgenerate

generate
	for(i=0; i<NUM_CACHES; i=i+1) begin: SEPARATE_INPUTS
		assign w_address[i] = address [i*ADDRESS_WIDTH +: ADDRESS_WIDTH];
		assign w_data_in[i] = data_in [i*BUS_WIDTH_UP +: BUS_WIDTH_UP];
		assign w_msg_in[i]  = msg_in  [i*MSG_BITS +: MSG_BITS];
	end
endgenerate

generate
	for(i=0; i<NUM_CACHES; i=i+1) begin: AGGREGATE_OUTPUTS
		assign data_out[i*BUS_WIDTH_UP +: BUS_WIDTH_UP]          = t_data_out[i];
		assign out_address[i*ADDRESS_WIDTH +: ADDRESS_WIDTH] = t_out_address[i];
		assign msg_out[i*MSG_BITS +: MSG_BITS]               = t_msg_out[i];
	end
endgenerate

generate
	for(i=0; i<NUM_CACHES; i=i+1) begin: REQUESTS
		assign requests[i] = ((w_msg_in[i] == WB_REQ) | (w_msg_in[i] == R_REQ) | (w_msg_in[i] == FLUSH)
                             | (w_msg_in[i] == INVLD) | (w_msg_in[i] == RFO_BCAST))? 1 : 0;
	end
endgenerate

generate
	for(i=0; i<NUM_CACHES; i=i+1) begin: MSGS
		assign msgs[i] = (t_msg_out[i] == MEM_NO_MSG) ? 0 : 1;
	end
endgenerate

generate
	for(i=0; i<NUM_CACHES; i=i+1) begin: FLUSH_READY
		assign flush_ready[i] = (w_msg_in[i] == FLUSH) ? 1 : 0;
		assign no_flush[i]    = (w_msg_in[i] == NO_FLUSH) ? 0 : 1;
	end
endgenerate


assign current_index = t_address[OFFSET_BITS +: INDEX_BITS];
assign current_tag   = t_address[(OFFSET_BITS+INDEX_BITS) +: TAG_BITS];
assign hit           = (state == SERVING) ? valid_read[current_index] : 0;
assign dirty_bit     = (state == SERVING) ? line_out[current_index][LINE_WIDTH-2] : 0;
assign inclusion_bit = (state == SERVING) ? line_out[current_index][LINE_WIDTH-3] : 0;
assign valid_bit     = (state == SERVING) ? line_out[current_index][LINE_WIDTH-1] : 0;
assign evicted_tag   = ((state == SERVING) & ~valid_read[current_index] & (inclusion_bit | dirty_bit)) ? line_out[current_index][(LINE_WIDTH-1-STATUS_BITS-COHERENCE_BITS) -: TAG_BITS] : 0;




// One hot decoder to convert 'flush_ready' signal to binary.
one_hot_decoder #(NUM_CACHES) flush_ready_decode (flush_ready, flush_ready_cache, flush_ready_valid);

// Instantiate arbiter
arbiter #(NUM_CACHES) arbiter_1 (clock, reset, requests, serve_next);

// Instantiate sets
generate
	for(i=0; i<CACHE_DEPTH; i=i+1) begin: SETS
		set #(STATUS_BITS, COHERENCE_BITS, TAG_BITS, OFFSET_BITS, DATA_WIDTH, NUMBER_OF_WAYS, REPLACEMENT_MODE_BITS, i)
                        set_inst(clock, reset,
                                 read_set[i], write_set[i], invalidate_set[i], flush_set[i],
                                 line_in[i], tag_in[i], way_select[i], way_select_valid[i], 1'b1, report,
                                 line_out[i], matched_way[i], valid_read[i]
                         );
	end
endgenerate


always @(posedge clock) begin
	if(reset) begin
		serving      <= 0;
		t_data_in    <= 0;
		t_address    <= 0;
		t_msg        <= 0;
		read         <= 0;
		write        <= 0;
		invalidate   <= 0;
		flush        <= 0;
		flush_anyway <= 0;
		t_current_line    <= 0;
		t_matched_way     <= 0;
		t_valid_read      <= 0;
		state             <= IDLE;
		cache2mem_data    <= 0;
		cache2mem_address <= 0;
		cache2mem_msg     <= NO_REQ;
		new_line          <= 0;
		flush_mem_req     <= 0;
		issued_flush_req  <= 0;
		for(j=0; j<NUM_CACHES; j=j+1) begin
			t_data_out[j]    <= 0;
			t_out_address[j] <= 0;
			t_msg_out[j]     <= MEM_NO_MSG;
		end
	end
	else begin
		if((mem2cache_msg == REQ_FLUSH) & (state != SERVING) & (state != SERV_FLUSH_REQ) & (state != NO_FLUSH_RESP) &
		   (state != READ_OUT) & (state != WRITE) & (state != UPDATE) & (state != FLUSH_WAIT)) begin
			t_address     <= mem2cache_address;
			t_msg         <= REQ_FLUSH;
			flush_mem_req <= 1;
			state         <= SERVING;
		end
		else begin
			case(state)
				IDLE: begin
					write      <= 0;
					new_line   <= 0;
					invalidate <= 0;
					flush      <= 0;
					for(j=0; j<NUM_CACHES; j=j+1) begin
						t_data_out[j]    <= 0;
						t_out_address[j] <= 0;
						t_msg_out[j]     <= MEM_NO_MSG;
					end
					if(|requests & ~(|msgs)) begin
						serving            <= serve_next;
						t_data_in          <= w_data_in[serve_next];
						t_address          <= w_address[serve_next];
						t_msg              <= w_msg_in[serve_next];
						t_current_line     <= line_out[current_index];
						t_msg_out[serving] <= MEM_NO_MSG;
						state              <= SERVING;
					end
					else
						state <= IDLE;
				end
				SERVING: begin
					t_current_line <= line_out[current_index];
					t_matched_way  <= matched_way[current_index];
					t_valid_read   <= valid_read[current_index];
					if(hit) begin
						if(flush_mem_req)begin
							if(inclusion_bit)begin
								for(j=0; j<NUM_CACHES; j=j+1)begin
									t_out_address[j] <= t_address;
									t_msg_out[j]     <= REQ_FLUSH;
								end
								issued_flush_req <= 1;
								flush_anyway     <= dirty_bit;
								state            <= FLUSH_WAIT;
							end
							else if(dirty_bit)begin
								cache2mem_data    <= {line_out[current_index][(LINE_WIDTH-1) -: (STATUS_BITS+COHERENCE_BITS)],
                                                      line_out[current_index][0 +: DATA_WIDTH*WORDS_PER_LINE]};
								cache2mem_address <= t_address;
								cache2mem_msg     <= FLUSH;
								state             <= SERV_FLUSH_REQ;
							end
							else begin
								cache2mem_msg <= NO_FLUSH;
								state         <= NO_FLUSH_RESP;
							end
						end
						else if(t_msg == FLUSH)begin // Request from (x-1) cache.
							cache2mem_data     <= (t_data_in[BUS_WIDTH_UP-2]) ? (CACHE_LEVEL == 2) ? 
                                                  {t_data_in[(BUS_WIDTH_UP-1) -: (STATUS_BITS-1)], 1'b0,
                                                  t_data_in[(BUS_WIDTH_UP-STATUS_BITS) : 0]} // BUS_WIDTH-1-(STATUS_BITS-1) //
                                                : t_data_in
                                                : {line_out[current_index][(LINE_WIDTH-1) -: (STATUS_BITS+COHERENCE_BITS)],
                                                   line_out[current_index][0 +: DATA_WIDTH*WORDS_PER_LINE]};
							cache2mem_address  <= t_address;
							cache2mem_msg      <= FLUSH;
							t_msg_out[serving] <= M_RECV;
							state              <= SERV_FLUSH_REQ;
						end
						else if(t_msg == INVLD)begin
							cache2mem_address  <= t_address;
							cache2mem_msg      <= INVLD;
							cache2mem_data     <= (t_data_in[BUS_WIDTH_UP-2]) ? (CACHE_LEVEL == 2) ?
                                                  {t_data_in[(BUS_WIDTH_UP-1) -: (STATUS_BITS-1)], 1'b0,
                                                  t_data_in[(BUS_WIDTH_UP-STATUS_BITS) : 0]} 
                                                : t_data_in
                                                : {line_out[current_index][(LINE_WIDTH-1) -: (STATUS_BITS+COHERENCE_BITS)],
                                                   line_out[current_index][0 +: DATA_WIDTH*WORDS_PER_LINE]};
							t_msg_out[serving] <= M_RECV;
							state              <= SERV_INVLD;
						end
						else begin
						state     <= (t_msg == WB_REQ) ? WRITE
							       : ((t_msg == R_REQ) | (t_msg == RFO_BCAST))  ? READ_OUT
							       : IDLE;
						end
					end
					else begin
						if(flush_mem_req)begin
							cache2mem_msg <= NO_FLUSH;
							state         <= NO_FLUSH_RESP;
						end
						else if(t_msg == FLUSH)begin
							cache2mem_data     <= (t_data_in[BUS_WIDTH_UP-2]) ? (CACHE_LEVEL == 2) ?
                                                  {t_data_in[(BUS_WIDTH_UP-1) -: (STATUS_BITS-1)], 1'b0,
                                                  t_data_in[(BUS_WIDTH_UP-STATUS_BITS) : 0]} // BUS_WIDTH-1-(STATUS_BITS-1) //
                                                : t_data_in : 0;
							cache2mem_address  <= t_address;
							cache2mem_msg      <= t_msg;
							t_msg_out[serving] <= M_RECV;
							state              <= SERV_FLUSH_REQ;
						end
						else if(t_msg == INVLD)begin
							cache2mem_address  <= t_address;
							cache2mem_data     <= (t_data_in[BUS_WIDTH_UP-2]) ? (CACHE_LEVEL == 2) ?
                                                  {t_data_in[(BUS_WIDTH_UP-1) -: (STATUS_BITS-1)], 1'b0,
                                                  t_data_in[(BUS_WIDTH_UP-STATUS_BITS) : 0]}
                                                : t_data_in : 0;
							cache2mem_msg      <= t_msg;
							t_msg_out[serving] <= M_RECV;
							state              <= SERV_INVLD;
						end
						else if(inclusion_bit) begin// Inclusion bit is high. (Level (x-1) cache might have a stale copy of the cache line.)
							for(j=0; j<NUM_CACHES; j=j+1)begin
								t_out_address[j] <= {evicted_tag, current_index, zero_offset};
								t_msg_out[j]     <= REQ_FLUSH;
							end
							issued_flush_req <= 1;
							state            <= FLUSH_WAIT;
						end
						else if(dirty_bit) begin
							cache2mem_data    <= {t_current_line[(LINE_WIDTH-1) -: (STATUS_BITS+COHERENCE_BITS)],
                                                  t_current_line[0 +: DATA_WIDTH*WORDS_PER_LINE]};
							cache2mem_address <= {evicted_tag, current_index, zero_offset};
							cache2mem_msg     <= WB_REQ;
							state             <= WRITE_BACK;
						end
						else begin
							if((t_msg == R_REQ) | (t_msg == RFO_BCAST))begin
								cache2mem_address <= t_address;
								cache2mem_msg     <= R_REQ;
								state             <= READ_ST;
							end
							else if(t_msg == WB_REQ)
								state <= WRITE;
							else
								state <= IDLE;
						end
					end
				end
				READ_OUT: begin
                    if(t_valid_read)begin
                        case(t_current_line[(LINE_WIDTH-1-STATUS_BITS) -: COHERENCE_BITS])
                            INVALID:begin
					            t_data_out[serving] <= (CACHE_LEVEL == 2) ? {t_current_line[(LINE_WIDTH-1) -: (STATUS_BITS-1)],
                                                       EXCLUSIVE, t_current_line[0 +: DATA_WIDTH*WORDS_PER_LINE]}
                                                       : {t_current_line[(LINE_WIDTH-1) -: STATUS_BITS], EXCLUSIVE, t_current_line[0 +: DATA_WIDTH*WORDS_PER_LINE]};
                                new_line <= {t_current_line[(LINE_WIDTH-1) -: (STATUS_BITS-1)], 1'b1, EXCLUSIVE, t_current_line[(LINE_WIDTH-1-STATUS_BITS-COHERENCE_BITS) : 0]};
                            end
                            EXCLUSIVE:begin
					            t_data_out[serving] <= (CACHE_LEVEL == 2) ? {t_current_line[(LINE_WIDTH-1) -: (STATUS_BITS-1)],
                                                       SHARED, t_current_line[0 +: DATA_WIDTH*WORDS_PER_LINE]}
                                                       : {t_current_line[(LINE_WIDTH-1) -: STATUS_BITS], SHARED, t_current_line[0 +: DATA_WIDTH*WORDS_PER_LINE]};
                                new_line <= {t_current_line[(LINE_WIDTH-1) -: (STATUS_BITS-1)], 1'b1, SHARED, t_current_line[(LINE_WIDTH-1-STATUS_BITS-COHERENCE_BITS) : 0]};
                            end
                            default:begin
					            t_data_out[serving] <= (CACHE_LEVEL == 2) ? {t_current_line[(LINE_WIDTH-1) -: (STATUS_BITS-1)],
                                                       t_current_line[(LINE_WIDTH-1-STATUS_BITS) -: COHERENCE_BITS], t_current_line[0 +: DATA_WIDTH*WORDS_PER_LINE]}
                                                       : {t_current_line[(LINE_WIDTH-1) -: (STATUS_BITS+COHERENCE_BITS)], t_current_line[0 +: DATA_WIDTH*WORDS_PER_LINE]};
                                new_line <= {t_current_line[(LINE_WIDTH-1) -: (STATUS_BITS-1)], 1'b1, SHARED, t_current_line[(LINE_WIDTH-1-STATUS_BITS-COHERENCE_BITS) : 0]};
                            end
                        endcase
                        write <= 1;
                    end
                    else begin
					    t_data_out[serving] <= (CACHE_LEVEL == 2) ? {t_current_line[(LINE_WIDTH-1) -: (STATUS_BITS-1)],
                                               t_current_line[(LINE_WIDTH-1-STATUS_BITS) -: COHERENCE_BITS], t_current_line[0 +: DATA_WIDTH*WORDS_PER_LINE]}
                                               : {t_current_line[(LINE_WIDTH-1) -: (STATUS_BITS+COHERENCE_BITS)], t_current_line[0 +: DATA_WIDTH*WORDS_PER_LINE]};
                    end
					t_out_address[serving] <= t_address;
					t_msg_out[serving]     <= MEM_SENT;
					state                  <= IDLE;
				end
				WRITE: begin
					invalidate         <= 0;
					write              <= 1;
					new_line           <= {2'b11, 1'b0, INVALID, current_tag, t_data_in[DATA_WIDTH*WORDS_PER_LINE-1 : 0]};
					t_msg_out[serving] <= MEM_READY;
					state              <= IDLE;
				end
				FLUSH_WAIT: begin
					flush  <= 1'b0;
					if(flush_ready_valid)begin
						cache2mem_data    <= (CACHE_LEVEL == 2) ? {w_data_in[flush_ready_cache][(BUS_WIDTH_UP-1) -: (STATUS_BITS-1)],
                                             1'b0, w_data_in[flush_ready_cache][DATA_WIDTH*WORDS_PER_LINE+COHERENCE_BITS-1 : 0]}
                                           : w_data_in[flush_ready_cache];
						cache2mem_address <= t_out_address[flush_ready_cache];
						cache2mem_msg     <= (t_msg == REQ_FLUSH) ? FLUSH : WB_REQ;
						write             <= 1;
						invalidate        <= 1;
						new_line          <= {2'b11, 1'b0, INVALID, t_out_address[flush_ready_cache][(ADDRESS_WIDTH-1) -: TAG_BITS],
                                              w_data_in[flush_ready_cache][DATA_WIDTH*WORDS_PER_LINE-1 : 0]};
						for(j=0; j<NUM_CACHES; j=j+1)begin
							t_out_address[j] <= 0;
							t_msg_out[j]     <= MEM_NO_MSG;
						end
						state    <= (t_msg == REQ_FLUSH) ? SERV_FLUSH_REQ : WRITE_BACK;
					end

					else if(no_flush == 0)begin
						if(flush_anyway)begin
							cache2mem_data    <= {t_current_line[(LINE_WIDTH-1) -: (STATUS_BITS+COHERENCE_BITS)],
                                                  t_current_line[0 +: DATA_WIDTH*WORDS_PER_LINE]};
							cache2mem_address <= t_out_address[0];
							cache2mem_msg     <= (t_msg == REQ_FLUSH) ? FLUSH : WB_REQ;
							for(j=0; j<NUM_CACHES; j=j+1)begin
								t_out_address[j] <= 0;
								t_msg_out[j]     <= MEM_NO_MSG;
							end
							state    <= (t_msg == REQ_FLUSH) ? SERV_FLUSH_REQ : WRITE_BACK;
						end
						else begin
							cache2mem_data    <= 0;
							cache2mem_address <= 0;
							cache2mem_msg     <= NO_FLUSH;
							state             <= NO_FLUSH_RESP;
						end
					end
					else begin
						state   <= FLUSH_WAIT;
					end
				end
				WRITE_BACK: begin
					write      <= 0;
					invalidate <= 0;
					if(mem2cache_msg == MEM_READY) begin
						cache2mem_address <= ((t_msg == R_REQ) | (t_msg == RFO_BCAST)) ? t_address : 0;
						cache2mem_msg     <= ((t_msg == R_REQ) | (t_msg == RFO_BCAST)) ? R_REQ : NO_REQ;
						cache2mem_data    <= 0;
						issued_flush_req  <= 0;
						invalidate        <= 1;
						state             <= ((t_msg == R_REQ) | (t_msg == RFO_BCAST)) ? READ_ST
								           : ((t_msg == WB_REQ) & ~issued_flush_req) ? WRITE
								           :  IDLE;
					end
					else
						state <= WRITE_BACK;
				end
				READ_ST: begin
					invalidate <= 0;
					if(mem2cache_msg == MEM_SENT) begin
						write             <= 1'b1;
						new_line          <= {2'b10, 1'b1, EXCLUSIVE, current_tag, mem2cache_data[DATA_WIDTH*WORDS_PER_LINE-1 : 0]};
						t_current_line    <= {2'b10, 1'b1, EXCLUSIVE,  current_tag, mem2cache_data[DATA_WIDTH*WORDS_PER_LINE-1 : 0]};
						cache2mem_msg     <= NO_REQ;
						cache2mem_address <= 0;
						state             <= UPDATE;
					end
					else
						state <= READ_ST;
				end
				UPDATE: begin
					write <= 1'b0;
					state <= READ_OUT;
				end
				SERV_FLUSH_REQ: begin
					write      <= 0;
					invalidate <= 0;
					flush            <= 0;
					issued_flush_req <= 0;
					if(((mem2cache_msg == MEM_NO_MSG) & (flush_mem_req)) | ((mem2cache_msg == M_RECV) & (t_msg == FLUSH) & ~flush_mem_req))begin
						cache2mem_data    <= 0;
						cache2mem_address <= 0;
						cache2mem_msg     <= NO_REQ;
						flush_mem_req     <= 0;
						flush             <= (flush_mem_req) ? 1 : 0;
						state             <= (flush_mem_req) ? IDLE : NO_FLUSH_RESP;
					end
					else
						state             <= SERV_FLUSH_REQ;
				end
				NO_FLUSH_RESP: begin
					flush            <= 0;
					issued_flush_req <= 0;
					if(mem2cache_msg == MEM_NO_MSG)begin
						cache2mem_data    <= 0;
						cache2mem_address <= 0;
						flush_mem_req     <= 0;
						flush             <= 1;
						cache2mem_msg     <= NO_REQ;
						state             <= IDLE;
					end
					else
						state             <= NO_FLUSH_RESP;
				end
				SERV_INVLD: begin
					invalidate <= 1'b0;
					if(mem2cache_msg == M_RECV)begin
						state             <= WAIT_INVLD;
						cache2mem_address <= 0;
						cache2mem_data    <= 0;
						cache2mem_msg     <= NO_REQ;
					end
					else
						state <= SERV_INVLD;
				end
				WAIT_INVLD:begin
					if(mem2cache_msg == MEM_NO_MSG)begin
						invalidate <= 1;
						state      <= IDLE;
					end
					else
						state      <= WAIT_INVLD;
				end
				default: state <= IDLE;
			endcase
		end
	end
end


endmodule
