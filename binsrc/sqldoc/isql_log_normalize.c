/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2014 OpenLink Software
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
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct cut_search_replace_s
{
  char *csr_search;
  char *csr_replace;
} cut_search_replace_t;

typedef struct cut_config_s
{
  cut_search_replace_t **cc_replaces;
  int cc_replace_count;
} cut_config_t;

typedef struct cut_buf_s
{
  const char *cb_name;
  char *cb_buf;
  size_t cb_len;
  char **cb_lines;
  int cb_lines_count;
}
cut_buf_t;

typedef struct cut_env_s
{
  cut_config_t ce_cfg;
  cut_buf_t ce_src;
  cut_buf_t ce_tgt;
} cut_env_t;

static char errmsg_buf[1000];

void readtextfile (const char *src_name, char **bufptr, size_t *lenptr, char **err_ret)
{
  FILE *f = fopen (src_name, "rt");
  size_t filelen;
  if (NULL == f) {
    sprintf (errmsg_buf, "Cannot open file '%s' for reading.", src_name); err_ret[0] = errmsg_buf; return; }
  if (0 != fseek (f, 0L, SEEK_END)) {
    fclose (f);
    sprintf (errmsg_buf, "Cannot seek file '%s' to end.", src_name); err_ret[0] = errmsg_buf; return; }
  filelen = ftell (f);
  if (0 != fseek (f, 0L, SEEK_SET)) {
    fclose (f);
    sprintf (errmsg_buf, "Cannot seek file '%s' before reading.", src_name); err_ret[0] = errmsg_buf; return; }
  lenptr[0] = filelen;
  bufptr[0] = malloc (filelen+1);
  bufptr[0][filelen] = '\0';
  if (0 != filelen)
    if (1 != fread (bufptr[0], filelen, 1, f)) {
      fclose (f);
      sprintf (errmsg_buf, "Cannot read %ld bytes from file '%s'.", (long)(filelen), src_name); err_ret[0] = errmsg_buf; return; }
  fclose (f);
}

void writetextfile (const char *tgt_name, char *buf, size_t len, char **err_ret)
{
  FILE *f = fopen (tgt_name, "wb");
  if (NULL == f) {
    sprintf (errmsg_buf, "Cannot open file '%s' for writing.", tgt_name); err_ret[0] = errmsg_buf; return; }
  if (0 != len)
    {
      if (1 != fwrite (buf, len, 1, f))
	{
	  fclose (f);
	  sprintf (errmsg_buf, "Cannot write %ld bytes to file '%s'.", (long)(len), tgt_name); err_ret[0] = errmsg_buf; return; }
    }
  fclose (f);
}

void cut_buf_split_into_lines (cut_buf_t *cb)
{
  char *tail = cb->cb_buf;
  int lineidx = 0;
  char **tmp_lines = malloc (sizeof (char *) * (1+cb->cb_len));
  for (;;) {
    char *line_end = strchr (tail, '\n');
    tmp_lines [lineidx++] = tail;
    if (NULL == line_end)
      break;
    tail = line_end+1;
    while ((line_end > tail) && (('\r' == line_end[-1]) || ('\t' == line_end[-1]) || (' ' == line_end[-1])))
      line_end--;
    line_end[0] = '\0';
    }
  while ((lineidx > 0) && ('\0' == tmp_lines[lineidx-1][0])) lineidx--;
  cb->cb_lines = malloc (sizeof (char *) * lineidx);
  cb->cb_lines_count = lineidx;
  memcpy (cb->cb_lines, tmp_lines, sizeof (char *) * lineidx);
  free (tmp_lines);
}

void cut_buf_compose_text (cut_buf_t *tgt)
{
  int lineidx;
  char *tgt_tail;
  size_t bufsize = 1;
  for (lineidx = 0; lineidx < tgt->cb_lines_count; lineidx++)
    bufsize += (strlen (tgt->cb_lines[lineidx]) + 1);
  tgt->cb_buf = malloc (bufsize);
  tgt_tail = tgt->cb_buf;
  for (lineidx = 0; lineidx < tgt->cb_lines_count; lineidx++)
    {
      char *line = tgt->cb_lines[lineidx];
      while ('\0' != ((tgt_tail++)[0] = (line++)[0])) ;
      tgt_tail[-1] = '\n';
    }
  tgt_tail[0] = '\0';
  tgt->cb_len = tgt_tail - tgt->cb_buf;
}

char *cut_pattern_match (const char *src, const char *pattern, const char *replace)
{
  char *res = malloc ( strlen (src) + 1 + strlen (replace));
  int echomode = 1;
  const char *srctail = src;
  const char *patterntail;
  char *restail = res;
  for (patterntail = pattern; '\0' != patterntail[0]; patterntail++)
    {
      switch (patterntail[0])
        {
	  case '(': echomode = 0; continue;
	  case ')': echomode = 1; continue;
	  case '9':
	    if (!isdigit (srctail[0]))
	      goto fail;
	    do srctail++; while (isdigit (srctail[0]));
	    continue;
        }
    }

fail:
  free (res);
  return NULL;
}

int strbegins (const char * haystack, const char * needle)
{
  size_t hlen = strlen (haystack), nlen = strlen (needle);
  return (hlen >= nlen) && !memcmp (haystack, needle, nlen);
}

int strends (const char * haystack, const char * needle)
{
  size_t hlen = strlen (haystack), nlen = strlen (needle);
  return (hlen >= nlen) && !strcmp (haystack+hlen-nlen, needle);
}

int stralphabet (const char *from, const char *to, const char *alphabet)
{
  for (; from < to; from++)
    {
      if (NULL == strchr (alphabet, from[0]))
	return 0;
    }
  return 1;
}

void cut_substitute_all (cut_env_t *env, cut_buf_t *tgt, cut_buf_t *src)
{
  int sr_ctr;
  int lineidx;
  tgt->cb_lines_count = src->cb_lines_count;
  tgt->cb_lines = malloc (sizeof (char *) * (src->cb_len));
  for (lineidx = 0; lineidx < src->cb_lines_count; lineidx++)
    {
      char *hit1, *hit2;
      char *srcline = src->cb_lines[lineidx];
      char *tgtline;
      if (
	('\0' == srcline[0]) ||
	strbegins (srcline, "--#") ||
	strbegins (srcline, "--src ") ||
	strbegins (srcline, "OpenLink Interactive SQL (Virtuoso), version ") ||
	!strcmp (srcline, "Type HELP; for help and EXIT; to exit.") )
	{
	  tgt->cb_lines[lineidx] = tgtline = strdup ("");
	  continue;
	}
      if (
	(hit1 = strstr (srcline, "-- ")) &&
	(hit2 = strstr (hit1, " msec")) &&
	stralphabet (hit1 + strlen("-- "), hit2, "0123456789") )
	{
	  tgtline = malloc (strlen (srcline) + 6);
	  strcpy (tgtline, srcline);
	  sprintf (tgtline + (hit1 - srcline), "-- 00000%s", hit2);
	  srcline = tgtline;
	}
      if (
	(hit1 = strstr (srcline, "Connected to OpenLink Virtuoso VDBMS")) )
	{
	  tgtline = malloc (strlen (srcline)+1);
	  strcpy (tgtline, srcline);
	  strcpy (tgtline + (hit1 - srcline), hit1 + strlen ("Connected to OpenLink Virtuoso VDBMS"));
	  srcline = tgtline;
	}
      if (
	(hit1 = strstr (srcline, "Driver: ")) &&
	(hit2 = strstr (hit1, " OpenLink Virtuoso ODBC Driver")) &&
	stralphabet (hit1 + strlen ("Driver: "), hit2, "0123456789.") )
	{
	  tgtline = malloc (strlen (srcline)+1);
	  strcpy (tgtline, srcline);
	  strcpy (tgtline + (hit1 - srcline), hit2 + strlen (" OpenLink Virtuoso ODBC Driver"));
	  srcline = tgtline;
	}
      if (
	(hit1 = strstr (srcline, "parse error [")) &&
	(hit2 = strstr (hit1, "] at")) &&
	stralphabet (hit1 + strlen ("parse error ["), hit2, "0123456789.-") )
	{
	  tgtline = strdup (srcline);
	  sprintf (tgtline + (hit1 - srcline), "parse error at%s", hit2 + strlen ("] at"));
	  srcline = tgtline;
	}
      if (strends (srcline, "parse error"))
	{
	  tgtline = malloc (strlen (srcline) + 4);
	  sprintf (tgtline, "%s at", srcline);
	  srcline = tgtline;
	}
      if (
	(hit1 = strstr (srcline, "-- Line ")) &&
	(hit2 = strstr (hit1, ": exit")) &&
	stralphabet (hit1 + strlen("-- Line "), hit2, "0123456789") )
	{
	  tgtline = strdup (srcline);
	  sprintf (tgtline + (hit1 - srcline), "exit%s", hit2 + strlen (": exit"));
	  srcline = tgtline;
	}

      for (sr_ctr = 0; sr_ctr < env->ce_cfg.cc_replace_count; sr_ctr++)
        {
	  cut_search_replace_t *sr = env->ce_cfg.cc_replaces[sr_ctr];
	  char *search = sr->csr_search;
	  char *replace = sr->csr_replace;
	  while (NULL != (hit1 = strstr (srcline, search)))
	    {
	      tgtline = malloc (strlen (srcline) + strlen (replace) + 1 - strlen (search));
	      memcpy (tgtline, srcline, (hit1 - srcline));
	      strcpy (tgtline + (hit1 - srcline), replace);
	      strcat (tgtline, hit1 + strlen (search));
	      srcline = tgtline;
	    }
	}
      tgt->cb_lines[lineidx] = tgtline = strdup (srcline);
	      
    }
}



int main (int argc, const char *argv[])
{
  char *err = NULL;
  cut_env_t *env = malloc (sizeof (cut_env_t));
  int argctr = 1;
  env->ce_src.cb_name = NULL;
  env->ce_tgt.cb_name = NULL;
  env->ce_src.cb_buf = NULL;
  env->ce_tgt.cb_buf = NULL;
  env->ce_src.cb_len = 0;
  env->ce_tgt.cb_len = 0;
  env->ce_cfg.cc_replaces = malloc (sizeof (cut_search_replace_t *) * ((argc+2) / 3));
  env->ce_cfg.cc_replace_count = 0;
  while (argctr < argc)
    {
      if (!strcmp ("-s", argv[argctr]) && (argctr < (argc-1)))
	{
	  env->ce_src.cb_name = argv[argctr+1];
	  argctr += 2;
	  continue;
	}
      if (!strcmp ("-o", argv[argctr]) && (argctr < (argc-1)))
	{
	  env->ce_tgt.cb_name = argv[argctr+1];
	  argctr += 2;
	  continue;
	}
      if (!strcmp ("-R", argv[argctr]) && (argctr < (argc-2)))
	{
	  cut_search_replace_t *sr = malloc (sizeof (cut_search_replace_t));
	  env->ce_cfg.cc_replaces[env->ce_cfg.cc_replace_count] = sr;
	  sr->csr_search = argv[argctr+1];
	  sr->csr_replace = argv[argctr+2];
	  env->ce_cfg.cc_replace_count += 1;
	  argctr += 3;
	  continue;
	}
      fprintf (stderr, "Invalid argument %d (%s)\n", argctr, argv[argctr]);
      goto usage;
    }

  if (NULL == env->ce_src.cb_name)
    {
      fprintf (stderr, "No source file specified\n");
      goto usage;
    }
  if (NULL == env->ce_tgt.cb_name)
    {
      fprintf (stderr, "No destination file specified\n");
      goto usage;
    }

  readtextfile (env->ce_src.cb_name, &env->ce_src.cb_buf, &env->ce_src.cb_len, &err);
  if (NULL != err)
    { fprintf (stderr, "%s", err); exit (1); }

  cut_buf_split_into_lines (&(env->ce_src));

  cut_substitute_all (env, &(env->ce_tgt), &(env->ce_src));

  cut_buf_compose_text (&(env->ce_tgt));
 
  writetextfile (env->ce_tgt.cb_name, env->ce_tgt.cb_buf, env->ce_tgt.cb_len, &err);
  if (NULL != err)
    { fprintf (stderr, "%s", err); exit (1); }
  exit (0);
usage:
  fprintf(stderr, "Usage... !!!");
  exit (2);
}
