/****************************************************************
 * parser_defs.sv - definition file for parser
 *
 * Authors        : Viraj Khatri (vk5@pdx.edu)
 * Last Modified  : 20th October, 2021
 *
 * Description    :
 * -----------
 * defines -
 * 1. address bus width
 * 2. trace file number to opcode conversion
 * 3. states of parser module - exported here so that the
 *                              test_bench can use states to
 *                              debug parser module
 ****************************************************************/

package global_defs;

parameter ADDRESS_WIDTH = 33;
parameter QUEUE_SIZE = 16;

typedef logic[31:0] int_t;

parameter BITS_FOR_100 = $clog2(100);
typedef logic[BITS_FOR_100-1:0] age_counter_t;

// 3 possible opcodes present in file + NOP extra
typedef enum logic[1:0] {
	DATA_READ = 0, // 0 = read
	DATA_WRITE,    // 1 = write
	OPCODE_FETCH,  // 2 = opcode fetch
	NOP            // 3 = No OPeration instruction
	               // a bus under reset or an uninitialized bus will have NOP
} parsed_op_t;

// parser module states
typedef enum logic {
	WAITE, // waiting for empty spot in queue
	NEW_OP // read and outputting new operation
} parser_states_t;

// output from parser
typedef struct packed {

	logic                            op_ready_s; // strobe signal to mark new output
	parsed_op_t                      opcode;     // opcode of operation
	logic        [ADDRESS_WIDTH-1:0] address;    // address of operation
	int_t                            time_cpu;   // cpu clock count for operation issue

} parser_out_struct_t;

parameter BG_OFFSET = 6;
parameter BANK_OFFSET = 8;
parameter COLUMN_OFFSET = 10;
parameter ROW_OFFSET = 18;

parameter [ADDRESS_WIDTH-1:0] bank_group_mask = ( {2{1'b1}} << BG_OFFSET );
parameter [ADDRESS_WIDTH-1:0] bank_mask       = ( {2{1'b1}} << BANK_OFFSET );
parameter [ADDRESS_WIDTH-1:0] column_mask     = ( {8{1'b1}} << COLUMN_OFFSET );
parameter [ADDRESS_WIDTH-1:0] row_mask        = ( {15{1'b1}} << ROW_OFFSET );

// DRAM timing constraints in CPU clock cycles
// CPU clock - 3.2GHz, DRAM clock - 1.6GHz
parameter T_RC    = 152;      // 76 DRAM Cycles
parameter T_RAS   = 104;      // 52
parameter T_RRD_L = 12;       // 6
parameter T_RRD_S = 8;        // 4
parameter T_RP    = 48;       // 24
parameter T_RFC   = 1120;     // 350ns for a 312.5ps CPU clock period
parameter T_CWD   = 40;       // 20
parameter T_CAS   = 48;       // 24
parameter T_RCD   = 48;       // 24
parameter T_WR    = 40;       // 20
parameter T_RTP   = 24;       // 12
parameter T_CCD_L = 16;       // 8
parameter T_CCD_S = 8;        // 4
parameter T_BURST = 8;        // 4
parameter T_WTR_L = 24;       // 12
parameter T_WTR_S = 8;        // 4
parameter T_REFI  = 24960000; // 7.8us for 312.5ps CPU clock period

endpackage : global_defs

