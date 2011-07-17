/*
 * Milkymist SoC
 * Copyright (C) 2007, 2008, 2009, 2010, 2011 Sebastien Bourdeauducq
 * Copyleft 2011 Cristian Paul
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

module tb_namuru();

/* 100MHz system clock */
reg sys_clk;
initial sys_clk = 1'b0;
always #5 sys_clk = ~sys_clk;

/* 25MHz gps receiver clock */
reg gps_rec_clk;
initial gps_rec_clk = 1'b0;
always #5 gps_rec_clk = ~gps_rec_clk;

reg [31:0] wb_adr_i;
reg [31:0] wb_dat_i;
wire [31:0] wb_dat_o;
reg wb_cyc_i;
reg wb_stb_i;
reg wb_we_i;
wire wb_ack_o;
reg sys_rst;

namuru baseband (
	.sys_clk(sys_clk),
	.sys_rst(sys_rst),

	.wb_adr_i(wb_adr_i),
	.wb_dat_i(wb_dat_i),
	.wb_dat_o(wb_dat_o),
	.wb_cyc_i(wb_cyc_i),
	.wb_stb_i(wb_stb_i),
	.wb_we_i(wb_we_i),
	.wb_sel_i(4'hf),
	.wb_ack_o(wb_ack_o),

	.gps_rec_clk(gps_rec_clk),
	.gps_rec_sign(),
	.gps_rec_mag()
);

task waitclock;
begin
	@(posedge sys_clk);
	#1;
end
endtask

task wbwrite;
input [31:0] address;
input [31:0] data;
integer i;
begin
	wb_adr_i = address;
	wb_dat_i = data;
	wb_cyc_i = 1'b1;
	wb_stb_i = 1'b1;
	wb_we_i = 1'b1;
	i = 0;
	while(~wb_ack_o) begin
		i = i+1;
		waitclock;
	end
	waitclock;
	$display("WB Write: %x=%x acked in %d clocks", address, data, i);
	wb_cyc_i = 1'b0;
	wb_stb_i = 1'b0;
	wb_we_i = 1'b0;
end
endtask

task wbread;
input [31:0] address;
integer i;
begin
	wb_adr_i = address;
	wb_cyc_i = 1'b1;
	wb_stb_i = 1'b1;
	wb_we_i = 1'b0;
	i = 0;
	while(~wb_ack_o) begin
		i = i+1;
		waitclock;
	end
	$display("WB Read : %x=%x acked in %d clocks", address, wb_dat_o, i);
	waitclock;
	wb_cyc_i = 1'b0;
	wb_stb_i = 1'b0;
	wb_we_i = 1'b0;
end
endtask

initial begin
	/* Reset / Initialize our logic */
	sys_rst = 1'b1;
//	gps_rec_clk = 1'b1;

	waitclock;

	sys_rst = 1'b0;
	//gps_rec_clk = 1'b0;

	waitclock;

	//wbwrite(32'b00000, 32'h12345678);
	wbread(32'h3bc); //hw id EF
	wbread(32'b1110111100); //hw id EF
	wbread(32'h380); //status E0
	wbread(32'h384); //new_data E1
//	wbread(32'h388); //tic_count E2

	#5000;

	$finish;
end

endmodule
