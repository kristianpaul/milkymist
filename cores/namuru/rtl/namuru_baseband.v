/*
 * Milkymist VJ SoC
 * Copyright (C) 2007, 2008, 2009 Sebastien Bourdeauducq
 * Copyleft 2011, Cristian Paul 
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

module wb_generic(
	input sys_clk,
	input sys_rst,
	
	/* WB */
	input [31:0] wb_adr_i,
	input [31:0] wb_dat_i,
	output [31:0] wb_dat_o,
	input [3:0] wb_sel_i,
	input wb_cyc_i,
	input wb_stb_i,
	input wb_we_i,
	output reg wb_ack_o
);
// at least you want to align this in software
wire [31:0] wb_dat_i_le = {wb_dat_i[7:0], wb_dat_i[15:8], wb_dat_i[23:16], wb_dat_i[31:24]};

reg next_csr_we;
reg [31:0] dato0;
reg [31:0] dato1;
reg [31:0] dato2;
reg [31:0] dato3;

reg [31:0] wb_dat_o_le;
always @(posedge sys_clk) begin
	        if(sys_rst) begin
			wb_dat_o_le <= 32'd0;
			dato0 <= 32'h11111111;
			dato1 <= 32'h22222222;
			dato2 <= 32'h33333333;
			dato3 <= 32'h44444444;
		end else begin
			wb_dat_o_le <= 32'd0;
			if(next_csr_we) begin
				/* write */
				case(wb_adr_i[9:2])
					/* channel 0 */
					3'd0: dato0 <= wb_dat_i_le;
					3'd1: dato1 <= wb_dat_i_le;
					3'd2: dato2 <= wb_dat_i_le;
					3'd3: dato3 <= wb_dat_i_le;
					/* status */ 

					/* control */ 
				endcase
			end
			/* read */
			case(wb_adr_i[9:2])
				3'd0: wb_dat_o_le <= dato0;
				3'd1: wb_dat_o_le <= dato1;
				3'd2: wb_dat_o_le <= dato2;
				3'd3: wb_dat_o_le <= dato3;
			//	default wb_dat_o_le <= 32'hfecafeca;
			endcase
		end
	end
// at least you want to align this in software
assign wb_dat_o = {wb_dat_o_le[7:0], wb_dat_o_le[15:8], wb_dat_o_le[23:16], wb_dat_o_le[31:24]};

reg [1:0] state;
reg [1:0] next_state;

parameter IDLE		= 2'd0;
parameter DELAYACK1	= 2'd1;
parameter DELAYACK2	= 2'd2;
parameter ACK		= 2'd3;

always @(posedge sys_clk) begin
	if(sys_rst)
		state <= IDLE;
	else
		state <= next_state;
end

always @(*) begin
	next_state = state;
	
	wb_ack_o = 1'b0;
	next_csr_we = 1'b0;
	
	case(state)
		IDLE: begin
			if(wb_cyc_i & wb_stb_i) begin
				/* We have a request for us */
				next_csr_we = wb_we_i;
				if(wb_we_i)
					next_state = ACK;
				else
					next_state = DELAYACK1;
			end
		end
		DELAYACK1: next_state = DELAYACK2;
		DELAYACK2: next_state = ACK;
		ACK: begin
			wb_ack_o = 1'b1;
			next_state = IDLE;
		end
	endcase
end

endmodule
