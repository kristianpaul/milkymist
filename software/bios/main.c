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

#include <stdio.h>
#include <console.h>
#include <string.h>
#include <uart.h>
#include <blockdev.h>
#include <fatfs.h>
#include <crc.h>
#include <system.h>
#include <board.h>
#include <irq.h>
#include <version.h>
#include <net/mdio.h>
#include <hw/fmlbrg.h>
#include <hw/sysctl.h>
#include <hw/gpio.h>
#include <hw/flash.h>
#include <hw/minimac.h>

#include <hal/vga.h>
#include <hal/tmu.h>
#include <hal/brd.h>
#include <hal/usb.h>
#include <hal/ukb.h>

#include "boot.h"
#include "splash.h"

enum {
	CSR_IE = 1, CSR_IM, CSR_IP, CSR_ICC, CSR_DCC, CSR_CC, CSR_CFG, CSR_EBA,
	CSR_DC, CSR_DEBA, CSR_JTX, CSR_JRX, CSR_BP0, CSR_BP1, CSR_BP2, CSR_BP3,
	CSR_WP0, CSR_WP1, CSR_WP2, CSR_WP3,
};

/*  registers */
/* CH0 */
#define CH0_PRN_KEY	(0xa0000000)
#define CH0_CARRIER_NCO	(0xa0000004)
#define CH0_CODE_NCO	(0xa0000008)
#define CH0_CODE_SLEW	(0xa000000c)
#define CH0_I_EARLY	(0xa0000010)
#define CH0_Q_EARLY	(0xa0000014)
#define CH0_I_PROMPT	(0xa0000018)
#define CH0_Q_PROMPT	(0xa000001c)
#define CH0_I_LATE	(0xa0000020)
#define CH0_Q_LATE	(0xa0000024)
#define CH0_CARRIER_MEASUREMENT (0xa0000028)
#define CH0_CODE_MEASUREMENT (0xa000002c)
#define CH0_EPOCH	(0xa0000030)
#define CH0_EPOCH_CHECK	(0xa0000034)
#define CH0_EPOCH_LOAD	(0xa0000038)
#define CH0_ENABLES	(0xa000003c)

/* Status */
#define STATUS		(0xa0000380)
#define NEW_DATA	(0xa0000384)
#define TIC_COUNT	(0xa0000388)
#define ACCUM_COUNT	(0xa000038c)
#define CLEAR_STATUS	(0xa0000390)
#define HW_ID		(0xa00003bc)

/* Control */
#define RESET		(0xa00003c0)
#define PROG_TIC	(0xa00003c4)
#define PROG_ACCUM_INT 	(0xa00003c8)
#define TEMP		(0xa00003cc)

/* PRN Codes */
const  int prn_code[37] = {
	0x3EC, 0x3D8, 0x3B0, 0x360, 0x096, 0x12C, 0x196, 0x32C, 0x258,
	0x374, 0x2E8, 0x3A0, 0x340, 0x280, 0x100, 0x200, 0x226,
	0x04C, 0x098, 0x130, 0x260, 0x0C0, 0x0CE, 0x270, 0x0E0,
	0x1C0, 0x380, 0x300, 0x056, 0x0AC, 0x158, 0x2B0, 0x160,
	0x0B0, 0x316, 0x22C, 0x0B0};
};

/* MMIO */
#define MM_READ(reg) (*((volatile unsigned int *)(reg)))
#define MM_READS(reg) (short int)(*((volatile unsigned int *)(reg))) 
#define MM_WRITE(reg, val) *((volatile unsigned int *)(reg)) = val

/* General address space functions */

#define NUMBER_OF_BYTES_ON_A_LINE 16
static void dump_bytes(unsigned int *ptr, int count, unsigned addr)
{
	char *data = (char *)ptr;
	int line_bytes = 0, i = 0;

	putsnonl("Memory dump:");
	while(count > 0){
		line_bytes =
			(count > NUMBER_OF_BYTES_ON_A_LINE)?
				NUMBER_OF_BYTES_ON_A_LINE : count;

		printf("\n0x%08x  ", addr);
		for(i=0;i<line_bytes;i++)
			printf("%02x ", *(unsigned char *)(data+i));

		for(;i<NUMBER_OF_BYTES_ON_A_LINE;i++)
			printf("   ");

		printf(" ");

		for(i=0;i<line_bytes;i++) {
			if((*(data+i) < 0x20) || (*(data+i) > 0x7e))
				printf(".");
			else
				printf("%c", *(data+i));
		}

		for(;i<NUMBER_OF_BYTES_ON_A_LINE;i++)
			printf(" ");

		data += (char)line_bytes;
		count -= line_bytes;
		addr += line_bytes;
	}
	printf("\n");
}

static void memtest1()
{
	volatile unsigned int *count_addr = (volatile unsigned int *)0xa00003cc;
	int i;
	int j;
	int errors = 0;
	int pass = 0;
	puts("Start \n");
	unsigned int buf[100000];
	for (i = 0; i != 100; i++)
		for (j = 0; j != sizeof(buf); j++) {
			*count_addr = buf[j];
			if( *count_addr != buf[j]){
			       //	printf("E. %u", *count_addr);
			       errors++;
			}
			pass++;
		}
	printf("Errors: %u \n", errors);
	printf("Cycles: %u \n", pass);
	puts("Done \n");
}

static void init()
{
	char *c;
	printf("\n");
	printf("Initializing Correlator: \n");
	/* prog tic*/
	MM_WRITE(PROG_TIC,0x18ffff);
	printf("Prog TIC\n");
	/* prog accum int*/
	MM_WRITE(PROG_ACCUM_INT,0x1fff);
	printf("Accum TIC\n");
	/* prn */
	MM_WRITE(CH0_PRN_KEY,0x300);
	printf("CH0 PRN Key \n");
	/* carrier nco */
	MM_WRITE(CH0_CARRIER_NCO,0x9f0000);
	printf("Carrier NCO\n");
	/* code nco */
	MM_WRITE(CH0_CODE_NCO,0x3ff00);
	printf("CH0 Code NCO\n");
	/* code slew */
	MM_WRITE(CH0_CODE_SLEW,0x400); // this will be based upon a variable
	printf("CH0 Code SLEW\n");
	/* logic enable */
	MM_WRITE(CH0_ENABLES,0xff);
	printf("CH0 LOGIC ENABLED\n");
	/* epoch load */
	MM_WRITE(CH0_EPOCH_LOAD,0xff);
	printf("CH0 Epoch Load\n");
	printf("Done\n");
}
static void measure()
{
	char *c;
	while(1)
	{
		MM_WRITE(CLEAR_STATUS,0x0f);
		if(readchar_nonblock()) 
		{
			c = readchar();
			if(c == 'q')
				break;
		}
	}
	printf("Bye\n");
}
static void accumone()
{
	char *c;
//	short int value;
	printf("Accumulator: \n");
	printf("I_P\n");
	/* missing polling accum int pin */
	while(1)
	{
                
//		volatile unsigned int *ch_prompt = CH0_I_PROMPT;
//		value = (short int) *ch_prompt;
		//printf("%d\n",(short int)(*((volatile unsigned int *)(CH0_I_PROMPT))));
		printf("%d\n",MM_READS(CH0_I_PROMPT));
	MM_WRITE(CLEAR_STATUS,0x0f);
	MM_WRITE(CH0_ENABLES,0xff);
		if(readchar_nonblock()) 
		{
			c = readchar();
			if(c == 'q')
				break;
		}
	}
	printf("\n");

}
static void accumu()
{
	char *c;
	printf("Accumulators: \n");
	printf("I_E\tQ_E\tI_P\tQ_P\tI_L\tQ_L\n");
	/* missing polling accum int pin */
	while(1)
	{
		printf("%02d\t%02d\t%02d\t%02d\t%02d\t%02d\n",(MM_READ(CH0_I_EARLY)),(MM_READ(CH0_Q_EARLY)),(MM_READ(CH0_I_PROMPT)),(MM_READ(CH0_Q_PROMPT)),(MM_READ(CH0_I_LATE)),(MM_READ(CH0_Q_LATE)));
	MM_WRITE(CLEAR_STATUS,0x0f);
	MM_WRITE(CH0_ENABLES,0xff);
		if(readchar_nonblock()) 
		{
			c = readchar();
			if(c == 'q')
				break;
		}
	}
	printf("\n");

}

static void accums()
{
	char *c;
	printf("Accumulators: \n");
	printf("I_E\tQ_E\tI_P\tQ_P\tI_L\tQ_L\n");
	/* missing polling accum int pin */
	while(1)
	{
		printf("%d\t%d\t%d\t%d\t%d\t%d\n",(MM_READS(CH0_I_EARLY)),(MM_READS(CH0_Q_EARLY)),(MM_READS(CH0_I_PROMPT)),(MM_READS(CH0_Q_PROMPT)),(MM_READS(CH0_I_LATE)),(MM_READS(CH0_Q_LATE)));
	MM_WRITE(CLEAR_STATUS,0x0f);
	MM_WRITE(CH0_ENABLES,0xff);
		if(readchar_nonblock()) 
		{
			c = readchar();
			if(c == 'q')
				break;
		}
	}
	printf("\n");

}

static void status()
{
	char *c;
	printf("\n");
	printf("Status: \n");
	printf("TIC_COUNT\tACCUM_COUNT\tCARRIER_MEASURE\tCODE_MEASURE\t\tSTATUS\tNEW_DATA\n");
	while(1)
	{
		printf("%02d\t\t%02d\t\t%02d\t\t%02d\t\t%02d\t\t%02d\n",(MM_READ(TIC_COUNT)),(MM_READ(ACCUM_COUNT)),(MM_READ(CH0_CARRIER_MEASUREMENT)),(MM_READ(CH0_CODE_MEASUREMENT)),(MM_READ(STATUS)),(MM_READ(NEW_DATA)));
	MM_WRITE(CLEAR_STATUS,0x0f);
//	MM_WRITE(CH0_ENABLES,0xff);
		if(readchar_nonblock()) 
		{
			c = readchar();
			if(c == 'q')
				break;
		}
	}
	MM_WRITE(STATUS,0x0); //clear status_read flag
	printf("\n");
}

static void acq()
{
	char *c;
	printf("Accumulators: \n");
	printf("I_E\tQ_E\tI_P\tQ_P\tI_L\tQ_L\n");
	/* missing polling accum int pin */
	while(1)
	{
		printf("%02d\t%02d\t%02d\t%02d\t%02d\t%02d\n",(MM_READ(CH0_I_EARLY)),(MM_READ(CH0_Q_EARLY)),(MM_READ(CH0_I_PROMPT)),(MM_READ(CH0_Q_PROMPT)),(MM_READ(CH0_I_LATE)),(MM_READ(CH0_Q_LATE)));
	MM_WRITE(CLEAR_STATUS,0x0f);
	MM_WRITE(CH0_ENABLES,0xff);
		if(readchar_nonblock()) 
		{
			c = readchar();
			if(c == 'q')
				break;
		}
	}
	printf("\n");

}

static void printmath()
{
/*	int positive = 20;
	int negative = -20; */
	volatile signed short int positive = 30;
	volatile signed short int negative = -30;
	float floating = 0;
	printf("Positive value as unsigned: %u \n", positive);
	printf("Negative value as unsigned: %u \n", negative);
	printf("Float value as unsigned: %u \n", floating);
	printf("Positive value as signed: %d \n", positive);
	printf("Negative value as signed: %d \n", negative);
//	printf("Float value as float: %f \n", &floating);
}

static void mr(char *startaddr, char *len)
{
	char *c;
	unsigned int *addr;
	unsigned int length;

	if(*startaddr == 0) {
		printf("mr <address> [length]\n");
		return;
	}
	addr = (unsigned *)strtoul(startaddr, &c, 0);
	if(*c != 0) {
		printf("incorrect address\n");
		return;
	}
	if(*len == 0) {
		length = 1;
	} else {
		length = strtoul(len, &c, 0);
		if(*c != 0) {
			printf("incorrect length\n");
			return;
		}
	}

	dump_bytes(addr, length, (unsigned)addr);
}

static void mw(char *addr, char *value, char *count)
{
	char *c;
	unsigned int *addr2;
	unsigned int value2;
	unsigned int count2;
	unsigned int i;

	if((*addr == 0) || (*value == 0)) {
		printf("mw <address> <value> [count]\n");
		return;
	}
	addr2 = (unsigned int *)strtoul(addr, &c, 0);
	if(*c != 0) {
		printf("incorrect address\n");
		return;
	}
	value2 = strtoul(value, &c, 0);
	if(*c != 0) {
		printf("incorrect value\n");
		return;
	}
	if(*count == 0) {
		count2 = 1;
	} else {
		count2 = strtoul(count, &c, 0);
		if(*c != 0) {
			printf("incorrect count\n");
			return;
		}
	}
	for (i=0;i<count2;i++) *addr2++ = value2;
}

static void mc(char *dstaddr, char *srcaddr, char *count)
{
	char *c;
	unsigned int *dstaddr2;
	unsigned int *srcaddr2;
	unsigned int count2;
	unsigned int i;

	if((*dstaddr == 0) || (*srcaddr == 0)) {
		printf("mc <dst> <src> [count]\n");
		return;
	}
	dstaddr2 = (unsigned int *)strtoul(dstaddr, &c, 0);
	if(*c != 0) {
		printf("incorrect destination address\n");
		return;
	}
	srcaddr2 = (unsigned int *)strtoul(srcaddr, &c, 0);
	if(*c != 0) {
		printf("incorrect source address\n");
		return;
	}
	if(*count == 0) {
		count2 = 1;
	} else {
		count2 = strtoul(count, &c, 0);
		if(*c != 0) {
			printf("incorrect count\n");
			return;
		}
	}
	for (i=0;i<count2;i++) *dstaddr2++ = *srcaddr2++;
}

static void crc(char *startaddr, char *len)
{
	char *c;
	char *addr;
	unsigned int length;

	if((*startaddr == 0)||(*len == 0)) {
		printf("crc <address> <length>\n");
		return;
	}
	addr = (char *)strtoul(startaddr, &c, 0);
	if(*c != 0) {
		printf("incorrect address\n");
		return;
	}
	length = strtoul(len, &c, 0);
	if(*c != 0) {
		printf("incorrect length\n");
		return;
	}

	printf("CRC32: %08x\n", crc32((unsigned char *)addr, length));
}

/* processor registers */
static int parse_csr(const char *csr)
{
	if(!strcmp(csr, "ie"))   return CSR_IE;
	if(!strcmp(csr, "im"))   return CSR_IM;
	if(!strcmp(csr, "ip"))   return CSR_IP;
	if(!strcmp(csr, "icc"))  return CSR_ICC;
	if(!strcmp(csr, "dcc"))  return CSR_DCC;
	if(!strcmp(csr, "cc"))   return CSR_CC;
	if(!strcmp(csr, "cfg"))  return CSR_CFG;
	if(!strcmp(csr, "eba"))  return CSR_EBA;
	if(!strcmp(csr, "dc"))   return CSR_DC;
	if(!strcmp(csr, "deba")) return CSR_DEBA;
	if(!strcmp(csr, "jtx"))  return CSR_JTX;
	if(!strcmp(csr, "jrx"))  return CSR_JRX;
	if(!strcmp(csr, "bp0"))  return CSR_BP0;
	if(!strcmp(csr, "bp1"))  return CSR_BP1;
	if(!strcmp(csr, "bp2"))  return CSR_BP2;
	if(!strcmp(csr, "bp3"))  return CSR_BP3;
	if(!strcmp(csr, "wp0"))  return CSR_WP0;
	if(!strcmp(csr, "wp1"))  return CSR_WP1;
	if(!strcmp(csr, "wp2"))  return CSR_WP2;
	if(!strcmp(csr, "wp3"))  return CSR_WP3;

	return 0;
}

static void rcsr(char *csr)
{
	unsigned int csr2;
	register unsigned int value;

	if(*csr == 0) {
		printf("rcsr <csr>\n");
		return;
	}

	csr2 = parse_csr(csr);
	if(csr2 == 0) {
		printf("incorrect csr\n");
		return;
	}

	switch(csr2) {
		case CSR_IE:   asm volatile ("rcsr %0,ie":"=r"(value)); break;
		case CSR_IM:   asm volatile ("rcsr %0,im":"=r"(value)); break;
		case CSR_IP:   asm volatile ("rcsr %0,ip":"=r"(value)); break;
		case CSR_CC:   asm volatile ("rcsr %0,cc":"=r"(value)); break;
		case CSR_CFG:  asm volatile ("rcsr %0,cfg":"=r"(value)); break;
		case CSR_EBA:  asm volatile ("rcsr %0,eba":"=r"(value)); break;
		case CSR_DEBA: asm volatile ("rcsr %0,deba":"=r"(value)); break;
		case CSR_JTX:  asm volatile ("rcsr %0,jtx":"=r"(value)); break;
		case CSR_JRX:  asm volatile ("rcsr %0,jrx":"=r"(value)); break;
		default: printf("csr write only\n"); return;
	}

	printf("%08x\n", value);
}

static void wcsr(char *csr, char *value)
{
	char *c;
	unsigned int csr2;
	register unsigned int value2;

	if((*csr == 0) || (*value == 0)) {
		printf("wcsr <csr> <address>\n");
		return;
	}

	csr2 = parse_csr(csr);
	if(csr2 == 0) {
		printf("incorrect csr\n");
		return;
	}
	value2 = strtoul(value, &c, 0);
	if(*c != 0) {
		printf("incorrect value\n");
		return;
	}

	switch(csr2) {
		case CSR_IE:   asm volatile ("wcsr ie,%0"::"r"(value2)); break;
		case CSR_IM:   asm volatile ("wcsr im,%0"::"r"(value2)); break;
		case CSR_ICC:  asm volatile ("wcsr icc,%0"::"r"(value2)); break;
		case CSR_DCC:  asm volatile ("wcsr dcc,%0"::"r"(value2)); break;
		case CSR_EBA:  asm volatile ("wcsr eba,%0"::"r"(value2)); break;
		case CSR_DC:   asm volatile ("wcsr dcc,%0"::"r"(value2)); break;
		case CSR_DEBA: asm volatile ("wcsr deba,%0"::"r"(value2)); break;
		case CSR_JTX:  asm volatile ("wcsr jtx,%0"::"r"(value2)); break;
		case CSR_JRX:  asm volatile ("wcsr jrx,%0"::"r"(value2)); break;
		case CSR_BP0:  asm volatile ("wcsr bp0,%0"::"r"(value2)); break;
		case CSR_BP1:  asm volatile ("wcsr bp1,%0"::"r"(value2)); break;
		case CSR_BP2:  asm volatile ("wcsr bp2,%0"::"r"(value2)); break;
		case CSR_BP3:  asm volatile ("wcsr bp3,%0"::"r"(value2)); break;
		case CSR_WP0:  asm volatile ("wcsr wp0,%0"::"r"(value2)); break;
		case CSR_WP1:  asm volatile ("wcsr wp1,%0"::"r"(value2)); break;
		case CSR_WP2:  asm volatile ("wcsr wp2,%0"::"r"(value2)); break;
		case CSR_WP3:  asm volatile ("wcsr wp3,%0"::"r"(value2)); break;
		default: printf("csr read only\n"); return;
	}
}


/* CF filesystem functions */

static int lscb(const char *filename, const char *longname, void *param)
{
	printf("%12s [%s]\n", filename, longname);
	return 1;
}

static void ls(char *dev)
{
	if(!fatfs_init(BLOCKDEV_MEMORY_CARD)) return;
	fatfs_list_files(lscb, NULL);
	fatfs_done();
}

static void load(char *filename, char *addr, char *dev)
{
	char *c;
	unsigned int *addr2;

	if((*filename == 0) || (*addr == 0)) {
		printf("load <filename> <address>\n");
		return;
	}
	addr2 = (unsigned *)strtoul(addr, &c, 0);
	if(*c != 0) {
		printf("incorrect address\n");
		return;
	}
	if(!fatfs_init(BLOCKDEV_MEMORY_CARD)) return;
	fatfs_load(filename, (char *)addr2, 16*1024*1024, NULL);
	fatfs_done();
}

static void mdior(char *reg)
{
	char *c;
	int reg2;

	if(*reg == 0) {
		printf("mdior <register>\n");
		return;
	}
	reg2 = strtoul(reg, &c, 0);
	if(*c != 0) {
		printf("incorrect register\n");
		return;
	}

	printf("%04x\n", mdio_read(brd_desc->ethernet_phyadr, reg2));
}

static void mdiow(char *reg, char *value)
{
	char *c;
	int reg2;
	int value2;

	if((*reg == 0) || (*value == 0)) {
		printf("mdiow <register> <value>\n");
		return;
	}
	reg2 = strtoul(reg, &c, 0);
	if(*c != 0) {
		printf("incorrect address\n");
		return;
	}
	value2 = strtoul(value, &c, 0);
	if(*c != 0) {
		printf("incorrect value\n");
		return;
	}

	mdio_write(brd_desc->ethernet_phyadr, reg2, value2);
}

/* Init + command line */

static void help()
{
	puts("Milkymist(tm) BIOS (bootloader)");
	puts("Don't know what to do? Try 'flashboot'.\n");
	puts("Available commands:");
	puts("cons       - switch console mode");
	puts("flush      - flush FML bridge cache");
	puts("mr         - read address space");
	puts("mw         - write address space");
	puts("mc         - copy address space");
	puts("crc        - compute CRC32 of a part of the address space");
	puts("rcsr       - read processor CSR");
	puts("wcsr       - write processor CSR");
	puts("ls         - list files on the filesystem");
	puts("load       - load a file from the filesystem");
	puts("netboot    - boot via TFTP");
	puts("serialboot - boot via SFL");
	puts("fsboot     - boot from the filesystem");
	puts("flashboot  - boot from flash");
	puts("mdior      - read MDIO register");
	puts("mdiow      - write MDIO register");
	puts("version    - display version");
	puts("reboot     - system reset");
	puts("reconf     - reload FPGA configuration");
	puts("init - init correlator essential registers");
	puts("status - dump status to screen");
	puts("measure - no dump,measure TPs with scope ");
	puts("accums - dump accumlators as signed to screen");
	puts("accumu - dump accumlators as un-signed to screen");
	puts("accumone - dump one accumlator as signed to screen");
	puts("memtest1   - memory speed test, use a stopwatch!");
	puts("printmath   - confirm some signed/unsiged visualization");
}

static char *get_token(char **str)
{
	char *c, *d;

	c = (char *)strchr(*str, ' ');
	if(c == NULL) {
		d = *str;
		*str = *str+strlen(*str);
		return d;
	}
	*c = 0;
	d = *str;
	*str = c+1;
	return d;
}

static void do_command(char *c)
{
	char *token;

	token = get_token(&c);

	if(strcmp(token, "cons") == 0) vga_set_console(!vga_get_console());
	else if(strcmp(token, "flush") == 0) flush_bridge_cache();
	else if(strcmp(token, "mr") == 0) mr(get_token(&c), get_token(&c));
	else if(strcmp(token, "mw") == 0) mw(get_token(&c), get_token(&c), get_token(&c));
	else if(strcmp(token, "mc") == 0) mc(get_token(&c), get_token(&c), get_token(&c));
	else if(strcmp(token, "crc") == 0) crc(get_token(&c), get_token(&c));

	else if(strcmp(token, "ls") == 0) ls(get_token(&c));
	else if(strcmp(token, "load") == 0) load(get_token(&c), get_token(&c), get_token(&c));

	else if(strcmp(token, "netboot") == 0) netboot();
	else if(strcmp(token, "serialboot") == 0) serialboot();
	else if(strcmp(token, "fsboot") == 0) fsboot(BLOCKDEV_MEMORY_CARD);
	else if(strcmp(token, "flashboot") == 0) flashboot();

	else if(strcmp(token, "mdior") == 0) mdior(get_token(&c));
	else if(strcmp(token, "mdiow") == 0) mdiow(get_token(&c), get_token(&c));

	else if(strcmp(token, "version") == 0) puts(VERSION);
	else if(strcmp(token, "reboot") == 0) reboot();
	else if(strcmp(token, "reconf") == 0) reconf();

	else if(strcmp(token, "help") == 0) help();
	
	else if(strcmp(token, "init") == 0) init();
	else if(strcmp(token, "status") == 0) status();
	else if(strcmp(token, "measure") == 0) measure();
	else if(strcmp(token, "accums") == 0) accums();
	else if(strcmp(token, "accumu") == 0) accumu();
	else if(strcmp(token, "accumone") == 0) accumone();
	else if(strcmp(token, "memtest1") == 0) memtest1();
	else if(strcmp(token, "printmath") == 0) printmath();

	else if(strcmp(token, "rcsr") == 0) rcsr(get_token(&c));
	else if(strcmp(token, "wcsr") == 0) wcsr(get_token(&c), get_token(&c));

	else if(strcmp(token, "") != 0)
		printf("Command not found\n");
}

static int test_user_abort()
{
	char c;

	puts("I: Press Q or ESC to abort boot");
	CSR_TIMER0_COUNTER = 0;
	CSR_TIMER0_COMPARE = 2*CSR_FREQUENCY;
	CSR_TIMER0_CONTROL = TIMER_ENABLE;
	while(CSR_TIMER0_CONTROL & TIMER_ENABLE) {
		if(readchar_nonblock()) {
			c = readchar();
			if((c == 'Q')||(c == '\e')) {
				puts("I: Aborted boot on user request");
				return 0;
			}
			if(c == 0x07) {
				vga_unblank();
				vga_set_console(1);
				netboot();
				return 0;
			}
		}
	}
	return 1;
}

int rescue;

extern unsigned int _edata;

static void crcbios()
{
	unsigned int offset_bios;
	unsigned int length;
	unsigned int expected_crc;
	unsigned int actual_crc;

	/*
	 * _edata is located right after the end of the flat
	 * binary image. The CRC tool writes the 32-bit CRC here.
	 * We also use the address of _edata to know the length
	 * of our code.
	 */
	offset_bios = rescue ? FLASH_OFFSET_RESCUE_BIOS : FLASH_OFFSET_REGULAR_BIOS;
	expected_crc = _edata;
	length = (unsigned int)&_edata - offset_bios;
	actual_crc = crc32((unsigned char *)offset_bios, length);
	if(expected_crc == actual_crc)
		printf("I: BIOS CRC passed (%08x)\n", actual_crc);
	else {
		printf("W: BIOS CRC failed (expected %08x, got %08x)\n", expected_crc, actual_crc);
		printf("W: The system will continue, but expect problems.\n");
	}
}

static void print_mac()
{
	unsigned char *macadr = (unsigned char *)FLASH_OFFSET_MAC_ADDRESS;

	printf("I: MAC address: %02x:%02x:%02x:%02x:%02x:%02x\n", macadr[0], macadr[1], macadr[2], macadr[3], macadr[4], macadr[5]);
}

static const char banner[] =
	"\nMILKYMIST(tm) v"VERSION" BIOS   http://www.milkymist.org\n"
	"Modified to assist Namuru Correlator \n\n"
	"(c) Copyleft 2011 Cristian Paul Peñaranda Rojas \n\n"
	"(c) Copyright 2007, 2008, 2009, 2010, 2011 Sebastien Bourdeauducq\n\n"
	"This program is free software: you can redistribute it and/or modify\n"
	"it under the terms of the GNU General Public License as published by\n"
	"the Free Software Foundation, version 3 of the License.\n\n";

static void boot_sequence()
{
	if(test_user_abort()) {
		if(rescue) {
			netboot();
			serialboot();
			fsboot(BLOCKDEV_MEMORY_CARD);
			flashboot();
		} else {
			fsboot(BLOCKDEV_MEMORY_CARD);
			flashboot();
			netboot();
			serialboot();
		}
		printf("E: No boot medium found\n");
	}
}

static void readstr(char *s, int size)
{
	char c[2];
	int ptr;

	c[1] = 0;
	ptr = 0;
	while(1) {
		c[0] = readchar();
		switch(c[0]) {
			case 0x7f:
			case 0x08:
				if(ptr > 0) {
					ptr--;
					putsnonl("\x08 \x08");
				}
				break;
			case '\e':
				vga_set_console(!vga_get_console());
				break;
			case 0x07:
				break;
			case '\r':
			case '\n':
				s[ptr] = 0x00;
				putsnonl("\n");
				return;
			default:
				putsnonl(c);
				s[ptr] = c[0];
				ptr++;
				break;
		}
	}
}

static void ethreset_delay()
{
	CSR_TIMER0_COUNTER = 0;
	CSR_TIMER0_COMPARE = CSR_FREQUENCY >> 2;
	CSR_TIMER0_CONTROL = TIMER_ENABLE;
	while(CSR_TIMER0_CONTROL & TIMER_ENABLE);
}

static void ethreset()
{
	CSR_MINIMAC_SETUP = MINIMAC_SETUP_PHYRST;
	ethreset_delay();
	CSR_MINIMAC_SETUP = 0;
	ethreset_delay();
}

int main(int i, char **c)
{
	char buffer[64];

	/* lock gdbstub ROM */
	CSR_DBG_CTRL = DBG_CTRL_GDB_ROM_LOCK;

	/* enable bus errors */
	CSR_DBG_CTRL = DBG_CTRL_BUS_ERR_EN;

	CSR_GPIO_OUT = GPIO_LED1;
	rescue = !((unsigned int)main > FLASH_OFFSET_REGULAR_BIOS);

	irq_setmask(0);
	irq_enable(1);
	uart_init();
	vga_init(!(rescue || (CSR_GPIO_IN & GPIO_BTN2)));
	putsnonl(banner);
	crcbios();
//	brd_init();
	//tmu_init(); /* < for hardware-accelerated scrolling */
	//usb_init();
	//ukb_init();

	if(rescue)
		printf("I: Booting in rescue mode\n");

	//splash_display();
	//ethreset(); /* < that pesky ethernet PHY needs two resets at times... */
	//print_mac();
	//boot_sequence(); //enable for rtems booting from NOR
	//vga_unblank();
	//vga_set_console(1);
	while(1) {
		putsnonl("\e[1mBIOS>\e[0m ");
		readstr(buffer, 64);
		do_command(buffer);
	}
	return 0;
}
