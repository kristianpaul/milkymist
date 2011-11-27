/*
 * Milkymist SoC (Software)
 * Copyright (C) 2007, 2008, 2009, 2010, 2011 Sebastien Bourdeauducq
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

#ifndef __MEMSTATS_H
#define __MEMSTATS_H

void memstats_init();
void memstats_tick();
unsigned int memstat_occupancy();	/* < Memory bus occupancy in % */
unsigned int memstat_net_bandwidth();	/* < Net bandwidth computed on data actually transferred, Mb/s */
unsigned int memstat_amat(); 		/* < Average Memory Access Time, in 1/100 cycles */

void memstat_capture_start();
int memstat_capture_ready();
unsigned int memstat_capture_get(int index);

#endif /* __MEMSTATS_H */
