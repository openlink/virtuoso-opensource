/*
 * Sccsid:     @(#) tpcw.h 12.1.1.15@(#)
 *
 * general definitions and control information for the TPCW code 
 * generator; if it controls the data set, it's here
 */
#ifndef TPCW_H
#define  TPCW_H
#define NAME			"TPC-W"
#define VERSION           1
#define RELEASE           0
#define MODIFICATION      0
#define PATCH             ""
#define TPC             "Transaction Processing Performance Council"
#define C_DATES         "1999 - 2000"

#include "config.h"

#include <stdio.h>
#include <stdlib.h>

/******* utility functions ********/
#ifdef MIN
#undef MIN
#endif
#ifdef MAX
#undef MAX
#endif
#define MIN(a, b) ((a) < (b))?(a):(b)
#define MAX(a, b) ((a) > (b))?(a):(b)

#define INTERNAL_ERROR(p)  {fprintf(stderr,"%s", p);abort();}
#define LN_CNT	4
static char lnoise[4] = {'|', '/', '-', '\\' };
#define LIFENOISE(n, var)	\
	if (verbose > 0) fprintf(stderr, "%c\b", lnoise[(var%LN_CNT)])

#define MALLOC_CHECK(var) \
    if ((var) == NULL) \
        { \
        fprintf(stderr, "Malloc failed at %s:%d\n",  \
            __FILE__, __LINE__); \
        exit(1);\
        }
#define OPEN_CHECK(var, path) \
    if ((var) == NULL) \
        { \
        fprintf(stderr, "Open failed for %s at %s:%d\n",  \
            path, __FILE__, __LINE__); \
        exit(1);\
        }

/******* general defines ********/

/* operational modes */
#define NONE	-1
#define TITLE	0
#define AUTHOR	1
#define BIO		2


/******* table definitions ********/
#define MIN_TITLE_LEN	14
#define MAX_TITLE_LEN	60
#define TITLE_INSERT_MIN	0
#define TITLE_INSERT_MAX	44
#define I_TITLE_SPLICE	25 /* percentage of mid-word insertions */
#define I_TITLE_DEN		5
#define I_ITEM_MIN		1
#define SYL_CNT	7

#define A_LNAME_MIN		14	/* minimum length of A_LNAME [unused 991008] */
#define A_LNAME_MAX		20	/* maximum length of A_LNAME */
#define A_LPAD_PROB		25	/* probability of digsyl() only for A_LNAME */
#define A_LPAD_MIN		1	/* minimum length of a_rnd() suffix */
#define A_LPAD_MAX		6	/* maximum length of a_rnd() suffix */
#define A_AUTHOR_DEN	2.5
#define A_AUTHOR_MIN	1

#define A_BIO_MIN	125
#define A_BIO_MAX	500

/******* structure definitions ********/
typedef struct
{
   long	weight;
   long	index;
}         set_member;

typedef struct
{
   int      count;
   int      max;
   set_member *list;
   long *permute;
   char	*data;
}         distribution;
/*
 * some handy access functions 
 */
#define DIST_SIZE(d)		d->count
#define DIST_MEMBER(d, i)	(char *)((d)->data + ((set_member *)((d)->list + i))->index)

typedef struct SEED_T {
	long table;
	long value;
	long usage;
	long boundary;
	} seed_t;


/******* functoin prototypes ********/
/* bm_utils.c */
char	*env_config(char *var, char *dflt);
int     a_rnd(int min, int max, int column, char *dest);
int     tx_rnd(long min, long max, long column, char *tgt);
long	dssncasecmp(char *s1, char *s2, int n);
long	dsscasecmp(char *s1, char *s2);
int		dist_select(distribution * s, int c, char *target, int limit);
void	agg_str(distribution *set, long count, long col, char *dest);
void	read_dist(char *path, char *name, distribution * target);
void	embed_str(distribution *d, int min, int max, int stream, char *dest);
#ifndef STDLIB_HAS_GETOPT
int		getopt(int arg_cnt, char **arg_vect, char *oprions);
#endif /* STDLIB_HAS_GETOPT */

/* rnd.c */
long	NextRand(long nSeed);
long	UnifInt(long nLow, long nHigh, long nStream);
double	UnifReal(double dLow, double dHigh, long nStream);
double	Exponential(double dMean, long nStream);
long	tpc_random(long min, long max, long seed);
void	row_start(int t);
void	row_stop(int t);
void	dump_seeds(int t);

/* text.c */
#define MAX_GRAMMAR_LEN	12	/* max length of grammar component */
#define MAX_SENT_LEN	256 /* max length of populated sentence */
#define RNG_PER_SENT	27	/* max number of RNG calls per sentence */
int		dbg_text(char * t, int min, int max, int s);

/* tpcw.c */
char *mk_title(int item);
char *mk_author(int author);

#ifdef DECLARER
#define EXTERN
#else
#define EXTERN extern
#endif            /* DECLARER */

/* miscellaneous globals */
EXTERN char *dpath;
EXTERN int	set_seeds; /* UNUSED 19990929 */
EXTERN int	item_count;
EXTERN int	mode;
EXTERN int	author_count;
EXTERN int	verbose;
EXTERN int	scale;
EXTERN int	force;	/* UNUSED 19991008 */

/* distributions that control text generation */
EXTERN distribution articles;
EXTERN distribution nouns;
EXTERN distribution adjectives;
EXTERN distribution adverbs;
EXTERN distribution prepositions;
EXTERN distribution verbs;
EXTERN distribution terminators;
EXTERN distribution auxillaries;
EXTERN distribution np;
EXTERN distribution vp;
EXTERN distribution grammar;


/******** environmental variables and defaults ***************/
#define  DIST_TAG  "TPCW_DIST"		/* environment var to override ... */
#define  DIST_DFLT "grammar.tpcw"	/* default file to hold distributions */
#define  PATH_TAG  "TPCW_PATH"		/* environment var to override ... */
#define  PATH_DFLT "."				/* default directory to hold tables */
#define  CONFIG_TAG  "TPCW_CONFIG"	/* environment var to override ... */
#define  CONFIG_DFLT "."			/* default directory to config files */

/*********** distribuitons currently defined *************/
#define  UNIFORM   0

/*********** seed indexes *************/
#define I_TITLE_SD		0
#define A_LNAME_SD		1
#define A_BIO_SD		2
#endif            /* TPCW_H */
