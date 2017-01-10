/*
 *  $Id$
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
 */

#include "Dk.h"
#include "multibyte.h"
#include "http.h"
#include "langfunc.h"


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
  '@','@','@','@','@','@','@','@','@','@','@','O','Q','O','O','@',
/* `   a   b   c   d   e   f   g   h   i   j   k   l   m   n   o  */
  '@','@','@','@','@','@','@','@','@','@','@','@','@','@','@','@',
/* p   q   r   s   t   u   v   w   x   y   z   {   |   }   ~      */
  '@','@','@','@','@','@','@','@','@','@','@','O','R','O','@','R',
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
#define PCT	'%'
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
#define CDATA2	'D'
#define BSLASHC	'\\'
#define BSLASHU	'u'
#define DOCWRI  'W'
#define REPEAT  'R'


dks_charclass_props_t dks_charclasses['R'+1-'>'] = {
/*		|0	|1	|2	|3	|4	|5	|6	|7	|8	|9	|10	|11	|12	|13	|13	*/
/*		|NONE	|PTEXT	|SQATTR	|DQATTR	|COMMENT|CDATA	|URI	|DAV	|URI_R	|URI_NR	|TTL_SQ	|TTL_DQ	|TTLIRI	|JS_SQ	|JS_DQ	*/
/* > wide    */ {0	,0	,0	,0	,0	,0	,PCT	,PCT	,PCT	,PCT	,BSLASHU,BSLASHU,BSLASHU,BSLASHU,BSLASHU},
/* ? enc.miss*/ {BAD	,LATTICE,LATTICE,LATTICE,LATTICE,CDATA2	,PCT	,PCT	,PCT	,PCT	,BSLASHU,BSLASHU,BSLASHU,BSLASHU,BSLASHU},
/* @ letters */	{0	,0	,0	,0	,0	,0	,0	,0	,0	,0	,0	,0	,0	,0	,0	},
/* A 8-bit   */	{0	,0	,0	,0	,0	,0	,0	,PCT	,PCT	,PCT	,BSLASHU,BSLASHU,BSLASHU,BSLASHU,BSLASHU},
/* B < 0x20  */	{BAD	,LATTICE,LATTICE,LATTICE,0	,0	,PCT	,0	,PCT	,PCT	,BSLASHU,BSLASHU,BSLASHU,BSLASHU,BSLASHU},
/* C !       */	{0	,0	,0	,0	,0	,0	,PCT	,0	,PCT	,PCT	,0	,0	,0	,0	,0	},
/* D 0x09    */	{0	,0	,LATTICE,LATTICE,0	,0	,PCT	,0	,PCT	,PCT	,BSLASHC,BSLASHC,BSLASHU,BSLASHC,BSLASHC},
/* E 0x0A    */	{0	,0	,LATTICE,LATTICE,0	,0	,PCT	,0	,PCT	,PCT	,BSLASHC,BSLASHC,BSLASHU,BSLASHC,BSLASHC},
/* F 0x0D    */	{0	,SOAPCR	,LATTICE,LATTICE,0	,0	,PCT	,0	,PCT	,PCT	,BSLASHC,BSLASHC,BSLASHU,BSLASHC,BSLASHC},
/* G "       */	{0	,QUOT	,0	,QUOT	,0	,0	,PCT	,PCT	,PCT	,PCT	,0	,BSLASHC,BSLASHU,0	,BSLASHC},
/* H &       */	{0	,AMP	,AMPATTR,AMPATTR,0	,0	,PCT	,PCT	,PCT	,0	,0	,0	,0	,0	,0	},
/* I '       */	{0	,LATTICE,LATTICE,0	,0	,0	,PCT	,0	,0	,0	,BSLASHC,0	,BSLASHU,BSLASHC,0	},
/* J 0x20    */	{0	,0	,0	,0	,0	,0	,PCT	,PCT	,PCT	,PCT	,0	,0	,BSLASHU,0	,0	},
/* K <       */	{0	,LT	,LTATTR	,LTATTR	,0	,0	,PCT	,PCT	,PCT	,PCT	,0	,0	,BSLASHU,0	,0	},
/* L >       */	{0	,GT	,GTATTR	,GTATTR	,COMMENT,CDATA	,PCT	,PCT	,PCT	,PCT	,0	,0	,BSLASHU,0	,0	},
/* M %	     */	{0	,0	,0	,0	,0	,0	,PCT	,0	,0	,0	,0	,0	,0	,0	,0	},
/* N /	     */	{0	,0	,0	,0	,0	,0	,PCT	,0	,PCT	,0	,0	,0	,0	,0	,0	},
/* O *	     */	{0	,0	,0	,0	,0	,0	,PCT	,0	,0	,0	,0	,0	,0	,0	,0	},
/* P punct-! */	{0	,0	,0	,0	,0	,0	,PCT	,0	,PCT	,0	,0	,0	,0	,0	,0	},
/* Q \	     */	{0	,0	,0	,0	,0	,0	,PCT	,0	,0	,0	,BSLASHC,BSLASHC,BSLASHU,BSLASHC,BSLASHC},
/* R |, 0x7f */	{0	,0	,0	,0	,0	,0	,PCT	,PCT	,PCT	,PCT	,0	,0	,0	,0	,0	} };

unsigned char dks_esc_bslashc[0x80] = {
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
   0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,'t','n',0  ,0  ,'r',0  ,0 ,
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
   0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0 ,
/*     !   "   #   $   %   &   '   (   )   *   +    ,  -   .   /  */
   0  ,0  ,'"',0  ,0  ,0  ,0 ,'\'',0  ,0  ,0  ,0  ,0  ,0  ,0  ,0 ,
/* 0   1   2   3   4   5   6   7   8   9   :   ;   <   =   >   ?  */
   0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,'>',0 ,
/* @   A   B   C   D   E   F   G   H   I   J   K   L   M   N   O  */
   0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0 ,
/* P   Q   R   S   T   U   V   W   X   Y   Z   [   \   ]   ^   _  */
   0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0 ,'\\',0  ,0  ,0 ,
/* `   a   b   c   d   e   f   g   h   i   j   k   l   m   n   o  */
   0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0 ,
/* p   q   r   s   t   u   v   w   x   y   z   {   |   }   ~      */
   0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0  ,0 };


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
dks_esc_write (dk_session_t * ses, const char * src_str, size_t src_len,
  wcharset_t * tgt_charset, wcharset_t * src_charset, int dks_esc_mode)
{
  unsigned const char *src_tail = (unsigned const char *)src_str;
  unsigned char *str_end = (unsigned char *)(src_str+src_len);
  wchar_t wc;
  unsigned char action;
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
  action = DKS_ESC_CHARCLASS_ACTION(wc,dks_esc_mode_base);
  switch (action)
    {
    case ASIS:		goto out_byte_asis;
    case LATTICE:	goto out_lattice;
    case PCT:		goto out_percent;
    case AMPATTR:	if (dks_esc_mode & DKS_ESC_COMPAT_HTML) goto out_ampattr; /* no break */
    case AMP:		goto out_amp;
    case GTATTR:	if (dks_esc_mode & DKS_ESC_COMPAT_HTML) goto out_byte_asis; /* no break */
    case GT:		OUT_TO_BUF("&gt;", 4); goto char_done;
    case LTATTR:	if (dks_esc_mode & DKS_ESC_COMPAT_HTML) goto out_byte_asis; /* no break */
    case LT:		OUT_TO_BUF("&lt;", 4); goto char_done;
    case QUOT:		OUT_TO_BUF("&quot;", 6); goto char_done;
    case PLUS:		out_buf[out_buf_idx++] = '+'; goto char_done;
    case BAD:		out_buf[out_buf_idx++] = '?'; goto char_done;
    case SOAPCR:	if (dks_esc_mode & DKS_ESC_COMPAT_SOAP) goto out_lattice; goto out_byte_asis;
    case COMMENT:	goto out_comment;
    case CDATA:		goto out_cdata;
    case CDATA2:
      {
        char tmp[40];
        snprintf (tmp, sizeof (tmp), "]]>&#%lu;<![CDATA[", (unsigned long)wc);
        OUT_TO_BUF (tmp, (int) strlen (tmp));
        goto char_done;
      }
    case BSLASHC:	out_buf[out_buf_idx++] = '\\'; out_buf[out_buf_idx++] = dks_esc_bslashc[wc]; goto char_done;
    case BSLASHU:
      {
        out_buf[out_buf_idx++] = '\\';
        if (wc & ~0xffff)
          {
            out_buf[out_buf_idx++] = 'U';
            out_buf[out_buf_idx++] = "0123456789ABCDEF"[(wc&0xF0000000)>>28];
            out_buf[out_buf_idx++] = "0123456789ABCDEF"[(wc&0x0F000000)>>24];
            out_buf[out_buf_idx++] = "0123456789ABCDEF"[(wc&0x00F00000)>>20];
            out_buf[out_buf_idx++] = "0123456789ABCDEF"[(wc&0x000F0000)>>16];
          }
        else
          {
            out_buf[out_buf_idx++] = 'u';
          }
        out_buf[out_buf_idx++] = "0123456789ABCDEF"[(wc&0x0000F000)>>12];
        out_buf[out_buf_idx++] = "0123456789ABCDEF"[(wc&0x00000F00)>>8];
        out_buf[out_buf_idx++] = "0123456789ABCDEF"[(wc&0x000000F0)>>4];
        out_buf[out_buf_idx++] = "0123456789ABCDEF"[wc&0x0000000F];
        goto char_done;
      }
/*                            0          1         2   */
/*                            012 34567890123456789012 */
    case DOCWRI: OUT_TO_BUF ("');\ndocument.writeln('", 22); goto char_done;
    case REPEAT: out_buf[out_buf_idx++] = wc; out_buf[out_buf_idx++] = wc; goto char_done;
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
    if (wc & ~0x7F)
      {
        char utf8_buf[MAX_UTF8_CHAR];
        char *utf8_head = utf8_buf;
        char *utf8_tail = eh_encode_char__UTF8 (wc, utf8_buf, utf8_buf + MAX_UTF8_CHAR);
        while (utf8_head < utf8_tail)
          {
            out_buf[out_buf_idx++] = '%';
            out_buf[out_buf_idx++] = "0123456789ABCDEF"[((utf8_head[0])&0xF0)>>4];
            out_buf[out_buf_idx++] = "0123456789ABCDEF"[(utf8_head[0])&0x0F];
            utf8_head++;
          }
      }
    else
      {
        out_buf[out_buf_idx++] = '%';
        out_buf[out_buf_idx++] = "0123456789ABCDEF"[(wc&0xF0)>>4];
        out_buf[out_buf_idx++] = "0123456789ABCDEF"[wc&0x0F];
      }
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
    unsigned const char *src_tail_lookahead = src_tail;
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
  if (out_buf_idx < (sizeof(out_buf) / sizeof(out_buf[0])) - 40)
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
            action = dks_charclasses['?'-'>'][dks_esc_mode_base];
            switch (action)
              {
              case LATTICE:
                {
		  char tmp[20];
		  snprintf (tmp, sizeof (tmp), "&#%lu;", (unsigned long)wc);
		  session_buffered_write (ses, tmp, strlen(tmp));
		  continue;
                }
	      case PCT:
                {
                  char temp[VIRT_MB_CUR_MAX];
                  virt_mbstate_t st;
                  size_t temp_len;
                  memset (&st, 0, sizeof (st));
                  temp_len = virt_wcrtomb ((unsigned char *) temp, wc, &st);
                  if (((long)temp_len) > 0)
                    {
                      char pct[VIRT_MB_CUR_MAX];
                      size_t ctr;
                      char *pct_tail = pct;
                      for (ctr = 0; ctr < temp_len; ctr++)
                        {
                          (pct_tail++)[0] = '%';
                          (pct_tail++)[0] = "0123456789ABCDEF"[((temp[ctr])&0xF0)>>4];
                          (pct_tail++)[0] = "0123456789ABCDEF"[(temp[ctr])&0x0F];
                        }
                      session_buffered_write (ses, pct, (pct_tail-pct));
                    }
                  else
                    session_buffered_write_char ('?', ses);
                  continue;
                }
              case BAD:
                session_buffered_write_char ('?', ses);
                continue;
              case CDATA2:
                {
                  char tmp[40];
                  snprintf (tmp, sizeof (tmp), "]]>&#%lu;<![CDATA[", (unsigned long)wc);
                  session_buffered_write (ses, tmp, strlen(tmp));
                  continue;
                }
              case BSLASHU:
                {
                  char tmp[10];
                  char *tail = tmp;
                  (tail++)[0] = '\\';
                  if (wc & ~0xffff)
                    {
                      (tail++)[0] = 'U';
                      (tail++)[0] = "0123456789ABCDEF"[(wc&0xF0000000)>>28];
                      (tail++)[0] = "0123456789ABCDEF"[(wc&0x0F000000)>>24];
                      (tail++)[0] = "0123456789ABCDEF"[(wc&0x00F00000)>>20];
                      (tail++)[0] = "0123456789ABCDEF"[(wc&0x000F0000)>>16];
                    }
                  else
                    {
                      (tail++)[0] = 'u';
                    }
                  (tail++)[0] = "0123456789ABCDEF"[(wc&0x0000F000)>>12];
                  (tail++)[0] = "0123456789ABCDEF"[(wc&0x00000F00)>>8];
                  (tail++)[0] = "0123456789ABCDEF"[(wc&0x000000F0)>>4];
                  (tail++)[0] = "0123456789ABCDEF"[wc&0x0000000F];
                  session_buffered_write (ses, tmp, (tail-tmp));
                  continue;
                }
              default: GPF_T;
            }
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
