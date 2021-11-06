// Code your design here
module fifo(clk, rst, wr_en, rd_en, wdata, rdata, full, empty, wr_tog, rd_tog, error);
parameter DEPTH=64;
parameter WIDTH=8;
parameter PTR_WIDTH=6;

input clk, rst, wr_en, rd_en;
input [WIDTH-1:0] wdata;
output reg [WIDTH-1:0] rdata;
output reg full, empty, error, wr_tog, rd_tog;

reg [WIDTH-1:0]mem[DEPTH-1:0];
reg [PTR_WIDTH-1:0] wr_ptr, rd_ptr;
integer i;

always@(posedge clk) begin
	if(rst) begin
		rdata=0;
		full=0;
		empty=1;
		error=0;
		wr_tog=0;
		rd_tog=0;
		wr_ptr=6'b000000;
		rd_ptr=6'b000000;
		for( i=0; i<DEPTH; i=i+1)
			mem[i]=0;
	end

	else begin
		error=0;
		if(wr_en) begin
			if(full)
				error=1;
				else begin
					mem[wr_ptr]=wdata;
					if(wr_ptr==DEPTH-1) begin
						wr_tog=~wr_tog;
					end
					wr_ptr=wr_ptr+1;
				end

		end
		
		if(rd_en) begin
			if(empty)
				error=1;
				else begin
					rdata=mem[rd_ptr];
					if(rd_ptr==DEPTH-1) begin
						rd_tog=~rd_tog;
					end
					rd_ptr=rd_ptr+1;
				end
			end
		end

	end

	always@(wr_ptr or rd_ptr) begin
		empty=0;
		full=0;
		if(wr_ptr==rd_ptr && wr_tog==rd_tog)
			empty=1;
			if(wr_ptr==rd_ptr && wr_tog!=rd_tog)
				full=1;
	end
endmodule