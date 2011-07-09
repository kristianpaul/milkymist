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

module namuru #(
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
	input gps_rec_sign,
	input gps_rec_mag,

	output accum_int

	/* Debug */
	//output gps_led
	//output namuru_nco
);

/* Interconnect wires */
/* control and status */
wire rstn;
wire [23:0] tic_count;
wire [23:0] accum_count;
wire [23:0] prog_tic;
wire [23:0] prog_accum_int;

/* time base */
wire pre_tic_enable;
wire tic_enable;
wire accum_enable_s;
wire accum_sample_enable;

/* channel 0 */
wire [9:0] ch0_prn_key;
wire [28:0] ch0_carr_nco;
wire [27:0] ch0_code_nco;
wire [10:0] ch0_code_slew;
wire [10:0] ch0_epoch_load;
wire ch0_prn_key_enable; 
wire ch0_slew_enable;
wire ch0_epoch_enable;
wire ch0_dump;
wire [15:0] ch0_i_early, ch0_q_early, ch0_i_prompt, ch0_q_prompt, ch0_i_late, ch0_q_late;
wire [31:0] ch0_carrier_val;
wire [20:0] ch0_code_val;
wire [10:0] ch0_epoch, ch0_epoch_check;


/* Registers and Bus Interface */
namuru_ctlif #(
	.csr_addr(csr_addr)
) ctlif (
	.sys_clk(sys_clk),
	.sys_rst(sys_rst),

	.csr_a(csr_a),
	.csr_we(csr_we),
	.csr_di(csr_di),
	.csr_do(csr_do),

	/* int */
	.accum_int(accum_int),

	/* status */
	/* wires from time base registers */
	
	.rstn(rstn),
	.tic_divide(prog_tic),
	.accum_divide(prog_accum_int),
	.pre_tic_enable(pre_tic_enable),
	.tic_enable(tic_enable),
	.accum_enable(accum_enable_s),
	.accum_sample_enable(accum_sample_enable),
	.tic_count(tic_count),
	.accum_count(accum_count),

	/* fow now ctlif but channels should be mapped to wishbone TODO*/

	/* regs and wires from channel 0 */
	.ch0_prn_key(ch0_prn_key),
	.ch0_carr_nco(ch0_carr_nco),
	.ch0_code_nco(ch0_code_nco),
	.ch0_code_slew(ch0_code_slew),
	.ch0_epoch_load(ch0_epoch_load),
	.ch0_prn_key_enable(ch0_prn_key_enable), 
	.ch0_slew_enable(ch0_slew_enable),
	.ch0_epoch_enable(ch0_epoch_enable),
	.ch0_dump(ch0_dump),
	.ch0_i_early(ch0_i_early),
	.ch0_q_early(ch0_q_earlY),
	.ch0_i_prompt(ch0_i_prompt),
	.ch0_q_prompt(ch0_q_prompt),
	.ch0_i_late(ch0_i_lat),
	.ch0_q_late(ch0_q_late),
	.ch0_carrier_val(ch0_carrier_val),
	.ch0_code_val(ch0_code_val),
	.ch0_epoch(ch0_epoch),
	.ch0_epoch_check(ch0_epoch_chec)
);

/* Baseband */
// this will be usefull to 
//gps_baseband  baseband(
//	.gps_rec_clk(gps_rec_clk),
//	.gps_rec_sign(gps_rec_sign),
//	.gps_rec_mag(gps_rec_mag),
//);

//time base
time_base tb (
	.clk(gps_rec_clk), 
	.rstn(rstn),
	.tic_divide(prog_tic),
	.accum_divide(prog_accum_int),
//	.sample_clk(s_clk), // not used here
	.pre_tic_enable(pre_tic_enable),
	.tic_enable(tic_enable),
	.accum_enable(accum_enable_s),
	.accum_sample_enable(accum_sample_enable),
	.tic_count(tic_count),
	.accum_count(accum_count)
);

/* tracking channel 0 */
tracking_channel tc0 (
	.clk(gps_rec_clk), 
	.rstn(rstn),
	.accum_sample_enable(accum_sample_enable),
	.if_sign(sign), 
	.if_mag(mag),
	.pre_tic_enable(pre_tic_enable),
	.tic_enable(tic_enable),
	.carr_nco_fc(ch0_carr_nco),
	.code_nco_fc(ch0_code_nco),
	.prn_key(ch0_prn_key),
	.prn_key_enable(ch0_prn_key_enable),
	.code_slew(ch0_code_slew),
	.slew_enable(ch0_slew_enable),
	.epoch_enable(ch0_epoch_enable),
	.dump(ch0_dump),
	.i_early(ch0_i_early),
	.q_early(ch0_q_early),
	.i_prompt(ch0_i_prompt),
	.q_prompt(ch0_q_prompt),
	.i_late(ch0_i_late),
	.q_late(ch0_q_late),
	.carrier_val(ch0_carrier_val),
	.code_val(ch0_code_val),
	.epoch_load(ch0_epoch_load),
	.epoch(ch0_epoch),
	.epoch_check(ch0_epoch_check)
);
endmodule
