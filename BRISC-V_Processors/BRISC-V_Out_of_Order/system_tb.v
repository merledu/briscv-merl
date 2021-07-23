
module tb_combined_units();

reg clock;
reg reset;
reg valid;
reg [31:0] noOpCount;
reg [31:0] instructionCount;
reg [31:0] totalInstructionCount;
reg [31:0] inner_hazard_count [0:3];
reg [31:0] outer_hazard_count [0:3];
reg [31:0] queue_used_cycle_count;



wire [31:0] scheduled_instruction;
wire [19:0] scheduled_instruction_PC;
wire [4:0]  register_writeback;
wire scheduler_valid;
wire [31: 0] cycle_count;
wire endsim;   
wire [31: 0] writeback_register_data;  
wire [3:  0] inner_hazard_bits;
wire [3:  0] outer_hazard_bits;
wire [3:  0] queue_in_use;

real IPC;
real CPI;
real real_cycles;
real real_instructions;
real average_inner_hazard;
real average_outer_hazard;

top_level #() system_under_test(

    .clock(clock),                                                          
    .reset(reset),                                   
                                                                                            
    .scheduled_instruction(scheduled_instruction), 
    .scheduled_instruction_PC(scheduled_instruction_PC),          
    .cycle_count(cycle_count),
    .scheduler_valid(scheduler_valid),
    .register_writeback(register_writeback),
    .writeback_register_data(writeback_register_data),     
    .hazard_table_TB(outer_hazard_bits),         
    .inner_hazard_table_TB(inner_hazard_bits),
    .queue_table_in_use_TB(queue_in_use)       

);


assign endsim = (register_writeback == 5'h09) ? 1'b0: 1'b1; //5'h09 is the real result reg
// Clock generator
always #1 clock = ~clock;
initial begin
// this test will fill the scheduler and then fill the queue
    $dumpfile ("decode.vcd");
    $dumpvars();
    
    $display("############################################");
    $display("#              BRISC-V  OOOE               #");
    $display("############################################ \n");
      noOpCount                <= 1;  // first no-op accounted for.
      instructionCount         <= 0;
      IPC                      <= 0;
      CPI                      <= 0;
      inner_hazard_count[0]    <= 0;
      inner_hazard_count[1]    <= 0; 
      inner_hazard_count[2]    <= 0;
      inner_hazard_count[3]    <= 0;
      outer_hazard_count[0]    <= 0;
      outer_hazard_count[1]    <= 0; 
      outer_hazard_count[2]    <= 0;
      outer_hazard_count[3]    <= 0;
      queue_used_cycle_count   <= 0;
      reset                    <= 1;
      clock                    <= 0;
    #1 reset                   <= 0; 
    #1;

    $display (" --- Start ---  \n");
    $display(" PC    | scheduled_instruction  \n");
    while(endsim > 0) begin
        if(|queue_in_use) begin
        queue_used_cycle_count <= queue_used_cycle_count + 1; 
        end
        // count each bit in inner hazard and outter hazard each cycle then divide each bit
        // by total cycles then sum the averages for average total. 
        if(inner_hazard_bits > 0) begin  // see if I can replace with a for loop
            inner_hazard_count[0] <= (inner_hazard_bits[0]) ? inner_hazard_count[0] +1 : inner_hazard_count[0];
            inner_hazard_count[1] <= (inner_hazard_bits[1]) ? inner_hazard_count[1] +1 : inner_hazard_count[1];
            inner_hazard_count[2] <= (inner_hazard_bits[2]) ? inner_hazard_count[2] +1 : inner_hazard_count[2];
            inner_hazard_count[3] <= (inner_hazard_bits[3]) ? inner_hazard_count[3] +1 : inner_hazard_count[3];
        end
        if(outer_hazard_bits > 0) begin
            outer_hazard_count[0] <= (outer_hazard_bits[0]) ? outer_hazard_count[0] +1 : outer_hazard_count[0];
            outer_hazard_count[1] <= (outer_hazard_bits[1]) ? outer_hazard_count[1] +1 : outer_hazard_count[1];
            outer_hazard_count[2] <= (outer_hazard_bits[2]) ? outer_hazard_count[2] +1 : outer_hazard_count[2];
            outer_hazard_count[3] <= (outer_hazard_bits[3]) ? outer_hazard_count[3] +1 : outer_hazard_count[3];
        end
        if(scheduler_valid ==1'b1) begin
            if (scheduled_instruction_PC != 0) begin
                $display("%h  : %h     \n", scheduled_instruction_PC, scheduled_instruction );
                instructionCount <= instructionCount + 1;
            end
            else begin
                noOpCount <= noOpCount + 1;
            end
        end
        #2;
        totalInstructionCount <= noOpCount + instructionCount;
    end
    // add up add the cycles there was a hazard in the instruciton queue
    average_inner_hazard = (inner_hazard_count[0] + inner_hazard_count[1] +
                           inner_hazard_count[2] + inner_hazard_count[3]) ;
    average_outer_hazard = (outer_hazard_count[0] + outer_hazard_count[1] +
                           outer_hazard_count[2] + outer_hazard_count[3]);
                           
    // average the values by dividing by the number of cycles the queue is used.             
    average_outer_hazard =  average_outer_hazard / queue_used_cycle_count;  
    average_inner_hazard =  average_inner_hazard / queue_used_cycle_count;  
                         
    real_instructions    =  totalInstructionCount;
    real_cycles          =  cycle_count;
    // Instruction per cycles
    IPC                  =  real_instructions / real_cycles;
    // cycles per instructions
    CPI                  =  real_cycles /real_instructions;
    
    $display("program took %d cycles to complete.\n", cycle_count);
    $display("There were %d extra noops ran. \n",     noOpCount);
    $display("The IPC is calculated as                                        %f.\n", IPC);
    $display("The CPI is calcuated as                                         %f.\n", CPI);
    // average instruction dependencie
    $display("The average of instrucitons in the queue with outer hazards is  %f.\n", (average_outer_hazard *100));
    $display("The percent of instrucitons in the queue with inner hazards is  %f.\n", (average_inner_hazard *100));
    $display("The total percent of instrucitons in the queue with hazards is  %f.\n", ((average_outer_hazard + average_inner_hazard)*100));
    // average # of cycles an instruction is in each module.
    // instruction queue average
    $display("The instruction queue is activly used  %f percent of run \n",  ((queue_used_cycle_count/real_cycles)*100));
    $display("The final result of the program was %d \n",  writeback_register_data );
    
    $stop;
end
endmodule