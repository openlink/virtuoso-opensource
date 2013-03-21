/*
 *  $Id$
 *
 *  tidy.c - HTML parser and pretty printer
 *
 *  Copyright (c) 1998-2000 World Wide Web Consortium
 *  (Massachusetts Institute of Technology, Institut National de
 *  Recherche en Informatique et en Automatique, Keio University).
 *  All Rights Reserved.
 *
 *  Contributing Author(s):
 *
 *  Dave Raggett <dsr@w3.org>
 *
 *  The contributing author(s) would like to thank all those who
 *  helped with testing, bug fixes, and patience.  This wouldn't
 *  have been possible without all of you.
 *
 *  COPYRIGHT NOTICE:
 *
 *  This software and documentation is provided "as is," and
 *  the copyright holders and contributing author(s) make no
 *  representations or warranties, express or implied, including
 *  but not limited to, warranties of merchantability or fitness
 *  for any particular purpose or that the use of the software or
 *  documentation will not infringe any third party patents,
 *  copyrights, trademarks or other rights.
 *
 *  The copyright holders and contributing author(s) will not be
 *  liable for any direct, indirect, special or consequential damages
 *  arising out of any use of the software or documentation, even if
 *  advised of the possibility of such damage.
 *
 *  Permission is hereby granted to use, copy, modify, and distribute
 *  this source code, or portions hereof, documentation and executables,
 *  for any purpose, without fee, subject to the following restrictions:
 *
 *  1. The origin of this source code must not be misrepresented.
 *  2. Altered versions must be plainly marked as such and must
 *     not be misrepresented as being the original source.
 *  3. This Copyright notice may not be removed or altered from any
 *     source or altered source distribution.
 *
 *  The copyright holders and contributing author(s) specifically
 *  permit, without fee, and encourage the use of this source code
 *  as a component for supporting the Hypertext Markup Language in
 *  commercial products. If you use this source code in a product,
 *  acknowledgment is not required but would be appreciated.
 */

#include "platform.h"
#include "html.h"

void InitTidy(void);
void DeInitTidy(void);

extern char *release_date;

Bool        debug_flag = no;
Node       *debug_element = null;
Lexer      *debug_lexer = null;
uint       totalerrors = 0;
uint       totalwarnings = 0;
uint       optionerrors = 0;

#ifdef BIF_TIDY
errout_t *errout;  /* set to stderr or stdout */
#else
FILE *errout;  /* set to stderr or stdout */
FILE *input;
#endif

/* Mapping for Windows Western character set (128-159) to Unicode */
int Win2Unicode[32] =
{
    0x20AC, 0x0000, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
    0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x0000, 0x017D, 0x0000,
    0x0000, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
    0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x0000, 0x017E, 0x0178
};

/*
John Love-Jensen contributed this table for mapping MacRoman
character set to Unicode
*/

int Mac2Unicode[256] =
{
    0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
    0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F,

    0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017,
    0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D, 0x001E, 0x001F,

    0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027,
    0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F,

    0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
    0x0038, 0x0039, 0x003A, 0x003B, 0x003C, 0x003D, 0x003E, 0x003F,

    0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
    0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,

    0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
    0x0058, 0x0059, 0x005A, 0x005B, 0x005C, 0x005D, 0x005E, 0x005F,

    0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
    0x0068, 0x0069, 0x006A, 0x006B, 0x006C, 0x006D, 0x006E, 0x006F,

    0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
    0x0078, 0x0079, 0x007A, 0x007B, 0x007C, 0x007D, 0x007E, 0x007F,
    /* x7F = DEL */
    0x00C4, 0x00C5, 0x00C7, 0x00C9, 0x00D1, 0x00D6, 0x00DC, 0x00E1,
    0x00E0, 0x00E2, 0x00E4, 0x00E3, 0x00E5, 0x00E7, 0x00E9, 0x00E8,

    0x00EA, 0x00EB, 0x00ED, 0x00EC, 0x00EE, 0x00EF, 0x00F1, 0x00F3,
    0x00F2, 0x00F4, 0x00F6, 0x00F5, 0x00FA, 0x00F9, 0x00FB, 0x00FC,

    0x2020, 0x00B0, 0x00A2, 0x00A3, 0x00A7, 0x2022, 0x00B6, 0x00DF,
    0x00AE, 0x00A9, 0x2122, 0x00B4, 0x00A8, 0x2260, 0x00C6, 0x00D8,

    0x221E, 0x00B1, 0x2264, 0x2265, 0x00A5, 0x00B5, 0x2202, 0x2211,
    0x220F, 0x03C0, 0x222B, 0x00AA, 0x00BA, 0x03A9, 0x00E6, 0x00F8,

    0x00BF, 0x00A1, 0x00AC, 0x221A, 0x0192, 0x2248, 0x2206, 0x00AB,
    0x00BB, 0x2026, 0x00A0, 0x00C0, 0x00C3, 0x00D5, 0x0152, 0x0153,

    0x2013, 0x2014, 0x201C, 0x201D, 0x2018, 0x2019, 0x00F7, 0x25CA,
    0x00FF, 0x0178, 0x2044, 0x20AC, 0x2039, 0x203A, 0xFB01, 0xFB02,

    0x2021, 0x00B7, 0x201A, 0x201E, 0x2030, 0x00C2, 0x00CA, 0x00C1,
    0x00CB, 0x00C8, 0x00CD, 0x00CE, 0x00CF, 0x00CC, 0x00D3, 0x00D4,
    /* xF0 = Apple Logo */
    0xF8FF, 0x00D2, 0x00DA, 0x00DB, 0x00D9, 0x0131, 0x02C6, 0x02DC,
    0x00AF, 0x02D8, 0x02D9, 0x02DA, 0x00B8, 0x02DD, 0x02DB, 0x02C7
};

#ifdef BIF_TIDY
/* Tidy as bif has no inner fatal errors: the only possible "out of memory"
   fatal will be trapped in dk_alloc() */
#else

void FatalError(char *msg)
{
    fprintf(stderr, "Fatal error: %s\n", msg);
    DeInitTidy();

    if (input && input != stdin)
        fclose(input);

    /* 2 signifies a serious error */
    exit(2);
}

#endif

#ifdef BIF_TIDY

void *MemRealloc(void *mem, uint newsize)
{
  void * new = MemAlloc(newsize);
  if (NULL != mem)
    {
      size_t to_copy = box_length ((box_t) mem);
      memcpy (new, mem, to_copy);
    }
  return new;
}

#else

void *MemAlloc(uint size)
{
    void *p;

    p = malloc(size);

    if (!p)
        FatalError("Out of memory!");

    return p;
}

void *MemRealloc(void *mem, uint newsize)
{
    void *p;

    if (mem == (void *)null)
        return MemAlloc(newsize);

    p = realloc(mem, newsize);

    if (!p)
        FatalError("Out of memory!");

    return p;
}

void MemFree(void *mem)
{
    if (mem != (void *)null)
        free(mem);
}

void ClearMemory(void *mem, uint size)
{
    memset(mem, 0, size);
}

#endif

#ifdef BIF_TIDY

StreamIn *OpenInputBoxString(caddr_t html_input)
{
    StreamIn *in;
    in = (StreamIn *)MemAlloc(sizeof(StreamIn));
    ClearMemory(in, sizeof (StreamIn));
    in->input.tio_data.lm_memblock = html_input;
    in->input.tio_data.lm_length = box_length (html_input)-1;
    in->input.tio_pos = 0;
    in->pushed = no;
    in->curline = 1;
    in->curcol = 1;
    in->encoding = CharEncoding;
    in->state = FSM_ASCII;
    return in;
}

#else

StreamIn *OpenInputFile(FILE *fp)
{
    StreamIn *in;

    in = (StreamIn *)MemAlloc(sizeof(StreamIn));
    in->file = fp;
    in->pushed = no;
    in->c = '\0';
    in->tabs = 0;
    in->curline = 1;
    in->curcol = 1;
    in->encoding = CharEncoding;
    in->state = FSM_ASCII;

    return in;
}
#endif

/* read char from stream */
static int ReadCharFromStream(StreamIn *in)
{
    uint n, c, i, count;

#ifdef BIF_TIDY
    if (in->input.tio_pos >= in->input.tio_data.lm_length)
        return -1;
    c = in->input.tio_data.lm_memblock[in->input.tio_pos++];
#else
    if (feof(in->file))
        return -1;
    c = getc(in->file);
#endif

    /*
       A document in ISO-2022 based encoding uses some ESC sequences
       called "designator" to switch character sets. The designators
       defined and used in ISO-2022-JP are:

        "ESC" + "(" + ?     for ISO646 variants

        "ESC" + "$" + ?     and
        "ESC" + "$" + "(" + ?   for multibyte character sets

       Where ? stands for a single character used to indicate the
       character set for multibyte characters.

       Tidy handles this by preserving the escape sequence and
       setting the top bit of each byte for non-ascii chars. This
       bit is then cleared on output. The input stream keeps track
       of the state to determine when to set/clear the bit.
    */
    if (0 == c)
      return c;

    if (in->encoding == ISO2022)
    {
        if (c == 0x1b)  /* ESC */
        {
            in->state = FSM_ESC;
            return c;
        }

        switch (in->state)
        {
        case FSM_ESC:
            if (c == '$')
                in->state = FSM_ESCD;
            else if (c == '(')
                in->state = FSM_ESCP;
            else
                in->state = FSM_ASCII;
            break;

        case FSM_ESCD:
            if (c == '(')
                in->state = FSM_ESCDP;
            else
                in->state = FSM_NONASCII;
            break;

        case FSM_ESCDP:
            in->state = FSM_NONASCII;
            break;

        case FSM_ESCP:
            in->state = FSM_ASCII;
            break;

        case FSM_NONASCII:
            c |= 0x80;
            break;
        }

        return c;
    }

    if (in->encoding != UTF8)
        return c;

    /* deal with UTF-8 encoded char */

    if ((c & 0xE0) == 0xC0)  /* 110X XXXX  two bytes */
    {
        n = c & 31;
        count = 1;
    }
    else if ((c & 0xF0) == 0xE0)  /* 1110 XXXX  three bytes */
    {
        n = c & 15;
        count = 2;
    }
    else if ((c & 0xF8) == 0xF0)  /* 1111 0XXX  four bytes */
    {
        n = c & 7;
        count = 3;
    }
    else if ((c & 0xFC) == 0xF8)  /* 1111 10XX  five bytes */
    {
        n = c & 3;
        count = 4;
    }
    else if ((c & 0xFE) == 0xFC)       /* 1111 110X  six bytes */
    {
        n = c & 1;
        count = 5;
    }
    else  /* 0XXX XXXX one byte */
        return c;

    /* successor bytes should have the form 10XX XXXX */
    for (i = 1; i <= count; ++i)
    {
#ifdef BIF_TIDY
        if (in->input.tio_pos >= in->input.tio_data.lm_length)
          return -1;
        c = in->input.tio_data.lm_memblock[in->input.tio_pos++];
#else
        if (feof(in->file))
            return -1;
        c = getc(in->file);
#endif
        n = (n << 6) | (c & 0x3F);
    }

    return n;
}

int ReadChar(StreamIn *in)
{
    int c;

    if (in->pushed)
    {
        in->pushed = no;
        c =  in->c;

        if (c == '\n')
        {
            in->curcol = 1;
            in->curline++;
            return c;
        }

        in->curcol++;
        return c;
    }

    in->lastcol = in->curcol;

    if (in->tabs > 0)
    {
        in->curcol++;
        in->tabs--;
        return ' ';
    }

    for (;;)
    {
        c = ReadCharFromStream(in);

        if (c < 0)
            return EndOfStream;

        if (c == '\n')
        {
            in->curcol = 1;
            in->curline++;
            break;
        }

        if (c == '\t')
        {
            in->tabs = tabsize - ((in->curcol - 1) % tabsize) - 1;
            in->curcol++;
            c = ' ';
            break;
        }

        /* strip control characters, except for Esc */

        if (c == '\033')
            break;

        if (0 < c && c < 32)
            continue;

        /* watch out for IS02022 */

        if (in->encoding == RAW || in->encoding == ISO2022)
        {
            in->curcol++;
            break;
        }

        if (in->encoding == MACROMAN)
            c = Mac2Unicode[c];

        /* produced e.g. as a side-effect of smart quotes in Word */

        if (127 < c && c < 160)
        {
            ReportEncodingError(in->lexer, WINDOWS_CHARS, c);

            c = Win2Unicode[c - 128];

            if (c == 0)
                continue;
        }

        in->curcol++;
        break;
    }

    return c;
}

void UngetChar(int c, StreamIn *in)
{
    in->pushed = yes;
    in->c = c;

    if (c == '\n')
        --(in->curline);

    in->curcol = in->lastcol;
}

/* like strdup but using MemAlloc */
char *wstrdup(char *str)
{
    char *s, *p;
    int len;

    if (str == null)
        return null;

    for (len = 0; str[len] != '\0'; ++len);

    s = (char *)MemAlloc(sizeof(char)*(1+len));
    for (p = s; (*p++ = *str++););
    return s;
}

/* like strndup but using MemAlloc */
char *wstrndup(char *str, int len)
{
    char *s, *p;

    if (str == null || len < 0)
        return null;

    s = (char *)MemAlloc(sizeof(char)*(1+len));

    p = s;

    while (len-- > 0 && (*p++ = *str++));

    *p = '\0';
    return s;
}

/* exactly same as strncpy */
void wstrncpy(char *s1, char *s2, int size)
{
    if (s1 != null && s2 != null)
    {
        if (size >= 0)
        {
            while (size--)
                *s1++ = *s2++;
        }
        else
            while ((*s1++ = *s2++));
    }
}

void wstrcpy(char *s1, char *s2)
{
    while ((*s1++ = *s2++));
}

void wstrcat(char *s1, char *s2)
{
    while (*s1)
        ++s1;

    while ((*s1++ = *s2++));
}

/* exactly same as strcmp */
int wstrcmp(char *s1, char *s2)
{
    int c;

    while ((c = *s1) == *s2)
    {
        if (c == '\0')
            return 0;

        ++s1;
        ++s2;
    }

    return (*s1 > *s2 ? 1 : -1);
}

/* returns byte count, not char count */
int wstrlen(char *str)
{
    int len = 0;

    while(*str++)
        ++len;

    return len;
}

/*
 MS C 4.2 doesn't include strcasecmp.
 Note that tolower and toupper won't
 work on chars > 127
*/
int wstrcasecmp(char *s1, char *s2)
{
    uint c;

    while (c = (uint)(*s1), ToLower(c) == ToLower((uint)(*s2)))
    {
        if (c == '\0')
            return 0;

        ++s1;
        ++s2;
    }

    return (*s1 > *s2 ? 1 : -1);
}

int wstrncmp(char *s1, char *s2, int n)
{
    int c;

    while ((c = *s1) == *s2)
    {
        if (c == '\0')
            return 0;

        if (n == 0)
            return 0;

        ++s1;
        ++s2;
        --n;
    }

    if (n == 0)
        return 0;

    return (*s1 > *s2 ? 1 : -1);
}

int wstrncasecmp(char *s1, char *s2, int n)
{
    int c;

    while (c = *s1, tolower(c) == tolower(*s2))
    {
        if (c == '\0')
            return 0;

        if (n == 0)
            return 0;

        ++s1;
        ++s2;
        --n;
    }

    if (n == 0)
        return 0;

    return (*s1 > *s2 ? 1 : -1);
}

Bool wsubstr(char *s1, char *s2)
{
    int i, len1 = wstrlen(s1), len2 = wstrlen(s2);

    for (i = 0; i <= len1 - len2; ++i)
    {
        if (wstrncasecmp(s1+i, s2, len2) == 0)
            return yes;
    }

    return no;
}

/* For mac users, should we map Unicode back to MacRoman? */
#ifdef BIF_TIDY
#define outputc(ch) out->tio.tio_data.lm_memblock[out->tio.tio_pos++] = (ch)
#else
#define outputc(ch) putc((ch), out->fp)
#endif

void outc(uint c, Out *out)
{
    uint ch;
    int newlen = out->tio.tio_pos + 0x100;
    if (newlen >= out->tio.tio_data.lm_length)
      {
	caddr_t new_buf;
	newlen *= 2;
        new_buf = dk_alloc (newlen);
	if (0 != out->tio.tio_pos)
	  memcpy (new_buf, out->tio.tio_data.lm_memblock, out->tio.tio_pos);
        if (NULL != out->tio.tio_data.lm_memblock)
	  dk_free (out->tio.tio_data.lm_memblock, out->tio.tio_data.lm_length);
        out->tio.tio_data.lm_memblock = new_buf;
        out->tio.tio_data.lm_length = newlen;
      }

    if (out->encoding == UTF8)
    {
        if (c < 128)
            outputc(c);
        else if (c <= 0x7FF)
        {
            ch = (0xC0 | (c >> 6)); outputc(ch);
            ch = (0x80 | (c & 0x3F)); outputc(ch);
        }
        else if (c <= 0xFFFF)
        {
            ch = (0xE0 | (c >> 12)); outputc(ch);
            ch = (0x80 | ((c >> 6) & 0x3F)); outputc(ch);
            ch = (0x80 | (c & 0x3F)); outputc(ch);
        }
        else if (c <= 0x1FFFFF)
        {
            ch = (0xF0 | (c >> 18)); outputc(ch);
            ch = (0x80 | ((c >> 12) & 0x3F)); outputc(ch);
            ch = (0x80 | ((c >> 6) & 0x3F)); outputc(ch);
            ch = (0x80 | (c & 0x3F)); outputc(ch);
        }
        else
        {
            ch = (0xF8 | (c >> 24)); outputc(ch);
            ch = (0x80 | ((c >> 18) & 0x3F)); outputc(ch);
            ch = (0x80 | ((c >> 12) & 0x3F)); outputc(ch);
            ch = (0x80 | ((c >> 6) & 0x3F)); outputc(ch);
            ch = (0x80 | (c & 0x3F)); outputc(ch);
        }
    }
    else if (out->encoding == ISO2022)
    {
        if (c == 0x1b)  /* ESC */
            out->state = FSM_ESC;
        else
        {
            switch (out->state)
            {
            case FSM_ESC:
                if (c == '$')
                    out->state = FSM_ESCD;
                else if (c == '(')
                    out->state = FSM_ESCP;
                else
                    out->state = FSM_ASCII;
                break;

            case FSM_ESCD:
                if (c == '(')
                    out->state = FSM_ESCDP;
                else
                    out->state = FSM_NONASCII;
                break;

            case FSM_ESCDP:
                out->state = FSM_NONASCII;
                break;

            case FSM_ESCP:
                out->state = FSM_ASCII;
                break;

            case FSM_NONASCII:
                c &= 0x7F;
                break;
            }
        }

        outputc(c);
    }
    else
        outputc(c);
}

#ifdef BIF_TIDY
mem_pool_t *tidy_mp = NULL;
#endif

/*
  first time initialization which should
  precede reading the command line
*/

void InitTidy(void)
{
#ifdef BIF_TIDY
    if (NULL == tidy_mp)
      tidy_mp = mem_pool_alloc();
#endif
    InitMap();
    InitAttrs();
    InitTags();
    InitEntities();
    InitConfig();

    totalerrors = totalwarnings = 0;
    XmlTags = XmlOut = HideEndTags = UpperCaseTags =
    MakeClean = writeback = OnlyErrors = no;

#ifndef BIF_TIDY
    input = null;
    errfile = null;
    errout = stderr;
#ifdef CONFIG_FILE
    ParseConfigFile(CONFIG_FILE);
#endif
#endif
}

/*
  call this when you have finished with tidy
  to free the hash tables and other resources
*/
void DeInitTidy(void)
{
    FreeTags();
    FreeAttrTable();
    FreeEntities();
    FreeConfig();
    FreePrintBuf();
#ifdef BIF_TIDY
    mp_free (tidy_mp);
    tidy_mp = NULL;
#endif
}

#ifdef BIF_TIDY

int do_tidy (caddr_t html_input, caddr_t config_input, caddr_t *html_output)
{
    Node *document, *doctype;
    Lexer *lexer;
    Out out;   /* normal output stream */

    InitTidy();
    out.tio.tio_data.lm_memblock = NULL;
    out.tio.tio_data.lm_length = 0;
    out.tio.tio_pos = 0;

    ParseConfigBoxString (config_input);
    /* ensure config is self-consistent */
    AdjustConfig();

    {
        {
            lexer = NewLexer(OpenInputBoxString(html_input));
            lexer->errout = errout;

            /*
              store pointer to lexer in input stream
              to allow character encoding errors to be
              reported
            */
            lexer->in->lexer = lexer;

            /* Tidy doesn't alter the doctype for generic XML docs */
            if (XmlTags)
                document = ParseXMLDocument(lexer);
            else
            {
                lexer->warnings = 0;

                document = ParseDocument(lexer);

                if (!CheckNodeIntegrity(document))
                {
                    fprintf(stderr, "\nPanic - tree has lost its integrity\n");
                    exit(1);
                }

                /* simplifies <b><b> ... </b> ...</b> etc. */
                NestedEmphasis(document);

                /* cleans up <dir>indented text</dir> etc. */
                List2BQ(document);
                BQ2Div(document);

                /* replaces i by em and b by strong */
                if (LogicalEmphasis)
                    EmFromI(document);

                if (Word2000 && IsWord2000(document))
                {
                    /* prune Word2000's <![if ...]> ... <![endif]> */
                    DropSections(lexer, document);

                    /* drop style & class attributes and empty p, span elements */
                    CleanWord2000(lexer, document);
                }

                /* replaces presentational markup by style rules */
                if (MakeClean || DropFontTags)
                    CleanTree(lexer, document);

                if (!CheckNodeIntegrity(document))
                {
                    fprintf(stderr, "\nPanic - tree has lost its integrity\n");
                    exit(1);
                }

                doctype = FindDocType(document);

                if (document->content)
                {
                    if (xHTML)
                        SetXHTMLDocType(lexer, document);
                    else
                        FixDocType(lexer, document);

                    if (TidyMark)
                        AddGenerator(lexer, document);
                }

                /* ensure presence of initial <?XML version="1.0"?> */
                if (XmlOut && XmlPi)
                    FixXMLPI(lexer, document);

                totalwarnings += lexer->warnings;
                totalerrors += lexer->errors;

                if (!Quiet && document->content)
                {
                    ReportVersion4bif(errout, lexer, doctype);
                    ReportNumWarnings(errout, lexer);
                }
            }

            MemFree(lexer->in);

            if (lexer->errors > 0)
                NeedsAuthorIntervention(errout);

            out.state = FSM_ASCII;
            out.encoding = CharEncoding;

            if ((NULL != html_output) && (!OnlyErrors && lexer->errors == 0))
            {
                {
                    if (XmlTags)
                        PPrintXMLTree(&out, null, 0, lexer, document);
                    else
                        PPrintTree(&out, null, 0, lexer, document);
                    PFlushLine(&out, 0);
                }
            }

            ErrorSummary(lexer);
            FreeNode(document);
            FreeLexer(lexer);
        }
    }

    if (totalerrors + totalwarnings > 0)
        GeneralInfo(errout);

    /* called to free hash tables etc. */
    DeInitTidy();

    if (NULL != html_output)
      html_output[0] = box_dv_short_nchars (out.tio.tio_data.lm_memblock, out.tio.tio_pos);
    if (NULL != out.tio.tio_data.lm_memblock)
      dk_free (out.tio.tio_data.lm_memblock, -1);
    /* return status can be used by scripts */

    if (totalerrors > 0)
        return 2;

    if (totalwarnings > 0)
        return 1;

    /* 0 signifies all is ok */
    return 0;
}

#else

int main(int argc, char **argv)
{
    char *file, *prog;
    Node *document, *doctype;
    Lexer *lexer;
    char *s, c, *arg, *current_errorfile = "stderr";
    Out out;   /* normal output stream */

#if PRESERVEFILETIMES
    struct utimbuf filetimes;
    struct stat sbuf;
#endif
    Bool haveFileTimes;

    InitTidy();

    /* look for env var "HTML_TIDY" */
    /* then for ~/.tidyrc (on Unix) */

    if ((file = getenv("HTML_TIDY")))
        ParseConfigFile(file);
#ifdef SUPPORT_GETPWNAM
    else
        ParseConfigFile("~/.tidyrc");
#endif /* SUPPORT_GETPWNAM */

    /* read command line */

    prog = argv[0];

    while (argc > 0)
    {
        if (argc > 1 && argv[1][0] == '-')
        {
            /* support -foo and --foo */
            arg = argv[1] + 1;
#if 0
            if (arg[0] == '-')
                ++arg;
#endif
            if (strcmp(arg, "indent") == 0)
                IndentContent = yes;
            else if (strcmp(arg, "xml") == 0)
                XmlTags = yes;
            else if (strcmp(arg, "asxml") == 0 || strcmp(arg, "asxhtml") == 0)
                xHTML = yes;
            else if (strcmp(arg, "indent") == 0)
            {
                IndentContent = yes;
                SmartIndent = yes;
            }
            else if (strcmp(arg, "omit") == 0)
                HideEndTags = yes;
            else if (strcmp(arg, "upper") == 0)
                UpperCaseTags = yes;
            else if (strcmp(arg, "clean") == 0)
                MakeClean = yes;
            else if (strcmp(arg, "raw") == 0)
                CharEncoding = RAW;
            else if (strcmp(arg, "ascii") == 0)
                CharEncoding = ASCII;
            else if (strcmp(arg, "latin1") == 0)
                CharEncoding = LATIN1;
            else if (strcmp(arg, "utf8") == 0)
                CharEncoding = UTF8;
            else if (strcmp(arg, "iso2022") == 0)
                CharEncoding = ISO2022;
            else if (strcmp(arg, "mac") == 0)
                CharEncoding = MACROMAN;
            else if (strcmp(arg, "numeric") == 0)
                NumEntities = yes;
            else if (strcmp(arg, "modify") == 0)
                writeback = yes;
            else if (strcmp(arg, "change") == 0)  /* obsolete */
                writeback = yes;
            else if (strcmp(arg, "update") == 0)  /* obsolete */
                writeback = yes;
            else if (strcmp(arg, "errors") == 0)
                OnlyErrors = yes;
            else if (strcmp(arg, "quiet") == 0)
                Quiet = yes;
            else if (strcmp(arg, "slides") == 0)
                BurstSlides = yes;
            else if (strcmp(arg, "help") == 0 ||
                     argv[1][1] == '?'|| argv[1][1] == 'h')
            {
                HelpText(stdout, prog);
                return 1;
            }
            else if (strcmp(arg, "config") == 0)
            {
                if (argc >= 3)
                {
                    ParseConfigFile(argv[2]);
                    --argc;
                    ++argv;
                }
            }
            else if (strcmp(argv[1], "-file") == 0 ||
                     strcmp(argv[1], "--file") == 0 ||
                        strcmp(argv[1], "-f") == 0)
            {
                if (argc >= 3)
                {
                    /* create copy that can be freed by FreeConfig() */
                    errfile = wstrdup(argv[2]);
                    --argc;
                    ++argv;
                }
            }
            else if (strcmp(argv[1], "-wrap") == 0 ||
                        strcmp(argv[1], "--wrap") == 0 ||
                        strcmp(argv[1], "-w") == 0)
            {
                if (argc >= 3)
                {
                    sscanf(argv[2], "%d", &wraplen);
                    --argc;
                    ++argv;
                }
            }
            else if (strcmp(argv[1], "-version") == 0 ||
                        strcmp(argv[1], "--version") == 0 ||
                        strcmp(argv[1], "-v") == 0)
            {
                ShowVersion(errout);
                /* called to free hash tables etc. */
                DeInitTidy();
                return 0;

            }
            else if(strncmp(argv[1],"--",2)==0)
            {
                if (ParseConfig(argv[1]+2, argv[2]))
                {
                    ++argv;
                    --argc;
                }
            }
            else
            {
                s = argv[1];

                while ((c = *++s))
                {
                    if (c == 'i')
                    {
                        IndentContent = yes;
                        SmartIndent = yes;
                    }
                    else if (c == 'o')
                        HideEndTags = yes;
                    else if (c == 'u')
                        UpperCaseTags = yes;
                    else if (c == 'c')
                        MakeClean = yes;
                    else if (c == 'n')
                        NumEntities = yes;
                    else if (c == 'm')
                        writeback = yes;
                    else if (c == 'e')
                        OnlyErrors = yes;
                    else if (c == 'q')
                        Quiet = yes;
                    else
                        UnknownOption(stderr, c);
                }
            }

            --argc;
            ++argv;
            continue;
        }

        /* ensure config is self-consistent */
        AdjustConfig();

        /* user specified error file */
        if (errfile)
        {
            FILE *fp;

            /* is it same as the currently opened file? */
            if (wstrcmp(errfile, current_errorfile) != 0)
            {
                /* no so close previous error file */

                if (errout != stderr)
                    fclose(errout);

                /* and try to open the new error file */
                fp = fopen(errfile, "w");

                if (fp != null)
                {
                    errout = fp;
                    current_errorfile = errfile;
                }
                else /* can't be opened so fall back to stderr */
                {
                    errout = stderr;
                    current_errorfile = "stderr";
                }
            }
        }

        haveFileTimes = no;

        if (argc > 1)
        {
            file = argv[1];
            input = fopen(file, "r");

#if PRESERVEFILETIMES
            /* get last modified time */
            if (KeepFileTimes && input && fstat(fileno(input), &sbuf) != -1)
            {
                filetimes.actime = sbuf.st_atime;
                filetimes.modtime = sbuf.st_mtime;
                haveFileTimes = yes;
            }
#endif
        }
        else
        {
            input = stdin;
            file = "stdin";
        }

        if (input != null)
        {
            lexer = NewLexer(OpenInput(input));
            lexer->errout = errout;

            /*
              store pointer to lexer in input stream
              to allow character encoding errors to be
              reported
            */
            lexer->in->lexer = lexer;

            /* Tidy doesn't alter the doctype for generic XML docs */
            if (XmlTags)
                document = ParseXMLDocument(lexer);
            else
            {
                lexer->warnings = 0;

                if (!Quiet)
                    HelloMessage(errout, release_date, file);

                document = ParseDocument(lexer);

                if (!CheckNodeIntegrity(document))
                {
                    fprintf(stderr, "\nPanic - tree has lost its integrity\n");
                    exit(1);
                }

                /* simplifies <b><b> ... </b> ...</b> etc. */
                NestedEmphasis(document);

                /* cleans up <dir>indented text</dir> etc. */
                List2BQ(document);
                BQ2Div(document);

                /* replaces i by em and b by strong */
                if (LogicalEmphasis)
                    EmFromI(document);

                if (Word2000 && IsWord2000(document))
                {
                    /* prune Word2000's <![if ...]> ... <![endif]> */
                    DropSections(lexer, document);

                    /* drop style & class attributes and empty p, span elements */
                    CleanWord2000(lexer, document);
                }

                /* replaces presentational markup by style rules */
                if (MakeClean || DropFontTags)
                    CleanTree(lexer, document);

                if (!CheckNodeIntegrity(document))
                {
                    fprintf(stderr, "\nPanic - tree has lost its integrity\n");
                    exit(1);
                }

                doctype = FindDocType(document);

                if (document->content)
                {
                    if (xHTML)
                        SetXHTMLDocType(lexer, document);
                    else
                        FixDocType(lexer, document);

                    if (TidyMark)
                        AddGenerator(lexer, document);
                }

                /* ensure presence of initial <?XML version="1.0"?> */
                if (XmlOut && XmlPi)
                    FixXMLPI(lexer, document);

                totalwarnings += lexer->warnings;
                totalerrors += lexer->errors;

                if (!Quiet && document->content)
                {
                    ReportVersion(errout, lexer, file, doctype);
                    ReportNumWarnings(errout, lexer);
                }
            }

            if (input != stdin)
            {
                fclose(input);
            }

            MemFree(lexer->in);

            if (lexer->errors > 0)
                NeedsAuthorIntervention(errout);

            out.state = FSM_ASCII;
            out.encoding = CharEncoding;

            if (!OnlyErrors && lexer->errors == 0)
            {
                if (BurstSlides)
                {
                    Node *body, *doctype;

                    /*
                       remove doctype to avoid potential clash with
                       markup introduced when bursting into slides
                    */
                    /* discard the document type */
                    doctype = FindDocType(document);

                    if (doctype)
                        DiscardElement(doctype);

                    /* slides use transitional features */
                    lexer->versions |= VERS_HTML40_LOOSE;

                    /* and patch up doctype to match */
                    if (xHTML)
                        SetXHTMLDocType(lexer, document);
                    else
                        FixDocType(lexer, document);


                    /* find the body element which may be implicit */
                    body = FindBody(document);

                    if (body)
                    {
                        ReportNumberOfSlides(errout, CountSlides(body));
                        CreateSlides(lexer, document);
                    }
                    else
                        MissingBody(errout);
                }
                else if (writeback && (input = fopen(file, "w")))
                {
                    out.fp = input;

                    if (XmlTags)
                        PPrintXMLTree(&out, null, 0, lexer, document);
                    else
                        PPrintTree(&out, null, 0, lexer, document);

                    PFlushLine(&out, 0);

#if PRESERVEFILETIMES
                    /* set file last accessed/modified times to original values */
                    if (haveFileTimes)
                        futime(fileno(input), &filetimes);
#endif
                    fclose(input);
                }
                else
                {
                    out.fp = stdout;

                    if (XmlTags)
                        PPrintXMLTree(&out, null, 0, lexer, document);
                    else
                        PPrintTree(&out, null, 0, lexer, document);

                    PFlushLine(&out, 0);
                }

            }

            ErrorSummary(lexer);
            FreeNode(document);
            FreeLexer(lexer);
        }
        else
            UnknownFile(errout, prog, file);

        --argc;
        ++argv;

        if (argc <= 1)
            break;
    }

    if (totalerrors + totalwarnings > 0)
        GeneralInfo(errout);

    if (errout != stderr)
        fclose(errout);

    /* called to free hash tables etc. */
    DeInitTidy();

    /* return status can be used by scripts */

    if (totalerrors > 0)
        return 2;

    if (totalwarnings > 0)
        return 1;

    /* 0 signifies all is ok */
    return 0;
}

#endif
