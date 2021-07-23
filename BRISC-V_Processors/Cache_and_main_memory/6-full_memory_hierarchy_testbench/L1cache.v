/******************************************************************************
*	L1 cache
* - L1 cache instantiates sets
* - cache operates in a pipelined manner where every operation takes two cycles
*   to complete(on a cache hit).
******************************************************************************/ 
/******************************************************************************
* - Valid signal go high only for reads.
       
    * Coherence vesion *
* -  Use include file for localparam definitions for bus signals.
* - change bus widths to new bus format.
* - Replace FLUSH_C and INVLD_C messages with FLUSH and INVLD.
* - Add port for coherence and 'coherence_action_required signal'
* update controller for coherence.
*   - part of coherence is integrated to the main cache controller.
*   - coherence actions stall the normal cache operations.
    - Added WAIT_WS_ENABLE state and relevent logic around it.
    - Coherence state transitions when bringing up and writing to cache lines.
    - RFO_BCAST on write misses.
* - Update controller to send WS_BCAST and RFO_BCAST on main bus.
*
* - add 'accept_req_flush'
* - write separate controller for rest of the coherence operations.
* - update inputs to sets to handle coherence operations.
* - update main controller to stop writing SG0 to SG1 when coherence controller
*   is accessing the same index.
* - Added additional checks to prevent accidental state transitions while
*   cache is waiting for a response from L2, due to messages related to
*   coherence operations on mem2cache_msg bus.
* - changes made to ensure that the main FSM leaves waiting states while there
*   is a coherence request coming in but its not accepted because main
*   controller is waiting for something to be done to the same cache set.
******************************************************************************/ 

module L1cache #(
parameter STATUS_BITS           = 2,
          COHERENCE_BITS        = 2,
          OFFSET_BITS           = 2,
          DATA_WIDTH            = 8,
          NUMBER_OF_WAYS        = 4,
          REPLACEMENT_MODE_BITS = 1,       // Number of bits used to select replacement policy.
	      ADDRESS_WIDTH         = 12,
	      INDEX_BITS            = 4,
	      MSG_BITS              = 3,
          CORE                  = 0,
          CACHE_NO              = 0
) (
clock, reset,
read, write, invalidate, flush,
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
localparam TAG_BITS    = ADDRESS_WIDTH - OFFSET_BITS - INDEX_BITS;
localparam LINE_WIDTH  = WORDS_PER_LINE*DATA_WIDTH + TAG_BITS + COHERENCE_BITS + STATUS_BITS;    //(words_per_line*number_of_bits_per_word + number_of_tag_bits + coherence_bits + status_bits)
localparam WAY_BITS    = log2(NUMBER_OF_WAYS);
localparam CACHE_DEPTH = 1 << INDEX_BITS;
localparam BUS_WIDTH   = DATA_WIDTH*WORDS_PER_LINE + STATUS_BITS + COHERENCE_BITS;

localparam IDLE           = 0, 
	       CACHE_ACCESS   = 1,
    	   WRITE_BACK 	  = 2, 
	       WB_WAIT 	      = 3, 
	       READ_ST 	      = 4, 
	       WAIT 	      = 5, 
	       UPDATE 	      = 6,
	       UPDATE_DONE 	  = 7,
	       SRV_FLUSH_REQ  = 8,
	       WAIT_FLUSH_REQ = 9,
	       SRV_INVLD_REQ  = 10,
	       WAIT_INVLD_REQ = 11,
           WAIT_WS_ENABLE = 12;

localparam NO_COHERENCE_OP     = 0,
           HANDLE_COH_REQ      = 1,
           WAIT_FOR_CONTROLLER = 2;

`include "./params.v"
//`include "/home/sahanb/Documents/1-Projects/1-adaptive_cache/1-workspace/28-coherence/params.v"

input clock, reset;
input read, write, invalidate, flush;
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

// Performance data
reg [31 : 0] cycles;

always @ (posedge clock) begin
        if (reset) begin
                cycles           <= 0;
        end
        else begin
                cycles           <= cycles + 1;
                if (report) begin
                        $display ("\n------------------------ L1 cache Core:%1d Cache:%1d-----------------------", CORE, CACHE_NO);
                        //$display ("---------------------------------------------------------------------------------------");
                end
        end
end

// Internal wires and regs
wire [CACHE_DEPTH-1 : 0] write_set, read_set, flush_set, invalidate_set;
wire [LINE_WIDTH-1 : 0]  line_in [CACHE_DEPTH-1 : 0];
wire [TAG_BITS-1 : 0]    tag_in [CACHE_DEPTH-1 : 0];
wire [WAY_BITS-1 : 0]    way_select [CACHE_DEPTH-1 : 0];
wire [CACHE_DEPTH-1 : 0] way_select_valid;
wire [LINE_WIDTH-1 : 0]  line_out [CACHE_DEPTH-1 : 0];
wire [WAY_BITS-1 : 0]    matched_way [CACHE_DEPTH-1 : 0];
wire [CACHE_DEPTH-1 : 0] valid_read;

reg [WAY_BITS-1 : 0] t_matched_way, t_req_matched_way, t_coh_matched_way;
reg                  t_matched_way_valid, t_req_valid_read, t_coh_valid_read;
reg [MSG_BITS-1 : 0] save_msg;
reg [ADDRESS_WIDTH-1 : 0] save_address;

reg coh_write, coh_invalidate, coh_flush;
reg [BUS_WIDTH-1 : 0] t_coherence_data;
reg [MSG_BITS-1 : 0] t_coherence_msg_out;
reg [LINE_WIDTH-1 : 0] t_coherence_line;

genvar i;

reg [3:0] state, save_state;
reg [2:0] coh_state;

reg SG1_read, SG1_write, SG1_flush, SG1_invalidate;
reg [ADDRESS_WIDTH-1:0] SG1_address;
reg [DATA_WIDTH-1:0]    SG1_in_data;

reg SG0_read, SG0_write, SG0_flush, SG0_invalidate;
reg [ADDRESS_WIDTH-1:0] SG0_address;
reg [DATA_WIDTH-1:0]    SG0_in_data;

wire [(DATA_WIDTH * WORDS_PER_LINE)-1:0] new_data_block;
wire [DATA_WIDTH -1:0] r_words [0:WORDS_PER_LINE-1];
wire [DATA_WIDTH -1:0] w_words [0:WORDS_PER_LINE-1];

reg t_valid;
reg [DATA_WIDTH-1 : 0] t_out_data;

reg [ADDRESS_WIDTH-1 : 0] wb_address;
reg [BUS_WIDTH-1 : 0] wb_data_block;
reg invalidate_wb_way;
reg switch_state;

reg [MSG_BITS-1 : 0]      t_cache2mem_msg;
reg [ADDRESS_WIDTH-1 : 0] t_cache2mem_address;
reg [BUS_WIDTH-1 : 0]     t_cache2mem_data;

reg mem_flush_req;
reg [ADDRESS_WIDTH-1 :0] t_req_address;
reg [LINE_WIDTH-1 :0]    t_req_line;

reg [LINE_WIDTH-1 : 0] coherence_line, coh_new_line;

wire valid_bit, dirty;
wire [LINE_WIDTH-1 : 0] current_line;
wire [INDEX_BITS-1 : 0] current_index;
wire [INDEX_BITS-1 : 0] write_index;
wire [INDEX_BITS-1 : 0] coherence_index;
wire hit;
wire read_line, write_line;
wire stall;
wire [TAG_BITS-1 : 0]    current_tag;
wire [TAG_BITS-1 : 0]    coherence_tag;
wire [TAG_BITS-1 : 0]    c2c_tag;
wire [INDEX_BITS-1 : 0]  c2c_index;
wire [OFFSET_BITS-1 : 0] c2c_offset;
wire [OFFSET_BITS-1 : 0] zero_offset = 0;
wire [BUS_WIDTH-1:0]     current_data_block;
wire [LINE_WIDTH-1 : 0]  new_line;

wire coherence_action_required, accept_coherence_op;
wire [COHERENCE_BITS-1 : 0] coherence_bits_from_mem, current_coherence_bits;
wire accept_req_flush;

assign valid_bit = current_line[LINE_WIDTH-1];
assign dirty     = current_line[LINE_WIDTH-2];

assign accept_req_flush = ((mem2cache_msg == REQ_FLUSH) & (state != UPDATE) & (state != UPDATE_DONE) & (state != CACHE_ACCESS) 
		                  & (state != SRV_FLUSH_REQ) & (state != WAIT_FLUSH_REQ) & ~((state == IDLE) & (read|write|invalidate|flush)));
assign accept_coherence_op = coherence_action_required & (coh_state == NO_COHERENCE_OP) &
                             (( ~((SG1_address[OFFSET_BITS +: INDEX_BITS] == coherence_index) & (SG1_read|SG1_write|SG1_invalidate|SG1_flush))
                             & (current_index != coherence_index)) | ((state == IDLE) & ~(read|write|invalidate|flush)));
//assign accept_coherence_op = coherence_action_required & (coh_state == NO_COHERENCE_OP) &
//                             (((SG1_address[OFFSET_BITS +: INDEX_BITS] != coherence_index)
//                             & (current_index != coherence_index) & ~(SG1_read|SG1_write|SG1_invalidate|SG1_flush)) | ((state == IDLE) & ~(read|write|invalidate|flush)));
   
assign current_index = reset ? 0
                     : ((mem2cache_msg == REQ_FLUSH) & ~((state == IDLE) & (read|write|invalidate|flush))) ? mem2cache_address[OFFSET_BITS +: INDEX_BITS]
                     : (state == IDLE) ? address[OFFSET_BITS +: INDEX_BITS]
                     : (state == UPDATE_DONE) ? SG0_address[OFFSET_BITS +: INDEX_BITS] : SG1_address[OFFSET_BITS +: INDEX_BITS];

assign coherence_index = coherence_address[OFFSET_BITS +: INDEX_BITS];
assign coherence_tag   = coherence_address[(ADDRESS_WIDTH-1) -: TAG_BITS];

assign current_line = ((coh_state == NO_COHERENCE_OP) & accept_coherence_op) ? line_out[coherence_index]
                    : line_out[current_index];

assign current_data_block = (state == WAIT_WS_ENABLE) ?
                            {t_req_line[(LINE_WIDTH-1) -: (STATUS_BITS+COHERENCE_BITS)], t_req_line[(DATA_WIDTH*WORDS_PER_LINE)-1 : 0]}
                          : {current_line[(LINE_WIDTH-1) -: (STATUS_BITS+COHERENCE_BITS)], current_line[(DATA_WIDTH*WORDS_PER_LINE)-1 : 0]};

assign read_line = reset ? 0 : accept_req_flush ? 1
                             : ((flush | invalidate) & (state == IDLE)) ? 1
			                 : ((write | read) & ((state == IDLE) | ((state == CACHE_ACCESS) & ~stall))) ? 1
			                 : ((SG1_read | SG1_write | SG1_flush | SG1_invalidate) & (state == CACHE_ACCESS)) ? 1
			                 : ((SG0_write | SG0_read | SG0_flush | SG0_invalidate) & (state == UPDATE_DONE) & ~stall) ? 1
			                 : ((SG1_write | SG1_read) & (state == UPDATE)) ? 1 : 0;

assign write_line = (((state == CACHE_ACCESS) & SG1_write & (c2c_tag == current_tag) & valid_bit & (current_coherence_bits != SHARED))
		            | ((state == WAIT) & ((mem2cache_msg == MEM_SENT) & (coherence_msg_in == C_NO_REQ | coh_state == NO_COHERENCE_OP)))
                    | ((state == WAIT_WS_ENABLE) & (coherence_msg_in == ENABLE_WS))) ? 1 : 0;

assign hit	 = ((SG1_write | SG1_read | SG1_flush | SG1_invalidate) & (c2c_tag == current_tag) & valid_bit) ? 1 : 0;
assign stall = ((((c2c_index == SG0_address [OFFSET_BITS +: INDEX_BITS]) & (SG0_write | SG0_read | SG0_flush | SG0_invalidate)) | 
			   ((c2c_index == address[OFFSET_BITS +: INDEX_BITS]) & (read | write | flush | invalidate)))  & SG1_write)? 1 : 0;

assign current_tag = current_line[(LINE_WIDTH-1-STATUS_BITS-COHERENCE_BITS) -: TAG_BITS];
assign c2c_tag	   = SG1_address[(ADDRESS_WIDTH-1) -: TAG_BITS];
assign c2c_index   = SG1_address[OFFSET_BITS +: INDEX_BITS];
assign c2c_offset  = SG1_address[(OFFSET_BITS-1) : 0];

assign new_line	= (SG1_write & (c2c_tag == current_tag) & valid_bit & (current_coherence_bits == EXCLUSIVE)) ? {2'b11, MODIFIED, current_tag, new_data_block}
                : (SG1_write & (c2c_tag == current_tag) & valid_bit & (current_coherence_bits == MODIFIED)) ? {2'b11, current_coherence_bits, current_tag, new_data_block}
		        : ((state == WAIT) & ((mem2cache_msg == MEM_SENT) & (coherence_msg_in == C_NO_REQ | coh_state == NO_COHERENCE_OP)) & SG1_write) ? {2'b11, MODIFIED, c2c_tag, new_data_block}
		        : ((state == WAIT) & ((mem2cache_msg == MEM_SENT) & (coherence_msg_in == C_NO_REQ | coh_state == NO_COHERENCE_OP)) & SG1_read) ? {2'b10, coherence_bits_from_mem, c2c_tag, new_data_block}
                : ((state == WAIT_WS_ENABLE) & (coherence_msg_in == ENABLE_WS)) ? {2'b11, MODIFIED, c2c_tag, new_data_block}
		        : 0;

assign write_index = ((SG1_write & (c2c_tag == current_tag) & valid_bit) | ((state == WAIT) & ((mem2cache_msg == MEM_SENT) & (coherence_msg_in == C_NO_REQ | coh_state == NO_COHERENCE_OP)))
                     | ((state == WAIT_WS_ENABLE) & (coherence_msg_in == ENABLE_WS))) ? c2c_index : 0;

assign coherence_action_required = ((coherence_msg_in == C_RD_BCAST) | (coherence_msg_in == C_FLUSH_BCAST)
                                   | (coherence_msg_in == C_INVLD_BCAST) | (coherence_msg_in == C_WS_BCAST)
                                   | (coherence_msg_in == C_RFO_BCAST)) ? 1 : 0;

assign coherence_bits_from_mem = mem2cache_data[(BUS_WIDTH-1-STATUS_BITS) -: COHERENCE_BITS];
assign current_coherence_bits  = current_line[(LINE_WIDTH-1-STATUS_BITS) -: COHERENCE_BITS];

generate
	for(i=0; i<WORDS_PER_LINE; i=i+1) begin: R_WORDS
		assign r_words[i] = current_data_block[i*DATA_WIDTH +: DATA_WIDTH];
		assign new_data_block [(((i + 1) *(DATA_WIDTH))-1) -: DATA_WIDTH] = w_words[i];
	end

	for(i=0; i<WORDS_PER_LINE; i=i+1) begin: W_WORDS
		assign w_words[i] = (SG1_write & (c2c_tag == current_tag) & valid_bit & (c2c_offset == i)) ? SG1_in_data
				          : ((state == WAIT) & ((mem2cache_msg == MEM_SENT) & (coherence_msg_in == C_NO_REQ | coh_state == NO_COHERENCE_OP)) & (mem2cache_address == t_cache2mem_address)) ?
				            (SG1_write & (c2c_offset == i)) ? SG1_in_data : mem2cache_data[(DATA_WIDTH*i) +: DATA_WIDTH]
                          : ((state == WAIT_WS_ENABLE) & (coherence_msg_in == ENABLE_WS)) ?
                            (SG1_write & (c2c_offset == i)) ? SG1_in_data : r_words[i]
				          : r_words[i];
	end
endgenerate

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

// Connect read_line
generate
	for(i=0; i<CACHE_DEPTH; i=i+1) begin: READ_SET
		assign read_set[i] = ((coherence_index == i) & accept_coherence_op) ? 1
                           : (current_index == i) ? read_line 
                           : 0;
	end
endgenerate

// Connect write_line
generate
	for(i=0; i<CACHE_DEPTH; i=i+1) begin: WRITE_SET
		assign write_set[i] = ((coherence_index == i) & coh_write) ? 1
                            : (write_index == i) ? write_line
                            : 0;
	end
endgenerate

// Connect line_in
generate
	for(i=0; i<CACHE_DEPTH; i=i+1) begin : LINE_IN
		assign line_in[i] = (write_index == i) ? new_line
                          : ((coherence_index == i) & coh_write) ? coh_new_line 
                          : 0;
	end
endgenerate

// Connect tag_in
generate
	for(i=0; i<CACHE_DEPTH; i=i+1) begin : TAG_IN
		assign tag_in[i] = ((coherence_index == i) & accept_coherence_op) ? coherence_tag
                         : (current_index == i) ? ((mem2cache_msg == REQ_FLUSH) & (state != SRV_FLUSH_REQ) & (state != WAIT_FLUSH_REQ)) ? mem2cache_address[ADDRESS_WIDTH-1 -: TAG_BITS]
				         : ((state == IDLE) & (read|write|invalidate|flush)) ? address[ADDRESS_WIDTH-1 -: TAG_BITS]
				         : (state == UPDATE_DONE) ? SG0_address[ADDRESS_WIDTH-1 -: TAG_BITS]
				         : (state == SRV_FLUSH_REQ) ? t_req_address[ADDRESS_WIDTH-1 -: TAG_BITS]
				         : (state == SRV_INVLD_REQ) ? t_req_address[ADDRESS_WIDTH-1 -: TAG_BITS]
				         : SG1_address[ADDRESS_WIDTH-1 -: TAG_BITS]	: 0;
	end
endgenerate

// way_select and way_select_valid
generate
	for(i=0; i<CACHE_DEPTH; i=i+1) begin : WAY_SELECT
		assign way_select[i]	   = (state == CACHE_ACCESS) ? t_matched_way 
					               : (state == SRV_FLUSH_REQ) ? t_req_matched_way
					               : (state == WAIT_WS_ENABLE) ? t_matched_way
					               : (state == SRV_INVLD_REQ) ? t_req_matched_way
                                   : ((coherence_index == i) & (coh_write|coh_flush|coh_invalidate)) ? t_coh_matched_way
                                   : 0;
		assign way_select_valid[i] = (state == CACHE_ACCESS)? t_matched_way_valid
	       				           : (state == SRV_FLUSH_REQ) ? t_req_valid_read
	       				           : ((state == WAIT_WS_ENABLE) & (coherence_msg_in == ENABLE_WS)) ? t_matched_way_valid
	       				           : (state == SRV_INVLD_REQ) ? t_req_valid_read 
                                   : ((coherence_index == i) & (coh_write|coh_flush|coh_invalidate)) ? t_coh_valid_read
                                   : 0;
	end
endgenerate

// Connect internal wires to outside signals
generate
	for(i=0; i<CACHE_DEPTH; i=i+1) begin: CONNECTIONS
		assign flush_set[i]      = ((i == current_index) & (state == SRV_FLUSH_REQ) & t_req_valid_read)
                                   | ((coherence_index == i) & coh_flush) ;
		assign invalidate_set[i] = ((i == current_index) & (((state == SRV_INVLD_REQ) & t_req_valid_read) | invalidate_wb_way))
                                   | ((i == coherence_index) & coh_invalidate);
	end
endgenerate


// Cache control logic
always @(posedge clock)begin
	if(reset)begin
		SG0_read       <= 0;
		SG0_write      <= 0;
		SG0_flush      <= 0;
		SG0_invalidate <= 0;
		SG0_address    <= 0;
		SG0_in_data    <= 0;
		
		SG1_read       <= 0;
		SG1_write      <= 0;
		SG1_flush      <= 0;
		SG1_invalidate <= 0;
		SG1_address    <= 0;
		SG1_in_data    <= 0;
		
		t_cache2mem_msg     <= 0;
		t_cache2mem_address <= 0;
		t_cache2mem_data    <= 0;

		t_matched_way       <= 0;
		t_matched_way_valid <= 0;

		t_req_matched_way <= 0;
		t_req_valid_read  <= 0;
		t_req_address     <= 0;
		mem_flush_req     <= 0;

		wb_address	      <= 0;
		wb_data_block	  <= 0;
		invalidate_wb_way <= 0;
		switch_state      <= 0;

		state	     <= IDLE;
		save_state   <= IDLE;
		save_msg     <= NO_REQ;
		save_address <= 0;
	end
	else begin
		if(accept_req_flush)begin
			t_req_address     <= mem2cache_address;
			mem_flush_req     <= 1;
			t_req_line        <= current_line;
			t_req_matched_way <= matched_way[current_index];
			t_req_valid_read  <= valid_read[current_index];
			state             <= SRV_FLUSH_REQ;
			save_state        <= state;
			save_msg          <= cache2mem_msg;
			save_address      <= cache2mem_address;
		end
		else begin
			wb_address    <= valid_bit? {current_tag, c2c_index, zero_offset} : wb_address;
			wb_data_block <= valid_bit? current_data_block : wb_data_block;

			case(state)
				IDLE: begin
                    if((address[OFFSET_BITS +: INDEX_BITS] == coherence_index) & (read|write|invalidate|flush) & (coherence_msg_in != C_NO_REQ))begin
						SG0_read       <= read;
						SG0_write      <= write;
						SG0_flush      <= flush;
						SG0_invalidate <= invalidate;
						SG0_address    <= address;
						SG0_in_data    <= data_in;
                        state          <= UPDATE_DONE;
                    end
                    else begin
					    SG1_read       <= read;
					    SG1_write      <= write;    
					    SG1_flush      <= flush;
					    SG1_invalidate <= invalidate;
					    SG1_address    <= address;
					    SG1_in_data    <= data_in;
					    
					    t_matched_way       <= matched_way[current_index];
					    t_matched_way_valid <= valid_read[current_index];
				
					    if(flush)begin
					    	t_req_address     <= (address >> 2) << 2;
					    	t_req_line        <= current_line;
					    	t_req_matched_way <= matched_way[current_index];
					    	t_req_valid_read  <= valid_read[current_index];
					    	save_state        <= IDLE;
					    	save_msg          <= NO_REQ;
					    	save_address      <= 0;
					    	state             <= SRV_FLUSH_REQ;
					    end
					    else if(invalidate)begin
					    	t_req_address     <= (address >> 2) << 2;
					    	t_req_line        <= current_line;
					    	t_req_matched_way <= matched_way[current_index];
					    	t_req_valid_read  <= valid_read[current_index];
					    	save_state        <= IDLE;
					    	save_msg          <= NO_REQ;
					    	save_address      <= 0;
					    	state             <= SRV_INVLD_REQ;
					    end
					    else
					    	state <= (read | write)? CACHE_ACCESS : IDLE;
                    end
				end

				CACHE_ACCESS: begin
					invalidate_wb_way <= 0;
					if(hit)begin
                        if(SG1_write & current_coherence_bits == SHARED)begin
                            t_matched_way       <= matched_way[current_index];
							t_matched_way_valid <= valid_read[current_index];
							SG0_read            <= read;
							SG0_write           <= write;
							SG0_flush           <= flush;
							SG0_invalidate      <= invalidate;
							SG0_address         <= address;
							SG0_in_data         <= data_in;
                            t_cache2mem_msg     <= WS_BCAST;
                            t_cache2mem_address <= (SG1_address >> 2) << 2;
                            t_req_line          <= current_line;
                            state <= WAIT_WS_ENABLE;
                        end
						else if(stall)begin                  
							SG1_read       <= 0;
							SG1_write      <= 0;
							SG1_flush      <= 0;
							SG1_invalidate <= 0;
							SG1_in_data    <= 0;
	
							SG0_read       <= read;
							SG0_write      <= write;
							SG0_flush      <= flush;
							SG0_invalidate <= invalidate;
							SG0_address    <= address;
							SG0_in_data    <= data_in;
	
							t_matched_way       <= matched_way[current_index];
							t_matched_way_valid <= valid_read[current_index];
	
							state <= UPDATE_DONE;
						end
						else begin
                            if((address[OFFSET_BITS +: INDEX_BITS] == coherence_index) & (read|write|invalidate|flush) & (coherence_msg_in != C_NO_REQ))begin
						        SG0_read       <= read;
						        SG0_write      <= write;
						        SG0_flush      <= flush;
						        SG0_invalidate <= invalidate;
						        SG0_address    <= address;
						        SG0_in_data    <= data_in;
                                state          <= UPDATE_DONE;
                            end
                            else begin
							    SG1_read       <= read;
							    SG1_write      <= write;
							    SG1_flush      <= flush;
							    SG1_invalidate <= invalidate;
							    SG1_address    <= address;
							    SG1_in_data    <= data_in;
	
							    if(SG1_flush)begin
							    	t_req_address     <= (SG1_address >> 2) << 2;
							    	t_req_line        <= current_line;
							    	t_req_matched_way <= matched_way[current_index];
							    	t_req_valid_read  <= valid_read[current_index];
							    	save_state        <= IDLE;
							    	save_msg          <= NO_REQ;
							    	save_address      <= 0;
							    	state             <= SRV_FLUSH_REQ;
							    end
							    else if(SG1_invalidate)begin
							    	t_req_address     <= (SG1_address >> 2) << 2;
							    	t_req_line        <= current_line;
							    	t_req_matched_way <= matched_way[current_index];
							    	t_req_valid_read  <= valid_read[current_index];
							    	save_state        <= IDLE;
							    	save_msg          <= NO_REQ;
							    	save_address      <= 0;
							    	state             <= SRV_INVLD_REQ;
							    end
							    else
							    	state <= (read | write | flush | invalidate) ? CACHE_ACCESS : IDLE;
                            end
						end
					end
					else begin
						SG0_read       <= read;
						SG0_write      <= write;
						SG0_flush      <= flush;
						SG0_invalidate <= invalidate;
						SG0_address    <= address;
						SG0_in_data    <= data_in;

						if(SG1_flush)begin
							t_req_address     <= (SG1_address >> 2) << 2;
							t_req_line        <= current_line;
							t_req_matched_way <= matched_way[current_index];
							t_req_valid_read  <= valid_read[current_index];
							save_state        <= IDLE;
							save_msg          <= NO_REQ;
							save_address      <= 0;
							state             <= SRV_FLUSH_REQ;
						end
						else if(SG1_invalidate)begin
							t_req_address     <= (SG1_address >> 2) << 2;
							t_req_line        <= current_line;
							t_req_matched_way <= matched_way[current_index];
							t_req_valid_read  <= valid_read[current_index];
							save_state        <= IDLE;
							save_msg          <= NO_REQ;
							save_address      <= 0;
							state             <= SRV_INVLD_REQ;
						end

						else
							state <= (dirty & valid_bit) ? WRITE_BACK : READ_ST;
					end
				end

				READ_ST: begin
					invalidate_wb_way   <= 0;
					t_cache2mem_msg     <= (SG1_write) ? RFO_BCAST : R_REQ;
					t_cache2mem_address <= (SG1_address >> OFFSET_BITS) << OFFSET_BITS;
					state               <= WAIT;
				end

				WAIT: begin
					if(mem2cache_msg == MEM_SENT & (coherence_msg_in == C_NO_REQ | coh_state == NO_COHERENCE_OP) & t_cache2mem_address == mem2cache_address) begin
						t_cache2mem_msg	<= NO_REQ;
						state		<= UPDATE;
					end
					else
						state		<= WAIT;
				end

				UPDATE: begin
					state <= UPDATE_DONE;
				end

				UPDATE_DONE: begin
					if(stall) begin
						SG1_read       <= 0;
						SG1_write      <= 0;
						SG1_flush      <= 0;
						SG1_invalidate <= 0;
						SG1_in_data    <= 0;
						state          <= UPDATE_DONE;
					end
					else begin
                        if((SG0_address[OFFSET_BITS +: INDEX_BITS] == coherence_index) & (SG0_read|SG0_write|SG0_invalidate|SG0_flush) & (coherence_msg_in != C_NO_REQ))begin
                            state <= UPDATE_DONE;
                        end
                        else begin
						    SG1_read       <= SG0_read;
						    SG1_write      <= SG0_write;
						    SG1_flush      <= SG0_flush;
						    SG1_invalidate <= SG0_invalidate;
						    SG1_address    <= SG0_address;
						    SG1_in_data    <= SG0_in_data;

						    SG0_read       <= 0;
						    SG0_write      <= 0;
						    SG0_flush      <= 0;
						    SG0_invalidate <= 0;
						    SG0_address    <= 0;
						    SG0_in_data    <= 0;

						    t_matched_way	    <= matched_way[current_index];
						    t_matched_way_valid <= valid_read[current_index];

						    state <= (SG0_read | SG0_write | SG0_flush | SG0_invalidate) ? CACHE_ACCESS : IDLE;
                        end
					end
				end
				
				WRITE_BACK: begin
					t_cache2mem_msg	    <= WB_REQ;
					t_cache2mem_address <= wb_address;
					t_cache2mem_data    <= wb_data_block;
					state               <= WB_WAIT;
				end
				
				WB_WAIT: begin
					if(mem2cache_msg == MEM_READY & (coherence_msg_in == C_NO_REQ | coh_state == NO_COHERENCE_OP)) begin
						t_cache2mem_msg	  <= NO_REQ;
						invalidate_wb_way <= 1;
						state <= (SG1_read | SG1_write) ? READ_ST : CACHE_ACCESS;
					end
					else
						state <= WB_WAIT;
				end
				SRV_FLUSH_REQ: begin
					t_cache2mem_address <= t_req_address;
					state               <= WAIT_FLUSH_REQ;
					if((t_req_line[LINE_WIDTH-2]) & t_req_valid_read)begin
						t_cache2mem_msg  <= FLUSH;
						t_cache2mem_data <= {t_req_line[(LINE_WIDTH-1) -: (STATUS_BITS+COHERENCE_BITS)],
                                            t_req_line[0 +: DATA_WIDTH*WORDS_PER_LINE]};
					end
					else begin
						t_cache2mem_msg  <= (mem_flush_req) ? NO_FLUSH : FLUSH;
						t_cache2mem_data <= 0;
					end
				end
				WAIT_FLUSH_REQ: begin
					if(mem2cache_msg == M_RECV & (coherence_msg_in == C_NO_REQ | coh_state == NO_COHERENCE_OP))begin
						t_cache2mem_msg <= NO_REQ;
						switch_state    <= 1;
					end
					else if(((mem2cache_msg == MEM_NO_MSG) & (coherence_msg_in == C_NO_REQ | coh_state == NO_COHERENCE_OP)) & (switch_state | mem_flush_req))begin
						switch_state  <= 0;
						mem_flush_req <= 0;
						if(save_state == WB_WAIT & t_req_valid_read & (save_address[OFFSET_BITS +: INDEX_BITS] == t_req_address[OFFSET_BITS +: INDEX_BITS]))begin
							t_cache2mem_msg     <= NO_REQ;
							t_cache2mem_address <= 0;
							t_cache2mem_data    <= 0;
							state               <= (SG1_read | SG1_write) ? READ_ST : CACHE_ACCESS;
						end
						else begin
							t_cache2mem_msg     <= (mem_flush_req) ? save_msg : NO_REQ;
							t_cache2mem_address <= save_address;
							t_cache2mem_data    <= wb_data_block;
							state               <= (mem_flush_req) ? save_state : IDLE;
						end
					end
					else
						state <= WAIT_FLUSH_REQ;
				end
				SRV_INVLD_REQ: begin
					t_cache2mem_address <= t_req_address;
					state               <= WAIT_INVLD_REQ;
					t_cache2mem_msg     <= INVLD;
					if((t_req_line[LINE_WIDTH-2]) & t_req_valid_read)begin
						t_cache2mem_data <= {t_req_line[(LINE_WIDTH-1) -: (STATUS_BITS+COHERENCE_BITS)],
                                            t_req_line[0 +: DATA_WIDTH*WORDS_PER_LINE]};
					end
					else begin
						t_cache2mem_data <= 0;
					end
				end
				WAIT_INVLD_REQ: begin
					if(mem2cache_msg == M_RECV & (coherence_msg_in == C_NO_REQ | coh_state == NO_COHERENCE_OP))begin
						t_cache2mem_msg     <= NO_REQ;
						switch_state        <= 1;
					end
					else if(((mem2cache_msg == MEM_NO_MSG) & (coherence_msg_in == C_NO_REQ | coh_state == NO_COHERENCE_OP)) & switch_state)begin
						switch_state        <= 0;
						t_cache2mem_address <= save_address;
						t_cache2mem_data    <= wb_data_block;
						mem_flush_req       <= 0;
						state               <= IDLE;
					end
					else
						state <= WAIT_INVLD_REQ;
				end
                WAIT_WS_ENABLE:begin
                    if(coherence_msg_in == ENABLE_WS)begin
                        t_cache2mem_msg <= NO_REQ;
                        state <= UPDATE_DONE;
                    end
                    else
                        state <= WAIT_WS_ENABLE;
                end
				default: state	<= IDLE;
			endcase
		end
	end
end

// controller for coherence operations
always @(posedge clock)begin
    if(reset)begin
        t_coherence_msg_out <= C_NO_RESP;
        t_coherence_line    <= 0;
        t_coherence_data    <= 0;
        t_coh_matched_way   <= 0;
        t_coh_valid_read    <= 0;
        coh_new_line        <= 0;
        coh_write           <= 0;
        coh_flush           <= 0;
        coh_invalidate      <= 0;
        coh_state           <= NO_COHERENCE_OP;
    end
    else begin
        case(coh_state)
            NO_COHERENCE_OP:begin
                if(accept_coherence_op)begin
                    t_coherence_line  <= current_line; //TODO// update current_index to get the correct current line here.
			        t_coh_matched_way <= matched_way[coherence_index]; //TODO// make sure way in is updated whenever using this.
			        t_coh_valid_read  <= valid_read[coherence_index];
                    coh_state <= HANDLE_COH_REQ;
                end
            end
            HANDLE_COH_REQ:begin
                case(coherence_msg_in)
                    C_RD_BCAST:begin
                        coh_state <= WAIT_FOR_CONTROLLER;
                        if(t_coh_valid_read & t_coherence_line[LINE_WIDTH-2])begin
                            t_coherence_msg_out <= C_WB;
                            coh_invalidate      <= 1;
                            t_coherence_data    <= {t_coherence_line[(LINE_WIDTH-1) -: (STATUS_BITS+COHERENCE_BITS)],
                                                    t_coherence_line[0 +: DATA_WIDTH*WORDS_PER_LINE]};
                        end
                        else if(t_coh_valid_read)begin
                            coh_write    <= 1;
                            coh_new_line <= {t_coherence_line[(LINE_WIDTH-1) -: STATUS_BITS], SHARED,
                                             t_coherence_line[0 +: DATA_WIDTH*WORDS_PER_LINE+TAG_BITS]};
                            t_coherence_msg_out <= C_EN_ACCESS;
                        end
                        else
                            t_coherence_msg_out <= C_EN_ACCESS;
                    end
                    C_WS_BCAST:begin
                        coh_state <= WAIT_FOR_CONTROLLER;
                        /*if(t_coh_valid_read & t_coherence_line[LINE_WIDTH-2])begin
                            t_coherence_msg_out <= C_WB;
                            coh_invalidate      <= 1;
                            t_coherence_data    <= {t_coherence_line[(LINE_WIDTH-1) -: (STATUS_BITS+COHERENCE_BITS)],
                                                    t_coherence_line[0 +: DATA_WIDTH*WORDS_PER_LINE]};
                        end
                        else */  // cannot be in dirty and shared states at the same time.
                       if(t_coh_valid_read)begin
                            coh_invalidate      <= 1;
                            t_coherence_msg_out <= C_EN_ACCESS;
                        end
                        else
                            t_coherence_msg_out <= C_EN_ACCESS;
                    end
                    C_RFO_BCAST:begin
                        coh_state <= WAIT_FOR_CONTROLLER;
                        if(t_coh_valid_read & t_coherence_line[LINE_WIDTH-2])begin
                            t_coherence_msg_out <= C_WB;
                            coh_invalidate      <= 1;
                            t_coherence_data    <= {t_coherence_line[(LINE_WIDTH-1) -: (STATUS_BITS+COHERENCE_BITS)],
                                                    t_coherence_line[0 +: DATA_WIDTH*WORDS_PER_LINE]};
                        end
                        else if(t_coh_valid_read)begin
                            coh_invalidate      <= 1;
                            t_coherence_msg_out <= C_EN_ACCESS;
                        end
                        else
                            t_coherence_msg_out <= C_EN_ACCESS;
                    end
                    C_FLUSH_BCAST:begin
                        coh_state <= WAIT_FOR_CONTROLLER;
                        if(t_coh_valid_read & t_coherence_line[LINE_WIDTH-2])begin
                            t_coherence_msg_out <= C_FLUSH;
                            coh_flush           <= 1;
                            t_coherence_data    <= {t_coherence_line[(LINE_WIDTH-1) -: (STATUS_BITS+COHERENCE_BITS)],
                                                    t_coherence_line[0 +: DATA_WIDTH*WORDS_PER_LINE]};
                        end
                        else if(t_coh_valid_read)begin
                            coh_flush           <= 1;
                            t_coherence_msg_out <= C_EN_ACCESS;
                        end
                        else
                            t_coherence_msg_out <= C_EN_ACCESS;
                    end
                    C_INVLD_BCAST:begin
                        coh_state <= WAIT_FOR_CONTROLLER;
                        if(t_coh_valid_read & t_coherence_line[LINE_WIDTH-2])begin
                            t_coherence_msg_out <= C_INVLD;
                            coh_invalidate      <= 1;
                            t_coherence_data    <= {t_coherence_line[(LINE_WIDTH-1) -: (STATUS_BITS+COHERENCE_BITS)],
                                                    t_coherence_line[0 +: DATA_WIDTH*WORDS_PER_LINE]};
                        end
                        else if(t_coh_valid_read)begin
                            coh_invalidate      <= 1;
                            t_coherence_msg_out <= C_EN_ACCESS;
                        end
                        else
                            t_coherence_msg_out <= C_EN_ACCESS;
                    end
                    default:begin
                        coh_state           <= NO_COHERENCE_OP;
                        t_coherence_msg_out <= C_NO_RESP;
                    end
                endcase
            end
            WAIT_FOR_CONTROLLER:begin
                coh_write      <= 0;
                coh_invalidate <= 0;
                coh_flush      <= 0;
                if(coherence_msg_in == C_NO_REQ)begin
                    t_coherence_data    <= 0;
                    t_coherence_msg_out <= C_NO_RESP;
                    coh_state <= NO_COHERENCE_OP;
                end
            end
            default: coh_state <= NO_COHERENCE_OP;
        endcase
    end
end


// Drive outputs
assign  cache2mem_msg     = reset? 0: t_cache2mem_msg; 
assign  cache2mem_address = reset? 0: t_cache2mem_address; 
assign  cache2mem_data    = reset? 0: t_cache2mem_data;					
assign	out_address	  = SG1_address;
assign  valid    	  = (hit & SG1_read & ((state == UPDATE) | (state == CACHE_ACCESS))) ? 1 : 0;
assign  data_out 	  = (hit & SG1_read)? r_words[c2c_offset]: 0;
//TODO// update ready to go low when the address or SG0 has the same index as coherence and there is coherence operation going on.
assign  ready    	  = ((mem2cache_msg != REQ_FLUSH) & ~((flush & ((state == IDLE) | (state == CACHE_ACCESS))) | (state == SRV_FLUSH_REQ) | (state == WAIT_FLUSH_REQ)) 
                        & ~((invalidate & ((state == IDLE) | (state == CACHE_ACCESS))) | (state == SRV_INVLD_REQ) | (state == WAIT_INVLD_REQ))
                        & (~SG1_flush & ~SG1_invalidate & ~SG0_flush & ~SG0_invalidate) 
			            & (reset | (state == IDLE) | ((state == CACHE_ACCESS) & hit & ~stall))
                        & ~(SG1_write & current_coherence_bits == SHARED)
                        & ~((address[OFFSET_BITS +: INDEX_BITS] == coherence_index) & (coherence_msg_in != C_NO_REQ) & (read|write|invalidate|flush)) ) ? 1 : 0;
//assign  ready    	  = ((mem2cache_msg != REQ_FLUSH) & ~((flush & ((state == IDLE) | (state == CACHE_ACCESS))) | (state == SRV_FLUSH_REQ) | (state == WAIT_FLUSH_REQ)) 
//                        & ~((invalidate & ((state == IDLE) | (state == CACHE_ACCESS))) | (state == SRV_INVLD_REQ) | (state == WAIT_INVLD_REQ))
//                        & (~SG1_flush & ~SG1_invalidate & ~SG0_flush & ~SG0_invalidate) 
//			            & (reset | (state == IDLE) | ((state == CACHE_ACCESS) & hit & ~stall))) ? 1 : 0;

assign coherence_msg_out = reset ? 0 : t_coherence_msg_out;
assign coherence_data    = reset ? 0 : t_coherence_data;

endmodule
