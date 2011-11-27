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

module namuru (
	input sys_clk,
	input sys_rst,

	/* WISHBONE to access RAM */
	input [31:0] wb_adr_i,
	output [31:0] wb_dat_o,
	input [31:0] wb_dat_i,
	input [3:0] wb_sel_i,
	input wb_stb_i,
	input wb_cyc_i,
	output wb_ack_o,
	input wb_we_i,

        /* From GPS Receiver */
        //input gps_rec_clk,
	input gps_rec_sign,
	input gps_rec_mag,

	/* correlator specific */
	output accum_interrupt,

	/* visual indicator */
	output gps_led,

	/* Debug */
	output debug_s,
	output debug_p,
	output debug_c


);

gps_channel_correlator gps_correlator (
	.correlator_clk(sys_clk),
	.correlator_rst(sys_rst),
	.sign(gps_rec_sign),
	.mag(gps_rec_mag),
	.accum_int(accum_interrupt),
	.wb_adr_i(wb_adr_i),
	.wb_dat_o(wb_dat_o),
	.wb_dat_i(wb_dat_i),
	.wb_sel_i(),
	.wb_stb_i(wb_stb_i),
	.wb_cyc_i(wb_cyc_i),
	.wb_ack_o(wb_ack_o),
	.wb_we_i(wb_we_i),
	.gps_led(gps_led)
);
endmodule
