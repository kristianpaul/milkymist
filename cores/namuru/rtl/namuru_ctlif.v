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

module namuru_ctlif #(
	parameter csr_addr = 5'h0
) (
	input sys_clk,
	input sys_rst,

	input [14:0] csr_a,
	input csr_we,
	input [31:0] csr_di,
	output reg [31:0] csr_do,

	input rstn,
	input tic_divide,
	input accum_divide,
	input pre_tic_enable,
	input tic_enable,
	input accum_enable,
	input accum_sample_enable,
	input tic_count,
	input accum_count,
	
	input reg [9:0] ch0_prn_key,
	input reg [27:0] ch0_carr_nco,
	input reg [28:0] ch0_code_nco,
	input reg [10:0]ch0_code_slew,
	input reg [10:0] ch0_epoch_load,
	input reg ch0_prn_key_enable,
	input reg ch0_slew_enable,
	input reg ch0_epoch_enable,
	input ch0_dump,
	input [15:0] ch0_i_early,
	input [15:0] ch0_q_early,
	input [15:0] ch0_i_prompt,
	input [15:0] ch0_q_prompt,
	input [15:0] ch0_i_late,
	input [15:0] ch0_q_late,
	input [31:0] ch0_carrier_val,
	input [20:0] ch0_code_val,
	input [10:0] ch0_epoch,
	input [10:0] ch0_epoch_check

);
wire csr_selected = csr_a[14:10] == csr_addr;
/* control registers */
reg [23:0] prog_tic;
reg [23:0] prog_accum_int;

/* status registers */
reg [1:0] status; // TIC = bit 0, ACCUM_INT = bit 1, cleared on read
reg status_read; // pulse when status register is read
reg [11:0] new_data; // chan0 = bit 0, chan1 = bit 1 etc, cleared on read
reg new_data_read; // pules when new_data register is read
reg [11:0] dump_mask; // mask a channel that has a dump aligned with the new data read
reg [11:0] dump_mask_2; // mask for two clock cycles


always @(posedge sys_clk) begin
	if(sys_rst) begin
		rstn <= 1'd0;
		prog_tic <= 24'd0;
		prog_accum_int <= 24'd0;

	end else begin
		csr_do <= 32'd0;
		if(csr_selected) begin
			if(csr_we) begin
				case(csr_a[2:0])
					/*  control */
					3'd0: rstn <= csr_di[23:0];
					3'd1: prog_tic <= csr_di[23:0];
					3'd2: prog_accum_int <= csr_di[23:0];

					/* this will be messy from here unless
					* we move tracking channels to
					* wishbone */
					/* channel 0 */
				endcase
			end
			case(csr_a[2:0])
					/*  status */
				3'd0: csr_do <= xx;
				3'd1: csr_do <= xx;
				3'd2: csr_do <= xx;
				3'd4: csr_do <= xx;
					/* this will be messy from here unless
					* we move tracking channels to
					* wishbone */
					/* channel 0 */
			endcase
		end
	end
end
assign tic_divide = prog_tic;
assign accum_divide = prog_accum_int;

endmodule
