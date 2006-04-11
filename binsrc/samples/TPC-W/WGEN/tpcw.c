/* @(#) tpcw.c 12.1.1.11@(#) */
#include <stdio.h>
#include <string.h>
#include <malloc.h>
#include <math.h>
#include <memory.h>
#include "tpcw.h"
#include "config.h"

/*
 * Routine:  digsyl()
 * Purpose:	convert an integer to a syntetic word of given length as 
 *			required by Clause 4.6.2.8
 * Data Structures: digsyllables[] array to map digit to syllable
 * Params: range -- integer to convert
 *         width -- width lead 0 pad; 0 == no pad
 * Returns: char * to static array
 * Side Effects: since the result is stored in a static char[], the result
 *				will be over-written by a subsequent call
 * TODO: None
 */
#define SYL_WIDTH	2	/* width of each syllable */
static char *digsyllables[10] = 
	{"BA", "OG", "AL", "RI", "RE", "SE", "AT", "UL", "IN", "NG"};

char *
digsyl(int range, int width)
{
	int i,
		base = 1,
		target;
	static char *new_dig = NULL;
	static int last_width = 0;

	if (range <= 0 || width < 0)
		return(NULL);
	
	if (width == 0) 
		{
		base=1;width=1;
		while(base <= range/10)
			{
			width++;
			base *= 10 ;
			}
		} 
	else  
		{
		for (i=0; i < width - 1; i++)
			base *= 10;
		}
	
	if (new_dig == NULL)
		{
		new_dig = (char *)malloc(sizeof(char) * SYL_WIDTH * width + 1);
		MALLOC_CHECK(new_dig);
		last_width = width;
		}
	else
		{
		new_dig[0] = '\0';
		if (last_width < width)
			{
			new_dig = 
				(char *)realloc(new_dig, width * sizeof(char) * SYL_WIDTH + 1);
			MALLOC_CHECK(new_dig);
			last_width = width;
			}
		}

	for (i=0; i < width * SYL_WIDTH; i += SYL_WIDTH)
		{
		target = range - (range % base);
		target /= base;
		strcpy(new_dig + i, digsyllables[target % 10]);
		range -= base * target;
		base /= 10;
		}

	return(new_dig);
}

/*
 * Routine: mk_title()
 * Purpose: create a pseudo-text based item title as required by clause 4.6.2.17
 * Data Structures:
 *
 * Params: int item -- item number to base title upon
 * Returns: char * pointer to static title 
 * Called By: main()
 * Calls: digsyl(), tpc_random()
 * Side Effects: since the result is stored in a static char[], the result
 *				will be over-written by a subsequent call
 * TODO: None
 */
char * 
mk_title(int item)
{
	static char res[MAX_TITLE_LEN + 1 + SYL_WIDTH * SYL_CNT + 1];
	char base[MAX_TITLE_LEN + 1];
	char *dig;
	int insert,
		splice;

	/*
	 * generate the base text and the digsyl() output to be added
	 */
	dbg_text(base, MIN_TITLE_LEN, MAX_TITLE_LEN, I_TITLE_SD);
	insert = 
		tpc_random(MIN(TITLE_INSERT_MIN, strlen(base) - 1), 
					MIN(TITLE_INSERT_MAX, strlen(base) - 1), 
					I_TITLE_SD);
	if (item <= (item_count / I_TITLE_DEN))
		dig = digsyl(item, SYL_CNT);
	else
		{
		dig = 
			digsyl(
				tpc_random(I_ITEM_MIN, item_count / I_TITLE_DEN, I_TITLE_SD), 
					SYL_CNT);
		}
	
	if (insert != 0) /* need to find a word boundary */
		while (base[insert] && base[insert] != ' ' && insert > 0)
			insert -= 1;
	if (base[insert] == '\0')
		insert = -1;
	else if (insert != 0)
		base[insert] = '\0';

	/* 25% of insertions are partail word splices, the rest are whole word */
	splice = (tpc_random(1, 100, I_TITLE_SD) <= I_TITLE_SPLICE)?1:0;
	if (splice)
		{
		if (insert == 0)
			sprintf(res, "%s%s", dig, base);
		else
			if (insert == -1)
				sprintf(res, "%s %s", base, dig);
			else
				sprintf(res, "%s %s%s", base, dig, &base[insert+ 1]);
		}
	else
		{
		if (insert == 0)
			sprintf(res, "%s %s", dig, base);
		else
			if (insert == -1)
				sprintf(res, "%s %s", base, dig);
			else
				sprintf(res, "%s %s %s", base, dig, &base[insert+ 1]);
		}

	/* if result is too long, re-truncate at word boundary */
	if (strlen(res) > MAX_TITLE_LEN)
		{
		splice = MAX_TITLE_LEN;
		while (res[splice] != ' ' && 
			splice > (insert + (SYL_CNT * SYL_WIDTH) + 1))
			splice -= 1;
		res[splice] = '\0';
		}

	return(res);
}

/*
 * Routine: mk_author()
 * Purpose: create A_LNAME as required in Clause 4.6.2.18
 * Params: int author: author number to base the last name upon
 * Returns: char *
 * Called By: main()
 * Calls: digsyl(), tpc_random()
 * Side Effects: since the result is stored in a static char[], the result
 *				will be over-written by a subsequent call
 * TODO: None
 */
char * 
mk_author(int author)
{
	static	char res[A_LNAME_MAX + 1];
	char 	*dig,
			pad[A_LPAD_MAX + 1];
	int		lname_pad,
			len;

	memset(res, ' ', A_LNAME_MAX);
	if (author <= (author_count / A_AUTHOR_DEN))
		dig = digsyl(author, SYL_CNT);
	else
		{
		dig = digsyl(
			tpc_random(A_AUTHOR_MIN, (long)(author_count / A_AUTHOR_DEN), 
				A_LNAME_SD), SYL_CNT);
		}

	strncpy(res, dig, SYL_CNT * SYL_WIDTH);

	/* 75% of names are digsyl() alone; the rest have a a_rnd suffix */
	lname_pad = (tpc_random(1, 100, I_TITLE_SD) <= A_LPAD_PROB)?1:0;
	if (lname_pad)
		{
		len = a_rnd(A_LPAD_MIN, A_LPAD_MAX, A_LNAME_SD, pad);
		strncpy(&res[SYL_CNT * SYL_WIDTH], pad, len);
		}

	res[A_LNAME_MAX] = '\0';

	return(res);
}

#ifdef TEST
main()
{
	char *retval;
	
	retval = digsyl(-1, 0);
	if (retval != NULL)
		printf("Call with D < 0 FAILS (%s)\n", retval);
	else
		printf("Call with D < 0 ok\n");
	retval = digsyl(4, 0);
	if (strcmp(retval, "RE"))
		printf("digsyl(4, 0) FAILS (%s)\n", retval);
	else
		printf("digsyl(4, 0) ok\n");
	retval = digsyl(100, 0);
	if (strcmp(retval, "OGBABA"))
		printf("digsyl(100, 0) FAILS (%s)\n", retval);
	else
		printf("digsyl(100, 0) ok\n");
	retval = digsyl(100, 5);
	if (strcmp(retval, "BABAOGBABA"))
		printf("digsyl(100, 5) FAILS (%s)\n", retval);
	else
		printf("digsyl(100, 5) ok\n");
	retval = digsyl(1972, 0);
	if (strcmp(retval, "OGNGULAL"))
		printf("digsyl(1972, 0) FAILS (%s)\n", retval);
	else
		printf("digsyl(1972, 0) ok\n");
	retval = digsyl(1972, 6);
	if (strcmp(retval, "BABAOGNGULAL"))
		printf("digsyl(1972, 6) FAILS (%s)\n", retval);
	else
		printf("digsyl(1972, 6) ok\n");
}
#endif /* TEST */
