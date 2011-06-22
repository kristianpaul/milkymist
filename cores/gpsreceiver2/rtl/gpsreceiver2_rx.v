/*
 * Milkymist SoC
 * Copyright (C) 2007, 2008, 2009, 2010, 2011 Sebastien Bourdeauducq
 * Copyleft 2011 Cristian Paul Pen~aranda Rojas
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

module gpsreceiver2_rx(

	/* from gps front end */
	input gps_rec_clk,
	input gps_rec_sync,
	input gps_rec_data,
	
	output rxb0_clk,
	output [7:0] rxb0_dat,

	output gps_led

);
/* Serial to Parallel */
reg [7:0] iq_rx_data;
always @(posedge gps_rec_clk) begin
	iq_rx_data <= {gps_rec_data,iq_rx_data[7:1]};
end

assign rxb0_dat = iq_rx_data;

/* clock pulse for byte sync */
reg sync_counter = 1'b0;
always @(posedge gps_rec_sync) begin
	sync_counter <= sync_counter + 1;
end

reg sync_clk;
always @(gps_rec_clk) begin
	if(~sync_counter & gps_rec_sync)
		sync_clk = 1'b1;
	else
		sync_clk = 1'b0;
end

assign  rxb0_clk = sync_clk;


/* Silly  Debug */
reg [22:0]  counter = 23'b0;
always @(posedge rxb0_clk) begin
	counter <= counter + 1;
end
assign gps_led = counter[21];

endmodule
