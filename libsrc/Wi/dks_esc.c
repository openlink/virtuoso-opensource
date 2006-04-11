/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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
#include "Dk.h"
#include "multibyte.h"
#include "http.h"

unsigned char dks_esc_char_props[0x100] = {
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'B','B','B','B','B','B','B','B','B','D','E','B','B','F','B','B',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'B','B','B','B','B','B','B','B','B','B','B','B','B','B','B','B',
/*     !   "   #   $   %   &   '   (   )   *   +   ,   -   .   /  */
  'J','C','G','M','P','M','H','I','M','M','O','P','P','@','@','N',
/* 0   1   2   3   4   5   6   7   8   9   :   ;   <   =   >   ?  */
  '@','@','@','@','@','@','@','@','@','@','P','P','K','P','L','P',
/* @   A   B   C   D   E   F   G   H   I   J   K   L   M   N   O  */
  '@','@','@','@','@','@','@','@','@','@','@','@','@','@','@','@',
/* P   Q   R   S   T   U   V   W   X   Y   Z   [   \   ]   ^   _  */
  '@','@','@','@','@','@','@','@','@','@','@','@','@','@','@','@',
/* `   a   b   c   d   e   f   g   h   i   j   k   l   m   n   o  */
  '@','@','@','@','@','@','@','@','@','@','@','@','@','@','@','@',
/* p   q   r   s   t   u   v   w   x   y   z   {   |   }   ~      */
  '@','@','@','@','@','@','@','@','@','@','@','@','@','@','@','@',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A' };


#define ASIS	0
#define LATTICE	'#'
#define PERCENT	'%'
#define AMPATTR	'A'
#define AMP	'&'
#define GTATTR	'G'
#define GT	'>'
#define	LTATTR	'L'
#define	LT	'<'
#define QUOT	'"'
#define PLUS	'+'
#define BAD	'?'
#define SOAPCR	's'
#define COMMENT	'c'
#define CDATA	'd'


typedef unsigned char dks_charclass_props_t[COUNTOF__DKS_ESC];

dks_charclass_props_t dks_charclasses['P'+1-'@'] = {
/*		|NONE	|PTEXT	|SQATTR	|DQATTR	|COMMENT|CDATA	|URI	|DAV	|URI_RES	|URI_NRES*/
/* letters   */	{0	,0	,0	,0	,0	,0	,0	,0	,0		,0},
/* A 8-bit   */	{0	,0	,0	,0	,0	,0	,0	,PERCENT,PERCENT	,PERCENT},
/* B < 0x20  */	{BAD	,LATTICE,LATTICE,LATTICE,0	,0	,PERCENT,0	,PERCENT	,PERCENT},
/* C !       */	{0	,0	,0	,0	,0	,0	,PERCENT,0	,PERCENT	,PERCENT},
/* D 0x09    */	{0	,0	,LATTICE,LATTICE,0	,0	,PERCENT,0	,PERCENT	,PERCENT},
/* E 0x0A    */	{0	,0	,LATTICE,LATTICE,0	,0	,PERCENT,0	,PERCENT	,PERCENT},
/* F 0x0D    */	{0	,SOAPCR	,LATTICE,LATTICE,0	,0	,PERCENT,0	,PERCENT	,PERCENT},
/* G "       */	{0	,QUOT	,0	,QUOT	,0	,0	,PERCENT,PERCENT,PERCENT	,PERCENT},
/* H &       */	{0	,AMP	,AMPATTR,AMPATTR,0	,0	,PERCENT,PERCENT,PERCENT	,0},
/* I '       */	{0	,LATTICE,LATTICE,0	,0	,0	,PERCENT,0	,0		,0},
/* J 0x20    */	{0	,0	,0	,0	,0	,0	,PLUS	,PERCENT,PERCENT	,PERCENT},
/* K <       */	{0	,LT	,LTATTR	,LTATTR	,0	,0	,PERCENT,PERCENT,PERCENT	,PERCENT},
/* L >       */	{0	,GT	,GTATTR	,GTATTR	,COMMENT,CDATA	,PERCENT,PERCENT,PERCENT	,PERCENT},
/* M %	     */	{0	,0	,0	,0	,0	,0	,PERCENT,0	,0		,0},
/* N /	     */	{0	,0	,0	,0	,0	,0	,0	,0	,PERCENT	,0},
/* O *	     */	{0	,0	,0	,0	,0	,0	,PERCENT,0	,0		,0},
/* P punct-! */	{0	,0	,0	,0	,0	,0	,PERCENT,0	,PERCENT	,0} };

int dks_use_qmarks['L'+1-'@'] =
/*		|NONE	|PTEXT	|SQATTR	|DQATTR	|COMMENT|CDATA	|URI	|DAV	*/
		{1	,1	,1	,1	,1	,0	,0	,0	};

#define CHARSET_WIDE (CHARSET_UTF8+1)

#define OUT_TO_BUF(strg,len) \
  { \
    int _ctr, _len = (len); \
    for (_ctr = 0; _ctr < _len; _ctr++) \
      out_buf[out_buf_idx++] = (strg)[_ctr]; \
  }

#define LOOK_TAIL(tail) \
 (((NULL == src_charset) || (CHARSET_UTF8 == src_charset)) ? (tail)[0] : \
  ((CHARSET_WIDE == src_charset) ? ((wchar_t *)((tail)))[0] : \
   src_charset->chrs_table[(tail)[0]] ) )

#define FETCH_TAIL(tail) \
 (tail) += ((CHARSET_WIDE == src_charset) ? sizeof(wchar_t) : 1)

void
dks_esc_write (dk_session_t * ses, char * src_str, size_t src_len,
  wcharset_t * tgt_charset, wcharset_t * src_charset, int dks_esc_mode)
{
  unsigned char *src_tail = (unsigned char *)src_str;
  unsigned char *str_end = (unsigned char *)(src_str+src_len);
  wchar_t wc;
  unsigned char wc_class, action;
  int dks_esc_mode_base = dks_esc_mode & 0xFF;
  wchar_t out_buf[0x80];
  int out_buf_idx = 2;

  if (0 == src_len)
    return;
#ifdef DEBUG    
  if (src_len > MAX_BOX_LENGTH)
    GPF_T1("Abnormally long string length specified for dks_esc_write");
#endif
#ifdef DEBUG
  if ((CHARSET_WIDE == src_charset) && ((str_end - src_tail) % sizeof (wchar_t)))
    GPF_T;
#endif

  out_buf[0] = out_buf[1] = '0';

again:
  if (NULL == src_charset)
    wc = (src_tail++)[0];
  else if (CHARSET_UTF8 == src_charset)
    {
      virt_mbstate_t state;
      int charlen;
      memset (&state, 0, sizeof (virt_mbstate_t));
      charlen = (int) virt_mbrtowc (&wc, src_tail, str_end - src_tail, &state);
      if (charlen <= 0)
	{
	  wc = L'?';
	  src_tail++;
	}
      else
	src_tail += charlen;
    }
  else if (CHARSET_WIDE == src_charset)
    {
      wc = ((wchar_t *)(src_tail))[0];
      src_tail += sizeof (wchar_t);
    }
  else
    {
      wc = src_charset->chrs_table[src_tail[0]];
      src_tail++;
    }

  if (wc & ~0xff)
    goto out_byte_asis;
  wc_class = dks_esc_char_props[wc] - '@';
  action = dks_charclasses[wc_class][dks_esc_mode_base];
  switch (action)
    {
      case ASIS:	goto out_byte_asis;
      case LATTICE:	goto out_lattice;
      case PERCENT:	goto out_percent;
      case AMPATTR:	if (dks_esc_mode & DKS_ESC_COMPAT_HTML) goto out_ampattr; /* no break */
      case AMP:		goto out_amp;
      case GTATTR:	if (dks_esc_mode & DKS_ESC_COMPAT_HTML) goto out_byte_asis; /* no break */
      case GT:		OUT_TO_BUF("&gt;", 4); goto char_done;
      case LTATTR:	if (dks_esc_mode & DKS_ESC_COMPAT_HTML) goto out_byte_asis; /* no break */
      case LT:		OUT_TO_BUF("&lt;", 4); goto char_done;
      case QUOT:	OUT_TO_BUF("&quot;", 6); goto char_done;
      case PLUS:	out_buf[out_buf_idx++] = '+'; goto char_done;
      case BAD:		out_buf[out_buf_idx++] = '?'; goto char_done;
      case SOAPCR:	if (dks_esc_mode & DKS_ESC_COMPAT_SOAP) goto out_lattice; goto out_byte_asis;
      case COMMENT:	goto out_comment;
      case CDATA:	goto out_cdata;
      default: GPF_T;
    }

out_byte_asis:
  out_buf[out_buf_idx++] = wc;
  goto char_done;

out_lattice:
  {
    char tmp[20];
    snprintf (tmp, sizeof (tmp), "&#%lu;", (unsigned long)wc);
    OUT_TO_BUF (tmp, (int) strlen (tmp));
    goto char_done;
  }

out_percent:
  {
    out_buf[out_buf_idx++] = '%';
    out_buf[out_buf_idx++] = "0123456789ABCDEF"[(wc&0xF0)>>4];
    out_buf[out_buf_idx++] = "0123456789ABCDEF"[wc&0x0F];
    goto char_done;
  }

out_amp:
  {
    wchar_t lookahead;
    if (src_tail >= str_end)
      lookahead = 0;
    else
      lookahead = LOOK_TAIL(src_tail);
    if ('{' == lookahead)
      goto out_byte_asis;
    OUT_TO_BUF("&amp;", 5);
    goto char_done;
  }

out_ampattr:
  {
    unsigned char *src_tail_lookahead = src_tail;
    wchar_t lookahead;
    if (src_tail_lookahead >= str_end)
      lookahead = '\0';
    else
      {
	lookahead = LOOK_TAIL(src_tail_lookahead);
	FETCH_TAIL(src_tail_lookahead);
      }
    if ('{' == lookahead)
      goto out_byte_asis;
    while (src_tail_lookahead < str_end)
      {
	if (!isalnum (lookahead))
	  break;
	lookahead = LOOK_TAIL(src_tail_lookahead);
	FETCH_TAIL(src_tail_lookahead);
	if ('=' == lookahead)
	  goto out_byte_asis;
      }
    OUT_TO_BUF("&amp;", 5);
    goto char_done;
  }

out_comment:
  if (('-' != out_buf[out_buf_idx-2]) || ('-' != out_buf[out_buf_idx-1]))
    goto out_byte_asis;
  goto out_lattice;

out_cdata:
  if ((']' != out_buf[out_buf_idx-2]) || (']' != out_buf[out_buf_idx-1]))
    goto out_byte_asis;
  OUT_TO_BUF("]]><![CDATA[>", 13);
  goto char_done;

char_done:

  if (src_tail >= str_end)
    {
      if (2 == out_buf_idx)
        return;
      goto flush_out_buf;
    }
  if (out_buf_idx < (sizeof(out_buf) / sizeof(out_buf[0])) - 15)
    goto again;

flush_out_buf:
  {
    int flush_idx;
    for (flush_idx = 2; flush_idx < out_buf_idx; flush_idx++)
      {
	wc = out_buf[flush_idx];
	if (CHARSET_UTF8 != tgt_charset)
	  {
	    if (!wc)
	      {
		session_buffered_write_char (wc, ses);
		continue;
	      }
	    if (NULL != tgt_charset)
	      {
		unsigned char wc_encod = (unsigned char) ((ptrlong) gethash ((void *)((ptrlong)wc), tgt_charset->chrs_ht));
		if (!wc_encod)
		  goto flush_bad_char;
		session_buffered_write_char (wc_encod, ses);
		continue;
	      }
	    else
	      {
		if (wc & ~0xff)
		  goto flush_bad_char;
	      }
	    session_buffered_write_char (wc, ses);
	    continue;
flush_bad_char:
	    if (dks_use_qmarks[dks_esc_mode_base])
	      {
		char tmp[20];
		snprintf (tmp, sizeof (tmp), "&#%lu;", (unsigned long)wc);
		session_buffered_write (ses, tmp, strlen(tmp));
		continue;
	      }
	    else
	      session_buffered_write_char ('?', ses);
	    continue;
	  }
	if (wc & ~0x7F)
	  {
	    char temp[VIRT_MB_CUR_MAX];
	    virt_mbstate_t st;
	    size_t temp_len;
	    memset (&st, 0, sizeof (st));
	    temp_len = virt_wcrtomb ((unsigned char *) temp, wc, &st);
	    if (((long)temp_len) > 0)
	      session_buffered_write (ses, temp, temp_len);
	    else
	      session_buffered_write_char ('?', ses);
	    continue;
	  }
        session_buffered_write_char (wc, ses);
      }
    if (src_tail >= str_end)
      return;
  out_buf[0] = out_buf[out_buf_idx-2];
  out_buf[1] = out_buf[out_buf_idx-1];
  out_buf_idx = 2;
  goto again;
  }
}

void
dks_wide_esc_write (dk_session_t * ses, wchar_t * wstr, int len,
  wcharset_t * tgt_charset, int dks_esc_mode)
{
  dks_esc_write (ses, (char *)(wstr), len * sizeof(wchar_t), tgt_charset, CHARSET_WIDE, dks_esc_mode);
}
