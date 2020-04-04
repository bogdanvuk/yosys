module top;
  typedef struct packed {
    logic [7:0]  b;
    logic [7:0]  a;
  } s0;

	s0 s0_s = 16'haa55;

	always @(*) assert(s0_s.a == 8'h55);
	always @(*) assert(s0_s.b == 8'haa);

  typedef struct packed {
    s0           s0_f;
    logic [4:0]  c;
  } s1;

	s1 s1_s = {{8'h22, 8'h11}, 5'h3};

	always @(*) assert(s1_s.s0_f.a == 8'h11);
	always @(*) assert(s1_s.s0_f.b == 8'h22);
	always @(*) assert(s1_s.s0_f == {8'h22, 8'h11});
	always @(*) assert(s1_s.c == 5'h3);

  typedef struct packed {
    s1           s1_f;
    s0           s0_f;
		logic 			 d;
  } s2;

	s2 s2_s = {{8'h44, 8'h33, 5'h3}, {8'h22, 8'h11}, 1'b1};

	always @(*) assert(s2_s.d == 1'b1);

	always @(*) assert(s2_s.s0_f.a == 8'h11);
	always @(*) assert(s2_s.s0_f.b == 8'h22);

	always @(*) assert(s2_s.s1_f.c == 5'h3);
	always @(*) assert(s2_s.s1_f.s0_f.a == 8'h33);
	always @(*) assert(s2_s.s1_f.s0_f.b == 8'h44);

endmodule
