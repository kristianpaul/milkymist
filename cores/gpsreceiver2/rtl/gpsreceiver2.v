/*
 * Milkymist SoC GPS-SDR
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

module gpsreceiver2 #(
	parameter csr_addr = 5'h0
) (
	input sys_clk,
	input sys_rst,

	/* CSR */
	input [14:0] csr_a,
	input csr_we,
	input [31:0] csr_di,
	output [31:0] csr_do,

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
	input gps_rec_sync,
	input gps_rec_data,

	/* Debug */
	output gps_led 	
);

wire rxb0_clk;
wire [7:0] rxb0_dat;
wire [10:0] rxb0_adr;
wire rxb0_we;
wire [10:0] rx_count_0;

/* Config */
gpsreceiver2_ctlif #(
	.csr_addr(csr_addr)
) ctlif (
	.sys_clk(sys_clk),
	.sys_rst(sys_rst),

	.csr_a(csr_a),
	.csr_we(csr_we),
	.csr_di(csr_di),
	.csr_do(csr_do),

	.rx_count_0(rx_count_0),
	.r_enable(r_enable),
	.r_reset(r_reset)
);

/* Buffer */
gpsreceiver2_memory memory(
	.sys_clk(sys_clk),
	.sys_rst(sys_rst),

	.wb_adr_i(wb_adr_i),
	.wb_dat_o(wb_dat_o),
	.wb_dat_i(wb_dat_i),
	.wb_sel_i(wb_sel_i),
	.wb_stb_i(wb_stb_i),
	.wb_cyc_i(wb_cyc_i),
	.wb_ack_o(wb_ack_o),
	.wb_we_i(wb_we_i),
	
	.rxb0_clk(rxb0_clk),
	.rxb0_dat(rxb0_dat),
	.rxb0_adr(rxb0_adr),
	.rxb0_we(rxb0_we)
);

/* From GPS Receiver */
gpsreceiver2_rx rx(
	.gps_rec_clk(gps_rec_clk),
	.gps_rec_sync(gps_rec_sync),
	.gps_rec_data(gps_rec_data),

	.rxb0_clk(rxb0_clk),
	.rxb0_dat(rxb0_dat),

	.gps_led(gps_led)
);

/* Counter */
gpsreceiver2_counter counter(
	.rxb0_clk(rxb0_clk),
	.rxb0_adr(rxb0_adr),
	.rxb0_we(rxb0_we),

	.r_enable(r_enable),
	.r_reset(r_reset),
	.rx_count_0(rx_count_0)
);

endmodule
