module tb_l1cache ();

parameter STATUS_BITS           = 2,
          COHERENCE_BITS        = 2,
          OFFSET_BITS           = 2,
          DATA_WIDTH            = 8,
          NUMBER_OF_WAYS        = 4,
          REPLACEMENT_MODE_BITS = 1,
	      ADDRESS_WIDTH         = 12,
	      INDEX_BITS            = 2,
	      MSG_BITS              = 3;

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

localparam WORDS_PER_LINE = 1 << OFFSET_BITS;
localparam BUS_WIDTH = DATA_WIDTH*WORDS_PER_LINE + STATUS_BITS + COHERENCE_BITS;

`include "./params.v"

reg  clock, reset;
reg  read, write, invalidate, flush;
reg  [ADDRESS_WIDTH-1 : 0] address;
reg  [DATA_WIDTH-1 : 0] data_in;
reg  report;
wire [DATA_WIDTH-1 : 0] data_out;
wire [ADDRESS_WIDTH-1 : 0] out_address;
wire ready;
wire valid;

reg  [MSG_BITS-1 : 0] mem2cache_msg;
reg  [BUS_WIDTH-1 : 0] mem2cache_data;
reg  [ADDRESS_WIDTH-1 : 0] mem2cache_address;
wire [MSG_BITS-1 : 0] cache2mem_msg;
wire [BUS_WIDTH-1 : 0] cache2mem_data;
wire [ADDRESS_WIDTH-1 : 0] cache2mem_address;

reg [MSG_BITS-1 : 0] coherence_msg_in;
reg [ADDRESS_WIDTH-1 : 0] coherence_address;
wire [MSG_BITS-1 : 0] coherence_msg_out;
wire [BUS_WIDTH-1 : 0] coherence_data;
wire replacement_mode = 1;

// generate clock
always #5 clock = ~clock;

// instantiate cache
L1cache #(STATUS_BITS, COHERENCE_BITS, OFFSET_BITS, DATA_WIDTH, NUMBER_OF_WAYS,
          REPLACEMENT_MODE_BITS, ADDRESS_WIDTH, INDEX_BITS, MSG_BITS, 0 ,0) 
	DUT (clock, reset, read, write, invalidate, flush, replacement_mode, address, 
        data_in, report, data_out, out_address, ready, valid, mem2cache_msg, 
        mem2cache_data, mem2cache_address, cache2mem_msg, cache2mem_data, 
        cache2mem_address, coherence_msg_in, coherence_address, coherence_msg_out,
        coherence_data);

initial begin
    clock = 1;
end

initial begin
	reset	   <= 1;
	read	   <= 0;
	write	   <= 0;
	invalidate <= 0;
	flush	   <= 0;
	address	   <= 0;
	data_in	   <= 0;
	report	   <= 1;
	mem2cache_msg	  <= 0;
	mem2cache_data	  <= 0;
	mem2cache_address <= 0;
    coherence_msg_in  <= C_NO_REQ;
    coherence_address <= 0;
	repeat(4) @(posedge clock);
	@(posedge clock) reset <= 0;
    repeat(4) @(posedge clock);
	@(posedge clock)begin
	write	<= 1;
	address <= 12'h41C;
	data_in <= 8'hff;
	end
	@(posedge clock)begin
	read  <= 0;
	write <= 0;
	end
	wait((cache2mem_msg == RFO_BCAST) & (cache2mem_address == 12'h41C));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
	mem2cache_msg 		<= MEM_SENT;
	mem2cache_address	<= 12'h41C;
	mem2cache_data		<= 32'hEE110203;
	end
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;

	wait(ready);
	@(posedge clock)begin
	read	<= 1;
	address <= 12'h41D;
	end
	@(posedge clock) address <= 12'h41E;
	@(posedge clock) address <= 12'h41F;
	@(posedge clock) read	 <= 0;

	repeat(1) @(posedge clock);
	@(posedge clock)begin
	read	<= 1;
	address	<= 12'h114;
	end
	@(posedge clock)begin
		if(ready)
			 address <= 12'h116;
	end
	wait(~ready);
	@(posedge clock) read <= 0;
	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'h114));
	@(posedge clock)begin
	mem2cache_data		<= 36'hD12345678; //exclusive line
	mem2cache_msg 		<= MEM_SENT;
	mem2cache_address	<= 12'h114;
	end
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	
	wait(ready);
	@(posedge clock)begin
	read	<= 1;
	address <= 12'h115;
	end
	@(posedge clock) read	<= 0;

	repeat(2) @(posedge clock);
	@(posedge clock)begin
	write	<= 1;
	address <= 12'h115;
	data_in <= 8'h99;
	end
	@(posedge clock)begin
		if(ready)begin
			write	<= 0;
			read	<= 1;
			address <= 12'h116;
		end
	end
	@(posedge clock)begin
		read <= 0;
	end
	
	repeat(1) @(posedge clock);
	@(posedge clock)begin
	read    <= 1;
	address <= 12'h115;
	end
	@(posedge clock)begin
		if(ready) address <= 12'h23C;
	end
	@(posedge clock) read <= 0;

	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'h23C));
	repeat(2) @(posedge clock);
	@(posedge clock)begin
	mem2cache_data		<= 36'h9AA00CD33;
	mem2cache_msg 		<= MEM_SENT;
	mem2cache_address	<= 12'h23C;
	end
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	
	wait(ready);
	@(posedge clock)begin
	read    <= 1;
	address <= 12'h5FD;
	end
	@(posedge clock)begin
	read	<= 0;
	write	<= 1;
	address <= 12'h99F;
	data_in <= 8'h70;
	end
	@(posedge clock) write <= 0;
	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'h5FC));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
	mem2cache_data		<= 36'h9543210ED;
	mem2cache_msg 		<= MEM_SENT;
	mem2cache_address	<= 12'h5FC;
	end
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	
	wait((cache2mem_msg == RFO_BCAST) & (cache2mem_address == 12'h99C));
	@(posedge clock)begin
	mem2cache_data		<= 32'h01556501;
	mem2cache_msg 		<= MEM_SENT;
	mem2cache_address	<= 12'h99C;
	end
	@(posedge clock) mem2cache_msg		<= MEM_NO_MSG;

	wait(ready);
	repeat(1) @(posedge clock);
	@(posedge clock)begin
	read	<= 1;
	address <= 12'h41E;
	end
	@(posedge clock) address <= 12'h5FF;
	@(posedge clock) address <= 12'h87D;
	@(posedge clock) address <= 12'h17C;
	@(posedge clock) read <= 0;

	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'h87C));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
	mem2cache_data		<= 36'h961626364;
	mem2cache_msg 		<= MEM_SENT;
	mem2cache_address	<= 12'h87C;
	end
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	wait((cache2mem_msg == WB_REQ) & (cache2mem_address == 12'h99C));
	repeat(1) @(posedge clock);
	@(posedge clock) mem2cache_msg <= MEM_READY;
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	
	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'h17C));
	@(posedge clock)begin
	mem2cache_data		<= 36'h989888786;
	mem2cache_msg 		<= MEM_SENT;
	mem2cache_address	<= 12'h17C;
	end
	@(posedge clock)begin
	mem2cache_msg <= MEM_NO_MSG;
	end
	wait(ready);
	repeat(4) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg     <= REQ_FLUSH;
		mem2cache_address <= 12'h41C;
	end
	wait((cache2mem_msg == FLUSH) & (cache2mem_address == 12'h41C));
	repeat(1) @(posedge clock);
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;

	wait(cache2mem_msg == NO_REQ);
	repeat(2) @(posedge clock);
	@(posedge clock)begin
		read    <= 1;
		address <= 12'h33C;
	end
	@(posedge clock)begin
		read     <= 0;
		write    <= 1;
		address  <= 12'h114;
		data_in  <= 8'h01;
	end
	@(posedge clock) write <= 0;

	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'h33C));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_address <= 12'h87C;
		mem2cache_msg     <= REQ_FLUSH;
	end
	wait((cache2mem_msg == NO_FLUSH) & (cache2mem_address == 12'h87C));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg <= MEM_NO_MSG;
	end

	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'h33C));
	repeat(1) @(posedge clock);
	@(posedge clock) begin
		mem2cache_msg     <= MEM_SENT;
		mem2cache_address <= 12'h33C;
		mem2cache_data    <= 36'h999991111;
	end
	wait(cache2mem_msg == NO_REQ);
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;

	wait(ready);
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		write   <= 1;
		address <= 12'hAAf;
		data_in <= 8'h99;
	end
	@(posedge clock)begin
		write   <= 0;
		read    <= 1;
		address <= 12'hAAE;
	end
	@(posedge clock) read <= 0;
	wait((cache2mem_msg == RFO_BCAST) & (cache2mem_address == 12'hAAC));
	repeat(2) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg     <= REQ_FLUSH;
		mem2cache_address <= 12'h114;
	end

	wait((cache2mem_msg == FLUSH) & (cache2mem_address == 12'h114));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg <= MEM_NO_MSG;
	end

	wait((cache2mem_msg == RFO_BCAST) & (cache2mem_address == 12'hAAC));
	repeat(2) @(posedge clock);
	@(posedge clock)begin
		mem2cache_address <= 12'hAAC;
		mem2cache_msg     <= MEM_SENT;
		mem2cache_data    <= 32'h32132132;
	end

	wait(cache2mem_msg == NO_REQ);
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	
	wait(valid & (out_address == 12'hAAE));
	read <= 0;

	repeat(2) @(posedge clock);
	@(posedge clock)begin              
          	read <= 1;
          	address <= 12'h5FD;
          end
	@(posedge clock) address <= 12'h17C;
	@(posedge clock) address <= 12'h33C;
	@(posedge clock) address <= 12'h20C;
	@(posedge clock) read <= 0;
	
	wait((cache2mem_msg == WB_REQ) & (cache2mem_address == 12'hAAC));
	@(posedge clock)begin
		mem2cache_msg     <= REQ_FLUSH;
		mem2cache_address <= 12'h17C;
	end

	wait((cache2mem_msg == NO_FLUSH) & (cache2mem_address == 12'h17C));
	repeat(2) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg <= MEM_NO_MSG;
	end

	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'h20C));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg <= MEM_SENT;
		mem2cache_address <= 12'h20C;
		mem2cache_data <= 36'h988668866;
	end
	wait(cache2mem_msg == NO_REQ);
	@(posedge clock)begin
	    mem2cache_msg <= MEM_NO_MSG;
		read <= 0;
	end
	
	wait(ready);
	@(posedge clock)begin
		flush <= 1;
		address <= 12'h5FF;
	end
	@(posedge clock) flush <= 0;
	wait((cache2mem_msg == FLUSH) & (cache2mem_address == 12'h5FC));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg <= M_RECV;
		mem2cache_address <= 12'h5FC;
	end
	wait(cache2mem_msg == NO_REQ);
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;

	wait(ready);
	@(posedge clock)begin
		flush   <= 1;
		address <= 12'hAAD;
	end
	@(posedge clock) flush <= 0;
	wait((cache2mem_msg == FLUSH) & (cache2mem_address == 12'hAAC));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg <= M_RECV;
		mem2cache_address <= 12'hAAC;
	end
	wait(cache2mem_msg == NO_REQ);
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;

	wait(ready);
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		invalidate <= 1;
		address    <= 12'h20D;
	end
	@(posedge clock) invalidate <= 0;
	wait((cache2mem_msg == INVLD) & (cache2mem_address == 12'h20C));
	repeat(1) @(posedge clock);
	@(posedge clock) mem2cache_msg <= M_RECV;
	wait(cache2mem_msg == NO_REQ);
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;

	repeat(2) @(posedge clock);
	@(posedge clock)begin
		write <= 1;
		address <= 12'h35C;
		data_in <= 8'h65;
	end
	@(posedge clock)begin
		address <= 12'h36D;
		data_in <= 8'h21;
	end
	wait(ready == 0);
	@(posedge clock) write <= 0;

	wait((cache2mem_msg == RFO_BCAST) & (cache2mem_address == 12'h35C));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg     <= MEM_SENT;
		mem2cache_address <= 12'h35C;
		mem2cache_data    <= 32'h11992288;
	end
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;

	wait((cache2mem_msg == RFO_BCAST) & (cache2mem_address == 12'h36C));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg     <= MEM_SENT;
		mem2cache_address <= 12'h36C;
		mem2cache_data    <= 32'hDDDDDDDD;
	end
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	
	wait(ready);
	repeat(2) @(posedge clock);
	@(posedge clock)begin
		read    <= 1;
		address <= 12'h77E;
	end
	@(posedge clock)begin
		read    <= 0;
		flush   <= 1;
		address <= 12'h35F;
	end
	@(posedge clock) flush <= 0;
	
	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'h77C));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg     <= MEM_SENT;
		mem2cache_address <= 12'h77C;
		mem2cache_data    <= 36'h9FEDCBA98;
	end
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	
	wait((cache2mem_msg == FLUSH) & (cache2mem_address == 12'h35C));
	repeat(1) @(posedge clock);
	@(posedge clock) mem2cache_msg <= M_RECV;
	repeat(2) @(posedge clock);
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	
	wait(ready);
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		write   <= 1;
		address <= 12'h36C;
		data_in <= 8'h09;
	end
	@(posedge clock)begin
		write      <= 0;
		invalidate <= 1;
		address    <= 12'h36F;
	end
	@(posedge clock) invalidate <= 0;
	
	wait((cache2mem_msg == INVLD) & (cache2mem_address == 12'h36C));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg     <= REQ_FLUSH;
		mem2cache_address <= 12'h08C;
	end
	wait((cache2mem_msg == NO_FLUSH) & (cache2mem_address == 12'h08C));
	repeat(1) @(posedge clock);
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	wait((cache2mem_msg == INVLD) & (cache2mem_address == 12'h36C));
	repeat(1) @(posedge clock);
	@(posedge clock) mem2cache_msg <= M_RECV;
	repeat(2) @(posedge clock);
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;

	wait(ready);
	@(posedge clock)begin
		read <= 1;
		address <= 12'h33E;
	end
	@(posedge clock)begin
		read <= 0;
		flush <= 1;
		address <= 12'hBDF;
	end
	@(posedge clock) flush <= 0;

	wait((cache2mem_msg == FLUSH) & (cache2mem_address == 12'hBDC));
	@(posedge clock) mem2cache_msg <= M_RECV;
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	
	wait(ready);
	@(posedge clock)begin
		write <= 1;
		address <= 12'h398;
		data_in <= 8'h77;
	end
	@(posedge clock)begin
		address <= 12'hABC;
		data_in <= 8'h10;
	end
	@(posedge clock) write <= 0;
	wait((cache2mem_msg == RFO_BCAST) & (cache2mem_address == 12'h398));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_data <= 32'h36362525;
		mem2cache_address <= 12'h398;
		mem2cache_msg <= MEM_SENT;
	end
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;

	@(posedge clock)begin
		mem2cache_address <= 12'h005;
		mem2cache_msg <= REQ_FLUSH;
	end
	wait((cache2mem_msg == NO_FLUSH) & (cache2mem_address == 12'h005));
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	wait((cache2mem_msg == RFO_BCAST) & (cache2mem_address == 12'hABC));
	@(posedge clock)begin
		mem2cache_data <= 32'h01020304;
		mem2cache_address <= 12'hABC;
		mem2cache_msg <= MEM_SENT;
	end
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	
	wait(ready);
	@(posedge clock)begin
		read <= 1;
		address <= 12'h06E;
	end
	@(posedge clock) address <= 12'h77D;
	@(posedge clock) read <= 0;
	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'h06C));
	@(posedge clock)begin
		mem2cache_msg <= MEM_SENT;
		mem2cache_address <= 12'h06C;
		mem2cache_data    <= 36'h912555555;
	end
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;

	wait(ready);
	@(posedge clock)begin
		read <= 1;
		address <= 12'h33F;
	end
	@(posedge clock) address <= 12'hCCF;
	@(posedge clock) read <= 0;
	wait((cache2mem_msg == WB_REQ) & (cache2mem_address == 12'hABC));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg <= REQ_FLUSH;
		mem2cache_address <= 12'h39C;
	end
	wait((cache2mem_msg == NO_FLUSH) & (cache2mem_address == 12'h39C));
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	wait((cache2mem_msg == WB_REQ) & (cache2mem_address == 12'hABC));
	@(posedge clock) mem2cache_msg <= MEM_READY;
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'hCCC));
	@(posedge clock)begin
		mem2cache_msg <= MEM_SENT;
		mem2cache_address <= 12'hCCC;
		mem2cache_data <= 36'hBEEEEEEEE;
	end
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;

	wait(ready);
	@(posedge clock)begin
		write <= 1;
		address <= 12'h06C;
		data_in <= 8'h22;
	end
	@(posedge clock) address <= 12'h77C;
	@(posedge clock) write <= 0;
	wait(ready);
	@(posedge clock)begin
	       	address <= 12'h33C;
		read <= 1;
	end
	@(posedge clock) address <= 12'hCCC;
	@(posedge clock)begin
	    address <= 12'h88C;
		write <= 1;
		read  <= 0;
	end
	@(posedge clock) write <= 0;
	wait((cache2mem_msg == WB_REQ) & (cache2mem_address == 12'h06C));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg <= REQ_FLUSH;
		mem2cache_address <= 12'h398;
	end
	wait((cache2mem_msg == FLUSH) & (cache2mem_address == 12'h398));
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	wait((cache2mem_msg == WB_REQ) & (cache2mem_address == 12'h06C));
	@(posedge clock) mem2cache_msg <= MEM_READY;
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	wait((cache2mem_msg == RFO_BCAST) & (cache2mem_address == 12'h88C));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg <= MEM_SENT;
		mem2cache_address <= 12'h88C;
		mem2cache_data <= 32'h02040816;
	end
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;

	wait(ready);
	@(posedge clock)begin
		read <= 1;
		address <= 12'h77E;
	end
	@(posedge clock)begin
		read <= 0;
		write <= 1;
	       	address <= 12'h55D;
	end
	@(posedge clock)begin
		write <= 0;
		flush <= 1;
	end
	@(posedge clock) flush <= 0;
	wait((cache2mem_msg == RFO_BCAST) & (cache2mem_address == 12'h55C));
	repeat(1) @(posedge clock);
	@(posedge clock)begin
		mem2cache_msg <= REQ_FLUSH;
		mem2cache_address <= 12'h88C;
	end
	wait((cache2mem_msg == FLUSH) & (cache2mem_address == 12'h88C));
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	wait((cache2mem_msg == RFO_BCAST) & (cache2mem_address == 12'h55C));
	@(posedge clock)begin
		mem2cache_msg <= MEM_SENT;
		mem2cache_address <= 12'h55C;
		mem2cache_data <= 32'h85857575;
	end
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;
	wait((cache2mem_msg == FLUSH) & (cache2mem_address == 12'h55C));
	@(posedge clock) mem2cache_msg <= M_RECV;
	wait(cache2mem_msg == NO_REQ);
	@(posedge clock) mem2cache_msg <= MEM_NO_MSG;

    wait(ready);
    repeat(2) @(posedge clock);
    @(posedge clock)begin
        write   <= 1;
        address <= 12'hCCE;
        data_in <= 8'h61;
    end
    @(posedge clock)begin
        address <= 12'h338;
        write   <= 0;
        read    <= 1;
    end
    @(posedge clock) read <= 0;
    wait((cache2mem_msg == WS_BCAST) & (cache2mem_address == 12'hCCC));
    repeat(1) @(posedge clock);
    @(posedge clock) coherence_msg_in <= ENABLE_WS;
    wait(cache2mem_msg == NO_REQ);
    @(posedge clock) coherence_msg_in <= C_NO_REQ;
    wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'h338));
    @(posedge clock)begin
        mem2cache_msg     <= MEM_SENT;
        mem2cache_address <= 12'h338;
        mem2cache_data    <= 36'hB44433377;
    end
    @(posedge clock) mem2cache_msg <= MEM_NO_MSG;
    
    wait(ready);
    repeat(1) @(posedge clock);
    @(posedge clock)begin
        write   <= 1;
        address <= 12'h339;
        data_in <= 8'h00;
    end
    @(posedge clock)begin
        address <= 12'h458;
        read    <= 1;
        write   <= 0;
    end
    @(posedge clock) read <= 0;
    wait((cache2mem_msg == WS_BCAST) & (cache2mem_address == 12'h338));
    @(posedge clock) coherence_msg_in <= ENABLE_WS;
    wait(cache2mem_msg == NO_REQ);
    @(posedge clock) coherence_msg_in <= C_NO_REQ;
    wait((cache2mem_msg == R_REQ) & (cache2mem_address == 12'h458));
    @(posedge clock)begin
        mem2cache_msg     <= MEM_SENT;
        mem2cache_address <= 12'h458;
        mem2cache_data    <= 36'hB84445555;
    end
    @(posedge clock) mem2cache_msg <= MEM_NO_MSG;

    wait(ready);
    repeat(4) @(posedge clock);
    @(posedge clock)begin
        coherence_msg_in  <= C_RD_BCAST;
        coherence_address <= 12'hCCC;
    end
    wait((coherence_msg_out == C_WB) & (coherence_data == 36'hEEE61EEEE));
    @(posedge clock) coherence_msg_in <= C_NO_REQ;

    wait(coherence_msg_out == C_NO_RESP);
    repeat(1) @(posedge clock);
    @(posedge clock)begin
        read <= 1;
        address <= 12'h459;
    end
    @(posedge clock)begin
        read <= 0;
        coherence_msg_in  <= C_WS_BCAST;
        coherence_address <= 12'h458;
    end
    wait(coherence_msg_out == C_EN_ACCESS);
    @(posedge clock) coherence_msg_in <= C_NO_REQ;
    
    wait(coherence_msg_out == C_NO_RESP);
    repeat(1) @(posedge clock);
    @(posedge clock)begin
        coherence_msg_in  <= C_FLUSH_BCAST;
        coherence_address <= 12'h77C;
    end
    wait((coherence_msg_out == C_FLUSH) & (coherence_data == 36'hEFEDCBA22));
    @(posedge clock) coherence_msg_in <= C_NO_REQ;

    wait(coherence_msg_out == C_NO_RESP);
    repeat(1) @(posedge clock);
    @(posedge clock)begin
        coherence_address <= 12'h33C;
        coherence_msg_in  <= C_RD_BCAST;
    end
    @(posedge clock)begin
        write <= 1;
        address <= 12'h33F;
        data_in <= 8'h00;
    end
    @(posedge clock) write <= 0;
    wait(coherence_msg_out == C_EN_ACCESS);
    @(posedge clock) coherence_msg_in <= C_NO_REQ;
    wait((cache2mem_msg == WS_BCAST) & (cache2mem_address == 12'h33C));
    repeat(1) @(posedge clock);
    @(posedge clock) coherence_msg_in <= ENABLE_WS;
    wait(cache2mem_msg == NO_REQ);
    @(posedge clock)begin
        coherence_msg_in  <= C_RFO_BCAST;
        coherence_address <= 12'h338;
        read <= 1;
        address <= 12'h33D;
    end
    @(posedge clock) address <= 12'h339;
    @(posedge clock) read <= 0;
    wait((coherence_msg_out == C_WB) & (coherence_data == 36'hE44430077));
    repeat(1) @(posedge clock);
    @(posedge clock) coherence_msg_in <= C_NO_REQ;
    wait((cache2mem_address == 12'h338) & (cache2mem_msg == R_REQ));
    repeat(1) @(posedge clock);
    @(posedge clock)begin
        coherence_address <= 12'h943;
        coherence_msg_in  <= C_INVLD_BCAST;
    end
    wait(coherence_msg_out == C_EN_ACCESS);
    @(posedge clock) coherence_msg_in <= C_NO_REQ;
    @(posedge clock)begin
        mem2cache_msg <= MEM_SENT;
        mem2cache_address <= 12'h338;
        mem2cache_data <= 36'hB77774433;
    end
    wait(cache2mem_msg == NO_REQ);
    @(posedge clock) mem2cache_msg <= MEM_NO_MSG;
end


// self checking code
reg [DATA_WIDTH-1 : 0] data_out_c;
reg [ADDRESS_WIDTH-1 : 0] out_address_c;
reg ready_c;
reg valid_c;

reg [MSG_BITS-1 : 0] cache2mem_msg_c;
reg [BUS_WIDTH-1 : 0] cache2mem_data_c;
reg [ADDRESS_WIDTH-1 : 0] cache2mem_address_c;

reg [MSG_BITS-1 : 0] coherence_msg_out_c;
reg [BUS_WIDTH-1 : 0] coherence_data_c;
reg [3:0] state_c;

wire c_data_out			 = |(data_out ^ data_out_c);
wire c_out_address		 = |(out_address ^ out_address_c);
wire c_ready			 = ready ^ ready_c;
wire c_valid			 = valid ^ valid_c;
wire c_cache2mem_msg	 = |(cache2mem_msg ^ cache2mem_msg_c);
wire c_cache2mem_data	 = |(cache2mem_data ^ cache2mem_data_c);
wire c_coherence_msg_out = |(coherence_msg_out ^ coherence_msg_out_c);
wire c_coherence_data    = |(coherence_data ^ coherence_data_c);
wire c_cache2mem_address = |(cache2mem_address ^ cache2mem_address_c);
wire c_state             = |(DUT.state ^ state_c);

wire mismatch = c_data_out | c_out_address | c_ready | c_valid | c_cache2mem_msg |
                c_cache2mem_data | c_cache2mem_address | c_coherence_data | 
                c_coherence_msg_out | c_state;


initial begin
	data_out_c <= 0;
	out_address_c <= 0;
	ready_c <= 0;
	valid_c <= 0;
	cache2mem_msg_c <= 0;
	cache2mem_data_c <= 0;
	cache2mem_address_c <= 0;
    coherence_data_c    <= 0;
    coherence_msg_out_c <= C_NO_RESP;
    state_c <= IDLE;
    #10; //10
    state_c <= RESET;
	#50; //60
    ready_c <= 1;
    state_c <= IDLE;
    #50; //110
    state_c <= CACHE_ACCESS;
	out_address_c <= 12'h41C;
	ready_c <= 0;
    #10; //120
    state_c <= READ_STATE;
	#10; //130
    state_c <= WAIT; 
	cache2mem_msg_c <= RFO_BCAST;
	cache2mem_address_c <= 12'h41C;
	#30; //160	
    state_c <= UPDATE;
	valid_c <= 0;
	cache2mem_msg_c <= 0;
    cache2mem_address_c <= 0;
	#10; //170
	valid_c <= 0;
    state_c <= WAIT_FOR_ACCESS;
	#10; //180
	ready_c <= 1;
    state_c <= IDLE;
	#20; //200
    state_c <= CACHE_ACCESS;
	valid_c <= 1;
	data_out_c <= 8'h02;
	out_address_c <= 12'h41D;
	#10;
	data_out_c <= 8'h11;
	out_address_c <= 12'h41E;
	#10;
	data_out_c <= 8'hEE;
	out_address_c <= 12'h41F;
	#10; //230
    state_c <= IDLE;
	data_out_c <= 8'h00;
	valid_c <= 0;
	#20; //250
    state_c <= CACHE_ACCESS;
	ready_c <= 0;
	out_address_c <= 12'h114;
    #10; //260
    state_c <= READ_STATE;
	#10; //270
    state_c <= WAIT;
	cache2mem_msg_c <= R_REQ;
	cache2mem_address_c <= 12'h114;
	#20; //290
    state_c <= UPDATE;
	cache2mem_msg_c <= 0;
    cache2mem_address_c <= 0;
	data_out_c <= 8'h78;
	valid_c <= 1;
	#10; //300
    state_c <= WAIT_FOR_ACCESS;
    data_out_c <= 0;
	valid_c <= 0;
	#10; //310
	state_c <= CACHE_ACCESS;
	valid_c <= 1;
	ready_c <= 1;
	data_out_c <= 8'h34;
	out_address_c <= 12'h116;
	#10; //320
	state_c <= IDLE;
	valid_c <= 0;
	data_out_c <= 8'h00;
	#10; //330
	state_c <= CACHE_ACCESS;
	valid_c <= 1;
	data_out_c <= 8'h56;
	out_address_c <= 12'h115;
	#10; //340
	state_c <= IDLE;
	data_out_c <= 8'h00;
	valid_c <= 0;
	#30; //370
	state_c <= CACHE_ACCESS;
	valid_c <= 0;
	ready_c <= 0;
	#10; //380
	state_c <= WAIT_FOR_ACCESS;
	valid_c <= 0;
	#10; //390
	state_c <= CACHE_ACCESS;
	valid_c <= 1;
	ready_c <= 1;
	data_out_c <= 8'h34;
	out_address_c <= 12'h116;
	#10; //400
	state_c <= IDLE;
	data_out_c <= 0;
	valid_c <= 0;
	#10;//410
	state_c <= CACHE_ACCESS;
	data_out_c <= 8'h99;
	out_address_c <= 12'h115;
	valid_c <= 1;
	#10; //420
	data_out_c <= 8'h00;
	out_address_c <= 12'h23C;
	ready_c <= 0;
	valid_c <= 0;
	#10; //430
	state_c <= READ_STATE;
	#10; //440
	state_c <= WAIT;
	cache2mem_msg_c <= R_REQ;
	cache2mem_address_c <= 12'h23C;
	#40; //480
	state_c <= UPDATE;
	cache2mem_msg_c <= 0;
	cache2mem_address_c <= 0;
	valid_c <= 1;
	data_out_c <= 8'h33;
	#10; //490
    state_c <= WAIT_FOR_ACCESS;
    data_out_c <= 0;    
	valid_c <= 0;
	#10; //500
    state_c <= IDLE;
	data_out_c <= 0;
	ready_c <= 1;
	#20; //520
    state_c <= CACHE_ACCESS;
	data_out_c <= 8'h00;
	ready_c <= 0;
	valid_c <= 0;
	out_address_c <= 12'h5FD;
    #10; //530
    state_c <= READ_STATE;
	#10; //540
    state_c <= WAIT;
	cache2mem_msg_c <= R_REQ;
	cache2mem_address_c <= 12'h5FC;
	#30; //570
    state_c <= UPDATE;
    cache2mem_address_c <= 0;
	cache2mem_msg_c <= 0;
	data_out_c <= 8'h10;
	valid_c <= 1;
	#10; //580
    state_c <= WAIT_FOR_ACCESS;
	data_out_c <= 8'h00;
	valid_c <= 0;
	#10; //590
    state_c <= CACHE_ACCESS;
	out_address_c <= 12'h99F;
    #10; //600
    state_c <= READ_STATE;
	#10; //610
    state_c <= WAIT;
	cache2mem_msg_c <= RFO_BCAST;
	cache2mem_address_c <= 12'h99C;
	#20; //630
    state_c <= UPDATE;
    cache2mem_address_c <= 0;
	cache2mem_msg_c <= 0;
	valid_c <= 0;
	#10; //640
    state_c <= WAIT_FOR_ACCESS;    
	valid_c <= 0;
	#10; //650
    state_c <= IDLE;
	ready_c <= 1;
	#30; //680
    state_c <= CACHE_ACCESS;    
	data_out_c <= 8'h11;
	out_address_c <= 12'h41E;
	valid_c <= 1;
	#10; //690
	data_out_c <= 8'h54;
	out_address_c <= 12'h5FF;
	#10; //700
	data_out_c <= 8'h00;
	out_address_c <= 12'h487D;
	valid_c <= 0;
	ready_c <= 0;
    #10; //710
    state_c <= READ_STATE;
	#10; //720
    state_c <=WAIT;
	cache2mem_msg_c <= R_REQ;
	cache2mem_address_c <= 12'h87C;
	#30; //750
    state_c <= UPDATE;
    cache2mem_address_c <= 0;    
	cache2mem_msg_c <= 0;
	valid_c <= 1;
	data_out_c <= 8'h63;
	#10; //760
    state_c <= WAIT_FOR_ACCESS;    
	valid_c <= 0;
	data_out_c <= 8'h00;
	#10; //770
    state_c <= CACHE_ACCESS;
	out_address_c <= 12'h17C;
    #10; //780
    state_c <= WRITE_BACK;
	#10; //790
    state_c <= WB_WAIT;    
	cache2mem_msg_c <= 1;
	cache2mem_data_c <= 36'hE70556501;
	cache2mem_address_c <= 12'h99C;
	#30; //820
    state_c <= READ_STATE;
    cache2mem_address_c <= 0;
    cache2mem_data_c <= 0; 
	cache2mem_msg_c <= 0;
	#10; //830
    state_c <= WAIT;
	cache2mem_msg_c <= R_REQ;
	cache2mem_address_c <= 12'h17C;
	#20; //850
    state_c <= UPDATE;
    cache2mem_address_c <= 0;
	cache2mem_msg_c <= 0;
	valid_c <= 1;
	data_out_c <= 8'h86;
	#10; //860
    state_c <= WAIT_FOR_ACCESS;
    data_out_c <= 0;
	valid_c <= 0;
	#10; //870
    state_c <= IDLE;
	data_out_c <= 0;
	ready_c <= 1;
	#10; //880	
	valid_c <= 0;
	data_out_c <= 8'h00;
	#40; //920	
	ready_c <= 0;
    #10; //930
    state_c <= CACHE_ACCESS;
    #10; //940
    state_c <= SRV_FLUSH_REQ;
	#10; //950
    state_c <= WAIT_FLUSH_REQ;
	cache2mem_msg_c <= FLUSH;
	cache2mem_data_c <= 36'hEEE1102FF;
	cache2mem_address_c <= 12'h41C;
	#30; //980
    state_c <= IDLE;
    cache2mem_address_c <= 0;    
	cache2mem_msg_c <= NO_REQ;
	cache2mem_data_c <= 0;
	cache2mem_address_c <= 0;
	ready_c <= 1;
	#40; //1020
    state_c <= CACHE_ACCESS;    
	out_address_c <= 12'h33C;
	ready_c <= 0;
    #10; //1030
    state_c <= READ_STATE;
	#10; //1040
    state_c <= WAIT;
	cache2mem_msg_c <= R_REQ;
	cache2mem_address_c <= 12'h33C;
    #30; //1070
    state_c <= CACHE_ACCESS;
    #10; //1080
    state_c <= SRV_FLUSH_REQ;
	#10; //1090
    state_c <= WAIT_FLUSH_REQ;
	cache2mem_msg_c <= NO_FLUSH;
	cache2mem_data_c <= 0;
	cache2mem_address_c <= 12'h87C;
	#30; //1120
    state_c <= WAIT;
	cache2mem_msg_c <= R_REQ;
	cache2mem_address_c <= 12'h33C;
	#30; //1150
    state_c <= UPDATE;
    cache2mem_address_c <= 0;
	cache2mem_msg_c <= NO_REQ;
	data_out_c <= 8'h11;
	valid_c <= 1;
	#10; //1160
    state_c <= WAIT_FOR_ACCESS;    
	valid_c <= 0;
	data_out_c <= 8'h00;
	#10; //1170
    state_c <= CACHE_ACCESS;
	valid_c <= 0;
	out_address_c <= 12'h114;
	ready_c <= 1;
	#10; //1180
    state_c <= IDLE;    
	valid_c <= 0;
	#10; //1190	
	ready_c <= 1;
	#10; //1200
    state_c <= CACHE_ACCESS;    
	ready_c <= 0;
	out_address_c <= 12'hAAF;
    #10; //1210
    state_c <= READ_STATE;
	#10; //1220
    state_c <= WAIT;
	cache2mem_msg_c <= RFO_BCAST;
	cache2mem_address_c <= 12'hAAC;
    #40; //1260
    state_c <= CACHE_ACCESS;
    #10; //1270
    state_c <= SRV_FLUSH_REQ;
	#10; //1280
    state_c <= WAIT_FLUSH_REQ;
	cache2mem_msg_c <= FLUSH;
	cache2mem_address_c <= 12'h114;
	cache2mem_data_c <= 36'hE12349901;
	#30; //1310
    state_c <= WAIT;
	cache2mem_msg_c <= RFO_BCAST;
	cache2mem_address_c <= 12'hAAC;
	cache2mem_data_c <= 0;
	#40; //1350
    state_c <= UPDATE;
    cache2mem_address_c <= 0;
	cache2mem_msg_c <= NO_REQ;
	valid_c <= 0;
	#10; //1360
    state_c <= WAIT_FOR_ACCESS;
	valid_c <= 0;
	#20; //1380
    state_c <= CACHE_ACCESS;
	data_out_c <= 8'h13;
	out_address_c <= 12'hAAE;
	ready_c <= 1;
	valid_c <= 1;
	#10; //1390
    state_c <= IDLE;
	valid_c <= 0;
	data_out_c <= 0;
	#30; //1420
    state_c <= CACHE_ACCESS;    
	data_out_c <= 8'h10;
	out_address_c <= 12'h5FD;
	valid_c <= 1;
	#10; //1430	
	data_out_c <= 8'h86;
	out_address_c <= 12'h17C;
	#10; //1440
	data_out_c <= 8'h11;
	out_address_c <= 12'h33C;
	#10; //1450
	valid_c <= 0;
	ready_c <= 0;
	data_out_c <= 0;
	out_address_c <= 12'h20C;
    #10; //1460
    state_c <= WRITE_BACK;
	#10; //1470
    state_c <= WB_WAIT;
	cache2mem_msg_c <= WB_REQ;
	cache2mem_data_c <= 36'hE99132132;
    cache2mem_address_c <= 12'hAAC;
    #20; //1490
    state_c <= CACHE_ACCESS;
    #10; //1500
    state_c <= SRV_FLUSH_REQ;
	#10; //1510
    state_c <= WAIT_FLUSH_REQ;
	cache2mem_msg_c <= NO_FLUSH;
	cache2mem_data_c <= 0;
	cache2mem_address_c <= 12'h17C;
	#40; //1550
    state_c <= READ_STATE;
	cache2mem_msg_c <= NO_REQ;
	cache2mem_address_c <= 0;
	#10; //1560
    state_c <= WAIT;    
	cache2mem_msg_c <= R_REQ;
	cache2mem_address_c <= 12'h20C;
	#30; //1590
    state_c <= UPDATE;
    cache2mem_address_c <= 0;
	cache2mem_msg_c <= NO_REQ;
	data_out_c <= 8'h66;
	valid_c <= 1;
	#10; //1600
    state_c <= WAIT_FOR_ACCESS;
    data_out_c <= 0;
	valid_c <= 0;
	#10; //1610
    state_c <= IDLE;
	data_out_c <= 0;
	ready_c <= 1;
	#10; //1620
	valid_c <= 0;
	data_out_c <= 0;
	ready_c <= 0;
	#10; //1630
    state_c <= CACHE_ACCESS;
	valid_c <= 0;
	out_address_c <= 12'h5FF;
	#10; //1640
    state_c <= SRV_FLUSH_REQ;
    #10; //1650
    state_c <= WAIT_FLUSH_REQ;
	valid_c <= 0;
	cache2mem_msg_c <= FLUSH;
	cache2mem_data_c <= 0;
	cache2mem_address_c <= 12'h5FC;
	#30; //1680	
	cache2mem_msg_c <= NO_REQ;
    cache2mem_address_c <= 0;
	#20; //1700
	state_c <= IDLE;
	cache2mem_data_c <= 0;
	cache2mem_address_c <= 12'h000;
	ready_c <= 1;
	#10; //1710
	ready_c <= 0;
	#10; //1720
	state_c <= CACHE_ACCESS;
	valid_c <= 0;
	out_address_c <= 12'hAAD;
	#10; //1730
	state_c <= SRV_FLUSH_REQ;
	#10; //1740
	state_c <= WAIT_FLUSH_REQ;
	valid_c <= 0;
	cache2mem_msg_c <= FLUSH;
	cache2mem_data_c <= 36'hE99132132;
	cache2mem_address_c <= 12'hAAC;
	#30; //1770
	cache2mem_address_c <= 0;
	cache2mem_data_c <= 0;
	cache2mem_msg_c <= NO_REQ;
	#20; //1790
	state_c <= IDLE;
	cache2mem_address_c <= 0;
	ready_c <= 1;
	#20; //1810
	ready_c <= 0;
	#10; //1820
	state_c <= CACHE_ACCESS;
	valid_c <= 0;
	out_address_c <= 12'h20D;
	#10; //1830
	state_c <= SRV_INVLD_REQ;
	#10; //1840
	state_c <= WAIT_INVLD_REQ;
	valid_c <= 0;
	cache2mem_msg_c <= INVLD;
	cache2mem_data_c <= 0;
	cache2mem_address_c <= 12'h20C;
	#30; //1870
	cache2mem_address_c <= 0;
	cache2mem_msg_c <= NO_REQ;
	#20; //1890
	state_c <= IDLE;
	cache2mem_data_c <= 0;
	cache2mem_address_c <= 0;
	ready_c <= 1;
	#30; //1920
	state_c <= CACHE_ACCESS;
	out_address_c <= 12'h35C;
	ready_c <= 0;
	#10; //1930
	state_c <= READ_STATE;
	#10; //1940
	state_c <= WAIT;
	cache2mem_msg_c <= RFO_BCAST;
	cache2mem_address_c <= 12'h35C;
	#30; //1970
	state_c <= UPDATE;
	cache2mem_msg_c <= NO_REQ;
	cache2mem_address_c <= 0;
	valid_c <= 0;
	#10; //1980
	state_c <= WAIT_FOR_ACCESS;
	valid_c <= 0;
	#20; //2000
	state_c <= CACHE_ACCESS;
	out_address_c <= 12'h36D;
	#10; //2010
	state_c <= READ_STATE;
	#10; //2020
	state_c <= WAIT;
	cache2mem_msg_c <= RFO_BCAST;
	cache2mem_address_c <= 12'h36C;
	#30; //2050
	state_c <= UPDATE;
	cache2mem_address_c <= 0;
	cache2mem_msg_c <= NO_REQ;
	valid_c <= 0;
	#10; //2060
	state_c <= WAIT_FOR_ACCESS;
	valid_c <= 0;
	#10; //2070
	state_c <= IDLE;
	ready_c <= 1;
	#40; //2110
	state_c <= CACHE_ACCESS;
	ready_c <= 0;
	out_address_c <= 12'h77E;
	#10; //2120
	state_c <= READ_STATE;
	#10; //2130
	state_c <= WAIT;
	cache2mem_msg_c <= R_REQ;
	cache2mem_address_c <= 12'h77C;
	#30; //2160
	state_c <= UPDATE;
	cache2mem_address_c <= 0;
	cache2mem_msg_c <= NO_REQ;
	valid_c <= 1;
	data_out_c <= 8'hDC;
	#10; //2170
	state_c <= WAIT_FOR_ACCESS;
	valid_c <= 0;
	data_out_c <= 0;
	#10; //2180
	state_c <= CACHE_ACCESS;
	out_address_c <= 12'h35F;
	valid_c <= 0;
	#10; //2190
	state_c <= SRV_FLUSH_REQ;
	valid_c <= 0;
	#10; //2200
	state_c <= WAIT_FLUSH_REQ;
	cache2mem_msg_c <= FLUSH;
	cache2mem_address_c <= 12'h35C;
	cache2mem_data_c <= 36'hE11992265;
	#30; //2230
	cache2mem_address_c <= 0;
	cache2mem_data_c <= 0;
	cache2mem_msg_c <= NO_REQ;
	#30; //2260
	state_c <= IDLE;
	cache2mem_address_c <= 0;
	cache2mem_data_c <= 0;
	ready_c <= 1;
	#30; //2290
	state_c <= CACHE_ACCESS;
	ready_c <= 0;
	valid_c <= 0;
	out_address_c <= 12'h36C;
	#10; //2300
	state_c <= WAIT_FOR_ACCESS;
	valid_c <= 0;
	#10; //2310
	state_c <= CACHE_ACCESS;
	out_address_c <= 12'h36F;
	valid_c <= 0;
	#10; //2320
	state_c <= SRV_INVLD_REQ;
	valid_c <= 0;
	#10; //2330
	state_c <= WAIT_INVLD_REQ;
	cache2mem_msg_c <= INVLD;
	cache2mem_address_c <= 12'h36C;
	cache2mem_data_c <= 36'hEdddd2109;
	#30; //2360
	state_c <= CACHE_ACCESS;
	#10; //2370
	state_c <= SRV_FLUSH_REQ;
	#10; //2380
	state_c <= WAIT_FLUSH_REQ;
	cache2mem_msg_c <= NO_FLUSH;
	cache2mem_address_c <= 12'h08C;
	cache2mem_data_c <= 0;
	#30; //2410
	state_c <= WAIT_INVLD_REQ;
	cache2mem_msg_c <= INVLD;
	cache2mem_address_c <= 12'h36C;
	cache2mem_data_c <= 36'hEdddd2109;
	#30; //2440
	cache2mem_address_c <= 0;
	cache2mem_data_c <= 0;
	cache2mem_msg_c <= NO_REQ;
	#30; //2470
	state_c <= IDLE;
	ready_c <= 1;
	#20; //2490
	state_c <= CACHE_ACCESS;
	ready_c <= 0;
	valid_c <= 1;
	out_address_c <= 12'h33E;
	data_out_c <= 8'h99;
	#10; //2500
	valid_c <= 0;
	data_out_c <= 0;
	out_address_c <= 12'hBDF;
	#10; //2510
	state_c <= SRV_FLUSH_REQ;
	#10; //2520
	state_c <= WAIT_FLUSH_REQ;
	valid_c <= 0;
	cache2mem_msg_c <= FLUSH;
	cache2mem_data_c <= 0;
	cache2mem_address_c <= 12'hBDC;
	#20; //2540
	cache2mem_address_c <= 0;
	cache2mem_msg_c <= NO_REQ;
	#10; //2550
	state_c <= IDLE;
	cache2mem_data_c <= 0;
	cache2mem_address_c <= 0;
	#10; //2560
	ready_c <= 1;
	#20; //2580
	state_c <= CACHE_ACCESS;
	ready_c <= 0;
	out_address_c <= 12'h398;
	#10; //2590
	state_c <= READ_STATE;
	#10; //2600
    state_c <= WAIT;
	cache2mem_address_c <= 12'h398;
	cache2mem_msg_c <= RFO_BCAST;
	#30; //2630
    state_c <= UPDATE;
    cache2mem_address_c <= 0;
	cache2mem_msg_c <= NO_REQ;
	valid_c <= 0;
	#10; //2640
    state_c <= WAIT_FOR_ACCESS;
	valid_c <= 0;
	#10; // 2650
    state_c <= CACHE_ACCESS;
	out_address_c <= 12'hABC;
    #10; //2660
    state_c <= READ_STATE;
    #10; //2670
    state_c <= CACHE_ACCESS;
	#10; //2680
    state_c <= SRV_FLUSH_REQ;
    #10; //2690
    state_c <= WAIT_FLUSH_REQ;
	cache2mem_msg_c <= NO_FLUSH;
	cache2mem_data_c <= 0;
	cache2mem_address_c <= 12'h005;
	#20; //2710
    state_c <= READ_STATE;    
	cache2mem_msg_c <= NO_REQ;
	cache2mem_data_c <= 0;
	cache2mem_address_c <= 0;
	#10; //2720
    state_c <= WAIT;
	cache2mem_msg_c <= RFO_BCAST;
	cache2mem_address_c <= 12'hABC;
	#20; //2740
    state_c <= UPDATE;
    cache2mem_address_c <= 0;    
	cache2mem_msg_c <= NO_REQ;
	valid_c <= 0;
	#10; //2750
    state_c <= WAIT_FOR_ACCESS;
	valid_c <= 0;
	#10; //2760
    state_c <= IDLE;
	ready_c <= 1;
	#20; //2780
    state_c <= CACHE_ACCESS;    
	out_address_c <= 12'h06E;
	ready_c <= 0;
    #10;
    state_c <= READ_STATE;
	#10; //2800	
    state_c <= WAIT;
	cache2mem_msg_c <= R_REQ;
	cache2mem_address_c <= 12'h06C;
	#20; // 2820
    state_c <= UPDATE;
    cache2mem_address_c <= 0;
	cache2mem_msg_c <= NO_REQ;
	valid_c <= 1;
	data_out_c <= 8'h55;
	#10; //2830
    state_c <= WAIT_FOR_ACCESS;
	valid_c <= 0;
	data_out_c <= 0;
	#10; //2840
    state_c <= CACHE_ACCESS;
	valid_c <= 1;
	data_out_c <= 8'hBA;
	out_address_c <= 12'h77D;
	ready_c <= 1;
	#10; //2850
    state_c <= IDLE;
	valid_c <= 0;
	data_out_c <= 0;
	#10; //2860
    state_c <= CACHE_ACCESS;
	valid_c <= 1;
	out_address_c <= 12'h33F;
	data_out_c <= 8'h99;
	#10; //2870	
	valid_c <= 0;
	ready_c <= 0;
	data_out_c <= 0;
	out_address_c <= 12'hCCF;
    #10; //2880
    state_c <= WRITE_BACK;
	#10; //2890
    state_c <=WB_WAIT;
	cache2mem_msg_c <= WB_REQ;
	cache2mem_address_c <= 12'hABC;
	cache2mem_data_c <= 36'hE01020310;
    #30; //2920
    state_c <= CACHE_ACCESS;
    #10; //2930
    state_c <= SRV_FLUSH_REQ;
	#10; //2940
    state_c <= WAIT_FLUSH_REQ;
	cache2mem_msg_c <= NO_FLUSH;
	cache2mem_address_c <= 12'h39C;
	cache2mem_data_c <= 0;
	#20; //2960
    state_c <= WB_WAIT;    
	cache2mem_msg_c <= WB_REQ;
	cache2mem_address_c <= 12'hABC;
	cache2mem_data_c <= 36'hE01020310;
	#20; //2980
    state_c <= READ_STATE;
    cache2mem_address_c <= 0;
    cache2mem_data_c <= 0;
	cache2mem_msg_c <= NO_REQ;
	#10; //2990
    state_c <= WAIT;
	cache2mem_msg_c <= R_REQ;
	cache2mem_address_c <= 12'hCCC;
	#20; //3010
    state_c <= UPDATE;
    cache2mem_address_c <= 0;
	cache2mem_msg_c <= NO_REQ;
	valid_c <= 1;
	data_out_c <= 8'hEE;
	#10; //3020
    state_c <= WAIT_FOR_ACCESS;
    data_out_c <= 0;
	valid_c <= 0;
	#10; //3030
    state_c <= IDLE;
	data_out_c <= 0;
	ready_c <= 1;
	#20; //3050
    state_c <= CACHE_ACCESS;
	valid_c <= 0;
	out_address_c <= 12'h06C;
	ready_c <= 0;
	#10; //3060
    state_c <= WAIT_FOR_ACCESS;
	valid_c <= 0;
	#10; //3070
    state_c <= CACHE_ACCESS;
	valid_c <= 0;
	ready_c <= 1;
	out_address_c <= 12'h77C;
	#10; //3080
    state_c <= IDLE;
	valid_c <= 0;
	#10; //3090
    state_c <= CACHE_ACCESS;
	valid_c <= 1;
	out_address_c <= 12'h33C;
	data_out_c <= 8'h11;
	#10; //3100
	out_address_c <= 12'hCCC;
	data_out_c <= 8'hEE;
	#10; //3110
	valid_c <= 0;
	ready_c <= 0;
	out_address_c <= 12'h88C;
	data_out_c <= 0;
    #10; //3120
    state_c <= WRITE_BACK;
	#10; //3130
    state_c <= WB_WAIT;
	cache2mem_msg_c <= WB_REQ;
	cache2mem_address_c <= 12'h06C;
	cache2mem_data_c <= 36'hE12555522;
    #30; //3160
    state_c <= CACHE_ACCESS;
    #10; //3170
    state_c <= SRV_FLUSH_REQ;
	#10; //3180
    state_c <= WAIT_FLUSH_REQ;    
	cache2mem_msg_c <= FLUSH;
	cache2mem_address_c <= 12'h398;
	cache2mem_data_c <= 36'hE36362577;
	#20; //3200
    state_c <= WB_WAIT;
	cache2mem_msg_c <= WB_REQ;
	cache2mem_address_c <= 12'h06C;
	cache2mem_data_c <= 36'hE12555522;
	#20; //3220
    state_c <= READ_STATE;
    cache2mem_address_c <= 0;
    cache2mem_data_c <= 0;
	cache2mem_msg_c <= NO_REQ;
	#10; //3230
    state_c <= WAIT;    
	cache2mem_msg_c <= RFO_BCAST;
	cache2mem_address_c <= 12'h88C;
	#30; //3260
    state_c <= UPDATE;    
	cache2mem_address_c <= 0;
	cache2mem_msg_c <= NO_REQ;
	valid_c <= 0;
	#10; //3270
    state_c <= WAIT_FOR_ACCESS;
	valid_c <= 0;
	#10; //3280
    state_c <= IDLE;
	ready_c <= 1;
	#20; //3300
    state_c <= CACHE_ACCESS;
	valid_c <= 1;
	out_address_c <= 12'h77E;
	data_out_c <= 8'hDC;
	#10; //3310
	valid_c <= 0;
	ready_c <= 0;
	out_address_c <= 12'h55D;
	data_out_c <= 0;
    #10; //3320
    state_c <= READ_STATE;
	#10; //3330
    state_c <= WAIT;
	cache2mem_msg_c <= RFO_BCAST;
	cache2mem_address_c <= 12'h55C;
    #30; //3360
    state_c <= CACHE_ACCESS;
    #10; //3370
    state_c <= SRV_FLUSH_REQ;
	#10; //3380
    state_c <= WAIT_FLUSH_REQ;
	cache2mem_msg_c <= FLUSH;
	cache2mem_address_c <= 12'h88C;
	cache2mem_data_c <= 36'hE02040822;
	#20; //3400
    state_c <= WAIT;
	cache2mem_msg_c <= RFO_BCAST;
	cache2mem_address_c <= 12'h55C;
	cache2mem_data_c <= 0;
	#20; //3420
    state_c <= UPDATE;
    cache2mem_address_c <= 0;
	cache2mem_msg_c <= NO_REQ;
	valid_c <= 0;
	#10; // 3430
    state_c <= WAIT_FOR_ACCESS;
	valid_c <= 0;
	#20; //3450
    state_c <= CACHE_ACCESS;
	valid_c <= 0;
	#10; //3460
    state_c <= SRV_FLUSH_REQ;
	valid_c <= 0;
	#10; //3470
    state_c <= WAIT_FLUSH_REQ;
	cache2mem_msg_c <= FLUSH;
	cache2mem_data_c <= 36'hE85852275;
    cache2mem_address_c <= 12'h55C;
	#20; //3490
    cache2mem_address_c <= 0;
    cache2mem_data_c <= 0;    
	cache2mem_msg_c <= NO_REQ;
	#20; //3510
    state_c <= IDLE;
	cache2mem_address_c <= 0;
	cache2mem_data_c <= 0;
	ready_c <= 1;
    #40; //3550
    state_c <= CACHE_ACCESS;
    out_address_c <= 12'hCCE;
    ready_c <= 0;
    #10; // 3560
    state_c <= WAIT_WS_ENABLE;
    cache2mem_msg_c <= WS_BCAST;
    cache2mem_address_c <= 12'hCCC;
    #30; //3590
    state_c <= WAIT_FOR_ACCESS;
    cache2mem_msg_c <= NO_REQ;
    cache2mem_address_c <= 0;
    #10; //3600
    state_c <= CACHE_ACCESS;
    out_address_c <= 12'h338;
    #10; //3610
    state_c <= READ_STATE;
    #10; //3620
    state_c <= WAIT;
    cache2mem_msg_c <= R_REQ;
    cache2mem_address_c <= 12'h338;
    #20; //3640
    state_c <= UPDATE;
    valid_c <= 1;
    data_out_c <= 8'h77;
    cache2mem_msg_c <= NO_REQ;
    cache2mem_address_c <= 0;
    #10; //3650
    state_c <= WAIT_FOR_ACCESS;
    data_out_c <= 0;
    valid_c <= 0;
    #10; //3660
    state_c <= IDLE;   
    data_out_c <= 0;
    data_out_c <= 0;
    ready_c <= 1;
    #30; //3690
    state_c <= CACHE_ACCESS;
    ready_c <= 0;
    out_address_c <= 12'h339;
    #10; //3700
    state_c <= WAIT_WS_ENABLE;
    cache2mem_address_c <= 12'h338;
    cache2mem_msg_c <= WS_BCAST;
    #20; //3720
    state_c <= WAIT_FOR_ACCESS;
    cache2mem_msg_c <= NO_REQ;
    cache2mem_address_c <= 0;
    #20; //3740
    state_c <= CACHE_ACCESS;
    out_address_c <= 12'h458;
    #10; //3750
    state_c <= READ_STATE;
    #10; //3760
    state_c <= WAIT;
    cache2mem_msg_c <= R_REQ;
    cache2mem_address_c <= 12'h458;
    #20; //3780
    state_c <= UPDATE;
    cache2mem_address_c <= 0;
    cache2mem_msg_c <= NO_REQ;
    valid_c <= 1;
    data_out_c <= 8'h55;
    #10; //3790
    state_c <= WAIT_FOR_ACCESS;
    data_out_c <= 0;
    valid_c <= 0;
    #10; //3800
    state_c <= IDLE;
    data_out_c <= 0;
    ready_c <= 1;
    #80; //3880
    coherence_msg_out_c <= C_WB;
    coherence_data_c <= 36'hEEE61EEEE;
    #20; //3900  
    coherence_msg_out_c <= C_NO_RESP;
    coherence_data_c <= 0;
    #30; //3930
    state_c <= CACHE_ACCESS; 
    valid_c <= 1;
    data_out_c <= 8'h55;
    out_address_c <= 12'h459;
    ready_c <= 0;
    #10; //3940
    state_c <= WAIT_FOR_ACCESS; 
    valid_c <= 0;
    data_out_c <= 0;
    #10; //3950
    state_c <= IDLE;
    ready_c <= 1;
    #10; //3960 
    coherence_msg_out_c <= C_EN_ACCESS;
    #20; //3980
    coherence_msg_out_c <= C_NO_RESP;
    #50; //4030    
    coherence_msg_out_c <= C_FLUSH;
    coherence_data_c <= 36'hEFEDCBA22;
    #20; //4050
    coherence_msg_out_c <= C_NO_RESP;
    coherence_data_c <= 0;
    #30; //4080   
    ready_c <= 0;
    #10; //4090
    state_c <= WAIT_FOR_ACCESS;
    #10; //4100
    coherence_msg_out_c <= C_EN_ACCESS;
    #20; //4120
    state_c <= CACHE_ACCESS;
    coherence_msg_out_c <= C_NO_RESP;
    out_address_c <= 12'h33F;
    #10;  //4130
    state_c <= WAIT_WS_ENABLE;
    cache2mem_msg_c <= WS_BCAST;
    cache2mem_address_c <= 12'h33C;
    #30; //4160
    state_c <= WAIT_FOR_ACCESS;
    cache2mem_address_c <= 0;
    cache2mem_msg_c <= NO_REQ;
    #10; //4170
    state_c <= IDLE;
    ready_c <= 1;
    #10; //4180
    state_c <= CACHE_ACCESS;
    out_address_c <= 12'h33D;
    ready_c <= 0;
    valid_c <= 1;
    data_out_c <= 8'h11;
    #10; //4190
    state_c <= WAIT_FOR_ACCESS;
    data_out_c <= 0;
    valid_c <= 0;
    data_out_c <= 0;
    #10; //4200
    coherence_msg_out_c <= C_WB;
    coherence_data_c <= 36'hE44430077;
    #30; //4230
    state_c <= CACHE_ACCESS;
    coherence_msg_out_c <= C_NO_RESP;
    coherence_data_c <= 0;
    out_address_c <= 12'h339;
    #10; //4240
    state_c <= READ_STATE;
    #10; //4250
    state_c <= WAIT;
    cache2mem_msg_c <= R_REQ;
    cache2mem_address_c <= 12'h338;
    #50; //4300
    coherence_msg_out_c <= C_EN_ACCESS;
    #20; //4320
    coherence_msg_out_c <= C_NO_RESP;
    #10; //4330
    state_c <= UPDATE;
    cache2mem_address_c <= 0;
    cache2mem_msg_c <= NO_REQ;
    valid_c <= 1;
    data_out_c <= 8'h44;
    #10; //4340
    state_c <= WAIT_FOR_ACCESS; 
    valid_c <= 0;
    data_out_c <= 0;
    #10; //4350
    state_c <= IDLE;
    ready_c <= 1;
end

endmodule
