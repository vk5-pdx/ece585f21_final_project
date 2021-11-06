// Code your testbench here
// or browse Examples
//`include "fifo.v"
module fifo_tb;
parameter DEPTH=64;
parameter WIDTH=8;
parameter PTR_WIDTH=6;

reg clk, rst, wr_en, rd_en;
reg [WIDTH-1:0] wdata;
wire [WIDTH-1:0] rdata;
wire full, empty, error, wr_tog, rd_tog;

reg [WIDTH-1:0]mem[DEPTH-1:0];
reg [PTR_WIDTH-1:0] wr_ptr, rd_ptr;
integer i;
reg[30*8:0] testcase;

fifo dut(clk, rst, wr_en, rd_en, wdata, rdata, full, empty, wr_tog, rd_tog, error);

initial begin
	clk=0;
	forever #5 clk=~clk;
end

initial begin
	rst=1;
	#15; 
  	rst=0;
	$value$plusargs("testcase=%s", testcase);

	case(testcase)
		"empty": begin
			fifo_write(32);
			fifo_read(32);
		end
		"full": begin
			fifo_write(DEPTH);
		end
		"empty_error": begin
			fifo_write(15);
			fifo_read(20);
		end
		"full_error": begin
			fifo_write(DEPTH+1);
		end
		"concurrent_wr_rd": begin
			fork
				fifo_write(32);
				fifo_read(32);
			join
		end

	endcase
end

  task fifo_write( input integer number);
begin
	for(i=0; i<number; i=i+1) begin
		@(posedge clk)
		wr_en=1;
		wdata=$random;
	end
	@(posedge clk)
	wr_en=0;
	wdata=0;
end
endtask

  task fifo_read( input integer number);
begin
	for(i=0; i<number; i=i+1) begin
		@(posedge clk)
		rd_en=1;
	end
	@(posedge clk)
	rd_en=0;
end
endtask

initial begin
	#2000;
	$finish;
end

initial begin
	$dumpfile("test.vcd");
	$dumpvars;
end
endmodule