/*
 * GPS-SDR for Milkymist SoC
 * Copyright (C) 2007, 2008, 2009, 2010, 2011 Sebastien Bourdeauducq
 * Copyleft 2011 Cristian Paul Pen~arada Rojas
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

module gpsreceiver2_ctlif #(
	parameter csr_addr = 5'h0
) (
	input sys_clk,
	input sys_rst,

	input [14:0] csr_a,
	input csr_we,
	input [31:0] csr_di,
	output reg [31:0] csr_do,
	
	input [10:0] rx_count_0
);


wire csr_selected = csr_a[14:10] == csr_addr;

always @(posedge sys_clk) begin
	if(sys_rst) begin
		csr_do <= 32'd0;

	end else begin
		csr_do <= 32'd0;
		if(csr_selected) begin
			if(csr_we) begin
				/*case(csr_a[2:0])

					3'd1: begin
						lk <= csr_di[3];
						oe <= csr_di[2];
						do <= csr_di[0];
					end

					3'd2: s0_state <= csr_di[1:0];
					// 'd3 rx_count_0 is read-only
					3'd4: s1_state <= csr_di[1:0];
				endcase */
			end
			case(csr_a[2:0])

				3'd1: csr_do <= rx_count_0;
			endcase
		end /* if(csr_selected) */
	end
end
endmodule
