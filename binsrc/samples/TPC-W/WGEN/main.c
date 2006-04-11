/* @(#) main.c 12.1.1.11@(#) */
/* sample driver for tpcw text generation */

#define DECLARER				/* EXTERN references get defined here */

#include "config.h"
#include <stdlib.h>
#if (defined(_POSIX_)||!defined(WIN32))		/* Change for Windows NT */
#include <unistd.h>
#include <sys/wait.h>
#endif /* WIN32 */
#include <stdio.h>				/* */
#include <limits.h>
#include <math.h>
#include <ctype.h>
#include <signal.h>
#include <string.h>
#include <errno.h>
#ifdef HP
#include <strings.h>
#endif
#if (defined(WIN32)&&!defined(_POSIX_))
#include <process.h>
#pragma warning(disable:4201)
#pragma warning(disable:4214)
#pragma warning(disable:4514)
#define WIN32_LEAN_AND_MEAN
#define NOATOM
#define NOGDICAPMASKS
#define NOMETAFILE
#define NOMINMAX
#define NOMSG
#define NOOPENFILE
#define NORASTEROPS
#define NOSCROLL
#define NOSOUND
#define NOSYSMETRICS
#define NOTEXTMETRIC
#define NOWH
#define NOCOMM
#define NOKANJI
#define NOMCX
#include <windows.h>
#pragma warning(default:4201)
#pragma warning(default:4214)
#endif

#include "tpcw.h"

/*
* Function prototypes
*/
void	usage (void);
void	load_dists (void);

extern int optind, opterr;
extern char *optarg;

void
usage (void)
{
	printf("\n\n");
	printf("USAGE: tpcw [options]\n\n");
	printf("\ttpcw is a sample database-population generator. It includes some\n");
	printf("\tof the functionality that would be required to build a complete\n");
	printf("\tTPC-W data set.\n\n");
	printf("Option Argument  Default        Description\n");
	printf("------ --------  -------        -----------\n");
	printf("-h                              Display a usage summary\n");
	printf("-s     <samples>                Number of sample generated\n");
	printf("-a     <authors>  250           Set the number of authors\n");
	printf("-i     <items>   1000           Set the number of items\n");
	printf("-d     <file>    grammar.tpcw   Read distributions from <file>\n");
	printf("-m     <mode>       0           Set the output mode. Defined modes are:\n");
	printf("                                    0 -- I_TITLE\n");
	printf("                                         samples defaults to item_count\n");
	printf("                                    1 -- A_LNAME\n");
	printf("                                         samples defaults to author_count\n");
	return;

}

void
process_options (int count, char **vector)
{
	int option;

	/* set defaults */
	force = 0;
	verbose = 0;
	mode = 0;
	scale = -1;
	item_count = 1000;
	author_count = 250;

	while ((option = getopt (count, vector, "a:d:hi:m:s:v")) != -1)
	switch (option)
		{
		case 'a':				/* set author count */
			author_count = atoi(optarg);
			break;
		case 'd':				/* specify distribuions on the command line */
			if ((dpath = strdup(optarg)) == NULL)
				INTERNAL_ERROR("strdup() failed for -d option");
			break;
		case 'i':				/* set item count */
			item_count = atoi(optarg);
			break;
		case 'm':				/* set output mode */
			mode = atoi(optarg);
			break;
		case 's':				/* set scale of output */
			scale = atoi(optarg);
			break;
		case 'v':				/* life noises enabled */
			verbose = 1;
			break;
		default:
			printf ("ERROR: option '%c' unknown.\n",
				*(vector[optind] + 1));
		case 'h':				/* something unexpected */
			fprintf (stderr,
				"%s Population Generator (Version %d.%d.%d%s)\n",
				NAME, VERSION, RELEASE, MODIFICATION, PATCH);
			fprintf (stderr, "Copyright %s %s\n", TPC, C_DATES);
			usage ();
			exit (1);
		}

	return;
}

/*
* MAIN
*
* assumes the existance of getopt() to clean up the command 
* line handling
*/
int
main (int ac, char **av)
{
	int	i;
	
	
#ifdef NO_SUPPORT
	signal (SIGINT, exit);
#endif /* NO_SUPPORT */

	process_options (ac, av);

	if (verbose >= 0)
		{
		fprintf (stderr,
			"%s Population Generator (Version %d.%d.%d%s)\n",
			NAME, VERSION, RELEASE, MODIFICATION, PATCH);
		fprintf (stderr, "Copyright %s %s\n", TPC, C_DATES);
		}

	load_dists();

	switch (mode)
		{
		case TITLE:
			if (scale <= 0 || scale > item_count)
				scale = item_count;
			for (i=0; i < scale; i++)
				printf("%s\n", mk_title(i+1));
			break;
		case AUTHOR:
			if (scale <= 0 || scale > author_count)
				scale = author_count;
			for (i=0; i < scale; i++)
				printf("%s\n", mk_author(i+1));
			break;
		default:
			INTERNAL_ERROR("Bad option to mode");
			break;
		}

	return (0);
}
