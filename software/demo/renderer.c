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
#include <string.h>
#include <math.h>
#include <system.h>

#include <hal/pfpu.h>
#include <hal/vga.h>

#include "eval.h"
#include "apipe.h"
#include "renderer.h"

int renderer_on;

int renderer_hmeshlast;
int renderer_vmeshlast;
int renderer_texsize;

void renderer_init()
{
	renderer_on = 0;
	renderer_hmeshlast = 32;
	renderer_vmeshlast = 32;
	renderer_texsize = 512;
	printf("RDR: renderer ready (mesh:%dx%d, texsize:%d)\n", renderer_hmeshlast, renderer_vmeshlast, renderer_texsize);
}

static int linenr;

static int process_equation(char *equation, int per_vertex)
{
	char *c, *c2;

	c = strchr(equation, '=');
	if(!c) {
		printf("RDR: error l.%d: malformed equation (%s)\n", linenr, equation);
		return 0;
	}
	*c = 0;

	if(*equation == 0) {
		printf("RDR: error l.%d: missing lvalue\n", linenr);
		return 0;
	}
	c2 = c - 1;
	while((c2 > equation) && (*c2 == ' ')) *c2-- = 0;
	
	c++;
	while(*c == ' ') c++;

	if(*equation == 0) {
		printf("RDR: error l.%d: missing lvalue\n", linenr);
		return 0;
	}
	if(*c == 0) {
		printf("RDR: error l.%d: missing rvalue\n", linenr);
		return 0;
	}

	if(per_vertex)
		return eval_add_per_vertex(linenr, equation, c);
	else
		return eval_add_per_frame(linenr, equation, c);
}

static int process_equations(char *equations, int per_vertex)
{
	char *c;

	while(*equations) {
		c = strchr(equations, ';');
		if(!c)
			return process_equation(equations, per_vertex);
		*c = 0;
		if(!process_equation(equations, per_vertex)) return 0;
		equations = c + 1;
	}
	return 1;
}

static int process_top_assign(char *left, char *right)
{
	int pfv;
	
	while(*right == ' ') right++;
	if(*right == 0) return 1;

	pfv = eval_pfv_from_name(left);
	if(pfv >= 0) {
		/* patch initial condition or global parameter */
		eval_set_initial(pfv, atof(right));
		return 1;
	}

	if(strncmp(left, "per_frame", 9) == 0)
		/* per-frame equation */
		return process_equations(right, 0);

	if((strncmp(left, "per_vertex", 10) == 0) || (strncmp(left, "per_pixel", 9) == 0))
		/* per-vertex equation */
		return process_equations(right, 1);

#ifdef RENDERER_DEBUG
	printf("RDR: warning l.%d: ignoring unknown parameter %s\n", linenr, left);
#endif

	return 1;
}

static int process_line(char *line)
{
	char *c;
	
	while(*line == ' ') line++;
	if(*line == 0) return 1;
	if(*line == '[') return 1;

	c = strstr(line, "//");
	if(c) *c = 0;
	
	c = line + strlen(line) - 1;
	while((c >= line) && (*c == ' ')) *c-- = 0;
	if(*line == 0) return 1;

	c = strchr(line, '=');
	if(!c) {
		printf("RDR: error l.%d: '=' expected\n", linenr);
		return 0;
	}
	*c = 0;
	return process_top_assign(line, c+1);
}

static int load_patch(char *patch_code)
{
	char *eol;
	
	linenr = 0;
	while(*patch_code) {
		linenr++;
		eol = strchr(patch_code, '\n');
		if(!eol)
			return process_line(patch_code);
		*eol = 0;
		if(*patch_code == 0) {
			patch_code = eol + 1;
			continue;
		}
		if(*(eol - 1) == '\r') *(eol - 1) = 0;
		if(!process_line(patch_code)) return 0;
		patch_code = eol + 1;
	}
	return 1;
}

int renderer_start(char *patch_code)
{
	if(renderer_on) renderer_stop();
	eval_init();
	if(!load_patch(patch_code)) return 0;
	if(!eval_schedule()) return 0;
	apipe_start();
	renderer_on = 1;
	vga_set_console(0);
#ifdef RENDERER_DEBUG
	printf("RDR: started\n");
#endif
	return 1;
}

void renderer_istart()
{
	if(renderer_on) renderer_stop();
	eval_init();
	linenr = 0;
}

int renderer_iinput(char *line)
{
	linenr++;
	return process_line(line);
}

int renderer_idone()
{
	if(!eval_schedule()) return 0;
	apipe_start();
	renderer_on = 1;
	vga_set_console(0);
#ifdef RENDERER_DEBUG
	printf("RDR: started\n");
#endif
	return 1;
}

void renderer_stop()
{
#ifdef RENDERER_DEBUG
	printf("RDR: stopped\n");
#endif
	renderer_on = 0;
	apipe_stop();
}
