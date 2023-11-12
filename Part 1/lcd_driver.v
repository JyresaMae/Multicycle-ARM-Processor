module lcd_driver(
  input CLOCK_50,    //    50 MHz clock
  input [31:0] Instr, 
  input [3:0] state_for_show,

//    LCD Module 16X2
  output LCD_ON,    // LCD Power ON/OFF
  output LCD_BLON,    // LCD Back Light ON/OFF
  output LCD_RW,    // LCD Read/Write Select, 0 = Write, 1 = Read
  output LCD_EN,    // LCD Enable
  output LCD_RS,    // LCD Command/Data Select, 0 = Command, 1 = Data
  inout [7:0] LCD_DATA    // LCD Data bus 8 bits
);

// reset delay gives some time for peripherals to initialize
wire DLY_RST;
Reset_Delay r0(    .iCLK(CLOCK_50),.oRESET(DLY_RST) );


// turn LCD ON
assign    LCD_ON        =    1'b1;
assign    LCD_BLON    =    1'b1;


LCD_Display u1(
// Host Side
   .iCLK_50MHZ(CLOCK_50),
   .iRST_N(DLY_RST),
   .Instr(Instr),
   .state_for_show(state_for_show),
// LCD Side
   .DATA_BUS(LCD_DATA),
   .LCD_RW(LCD_RW),
   .LCD_E(LCD_EN),
   .LCD_RS(LCD_RS)
);

endmodule

        
module LCD_Display(iCLK_50MHZ, iRST_N, Instr, state_for_show, 
    LCD_RS,LCD_E,LCD_RW,DATA_BUS);
input iCLK_50MHZ, iRST_N;
input [31:0] Instr; 
input [3:0] state_for_show;
output LCD_RS, LCD_E, LCD_RW;
inout [7:0] DATA_BUS;

parameter
HOLD = 4'h0,
FUNC_SET = 4'h1,
DISPLAY_ON = 4'h2,
MODE_SET = 4'h3,
Print_String = 4'h4,
LINE2 = 4'h5,
RETURN_HOME = 4'h6,
DROP_LCD_E = 4'h7,
RESET1 = 4'h8,
RESET2 = 4'h9,
RESET3 = 4'ha,
DISPLAY_OFF = 4'hb,
DISPLAY_CLEAR = 4'hc;

reg [3:0] state, next_command;
// Enter new ASCII hex data above for LCD Display
reg [7:0] DATA_BUS_VALUE;
wire [7:0] Next_Char;
reg [19:0] CLK_COUNT_400HZ;
reg [4:0] CHAR_COUNT;
reg CLK_400HZ, LCD_RW_INT, LCD_E, LCD_RS;

// BIDIRECTIONAL TRI STATE LCD DATA BUS
assign DATA_BUS = (LCD_RW_INT? 8'bZZZZZZZZ: DATA_BUS_VALUE);

LCD_display_string u1(
.index(CHAR_COUNT),
.out(Next_Char),
.state_for_show(state_for_show),
.Instr(Instr) );

assign LCD_RW = LCD_RW_INT;

always @(posedge iCLK_50MHZ or negedge iRST_N)
    if (!iRST_N)
    begin
       CLK_COUNT_400HZ <= 20'h00000;
       CLK_400HZ <= 1'b0;
    end
    else if (CLK_COUNT_400HZ < 20'h0F424)
    begin
       CLK_COUNT_400HZ <= CLK_COUNT_400HZ + 1'b1;
    end
    else
    begin
      CLK_COUNT_400HZ <= 20'h00000;
      CLK_400HZ <= ~CLK_400HZ;
    end
// State Machine to send commands and data to LCD DISPLAY

always @(posedge CLK_400HZ or negedge iRST_N)
    if (!iRST_N)
    begin
     state <= RESET1;
    end
    else
    case (state)
    RESET1:            
// Set Function to 8-bit transfer and 2 line display with 5x8 Font size
// see Hitachi HD44780 family data sheet for LCD command and timing details
    begin
      LCD_E <= 1'b1;
      LCD_RS <= 1'b0;
      LCD_RW_INT <= 1'b0;
      DATA_BUS_VALUE <= 8'h38;
      state <= DROP_LCD_E;
      next_command <= RESET2;
      CHAR_COUNT <= 5'b00000;
    end
    RESET2:
    begin
      LCD_E <= 1'b1;
      LCD_RS <= 1'b0;
      LCD_RW_INT <= 1'b0;
      DATA_BUS_VALUE <= 8'h38;
      state <= DROP_LCD_E;
      next_command <= RESET3;
    end
    RESET3:
    begin
      LCD_E <= 1'b1;
      LCD_RS <= 1'b0;
      LCD_RW_INT <= 1'b0;
      DATA_BUS_VALUE <= 8'h38;
      state <= DROP_LCD_E;
      next_command <= FUNC_SET;
    end
// EXTRA STATES ABOVE ARE NEEDED FOR RELIABLE PUSHBUTTON RESET OF LCD

    FUNC_SET:
    begin
      LCD_E <= 1'b1;
      LCD_RS <= 1'b0;
      LCD_RW_INT <= 1'b0;
      DATA_BUS_VALUE <= 8'h38;
      state <= DROP_LCD_E;
      next_command <= DISPLAY_OFF;
    end

// Turn off Display and Turn off cursor
    DISPLAY_OFF:
    begin
      LCD_E <= 1'b1;
      LCD_RS <= 1'b0;
      LCD_RW_INT <= 1'b0;
      DATA_BUS_VALUE <= 8'h08;
      state <= DROP_LCD_E;
      next_command <= DISPLAY_CLEAR;
    end

// Clear Display and Turn off cursor
    DISPLAY_CLEAR:
    begin
      LCD_E <= 1'b1;
      LCD_RS <= 1'b0;
      LCD_RW_INT <= 1'b0;
      DATA_BUS_VALUE <= 8'h01;
      state <= DROP_LCD_E;
      next_command <= DISPLAY_ON;
    end

// Turn on Display and Turn off cursor
    DISPLAY_ON:
    begin
      LCD_E <= 1'b1;
      LCD_RS <= 1'b0;
      LCD_RW_INT <= 1'b0;
      DATA_BUS_VALUE <= 8'h0C;
      state <= DROP_LCD_E;
      next_command <= MODE_SET;
    end

// Set write mode to auto increment address and move cursor to the right
    MODE_SET:
    begin
      LCD_E <= 1'b1;
      LCD_RS <= 1'b0;
      LCD_RW_INT <= 1'b0;
      DATA_BUS_VALUE <= 8'h06;
      state <= DROP_LCD_E;
      next_command <= Print_String;
    end

// Write ASCII hex character in first LCD character location
    Print_String:
    begin
      state <= DROP_LCD_E;
      LCD_E <= 1'b1;
      LCD_RS <= 1'b1;
      LCD_RW_INT <= 1'b0;
    // ASCII character to output
      DATA_BUS_VALUE <= Next_Char;
    // Loop to send out 32 characters to LCD Display  (16 by 2 lines)
      if ((CHAR_COUNT < 31) && (Next_Char != 8'hFE))
         CHAR_COUNT <= CHAR_COUNT + 1'b1;
      else
         CHAR_COUNT <= 5'b00000; 
    // Jump to second line?
      if (CHAR_COUNT == 15)
        next_command <= LINE2;
    // Return to first line?
      else if ((CHAR_COUNT == 31) || (Next_Char == 8'hFE))
        next_command <= RETURN_HOME;
      else
        next_command <= Print_String;
    end

// Set write address to line 2 character 1
    LINE2:
    begin
      LCD_E <= 1'b1;
      LCD_RS <= 1'b0;
      LCD_RW_INT <= 1'b0;
      DATA_BUS_VALUE <= 8'hC0;
      state <= DROP_LCD_E;
      next_command <= Print_String;
    end

// Return write address to first character postion on line 1
    RETURN_HOME:
    begin
      LCD_E <= 1'b1;
      LCD_RS <= 1'b0;
      LCD_RW_INT <= 1'b0;
      DATA_BUS_VALUE <= 8'h80;
      state <= DROP_LCD_E;
      next_command <= Print_String;
    end

// The next three states occur at the end of each command or data transfer to the LCD
// Drop LCD E line - falling edge loads inst/data to LCD controller
    DROP_LCD_E:
    begin
      LCD_E <= 1'b0;
      state <= HOLD;
    end
// Hold LCD inst/data valid after falling edge of E line                
    HOLD:
    begin
      state <= next_command;
    end
    endcase
endmodule

module LCD_display_string(index,out,Instr,state_for_show);
input [4:0] index;
input [31:0] Instr;
input [3:0] state_for_show;
output reg [7:0] out;
// ASCII hex values for LCD Display
// Enter Live Hex Data Values from hardware here
// LCD DISPLAYS THE FOLLOWING:
//----------------------------
//| Count=XX                  |
//| DE2                       |
//----------------------------
// Line 1
   always 
     case (index)
	    5'h00: out <= 8'h53;
	    5'h01: out <= 8'h54;
	    5'h02: out <= 8'h41;
	    5'h03: out <= 8'h54;
	    5'h04: out <= 8'h45;
	    5'h05: out <= 8'h3A;
	    5'h06: out <= 8'h20;
	    5'h07:	case (state_for_show)
	    			4'b0000: out <= 8'h46;
	    			4'b0001: out <= 8'h44;
	    			4'b0010: out <= 8'h4D;
	    			4'b0011: out <= 8'h4D;
	    			4'b0100: out <= 8'h4D;
	    			4'b0101: out <= 8'h4D;
	    			4'b0110: out <= 8'h45;
	    			4'b0111: out <= 8'h45;
	    			4'b1000: out <= 8'h41;
	    			4'b1001: out <= 8'h42;
	    			4'b1010: out <= 8'h55;
	    			default: out <= 8'h20;
	    		endcase
	   	5'h08: case (state_for_show)
	    			4'b0000: out <= 8'h65;
	    			4'b0001: out <= 8'h65;
	    			4'b0010: out <= 8'h65;
	    			4'b0011: out <= 8'h65;
	    			4'b0100: out <= 8'h65;
	    			4'b0101: out <= 8'h65;
	    			4'b0110: out <= 8'h78;
	    			4'b0111: out <= 8'h78;
	    			4'b1000: out <= 8'h4C;
	    			4'b1001: out <= 8'h72;
	    			4'b1010: out <= 8'h4E;
	    			default: out <= 8'h20;
	    		endcase
	   	5'h09: case (state_for_show)
	    			4'b0000: out <= 8'h74;
	    			4'b0001: out <= 8'h63;
	    			4'b0010: out <= 8'h6D;
	    			4'b0011: out <= 8'h6D;
	    			4'b0100: out <= 8'h6D;
	    			4'b0101: out <= 8'h6D;
	    			4'b0110: out <= 8'h65;
	    			4'b0111: out <= 8'h65;
	    			4'b1000: out <= 8'h55;
	    			4'b1001: out <= 8'h61;
	    			4'b1010: out <= 8'h4B;
	    			default: out <= 8'h20;
	    		endcase
	    5'h0A: case (state_for_show)
	    			4'b0000: out <= 8'h63;
	    			4'b0001: out <= 8'h6F;
	    			4'b0010: out <= 8'h41;
	    			4'b0011: out <= 8'h52;
	    			4'b0100: out <= 8'h57;
	    			4'b0101: out <= 8'h57;
	    			4'b0110: out <= 8'h63;
	    			4'b0111: out <= 8'h63;
	    			4'b1000: out <= 8'h57;
	    			4'b1001: out <= 8'h6E;
	    			4'b1010: out <= 8'h4E;
	    			default: out <= 8'h20;
	    		endcase
	    5'h0B: case (state_for_show)
	    			4'b0000: out <= 8'h68;
	    			4'b0001: out <= 8'h64;
	    			4'b0010: out <= 8'h64;
	    			4'b0011: out <= 8'h65;
	    			4'b0100: out <= 8'h42;
	    			4'b0101: out <= 8'h72;
	    			4'b0110: out <= 8'h75;
	    			4'b0111: out <= 8'h75;
	    			4'b1000: out <= 8'h42;
	    			4'b1001: out <= 8'h63;
	    			4'b1010: out <= 8'h4F;
	    			default: out <= 8'h20;
	    		endcase
	    5'h0C: case (state_for_show)
	    			4'b0000: out <= 8'h20;
	    			4'b0001: out <= 8'h65;
	    			4'b0010: out <= 8'h72;
	    			4'b0011: out <= 8'h61;
	    			4'b0100: out <= 8'h20;
	    			4'b0101: out <= 8'h69;
	    			4'b0110: out <= 8'h74;
	    			4'b0111: out <= 8'h74;
	    			4'b1000: out <= 8'h20;
	    			4'b1001: out <= 8'h68;
	    			4'b1010: out <= 8'h57;
	    			default: out <= 8'h20;
	    		endcase
	    5'h0D: case (state_for_show)
					4'b0000: out <= 8'h20;
					4'b0001: out <= 8'h20;
					4'b0010: out <= 8'h20;
					4'b0011: out <= 8'h64;
					4'b0100: out <= 8'h20;
					4'b0101: out <= 8'h74;
					4'b0110: out <= 8'h65;
					4'b0111: out <= 8'h65;
					4'b1000: out <= 8'h20;
					4'b1001: out <= 8'h20;
					4'b1010: out <= 8'h4E;
					default: out <= 8'h20;
				endcase
		5'h0E: case (state_for_show)
					4'b0000: out <= 8'h20;
					4'b0001: out <= 8'h20;
					4'b0010: out <= 8'h20;
					4'b0011: out <= 8'h20;
					4'b0100: out <= 8'h20;
					4'b0101: out <= 8'h65;
					4'b0110: out <= 8'h52;
					4'b0111: out <= 8'h49;
					4'b1000: out <= 8'h20;
					4'b1001: out <= 8'h20;
					4'b1010: out <= 8'h20;
					default: out <= 8'h20;
				endcase
	// Line 2
	    5'h10: case (Instr[27:26])//opcode

	    			// data processing
					2'b00:begin

							case (Instr[24:21])

								// add
								4'b0100:	out <= 8'h41;

								// sub
								4'b0010:	out <= 8'h53;

								// orr
								4'b1100:	out <= 8'h4F;
								
								// and
								4'b0000:	out <= 8'h41;

								default: 	out <= 8'h20;
							endcase

						 end

					// memory	 	
					2'b01:	if(Instr[20])	out <= 8'h4C;
							else 			out <= 8'h53;

					// B		
					2'b10: 					out <= 8'h42;

					default: 				out <= 8'h20;
				endcase
					
	    5'h11: case (Instr[27:26])//opcode

	    			// data processing
					2'b00:begin

							case (Instr[24:21])

								// add
								4'b0100:		out <= 8'h44;
	
								// sub	
								4'b0010:		out <= 8'h55;
	
								// orr	
								4'b1100:		out <= 8'h52;
									
								// and	
								4'b0000:		out <= 8'h4E;

								default: 		out <= 8'h20;
							endcase

						 end
					// memory	 	
					2'b01:	if(Instr[20])		out <= 8'h44;
							else 				out <= 8'h54;

					// B		
					2'b10: case (Instr[31:28])
							4'b0000:			out <= 8'h45;
							4'b0001:			out <= 8'h4E;
							4'b0010:			out <= 8'h43;
							4'b0011:			out <= 8'h43;
							4'b0100:			out <= 8'h4D;
							4'b0101:			out <= 8'h50;
							4'b0110:			out <= 8'h56;
							4'b0111:			out <= 8'h56;
							4'b1000:			out <= 8'h48;
							4'b1001:			out <= 8'h4C;
							4'b1010:			out <= 8'h47;
							4'b1011:			out <= 8'h4C;
							4'b1100:			out <= 8'h47;
							4'b1101:			out <= 8'h4C;
							default:			out <= 8'h20;
						endcase

					default: 					out <= 8'h20;
				endcase
					
	    5'h12: case (Instr[27:26])//opcode

	    			// data processing
					2'b00:begin

							case (Instr[24:21])

								// ADD
								4'b0100:		out <= 8'h44;
	
								// SUB	
								4'b0010:		out <= 8'h42;
	
								// ORR	
								4'b1100:		out <= 8'h52;
									
								// AND	
								4'b0000:		out <= 8'h44;

								default: 		out <= 8'h20;
							endcase

						 end

					// memory	 	
					2'b01:	if(Instr[20])		out <= 8'h52;
							else 				out <= 8'h52;

					// B		
					2'b10: case (Instr[31:28])
							4'b0000:			out <= 8'h51;
							4'b0001:			out <= 8'h45;
							4'b0010:			out <= 8'h53;
							4'b0011:			out <= 8'h43;
							4'b0100:			out <= 8'h49;
							4'b0101:			out <= 8'h4C;
							4'b0110:			out <= 8'h53;
							4'b0111:			out <= 8'h43;
							4'b1000:			out <= 8'h49;
							4'b1001:			out <= 8'h53;
							4'b1010:			out <= 8'h45;
							4'b1011:			out <= 8'h54;
							4'b1100:			out <= 8'h54;
							4'b1101:			out <= 8'h45;
							default:			out <= 8'h20;
						endcase
					default:					out <= 8'h20;
				endcase
		5'h13: case (Instr[27:26])//opcode

	    			// data processing
					2'b00:begin
							if(Instr[20]) begin
														out <= 8'h53;
							end
							else begin
								case (Instr[31:28])
									4'b0000:			out <= 8'h45;
									4'b0001:			out <= 8'h4E;
									4'b0010:			out <= 8'h43;
									4'b0011:			out <= 8'h43;
									4'b0100:			out <= 8'h4D;
									4'b0101:			out <= 8'h50;
									4'b0110:			out <= 8'h56;
									4'b0111:			out <= 8'h56;
									4'b1000:			out <= 8'h48;
									4'b1001:			out <= 8'h4C;
									4'b1010:			out <= 8'h47;
									4'b1011:			out <= 8'h4C;
									4'b1100:			out <= 8'h47;
									4'b1101:			out <= 8'h4C;
									default:			out <= 8'h20;
								endcase
							end
					end
					// memory	 	
					2'b01:begin
							case (Instr[31:28])
								4'b0000:			out <= 8'h45;
								4'b0001:			out <= 8'h4E;
								4'b0010:			out <= 8'h43;
								4'b0011:			out <= 8'h43;
								4'b0100:			out <= 8'h4D;
								4'b0101:			out <= 8'h50;
								4'b0110:			out <= 8'h56;
								4'b0111:			out <= 8'h56;
								4'b1000:			out <= 8'h48;
								4'b1001:			out <= 8'h4C;
								4'b1010:			out <= 8'h47;
								4'b1011:			out <= 8'h4C;
								4'b1100:			out <= 8'h47;
								4'b1101:			out <= 8'h4C;
								default:			out <= 8'h20;
							endcase
					end
					default:						out <= 8'h20;
				endcase
		5'h14: case (Instr[27:26])//opcode

	    			// data processing
					2'b00:begin
							if(Instr[20]) begin
														out <= 8'h20;
							end
							else begin
								case (Instr[31:28])
									4'b0000:			out <= 8'h51;
									4'b0001:			out <= 8'h45;
									4'b0010:			out <= 8'h53;
									4'b0011:			out <= 8'h43;
									4'b0100:			out <= 8'h49;
									4'b0101:			out <= 8'h4C;
									4'b0110:			out <= 8'h53;
									4'b0111:			out <= 8'h43;
									4'b1000:			out <= 8'h49;
									4'b1001:			out <= 8'h53;
									4'b1010:			out <= 8'h45;
									4'b1011:			out <= 8'h54;
									4'b1100:			out <= 8'h54;
									4'b1101:			out <= 8'h45;
									default:			out <= 8'h20;
								endcase
							end
						end
					// memory	 	
					2'b01:begin
							case (Instr[31:28])
								4'b0000:			out <= 8'h51;
								4'b0001:			out <= 8'h45;
								4'b0010:			out <= 8'h53;
								4'b0011:			out <= 8'h43;
								4'b0100:			out <= 8'h49;
								4'b0101:			out <= 8'h4C;
								4'b0110:			out <= 8'h53;
								4'b0111:			out <= 8'h43;
								4'b1000:			out <= 8'h49;
								4'b1001:			out <= 8'h53;
								4'b1010:			out <= 8'h45;
								4'b1011:			out <= 8'h54;
								4'b1100:			out <= 8'h54;
								4'b1101:			out <= 8'h45;
								default:			out <= 8'h20;
							endcase
						end
						default:					out <= 8'h20;
					endcase
		5'h15:										out <= 8'h20;

		5'h16:	if(Instr[27:26] == 2'b10)			out <= 8'h20;//B							
				else								out <= 8'h52;

		5'h17:		if(Instr[27:26] == 2'b10)		out <= 8'h20;//B
					else begin
						case (Instr[15:12])
							4'b0000:				out <= 8'h30;
							4'b0001:				out <= 8'h31;
							4'b0010:				out <= 8'h32;
							4'b0011:				out <= 8'h33;
							4'b0100:				out <= 8'h34;
							4'b0101:				out <= 8'h35;
							4'b0110:				out <= 8'h36;
							4'b0111:				out <= 8'h37;
							4'b1000:				out <= 8'h38;
							4'b1001:				out <= 8'h39;
							4'b1010:				out <= 8'h41;
							4'b1011:				out <= 8'h42;
							4'b1100:				out <= 8'h43;
							4'b1101:				out <= 8'h44;
							4'b1110:				out <= 8'h45;
							4'b1111:				out <= 8'h46;
						endcase
					end
		5'h18:	if(Instr[27:26] == 2'b10)			out <= 8'h20;//B							
				else								out <= 8'h2C;
		
		5'h19:	if(Instr[27:26] == 2'b01)			out <= 8'h5B;//memory							
				else								out <= 8'h20;//B or DP

		5'h1A:	if(Instr[27:26] == 2'b10)			out <= 8'h20;//B							
				else								out <= 8'h52;

		5'h1B:		if(Instr[27:26] == 2'b10)		out <= 8'h20;//B
					else begin
						case (Instr[19:16])
							4'b0000:				out <= 8'h30;
							4'b0001:				out <= 8'h31;
							4'b0010:				out <= 8'h32;
							4'b0011:				out <= 8'h33;
							4'b0100:				out <= 8'h34;
							4'b0101:				out <= 8'h35;
							4'b0110:				out <= 8'h36;
							4'b0111:				out <= 8'h37;
							4'b1000:				out <= 8'h38;
							4'b1001:				out <= 8'h39;
							4'b1010:				out <= 8'h41;
							4'b1011:				out <= 8'h42;
							4'b1100:				out <= 8'h43;
							4'b1101:				out <= 8'h44;
							4'b1110:				out <= 8'h45;
							4'b1111:				out <= 8'h46;
						endcase
					end

		5'h1C:	if(Instr[27:26] == 2'b10)			out <= 8'h20;//B							
				else								out <= 8'h2C;

		5'h1D:	if(Instr[27:26] == 2'b10)			out <= 8'h20;//B							
				else begin
					
					if(Instr[25] && Instr[27:26] == 2'b00) begin//DP
													out <= 8'h49;
					end
					
					else if(!Instr[25] && Instr[27:26] == 2'b01) begin
													out <= 8'h49;
					end
					
					else begin
													out <= 8'h52;
					end
				end
		5'h1E:	if(Instr[27:26] == 2'b10)			out <= 8'h20;//B							
				else begin
					
					if(Instr[25] && Instr[27:26] == 2'b00) begin//DP
													out <= 8'h6D;
					end
					
					else if(!Instr[25] && Instr[27:26] == 2'b01) begin
													out <= 8'h6D;
					end
					
					else begin
						case (Instr[3:0])
							4'b0000:				out <= 8'h30;
							4'b0001:				out <= 8'h31;
							4'b0010:				out <= 8'h32;
							4'b0011:				out <= 8'h33;
							4'b0100:				out <= 8'h34;
							4'b0101:				out <= 8'h35;
							4'b0110:				out <= 8'h36;
							4'b0111:				out <= 8'h37;
							4'b1000:				out <= 8'h38;
							4'b1001:				out <= 8'h39;
							4'b1010:				out <= 8'h41;
							4'b1011:				out <= 8'h42;
							4'b1100:				out <= 8'h43;
							4'b1101:				out <= 8'h44;
							4'b1110:				out <= 8'h45;
							4'b1111:				out <= 8'h46;
						endcase
					end
				end

		5'h1F:	if(Instr[27:26] == 2'b01)			out <= 8'h5D;//memory							
				else								out <= 8'h20;//B or DP
	    default: out <= 8'h20;

    endcase
endmodule












module    Reset_Delay(iCLK,oRESET);
input        iCLK;
output reg    oRESET;
reg    [19:0]    Cont;

always@(posedge iCLK)
begin
    if(Cont!=20'hFFFFF)
    begin
        Cont    <=    Cont+1'b1;
        oRESET    <=    1'b0;
    end
    else
    oRESET    <=    1'b1;
end

endmodule






/*
 SW8 (GLOBAL RESET) resets LCD
ENTITY LCD_Display IS
-- Enter number of live Hex hardware data values to display
-- (do not count ASCII character constants)
    GENERIC(Num_Hex_Digits: Integer:= 2); 
-----------------------------------------------------------------------
-- LCD Displays 16 Characters on 2 lines
-- LCD_display string is an ASCII character string entered in hex for 
-- the two lines of the  LCD Display   (See ASCII to hex table below)
-- Edit LCD_Display_String entries above to modify display
-- Enter the ASCII character's 2 hex digit equivalent value
-- (see table below for ASCII hex values)
-- To display character assign ASCII value to LCD_display_string(x)
-- To skip a character use 8'h20" (ASCII space)
-- To dislay "live" hex values from hardware on LCD use the following: 
--   make array element for that character location 8'h0" & 4-bit field from Hex_Display_Data
--   state machine sees 8'h0" in high 4-bits & grabs the next lower 4-bits from Hex_Display_Data input
--   and performs 4-bit binary to ASCII conversion needed to print a hex digit
--   Num_Hex_Digits must be set to the count of hex data characters (ie. "00"s) in the display
--   Connect hardware bits to display to Hex_Display_Data input
-- To display less than 32 characters, terminate string with an entry of 8'hFE"
--  (fewer characters may slightly increase the LCD's data update rate)
------------------------------------------------------------------- 
--                        ASCII HEX TABLE
--  Hex                        Low Hex Digit
-- Value  0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
------\----------------------------------------------------------------
--H  2 |  SP  !   "   #   $   %   &   '   (   )   *   +   ,   -   .   /
--i  3 |  0   1   2   3   4   5   6   7   8   9   :   ;   <   =   >   ?
--g  4 |  @   A   B   C   D   E   F   G   H   I   J   K   L   M   N   O
--h  5 |  P   Q   R   S   T   U   V   W   X   Y   Z   [   \   ]   ^   _
--   6 |  `   a   b   c   d   e   f   g   h   i   j   k   l   m   n   o
--   7 |  p   q   r   s   t   u   v   w   x   y   z   {   |   }   ~ DEL
-----------------------------------------------------------------------
-- Example "A" is row 4 column 1, so hex value is 8'h41"
-- *see LCD Controller's Datasheet for other graphics characters available
*/