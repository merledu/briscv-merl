// LRU module accepts the clock and reset, along with:
//      access       - specifying which way is getting accessed 
//      access_valid - high when a way is getting accessed
//
// The module outputs a one-hot array 'lru', where 1 means that this way is the least recently used.

module LRU #( 
    parameter WIDTH=4
) (
    input clock,
    input reset, 
    input [log2(WIDTH)-1:0] access,
    input access_valid,
    output [WIDTH-1:0] lru
);
    
    //define the log2 function
    function integer log2;
      input integer num;
      integer i, result;
      begin
          for (i = 0; 2 ** i < num; i = i + 1)
              result = i + 1;
          log2 = result;
      end
    endfunction


    reg [WIDTH-1:0] order [WIDTH-1:0];
    genvar i;

    generate 
    for (i=0; i<WIDTH; i=i+1) begin:outer_loop
        always @ (posedge clock) begin
            if (reset) begin
                order[i] <= i; 
            end
            else begin 
                if (access_valid) begin
                    // If this way is accessed, it becomes the most recently used, with a value of 0
                    if (access == i) 
                        order[i] <= 0;
                    // If a different way is accessed and it was used less recently than this way, that way has just
                    // come to the front of the line and has pushed this way 1 step back, i.e. it cut in line. 
                    // On the other hand, if that way was used more recently, nothing changes for this way.
                    else if (order[access] > order[i]) 
                        order[i] <= order[i] + 1;
                end
            end
        end

        // LRU line is high if it is the least recently used line. Otherwise it is low.
        assign lru[i] = order[i] == (WIDTH - 1); 
    end 
    endgenerate 

endmodule
