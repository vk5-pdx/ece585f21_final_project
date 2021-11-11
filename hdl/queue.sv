/****************************************************************
 * queue.sv - queue structure for storing memory requests
 *
 * Author        : Viraj Khatri (vk5@pdx.edu)
 * Last Modified : 9th November, 2021
 *
 * Description   :
 * -----------
 * implementing queue as fifo for checkpoint 3, as no re-ordering
 * of outputs required as of yet.
 ****************************************************************/

import global_defs::*;

module queue #(
	parameter POINTER_SIZE = $clog2(QUEUE_SIZE)+1,     // log_2(n)+1 bits taken to track if the read and write
	                                                   // pointers are in different cycles for full/empty fifos
	parameter BITS_FOR_100 = $clog2(100)
)
(
	// inputs
	input  logic                           CPU_clk, rst_n,
	input  logic                           op_ready_s, // operation ready strobe, new operation available on input
	input  parsed_op_t                     opcode_in,  // opcode from operation
	input  logic       [ADDRESS_WIDTH-1:0] address_in, // address from operation

	// outputs
	output parsed_op_t                     opcode_out,
	output logic       [ADDRESS_WIDTH-1:0] address_out,

	// debugging outputs
	output logic       [POINTER_SIZE-1:0]  read_p_out,
	output logic       [POINTER_SIZE-1:0]  write_p_out,
	output logic       [ADDRESS_WIDTH-1:0] address_queue [QUEUE_SIZE],
	output parsed_op_t                     opcode_queue [QUEUE_SIZE],
	output logic       [BITS_FOR_100-1:0]  counter_queue [QUEUE_SIZE]
);

localparam CALC_POINTER_SIZE = $clog2(QUEUE_SIZE)+1;
generate if(CALC_POINTER_SIZE != POINTER_SIZE)
	$fatal("queue instantiated with wrong pointer size, this is internally calculated, don't specify");
endgenerate

// queue storage
typedef struct {
	logic       [ADDRESS_WIDTH-1:0] address;
	parsed_op_t                     opcode;
	logic       [BITS_FOR_100-1:0]  counter;
	logic                           valid;
} storage_t;

storage_t storage [QUEUE_SIZE];
for (genvar i=0 ; i<QUEUE_SIZE; i++) begin : storage_output_assign
	assign address_queue[i] = storage[i].address;
	assign opcode_queue[i] = storage[i].opcode;
	assign counter_queue[i] = storage[i].counter;
end : storage_output_assign

// read and write pointers for FIFO
logic [POINTER_SIZE-1:0] read_p, write_p;
assign read_p_out = read_p;
assign write_p_out = write_p;

// ff block with decision making for incoming requests
always_ff@(negedge CPU_clk or negedge rst_n) begin
	if (!rst_n) begin
		read_p = '0;
		write_p = '0;
		for (int i=0; i<QUEUE_SIZE; i++) begin
			storage[i].valid = 0;
			storage[i].counter = 0;
		end
	end else begin
		// increment all counter for all valid operations stored in queue
		for (int i=0; i<QUEUE_SIZE; i++) begin
			if (storage[i].valid == 1) storage[i].counter++;
		end

		// what to do when new operation is signalled by strobe
		if (op_ready_s) begin
			if (read_p[POINTER_SIZE-2:0] == write_p[POINTER_SIZE-2:0]
				 && read_p[POINTER_SIZE-1] != write_p[POINTER_SIZE-1]) begin
				// the queue is full, ignore incoming requests
				$display("queue is full, can't accept new input");
				$stop;
			end else begin
				storage[write_p].opcode = opcode_in;
				storage[write_p].address = address_in;
				storage[write_p].valid = 1;
				storage[write_p].counter = 0;

				// move the write pointer
				if (write_p+1 == QUEUE_SIZE-1) begin
					//write_p = write_p & (1 << (POINTER_SIZE-1)); // clearing all bits other than MSB
					//write_p = write_p ^ (1 << (POINTER_SIZE-1)); // toggling MSB
					write_p = { ~write_p[POINTER_SIZE-1], '0}; // toggles MSB and puts count back to 0;
				end else begin
					write_p++;
				end
			end
		end
	end
end

// ff block for evicting 100 CPU_clk cycles old requests
always_ff@(negedge CPU_clk) begin
	for (int i=0; i<QUEUE_SIZE; i++) begin
		// we do not need to check fifo full/empty as valid bit implies that
		// queue has some entries
		if (storage[i].valid == 1 && storage[i].counter == 100) begin
			opcode_out = storage[i].opcode;
			address_out = storage[i].address;
			storage[i].valid = 0;
			storage[i].counter = 0;

			// move the read pointer
			if (read_p+1 == QUEUE_SIZE-1) begin
				//read_p = read_p & (1 << (POINTER_SIZE-1)); // clearing all bits other than MSB
				//read_p = read_p ^ (1 << (POINTER_SIZE-1)); // toggling MSB
				read_p = { ~read_p[POINTER_SIZE-1], '0}; // toggles MSB and puts count back to 0;
			end else begin
				read_p++;
			end
		end
	end
end

endmodule : queue
