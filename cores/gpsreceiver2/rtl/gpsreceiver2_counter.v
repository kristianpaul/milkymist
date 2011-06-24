/*
 * Milkymist SoC - GPS-SDR
 * Copyright (C) 2007, 2008, 2009, 2010, 2011 Sebastien Bourdeauducq
 * Copyleft 2011 Cristian Paul Peñaranda Rojas
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

module gpsreceiver2_counter(
	input rxb0_clk,

	input r_enable,
	input r_reset,

	output rxb0_we,
	output [10:0] rxb0_adr,   	/* to buffer */
	output reg [10:0] rx_count_0 	/* to control */
);


/* Address Counter */
initial rx_count_0 = 11'b0;
always @(posedge rxb0_clk) begin
	if(r_reset)
		rx_count_0 <= 11'd0;
	else if(r_enable)
		rx_count_0 <= rx_count_0 + 11'd1;
end

assign rxb0_adr = rx_count_0;

endmodule
