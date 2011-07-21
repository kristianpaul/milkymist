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
        input gps_rec_clk,
	input gps_rec_sign,
	input gps_rec_mag,

	/* correlator specific */
	output accum_interrupt

	/* Debug */
	//output namuru_nco
);

/*CDC Sync from Master to Slave */
/* reset */
namuru_psync system_rst(
	.clk1(sys_clk),
	.i(sys_rst),
	.clk2(gps_rec_clk),
	.o(sys_rst_sync)
);

/* stb */
namuru_ssync wb_stb_in(
	.clks(gps_rec_clk),
	.i(wb_stb_i),
	.o(wb_stb_i_sync)
);

/* cyc */
namuru_ssync wb_cyc_in(
	.clks(gps_rec_clk),
	.i(wb_cyc_i),
	.o(wb_cyc_i_sync)
);

/* we */
namuru_ssync wb_we_in(
	.clks(gps_rec_clk),
	.i(wb_we_i),
	.o(wb_we_i_sync)
);

gps_channel_correlator gps_correlator (
	.correlator_clk(gps_rec_clk),
	.correlator_rst(sys_rst_sync),
	.sign(gps_rec_sign),
	.mag(gps_rec_mag),
	.accum_int(accum_interrupt),
	.wb_adr_i(wb_adr_i),
	.wb_dat_o(wb_dat_o),
	.wb_dat_i(wb_dat_i),
	.wb_sel_i(),
	.wb_stb_i(wb_stb_i_sync),
	.wb_cyc_i(wb_cyc_i_sync),
	.wb_ack_o(wb_ack_o_sync),
	.wb_we_i(wb_we_i_sync)
);

/*CDC Sync from Slave to Master */
/* ack */
namuru_psync wb_ack_out(
	.clk1(gps_rec_clk),
	.i(wb_ack_o_sync),
	.clk2(sys_clk),
	.o(wb_ack_o)
);

endmodule
