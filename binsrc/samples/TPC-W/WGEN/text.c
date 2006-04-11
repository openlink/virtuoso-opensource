/* @(#) text.c 12.1.1.5@(#) */
/*
 * text.c --- pseaudo text generator for use in DBGEN 2.0
 *
 * Defined Routines:
 *		dbg_text() -- select and translate a sentance form
 */

#ifdef TEST
#define DECLARER
#endif /* TEST */

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

static int vocab_scale[6][7] =
/*I			N		V		D		J		P		X */
{
{1,			300,	450,	300,	300,	 70,	10},	/* 1430 */
{1000,		350,	500,	350,	350,	 85,	12},	/* 1647 */
{10000,		440,	600,	440,	440,	105,	14},	/* 2039 */
{100000,	550,	800,	550,	550,	130,	16},	/* 2596 */
{1000000,	750,	1100,	750,	750,	165,	17},	/* 3532 */
{10000000,	993,	1478,	926,	934,	216,	18}		/* 4570 */
};

#define MAX_SCALE	5
/* indexes to vocab scale */
#define	TERM	-2
#define	ART		-1
#define	NOUN	1
#define	VERB	2
#define	ADV		3
#define	ADJ		4
#define	PREP	5
#define	AUX		6

/* 
 * find the word to use for a given POS placeholder, possibly subject to
 * scaling limits
 */
static int
pick_word(distribution *src, int pos, long col, char *dest)
{
	int icnt,
		limit,
		i;

	if (item_count < 1)
		icnt = 1;
	else
		icnt = item_count;

	if (pos > 0)
		{
		for (i=MAX_SCALE; i >= 0; i--)
			if (vocab_scale[i][0] <= icnt)
				{
				limit = vocab_scale[i][pos];
				break;
				}
		}
	else
		limit = NONE;

	return(dist_select(src, col, dest, limit));
	
}

/*
* read the distributions needed in the benchamrk
*/
void
load_dists (void)
{
	/* load the distributions that contain text generation */
	read_dist (env_config (DIST_TAG, DIST_DFLT), "nouns", &nouns);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "verbs", &verbs);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "adjectives", &adjectives);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "adverbs", &adverbs);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "auxillaries", &auxillaries);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "terminators", &terminators);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "articles", &articles);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "prepositions", &prepositions);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "grammar", &grammar);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "np", &np);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "vp", &vp);
	return;	
}

/* 
 * txt_vp() -- 
 *		generate a verb phrase by
 *		1) selecting a verb phrase form
 *		2) parsing it to select parts of speech
 *		3) selecting appropriate words
 *		4) adding punctuation as required
 *
 *	Returns: length of generated phrase
 *	Called By: txt_sentence()
 *	Calls: dist_select() 
 */
static int
txt_vp(char *dest, int sd) 
{
	char syntax[MAX_GRAMMAR_LEN + 1],
		*cptr,
		*parse_target;
	distribution *src;
	int i,
		res = 0,
		pos;

	
	dist_select(&vp, sd, &syntax[0], NONE);
	parse_target = syntax;
	while ((cptr = strtok(parse_target, " ")) != NULL)
	{
		src = NULL;
		switch(*cptr)
		{
		case 'D':
			src = &adverbs;
			pos = ADV;
			break;
		case 'V':
			src = &verbs;
			pos = VERB;
			break;
		case 'X': 
			src = &auxillaries;
			pos = AUX;
			break;
		}	/* end of POS switch statement */
		i = pick_word(src, pos, sd, dest);
		i = strlen(DIST_MEMBER(src, i));
		dest += i;
		res += i;
		if (*(++cptr))	/* miscelaneous fillagree, like punctuation */
		{
			dest += 1;
			res += 1;
			*dest = *cptr;
		}
		*dest = ' ';
		dest++;
		res++;
		parse_target = NULL;
	}	/* end of while loop */

	return(res);
}

/* 
 * txt_np() -- 
 *		generate a noun phrase by
 *		1) selecting a noun phrase form
 *		2) parsing it to select parts of speech
 *		3) selecting appropriate words
 *		4) adding punctuation as required
 *
 *	Returns: length of generated phrase
 *	Called By: txt_sentence()
 *	Calls: dist_select(), 
 */
static int
txt_np(char *dest, int sd) 
{
	char syntax[MAX_GRAMMAR_LEN + 1],
		*cptr,
		*parse_target;
	distribution *src;
	int i,
		res = 0,
		pos;

	
	dist_select(&np, sd, &syntax[0], NONE);
	parse_target = syntax;
	while ((cptr = strtok(parse_target, " ")) != NULL)
	{
		src = NULL;
		switch(*cptr)
		{
		case 'A':
			src = &articles;
			pos = ART;
			break;
		case 'J':
			src = &adjectives;
			pos = ADJ;
			break;
		case 'D':
			src = &adverbs;
			pos = ADV;
			break;
		case 'N': 
			src = &nouns;
			pos = NOUN;
			break;
		}	/* end of POS switch statement */
		i = pick_word(src, pos, sd, dest);
		i = strlen(DIST_MEMBER(src, i));
		dest += i;
		res += i;
		if (*(++cptr))	/* miscelaneous fillagree, like punctuation */
		{
			*dest = *cptr;
			dest += 1;
			res += 1;
		}
		*dest = ' ';
		dest++;
		res++;
		parse_target = NULL;
	}	/* end of while loop */

	return(res);
}

/* 
 * txt_sentence() -- 
 *		generate a sentence by
 *		1) selecting a sentence form
 *		2) parsing it to select parts of speech or phrase types
 *		3) selecting appropriate words
 *		4) adding punctuation as required
 *
 *	Returns: length of generated sentence
 *	Called By: dbg_text()
 *	Calls: dist_select(), txt_np(), txt_vp() 
 */
static int
txt_sentence(char *dest, int sd) 
{
	char syntax[MAX_GRAMMAR_LEN + 1],
		*cptr;
	int i,
		res = 0,
		len = 0;

	
	dist_select(&grammar, sd, syntax, NONE);
	cptr = syntax;

next_token:	/* I hate goto's, but can't seem to have parent and child use strtok() */
	while (*cptr && *cptr == ' ')
		cptr++;
	if (*cptr == '\0')
		goto done;
	switch(*cptr)
		{
		case 'V':
			len = txt_vp(dest, sd);
			break;
		case 'N': 
			len = txt_np(dest, sd);
			break;
		case 'P':
			i = pick_word(&prepositions, PREP, sd, dest);
			len = strlen(DIST_MEMBER(&prepositions, i));
			strcpy((dest + len), " the ");
			len += 5;
			len += txt_np(dest + len, sd);
			break;
		case 'T':
			/*terminators should abut previous word */
			i = dist_select(&terminators, sd, --dest, NONE); 
			len = strlen(DIST_MEMBER(&terminators, i));
			break;
		}	/* end of POS switch statement */
		dest += len;
		res += len;
		cptr++;
		if (*cptr && *cptr != ' ')	/* miscelaneous fillagree, like punctuation */
		{
			dest += 1;
			res += 1;
			*dest = *cptr;
		}
		goto next_token;
done:
	*dest = '\0';
	return(--res);
}

/*
 * dbg_text() -- 
 *		produce ELIZA-like text of random, bounded length, truncating the last 
 *		generated sentence as required
 */
int
dbg_text(char *tgt, int min, int max, int sd)
{
	long length = 0; 
	int wordlen = 0,
		needed,
		s_len;
	char sentence[MAX_SENT_LEN + 1];
	
	length = tpc_random(min, max, sd);

	while (wordlen < length)
	{
		s_len = txt_sentence(sentence, sd);
		if ( s_len < 0)
			{
			INTERNAL_ERROR("Bad sentence formation");
			}
		else
			*sentence = toupper(*sentence);
		needed = length - wordlen;
		if (needed >= s_len + 1)	/* need the entire sentence */
		{
			strcpy(tgt, sentence);
			tgt += s_len;
			wordlen += s_len + 1;
			*(tgt++) = ' ';
		}
		else /* chop the new sentence off to match the length target */
		{
			wordlen += needed;
			/* 
			 * change termination to word boudaries
			 */
			while (needed && sentence[needed] != ' ')
				needed -= 1;
			sentence[needed] = '\0';
			strcpy(tgt, sentence);
			tgt += needed;
		}
	}
	*tgt = '\0';

	return(wordlen);
}

#ifdef TEST
tdef tdefs = { NULL };

main()
{
	char prattle[401];
	
	read_dist (env_config (DIST_TAG, DIST_DFLT), "nouns", &nouns);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "verbs", &verbs);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "adjectives", &adjectives);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "adverbs", &adverbs);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "auxillaries", &auxillaries);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "terminators", &terminators);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "articles", &articles);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "prepositions", &prepositions);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "grammar", &grammar);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "np", &np);
	read_dist (env_config (DIST_TAG, DIST_DFLT), "vp", &vp);

	while (1)
	{
		dbg_text(&prattle[0], 300, 400, 0);
		printf("<%s>\n", prattle);
	}

	return(0);
}
#endif /* TEST */
