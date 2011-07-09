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

	output reg rstn,
	input tic_divide,
	input accum_divide,
	input pre_tic_enable,
	input tic_enable,
	input accum_enable,
	input accum_sample_enable,
	input tic_count,
	input accum_count,
	output reg accum_int,  //interrupt
	
	input [9:0] ch0_prn_key,
	input [27:0] ch0_carr_nco,
	input [28:0] ch0_code_nco,
	input [10:0]ch0_code_slew,
	input [10:0] ch0_epoch_load,
	input ch0_prn_key_enable,
	input ch0_slew_enable,
	input ch0_epoch_enable,
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

/* channel 0 registers */
reg [9:0] ch0_prn_key_reg;
reg [28:0] ch0_carr_nco_reg;
reg [27:0] ch0_code_nco_reg;
reg [10:0] ch0_code_slew_reg;
reg [10:0] ch0_epoch_load_reg;
reg ch0_prn_key_enable_reg;
reg ch0_slew_enable_reg;
reg ch0_epoch_enable_reg;


always @(posedge sys_clk) begin
	if(sys_rst) begin
		rstn <= 1'd0;
		prog_tic <= 24'd0;
		prog_accum_int <= 24'd0;

	end else begin
		csr_do <= 32'd0;
		if(csr_selected) begin
			if(csr_we) begin
				case(csr_a[4:0])
					/*  control */
					5'h10: rstn <= csr_di[23:0];
					5'h11: prog_tic <= csr_di[23:0];
					5'h12: prog_accum_int <= csr_di[23:0];

					/* this will be messy from here unless
					* we move tracking channels to
					* wishbone when 12 channels */

					/* channel 0 WRITE */
					5'h0: begin
						ch0_prn_key_enable_reg <= !csr_we;
						ch0_prn_key_reg <= csr_di[9:0];
						end
					5'h1: ch0_carr_nco_reg <= csr_di[28:0];
					5'h2: ch0_code_nco_reg <= csr_di[27:0];
					5'h3: begin
						ch0_slew_enable_reg <= !csr_we;
						ch0_code_slew_reg <= csr_di[9:0];
						end
					/* ..... */
					5'he: begin
						ch0_epoch_enable_reg <= !csr_we;
						ch0_epoch_load_reg <= csr_di[9:0];
						end
				endcase
			end
			case(csr_a[4:0])
					/*  status */
					5'h10: begin
						csr_do <= {30'h0, status};
						status_read <= !csr_we; // pulse status flag to clear status register
					end
					5'h11: begin
						csr_do <= {30'h0,new_data};
						new_data_read <= !csr_we; 
						dump_mask[0] <= ch0_dump;
					end
					5'h12: csr_do <= {8'h0,tic_count};
					5'h13: csr_do <= {8'h0,accum_count};

					/* this will be messy from here unless
					* we move tracking channels to
					* wishbone when 12 channels */

					/* channel 0 READ */
					/* ..... */
					5'h4: csr_do <= {16'h0, ch0_i_early};
					5'h5: csr_do <= {16'h0, ch0_q_early};
					5'h6: csr_do <= {16'h0, ch0_i_prompt};
					5'h7: csr_do <= {16'h0, ch0_q_prompt};
					5'h8: csr_do <= {16'h0, ch0_i_late};
					5'h9: csr_do <= {16'h0, ch0_q_late};
					5'ha: csr_do <= ch0_carrier_val; // 32 bits
					5'hb: csr_do <= {11'h0, ch0_code_val}; // 21 bits
					5'hc: csr_do <= {21'h0, ch0_epoch}; // 11 bits
					5'hd: csr_do <= {21'h0, ch0_epoch_check}; // 11 bits
			endcase
		end
	end
end

/* control regs assigments */
assign tic_divide = prog_tic;
assign accum_divide = prog_accum_int;

/* channel 0 regs assigments */
assign ch0_prn_key = ch0_prn_key_reg;
assign ch0_carr_nco = ch0_carr_nco_reg;
assign ch0_code_nco = ch0_code_nco_reg;
assign ch0_code_slew = ch0_code_slew_reg;
assign ch0_epoch_load = ch0_epoch_load_reg;
assign ch0_prn_key_enable = ch0_prn_key_enable_reg;
assign ch0_slew_enable = ch0_slew_enable_reg;
assign ch0_epoch_enable = ch0_epoch_enable_reg;

/* status registers */
reg [1:0] status; // TIC = bit 0, ACCUM_INT = bit 1, cleared on read
reg status_read; // pulse when status register is read
reg [11:0] new_data; // chan0 = bit 0, chan1 = bit 1 etc, cleared on read
reg new_data_read; // pules when new_data register is read
reg [11:0] dump_mask; // mask a channel that has a dump aligned with the new data read
reg [11:0] dump_mask_2; // mask for two clock cycles
//wire accum_enable_s;

// process to create a two clk wide dump_mask pulse
always @ (posedge sys_clk) begin
	if (!rstn)
		dump_mask_2 <= 0;
	else
		dump_mask_2 <= dump_mask;
end

/* process to reset the status register after a read
   also create accum_int signal that is cleared after status read */

always @ (posedge sys_clk) begin
	if (!rstn || status_read)
	begin
		status <= 0;
		accum_int <= 0;
	end else begin
		if (tic_enable)
			status[0] <= 1;
		if (accum_enable)
		begin
			status[1] <= 1;
			accum_int <= 1;
		end
	end
end

/* process to reset the new_data register after a read
 set new data bits when channel dumps occur */

always @ (posedge sys_clk) begin
	if (!rstn || new_data_read) begin
		new_data <= dump_mask | dump_mask_2;
	end else begin
		if (ch0_dump) 
			new_data[0] <= 1;
	end
end


endmodule
