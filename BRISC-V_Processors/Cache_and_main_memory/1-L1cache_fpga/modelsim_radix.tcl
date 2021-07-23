radix define l1_states {
4'd0 "IDLE",
4'd1 "RESET",          
4'd2 "WAIT_FOR_ACCESS",
4'd3 "CACHE_ACCESS",
4'd4 "READ_STATE",  
4'd5 "WRITE_BACK",    
4'd6 "WAIT",          
4'd7 "UPDATE",        
4'd8 "WB_WAIT",       
4'd9 "SRV_FLUSH_REQ", 
4'd10 "WAIT_FLUSH_REQ",
4'd11 "SRV_INVLD_REQ",
4'd12 "WAIT_INVLD_REQ",
4'd13 "WAIT_WS_ENABLE"
}

radix define lx_states {
 4'd0 "IDLE",
 4'd1 "SERVING",
 4'd2 "READ_OUT",
 4'd3 "WRITE",
 4'd4 "READ_ST",
 4'd5 "WRITE_BACK",
 4'd6 "UPDATE",
 4'd7 "FLUSH_WAIT",
 4'd8 "SERV_FLUSH_REQ",
 4'd9 "NO_FLUSH_RESP",
 4'd10 "SERV_INVLD",
 4'd11 "WAIT_INVLD",
 4'd12 "RESET",
 4'd13 "BRAM_DELAY"
}

radix define mem_msgs {
3'd0 "MEM_NO_MSG",
3'd1 "MEM_READY",
3'd2 "MEM_SENT",
3'd3 "REQ_FLUSH",
3'd4 "M_RECV"
}

radix define cache_msgs {
3'd0 "NO_REQ",
3'd1 "WB_REQ",
3'd2 "R_REQ",
3'd3 "FLUSH",
3'd4 "NO_FLUSH",
3'd5 "INVLD",
3'd6 "WS_BCAST",
3'd7 "RFO_BCAST"
}

radix define l1_coherence_msg_in {
3'd0 "C_NO_REQ",
3'd1 "C_RD_BCAST",
3'd2 "ENABLE_WS",
3'd3 "C_FLUSH_BCAST",
3'd4 "C_INVLD_BCAST",
3'd5 "C_WS_BCAST",
3'd6 "C_RFO_BCAST"
}

radix define l1_coherence_msg_out {
3'd0 "C_NO_RESP",
3'd1 "C_WB",
3'd2 "C_EN_ACCESS",
3'd3 "C_FLUSH",
3'd5 "C_INVLD" 
}

radix define l1_coherence_states {
3'd0 "NO_COHERENCE_OP",
3'd1 "BRAM_ACCESS",
3'd2 "HANDLE_COH_OP",
3'd3 "WAIT_FOR_CONTROLLER"
}

radix define coh_controller_states {
3'd0 "IDLE",
3'd1 "WAIT_EN",
3'd2 "COHERENCE_WB",
3'd3 "GRANT_ACCESS",
3'd4 "WAIT_CUR_ACCESS",
3'd5 "COHERENCE_FLUSH",
3'd6 "COHERENCE_INVLD",
3'd7 "WRITE_SHARED"
}

radix define mem_intf_states {
3'd0 "IDLE",
3'd1 "READ_MEMORY",
3'd2 "WRITE_MEMORY",
3'd3 "RESPOND"
}

radix define main_mem_states {
3'd0 "IDLE",
3'd1 "SERVING",
3'd2 "READ_OUT"
}
