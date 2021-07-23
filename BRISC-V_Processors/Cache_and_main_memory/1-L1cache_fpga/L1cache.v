/******************************************************************************
* Module: L1 cache
* Description: New cache controller to handle BRAM delay properly
******************************************************************************/

module L1cache #(
parameter STATUS_BITS           = 2,
          COHERENCE_BITS        = 2,
          OFFSET_BITS           = 2,
          DATA_WIDTH            = 32,
          NUMBER_OF_WAYS        = 1,
          REPLACEMENT_MODE_BITS = 1,
	      ADDRESS_WIDTH         = 32,
	      INDEX_BITS            = 6,
	      MSG_BITS              = 3,
          CORE                  = 0,
          CACHE_NO              = 0
)(
clock, reset,
read, write, invalidate, flush,
replacement_mode,
address,
data_in,
report,
data_out,
out_address,
ready,
valid,

mem2cache_msg,
mem2cache_data,
mem2cache_address,
cache2mem_msg,
cache2mem_data,
cache2mem_address,

coherence_msg_in,
coherence_address,
coherence_msg_out,
coherence_data
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
localparam BLOCK_WIDTH    = DATA_WIDTH*WORDS_PER_LINE;
localparam MBITS          = COHERENCE_BITS + STATUS_BITS;
localparam TAG_BITS       = ADDRESS_WIDTH - OFFSET_BITS - INDEX_BITS;
localparam LINE_WIDTH     = BLOCK_WIDTH + TAG_BITS + MBITS;
localparam WAY_BITS       = (NUMBER_OF_WAYS > 1) ? log2(NUMBER_OF_WAYS) : 0;
localparam CACHE_DEPTH    = 1 << INDEX_BITS;
localparam BUS_WIDTH      = BLOCK_WIDTH + MBITS;

localparam IDLE            = 0,
           RESET           = 1,
		   WAIT_FOR_ACCESS = 2,
		   CACHE_ACCESS    = 3,
           READ_STATE      = 4,
           WRITE_BACK      = 5,
           WAIT            = 6,
		   UPDATE          = 7,
           WB_WAIT         = 8,
		   SRV_FLUSH_REQ   = 9,
		   WAIT_FLUSH_REQ  = 10,
		   SRV_INVLD_REQ   = 11,
		   WAIT_INVLD_REQ  = 12,
		   WAIT_WS_ENABLE  = 13;

localparam NO_COHERENCE_OP     = 0,
           BRAM_ACCESS         = 1,
           HANDLE_COH_REQ      = 2,
           WAIT_FOR_CONTROLLER = 3;

`include "./params.v"

input clock, reset;
input read, write, invalidate, flush;
input [REPLACEMENT_MODE_BITS-1 : 0] replacement_mode;
input [ADDRESS_WIDTH-1 : 0] address;
input [DATA_WIDTH-1 : 0] data_in;
input report;
output [DATA_WIDTH-1 : 0] data_out;
output [ADDRESS_WIDTH-1 : 0] out_address;
output ready;
output valid;

input [MSG_BITS-1 : 0] mem2cache_msg;
input [BUS_WIDTH-1 : 0] mem2cache_data;
input [ADDRESS_WIDTH-1 : 0] mem2cache_address;
output [MSG_BITS-1 : 0] cache2mem_msg;
output [BUS_WIDTH-1 : 0] cache2mem_data;
output [ADDRESS_WIDTH-1 : 0] cache2mem_address;

input [MSG_BITS-1 : 0] coherence_msg_in;
input [ADDRESS_WIDTH-1 : 0] coherence_address;
output [MSG_BITS-1 : 0] coherence_msg_out;
output [BUS_WIDTH-1 : 0] coherence_data;

genvar i;
integer j, k;

reg [3:0] state, save_state;
reg [1:0] coh_state;
reg [INDEX_BITS-1 : 0] reset_counter;
reg [ADDRESS_WIDTH-1 : 0] REQ1_address, REQ2_address;
reg [DATA_WIDTH-1 : 0] REQ1_data, REQ2_data;
reg REQ1_read, REQ1_write, REQ1_flush, REQ1_invalidate, REQ2_read, REQ2_write,
    REQ2_flush, REQ2_invalidate, MEM_flush;
reg [ADDRESS_WIDTH-1 : 0] MEM_address;
reg [LINE_WIDTH-1 : 0] r_line_out;
reg [LINE_WIDTH-1 : 0] r_coherence_line;
reg [LINE_WIDTH-1 : 0] r_flush_line_out;
reg [WAY_BITS-1 : 0] r_matched_way, r_flush_matched_way;
reg r_valid_read, r_dirty_bit;
reg [MSG_BITS-1 : 0] r_cache2mem_msg, save_msg;
reg [BUS_WIDTH-1 : 0] r_cache2mem_data, save_data;
reg [ADDRESS_WIDTH-1 : 0] r_cache2mem_address, save_address;
reg [DATA_WIDTH-1 : 0] r_words_from_mem [WORDS_PER_LINE-1 : 0];
reg switch_state;
reg [TAG_BITS-1 : 0] flush_req_tag;
reg [BUS_WIDTH-1 : 0] r_coherence_data;
reg [MSG_BITS-1 : 0] r_coherence_msg_out;
reg r_coh_valid_read, r_flush_valid_read, r_flush_dirty_bit;
reg [WAY_BITS-1 : 0] r_coh_matched_way;

wire i_reset;
wire [NUMBER_OF_WAYS-1 : 0] we0, we1;
wire [LINE_WIDTH-1 : 0] data_in0, data_in1;
wire [ADDRESS_WIDTH-1 : 0] address_in0, address_in1;
wire [LINE_WIDTH-1 : 0] data_out0 [NUMBER_OF_WAYS-1 : 0];
wire [LINE_WIDTH-1 : 0] data_out1 [NUMBER_OF_WAYS-1 : 0];
wire [TAG_BITS-1 : 0] tag_out0 [NUMBER_OF_WAYS-1 : 0];
wire [TAG_BITS-1 : 0] tag_out1 [NUMBER_OF_WAYS-1 : 0];
wire [NUMBER_OF_WAYS-1 : 0] valid_line0, valid_line1;
wire [NUMBER_OF_WAYS-1 : 0] tag_match, coh_tag_match;

wire [INDEX_BITS-1 : 0] address_index;
wire [TAG_BITS-1 : 0] tag_in, coh_tag_in;
wire [WAY_BITS-1 : 0] decoded_tag_match, decoded_coh_tag_match;
wire valid_tag_match, valid_coh_tag_match;
wire [LINE_WIDTH-1 : 0] line_out;
wire [LINE_WIDTH-1 : 0] coh_line_out;
wire valid_bit, dirty_bit, hit, stall;
wire [COHERENCE_BITS-1 : 0] curr_coherence_bits, coh_bits_from_mem;
wire [TAG_BITS-1 : 0] curr_tag, REQ1_tag;
wire [INDEX_BITS-1 : 0] REQ1_index, REQ2_index, replace_index;
wire accept_flush_req;
wire [OFFSET_BITS-1 : 0] zero_offset = 0;
wire [LINE_WIDTH-1 : 0] new_line;
wire [LINE_WIDTH-1 : 0] coh_new_line;
wire write_line, flush_line, invalidate_line;
wire [DATA_WIDTH-1 : 0] w_words [WORDS_PER_LINE-1 : 0];
wire [DATA_WIDTH-1 : 0] line_out_words [WORDS_PER_LINE-1 : 0];
wire [BLOCK_WIDTH-1 : 0] w_words_concat, new_data, new_data2;
wire [NUMBER_OF_WAYS-1 : 0] replace_way_encoded, ways_in_use;
wire [WAY_BITS-1 : 0] replace_way, current_access;
wire valid_replace_way, access_valid;
wire coh_write, coh_flush, coh_invalidate;
wire coh_dirty_line;
wire accept_coherence_op, coherence_action_required;
wire [INDEX_BITS-1 : 0] coherence_index;

generate
	for(i=0; i<NUMBER_OF_WAYS; i=i+1)begin : BRAM
		dual_port_ram #(LINE_WIDTH, ADDRESS_WIDTH, INDEX_BITS, "OLD_DATA") 
		    way_bram(clock, we0[i], we1[i], data_in0, data_in1,
			address_in0, address_in1, data_out0[i], data_out1[i]);
	end
endgenerate

//Instantiate one-hot decoders
generate
if(NUMBER_OF_WAYS > 1)begin
one_hot_decoder #(NUMBER_OF_WAYS) 
    decoder_1 (tag_match, decoded_tag_match, valid_tag_match);
one_hot_decoder #(NUMBER_OF_WAYS) 
    decoder_2 (replace_way_encoded, replace_way, valid_replace_way);
one_hot_decoder #(NUMBER_OF_WAYS) 
    decoder_3 (coh_tag_match, decoded_coh_tag_match, valid_coh_tag_match);
end
else begin
    assign decoded_tag_match     = 0;
    assign valid_tag_match       = tag_match;
    assign replace_way           = 0;
    assign valid_replace_way     = replace_way_encoded;
    assign decoded_coh_tag_match = 0;
    assign valid_coh_tag_match   = coh_tag_match;
end
endgenerate

//Instantiate replacement controller
generate
if(NUMBER_OF_WAYS > 1)
replacement_controller #(NUMBER_OF_WAYS, INDEX_BITS) 
	replace_inst(clock, i_reset, ways_in_use, replace_index, replacement_mode, 
	current_access, access_valid, report, replace_way_encoded);
else
    assign replace_way_encoded = 0;
endgenerate

generate
	for(i=0; i<NUMBER_OF_WAYS; i=i+1)begin:W_EN
		assign we0[i] = (state == RESET) ? 1 
		              : write_line & (i==r_matched_way) ? 1
					  : (invalidate_line|flush_line) & ~MEM_flush & (i==r_matched_way) ? 1
                      : flush_line & MEM_flush & (i==r_flush_matched_way) ? 1
		              : 0;
		assign we1[i] = (state==CACHE_ACCESS) & REQ1_write & (i==decoded_tag_match)
                        & valid_tag_match & ~MEM_flush & (curr_coherence_bits != SHARED) ? 1
                      : (coh_write|coh_invalidate|coh_flush) & (i==r_coh_matched_way) ? 1 
                      : 0;
	end
	for(i=0; i<NUMBER_OF_WAYS; i=i+1)begin: TAGS0
		assign tag_out0[i]    = data_out0[i][BLOCK_WIDTH +: TAG_BITS];
		assign valid_line0[i] = data_out0[i][LINE_WIDTH-1];
		assign tag_match[i]   = (tag_out0[i] == tag_in) & valid_line0[i]; 
	end
	for(i=0; i<NUMBER_OF_WAYS; i=i+1)begin: TAGS1
		assign tag_out1[i]      = data_out1[i][BLOCK_WIDTH +: TAG_BITS];
		assign valid_line1[i]   = data_out1[i][LINE_WIDTH-1];
		assign coh_tag_match[i] = (tag_out1[i] == coh_tag_in) & valid_line1[i];
    end
endgenerate

assign i_reset      = reset | (state == RESET);
assign ways_in_use  = valid_line0;

assign data_in0    = (state == RESET) ? 0 
                   : write_line ? new_line
				   : invalidate_line ? {{(MBITS){1'b0}}, 
				     r_line_out[0 +: (BLOCK_WIDTH+TAG_BITS)]}
                   : 0;


assign address_in0 = (state == RESET) ? reset_counter 
                   : (state == IDLE) ? address_index
                   : (state == CACHE_ACCESS) & hit ? address_index
                   : accept_flush_req ? mem2cache_address[OFFSET_BITS +: INDEX_BITS]
                   : (state == WAIT_FOR_ACCESS) ? REQ2_index
				   : (write_line|invalidate_line) ? REQ1_index
				   : (flush_line & MEM_flush) ? MEM_address[OFFSET_BITS +: INDEX_BITS]
				   : (flush_line & REQ1_flush) ? REQ1_index
                   : REQ1_index;

assign data_in1 = (state==CACHE_ACCESS) & REQ1_write ? 
				  (curr_coherence_bits == EXCLUSIVE) ?
				  {2'b11, MODIFIED, curr_tag, w_words_concat}
				: {2'b11, curr_coherence_bits, curr_tag, w_words_concat}
                : (coh_write|coh_invalidate|coh_flush) ? coh_new_line
                : 0;
assign address_in1 = (state==CACHE_ACCESS) & REQ1_write ? REQ1_index       
                   : accept_coherence_op ? coherence_index 
                   : (coh_write|coh_invalidate|coh_flush) ? coherence_index
                   : 0;
assign write_line = ((mem2cache_msg == MEM_SENT) & (r_cache2mem_address == mem2cache_address)
                    & ((coh_state == NO_COHERENCE_OP) | (coherence_msg_in == C_NO_REQ))) ? 1
                  : (state == WAIT_WS_ENABLE) & (coherence_msg_in == ENABLE_WS) ? 1
                  : 0;

generate
    for(i=0; i<WORDS_PER_LINE; i=i+1)begin : NEW_DATA
        assign new_data[i*DATA_WIDTH +: DATA_WIDTH] = 
            (i==REQ1_address[0+:OFFSET_BITS]) ? REQ1_data 
            : mem2cache_data[i*DATA_WIDTH +: DATA_WIDTH];
    end
    for(i=0; i<WORDS_PER_LINE; i=i+1)begin : NEW_DATA2
        assign new_data2[i*DATA_WIDTH +: DATA_WIDTH] = 
            (i==REQ1_address[0+:OFFSET_BITS]) ? REQ1_data 
            : r_line_out[i*DATA_WIDTH +: DATA_WIDTH];
    end
endgenerate

assign new_line = (mem2cache_msg==MEM_SENT & REQ1_write) ? 
                  {2'b11, MODIFIED, REQ1_tag, new_data}
                : (mem2cache_msg==MEM_SENT & REQ1_read) ? 
                  {2'b10, coh_bits_from_mem, REQ1_tag, mem2cache_data[0+:BLOCK_WIDTH]}
                : (state == WAIT_WS_ENABLE) & (coherence_msg_in == ENABLE_WS) ?
                  {2'b11, MODIFIED, REQ1_tag, new_data2} 
				: 0;
				
assign flush_line = (state==WAIT_FLUSH_REQ) & (mem2cache_msg==MEM_NO_MSG) &
                    (~MEM_flush & r_valid_read | MEM_flush & r_flush_valid_read) &
                    (coherence_msg_in == C_NO_REQ | coh_state == NO_COHERENCE_OP) ? 1 : 0;

assign invalidate_line = ((state == WB_WAIT) & (mem2cache_msg == MEM_READY) & 
                         ((coherence_msg_in == C_NO_REQ) | (coh_state == NO_COHERENCE_OP))) ? 1
					   : (state == WAIT_INVLD_REQ & mem2cache_msg == M_RECV & 
                         r_valid_read &
					     (coherence_msg_in == C_NO_REQ | coh_state == NO_COHERENCE_OP)) ? 1
					   : 0;

assign address_index   = address[OFFSET_BITS +: INDEX_BITS];
assign REQ1_tag        = REQ1_address[ADDRESS_WIDTH-1 -: TAG_BITS];
assign REQ1_index      = REQ1_address[OFFSET_BITS +: INDEX_BITS];
assign REQ2_index      = REQ2_address[OFFSET_BITS +: INDEX_BITS];
assign coherence_index = coherence_address[OFFSET_BITS +: INDEX_BITS];

assign tag_in   = (state == CACHE_ACCESS) ? MEM_flush ? flush_req_tag 
                : REQ1_tag : 0;
assign line_out = valid_tag_match ? data_out0[decoded_tag_match]
                : data_out0[replace_way]; 
assign valid_bit = line_out[LINE_WIDTH-1];
assign dirty_bit = line_out[LINE_WIDTH-2];
assign curr_tag  = (state == CACHE_ACCESS) ? line_out[BLOCK_WIDTH +: TAG_BITS]
                 : r_line_out[BLOCK_WIDTH +: TAG_BITS];

assign curr_coherence_bits = line_out[LINE_WIDTH-1-STATUS_BITS -: COHERENCE_BITS];

assign replace_index = (state == RESET) ? reset_counter : REQ1_index;


assign hit = ((REQ1_write|REQ1_read|REQ1_flush|REQ1_invalidate|MEM_flush) & 
             valid_tag_match) ? 1 : 0;
			   
assign stall = (((REQ1_index == REQ2_index & (REQ2_write|REQ2_read|REQ2_flush|REQ2_invalidate)) |
			   ((REQ1_index == address_index) & (read|write|flush|invalidate))) & REQ1_write) ? 1
             : ~((coherence_msg_in==C_NO_REQ) | (coherence_msg_in==ENABLE_WS)) & 
			   (((address_index == coherence_index) & (read|write|flush|invalidate)) |
			   ((REQ2_index == coherence_index) & (REQ2_read|REQ2_write|REQ2_flush|
			   REQ2_invalidate)) |
			   ((REQ1_index == coherence_index) & (REQ1_read|REQ1_write|REQ1_flush|
			   REQ1_invalidate))) ? 1
             : 0;

assign accept_flush_req = ((mem2cache_msg == REQ_FLUSH) & (state != UPDATE) & 
                          (state != WAIT_FOR_ACCESS) & (state != CACHE_ACCESS) & 
                          (state != SRV_FLUSH_REQ) & (state != WAIT_FLUSH_REQ) & 
                          ~((state == IDLE) & (read|write|invalidate|flush)));

assign coh_bits_from_mem = mem2cache_data[BLOCK_WIDTH +: COHERENCE_BITS];

generate
	for(i=0; i<WORDS_PER_LINE; i=i+1)begin: W_WORDS
		assign w_words[i] = (state==CACHE_ACCESS) & REQ1_write & 
		                    (i==REQ1_address[0+:OFFSET_BITS]) ? REQ1_data
						  : line_out_words[i];
		assign w_words_concat[i*DATA_WIDTH +: DATA_WIDTH] = w_words[i];
	end
	for(i=0; i<WORDS_PER_LINE; i=i+1)begin: LINE_OUT_WORDS
		assign line_out_words[i] = line_out[i*DATA_WIDTH +: DATA_WIDTH];
	end
endgenerate

assign current_access = write_line ? r_matched_way : decoded_tag_match;
assign access_valid   = write_line | (valid_tag_match & (state == CACHE_ACCESS) & ~MEM_flush);

assign accept_coherence_op = (state != RESET) & coherence_action_required & 
                             (coh_state == NO_COHERENCE_OP) &
                             ~((REQ1_index == coherence_index) & 
                             (REQ1_write|write_line|flush_line|invalidate_line));

assign coherence_action_required = ((coherence_msg_in == C_RD_BCAST) | 
                                   (coherence_msg_in == C_FLUSH_BCAST) |
                                   (coherence_msg_in == C_INVLD_BCAST) |
                                   (coherence_msg_in == C_WS_BCAST) |
                                   (coherence_msg_in == C_RFO_BCAST)) ? 1 : 0;

assign coh_tag_in = coherence_address[ADDRESS_WIDTH-1 -: TAG_BITS];
assign coh_line_out = valid_coh_tag_match ? data_out1[decoded_coh_tag_match] : 0;

assign coh_dirty_line = r_coherence_line[LINE_WIDTH-2];

assign coh_new_line   = (coh_state == HANDLE_COH_REQ) ? 
                        (coherence_msg_in == C_RD_BCAST) & r_coh_valid_read & coh_dirty_line ?
                        {{(MBITS){1'b0}},r_coherence_line
                        [0+:(BLOCK_WIDTH+TAG_BITS)]}
                      : (coherence_msg_in == C_RD_BCAST) & r_coh_valid_read & ~coh_dirty_line ?
                        {r_coherence_line[LINE_WIDTH-1 -: STATUS_BITS], SHARED,
                        r_coherence_line[0+:(BLOCK_WIDTH+TAG_BITS)]}
                      : (coherence_msg_in == C_WS_BCAST) & r_coh_valid_read ?
                        {{(MBITS){1'b0}},r_coherence_line
                        [0+:(BLOCK_WIDTH+TAG_BITS)]}
                      : (coherence_msg_in == C_RFO_BCAST | coherence_msg_in == C_INVLD_BCAST) & 
                        r_coh_valid_read ?
                        {{(MBITS){1'b0}},r_coherence_line
                        [0+:(BLOCK_WIDTH+TAG_BITS)]}
                      : 0 : 0;

assign coh_invalidate = (coh_state == HANDLE_COH_REQ) ? 
                        (coherence_msg_in == C_RD_BCAST) & r_coh_valid_read & coh_dirty_line ? 1
                      : (coherence_msg_in == C_WS_BCAST) & r_coh_valid_read ? 1
                      : (coherence_msg_in == C_WS_BCAST) & r_coh_valid_read ? 1
                      : (coherence_msg_in == C_RFO_BCAST) & r_coh_valid_read ? 1
                      : (coherence_msg_in == C_INVLD_BCAST) & r_coh_valid_read ? 1
                      : 0 : 0;

assign coh_write = (coh_state == HANDLE_COH_REQ) & (coherence_msg_in == C_RD_BCAST) &
                   r_coh_valid_read & ~coh_dirty_line ? 1
                 : 0;

assign coh_flush = (coh_state == HANDLE_COH_REQ) & (coherence_msg_in == C_FLUSH_BCAST) &
                   r_coh_valid_read ? 1
                 : 0;


// Cache controller //
always @(posedge clock)begin
	if(reset & (state !=RESET))begin
		reset_counter   <= 0;
		switch_state    <= 0;
		save_address    <= 0;
		save_data       <= 0;
		save_msg        <= 0;
		REQ1_address    <= 0;
		REQ1_data       <= 0;
		REQ1_read       <= 0;
		REQ1_write      <= 0;
		REQ1_flush      <= 0;
		REQ1_invalidate <= 0;
		REQ2_address    <= 0;
		REQ2_data       <= 0;
		REQ2_read       <= 0;
		REQ2_write      <= 0;
		REQ2_flush      <= 0;
		REQ2_invalidate <= 0;
        flush_req_tag   <= 0;
        MEM_flush       <= 0;
		r_cache2mem_address <= 0;
		r_cache2mem_data    <= 0;
		r_cache2mem_msg     <= NO_REQ;
		r_valid_read        <= 0;
        r_dirty_bit         <= 0;
        r_matched_way       <= 0;
        r_line_out          <= 0;
		r_flush_valid_read  <= 0;
        r_flush_dirty_bit   <= 0;
        r_flush_matched_way <= 0;
        r_flush_line_out    <= 0;
		state <= RESET;
	end
	else begin
        if(accept_flush_req)begin
            MEM_address   <= mem2cache_address;
            MEM_flush     <= 1;
            flush_req_tag <= mem2cache_address[ADDRESS_WIDTH-1 -: TAG_BITS];
            save_msg      <= cache2mem_msg;
            save_address  <= cache2mem_address;
            save_data     <= cache2mem_data;
			save_state    <= state;
            state         <= CACHE_ACCESS;
        end
        else begin
		    case(state)
		    	RESET:begin
		    		if(reset_counter < CACHE_DEPTH-1)
                        reset_counter <= reset_counter + 1;
                    else if((reset_counter == CACHE_DEPTH-1) & ~reset) begin
                        reset_counter <= 0;
                        state         <= IDLE;
                    end
		    	end	
		    	IDLE:begin
		    		if((address_index == coherence_index) & (read|write|flush|invalidate) & 
                    (coherence_msg_in != C_NO_REQ))begin
                        REQ2_read       <= read;
		    			REQ2_write      <= write;
		    			REQ2_flush      <= flush;
		    			REQ2_invalidate <= invalidate;
		    			REQ2_address    <= address;
		    			REQ2_data       <= data_in;
		    			state <= WAIT_FOR_ACCESS;
		    		end
		    		else begin
		    			REQ1_address    <= address;
		    			REQ1_data       <= data_in;
		    			REQ1_read       <= read;
		    			REQ1_write      <= write;
		    			REQ1_flush      <= flush;
		    			REQ1_invalidate <= invalidate;
		    			state <= (read|write|flush|invalidate) ? CACHE_ACCESS : IDLE;
		    		end
		    	end
		    	CACHE_ACCESS:begin
                    if(MEM_flush)begin
                        r_flush_line_out    <= line_out;
                        r_flush_matched_way <= valid_tag_match ? decoded_tag_match
                                             : replace_way;
                        r_flush_valid_read  <= valid_tag_match;
                        r_flush_dirty_bit   <= dirty_bit;
                        state <= SRV_FLUSH_REQ;
                    end
                    else begin
		    		    r_line_out    <= line_out;
		    		    r_matched_way <= valid_tag_match ? decoded_tag_match
                                       : replace_way; 
		    		    r_valid_read  <= valid_tag_match;
                        r_dirty_bit   <= dirty_bit;
		    		    if(hit)begin
                            if(REQ1_write & (curr_coherence_bits == SHARED))begin
                                REQ2_address        <= address;
		    		    		REQ2_data           <= data_in;
		    		    		REQ2_read           <= read;
		    		    		REQ2_write          <= write;
		    		    		REQ2_flush          <= flush;
		    		    		REQ2_invalidate     <= invalidate;
                                r_cache2mem_address <= (REQ1_address >> OFFSET_BITS)
                                                        << OFFSET_BITS;
                                r_cache2mem_msg     <= WS_BCAST;
		    		    		state <= WAIT_WS_ENABLE;
                            end
		    		    	else if(stall)begin
		    		    		REQ1_data       <= 0;
		    		    		REQ1_read       <= 0;
		    		    		REQ1_write      <= 0;
		    		    		REQ1_flush      <= 0;
		    		    		REQ1_invalidate <= 0;
		    		    		REQ2_address    <= address;
		    		    		REQ2_data       <= data_in;
		    		    		REQ2_read       <= read;
		    		    		REQ2_write      <= write;
		    		    		REQ2_flush      <= flush;
		    		    		REQ2_invalidate <= invalidate;
		    		    		state           <= WAIT_FOR_ACCESS;
		    		    	end
                            else begin
                                REQ1_read       <= read;
                                REQ1_write      <= write;
                                REQ1_flush      <= flush;
                                REQ1_invalidate <= invalidate;
                                REQ1_address    <= address;
                                REQ1_data       <= data_in;
                                if(REQ1_flush)begin
		    		    		   state <= SRV_FLUSH_REQ;
                                end
                                else if(REQ1_invalidate)begin
		    		    			state <= SRV_INVLD_REQ;
                                end
                                else
                                    state <= (read|write|flush|invalidate) ? 
                                             CACHE_ACCESS : IDLE;
                            end
		    		    end
		    		    else begin
		    	            REQ2_read       <= read;
		    		    	REQ2_write      <= write;
		    		    	REQ2_flush      <= flush;
		    		    	REQ2_invalidate <= invalidate;
		    		    	REQ2_address    <= address;
		    		    	REQ2_data       <= data_in;	
                            if(REQ1_flush)begin
                                state <= SRV_FLUSH_REQ;
                            end
                            else if(REQ1_invalidate)begin
                                state <= SRV_INVLD_REQ;
                            end
                            else
                                state <= (dirty_bit & valid_bit) ? WRITE_BACK : READ_STATE;
		    		    end
                    end
		    	end
                READ_STATE:begin
                    r_cache2mem_msg     <= REQ1_write ? RFO_BCAST : R_REQ;
                    r_cache2mem_address <= (REQ1_address >> OFFSET_BITS) << OFFSET_BITS;
                    r_cache2mem_data    <= 0;
                    state <= WAIT;
                end
                WAIT:begin
                    if(mem2cache_msg == MEM_SENT & (coherence_msg_in == C_NO_REQ
                    | coh_state == NO_COHERENCE_OP) & r_cache2mem_address == 
                    mem2cache_address)begin
                        r_cache2mem_msg	    <= NO_REQ;
                        r_cache2mem_address <= 0;
		    			for(j=0; j<WORDS_PER_LINE; j=j+1)begin
		    				r_words_from_mem[j] <= mem2cache_data[j*DATA_WIDTH 
                                                   +: DATA_WIDTH];
		    			end
		    			state <= UPDATE;
                    end
                    else
                        state <= WAIT;
                end
                UPDATE:begin
                    state <= WAIT_FOR_ACCESS;
                end
                WAIT_FOR_ACCESS:begin
                    if(stall)begin
		    			REQ1_data       <= 0;
		    			REQ1_read       <= 0;
		    			REQ1_write      <= 0;
		    			REQ1_flush      <= 0;
		    			REQ1_invalidate <= 0;
                        state <= WAIT_FOR_ACCESS;
                    end
                    else begin
                        REQ1_address    <= REQ2_address;
		    			REQ1_data       <= REQ2_data;
		    			REQ1_read       <= REQ2_read;
		    			REQ1_write      <= REQ2_write;
		    			REQ1_flush      <= REQ2_flush;
		    			REQ1_invalidate <= REQ2_invalidate;
                        REQ2_address    <= 0;
		    			REQ2_data       <= 0;
		    			REQ2_read       <= 0;
		    			REQ2_write      <= 0;
		    			REQ2_flush      <= 0;
		    			REQ2_invalidate <= 0;
                        state <= (REQ2_read|REQ2_write|REQ2_flush|REQ2_invalidate)
                                 ? CACHE_ACCESS : IDLE;
                    end
                end
                WRITE_BACK:begin
                    r_cache2mem_msg     <= WB_REQ;
                    r_cache2mem_address <= {curr_tag, REQ1_index, zero_offset};
                    r_cache2mem_data    <= {r_line_out[LINE_WIDTH-1 -: (STATUS_BITS
                                           +COHERENCE_BITS)], r_line_out[0 +:
                                           DATA_WIDTH*WORDS_PER_LINE]};
                    state <= WB_WAIT;
                end
                WB_WAIT:begin
                    if(mem2cache_msg == MEM_READY & (coherence_msg_in == C_NO_REQ
                    | coh_state == NO_COHERENCE_OP))begin
		    			r_cache2mem_msg     <= NO_REQ;
		    			r_cache2mem_address <= 0;
		    			r_cache2mem_data    <= 0;
                        state <= (REQ1_read | REQ1_write) ? READ_STATE : CACHE_ACCESS;
                    end
                    else
                        state <= WB_WAIT;
                end
		    	SRV_FLUSH_REQ:begin
		    		r_cache2mem_msg     <= MEM_flush & ~(r_flush_valid_read & 
                                           r_flush_dirty_bit) ? NO_FLUSH : FLUSH;
		    		r_cache2mem_address <= MEM_flush ? MEM_address 
		    		                     : (REQ1_address >> OFFSET_BITS) << OFFSET_BITS;
		    		r_cache2mem_data    <= MEM_flush ?
                                           r_flush_valid_read & r_flush_dirty_bit ? 
                                           {r_flush_line_out[LINE_WIDTH-1 -: (STATUS_BITS+
                                           COHERENCE_BITS)], r_flush_line_out
		    							   [0 +: DATA_WIDTH*WORDS_PER_LINE]} : 0
                                         : r_valid_read & r_dirty_bit ? 
                                           {r_line_out[LINE_WIDTH-1 -: (STATUS_BITS+
                                           COHERENCE_BITS)], r_line_out
		    							   [0 +: DATA_WIDTH*WORDS_PER_LINE]} : 0;
		    		switch_state <= 0;
		    		state        <= WAIT_FLUSH_REQ;
		    	end
		    	WAIT_FLUSH_REQ:begin
		    		if(mem2cache_msg == M_RECV & (coherence_msg_in == C_NO_REQ 
                    | coh_state == NO_COHERENCE_OP))begin
                        r_cache2mem_msg     <= NO_REQ;
                        r_cache2mem_address <= 0;
                        r_cache2mem_data    <= 0;
		    			switch_state <= 1;
		    		end
		    		else if(mem2cache_msg==MEM_NO_MSG & (coherence_msg_in == C_NO_REQ 
                    | coh_state == NO_COHERENCE_OP) & (MEM_flush|switch_state))begin
		    			if(MEM_flush)begin
                            MEM_flush <= 0;
		    				if(save_state==WB_WAIT & r_flush_valid_read & save_address
		    				[OFFSET_BITS +: INDEX_BITS] == MEM_address[OFFSET_BITS 
		    				+: INDEX_BITS])begin
		    					r_cache2mem_msg     <= NO_REQ;
		    					r_cache2mem_address <= 0;
		    					r_cache2mem_data    <= 0;
                                r_matched_way <= r_flush_matched_way;
		    					state <= (REQ1_read|REQ1_write) ? READ_STATE 
                                       : CACHE_ACCESS;
		    				end
		    				else begin
                                if(save_state==WAIT & r_flush_valid_read & save_address
								[OFFSET_BITS +: INDEX_BITS] == MEM_address[OFFSET_BITS 
								+: INDEX_BITS])begin
									r_matched_way <= r_flush_matched_way;
								end
		    					r_cache2mem_msg     <= save_msg;
		    					r_cache2mem_address <= save_address;
		    					r_cache2mem_data    <= save_data;
		    					state <= save_state;
		    				end
		    			end
		    			else begin
		    				r_cache2mem_msg     <= NO_REQ;
		    				r_cache2mem_address <= 0;
		    				r_cache2mem_data    <= 0;
		    				state <= IDLE;
		    			end
		    		end
		    		else
		    			state <= WAIT_FLUSH_REQ;
		    	end
		    	SRV_INVLD_REQ:begin
		    		r_cache2mem_msg     <= INVLD;
		    		r_cache2mem_address <= (REQ1_address >> OFFSET_BITS) << OFFSET_BITS;
		    		r_cache2mem_data    <= r_valid_read & r_dirty_bit ?
                                           {r_line_out[LINE_WIDTH-1 -: 
		    		                       (STATUS_BITS+COHERENCE_BITS)], r_line_out
		    							   [0 +: DATA_WIDTH*WORDS_PER_LINE]} : 0;
		    		switch_state <= 0;
		    		state        <= WAIT_INVLD_REQ;
		    	end
		    	WAIT_INVLD_REQ:begin
		    		if(mem2cache_msg == M_RECV & (coherence_msg_in == C_NO_REQ |
                    coh_state == NO_COHERENCE_OP))begin
		    			r_cache2mem_msg     <= NO_REQ;
		    			r_cache2mem_address <= 0;
		    			r_cache2mem_data    <= 0;
		    			switch_state        <= 1;
		    		end
		    		else if(((mem2cache_msg == MEM_NO_MSG) & 
                    (coherence_msg_in == C_NO_REQ | coh_state == NO_COHERENCE_OP)) & 
                    switch_state)begin
		    			state <= IDLE;
		    		end
		    	end
		    	WAIT_WS_ENABLE:begin
		    		if(coherence_msg_in == ENABLE_WS)begin
                            r_cache2mem_msg     <= NO_REQ;
		    				r_cache2mem_address <= 0;
		    				r_cache2mem_data    <= 0;
                            state <= WAIT_FOR_ACCESS;
                        end
                        else
                            state <= WAIT_WS_ENABLE;
		    	end
		    	default: state <= IDLE;
		    endcase
        end
	end
end


// controller for coherence operations
always @(posedge clock)begin
    if(reset)begin
        r_coherence_msg_out <= C_NO_RESP;
        r_coherence_line    <= 0;
        r_coherence_data    <= 0;
        r_coh_matched_way   <= 0;
        r_coh_valid_read    <= 0;
        coh_state           <= NO_COHERENCE_OP;
    end
    else begin
        case(coh_state)
            NO_COHERENCE_OP:begin
                r_coherence_msg_out <= C_NO_RESP;
                r_coherence_data    <= 0;
                if(accept_coherence_op)begin
                    coh_state <= BRAM_ACCESS;
                end
            end
            BRAM_ACCESS:begin
                r_coherence_line    <= coh_line_out;
                r_coh_matched_way   <= decoded_coh_tag_match;
                r_coh_valid_read    <= valid_coh_tag_match;
                coh_state <= HANDLE_COH_REQ;
            end
            HANDLE_COH_REQ:begin
                coh_state <= WAIT_FOR_CONTROLLER;
                case(coherence_msg_in)
                    C_RD_BCAST:begin
                        if(r_coh_valid_read & coh_dirty_line)begin
                            r_coherence_msg_out <= C_WB;
                            r_coherence_data    <= {r_coherence_line[LINE_WIDTH-1 -:
                                                   (STATUS_BITS+COHERENCE_BITS)],
                                                   r_coherence_line[0 +: DATA_WIDTH
                                                   *WORDS_PER_LINE]};
                        end
                        else if(r_coh_valid_read) begin
                            r_coherence_msg_out <= C_EN_ACCESS;
                            r_coherence_data    <= 0;
                        end
                        else
                            r_coherence_msg_out <= C_EN_ACCESS;
                    end
                    C_WS_BCAST:begin
                        r_coherence_msg_out <= C_EN_ACCESS;
                    end
                    C_RFO_BCAST:begin
                        if(r_coh_valid_read & coh_dirty_line)begin
                            r_coherence_msg_out <= C_WB;
                            r_coherence_data    <= {r_coherence_line[LINE_WIDTH-1 -:
                                                   (STATUS_BITS+COHERENCE_BITS)],
                                                   r_coherence_line[0 +: DATA_WIDTH
                                                   *WORDS_PER_LINE]};
                        end
                        else
                            r_coherence_msg_out <= C_EN_ACCESS;
                    end
                    C_FLUSH_BCAST:begin
                        if(r_coh_valid_read & coh_dirty_line)begin
                            r_coherence_msg_out <= C_FLUSH;
                            r_coherence_data    <= {r_coherence_line[LINE_WIDTH-1 -:
                                                   (STATUS_BITS+COHERENCE_BITS)],
                                                   r_coherence_line[0 +: DATA_WIDTH
                                                   *WORDS_PER_LINE]};
                        end
                        else
                            r_coherence_msg_out <= C_EN_ACCESS;
                    end
                    C_INVLD_BCAST:begin
                        if(r_coh_valid_read & coh_dirty_line)begin
                            r_coherence_msg_out <= C_INVLD;
                            r_coherence_data    <= {r_coherence_line[LINE_WIDTH-1 -:
                                                   (STATUS_BITS+COHERENCE_BITS)],
                                                   r_coherence_line[0 +: DATA_WIDTH
                                                   *WORDS_PER_LINE]};
                        end
                        else
                            r_coherence_msg_out <= C_EN_ACCESS;
                    end
                    default:begin
                        r_coherence_msg_out <= C_NO_RESP;
                    end
                endcase
            end
            WAIT_FOR_CONTROLLER:begin
                if(coherence_msg_in == C_NO_REQ)begin
                    r_coherence_msg_out <= C_NO_RESP;
                    r_coherence_data    <= 0;
                    coh_state           <= NO_COHERENCE_OP;
                end
                else
                    coh_state <= WAIT_FOR_CONTROLLER;
            end
            default: coh_state <= NO_COHERENCE_OP;
        endcase
    end
end


// Drive outputs
assign ready = ((mem2cache_msg != REQ_FLUSH) & ~((flush & ((state == IDLE) |
               (state == CACHE_ACCESS))) | (state == SRV_FLUSH_REQ) | (state == WAIT_FLUSH_REQ)) 
			   & ~((invalidate & ((state == IDLE) | (state == CACHE_ACCESS))) | 
			   (state == SRV_INVLD_REQ) | (state == WAIT_INVLD_REQ)) & (state != RESET) & 
			   (~REQ1_flush & ~REQ1_invalidate & ~REQ2_flush & ~REQ2_invalidate) &
			   (reset | (state == IDLE) | ((state == CACHE_ACCESS) & hit & ~stall)) &
			   ~(REQ1_write & curr_coherence_bits == SHARED) & 
			   ~((address_index == coherence_index) & (coherence_msg_in != C_NO_REQ) & 
			   (read|write|invalidate|flush)) &
               ~(REQ1_index==coherence_index & (coherence_msg_in != C_NO_REQ) &
               (REQ1_read|REQ1_write|REQ1_flush|REQ1_invalidate)) &
               ~(REQ2_index==coherence_index & (coherence_msg_in != C_NO_REQ) &
               (REQ2_read|REQ2_write|REQ2_flush|REQ2_invalidate))
               ) ? 1 : 0;
			   
assign valid = (((state == CACHE_ACCESS) & hit) | (state == UPDATE)) & REQ1_read & ~MEM_flush;

assign data_out = ((state == CACHE_ACCESS) & hit & REQ1_read & ~MEM_flush) ? 
                  line_out_words[REQ1_address[0 +: OFFSET_BITS]]
                : (state == UPDATE) & REQ1_read ? r_words_from_mem[REQ1_address[0 +: OFFSET_BITS]]
				: 0;
				
assign cache2mem_address = r_cache2mem_address;
assign cache2mem_data    = r_cache2mem_data;
assign cache2mem_msg     = r_cache2mem_msg;
assign out_address       = REQ1_address;

assign coherence_msg_out = r_coherence_msg_out;
assign coherence_data    = r_coherence_data;



// Performance data
reg [31 : 0] cycles;

always @ (posedge clock) begin
    if (reset) begin
        cycles           <= 0;
    end
    else begin
        cycles           <= cycles + 1;
        /*if(report)begin
            $display ("\n----------------- L1 cach || cycles:%d ----------------", cycles);
            for(j=0; j<CACHE_DEPTH; j=j+1)begin
                $display("---------------------Set:%3d--------------------------", j);
                for(k=0; k<NUMBER_OF_WAYS; k=k+1)begin
                    if(k==0)
                        $display("Way:%1d ==> Status bits [%b]\t| Coherence bits [%b]\t| Tag [0x%h]\t| Data [0x%h]", k,
                        BRAM[0].way_bram.mem[j][LINE_WIDTH-1 -: STATUS_BITS],
                        BRAM[0].way_bram.mem[j][LINE_WIDTH-1-STATUS_BITS -: COHERENCE_BITS],
                        BRAM[0].way_bram.mem[j][LINE_WIDTH-1-STATUS_BITS-COHERENCE_BITS -: TAG_BITS],
                        BRAM[0].way_bram.mem[j][0 +: BLOCK_WIDTH]);
                    else if(k==1)
                        $display("Way:%1d ==> Status bits [%b]\t| Coherence bits [%b]\t| Tag [0x%h]\t| Data [0x%h]", k,
                        BRAM[1].way_bram.mem[j][LINE_WIDTH-1 -: STATUS_BITS],
                        BRAM[1].way_bram.mem[j][LINE_WIDTH-1-STATUS_BITS -: COHERENCE_BITS],
                        BRAM[1].way_bram.mem[j][LINE_WIDTH-1-STATUS_BITS-COHERENCE_BITS -: TAG_BITS],
                        BRAM[1].way_bram.mem[j][0 +: BLOCK_WIDTH]);
                    else if(k==2)
                        $display("Way:%1d ==> Status bits [%b]\t| Coherence bits [%b]\t| Tag [0x%h]\t| Data [0x%h]", k,
                        BRAM[2].way_bram.mem[j][LINE_WIDTH-1 -: STATUS_BITS],
                        BRAM[2].way_bram.mem[j][LINE_WIDTH-1-STATUS_BITS -: COHERENCE_BITS],
                        BRAM[2].way_bram.mem[j][LINE_WIDTH-1-STATUS_BITS-COHERENCE_BITS -: TAG_BITS],
                        BRAM[2].way_bram.mem[j][0 +: BLOCK_WIDTH]);
                    else
                        $display("Way:%1d ==> Status bits [%b]\t| Coherence bits [%b]\t| Tag [0x%h]\t| Data [0x%h]", k,
                        BRAM[3].way_bram.mem[j][LINE_WIDTH-1 -: STATUS_BITS],
                        BRAM[3].way_bram.mem[j][LINE_WIDTH-1-STATUS_BITS -: COHERENCE_BITS],
                        BRAM[3].way_bram.mem[j][LINE_WIDTH-1-STATUS_BITS-COHERENCE_BITS -: TAG_BITS],
                        BRAM[3].way_bram.mem[j][0 +: BLOCK_WIDTH]);
                end
                    $display("LRU=====>%b", replace_inst.lru_inst.lru_bram.mem[j]);
            end
        end*/
    end
end

endmodule
