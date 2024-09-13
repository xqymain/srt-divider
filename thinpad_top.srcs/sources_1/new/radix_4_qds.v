module radix_4_qds_v1 #(
	parameter WIDTH = 32,
	// ATTENTION: Don't change the below paras !!!
	parameter ITN_WIDTH = 1 + WIDTH + 2 + 1,
	parameter QUOT_ONEHOT_WIDTH = 5
)(
	input  wire [ITN_WIDTH-1:0] rem_sum_i,
	input  wire [ITN_WIDTH-1:0] rem_carry_i,
	input  wire [WIDTH-1:0] divisor_i,
	input  wire [4:0] qds_para_neg_1_i,
	input  wire [2:0] qds_para_neg_0_i,
	input  wire [1:0] qds_para_pos_1_i,
	input  wire [4:0] qds_para_pos_2_i,
	input  wire special_divisor_i,
	input  wire [QUOT_ONEHOT_WIDTH-1:0] prev_quot_digit_i,
	output wire [QUOT_ONEHOT_WIDTH-1:0] quot_digit_o
);

// ================================================================================================================================================
// (local) parameters begin

localparam QUOT_NEG_2 = 0;
localparam QUOT_NEG_1 = 1;
localparam QUOT_ZERO  = 2;
localparam QUOT_POS_1 = 3;
localparam QUOT_POS_2 = 4;

// (local) parameters end
// ================================================================================================================================================

// ================================================================================================================================================
// signals begin

wire [(ITN_WIDTH + 4)-1:0] rem_sum_mul_16;
wire [(ITN_WIDTH + 4)-1:0] rem_carry_mul_16;
wire [6:0] rem_sum_mul_16_trunc_2_5;
wire [6:0] rem_carry_mul_16_trunc_2_5;
wire [6:0] rem_sum_mul_16_trunc_3_4;
wire [6:0] rem_carry_mul_16_trunc_3_4;

wire [6:0] para_m_neg_1_trunc_2_5;
wire [6:0] para_m_neg_0_trunc_3_4;
wire [6:0] para_m_pos_1_trunc_3_4;
wire [6:0] para_m_pos_2_trunc_2_5;

wire [ITN_WIDTH-1:0] divisor;
wire [(ITN_WIDTH + 2)-1:0] divisor_mul_4;
wire [(ITN_WIDTH + 2)-1:0] divisor_mul_8;
wire [(ITN_WIDTH + 2)-1:0] divisor_mul_neg_4;
wire [(ITN_WIDTH + 2)-1:0] divisor_mul_neg_8;
wire [6:0] divisor_mul_4_trunc_2_5;
wire [6:0] divisor_mul_4_trunc_3_4;
wire [6:0] divisor_mul_8_trunc_2_5;
wire [6:0] divisor_mul_8_trunc_3_4;
wire [6:0] divisor_mul_neg_4_trunc_2_5;
wire [6:0] divisor_mul_neg_4_trunc_3_4;
wire [6:0] divisor_mul_neg_8_trunc_2_5;
wire [6:0] divisor_mul_neg_8_trunc_3_4;
wire [6:0] divisor_for_sd_trunc_3_4;
wire [6:0] divisor_for_sd_trunc_2_5;

wire sd_m_neg_1_sign;
wire sd_m_neg_0_sign;
wire sd_m_pos_1_sign;
wire sd_m_pos_2_sign;

// signals end
// ================================================================================================================================================

// After "16 * " operation, the decimal point is still between "[ITN_WIDTH-1]" and "[ITN_WIDTH-2]".
assign rem_sum_mul_16 = {rem_sum_i, 4'b0};
assign rem_carry_mul_16 = {rem_carry_i, 4'b0};

assign rem_sum_mul_16_trunc_2_5 = rem_sum_mul_16[(ITN_WIDTH    ) -: 7];
assign rem_sum_mul_16_trunc_3_4 = rem_sum_mul_16[(ITN_WIDTH + 1) -: 7];
assign rem_carry_mul_16_trunc_2_5 = rem_carry_mul_16[(ITN_WIDTH    ) -: 7];
assign rem_carry_mul_16_trunc_3_4 = rem_carry_mul_16[(ITN_WIDTH + 1) -: 7];

// ================================================================================================================================================
// Calculate the parameters for CMP.
// ================================================================================================================================================
assign para_m_neg_1_trunc_2_5 = {1'b0, qds_para_neg_1_i, 1'b0};
assign para_m_neg_0_trunc_3_4 = {3'b0, qds_para_neg_0_i, special_divisor_i};
assign para_m_pos_1_trunc_3_4 = {4'b1111, qds_para_pos_1_i, special_divisor_i};
assign para_m_pos_2_trunc_2_5 = {1'b1, qds_para_pos_2_i, 1'b0};

// ================================================================================================================================================
// Calculate "-4 * q * D" for CMP.
// ================================================================================================================================================
assign divisor = {1'b0, divisor_i, 3'b0};
assign divisor_mul_4 = {divisor, 2'b0};
assign divisor_mul_8 = {divisor[ITN_WIDTH-2:0], 3'b0};
assign divisor_mul_neg_4 = ~{divisor, 2'b0};
assign divisor_mul_neg_8 = ~{divisor[ITN_WIDTH-2:0], 1'b0, 2'b0};

// The decimal point is between "[ITN_WIDTH-1]" and "[ITN_WIDTH-2]".
assign divisor_mul_4_trunc_2_5 = divisor_mul_4[(ITN_WIDTH    ) -: 7];
assign divisor_mul_4_trunc_3_4 = divisor_mul_4[(ITN_WIDTH + 1) -: 7];
assign divisor_mul_8_trunc_2_5 = divisor_mul_8[(ITN_WIDTH    ) -: 7];
assign divisor_mul_8_trunc_3_4 = divisor_mul_8[(ITN_WIDTH + 1) -: 7];
assign divisor_mul_neg_4_trunc_2_5 = divisor_mul_neg_4[(ITN_WIDTH    ) -: 7];
assign divisor_mul_neg_4_trunc_3_4 = divisor_mul_neg_4[(ITN_WIDTH + 1) -: 7];
assign divisor_mul_neg_8_trunc_2_5 = divisor_mul_neg_8[(ITN_WIDTH    ) -: 7];
assign divisor_mul_neg_8_trunc_3_4 = divisor_mul_neg_8[(ITN_WIDTH + 1) -: 7];

// sd = Sign Detector
assign divisor_for_sd_trunc_2_5 = 
  ({(7){prev_quot_digit_i[QUOT_NEG_2]}} & divisor_mul_8_trunc_2_5)
| ({(7){prev_quot_digit_i[QUOT_NEG_1]}} & divisor_mul_4_trunc_2_5)
| ({(7){prev_quot_digit_i[QUOT_POS_1]}} & divisor_mul_neg_4_trunc_2_5)
| ({(7){prev_quot_digit_i[QUOT_POS_2]}} & divisor_mul_neg_8_trunc_2_5);

assign divisor_for_sd_trunc_3_4 = 
  ({(7){prev_quot_digit_i[QUOT_NEG_2]}} & divisor_mul_8_trunc_3_4)
| ({(7){prev_quot_digit_i[QUOT_NEG_1]}} & divisor_mul_4_trunc_3_4)
| ({(7){prev_quot_digit_i[QUOT_POS_1]}} & divisor_mul_neg_4_trunc_3_4)
| ({(7){prev_quot_digit_i[QUOT_POS_2]}} & divisor_mul_neg_8_trunc_3_4);

// ================================================================================================================================================
// Calculate sign and code the res.
// ================================================================================================================================================
radix_4_sign_detector
u_sd_m_neg_1 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_2_5),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_2_5),
	.parameter_i(para_m_neg_1_trunc_2_5),
	.divisor_i(divisor_for_sd_trunc_2_5),
	.sign_o(sd_m_neg_1_sign)
);
radix_4_sign_detector
u_sd_m_neg_0 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_3_4),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_3_4),
	.parameter_i(para_m_neg_0_trunc_3_4),
	.divisor_i(divisor_for_sd_trunc_3_4),
	.sign_o(sd_m_neg_0_sign)
);
radix_4_sign_detector
u_sd_m_pos_1 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_3_4),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_3_4),
	.parameter_i(para_m_pos_1_trunc_3_4),
	.divisor_i(divisor_for_sd_trunc_3_4),
	.sign_o(sd_m_pos_1_sign)
);
radix_4_sign_detector
u_sd_m_pos_2 (
	.rem_sum_msb_i(rem_sum_mul_16_trunc_2_5),
	.rem_carry_msb_i(rem_carry_mul_16_trunc_2_5),
	.parameter_i(para_m_pos_2_trunc_2_5),
	.divisor_i(divisor_for_sd_trunc_2_5),
	.sign_o(sd_m_pos_2_sign)
);

radix_4_sign_coder
u_sign_coder (
	.sd_m_neg_1_sign_i(sd_m_neg_1_sign),
	.sd_m_neg_0_sign_i(sd_m_neg_0_sign),
	.sd_m_pos_1_sign_i(sd_m_pos_1_sign),
	.sd_m_pos_2_sign_i(sd_m_pos_2_sign),
	.quot_o(quot_digit_o)
);

endmodule
