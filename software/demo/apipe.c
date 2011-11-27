/*
 * Milkymist SoC (Software)
 * Copyright (C) 2007, 2008, 2009, 2010 Sebastien Bourdeauducq
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

#include <stdio.h>
#include <board.h>

#include <hal/brd.h>
#include <hal/snd.h>
#include <hal/pfpu.h>
#include <hal/time.h>
#include <hal/dmx.h>

#include "analyzer.h"
#include "eval.h"
#include "cpustats.h"
#include "rpipe.h"
#include "apipe.h"

/* Also used as frame rate limiter */
#define NSAMPLES (48000/25)

static short audiobuffer1[NSAMPLES*2];
static short audiobuffer2[NSAMPLES*2];
static short audiobuffer3[NSAMPLES*2];

static int run_analyzer_bottom_half;
static short *analyzer_buffer;
static int peak_bass, peak_mid, peak_treb;
static float bass_att, mid_att, treb_att;

static volatile int eval_ready;

static struct rpipe_frame frame1 __attribute__((aligned(8)));
static struct rpipe_frame frame2 __attribute__((aligned(8)));
static volatile int frame1_free;
static volatile int frame2_free;

static struct rpipe_frame *alloc_rpipe_frame()
{
	if(frame1_free) return &frame1;
	if(frame2_free) return &frame2;
	return NULL;
}

static void refill_rpipe_frame(struct rpipe_frame *rpipe_frame)
{
	if(rpipe_frame == &frame1) frame1_free = 1;
	else if(rpipe_frame == &frame2) frame2_free = 1;
	else printf("API: trying to refill unknown rpipe frame\n");
}

static void free_rpipe_frame(struct rpipe_frame *rpipe_frame)
{
	snd_record_refill(rpipe_frame->samples);
	refill_rpipe_frame(rpipe_frame);
}

void apipe_init()
{
	run_analyzer_bottom_half = 0;
	peak_bass = 1200000/5;
	peak_mid =  1000000/5;
	peak_treb =  900000/5;
	bass_att = 0.0;
	mid_att = 0.0;
	treb_att = 0.0;
	eval_ready = 1;
	frame1_free = 1;
	frame2_free = 1;
	printf("API: analysis pipeline ready\n");
}

static void apipe_snd_callback(short *buffer, void *user)
{
	if(!eval_ready) {
		/* Skip this buffer */
		snd_record_refill(buffer);
		return;
	}
	analyzer_buffer = buffer;
	run_analyzer_bottom_half = 1;
}

static float brightness_error;

void apipe_start()
{
	brightness_error = 0.0;
	snd_record_empty();
	snd_record_refill(audiobuffer1);
	snd_record_refill(audiobuffer2);
	snd_record_refill(audiobuffer3);
	snd_record_start(apipe_snd_callback, NSAMPLES, NULL);
}

void apipe_stop()
{
	snd_record_stop();
	run_analyzer_bottom_half = 0;
	while(!(eval_ready && frame1_free && frame2_free)) rpipe_service();
}

static struct pfpu_td pfpu_td;

//#define DUMP_MESH

static void pvv_callback(struct pfpu_td *td)
{
	struct rpipe_frame *rpipe_frame;
	#ifdef DUMP_MESH
	int x, y;
	#endif

	rpipe_frame = (struct rpipe_frame *)td->user;

	#ifdef DUMP_MESH
	for(y=0;y<=2;y++) {
		for(x=0;x<=2;x++)
			printf("(%02d %02d) ", rpipe_frame->vertices[y][x].x, rpipe_frame->vertices[y][x].y);
		printf("\n");
	}
	printf("\n");
	#endif

	if(!rpipe_input(rpipe_frame)) free_rpipe_frame(rpipe_frame);
	eval_ready = 1;
}

static void pfv_callback(struct pfpu_td *td)
{
	struct rpipe_frame *rpipe_frame;
	int ibrightness;

	rpipe_frame = (struct rpipe_frame *)td->user;

	brightness_error += eval_read_pfv(pfv_decay);
	ibrightness = 64.0*brightness_error;
	brightness_error -= (float)ibrightness/64.0;
	if(ibrightness > 64) ibrightness = 64;
	rpipe_frame->brightness = ibrightness - 1;

	rpipe_frame->wave_mode = eval_read_pfv(pfv_wave_mode);
	rpipe_frame->wave_scale = eval_read_pfv(pfv_wave_scale);
	rpipe_frame->wave_additive = eval_read_pfv(pfv_wave_additive) != 0.0;
	rpipe_frame->wave_usedots = eval_read_pfv(pfv_wave_usedots) != 0.0;
	rpipe_frame->wave_brighten = eval_read_pfv(pfv_wave_brighten) != 0.0;
	rpipe_frame->wave_thick = eval_read_pfv(pfv_wave_thick) != 0.0;
	
	rpipe_frame->wave_x = eval_read_pfv(pfv_wave_x);
	rpipe_frame->wave_y = 1.0 - eval_read_pfv(pfv_wave_y);
	rpipe_frame->wave_r = eval_read_pfv(pfv_wave_r);
	rpipe_frame->wave_g = eval_read_pfv(pfv_wave_g);
	rpipe_frame->wave_b = eval_read_pfv(pfv_wave_b);
	rpipe_frame->wave_a = eval_read_pfv(pfv_wave_a);

	rpipe_frame->ob_size = eval_read_pfv(pfv_ob_size);
	rpipe_frame->ob_r = eval_read_pfv(pfv_ob_r);
	rpipe_frame->ob_g = eval_read_pfv(pfv_ob_g);
	rpipe_frame->ob_b = eval_read_pfv(pfv_ob_b);
	rpipe_frame->ob_a = eval_read_pfv(pfv_ob_a);

	rpipe_frame->ib_size = eval_read_pfv(pfv_ib_size);
	rpipe_frame->ib_r = eval_read_pfv(pfv_ib_r);
	rpipe_frame->ib_g = eval_read_pfv(pfv_ib_g);
	rpipe_frame->ib_b = eval_read_pfv(pfv_ib_b);
	rpipe_frame->ib_a = eval_read_pfv(pfv_ib_a);

	rpipe_frame->mv_x = eval_read_pfv(pfv_mv_x);
	rpipe_frame->mv_y = eval_read_pfv(pfv_mv_y);
	rpipe_frame->mv_dx = eval_read_pfv(pfv_mv_dx);
	rpipe_frame->mv_dy = eval_read_pfv(pfv_mv_dy);
	rpipe_frame->mv_l = eval_read_pfv(pfv_mv_l);
	rpipe_frame->mv_r = eval_read_pfv(pfv_mv_r);
	rpipe_frame->mv_g = eval_read_pfv(pfv_mv_g);
	rpipe_frame->mv_b = eval_read_pfv(pfv_mv_b);
	rpipe_frame->mv_a = eval_read_pfv(pfv_mv_a);

	rpipe_frame->tex_wrap = eval_read_pfv(pfv_tex_wrap) != 0.0;

	rpipe_frame->vecho_alpha = eval_read_pfv(pfv_video_echo_alpha);
	rpipe_frame->vecho_zoom = eval_read_pfv(pfv_video_echo_zoom);
	rpipe_frame->vecho_orientation = eval_read_pfv(pfv_video_echo_orientation);

	rpipe_frame->dmx1 = eval_read_pfv(pfv_dmx1);
	rpipe_frame->dmx2 = eval_read_pfv(pfv_dmx2);
	rpipe_frame->dmx3 = eval_read_pfv(pfv_dmx3);
	rpipe_frame->dmx4 = eval_read_pfv(pfv_dmx4);

	eval_transfer_pvv_regs();
	eval_pvv_fill_td(&pfpu_td, &rpipe_frame->vertices[0][0], pvv_callback, rpipe_frame);
	pfpu_submit_task(&pfpu_td);
}

static void analyzer_bottom_half()
{
	struct analyzer_state analyzer;
	int bass, mid, treb;
	float fbass, fmid, ftreb;
	float time;
	int i;
	struct rpipe_frame *rpipe_frame;
	struct timestamp ts;

	rpipe_frame = alloc_rpipe_frame();
	if(rpipe_frame == NULL) {
		snd_record_refill(analyzer_buffer);
		return; /* drop this buffer */
	}

	rpipe_frame->nsamples = NSAMPLES;
	rpipe_frame->samples = analyzer_buffer;
	rpipe_frame->callback = free_rpipe_frame;

	analyzer_init(&analyzer);
	for(i=0;i<NSAMPLES;i++)
		analyzer_put_sample(&analyzer, analyzer_buffer[2*i], analyzer_buffer[2*i+1]);

	bass = analyzer_get_bass(&analyzer);
	mid = analyzer_get_mid(&analyzer);
	treb = analyzer_get_treb(&analyzer);
	// TODO: appropriate scaling
	fbass = (float)bass/(float)peak_bass;
	fmid = (float)mid/(float)peak_mid;
	ftreb = (float)treb/(float)peak_treb;

	treb_att = 0.6f*treb_att + 0.4f*ftreb;
	mid_att = 0.6f*mid_att + 0.4f*fmid;
	bass_att = 0.6f*bass_att + 0.4f*fbass;

	time_get(&ts);
	time = (float)ts.sec + (float)ts.usec/1000000.0;

	eval_reinit_all_pfv();
	
	eval_write_pfv(pfv_time, time);
	eval_write_pfv(pfv_bass, fbass);
	eval_write_pfv(pfv_mid, fmid);
	eval_write_pfv(pfv_treb, ftreb);
	eval_write_pfv(pfv_bass_att, bass_att);
	eval_write_pfv(pfv_mid_att, mid_att);
	eval_write_pfv(pfv_treb_att, treb_att);

	eval_write_pfv(pfv_idmx1, ((float)dmx_get(0))/255.0);
	eval_write_pfv(pfv_idmx2, ((float)dmx_get(1))/255.0);
	eval_write_pfv(pfv_idmx3, ((float)dmx_get(2))/255.0);
	eval_write_pfv(pfv_idmx4, ((float)dmx_get(3))/255.0);

	rpipe_frame->time = time;
	rpipe_frame->treb = ftreb;

	eval_pfv_fill_td(&pfpu_td, pfv_callback, rpipe_frame);
	pfpu_submit_task(&pfpu_td);
}

void apipe_service()
{
	if(run_analyzer_bottom_half) {
		cpustats_enter();
		eval_ready = 0;
		run_analyzer_bottom_half = 0;
		analyzer_bottom_half();
		cpustats_leave();
	}
}
