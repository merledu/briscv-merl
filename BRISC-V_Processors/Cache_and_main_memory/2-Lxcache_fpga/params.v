// memory to cache messages
localparam MEM_NO_MSG = 0,
	       MEM_READY  = 1,
	       MEM_SENT   = 2,
	       REQ_FLUSH  = 3,
	       M_RECV     = 4;

// cache to memory messages
localparam NO_REQ     = 0,
           WB_REQ     = 1,
           R_REQ      = 2,
	       FLUSH      = 3,
	       NO_FLUSH   = 4,
	       INVLD      = 5,
	       WS_BCAST   = 6,
           RFO_BCAST  = 7;

// L1 cache to coherence controller messages
localparam C_NO_RESP   = 0,
	       C_WB        = 1,
	       C_EN_ACCESS = 2,
           C_FLUSH     = 3,
           C_INVLD     = 5;

// coherence controller to cache messages
localparam C_NO_REQ      = 0,
	       C_RD_BCAST    = 1,
	       ENABLE_WS     = 2,
           C_FLUSH_BCAST = 3,
	       C_INVLD_BCAST = 4,
	       C_WS_BCAST    = 5,
	       C_RFO_BCAST   = 6;
// coherence states
localparam INVALID   = 2'b00,
           EXCLUSIVE = 2'b01,
           SHARED    = 2'b11,
           MODIFIED  = 2'b10;
