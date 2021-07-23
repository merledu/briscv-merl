radix -hex
source modelsim_radix.tcl

add wave sim:/tb_lxcache/clock
add wave sim:/tb_lxcache/reset
add wave sim:/tb_lxcache/mismatch

add wave -radix lx_states sim:/tb_lxcache/DUT/state

add wave -radix cache_msgs sim:/tb_lxcache/msg_in0
add wave sim:/tb_lxcache/address0
add wave sim:/tb_lxcache/data_in0
add wave -radix mem_msgs sim:/tb_lxcache/msg_out0
add wave sim:/tb_lxcache/out_address0
add wave sim:/tb_lxcache/data_out0

add wave -radix cache_msgs sim:/tb_lxcache/msg_in1
add wave sim:/tb_lxcache/address1
add wave sim:/tb_lxcache/data_in1
add wave -radix mem_msgs sim:/tb_lxcache/msg_out1
add wave sim:/tb_lxcache/out_address1
add wave sim:/tb_lxcache/data_out1

add wave -radix cache_msgs sim:/tb_lxcache/msg_in2
add wave sim:/tb_lxcache/address2
add wave sim:/tb_lxcache/data_in2
add wave -radix mem_msgs sim:/tb_lxcache/msg_out2
add wave sim:/tb_lxcache/out_address2
add wave sim:/tb_lxcache/data_out2

add wave -radix cache_msgs sim:/tb_lxcache/msg_in3
add wave sim:/tb_lxcache/address3
add wave sim:/tb_lxcache/data_in3
add wave -radix mem_msgs sim:/tb_lxcache/msg_out3
add wave sim:/tb_lxcache/out_address3
add wave sim:/tb_lxcache/data_out3

add wave -radix cache_msgs sim:/tb_lxcache/cache2mem_msg
add wave sim:/tb_lxcache/cache2mem_address
add wave sim:/tb_lxcache/cache2mem_data
add wave -radix mem_msgs sim:/tb_lxcache/mem2cache_msg
add wave sim:/tb_lxcache/mem2cache_address
add wave sim:/tb_lxcache/mem2cache_data

#run 3800
