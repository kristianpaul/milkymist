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
	input gps_rec_mag

	//output accum_int

	/* Debug */
	//output gps_led
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
reg stb_i0;
reg stb_i1;
reg stb_i2;
reg stb_i3;

always @(posedge gps_rec_clk) begin
	stb_i0 <= wb_stb_i;
	stb_i1 <= stb_i0;
	stb_i2 <= stb_i1;
	stb_i3 <= stb_i2;
end

assign wb_stb_i_sync = stb_i3;
/* cyc */
reg cyc_i0;
reg cyc_i1;
reg cyc_i2;
reg cyc_i3;

always @(posedge gps_rec_clk) begin
	cyc_i0 <= wb_cyc_i;
	cyc_i1 <= cyc_i0;
	cyc_i2 <= cyc_i1;
	cyc_i3 <= cyc_i2;
end

assign wb_cyc_i_sync = cyc_i3;

/* we */
reg we_i0;
reg we_i1;
reg we_i2;
reg we_i3;

always @(posedge gps_rec_clk) begin
	we_i0 <= wb_we_i;
	we_i1 <= we_i0;
	we_i2 <= we_i1;
	we_i3 <= we_i2;
end

assign wb_we_i_sync = we_i3;

gps_channel_correlator gps_correlator (
	.sys_clk(gps_rec_clk),
	.sys_rst(sys_rst_sync),
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
namuru_psync system_ack(
	.clk1(gps_rec_clk),
	.i(wb_ack_o_sync),
	.clk2(sys_clk),
	.o(wb_ack_o)
);

endmodule
