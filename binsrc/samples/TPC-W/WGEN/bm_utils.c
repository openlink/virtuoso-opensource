/* @(#) bm_utils.c 12.1.1.6@(#)
 *
 * Various routines that handle distributions, value selections and
 * seed value management for the DSS benchmark. Current functions:
 * env_config -- set config vars with optional environment override
 * a_rnd(min, max) -- random alphanumeric within length range
 * dist_select() -- select a string from the set of size
 * read_dist(file, name, distribution *) -- read named dist from file
 * e_str(set, min, max) -- build an embedded str
 * dsscasecmp() -- version of strcasecmp()
 * dssncasecmp() -- version of strncasecmp()
 * getopt()
 */

#include "tpcw.h"
#include <stdio.h>
#include <time.h>
#include <errno.h>
#include <string.h>
#ifdef HP
#include <strings.h>
#endif            /* HP */
#include <ctype.h>
#include <math.h>
#ifndef _POSIX_SOURCE
#include <malloc.h>
#endif /* POSIX_SOURCE */
#include <fcntl.h>
#ifdef IBM
#include <sys/mode.h>
#endif /* IBM */
#include <sys/types.h>
#include <sys/stat.h>
/* Lines added by Chuck McDevitt for WIN32 support */
#ifdef WIN32
#ifndef _POSIX_
#include <io.h>
#ifndef S_ISREG
#define S_ISREG(m) ( ((m) & _S_IFMT) == _S_IFREG )
#define S_ISFIFO(m) ( ((m) & _S_IFMT) == _S_IFIFO )
#endif 
#endif
#ifndef stat
#define stat _stat
#endif
#ifndef fdopen
#define fdopen _fdopen
#endif
#ifndef open
#define open _open
#endif
#ifndef O_RDONLY
#define O_RDONLY _O_RDONLY
#endif
#ifndef O_WRONLY
#define O_WRONLY _O_WRONLY
#endif
#ifndef O_CREAT
#define O_CREAT _O_CREAT
#endif
#endif
/* End of lines added by Chuck McDevitt for WIN32 support */

static char alpha_num[65] =
"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

char     *getenv(const char *name);
void usage();
extern seed_t Seed[];

/*
 * env_config: look for a environmental variable setting and return its
 * value; otherwise return the default supplied
 */
char     *
env_config(char *var, char *dflt)
{
   static char *evar;

   if ((evar = getenv(var)) != NULL)
      return (evar);
   else
      return (dflt);
}

/*
 * generate a random string with length randomly selected in [min, max]
 * and using the characters in alphanum (currently includes a space
 * and comma)
 */
int
a_rnd(int min, int max, int column, char *dest)
{
	static int set_len = -1;
	long	i,
			len,
			char_int;

	if (set_len == -1)
		set_len = strlen(alpha_num);
	len = tpc_random(min, max, column);
	for (i = 0; i < len; i++)
		{
		if (i % 5 == 0)
			char_int = tpc_random(0, MAX_LONG, column);
		*(dest + i) = alpha_num[char_int % set_len];
		char_int >>= 6;
		}
	*(dest + len) = '\0';

	return (len);
}

static int
dist_search(distribution *d, int w)
{
	int	low=0,
		high=d->count - 1,
		current;

	do {
		current=low + (high - low)/2;
		if (d->list[current].weight == w)
			return(current);
		else if (d->list[current].weight > w)
			high = current;
		else
			low = current;
		} while ((high - low) > 1);

	return((d->list[high].weight > w)?low:high);
}

/*
 * return the string associate with the LSB of a uniformly selected
 * long in [1, max] where max is determined by the distribution
 * being queried and an optional upper bound
 */
int
dist_select(distribution *s, int c, char *target, int bound)
{
    long      i = 0;
    long      j;

    if (bound == NONE || bound > s->count - 1)
		j = tpc_random(1, s->list[s->count - 1].weight, c);
	else
		j = tpc_random(1, s->list[bound - 1].weight, c);
    i = dist_search(s, j);
	/*
	while (s->list[i].weight < j)
        i++;
	*/
    strcpy(target, s->data + s->list[i].index);
    return(i);
}

/*
* load a distribution from a flat file into the target structure;
* should be rewritten to allow multiple dists in a file
*/
#define AVG_LEN	5
void
read_dist(char *path, char *name, distribution *target)
{
FILE     *fp;
char      line[256],
         token[256],
        *c;
long      weight,
         count = 0,
         name_set = 0,
         count_set = 0,
		 avg_len = AVG_LEN,
		 index = 0,
		 size = 0,
		 line_cnt = 0;

    if (dpath == NULL)
		{
		sprintf(line, "%s%c%s", 
			env_config(CONFIG_TAG, CONFIG_DFLT), PATH_SEP, path);
		fp = fopen(line, "r");
		OPEN_CHECK(fp, line);
		}
	else
		{
		fp = fopen(dpath, "r");
		OPEN_CHECK(fp, dpath);
		}
    while (fgets(line, sizeof(line), fp) != NULL)
        {
		line_cnt += 1;
        if ((c = strchr(line, '\n')) != NULL)
            *c = '\0';
        if ((c = strchr(line, '#')) != NULL)
            *c = '\0';
        if (*line == '\0')
            continue;

        if (!name_set)
            {
            if (!dsscasecmp(strtok(line, "\n\t "), "BEGIN"))
				if (!dsscasecmp(strtok(NULL, "\n\t "), name))
					name_set = 1;
				continue;
            }
        else
            {
            if (!dssncasecmp(line, "END", 3))
				if (strlen(line) > strlen(name))
					if (!dssncasecmp(&line[strlen(line) - strlen(name)], 
							name, strlen(name)))
					break;
            }

        if (sscanf(line, "%[^|]|%ld", token, &weight) != 2)
            continue;

        if (!count_set)
			{
			if (!dsscasecmp(token, "count"))
				{
				target->count = weight;
				target->list =
					(set_member *)
						malloc((size_t)(weight * sizeof(set_member)));
				MALLOC_CHECK(target->list);
				size = target->count * (AVG_LEN + 3);
				target->data = (char *)malloc(size);
					MALLOC_CHECK(target->data);
				index = 0;
				target->max = 0;
				count_set = 1;
				}
			continue;
			}

        if ((index + (int)strlen(token) + 1) >= size)
			{
			size += target->count;
			target->data = 
				(char *)realloc(target->data, size);
			MALLOC_CHECK(target->data);
			}
		strcpy(target->data + index, token);
        target->max += weight;
        target->list[count].weight = target->max;
        target->list[count].index = index;
		index += strlen(token) + 1;

        count += 1;
        } /* while fgets() */

    if (count != target->count)
        {
        fprintf(stderr, "Read error on dist '%s' (%d/%d)\n", 
			name, count, target->count);
        exit(1);
        }
	target->permute = (long *)NULL;
    fclose(fp);
    return;
}

long
dssncasecmp(char *s1, char *s2, int n)
{
    for (; n > 0; ++s1, ++s2, --n)
        if (tolower(*s1) != tolower(*s2))
            return ((tolower(*s1) < tolower(*s2)) ? -1 : 1);
        else if (*s1 == '\0')
            return (0);
        return (0);
}

long
dsscasecmp(char *s1, char *s2)
{
    for (; tolower(*s1) == tolower(*s2); ++s1, ++s2)
        if (*s1 == '\0')
            return (0);
    return ((tolower(*s1) < tolower(*s2)) ? -1 : 1);
}

#ifndef STDLIB_HAS_GETOPT
int optind = 0;
int opterr = 0;
char *optarg = NULL;

int
getopt(int ac, char **av, char *opt)
{
    static char *nextchar = NULL;
    char *cp;
    char hold;

    if (optarg == NULL)
        {
        optarg = (char *)malloc(BUFSIZ);
        MALLOC_CHECK(optarg);
        }

    if (!nextchar || *nextchar == '\0')
        {
        optind++;
        if (optind == ac)
            return(-1);
        nextchar = av[optind];
        if (*nextchar != '-')
            return(-1);
        nextchar +=1;
        }

    if (nextchar && *nextchar == '-')   /* -- termination */
        {
        optind++;
        return(-1);
        }
    else        /* found an option */
        {
        cp = strchr(opt, *nextchar);
        nextchar += 1;
        if (cp == NULL) /* not defined for this run */
            return('?');
        if (*(cp + 1) == ':')   /* option takes an argument */
            {
            if (*nextchar)
                {
                hold = *cp;
                cp = optarg;
                while (*nextchar)
                    *cp++ = *nextchar++;
                *cp = '\0';
                *cp = hold;
                }
            else        /* white space separated, use next arg */
                {
                if (++optind == ac)
                    return('?');
                strcpy(optarg, av[optind]);
                }
            nextchar = NULL;
            }
        return(*cp);
        }
}
#endif /* STDLIB_HAS_GETOPT */
