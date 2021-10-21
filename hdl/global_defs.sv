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
	READING,     // reading from file
	NEW_OP       // if clock count matches entry from trace file, output stuff from parser
	             // otherwise wait in this state and keep counting
} parser_states_t;

endpackage : global_defs
