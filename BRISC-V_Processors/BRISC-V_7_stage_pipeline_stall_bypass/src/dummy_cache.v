module dummy_cache #(
    parameter CORE = 0,
    parameter DATA_WIDTH = 32,
    parameter ADDRESS_BITS = 12,
    parameter PROGRAM = "../software/applications/binaries/<your_program>",
    parameter MISS_THRESHOLD = 3,
    parameter HIT_THRESHOLD = 3
) (

    input clock,
    input reset,

    input read,
    input write,
    input [ADDRESS_BITS-1:0] address,
    input [DATA_WIDTH-1:0] in_data,

    output reg valid,
    output reg ready,
    output [ADDRESS_BITS-1:0] out_addr,
    output [DATA_WIDTH-1:0] out_data

);

localparam CACHE_HIT   = 8'd0;
localparam CACHE_MISS = 8'd1;

reg [7:0] count;
reg [7:0] state;

wire [DATA_WIDTH-1:0] bram_read_data;
wire [DATA_WIDTH-1:0] bram_write_data;

assign bram_write_data = in_data;
assign out_data = valid ? bram_read_data : {DATA_WIDTH{1'b0}};

always@(posedge clock) begin
  if (reset) begin
        ready <= 1'b0;
        valid <= 1'b0;
        count <= 8'd0;
        state <= CACHE_HIT;
  end else begin
    case(state)
      CACHE_HIT: begin
        ready <= 1'b1;
        valid <= write; 
        count <= count > HIT_THRESHOLD ? 8'd0 : count + 8'd1;
        state <= count > HIT_THRESHOLD ? CACHE_MISS : CACHE_HIT;
      end
      CACHE_MISS: begin
        ready <= 1'b0;
        valid <= 1'b0;
        count <= count > MISS_THRESHOLD ? 8'd0 : count + 8'd1;
        state <= count > MISS_THRESHOLD ? CACHE_HIT : CACHE_MISS;
      end
      default: begin
        ready <= 1'b0;
        valid <= 1'b0;
        count <= 8'd0;
        state <= state;
      end
    endcase
  end
end

BRAM #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDRESS_BITS),
    .INIT_FILE(PROGRAM)
) RAM (
        .clock(clock),
        .readEnable(read_enable),
        .readAddress(address),
        .readData(bram_read_data),

        .writeEnable(write_enable),
        .writeAddress(address),
        .writeData(bram_write_data)
);



endmodule
