module format_score(input [7:0] score,
						  output reg [7:0] formatted);
	always @(*)
	begin
		if (score[3:0] >= 4'b1001) begin
			formatted[3:0] = score[3:0] - 4'b1001;
			formatted = {(score[7:4] + 1), formatted[3:0]};
		end
		else begin
			formatted = score;
		end
	end

endmodule
