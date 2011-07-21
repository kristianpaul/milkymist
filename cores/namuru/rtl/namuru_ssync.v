/*
 * Milkymist SoC GPS-SDR
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

module namuru_ssync(
	input i,
	input clks,
	input o
);

reg level1;
reg level2;
reg level3;
reg level4;
always @(posedge clkss) begin
	level1 <= i;
	level2 <= level1;
	level3 <= level2;
	level4 <= level3;
end

//assign o = level3 & level4;
assign o = level4;

initial begin
	level1 <= 1'b0;
	level2 <= 1'b0;
	level3 <= 1'b0;
	level4 <= 1'b0;
end

endmodule
