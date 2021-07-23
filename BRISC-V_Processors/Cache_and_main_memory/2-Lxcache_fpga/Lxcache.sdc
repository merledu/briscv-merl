create_clock -name clock -period 10 [get_ports {clock}]

set_multicycle_path -from {t_msg_out[*][*]} -to {cache2mem_data[*]} -setup -end 2
