radix -hex
source modelsim_radix.tcl

add wave sim:/tb_l1cache/clock
add wave -radix unsigned sim:/tb_l1cache/DUT/cycles
add wave sim:/tb_l1cache/reset
add wave sim:/tb_l1cache/mismatch

add wave -radix l1_states sim:/tb_l1cache/DUT/state
add wave -radix l1_coherence_states sim:/tb_l1cache/DUT/coh_state

add wave sim:/tb_l1cache/read
add wave sim:/tb_l1cache/write
add wave sim:/tb_l1cache/invalidate
add wave sim:/tb_l1cache/flush

add wave sim:/tb_l1cache/address
add wave sim:/tb_l1cache/data_in

add wave sim:/tb_l1cache/valid
add wave sim:/tb_l1cache/ready
add wave sim:/tb_l1cache/data_out
add wave sim:/tb_l1cache/out_address

add wave -radix cache_msgs sim:/tb_l1cache/cache2mem_msg
add wave sim:/tb_l1cache/cache2mem_address
add wave sim:/tb_l1cache/cache2mem_data

add wave -radix mem_msgs sim:/tb_l1cache/mem2cache_msg
add wave sim:/tb_l1cache/mem2cache_address
add wave sim:/tb_l1cache/mem2cache_data

add wave -radix l1_coherence_msg_in sim:/tb_l1cache/coherence_msg_in
add wave sim:/tb_l1cache/coherence_address
add wave -radix l1_coherence_msg_out sim:/tb_l1cache/coherence_msg_out
add wave sim:/tb_l1cache/coherence_data
