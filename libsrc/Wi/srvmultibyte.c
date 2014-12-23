/*
 *  srvmultibyte.c
 *
 *  $Id$
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

#include "sqlnode.h"
#include "sqlfn.h"
#include "wi.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "sqlbif.h"
#include <errno.h>
#if !defined (__APPLE__)
#include <wchar.h>
#endif
#include "libutil.h"
#include "sqlparext.h"
#include "sqlcmps.h"
#include "sqlcstate.h"

id_hash_t *global_wide_charsets = NULL;
wcharset_t * default_charset = NULL;
caddr_t default_charset_name = NULL;

wchar_t
CHAR_TO_WCHAR (unsigned char uchar, wcharset_t *charset)
{
  if (!uchar)
    return uchar;
  return charset && charset != CHARSET_UTF8 ? charset->chrs_table[uchar] : ((wchar_t) uchar);
}


unsigned char
WCHAR_TO_CHAR (wchar_t wchar, wcharset_t *charset)
{
  unsigned char value;
  if (charset && charset != CHARSET_UTF8 && wchar)
    {
      value = (unsigned char) ((ptrlong) gethash ((void *) (ptrlong) wchar, charset->chrs_ht));
      if (!value)
	value = '?';
    }
  else if (((unsigned long)wchar) < 0x100L)
    value = (unsigned char) wchar;
  else
    value = '?';

  return (value);
}


#define UCHAR unsigned char
#define isoctdigit(C) (((C) & ~7) == 060)	/* 060 = 0x30 = 48. = '0' */
#define hexdigtoi(C) (isdigit(C) ? ((C) - '0') : (toupper(C) - ('A' - 10)))

int
parse_wide_string_literal (unsigned char **str_ptr, caddr_t box, wcharset_t *charset)
{
  unsigned int i = 0;
  volatile unsigned int q;
  wchar_t z;
  UCHAR *str = (**str_ptr == 'N' || **str_ptr == 'n') ? *str_ptr + 1 : *str_ptr;
  UCHAR beg_quote = *str++;	/* And skip past N and it. */
  wchar_t c;
  wchar_t *result = (wchar_t *)box;
  if (!charset)
    {
      client_connection_t *cli = GET_IMMEDIATE_CLIENT_OR_NULL;
      if (cli)
	charset = cli->cli_charset;
    }
  if (!charset)
    charset = default_charset;


  for (/* no init */; '\0' != str[0]; str++)
    {
      switch (str[0])
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
			  c = CHAR_TO_WCHAR(*(str - 1), charset);
			  break;
			}
		    case 'a':
			  {
			    c = (wchar_t)7;
			    break;
			  }		/* BEL audible alert */
		    case 'b':
			    {
			      c = (wchar_t)'\b';
			      break;
			    }		/* BS  backspace */
			    /*	      case 'e': { c = '\033'; break; } *//* ESC escape */
		    case 'f':
			      {
				c = (wchar_t)'\f';
				break;
			      }		/* FF  form feed */
		    case 'n':
				{
				  c = (wchar_t)'\n';
				  break;
				}		/* NL (LF) newline */
		    case 'r':
				  {
				    c = (wchar_t)'\r';
				    break;
				  }		/* CR  carriage return */
		    case 't':
				    {
				      c = (wchar_t)'\t';
				      break;
				    }		/* HT  horizontal tab */
		    case 'v':
				      {
					c = (wchar_t)'\013';
					break;
				      }		/* VT  vertical tab */
		    case 'x':	/* There's a hexadecimal char constant \xhh */
		    case 'X':
					{		/* We should check that only max 2 digits are parsed */
					  q = 4;
					  z = 0;
					  str++;
					  while (*str && isxdigit (*str) && (q--))
					    {
					      z = ((z << 4) + (isdigit (*str) ?
						    (*str - '0') : (toupper (*str) - 'A' + 10)));
					      str++;
					    }
					  c = z;
					  if (!z)
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
					    q = 6;
					    z = 0;
					    while (isoctdigit (*str) && (q--))
					      {
						z = ((z << 3) + (*str++ - '0'));
					      }
					    c = z;
					    str--;	/* str is incremented soon. */
					    if (!z)
					      return -1;
					    break;
					  }		/* octal digits */
			/* \\\n should not appear in the output at all */
		    case '\n':
		    case '\r':
			continue;
		    default:		/* Every other character after backslash produces */
					    {		/* that same character, i.e. \\ = \, \' = ', etc. */
					      c = CHAR_TO_WCHAR(*str, charset);
					      break;
					    }		/* default */

		  }			/* inner switch for character after a backslash */
		if (result)
		  result[i] = c;
		i++;
		break;
	      } /* if for processing backslashes */
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
		  result[i] = CHAR_TO_WCHAR(*str, charset);
		i++;
		break;
	      }
	  }
	}			/* outer switch */
    }				/* for loop */
out:;
  if (result)
    {
      result[i] = L'\0';
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
  return ((i + 1) * sizeof(wchar_t));			/* Return the length. */
}

caddr_t
box_narrow_string_as_wide (unsigned char *str, caddr_t wide, long max_len, wcharset_t *charset, caddr_t * err_ret, int isbox)
{
  long i, len = (long)(isbox ? (box_length ((box_t) str) - 1) : strlen((const char *) str));
  wchar_t *box;
  size_t wide_len;
  if (!charset)
    {
      client_connection_t *cli = GET_IMMEDIATE_CLIENT_OR_NULL;
      if (cli)
	charset = cli->cli_charset;
    }
  if (!charset)
    charset = default_charset;


  if (max_len > 0 && len > max_len)
    len = max_len;
/*  if (len == 0)
    return NULL; - explicit bug */
  wide_len = (len + 1) * sizeof(wchar_t);
  if (wide_len > MAX_READ_STRING)
    {
      if (err_ret)
	*err_ret = srv_make_new_error ("22023", "SR578", "The expected result length of wide string (%ld) is too large");
      return NULL;
    }
  box = (wchar_t *) (wide ? wide : dk_alloc_box (wide_len, DV_WIDE));
  for (i = 0; i < len; i++)
    box[i] = CHAR_TO_WCHAR(str[i], charset);
  box[len] = L'\0';
  return ((caddr_t) box);
}


dk_session_t *
bh_string_output_w (/* this was before 3.0: index_space_t * isp, */ lock_trx_t * lt, blob_handle_t * bh, int omit)
{
  /* take current page at current place and make string of
     n bytes from the place and write to client */
  dk_session_t *string_output = NULL;
  dp_addr_t start = bh->bh_current_page;
  buffer_desc_t *buf;
  long from_char = bh->bh_position;
  long chars_filled = 0, chars_on_page;
  virt_mbstate_t state;
  wchar_t wpage[PAGE_SZ];
#if 0 /* this was */
  it_cursor_t *tmp_itc = itc_create (isp, lt);
#else
  it_cursor_t *tmp_itc = itc_create (NULL, lt);
  itc_from_it (tmp_itc, bh->bh_it);
#endif

  while (start)
    {
      long char_len, byte_len, next;
      unsigned char *mbc;
      if (NULL == string_output)
	string_output = strses_allocate();
      memset (&state, 0, sizeof (state));
      ITC_IN_KNOWN_MAP (tmp_itc, start);
      page_wait_access (tmp_itc, start, NULL, &buf, PA_READ, RWG_WAIT_ANY);
      if (!buf || PF_OF_DELETED == buf)
	{
	  log_info ("Attempt to read deleted blob dp = %d start = %d.",
		    start, bh->bh_page);
	  break;
	}
      byte_len = LONG_REF (buf->bd_buffer + DP_BLOB_LEN);
      mbc = buf->bd_buffer + DP_DATA;
      char_len = (long) virt_mbsnrtowcs (wpage, &mbc, byte_len, PAGE_DATA_SZ, &state);
      if (char_len < 0)
	GPF_T1 ("bad UTF8 data in wide blob page");
      chars_on_page = char_len - from_char;
      if (chars_on_page)
	{
	  /* dbg_printf (("Read blob page %ld, %ld bytes.\n", start,
		bytes_on_page)); */
	  if (!omit)
	      session_buffered_write (string_output, (char *) (wpage + from_char), chars_on_page * sizeof (wchar_t));

	  chars_filled += chars_on_page;
	  from_char += chars_on_page;
	}
      next = LONG_REF (buf->bd_buffer + DP_OVERFLOW);
      page_leave_outside_map (buf);
      if (start == bh->bh_page)
      {
	      dp_addr_t t = LONG_REF (buf->bd_buffer + DP_BLOB_DIR);
	      if (bh->bh_dir_page && t!=bh->bh_dir_page)
		log_info ("Mismatch in directory page ID %d(%x) vs %d(%x).",
		    t,t,bh->bh_dir_page,bh->bh_dir_page);
	      bh->bh_dir_page=t;
      }
      bh->bh_current_page = next;
      bh->bh_position = 0;
      from_char = 0;
      start = next;
    }
  itc_free (tmp_itc);
  return (string_output);
}


dk_set_t
bh_string_list_w (/* this was before 3.0: index_space_t * isp,*/ lock_trx_t * lt, blob_handle_t * bh,
    long get_chars, int omit)
{
  /* take current page at current place and make string of
     n bytes from the place and write to client */
  caddr_t page_string;
  dk_set_t string_list = NULL;
  dp_addr_t start = bh->bh_current_page;
  buffer_desc_t *buf = NULL;
  long from_char = bh->bh_position;
  long chars_filled = 0, chars_on_page;
  virt_mbstate_t state;
  wchar_t wpage[PAGE_SZ];
  it_cursor_t *tmp_itc;
  tmp_itc = itc_create (NULL, lt);
  itc_from_it (tmp_itc, bh->bh_it);

  while (start)
    {
      long char_len, byte_len, next;
      unsigned char *mbc;
      uint32 timestamp;
      int type;

      memset (&state, 0, sizeof (state));
      if (!page_wait_blob_access (tmp_itc, start, &buf, PA_READ, bh, 1))
	break;

      type = SHORT_REF (buf->bd_buffer + DP_FLAGS);
      timestamp = LONG_REF (buf->bd_buffer + DP_BLOB_TS);

      if ((DPF_BLOB != type) &&
	  (DPF_BLOB_DIR != type))
	{
	  page_leave_outside_map (buf);
	  dbg_printf (("wrong blob type\n"));
	  return 0;
	}

      if ((bh->bh_timestamp != BH_ANY) && (timestamp != bh->bh_timestamp))
	{
	  page_leave_outside_map (buf);
	  return BH_DIRTYREAD;
	}

      byte_len = LONG_REF (buf->bd_buffer + DP_BLOB_LEN);
      mbc = buf->bd_buffer + DP_DATA;
      char_len = (long) virt_mbsnrtowcs (wpage, &mbc, byte_len, PAGE_DATA_SZ, &state);
      if (char_len < 0)
	GPF_T1 ("bad UTF8 data in wide blob page");
      chars_on_page = MIN (char_len - from_char, get_chars);
      if (chars_on_page)
	{
	  /* dbg_printf (("Read blob page %ld, %ld bytes.\n", start,
		bytes_on_page)); */
	  if (!omit)
	    {
	      if (DK_MEM_RESERVE)
		{
		  SET_DK_MEM_RESERVE_STATE (lt);
		  itc_bust_this_trx (tmp_itc, &buf, ITC_BUST_THROW);
		}
	      page_string = dk_alloc_box ((chars_on_page + 1) * sizeof(wchar_t), DV_WIDE);
	      memcpy (page_string, wpage + from_char,
		  chars_on_page * sizeof (wchar_t));
	      ((wchar_t *)page_string)[chars_on_page] = 0;
	      dk_set_push (&string_list, page_string);
	    }
	  chars_filled += chars_on_page;
	  get_chars -= chars_on_page;
	  from_char += chars_on_page;
	}
      next = LONG_REF (buf->bd_buffer + DP_OVERFLOW);
      page_leave_outside_map (buf);
      if (0 == get_chars)
	{
	  bh->bh_position = from_char;
	  break;
	}
      bh->bh_current_page = next;
      bh->bh_position = 0;
      from_char = 0;
      start = next;
    }
  itc_free (tmp_itc);
  return (dk_set_nreverse (string_list));
}


static int
print_narrow_string_as_wide (dk_session_t *ses, unsigned char *string, wcharset_t *charset)
{
  unsigned char *pstr = string;
  long utf8_len = 0, char_utf8_len;
  virt_mbstate_t state;
  wchar_t wchar;
  unsigned char mbs[VIRT_MB_CUR_MAX];

  memset (&state, 0, sizeof (virt_mbstate_t));
  while (*pstr)
    {
      wchar = CHAR_TO_WCHAR (*pstr, charset);
      char_utf8_len = (long) virt_wcrtomb (mbs, wchar, &state);
      if (char_utf8_len < 1)
	return char_utf8_len;
      utf8_len += char_utf8_len;
      pstr += 1;
    }
  if (utf8_len < 256)
    {
      session_buffered_write_char (DV_WIDE, ses);
      session_buffered_write_char ((char) utf8_len, ses);
    }
  else
    {
      session_buffered_write_char (DV_LONG_WIDE, ses);
      print_long (utf8_len, ses);
    }

  memset (&state, 0, sizeof (virt_mbstate_t));
  pstr = string;
  while (*pstr)
    {
      wchar = CHAR_TO_WCHAR (*pstr, charset);
      char_utf8_len = (long) virt_wcrtomb (mbs, wchar, &state);
      session_buffered_write (ses, (char *) mbs, char_utf8_len);
      pstr += 1;
    }
  return utf8_len;
}


void
row_print_wide (caddr_t thing, dk_session_t * ses, dbe_column_t * col,
    caddr_t * err_ret, dtp_t dtp, wcharset_t * wcharset)
{
  switch (dtp)
    {
      case DV_STRING:
	  if (0 > print_narrow_string_as_wide (ses, (unsigned char *) thing, wcharset))
	    {
	      caddr_t err = NULL;
	      err = srv_make_new_error ("22005", "IN009",
		 "Bad value for wide string column %s, dtp = %d.",
		 col->col_name, dtp);
	      if (err_ret)
		*err_ret = err;
	      else
		sqlr_resignal (err);
	      return;
	    }
	  break;
      case DV_WIDE:
          wide_serialize (thing, ses);
	  break;
      default:
	    {
	      caddr_t err = NULL;
	      err = srv_make_new_error ("22005", "IN011",
		 "Bad value for wide string column %s, type=%s.", col->col_name, dv_type_title (dtp));
	      if (err_ret)
		*err_ret = err;
	      else
		sqlr_resignal (err);
	    }
	  break;

    }
}

int
compare_wide_to_utf8 (caddr_t _utf8_data, long utf8_len,
    caddr_t _wide_data, long wide_len, collation_t *collation)
{
  unsigned char *utf8_data = (unsigned char *) _utf8_data;
  wchar_t *wide_data = (wchar_t *) _wide_data;
  long winx, ninx;

  wchar_t wtmp;
  virt_mbstate_t state;
  int rc;

  memset (&state, 0, sizeof (virt_mbstate_t));
  wide_len = wide_len / sizeof (wchar_t);

  ninx = winx = 0;
  if (collation)
    while(1)
      {
        wchar_t xlat_wtmp, xlat2;
	if (ninx == utf8_len)
	  {
	    if (winx == wide_len)
	      return DVC_MATCH;
	    else
	      return DVC_LESS;
	  }
	if (winx == wide_len)
	  return DVC_GREATER;

	rc = (int) virt_mbrtowc (&wtmp, utf8_data + ninx, utf8_len - ninx, &state);
	if (rc <= 0)
	  GPF_T1 ("inconsistent wide char data");
        xlat_wtmp = COLLATION_XLAT_WIDE (collation, wtmp);
        xlat2 = COLLATION_XLAT_WIDE (collation, wide_data[winx]);
	if (xlat_wtmp < xlat2)
	  return DVC_LESS;
	if (xlat_wtmp > xlat2)
	  return DVC_GREATER;
	winx++;
	ninx += rc;
      }
  else
    while(1)
      {
	if (ninx == utf8_len)
	  {
	    if (winx == wide_len)
	      return DVC_MATCH;
	    else
	      return DVC_LESS;
	  }
	if (winx == wide_len)
	  return DVC_GREATER;

	rc = (int) virt_mbrtowc (&wtmp, utf8_data + ninx, utf8_len - ninx, &state);
	if (rc <= 0)
	  GPF_T1 ("inconsistent wide char data");
	if (wtmp < wide_data[winx])
	  return DVC_LESS;
	if (wtmp > wide_data[winx])
	  return DVC_GREATER;
	winx++;
	ninx += rc;
      }
}


int
compare_utf8_with_collation (caddr_t dv1, long n1,
    caddr_t dv2, long n2, collation_t *collation)
{
  long inx1, inx2;

  wchar_t wtmp1, wtmp2, xlat_wtmp1, xlat_wtmp2;
  virt_mbstate_t state1, state2;
  int rc1, rc2;

  memset (&state1, 0, sizeof (virt_mbstate_t));
  memset (&state2, 0, sizeof (virt_mbstate_t));

  inx1 = inx2 = 0;
  if (collation)
    while(1)
      {
	if (inx1 == n1)
	  {
	    while (inx2 < n2)
	      { /* skip all ignorable rest chars */
		rc2 = (int) virt_mbrtowc (&wtmp2, (unsigned char *) (dv2 + inx2), n2 - inx2, &state2);
		if (rc2 <= 0)
		  GPF_T1 ("inconsistent wide char data");
		if (!COLLATION_XLAT_WIDE (collation, wtmp2))
		  {
		    inx2+=rc2;
		    continue;
		  }
		else
		  break;
	      }

	    if (inx2 == n2)
	      return DVC_MATCH;
	    else
	      return DVC_LESS;
	  }
	if (inx2 == n2)
	  return DVC_GREATER;

	rc1 = (int) virt_mbrtowc (&wtmp1, (unsigned char *) (dv1 + inx1), n1 - inx1, &state1);
	if (rc1 <= 0)
	  GPF_T1 ("inconsistent wide char data");
	rc2 = (int) virt_mbrtowc (&wtmp2, (unsigned char *) (dv2 + inx2), n2 - inx2, &state2);
	if (rc2 <= 0)
	  GPF_T1 ("inconsistent wide char data");
        xlat_wtmp1 = COLLATION_XLAT_WIDE (collation, wtmp1);
	if (!xlat_wtmp1)
	  {
	    inx1+=rc1;
	    continue;
	  }
        xlat_wtmp2 = COLLATION_XLAT_WIDE (collation, wtmp2);
	if (!xlat_wtmp2)
	  {
	    inx2+=rc2;
	    continue;
	  }
	if (xlat_wtmp1 < xlat_wtmp2)
	  return DVC_LESS;
	if (xlat_wtmp1 > xlat_wtmp2)
	  return DVC_GREATER;
	inx1 += rc1;
	inx2 += rc2;
      }
  else
    while(1)
      {
	if (inx1 == n1)
	  {
	    if (inx2 == n2)
	      return DVC_MATCH;
	    else
	      return DVC_LESS;
	  }
	if (inx2 == n2)
	  return DVC_GREATER;

	rc1 = (int) virt_mbrtowc (&wtmp1, (unsigned char *) (dv1 + inx1), n1 - inx1, &state1);
	if (rc1 <= 0)
	  GPF_T1 ("inconsistent wide char data");
	rc2 = (int) virt_mbrtowc (&wtmp2, (unsigned char *) (dv2 + inx2), n2 - inx2, &state2);
	if (rc2 <= 0)
	  GPF_T1 ("inconsistent wide char data");
	if (wtmp1 < wtmp2)
	  return DVC_LESS;
	if (wtmp1 > wtmp2)
	  return DVC_GREATER;
	inx1 += rc1;
	inx2 += rc2;
      }
}

caddr_t
box_wide_char_string (caddr_t data, size_t len)
{
  caddr_t res = dk_alloc_box (len + sizeof (wchar_t), DV_WIDE);
  memcpy (res, data, len);
  ((wchar_t *)res)[len / sizeof (wchar_t)] = L'\x0';
  return res;
}


caddr_t
box_wide_string_as_narrow (caddr_t _str, caddr_t narrow, long max_len, wcharset_t *charset)
{
  wchar_t *str = (wchar_t *) _str;
  long len = box_length (str) / sizeof (wchar_t) - 1, i;
  unsigned char *box;
  if (!charset)
    {
      client_connection_t *cli = GET_IMMEDIATE_CLIENT_OR_NULL;
      if (cli)
	charset = cli->cli_charset;
    }
  if (!charset)
    charset = default_charset;


  if (max_len > 0 && len > max_len)
    len = max_len;
/*  if (len == 0)
    {
      if (narrow) narrow[0] = 0;
      return box_dv_short_string("");
    } in case if not null narrow - leak */
  box = (unsigned char *) (narrow ? narrow : dk_alloc_box (len + 1, DV_STRING));
  for (i = 0; i < len && str[i]; i++)
    box[i] = WCHAR_TO_CHAR(str[i], charset);
  box[len] = 0;
  return ((caddr_t) box);
}


wcharset_t *
sch_name_to_charset_1 (const char *o_default, const char *q, const char *o, const char *n)
{
  wcharset_t *cs_found = NULL;
  int n_found = 0;
  char **cs_name;
  char cq[MAX_NAME_LEN];
  char co[MAX_NAME_LEN];
  char cn[MAX_NAME_LEN];

  wcharset_t **pcs;
  id_hash_iterator_t it;

  id_hash_iterator (&it, global_wide_charsets);
  while (hit_next (&it, (caddr_t *) & cs_name, (caddr_t *) & pcs))
    {
      /* if this changed to strncmp CaSE MODE 2 */
      wcharset_t *cs = *pcs;
      sch_split_name(NULL, cs->chrs_name, cq, co, cn);

      if (0 != CASEMODESTRCMP (cq, q))
	continue;
      if (0 == CASEMODESTRCMP (cn, n))
	{
	  if (o[0])
	    {
	      if (0 == CASEMODESTRCMP (co, o))
		return cs;
	      else
		continue;
	    }
	  else
	    {
	      if (0 == CASEMODESTRCMP (co, o_default))
		return cs;
	      cs_found = cs;
	      n_found++;
	    }
	}
    }
  if (cs_found)
    {
      if (n_found > 1)
	return ((wcharset_t *) -1L);
      return cs_found;
    }

  return NULL;
}

wcharset_t *
sch_name_to_charset (const char *name)
{
  if (!name || !name[0])
    return default_charset;
  else
    {
      wcharset_t **charset = (wcharset_t **) id_hash_get (global_wide_charsets, (caddr_t) &name);
      if (charset)
	return charset[0];
      else
	return NULL;
    }
}


caddr_t
complete_charset_name (caddr_t _qi, char *cs_name)
{
  caddr_t result;
  wcharset_t *cs = sch_name_to_charset (cs_name);
  query_instance_t *qi = (query_instance_t *)_qi;
  if (cs)
    result = box_dv_short_string (cs->chrs_name);
  else
    {
      char q[MAX_NAME_LEN];
      char o[MAX_NAME_LEN];
      char n[MAX_NAME_LEN];
      char complete[MAX_QUAL_NAME_LEN];
      q[0] = 0;
      o[0] = 0;
      n[0] = 0;
      sch_split_name (qi->qi_client->cli_qualifier, cs_name, q, o, n);
      if (0 == o[0])
	strcpy_ck (o, cli_owner (qi->qi_client));
      snprintf (complete, sizeof (complete), "%s.%s.%s", q, o, n);
      result = box_dv_short_string (complete);
    }
  if (CM_UPPER == case_mode && result)
    sqlp_upcase (result);
  return result;
}


int
compare_wide_to_narrow (wchar_t *wbox1, long n1, unsigned char *box2, long n2)
{
  wchar_t temp;
  long inx = 0;
  while (1)
    {
      if (inx == n1)	/* box1 in end? */
	{
	  if (inx == n2)
	    return DVC_MATCH;  /* box2 of same length */
	  else
	    return DVC_LESS;   /* otherwise box1 is shorter than box2 */
	}
      if (inx == n2)
	return DVC_GREATER;	/* box2 in end (but not box1) */
      temp = CHAR_TO_WCHAR (box2[inx], NULL);
      if (wbox1[inx] < temp)
	return DVC_LESS;
      if (wbox1[inx] > temp)
	return DVC_GREATER;
      inx++;
    }
  /*NOTREACHED*/
  return DVC_LESS;
}


caddr_t
box_utf8_string_as_narrow (ccaddr_t _str, caddr_t narrow, long max_len, wcharset_t *charset)
{
  virt_mbstate_t state;
  long len, inx;
  const unsigned char *str = (const unsigned char *) _str, *src = (const unsigned char *) _str;
  caddr_t box;
  if (!charset)
    {
      client_connection_t *cli = GET_IMMEDIATE_CLIENT_OR_NULL;
      if (cli)
	charset = cli->cli_charset;
    }
  if (!charset)
    charset = default_charset;

  memset (&state, 0, sizeof (virt_mbstate_t));
  len = (long) virt_mbsnrtowcs (NULL, (unsigned char **) &src, box_length (str), 0, &state);
  if (max_len > 0 && len > max_len)
    len = max_len;
  if (len < 0) /* there was <= 0 - bug */
    return NULL;
  box = narrow ? narrow : dk_alloc_box (len + 1, DV_LONG_STRING);
  for (inx = 0, src = str, memset (&state, 0, sizeof (virt_mbstate_t)); inx < len; inx++)
    {
      wchar_t wc;
      long char_len = (long) virt_mbrtowc (&wc, src, (box_length (str)) - (long)((src - str)), &state);
      if (char_len <= 0)
	{
	  box[inx] = '?';
	  src++;
	}
      else
	{
	  box[inx] = WCHAR_TO_CHAR (wc, charset);
	  src += char_len;
	}
    }
  box[len] = 0;
  return box;
}

/* this function take a string not a box as _str argument */
caddr_t
t_box_utf8_string_as_narrow (ccaddr_t _str, caddr_t narrow, long max_len, wcharset_t *charset)
{
  virt_mbstate_t state;
  long len, inx;
  const unsigned char *str = (const unsigned char *) _str, *src = (const unsigned char *) _str;
  caddr_t box;
  if (!charset)
    {
      client_connection_t *cli = GET_IMMEDIATE_CLIENT_OR_NULL;
      if (cli)
	charset = cli->cli_charset;
    }
  if (!charset)
    charset = default_charset;

  memset (&state, 0, sizeof (virt_mbstate_t));
  len = (long) virt_mbsnrtowcs (NULL, (unsigned char **) &src, strlen ((char *) str), 0, &state);
  if (max_len > 0 && len > max_len)
    len = max_len;
  if (len < 0) /* there was <= 0 - bug */
    return NULL;
  box = narrow ? narrow : t_alloc_box (len + 1, DV_LONG_STRING);
  for (inx = 0, src = str, memset (&state, 0, sizeof (virt_mbstate_t)); inx < len; inx++)
    {
      wchar_t wc;
      long char_len = (long) virt_mbrtowc (&wc, src, (strlen ((char *) str)) - (long)((src - str)), &state);
      if (char_len <= 0)
	{
	  box[inx] = '?';
	  src++;
	}
      else
	{
	  box[inx] = WCHAR_TO_CHAR (wc, charset);
	  src += char_len;
	}
    }
  box[len] = 0;
  return box;
}

caddr_t
DBG_NAME(box_narrow_string_as_utf8) (DBG_PARAMS caddr_t _str, caddr_t narrow, long max_len, wcharset_t *charset, caddr_t * err_ret, int isbox)
{
  caddr_t box = NULL, tmp;
  if (!charset)
    {
      client_connection_t *cli = GET_IMMEDIATE_CLIENT_OR_NULL;
      if (cli)
	charset = cli->cli_charset;
    }
  if (!charset)
    charset = default_charset;

  tmp = box_narrow_string_as_wide ((unsigned char *) narrow, NULL, 0, charset, err_ret, isbox);
  if (tmp)
    {
      box = DBG_NAME (box_wide_as_utf8_char) (DBG_ARGS tmp, box_length (tmp) / sizeof (wchar_t) - 1, DV_STRING);
      dk_free_box (tmp);
    }
  return box;
}


caddr_t
t_box_utf8_as_wide_char (ccaddr_t _utf8, caddr_t _wide_dest, size_t utf8_len, size_t max_wide_len)
{
  unsigned char *utf8 = (unsigned char *) _utf8;
  unsigned char *utf8work;
  size_t wide_len;
  virt_mbstate_t state;
  caddr_t dest;

  utf8work = utf8;
  memset (&state, 0, sizeof (virt_mbstate_t));
  wide_len = virt_mbsnrtowcs (NULL, &utf8work, utf8_len, 0, &state);
  if (((long) wide_len) < 0)
    return _wide_dest ? ((caddr_t) wide_len) : NULL;
  if (max_wide_len && max_wide_len < wide_len)
    wide_len = max_wide_len;
  if (_wide_dest)
    dest = _wide_dest;
  else
    dest = t_alloc_box ((int) (wide_len  + 1) * sizeof (wchar_t), DV_WIDE);

  utf8work = utf8;
  memset (&state, 0, sizeof (virt_mbstate_t));
  if (wide_len != virt_mbsnrtowcs ((wchar_t *) dest, &utf8work, utf8_len, wide_len, &state))
    GPF_T1("non consistent multi-byte to wide char translation of a buffer");

  ((wchar_t *)dest)[wide_len] = L'\0';
  if (_wide_dest)
    return ((caddr_t)wide_len);
  else
    return dest;
}

wchar_t * reverse_wide_string (wchar_t * str)
{
  int inx;
  size_t len = box_length (str) / sizeof (wchar_t) - 1;
  for (inx=0;inx<len/2;inx++)
    {
      wchar_t tmp = str[inx];
      str[inx]=str[len - inx - 1];
      str[len - inx -1] = tmp;
    }
  return str;
}

/* slow solution, should be rewritten later */
caddr_t
strstr_utf8_with_collation (caddr_t dv1, long n1,
    caddr_t dv2, long n2, caddr_t *next, collation_t *collation)
{
  int n1inx = 0, n2inx = 0, n1inx_beg = 0;
  int utf8_1len = box_length (dv1) - 1;
  int utf8_2len = box_length (dv2) - 1;
  virt_mbstate_t state1, state2;
  wchar_t wtmp1, wtmp2, xlat_wtmp1, xlat_wtmp2;
  memset (&state1, 0, sizeof (virt_mbstate_t));
  memset (&state2, 0, sizeof (virt_mbstate_t));

  if (collation)
    {
      while (1)
	{
	  int rc1, rc2;
	  if (!n1inx_beg)
	    n1inx_beg = n1inx;
	again:
	  if (n1inx == utf8_1len && n2inx != utf8_2len)
	    return 0;
	  if (n2inx == utf8_2len)
	    {
	      if (next)
		next[0] = dv1+n1inx;

	      while(1)
		{
		  /* ignore all remaining ignorable signs */
		  rc1 = (int) virt_mbrtowc (&wtmp1, (unsigned char *) dv1+n1inx_beg,
		      utf8_1len-n1inx_beg, &state1);
		  if (rc1 < 0)
		    GPF_T1 ("inconsistent wide char data");
		  if (!COLLATION_XLAT_WIDE (collation, wtmp1))
		    { /* ignore symbol, unicode normalization algorithm */
		      n1inx_beg+=rc1;
		    }
		  else
		    return dv1+n1inx_beg;
		}
	    }
	  rc2 = (int) virt_mbrtowc (&wtmp2, (unsigned char *) dv2+n2inx,
	      utf8_2len-n2inx, &state2);
	  if (rc2 < 0)
	    GPF_T1 ("inconsistent wide char data");
          xlat_wtmp2 = COLLATION_XLAT_WIDE (collation, wtmp2);
	  if (!xlat_wtmp2)
	    { /* ignore symbol, unicode normalization algorithm */
	      n2inx+=rc2;
	      goto again;
	    }
	  rc1 = (int) virt_mbrtowc (&wtmp1, (unsigned char *) dv1+n1inx,
	      utf8_1len-n1inx, &state1);
	  if (rc1 < 0)
	    GPF_T1 ("inconsistent wide char data");
          xlat_wtmp1 = COLLATION_XLAT_WIDE (collation, wtmp1);
	  if (!xlat_wtmp1)
	    { /* ignore symbol, unicode normalization algorithm */
	      n1inx+=rc1;
	      goto again;
	    }

	  if (xlat_wtmp1 != xlat_wtmp2)
	    {
	      n1inx+=rc1;
	      n2inx=0;
	      n1inx_beg=n1inx;
	      memset (&state2, 0, sizeof (virt_mbstate_t));
	      continue;
	    }
	  n1inx+=rc1;
	  n2inx+=rc2;
	}
    }
  else
    {
      while (1)
	{
	  int rc1, rc2;
	  if (!n1inx_beg)
	    n1inx_beg = n1inx;
	  if (n1inx == utf8_1len && n2inx != utf8_2len)
	    return 0;
	  if (n2inx == utf8_2len)
	    {
	      if (next)
		next[0] = dv1+n1inx;
	      return dv1+n1inx_beg;
	    }
	  rc1 = (int) virt_mbrtowc (&wtmp1, (unsigned char *) dv1+n1inx,
	      utf8_1len-n1inx, &state1);
	  rc2 = (int) virt_mbrtowc (&wtmp2, (unsigned char *) dv2+n2inx,
	      utf8_2len-n2inx, &state2);
	  if (rc1 < 0  || rc2 < 0)
	    GPF_T1 ("inconsistent wide char data");
	  if (wtmp1 != wtmp2)
	    {
	      n1inx+=rc1;
	      n2inx=0;
	      n1inx_beg=n1inx;
	      memset (&state2, 0, sizeof (virt_mbstate_t));
	      continue;
	    }
	  n1inx+=rc1;
	  n2inx+=rc2;
	}
    }

  return 0;
}
