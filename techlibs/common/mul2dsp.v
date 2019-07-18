// From Eddie Hung
// extracted from: https://github.com/eddiehung/vtr-with-yosys/blob/vtr7-with-yosys/vtr_flow/misc/yosys_models.v#L220
// revised by Andre DeHon
// further revised by David Shah
`ifndef DSP_A_MAXWIDTH
$error("Macro DSP_A_MAXWIDTH must be defined");
`endif
`ifndef DSP_A_SIGNEDONLY
`define DSP_A_SIGNEDONLY 0
`endif
`ifndef DSP_B_MAXWIDTH
$error("Macro DSP_B_MAXWIDTH must be defined");
`endif
`ifndef DSP_B_SIGNEDONLY
`define DSP_B_SIGNEDONLY 0
`endif

`ifndef DSP_NAME
$error("Macro DSP_NAME must be defined");
`endif

`define MAX(a,b) (a > b ? a : b)
`define MIN(a,b) (a < b ? a : b)

module \$mul (A, B, Y); 
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH-1:0] Y;

	generate
        if (`DSP_A_SIGNEDONLY && `DSP_B_SIGNEDONLY && !A_SIGNED) begin
		wire [1:0] dummy;
		\$mul #(
			.A_SIGNED(1),
			.B_SIGNED(1),
			.A_WIDTH(A_WIDTH + 1),
			.B_WIDTH(B_WIDTH + 1),
			.Y_WIDTH(Y_WIDTH + 2)
		) _TECHMAP_REPLACE_ (
			.A({1'b0, A}),
			.B({1'b0, B}),
			.Y({dummy, Y})
		);
        end
	// NB: A_SIGNED == B_SIGNED == 0 from here
	else if (A_WIDTH >= B_WIDTH)
		\$__mul_gen #(
			.A_SIGNED(A_SIGNED),
			.B_SIGNED(B_SIGNED),
			.A_WIDTH(A_WIDTH),
			.B_WIDTH(B_WIDTH),
			.Y_WIDTH(Y_WIDTH)
		) _TECHMAP_REPLACE_ (
			.A(A),
			.B(B),
			.Y(Y)
		);
	else
		\$__mul_gen #(
			.A_SIGNED(B_SIGNED),
			.B_SIGNED(A_SIGNED),
			.A_WIDTH(B_WIDTH),
			.B_WIDTH(A_WIDTH),
			.Y_WIDTH(Y_WIDTH)
		) _TECHMAP_REPLACE_ (
			.A(B),
			.B(A),
			.Y(Y)
		);
	endgenerate
endmodule

module \$__mul_gen (A, B, Y);
	parameter A_SIGNED = 0;
	parameter B_SIGNED = 0;
	parameter A_WIDTH = 1;
	parameter B_WIDTH = 1;
	parameter Y_WIDTH = 1;

	input [A_WIDTH-1:0] A;
	input [B_WIDTH-1:0] B;
	output [Y_WIDTH-1:0] Y;

	wire [1023:0] _TECHMAP_DO_ = "proc; clean";

	genvar i;
	generate
		if (A_WIDTH > `DSP_A_MAXWIDTH) begin
`ifdef DSP_A_SIGNEDONLY
			localparam sign_headroom = 1;
`else 	
			localparam sign_headroom = 0;
`endif
			localparam n_floored = A_WIDTH/(`DSP_A_MAXWIDTH - sign_headroom);
			localparam n = n_floored + (n_floored*(`DSP_A_MAXWIDTH - sign_headroom) < A_WIDTH ? 1 : 0);
			wire [`DSP_A_MAXWIDTH+B_WIDTH-1:0] partial [n-1:1];
			wire [Y_WIDTH-1:0] partial_sum [n-2:0];
			localparam int_yw = `MIN(Y_WIDTH, B_WIDTH+`DSP_A_MAXWIDTH);

			\$__mul_gen #(
				.A_SIGNED(0),
				.B_SIGNED(B_SIGNED),
				.A_WIDTH(`DSP_A_MAXWIDTH),
				.B_WIDTH(B_WIDTH),
				.Y_WIDTH(int_yw)
			) mul_slice_first (
				.A({{sign_headroom{1'b0}}, A[`DSP_A_MAXWIDTH-sign_headroom-1:0]}),
				.B(B),
				.Y(partial_sum[0][int_yw-1:0])
			);
			if (Y_WIDTH > int_yw)
				assign partial_sum[0][Y_WIDTH-1:int_yw]=0;

			for (i = 1; i < n-1; i=i+1) begin:slice
				\$__mul_gen #(
					.A_SIGNED(0),
					.B_SIGNED(B_SIGNED),
					.A_WIDTH(`DSP_A_MAXWIDTH),
					.B_WIDTH(B_WIDTH),
					.Y_WIDTH(int_yw)
				) mul_slice (
					.A({{sign_headroom{1'b0}}, A[(i+1)*(`DSP_A_MAXWIDTH-sign_headroom)-1:i*(`DSP_A_MAXWIDTH-sign_headroom)]}),
					.B(B),
					.Y(partial[i][int_yw-1:0])
				);
				//assign partial_sum[i] = (partial[i] << i*`DSP_A_MAXWIDTH) + partial_sum[i-1];
				assign partial_sum[i] = {
					partial[i][int_yw-1:0]
					+ partial_sum[i-1][Y_WIDTH-1:(i*(`DSP_A_MAXWIDTH-sign_headroom))],
					partial_sum[i-1][(i*(`DSP_A_MAXWIDTH-sign_headroom))-1:0]
				};
			end

			\$__mul_gen #(
				.A_SIGNED(A_SIGNED),
				.B_SIGNED(B_SIGNED),
				.A_WIDTH(A_WIDTH-(n-1)*(`DSP_A_MAXWIDTH-sign_headroom)),
				.B_WIDTH(B_WIDTH),
				.Y_WIDTH(`MIN(Y_WIDTH, A_WIDTH-(n-1)*(`DSP_A_MAXWIDTH-sign_headroom)+B_WIDTH)),
			) mul_slice_last (
				.A(A[A_WIDTH-1:(n-1)*(`DSP_A_MAXWIDTH-sign_headroom)]),
				.B(B),
				.Y(partial[n-1][`MIN(Y_WIDTH, A_WIDTH-(n-1)*(`DSP_A_MAXWIDTH-sign_headroom)+B_WIDTH)-1:0])
			);
			//assign Y = (partial[n-1] << (n-1)*`DSP_A_MAXWIDTH) + partial_sum[n-2];
			assign Y = {
				partial[n-1][`MIN(Y_WIDTH, A_WIDTH-(n-1)*(`DSP_A_MAXWIDTH-sign_headroom)+B_WIDTH):0]
				+ partial_sum[n-2][Y_WIDTH-1:((n-1)*(`DSP_A_MAXWIDTH-sign_headroom))],
				partial_sum[n-2][((n-1)*(`DSP_A_MAXWIDTH-sign_headroom))-1:0]
			};
		end
		else if (B_WIDTH > `DSP_B_MAXWIDTH) begin
`ifdef DSP_B_SIGNEDONLY
			localparam sign_headroom = 1;
`else 	
			localparam sign_headroom = 0;
`endif
			localparam n_floored = B_WIDTH/(`DSP_B_MAXWIDTH - sign_headroom);
			localparam n = n_floored + (n_floored*(`DSP_B_MAXWIDTH - sign_headroom) < B_WIDTH ? 1 : 0);
			wire [A_WIDTH+`DSP_B_MAXWIDTH-1:0] partial [n-1:1];
			wire [Y_WIDTH-1:0] partial_sum [n-2:0];
			localparam int_yw = `MIN(Y_WIDTH, A_WIDTH+`DSP_B_MAXWIDTH);

			\$__mul_gen #(
				.A_SIGNED(A_SIGNED),
				.B_SIGNED(0),
				.A_WIDTH(A_WIDTH),
				.B_WIDTH(`DSP_B_MAXWIDTH),
				.Y_WIDTH(int_yw)
			) mul_first (
				.A(A),
				.B({{sign_headroom{1'b0}}, B[(`DSP_B_MAXWIDTH - sign_headroom)-1:0]}),
				.Y(partial_sum[0][int_yw-1:0])
			);
			if (Y_WIDTH > int_yw)
				assign partial_sum[0][Y_WIDTH-1:int_yw]=0;

			for (i = 1; i < n-1; i=i+1) begin:slice
				\$__mul_gen #(
					.A_SIGNED(A_SIGNED),
					.B_SIGNED(0),
					.A_WIDTH(A_WIDTH),
					.B_WIDTH(`DSP_B_MAXWIDTH),
					.Y_WIDTH(int_yw)
				) mul (
					.A(A),
					.B({{sign_headroom{1'b0}}, B[(i+1)*(`DSP_B_MAXWIDTH - sign_headroom)-1:i*(`DSP_B_MAXWIDTH - sign_headroom)]}),
					.Y(partial[i][int_yw-1:0])
				);
				//assign partial_sum[i] = (partial[i] << i*`DSP_B_MAXWIDTH) + partial_sum[i-1];
				// was:
				//assign partial_sum[i] = {
				//  partial[i][A_WIDTH+`DSP_B_MAXWIDTH-1:`DSP_B_MAXWIDTH], 
				//	partial[i][`DSP_B_MAXWIDTH-1:0] + partial_sum[i-1][A_WIDTH+(i*`DSP_B_MAXWIDTH)-1:A_WIDTH+((i-1)*`DSP_B_MAXWIDTH)],
				//	partial_sum[i-1][A_WIDTH+((i-1)*`DSP_B_MAXWIDTH):0]
				assign partial_sum[i] = {
					partial[i][int_yw-1:0]
					+ partial_sum[i-1][Y_WIDTH-1:(i*(`DSP_B_MAXWIDTH - sign_headroom))],
					partial_sum[i-1][(i*(`DSP_B_MAXWIDTH - sign_headroom))-1:0] 
				};
			end

			\$__mul_gen #(
				.A_SIGNED(A_SIGNED),
				.B_SIGNED(B_SIGNED),
				.A_WIDTH(A_WIDTH),
				.B_WIDTH(B_WIDTH-(n-1)*(`DSP_B_MAXWIDTH - sign_headroom)),
				.Y_WIDTH(`MIN(Y_WIDTH, A_WIDTH+B_WIDTH-(n-1)*(`DSP_B_MAXWIDTH - sign_headroom)))
			) mul_last (
				.A(A),
				.B(B[B_WIDTH-1:(n-1)*(`DSP_B_MAXWIDTH - sign_headroom)]),
				.Y(partial[n-1][`MIN(Y_WIDTH, A_WIDTH+B_WIDTH-(n-1)*(`DSP_B_MAXWIDTH - sign_headroom))-1:0])
			);
			// AMD: this came comment out -- looks closer to right answer
			//assign Y = (partial[n-1] << (n-1)*`DSP_B_MAXWIDTH) + partial_sum[n-2];
			// was (looks broken)
			//assign Y = {
			//	partial[n-1][A_WIDTH+`DSP_B_MAXWIDTH-1:`DSP_B_MAXWIDTH],
			//	partial[n-1][`DSP_B_MAXWIDTH-1:0] + partial_sum[n-2][A_WIDTH+((n-1)*`DSP_B_MAXWIDTH)-1:A_WIDTH+((n-2)*`DSP_B_MAXWIDTH)],
			//	partial_sum[n-2][A_WIDTH+((n-2)*`DSP_B_MAXWIDTH):0]
			assign Y = {
				partial[n-1][`MIN(Y_WIDTH, A_WIDTH+B_WIDTH-(n-1)*(`DSP_B_MAXWIDTH - sign_headroom))-1:0]
				+ partial_sum[n-2][Y_WIDTH-1:((n-1)*(`DSP_B_MAXWIDTH - sign_headroom))],
				partial_sum[n-2][((n-1)*(`DSP_B_MAXWIDTH - sign_headroom))-1:0]
			};
		end
		else begin 
			wire [A_WIDTH+B_WIDTH-1:0] out;
			wire [(`DSP_A_MAXWIDTH+`DSP_B_MAXWIDTH)-(A_WIDTH+B_WIDTH)-1:0] dummy;
			wire Asign, Bsign;
			assign Asign = (A_SIGNED ? A[A_WIDTH-1] : 1'b0);
			assign Bsign = (B_SIGNED ? B[B_WIDTH-1] : 1'b0);
			`DSP_NAME _TECHMAP_REPLACE_ (
				.A({ {{`DSP_A_MAXWIDTH-A_WIDTH}{Asign}}, A }),
				.B({ {{`DSP_B_MAXWIDTH-B_WIDTH}{Bsign}}, B }),
				.Y({dummy, out})
			);
			if (Y_WIDTH < A_WIDTH+B_WIDTH)
				assign Y = out[Y_WIDTH-1:0];
			else begin
				wire Ysign = (A_SIGNED || B_SIGNED ? out[A_WIDTH+B_WIDTH-1] : 1'b0);
				assign Y = { {{Y_WIDTH-(A_WIDTH+B_WIDTH)}{Ysign}}, out[A_WIDTH+B_WIDTH-1:0] };
			end
		end
	endgenerate
endmodule

