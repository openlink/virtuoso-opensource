%{
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
 */

#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#ifndef WLEX_TEST
#ifdef _USRDLL
#include "import_gate_virtuoso.h"
#else
#include "Dk.h"
#endif
#endif

#define MAXLISTDEPTH 10

#define WLEX_FONT_DEFAULT	0
#define WLEX_FONT_B		1
#define WLEX_FONT_U		2
#define WLEX_FONT_BU		3
#define WLEX_FONT_TT		4
#define WLEX_FONT_BTT		5
#define WLEX_FONT_I		6

#define WLEX_LIST_UL		0
#define WLEX_LIST_OL		1
#define WLEX_LIST_DL		2

typedef struct bufmem_s {
  char *bm_memblock;
  size_t bm_length;
} bufmem_t;

typedef struct wlex_state_s {
  int wlex_font;			/*!< Bitmask of WLEX_FONT_xx values */
  int wlex_headerlevel;			/*!< Last header level, 1 to 6 for H1 to H6 */
  int wlex_listlevel;			/*!< Nesting level for lists, 0 = outside list, 1 = three spaces etc. */
  int wlex_listmodes[MAXLISTDEPTH];	/*!< Array of WLEX_LIST_UL and WLEX_LIST_OL */
  int wlex_in_para;			/*!< Inside a text paragraph */
  int wlex_para_depressed;		/*!< No splitting to paragraphs due to verbatim or table or the like */
  int wlex_noautolink;			/*!< Automatic links are disabled */
  int wlex_in_table;			/*!< Table is in progress */
  int wlex_in_any_text;
  int wlex_format_lock;
  int wlex_xmp_depth;
  int wlex_id_num;
  bufmem_t wikiwordbuf;
  bufmem_t hrefbuf;
  bufmem_t titlebuf;
  bufmem_t predicatebuf;
#ifndef WLEX_TEST
  char * wlex_text;
  int wlex_text_len;
  int wlex_text_ofs;
  dk_session_t *wlex_out;
#endif
  int __test;
  int wlex_nowiki;
  int wlex_prevst;
  } wlex_state_t;

#ifdef WLEX_TEST
#define wlex_alloc(n) malloc(n)
#define wlex_free(p,n) free(p)
#else
#define wlex_alloc(n) dk_alloc(n)
#define wlex_free(p,n) dk_free(p,n)
#endif

#define ISNOTWIKIWORDCHAR(ch) \
	((' ' == (ch)) || ('\t' == (ch)) || ('.' == (ch)) \
	|| (!isalnum((ch)) && (',' != (ch)) && ('_' != (ch)) && ('-' != (ch))))

static wlex_state_t wlex_instance;
#define STATE(n) (wlex_instance.n)
#define STATEPTR (&wlex_instance)

#define WLEX_RESET_FONT		0x01
#define WLEX_RESET_HEADER	0x02
#define WLEX_RESET_TABLE	0x04
#define WLEX_RESET_LIST		0x08
#define WLEX_RESET_PARA		0x10

static void wlex_reset(int what);
static int wlex_textbegin (void);

#define STARTPARA \
  do { \
      if (!STATE(wlex_in_any_text)) \
        wlex_textbegin(); \
    } while(0)

#ifdef WLEX_TEST
#define PRINT(strg) printf("{%d:%s}", __LINE__, (strg))
#else
#define PRINT(strg) session_buffered_write (STATE(wlex_out), (strg), strlen(strg))
#endif

#ifdef WLEX_TEST
#define NPRINT(strg,len) fwrite ((strg), len, 1, stdout)
#else
#define NPRINT(strg,len) session_buffered_write (STATE(wlex_out), (strg), len)
#endif

#define PRINTTEXT(strg) \
  do { STARTPARA; PRINT((strg)); } while(0)

#define COPYTEXT PRINTTEXT(yytext)

#define COPY_WS_TEXT \
  do { STARTPARA; PRINT (" "); PRINT ((yytext)); } while (0);


#define LEXERROR(strg) \
  do { \
    PRINT("\n<!-- SyntError: "); \
    PRINT(strg); PRINT("\n"); \
    PRINT(yytext); PRINT(" -->\n"); \
    } while(0);

#define YY_FATAL_ERROR(msg) wikiyylexerror (msg)

static void wikiyylexerror (char * msg);

static void bm_alloc (bufmem_t *buf, size_t len)
{
  if (len < buf->bm_length)
    return;
  if (NULL != buf->bm_memblock)
    wlex_free (buf->bm_memblock, -1);
  buf->bm_length = (len + 0x100) & ~0x7F;
  buf->bm_memblock = wlex_alloc (buf->bm_length);
}

void wikilexdone ()
{
  wlex_state_t * st = STATEPTR;
  if (st->wikiwordbuf.bm_memblock != NULL)
    wlex_free (st->wikiwordbuf.bm_memblock, -1);
  if (st->hrefbuf.bm_memblock != NULL)
    wlex_free (st->hrefbuf.bm_memblock, -1);
  if (st->titlebuf.bm_memblock != NULL)
    wlex_free (st->titlebuf.bm_memblock, -1);
  if (st->predicatebuf.bm_memblock != NULL)
    wlex_free (st->predicatebuf.bm_memblock, -1);
}

static char *strdigit (char *str)
{
  while ('\0' != *str)
    {
      if (isdigit (*str))
        return str;
      str++;
    }
  return NULL;
}

static char *strnonws (char *str)
{
  while ('\0' != *str)
    {
      if (NULL == strchr (" \t\r\n", (*str)))
        return str;
      str++;
    }
  return NULL;
}


static struct xmlrepl_s {
  char c;
  const char* repl;
} xmlrepl[] = {
  {'\'', "&quot;"},
  {'&', "&amp;"},
  {'<', "&lt;"},
  {'>', "&gt;"}
};
#define XMLREPL_SZ ((sizeof(xmlrepl)/sizeof(struct xmlrepl_s)))

static void xml_encode (const char* str)
{
  const char* p = str;
  int idx;
  while (*p)
    {
      for(idx=0;idx<XMLREPL_SZ;++idx)
	{
	  if (xmlrepl[idx].c == p[0])
	    {
	      PRINT(xmlrepl[idx].repl);
	      break;
	    }
	 }
      if (XMLREPL_SZ == idx)
        session_buffered_write(STATE(wlex_out), p, 1);
      ++p;
    }
}





static void wlex_font(int newfont)
{
  char *tags;
  if (newfont == STATE(wlex_font))
    return;
  switch (STATE(wlex_font))
    {
    case WLEX_FONT_DEFAULT: tags=""; break;
    case WLEX_FONT_B: tags = "</B>"; break;
    case WLEX_FONT_U: tags = "</U>"; break;
    case WLEX_FONT_I: tags = "</I>"; break;
    case WLEX_FONT_BU: tags = "</U></B>"; break;
    case WLEX_FONT_TT: tags = "</CODE>"; break;
    case WLEX_FONT_BTT: tags = "</CODE></B>"; break;
    }
  PRINTTEXT(tags);
  STATE(wlex_font) = newfont;
  switch (STATE(wlex_font))
    {
    case WLEX_FONT_DEFAULT: tags = ""; break;
    case WLEX_FONT_B: tags = "<B>"; break;
    case WLEX_FONT_U: tags = "<U>"; break;
    case WLEX_FONT_I: tags = "<I>"; break;
    case WLEX_FONT_BU: tags = "<B><U>"; break;
    case WLEX_FONT_TT: tags = "<CODE>"; break;
    case WLEX_FONT_BTT: tags = "<B><CODE>"; break;
    }
  PRINTTEXT(tags);
}

static void wlex_headerlevel(int newlevel)
{
  wlex_reset (~WLEX_RESET_HEADER);
  if (newlevel >= MAXLISTDEPTH)
    newlevel = MAXLISTDEPTH;
  if (newlevel == STATE(wlex_headerlevel))
    return;
  if (STATE(wlex_headerlevel) != 0)
    {
      char buf[10];
      strcpy(buf, "</Hn>\n"); buf[3] = '0' + STATE(wlex_headerlevel);
      PRINT(buf);
    }
  STATE(wlex_headerlevel) = newlevel;
  if (STATE(wlex_headerlevel) != 0)
    {
      char buf[10];
      strcpy(buf, "<Hn>"); buf[2] = '0' + STATE(wlex_headerlevel);
      PRINT(buf);
    }
}

static void wlex_list (int newlevel, int newmode, char *text)
{
  int listmode;
  wlex_reset (~WLEX_RESET_LIST);
  listmode = STATE(wlex_listmodes)[STATE(wlex_listlevel)];
  if (newlevel >= MAXLISTDEPTH)
    newlevel = MAXLISTDEPTH - 1;
  while ((newlevel < STATE(wlex_listlevel)) ||
    ((newlevel > 0) && (newlevel == STATE(wlex_listlevel)) && (listmode != newmode))
   )
    {
      switch (listmode)
        {
	case WLEX_LIST_UL: PRINT("</LI>\n</UL>"); break;
	case WLEX_LIST_OL: PRINT("</LI>\n</OL>"); break;
	case WLEX_LIST_DL: PRINT("</DD>\n</DL>"); break;
	}
      if (WLEX_LIST_DL == listmode)
        STATE(wlex_listmodes)[STATE(wlex_listlevel)] = WLEX_LIST_UL;
      STATE(wlex_listlevel) -= 1;
      listmode = STATE(wlex_listmodes)[STATE(wlex_listlevel)];
    }
  if ((newlevel > 0) && (newlevel == STATE(wlex_listlevel)) && (listmode == newmode))
    {
      switch (listmode)
        {
	case WLEX_LIST_UL: PRINT("</LI>\n<LI>"); break;
	case WLEX_LIST_OL: PRINT("</LI>\n<LI>"); break;
	case WLEX_LIST_DL: PRINT("</DD>\n<DT>"); break;
	}
    }
  STATE(wlex_listmodes)[newlevel] = newmode;
  while (newlevel > STATE(wlex_listlevel))
    {
      STATE(wlex_listlevel) += 1;
      listmode = STATE(wlex_listmodes)[STATE(wlex_listlevel)];
      switch (listmode)
        {
	case WLEX_LIST_UL: PRINT("<UL><LI>"); break;
	case WLEX_LIST_OL: PRINT("<OL><LI>"); break;
	case WLEX_LIST_DL: PRINT("<DL><DT>"); break;
	}
    }
  if (WLEX_LIST_DL == listmode)
    {
      char *tail = text;
      while (NULL != strchr (" \t", tail[0]))
        tail++;
      NPRINT (tail, strchr (tail, ':') - tail);
      PRINT ("</DT><DD>");
    }
}

static void wlex_para(int enable)
{
  if (STATE(wlex_in_para) == enable)
    return;
  if (enable)
    PRINT("<P>");
  else
    if (!STATE(wlex_para_depressed))
      PRINT("</P>\n");
  STATE(wlex_in_para) = enable;
  STATE(wlex_para_depressed) = 0;
}

static void wlex_verbatim (int enable)
{
  if (enable)
    {
      int intext = STATE(wlex_in_any_text);
      wlex_reset(~(WLEX_RESET_LIST | WLEX_RESET_TABLE));
      if (intext);
        PRINT("<BR>");
      PRINT("<PRE>");
    }
  else
    PRINT("</PRE>");
  if (
    (0 != STATE(wlex_headerlevel)) ||
    (0 != STATE(wlex_listlevel)) )
    PRINT("<BR>");
}

static void wlex_id_print (wlex_state_t * st)
{
  char str[255];
  sprintf (str, " id=\"%d\"", st->wlex_id_num++);
  PRINT(str);
}

static void wlex_reset(int what)
{
  if ((what & WLEX_RESET_FONT) && (WLEX_FONT_DEFAULT != STATE(wlex_font)))
    wlex_font(WLEX_FONT_DEFAULT);
  if (what & WLEX_RESET_FONT)
    {
      while (0 < STATE(wlex_xmp_depth)) { PRINT("</XMP>"); STATE(wlex_xmp_depth) -= 1; STATE(wlex_format_lock) -= 1; }
      while (0 < STATE(wlex_format_lock)) { PRINT("</PRE>"); STATE(wlex_format_lock) -= 1; }
    }
  if ((what & WLEX_RESET_HEADER) && (0 != STATE(wlex_headerlevel)))
    wlex_headerlevel (0);
  if ((what & WLEX_RESET_LIST) && (0 != STATE(wlex_listlevel)))
    wlex_list (0, 0, NULL);
  if ((what & WLEX_RESET_PARA) && (0 != STATE(wlex_in_para)))
    wlex_para (0);
  if (STATE(wlex_in_any_text))
    STATE(wlex_in_any_text) = (
      (0 != STATE(wlex_headerlevel)) ||
      (0 != STATE(wlex_listlevel)) ||
      STATE(wlex_in_para) ||
      STATE(wlex_in_table) );
}

int wlex_textbegin (void)
{
  if ((0 != STATE(wlex_headerlevel)) ||
    (0 != STATE(wlex_listlevel)) ||
    STATE(wlex_in_para) ||
    STATE(wlex_in_table) )
  STATE(wlex_in_any_text) = 1;
  if (STATE (wlex_in_any_text))
    return 0;
  wlex_para (1);
  STATE (wlex_in_any_text) = 1;
  return 1;
}

static void wlex_ahref_2 (char *href, char *style, char *title, char* predicate)
{
  STARTPARA; PRINT("<A HREF=\""); xml_encode(href); PRINT("\" ");
  if (predicate)
    {
      PRINT("PREDICATE=\"");
      PRINT(predicate);
      PRINT("\" ");
    }
  PRINT("STYLE=\""); PRINT(style); PRINT("\">");
  PRINT(title); PRINT ("</A>");
}

static void wlex_ahref (char *href, char *style, char *title)
{
  wlex_ahref_2 (href, style, title, NULL);
}


char *wlex_wikiwordnorm (wlex_state_t *st, char *text)
{
  char *src, *tgt;
  bufmem_t *buf = &(st->wikiwordbuf);
  bm_alloc (buf, strlen(text) + 1);
  src = text;
  tgt = buf->bm_memblock;
  if (!strncmp (src, "%TWIKIWEB%", 10))
    {
      strcpy (tgt, "TWiki");
      tgt += 5;
      text += 10;
      src = text;
    }
  while ('\0' != src[0])
    {
      if ((src == text) || ISNOTWIKIWORDCHAR(src[0]))
        {
	  while (src[0] && ISNOTWIKIWORDCHAR(src[0])) src++;
	  if (!src[0])
	    break;
	  if (isalpha (src[0]))
	    (tgt++)[0] = toupper (src[0]);
	  else
	    (tgt++)[0] = src[0];
	}
      else
        (tgt++)[0] = src[0];
      src++;
    }
  tgt[0] = '\0';
  return buf->bm_memblock;
}

static void wlex_split_forced_link (wlex_state_t *st, char *text, char *delim)
{
  bufmem_t *href = &(st->hrefbuf);
  bufmem_t *title = &(st->titlebuf);
  int textlen = strlen (text);
  char *href_start, *href_end, *title_start, *title_end;
  bm_alloc (href, textlen);
  bm_alloc (title, textlen);
  href_start = text + 2; /* to omit first "[[" */
  title_end = text + textlen - 2; /* '... - 2' is to omit last "]]" */
  /* handle the case of triple "[" */
  if ((href_start[0] == '[') && (title_end > href_start)  && (title_end[-1] == ']'))
    {
      ++href_start; --title_end;
    }
  if (NULL == delim) /* Same text is for both href and title */
    {
       href_end = title_end;
       title_start = href_start;
    }
  else
    {
       href_end = strstr (text, delim);
       title_start = href_end + strlen (delim);
    }
  while ((href_start < href_end) && ((' ' == href_start[0]) || ('\t' == href_start[0]))) href_start++;
  while ((href_start < href_end) && ((' ' == href_end[-1]) || ('\t' == href_end[-1]))) href_end--;
  while ((title_start < title_end) && ((' ' == title_start[0]) || ('\t' == title_start[0]))) title_start++;
  while ((title_start < title_end) && ((' ' == title_end[-1]) || ('\t' == title_end[-1]))) title_end--;
  memcpy (href->bm_memblock, href_start, href_end - href_start);
  href->bm_memblock [href_end - href_start] = '\0';
  memcpy (title->bm_memblock, title_start, title_end - title_start);
  title->bm_memblock [title_end - title_start] = '\0';
}

/* delim == NULL and delim_pred == NULL are not allowed */
static void wlex_split_forced_sem_link (wlex_state_t *st, char *text, char *delim_pred, char *delim)
{
  bufmem_t *href = &(st->hrefbuf);
  bufmem_t *title = &(st->titlebuf);
  bufmem_t *pred = &(st->predicatebuf);
  int textlen = strlen (text);
  char *href_start, *href_end, *title_start, *title_end, *pred_start, *pred_end;
  bm_alloc (href, textlen);
  bm_alloc (title, textlen);
  bm_alloc (pred, textlen);
  pred_start = text + 2; /* to omit first "[[" */
  pred_end = strstr (text, delim_pred);
  href_start = pred_end + strlen (delim_pred);
  if (delim)
    {
      href_end = strstr (href_start, delim);
      title_start = href_end + strlen (delim);
      title_end = text + textlen - 2;  /* to omit first "]]" */
    }
  else
    {
      href_end = text + textlen - 2;
      title_start = href_start;
      title_end = href_end;
    }

  while ((pred_start < pred_end) && ((' ' == pred_start[0]) || ('\t' == pred_start[0]))) pred_start++;
  while ((pred_start < pred_end) && ((' ' == pred_end[-1]) || ('\t' == pred_end[-1]))) pred_end--;
  while ((href_start < href_end) && ((' ' == href_start[0]) || ('\t' == href_start[0]))) href_start++;
  while ((href_start < href_end) && ((' ' == href_end[-1]) || ('\t' == href_end[-1]))) href_end--;
  while ((title_start < title_end) && ((' ' == title_start[0]) || ('\t' == title_start[0]))) title_start++;
  while ((title_start < title_end) && ((' ' == title_end[-1]) || ('\t' == title_end[-1]))) title_end--;
  memcpy (pred->bm_memblock, pred_start, pred_end - pred_start);
  pred->bm_memblock [pred_end - pred_start] = '\0';
  memcpy (href->bm_memblock, href_start, href_end - href_start);
  href->bm_memblock [href_end - href_start] = '\0';
  memcpy (title->bm_memblock, title_start, title_end - title_start);
  title->bm_memblock [title_end - title_start] = '\0';
}


static void wlex_forced_link (wlex_state_t *st, char *text, char *delim, int wordnorm, char *style)
{
   wlex_split_forced_link (st, text, delim);
   if (wordnorm)
     wlex_ahref (wlex_wikiwordnorm (st, st->hrefbuf.bm_memblock), style, st->titlebuf.bm_memblock);
   else
     wlex_ahref (st->hrefbuf.bm_memblock, style, st->titlebuf.bm_memblock);
}

static void wlex_forced_link_with_pred (wlex_state_t *st, char *text, char *delim_pred, char *delim, char *style)
{
  wlex_split_forced_sem_link (st, text, delim_pred, delim);
  wlex_ahref_2 (st->hrefbuf.bm_memblock, style, st->titlebuf.bm_memblock, st->predicatebuf.bm_memblock);
}

static void wlex_div_with_pred (wlex_state_t *st, char *text, char *delim_pred, char *delim, char *style)
{
  wlex_split_forced_sem_link (st, text, delim_pred, delim);
  PRINT("<SPAN PREDICATE=\"");
  PRINT(st->predicatebuf.bm_memblock);
  PRINT("\" STYLE=\"");
  PRINT(style);
  PRINT("\" VALUE=\"");
  PRINT(st->hrefbuf.bm_memblock);
  PRINT("\">");
  PRINT(st->titlebuf.bm_memblock);
  PRINT("</SPAN>");
}

int wlex_count_header_level (char * line)
{
  char* ptr = line, *marker;
  int cnt = 0;
  while (ptr[0] && (ptr[0] == '-' || isspace(ptr[0]))) ++ptr;
  marker = ptr;
  while (ptr[0] && (ptr[0] == marker[0])) { ++ptr; ++cnt; }
  return cnt;
}


#ifndef WLEX_TEST
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
  do \
    { \
      int rest_len = STATE(wlex_text_len) - STATE(wlex_text_ofs); \
      int get_len = (max_size); \
      if (get_len > rest_len) \
	get_len = rest_len; \
      memcpy ((buf), (STATE(wlex_text) + STATE(wlex_text_ofs)), get_len); \
      (result) = get_len; \
      STATE(wlex_text_ofs) += get_len; \
    } while (0);
#endif

%}

%x VERBATIM
%x PLAINHTML
%x TABLELINE
%x TABLEHEADER
%x WIKTOLOGY

WS		([ \t]+)
WSNLS		([ \t\n\r]*)
ENDPUNCT	([.,:;\)\]\}\<\>])
STARTPUNCT	([\(\[\{\<\>])
S_NL		((\r)?(\n)(\r)?)
WS_NL		({WS}?{S_NL})
WSS_NL		({WS}*{S_NL})
BLANK		({WS}|{S_NL})
NOTAWORDSTART	({WS}|{S_NL}|{ENDPUNCT})
NOTAWORDEND	({WS}|{S_NL}|{STARTPUNCT})
NOTENDOFCODE	(([^\n<])|("<"[^/])|("</"[^Cc])|("</"[Cc][^Oo])|("</"[Cc][Oo][^Dd])|("</"[Cc][Oo][Dd][^Ee])|("</"[Cc][Oo][Dd][Ee](" "?)[^>]))
WORDCHAR	([A-Za-z0-9/\\.])
SIMPLEWORD	(([A-Za-z0-9/\\.]+)?[A-Za-z0-9\\])
SIMPLEWORD2	(([A-Za-z0-9/\\.]+)?[A-Za-z0-9_=/\\])
WIKIWORD	((([A-Z]+)([a-z]+)([A-Z]+)([A-Za-z0-9]*))|("%WIKIUSERNAME%"))
CLUSTERNAME	((([A-Z]+)([a-z]+)([A-Za-z0-9]*))|("%TWIKIWEB%"))
QWIKIWORD	({CLUSTERNAME}"."{WIKIWORD})
SITENAME	({WIKIWORD}|([A-Z]+))
INTERWIKI	({SITENAME}":"(({CLUSTERNAME}".")?){WIKIWORD})
DEFTERM		([^ \t\r\n:]+)
SIMPLESENTENCE	([a-zA-Z0-9\-\.][a-zA-Z0-9\-\. \t]*)
BWORD		({SIMPLESENTENCE}"*")
TTWORD		({SIMPLESENTENCE}"=")
BUWORD		({SIMPLESENTENCE}"__")
IWORD		({SIMPLESENTENCE}"/"{BLANK})
UWORD		({SIMPLESENTENCE}"_")
BTTWORD		(([^ =\t\r\n]+)"==")
PROTOCOL	((("http")|("https")|("ftp")|("gopher")|("news")|("file")|("telnet"))"://")
HOSTNAME	([A-Za-z](([A-Za-z0-9-]*[A-Za-z0-9])|([A-Za-z0-9]*)))
DOMAINNAME	({HOSTNAME}(("."{HOSTNAME})*))
LOCALRES	([A-Za-z0-9_.:|/?+%&-=@]+)
FRAG		("#"{LOCALRES})
USERNAME	([A-Za-z]([A-Za-z0-9_-]*))
ABSURI		({PROTOCOL}(({USERNAME}(("!"{LOCALRES})?)"@")?){DOMAINNAME}(((":"{LOCALRES})|("/"(({LOCALRES}?))))({FRAG}?))?)
DUMMYURI	({PROTOCOL}([A-Za-z0-9_.:|/?+%&-=~#]+))
LINKTITLE	([^[\]\|]+)
FORCEDWIKILINK	([^\r\n\[\]~@:\\/{}<>\|]+)
EMAIL		({USERNAME}"@"{DOMAINNAME}(("?"{LOCALRES})?))
MAILTO		("mailto:"{USERNAME}"@"{DOMAINNAME}(("?"{LOCALRES})?))
TAGNAME		((([A-Z][A-Z0-9]*)|([a-z][a-z0-9]*))((":"{USERNAME})?))
MACRONAME	([A-Z]+(":"[A-Z]+)?)
MACROARGNAME	([a-z]+)
MACROARGVALUE	("\""[A-Za-z0-9_.:;|\\/?+%&'` \t-\[\]$^]*"\"")
MACROARG	({MACROARGNAME}"="{MACROARGVALUE})
MACROARGS	({WS}?({MACROARG}({WS}{MACROARG})*{WS}?)?)
INLINEMACROCONT ((([^?][^>])|(.[^?][^>]))*|.)
INLINEMACRO	("<?inline"{INLINEMACROCONT}"?>")
CELLFRAG	([^|\r\n]*)
CELL		({CELLFRAG}("\\"{WS_NL}{CELLFRAG})*)
TABLEROW	("|"({CELL}"|")+{WS_NL})
NOP		("<"("nop"|"NOP"){WS}?("/"?)">")
THEADCELL	([^|\r\n*]*)
THROW		("|"({WS}*"*"{THEADCELL}"*"{WS}*"|")*){WS_NL}
PREDICATE	([A-Za-z][A-Za-z0-9 ]*)
HTML		(("<html"({WS}+)"xmlns=\"http://www.w3.org/1999/xhtml\">")|("<html"({WS}+)"xmlns=\'http://www.w3.org/1999/xhtml\'>"))
DOCTYPE		("<!DOCTYPE")([^>]*>)
MFONTMOD	("\*"|"=="|"__")
MFONTMODNEXT	([\*=_])
MFONTMODS	({MFONTMOD}{MFONTMODNEXT}+)
        /* Wiktology */
WIKTOLOGYMARK   (".ontology"|".ONTOLOGY")
WIKTOLOGYSTOP   (".end"|".END")
%%

	/* Verbatim */
<INITIAL>^({WS}?)"<verbatim>"{WS_NL}	{ BEGIN(VERBATIM); wlex_verbatim(1); }
<VERBATIM>^({WS}?)"</verbatim>"{WS_NL}	{ BEGIN(INITIAL); wlex_verbatim(0); }
<VERBATIM>"</verbatim>"{WS_NL}		{ BEGIN(INITIAL); wlex_verbatim(0); }
<VERBATIM>"<"				{ PRINT ("&lt;"); }
<VERBATIM>">"				{ PRINT ("&gt;"); }
<VERBATIM>[^<\r\n]*[\r\n]		{ PRINT (yytext); }
<VERBATIM>[ \t\r\n]			{ PRINT (yytext); }
<VERBATIM>{SIMPLEWORD}			{ PRINT (yytext); }
<VERBATIM>"<?"				{ PRINT ("&lt;?"); }
<VERBATIM>.				{ PRINT(yytext); }

	/* Wiktology */
<INITIAL>{WIKTOLOGYMARK}{WS_NL}		{ PRINT("<p><b>Wikitology detected:</b><br><div id='wiktology'>"); BEGIN(WIKTOLOGY); wlex_verbatim(1); }
<WIKTOLOGY>"<"				{ PRINT ("&lt;"); }
<WIKTOLOGY>">"				{ PRINT ("&gt;"); }
<WIKTOLOGY>[^<\r\n]*[\r\n]		{ PRINT (yytext); }
<WIKTOLOGY>[ \t\r\n]			{ PRINT (yytext); }
<WIKTOLOGY>{SIMPLEWORD}			{ PRINT (yytext); }
<WIKTOLOGY>"<?"				{ PRINT ("&lt;?"); }
<WIKTOLOGY>{WIKTOLOGYSTOP}{WS_NL}		{ PRINT("</div></p><b>End of Wikitology</b><br>"); BEGIN(INITIAL); wlex_verbatim(0); }


	/* WikiLinks. This is the core :) They are of highest possible priority */
<*>{WIKIWORD}				{ if (STATE(wlex_noautolink)) COPYTEXT; else wlex_ahref (wlex_wikiwordnorm (STATEPTR, yytext), "wikiword", yytext); }
<*>{QWIKIWORD}				{ if (STATE(wlex_noautolink)) COPYTEXT; else wlex_ahref (wlex_wikiwordnorm (STATEPTR, yytext), "qwikiword", strchr (yytext, '.') + 1); }
<*>{INTERWIKI}				{ if (STATE(wlex_noautolink)) COPYTEXT; else wlex_ahref (wlex_wikiwordnorm (STATEPTR, yytext), "interwiki", yytext); }
<*>{NOP}({WIKIWORD}|{QWIKIWORD}|{INTERWIKI})	{ PRINT("<NOP />"); PRINTTEXT(strchr(yytext,'>')+1); }

	/* xmlns must be removed for <html tag. this is workaround and must be replaced by proper handling XHTML */
<INITIAL>{HTML}				{ PRINT ("<html>"); BEGIN(PLAINHTML); }
<INITIAL>{DOCTYPE}			{ ; }



	/* PlainHtml */
<INITIAL>^({WS}?)"<plainhtml>"{WS_NL}		{ BEGIN(PLAINHTML); }
<INITIAL>"<nowiki>"			{ BEGIN(PLAINHTML); STATE(wlex_noautolink) = 1; STATE(wlex_nowiki) = 1;  STATE(wlex_in_any_text) = 1; STATE(wlex_prevst) = INITIAL; }
<TABLELINE>"<nowiki>"			{ BEGIN(PLAINHTML); STATE(wlex_noautolink) = 1; STATE(wlex_nowiki) = 1;  STATE(wlex_in_any_text) = 1; STATE(wlex_prevst) = TABLELINE; }
<PLAINHTML>^({WS}?)"</plainhtml>"{WS_NL}	{ BEGIN(INITIAL); }
<PLAINHTML>"</nowiki>"				{ if ((STATE(wlex_prevst)) == TABLELINE) { BEGIN(TABLELINE);} else { BEGIN(INITIAL);} STATE(wlex_noautolink) = 0; STATE (wlex_nowiki) = 0; }
<PLAINHTML>"</html>"{WS_NL}		        { BEGIN(INITIAL); }
<PLAINHTML>{WS_NL}				{ if (STATE(wlex_nowiki)) PRINT ("<BR/>"); }
<PLAINHTML>.					{ PRINT (yytext); }

<INITIAL,TABLELINE>^({WS}?)"<noautolink>"{WS_NL}		{ STATE(wlex_noautolink) = 1; }
<INITIAL,TABLELINE>^({WS}?)"</noautolink>"{WS_NL}		{ STATE(wlex_noautolink) = 0; }

	/* Other links. Their priorities are higher than anything else except <verbatim> */
<INITIAL,TABLELINE>{MAILTO}				{ if (WLEX_FONT_DEFAULT == STATE(wlex_font)) wlex_ahref (yytext, "mailto", yytext+7); else COPYTEXT; }
<INITIAL,TABLELINE>{EMAIL}				{ if (WLEX_FONT_DEFAULT == STATE(wlex_font)) wlex_ahref (yytext, "mailto", yytext); else COPYTEXT; }
<INITIAL,TABLELINE>{ABSURI}				{ if (WLEX_FONT_DEFAULT == STATE(wlex_font)) wlex_ahref (yytext, "absuri", yytext); else COPYTEXT; }
<INITIAL,TABLELINE>"[[["{LINKTITLE}"]]]"		{ wlex_forced_link (STATEPTR, yytext, NULL, 1, "forcedwikiword");  }
<INITIAL,TABLELINE>"[["{PREDICATE}"::"{FORCEDWIKILINK}"]]"	{ wlex_forced_link_with_pred (STATEPTR, yytext, "::", NULL, "forcedwikiword");  }
<INITIAL,TABLELINE>"[["{MAILTO}" "{LINKTITLE}"]]"	{ wlex_forced_link (STATEPTR, yytext, " ", 0, "mailto"); }
<INITIAL,TABLELINE>"[["{MAILTO}"]["{LINKTITLE}"]]"	{ wlex_forced_link (STATEPTR, yytext, "][", 0, "mailto");  }
<INITIAL,TABLELINE>"[["{WIKIWORD}" "{LINKTITLE}"]]"	{ wlex_forced_link (STATEPTR, yytext, " ", 0, "wikiword"); }
<INITIAL,TABLELINE>"[["{WIKIWORD}"]["{LINKTITLE}"]]"	{ wlex_forced_link (STATEPTR, yytext, "][", 0, "wikiword");  }
<INITIAL,TABLELINE>"[["{QWIKIWORD}" "{LINKTITLE}"]]"	{ wlex_forced_link (STATEPTR, yytext, " ", 0, "qwikiword");  }
<INITIAL,TABLELINE>"[["{QWIKIWORD}"]["{LINKTITLE}"]]"	{ wlex_forced_link (STATEPTR, yytext, "][", 0, "qwikiword");  }
<INITIAL,TABLELINE>"[["{INTERWIKI}" "{LINKTITLE}"]]"	{ wlex_forced_link (STATEPTR, yytext, " ", 0, "interwiki");  }
<INITIAL,TABLELINE>"[["{INTERWIKI}"]["{LINKTITLE}"]]"	{ wlex_forced_link (STATEPTR, yytext, "][", 0, "interwiki");  }
<INITIAL,TABLELINE>"[["{DUMMYURI}" "{LINKTITLE}"]]"	{ wlex_forced_link (STATEPTR, yytext, " ", 0, "absuri"); }
<INITIAL,TABLELINE>"[["{DUMMYURI}"]["{LINKTITLE}"]]"	{ wlex_forced_link (STATEPTR, yytext, "][", 0, "absuri"); }
<INITIAL,TABLELINE>"[["{FRAG}" "{LINKTITLE}"]]"		{ wlex_forced_link (STATEPTR, yytext, " ", 0, "anchorhere"); }
<INITIAL,TABLELINE>"[["{FRAG}"]["{LINKTITLE}"]]"	{ wlex_forced_link (STATEPTR, yytext, "][", 0, "anchorhere");  }
<INITIAL,TABLELINE>"[["{LINKTITLE}"]]"			{ wlex_forced_link (STATEPTR, yytext, NULL, 1, "forcedwikiword");  }
<INITIAL,TABLELINE>"[["{FORCEDWIKILINK}"]["{LINKTITLE}"]]"	{ wlex_forced_link (STATEPTR, yytext, "][", 1, "forcedwikiword");  }
<INITIAL,TABLELINE>"[["{LOCALRES}"]["{LINKTITLE}"]]"	{ wlex_forced_link (STATEPTR, yytext, "][", 0, "reluri");  }
<INITIAL,TABLELINE>"[["{PREDICATE}"::"{FORCEDWIKILINK}"|"{LINKTITLE}"]]"	{ wlex_forced_link_with_pred (STATEPTR, yytext, "::", "|", "forcedwikiword");  }
<INITIAL,TABLELINE>"[["{PREDICATE}":="{FORCEDWIKILINK}"|"{LINKTITLE}"]]"	{ wlex_div_with_pred (STATEPTR, yytext, ":=", "|", "semanticvalue");  }

	/* HTML tags */
<INITIAL>"<"("pre"|"PRE")[^\r\n<>]*">"	{ if (!STATE(wlex_xmp_depth)) STATE(wlex_format_lock) += 1; PRINT(yytext); }
<INITIAL>"</"("pre"|"PRE")[ \t]*">"	{ if (!STATE(wlex_xmp_depth) && (0 < STATE(wlex_format_lock))) STATE(wlex_format_lock) -= 1; PRINT(yytext); }
<INITIAL>"<"("xmp"|"XMP")[^\r\n<>]*">"	{ STATE(wlex_xmp_depth) += 1; STATE(wlex_format_lock) += 1; PRINT(yytext); }
<INITIAL>"</"("xmp"|"XMP")[ \t]*">"	{ if (0 < STATE(wlex_xmp_depth)) { STATE(wlex_xmp_depth) -= 1; STATE(wlex_format_lock) -= 1; } PRINT(yytext); }
<INITIAL,TABLELINE,PLAINHTML>"<"{TAGNAME}[^\r\n<>]*">"	{
        if (!STATE(wlex_in_para) && !STATE(wlex_in_any_text))
	  STATE(wlex_in_para) = STATE(wlex_in_any_text) = STATE(wlex_para_depressed) = 1;
	PRINT(yytext);
    }
<INITIAL,TABLELINE,PLAINHTML>"</"{TAGNAME}[ \t]*">"	{ PRINT(yytext); }
<INITIAL,TABLELINE,PLAINHTML>{NOP}			{ PRINT("<!-- nop -->"); }

	/* Ends of lines and ends of paragraphs */
<INITIAL>"."{WS_NL}{WS_NL}	{ if (0 < STATE(wlex_format_lock)) PRINT(yytext); else PRINTTEXT("."); wlex_reset (~0); }
<INITIAL>"."{WS_NL}		{ if (0 < STATE(wlex_format_lock)) PRINT(yytext); else PRINTTEXT(".\n"); }
<INITIAL>". "/{BLANK}		{ if (0 < STATE(wlex_format_lock)) PRINT(yytext); else PRINTTEXT(".\n"); }
<INITIAL>"."/{BLANK}		{ if (0 < STATE(wlex_format_lock)) PRINT(yytext); else PRINTTEXT(".\n"); }
<INITIAL>{WS}"."		{ if (0 < STATE(wlex_format_lock)) PRINT(yytext); else COPYTEXT; }
<INITIAL>{WS_NL}{WS_NL}		{ if (0 < STATE(wlex_format_lock)) PRINT(yytext); else wlex_reset (~0); }
 <INITIAL>{WS_NL}		{ if (0 < STATE(wlex_format_lock))
 				    PRINT(yytext);
				  else
				    {
				      if (STATE(wlex_headerlevel))
				         wlex_headerlevel(0);
				      PRINTTEXT(" ");
				    }
				}

	/* Titles */
<INITIAL,TABLELINE>^{WS}*"---"([+]+)	{ BEGIN(INITIAL); wlex_headerlevel (wlex_count_header_level(yytext)); }
<INITIAL,TABLELINE>^{WS}*"---#"{WS}	{ BEGIN(INITIAL); wlex_headerlevel (1); }
<INITIAL,TABLELINE>^{WS}*"--"([+]+)	{ BEGIN(INITIAL); wlex_headerlevel (wlex_count_header_level(yytext)); }
<INITIAL,TABLELINE>^{WS}*"--#"{WS}	{ BEGIN(INITIAL); wlex_headerlevel (1); }
<INITIAL,TABLELINE>^{WS}*"---"("-"*)([+]+)	{ BEGIN(INITIAL); wlex_headerlevel (wlex_count_header_level(yytext)); }
<INITIAL,TABLELINE>^{WS}*"------#"{WS}	{ BEGIN(INITIAL); wlex_headerlevel (1); }
<INITIAL,TABLELINE>"!!"		{ if (STATE(wlex_headerlevel)) PRINT("<NOTOC />"); else PRINT(yytext); }

	/* Lists */
<INITIAL,TABLELINE>^([ ][ ][ ])+"*"{WS}			{ BEGIN(INITIAL); wlex_list ((strchr(yytext, '*') - yytext) / 3, WLEX_LIST_UL, NULL); }
<INITIAL,TABLELINE>^([ ][ ][ ])+[1-9]([0-9]*)([.]?){WS}	{ BEGIN(INITIAL); wlex_list ((strdigit(yytext) - yytext) / 3, WLEX_LIST_OL, NULL); }
<INITIAL,TABLELINE>^([ ][ ][ ])+{DEFTERM}":"{WS}	{ BEGIN(INITIAL); wlex_list ((strnonws(yytext) - yytext) / 3, WLEX_LIST_DL, yytext); }
<INITIAL,TABLELINE>^([\t])+"*"{WS}			{ BEGIN(INITIAL); wlex_list (strchr(yytext, '*') - yytext, WLEX_LIST_UL, NULL); }
<INITIAL,TABLELINE>^([\t])+[1-9]([0-9]*)([.]?){WS}	{ BEGIN(INITIAL); wlex_list (strdigit(yytext) - yytext, WLEX_LIST_OL, NULL); }
<INITIAL,TABLELINE>^([\t])+{DEFTERM}":"{WS}		{ BEGIN(INITIAL); wlex_list (strnonws(yytext) - yytext, WLEX_LIST_DL, yytext); }

	/* Font processing */
<INITIAL,TABLELINE>{WS}*{MFONTMODS}		{ COPYTEXT; }

<INITIAL,TABLELINE>{WS}*"__"/{NOTAWORDSTART}	{ if (WLEX_FONT_BU == STATE(wlex_font)) wlex_font (WLEX_FONT_DEFAULT); else COPYTEXT;}
<INITIAL,TABLELINE>{WS}*"*"/{NOTAWORDSTART}	{ if (WLEX_FONT_B == STATE(wlex_font)) wlex_font (WLEX_FONT_DEFAULT); else COPYTEXT;}
<INITIAL,TABLELINE>{WS}*"_"/{NOTAWORDSTART}	{ if (WLEX_FONT_U == STATE(wlex_font)) wlex_font (WLEX_FONT_DEFAULT); else COPYTEXT;}
<INITIAL,TABLELINE>{WS}*"=="/{NOTAWORDSTART}	{ if (WLEX_FONT_BTT == STATE(wlex_font)) wlex_font (WLEX_FONT_DEFAULT); else COPYTEXT;}
<INITIAL,TABLELINE>{WS}*"="/{NOTAWORDSTART}	{ if (WLEX_FONT_TT == STATE(wlex_font)) wlex_font (WLEX_FONT_DEFAULT); else COPYTEXT;}
<INITIAL,TABLELINE>{WS}*"/"/{NOTAWORDSTART}	{ if (WLEX_FONT_I == STATE(wlex_font)) wlex_font (WLEX_FONT_DEFAULT); else COPYTEXT;}

<INITIAL,TABLELINE>{WS}*"__"/{BUWORD}		{ if (WLEX_FONT_DEFAULT == STATE(wlex_font)) { PRINT(" "); wlex_font (WLEX_FONT_BU); } else COPYTEXT; }
<INITIAL,TABLELINE>{WS}*"*"/{BWORD}		{ if (WLEX_FONT_DEFAULT == STATE(wlex_font)) { PRINT(" "); wlex_font (WLEX_FONT_B); } else COPYTEXT; }
<INITIAL,TABLELINE>{WS}*"_"/{UWORD}		{ if (WLEX_FONT_DEFAULT == STATE(wlex_font)) { PRINT(" "); wlex_font (WLEX_FONT_U); } else COPYTEXT; }
<INITIAL,TABLELINE>{WS}*"=="/{BTTWORD}		{ if (WLEX_FONT_DEFAULT == STATE(wlex_font)) { PRINT(" "); wlex_font (WLEX_FONT_BTT); } else COPYTEXT; }
<INITIAL,TABLELINE>{WS}*"="/{TTWORD}		{ if (WLEX_FONT_DEFAULT == STATE(wlex_font)) { PRINT(" "); wlex_font (WLEX_FONT_TT); } else COPYTEXT; }
<INITIAL,TABLELINE>{WS}*"/"/{IWORD}		{ if (WLEX_FONT_DEFAULT == STATE(wlex_font)) { PRINT(" "); wlex_font (WLEX_FONT_I); } else COPYTEXT; }

<TABLEHEADER>{WS}"*"		{ STATE(wlex_in_any_text) = 1; }

	/* Other formatting */
<INITIAL,TABLELINE>^({WS}?)"---"			{ PRINT("<HR />"); }
<INITIAL,TABLELINE>^({WS}?)"#"{WIKIWORD}	{
	PRINT("<A NAME=\"");
	PRINT(strchr (yytext, '#')+1);
	PRINT("\">\n");
    }

	/* Variables and macro calls */
<INITIAL,TABLELINE>"%"{MACRONAME}"%"	{ PRINT("<?"); NPRINT(yytext+1,strlen(yytext)-2); PRINT("?>"); }
<INITIAL,TABLELINE>"%"{MACRONAME}"{"{MACROARGS}"}%"	{
	char *lbrace = strchr (yytext, '{');
	char *rbrace = strchr (yytext, '}');
	PRINT("<?"); NPRINT(yytext+1,lbrace-(yytext+1)); PRINT(" ");
	NPRINT(lbrace+1, rbrace-(lbrace+1)); PRINT("?>");
    }
<INITIAL,TABLELINE>"%"{MACRONAME}"{"{MACROARGVALUE}"}%"	{
	char *lbrace = strchr (yytext, '{');
	char *rbrace = strchr (yytext, '}');
	PRINT("<?"); NPRINT(yytext+1,lbrace-(yytext+1)); PRINT(" param=");
	NPRINT(lbrace+1, rbrace-(lbrace+1)); PRINT("?>");
    }
<INITIAL,TABLELINE>{INLINEMACRO}	{ COPYTEXT; }


	/* Tables */
<INITIAL>^{WS}?/{THROW}		{ wlex_reset(~WLEX_RESET_LIST); BEGIN(TABLEHEADER);  STATE(wlex_in_any_text) = 1; PRINT("\n<TABLE class=\"wikitable\">"); }
<TABLEHEADER>^{WS}?"|"/{WS}*"*"		{ PRINT("\n<TR><TH"); wlex_id_print (STATEPTR); PRINT (">"); }
<TABLEHEADER>"|"{WS_NL}/({WS}?{TABLEROW})	{ PRINT("</TH></TR>"); BEGIN(TABLELINE); }
<TABLEHEADER>"|"{WS_NL}/({WS}?{THROW})	{ PRINT("</TH></TR>"); }
<TABLEHEADER>"|"/{WS_NL}		{ PRINT("</TH></TR>\n</TABLE>\n"); BEGIN(INITIAL); wlex_reset(~WLEX_RESET_LIST); }
<TABLEHEADER>"|"			{ PRINT("</TH><TH"); wlex_id_print (STATEPTR); PRINT (">"); }
<TABLEHEADER>"<"			{ PRINT("&lt;"); }
<TABLEHEADER>"*"			{ ; }
<TABLEHEADER>.				{ PRINT(yytext); }


<INITIAL>^{WS}?/{TABLEROW}		{ wlex_reset(~WLEX_RESET_LIST); BEGIN(TABLELINE); STATE(wlex_in_any_text) = 1; PRINT("\n<TABLE class=\"wikitable\">"); }
<TABLELINE>^{WS}?"|"/"  "		{ PRINT("\n<TR><TD ALIGN=\"center\">"); }
<TABLELINE>^{WS}?"|"			{ PRINT("\n<TR><TD>"); }
<TABLELINE>"|"{WS_NL}/({WS}?{TABLEROW})	{ PRINT("</TD></TR>"); }
<TABLELINE>"|"/{WS_NL}			{ PRINT("</TD></TR>\n</TABLE>\n"); BEGIN(INITIAL); wlex_reset(~WLEX_RESET_LIST); }
<TABLELINE>"|"/"  "			{ PRINT("</TD><TD ALIGN=\"center\">"); }
<TABLELINE>"|"/"|"			{ PRINT("</TD><TD STYLE=\"colspanstub\">"); }
<TABLELINE>"|"				{ PRINT("</TD><TD>"); }
<TABLELINE>"|"				{ PRINT("</TD><TD>"); }
<TABLELINE>"\\"{WS_NL}			{ ; }
<TABLELINE>"<"				{ PRINT("&lt;"); }
<TABLELINE>.				{ PRINT(yytext); }


	/* Inlined verbatims
	<INITIAL>"<CODE>"({NOTENDOFCODE}*)({S_NL}({NOTENDOFCODE}+))*({S_NL}?)({WS}?)"</CODE>"	{ COPYTEXT; }
	<INITIAL>"<CODE>"({NOTENDOFCODE}*)({S_NL}({NOTENDOFCODE}+))*{WS_NL}{WS_NL}			{ COPYTEXT; }
	<INITIAL>"</CODE>"						{ LEXERROR("</CODE> is found but no <CODE> before it"); }
	*/

	/* Others */
<*>{SIMPLEWORD}			{ COPYTEXT; }
<*>"<?"				{ COPYTEXT; }
<INITIAL>"<"			{ PRINTTEXT("&lt;"); }
<INITIAL>.			{ COPYTEXT; }
<*><<EOF>>			{ wlex_reset (~0); return 0; }

%%
/*<INITIAL>.([^ \t\r\n\[\]#*_=<A-Z1-9-]*)	{ COPYTEXT; }*/

int
wikiyywrap (void)
{
  return (1);
}

#ifdef WLEX_TEST
int main(int argc, char *argv[])
{
  if (argc > 1)
    yyin = fopen (argv[1], "r");
  wikiyylex();
  return 0;
}
#else
void wikiyylex_prepare (char *text, dk_session_t *out)
{
  memset (&wlex_instance, 0, sizeof (wlex_instance));
  STATE (wlex_text) = text;
  STATE (wlex_text_len) = strlen(text);
  STATE (wlex_out) = out;
  BEGIN(INITIAL);
}

static void wikiyylexerror (char * msg)
{
  du_thread_t * self = THREAD_CURRENT_THREAD;
  caddr_t * err = dk_alloc_box_zero (3 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  err [0] = box_dv_short_string ("42000");
  err [1] = box_dv_short_string ("SRXXX");
  err [2] = box_dv_short_string (msg);
  self->thr_reset_code = (caddr_t) err;
  longjmp_splice (self->thr_reset_ctx, 1);
}
#endif
