//`timescale 1ns/1ps
module tb_lxcache();

parameter STATUS_BITS           = 3,	// Valid bit + Dirty bit + inclusion bit
	      COHERENCE_BITS        = 2,
	      OFFSET_BITS           = 2,
	      DATA_WIDTH            = 8,
	      NUMBER_OF_WAYS        = 2,
	      REPLACEMENT_MODE_BITS = 1,
	      ADDRESS_WIDTH         = 12,
	      INDEX_BITS            = 6,
	      MSG_BITS              = 3,
	      NUM_CACHES            = 4,	// Number of caches served.
	      CACHE_LEVEL           = 2;

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
           WAIT_INVLD     = 11,
           RESET          = 12,
           BRAM_DELAY     = 13;

`include "./params.v"

reg clock, reset;
reg [ADDRESS_WIDTH-1 : 0] address0, address1, address2, address3;
reg [BUS_WIDTH_UP-1 : 0] data_in0, data_in1, data_in2, data_in3;
reg [MSG_BITS-1 : 0] msg_in0, msg_in1, msg_in2, msg_in3;
reg report;
wire [BUS_WIDTH_UP-1 : 0] data_out0, data_out1, data_out2, data_out3;
wire [ADDRESS_WIDTH-1 : 0] out_address0, out_address1, out_address2, out_address3;
wire [MSG_BITS-1 : 0] msg_out0, msg_out1, msg_out2, msg_out3;

reg [MSG_BITS-1 : 0]       mem2cache_msg;
reg [ADDRESS_WIDTH-1 : 0]  mem2cache_address;
reg [BUS_WIDTH_DOWN-1 : 0]      mem2cache_data;
wire [MSG_BITS-1 : 0]      cache2mem_msg;
wire [ADDRESS_WIDTH-1 : 0] cache2mem_address;
wire [BUS_WIDTH_DOWN-1 : 0] cache2mem_data;


// Instantiate Lxcache
Lxcache #(STATUS_BITS, COHERENCE_BITS, OFFSET_BITS, DATA_WIDTH, NUMBER_OF_WAYS, REPLACEMENT_MODE_BITS, ADDRESS_WIDTH, INDEX_BITS, MSG_BITS, NUM_CACHES, CACHE_LEVEL)
	DUT (clock, reset,
	     {address3, address2, address1, address0},
	     {data_in3, data_in2, data_in1, data_in0},
	     {msg_in3, msg_in2, msg_in1, msg_in0},
	     report,
	     {data_out3, data_out2, data_out1, data_out0},
	     {out_address3, out_address2, out_address1, out_address0},
	     {msg_out3, msg_out2, msg_out1, msg_out0},
	     
		 mem2cache_msg,
	     mem2cache_address,
	     mem2cache_data,
	     cache2mem_msg,
	     cache2mem_address,
	     cache2mem_data
	     );

// generate clock
always #5 clock = ~clock;

initial
begin
	clock = 1;
	reset = 1;
	report = 0;
	mem2cache_msg = MEM_NO_MSG;
	mem2cache_address = 0;
	mem2cache_data = 0;
	#50;
	reset = 0;
	
	wait(cache2mem_msg == R_REQ);
	repeat(2) @(posedge clock);
	mem2cache_data = 36'h111223344;
	mem2cache_address = 12'h3FC;
	mem2cache_msg = MEM_SENT;
	wait(cache2mem_msg == NO_REQ);
	mem2cache_msg = MEM_NO_MSG;

	wait(cache2mem_msg == R_REQ);
	repeat(2) @(posedge clock);
	mem2cache_data = 32'h98765432;
	mem2cache_address = 12'h9FC;
	mem2cache_msg = MEM_SENT;
	wait(cache2mem_msg == NO_REQ);
	mem2cache_msg = MEM_NO_MSG;

	wait(cache2mem_msg == R_REQ);
	repeat(2) @(posedge clock);
	mem2cache_data = 32'hAABBCCDD;
	mem2cache_address = 12'h2F8;
	mem2cache_msg = MEM_SENT;
	wait(cache2mem_msg == NO_REQ);
	mem2cache_msg = MEM_NO_MSG;

	wait(cache2mem_msg == WB_REQ)
	repeat(2) @(posedge clock);
	mem2cache_msg = MEM_READY;
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;

	wait(cache2mem_msg == R_REQ);
	repeat(2) @(posedge clock);
	mem2cache_data = 32'hFFFFEEEE;
	mem2cache_address = 12'hAFC;
	mem2cache_msg = MEM_SENT;
	wait(cache2mem_msg == NO_REQ);
	mem2cache_msg = MEM_NO_MSG;

	wait((cache2mem_msg == WB_REQ) & (cache2mem_address == 12'hAFC));
	repeat(2) @(posedge clock);
	mem2cache_msg = MEM_READY;
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;

	wait((cache2mem_msg == WB_REQ) & (cache2mem_address == 12'h9FC));
	repeat(2) @(posedge clock);
	mem2cache_msg = MEM_READY;
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;

	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'hFFC));
	repeat(2) @(posedge clock);
	mem2cache_data = 32'h11111111;
	mem2cache_address = 12'hFFC;
	mem2cache_msg = MEM_SENT;
	wait(cache2mem_msg == NO_REQ);
	mem2cache_msg = MEM_NO_MSG; //930

	#130;
	@(posedge clock) begin
		mem2cache_msg     = REQ_FLUSH;
		mem2cache_address = 12'h2F8;
	end
	wait(cache2mem_msg == NO_FLUSH);
	@(posedge clock) mem2cache_msg = MEM_NO_MSG; //1150

	#30;
	@(posedge clock) begin
		mem2cache_msg     = REQ_FLUSH;
		mem2cache_address = 12'h6FC;
	end

	wait((cache2mem_msg == FLUSH) & (cache2mem_address == 12'h6FC));
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;

	#30;
	@(posedge clock) begin
		mem2cache_msg     = REQ_FLUSH;
		mem2cache_address = 12'hFFC;
	end

	wait((cache2mem_msg == FLUSH) & (cache2mem_address == 12'hFFC));
	repeat(1) @(posedge clock);
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;

	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'h1FC));
	@(posedge clock)begin
		mem2cache_msg     = MEM_SENT;
		mem2cache_address = 12'h1FC;
		mem2cache_data    = 32'h99999999;
	end
	wait(cache2mem_msg == NO_REQ);
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;

	wait((cache2mem_msg == FLUSH) & (cache2mem_address == 12'hDFC));
	repeat(2) @(posedge clock);
	@(posedge clock) mem2cache_msg = M_RECV;
	wait(cache2mem_msg == NO_REQ);
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;

	wait((cache2mem_msg == FLUSH) & (cache2mem_address == 12'h1FC));
	repeat(2) @(posedge clock);
	@(posedge clock) mem2cache_msg = M_RECV;
	wait(cache2mem_msg == NO_REQ);
	repeat(2) @(posedge clock);
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;

	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'h4FC));
	repeat(2) @(posedge clock);
	@(posedge clock) begin
		mem2cache_msg = MEM_SENT;
		mem2cache_address = 12'h4FC;
		mem2cache_data    = 32'hAAAAAAAA;
	end
	wait(cache2mem_msg == NO_REQ);
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;

	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'h5FC));
	repeat(2) @(posedge clock);
	@(posedge clock) begin
		mem2cache_msg = MEM_SENT;
		mem2cache_address = 12'h5FC;
		mem2cache_data    = 32'hBDBDBDBD;
	end
	wait(cache2mem_msg == NO_REQ);
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;

	wait((cache2mem_msg == INVLD) & (cache2mem_address == 12'h4FC));
	repeat(2) @(posedge clock);
	@(posedge clock) mem2cache_msg = M_RECV;
	wait(cache2mem_msg == NO_REQ);
	repeat(2) @(posedge clock);
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;
	
	wait((cache2mem_msg == INVLD) & (cache2mem_address == 12'h5FC));
	repeat(1) @(posedge clock);
	@(posedge clock) mem2cache_msg = M_RECV;
	wait(cache2mem_msg == NO_REQ);
	repeat(1) @(posedge clock);
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;
	
	wait((cache2mem_msg == WB_REQ) & (cache2mem_address == 12'h7F8));
	repeat(1) @(posedge clock);
	@(posedge clock) mem2cache_msg = MEM_READY;
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;

	wait((cache2mem_msg == WB_REQ) & (cache2mem_address == 12'hAF8));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg = REQ_FLUSH;
		mem2cache_address = 12'h3F8;
	end
	wait((cache2mem_msg == FLUSH) & (cache2mem_address == 12'h3F8));
	repeat(1) @(posedge clock);
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;
	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'hCF8));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg = MEM_SENT;
		mem2cache_address = 12'hCF8;
		mem2cache_data = 32'h00700700;
	end
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;

	wait((cache2mem_msg == WB_REQ) & (cache2mem_address == 12'hAF8));
	repeat(1) @(posedge clock);
	@(posedge clock) mem2cache_msg = MEM_READY;

	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'hEF8));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg     = MEM_SENT;
		mem2cache_address = 12'hEF8;
		mem2cache_data    = 32'h15253545;
	end
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;

	wait((cache2mem_msg == WB_REQ) & (cache2mem_address == 12'hEF8));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg     = REQ_FLUSH;
		mem2cache_address = 12'hCF8;
	end
	wait((cache2mem_msg == FLUSH) & (cache2mem_address == 12'hCF8));
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;
	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'hBF8));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg     = MEM_SENT;
		mem2cache_address = 12'hBF8;
		mem2cache_data    = 32'hFCFFFCCC;
	end
	@(posedge clock) mem2cache_msg = MEM_NO_MSG;
	

end

initial //cache 1
begin
	address0 = 0;
	data_in0 = 0;
	msg_in0  = 0;
	//wait(reset == 0)
	wait(DUT.state == IDLE)
	@(posedge clock) begin
		address0 = 12'h3FC;
		msg_in0  = R_REQ;
	end
	wait(msg_out0 == MEM_SENT)
	@(posedge clock) msg_in0 = NO_REQ;
	#160;
	@(posedge clock) begin
		address0 = 12'h3FC;
		msg_in0  = WB_REQ;
		data_in0 = 32'h11000044;
	end
	wait(msg_out0 == MEM_READY)
	@(posedge clock) msg_in0 = NO_REQ;

	wait(msg_out0 == REQ_FLUSH);
	repeat(2) @(posedge clock);
	@(posedge clock) begin
		data_in0 = 36'hCABCDABCD;
		address0 = 12'h9FC;
		msg_in0  = FLUSH;
	end

	wait(msg_out0 == MEM_NO_MSG);
	@(posedge clock) msg_in0 = NO_REQ;

	wait((msg_out0 == REQ_FLUSH) & (out_address0 == 12'h2F8));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		msg_in0 = NO_FLUSH;
	end
	wait(msg_out0 == MEM_NO_MSG);
	@(posedge clock) msg_in0 = NO_REQ;

	wait((msg_out0 == REQ_FLUSH) & (out_address0 == 12'h6FC));
	repeat(2) @(posedge clock);
	@(posedge clock)begin
		msg_in0 = NO_FLUSH;
	end
	wait(msg_out0 == MEM_NO_MSG);
	@(posedge clock) msg_in0 = NO_REQ;

	wait((msg_out0 == REQ_FLUSH) & (out_address0 == 12'hFFC));
	repeat(2) @(posedge clock);
	@(posedge clock)begin
		msg_in0 = NO_FLUSH;
	end
	wait(msg_out0 == MEM_NO_MSG);
	@(posedge clock) msg_in0 = NO_REQ;

	repeat(99) @(posedge clock);
	@(posedge clock)begin
		msg_in0  = WB_REQ;
		address0 = 12'hAF8;
		data_in0 = 32'h10001000;
	end
	wait((msg_out0 == REQ_FLUSH) & (out_address0 == 12'h7F8));
	@(posedge clock)begin
		msg_in0  = FLUSH;
		address0 = 12'h7F8;
		data_in0 = 36'hC02200220;
	end
	wait(msg_out0 == MEM_NO_MSG);
	@(posedge clock)begin
		msg_in0  = WB_REQ;
		address0 = 12'hAF8;
		data_in0 = 32'h10001000;
	end
	wait(msg_out0 == MEM_READY);
	@(posedge clock) msg_in0 = NO_REQ;
end

initial //cache 2
begin
       	address1 = 0;
	data_in1 = 0;
	msg_in1  = 0;
	//#350;
    wait(DUT.state == IDLE);
    #310;
	@(posedge clock)begin
		msg_in1  = R_REQ;
		address1 = 12'h9FC;
	end
	wait(msg_out1 == MEM_SENT)
	@(posedge clock) msg_in1 = NO_REQ;

	repeat(2) @(posedge clock);

	@(posedge clock)begin
		msg_in1  = R_REQ;
		address1 = 12'hAFC;
	end
	wait(msg_out1 == MEM_SENT)
	@(posedge clock) msg_in1 = NO_REQ;

	repeat(2) @(posedge clock);
	@(posedge clock)begin
		msg_in1  = WB_REQ;
		address1 = 12'hAFC;
		data_in1 = 32'h00110022;
	end
	wait(msg_out1 == MEM_READY)
	@(posedge clock) msg_in1 = NO_REQ;

	repeat(2) @(posedge clock);
	@(posedge clock)begin
		msg_in1  = R_REQ;
		address1 = 12'h9FC;
	end
	wait(msg_out1 == MEM_SENT)
	@(posedge clock) msg_in1 = NO_REQ;

	repeat(2) @(posedge clock);
	@(posedge clock)begin
		msg_in1  = WB_REQ;
		address1 = 12'h6FC;
		data_in1 = 32'h45454545;
	end
	wait(msg_out1 == MEM_READY)
	@(posedge clock) msg_in1 = NO_REQ;

	repeat(3) @(posedge clock);
	@(posedge clock) begin
		msg_in1  = R_REQ;
		address1 = 12'hFFC;
	end
	wait((msg_out1 == MEM_SENT) & (out_address1 == 12'hFFC));
	@(posedge clock) msg_in1 = NO_REQ;

	wait((msg_out1 == REQ_FLUSH) & (out_address1 == 12'h2F8));
	repeat(2) @(posedge clock);
	@(posedge clock)begin
		msg_in1 = NO_FLUSH;
	end
	wait(msg_out1 == MEM_NO_MSG);
	@(posedge clock) msg_in1 = NO_REQ;

	wait((msg_out1 == REQ_FLUSH) & (out_address1 == 12'h6FC));
	repeat(2) @(posedge clock);
	@(posedge clock)begin
		msg_in1 = NO_FLUSH;
	end
	wait(msg_out1 == MEM_NO_MSG);
	@(posedge clock) msg_in1 = NO_REQ;

	wait((msg_out1 == REQ_FLUSH) & (out_address1 == 12'hFFC));
	repeat(2) @(posedge clock);
	@(posedge clock)begin
		msg_in1 = NO_FLUSH;
	end
	wait(msg_out1 == MEM_NO_MSG);
	@(posedge clock) msg_in1 = NO_REQ;
	
	repeat(82) @(posedge clock);
	@(posedge clock)begin
		msg_in1  = WB_REQ;
		address1 = 12'h3F8;
		data_in1 = 32'h25652565;
	end
	wait(msg_out1 == MEM_READY);
	@(posedge clock) msg_in1 = NO_REQ;
	
	@(posedge clock)begin
		msg_in1 = R_REQ;
		address1 = 12'h7F8;
	end
	wait((msg_out1 == MEM_SENT) & (out_address1 == 12'h7F8));
	@(posedge clock) msg_in1 = NO_REQ;

	//repeat(50) @(posedge clock);
	repeat(52) @(posedge clock);
	@(posedge clock) begin
		msg_in1  = WB_REQ;
		address1 = 12'hEF8;
		data_in1 = 32'h66662222;
	end
	wait(msg_out1 == MEM_READY);
	@(posedge clock) msg_in1 = NO_REQ;
end

initial //cache 3
begin
	address2 = 0;
	data_in2 = 0;
	msg_in2  = 0;
	//#110;
    wait(DUT.state == IDLE);
    #70;
	@(posedge clock)begin
		msg_in2 = R_REQ;
		address2 = 12'h9FC;
	end
	wait(msg_out2 == MEM_SENT)
	@(posedge clock) msg_in2 = NO_REQ;

	#780;
	@(posedge clock)begin
		address2 = 12'h6FC;
		msg_in2  = R_REQ;
	end
	wait((msg_out2 == MEM_SENT) & (out_address2 == 12'h6FC));
	@(posedge clock) msg_in2 = NO_REQ;

	wait((msg_out2 == REQ_FLUSH) & (out_address2 == 12'h2F8));
	repeat(3) @(posedge clock);
	@(posedge clock)begin
		msg_in2 = NO_FLUSH;
	end
	wait(msg_out2 == MEM_NO_MSG);
	@(posedge clock) msg_in2 = NO_REQ;

	wait((msg_out2 == REQ_FLUSH) & (out_address2 == 12'h6FC));
	repeat(2) @(posedge clock);
	@(posedge clock)begin
		msg_in2 = NO_FLUSH;
	end
	wait(msg_out2 == MEM_NO_MSG);
	@(posedge clock) msg_in2 = NO_REQ;

	wait((msg_out2 == REQ_FLUSH) & (out_address2 == 12'hFFC));
	repeat(2) @(posedge clock);
	@(posedge clock)begin
		msg_in2 = NO_FLUSH;
	end
	wait(msg_out2 == MEM_NO_MSG);
	@(posedge clock) msg_in2 = NO_REQ;
	
	repeat(82) @(posedge clock);
	@(posedge clock)begin
		msg_in2  = WB_REQ;
		address2 = 12'h7F8;
		data_in2 = 32'h66665555;
	end
	wait(msg_out2 == MEM_READY);
	@(posedge clock) msg_in2 = NO_REQ;
	
	@(posedge clock)begin
		msg_in2 = R_REQ;
		address2 = 12'h3F8;
	end
	wait((msg_out2 == MEM_SENT) & (out_address2 == 12'h3F8));
	@(posedge clock) msg_in2 = NO_REQ;

	repeat(4) @(posedge clock);
	@(posedge clock)begin
		msg_in2  = WB_REQ;
		address2 = 12'h3F8;
		data_in2 = 32'h77774444;
	end
	wait(msg_out2 == MEM_READY);
	@(posedge clock) msg_in2 = NO_REQ;

	@(posedge clock)begin
		msg_in2  = R_REQ;
		address2 = 12'hCF8;
	end
	wait((msg_out2 == MEM_SENT) & (out_address2 == 12'hCF8));
	@(posedge clock) msg_in2 = NO_REQ;

	@(posedge clock)begin
		msg_in2  = R_REQ;
		address2 = 12'hEF8;
	end
	wait(msg_out2 == MEM_SENT);
	@(posedge clock) msg_in2 = NO_REQ;

	repeat(1) @(posedge clock);
	@(posedge clock)begin
		msg_in2  = WB_REQ;
		address2 = 12'hCF8;
		data_in2 = 32'h22266626;
	end
	wait(msg_out2 == MEM_READY);
	@(posedge clock) msg_in2 = NO_REQ;
	
	@(posedge clock)begin
		msg_in2  = R_REQ;
		address2 = 12'hBF8;
	end
	wait(msg_out2 == MEM_SENT);
	@(posedge clock) msg_in2 = NO_REQ;

end

initial //cache 4
begin
	address3 = 0;
	data_in3 = 0;
	msg_in3  = 0;
	//#110;
    wait(DUT.state == IDLE);
    #70;
	@(posedge clock)begin
		msg_in3 = R_REQ;
		address3 = 12'h2F8;
	end
	wait(msg_out3 == MEM_SENT)
	@(posedge clock) msg_in3 = NO_REQ;

	wait((msg_out3 == REQ_FLUSH) & (out_address3 == 12'h2F8));
	repeat(4) @(posedge clock);
	@(posedge clock)begin
		msg_in3 = NO_FLUSH;
	end
	wait(msg_out3 == MEM_NO_MSG);
	@(posedge clock) msg_in3 = NO_REQ;

	wait((msg_out3 == REQ_FLUSH) & (out_address3 == 12'h6FC));
	repeat(2) @(posedge clock);
	@(posedge clock)begin
		msg_in3 = NO_FLUSH;
	end
	wait(msg_out3 == MEM_NO_MSG);
	@(posedge clock) msg_in3 = NO_REQ;

	wait((msg_out3 == REQ_FLUSH) & (out_address3 == 12'hFFC));
	repeat(2) @(posedge clock);
	@(posedge clock)begin
		msg_in3  = FLUSH;
		data_in3 = 36'hC33331111;
		address3 = 32'hFFC;
	end
	wait(msg_out3 == MEM_NO_MSG);
	@(posedge clock) msg_in3 = NO_REQ;

	#30;
	@(posedge clock)begin
		msg_in3 = R_REQ;
		address3 = 12'h1FC;
	end
	wait(msg_out3 == MEM_SENT);
	@(posedge clock) msg_in3 = NO_REQ;

	#20;
	@(posedge clock)begin
		msg_in3  = FLUSH;
		address3 = 12'hDFC;	  //This combination is not exactly accurate because this address cannot be in the upper level (it should be to have a value)
		data_in3 = 36'hC8888_8888; // But this does not break the cache algorithm.
	end
	wait(msg_out3 == M_RECV);
	@(posedge clock) msg_in3 = NO_REQ;

	wait(msg_out3 == MEM_NO_MSG);
	repeat(2) @(posedge clock);
	@(posedge clock)begin
		msg_in3  = FLUSH;
		address3 = 12'h1FC;
        data_in3 = 0;
	end
	wait(msg_out3 == M_RECV);
	@(posedge clock) msg_in3 = NO_REQ;
	
	wait(msg_out3 == MEM_NO_MSG);
	repeat(2) @(posedge clock);
	@(posedge clock)begin
		msg_in3 = R_REQ;
		address3 = 12'h4FC;
	end
	wait(msg_out3 == MEM_SENT);
	@(posedge clock)msg_in3 = NO_REQ;
	wait(msg_out3 == MEM_NO_MSG);
	//repeat(2) @(posedge clock);
	@(posedge clock)begin
		msg_in3 = R_REQ;
		address3 = 12'h5FC;
	end
	wait(msg_out3 == MEM_SENT);
	@(posedge clock) msg_in3 = NO_REQ;

	repeat(2) @(posedge clock);
	@(posedge clock)begin
		msg_in3  = INVLD;
		address3 = 12'h4FC;
        data_in3 = 36'hC00000000;
	end
	wait(msg_out3 == M_RECV);
	@(posedge clock) msg_in3 = NO_REQ;

	wait(msg_out3 == MEM_NO_MSG);
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		msg_in3  = INVLD;
		address3 = 12'h5FC;
        data_in3 = 0;
	end
	wait(msg_out3 == M_RECV);
	@(posedge clock) msg_in3 = NO_REQ;

end


// self checking code
reg [BUS_WIDTH_UP-1 : 0] data_out0_c, data_out1_c, data_out2_c, data_out3_c;
reg [MSG_BITS-1 : 0] msg_out0_c, msg_out1_c, msg_out2_c, msg_out3_c;
reg [ADDRESS_WIDTH-1 : 0] out_address0_c, out_address1_c, out_address2_c, out_address3_c;
reg [BUS_WIDTH_DOWN-1 : 0] cache2mem_data_c;
reg [ADDRESS_WIDTH-1 : 0] cache2mem_address_c;
reg [MSG_BITS-1 : 0] cache2mem_msg_c;
reg [3:0] state_c;

wire c_data_out0 = |(data_out0 ^ data_out0_c);
wire c_data_out1 = |(data_out1 ^ data_out1_c);
wire c_data_out2 = |(data_out2 ^ data_out2_c);
wire c_data_out3 = |(data_out3 ^ data_out3_c);

wire c_msg_out0 = |(msg_out0 ^ msg_out0_c);
wire c_msg_out1 = |(msg_out1 ^ msg_out1_c);
wire c_msg_out2 = |(msg_out2 ^ msg_out2_c);
wire c_msg_out3 = |(msg_out3 ^ msg_out3_c);

wire c_out_address0 = |(out_address0 ^ out_address0_c);
wire c_out_address1 = |(out_address1 ^ out_address1_c);
wire c_out_address2 = |(out_address2 ^ out_address2_c);
wire c_out_address3 = |(out_address3 ^ out_address3_c);

wire c_cache2mem_data    = |(cache2mem_data ^ cache2mem_data_c);
wire c_cache2mem_address = |(cache2mem_address ^ cache2mem_address_c);
wire c_cache2mem_msg     = |(cache2mem_msg ^ cache2mem_msg_c);
wire c_state             = |(DUT.state ^ state_c);

wire mismatch;

assign mismatch = c_data_out0 | c_data_out1 | c_data_out2 | c_data_out3 |
                c_msg_out0 | c_msg_out1 | c_msg_out2 | c_msg_out3 |
				c_out_address0 | c_out_address1 | c_out_address2 | c_out_address3 |
				c_cache2mem_address | c_cache2mem_data | c_cache2mem_msg | c_state;

initial begin
msg_out0_c <= MEM_NO_MSG;
msg_out1_c <= MEM_NO_MSG;
msg_out2_c <= MEM_NO_MSG;
msg_out3_c <= MEM_NO_MSG;
out_address0_c <= 0;
out_address1_c <= 0;
out_address2_c <= 0;
out_address3_c <= 0;
data_out0_c <= 0;
data_out1_c <= 0;
data_out2_c <= 0;
data_out3_c <= 0;
cache2mem_address_c <= 0;
cache2mem_data_c <= 0;
cache2mem_msg_c <= NO_REQ;
state_c <= RESET;

#680;
//repeat(67) @(posedge clock);
//@(posedge clock)
state_c <= IDLE;

#20;	//60
state_c <= SERVING;
#10;	//70
state_c <= READ_ST;
cache2mem_address_c <= 12'h3FC;
cache2mem_msg_c     <= R_REQ;
#30;	//100
state_c <= UPDATE;
cache2mem_msg_c <= NO_REQ;
cache2mem_address_c <= 0;
#10;	//110
state_c <= READ_OUT;
#10;	//120
state_c <= IDLE;
msg_out0_c <= MEM_SENT;
out_address0_c <= 12'h3FC;
data_out0_c <= 36'h911223344;
#10;	//130
msg_out0_c <= MEM_NO_MSG;
out_address0_c <= 0;
data_out0_c <= 0;
#10;	//140
state_c <= SERVING;
#10;	//150
state_c <= READ_ST;
cache2mem_address_c <= 12'h9FC;
cache2mem_msg_c <= R_REQ;
#30;	//180
state_c <= UPDATE;
cache2mem_msg_c <= NO_REQ;
cache2mem_address_c <= 0;
#10;	//190
state_c <= READ_OUT;
#10;	//200
state_c <= IDLE;
msg_out2_c <= MEM_SENT;
out_address2_c <= 12'h9FC;
data_out2_c <= 36'h998765432;
#10;	//210
msg_out2_c <= MEM_NO_MSG;
out_address2_c <= 0;
data_out2_c <= 0;
#10;	//220
state_c <= SERVING;
#10;	//230
state_c <= READ_ST;
cache2mem_address_c <= 12'h2F8;
cache2mem_msg_c <= R_REQ;
#30;	//260
state_c <= UPDATE;
cache2mem_msg_c <= NO_REQ;
cache2mem_address_c <= 0;
#10;	//270
state_c <= READ_OUT;
#10;	//280
state_c <= IDLE;
msg_out3_c <= MEM_SENT;
out_address3_c <= 12'h2F8;
data_out3_c <= 36'h9AABBCCDD;
#10;	//290
msg_out3_c <= MEM_NO_MSG;
out_address3_c <= 0;
data_out3_c <= 0;
#10;	//300
state_c <= SERVING;
#10;	//310
state_c <= WRITE;
#10;	//320
state_c <= IDLE;
msg_out0_c <= MEM_READY;
#10;	//330
msg_out0_c <= MEM_NO_MSG;
#30;	//360
state_c <= SERVING;
#10;	//370
state_c <= READ_OUT;
#10;	//380
state_c <= IDLE;
msg_out1_c <= MEM_SENT;
out_address1_c <= 12'h9FC;
data_out1_c <= 36'hb98765432;
#10;	//390
msg_out1_c <= MEM_NO_MSG;
out_address1_c <= 0;
data_out1_c <= 0;
#40;	//430
state_c <= SERVING;
#10;	//440
state_c <= WRITE_BACK;
cache2mem_msg_c <= WB_REQ;
cache2mem_address_c <= 12'h3FC;
cache2mem_data_c <= 37'h1811000044;
#30;	//470
state_c <= READ_ST;
cache2mem_msg_c <= R_REQ;
cache2mem_address_c <= 12'hAFC;
cache2mem_data_c <= 0;
#30;	//500
state_c <= UPDATE;
cache2mem_msg_c <= NO_REQ;
cache2mem_address_c <= 0;
#10;	//510
state_c <= READ_OUT;
#10;	//520
state_c <= IDLE;
msg_out1_c <= MEM_SENT;
out_address1_c <= 12'hAFC;
data_out1_c <= 36'h9FFFFEEEE;
#10;	//530
msg_out1_c <= MEM_NO_MSG;
out_address1_c <= 0;
data_out1_c	<= 0;
#40;	//570
state_c <= SERVING;
#10;	//580
state_c <= WRITE;
#10;	//590
state_c <= IDLE;
msg_out1_c <= MEM_READY;
#10;	//600
msg_out1_c <= MEM_NO_MSG;
#40;	//640
state_c <= SERVING;
#10;	//650
state_c <= READ_OUT;
#10;	//660
state_c <= IDLE;
msg_out1_c <= MEM_SENT;
out_address1_c <= 12'h9FC;
data_out1_c	<= 36'hB98765432;
#10;	//670
msg_out1_c <= MEM_NO_MSG;
out_address1_c <= 0;
data_out1_c	<= 0;
#40;	//710
state_c <= SERVING;
#10;	//720
state_c <= WRITE_BACK;
cache2mem_address_c <= 12'hAFC;
cache2mem_msg_c <= WB_REQ;
cache2mem_data_c <= 37'h1800110022;
#30;	//750
state_c <= WRITE;
cache2mem_msg_c <= NO_REQ;
cache2mem_address_c <= 0;
cache2mem_data_c <= 0;
#10;	//760
state_c <= IDLE;
msg_out1_c <= MEM_READY;
#10;	//770
msg_out1_c <= MEM_NO_MSG;
#50;	//820
state_c <= SERVING;
#10;	//830
state_c <= FLUSH_WAIT;
msg_out0_c <= REQ_FLUSH;
msg_out1_c <= REQ_FLUSH;
msg_out2_c <= REQ_FLUSH;
msg_out3_c <= REQ_FLUSH;
out_address0_c <= 12'h9FC;
out_address1_c <= 12'h9FC;
out_address2_c <= 12'h9FC;
out_address3_c <= 12'h9FC;
#40;	//870
state_c <= WRITE_BACK;
msg_out0_c <= MEM_NO_MSG;
msg_out1_c <= MEM_NO_MSG;
msg_out2_c <= MEM_NO_MSG;
msg_out3_c <= MEM_NO_MSG;
out_address0_c <= 0;
out_address1_c <= 0;
out_address2_c <= 0;
out_address3_c <= 0;
cache2mem_address_c <= 12'h9FC;
cache2mem_msg_c <= WB_REQ;
cache2mem_data_c <= 37'h18ABCDABCD;
#30;	//900
state_c <= READ_ST;
cache2mem_address_c <= 12'hFFC;
cache2mem_msg_c <= R_REQ;
cache2mem_data_c <= 0;
#30;	//930
state_c <= UPDATE;
cache2mem_address_c <= 0;
cache2mem_msg_c <= NO_REQ;
#10;	//940
state_c <= READ_OUT;
#10;	//950
state_c <= IDLE;
msg_out1_c <= MEM_SENT;
out_address1_c <= 12'hFFC;
data_out1_c <= 36'h911111111;
#10;	//960
msg_out1_c <= MEM_NO_MSG;
out_address1_c <= 0;
data_out1_c <= 0;
#40;	//1000
state_c <= SERVING;
#10;	//1010
state_c <= READ_OUT;
#10;	//1020
state_c <= IDLE;
msg_out2_c <= MEM_SENT;
out_address2_c <= 12'h6FC;
data_out2_c <= 37'hD45454545;
#10;	//1030
msg_out2_c <= MEM_NO_MSG;
out_address2_c <= 0;
data_out2_c <= 0;
#40;	//1070
state_c <= SERVING;
#10;	//1080
state_c <= FLUSH_WAIT;
msg_out0_c <= REQ_FLUSH;
msg_out1_c <= REQ_FLUSH;
msg_out2_c <= REQ_FLUSH;
msg_out3_c <= REQ_FLUSH;
out_address0_c <= 12'h2F8;
out_address1_c <= 12'h2F8;
out_address2_c <= 12'h2F8;
out_address3_c <= 12'h2F8;
#60;	//1140
state_c <= NO_FLUSH_RESP;
cache2mem_msg_c <= NO_FLUSH;
#20;	//1160
state_c <= BRAM_DELAY;
cache2mem_msg_c <= NO_REQ;
#10;	//1170
state_c <= IDLE;
msg_out0_c <= MEM_NO_MSG;
msg_out1_c <= MEM_NO_MSG;
msg_out2_c <= MEM_NO_MSG;
msg_out3_c <= MEM_NO_MSG;
out_address0_c <= 0;
out_address1_c <= 0;
out_address2_c <= 0;
out_address3_c <= 0;
#20;	//1190
state_c <= SERVING;
#10;	//1200
state_c <= FLUSH_WAIT;
msg_out0_c <= REQ_FLUSH;
msg_out1_c <= REQ_FLUSH;
msg_out2_c <= REQ_FLUSH;
msg_out3_c <= REQ_FLUSH;
out_address0_c <= 12'h6FC;
out_address1_c <= 12'h6FC;
out_address2_c <= 12'h6FC;
out_address3_c <= 12'h6FC;
#40;	//1240
state_c <= SERV_FLUSH_REQ;
cache2mem_msg_c <= FLUSH;
cache2mem_address_c <= 12'h6FC;
cache2mem_data_c <= 37'h1D45454545;
msg_out0_c <= MEM_NO_MSG;
msg_out1_c <= MEM_NO_MSG;
msg_out2_c <= MEM_NO_MSG;
msg_out3_c <= MEM_NO_MSG;
out_address0_c <= 0;
out_address1_c <= 0;
out_address2_c <= 0;
out_address3_c <= 0;
#20;	//1260
state_c <= BRAM_DELAY;
cache2mem_msg_c <= NO_REQ;
cache2mem_address_c <= 0;
cache2mem_data_c <= 0;
#10;
state_c <= IDLE;
#20;	//1290
state_c <= SERVING;
#10;	//1300
state_c <= FLUSH_WAIT;
msg_out0_c <= REQ_FLUSH;
msg_out1_c <= REQ_FLUSH;
msg_out2_c <= REQ_FLUSH;
msg_out3_c <= REQ_FLUSH;
out_address0_c <= 12'hFFC;
out_address1_c <= 12'hFFC;
out_address2_c <= 12'hFFC;
out_address3_c <= 12'hFFC;
#40;	//1340
state_c <= SERV_FLUSH_REQ;
msg_out0_c <= MEM_NO_MSG;
msg_out1_c <= MEM_NO_MSG;
msg_out2_c <= MEM_NO_MSG;
msg_out3_c <= MEM_NO_MSG;
out_address0_c <= 0;
out_address1_c <= 0;
out_address2_c <= 0;
out_address3_c <= 0;
cache2mem_msg_c <= FLUSH;
cache2mem_address_c <= 12'hFFC;
cache2mem_data_c <= 37'h1833331111;
#30;	//1370
state_c <= BRAM_DELAY;
cache2mem_msg_c <= NO_REQ;
cache2mem_address_c <= 0;
cache2mem_data_c <= 0;
#10;
state_c <= IDLE;
#10;	//1390
state_c <= SERVING;
#10;	//1400
state_c <= READ_ST;
cache2mem_msg_c <= R_REQ;
cache2mem_address_c <= 12'h1FC;
#20;	//1420
state_c <= UPDATE;
cache2mem_msg_c <= NO_REQ;
cache2mem_address_c <= 0;
#10;	//1430
state_c <= READ_OUT;
#10;	//1440
state_c <= IDLE;
msg_out3_c <= MEM_SENT;
out_address3_c <= 12'h1FC;
data_out3_c <= 36'h999999999;
#10;	//1450
msg_out3_c <= MEM_NO_MSG;
out_address3_c <= 0;
data_out3_c <= 0;
#30;	//1480
state_c <= SERVING;
#10;	//1490
state_c <= SERV_FLUSH_REQ;
msg_out3_c <= M_RECV;
cache2mem_msg_c <= FLUSH;
cache2mem_address_c <= 12'hDFC;
cache2mem_data_c <= 37'h1888888888;
#40;	//1530
state_c <= NO_FLUSH_RESP;
cache2mem_msg_c <= NO_REQ;
cache2mem_address_c <= 0;
cache2mem_data_c <= 0;
#20;	//1550
state_c <= BRAM_DELAY;
#10;	//1560
state_c <= IDLE;
msg_out3_c <= MEM_NO_MSG;
#40;	//1600
state_c <= SERVING;
#10;	//1610
state_c <= SERV_FLUSH_REQ;
msg_out3_c <= M_RECV;
cache2mem_msg_c <= FLUSH;
cache2mem_address_c <= 12'h1FC;
cache2mem_data_c <= 37'h1599999999;
#40;	//1650
state_c <= NO_FLUSH_RESP;
cache2mem_msg_c <= NO_REQ;
cache2mem_address_c <= 0;
cache2mem_data_c <= 0;
#40;	//1690
state_c <= BRAM_DELAY;
#10;	//1700
state_c <= IDLE;
msg_out3_c <= MEM_NO_MSG;
#40;	//1740
state_c <= SERVING;
#10;	//1750
state_c <= READ_ST;
cache2mem_msg_c <= R_REQ;
cache2mem_address_c <= 12'h4FC;
#40;	//1790
state_c <= UPDATE;
cache2mem_msg_c <= NO_REQ;
cache2mem_address_c <= 0;
#10;	//1800
state_c <= READ_OUT;
#10;	//1810
state_c <= IDLE;
msg_out3_c <= MEM_SENT;
out_address3_c <= 12'h4FC;
data_out3_c <= 36'h9AAAAAAAA;
#10;	//1820
msg_out3_c <= MEM_NO_MSG;
out_address3_c <= 0;
data_out3_c <= 0;
#20;	//1840
state_c <= SERVING;
#10;	//1850
state_c <= READ_ST;
cache2mem_msg_c <= R_REQ;
cache2mem_address_c <= 12'h5FC;
#40;	//1890
state_c <= UPDATE;
cache2mem_msg_c <= 0;
cache2mem_address_c <= 0;
#10;	//1900
state_c <= READ_OUT;
#10;	//1910
state_c <= IDLE;
msg_out3_c <= MEM_SENT;
out_address3_c <= 12'h5FC;
data_out3_c <= 36'h9bdbdbdbd;
#10;	//1920
msg_out3_c <= MEM_NO_MSG;
out_address3_c <= 0;
data_out3_c <= 0;
#40;	//1960
state_c <= SERVING;
#10;	//1970
state_c <= SERV_INVLD;
msg_out3_c <= M_RECV;
cache2mem_msg_c <= INVLD;
cache2mem_address_c <= 12'h4FC;
cache2mem_data_c <= 37'h1800000000;
#40;	//2010
state_c	<= WAIT_INVLD;
cache2mem_msg_c <= NO_REQ;
cache2mem_address_c <= 0;
cache2mem_data_c <= 0;
#40;	//2050
state_c <= BRAM_DELAY;
#10;	//2060
state_c <= IDLE;
msg_out3_c <= MEM_NO_MSG;
#30;	//2090
state_c <= SERVING;
#10;	//2100
state_c <= SERV_INVLD;
msg_out3_c <= M_RECV;
cache2mem_msg_c <= INVLD;
cache2mem_address_c <= 12'h5FC;
cache2mem_data_c <= 37'h15BDBDBDBD;
#30;	//2130
state_c <= WAIT_INVLD;
cache2mem_msg_c <= NO_REQ;
cache2mem_address_c <= 0;
cache2mem_data_c <= 0;
#30;	//2160
state_c <= BRAM_DELAY;
#10;	//2170
state_c <= IDLE;
msg_out3_c <= MEM_NO_MSG;
#20;	//2190
state_c <= SERVING;
#10;	//2200
state_c <= WRITE;
#10;	//2210
state_c <= IDLE;
msg_out1_c <= MEM_READY;
#10;	//2220
msg_out1_c <= MEM_NO_MSG;
#10;	//2230
state_c <= SERVING;
#10;	//2240
state_c <= WRITE;
#10;	//2250
state_c <= IDLE;
msg_out2_c <= MEM_READY;
#10;	//2260
msg_out2_c <= MEM_NO_MSG;
#10;	//2270
state_c <= SERVING;
#10;	//2280
state_c <= READ_OUT;
#10;	//2290
state_c <= IDLE;
msg_out1_c <= MEM_SENT;
data_out1_c <= 36'hD66665555;
out_address1_c <= 12'h7F8;
#10;	//2300
msg_out1_c <= MEM_NO_MSG;
data_out1_c <= 0;
out_address1_c <= 0;
#10;	//2310
state_c <= SERVING;
#10;	//2320
state_c <= READ_OUT;
#10;	//2330
state_c <= IDLE;
msg_out2_c <= MEM_SENT;
data_out2_c <= 36'hD25652565;
out_address2_c <= 12'h3F8;
#10;	//2340
msg_out2_c <= MEM_NO_MSG;
data_out2_c <= 0;
out_address2_c <= 0;
#20;	//2360
state_c <= SERVING;
#10;	//2370
state_c <= FLUSH_WAIT;
msg_out0_c <= REQ_FLUSH;
msg_out1_c <= REQ_FLUSH;
msg_out2_c <= REQ_FLUSH;
msg_out3_c <= REQ_FLUSH;
out_address0_c <= 12'h7F8;
out_address1_c <= 12'h7F8;
out_address2_c <= 12'h7F8;
out_address3_c <= 12'h7F8;
#20;	//2390
state_c <= WRITE_BACK;
msg_out0_c <= MEM_NO_MSG;
msg_out1_c <= MEM_NO_MSG;
msg_out2_c <= MEM_NO_MSG;
msg_out3_c <= MEM_NO_MSG;
out_address0_c <= 0;
out_address1_c <= 0;
out_address2_c <= 0;
out_address3_c <= 0;
cache2mem_msg_c <= WB_REQ;
cache2mem_address_c <= 12'h7F8;
cache2mem_data_c <= 37'h1802200220;
#30;	//2420
state_c <= BRAM_DELAY;
cache2mem_msg_c <= NO_REQ;
cache2mem_address_c <= 0;
cache2mem_data_c <= 0;
#10;
state_c <= IDLE;
#10;	//2430
state_c <= SERVING;
#10;	//2440
state_c <= WRITE;
#10;	//2450
state_c <= IDLE;
msg_out0_c <= MEM_READY;
#10;	//2460
msg_out0_c <= MEM_NO_MSG;
#10;	//2470
state_c <= SERVING;
#10;	//2480
state_c <= WRITE;
#10;	//2490
state_c <= IDLE;
msg_out2_c <= MEM_READY;
#10;	//2500
msg_out2_c <= MEM_NO_MSG;
#20;	//2520
state_c <= SERVING;
#10;	//2530
state_c <= WRITE_BACK;
cache2mem_msg_c <= WB_REQ;
cache2mem_address_c <= 12'hAF8;
cache2mem_data_c <= 37'h1810001000;
#30;	//2560
state_c <= SERVING;
#10;	//2570
state_c <= SERV_FLUSH_REQ;
cache2mem_msg_c <= FLUSH;
cache2mem_address_c <= 12'h3F8;
cache2mem_data_c <= 37'h1877774444;
#30;	//2600
state_c <= BRAM_DELAY;
cache2mem_msg_c <= NO_REQ;
cache2mem_address_c <= 0;
cache2mem_data_c <= 0;
#10;
state_c <= IDLE;
#10;	//2610
state_c <= SERVING;
#10;	//2620
state_c <= READ_ST;
cache2mem_msg_c <= R_REQ;
cache2mem_address_c <= 12'hCF8;
#30;	//2650
state_c <= UPDATE;
cache2mem_msg_c <= NO_REQ;
cache2mem_address_c <= 0;
#10;	//2660
state_c <= READ_OUT;
#10;	//2670
state_c <= IDLE;
msg_out2_c <= MEM_SENT;
out_address2_c <= 12'hCF8;
data_out2_c <= 36'h900700700;
#10;	//2680
msg_out2_c <= MEM_NO_MSG;
out_address2_c <= 0;
data_out2_c <= 0;
#20;	//2700
state_c <= SERVING;
#10;	//2710
state_c <= WRITE_BACK;
cache2mem_msg_c <= WB_REQ;
cache2mem_address_c <= 12'hAF8;
cache2mem_data_c <= 37'h1810001000;
#30;	//2740
state_c <= READ_ST;
cache2mem_msg_c <= R_REQ;
cache2mem_address_c <= 12'hEF8;
cache2mem_data_c <= 0;
#30;	//2770
state_c <= UPDATE;
cache2mem_msg_c <= NO_REQ;
cache2mem_address_c <= 0;
#10;	//2780
state_c <= READ_OUT;
#10;	//2790
state_c <= IDLE;
msg_out2_c <= MEM_SENT;
out_address2_c <= 12'hEF8;
data_out2_c <= 36'h915253545;
#10;	//2800
msg_out2_c <= MEM_NO_MSG;
out_address2_c <= 0;
data_out2_c <= 0;
#20;	//2820
state_c <= SERVING;
#10;	//2830
state_c <= WRITE;
#10;	//2840
state_c <= IDLE;
msg_out1_c <= MEM_READY;
#10;	//2850
msg_out1_c <= MEM_NO_MSG;
#10;	//2860
state_c <= SERVING;
#10;	//2870
state_c <= WRITE;
#10;	//2880
state_c <= IDLE;
msg_out2_c <= MEM_READY;
#10;	//2890
msg_out2_c <= MEM_NO_MSG;
#20;	//2910
state_c <= SERVING;
#10;	//2920
state_c <= WRITE_BACK;
cache2mem_msg_c     <= WB_REQ;
cache2mem_address_c <= 12'hEF8;
cache2mem_data_c    <= 37'h1866662222;
#30;	//2950
state_c <= SERVING;
#10;	//2960
state_c <= SERV_FLUSH_REQ;
cache2mem_msg_c     <= FLUSH;
cache2mem_address_c <= 12'hCF8;
cache2mem_data_c    <= 37'h1822266626;
#20;	//2980
state_c <= BRAM_DELAY;
cache2mem_msg_c     <= NO_REQ;
cache2mem_address_c <= 0;
cache2mem_data_c    <= 0;
#10;
state_c <= IDLE;
#10;	//2990
state_c <= SERVING;
#10;	//3000
state_c <= READ_ST;
cache2mem_msg_c     <= R_REQ;
cache2mem_address_c <= 12'hBF8;
#30;	//3030
state_c <= UPDATE;
cache2mem_msg_c     <= NO_REQ;
cache2mem_address_c <= 0;
#10;	//3040
state_c <= READ_OUT;
#10;	//3050
state_c <= IDLE;
msg_out2_c <= MEM_SENT;
data_out2_c <= 36'h9FCFFFCCC;
out_address2_c <= 12'hBF8;
#10;	//3060
msg_out2_c <= MEM_NO_MSG;
data_out2_c <= 0;
out_address2_c <= 0;












end










endmodule
