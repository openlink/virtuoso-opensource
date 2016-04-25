/*
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
#include <ctype.h>
#include <memory.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if !defined(_PTRDIFF_T_DEFINED) && !defined(_PTRDIFF_T)
typedef signed long ptrdiff_t;
#endif

typedef struct cut_label_s
{
  const char *cl_name;
  size_t cl_name_len;
  int cl_begin_line;
  int cl_end_line;
  int cl_score;
} cut_label_t;

#define CM_SHOULD_BEGIN_LINE	0x01
#define CM_SHOULD_END_LINE	0x02

typedef struct cut_match_s
{
  const char *cm_pattern;
  size_t cm_pattern_len;
  int cm_flags;
  int cm_score;
  int cm_end_is_included;
  const char *cm_replace;
  size_t cm_replace_len;
} cut_match_t;

typedef struct cut_config_s
{
  cut_label_t *cc_labels;
  int cc_labels_count;
  int cc_min_labels_score;
  int cc_strip_trailing_whitespaces;
  int cc_isql_norm;
  int cc_keep_pragmas;
  cut_match_t *cc_block_starts;
  int cc_block_starts_count;
  int cc_min_block_starts_score;
  cut_match_t *cc_block_hits;
  int cc_block_hits_count;
  int cc_min_block_hits_score;
  cut_match_t *cc_block_ends;
  int cc_block_ends_count;
  cut_match_t *cc_repls;
  int cc_repls_count;
  cut_match_t *cc_rlines;
  int cc_rlines_count;
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

void cut_buf_split_into_lines (cut_buf_t *cb, int strip_trailing_whitespaces)
{
  char *tail = cb->cb_buf;
  int lineidx = 0;
  char **tmp_lines = malloc (sizeof (char *) * (1+cb->cb_len));
  for (;;) {
    char *line_begin = tail;
    char *line_end = strchr (tail, '\n');
    tmp_lines [lineidx++] = tail;
    if (NULL == line_end)
      break;
    tail = line_end+1;
    while ((line_end > line_begin) && ('\r' == line_end[-1]))
      line_end--;
    if (strip_trailing_whitespaces)
      while ((line_end > line_begin) && (('\t' == line_end[-1]) || (' ' == line_end[-1])))
      line_end--;
    line_end[0] = '\0';
    }
  while ((lineidx > 1) && ('\0' == tmp_lines[lineidx-1][0])) lineidx--;
  cb->cb_lines = malloc (sizeof (char *) * lineidx);
  cb->cb_lines_count = lineidx;
  memcpy (cb->cb_lines, tmp_lines, sizeof (char *) * lineidx);
  free (tmp_lines);
}

void cut_buf_compose_text (cut_buf_t *src, int *lineidx_list, cut_buf_t *tgt)
{
  int *lineidx_list_tail = lineidx_list;
  char *tgt_tail;
  tgt->cb_buf = malloc (src->cb_len + 1);
  tgt_tail = tgt->cb_buf;
  while (lineidx_list_tail[0] >= 0)
    {
      char *line = src->cb_lines[(lineidx_list_tail++)[0]];
      while ('\0' != ((tgt_tail++)[0] = (line++)[0])) ;
      tgt_tail[-1] = '\n';
    }
   tgt->cb_len = tgt_tail - tgt->cb_buf;
}

void cut_by_pragmas (cut_env_t *env, int *tgt_lineidx_list, char **err_ret)
{
  int *tgt_lineidx_list_tail = tgt_lineidx_list;
  char *frag, *frag_end;
  int cur_score = 0;
  int line_no;
  int lctr;
  for (line_no = 1; line_no <= env->ce_src.cb_lines_count; line_no++)
    {
    char *src_line_tail = env->ce_src.cb_lines[line_no-1];
    int is_begin = 0;
    frag = strstr (src_line_tail, "#pragma");
    if (NULL == frag)
      goto plain_line;
    frag += 7; while (isspace (frag[0])) frag++;
    for (frag_end = frag; isalnum (frag_end[0]); frag_end++) { /* do nothing */ }
    if ((5 == (frag_end - frag)) && (!memcmp (frag, "begin", 5)))
      {
	is_begin = 1;
	goto get_cut_name;
      }
    if ((3 == (frag_end - frag)) && (!memcmp (frag, "end", 3)))
      {
	is_begin = 0;
	goto get_cut_name;
      }
    if ((6 == (frag_end - frag)) && (!memcmp (frag, "prefix", 6)))
      goto plain_line;
    if ((4 == (frag_end - frag)) && (!memcmp (frag, "line", 4)))
      goto plain_line;
    sprintf (errmsg_buf, "Invalid #pragma at line %d of file '%s'.", line_no, env->ce_src.cb_name); err_ret[0] = errmsg_buf; return;
get_cut_name:
    frag = frag_end; while (isspace (frag[0])) frag++;
    for (frag_end = frag; isalnum (frag_end[0]); frag_end++) { /* do nothing */ }
    if (frag_end == frag)
      {
        sprintf (errmsg_buf, "Identifier missing in '#pragma %s' at line %d of file '%s'.", (is_begin ? "begin" : "end"), line_no, env->ce_src.cb_name); err_ret[0] = errmsg_buf; return; }

    for (lctr = 0; lctr < env->ce_cfg.cc_labels_count; lctr++)
      {
	cut_label_t *curr_cl = env->ce_cfg.cc_labels + lctr;
	if ((curr_cl->cl_name_len == (frag_end - frag)) && (!memcmp (frag, curr_cl->cl_name, curr_cl->cl_name_len)))
	  {
	    if (is_begin)
	      {
		if (curr_cl->cl_begin_line) {
		  sprintf (errmsg_buf, "Redundand '#pragma begin %s' at line %d of file '%s'; previous '#pragma begin %s' was found at line %d.", curr_cl->cl_name, line_no, env->ce_src.cb_name, curr_cl->cl_name, curr_cl->cl_begin_line); err_ret[0] = errmsg_buf; return; }
		curr_cl->cl_begin_line = line_no;
		curr_cl->cl_end_line = 0;
		cur_score += curr_cl->cl_score;
	      }
	    else
	      {
		if (curr_cl->cl_end_line) {
		  sprintf (errmsg_buf, "Redundand '#pragma end %s' at line %d of file '%s'; previous '#pragma end %s' was found at line %d.", curr_cl->cl_name, line_no, env->ce_src.cb_name, curr_cl->cl_name, curr_cl->cl_end_line); err_ret[0] = errmsg_buf; return; }
		curr_cl->cl_begin_line = 0;
		curr_cl->cl_end_line = line_no;
		cur_score -= curr_cl->cl_score;
	      }
	  }
      }
    while (isspace (frag_end[0])) frag_end++;
    if (',' == frag_end[0])
      {
	frag_end++;
	goto get_cut_name;
      }
    if (env->ce_cfg.cc_keep_pragmas)
      {
	(tgt_lineidx_list_tail++)[0] = line_no-1;
      }
    continue;
plain_line:
    if (cur_score >= env->ce_cfg.cc_min_labels_score)
      {
	(tgt_lineidx_list_tail++)[0] = line_no-1;
      }
    };

  for (lctr = 0; lctr < env->ce_cfg.cc_labels_count; lctr++)
    {
      cut_label_t *curr_cl = env->ce_cfg.cc_labels + lctr;
      if (curr_cl->cl_begin_line) {
	sprintf (errmsg_buf, "'#pragma begin %s' at line %d of file '%s' has no matching '#pragma end %s'.", curr_cl->cl_name, curr_cl->cl_begin_line, env->ce_src.cb_name, curr_cl->cl_name); err_ret[0] = errmsg_buf; return; }
    }
   tgt_lineidx_list_tail[0] = -1;
}

ptrdiff_t
cut_find_hit_position (cut_match_t *cm, char *line)
{
  size_t line_len;
  char *hit;
  switch ((cm->cm_flags) & (CM_SHOULD_BEGIN_LINE | CM_SHOULD_END_LINE))
    {
    case 0:
      hit = strstr (line, cm->cm_pattern);
      if (NULL != hit)
        return (hit - line);
      break;
    case CM_SHOULD_BEGIN_LINE:
      if (0 == strncmp (line, cm->cm_pattern, cm->cm_pattern_len))
        return 0;
      break;
    case CM_SHOULD_END_LINE:
      line_len = strlen (line);
      /*while ((line_len > 0) && (((unsigned char *)(line))[line_len-1] <= ' ')) line_len--;*/
      if ((line_len > cm->cm_pattern_len) &&
	(0 == memcmp (line+(line_len - cm->cm_pattern_len), cm->cm_pattern, cm->cm_pattern_len)) )
        return line_len - cm->cm_pattern_len;
      break;
    case CM_SHOULD_BEGIN_LINE | CM_SHOULD_END_LINE:
      if (0 == strcmp (line, cm->cm_pattern))
  return 0;
      break;
    }
  return -1;
}

void cut_by_blocks (cut_env_t *env, int *src_lineidx_list, int *tgt_lineidx_list)
{
  int *src_lineidx_list_tail = src_lineidx_list;
  int *tgt_lineidx_list_tail = tgt_lineidx_list;
  int last_spaceline_idx;
  int *block_start_lineidx_ptr = NULL;
  int *block_end_lineidx_ptr = NULL;
#define BS_SPACE	0
#define BS_SEARCH_START	1
#define BS_SEARCH_HITS	2
#define BS_SKIP_END	3
  int block_status = BS_SPACE;
  int block_score = 0;
  int cm_ctr;
  for (;;)
    {
      char *line;
      if (src_lineidx_list_tail[0] < 0)
	{
	  if (BS_SEARCH_HITS != block_status)
	    break;
	   block_end_lineidx_ptr = src_lineidx_list_tail;
	   goto block_done;
	}
      line = env->ce_src.cb_lines[(src_lineidx_list_tail++)[0]];
      if ('\0' == line[0])
	last_spaceline_idx = src_lineidx_list_tail[-1];

      switch (block_status)
	{
	case BS_SPACE:
	  if ('\0' == line[0])
	    continue;
	  block_score = 0;
	  block_status = BS_SEARCH_START;
	  goto search_for_start;
	case BS_SEARCH_START:
	  if ('\0' == line[0])
	    {
	      block_status = BS_SPACE;
	      continue;
	    }
	  goto search_for_start;
	case BS_SEARCH_HITS:
	  if ('\0' == line[0])
	    {
	      block_status = BS_SPACE;
	      block_end_lineidx_ptr = src_lineidx_list_tail-1;
	      goto block_done;
	    }
	  goto search_for_hits;
	case BS_SKIP_END:
	  if ('\0' == line[0])
	    block_status = BS_SPACE;
	  continue;
	}
search_for_start:
      for (cm_ctr = 0; cm_ctr < env->ce_cfg.cc_block_starts_count; cm_ctr++)
	{
	  cut_match_t *curr_cm = env->ce_cfg.cc_block_starts + cm_ctr;
	  ptrdiff_t hit_pos = cut_find_hit_position (curr_cm, line);
	  if (0 <= hit_pos)
	    block_score += curr_cm->cm_score;
	}
      if (block_score >= env->ce_cfg.cc_min_block_starts_score)
	{
	  block_status = BS_SEARCH_HITS;
	  block_score = 0;
	  block_start_lineidx_ptr = src_lineidx_list_tail-1;
	  goto search_for_hits;
	}
      continue;
search_for_hits:
      for (cm_ctr = 0; cm_ctr < env->ce_cfg.cc_block_hits_count; cm_ctr++)
	{
	  cut_match_t *curr_cm = env->ce_cfg.cc_block_hits + cm_ctr;
	  ptrdiff_t hit_pos = cut_find_hit_position (curr_cm, line);
	  if (0 <= hit_pos)
	    block_score += curr_cm->cm_score;
	}
      for (cm_ctr = 0; cm_ctr < env->ce_cfg.cc_block_ends_count; cm_ctr++)
	{
	  cut_match_t *curr_cm = env->ce_cfg.cc_block_ends + cm_ctr;
	  ptrdiff_t hit_pos = cut_find_hit_position (curr_cm, line);
	  if (0 <= hit_pos)
	    {
              if (curr_cm->cm_end_is_included)
                block_end_lineidx_ptr = src_lineidx_list_tail;
              else
	      block_end_lineidx_ptr = src_lineidx_list_tail-1;
	      goto block_done;
	    }
	}
      continue;
block_done:
      if (block_score >= env->ce_cfg.cc_min_block_hits_score)
	{
	  if ((block_start_lineidx_ptr > src_lineidx_list) && (tgt_lineidx_list_tail > tgt_lineidx_list))
	    (tgt_lineidx_list_tail++)[0] = last_spaceline_idx;
	  while (block_start_lineidx_ptr < block_end_lineidx_ptr)
	    (tgt_lineidx_list_tail++)[0] = (block_start_lineidx_ptr++)[0];
	}
      if (BS_SEARCH_HITS == block_status)
        block_status = BS_SKIP_END;
      continue;
    }
  tgt_lineidx_list_tail[0] = -1;
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

void isql_norm_line_with_xxx (char *line)
{
  char *frag;
  if (NULL != (frag = strstr (line, "parse error")))
    {
      strcpy (frag, "parse error");
    }
  else if (NULL != (frag = strstr (line, "syntax error")))
    {
      strcpy (frag, "parse error"); /* The string "parse error" is shorter than the string "syntax error" so the source is shortened safely */
    }                             /* 012345678 */
  if (NULL != (frag = strstr (line, "at line ")))
    {
      char *tail = frag + 8;
      while (isdigit (tail[0])) tail++;
      while (' ' == (tail[0])) tail++;
      strcpy (frag, "at XXX ");
      memmove (frag+7, tail, strlen (tail)+1);
    }                             /* 0123456789 */
  if (NULL != (frag = strstr (line, "at lines ")))
    {
      char *tail = frag + 9;
      while (isdigit (tail[0])) tail++;
      if ('-' == tail[0])
        {
          tail++;
          while (isdigit (tail[0])) tail++;
        }
      while (' ' == (tail[0])) tail++;
      strcpy (frag, "at XXX ");
      memmove (frag+7, tail, strlen (tail)+1);
    }
}

void isql_norm (cut_env_t *env, int *src_lineidx_list, int *tgt_lineidx_list)
{
  char **lines = env->ce_src.cb_lines;
  int *src_lineidx_list_tail = src_lineidx_list;
  int *tgt_lineidx_list_tail = tgt_lineidx_list;
again:
  while (src_lineidx_list_tail[0] >= 0)
    {
      char *line = lines [src_lineidx_list_tail[0]];
      char *frag;
      isql_norm_line_with_xxx (line);
      if (strbegins (line, "*** Error"))
        {
          char *line_scan;
          int *li_scan_in, ctr;
          int *li_scan = src_lineidx_list_tail + 1;
                                          /* 012345678901234567 */
          if (NULL != (frag = strstr (line, "[Virtuoso Server]")))
            {
              char *tail = frag + 17;
              while (' ' == (tail[0])) tail++;
              strcpy (frag, "VS ");
              memmove (frag+3, tail, strlen (tail)+1);
            }                             /* 012345678901234567 */
          if (NULL != (frag = strstr (line, "[Virtuoso Driver]")))
            {
              char *tail = frag + 17;
              while (' ' == (tail[0])) tail++;
              strcpy (frag, "VD ");
              memmove (frag+3, tail, strlen (tail)+1);
            }
          ctr = 0;
          for (;;)
            {
              if (li_scan[0] < 0)
                goto errmsg_ok;
              li_scan_in = li_scan++;
              line_scan = lines [li_scan_in[0]];
              if (!strcmp (line_scan, "in"))
                break;
              if (ctr++ > 10)
                goto errmsg_ok;
            }
          while (li_scan[0] >= 0)
            {
              line_scan = lines [li_scan[0]];
              if (strbegins (line_scan, "at line ") || strbegins (line_scan, "in lines"))
                {
                  char *err_detail_line;
                  while (src_lineidx_list_tail < li_scan_in)
                    {
                      err_detail_line = lines [src_lineidx_list_tail[0]];
                      isql_norm_line_with_xxx (err_detail_line);
                    (tgt_lineidx_list_tail++)[0] = (src_lineidx_list_tail++)[0];
                    }
#if 0
                  err_detail_line = lines [li_scan[0]];
                  isql_norm_line_with_xxx (err_detail_line);
                  (tgt_lineidx_list_tail++)[0] = li_scan[0];
                  src_lineidx_list_tail = li_scan + 1;
#else
                  src_lineidx_list_tail = li_scan;
#endif
                  goto again;
                }
              li_scan++;
            }
        }
errmsg_ok:
      if (strbegins (line, "Warning "))
        {
                                          /* 012345678901234567 */
          if (NULL != (frag = strstr (line, "[Virtuoso Server]")))
            {
              char *tail = frag + 17;
              while (' ' == (tail[0])) tail++;
              strcpy (frag, "VS ");
              memmove (frag+3, tail, strlen (tail)+1);
            }                             /* 012345678901234567 */
          if (NULL != (frag = strstr (line, "[Virtuoso Driver]")))
            {
              char *tail = frag + 17;
              while (' ' == (tail[0])) tail++;
              strcpy (frag, "VD ");
              memmove (frag+3, tail, strlen (tail)+1);
            }
        }
      if (!strcmp (line, "Type HELP; for help and EXIT; to exit.") ||
	strbegins (line, "--#") ||
	strbegins (line, "--src ") ||
	strbegins (line, "OpenLink Interactive SQL (Virtuoso), version ") ||
	strbegins (line, "Driver: ") )
        {
          src_lineidx_list_tail++;
          goto again;
        }                /* 012345678 */
      if (strbegins (line, "-- Line "))
        {
          char *tail = line + 8;
          while (isdigit (tail[0])) tail++;
          while (' ' == (tail[0])) tail++;
          if (':' == tail[0])
        {
              tail++;
              while (' ' == tail[0]) tail++;
        }
          if ('\0' == tail[0])
            line[2] = '\0';
          else
            memmove (line+3, tail, strlen (tail)+1);
        }                             /* 012345678 */
      else if (strends (line, " msec."))
        {
          char *lineend = line + strlen (line) - strlen (" msec.");
          char *oldlineend = lineend;
          while ((lineend > line) && isdigit (lineend[-1])) lineend--;
          if (lineend < oldlineend)
            strcpy (lineend, "0 msec.");
        }

/*Default action: */
      (tgt_lineidx_list_tail++)[0] = (src_lineidx_list_tail++)[0];

    }
  tgt_lineidx_list_tail[0] = -1;
}



void replace_and_write (cut_env_t *env, const char *tgt_name, int *lineidx_list, char **err_ret)
{
  int *lineidx_list_tail = lineidx_list;
  FILE *f = fopen (tgt_name, "wb");
  if (NULL == f) {
    sprintf (errmsg_buf, "Cannot open file '%s' for writing.", tgt_name); err_ret[0] = errmsg_buf; return; }
  while (lineidx_list_tail[0] >= 0)
    {
      char *tail, *line = env->ce_src.cb_lines[(lineidx_list_tail++)[0]];
      int rctr, rcount;
      int tail_len;
      rcount = env->ce_cfg.cc_rlines_count;
      for (rctr = 0; rctr < rcount; rctr++)
        {
	  cut_match_t *curr_cm = env->ce_cfg.cc_rlines + rctr;
	  ptrdiff_t hit_pos = cut_find_hit_position (curr_cm, line);
          if (0 > hit_pos)
            continue;
          /*line_len = strlen (line);
          while ((line_len > 0) && (((unsigned char *)(line))[line_len-1] <= ' ')) line_len--;*/
          fwrite (curr_cm->cm_replace, curr_cm->cm_replace_len, 1, f);
          fputc ('\n', f);
          goto nextline; /* see_below */
        }
      rcount = env->ce_cfg.cc_repls_count;
      tail = line;
      tail_len = strlen (tail);
      for (;;)
        {
          ptrdiff_t min_hit_pos = 0xFFFFFF;
          cut_match_t *first_cm = NULL;
          for (rctr = 0; rctr < rcount; rctr++)
            {
              cut_match_t *curr_cm = env->ce_cfg.cc_repls + rctr;
              ptrdiff_t hit_pos;
              if ((CM_SHOULD_BEGIN_LINE & curr_cm->cm_flags) && (tail != line))
                continue;
              hit_pos = cut_find_hit_position (curr_cm, tail);
              if ((0 > hit_pos) || (hit_pos >= min_hit_pos))
                continue;
              min_hit_pos = hit_pos;
              first_cm = curr_cm;
              if (0 == hit_pos)
                break;
            }
          if (NULL == first_cm)
            break;
          if (0 < min_hit_pos)
            fwrite (tail, min_hit_pos, 1, f);
          fwrite (first_cm->cm_replace, first_cm->cm_replace_len, 1, f);
          tail += min_hit_pos + first_cm->cm_pattern_len;
        }
      fwrite (tail, strlen (tail), 1, f);
      fputc ('\n', f);

nextline: ;
    }
  fclose (f);
}

void *malloc_zero (size_t sz)
{
  void *res = malloc (sz);
  memset (res, sz, 0);
  return res;
}

int main (int argc, const char *argv[])
{
  char *err = NULL;
  cut_env_t *env = malloc_zero (sizeof (cut_env_t));
  int argctr = 1;
  int score = 1;
  int default_min_labels_score = 0;
  int default_min_block_hits_score = 0;
  int default_min_block_starts_score = 0;
  int min_labels_score_is_set = 0;
  int min_block_hits_score_is_set = 0;
  int min_block_starts_score_is_set = 0;
  int *lineidx_list = 0;
  env->ce_src.cb_name = NULL;
  env->ce_tgt.cb_name = NULL;
  env->ce_src.cb_buf = NULL;
  env->ce_tgt.cb_buf = NULL;
  env->ce_src.cb_len = 0;
  env->ce_tgt.cb_len = 0;
  env->ce_cfg.cc_labels = malloc_zero (sizeof (cut_label_t) * argc);
  env->ce_cfg.cc_labels_count = 0;
  env->ce_cfg.cc_block_starts = malloc_zero (sizeof (cut_match_t) * argc);
  env->ce_cfg.cc_block_starts_count = 0;
  env->ce_cfg.cc_block_hits = malloc_zero (sizeof (cut_match_t) * argc);
  env->ce_cfg.cc_block_hits_count = 0;
  env->ce_cfg.cc_block_ends = malloc_zero (sizeof (cut_match_t) * argc);
  env->ce_cfg.cc_block_ends_count = 0;
  env->ce_cfg.cc_repls = malloc_zero (sizeof (cut_match_t) * argc);
  env->ce_cfg.cc_repls_count = 0;
  env->ce_cfg.cc_rlines = malloc_zero (sizeof (cut_match_t) * argc);
  env->ce_cfg.cc_rlines_count = 0;

  while (argctr < argc)
    {
      if (!strcmp ("-I", argv[argctr]))
	{
          score = 1;
	  argctr += 1;
	  continue;
	}
      if (!strcmp ("-X", argv[argctr]))
	{
          score = -1;
	  argctr += 1;
	  continue;
	}
      if (!strcmp ("-P", argv[argctr]) && (argctr < (argc-1)))
	{
	  cut_label_t *new_cl = env->ce_cfg.cc_labels + env->ce_cfg.cc_labels_count++;
	  new_cl->cl_name = argv [argctr+1];
	  new_cl->cl_name_len = strlen (new_cl->cl_name);
	  new_cl->cl_begin_line = 0;
	  new_cl->cl_end_line = 0;
	  new_cl->cl_score = score;
	  default_min_labels_score += ((score > 0) ? score : 0);
	  argctr += 2;
	  continue;
	}
      if (!strncmp ("-BS", argv[argctr],3) && (argctr < (argc-1)))
	{
	  cut_match_t *new_cm = env->ce_cfg.cc_block_starts + env->ce_cfg.cc_block_starts_count++;
	  new_cm->cm_pattern = argv [argctr+1];
	  new_cm->cm_pattern_len = strlen (new_cm->cm_pattern);
	  new_cm->cm_flags = atoi (argv[argctr]+3);
	  new_cm->cm_score = score;
	  default_min_block_starts_score += ((score > 0) ? score : 0);
	  argctr += 2;
	  continue;
	}
      if (!strncmp ("-BH", argv[argctr],3) && (argctr < (argc-1)))
	{
	  cut_match_t *new_cm = env->ce_cfg.cc_block_hits + env->ce_cfg.cc_block_hits_count++;
	  new_cm->cm_pattern = argv [argctr+1];
	  new_cm->cm_pattern_len = strlen (new_cm->cm_pattern);
	  new_cm->cm_flags = atoi (argv[argctr]+3);
	  new_cm->cm_score = score;
	  default_min_block_hits_score += ((score > 0) ? score : 0);
	  argctr += 2;
	  continue;
	}
      if (!strncmp ("-BT", argv[argctr],3) && (argctr < (argc-1)))
	{
	  cut_match_t *new_cm = env->ce_cfg.cc_block_ends + env->ce_cfg.cc_block_ends_count++;
	  new_cm->cm_pattern = argv [argctr+1];
	  new_cm->cm_pattern_len = strlen (new_cm->cm_pattern);
	  new_cm->cm_flags = atoi (argv[argctr]+3);
	  new_cm->cm_score = 1;
	  argctr += 2;
	  continue;
	}
      if (!strncmp ("-BE", argv[argctr],3) && (argctr < (argc-1)))
	{
	  cut_match_t *new_cm = env->ce_cfg.cc_block_ends + env->ce_cfg.cc_block_ends_count++;
	  new_cm->cm_pattern = argv [argctr+1];
	  new_cm->cm_pattern_len = strlen (new_cm->cm_pattern);
	  new_cm->cm_flags = atoi (argv[argctr]+3);
          new_cm->cm_end_is_included = 1;
	  new_cm->cm_score = 1;
	  argctr += 2;
	  continue;
	}
      if (!strcmp ("-N", argv[argctr]) && (argctr < (argc-1)))
	{
	  env->ce_cfg.cc_min_labels_score = atoi (argv[argctr+1]);
	  min_labels_score_is_set = 1;
	  argctr += 2;
	  continue;
	}
      if (!strcmp ("-NBS", argv[argctr]) && (argctr < (argc-1)))
	{
	  env->ce_cfg.cc_min_block_starts_score = atoi (argv[argctr+1]);
	  min_block_starts_score_is_set = 1;
	  argctr += 2;
	  continue;
	}
      if (!strcmp ("-NBH", argv[argctr]) && (argctr < (argc-1)))
	{
	  env->ce_cfg.cc_min_block_hits_score = atoi (argv[argctr+1]);
	  min_block_hits_score_is_set = 1;
	  argctr += 2;
	  continue;
	}
      if (!strncmp ("-RL", argv[argctr],3) && (argctr < (argc-2)))
	{
	  cut_match_t *new_cm = env->ce_cfg.cc_rlines + env->ce_cfg.cc_rlines_count++;
	  new_cm->cm_pattern = argv [argctr+1];
	  new_cm->cm_pattern_len = strlen (new_cm->cm_pattern);
	  new_cm->cm_flags = atoi (argv[argctr]+3);
	  new_cm->cm_replace = argv [argctr+2];
	  new_cm->cm_replace_len = strlen (new_cm->cm_replace);
	  argctr += 3;
	  continue;
	}
      if (!strncmp ("-RS", argv[argctr],3) && (argctr < (argc-2)))
	{
	  cut_match_t *new_cm = env->ce_cfg.cc_repls + env->ce_cfg.cc_repls_count++;
	  new_cm->cm_pattern = argv [argctr+1];
	  new_cm->cm_pattern_len = strlen (new_cm->cm_pattern);
	  new_cm->cm_flags = atoi (argv[argctr]+3);
	  new_cm->cm_replace = argv [argctr+2];
	  new_cm->cm_replace_len = strlen (new_cm->cm_replace);
	  argctr += 3;
	  continue;
	}
      if (!strcmp ("-ISQL", argv[argctr]))
	{
          env->ce_cfg.cc_isql_norm = 1;
	  argctr += 1;
	  continue;
	}
      if (!strcmp ("-KP", argv[argctr]))
	{
          env->ce_cfg.cc_keep_pragmas = 1;
	  argctr += 1;
	  continue;
	}
      if (!strcmp ("-WS", argv[argctr]))
	{
          env->ce_cfg.cc_strip_trailing_whitespaces = 1;
	  argctr += 1;
	  continue;
	}
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
      fprintf (stderr, "Invalid argument %d (%s)\n", argctr, argv[argctr]);
      goto usage;
    }

  if (NULL == env->ce_src.cb_name)
    {
      fprintf (stderr, "No source file specified, add -s option\n");
      goto usage;
    }
  if (NULL == env->ce_tgt.cb_name)
    {
      fprintf (stderr, "No destination file specified, add -o option\n");
      goto usage;
    }

  if (!min_labels_score_is_set)
    env->ce_cfg.cc_min_labels_score = default_min_labels_score;
  if (!min_block_starts_score_is_set)
    env->ce_cfg.cc_min_block_starts_score = default_min_block_starts_score;
  if (!min_block_hits_score_is_set)
    env->ce_cfg.cc_min_block_hits_score = default_min_block_hits_score;

  readtextfile (env->ce_src.cb_name, &env->ce_src.cb_buf, &env->ce_src.cb_len, &err);
  if (NULL != err)
    { fprintf (stderr, "%s", err); exit (1); }

  cut_buf_split_into_lines (&(env->ce_src), env->ce_cfg.cc_strip_trailing_whitespaces);

  lineidx_list = malloc (sizeof(int) * (env->ce_src.cb_lines_count+1));
  cut_by_pragmas (env, lineidx_list, &err);
  if (NULL != err)
    { fprintf (stderr, "%s", err); exit (1); }

  if (env->ce_cfg.cc_isql_norm)
    {
      int *old_lineidx_list = lineidx_list;
      int *new_lineidx_list = malloc (sizeof(int) * (env->ce_src.cb_lines_count+1));
      isql_norm (env, old_lineidx_list, new_lineidx_list);
      lineidx_list = new_lineidx_list;
      free (old_lineidx_list);
    }

  if ((0 != env->ce_cfg.cc_block_starts_count) || (0 != env->ce_cfg.cc_block_hits_count) || (0 != env->ce_cfg.cc_block_ends_count))
    {
      int *old_lineidx_list = lineidx_list;
      int *new_lineidx_list = malloc (sizeof(int) * (env->ce_src.cb_lines_count+1));
      cut_by_blocks (env, old_lineidx_list, new_lineidx_list);
      lineidx_list = new_lineidx_list;
      free (old_lineidx_list);
    }
 
  if ((0 != env->ce_cfg.cc_rlines_count) || (0 != env->ce_cfg.cc_repls_count))
    {
      replace_and_write (env, env->ce_tgt.cb_name, lineidx_list, &err);
    }
  else
    {
  cut_buf_compose_text (&(env->ce_src), lineidx_list, &(env->ce_tgt));
  writetextfile (env->ce_tgt.cb_name, env->ce_tgt.cb_buf, env->ce_tgt.cb_len, &err);
    }
  if (NULL != err)
    { fprintf (stderr, "%s", err); exit (1); }
  exit (0);
usage:
  fprintf(stderr,
"\n"
"cutter -- a tool to extract selected fragments of text\n"
"\n"
"  Usage: cutter option1 option2 ...\n"
"\n"
"-s  <sourcefile>\tFile to read\n"
"-o  <targetfile>\tFile to write extracts\n"
"\n"
"-WS\tStrip trailing whitespaces before any other processing\n"
"\n"
"-P  <pragma-tag>\tAdd <pragma-tag> to scoring rule set\n"
"-X\tEvery tag listed after this option will decrement score by 1\n"
"-I\tEvery tag listed after this option will increment score by 1\n"
"-N  <integer>\tMinimal score of tags that makes the line valid\n"
"\n"
"-ISQL\tEdit the text to wipe out minor details of ISQL log\n"
"-KP\tKeep #pragma begin/end lines (the default is to filter them out)\n"
"\n"
"-BS<flag>  <pattern>\tAdd <pattern> with <flags> to scoring as block start\n"
"-BH<flag>  <pattern>\tAdd <pattern> with <flags> to scoring as block hit\n"
"-BE<flag>  <pattern>\tAdd <pattern> with <flags> to scoring as block end\n"
"-BT<flag>  <pattern>\tSame as -BE but for first line past the end of block\n"
"-NBS  <integer>\tMinimal score of block starts that makes the block valid\n"
"-NBH  <integer>\tMinimal score of block hits that makes the block valid\n"
"\n"
"-RL<flag>  <pattern> <new-line>\tReplaces whole line containing <pattern>\n"
"-RS<flag>  <pattern> <replace>\tReplaces <pattern> substring with <replace>\n"
"\n"
"<flags> specifies how <pattern> is searched in the lines of <sourcefile>:\n"
"0 means that the matching line should contain the <pattern> as a substring\n"
"1 means that the matching line should begin with <pattern> substring\n"
"2 means that the matching line should end with <pattern> substring\n"
"3 means that the matching line should be equal to <pattern>\n"
"\n"
"\n"
"The program reads the source file into an array of lines.\n"
"It writes to the target file every line that matches some logical condition.\n"
"There are two sorts of conditions:\n"
"\n"
"Lines may be tagged, and every line with sufficient number of appropriate tags\n"
"will pass the 'tagging test'. This let you extract subchapters of the text.\n"
"\n"
"Groups of lines may start with lines that match 'begin' patterns and end with\n"
"lines that match 'end' patterns; all lines of a group pass the 'block test' if\n"
"the group contains sufficient number of lines that match 'hit' patterns.\n"
"This let you extract blocks of program code.\n"
"\n"
"Lines with substrings like '#pragma begin <tag1>, <tag2>,... ,<tagN>'\n"
"or '#pragma end <tag1>, <tag2>,... ,<tagN>' assign tags to lines between them,\n"
"so lines between '#pragma begin foo' and #pragma end foo' are tagged by\n"
"'foo' tag keyword. Every '-P foo' option will add 1 to score of every line\n"
"that is tagged by 'foo' (or subtract 1 if -X option is used)'. Lines with\n"
"score not less than specified in '-N' option will pass the 'tagging test'.\n"
"\n"
"\n"
"Examples:\n"
"\n"
"cutter -P control -P validator -X -P bad -X -P base -N 1 -s vspx.sql -o cv.tmp\n"
"\n"
" - Write to cv.tmp all subchapters of vspx.sql that are tagged by\n"
"tags 'control' and/or 'validator', but neither 'bad' nor 'base':\n"
"\n"
"\n"
"cutter -BH1 'create function DB.DBA.SAMPLE' -BT3 ';' -s long.sql -o sample.sql\n"
"\n"
" - Write to sample.sql block(s) of code from long.sql. Selected block should\n"
"contain a 'hit' line that begins with 'create function DB.DBA.SAMPLE'\n"
"substring. End of every block is indicated by a single-character line ';'.\n"
"No patterns specified for block begin, so ';' at the end of one block also\n"
"indicates that the next block begins at next line.\n"
"\n"
"When both pragma tags and blocks are specified, the file first divided into\n"
"lines, then some parts of it are removed by pragmas then remaining lines are\n"
"filtered according to block rules.\n"
"\n"
"-ISQL normalizes the text if it's an output of ISQL client. The normalization\n"
"takes place after processing 'by pragmas' but before processing 'by blocks'.\n"
"\n"
"Search and replace is the last operation before writing the result.\n"
"First of all, whole lines are repalced (-RL options). Lines that are not\n"
"replaced by -RL are replaced substring by substring (-R options).\n"
   );
  exit (2);
}
