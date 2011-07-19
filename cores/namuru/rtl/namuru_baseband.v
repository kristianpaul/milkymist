/*
 * Milkymist VJ SoC
 * Copyright (C) 2007, 2008, 2009 Sebastien Bourdeauducq
 * Copyleft 2011, Cristian Paul 
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

module gps_channel_correlator(
	/* correlator specific */
	input correlator_clk,
	input correlator_rst,
	input sign,
	input mag,
	output reg accum_int, // interrupt pulse to tell FW to collect accumulation data, cleared on STATUS read
	
	/* WB */
	input [31:0] wb_adr_i,
	input [31:0] wb_dat_i,
	output [31:0] wb_dat_o,
	input [3:0] wb_sel_i,
	input wb_cyc_i,
	input wb_stb_i,
	input wb_we_i,
	output reg wb_ack_o
);
// at least you want to align this in software
wire [31:0] wb_dat_i_le = {wb_dat_i[7:0], wb_dat_i[15:8], wb_dat_i[23:16], wb_dat_i[31:24]};

wire accum_enable_s;
wire pre_tic_enable, tic_enable, accum_sample_enable;

wire [23:0] tic_count;
wire [23:0] accum_count;

reg sw_rst; // reset to tracking module
wire rstn; // software generated reset 

// channel 0 registers
reg [9:0] ch0_prn_key;
reg [28:0] ch0_carr_nco;
reg [27:0] ch0_code_nco;
reg [10:0] ch0_code_slew;
reg [10:0] ch0_epoch_load;
reg ch0_prn_key_enable, ch0_slew_enable, ch0_epoch_enable;
wire ch0_dump;
wire [15:0] ch0_i_early, ch0_q_early, ch0_i_prompt, ch0_q_prompt, ch0_i_late, ch0_q_late;
wire [31:0] ch0_carrier_val;
wire [20:0] ch0_code_val;
wire [10:0] ch0_epoch, ch0_epoch_check;

// status registers
reg [1:0] status; // TIC = bit 0, ACCUM_INT = bit 1, cleared on read
reg status_read; // pulse when status register is read
reg [11:0] new_data; // chan0 = bit 0, chan1 = bit 1 etc, cleared on read
reg new_data_read; // pules when new_data register is read
reg [11:0] dump_mask; // mask a channel that has a dump aligned with the new data read
reg [11:0] dump_mask_2; // mask for two clock cycles

// control registers
reg [23:0] prog_tic;
reg [23:0] prog_accum_int;

// connect up time base
time_base tb (
	.clk(correlator_clk),
	.rstn(rstn),
	.tic_divide(prog_tic),
	.accum_divide(prog_accum_int),
	.pre_tic_enable(pre_tic_enable),
	.tic_enable(tic_enable),
	.accum_enable(accum_enable_s),
	.tic_count(tic_count),
	.accum_count(accum_count)
);
assign rstn = !correlator_rst & !sw_rst; //TODO ~correlator_rst should be, so  1 & 1 (sw_rst default 0)

// connect up tracking channels
tracking_channel tc0 (
	.clk(correlator_clk),
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

// process to create a two clk wide dump_mask pulse
always @ (posedge correlator_clk) begin
	if (!rstn)
		dump_mask_2 <= 0;
	else
		dump_mask_2 <= dump_mask;
end

// process to reset the status register after a read
// also create accum_int signal that is cleared after status read
always @ (posedge correlator_clk) begin
	if (!rstn || status_read)
	begin
		status <= 0;
		accum_int <= 0;
	end else begin
		if (tic_enable)
			status[0] <= 1;
		if (accum_enable_s)
		begin
			status[1] <= 1;
			accum_int <= 1;
		end
	end
end

// process to reset the new_data register after a read
// set new data bits when channel dumps occur
always @ (posedge correlator_clk) begin
	if (!rstn || new_data_read)
	begin
		new_data <= dump_mask | dump_mask_2;
	end else begin
		if (ch0_dump)
			new_data[0] <= 1;
	end
end


reg next_csr_we;
reg [31:0] wb_dat_o_le;
always @(posedge correlator_clk) begin
	        if(correlator_rst) begin
			wb_dat_o_le <= 32'd0;
			ch0_prn_key_enable <= 1'b0;
			ch0_prn_key <= 10'b0;
			ch0_carr_nco <= 29'd0;// Need to initialize nco's (at least for simulation) or they don't run.
			ch0_code_nco <= 28'd0;
			ch0_slew_enable <= 1'b0;
			ch0_code_slew <= 11'b0;
			ch0_epoch_enable <=  1'b0;
			ch0_epoch_load <= 11'b0;

			sw_rst <= 1'b0;
			
		end else begin
			wb_dat_o_le <= 32'd0;
			if(next_csr_we) begin
				/* write */
				case(wb_adr_i[9:2])
				/* channel 0 */
				8'h00: begin
					ch0_prn_key_enable <= 1'b1; 
					ch0_prn_key <= wb_dat_i_le[9:0];
				end
				8'h01: ch0_carr_nco <= wb_dat_i_le[28:0];
				8'h02: ch0_code_nco <= wb_dat_i_le[27:0];
				8'h03: begin
					ch0_slew_enable <= 1'b1;
					ch0_code_slew <= wb_dat_i_le[10:0];
				end
				8'h0E : begin
					ch0_epoch_enable <=  1'b1;
					ch0_epoch_load <= wb_dat_i_le[10:0];
				end

				/* status */ 
				/* nothing to write */

				/* control */ 
				8'hF0: sw_rst <= 1'b1; // software reset
				8'hF1: prog_tic <= wb_dat_i_le[23:0]; // program TIC
				8'hF2: prog_accum_int <= wb_dat_i_le[23:0]; // program ACCUM_INT

				endcase
			end
			/* read */
			case(wb_adr_i[9:2])
			/* channel 0 */
			8'h04: wb_dat_o_le <= {16'h0, ch0_i_early};
			8'h05: wb_dat_o_le <= {16'h0, ch0_q_early};
			8'h06: wb_dat_o_le <= {16'h0, ch0_i_prompt};
			8'h07: wb_dat_o_le <= {16'h0, ch0_q_prompt};
			8'h08: wb_dat_o_le <= {16'h0, ch0_i_late};
			8'h09: wb_dat_o_le <= {16'h0, ch0_q_late};
			8'h0A: wb_dat_o_le <= ch0_carrier_val; // 32 bits
			8'h0B: wb_dat_o_le <= {11'h0, ch0_code_val}; // 21 bits
			8'h0C: wb_dat_o_le <= {21'h0, ch0_epoch}; // 11 bits
			8'h0D: wb_dat_o_le <= {21'h0, ch0_epoch_check}; // 11 bits

			/* status */ 
			8'hE0: begin // get status and pulse status_flag to clear status
				wb_dat_o_le <= {30'h0, status}; // only 2 status bits, therefore need to pad 30ms bits
				status_read <= 1'b1; // pulse status flag to clear status register
			end
			8'hE1: begin // get new_data
				wb_dat_o_le <= {30'h0,new_data}; //one new_data bit per channel, need to pad other bits
				// pulse the new data flag to clear new_data register
				new_data_read <= 1'b1;
				// make sure the flag is not cleared if a dump is aligned to new_data_read
				dump_mask[0] <= ch0_dump;
				/* more channels to come */
			end
			8'hE2: begin // tic count read
				wb_dat_o_le <= {8'h0,tic_count}; // 24 bits of TIC count
			end
			8'hE3: begin // accum count read
				wb_dat_o_le <= {8'h0,accum_count}; // 24 bits of accum count
			end
			8'hEF: begin // accum count read
				wb_dat_o_le <= 32'h14091987; // HW_TAG
			end
				/* control */ 
				/* nothing to read */
			endcase
		end
	end
// at least you want to align this in software
assign wb_dat_o = {wb_dat_o_le[7:0], wb_dat_o_le[15:8], wb_dat_o_le[23:16], wb_dat_o_le[31:24]};

reg [1:0] state;
reg [1:0] next_state;

parameter IDLE		= 2'd0;
parameter DELAYACK1	= 2'd1;
parameter DELAYACK2	= 2'd2;
parameter ACK		= 2'd3;

always @(posedge correlator_clk) begin
	if(correlator_rst)
		state <= IDLE;
	else
		state <= next_state;
end

always @(*) begin
	next_state = state;
	
	wb_ack_o = 1'b0;
	next_csr_we = 1'b0;
	
	case(state)
		IDLE: begin
			if(wb_cyc_i & wb_stb_i) begin
				/* We have a request for us */
				next_csr_we = wb_we_i;
				if(wb_we_i)
					next_state = ACK;
				else
					next_state = DELAYACK1;
			end
		end
		DELAYACK1: next_state = DELAYACK2;
		DELAYACK2: next_state = ACK;
		ACK: begin
			wb_ack_o = 1'b1;
			next_state = IDLE;
		end
	endcase
end

endmodule
