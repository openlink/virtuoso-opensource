/*
 *  expandav.c
 *
 *  $Id$
 *
 *  Commandline expansion
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2012 OpenLink Software
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

#include <libutil.h>


int glob_argc;
char **glob_argv;

#define REALLOC_AMOUNT 20

static int max_argv;

/*
 *  Add a token to the global argv list
 */
static void
add_argv (char *argv_element)
{
  char *new_element;

  if (glob_argc >= max_argv)
    {
      max_argv += REALLOC_AMOUNT;
      glob_argv = (char **) s_realloc (glob_argv, sizeof (char *) * max_argv);
    }

  new_element = s_strdup (argv_element);
  glob_argv[glob_argc++] = new_element;
}


#define ignore()	((car) == ' ' || (car) == '\t' || (car) == '\n')
#define gett()		car = fgetc (fd)

static char *
get_token (FILE *fd)
{
  static char token[500];
  char *tp;
  int car;

  do gett (); while (ignore ());

  if (car == EOF)
    return NULL;

  tp = token;
  if (car == '\"' || car == '\'')
    {
      int delim = car;
      gett ();
      while (car != delim && car != '\n' && car != EOF &&
	  (u_int) (tp - token) < sizeof (token) - 1)
	{
	  *tp++ = car;
	  gett ();
	}
#if 0
      if (car != delim)
	fputs ("unterminated string\n", stderr);
#endif
    }
  else
    {
      while ((u_int) (tp - token) < sizeof (token) - 1 && !ignore ())
	{
	  *tp++ = car;
	  gett ();
	}
    }

  *tp++ = '\0';

  return token;
}


static void
handle_response (char *response)
{
  FILE *response_fd;
  char *token;

  if ((response_fd = fopen (response, "r")) == NULL)
    {
      log (L_ERR, N_("unable to open response file %s"), response);
      terminate (1);
    }

  while ((token = get_token (response_fd)) != NULL)
    add_argv (token);
  fclose (response_fd);
}


/*
 *  Expand argv vector
 *
 *  Values for how:
 *    EXP_WILDCARD	Perform wildcard expansion (DEPRECATED)
 *    EXP_RESPONSE	Handle response files (last argument @filename)
 */
void
expand_argv (int *argc, char ***argv, int how)
{
  char *element;
  int nargs;
  int i;
  
  glob_argc = 0;

  nargs = *argc;
  max_argv = nargs + REALLOC_AMOUNT;
  glob_argv = salloc (max_argv, char *);

  for (i = 0; i < nargs; i++)
    {
      element = (*argv)[i];
      if (*element == '@' && (how & EXP_RESPONSE) && i == nargs - 1)
	handle_response (element + 1);
      else
	add_argv (element);
    }

  *argc = glob_argc;
  *argv = glob_argv;
}


#ifdef TEST
void
main (int argc, char **argv)
{
  int i;

  expand_argv (&argc, &argv, EXP_RESPONSE);
  for (i = 0; i < argc; i++)
    printf ("%d: `%s'\n", i, argv[i]);
}
#endif
