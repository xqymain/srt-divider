module compressor_3_2 #(
	parameter WIDTH = 16
)(
	input  [WIDTH-1:0] x1,
	input  [WIDTH-1:0] x2,
	input  [WIDTH-1:0] x3,
	
	output [WIDTH-1:0] sum_o,
	output [WIDTH-1:0] carry_o
);

assign sum_o = x1 ^ x2 ^ x3;
assign carry_o = {(x1[WIDTH-2:0] & x2[WIDTH-2:0]) | (x1[WIDTH-2:0] & x3[WIDTH-2:0]) | (x2[WIDTH-2:0] & x3[WIDTH-2:0]), 1'b0};

endmodule
