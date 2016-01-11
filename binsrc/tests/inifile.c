/*
 *  inifile.c
 *
 *  $Id$
 *
 *  Get fields out of an ini file and possibly rewrite them
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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

#define IN_LIBUTIL
#include <libutil.h>

extern char version[];

char *f_inifile	  = "oplrqb.ini";
char *f_section	  = NULL;
char *f_key	  = NULL;
char *f_value	  = NULL;
int   f_create    = 0;		/* Dummy parameter */
int   f_nocreate  = 0;

struct pgm_option options[] =
{
  {"inifile",	'f', ARG_STR,  &f_inifile,
  	N_("use this ini file")},
  {"create",    'c', ARG_NONE, &f_create,
  	N_("create the ini file if it does not exist (default)")},
  {"nocreate",  'n', ARG_NONE, &f_nocreate,
  	N_("do not create the ini file if it does not exist")},
  {"section",	's', ARG_STR,  &f_section,
  	N_("name of the section")},
  {"key",	'k', ARG_STR,  &f_key,
  	N_("name of the key")},
  {"value",	'v', ARG_STR,  &f_value,
  	N_("the value you want to write")},
  {0}
};

struct pgm_info program_info =
{
  NULL,
  version,
  "",
  EXP_RESPONSE | EXP_WILDCARD,
  options
};


void
usage (void)
{
  default_usage();
  fprintf(stderr, "\n");
  fprintf(stderr, _("If <value> contains a single - character, the <key> within"
  		  " <section> will be\ndeleted.\n\n"));
  fprintf(stderr, _("If both <key> and <value> contain a single - character "
  		  " the whole <section>\nwill be deleted.\n"));
  terminate (1);
}


int
main (int argc, char **argv)
{
  PCONFIG config;
  char *keyvalue = NULL;
#ifdef MALLOC_DEBUG
  dk_mutex_t *x = mutex_allocate();
  char *y = dk_alloc_box(1,1);
  dk_hash_t * z = hash_table_allocate(10);
#endif

  initialize_locale ("openlink");
  initialize_program (&argc, &argv);

  /*
   *  Check usage
   */
  if (!f_section && !f_key && !f_value)
    {
      default_usage();

      exit(0);
    }

  /*
   *  Try to open the ini file
   */
  if (cfg_init2 (&config, f_inifile, !f_nocreate) == -1)
    {
      if (f_nocreate && errno == ENOENT)
        exit (0);	/* Ignore silently */

      perror (f_inifile);
      exit (1);
    }

  /*
   *  Both <section> and <key> are mandatory fields
   */
  if (!f_section)
    {
      fprintf (stderr, _("%s: you must enter a section.\n"), MYNAME);
      exit (1);
    }
  if (!f_key)
    {
      fprintf (stderr, _("%s: you must enter a key or - to delete the section.\n"),
	  MYNAME);
      exit (1);
    }

  /*
   *  If handed a value, rewrite the ini file, possibly deleting one key or
   *  a whole section
   */
  if (f_value)
    {
      /*
       *  If the value contains a single '-' character we must
       *  signal the config routine to delete this key
       */
      if (f_value[0] == '\0' || (f_value[0] == '-' && f_value[1] == '\0'))
	f_value = NULL;

      /*
       *  If the key contains a single '-' character we must signal the
       *  config routines to delete the whole section
       */
      if (f_key[0] == '-' && f_key[1] == '\0')
	f_key = f_value = NULL;

      cfg_write (config, f_section, f_key, f_value);
      if (cfg_commit (config) == -1)
        {
	  perror (f_inifile);
	  exit (1);
	}
    }
  else
    {
      /*
       *  If the section/key pair is not found the keyvalue will be NULL.
       *  As some fprintf implementations cannot cope with this we set it
       *  to an empty string
       */
      if (cfg_getstring (config, f_section, f_key, &keyvalue) || keyvalue == NULL)
        keyvalue = "";

      fprintf (stdout, "%s\n", keyvalue);
    }

  return 0;
}
