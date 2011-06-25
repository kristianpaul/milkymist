/*
 * Milkymist SoC GPS-SDR
 * Copyright (C) 2007, 2008, 2009, 2010, 2011 Sebastien Bourdeauducq
 * Copyleft 2011 Cristian Paul Pen~arada Rojas
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

module gpsreceiver2_memory(
	input sys_clk,
	input sys_rst,
	input rxb0_clk,
	
	input [31:0] wb_adr_i,
	output [31:0] wb_dat_o,
	input [31:0] wb_dat_i,
	input [3:0] wb_sel_i,
	input wb_stb_i,
	input wb_cyc_i,
	output reg wb_ack_o,
	input wb_we_i,
	
	input [7:0] rxb0_dat,
	input [10:0] rxb0_adr,
	input rxb0_we

);

wire wb_en = wb_cyc_i & wb_stb_i;
wire [1:0] wb_buf = wb_adr_i[12:11];
wire [31:0] wb_dat_i_le = {wb_dat_i[7:0], wb_dat_i[15:8], wb_dat_i[23:16], wb_dat_i[31:24]};
wire [3:0] wb_sel_i_le = {wb_sel_i[0], wb_sel_i[1], wb_sel_i[2], wb_sel_i[3]};

RAMB16BWER #(
	.DATA_WIDTH_A(36),
	.DATA_WIDTH_B(9),
	.DOA_REG(0),
	.DOB_REG(0),
	.EN_RSTRAM_A("FALSE"),
	.EN_RSTRAM_B("FALSE"),
	.SIM_DEVICE("SPARTAN6"),
	.WRITE_MODE_A("READ_FIRST"),
	.WRITE_MODE_B("READ_FIRST")
//	.WRITE_MODE_A("WRITE_FIRST"),
//	.WRITE_MODE_B("WRITE_FIRST")
) rxb0 (
	.DIA(wb_dat_i_le),
	.DIPA(4'd0),
	.DOA(rxb0_dat),
	.ADDRA({wb_adr_i[10:2], 5'd0}),
	.WEA({4{wb_en & wb_we_i & (wb_buf == 2'b00)}} & wb_sel_i_le),
	.ENA(1'b1),
	.RSTA(1'b0),
	.CLKA(sys_clk),

	.DIB(rxb0_dat),
	.DIPB(1'd0),
	.DOB(),
	.ADDRB({rxb0_adr, 3'd0}),
	.WEB({4{1'b1}}), //HACK
	.ENB(1'b1),
	.RSTB(1'b0),
	.CLKB(rxb0_clk)
);

always @(posedge sys_clk) begin
	if(sys_rst)
		wb_ack_o <= 1'b0;
	else begin
		wb_ack_o <= 1'b0;
		if(wb_en & ~wb_ack_o)
			wb_ack_o <= 1'b1;
	end
end

assign wb_dat_o = {rxb0_wbdat[7:0], rxb0_wbdat[15:8], rxb0_wbdat[23:16], rxb0_wbdat[31:24]};

endmodule
