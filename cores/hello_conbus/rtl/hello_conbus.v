/*
 * Milkymist VJ SoC
 * Copyright (C) 2007, 2008, 2009 Sebastien Bourdeauducq
 * Copyleft   2011 Cristian Paul Peñaranda Rojas
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

module hello(
	input sys_clk,
	input sys_rst,
	
	/* WB */
	input [31:0] wb_adr_i,
	input [31:0] wb_dat_i,
	output reg [31:0] wb_dat_o,
	input wb_cyc_i,
	input wb_stb_i,
	input wb_we_i,
	output reg wb_ack_o,
	
	/* LED */
	output debug_led
);

reg [31:0] data_i;
/* Sync data */
reg next_csr_we;
always @(posedge sys_clk) begin
	data_i <= wb_dat_i;
end

/* Controller */
reg [1:0] state;
reg [1:0] next_state;

reg led_state = 1'b0;

parameter IDLE		= 2'd0;
parameter DELAYACK1	= 2'd1;
parameter DELAYACK2	= 2'd2;
parameter ACK		= 2'd3;

parameter OFF		= 1'd0;

always @(posedge sys_clk) begin
	if(sys_rst)
		state <= IDLE;
	else
		state <= next_state;
end

always @(*) begin
	next_state = state;
	
	wb_ack_o = 1'b0;
	
	case(state)
		IDLE: begin
			if(wb_cyc_i & wb_stb_i) begin
				/* We have a request for us */
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
//parameter csr_addr = 4'h0
//wire csr_selected = csr_a[14:10] == csr_addr;

/* fake read data */
always @(posedge sys_clk) begin
	if(next_state == DELAYACK1)
		wb_dat_o <= 4'hffff;
end

/* Drive LEd */
always @(posedge sys_clk) begin
	// ACK!!!
	if(next_state == ACK)
		led_state <= data_i[0];
end

assign  debug_led = led_state;

endmodule
