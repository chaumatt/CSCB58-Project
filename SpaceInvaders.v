module SpaceInvaders(CLOCK_50,
					SW,
					KEY,
					HEX0,
					HEX1,
					HEX4,
					HEX5,
					LEDR,
					// The parts below are for the VGA output.  Do not change.
					VGA_CLK,   						//	VGA Clock
					VGA_HS,							//	VGA H_SYNC
					VGA_VS,							//	VGA V_SYNC
					VGA_BLANK_N,						//	VGA BLANK
					VGA_SYNC_N,						//	VGA SYNC
					VGA_R,   						//	VGA Red[9:0]
					VGA_G,	 						//	VGA Green[9:0]
					VGA_B					//	VGA Blue[9:0]
		);
	// KEY[0] reset to the same level
	// KEY[1] moves right
	// KEY[2] moves left
	// KEY[3] fires bullet
	// KEY[0] + KEY[1] together resets to level 0 (speed level)
	
	// SW[0] controls if alien can fire / freezes alien fire
	// SW[1] instantly go to WIN state
	
	input CLOCK_50;
	// used for control
	input [1:0] SW;
	input [3:0] KEY;
	
	// outputs Hex (for score)
	output [6:0] HEX0;
	output [6:0] HEX1;
	output [6:0] HEX4;
	output [6:0] HEX5;
	
	// output for debugging
	output [17:0] LEDR;
	
	// outputs for VGA
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	
	// Create the colour, x, y wires that are inputs to the controller.
	reg [2:0] colour;
	reg [7:0] x;
	reg [7:0] y;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(1'b1),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(1'b1),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
	
	// coordinates for player, bullet, and the aliens, and alien bullet
	reg [7:0] p_x;
	reg [7:0] p_y;
	reg [7:0] bullet_x;
	reg [7:0] bullet_y;
	reg [7:0] A_bullet_x;
	reg [7:0] A_bullet_y;
	reg [7:0] A1alien_x;
	reg [7:0] A1alien_y;
	reg [7:0] A2alien_x;
	reg [7:0] A2alien_y;
	reg [7:0] A3alien_x;
	reg [7:0] A3alien_y;
	reg [7:0] A4alien_x;
	reg [7:0] A4alien_y;
	
	// track alien death. (1 for alive, 0 dead)
	reg A1;
	reg A2;
	reg A3;
	reg A4;
	// bitmap for the alien's design
	reg [127:0] alien_bitmap;
	
	// tracking current state
	reg [6:0] current_state;
	// counter for drawing shapes
	reg [17:0] draw_count;
	// mark if aliens are moving right or left (1'b1 is moving right, 1'b0 moving left) 
	reg alien1_right;
	reg alien2_right;
	reg alien3_right;
	reg alien4_right;
	// mark if bullet has been fired  (1'b1 when fired) 
	reg is_fired;
	reg a_fired;
	
	// x_rate 
	reg [2:0] x_rate;
	
	// score on HEX0, HEX1
	reg [7:0] score;
	wire [7:0] formatted_score;
	// high score on HEX4, HEX5
	reg [7:0] high_score;
	wire [7:0] formatted_high;
	
	// debugging led
	reg led0, led1, led2, led3;
	assign LEDR[0] = led0;
	assign LEDR[3] = led3;
	assign LEDR[1] = led1;
	assign LEDR[2] = led2;
	
	// format the score from binary to hex display
	format_score fc(.score(score),
						 .formatted(formatted_score));
	hex_display h0(.IN(formatted_score[3:0]),
						.OUT(HEX0));
	hex_display h1(.IN(formatted_score[7:4]),
						.OUT(HEX1));
	format_score fc1(.score(high_score),
						 .formatted(formatted_high));
	hex_display h4(.IN(formatted_high[3:0]),
						.OUT(HEX4));
	hex_display h5(.IN(formatted_high[7:4]),
						.OUT(HEX5));

	
	/***************************************
	FSM and datapath begins
	****************************************/
	localparam  RESET_BLACK 	= 7'd30,
				INIT_PLAYER 	= 7'd1,
				INIT_BULLET		= 7'd2,
				INIT_A1 		= 7'd3,
				INIT_A2 = 7'd17,
				INIT_A3 = 7'd18,
				INIT_A4 = 7'd19,
				WAIT			= 7'd4,

				ERASE_PLAYER 	= 7'd5,
				UPDATE_PLAYER 	= 7'd6,
				DRAW_PLAYER 	= 7'd7,
				ERASE_BULLET 	= 7'd8,
				UPDATE_BULLET 	= 7'd9,
				DRAW_BULLET 	= 7'd10,

				ERASE_A1 		= 7'd11,
				UPDATE_A1 		= 7'd12,
				DRAW_A1			= 7'd13,
				ERASE_A2 		= 7'd20,
				UPDATE_A2 		= 7'd21,
				DRAW_A2			= 7'd22,
				ERASE_A3 		= 7'd23,
				UPDATE_A3 		= 7'd24,
				DRAW_A3			= 7'd25,
				ERASE_A4 		= 7'd26,
				UPDATE_A4 		= 7'd27,
				DRAW_A4			= 7'd28,

				LOSE			   = 7'd14,
				TEST_HIT			= 7'd15,
				DRAW_LINE		= 7'd16,
				WIN 				= 7'd29,
				SET_X 			= 7'd34,
				LVL_UP 			= 7'd31,
				UPDATE_SCORE 	= 7'd32,
				UPDATE_HIGHEST = 7'd33,
				INITIAL_HIGH 	= 7'd0,
				INIT_A_BULLET 	= 7'd35,
				ERASE_A_BULLET = 7'd36,
				UPDATE_A_BULLET = 7'd37,
				DRAW_A_BULLET 	= 7'd38,
				TEST_A_HIT 		= 7'd39;
	
	// rate divider, delay before redraw
	wire frame;
	frame_counter(.clock(CLOCK_50), .go(frame));
	
	always @(posedge CLOCK_50)
	begin
		// set initial values
		colour = 3'b000;
		x = 8'b00000000;
		y = 8'b00000000;
		
		// when receive reset signal, reset to current level
		if (~KEY[0])
			current_state = RESET_BLACK;
		// reset level to 0
		if (~KEY[0] & ~KEY[1])
			current_state = SET_X;
		// cheat to win
		if (SW[1])
			current_state = WIN;
		
		case(current_state)
			INITIAL_HIGH: begin
				// set the initial high score 0
				high_score = 8'b0;
				current_state = SET_X;
			end
			SET_X: begin
				// set the inital score and level/movement rate
				x_rate = 3'b000;
				score = 8'b0;
				current_state = RESET_BLACK;
			end
			RESET_BLACK: begin
				// reset the screen by making it all black
				if (draw_count < 17'b1000_0000_0000_0000_0) begin
					x = draw_count[7:0];
					y = draw_count[15:8];
					draw_count = draw_count + 1'b1;
					led0 = 1'b0;
					led1 = 1'b0;
					led2 = 1'b0;
					end
				else begin
					draw_count= 18'b0;
					current_state = DRAW_LINE;
					end
				end
			DRAW_LINE: begin
				// draw the end line
				if (draw_count < 9'b1000_0000_0) begin
					colour = 3'b011;
					x = draw_count[7:0];
					y = 8'd108;
					draw_count = draw_count + 1'b1;
					end
				else begin
					draw_count= 18'b0;
					current_state = INIT_PLAYER;
					end
				end
			INIT_PLAYER: begin
				// initialize the player
				if (draw_count < 8'b1000_0000) begin
					p_x = 8'd76;
					p_y = 8'd110;
					x = p_x + draw_count[3:0];
					y = p_y + draw_count[6:4];
					draw_count = draw_count + 1'b1;
					colour = 3'b111;
					end
				else begin
					draw_count= 18'b0;
					current_state = INIT_BULLET;
					end
				end
			INIT_BULLET: begin
				// initialize the bullet
				bullet_x = 8'd80;
				bullet_y = 8'd108;
				x = bullet_x;
				y = bullet_y;
				colour = 3'b011;
				led3 = 1'b1;
				is_fired = 1'b0;
				current_state = INIT_A1;
				end
			INIT_A1: begin
				// init alien A1
				if (draw_count < 8'b1000_0000) begin
					A1alien_x = 8'd0;
					A1alien_y = 8'd0;
					x = A1alien_x + draw_count[3:0];
					y = A1alien_y + draw_count[6:4];
					draw_count = draw_count + 1'b1;
					colour = 3'b101;
					// start aliens moving right
					alien1_right = 1'b1;
					led2 = 1'b1;
					A1 = 1'b1;
					end
				else begin
					draw_count= 18'b0;
					if (SW[0])
						// if switch enabled, let alien fire
						current_state = INIT_A_BULLET;
					else
						current_state = INIT_A2;
					end
				end
			INIT_A_BULLET: begin
				// initialize the alien bullet
				A_bullet_x = 8'd8;
				A_bullet_y = 8'd9;
				x = A_bullet_x;
				y = A_bullet_y;
				colour = 3'b100;
				a_fired = 1'b1;
				current_state = INIT_A2;
			end
			INIT_A2: begin
				// init alien A2
				if (draw_count < 8'b1000_0000) begin
					A2alien_x = 8'd30;
					A2alien_y = 8'd0;
					x = A2alien_x + draw_count[3:0];
					y = A2alien_y + draw_count[6:4];
					draw_count = draw_count + 1'b1;
					colour = 3'b101;
					// start aliens moving right
					alien2_right = 1'b1;
					A2 = 1'b1;
					end
				else begin
					draw_count= 18'b0;
					current_state = INIT_A3;
					end
				end
			INIT_A3: begin
				// init alien A3
				if (draw_count < 8'b1000_0000) begin
					A3alien_x = 8'd60;
					A3alien_y = 8'd0;
					x = A3alien_x + draw_count[3:0];
					y = A3alien_y + draw_count[6:4];
					draw_count = draw_count + 1'b1;
					colour = 3'b101;
					// start aliens moving right
					alien3_right = 1'b1;
					A3 = 1'b1;
					end
				else begin
					draw_count= 18'b0;
					current_state = INIT_A4;
				end
				end
			INIT_A4: begin
				// init alien A4
				if (draw_count < 8'b1000_0000) begin
					A4alien_x = 8'd90;
					A4alien_y = 8'd0;
					x = A4alien_x + draw_count[3:0];
					y = A4alien_y + draw_count[6:4];
					draw_count = draw_count + 1'b1;
					colour = 3'b101;
					// start aliens moving right
					alien4_right = 1'b1;
					A4 = 1'b1;
					end
				else begin
					draw_count= 18'b0;
					current_state = WAIT;
					end
				end
			
			WAIT: begin
				// wait a frame
				if (frame)
					current_state = ERASE_PLAYER;
				end
				
			
			ERASE_PLAYER: begin
				// remove the player from screen
				if (draw_count < 8'b1000_0000) begin
					x = p_x + draw_count[3:0];
					y = p_y + draw_count[6:4];
					draw_count = draw_count + 1'b1;
					colour = 3'b000;
					end
				else begin
					draw_count= 18'b0;
					current_state = UPDATE_PLAYER;
					end
				end
			UPDATE_PLAYER: begin
				// update new player position
				// make sure that player can't move further past the left or right of the screen
				if (~KEY[1] && p_x < 8'd144) begin
					p_x = p_x + 1'b1;
					if (is_fired == 1'b0) begin
						bullet_x = bullet_x + 1;
						end
					end
				if (~KEY[2] && p_x > 8'd0) begin
					p_x = p_x - 1'b1;
					if (is_fired == 1'b0) begin
						bullet_x = bullet_x - 1;
						end
					end
				current_state = DRAW_PLAYER;
				end
			DRAW_PLAYER: begin
				if (draw_count < 8'b1000_0000) begin
					x = p_x + draw_count[3:0];
					y = p_y + draw_count[6:4];
					draw_count = draw_count + 1'b1;
					colour = 3'b111;
					end					
				else begin
					draw_count= 18'b0;
					current_state = ERASE_A1;
					end
				end
			/* ALIEN A1
			 */
			ERASE_A1: begin
				if (draw_count < 8'b1000_0000) begin
					x = A1alien_x + draw_count[3:0];
					y = A1alien_y + draw_count[6:4];
					draw_count = draw_count + 1'b1;
					colour = 3'b000;
					end
				else begin
					draw_count= 18'b0;
					current_state = UPDATE_A1;
					end
				end
			UPDATE_A1: begin
					// update new alien position
					// make sure that alien can't move further past the left or right of the screen
					// check if reached edge of left and right
					if (A1alien_x >= 8'd144) begin
						alien1_right = 1'b0;
						A1alien_x = 8'd144;
						A1alien_y = A1alien_y + 8;
						end
					else if ((A1alien_x <= 8'd0) && (A1alien_y != 8'd0)) begin
						alien1_right = 1'b1;
						A1alien_x = 8'd0;
						A1alien_y = A1alien_y + 8;
						end
					
					// update alien x position
					if (alien1_right == 1'b1) begin
						A1alien_x = A1alien_x + 1'b1 + x_rate;
						end
					else begin
						A1alien_x = A1alien_x - 1'b1 - x_rate;
						end
					
					
				if (A1 == 1'b1) begin
					// if alien is alive, draw it
					current_state = DRAW_A1;
				end
				else begin
					// alien is dead, erase
					current_state = ERASE_A2;
				end
				
				if ((A1 == 1'b1) && (A1alien_y + 3'd7 >= p_y))begin
						// alien reached bottom
						current_state = UPDATE_SCORE;
						end
				end
			DRAW_A1: begin
				if (draw_count < 8'b1000_0000) begin
					x = A1alien_x + draw_count[3:0];
					y = A1alien_y + draw_count[6:4];
					draw_count = draw_count + 1'b1;
					colour = 3'b101;
					led1 = 1'b1;
					end					
				else begin
					
					draw_count= 18'b0;
					current_state = ERASE_A2;
					end
				end
			/* ALIEN A2
			 */
			ERASE_A2: begin
				if (draw_count < 8'b1000_0000) begin
					x = A2alien_x + draw_count[3:0];
					y = A2alien_y + draw_count[6:4];
					draw_count = draw_count + 1'b1;
					colour = 3'b000;
					end
				else begin
					draw_count= 18'b0;
					current_state = UPDATE_A2;
					end
				end
			UPDATE_A2: begin
					// update new alien position
					// make sure that alien can't move further past the left or right of the screen
					
					// check if reached edge of left and right
					if (A2alien_x >= 8'd144) begin
						alien2_right = 1'b0;
						A2alien_x = 8'd144;
						A2alien_y = A2alien_y + 8;
						end
					else if ((A2alien_x <= 8'd0) && (A2alien_y != 8'd0)) begin
						alien2_right = 1'b1;
						A2alien_x = 8'd0;
						A2alien_y = A2alien_y + 8;
						end
					// update alien x
					if (alien2_right == 1'b1) begin
						A2alien_x = A2alien_x + 1'b1 + x_rate;
						end
					else begin
						A2alien_x = A2alien_x - 1'b1 - x_rate;
						end
				if (A2 == 1'b1) begin
					// if alive, draw
					current_state = DRAW_A2;
				end
				else begin
					// dead, go to next alien
					current_state = ERASE_A3;
				end
				
				if ((A2 == 1'b1) && (A2alien_y + 3'd7 >= p_y))begin
						// alien reached bottom, LOSE
						current_state = UPDATE_SCORE;
						end
				
				end
			DRAW_A2: begin
				if (draw_count < 8'b1000_0000) begin
					x = A2alien_x + draw_count[3:0];
					y = A2alien_y + draw_count[6:4];
					draw_count = draw_count + 1'b1;
					colour = 3'b101;
					end					
				else begin
					
					draw_count= 18'b0;
					current_state = ERASE_A3;
					end
				end
			/* ALIEN A3
			 */
			ERASE_A3: begin
				if (draw_count < 8'b1000_0000) begin
					x = A3alien_x + draw_count[3:0];
					y = A3alien_y + draw_count[6:4];
					draw_count = draw_count + 1'b1;
					colour = 3'b000;
					end
				else begin
					draw_count= 18'b0;
					current_state = UPDATE_A3;
					end
				end
			UPDATE_A3: begin
					// update new alien position
					// make sure that alien can't move further past the left or right of the screen
					// check if reached edge of left and right
					if (A3alien_x >= 8'd144) begin
						alien3_right = 1'b0;
						A3alien_x = 8'd144;
						A3alien_y = A3alien_y + 8;
						end
					else if ((A3alien_x <= 8'd0) && (A3alien_y != 8'd0)) begin
						alien3_right = 1'b1;
						A3alien_x = 8'd0;
						A3alien_y = A3alien_y + 8;
						end
					// update alien x position
					if (alien3_right == 1'b1) begin
						A3alien_x = A3alien_x + 1'b1 + x_rate;
						end
					else begin
						A3alien_x = A3alien_x - 1'b1 - x_rate;
						end
				
				if (A3 == 1'b1) begin
					// if alive, draw
					current_state = DRAW_A3;
				end
				else begin
					// dead, go to next alien
					current_state = ERASE_A4;
				end
				
				if ((A3 == 1'b1) && (A3alien_y + 3'd7 >= p_y))begin
						// alien reached bottom, LOSE
						current_state = UPDATE_SCORE;
						end
				end
			DRAW_A3: begin
				if (draw_count < 8'b1000_0000) begin
					x = A3alien_x + draw_count[3:0];
					y = A3alien_y + draw_count[6:4];
					draw_count = draw_count + 1'b1;
					colour = 3'b101;
					end					
				else begin
					
					draw_count= 18'b0;
					current_state = ERASE_A4;
					end
				end
			/* ALIEN A4
			 */
			ERASE_A4: begin
				if (draw_count < 8'b1000_0000) begin
					x = A4alien_x + draw_count[3:0];
					y = A4alien_y + draw_count[6:4];
					draw_count = draw_count + 1'b1;
					colour = 3'b000;
					end
				else begin
					draw_count= 18'b0;
					current_state = UPDATE_A4;
					end
				end
			UPDATE_A4: begin
					// update new alien position
					// make sure that alien can't move further past the left or right of the screen
					// check if reached edge of left and right
					if (A4alien_x >= 8'd144) begin
						alien4_right = 1'b0;
						A4alien_x = 8'd144;
						A4alien_y = A4alien_y + 8;
						end
					else if ((A4alien_x <= 8'd0) && (A4alien_y != 8'd0)) begin
						alien4_right = 1'b1;
						A4alien_x = 8'd0;
						A4alien_y = A4alien_y + 8;
						end
					// update x
					if (alien4_right == 1'b1) begin
						A4alien_x = A4alien_x + 1'b1 + x_rate;
						end
					else begin
						A4alien_x = A4alien_x - 1'b1 - x_rate;
						end

				if (A4 == 1'b1) begin
					// if alive, draw
					current_state = DRAW_A4;
				end
				else begin
					// dead, move to next state
					current_state = ERASE_BULLET;
				end
				
				if ((A4 == 1'b1) && (A4alien_y + 3'd7 >= p_y))begin
						// alien reached bottom, LOSE
						current_state = UPDATE_SCORE;
						end
				end
			DRAW_A4: begin
				if (draw_count < 8'b1000_0000) begin
					x = A4alien_x + draw_count[3:0];
					y = A4alien_y + draw_count[6:4];
					draw_count = draw_count + 1'b1;
					colour = 3'b101;
					end					
				else begin
					
					draw_count= 18'b0;
					current_state = ERASE_BULLET;
					end
				end
			
			ERASE_BULLET: begin
				x = bullet_x;
				y = bullet_y;
				if (y != 8'd108)
					colour = 3'b000;
				else
					colour = 3'b011;
				current_state = UPDATE_BULLET;
				end
			UPDATE_BULLET: begin
				if (~KEY[3]) begin
					is_fired = 1'b1;
					end
				
				if (bullet_y <= 8'd0) begin
					// bullet reached top of screen
					// reset position, and set to not fired
					bullet_y = 8'd108;
					is_fired = 1'b0;
					bullet_x = p_x + 4;
					end
				else if (is_fired == 1'b1) begin
					// move up
					bullet_y = bullet_y - 1;
					end
				else begin
					// follow player if not fired
					bullet_y = 8'd108;
					bullet_x = p_x + 4;
					end
	
				current_state = DRAW_BULLET;
				end
			DRAW_BULLET: begin 
				x = bullet_x;
				y = bullet_y;
				colour = 3'b011;
				if (SW[0])
					current_state = ERASE_A_BULLET;
				else
					current_state = TEST_HIT;
				end
			ERASE_A_BULLET: begin
				x = A_bullet_x;
				y = A_bullet_y;
				if (y != 8'd108)
					colour = 3'b000;
				else
					colour = 3'b011;
				current_state = UPDATE_A_BULLET;
				end
			UPDATE_A_BULLET: begin
				A_bullet_y = A_bullet_y + 1;
				current_state = DRAW_A_BULLET;
				if (A_bullet_y > 8'd111)
					// alien bullet reached bottom, test if it hit the player
					current_state = TEST_A_HIT;
				if ((~A1) && (~A2) && (~A3) && (~A4))
					// all aliens dead, level up (increase speed)
					current_state = LVL_UP;
			end
			DRAW_A_BULLET: begin 
				x = A_bullet_x;
				y = A_bullet_y;
				colour = 3'b100;
				current_state = TEST_HIT;
				end
			TEST_A_HIT: begin
				// check if hit the player
				if (((A_bullet_x <= p_x + 15) && (A_bullet_x >= p_x)) && ((A_bullet_y <= p_y + 7) && (A_bullet_y >= p_y)))
					current_state = UPDATE_SCORE;
				else begin
					// set where the alien bullet fires from
					// it fires from the first alive alien
					if (A1 == 1'b1) begin
						A_bullet_x = A1alien_x + 8'd8;
						A_bullet_y = A1alien_y + 8'd8;
						end
					else if (A2 == 1'b1) begin
						A_bullet_x = A2alien_x + 8'd8;
						A_bullet_y = A2alien_y + 8'd8;
						end
					else if (A3 == 1'b1) begin
						A_bullet_x = A3alien_x + 8'd8;
						A_bullet_y = A3alien_y + 8'd8;
						end
					else if (A4 == 1'b1) begin
						A_bullet_x = A4alien_x + 8'd8;
						A_bullet_y = A4alien_y + 8'd8;
						end
					current_state = UPDATE_A_BULLET;
				end
			end
			TEST_HIT: begin
				 //test if the updated bullet hit the alien
				 // if hit, update score, bullet fired set alien as dead, and erase the alien
				if ((A1 == 1'b1) && ((bullet_x <= A1alien_x + 15) && (bullet_x >= A1alien_x)) && ((bullet_y <= A1alien_y + 7) && (bullet_y >= A1alien_y)))
				begin
					score = score + 1;
					A1 = 1'b0;
					led0 = 1'b1;
					is_fired = 1'b0;
					current_state = ERASE_A1;
					end
				else if ((A2 == 1'b1) && ((bullet_x <= A2alien_x + 15) && (bullet_x >= A2alien_x)) && ((bullet_y <= A2alien_y + 7) && (bullet_y >= A2alien_y)))
				begin
					score = score + 1;
					A2 = 1'b0;
					is_fired = 1'b0;
					current_state = ERASE_A2;
					end
				else if ((A3 == 1'b1) && ((bullet_x <= A3alien_x + 15) && (bullet_x >= A3alien_x)) && ((bullet_y <= A3alien_y + 7) && (bullet_y >= A3alien_y)))
				begin
					score = score + 1;
					A3 = 1'b0;
					is_fired = 1'b0;
					current_state = ERASE_A3;
					end
				else if ((A4 == 1'b1) && ((bullet_x <= A4alien_x + 15) && (bullet_x >= A4alien_x)) && ((bullet_y <= A4alien_y + 7) && (bullet_y >= A4alien_y)))
				begin
					score = score + 1;
					A4 = 1'b0;
					is_fired = 1'b0;
					current_state = ERASE_A4;
					end
				else begin
					current_state = WAIT;
				end
				if ((~A1) && (~A2) && (~A3) && (~A4))
					current_state = LVL_UP;
				end
			LOSE: begin
				// when game is lost, display red screen of death
				if (draw_count < 17'b1000_0000_0000_0000_0) begin
					x = draw_count[7:0];
					y = draw_count[15:8];
					draw_count = draw_count + 1'b1;
					colour = 3'b100;
					end
				else begin
					draw_count = 18'b0;
					current_state = LOSE;
					end
				end
			WIN: begin
				// when game is won, display green screen of win
				if (draw_count < 17'b1000_0000_0000_0000_0) begin
					x = draw_count[7:0];
					y = draw_count[15:8];
					draw_count = draw_count + 1'b1;
					colour = 3'b010;
					end
				else begin
					draw_count = 18'b0;
					current_state = WIN;
					end
				end
			LVL_UP: begin
				// completed a level
				// update the rate the aliens move left to right up to a level
				if (x_rate < 3) begin
					score = score + 2;
					x_rate = x_rate + 1;
					current_state = RESET_BLACK; 
				end
				else begin
					// won the game (update the high score)
					current_state = UPDATE_HIGHEST; 
				end
			end
			UPDATE_HIGHEST: begin
				// update the high score
				if (score > high_score)
					high_score = score;
				current_state = WIN;
			end
			UPDATE_SCORE: begin
				// update the current score
				if (score >= 3)
					score = score - 3;
				else
					score = 12'b0;
				if (score > high_score)
					// new score is higher, update
					high_score = score;
				current_state = LOSE;
			end
			
			default: current_state = RESET_BLACK;
		endcase
	end
	
endmodule
 
// module counts a number of clock ticks to simulate 60 frames per second
// send go signal each frame counted
module frame_counter(input clock, output reg go);
	reg [19:0] count;
	// 50 000 000 / 60 frames = 833 333 seconds per frame
	// 833 333 = 20'b11001011011100110100
	always@(posedge clock)
    begin
        if (count == 20'b11001011011100110100) begin
		  count = 20'b0000_0000_0000_0000_0000;
		  go = 1'b1;
		  end
        else begin
			count = count + 1'b1;
			go = 1'b0;
		  end
    end
endmodule
