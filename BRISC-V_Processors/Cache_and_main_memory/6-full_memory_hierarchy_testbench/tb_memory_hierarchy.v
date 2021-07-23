/******************************************************************************
* Module: tb_hierarchy.v
* Integrates a cache hierarchy consisting of two L1 caches, shared L2 cache
* and a coherence controller.
******************************************************************************/

module tb_hierarchy();

parameter STATUS_BITS_L1        = 2,
          STATUS_BITS_L2        = 3,
          COHERENCE_BITS        = 2,
          OFFSET_BITS           = 2,
          DATA_WIDTH            = 32,
          NUMBER_OF_WAYS_L1     = 2,
          NUMBER_OF_WAYS_L2     = 4,
          REPLACEMENT_MODE_BITS = 1,
	      ADDRESS_WIDTH         = 32,
	      INDEX_BITS_L1         = 5,
	      INDEX_BITS_L2         = 6,
		  INDEX_BITS_MEMORY     = 10,
	      MSG_BITS              = 3,
          NUM_L1_CACHES         = 2,
		  NUM_MEMORY_PORTS      = 2,
		  //INIT_FILE             = "./instructions.dat";
		  INIT_FILE             = "/home/sahanb/instructions.dat";

//localparams
localparam WORDS_PER_LINE = 1 << OFFSET_BITS;
localparam BUS_WIDTH_L1   = STATUS_BITS_L1 + COHERENCE_BITS + DATA_WIDTH*WORDS_PER_LINE;
localparam BUS_WIDTH_L2   = STATUS_BITS_L2 + COHERENCE_BITS + DATA_WIDTH*WORDS_PER_LINE;

`include "./params.v"
//`include "/home/sahanb/Documents/1-Projects/1-adaptive_cache/1-workspace/28-coherence/params.v"

// wires and registers
reg clock, reset;
reg read0, read1, write0, write1, invalidate0, invalidate1, flush0, flush1;
reg [ADDRESS_WIDTH-1 : 0] address0, address1;
reg [DATA_WIDTH-1 : 0] data_in0, data_in1;
reg report_l1_0, report_l1_1, report_l2, report;


wire [DATA_WIDTH-1 : 0] data_out0, data_out1;
wire [ADDRESS_WIDTH-1 : 0] out_address0, out_address1;
wire ready0, ready1, valid0,valid1;
wire [BUS_WIDTH_L1-1 : 0] cache2mem_data0, cache2mem_data1;
wire [ADDRESS_WIDTH-1 : 0] cache2mem_address0, cache2mem_address1;
wire [MSG_BITS-1 : 0] cache2mem_msg0, cache2mem_msg1;
wire [BUS_WIDTH_L1-1 : 0] mem2cache_data0, mem2cache_data1;
wire [ADDRESS_WIDTH-1 : 0] mem2cache_address0, mem2cache_address1;
wire [MSG_BITS-1 : 0] mem2cache_msg0, mem2cache_msg1;
wire [MSG_BITS-1 : 0] coherence_msg_in0, coherence_msg_in1, coherence_msg_out0,
                      coherence_msg_out1;
wire [BUS_WIDTH_L1-1 : 0] coherence_data0, coherence_data1;
wire [ADDRESS_WIDTH-1 : 0] coherence_address0, coherence_address1;
wire [NUM_L1_CACHES*BUS_WIDTH_L1-1 : 0] cache2cc_data, cc2mem_data,
                                     cache2cc_coh_data, Lx2cache_data;
wire [NUM_L1_CACHES*ADDRESS_WIDTH-1 : 0] cache2cc_address, cc2mem_address,
                                      Lx2cache_address;
wire [NUM_L1_CACHES*MSG_BITS-1 : 0] cache2cc_msg, cc2mem_msg, cc2cache_msg,
                               cache2cc_coh_msg, cc2cache_coh_msg, Lx2cache_msg;
wire [BUS_WIDTH_L2-1 : 0] cache2interface_data;
wire [ADDRESS_WIDTH-1 : 0] cache2interface_address, cc2cache_coh_address;
wire [MSG_BITS-1 : 0] cache2interface_msg;

///
wire [MSG_BITS-1 : 0] interface2cache_msg;
wire [ADDRESS_WIDTH-1 : 0] interface2cache_address;
wire [BUS_WIDTH_L2-1 : 0] interface2cache_data;

reg [MSG_BITS-1 : 0] network2cache_msg          = 0;
reg [ADDRESS_WIDTH-1 : 0] network2cache_address = 0;
reg [DATA_WIDTH-1 : 0] network2cache_data       = 0;

wire [MSG_BITS-1 : 0] cache2network_msg;
wire [ADDRESS_WIDTH-1 : 0] cache2network_address;
wire [DATA_WIDTH-1 : 0] cache2network_data;

wire [MSG_BITS-1 : 0] mem2interface_msg,mem2nw_msg;
wire [ADDRESS_WIDTH-1 : 0] mem2interface_address,mem2nw_address;
wire [DATA_WIDTH-1 : 0] mem2interface_data,mem2nw_data;
reg [MSG_BITS-1 : 0] nw2mem_msg;
reg [ADDRESS_WIDTH-1 : 0] nw2mem_address;
reg [DATA_WIDTH-1 : 0] nw2mem_data;

wire [MSG_BITS-1 : 0] interface2mem_msg;
wire [ADDRESS_WIDTH-1 : 0] interface2mem_address;
wire [DATA_WIDTH-1 : 0] interface2mem_data;
///

assign cache2cc_data      = {cache2mem_data1, cache2mem_data0};
assign cache2cc_address   = {cache2mem_address1, cache2mem_address0};
assign cache2cc_msg       = {cache2mem_msg1, cache2mem_msg0};
assign cache2cc_coh_msg   = {coherence_msg_out1, coherence_msg_out0};
assign cache2cc_coh_data  = {coherence_data1, coherence_data0};
assign coherence_msg_in0  = cc2cache_coh_msg[0*MSG_BITS +: MSG_BITS];
assign coherence_msg_in1  = cc2cache_coh_msg[1*MSG_BITS +: MSG_BITS];
assign coherence_address0 = cc2cache_coh_address;
assign coherence_address1 = cc2cache_coh_address;
assign mem2cache_address0 = Lx2cache_address[0*ADDRESS_WIDTH +: ADDRESS_WIDTH];
assign mem2cache_address1 = Lx2cache_address[1*ADDRESS_WIDTH +: ADDRESS_WIDTH];
assign mem2cache_data0    = Lx2cache_data[0*BUS_WIDTH_L1 +: BUS_WIDTH_L1];
assign mem2cache_data1    = Lx2cache_data[1*BUS_WIDTH_L1 +: BUS_WIDTH_L1];
assign mem2cache_msg0     = Lx2cache_msg[0*MSG_BITS +: MSG_BITS];
assign mem2cache_msg1     = Lx2cache_msg[1*MSG_BITS +: MSG_BITS];

// generate clock
always #1 clock = ~clock;

// Performance data
reg [31 : 0] cycles;
always @ (posedge clock) begin
        if (reset)
                cycles           <= 0;
        else begin
                cycles           <= cycles + 1;
        end
end


//instantiate modules
//L1 cache 0
L1cache #(STATUS_BITS_L1, COHERENCE_BITS, OFFSET_BITS, DATA_WIDTH, NUMBER_OF_WAYS_L1,
          REPLACEMENT_MODE_BITS, ADDRESS_WIDTH, INDEX_BITS_L1, MSG_BITS, 0, 0 )
          L1_0 (clock, reset, read0, write0, invalidate0, flush0, address0,
          data_in0, (report_l1_0|report), data_out0, out_address0, ready0, valid0, mem2cache_msg0,
          mem2cache_data0, mem2cache_address0, cache2mem_msg0, cache2mem_data0, 
          cache2mem_address0, coherence_msg_in0, coherence_address0, coherence_msg_out0,
          coherence_data0);

//L1 cache 1
L1cache #(STATUS_BITS_L1, COHERENCE_BITS, OFFSET_BITS, DATA_WIDTH, NUMBER_OF_WAYS_L1,
          REPLACEMENT_MODE_BITS, ADDRESS_WIDTH, INDEX_BITS_L1, MSG_BITS, 1, 1 )
          L1_1 (clock, reset, read1, write1, invalidate1, flush1, address1,
          data_in1, (report_l1_1|report), data_out1, out_address1, ready1, valid1, mem2cache_msg1,
          mem2cache_data1, mem2cache_address1, cache2mem_msg1, cache2mem_data1, 
          cache2mem_address1, coherence_msg_in1, coherence_address1, coherence_msg_out1,
          coherence_data1);

//Coherence controller
coherence_controller #(STATUS_BITS_L1, COHERENCE_BITS, OFFSET_BITS, DATA_WIDTH, ADDRESS_WIDTH,
                       MSG_BITS, NUM_L1_CACHES)
                       C_CTRL (clock, reset, cache2cc_data, cache2cc_address, cache2cc_msg,
                       cc2mem_data, cc2mem_address, cc2mem_msg, Lx2cache_msg, cache2cc_coh_msg,
                       cache2cc_coh_data, cc2cache_coh_msg, cc2cache_coh_address);

//L2 cache
Lxcache #(STATUS_BITS_L2, COHERENCE_BITS, OFFSET_BITS, DATA_WIDTH, NUMBER_OF_WAYS_L2,
          REPLACEMENT_MODE_BITS, ADDRESS_WIDTH, INDEX_BITS_L2, MSG_BITS, NUM_L1_CACHES, 2)
          L2_0 (clock, reset, cc2mem_address, cc2mem_data, cc2mem_msg, (report_l2|report),
                Lx2cache_data, Lx2cache_address, Lx2cache_msg, interface2cache_msg,
                interface2cache_address, interface2cache_data, cache2interface_msg,
                cache2interface_address, cache2interface_data);
				
//Main memory interface
main_memory_interface #( STATUS_BITS_L2, COHERENCE_BITS, OFFSET_BITS, DATA_WIDTH,
    ADDRESS_WIDTH, MSG_BITS)
    DUT_intf(clock, reset, cache2interface_msg, cache2interface_address,
        cache2interface_data, interface2cache_msg, interface2cache_address,
        interface2cache_data, network2cache_msg, network2cache_address,
        network2cache_data, cache2network_msg, cache2network_address, 
        cache2network_data, mem2interface_msg, mem2interface_address,
        mem2interface_data, interface2mem_msg, interface2mem_address,
        interface2mem_data);
		
//Main memory
main_memory #(DATA_WIDTH, ADDRESS_WIDTH, MSG_BITS, INDEX_BITS_MEMORY, NUM_MEMORY_PORTS, INIT_FILE)
    DUT_mem(clock, reset, {nw2mem_msg,interface2mem_msg}, {nw2mem_address,interface2mem_address},
    {nw2mem_data,interface2mem_data}, {mem2nw_msg,mem2interface_msg}, {mem2nw_address,
    mem2interface_address}, {mem2nw_data,mem2interface_data});

				
// processes
// Global signals
initial begin
    clock  = 1;
    reset  = 1;
    report = 0;
    nw2mem_msg     = NO_REQ;
    nw2mem_address = 0;
    nw2mem_data    = 0;
    $display("### Begin simulation.\n");
    $display("### Assert reset.\n");
    repeat(4) @(posedge clock);
    @(posedge clock) reset = 0;
    $display("### De-assert reset.\n");
end

// L1_0 processor
initial begin
    read0       = 0;
    write0      = 0;
    invalidate0 = 0;
    flush0      = 0;
    data_in0    = 0;
    address0    = 0;
    report_l1_0 = 0;
    wait(~reset);
    @(posedge clock)begin
        read0    = 1;
        address0 = 32'h00000004;
    end
    $display("### L1 cache 0; read request; address:%8h | Cycle count:%3d\n", address0, cycles+1);
    @(posedge clock) read0 = 0;
    wait(valid0);
    $display("### L1 cache 0; responded to read request; out_address:%8h; data:%8h | Cycle count:%3d\n", out_address0, data_out0, cycles);
    $display("\n\n@@@@@ Cache dump @@@@@");
    report_l1_0 = 1; report_l1_1 = 0; report_l2  = 0;
    @(posedge clock)begin report_l1_0 = 0; report_l1_1 = 0; report_l2  = 0; end
    $display("\n\n\n");
    wait(ready0);
    @(posedge clock)begin
        read0    = 1;
        address0 = 32'h00000005;
    end
    $display("### L1 cache 0; read request; address:%8h | Cycle count:%3d\n", address0, cycles+1);
    @(posedge clock)begin
        read0    = 1;
        address0 = 32'h00000006;
    end
    $display("### L1 cache 0; read request; address:%8h | Cycle count:%3d\n", address0, cycles+1);
    wait(valid0 & out_address0 == 32'h5);
    $display("### L1 cache 0; responded to read request; out_address:%8h; data:%8h | Cycle count:%3d\n", out_address0, data_out0, cycles);

    @(posedge clock)begin
        read0    = 1;
        address0 = 32'h00000007;
    end
    $display("### L1 cache 0; read request; address:%8h | Cycle count:%3d\n", address0, cycles+1);
    wait(valid0 & out_address0 == 32'h6);
    $display("### L1 cache 0; responded to read request; out_address:%8h; data:%8h | Cycle count:%3d\n", out_address0, data_out0, cycles);
    @(posedge clock)begin
        read0    = 1;
        address0 = 32'h00000008;
    end
    $display("### L1 cache 0; read request; address:%8h | Cycle count:%3d\n", address0, cycles+1);
    wait(valid0 & out_address0 == 32'h7);
    $display("### L1 cache 0; responded to read request; out_address:%8h; data:%8h | Cycle count:%3d\n", out_address0, data_out0, cycles);
wait(valid0 & out_address0 == 32'h8);
    $display("### L1 cache 0; responded to read request; out_address:%8h; data:%8h | Cycle count:%3d\n", out_address0, data_out0, cycles);
    $display("\n\n@@@@@ Cache dump @@@@@");
    report_l1_0 = 1; report_l1_1 = 0; report_l2  = 0;
    @(posedge clock)begin report_l1_0 = 0; report_l1_1 = 0; report_l2  = 0; end
    $display("\n\n\n");    
    
    
    
    
    
    
/*    @(posedge clock)begin
        read0 = 0;
        write0 = 1;
        address0 = 12'h12a;
        data_in0 = 8'h99;
    end
    $display("### L1 cache 0; write request; address:%3h; data_in:%2h. | Cycle count:%3d\n", address0, data_in0, cycles+1);
    @(posedge clock) write0 = 0;
    wait(valid0);
    $display("### L1 cache 0; responded to read request; out_address:%3h; data:%2h. | Cycle count:%3d\n", out_address0, data_out0, cycles);
    $display("\n\n@@@@@ Cache dump @@@@@");
    report_l1_0 = 1; report_l1_1 = 1; report_l2  = 1;
    @(posedge clock) begin report_l1_0 = 0; report_l1_1 = 0; report_l2  = 0; end
    $display("\n\n\n");
    wait(ready0);
    $display("### L1 cache 0; ready after write request; out_address:%3h | Cycle count:%3d\n", out_address0, cycles);
    $display("\n\n@@@@@ Cache dump @@@@@");
    report_l1_0 = 1; report_l1_1 = 1; report_l2  = 1;
    @(posedge clock) begin report_l1_0 = 0; report_l1_1 = 0; report_l2  = 0; end
    $display("\n\n\n");
    @(posedge clock)begin
        address0 = 12'h12d;
        data_in0 = 8'h00;
        write0   = 1;
    end
	$display("### L1 cache 0; write request; address:%3h; data_in:%2h. | Cycle count:%3d\n", address0, data_in0, cycles+1);
    @(posedge clock) write0 = 0;
    wait(out_address0 == 12'h12d);
    @(posedge clock)begin
	    $display("### L1 cache 0; Status after write request; out_address:%3h | Cycle count:%3d\n", out_address0, cycles+1);
	    $display("\n\n@@@@@ Cache dump @@@@@");
        report_l1_0 = 1; report_l1_1 = 0; report_l2  = 1;
        @(posedge clock) begin report_l1_0 = 0; report_l1_1 = 0; report_l2  = 0; end
        $display("\n\n\n");
    end
    wait(~ready0);
    wait(ready0);
    repeat(10) @(posedge clock);
    @(posedge clock)begin
        read0    = 1;
        address0 = 12'h884;
    end
	$display("### L1 cache 0; read request; address:%3h | Cycle count:%3d\n", address0, cycles+1);
    @(posedge clock) read0 = 0;
	wait(valid0);
	$display("### L1 cache 0; responded to read request; out_address:%3h; data:%2h. | Cycle count:%3d\n", out_address0, data_out0, cycles);
    $display("\n\n@@@@@ Cache dump @@@@@");
    report_l1_0 = 1; report_l1_1 = 0; report_l2  = 1;
    @(posedge clock) begin report_l1_0 = 0; report_l1_1 = 0; report_l2  = 0; end
    $display("\n\n\n");
*/end

// L1_1 processor
initial begin
    read1       = 0;
    write1      = 0;
    invalidate1 = 0;
    flush1      = 0;
    data_in1    = 0;
    address1    = 0;
    report_l1_1 = 0;
    wait(~reset);
    repeat(63) @(posedge clock);
    @(posedge clock)begin
        write1    = 1;
        address1 = 32'h5;
        data_in1 = 32'h99995555;
    end
	$display("### L1 cache 1; write request; address:%8h; data:%8h | Cycle count:%3d\n", address1, data_in1, cycles+1);
    @(posedge clock) write1 = 0;
    wait(ready1);
	$display("### L1 cache 1; Status after write request; out_address:%8h | Cycle count:%3d\n", out_address1, cycles+1);
	$display("\n\n@@@@@ Cache dump @@@@@");
    report_l1_0 = 0; report_l1_1 = 1; report_l2  = 0;
    @(posedge clock) begin report_l1_0 = 0; report_l1_1 = 0; report_l2  = 0; end
    $display("\n\n\n");

    @(posedge clock)begin
        flush1   = 1;
        address1 = 32'h5;
    end
	$display("### L1 cache 1; flush request; address:%8h; | Cycle count:%3d\n", address1, data_out1, cycles);
    @(posedge clock) flush1 = 0;


/*
    $display("\n\n@@@@@ Cache dump @@@@@");
    report_l1_0 = 0; report_l1_1 = 1; report_l2  = 1;
    @(posedge clock)begin report_l1_0 = 0; report_l1_1 = 0; report_l2  = 0; end
    $display("\n\n\n");
    wait(ready1);
    repeat(20) @(posedge clock);
    @(posedge clock) begin
        read1 = 1;
        address1 = 12'h12a;
    end
	$display("### L1 cache 1; read request; address:%3h | Cycle count:%3d\n", address1, cycles+1);
    @(posedge clock) read1 = 0;
    wait(valid1);
	$display("### L1 cache 1; responded to read request; out_address:%3h; data:%2h | Cycle count:%3d\n", out_address1, data_out1, cycles);
    $display("\n\n@@@@@ Cache dump @@@@@");
    report_l1_0 = 1; report_l1_1 = 1; report_l2  = 1;
    @(posedge clock)begin report_l1_0 = 0; report_l1_1 = 0; report_l2  = 0; end
    $display("\n\n\n");
    wait(ready1);
    @(posedge clock)begin
        read1    = 1;
        address1 = 12'h14c;
    end
	$display("### L1 cache 1; read request; address:%3h | Cycle count:%3d\n", address1, cycles+1);
    @(posedge clock) address1 = 12'h16c;
	$display("### L1 cache 1; read request; address:%3h | Cycle count:%3d\n", address1, cycles+1);
    @(posedge clock) read1 = 0;
	wait(valid1 & (out_address1 == 12'h14c));
	$display("### L1 cache 1; responded to read request; out_address:%3h; data:%2h | Cycle count:%3d\n", out_address1, data_out1, cycles);
    $display("\n\n@@@@@ Cache dump @@@@@");
    report_l1_0 = 0; report_l1_1 = 1; report_l2  = 1;
    @(posedge clock)begin report_l1_0 = 0; report_l1_1 = 0; report_l2  = 0; end
    $display("\n\n\n");
    wait(valid1 & (out_address1 == 12'h16c));
	$display("### L1 cache 1; responded to read request; out_address:%3h; data:%2h | Cycle count:%3d\n", out_address1, data_out1, cycles);
    $display("\n\n@@@@@ Cache dump @@@@@");
    report_l1_0 = 0; report_l1_1 = 1; report_l2  = 1;
    @(posedge clock)begin report_l1_0 = 0; report_l1_1 = 0; report_l2  = 0; end
    $display("\n\n\n");
    wait(ready1);
    @(posedge clock)begin
        read1    = 1;
        address1 = 12'h18c;
    end
	$display("### L1 cache 1; read request; address:%3h | Cycle count:%3d\n", address1, cycles+1);
    @(posedge clock) address1 = 12'h1ac;
	$display("### L1 cache 1; read request; address:%3h | Cycle count:%3d\n", address1, cycles+1);
    @(posedge clock) read1 = 0;
	wait(valid1 & (out_address1 == 12'h18c));
	$display("### L1 cache 1; responded to read request; out_address:%3h; data:%2h | Cycle count:%3d\n", out_address1, data_out1, cycles);
    $display("\n\n@@@@@ Cache dump @@@@@");
    report_l1_0 = 0; report_l1_1 = 1; report_l2  = 1;
    @(posedge clock)begin report_l1_0 = 0; report_l1_1 = 0; report_l2  = 0; end
    $display("\n\n\n");
	wait(valid1 & (out_address1 == 12'h1ac));
	$display("### L1 cache 1; responded to read request; out_address:%3h; data:%2h | Cycle count:%3d\n", out_address1, data_out1, cycles);
    $display("\n\n@@@@@ Cache dump @@@@@");
    report_l1_0 = 1; report_l1_1 = 1; report_l2  = 1;
    @(posedge clock)begin report_l1_0 = 0; report_l1_1 = 0; report_l2  = 0; end
    $display("\n\n\n");
    //wait(valid1);
    wait(ready1);
    repeat(1) @(posedge clock);
    @(posedge clock)begin
        read1    = 1;
        address1 = 12'h884;
    end
	$display("### L1 cache 1; read request; address:%3h | Cycle count:%3d\n", address1, cycles+1);
    @(posedge clock) read1 = 0;
	wait(valid1);
	$display("### L1 cache 1; responded to read request; out_address:%3h; data:%2h | Cycle count:%3d\n", out_address1, data_out1, cycles);
    $display("\n\n@@@@@ Cache dump @@@@@");
    report_l1_0 = 1; report_l1_1 = 1; report_l2  = 1;
    @(posedge clock)begin report_l1_0 = 0; report_l1_1 = 0; report_l2  = 0; end
    $display("\n\n\n");
*/end

/*// memory
initial begin
    interface2cache_address = 0;
    interface2cache_data    = 0;
    interface2cache_msg     = MEM_NO_MSG;
    report_l2     = 0;
    wait((cache2interface_msg == R_REQ) & (cache2interface_address == 12'h12c));
    $display("### Memory: read request: address:%3h | cycle count:%3d\n", cache2interface_address, cycles);
    repeat(1) @(posedge clock);
    @(posedge clock)begin
        interface2cache_data    = 37'h1077778888;
        interface2cache_msg     = MEM_SENT;
        interface2cache_address = 12'h12c;
    end
    $display("### Memory: Response to read request: address:%3h : Cache line:%8h | cycle count:%3d\n", interface2cache_address, interface2cache_data, cycles+1);
    @(posedge clock) interface2cache_msg = MEM_NO_MSG;
    wait((cache2interface_msg == R_REQ) & (cache2interface_address == 12'h128));
	$display("### Memory: read request: address:%3h | cycle count:%3d\n", cache2interface_address, cycles);
    repeat(1) @(posedge clock);
    @(posedge clock)begin
        interface2cache_data    = 37'h1022223333;
        interface2cache_msg     = MEM_SENT;
        interface2cache_address = 12'h128;
    end
	$display("### Memory: Response to read request: address:%3h : Cache line:%8h | cycle count:%3d\n", interface2cache_address, interface2cache_data, cycles+1);
    @(posedge clock) interface2cache_msg = MEM_NO_MSG;
    wait((cache2interface_msg == R_REQ) & (cache2interface_address == 12'h14c));
	$display("### Memory: read request: address:%3h | cycle count:%3d\n", cache2interface_address, cycles);
    repeat(1) @(posedge clock);
    @(posedge clock)begin
        interface2cache_data    = 37'h1011223344;
        interface2cache_msg     = MEM_SENT;
        interface2cache_address = 12'h14c;
    end
	$display("### Memory: Response to read request: address:%3h : Cache line:%8h | cycle count:%3d\n", interface2cache_address, interface2cache_data, cycles+1);
    @(posedge clock) interface2cache_msg = MEM_NO_MSG;
    wait((cache2interface_msg == R_REQ) & (cache2interface_address == 12'h16c));
	$display("### Memory: read request: address:%3h | cycle count:%3d\n", cache2interface_address, cycles);
    repeat(1) @(posedge clock);
    @(posedge clock)begin
        interface2cache_data    = 37'h1065566556;
        interface2cache_msg     = MEM_SENT;
        interface2cache_address = 12'h16c;
    end
	$display("### Memory: Response to read request: address:%3h : Cache line:%8h | cycle count:%3d\n", interface2cache_address, interface2cache_data, cycles+1);
    @(posedge clock) interface2cache_msg = MEM_NO_MSG;
    wait((cache2interface_msg == R_REQ) & (cache2interface_address == 12'h18c));
	$display("### Memory: read request: address:%3h | cycle count:%3d\n", cache2interface_address, cycles);
    repeat(1) @(posedge clock);
    @(posedge clock)begin
        interface2cache_data    = 37'h1033332255;
        interface2cache_msg     = MEM_SENT;
        interface2cache_address = 12'h18c;
    end
	$display("### Memory: Response to read request: address:%3h : Cache line:%8h | cycle count:%3d\n", interface2cache_address, interface2cache_data, cycles+1);
    @(posedge clock) interface2cache_msg = MEM_NO_MSG;
    wait((cache2interface_msg == WB_REQ) & (cache2interface_address == 12'h12c));
	$display("### Memory: write-back request: address:%3h; data:%8h | cycle count:%3d\n", cache2interface_address, cache2interface_data, cycles);
    @(posedge clock) interface2cache_msg = MEM_READY;
	$display("### Memory: Accept write-back request | cycle count:%3d\n", cycles+1);
    @(posedge clock) interface2cache_msg = MEM_NO_MSG;
    wait((cache2interface_msg == R_REQ) & (cache2interface_address == 12'h1ac));
	$display("### Memory: read request: address:%3h | cycle count:%3d\n", cache2interface_address, cycles);
    repeat(1) @(posedge clock);
    @(posedge clock)begin
        interface2cache_data    = 37'h1069966996;
        interface2cache_msg     = MEM_SENT;
        interface2cache_address = 12'h1ac;
    end
	$display("### Memory: Response to read request: address:%3h : Cache line:%8h | cycle count:%3d\n", interface2cache_address, interface2cache_data, cycles+1);
    @(posedge clock) interface2cache_msg = MEM_NO_MSG;
    wait((cache2interface_msg == R_REQ) & (cache2interface_address == 12'h884));
	$display("### Memory: read request: address:%3h | cycle count:%3d\n", cache2interface_address, cycles);
    repeat(1) @(posedge clock);
    @(posedge clock)begin
        interface2cache_data    = 37'h1010203040;
        interface2cache_msg     = MEM_SENT;
        interface2cache_address = 12'h884;
    end
	$display("### Memory: Response to read request: address:%3h : Cache line:%8h | cycle count:%3d\n", interface2cache_address, interface2cache_data, cycles+1);
    @(posedge clock) interface2cache_msg = MEM_NO_MSG;
end

*/

endmodule
