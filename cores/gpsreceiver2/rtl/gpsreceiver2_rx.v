/*
 * Milkymist SoC
 * Copyright (C) 2007, 2008, 2009, 2010, 2011 Sebastien Bourdeauducq
 * Copyleft 2011 Cristian Paul Pen~aranda Rojas
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

module gpsreceiver2_rx(
	output reg [10:0] rx_count_0,

	output [7:0] rxb0_dat,
	output [10:0] rxb0_adr,
	output rxb0_we,
	
	input gps_rec_clk,
	input gps_rec_sync,
	input gps_rec_data,
	
	output gps_led
);
/*   Data Stream
*    from SiGE SE4162T
*
	* Nibble
	* SMSM  SMSMSMSMSMSMSMSMSMSMSMSMSMSM SM SM
	* IIQQ  IIQQIIQQIIQQIIQQIIQQIIQQIIQQ II QQ 
	* S     S   S   S   S   S   S   S    S       Sync
	* CCCC  CCCCCCCCCCCCCCCCCCCCCCCCCCCC CC CC   Clock
	*/

/* Serial to Parallel */
reg [3:0] iqnibble_rx_data;
always @(posedge gps_rec_clk)
begin
	iqnibble_rx_data <= {gps_rec_data,iqnibble_rx_data[3:1]};
end

/* Address Counter */
always @(posedge gps_rec_clk) begin
	if(gps_rec_clk)
		rx_count_0 <= rx_count_0 + 11'd0;
	else
		rx_count_0 <= rx_count_0 + 11'd1;
end

assign rxb0_adr = rx_count_0;

/* Data loading into buffer */
reg rxb_we_ctl;
assign rxb0_we = rxb_we_ctl;

reg [3:0] lo;
reg [3:0] hi;
reg [1:0] load_nibble;
/* concatenate two nibble as one byte */
always @(posedge gps_rec_clk) begin
	if(load_nibble[0])
		lo <= iqnibble_rx_data;
	if(load_nibble[1])
		hi <= iqnibble_rx_data;
end
assign rxb0_dat = {hi, lo};

reg [1:0] state;
reg [1:0] next_state;

parameter IDLE		= 2'd0;
parameter LOAD_LO	= 2'd1;
parameter LOAD_HI	= 2'd2;
parameter TERMINATE	= 2'd3;

initial state <= IDLE;
always @(posedge gps_rec_clk)
	state <= next_state;

always @(*) begin
	rxb_we_ctl = 1'b0;
	load_nibble = 2'b00;
	
	next_state = state;
	case(state)
		IDLE: begin
			if(gps_rec_sync) begin
				load_nibble = 2'b01;
				next_state = LOAD_HI;
			end
		end
		LOAD_LO: begin
			rxb_we_ctl = 1'b1;
			if(gps_rec_sync) begin
				load_nibble = 2'b01;
				next_state = LOAD_HI;
			end else begin
				next_state = TERMINATE;
			end
		end
		LOAD_HI: begin
			if(gps_rec_sync) begin
				load_nibble = 2'b10;
				next_state = LOAD_LO;
			end else begin
				next_state = TERMINATE;
			end
		end
		TERMINATE: begin
			next_state = IDLE;
		end
	endcase
end

/* Debug */
reg [22:0]  counter = 23'b0;
always @(posedge gps_rec_clk) begin
	counter <= counter + 1;
end
assign gps_led = counter[21];

endmodule
