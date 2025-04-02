// 3-to-2 Compressor Module

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

// Compute the carry:
// 1. Perform bitwise AND between each pair of inputs for bits [WIDTH-2:0]
// 2. Combine the results with bitwise OR to determine carry generation
// 3. Shift the carry left by one bit by concatenating a '0' at the LSB
assign carry_o = {
    (x1[WIDTH-2:0] & x2[WIDTH-2:0]) | 
    (x1[WIDTH-2:0] & x3[WIDTH-2:0]) | 
    (x2[WIDTH-2:0] & x3[WIDTH-2:0]), 
    1'b0 // Least Significant Bit is set to '0' after shifting
};

endmodule
