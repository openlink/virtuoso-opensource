/*
 *  sqlpfn.c
 *
 *  $Id$
 *
 *  Parser Functions
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

#include "wi.h"
#include "sqlnode.h"
#include "sqlfn.h"
#include "widv.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlpfn.h"
#include "security.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "util/strfuns.h"
#include "crsr.h"
#include "sqltype.h"
#include "sqlbif.h"
#include "sqlcstate.h"
#include "xmltree.h" /* For trick with precompilation of strings that are XPATH/XQuery expressions */
#include "xpf.h"


void yyerror (const char *s);

FILE *savefile;


#ifndef save_str
int
save_str (char *yytext)
{
/*
   fprintf(savefile,"%s",yytext);
 */
  return 0;
}
#endif

int
yywrap (void)
{
  return (1);
}

int
scn3splityywrap (void)
{
  return (1);
}


caddr_t
sym_string (const char *str)
{
  caddr_t xx = box_string (str);
  box_tag_modify (xx, DV_SYMBOL);
  return xx;
}


caddr_t
t_sym_string (const char *str)
{
  caddr_t xx = t_box_string (str);
  box_tag_modify (xx, DV_SYMBOL);
  return xx;
}


caddr_t
list (long n, ...)
{
  caddr_t *box;
  va_list ap;
  int inx;
  va_start (ap, n);
  box = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * n, DV_ARRAY_OF_POINTER);
  for (inx = 0; inx < n; inx++)
    {
      caddr_t child = va_arg (ap, caddr_t);
#ifdef MALLOC_DEBUG_LIST
      if (IS_BOX_POINTER (child))
	dk_alloc_box_assert (child);
#endif
      box[inx] = child;
    }
  va_end (ap);
  return ((caddr_t) box);
}


void
list_extend (caddr_t *list_ptr, long n, ...)
{
  caddr_t *box;
  va_list ap;
  int inx;
  int old_size = ((NULL == list_ptr[0]) ? 0 : BOX_ELEMENTS (list_ptr[0]));
  va_start (ap, n);
  box = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * (old_size + n), DV_ARRAY_OF_POINTER);
  if (NULL != list_ptr[0])
    memcpy (box, list_ptr[0], sizeof (caddr_t) * old_size);
  for (inx = 0; inx < n; inx++)
    {
      caddr_t child = va_arg (ap, caddr_t);
#ifdef MALLOC_DEBUG_LIST
      if (IS_BOX_POINTER (child))
	dk_alloc_box_assert (child);
#endif
      box[old_size + inx] = child;
    }
  va_end (ap);
  dk_free_box (list_ptr[0]);
  list_ptr[0] = (caddr_t)box;
}


void
list_nappend (caddr_t *list_ptr, caddr_t cont)
{
  caddr_t *box;
  int old_size = ((NULL == list_ptr[0]) ? 0 : BOX_ELEMENTS (list_ptr[0]));
  int cont_size = ((NULL == cont) ? 0 : BOX_ELEMENTS (cont));
  if (0 == old_size)
    {
      dk_free_box (list_ptr[0]);
      list_ptr[0] = cont;
      return;
    }
  box = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * (old_size + cont_size), DV_ARRAY_OF_POINTER);
  memcpy (box, list_ptr[0], sizeof (caddr_t) * old_size);
  if (NULL != cont)
    memcpy (box + old_size, cont, sizeof (caddr_t) * cont_size);
  dk_free_box (list_ptr[0]);
  dk_free_box (cont);
  list_ptr[0] = (caddr_t)box;
}


caddr_t
sc_list (long n, ...)
{
  caddr_t *box;
  va_list ap;
  int inx;
  va_start (ap, n);
  box = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * n, DV_ARRAY_OF_LONG);
  for (inx = 0; inx < n; inx++)
    {
      box[inx] = va_arg (ap, caddr_t);
    }
  va_end (ap);
  return ((caddr_t) box);
}


int
str_literal_len (char *str, char **start_ret)
{
  int pos = ((int) strlen (str)) - 2, len = 0;
  for (;;)
    {
      if (str[pos] == '\'' && pos == 0)
	{
	  *start_ret = str + 1;
	  return len;
	}
      if (0 == pos)
	break;

      if (str[pos] == '\'' && str[pos - 1] == '\'')
	{
	  pos -= 2;
	  len++;
	  continue;
	}
      if (str[pos] == '\'' && str[pos - 1] != '\'')
	{
	  *start_ret = str + pos + 1;
	  return len;
	}
      pos--;
      len++;
    }
  *start_ret = str + pos;
  return len;
}


#define UCHAR unsigned char

#define isoctdigit(C) (((C) & ~7) == 060)	/* 060 = 0x30 = 48. = '0' */
#define hexdigtoi(C) (isdigit(C) ? ((C) - '0') : (toupper(C) - ('A' - 10)))


int
parse_string_literal (unsigned char **str_ptr, unsigned char *result, int accept_zeros)
{
  unsigned int i = 0;
  unsigned int q, z;
  UCHAR *str = *str_ptr;
  UCHAR beg_quote = *str++;	/* And skip past it. */
  UCHAR c;

  for (/* no init*/; '\0' != str[0]; str++)
    {
      switch (*str)
	{
	case '\\':		/* An escaped character follows? */
	  {

	    if (!parse_not_char_c_escape)
	      {
		/* New escapes added 23.AUG.1991 \a for bell, and \v for vertical tab
		   as specified in ANSI C standard. Also now recognizes hexadecimal
		   character constants beginning with \x Note that \e for escape
		   does not belong to standard. (Commented out)
		 */
		switch (*++str)	/* Check the next character. */
		  {
		    /* If a string anomalously ends with a trailing (single) backslash, then
		       leave it dangling there: */
		    case '\0':
			{
			  c = *(str - 1);
			  break;
			}
		    case 'a':
			  {
			    c = '\7';
			    break;
			  }		/* BEL audible alert */
		    case 'b':
			    {
			      c = '\b';
			      break;
			    }		/* BS  backspace */
			    /*	      case 'e': { c = '\033'; break; } *//* ESC escape */
		    case 'f':
			      {
				c = '\f';
				break;
			      }		/* FF  form feed */
		    case 'n':
				{
				  c = '\n';
				  break;
				}		/* NL (LF) newline */
		    case 'r':
				  {
				    c = '\r';
				    break;
				  }		/* CR  carriage return */
		    case 't':
				    {
				      c = '\t';
				      break;
				    }		/* HT  horizontal tab */
		    case 'v':
				      {
					c = '\013';
					break;
				      }		/* VT  vertical tab */
		    case 'x':	/* There's a hexadecimal char constant \xhh */
		    case 'X':
					{		/* We should check that only max 2 digits are parsed */
					  q = 2;
					  z = 0;
					  str++;
					  while (*str && isxdigit (*str) && (q--))
					    {
					      z = ((z << 4) +
						  (isdigit (*str) ?
						   (*str - '0') :
						   (toupper (*str) - 'A' + 10)));
					      str++;
					    }
					  c = z;
					  if (!z && !accept_zeros)
					    return -1;
					  str--;	/* str is incremented soon. */
					  break;
					}
		    case '0':
		    case '1':
		    case '2':
		    case '3':
		    case '4':
		    case '5':
		    case '6':
		    case '7':
					  {		/* So it's an octal sequence like \033 : */
					    q = 3;
					    z = 0;
					    while (isoctdigit (*str) && (q--))
					      {
						z = ((z << 3) + (*str++ - '0'));
					      }
					    c = z;
					    if (!z && !accept_zeros)
					      return -1;
					    str--;	/* str is incremented soon. */
					    break;
					  }		/* octal digits */
		    case '\n':
		    case '\r':
			continue;
		    default:		/* Every other character after backslash produces */
					    {		/* that same character, i.e. \\ = \, \' = ', etc. */
					      c = *str;
					      break;
					    }		/* default */

		  }			/* inner switch for character after a backslash */
		if (result)
		  result[i] = c;
		i++;
		break;
	      } /* if for processing escapes */
	  }			/* case for backslash. */
	default:
	  {
	    if (*str == beg_quote)
	      {
		/* If the next char is a quote also, then this is not yet
		   the terminating quote */
		if (*(str + 1) == beg_quote)
		  {
		    str++;	/* Skip that quote next time. */
		    goto copy_char;
		  }
		else
		  {		/* String is terminated. */
		    goto out;
		  }
	      }
	    else
	      /* Any other character. */
	      {
	      copy_char:
		if (result)
		  result[i] = *str;
		i++;
		break;
	      }
	  }
	}			/* outer switch */
    }				/* for loop */
out:;
  if (result)
    {
      result[i] = '\0';
    }				/* Put a terminating zero. */
  if (*str)			/* The terminating quote is here. */
    {
      *str_ptr = str + 1;	/* Skip past it. */
    }
  else
    {
      /* The terminating quote is missing, we should produce an error here! */
      *str_ptr = str;		/* But in this version we are tolerant of that. */
    }
  return (i);			/* Return the length. */
}


caddr_t
strliteral (char *s)
{
  char *start = s;
  int len = parse_string_literal ((unsigned char **) &start, NULL, 1);

  caddr_t box = dk_alloc_box (len + 1, DV_SHORT_STRING);
  parse_string_literal ((unsigned char **) &s, (unsigned char *) box, 1);
  box[len] = 0;
  return box;
}


caddr_t
t_strliteral (char *s1)
{
  char *s = s1;
  char *start = s;
  int len;
  caddr_t box;
  if (parse_utf8_execs)
    {
      start = s = t_box_utf8_string_as_narrow (s, NULL, 0, sqlc_client()->cli_charset);
    }
  len = parse_string_literal ((unsigned char **) &start, NULL, 1);

  box = t_alloc_box (len + 1, DV_SHORT_STRING);
  parse_string_literal ((unsigned char **) &s, (unsigned char *) box, 1);
  box[len] = 0;
  return box;
}


caddr_t
wideliteral (char *s)
{
  char *start = s;
  int len;
  caddr_t box;

  if (parse_utf8_execs)
    {
      start += 1;
      len = parse_string_literal ((unsigned char **) &start, NULL, 0);
      if (len > 0)
	{
	  /* account for the N and two ' */
	  if (len != strlen (s) - 3)
	    {
	      box = t_alloc_box (len + 1, DV_SHORT_STRING);
	      start = s + 1;
	      parse_string_literal ((unsigned char **) &start, (unsigned char *) box, 0);
	      return t_box_utf8_as_wide_char (box, NULL, strlen (box), 0);
	    }
	  else
	    return t_box_utf8_as_wide_char (s + 2, NULL, strlen (s + 2) - 1, 0);
	}
      else
	return NULL;
    }
  else
    {
      len = parse_wide_string_literal ((unsigned char **) &start, NULL, NULL);
      box = len >= 0 ? t_alloc_box (len, DV_WIDE) : NULL;
      if (len >= 0)
	parse_wide_string_literal ((unsigned char **) &s, box, NULL);
      return box;
    }
}


caddr_t
sqlp_hex_literal (char *yytext, int unprocess_chars_at_end)
{
  unsigned char *src, _lo, _hi, *ptr;
  int len = ((int) strlen (yytext)) - unprocess_chars_at_end;
  caddr_t ret;

  if (len % 2 || len < 0)
    return NULL;
  ret = t_alloc_box (len / 2, DV_BIN);
  for (src = (unsigned char *) (yytext), ptr = (unsigned char *) ret;
      (src - ((unsigned char *) yytext)) < len; src+=2, ptr++)
    {
      _lo = toupper (src[1]); _hi = toupper (src[0]);
      *ptr = ((_hi - (_hi <= '9' ? '0' : 'A' - 10)) << 4) |
	  (_lo - (_lo <= '9' ? '0' : 'A' - 10));
    }
  return ret;
}


caddr_t
sqlp_bit_literal (char *yytext, int unprocess_chars_at_end)
{
  unsigned char *src, *ptr, *start = (unsigned char *) yytext;
  int len = ((int) strlen (yytext)) - unprocess_chars_at_end, dest_len;
  caddr_t ret;
  int bits_in = 0;

  if (len < 1)
    return NULL;
  dest_len = len / 8 + ((len % 8) ? 1 : 0);

  ret = t_alloc_box (dest_len, DV_BIN);
  memset (ret, 0, dest_len);
  src = start + len - 1;
  ptr = (unsigned char *) (ret + dest_len - 1);
  while (src >= start)
    {
      unsigned char bit_value = *src - '0';
      if (bits_in > 7)
	{
	  ptr--;
	  bits_in = 0;
	}
      if (bits_in)
	*ptr |= (bit_value & 0x1) << bits_in;
      else
	*ptr |= (bit_value & 0x1);

      bits_in += 1;
      src -= 1;
    }
  return ret;
}


caddr_t
sym_conc (caddr_t x, caddr_t y)
{
  char tmp[100];
  snprintf (tmp, sizeof (tmp), "%s.%s", x, y);
  dk_free_box (x);
  dk_free_box (y);
  return (sym_string (tmp));
}

void
yy_string_input_init (char *text)
{
  param_inx = 0;
  sqlc_sql_text = text;
}


int
yy_string_input (char *buf, int max)
{
  int len = (int) strlen (sqlc_sql_text);
  if (len == 0)
    return 0;
  if (len > max)
    len = max;
  memcpy (buf, sqlc_sql_text, len);
  sqlc_sql_text += len;
  return len;
}


ST **
asg_col_list (ST ** asg_list)
{
  int inx;
  ST **copy = (ST **) t_box_copy ((caddr_t) asg_list);
  DO_BOX (caddr_t *, asg, inx, ((caddr_t *) asg_list))
  {
    copy[inx] = (ST *) t_box_copy_tree ((caddr_t) asg[0]);
  }
  END_DO_BOX;
  return copy;
}


ST **
asg_val_list (ST ** asg_list)
{
  int inx;
  ST **copy = (ST **) t_box_copy ((caddr_t) asg_list);
  DO_BOX (caddr_t *, asg, inx, ((caddr_t *) asg_list))
  {
    copy[inx] = (ST *) t_box_copy_tree (asg[1]);
  }
  END_DO_BOX;
  return copy;
}


ST **
sqlp_local_variable_decls (caddr_t * names, ST * dtp)
{
  int inx;
  DO_BOX (caddr_t, name, inx, names)
  {
    ST *decl = t_listst (4,
	LOCAL_VAR, IN_MODE, name, t_box_copy_tree ((caddr_t) dtp));
    names[inx] = (caddr_t) decl;
  }
  END_DO_BOX;
  return ((ST **) names);
}


dk_set_t
sqlc_ensure_primary_key (dk_set_t elements)
{
  DO_SET (ST *, elt, &elements)
  {
    if (ST_P (elt, INDEX_DEF) || ST_P (elt, TABLE_UNDER))
      return elements;
  }
  END_DO_SET ();
  t_set_push (&elements,
      t_list (5,
	  INDEX_DEF, NULL, NULL,
	  t_list (1, t_box_string ("_IDN")),
	      t_list_to_array (sqlp_index_default_opts (NULL))));
  t_set_push (&elements, NULL);
  t_set_push (&elements,
      t_list (2,
	  t_list (2, (ptrlong) DV_LONG_INT, (ptrlong) 0),
	  t_list (1, CO_IDENTITY)));
  t_set_push (&elements, t_box_string ("_IDN"));
  return elements;
}


void
sqlp_upcase (char *str)
{
  while (*str)
    {
      char c = *str;
      if (c >= 'a' && c <= 'z')
	*str -= 32;
      str++;
    }
}

int case_mode;
int
casemode_strcmp (const char *s1, const char *s2)
{
  return CASEMODESTRCMP (s1, s2);
}

int
casemode_strncmp (const char *s1, const char *s2, size_t n)
{
  return CASEMODESTRNCMP (s1, s2, n);
}

caddr_t
DBG_NAME (sqlp_box_id_upcase) (DBG_PARAMS const char *str)
{
  /* nothing in 2 */
  caddr_t s;
  size_t len = strlen (str);
  if (len > MAX_NAME_LEN - 2)
    len = MAX_NAME_LEN - 2;
  s = DBG_NAME (box_dv_short_nchars) (DBG_ARGS str, len);
  box_tag_modify (s, DV_SYMBOL);
  if (CM_UPPER == case_mode)
    sqlp_upcase (s);
  return s;
}


caddr_t
t_sqlp_box_id_upcase (const char *str)
{
  /* nothing in 2 */
  caddr_t s;
  size_t len = strlen (str);
  if (len > MAX_NAME_LEN - 2)
    len = MAX_NAME_LEN - 2;
  s = t_box_dv_short_nchars ((caddr_t) str, len);
  box_tag_modify (s, DV_SYMBOL);
  if (CM_UPPER == case_mode)
    sqlp_upcase (s);
  return s;
}

caddr_t
t_sqlp_box_id_upcase_nchars (const char * str, int len)
{
  /* nothing in 2 */
  caddr_t s;
  if (len > MAX_NAME_LEN - 2)
    len = MAX_NAME_LEN - 2;
  s = t_box_dv_short_nchars ((caddr_t) str, len);
  box_tag_modify (s, DV_SYMBOL);
  if (CM_UPPER == case_mode)
    sqlp_upcase (s);
  return s;
}

caddr_t
sqlp_box_upcase (const char *str)
{
  caddr_t s = box_dv_short_string (str);
  sqlp_upcase (s);
  return s;
}


caddr_t
t_sqlp_box_upcase (const char *str)
{
  caddr_t s = t_box_string (str);
  sqlp_upcase (s);
  return s;
}

caddr_t
t_sqlp_box_id_quoted (const char *str, int end_ofs)
{
  char buf[MAX_NAME_LEN + 1], *cp;
  const char *sp;
  int len = (int) strlen (str);
  caddr_t s;
  if (len > MAX_NAME_LEN - 2)
    len = MAX_NAME_LEN - 2;
  for (cp = buf, sp = str; *sp && cp < &buf[MAX_NAME_LEN - 1] && sp - str < len - end_ofs;)
    if (*sp == '\"' && *(sp + 1) == '\"' && sp - str + 1 < len - end_ofs)
      sp++;
    else
      *cp++ = *sp++;
  *cp = 0;
  s = t_sym_string (buf);
  return s;
}


#if 0
caddr_t
sqlp_box_id_quoted (char *str)
{
  char buf[MAX_NAME_LEN + 1], *cp, *sp;
  int len = strlen (str);
  caddr_t s;
  if (len > MAX_NAME_LEN - 2)
    len = MAX_NAME_LEN - 2;
  for (cp = buf, sp = str; *sp && cp < &buf[MAX_NAME_LEN - 1] && sp - str < len - 1;)
    if (*sp == '\"' && *(sp + 1) == '\"')
      sp++;
    else
      *cp++ = *sp++;
  *cp = 0;
  s = sym_string (buf);
  return s;
}
#endif

static void
sqlp_check_infoschema (char *o)
{
  if (!CASEMODESTRCMP (o, "INFORMATION_SCHEMA") && global_scs)
    sqlp_have_infoschema_views = 1;
}

static char *
sqlp_infoschema_view_to_qual_col (const char *tb_name)
{
  if (!CASEMODESTRCMP (tb_name, "DB.INFORMATION_SCHEMA.TABLES"))
    return "TABLE_CATALOG";
  else if (!CASEMODESTRCMP (tb_name, "DB.INFORMATION_SCHEMA.COLUMNS"))
    return "TABLE_CATALOG";
  else if (!CASEMODESTRCMP (tb_name, "DB.INFORMATION_SCHEMA.SCHEMATA"))
    return "CATALOG_NAME";
  else if (!CASEMODESTRCMP (tb_name, "DB.INFORMATION_SCHEMA.CHECK_CONSTRAINTS"))
    return "CONSTRAINT_CATALOG";
  else if (!CASEMODESTRCMP (tb_name, "DB.INFORMATION_SCHEMA.COLUMN_DOMAIN_USAGE"))
    return "DOMAIN_CATALOG";
  else if (!CASEMODESTRCMP (tb_name, "DB.INFORMATION_SCHEMA.COLUMN_PRIVILEGES"))
    return "TABLE_CATALOG";
  else if (!CASEMODESTRCMP (tb_name, "DB.INFORMATION_SCHEMA.KEY_COLUMN_USAGE"))
    return "CONSTRAINT_CATALOG";
  else if (!CASEMODESTRCMP (tb_name, "DB.INFORMATION_SCHEMA.ROUTINES"))
    return "SPECIFIC_CATALOG";
  else if (!CASEMODESTRCMP (tb_name, "DB.INFORMATION_SCHEMA.PARAMETERS"))
    return "SPECIFIC_CATALOG";
  else if (!CASEMODESTRCMP (tb_name, "DB.INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS"))
    return "CONSTRAINT_CATALOG";
  else if (!CASEMODESTRCMP (tb_name, "DB.INFORMATION_SCHEMA.TABLE_CONSTRAINTS"))
    return "CONSTRAINT_CATALOG";
  else if (!CASEMODESTRCMP (tb_name, "DB.INFORMATION_SCHEMA.TABLE_PRIVILEGES"))
    return "TABLE_CATALOG";
  else if (!CASEMODESTRCMP (tb_name, "DB.INFORMATION_SCHEMA.VIEWS"))
    return "TABLE_CATALOG";
  else
    return NULL;
}


static caddr_t
sqlp_infoschema_redirect_tb (char *name, char *new_name, int sizeof_new_name, caddr_t *q_copy_ptr)
{
  char q[MAX_NAME_LEN], o[MAX_NAME_LEN], n[MAX_NAME_LEN];
  int new_name_allocated = 0;

  sch_split_name (sqlc_client ()->cli_qualifier, name, q, o, n);

  if (!CASEMODESTRCMP (o, "INFORMATION_SCHEMA"))
    {
      if (!new_name)
	{
	  sizeof_new_name = strlen (n) + sizeof ("DB.INFORMATION_SCHEMA.");
	  new_name = t_alloc_box (sizeof_new_name, DV_SYMBOL);
	  new_name_allocated = 1;
	}
      snprintf (new_name, sizeof_new_name, "DB.INFORMATION_SCHEMA.%s", n);

      /* not from the predefined INFOSCHEMA views */
      if (!sqlp_infoschema_view_to_qual_col (new_name))
	goto no_match;

      if (q_copy_ptr)
	*q_copy_ptr = t_box_string (q);
      return new_name;
    }
  else
    {
no_match:
      if (new_name)
	{
	  if (sizeof_new_name > 0 && !new_name_allocated)
	    {
	      if (sizeof_new_name > 1)
		strncpy (new_name, name, sizeof_new_name);
	      new_name[sizeof_new_name - 1] = 0;
	    }
	}
      return name;
    }
}


static void
sqlp_infoschema_redirect_tbs (ST **tree, ST **where_cond)
{
  if (!tree || !*tree)
    return;
  if (DV_TYPE_OF (*tree) != DV_ARRAY_OF_POINTER)
    return;
  if (ST_COLUMN ((*tree), COL_DOTTED) && (*tree)->_.col_ref.prefix)
    {
      (*tree)->_.col_ref.prefix = sqlp_infoschema_redirect_tb (
 	(*tree)->_.col_ref.prefix, NULL, 0, NULL);
    }
  else if (ST_P ((*tree), TABLE_DOTTED))
    {
      caddr_t old_name, new_name, q_ptr;

      old_name = (*tree)->_.table.name;
      new_name = sqlp_infoschema_redirect_tb (
        (*tree)->_.table.name, NULL, 0, &q_ptr);
      if (new_name != old_name)
	{
	  ST *cmp;
	  char *qual_col = sqlp_infoschema_view_to_qual_col (new_name);

	  /* not from the predefined INFOSCHEMA views */
	  if (!qual_col)
	    return;

	  (*tree)->_.table.name = new_name;
	  BIN_OP (cmp, BOP_EQ,
	      t_listst (3, COL_DOTTED,
		(*tree)->_.table.prefix ?
		  (*tree)->_.table.prefix :
		  new_name,
		t_sym_string (qual_col)),
	      (ST *) q_ptr);

	  t_st_and (where_cond, cmp);
	}
    }
  else if (ST_P ((*tree), SELECT_STMT))
    return;
  else
    {
      int inx;
      _DO_BOX (inx, (ST **) (*tree))
	{
	  sqlp_infoschema_redirect_tbs (&(((ST **) (*tree))[inx]), where_cond);
	}
      END_DO_BOX;
    }
}


ST *
sqlp_infoschema_redirect (ST *texp)
{
  if (global_scs && sqlp_have_infoschema_views && !inside_view)
    {
      ST *new_where = NULL;
      sqlp_infoschema_redirect_tbs (&texp, &new_where);
      if (new_where)
	t_st_and (&texp->_.table_exp.where, new_where);
      return texp;
    }
  else
    return texp;
}

dk_set_t view_aliases;


caddr_t
sqlp_table_name (char *q, size_t max_q, char *o, size_t max_o, char *n, int do_case)
{
  char temp[MAX_QUAL_NAME_LEN];

  if (do_case)
    sch_normalize_new_table_case (wi_inst.wi_schema, q, max_q, o, max_o);

  if (o)
    sqlp_check_infoschema (o);

  if (q)
    snprintf (temp, sizeof (temp), "%s.%s.%s", q ? q : "", o ? o : "", n);
  else if (o)
    snprintf (temp, sizeof (temp), "%s.%s", o, n);
  else
    snprintf (temp, sizeof (temp), "%s", n);
/*  dk_free_box (q);
  dk_free_box (o);
  dk_free_box (n);*/
  return (t_box_string (temp));
}


caddr_t
sqlp_type_name (char *q, size_t max_q, char *o, size_t max_o, char *n, int add_if_not)
{
  char temp[MAX_QUAL_NAME_LEN];
  sql_class_t *udt;
  caddr_t as_new_name;
  as_new_name = sqlp_new_table_name (q, max_q, o, max_o, n);
  if (sqlp_udt_current_type)
    {
      if (!CASEMODESTRCMP (as_new_name, sqlp_udt_current_type))
	return as_new_name;
    }
  udt = sch_name_to_type (wi_inst.wi_schema, as_new_name);
  if (udt)
    return as_new_name;
  if (q)
    snprintf (temp, sizeof (temp), "%s.%s.%s", q ? q : "", o ? o : "", n);
  else if (o)
    snprintf (temp, sizeof (temp), "%s.%s", o, n);
  else
    snprintf (temp, sizeof (temp), "%s", n);
  udt = sch_name_to_type (wi_inst.wi_schema, temp);
  if (udt)
    return (t_box_string (udt->scl_name));
  return as_new_name;
  /*
  else if (add_if_not)
    {
      caddr_t as_new_name = sqlp_new_table_name (q, o, n);
      udt = udt_alloc_class_def (as_new_name);
      udt->scl_ext_lang = sqlp_udt_current_type_lang == UDT_LANG_NONE ? UDT_LANG_SQL : sqlp_udt_current_type_lang;
      id_hash_set (wi_inst.wi_schema->sc_name_to_type,
	  (caddr_t) & udt->scl_name,
	  (caddr_t) & udt);
      return as_new_name;
    }
  else
    yy_new_error ("No user defined type",  "37000", "SQXXX");
  return NULL;
  */
}


caddr_t
c_pref (char *q, size_t max_q, char *o, size_t max_o, char *n)
{
  char *old_inside_view = inside_view;
  caddr_t ret;
  inside_view = NULL;
  ret = sqlp_table_name (q, max_q, o, max_o, n, 1);
  inside_view = old_inside_view;
  return ret;
}


caddr_t
sqlp_new_table_name (char *q, size_t max_q, char *o, size_t max_o, char *n)
{
  char temp[MAX_QUAL_NAME_LEN];
  char *q2 = q ? q : sqlc_client ()->cli_qualifier;
  char *o2 = o ? o : CLI_OWNER (sqlc_client ());

  sch_normalize_new_table_case (wi_inst.wi_schema, q, max_q, o, max_o);

  snprintf (temp, sizeof (temp), "%s.%s.%s", q2, o2, n);
/*  dk_free_box (q);
  dk_free_box (o);
  dk_free_box (n);*/
  return (t_box_string (temp));
}

caddr_t
sqlp_new_qualifier_name (char *q, size_t max_q)
{
  caddr_t new_q = t_box_string (q);
  sch_normalize_new_table_case (wi_inst.wi_schema, q, max_q, NULL, 0);
  return new_q;
}

caddr_t
sqlp_proc_name (char *q, size_t max_q, char *o, size_t max_o, char *mn, char *fn)
{
  caddr_t n = NULL;

  if (!mn || !fn)
      return sqlp_table_name (q, max_q, o, max_o, mn ? mn : fn, 1);

  n = t_alloc_box (strlen (mn) + strlen (fn) + 2, DV_SHORT_STRING);
  snprintf (n, box_length (n), "%s.%s", mn, fn);
/*  dk_free_box (mn);
  dk_free_box (fn);*/
  return sqlp_table_name (q, max_q, o, max_o, n, 1);
}


ST *
sqlp_union_tree_select (ST * tree)
{
  char margin;
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &margin, 6000))
    yyerror ("Nesting of union is too deep. If using SPARQL use more specific query specifying graph and predicates.");
  if (ST_P (tree, UNION_ALL_ST) || ST_P (tree, UNION_ST)
      || ST_P (tree, EXCEPT_ST) || ST_P (tree, EXCEPT_ALL_ST)
      || ST_P (tree, INTERSECT_ST) || ST_P (tree, INTERSECT_ALL_ST))
    return (sqlp_union_tree_select (tree->_.bin_exp.left));
  return tree;
}


ST *
sqlp_union_tree_right (ST * tree)
{
  char margin;
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &margin, 6000))
    yyerror ("Nesting of union is too deep. If using SPARQL use more specific query specifying graph and predicates.");
  if (ST_P (tree, UNION_ALL_ST) || ST_P (tree, UNION_ST)
      || ST_P (tree, EXCEPT_ST) || ST_P (tree, EXCEPT_ALL_ST)
      || ST_P (tree, INTERSECT_ST) || ST_P (tree, INTERSECT_ALL_ST))
    return (sqlp_union_tree_right (tree->_.bin_exp.right));
  return tree;
}


void
sqlp_view_def_1 (ST ** names, ST * exp)
{
  if (ST_P (exp, UNION_ST)
      || ST_P (exp, UNION_ALL_ST)
      || ST_P (exp, INTERSECT_ST) || ST_P (exp, INTERSECT_ALL_ST)
      || ST_P (exp, EXCEPT_ST) || ST_P (exp, EXCEPT_ALL_ST)
      )
    {
      sqlp_view_def_1 (names, exp->_.bin_exp.left);
      sqlp_view_def_1 (names, exp->_.bin_exp.right);
    }
  else
    {
      ST **selection = (ST **) exp->_.select_stmt.selection;
      int inx;
      if (BOX_ELEMENTS (names) != BOX_ELEMENTS (selection))
	yyerror ("Different number of names and columns in VIEW");
      DO_BOX (ST *, col, inx, selection)
      {
	if (!ST_P (col, BOP_AS))
	  selection[inx] = t_listst (5,
	      BOP_AS, col, NULL, t_box_copy ((caddr_t) names[inx]), NULL);
      }
      END_DO_BOX;
    }
}


ST *
sqlp_view_def (ST ** names, ST * exp, int generate_col_names)
{
  if (names && 0 == BOX_ELEMENTS (names))
    {
      /*dk_free_box ((caddr_t) names);*/
      names = NULL;
    }
  if (!names)
    {
      int inx, expr_inx = 1;
      ST *exp2 = exp;
      exp2 = sqlp_union_tree_select (exp2);
      names = (ST **) t_box_copy ((caddr_t) exp2->_.select_stmt.selection);
      DO_BOX (ST *, col, inx, exp2->_.select_stmt.selection)
      {
	if (ST_COLUMN (col, COL_DOTTED))
	  names[inx] = (ST *) t_box_copy (col->_.col_ref.name);
	else if (ST_P (col, BOP_AS))
	  names[inx] = (ST *) t_box_copy (col->_.as_exp.name);
	else if (generate_col_names)
	  {
	    char name_buf[30];
	    snprintf (name_buf, sizeof (name_buf), "EXPR_%d", expr_inx++);
	    names[inx] = (ST *) t_box_string (name_buf);
	  }
	else
	  yyerror ("Unnamed result column in derived table/view");
      }
      END_DO_BOX;
    }
  sqlp_view_def_1 (names, exp);
  /*dk_free_tree ((caddr_t) names);*/
  return exp;
}


void
sqlp_dt_header (ST * exp)
{
  if (ST_P (exp, UNION_ST)
      || ST_P (exp, UNION_ALL_ST)
      || ST_P (exp, INTERSECT_ST) || ST_P (exp, INTERSECT_ALL_ST)
      || ST_P (exp, EXCEPT_ST) || ST_P (exp, EXCEPT_ALL_ST)
      )
    {
      sqlp_dt_header (exp->_.bin_exp.left);
      sqlp_dt_header (exp->_.bin_exp.right);
    }
  else
    {
      ST **selection = (ST **) exp->_.select_stmt.selection;
      exp->_.select_stmt.selection = (caddr_t *) sqlp_stars (sqlp_wrapper_sqlxml ((ST **) selection), exp->_.select_stmt.table_exp->_.table_exp.from);
      sqlp_breakup (exp);
    }
}


void
sqlp_no_table (char *pref, char *name)
{
  char temp[500];
  snprintf (temp, sizeof (temp), "No table %s%s%s in * reference",
      pref ? pref : "", pref ? "." : "", name ? name : "");
  yy_new_error (temp, "42S02", NULL);
}


void
sqlp_expand_1_star_table_ref (ST * col, ST * tb_ref, dk_set_t * exp)
{
  char *col_pref = col->_.col_ref.prefix;
  dk_set_t parts;
  char *tb_pref = NULL;
  char *tb_name = NULL;
  switch (tb_ref->type)
    {
    case TABLE_REF:
      sqlp_expand_1_star_table_ref (col, tb_ref->_.table_ref.table, exp);
      break;

    case TABLE_DOTTED:
      tb_pref = tb_ref->_.table.prefix;
      tb_name = tb_ref->_.table.name;
      if (!col_pref
	  || (tb_pref && 0 == strcmp (tb_pref, col_pref))
	  || 0 == strcmp (tb_name, col_pref))
	{
	  char new_tb_name [MAX_QUAL_NAME_LEN];
	  dbe_table_t *tb;

	  sqlp_infoschema_redirect_tb (tb_name, new_tb_name, sizeof (new_tb_name), NULL);
	  tb = sch_name_to_table (wi_inst.wi_schema,
					       new_tb_name);
	  if (!tb)
	    sqlp_no_table (tb_pref, tb_name);
	  parts = key_ensure_visible_parts (tb->tb_primary_key);
	  DO_SET (dbe_column_t *, t_col, &parts)
	  {
	    t_dk_set_append_1 (exp,
		t_list (3, COL_DOTTED,
		    t_box_copy (tb_pref ? tb_pref : tb -> tb_name),
		    t_box_copy (t_col->col_name)));
	  }
	  END_DO_SET ();
	}
      break;

    case DERIVED_TABLE:
      tb_pref = tb_ref->_.table_ref.range;
      if (!col_pref
	  || 0 == strcmp (col_pref, tb_pref))
	{
	  int n_col;
	  ST **selection;
	  ST *table = tb_ref->_.table_ref.table;
	  table = sqlp_union_tree_select  (table);
	  if (ST_P (table, SELECT_STMT))
	    {
	      selection = (ST **) table->_.select_stmt.selection;
	      DO_BOX (ST *, as_exp, n_col, selection)
		{
		  if (sel_n_breakup (table) && n_col >= sel_n_breakup (table) - 1)
		    break;
		  t_dk_set_append_1 (exp,
		      t_list (3, COL_DOTTED,
			t_box_copy (tb_pref),
			t_box_copy (as_exp->_.as_exp.name)));
		}
	      END_DO_BOX;
	    }
	  else if (ST_P (table, PROC_TABLE))
	    {
	      int inx;
	      for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (table->_.proc_table.cols); inx += 2)
		{
		  if (!table->_.proc_table.cols[inx])
		    continue;
		  if (0 == strcmp ((caddr_t) table->_.proc_table.cols[inx], "_IDN"))
		    continue;
		  t_dk_set_append_1 (exp,
		      t_list (3, COL_DOTTED,
			t_box_copy ((caddr_t)tb_pref),
			t_box_copy ((caddr_t)table->_.proc_table.cols[inx])));
		}
	      /*GK: enable that if proc view params to participate in 'select *' */
#if 0
	      DO_BOX (caddr_t, param, inx, table->_.proc_table.params)
		{
		  if (!param)
		    continue;
		  t_dk_set_append_1 (exp,
		      t_list (3, COL_DOTTED,
			t_box_copy ((caddr_t)tb_pref),
			t_box_copy (param)));
		}
	      END_DO_BOX;
#endif
	    }
	}
      break;

    case JOINED_TABLE:
      sqlp_expand_1_star_table_ref (col, tb_ref->_.join.left, exp);
      sqlp_expand_1_star_table_ref (col, tb_ref->_.join.right, exp);
      break;
    }
}


void
sqlp_expand_1_star (ST * col, ST ** from, dk_set_t * exp)
{
  int inx;
  DO_BOX (ST *, tb_ref, inx, from)
  {
    sqlp_expand_1_star_table_ref (col, tb_ref, exp);
  }
  END_DO_BOX;
}


/*sqlxml*/
ST *
sqlp_wrapper_sqlxml_assign (ST * tree)
{
  if (ST_P (tree, BOP_AS))
    {
      tree->_.as_exp.left = sqlp_wrapper_sqlxml_assign (tree->_.as_exp.left);
      return tree;
    }
  if (ST_P (tree, CALL_STMT) &&
	(0 == stricmp (tree->_.call.name, "XMLELEMENT")
	   || 0 == stricmp (tree->_.call.name, "XMLFOREST")
	   || 0 == stricmp (tree->_.call.name, "XMLCONCAT")
	   || 0 == stricmp (tree->_.call.name, "XMLAGG")
	   || 0 == stricmp (tree->_.call.name, "DB.DBA.XMLAGG")
	   || 0 == stricmp (tree->_.call.name, "DB.DBA.xte_nodebld_final_root") ) )
    {
      ST * acc;
      ST * xmltreedoc;
      acc = (ST *) t_alloc_box (sizeof (ST), DV_ARRAY_OF_POINTER);
      xmltreedoc = t_listst (3, CALL_STMT, t_box_string ("XML_TREE_DOC"), t_list (1, acc));
      xmltreedoc->_.call.params[0] = tree;
      return xmltreedoc;
    }
  return tree;
}


ST **
sqlp_wrapper_sqlxml (ST ** selection)
{
  int inx;
  DO_BOX (ST *, arg, inx, selection)
  {
    selection[inx] = sqlp_wrapper_sqlxml_assign (arg);
  }
  END_DO_BOX;
  return selection;
}
/*end sqlxml*/


ST **
sqlp_stars (ST ** selection, ST ** from)
{
  dk_set_t exp_list = NULL;
  int inx, star = 0;
  DO_BOX (ST *, col, inx, selection)
  {
    if (ST_COLUMN (col, COL_DOTTED))
      if (col->_.col_ref.name == STAR)
	{
	  star = 1;
	  break;
	}
  }
  END_DO_BOX;
  if (!star)
    return selection;
  DO_BOX (ST *, col, inx, selection)
  {
    if (ST_COLUMN (col, COL_DOTTED) && col->_.col_ref.name == STAR)
      {
	dk_set_t prev_last = dk_set_last (exp_list);
	sqlp_expand_1_star (col, from, &exp_list);
	if (prev_last == dk_set_last (exp_list))
	  {
	    char temp[2000];
	    snprintf (temp, sizeof (temp), "Reference %s.* cannot be resolved",
		col->_.col_ref.prefix ? col->_.col_ref.prefix : "");
	    yyerror (temp);
	  }
      }
    else
      {
	exp_list = t_NCONC (exp_list, t_CONS (t_box_copy_tree ((caddr_t) col), NULL));
      }
  }
  END_DO_BOX;
  /*dk_free_box ((caddr_t) selection);*/
  return ((ST **) t_list_to_array (exp_list));
}


dk_set_t
sqlp_process_col_options (caddr_t table_name, dk_set_t table_opts)
{
  dk_set_t opts = table_opts;
  while (opts)
    {
      caddr_t col_name = (caddr_t) opts->data;
      if (col_name)
	{
	  ST **dtp = (ST **) opts->next->data;
	  ST **cc = (ST **) dtp[1];
	  if (cc)
	    {
	      int inx;
	      DO_BOX (ST *, co, inx, cc)
	      {
		if (IS_BOX_POINTER (co))
		  {
		    switch (co->type)
		      {

		      case FOREIGN_KEY:
			co->_.fkey.fk_cols =
			    (caddr_t *) t_list (1, t_box_copy (col_name));
			break;

		      case INDEX_DEF:
			co->_.index.cols =
			    (caddr_t *) t_list (1, t_box_copy (col_name));
			break;

		      case UNIQUE_DEF:
			co->_.index.cols =
			    (caddr_t *) t_list (1, t_box_copy (col_name));
			break;

		      case CHECK_CONSTR:
			break;

		      case CHECK_XMLSCHEMA_CONSTR:
		        {
		          ST *isnull_bop = (ST *)(co->_.op.arg_1);
		          ST *call_op = (ST *)(isnull_bop->_.op.arg_1);
		          caddr_t *arglist = ((caddr_t *)(call_op->_.call.params));
#ifdef DEBUG
		          if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF(arglist)) || (6 != BOX_ELEMENTS(arglist)))
		            GPF_T;
#endif
		          arglist [0] = t_box_string (table_name);
		          arglist [1] = t_box_string (col_name);
		          arglist [2] = (caddr_t) t_list (3, COL_DOTTED, NULL, t_box_copy_tree (col_name));
			  break;
			}

		      default: goto dont_add_table_opts;
		      }
		    table_opts = t_CONS (NULL,
		      t_CONS (t_box_copy_tree ((caddr_t) co), table_opts));
dont_add_table_opts: ;
		  }
	      }
	      END_DO_BOX;
	    }
	}
      opts = opts->next->next;
    }
  return table_opts;
}


ST *
sqlp_numeric (caddr_t pp, caddr_t ss)
{
  long prec = (long) unbox (pp);
  long scale = (long) unbox (ss);
/*  dk_free_box (ss);
  dk_free_box (pp);*/

  if (prec > NUMERIC_MAX_PRECISION || scale > NUMERIC_MAX_SCALE)
    yyerror ("Numeric precision or scale exceeds maximum: numeric(40,15)");
  if (prec < 0 || scale < 0)
    yyerror ("Non-valid numeric precision or scale");
  if (prec < scale)
    yyerror ("Numeric precision greater than the scale");

  if (0 == prec)
    return ((ST *) t_list (3, (ptrlong)DV_NUMERIC, t_box_num (NUMERIC_MAX_PRECISION),
	t_box_num (NUMERIC_MAX_SCALE)));

  if (scale != 0 || prec > 9)
    return ((ST *) t_list (3, (ptrlong)DV_NUMERIC, t_box_num (prec), t_box_num (scale)));

  if (prec < 5)
    return ((ST *) t_list (3, (ptrlong)DV_SHORT_INT, t_box_num (prec), t_box_num (0)));
  else
    return ((ST *) t_list (3, (ptrlong)DV_LONG_INT, t_box_num (prec), t_box_num (scale)));
}


caddr_t sqlp_known_function_name (caddr_t name)
{
  if (!bif_find (name))
    {
      char *full_name = sch_full_proc_name (wi_inst.wi_schema, name,
	cli_qual (sqlc_client ()), CLI_OWNER (sqlc_client ()) );
      if (NULL == full_name)
	yy_new_error ("Undefined function name in the declaration of user aggregate", "37000", "SQ155");
      return t_box_string (full_name);
    }
  return name;
}


ST *sqlp_make_user_aggregate_fun_ref (caddr_t function_name, ST **arglist, int allow_yyerror)
{
  ST *acc;
  caddr_t full_name;
  query_t *aggr;
  if (0 == stricmp (function_name, "XMLAGG"))
    function_name = t_box_string ("DB.DBA.XMLAGG");
  full_name = sch_full_proc_name (wi_inst.wi_schema, function_name,
    cli_qual (sqlc_client ()), CLI_OWNER (sqlc_client ()) );
  aggr = ((NULL == full_name) ? NULL : sch_proc_def (wi_inst.wi_schema, full_name));
  if (NULL == aggr)
    { if (allow_yyerror) yyerror ("Unknown aggregate name"); else return NULL; }
  if (NULL == aggr->qr_aggregate)
    { if (allow_yyerror) yyerror ("The specified name is not an aggregate name"); else return NULL; }
  acc = (ST *) t_alloc_box (sizeof (ST), DV_ARRAY_OF_POINTER);
  memset (acc, 0, sizeof (ST));
  acc->type = FUN_REF;
  acc->_.fn_ref.fn_code = AMMSC_USER;
  acc->_.fn_ref.user_aggr_addr = t_box_num ((ptrlong)(aggr->qr_aggregate));
  acc->_.fn_ref.all_distinct = 0;
  acc->_.fn_ref.fn_arglist = arglist;
  return t_listst (3, CALL_STMT, t_sym_string (aggr->qr_aggregate->ua_final.uaf_name), t_list (1, acc));

}

void
sqlp_complete_fun_ref (ST * tree)
{
  if (tree->_.fn_ref.fn_code == AMMSC_COUNT
      && !tree->_.fn_ref.all_distinct
      && tree->_.fn_ref.fn_arg && DV_LONG_INT != DV_TYPE_OF (tree->_.fn_ref.fn_arg))
    {
      /* count of non-* */
      ST * arg = tree->_.fn_ref.fn_arg; /* not AMMSC_USER so it's argument, not a vector of them */
      ST * exp = (ST*) t_list (3, CALL_STMT, t_sqlp_box_id_upcase  ("isnotnull"), t_list (1, arg));
      tree->_.fn_ref.fn_arg = exp;
      tree->_.fn_ref.fn_code = AMMSC_COUNTSUM;
    }
}


void
sqlp_in_view (char * view)
{
  user_t * v_user;
  char q [100];
  char o [100];
  char n [100];
  inside_view = view;
  view_aliases = NULL;
  if (!sec_users)
    {
      v_u_id = U_ID_DBA;
      v_g_id = G_ID_DBA;
      return;
    }

  if (!view)
    return;
  sch_split_name ("", view, q, o, n);
  v_user = sec_name_to_user (o);
  if (!v_user)
    {
      client_connection_t *cli = sqlc_client ();

      if (cli->cli_user && !sec_user_has_group (G_ID_DBA, cli->cli_user->usr_id) &&
	  0 != CASEMODESTRCMP ("INFORMATION_SCHEMA", o))
	yyerror ("View owner must be an existing user.");
      v_u_id = U_ID_DBA;
      v_g_id = G_ID_DBA;
    }
  else
    {
      v_u_id = v_user->usr_id;
      v_g_id = v_user->usr_g_id;
    }
}


caddr_t
sqlp_view_g_id (void)
{
  if (inside_view)
    return t_box_num (v_g_id);
  return t_box_num ((SC_G_ID (top_sc)));
}


caddr_t
sqlp_view_u_id (void)
{
  if (inside_view)
    return t_box_num (v_u_id);
  return t_box_num (SC_U_ID (top_sc));
}


dk_set_t html_lines;

caddr_t
sqlp_html_string (void)
{
  int len = 0;
  int fill = 0;
  caddr_t str;
  html_lines = dk_set_nreverse (html_lines);
  DO_SET (caddr_t, line, &html_lines)
    {
      len += box_length (line) - 1;
    }
  END_DO_SET ();
  str = t_alloc_box (len + 1, DV_SHORT_STRING);
  DO_SET (caddr_t, line, &html_lines)
    {
      memcpy (str + fill, line, box_length (line) - 1);
      fill += box_length (line) - 1;
      /*dk_free_box (line);*/
    }
  END_DO_SET ();
  str[fill] = 0;
  /*dk_set_free (html_lines);*/
  html_lines = NULL;
  return str;
}


ST *
st_left_sel (ST * tree)
{
  while (! ST_P (tree, SELECT_STMT))
    tree = tree->_.bin_exp.left;
  return tree;
}

ST *
sqlp_cr_vars (ST * sel)
{
  int inx;
  ST ** res = (ST **) t_box_copy ((caddr_t) sel->_.select_stmt.selection);
  DO_BOX (ST *, exp, inx, res)
    {
      if (ST_COLUMN (exp, COL_DOTTED))
	res[inx] = (ST*) t_list (4, LOCAL_VAR,IN_MODE,
	    t_list (3, COL_DOTTED, NULL, t_box_copy (exp->_.col_ref.name)),
	    t_list (3, (ptrlong)DV_ANY, (ptrlong)0, (ptrlong)0));
      else if (ST_P (exp, BOP_AS))
	res[inx] = (ST*) t_list (4, LOCAL_VAR, IN_MODE,
	    t_list (3, COL_DOTTED, NULL, t_box_copy (exp->_.as_exp.name)),
	    t_list (3, (ptrlong)DV_ANY, (ptrlong)0, (ptrlong)0));
      else
	yyerror ("FOR statement needs a cursor with named result columns ");
    }
  END_DO_BOX;
  return ((ST*) t_list (2, VARIABLE_DECL, res));
}

ST **
sqlp_cr_fetch_vars (ST * sel)
{
  int inx;
  ST ** res = (ST **) t_box_copy ((caddr_t) sel->_.select_stmt.selection);
  DO_BOX (ST *, exp, inx, res)
    {
      if (ST_COLUMN (exp, COL_DOTTED))
	res[inx] = (ST*) t_list (3, COL_DOTTED, NULL, t_box_copy (exp->_.col_ref.name));
      else if (ST_P (exp, BOP_AS))
	res[inx] = (ST*) t_list (3, COL_DOTTED, NULL, t_box_copy (exp->_.as_exp.name));
      else
	yyerror ("FOR statement needs a cursor with named result columns ");
    }
  END_DO_BOX;
  return res;
}




ST *
sqlp_for_statement (ST * sel, ST * body)
{
  ST * left_sel = st_left_sel (sel);
  ST * while_fetch;
  ST * while_handler;
  ST * cst;
  ST * cdef;
  static int ctr = 0;
  char cn[10];
  snprintf (cn, sizeof (cn), "c_%d", ctr++);
  cdef = t_listst (5, CURSOR_DEF, t_box_string (cn), sel, _SQL_CURSOR_FORWARD_ONLY, NULL);
  while_fetch = t_listst (5, FETCH_STMT, t_box_string (cn), sqlp_cr_fetch_vars (left_sel), (ptrlong) _SQL_FETCH_NEXT, NULL);
  while_handler = t_listst (4, HANDLER_DECL, HANDT_CONTINUE, t_list (1, (ptrlong)SQL_NO_DATA_FOUND), sqlp_resignal (NULL));
  cst = (ST*)
    t_list (5, COMPOUND_STMT, t_list (6,
	  cdef,
	  t_list (4, HANDLER_DECL, HANDT_CONTINUE, t_list (1, (ptrlong)SQL_NO_DATA_FOUND),
	    t_list (2, GOTO_STMT, t_box_string (cn))),
	  t_list (4, OPEN_STMT, t_box_string (cn), NULL, NULL),
	  sqlp_cr_vars (left_sel),
	  t_list (3, WHILE_STMT, t_list (4, BOP_EQ, t_box_num (1), t_box_num (1), NULL),
		t_list (5, COMPOUND_STMT, t_list (3,
		      while_fetch,
		      while_handler,
		      body),
		  t_box_num (global_scs->scs_scn3c.lineno),
		  t_box_num (scn3_get_lineno()),
		  t_box_string (scn3_get_file_name())
		        )),
	  t_list (3, LABELED_STMT, t_box_string (cn),
		t_list (5, COMPOUND_STMT, t_list (0),
		  t_box_num (global_scs->scs_scn3c.lineno),
		  t_box_num (scn3_get_lineno()),
		  t_box_string (scn3_get_file_name())
		  ))),
	t_box_num (global_scs->scs_scn3c.lineno),
	t_box_num (scn3_get_lineno()),
	t_box_string (scn3_get_file_name())
	);
  return cst;
}


long
sqlp_handler_star_pos (caddr_t name)
{
  if (DV_STRINGP (name))
    {
      char *star_pos = strchr (name, '*');
      return ((long) (star_pos ? (star_pos - name) : strlen (name)));
    }
  else
    return 0;
}


ST *
sqlp_resignal (ST *state)
{
  return t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("signal"),
      t_list (2,
	state ? (caddr_t) state : (caddr_t) t_list (3, COL_DOTTED, NULL, t_sqlp_box_id_upcase ("__SQL_STATE")),
	t_list (3, COL_DOTTED, NULL, t_sqlp_box_id_upcase ("__SQL_MESSAGE"))));
}


ST *
sqlp_embedded_xpath (caddr_t  string)
{
#ifdef BIF_XML
  caddr_t err = NULL;
  ST * tree = sqlc_embedded_xpath (top_sc, string, &err);
  if (err)
    {
      yyerror (ERR_MESSAGE (err));
    }
  return tree;
#else
  yyerror ("Embedded XPATH not enabled");
#endif
}



caddr_t *
sqlp_string_col_list (caddr_t * lst)
{
  int inx;
  DO_BOX (caddr_t, n, inx, lst)
    {
      caddr_t s = t_box_string (n);
      /*dk_free_box (n);*/
      lst[inx] = s;
    }
  END_DO_BOX;
  return lst;
}


caddr_t
sqlp_xml_col_name (ST * tree)
{
  char xx[4 * MAX_NAME_LEN];
  snprintf (xx, sizeof (xx),
      "%s!%d!%s", tree->_.xml_col.element, (int) unbox (tree->_.xml_col.tag), tree->_.xml_col.attr_name);
  return (t_box_string (xx));
}


int sqlp_xml_col_directive (char *id)
{
  if (!stricmp (id, "ID"))
    return XML_COL_ID;
  if (!stricmp (id, "IDREF"))
    return XML_COL_IDREF;
  if (!stricmp (id, "IDREFS"))
    yyerror ("Only 'ID' and 'IDREF' schema directives are supported in this version of Virtuoso, not 'IDREFS'");
  if (!stricmp (id, "element"))
    return XML_COL_ELEMENT;
  if (!stricmp (id, "hide"))
    return XML_COL_HIDE;
  if (!stricmp (id, "xml"))
    return XML_COL_XML;
  if (!stricmp (id, "xmltext"))
    return XML_COL_XMLTEXT;
  if (!stricmp (id, "cdata"))
    return XML_COL_CDATA;
  yyerror ("Invalid directive at the end of the name of XML-SQL column");
  return 0;
}


long
sqlp_xml_select_flags (char * mode, char * elt)
{
  long v = 0;
  if (0 == stricmp (mode, "auto"))
    v = XR_AUTO;
  else if (0 == stricmp (mode, "raw"))
    v = XR_ROW;
  else if (0 == stricmp (mode, "explicit"))
    v = XR_EXPLICIT;
  else
    yyerror ("FOR XML mode must be raw, auto or explicit");
  if (elt && 0 == stricmp (elt, "element"))
    v |= XR_ELEMENT;
/*  dk_free_box (mode);
  dk_free_box (elt);*/
  return v;
}

#if 0
void
sqlp_tweak_selection_names (ST * tree)
{
  ST ** sel;
  int inx;
  if (!ST_P (tree, SELECT_STMT))
    return;
  sel = (ST **)(tree->_.select_stmt.selection);
  DO_BOX (ST *, exp, inx, sel)
    {
      int inx2;
      if (!ST_P (exp, BOP_AS))
        goto tweak; /* see below */
      for (inx2 = inx; inx2--; /* no step */)
        if (!strcmp (sel[inx2]->_.as_exp.name, exp->_.as_exp.name))
          goto tweak; /* see below */
    }
  END_DO_BOX;
  return;
tweak:
  sqlc_selection_names (tree, 1);
}
#endif

ptrlong
sqlp_bunion_flag (ST * l, ST * r, long f)
{
  long lf =  (ST_P (l, UNION_ST) | ST_P (l, UNION_ALL_ST)) ? (long) l->_.set_exp.is_best : 0;
  long rf =  (ST_P (r, UNION_ST) | ST_P (r, UNION_ALL_ST)) ? (long) r->_.set_exp.is_best : 0;
  return ((ptrlong) (f ||  lf || rf));
}

ST *
sqlp_wpar_nonselect (ST *subq)
{
  ST *tbl_ref, *from_clause, *tbl_exp, **selection, *wrapped_subq;
  char tname[100];
  if (ST_P (subq, SELECT_STMT))
    return subq;
  snprintf (tname, sizeof (tname), "_subq_%ld", (long)((ptrlong)(subq)));
  tbl_ref = t_listst (3, DERIVED_TABLE, sqlp_view_def (NULL, subq, 0), t_box_string (tname));
  from_clause = t_listst (1, tbl_ref);
  tbl_exp = sqlp_infoschema_redirect (t_listst (9, TABLE_EXP, from_clause, NULL, NULL, NULL, NULL, (ptrlong) 0, NULL, NULL));
  selection = (ST **)t_list (1, t_listst (3, COL_DOTTED, (long) 0, STAR));
  wrapped_subq = t_listst (5, SELECT_STMT, NULL,
    sqlp_stars (sqlp_wrapper_sqlxml (selection), tbl_exp->_.table_exp.from) , NULL, tbl_exp);
  sqlp_breakup (wrapped_subq);
  return wrapped_subq;
}

ST *
sqlp_inline_order_by (ST *tree, ST **oby)
{
  ST *right;

  if (!oby)
    return tree;
  right = sqlp_union_tree_right (tree);

  if (!ST_P (right, SELECT_STMT) ||
      !right->_.select_stmt.table_exp ||
      right->_.select_stmt.table_exp->_.table_exp.order_by)
    yy_new_error ("Incorrect ORDER BY clause for query expression", "37000", "SQ147");
  right->_.select_stmt.table_exp->_.table_exp.order_by = oby;
  return tree;
}

static ST *
sqlp_raw_name_string_to_col_dotted (const char *fullname)
{
  char buf[MAX_QUAL_NAME_LEN];
  char *part1, *part2, *part3, *part4;
  strcpy_ck (buf, fullname);
  part1 = strchr (buf, '.');
  if (NULL == part1)
    return t_listst (3, COL_DOTTED, NULL, t_sqlp_box_id_upcase (buf));
  (part1++)[0] = '\0';
  part2 = strchr (part1, '.');
  if (NULL == part2)
    return t_listst (3, COL_DOTTED, c_pref (NULL, 0, NULL, 0, t_sqlp_box_id_upcase (buf)), t_sqlp_box_id_upcase (part1));
  (part2++)[0] = '\0';
  part3 = strchr (part2, '.');
  if (NULL == part3)
    return t_listst (3, COL_DOTTED, c_pref (NULL, 0, t_sqlp_box_id_upcase (buf), part1-buf, t_sqlp_box_id_upcase (part1)), t_sqlp_box_id_upcase (part2));
  (part3++)[0] = '\0';
  part4 = strchr (part3, '.');
  if (NULL != part4)
    yy_new_error ("Too many part characters in column name", "37000", "SQ197");
  if (part2 == (part1+1))
    return t_listst (3, COL_DOTTED, c_pref (t_sqlp_box_id_upcase (buf), part1-buf, NULL, 0, t_sqlp_box_id_upcase (part2)), t_sqlp_box_id_upcase (part3));
  return t_listst (3, COL_DOTTED, c_pref (t_sqlp_box_id_upcase (buf), part1-buf, t_sqlp_box_id_upcase (part1), part2-part1, t_sqlp_box_id_upcase (part2)), t_sqlp_box_id_upcase (part3));
}

static void
sqlp_contains_opts (ST * tree)
{
  int inx;
  if (0 == stricmp (tree->_.call.name, "contains")
      || 0 == stricmp (tree->_.call.name, "xcontains"))
    {
      if (2 > BOX_ELEMENTS (tree->_.call.params))
        yyerror ("The special SQL predicate has invalid number of arguments");
      DO_BOX (ST *, arg, inx, tree->_.call.params)
	{
	  if (inx < 2)
	    continue;
	  if (ST_COLUMN (arg, COL_DOTTED))
	    {
	      caddr_t name = arg->_.col_ref.name;
	      if (0 == stricmp (name, "offband")
		  || 0 == stricmp (name, "desc")
		  || 0 == stricmp (name, "descending")
		  || 0 == stricmp (name, "start_id")
		  || 0 == stricmp (name, "ranges")
		  || 0 == stricmp (name, "main_ranges")
		  || 0 == stricmp (name, "attr_ranges")
		  || 0 == stricmp (name, "score")
		  || 0 == stricmp (name, "score_limit")
		  || 0 == stricmp (name, "end_id")
		  || 0 == stricmp (name, "ext_fti") )
		{
/*		  dk_free_tree ((caddr_t) arg);*/
		  tree->_.call.params[inx] = (ST *) t_box_string (name);
		}
	    }
	}
      END_DO_BOX;
    }
}

/*sqlxml*/
static void
sqlp_check_arg (ST * tree)
{
  int inx;
  DO_BOX (ST *, arg, inx, tree->_.call.params)
    {
      if (ST_P (arg, BOP_AS))
	{
	  if ( /* This is Bug 7585 workaround */
	    !stricmp (tree->_.call.name, "XMLELEMENT") &&
	    ST_COLUMN (arg->_.as_exp.left, COL_DOTTED) &&
	    (NULL == arg->_.as_exp.left->_.col_ref.prefix) &&
	    !stricmp (arg->_.as_exp.left->_.col_ref.name, "NAME") )
	    {
	      tree->_.call.params[inx] = (ST *)t_box_string (arg->_.as_exp.name);
	    }
	  else
	    yyerror ("Aliases are not allowed here (missing comma between arguments of a function call?)");
	}
      else if (ST_P (arg, CALL_STMT) && stricmp (tree->_.call.name, "xml_tree_doc") &&
	(0 == stricmp (arg->_.call.name, "XMLELEMENT")))
	{
	  ST * acc = (ST *) t_alloc_box (sizeof (ST), DV_ARRAY_OF_POINTER);
          ST * xmltreedoc = t_listst (3, CALL_STMT, t_box_string ("XML_TREE_DOC"),
		t_list (1, acc));
          xmltreedoc->_.call.params[0] = arg;
          tree->_.call.params[inx]= xmltreedoc;
	}
    }
  END_DO_BOX;
}


static void
sqlp_sqlxml (ST * tree)
{
  int inx;
  if (0 == stricmp (tree->_.call.name, "XMLAGG"))
    {
      tree->_.call.name = t_box_string ("DB.DBA.XMLAGG");
      return;
    }
  if (0 == stricmp (tree->_.call.name, "XMLELEMENT"))
    {
      ST * arg;
      if (0 == BOX_ELEMENTS (tree->_.call.params))
	yyerror ("Function XMLELEMENT should have at least one argument that is element name");
      arg = tree->_.call.params[0];
      if (ST_COLUMN (arg, COL_DOTTED))
	tree->_.call.params[0] = (ST *) t_box_string (arg->_.col_ref.name);
      return;
    }
  if (0 == stricmp (tree->_.call.name, "XMLATTRIBUTES")
      || 0 == stricmp (tree->_.call.name, "XMLFOREST"))
    {
      ST **old_params = tree->_.call.params;
      ST **new_params = (ST **) t_alloc_box (box_length(old_params) * 2, DV_ARRAY_OF_POINTER);
      tree->_.call.params = new_params;
      DO_BOX (ST *, arg, inx, old_params)
	{
	  if (ST_P (arg, BOP_AS))
	    {
	      new_params[inx*2] = (ST *) t_box_string ((caddr_t) arg->_.as_exp.name);
	      new_params[inx*2+1] = (ST *) t_box_copy_tree ((caddr_t)arg->_.as_exp.left);
	      continue;
	    }
	  if (ST_COLUMN (arg, COL_DOTTED))
	    {
	      new_params[inx*2] = (ST *) t_box_string((caddr_t) arg->_.col_ref.name);
	      new_params[inx*2+1] = (ST *) t_box_copy_tree((box_t) arg);
	      continue;
	    }
	  yyerror ("Named argument expected (i.e. variable name or column name or an 'expression AS name' alias");
	}
      END_DO_BOX;
      return;
    }
}
/*end sqlxml*/

static void
sqlp_xpath_or_xquery_eval (ST * funcall_tree)
{
  char *call_name = funcall_tree->_.call.name;
      char buf[30];
      ST **old_params = funcall_tree->_.call.params;
      size_t old_argcount = BOX_ELEMENTS (old_params);
  if (enable_vec)
    return; /* FIXME: the _w_cache  do not run vectored, hack with ssl should be made vectored  */
      if (2 > old_argcount)
    yyerror ("Functions xpath_eval() and xquery_eval() require at least two arguments");
      if (DV_STRING == DV_TYPE_OF(old_params[0]))
        {
	  char predicate_type = (0 == stricmp (call_name, "xpath_eval")) ? 'p' : 'q';
          caddr_t err = NULL;
          wcharset_t *cset = top_sc->sc_client->cli_charset;
	  dk_set_t sql_columns = NULL;
	  xp_query_env_t xqre;
	  xp_query_t *xqr;
	  memset (&xqre, 0, sizeof (xp_query_env_t));
	  if (NULL == cset)
	    cset = default_charset;
          xqre.xqre_query_charset = cset;
          xqre.xqre_query_charset_is_set = 1;
          xqre.xqre_sql_columns = &sql_columns;
          /* xqre.xqre_key_gen = 2; This is possible but should be checked later */
          xqr = xp_query_parse (NULL, (caddr_t)(old_params[0]), predicate_type, &err, &xqre);
	  if (err)
	    {
	      if (!strcmp (ERR_STATE (err), "37XQR"))
		dk_free_tree (err);
	      else
		{
		  char buf[1900];
		  snprintf_ck (buf, sizeof(buf), "Can't compile the first argument of %s():\n%s", call_name, ERR_MESSAGE (err));
		  dk_free_tree (err);
		  while (NULL != sql_columns)
		    dk_free_box ((box_t) dk_set_pop (&sql_columns));
		  yyerror (buf);
		}
	    }
	  if (NULL != sql_columns)
	    {
	      dk_set_t param_set = NULL;
	      ST **param_list;
	      ST *vector_call;
	      while (NULL != sql_columns)
	        {
		  char buf [MAX_QUAL_NAME_LEN + 20];
	          caddr_t col_name = (caddr_t) dk_set_pop (&sql_columns);
	          ST *col_dotted = sqlp_raw_name_string_to_col_dotted (col_name);
		  sprintf (buf, XQ_SQL_COLUMN_FORMAT, col_name);
		  dk_set_push (&param_set, t_box_string (buf));
		  dk_set_push (&param_set, col_dotted);
	        }
	      param_list = (ST **)t_revlist_to_array (param_set);
	      vector_call = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("vector"), param_list);
	      if (2 == old_argcount)
	        {
		  funcall_tree->_.call.params = (ST **)t_list_concat ((caddr_t)old_params, (caddr_t)t_list (1, t_box_num_and_zero (1)));
		  old_params = funcall_tree->_.call.params;
		  old_argcount++;
		}
	      if (3 == old_argcount)
	        {
		  funcall_tree->_.call.params = (ST **)t_list_concat ((caddr_t)old_params, (caddr_t)t_list (1, vector_call));
		  old_params = funcall_tree->_.call.params;
		  old_argcount++;
	        }
	      else
	        {
	          old_params[3] =
	            t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("vector_concat"), t_list (2, vector_call, old_params[3]));
	        }
	    }
	  if (NULL != xqr)
	    {
          /*t_trash_push (xqr);*/
          old_params[0] = (ST *)xqr;
	      return;
	    }
        }
  sprintf (buf, "%s__w_cache", call_name);
  funcall_tree->_.call.name = t_sqlp_box_id_upcase (buf);
  funcall_tree->_.call.params = (ST **)t_list_concat ((caddr_t)old_params, (caddr_t)t_list (1, t_box_num_and_zero (0)));
}

static void
sqlp_xpath_funcall_or_apply (ST * funcall_tree)
{
  const char *call_name = funcall_tree->_.call.name;
  const char *xpf_name = NULL;
  xpf_metadata_t *metas = NULL;
  char buf[30];
  ST **old_params = funcall_tree->_.call.params;
  size_t old_argcount = BOX_ELEMENTS (old_params);
  char call_type = ((0 == stricmp (call_name, "xpath_funcall")) ? 'f' : 'a');
  if ('f' == call_type)
    {
      if (2 > old_argcount)
        yyerror ("Function xpath_funcall() requires at least two arguments");
    }
  else
    {
      if (3 != old_argcount)
        yyerror ("Function xpath_apply() requires exactly three arguments");
    }
  if (DV_STRING == DV_TYPE_OF(old_params[0]))
    {
      xpf_metadata_t ** metas_ptr;
      xpf_name = (const char *)(old_params[0]);
      metas_ptr = (xpf_metadata_t **)id_hash_get (xpf_metas, (caddr_t)(&xpf_name));
      if (NULL == metas_ptr)
        yyerror ("Unknown XPath function name is used as first argument of xpath_funcall() or xpath_apply() function");
      metas = metas_ptr[0];
    }
  if ((NULL != metas) && ('f' == call_type))
    {
      xp_query_t *xqr;
      int fn_argcount = old_argcount-2;
      if (metas->xpfm_min_arg_no > fn_argcount)
        yyerror ("The XPATH function mentioned in xpath_funcall() requires more arguments than specified in the call");
      if (metas->xpfm_main_arg_no < fn_argcount)
        {
          if (0 == metas->xpfm_tail_arg_no)
            yyerror ("The XPATH function mentioned in xpath_funcall() requires less arguments than specified in the call");
          else
            {
              int tail_mod = (fn_argcount - metas->xpfm_main_arg_no) % metas->xpfm_tail_arg_no;
              if (tail_mod)
                yyerror ("The XPATH function mentioned in xpath_funcall() requires less arguments than specified in the call");
            }
        }
      xqr = xqr_stub_for_funcall (metas, fn_argcount);
      xqr->xqr_key = box_copy (old_params[0]);
      /*t_trash_push (xqr);*/
      old_params[0] = (ST *)xqr;
    }
  sprintf (buf, "%s__w_cache", call_name);
      funcall_tree->_.call.name = t_sqlp_box_id_upcase (buf);
      funcall_tree->_.call.params = (ST **)t_list_concat ((caddr_t)old_params, (caddr_t)t_list (1, t_box_num_and_zero (0)));
}

ST *
sqlp_patch_call_if_special_or_optimizable (ST * funcall_tree)
{
  char *call_name = funcall_tree->_.call.name;
  bif_metadata_t *bmd;
  int argcount = BOX_ELEMENTS (funcall_tree->_.call.params);
  if ((DV_SYMBOL != DV_TYPE_OF (call_name)) && (DV_STRING != DV_TYPE_OF (call_name)))
    call_name = "";
  if (0 == stricmp (call_name, "contains")
      || 0 == stricmp (call_name, "xcontains"))
    {
      sqlp_contains_opts (funcall_tree);
      goto generic_check;
    }
/*sqlxml*/
  if (0 == stricmp (call_name, "XMLELEMENT")
	   || 0 == stricmp (call_name, "XMLFOREST")
	   || 0 == stricmp (call_name, "XMLATTRIBUTES")
	   || 0 == stricmp (call_name, "XMLCONCAT")
	   || 0 == stricmp (call_name, "XMLAGG")
	   || 0 == stricmp (call_name, "DB.DBA.XMLAGG") )
    {
      sqlp_sqlxml (funcall_tree);
      goto generic_check;
    }
  if (0 == stricmp (call_name, "fix_identifier_case"))
    {
      ST * param;
      if (0 == argcount)
	goto generic_check;
      param = funcall_tree->_.call.params[0];
      if (CM_UPPER != case_mode)
        return param;
      if (DV_STRING == DV_TYPE_OF (param))
        {
          caddr_t out = sqlp_box_id_upcase ((char *) param);
	  caddr_t out1 = t_box_dv_short_nchars (out, box_length (out) - 1);
	  dk_free_box (out);
	  return ((ST*) out1);
	}
      goto generic_check;
    }
  if (0 == stricmp (call_name, "xpath_eval")
	   || 0 == stricmp (call_name, "xquery_eval") )
    {
      sqlp_xpath_or_xquery_eval (funcall_tree);
      goto generic_check;
    }
  if (0 == stricmp (call_name, "xpath_funcall")
	   || 0 == stricmp (call_name, "xquery_apply") )
    {
      sqlp_xpath_funcall_or_apply (funcall_tree);
      goto generic_check;
    }
  if ((0 == strnicmp (call_name, "__I2ID", 6) || strstr (call_name, "IID_OF_QNAME"))
      && argcount >= 1)
    {
      caddr_t arg = sqlo_iri_constant_name_1 (funcall_tree->_.call.params[0]);
      if (arg)
	{
	  if (strstr (call_name, "OF_QNAME_"))
	    funcall_tree->_.call.name = t_box_string ("__I2IDN");
	  funcall_tree->_.call.params[0] = (ST *) arg;
	}
    }
generic_check:
  bmd = find_bif_metadata_by_raw_name (call_name);
  if (NULL != bmd)
    {
#if 0
      if ((bmd->bmd_min_argcount == bmd->bmd_max_argcount) && (bmd->bmd_min_argcount != argcount))
        yyerror (t_box_sprintf (1000, "Wrong number of arguments in %.200s() function call (%d arguments, must be %d):",
            call_name, argcount, bmd->bmd_min_argcount ) );
      if (bmd->bmd_min_argcount > argcount)
        yyerror (t_box_sprintf (1000, "Insufficient number of arguments in %.200s() function call (%d arguments, the minimum is %d):",
            call_name, argcount, bmd->bmd_min_argcount ) );
      if (bmd->bmd_max_argcount < argcount)
        yyerror (t_box_sprintf (1000, "Too many arguments in %.200s() function call (%d arguments, no more than %d are allowed):",
            call_name, argcount, bmd->bmd_max_argcount ) );
      if ((1 < bmd->bmd_argcount_inc) && (argcount - bmd->bmd_min_argcount) % bmd->bmd_argcount_inc)
        yyerror (t_box_sprintf (1000, "Wrong number of arguments in %.200s() function call (%d arguments, valid counts are %d, %d, %d etc.):",
            call_name, argcount, bmd->bmd_min_argcount, bmd->bmd_min_argcount + bmd->bmd_argcount_inc, bmd->bmd_min_argcount + 2 * bmd->bmd_argcount_inc ) );
#endif
      if (bmd->bmd_is_pure)
        {
          int argctr, quoted_arg_ctr = 0;
          size_t args_memsize = 0, res_memsize = 0;
          caddr_t err = NULL;
          caddr_t ret_val;
          caddr_t *unquoted_params = NULL;
          ST *lit;
          for (argctr = 0; argctr < argcount; argctr++)
            {
              ST *arg = funcall_tree->_.call.params[argctr];
              if (LITERAL_P (arg))
                continue;
              if (ST_P (arg, QUOTE))
                {
                  quoted_arg_ctr++;
                  continue;
                }
              goto not_a_constant_pure;
            }
          if (quoted_arg_ctr)
            {
              unquoted_params = (caddr_t *)t_box_copy ((caddr_t)(funcall_tree->_.call.params));
              for (argctr = 0; argctr < argcount; argctr++)
                {
                  ST *arg = funcall_tree->_.call.params[argctr];
                  if (ST_P (arg, QUOTE))
                    unquoted_params[argctr] = (caddr_t)(arg->_.op.arg_1);
                }
            }
          else
            unquoted_params = (caddr_t *)(funcall_tree->_.call.params);
          for (argctr = 0; argctr < argcount; argctr++)
            args_memsize += 8 + (IS_BOX_POINTER (unquoted_params[argctr]) ? box_length (unquoted_params[argctr]) : 8);
          ret_val = sqlr_run_bif_in_sandbox (bmd, unquoted_params, &err);
          if (NULL != err)
            {
#if 0
              ST *res;
              res = t_listst (3, CALL_STMT, t_box_dv_short_string ("signal"), t_list (2,
                  t_box_dv_short_string (ERR_STATE (err)),
                  t_box_dv_short_string (ERR_MESSAGE (err)) ) );
              dk_free_tree (err);
              return res;
#else
              goto not_a_constant_pure; /* see below */
#endif
            }
          if (!LITERAL_P(ret_val))
            {
              dk_free_box (ret_val);
              goto not_a_constant_pure; /* see below */
            }
          res_memsize = 8 + (IS_BOX_POINTER (ret_val) ? box_length (ret_val) : 8);
          if ((res_memsize > 0x1000) && (res_memsize > ((args_memsize * 3) / 2)))
            {
              dk_free_box (ret_val);
              goto not_a_constant_pure; /* see below */
            }
	  lit = (ST *)(t_full_box_copy_tree (ret_val));
	  if (DV_TYPE_OF (ret_val) == DV_RDF)
	    lit = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("__rdflit"), t_list (1, lit));
            dk_free_box (ret_val);
          return lit;
not_a_constant_pure: ;
        }
    }
  sqlp_check_arg (funcall_tree);
  return funcall_tree;
}


extern caddr_t uname_one_of_these;

ST *
sqlp_in_exp (ST * left, dk_set_t  right, int is_not)
{
  int inx;
  if (ST_P (left, COMMA_EXP))
    {
      ST * ors = NULL;
      DO_SET (ST *, exp, &right)
	{
	  ST * ands = NULL;
	  if (!ST_P (exp, COMMA_EXP))
	    yyerror ("IN predicate with multiple terms on the left not matched on the right");
	  if (BOX_ELEMENTS (exp->_.comma_exp.exps) != BOX_ELEMENTS (left->_.comma_exp.exps))
	    yyerror ("Different lengths of term lists in IN predicate");
	  DO_BOX (ST *, left_exp, inx, (ST**)left->_.comma_exp.exps)
	    {
	      ands = sql_tree_and (ands,
		  t_listst (4, BOP_EQ,
		    t_box_copy_tree ((caddr_t) left_exp),
		    exp->_.comma_exp.exps[inx], NULL));
	    }
	  END_DO_BOX;
	  if (ors)
	    ors = t_listst (4, BOP_OR, ors, ands, NULL);
	  else
	    ors = ands;
	}
      END_DO_SET ();
      if (is_not)
	{
	  ST * res = NULL;
	  NEGATE (res, ors);
	  return res;
	}
      return ors;
    }
  else
    {
      ST * res =
	t_listst (3, CALL_STMT, uname_one_of_these,
		t_list_to_array (t_CONS (left, right)));
      if (is_not)
	return (t_listst (3, BOP_EQ, t_box_num (0), res));
      else
	return (t_listst (3, BOP_LT, t_box_num (0), res));
    }
}


void
sqlp_pl_file (char * text)
{
  char *ptr = text, *sem;
  if (ptr)
    {
      pl_file_offs = 0;
      pl_file = NULL;
      while (*ptr && !isspace(*ptr)) /* skip leading comment */
	ptr++;
      while (*ptr && isspace(*ptr)) /* skip space */
	ptr++;
      sem = strrchr (ptr, ':'); /* got the delimiter */
      if (sem)
	{
	  int len = (int) (sem - ptr);
	  int line_no;

          sem++;

	  line_no = atol (sem);
	  if (global_scs->scs_scn3c.pragmaline_depth == 0)
	    { /* only on top level */
	      pl_file_offs = atol (sem);
	      pl_file = t_alloc_box (len+1, DV_STRING);
	      memcpy (pl_file, ptr, len);
	      pl_file[len] = 0;
	    }
	  scn3_set_file_line (ptr, len, line_no);
	}
    }
}


#ifdef PLDBG
void _br_push (void)
{
  if (parse_pldbg)
    {
      t_set_push(&sql3_ppbreaks, t_box_num(global_scs->scs_scn3c.plineno));
      t_set_push(&sql3_pbreaks, t_box_num(global_scs->scs_scn3c.lineno));
      t_set_push(&sql3_breaks, t_box_num(scn3_get_lineno()));
    }
}

void _br_pop (void)
{
  if (parse_pldbg)
    {
      t_set_pop(&sql3_breaks);
      t_set_pop(&sql3_pbreaks);
      t_set_pop(&sql3_ppbreaks);
    }
}

void _br_set (void)
{
  if (parse_pldbg && sql3_pbreaks &&
      (int) unbox ((box_t) sql3_pbreaks->data) != global_scs->scs_scn3c.lineno)
    {
      sql3_ppbreaks->data = (void *)t_box_num(global_scs->scs_scn3c.plineno);
      sql3_pbreaks->data = (void *)t_box_num(global_scs->scs_scn3c.lineno);
      sql3_breaks->data = (void *)t_box_num(scn3_get_lineno());
    }
}

int _br_get (void)
{
  int ret = (sql3_pbreaks ? (int) unbox((box_t) sql3_pbreaks->data) : 0);
  return ret;
}

int _br_lget (void)
{
  int ret = (sql3_breaks ? (int) unbox((box_t) sql3_breaks->data) : 0);
  return ret;
}

int _br_ppget (void)
{
  int ret = (sql3_ppbreaks ? (int) unbox((box_t) sql3_ppbreaks->data) : 0);
  return ret;
}

caddr_t _br_cstm (caddr_t stmt)
{
  ST *res = (parse_pldbg && !ST_P((ST *)(stmt), LABELED_STMT) ?
      (ST *) t_list (6, COMPOUND_STMT,
		     t_list (2,
		       t_list (2, BREAKPOINT_STMT,
			 t_box_num (_br_ppget())),
		       (stmt)),
		     t_box_num (_br_get()),
		     t_box_num (_br_lget()),
		     t_box_string (scn3_get_file_name ()),
		     t_box_num(1)) :
      (ST *) (stmt));
  return (caddr_t) res;
}
#endif

long sqlp_bin_op_serial = 0;


ST * sqlp_c_for_statement (ST **init, ST *cond, ST **inc, ST * body)
{
  ST *res;
  int init_cnt = BOX_ELEMENTS (init);
  int inc_cnt = BOX_ELEMENTS (inc);
  ST **cst = (ST **) t_alloc_box ((init_cnt + 1) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  ST **incst = (ST **) t_alloc_box ((inc_cnt + 1) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);

  memcpy (&(incst[1]), inc, inc_cnt * sizeof (caddr_t));
  incst[0] = body;
  memcpy (cst, init, init_cnt * sizeof (caddr_t));

  cst[init_cnt] = t_listst (3, WHILE_STMT, cond, t_listst (5, COMPOUND_STMT,
	incst,
	t_box_num (global_scs->scs_scn3c.lineno),
	t_box_num (scn3_get_lineno()),
	t_box_string (scn3_get_file_name())));

  res = t_listst (5, COMPOUND_STMT, cst,
      t_box_num (global_scs->scs_scn3c.lineno),
      t_box_num (scn3_get_lineno()),
      t_box_string (scn3_get_file_name()));
  return res;
}

ST * sqlp_foreach_statement (ST *data_type, caddr_t var, ST *arr, ST *body)
{
  static int ctr = 0;
  char cn[30];
  ST *comparison, *len_call, *inx, *inx2, *inc, *box1;

  snprintf (cn, sizeof (cn), "__foreach_inx%d", ctr++);
  inx = (ST *) t_list (3, COL_DOTTED, NULL, t_box_string (cn));
  len_call = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("length"), t_list (1, arr));

  inx2 = (ST *) t_box_copy_tree ((caddr_t) inx);
  BIN_OP (comparison, BOP_LT, inx2, len_call);
  inx2 = (ST *) t_box_copy_tree ((caddr_t) inx);
  box1 = (ST *) t_box_num (1);
  BIN_OP (inc, BOP_PLUS, inx2, box1);

  return sqlp_c_for_statement (
      (ST **) t_list (3,
		      t_list (2, VARIABLE_DECL,
			sqlp_local_variable_decls (t_list (1,
			    t_box_copy_tree ((caddr_t) inx)),
			  t_listst (2, (ptrlong)DV_LONG_INT, (ptrlong)0))),
		      t_list (2, VARIABLE_DECL,
			sqlp_local_variable_decls (t_list (1,
			    t_list (3, COL_DOTTED, NULL, t_box_copy_tree ((caddr_t) var))),
			  data_type)),
		      t_list (3, ASG_STMT,
			t_box_copy_tree ((caddr_t) inx),
			t_box_num_and_zero (0))
		      ),
      comparison,
      (ST **) t_list (1, t_list (3, ASG_STMT,
				 t_box_copy_tree ((caddr_t) inx), inc)),
      t_listst (5, COMPOUND_STMT,
	t_list (2,
	  t_list (3, ASG_STMT,
	    t_list (3, COL_DOTTED, NULL, t_box_copy_tree (var)), sqlp_wrapper_sqlxml_assign((ST*) t_list (3,
			    CALL_STMT, t_sqlp_box_id_upcase ("aref"),
			      t_list (2, arr, t_box_copy_tree ((caddr_t) inx))))),
	  body),
	t_box_num (global_scs->scs_scn3c.lineno),
	t_box_num (scn3_get_lineno()),
	t_box_string (scn3_get_file_name())));
}


ST *
sqlp_add_top_1 (ST *select_stmt)
{
  if (0 && !SEL_TOP (select_stmt))
    {
      select_stmt->_.select_stmt.top = t_listst (7, SELECT_TOP,
	  t_box_num (SEL_IS_DISTINCT (select_stmt) ? 1 : 0), /* preserve distinct */
	  box_num (1), /* TOP 1 */
	  t_box_num (0),
	  0,
	  box_num (0),
	  NULL);
    }
  return select_stmt;
}


ST *
sqlo_pop_as (ST * real_col)
{
  while (ST_P (real_col, BOP_AS))
    real_col = real_col->_.as_exp.left;
  return real_col;
}


void
sqlp_breakup (ST * sel)
{
  /* if the selection is a breakup list, put the component exps of the breakup list in the selection and save the breakup info in the top.
   * Check that lists are of equal length */
  static int breakup_alias_ctr = 0;
  int inx, is_first = 1, brk_len = 0;
  dk_set_t new_terms = NULL;
  dk_set_t * terms = (dk_set_t *) sel->_.select_stmt.selection;
  if (BOX_ELEMENTS (terms) < 2
      || !ST_P ( ((ST *)terms[0]), SELECT_BREAKUP) )
    return;
  if (sel->_.select_stmt.top || !sel->_.select_stmt.table_exp
      || sel->_.select_stmt.table_exp->_.table_exp.order_by || sel->_.select_stmt.table_exp->_.table_exp.group_by)
    yyerror ("breakup is not compatible with distinct, group by, order by or select with no from");
  DO_BOX (dk_set_t, term_list, inx, terms)
    {
if (!inx)
  continue; /* the 0th elt is a marker.  Not part of the breakup set */
      if (is_first)
	brk_len = dk_set_length (term_list);
      else if (brk_len != dk_set_length (term_list))
	yyerror ("breakup terms lists are not of even length");
      DO_SET (ST *, exp, &term_list)
	{
	  if (!is_first)
	    {
	      char alias[12];
	      ST * exp2 = sqlo_pop_as (exp);
	      sprintf (alias, "%d", breakup_alias_ctr++);
	      t_set_push (&new_terms, (void*) t_list (5, BOP_AS, exp2, NULL, t_box_string (alias), NULL));
	    }
	  else
	    t_set_push (&new_terms, (void*) exp);
	}
      END_DO_SET();
      is_first = 0;
    }
  END_DO_BOX;
  sel->_.select_stmt.selection = t_list_to_array (dk_set_nreverse (new_terms));
  sel->_.select_stmt.top = (ST*) (ptrlong) brk_len;
}


int
sel_n_breakup (ST* sel)
{
  /* returns the count of cols in each result row after breakup.  NEver less than 2 because there is always at least one col plus the flag to include or skip */
  ptrlong v;
  if (IS_BOX_POINTER (sel->_.select_stmt.top))
    return 0;
  v = (ptrlong) sel->_.select_stmt.top;
  return v > 1 ? v : 0;
}

caddr_t
sqlp_col_num (caddr_t n)
{
  /* check that the arg is between 1 and 1000 and return the unboxed 0 based index of the col */
  boxint n1 = unbox (n);
  if (n1 < 1 || n1 > 1000)
    yyerror ("Column index out of range in transitive dt");
  return (caddr_t)((ptrlong)(n1 - 1));
}


caddr_t
sqlp_minus (caddr_t x)
{
  switch (DV_TYPE_OF (x))
    {
    case DV_LONG_INT: return t_box_num (- unbox (x));
    case DV_NUMERIC: {
      NUMERIC_VAR (zero);
      numeric_from_int32 ((numeric_t) zero, 0);
      numeric_subtract ((numeric_t)x, (numeric_t) zero, (numeric_t)x);
      return x;
    }
    case DV_SINGLE_FLOAT: return t_box_float (- unbox_float (x));
    case DV_DOUBLE_FLOAT: return t_box_double (- unbox_double (x));
    default: yyerror ("unary minus of non-number");
    }
  return NULL;
}


int
sqlp_is_num_lit (caddr_t x)
{
  switch (DV_TYPE_OF (x))
    {
    case DV_LONG_INT:
    case DV_NUMERIC:
    case DV_SINGLE_FLOAT:
    case DV_DOUBLE_FLOAT:
      return 1;
    default: return 0;
    }
}


char *
sqlp_default_cluster ()
{
  return "__ALL";
}


dk_set_t
cl_all_host_group_list ()
{
  dk_set_t res = NULL;
  int inx;
  for (inx = local_cll.cll_max_host; inx > 0; inx--)
    {
      if (cl_id_to_host (inx))
	{
	  char name[20];
	  snprintf (name, sizeof (name), "Host%d", inx);
	  dk_set_push (&res, t_list (3, NULL, t_list (1, t_sym_string (name)), NULL));
	}
    }
  return res;
}

int enable_col_by_default  = 0;

dk_set_t
sqlp_index_default_opts(dk_set_t opts)
{
  if (enable_col_by_default)
    {
      DO_SET (caddr_t, opt, &opts)
	{
	  if (0 == stricmp (opt,  "not_column")
	      || 0 == stricmp (opt,  "column")
	      || 0 == stricmp (opt,  "bitmap"))
	    return opts;
	}
      END_DO_SET();
      return t_cons (t_box_string ("column"), opts);
    }
  return opts;
}

char *
sqlp_inx_col_opt ()
{
    return "column";
}
