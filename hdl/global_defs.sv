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

parameter ADDRESS_WIDTH = 32;
parameter QUEUE_SIZE = 16;


parameter BITS_FOR_100 = $clog2(100);
typedef age_counter_t logic[BITS_FOR_100-1:0];

// 3 possible opcodes present in file + NOP extra
typedef enum logic[1:0] {
	DATA_READ = 0,  // 0 = read
	DATA_WRITE,     // 1 = write
	OPCODE_FETCH,   // 2 = opcode fetch
	NOP             // 3 = No OPeration instruction
	                // a bus under reset or an uninitialized bus will have NOP
} parsed_op_t;

// parser module states
typedef enum logic {
	WAITE,  // waiting for empty spot in queue
	NEW_OP, // read and outputting new operation
} parser_states_t;

// output from parser
typedef struct packed {

	logic                            op_ready_s; // strobe signal to mark new output
	parsed_op_t                      opcode;     // opcode of operation
	logic        [ADDRESS_WIDTH-1:0] address;    // address of operation
	int unsigned                     time_cpu;   // cpu clock count for operation issue

} parser_out_struct_t;


endpackage : global_defs

