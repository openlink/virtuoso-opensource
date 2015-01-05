/*
 *  sqlbif.c
 *
 *  $Id$
 *
 *  Diff functionality
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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
 */

#include "libutil.h"
#include "sqlnode.h"
#include "sqlbif.h"
#include "wi.h"

#define DIFF_MATCH_VAL	(+100)
#define DIFF_DELETE_VAL	(-1)
#define DIFF_INSERT_VAL	(+1)

#define DIFF_MATCH (box_num(DIFF_MATCH_VAL))
#define DIFF_DELETE (box_num(DIFF_DELETE_VAL))
#define DIFF_INSERT (box_num(DIFF_INSERT_VAL))

#define DIFF_MATCH_STR	"matched: "
#define DIFF_DELETE_STR	"delete: "
#define DIFF_INSERT_STR "insert: "

#define DIFF_MODE_GNU		1
#define DIFF_MODE_VIRT		2
#define DIFF_MODE_CTX		3
#define DIFF_MODE_DIFF_E	4 /* not real diff -e output, some mix of -e and --normal */


#define DIFF_CMD_RANGE_DELETE 1
#define DIFF_CMD_RANGE_INSERT 2

#define DIFF_APPLY_STATE_INSERT	101

#define DIFF_CMD_CMD		1
#define DIFF_CMD_DELINS		2
#define DIFF_CMD_UNKNOWN	-1

#define DIFF_MAX_LENGTH	1300
#define DIFF_MAX_LENGTH_STR "1300"

#define NO_NEW_LINE_SUFFIX "\n\\ No newline at end of file\n"

typedef struct diff_cmd_s {
  int	dc_type;
  int	dc_from;
  int	dc_to;
} diff_cmd_t;


ptrlong * LCS_Delta (ptrlong * X, ptrlong * Y)
{
  int cwidth = BOX_ELEMENTS (Y) + 1;
  int ylen = box_length (Y) / sizeof (ptrlong);
  int xlen = box_length (X) / sizeof (ptrlong);
  ptrlong * c = (ptrlong*) dk_alloc_box ((xlen+1)*(1+ylen)*sizeof(ptrlong), DV_ARRAY_OF_LONG);
  ptrlong * b = (ptrlong*) dk_alloc_box ((xlen+1)*(1+ylen)*sizeof(ptrlong), DV_ARRAY_OF_LONG);
  int i,j;
  for (i=1; i<=xlen; i++)
    c[i*cwidth] = 0;
  for (j=0; j<=ylen; j++)
    c[j] = 0;
  for (i=0; i<(1+xlen)*(1+ylen); i++)
    b[i] = 0;
  for (i=1; i<=xlen; i++)
    {
      for (j=1; j<=ylen; j++)
	{
	  if (X[i-1] == Y[j-1])
	    {
	      c[i*cwidth + j] = c[(i-1)*cwidth + j - 1] + 1;
	      b[i*cwidth + j] = 1; /* up-left */
	    }
	  else if (c[(i-1)*cwidth + j] >= c[i*cwidth + j-1])
	    {
	      c[i*cwidth + j] = c[(i-1)*cwidth + j];
	      b[i*cwidth + j] = 2; /* up */
	    }
	  else
	    {
	      c[i*cwidth + j] = c[i*cwidth + j-1];
	      b[i*cwidth + j] = 3; /* left */
	    }
	}
    }
  dk_free_box ((box_t) c);
  return b;
}

int print_LCS (ptrlong * X, ptrlong * Y, ptrlong * b)
{
  int ylen = box_length (Y) / sizeof (ptrlong);
  int xlen = box_length (X) / sizeof (ptrlong);
  int i, j;
  int cwidth = ylen + 1;
  for (i = 0; i <= xlen; i++)
    {
      for (j = 0; j <= ylen; j++)
	{
	  int r = b[i*cwidth + j];
	  if (r == 1)
	    printf ("%ld,%ld\t", X[i-1], Y[j-1]);
	  else if (r == 2)
	    printf ("up\t");
	  else if (r == 3)
	    printf ("left\t");
	  else
	    printf ("-1\t");
	}
      printf ("\n");
    }
  return 0;
}


caddr_t* build_path_from_LCS (ptrlong * X, ptrlong * Y, ptrlong * b)
{
  int ylen = box_length (Y) / sizeof (ptrlong);
  int xlen = box_length (X) / sizeof (ptrlong);
  int i,j;
  int r;
  int cwidth = ylen + 1;
  dk_set_t path = 0;
  int state = 0;
  i = xlen;
  j = ylen;

  while ( (i >= 1) && (j >= 1))
    {
      r = b[i*cwidth+j];
      if (state && (r != 1))
	{
	  dk_set_push (&path, DIFF_MATCH);
	  dk_set_push (&path, box_num (state));
	  state = 0;
	}
      if (r == 1)
	{
	  state++;
	  --i;
	  --j;
	}
      else if (r == 2)
	{

	  dk_set_push (&path, DIFF_DELETE);
	  dk_set_push (&path, box_num (X[i-1]));
	  --i;
	}
      else if (r == 3)
	{
	  dk_set_push (&path, DIFF_INSERT);
	  dk_set_push (&path, box_num (Y[j-1]));
	  j--;
	}
    }
  if (state)
    {
      dk_set_push (&path, DIFF_MATCH);
      dk_set_push (&path, box_num (state));
    }
  while (i >= 1)
    {
      dk_set_push (&path, DIFF_DELETE);
      dk_set_push (&path, box_num (X[--i]));
    }
  while (j >= 1)
    {
      dk_set_push (&path, DIFF_INSERT);
      dk_set_push (&path, box_num (Y[--j]));
    }
  return (caddr_t*)list_to_array (dk_set_nreverse (path));
}

caddr_t parse_text_to_lines_1 (caddr_t * start, caddr_t end_text,
			       int detect_new_line /* 0 - do not detect
						      1 - just detect new line and write the suffix
						      2 - detect suffix and add new line if needed */ )
{
  caddr_t pointer, line_start;
  line_start = pointer = start[0];
  while (line_start < end_text)
    {
      if ((pointer[0] == '\r') ||
	  (pointer[0] == '\n') ||
	  (pointer == end_text))
	{
	  caddr_t line;
	  caddr_t old_pointer;
	  if ((1 == detect_new_line) && (pointer == end_text)) /* no new line at the end */
	    {
	      line = dk_alloc_box (pointer - line_start + strlen (NO_NEW_LINE_SUFFIX) + 1 /* 0 */, DV_STRING);
	      strncpy (line, line_start, (pointer - line_start));
	      strcpy (line + (pointer - line_start), NO_NEW_LINE_SUFFIX);
	      start[0] = pointer;
	      return line;
	    }
	  old_pointer = pointer;
	  if ('\r' == pointer[0])
	    pointer++;
	  if ('\n' == pointer[0])
	    pointer++;
	  if ((2 == detect_new_line) && ('\\' == pointer[0])) /* no new line suffix */
	    {
	      line = box_dv_short_nchars (line_start, old_pointer - line_start);
	      while ((pointer < end_text) && (pointer[0] != '\n'))
		++pointer;
	    }
	  else
	    {
	      line = dk_alloc_box (old_pointer - line_start + 2 /* \n + 0 */, DV_STRING);
	      strncpy (line, line_start, (old_pointer - line_start));
	      line[old_pointer - line_start] = '\n';
	      line[old_pointer - line_start + 1] = '\0';
	    }
	  start[0] = pointer;
	  return line;
	}
      if ((line_start[0] != '\r') &&
	  (line_start[0] != '\n'))
	pointer++;
    }
  return NULL;
}


#define istext(ch) (((ch) & 0xF8) && ((ch != 0x08)))

static int binstrchr (caddr_t line)
{
  int idx;
  for (idx = 0; idx < box_length(line) - 1; ++idx)
    {
      if (!istext (line[idx]))
	return idx;
    }
  return -1;
}

int parse_text_to_lines (caddr_t text, id_hash_t* lhash, ptrlong** res_array, ptrlong* currid, caddr_t ** line_array)
{
  caddr_t pointer, line_start, end_text;
  dk_set_t res_set = NULL;
  int res = -1;
  line_start = pointer = text;
  end_text = text + box_length (text) - 1;
  while (line_start < end_text)
    {
      caddr_t line = parse_text_to_lines_1 (&line_start, end_text, 1);
      if (line)
	{
	  ptrlong * idptr;
	  ptrlong id;
	  if (0 <= binstrchr (line))
	    {
	      dk_free_box ((box_t) line);
	      goto ret;
	    }
	  idptr = (ptrlong*) id_hash_get (lhash, (caddr_t) &line);
	  if (!idptr)
	    {
	      id = ++currid[0];
	      id_hash_set (lhash, (caddr_t)(&line), (caddr_t)(&id));
	    }
	  else
	    {
	      id = idptr[0];
	      dk_free_box ((box_t) line);
	    }
	  dk_set_push (&res_set, (caddr_t)id);
	}
      else
	break;
    }
  res = 1;
 ret:
  res_array [0] = (ptrlong*) list_to_array (res_set);
  if (line_array)
    {
      id_hash_iterator_t hit;
      ptrlong* id;
      caddr_t* line;
      line_array[0] = (caddr_t*) dk_alloc_box ((1+currid[0]) * sizeof(caddr_t), DV_ARRAY_OF_POINTER);
      memset (line_array[0], 0, (1+currid[0]) * sizeof(caddr_t));
      id_hash_iterator (&hit, lhash);

      while (hit_next (&hit, (char **)&line, (char **)&id))
	{
	  if (id && line)
	    line_array[0][id[0]] = line[0];
	}
    }
  return res;
}


caddr_t path_to_text (caddr_t* path, caddr_t * line_array, ptrlong mode)
{
  dk_session_t * ses;
  caddr_t text;
  int inx = 0;
  long line_A_counter = 0, line_B_counter = 0;
  ses = strses_allocate ();

  if ((mode != DIFF_MODE_GNU) &&
      (mode != DIFF_MODE_VIRT) &&
      (mode != DIFF_MODE_DIFF_E))
    return box_string ("not supported!!!");

  while (inx < BOX_ELEMENTS (path))
    {
      ptrlong op = unbox (path[inx]);
      if (op == DIFF_MATCH_VAL)
	{
	  ptrlong skip = unbox (path[++inx]);
	  if ((DIFF_MODE_GNU == mode) ||
	      (DIFF_MODE_DIFF_E == mode))
	    {
	      line_A_counter+=skip;
	      line_B_counter+=skip;
	    }
	  else if (mode == DIFF_MODE_VIRT)
	    {
	      char tmp[255];
	      sprintf (tmp, "%ld\n", skip);
	      session_buffered_write (ses, DIFF_MATCH_STR, strlen (DIFF_MATCH_STR));
	      session_buffered_write (ses, tmp, strlen(tmp));
	    }
	  ++inx;
	  continue;
	}
      else
	{
	  ptrlong id;
	  caddr_t line;
	  if ((op != DIFF_INSERT_VAL)  &&
	      (op != DIFF_DELETE_VAL))
	    GPF_T;
	  if (inx + 1 >= BOX_ELEMENTS (path))
	    GPF_T;
	  id = unbox (path[++inx]);
	  line = line_array[id];
	  if (op == DIFF_DELETE_VAL)
	    ++line_A_counter;
	  else if (op == DIFF_INSERT_VAL)
	    ++line_B_counter;
	  if (mode == DIFF_MODE_VIRT)
	    {
	      if (op == DIFF_INSERT_VAL)
		session_buffered_write (ses, DIFF_INSERT_STR, strlen (DIFF_INSERT_STR));
	      else if (op == DIFF_DELETE_VAL)
		session_buffered_write (ses, DIFF_DELETE_STR, strlen (DIFF_DELETE_STR));
	      else
		GPF_T;
	      if (id >= BOX_ELEMENTS (line_array))
		GPF_T;
	      session_buffered_write (ses, line, strlen (line));
/* 	      session_buffered_write_char ('\n', ses);  */
	    }
	  else if ( (DIFF_MODE_GNU == mode) ||
		    (DIFF_MODE_DIFF_E == mode) )
	    {
	      char tmp[255];
	      char prefix[3];
	      int forward_inx = inx - 1;
	      int delins_ops;
	      while (((forward_inx + 2) < BOX_ELEMENTS (path)) &&
		     (unbox (path[forward_inx+2]) == op))
		forward_inx += 2;
	      delins_ops = 1 + (forward_inx - inx + 1)/2;
	      if (DIFF_MODE_GNU == mode)
		{
		  if(1 == delins_ops) /* deleted, inserted one line */
		    sprintf (tmp, "%ld%s%ld\n", line_A_counter, op == DIFF_INSERT_VAL ? "a" : "d", line_B_counter);
		  else if (op == DIFF_DELETE_VAL)
		    sprintf (tmp, "%ld,%ldd%ld\n", line_A_counter, line_A_counter + delins_ops - 1, line_B_counter);
		  else if (op == DIFF_INSERT_VAL)
		    sprintf (tmp, "%lda%ld,%ld\n", line_A_counter, line_B_counter, line_B_counter + delins_ops - 1);
		  if (DIFF_DELETE_VAL == op)
		    line_A_counter += delins_ops - 1;
		  else if (DIFF_INSERT_VAL == op)
		    line_B_counter += delins_ops - 1;
		}
	      else
		{
		  if(1 == delins_ops) /* deleted, inserted one line */
		    sprintf (tmp, "%ld%s\n", line_A_counter, op == DIFF_INSERT_VAL ? "a" : "d");
		  else if (op == DIFF_DELETE_VAL)
		    sprintf (tmp, "%ld,%ldd\n", line_A_counter, line_A_counter + delins_ops - 1);
		  else if (op == DIFF_INSERT_VAL)
		    sprintf (tmp, "%lda\n", line_A_counter);
		  if (DIFF_DELETE_VAL == op)
		    line_A_counter += delins_ops - 1;
		  else if (DIFF_INSERT_VAL == op)
		    line_B_counter += delins_ops - 1;
		}
	      session_buffered_write (ses, tmp, strlen (tmp));
	      if (op == DIFF_INSERT_VAL)
		strcpy (prefix, "> ");
	      else
		strcpy (prefix, "< ");
	      if ((DIFF_MODE_GNU == mode) ||
		  ( (DIFF_MODE_DIFF_E == mode) &&
		    (DIFF_INSERT_VAL == op) ))
		{
		  while (1)
		    {
		      if ((op != DIFF_INSERT_VAL)  &&
			  (op != DIFF_DELETE_VAL))
			GPF_T;
		      line = line_array[id];
		      session_buffered_write (ses, prefix, strlen (prefix));
		      session_buffered_write (ses, line, strlen (line));
/* 		      session_buffered_write_char ('\n', ses); */

		      ++inx; ++inx;
		      if (inx > (forward_inx + 1))
			break;
		      id = unbox (path[inx]);
		      op = unbox (path[inx-1]);
		    }
		}
	      inx = forward_inx + 1;
	    }
	}
      inx++;
    }
  text = strses_string (ses);
  strses_free (ses);
  return text;
}


static
int diff_cmd_get (diff_cmd_t * cmd, caddr_t cmd_line)
{
  caddr_t _to;
  if ((cmd_line[0] == '>') ||
      (cmd_line[0] == '<') )
    return DIFF_CMD_DELINS;
  if ( (_to = strchr (cmd_line, 'd')) )
    {
      caddr_t _comma = strchr (cmd_line, ',');
      cmd->dc_type = DIFF_CMD_RANGE_DELETE;
      cmd->dc_from = atoi (cmd_line);
      if (_comma)
	cmd->dc_to = atoi (_comma + 1);
      else
	cmd->dc_to = cmd->dc_from;
      return DIFF_CMD_CMD;
    }
  else if ( (_to = strchr (cmd_line, 'a')) )
    {
      cmd->dc_type = DIFF_CMD_RANGE_INSERT;
      cmd->dc_from = atoi (cmd_line);
      cmd->dc_to = cmd->dc_from;
      return DIFF_CMD_CMD;
    }
  return DIFF_CMD_UNKNOWN;
}

static
void diff_apply_fill_text (caddr_t * curr_text, caddr_t end_text, int * curr_line, int from, dk_session_t * ses)
{
  int lines = from - curr_line[0] + 1;
  while ( (from < 0) || (lines--))
    {
      caddr_t line = parse_text_to_lines_1 (curr_text, end_text, 0);
      if (line)
	{
	  session_buffered_write (ses, line, strlen(line));
/* 	  session_buffered_write_char ('\n', ses); */
	  curr_line[0]++;
	  dk_free_box ((box_t) line);
	}
      else
	break;
    }
}

static
void diff_apply_delete (caddr_t * curr_text, caddr_t end_text, int * curr_line)
{
  caddr_t line = parse_text_to_lines_1 (curr_text, end_text, 0);
  curr_line[0]++;
  dk_free_box ((box_t) line);
}



static
void diff_apply_insert (char * insert_line,
			dk_session_t * ses)
{
  session_buffered_write (ses, insert_line, strlen (insert_line));
}

static
caddr_t diff_apply (caddr_t text, caddr_t patch, ptrlong mode)
{
  caddr_t curr_text;
  caddr_t start = curr_text = text;
  caddr_t end = start + box_length (start) - 1;
  dk_session_t * ses = strses_allocate ();
  caddr_t res_text;
  int state = 0;
  int curr_line = 1;
  caddr_t patch_start = patch;
  caddr_t patch_end = patch_start + box_length (patch_start) - 1;
  dk_set_t cmds = NULL;
  s_node_t * el;
  while (patch_start < patch_end)
    {
      caddr_t cmd_line = parse_text_to_lines_1 (&patch_start, patch_end, 2);
      dk_set_push (&cmds, cmd_line);
    }
  cmds = dk_set_nreverse (cmds);
  el = cmds;
  while (el)
    {
      caddr_t cmd_line = (caddr_t) el->data;
      if (cmd_line)
	{
	  diff_cmd_t cmd;
	  switch (diff_cmd_get (&cmd, cmd_line))
	    {
	    case DIFF_CMD_CMD:
	      {
		state = 0;
		if (cmd.dc_type == DIFF_CMD_RANGE_DELETE)
		  {
		    diff_apply_fill_text (&curr_text, end, &curr_line, cmd.dc_from - 1, ses);
		    while (curr_line <= cmd.dc_to)
		      diff_apply_delete (&curr_text, end, &curr_line);
		  }
		else if (cmd.dc_type == DIFF_CMD_RANGE_INSERT)
		  {
		    diff_apply_fill_text (&curr_text, end, &curr_line, cmd.dc_from, ses);
		    state = DIFF_APPLY_STATE_INSERT;
		  }
	      } break;
	    case DIFF_CMD_DELINS:
	      {
		if (DIFF_APPLY_STATE_INSERT == state)
		  {
		    diff_apply_insert (cmd_line + 2 /* skip "> " prefix */,
				       ses);
		  }
	      } break;
	    default:
	      break;
	    }
	  dk_free_box ((box_t) cmd_line);
	}
      el = el->next;
    }
  dk_set_free (cmds);
  diff_apply_fill_text (&curr_text, end, &curr_line, -1, ses);
  res_text = strses_string (ses);
  strses_free (ses);
  return res_text;
}

static
ptrlong bif_diff_mode_arg (caddr_t *qst, state_slot_t ** args, int nth, const char* funcname)
{
  ptrlong mode = DIFF_MODE_GNU;
  caddr_t mode_str = bif_string_arg (qst, args, nth, funcname);
  if (!strcmp (mode_str, "--virt2"))
    mode = DIFF_MODE_DIFF_E;
  else if (!strcmp (mode_str, "--normal"))
    mode = DIFF_MODE_GNU;
  else if (!strcmp (mode_str, "--virt"))
    mode = DIFF_MODE_VIRT;
  return mode;
}

static
long count_lines (caddr_t text)
{
  caddr_t pointer = text;
  long cnt = 0;
  while ( (pointer = strchr(pointer, '\n')) )
    {
      ++pointer;
      ++cnt;
    }
  return cnt;
}

static
caddr_t bif_diff (caddr_t *qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t source_doc = bif_string_arg  (qst, args, 0, "bif_diff");
  caddr_t dest_doc = bif_string_arg (qst, args, 1, "bif_diff");
  id_hash_t * line_hash = id_hash_allocate (1021, sizeof (caddr_t), sizeof (ptrlong), strhash, strhashcmp);
  caddr_t * line_array;
  ptrlong * source_array = 0;
  ptrlong * dest_array = 0;
  ptrlong * LCS;
  caddr_t path_text;
  ptrlong currid = -1;
  caddr_t * path;
  ptrlong mode = DIFF_MODE_GNU;
  if (BOX_ELEMENTS (args) > 2)
    mode = bif_diff_mode_arg (qst, args, 2, "bif_diff");

  if ((count_lines (source_doc) > DIFF_MAX_LENGTH) ||
      (count_lines (dest_doc) > DIFF_MAX_LENGTH))
    sqlr_new_error ("DF001", "SR479", "Too long document, must not exceed %d lines",  DIFF_MAX_LENGTH);

  if (0 > parse_text_to_lines (source_doc, line_hash, &source_array, &currid, NULL))
    {
      dk_free_box ((box_t) source_array);
      sqlr_new_error ("DF002", "SR480", "Source file is in binary format");
    }

  if (0 > parse_text_to_lines (dest_doc, line_hash, &dest_array, &currid, &line_array))
    {
      dk_free_box ((box_t) source_array);
      dk_free_box ((box_t) dest_array);
      sqlr_new_error ("DF002", "SR481", "Destination file is in binary format");
    }

  LCS = LCS_Delta (source_array, dest_array);
  path = build_path_from_LCS (source_array, dest_array, LCS);
  dk_free_box ((box_t) source_array);
  dk_free_box ((box_t) dest_array);
  dk_free_box ((box_t) LCS);

  path_text = path_to_text (path, line_array, mode);
  id_hash_free (line_hash);
  dk_free_tree ((box_t) line_array);
  dk_free_tree ((box_t) path);
  return path_text;
}

static
caddr_t bif_diff_apply (caddr_t *qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t text = bif_string_arg (qst, args, 0, "diff_apply");
  caddr_t patch = bif_string_arg (qst, args, 1, "diff_apply");
  ptrlong mode = DIFF_MODE_GNU;
  if (BOX_ELEMENTS (args) > 2)
    mode = bif_diff_mode_arg (qst, args, 2, "diff_apply");

  return diff_apply (text, patch, mode);
}

static
void reverse_cmd_line (char * line, char * res_line, size_t sz)
{
  int d1 = atoi (line);
  char * cmd_sep = strchr (line, 'd');
  if (!cmd_sep)
    cmd_sep = strchr (line, 'a');
  if (cmd_sep)
    {
      int d2 = atoi (cmd_sep + 1);
      if (d2)
	{
	  sprintf (res_line, "%d%c%d", d2, cmd_sep[0], d1);
	  return;
	}
    }
  strncpy (res_line, line, sz - 1);
  return;
}

static
caddr_t bif_diff_reverse (caddr_t *qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t patch = bif_string_arg (qst, args, 0, "diff_reverse");
  caddr_t end = patch + box_length(patch) - 1;
  caddr_t pointer = patch;
  dk_session_t * ses = strses_allocate();
  dk_set_t diff_set = 0;
  caddr_t res = 0;
  while (1)
    {
      caddr_t line = parse_text_to_lines_1 (&pointer, end, 0);
      if (line)
	{
	  if ((line[0] == '>') || (line[0] == '<') || (line[0] == '\\'))
	    {
	      session_buffered_write (ses, line, strlen(line));
	      session_buffered_write_char ('\n', ses);
	    }
	  else
	    {
	      char tmp[255];
	      memset (tmp, 0, sizeof (tmp));
	      dk_set_push (&diff_set, strses_string (ses));
	      strses_free (ses);
	      ses = strses_allocate ();
	      reverse_cmd_line (line, tmp, sizeof(tmp));
	      session_buffered_write (ses, tmp, strlen(tmp));
	      session_buffered_write_char ('\n', ses);
	    }
	  dk_free_box ((box_t) line);
	}
      else
	break;
    }
  dk_set_push (&diff_set, strses_string (ses));
  strses_free (ses);
  ses = strses_allocate ();
  DO_SET (caddr_t, diff_el, &diff_set)
    {
      session_buffered_write (ses, diff_el, strlen (diff_el));
    }
  END_DO_SET();
  res = strses_string (ses);
  strses_free (ses);
  dk_free_tree (list_to_array (diff_set));
  return res;
}

void
bif_diff_init (void)
{
  bif_define ("diff", bif_diff);
  bif_define ("diff_apply", bif_diff_apply);
  bif_define ("diff_reverse", bif_diff_reverse);
}

