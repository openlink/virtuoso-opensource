/*
 *  buildarg.c
 *
 *  $Id$
 *
 *  Parse a string into argv[], argc
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2017 OpenLink Software
 *  
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *  
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *  
 *  
*/

#include "libutil.h"

#define INIT	10
#define INCR	5


int
build_argv_from_string (const char *s, int *pargc, char ***pargv)
{
  char option[1024];
  char *optptr;
  int instring;
  int escaped;
  int newoption;
  int startopt;
  int store;
  int argc;
  char **argv;
  int nargv;

  *pargc = 0;
  *pargv = NULL;

  if (s == NULL)
    return -1;

  instring = escaped = 0;
  newoption = startopt = 1;
  argc = 0;
  nargv = INIT;
  optptr = NULL;

  argv = salloc (nargv, char *);

  while (*s && (*s == ' ' || *s == '\t'))
    s++;
  while (*s)
    {
      store = 0;
      if (escaped)
	{
	  store = 1;
	  escaped = 0;
	}
      else switch (*s)
	{
	case ' ':
	case '\t':
	  if (!instring)
	    startopt = 1;
	  else
	    store = 1;
	  break;
	case '\'':
	case '\"':
	  newoption = startopt;
	  if (instring)
	    {
	      if (instring == *s)
		instring = 0;
	      else
		store = 1;
	    }
	  else
	    instring = *s;
	  break;
	case '\\':
#ifdef DOSFS
	  if (s[1] == '\"' || s[1] == '\'' || s[1] == '\\')
#endif
	    {
	      newoption = startopt;
	      escaped = 1;
	      break;
	    }
	default:
	  newoption = startopt;
	  store = 1;
	  break;
	}
      if (newoption)
	{
	  startopt = newoption = 0;
	  if (optptr)
	    {
	      *optptr = 0;
	      argv[argc] = s_strdup (option);
	      if (++argc >= nargv - 1)
		{
		  nargv += INCR;
		  argv = (char **) s_realloc (argv, nargv * sizeof (char **));
		}
	    }
	  optptr = option;
	}
      if (store)
        *optptr++ = *s;
      s++;
    }

  if (optptr)
    {
      *optptr = 0;
      argv[argc++] = s_strdup (option);
    }

  *pargc = argc;
  *pargv = argv;
  if (argc >= nargv)
    argv = (char **) s_realloc (argv, ++nargv * sizeof (char **));
  while (argc < nargv)
    argv[argc++] = NULL;

  return 0;
}


void
free_argv (char **argv)
{
  int i;

  if (argv)
    {
      for (i = 0; argv[i]; i++)
	if (argv[i])
	  free (argv[i]);
      free (argv);
    }
}


#ifdef TEST

struct pgm_info program_info;

int
main (int argc, char **argv)
{
  char line[120];
  char **opts;
  int nopt;
  int i;

  while (1)
    {
      putchar ('>');
      if (fgets (line, sizeof (line), stdin) == NULL)
	break;
      line[strlen (line) - 1] = 0;
      build_argv_from_string (line, &nopt, &opts);
      printf ("nopt = %d\n", nopt);
      for (i = 0; i < nopt; i++)
	{
	  fprintf (stderr, "%d: '%s'\n", i, opts[i]);
	}
      free_argv (opts);
    }
  return 0;
}
#endif
