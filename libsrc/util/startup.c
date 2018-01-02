/*
 *  startup.c
 *
 *  $Id$
 *
 *  Provides default program initialization
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2018 OpenLink Software
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

#define DEFAULT_LINE_LENGTH 79

static struct option *long_options;


/*
 *  default program initialisation
 *
 *  - determines program_name
 *  - optionally expands argv (MSDOS)
 *  - parses options (long & short)
 *  - shows usage & version information
 */
void
initialize_program (int *argc, char ***argv)
{
  char short_options[120];
  static int f_flag;
  int optcnt;
  struct pgm_option *popt_ptr;
  struct option *lopt_ptr;
  char *sopt_ptr;
  int option_index;
  int key;

#ifdef WIN32
  StartNTApplication ();
#endif

  if (program_info.flags & (EXP_WILDCARD | EXP_RESPONSE))
    expand_argv (argc, argv, program_info.flags);

  /*
   *  if no program name is given, try to
   *  determine the name by analyzing argv[0]
   */
  if (program_info.program_name == NULL)
    {
#ifdef DOSFS
      char *s = setext ((*argv)[0], "", EXT_REMOVE);
      char *t = strrchr (s, '\\');
      program_info.program_name = s_strdup (strlwr (t ? t + 1 : s));
#elif defined(VMS)
      program_info.program_name = 
	  s_strdup (strlwr (strrchr (setext ((*argv)[0], "", EXT_REMOVE),
          ']') + 1));
#else
      char *myname = strrchr ((*argv)[0], '/');
      program_info.program_name = myname ? myname + 1 : (*argv)[0];
#endif
    }

  /*
   *  Counts the options in program options.
   *  Creates a long option array suitable for getopt_long.
   *  Creates a short option array.
   *
   *  Each long option points to the variable f_flag, so that getopt_long
   *  will return a 0 when a long option is specified. By examining f_flag
   *  we exactly know which long option was given.
   *
   *  Short options are looked up in the program option array
   */
  for (popt_ptr = program_info.program_options; popt_ptr->long_opt; popt_ptr++)
    ;
  optcnt = (int) (popt_ptr - program_info.program_options);
  sopt_ptr = short_options;
  lopt_ptr = long_options = salloc (optcnt + 1, struct option);
  switch (program_info.flags & EXP_ORDER_MASK)
    {
    case EXP_REQUIRE_ORDER:
      *sopt_ptr++ = '+';
      break;
    case EXP_RETURN_IN_ORDER:
      *sopt_ptr++ = '-';
      break;
    default:
      break;
    }
  for (popt_ptr = program_info.program_options; popt_ptr < program_info.program_options + optcnt;
       popt_ptr++, lopt_ptr++)
    {
      lopt_ptr->name = popt_ptr->long_opt;
      lopt_ptr->has_arg = popt_ptr->arg_type == ARG_NONE ? 0 : 1;
      lopt_ptr->flag = &f_flag;
      lopt_ptr->val = (int) (popt_ptr - program_info.program_options);
      if (popt_ptr->short_opt)
	{
	  *sopt_ptr++ = popt_ptr->short_opt;
	  if (popt_ptr->arg_type != ARG_NONE)
	    *sopt_ptr++ = ':';
	}
    }
  *sopt_ptr = 0;

  /*
   *  Parse the options
   */
  opterr = 0;
  while (1)
    {
      option_index = 0;
      key = getopt_long (*argc, *argv, short_options, long_options,
	  &option_index);

      if (key == EOF)
	break;

      if (key == '?')
	usage ();

      if (key == 0)
	popt_ptr = &program_info.program_options[f_flag];
      else
	{
	  for (popt_ptr = program_info.program_options;
	       popt_ptr->short_opt != key &&
	       popt_ptr < program_info.program_options + optcnt;
	       popt_ptr++);

	  if (popt_ptr->short_opt != key)
	    usage ();
	}
      /*
       *  Affect the main program
       *  possible arg_type values:
       *
       *    ARG_NONE
       *        No argument required -- sets pointed integer to 1
       *    ARG_STR
       *        Requires argument -- sets pointed char * to optarg
       *    ARG_INT
       *        Requires argument -- set pointed integer to atoi(optarg)
       *    ARG_LONG
       *        Requires argument -- set pointed long to atol(optarg)
       *    ARG_FUNC
       *        Requires argument -- calls pointed function(struct pgm_option)
       */
      if (popt_ptr->arg_ptr != NULL)
	switch (popt_ptr->arg_type)
	  {
	  case ARG_NONE:
	    *(int *) (popt_ptr->arg_ptr) = 1;
	    break;
	  case ARG_STR:
	    *(char **) (popt_ptr->arg_ptr) = optarg;
	    break;
	  case ARG_INT:
	    *(int *) (popt_ptr->arg_ptr) = atoi (optarg);
	    break;
	  case ARG_LONG:
	    *(int32 *) (popt_ptr->arg_ptr) = (int32) atol (optarg);
	    break;
	  case ARG_FUNC:
	    (*(int (*)(struct pgm_option *)) (popt_ptr->arg_ptr)) (popt_ptr);
	    break;
	  }
    }

  free (long_options);
}


/*
 *  default_usage ()
 *
 *  Prints a default usage by analyzing the program options
 *
 *  appearance:
 *
 *  <PROGRAM> <VERSION>
 *
 *  Usage:
 *    <PROGRAM> [options] [+option arg] [+option num] ...
 *              [+option arg] <EXTRA_INFO>
 *    +option   descriptive text
 *    +option   descriptive text
 */
void
default_usage (void)
{
  struct pgm_option *opt;
  char buf[120];
  char *bp;
  int fmtlen;
  int len;

  /*
   *  The header
   */
  fprintf (stderr, _("%s\nUsage:\n  %s"), program_info.program_version,
	   program_info.program_name);

  /*
   * [short options]
   */
  for (bp = buf, opt = program_info.program_options; opt->long_opt; opt++)
    {
      if (opt->short_opt)
	{
	  if (bp == buf)
	    {
	      *bp++ = '[';
	      *bp++ = '-';
	    }
	  *bp++ = opt->short_opt;
	}
    }
  len = (int) strlen (program_info.program_name) + 1;
  if (bp > buf)
    {
      *bp++ = ']';
      *bp++ = 0;
      fprintf (stderr, " %s", buf);
      len += (int) strlen (buf) + 1;
    }
  /*
   *  [+long options]
   */
  fmtlen = 0;
  for (opt = program_info.program_options; opt->long_opt; opt++)
    {
      int i = (int) strlen (opt->long_opt);
      if (!opt->help)
	continue;
      if (!strcmp (opt->long_opt, "internal"))
        continue;
      if (i > fmtlen)
	fmtlen = i;
      sprintf (buf, " [+%s", opt->long_opt);
      switch (opt->arg_type)
	{
	case ARG_NONE:
	  break;
	case ARG_INT:
	case ARG_LONG:
	  strcat (buf, " num");
	  break;
	default:
	  strcat (buf, " arg");
	  break;
	}
      strcat (buf, "]");
      if (len + strlen (buf) >= DEFAULT_LINE_LENGTH)
	{
#ifdef BROKEN_PRINTF
          int i;
          len = strlen (program_info.program_name) + 2;
          fputc ('\n', stderr);
          for (i = 0; i < len; i++)
            fputc (' ', stderr);
#else
	  len = (int) strlen (program_info.program_name) + 2;
	  fprintf (stderr, "\n%*s", -len, "");
#endif
	}
      fputs (buf, stderr);
      len += (int) strlen (buf);
    }
  /*
   *  extra usage
   */
  if (program_info.extra_usage && program_info.extra_usage[0])
    {
      int msglen = (int) strlen(program_info.extra_usage);
      if (len + 1 + msglen >= DEFAULT_LINE_LENGTH)
	{
#ifdef BROKEN_PRINTF
          int i;
          len = strlen (program_info.program_name) + 2;
          fputc ('\n', stderr);
          for (i = 0; i < len; i++)
            fputc (' ', stderr);
#else
	  len = (int) strlen (program_info.program_name) + 2;
	  fprintf (stderr, "\n%*s", -len, "");
#endif
	}
      fprintf (stderr, " %s", program_info.extra_usage);
    }
  fputc ('\n', stderr);
  /*
   *  option help
   */
  fmtlen = -(fmtlen + 2);
  for (opt = program_info.program_options; opt->long_opt; opt++)
    {
      if (!opt->help)
	continue;
#ifdef BROKEN_PRINTF
      int i = strlen (opt->long_opt);
      if (!strcmp (opt->long_opt, "internal"))
        continue;
      fprintf (stderr, "  +%s", opt->long_opt);
      while (i++ < -fmtlen);
        fputc (' ', stderr);
      fprintf (stderr, "%s\n", gettext(opt->help));
#else
      if (!strcmp (opt->long_opt, "internal"))
        continue;
      fprintf (stderr, "  +%*s %s\n",
	  fmtlen, opt->long_opt, gettext(opt->help));
#endif
    }
}
