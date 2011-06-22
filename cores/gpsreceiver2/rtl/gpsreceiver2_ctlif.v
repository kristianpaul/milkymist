/*
 * Milkymist SoC GPS-SDR
 * Copyright (C) 2007, 2008, 2009, 2010, 2011 Sebastien Bourdeauducq
 * Copyleft 2011 Cristian Paul Peñarada Rojas
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
	
	input [10:0] rx_count_0,
	output reg r_enable,
	output reg r_reset

);
wire csr_selected = csr_a[14:10] == csr_addr;

/* Sync counter  */
reg [10:0] r_count;
reg [10:0] r_count1;
always @(posedge sys_clk) begin
	r_count1 <= rx_count_0;
	r_count <= r_count1;

end

always @(posedge sys_clk) begin
	if(sys_rst) begin
		csr_do <= 32'd0;
		r_enable <= 1'd1;
		r_reset <= 1'd0;

	end else begin
		csr_do <= 32'd0;
		if(csr_selected) begin
			if(csr_we) begin
				case(csr_a[2:0])
					3'd0: r_reset <= csr_di[0];
					3'd1: r_enable <= csr_di[0];
				endcase
			end
			case(csr_a[2:0])
				3'd0: csr_do <= r_reset;
				3'd1: csr_do <= r_enable;
				3'd2: csr_do <= r_count;
				3'd4: csr_do <= 32'h11223344;
			endcase
		end
	end
end
endmodule
