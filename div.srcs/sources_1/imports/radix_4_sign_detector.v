module radix_4_sign_detector (
    input  wire [7-1:0] rem_sum_msb_i,
    input  wire [7-1:0] rem_carry_msb_i,
    input  wire [7-1:0] parameter_i,
    input  wire [7-1:0] divisor_i,
    
    output reg sign_o
);

reg [6-1:0] unused_bit;

always @(*) begin
    {sign_o, unused_bit} = rem_sum_msb_i + rem_carry_msb_i + parameter_i + divisor_i;
end

endmodule
