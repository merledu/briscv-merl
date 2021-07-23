/******************************************************************************
* Module: Lxcache
* Description: Lxcache module optimized for FPGA-based implementations
******************************************************************************/

module Lxcache #(
parameter STATUS_BITS           = 3, // Valid bit + Dirty bit + inclusion bit
	      COHERENCE_BITS        = 2,
	      OFFSET_BITS           = 2,
	      DATA_WIDTH            = 32,
	      NUMBER_OF_WAYS        = 4,
	      REPLACEMENT_MODE_BITS = 1,
	      ADDRESS_WIDTH         = 32,
	      INDEX_BITS            = 10,
	      MSG_BITS              = 3,
	      NUM_CACHES            = 2, // Number of caches served.
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
localparam TAG_BITS   = ADDRESS_WIDTH - OFFSET_BITS - INDEX_BITS;
localparam LINE_WIDTH = WORDS_PER_LINE*DATA_WIDTH + TAG_BITS + COHERENCE_BITS
                        + STATUS_BITS;
localparam BUS_WIDTH_DOWN = WORDS_PER_LINE*DATA_WIDTH + COHERENCE_BITS + STATUS_BITS;
localparam BUS_WIDTH_UP   = (CACHE_LEVEL == 2) ? BUS_WIDTH_DOWN-1 : BUS_WIDTH_DOWN;
localparam WAY_BITS       = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 1;
localparam CACHE_DEPTH    = 1 << INDEX_BITS;

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
	       WAIT_INVLD     = 11,
           RESET          = 12,
           BRAM_DELAY     = 13;

`include "./params.v"

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

genvar i;
integer j, k;

// Performance data
reg [31 : 0] cycles;

always @ (posedge clock) begin
    if (reset) begin
        cycles           <= 0;
    end
    else begin
        cycles           <= cycles + 1;
/*        if (report) begin
            $display ("\n-------------------- Lx cache Level:%1d || cycles:%d------------------", CACHE_LEVEL, cycles);
            for(j=0; j<CACHE_DEPTH; j=j+1)begin
              $display("-----------------------------Set:%3d----------------------------------", j);
                for(k=0; k<NUMBER_OF_WAYS; k=k+1)begin
                    if(k==0)
                    $display("Way:%1d ==> Status bits [%b]\t| Coherence bits [%b]\t| Tag [0x%h]\t| Data [0x%h]", k,
                       BRAM[0].way_bram.mem[j][LINE_WIDTH-1 -: STATUS_BITS],
                       BRAM[0].way_bram.mem[j][LINE_WIDTH-1-STATUS_BITS -: COHERENCE_BITS],
                       BRAM[0].way_bram.mem[j][LINE_WIDTH-1-STATUS_BITS-COHERENCE_BITS -: TAG_BITS],
                       BRAM[0].way_bram.mem[j][0 +: DATA_WIDTH*WORDS_PER_LINE]);
                    else
                    $display("Way:%1d ==> Status bits [%b]\t| Coherence bits [%b]\t| Tag [0x%h]\t| Data [0x%h]", k,
                       BRAM[1].way_bram.mem[j][LINE_WIDTH-1 -: STATUS_BITS],
                       BRAM[1].way_bram.mem[j][LINE_WIDTH-1-STATUS_BITS -: COHERENCE_BITS],
                       BRAM[1].way_bram.mem[j][LINE_WIDTH-1-STATUS_BITS-COHERENCE_BITS -: TAG_BITS],
                       BRAM[1].way_bram.mem[j][0 +: DATA_WIDTH*WORDS_PER_LINE]);
                end
                $display("LRU ====> %d | %d", replace_inst.lru_inst.order[j][0],
                    replace_inst.lru_inst.order[j][1]);
            end
        end*/
    end
end


reg [3:0] state;
reg [INDEX_BITS-1 : 0] reset_counter;
reg [log2(NUM_CACHES)-1 : 0] serving;
reg flush_anyway, flush_mem_req, issued_flush_req;
reg read, write, invalidate, flush;
reg [LINE_WIDTH-1 : 0] new_line;
reg [BUS_WIDTH_UP-1 : 0] t_data_in;
reg [ADDRESS_WIDTH-1 : 0] t_address;
reg [MSG_BITS-1 : 0] t_msg;
reg [LINE_WIDTH-1 : 0] t_current_line;
reg [WAY_BITS-1 : 0] t_matched_way;
reg t_valid_read;
reg [BUS_WIDTH_UP-1 : 0]  t_data_out [0 : NUM_CACHES-1];
reg [ADDRESS_WIDTH-1 : 0] t_out_address [0 : NUM_CACHES-1];
reg [MSG_BITS-1 : 0]      t_msg_out [0 : NUM_CACHES-1];

wire i_reset;
wire [NUMBER_OF_WAYS-1 : 0] we0, we1;
wire [LINE_WIDTH-1 : 0] data_in0, data_in1;
wire [ADDRESS_WIDTH-1 : 0] address_in0, address_in1;
wire [LINE_WIDTH-1 : 0] data_out0 [NUMBER_OF_WAYS-1 : 0];
wire [LINE_WIDTH-1 : 0] data_out1 [NUMBER_OF_WAYS-1 : 0];
wire [TAG_BITS-1 : 0] tag_out0 [NUMBER_OF_WAYS-1 : 0];
wire [LINE_WIDTH-1 : 0] line_out;
wire [INDEX_BITS-1 : 0] current_index;
wire [TAG_BITS-1 : 0]   current_tag, evicted_tag;
wire hit, dirty_bit, inclusion_bit;
wire [ADDRESS_WIDTH-1 : 0] w_address [0 : NUM_CACHES-1];
wire [BUS_WIDTH_UP-1 : 0] w_data_in [0 : NUM_CACHES-1];
wire [MSG_BITS-1 : 0] w_msg_in [0 : NUM_CACHES-1];
wire [NUM_CACHES-1 : 0] requests, msgs;
wire [NUMBER_OF_WAYS-1 : 0] tag_match, replace_way_encoded;
wire valid_replace_way;
wire [WAY_BITS-1 : 0] decoded_tag_match, matched_way, replace_way;
wire valid_tag_match, valid_empty_way, access_valid;
wire [NUMBER_OF_WAYS-1:0] ways_in_use, next_empty_way;
wire [WAY_BITS-1 : 0] current_access;
wire [REPLACEMENT_MODE_BITS-1 : 0] replacement_policy_select;
wire [log2(NUM_CACHES)-1 : 0] serve_next;
wire flush_ready_valid;
wire [log2(NUM_CACHES)-1 : 0] flush_ready_cache;
wire [NUM_CACHES-1 : 0]       flush_ready, no_flush;
wire [OFFSET_BITS-1 : 0] zero_offset = 0;

generate
	for(i=0; i<NUMBER_OF_WAYS; i=i+1)begin : BRAM
		dual_port_ram #(LINE_WIDTH, ADDRESS_WIDTH, INDEX_BITS, "OLD_DATA") 
		    way_bram(clock, we0[i], we1[i], data_in0, data_in1,
			address_in0, address_in1, data_out0[i], data_out1[i]);
	end
endgenerate

generate
	for(i=0; i<NUM_CACHES; i=i+1) begin: FLUSH_READY
		assign flush_ready[i] = (w_msg_in[i] == FLUSH) ? 1 : 0;
		assign no_flush[i]    = (w_msg_in[i] == NO_FLUSH) ? 0 : 1;
	end
endgenerate

//Instantiate one-hot decoders
generate
if(NUMBER_OF_WAYS > 1)begin
one_hot_decoder #(NUMBER_OF_WAYS) decoder_1(tag_match, decoded_tag_match, valid_tag_match);
one_hot_decoder #(NUM_CACHES) decoder_2 (flush_ready, flush_ready_cache, flush_ready_valid);
one_hot_decoder #(NUMBER_OF_WAYS) decoder_3(replace_way_encoded, replace_way, valid_replace_way);
end
else begin
    assign decoded_tag_match = 0;
    assign valid_tag_match   = tag_match;
    assign flush_ready_cache = 0;
    assign flush_ready_valid = flush_ready;
    assign replace_way       = 0;
    assign valid_replace_way = replace_way_encoded;
end
endgenerate

// Instantiate arbiter
arbiter #(NUM_CACHES) arbiter_1 (clock, i_reset, requests, serve_next);

//Instantiate replacement controller
generate
if(NUMBER_OF_WAYS > 1)begin
replacement_controller #(NUMBER_OF_WAYS, INDEX_BITS) 
	replace_inst(clock, i_reset, ways_in_use, current_index, replacement_policy_select, 
	current_access, access_valid, report, replace_way_encoded);
end
else 
    assign replace_way_encoded = 0;
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
		assign data_out[i*BUS_WIDTH_UP +: BUS_WIDTH_UP]      = t_data_out[i];
		assign out_address[i*ADDRESS_WIDTH +: ADDRESS_WIDTH] = t_out_address[i];
		assign msg_out[i*MSG_BITS +: MSG_BITS]               = t_msg_out[i];
	end
endgenerate

generate
	for(i=0; i<NUM_CACHES; i=i+1) begin: REQUESTS
		assign requests[i] = ((w_msg_in[i] == WB_REQ) | (w_msg_in[i] == R_REQ) 
		                     | (w_msg_in[i] == FLUSH) | (w_msg_in[i] == INVLD) 
							 | (w_msg_in[i] == RFO_BCAST))? 1 : 0;
		assign msgs[i]     = (t_msg_out[i] == MEM_NO_MSG) ? 0 : 1;
	end
endgenerate

generate
	for(i=0; i<NUMBER_OF_WAYS; i=i+1)begin: WAY_OPERATIONS
		assign tag_out0[i]    = data_out0[i][DATA_WIDTH*WORDS_PER_LINE +: TAG_BITS];
		assign tag_match[i]   = data_out0[i][LINE_WIDTH-1] & (current_tag == tag_out0[i]);
		assign ways_in_use[i] = (state == RESET) ? 0 : data_out0[i][LINE_WIDTH-1];
	end
endgenerate


assign i_reset       = reset | (state == RESET);
assign current_index = (state == RESET) ? reset_counter
                     : ((mem2cache_msg == REQ_FLUSH) & (state != SERVING) & 
                       (state != SERV_FLUSH_REQ) & (state != NO_FLUSH_RESP) & 
					   (state != READ_OUT) & (state != WRITE) & (state != UPDATE)
					   & (state != FLUSH_WAIT)) ? mem2cache_address[OFFSET_BITS
					   +: INDEX_BITS]
					   : (state == IDLE) & (|requests & ~(|msgs)) ? w_address
					   [serve_next][OFFSET_BITS +: INDEX_BITS]
					   : t_address[OFFSET_BITS +: INDEX_BITS];
					   
assign current_tag = ((mem2cache_msg == REQ_FLUSH) & (state != SERVING) & 
                     (state != SERV_FLUSH_REQ) & (state != NO_FLUSH_RESP) & 
					 (state != READ_OUT) & (state != WRITE) & (state != UPDATE)
					 & (state != FLUSH_WAIT)) ? mem2cache_address
					 [(OFFSET_BITS+INDEX_BITS) +: TAG_BITS]
					 : (state == IDLE) & (|requests & ~(|msgs)) ? w_address
					 [serve_next][(OFFSET_BITS+INDEX_BITS) +: TAG_BITS]
					 : t_address[(OFFSET_BITS+INDEX_BITS) +: TAG_BITS];
					   
assign matched_way = valid_tag_match ? decoded_tag_match : replace_way;
assign replacement_policy_select = 1;
assign current_access = write ? t_matched_way : valid_tag_match & (state == SERVING) ?
                        decoded_tag_match : 0;
assign access_valid   = (write & ~invalidate) | (state == SERVING & valid_tag_match);
assign hit            = (state == SERVING) ? valid_tag_match : 0;
assign line_out       = data_out0[matched_way];
assign dirty_bit      = (state == SERVING) ? line_out[LINE_WIDTH-2] : 0;
assign inclusion_bit  = (state == SERVING) ? line_out[LINE_WIDTH-3] : 0;
assign evicted_tag    = ((state == SERVING) & ~valid_tag_match & (inclusion_bit 
                        | dirty_bit)) ? line_out[(LINE_WIDTH-1-STATUS_BITS-COHERENCE_BITS)
                        -: TAG_BITS] : 0;
assign address_in0 = (state == RESET) ? reset_counter : current_index;
assign data_in0    = write ? new_line 
                   : invalidate ? {{(STATUS_BITS+COHERENCE_BITS){1'b0}}, 
                     t_current_line[0 +: (TAG_BITS+DATA_WIDTH*WORDS_PER_LINE)]}
                   : 0;

generate
    for(i=0; i<NUMBER_OF_WAYS; i=i+1)begin : WE0
        assign we0[i] = (state == RESET) ? 1
                      : (i == t_matched_way) ? (write|invalidate|flush) 
                      : 0;
    end
endgenerate


always @(posedge clock) begin
	if(reset) begin
		serving      <= 0;
		t_data_in    <= 0;
		t_address    <= 0;
		t_msg        <= 0;
		write        <= 0;
		invalidate   <= 0;
		flush        <= 0;
		flush_anyway <= 0;
		t_current_line    <= 0;
		t_matched_way     <= 0;
		t_valid_read      <= 0;
        reset_counter     <= 0;
        new_line          <= 0;
		state             <= RESET;
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
		if((mem2cache_msg == REQ_FLUSH) & (state != SERVING) & (state != SERV_FLUSH_REQ) 
		& (state != NO_FLUSH_RESP) & (state != READ_OUT) & (state != WRITE) 
		& (state != UPDATE) & (state != FLUSH_WAIT)) begin
			t_address     <= mem2cache_address;
			t_msg         <= REQ_FLUSH;
			flush_mem_req <= 1;
			state         <= SERVING;
		end
		else begin
			case(state)
                RESET:begin
                    if(reset_counter < CACHE_DEPTH-1)
                        reset_counter <= reset_counter + 1;
                    else begin
                        reset_counter <= 0;
                        state         <= IDLE;
                    end
                end
				IDLE:begin
					write      <= 0;
					new_line   <= 0;
					invalidate <= 0;
					flush      <= 0;
                    cache2mem_data <= 0;
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
						state              <= SERVING;
					end
					else
						state <= IDLE;
				end
				SERVING:begin
					t_current_line <= line_out;
					t_matched_way  <= matched_way;
					t_valid_read   <= valid_tag_match;
					if(hit)begin
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
								cache2mem_data    <= {line_out[(LINE_WIDTH-1)
                        							 -: (STATUS_BITS+COHERENCE_BITS)],
													 line_out[0 +: DATA_WIDTH*
                                                     WORDS_PER_LINE]};
								cache2mem_address <= t_address;
								cache2mem_msg     <= FLUSH;
								state             <= SERV_FLUSH_REQ;
							end
                            else begin
                                cache2mem_msg <= NO_FLUSH;
                                state         <= NO_FLUSH_RESP;
                            end
						end
                        else if(t_msg == FLUSH)begin
                            cache2mem_data     <= (t_data_in[BUS_WIDTH_UP-2]) ?
                                                  (CACHE_LEVEL == 2) ? {t_data_in
                                                  [(BUS_WIDTH_UP-1) -: (STATUS_BITS-1)], 1'b0,
                                                  t_data_in[(BUS_WIDTH_UP-STATUS_BITS) : 0]}
                                                : t_data_in
                                                : {line_out[(LINE_WIDTH-1) -: (STATUS_BITS+
                                                  COHERENCE_BITS)], line_out
                                                  [0 +: DATA_WIDTH*WORDS_PER_LINE]};
                            cache2mem_address  <= t_address;
                            cache2mem_msg      <= FLUSH;
                            t_msg_out[serving] <= M_RECV;
                            state              <= SERV_FLUSH_REQ;
                        end
                        else if(t_msg == INVLD)begin
                            cache2mem_address  <= t_address;
                            cache2mem_msg      <= INVLD;
                            cache2mem_data     <= (t_data_in[BUS_WIDTH_UP-2]) ?
                                                  (CACHE_LEVEL == 2) ? {t_data_in
                                                  [(BUS_WIDTH_UP-1) -: (STATUS_BITS-1)], 1'b0,
                                                  t_data_in[(BUS_WIDTH_UP-STATUS_BITS) : 0]}
                                                : t_data_in
                                                : {line_out[(LINE_WIDTH-1) -: (STATUS_BITS+
                                                  COHERENCE_BITS)], line_out
                                                  [0 +: DATA_WIDTH*WORDS_PER_LINE]};
                            t_msg_out[serving] <= M_RECV;
                            state              <= SERV_INVLD;
                        end
                        else begin
                            state <= (t_msg == WB_REQ) ? WRITE
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
                            cache2mem_data     <= (t_data_in[BUS_WIDTH_UP-2]) ?
                                                  (CACHE_LEVEL == 2) ? {t_data_in
                                                  [(BUS_WIDTH_UP-1) -: (STATUS_BITS-1)], 1'b0,
                                                  t_data_in[(BUS_WIDTH_UP-STATUS_BITS) : 0]}
                                                : t_data_in : 0;
							cache2mem_address  <= t_address;
							cache2mem_msg      <= t_msg;
							t_msg_out[serving] <= M_RECV;
							state              <= SERV_FLUSH_REQ;
                        end
                        else if(t_msg == INVLD)begin
                            cache2mem_data     <= (t_data_in[BUS_WIDTH_UP-2]) ?
                                                  (CACHE_LEVEL == 2) ? {t_data_in
                                                  [(BUS_WIDTH_UP-1) -: (STATUS_BITS-1)], 1'b0,
                                                  t_data_in[(BUS_WIDTH_UP-STATUS_BITS) : 0]}
                                                : t_data_in : 0;
							cache2mem_address  <= t_address;
							cache2mem_msg      <= t_msg;
							t_msg_out[serving] <= M_RECV;
							state              <= SERV_INVLD;
                        end
                        else if(inclusion_bit)begin
                            for(j=0; j<NUM_CACHES; j=j+1)begin
								t_out_address[j] <= {evicted_tag, current_index, zero_offset};
								t_msg_out[j]     <= REQ_FLUSH;
							end
							issued_flush_req <= 1;
							state            <= FLUSH_WAIT;
                        end
                        else if(dirty_bit)begin
                            cache2mem_data    <= {line_out[(LINE_WIDTH-1) -: 
                                                 (STATUS_BITS+COHERENCE_BITS)],
                                                 line_out[0 +: DATA_WIDTH*WORDS_PER_LINE]};
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
                READ_OUT:begin
                    if(t_valid_read)begin
                        case(t_current_line[(LINE_WIDTH-1-STATUS_BITS) -: COHERENCE_BITS])
                            INVALID:begin
					            t_data_out[serving] <= (CACHE_LEVEL == 2) ? 
                                                       {t_current_line[(LINE_WIDTH-1) 
                                                       -: (STATUS_BITS-1)], EXCLUSIVE,
                                                       t_current_line[0 +: DATA_WIDTH*
                                                       WORDS_PER_LINE]}
                                                     : {t_current_line[(LINE_WIDTH-1) 
                                                       -: STATUS_BITS], EXCLUSIVE, 
                                                       t_current_line[0 +: DATA_WIDTH*
                                                       WORDS_PER_LINE]};
                                new_line <= {t_current_line[(LINE_WIDTH-1) -: 
                                            (STATUS_BITS-1)], 1'b1, EXCLUSIVE, 
                                            t_current_line[(LINE_WIDTH-1-STATUS_BITS-
                                            COHERENCE_BITS) : 0]};
                            end
                            EXCLUSIVE:begin
					            t_data_out[serving] <= (CACHE_LEVEL == 2) ? 
                                                       {t_current_line[(LINE_WIDTH-1)
                                                       -: (STATUS_BITS-1)],SHARED, 
                                                       t_current_line[0 +: DATA_WIDTH
                                                       *WORDS_PER_LINE]}
                                                     : {t_current_line[(LINE_WIDTH-1) 
                                                       -: STATUS_BITS], SHARED, 
                                                       t_current_line[0 +: DATA_WIDTH
                                                       *WORDS_PER_LINE]};
                                new_line <= {t_current_line[(LINE_WIDTH-1) -: 
                                            (STATUS_BITS-1)], 1'b1, SHARED, 
                                            t_current_line[(LINE_WIDTH-1-STATUS_BITS-
                                            COHERENCE_BITS) : 0]};
                            end
                            default:begin
					            t_data_out[serving] <= (CACHE_LEVEL == 2) ? 
                                                       {t_current_line[(LINE_WIDTH-1) 
                                                       -: (STATUS_BITS-1)],
                                                       t_current_line[(LINE_WIDTH
                                                       -1-STATUS_BITS) -: COHERENCE_BITS],
                                                       t_current_line[0 +: DATA_WIDTH
                                                       *WORDS_PER_LINE]}
                                                     : {t_current_line[(LINE_WIDTH-1) 
                                                       -: (STATUS_BITS+COHERENCE_BITS)], 
                                                       t_current_line[0 +: DATA_WIDTH
                                                       *WORDS_PER_LINE]};
                                new_line <= {t_current_line[(LINE_WIDTH-1) -: 
                                            (STATUS_BITS-1)], 1'b1, SHARED, 
                                            t_current_line[(LINE_WIDTH-1-STATUS_BITS
                                            -COHERENCE_BITS) : 0]};
                            end
                        endcase
                        write <= 1;
                    end
                    else begin
                        t_data_out[serving] <= (CACHE_LEVEL == 2) ? 
                                               {t_current_line[(LINE_WIDTH-1) -:
                                               (STATUS_BITS-1)], t_current_line
                                               [(LINE_WIDTH-1-STATUS_BITS) -: 
                                               COHERENCE_BITS], t_current_line
                                               [0 +: DATA_WIDTH*WORDS_PER_LINE]}
                                             : {t_current_line[(LINE_WIDTH-1) -: 
                                               (STATUS_BITS+COHERENCE_BITS)], 
                                               t_current_line[0 +: DATA_WIDTH*WORDS_PER_LINE]};
                    end
                    t_out_address[serving] <= t_address;
                    t_msg_out[serving]     <= MEM_SENT;
                    state                  <= IDLE;
                end
                WRITE:begin
                    invalidate         <= 0;
					write              <= 1;
					new_line           <= {2'b11, 1'b0, INVALID, current_tag, 
                                          t_data_in[DATA_WIDTH*WORDS_PER_LINE-1 : 0]};
					t_msg_out[serving] <= MEM_READY;
					state              <= IDLE;
                end
                FLUSH_WAIT:begin
                    flush <= 0;
                    if(flush_ready_valid)begin
                        cache2mem_data    <= (CACHE_LEVEL == 2) ? 
                                             {w_data_in[flush_ready_cache]
                                             [(BUS_WIDTH_UP-1) -: (STATUS_BITS-1)],
                                             1'b0, w_data_in[flush_ready_cache]
                                             [DATA_WIDTH*WORDS_PER_LINE+COHERENCE_BITS-1 : 0]}
                                           : w_data_in[flush_ready_cache];
						cache2mem_address <= t_out_address[flush_ready_cache];
						cache2mem_msg     <= (t_msg == REQ_FLUSH) ? FLUSH : WB_REQ;
						write             <= 1;
						invalidate        <= 1;
						new_line          <= {2'b11, 1'b0, INVALID, t_out_address
                                             [flush_ready_cache][(ADDRESS_WIDTH-1) 
                                             -: TAG_BITS], w_data_in[flush_ready_cache]
                                             [DATA_WIDTH*WORDS_PER_LINE-1 : 0]};
						for(j=0; j<NUM_CACHES; j=j+1)begin
							t_out_address[j] <= 0;
							t_msg_out[j]     <= MEM_NO_MSG;
						end
						state    <= (t_msg == REQ_FLUSH) ? SERV_FLUSH_REQ : WRITE_BACK;
                    end
                    else if(no_flush == 0)begin
                        if(flush_anyway)begin
                            cache2mem_data    <= {t_current_line[(LINE_WIDTH-1) -: 
                                                 (STATUS_BITS+COHERENCE_BITS)],
                                                 t_current_line[0 +: DATA_WIDTH*
                                                 WORDS_PER_LINE]};
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
                    else
                        state <= FLUSH_WAIT;
                end
                WRITE_BACK:begin
                    write      <= 0;
					invalidate <= 0;
					if(mem2cache_msg == MEM_READY) begin
						cache2mem_address <= ((t_msg == R_REQ) | (t_msg == RFO_BCAST)) ?
                                             t_address : 0;
						cache2mem_msg     <= ((t_msg == R_REQ) | (t_msg == RFO_BCAST)) ?
                                             R_REQ : NO_REQ;
						cache2mem_data    <= 0;
						issued_flush_req  <= 0;
						invalidate        <= 1;
						state             <= ((t_msg == R_REQ) | (t_msg == RFO_BCAST)) ? READ_ST
								           : ((t_msg == WB_REQ) & ~issued_flush_req) ? WRITE
								           :  BRAM_DELAY;
					end
					else
						state <= WRITE_BACK;
                end
                READ_ST:begin
                    invalidate <= 0;
					if(mem2cache_msg == MEM_SENT) begin
						write             <= 1'b1;
						new_line          <= {2'b10, 1'b1, EXCLUSIVE, current_tag,
                                             mem2cache_data[DATA_WIDTH*WORDS_PER_LINE-1 : 0]};
						t_current_line    <= {2'b10, 1'b1, EXCLUSIVE, current_tag, 
                                             mem2cache_data[DATA_WIDTH*WORDS_PER_LINE-1 : 0]};
						cache2mem_msg     <= NO_REQ;
						cache2mem_address <= 0;
						state             <= UPDATE;
					end
					else
						state <= READ_ST;
                end
                UPDATE:begin
                    write <= 0;
                    state <= READ_OUT;
                end
                SERV_FLUSH_REQ:begin
                    write      <= 0;
					invalidate <= 0;
					flush            <= 0;
					issued_flush_req <= 0;
					if(((mem2cache_msg == MEM_NO_MSG) & (flush_mem_req)) 
                    | ((mem2cache_msg == M_RECV) & (t_msg == FLUSH) & ~flush_mem_req))begin
						cache2mem_data    <= 0;
						cache2mem_address <= 0;
						cache2mem_msg     <= NO_REQ;
						flush_mem_req     <= 0;
						flush             <= (flush_mem_req) ? 1 : 0;
						state             <= (flush_mem_req) ? BRAM_DELAY : NO_FLUSH_RESP;
					end
					else
						state             <= SERV_FLUSH_REQ;
                end
                NO_FLUSH_RESP:begin
                    flush            <= 0;
					issued_flush_req <= 0;
					if(mem2cache_msg == MEM_NO_MSG)begin
						cache2mem_data    <= 0;
						cache2mem_address <= 0;
						flush_mem_req     <= 0;
						flush             <= 1;
						cache2mem_msg     <= NO_REQ;
						state             <= BRAM_DELAY;
					end
					else
						state             <= NO_FLUSH_RESP;
                end
                SERV_INVLD:begin
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
						state      <= BRAM_DELAY;
					end
					else
						state      <= WAIT_INVLD;
                end
                BRAM_DELAY:begin
					write      <= 0;
					new_line   <= 0;
					invalidate <= 0;
					flush      <= 0;
					for(j=0; j<NUM_CACHES; j=j+1) begin
						t_data_out[j]    <= 0;
						t_out_address[j] <= 0;
						t_msg_out[j]     <= MEM_NO_MSG;
					end
                    state <= IDLE;
                end
				default: state <= IDLE;
			endcase
		end
	end
end

endmodule
