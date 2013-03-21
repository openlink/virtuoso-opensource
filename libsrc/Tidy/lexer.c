/*
 *  $Id$
 *
 *  lexer.c - Lexer for html parser
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

/*
  Given a file stream fp it returns a sequence of tokens.

     GetToken(fp) gets the next token
     UngetToken(fp) provides one level undo

  The tags include an attribute list:

    - linked list of attribute/value nodes
    - each node has 2 null-terminated strings.
    - entities are replaced in attribute values

  white space is compacted if not in preformatted mode
  If not in preformatted mode then leading white space
  is discarded and subsequent white space sequences
  compacted to single space chars.

  If XmlTags is no then Tag names are folded to upper
  case and attribute names to lower case.

 Not yet done:
    -   Doctype subset and marked sections
*/

#include "platform.h"
#include "html.h"

AttVal *ParseAttrs(Lexer *lexer, Bool *isempty);  /* forward references */
Node *CommentToken(Lexer *lexer);

/* used to classify chars for lexical purposes */
#define MAP(c) ((unsigned)c < 128 ? lexmap[(unsigned)c] : 0)
uint lexmap[128];

#define XHTML_NAMESPACE "http://www.w3.org/1999/xhtml"

/* the 3 URIs  for the XHTML 1.0 DTDs */
#define voyager_loose    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
#define voyager_strict   "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"
#define voyager_frameset "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd"

#define W3C_VERSIONS 8

struct _vers
{
    char *name;
    char *voyager_name;
    char *profile;
    int code;
} W3C_Version[] =
{
    {"HTML 4.01", "XHTML 1.0 Strict", voyager_strict, VERS_HTML40_STRICT},
    {"HTML 4.01 Transitional", "XHTML 1.0 Transitional", voyager_loose, VERS_HTML40_LOOSE},
    {"HTML 4.01 Frameset", "XHTML 1.0 Frameset", voyager_frameset, VERS_FRAMES},
    {"HTML 4.0", "XHTML 1.0 Strict", voyager_strict, VERS_HTML40_STRICT},
    {"HTML 4.0 Transitional", "XHTML 1.0 Transitional", voyager_loose, VERS_HTML40_LOOSE},
    {"HTML 4.0 Frameset", "XHTML 1.0 Frameset", voyager_frameset, VERS_FRAMES},
    {"HTML 3.2", "XHTML 1.0 Transitional", voyager_loose, VERS_HTML32},
    {"HTML 2.0", "XHTML 1.0 Strict", voyager_strict, VERS_HTML20}
};

Bool IsWhite(uint c)
{
    uint map = MAP(c);

    return (Bool)(map & white);
}

Bool IsDigit(uint c)
{
    uint map;

    map = MAP(c);

    return (Bool)(map & digit);
}

Bool IsLetter(uint c)
{
    uint map;

    map = MAP(c);

    return (Bool)(map & letter);
}

uint ToLower(uint c)
{
    uint map = MAP(c);

    if (map & uppercase)
        c += 'a' - 'A';

    return c;
}

uint ToUpper(uint c)
{
    uint map = MAP(c);

    if (map & lowercase)
        c += 'A' - 'a';

    return c;
}

char FoldCase(char c, Bool tocaps)
{
    uint map;

    if (!XmlTags)
    {
        map = MAP(c);

        if (tocaps)
        {
            if (map & lowercase)
                c += 'A' - 'a';
        }
        else /* force to lower case */
        {
            if (map & uppercase)
                c += 'a' - 'A';
        }
    }

    return c;
}


/*
   node->type is one of these:

    #define TextNode    1
    #define StartTag    2
    #define EndTag      3
    #define StartEndTag 4
*/
Lexer *NewLexer(StreamIn *in)
{
    Lexer *lexer;

    lexer = (Lexer *)MemAlloc(sizeof(Lexer));
        ClearMemory (lexer, sizeof (Lexer));
        lexer->in = in;
        lexer->lines = 1;
        lexer->columns = 1;
        lexer->state = LEX_CONTENT;
        lexer->badAccess = 0;
        lexer->badLayout = 0;
        lexer->badChars = 0;
        lexer->badForm = 0;
        lexer->warnings = 0;
        lexer->errors = no;
        lexer->waswhite = no;
        lexer->pushed = no;
        lexer->insertspace = no;
        lexer->exiled = no;
        lexer->isvoyager = no;
        lexer->versions = VERS_EVERYTHING;
        lexer->doctype = VERS_UNKNOWN;
        lexer->bad_doctype = no;
        lexer->txtstart = 0;
        lexer->txtend = 0;
        lexer->token = null;
        lexer->lexbuf =  null;
        lexer->lexlength = 0;
        lexer->lexsize = 0;
        lexer->inode = null;
        lexer->insert = null;
        lexer->istack = null;
        lexer->istacklength = 0;
        lexer->istacksize = 0;
        lexer->istackbase = 0;
        lexer->styles = null;
    return lexer;
}

#ifdef BIF_TIDY

Bool EndOfInput(Lexer *lexer)
{
    tidy_io_t *tio = &(lexer->in->input);
    return (tio->tio_pos >= tio->tio_data.lm_length);
}

#else

Bool EndOfInput(Lexer *lexer)
{
    return  (feof(lexer->in->file));
}

#endif

void FreeLexer(Lexer *lexer)
{
    if (lexer->pushed)
        FreeNode(lexer->token);

    if (lexer->lexbuf != null)
        MemFree(lexer->lexbuf);

    while (lexer->istacksize > 0)
        PopInline(lexer, null);

    if (lexer->istack)
        MemFree(lexer->istack);

    if (lexer->styles)
        FreeStyles(lexer);

    MemFree(lexer);
}

static void AddByte(Lexer *lexer, uint c)
{
    if (lexer->lexsize + 1 >= lexer->lexlength)
    {
        while (lexer->lexsize + 1 >= lexer->lexlength)
        {
            if (lexer->lexlength == 0)
                lexer->lexlength = 8192;
            else
                lexer->lexlength = lexer->lexlength * 2;
        }

        lexer->lexbuf = (char *)MemRealloc(lexer->lexbuf, lexer->lexlength*sizeof(char));
    }

    lexer->lexbuf[lexer->lexsize++] = (char)c;
    lexer->lexbuf[lexer->lexsize] = '\0';  /* debug */
}

static void ChangeChar(Lexer *lexer, char c)
{
    if (lexer->lexsize > 0)
    {
        lexer->lexbuf[lexer->lexsize-1] = c;
    }
}

/* store char c as UTF-8 encoded byte stream */
void AddCharToLexer(Lexer *lexer, uint c)
{
    if (c < 128)
        AddByte(lexer, c);
    else if (c <= 0x7FF)
    {
        AddByte(lexer, 0xC0 | (c >> 6));
        AddByte(lexer, 0x80 | (c & 0x3F));
    }
    else if (c <= 0xFFFF)
    {
        AddByte(lexer, 0xE0 | (c >> 12));
        AddByte(lexer, 0x80 | ((c >> 6) & 0x3F));
        AddByte(lexer, 0x80 | (c & 0x3F));
    }
    else if (c <= 0x1FFFFF)
    {
        AddByte(lexer, 0xF0 | (c >> 18));
        AddByte(lexer, 0x80 | ((c >> 12) & 0x3F));
        AddByte(lexer, 0x80 | ((c >> 6) & 0x3F));
        AddByte(lexer, 0x80 | (c & 0x3F));
    }
    else
    {
        AddByte(lexer, 0xF8 | (c >> 24));
        AddByte(lexer, 0x80 | ((c >> 18) & 0x3F));
        AddByte(lexer, 0x80 | ((c >> 12) & 0x3F));
        AddByte(lexer, 0x80 | ((c >> 6) & 0x3F));
        AddByte(lexer, 0x80 | (c & 0x3F));
    }
}

static void AddStringToLexer(Lexer *lexer, char *str)
{
    uint c;

    while((c = *str++))
        AddCharToLexer(lexer, c);
}

/*
  No longer attempts to insert missing ';' for unknown
  enitities unless one was present already, since this
  gives unexpected results.

  For example:   <a href="something.htm?foo&bar&fred">
  was tidied to: <a href="something.htm?foo&amp;bar;&amp;fred;">
  rather than:   <a href="something.htm?foo&amp;bar&amp;fred">

  My thanks for Maurice Buxton for spotting this.
*/
static void ParseEntity(Lexer *lexer, int mode)
{
    uint start, map;
    Bool first = yes, semicolon = no;
    int c, ch, startcol;

    start = lexer->lexsize - 1;  /* to start at "&" */
    startcol = lexer->in->curcol - 1;

    while ((c = ReadChar(lexer->in)) != EndOfStream)
    {
        if (c == ';')
        {
            semicolon = yes;
            break;
        }

        if (first && c == '#')
        {
            AddCharToLexer(lexer, c);
            first = no;
            continue;
        }

        first = no;
        map = MAP(c);

        if (map & namechar)
        {
            AddCharToLexer(lexer, c);
            continue;
        }

        /* otherwise put it back */

        UngetChar(c, lexer->in);
        break;
    }

    /* make sure entity is null terminated */
    lexer->lexbuf[lexer->lexsize] = '\0';

    ch = EntityCode(lexer->lexbuf+start);

    /* deal with unrecognized entities */
    if (ch <= 0)
    {
        /* set error position just before offending chararcter */
        lexer->lines = lexer->in->curline;
        lexer->columns = startcol;

        if (lexer->lexsize > start +1 )
        {
            ReportEntityError(lexer, UNKNOWN_ENTITY, lexer->lexbuf+start, ch);

            if (semicolon)
                AddCharToLexer(lexer, ';');
        }
        else /* naked & */
            ReportEntityError(lexer, UNESCAPED_AMPERSAND, lexer->lexbuf+start, ch);
    }
    else
    {
        if (c != ';')    /* issue warning if not terminated by ';' */
        {
            /* set error position just before offending chararcter */
            lexer->lines = lexer->in->curline;
            lexer->columns = startcol;
            ReportEntityError(lexer, MISSING_SEMICOLON, lexer->lexbuf+start, c);
        }

        lexer->lexsize = start;

        if (ch == 160 && (mode & Preformatted))
            ch = ' ';

        AddCharToLexer(lexer, ch);

        if (ch == '&' && !QuoteAmpersand)
        {
            AddCharToLexer(lexer, 'a');
            AddCharToLexer(lexer, 'm');
            AddCharToLexer(lexer, 'p');
            AddCharToLexer(lexer, ';');
        }
    }
}

static char ParseTagName(Lexer *lexer)
{
    int map;
    uint c;

    /* fold case of first char in buffer */

    c = lexer->lexbuf[lexer->txtstart];
    map = MAP(c);

    if (!XmlTags && (map & uppercase) != 0)
    {
        c -= (uint)('A' - 'a');
        lexer->lexbuf[lexer->txtstart] = c;
    }

    while ((c = ReadChar(lexer->in)) != EndOfStream)
    {
        map = MAP(c);

        if ((map & namechar) == 0)
            break;

       /* fold case of subsequent chars */

       if (!XmlTags && (map & uppercase) != 0)
            c -= (uint)('A' - 'a');

       AddCharToLexer(lexer, c);
    }

    lexer->txtend = lexer->lexsize;
    return c;
}

/*
  Used for elements and text nodes
  element name is null for text nodes
  start and end are offsets into lexbuf
  which contains the textual content of
  all elements in the parse tree.

  parent and content allow traversal
  of the parse tree in any direction.
  attributes are represented as a linked
  list of AttVal nodes which hold the
  strings for attribute/value pairs.
*/
Node *NewNode(void)
{
    Node *node;

    node = (Node *)MemAlloc(sizeof(Node));
    ClearMemory (node, sizeof (Node));
    node->type = TextNode;
    return node;
}

/* used to clone heading nodes when split by an <HR> */
Node *CloneNode(Lexer *lexer, Node *element)
{
    Node *node;

    node = NewNode();
    node->parent = element->parent;
    node->start = lexer->lexsize;
    node->end = lexer->lexsize;
    node->type = element->type;
    node->closed = element->closed;
    node->implicit = element->implicit;
    node->tag = element->tag;
    node->element = wstrdup(element->element);
    node->attributes = DupAttrs(element->attributes);
    return node;
}

/* free node's attributes */
void FreeAttrs(Node *node)
{
    AttVal *av;

    while (node->attributes)
    {
        av = node->attributes;

        if (av->attribute)
            MemFree(av->attribute);
        if (av->value)
            MemFree(av->value);

        node->attributes = av->next;
        MemFree(av);
    }
}

/* doesn't repair attribute list linkage */
void FreeAttribute(AttVal *av)
{
    if (av->attribute)
        MemFree(av->attribute);
    if (av->value)
        MemFree(av->value);

    MemFree(av);
}

/* remove attribute from node then free it */
void RemoveAttribute(Node *node, AttVal *attr)
{
    AttVal *av, *prev = null, *next;

    for (av = node->attributes; av != null; av = next)
    {
        next = av->next;

        if (av == attr)
        {
            if (prev)
                prev->next = next;
            else
                node->attributes = next;
        }
        else
            prev = av;
    }

    FreeAttribute(attr);
}

/*
  Free document nodes by iterating through peers and recursing
  through children. Set next to null before calling FreeNode()
  to avoid freeing peer nodes. Doesn't patch up prev/next links.
 */
void FreeNode(Node *node)
{
    AttVal *av;
    Node *next;

    while (node)
    {
        while (node->attributes)
        {
            av = node->attributes;

            if (av->attribute)
                MemFree(av->attribute);
            if (av->value)
                MemFree(av->value);

            node->attributes = av->next;
            MemFree(av);
        }

        if (node->element)
            MemFree(node->element);

        if (node->content)
            FreeNode(node->content);

        if (node->next)
        {
            next = node->next;
            MemFree(node);
            node = next;
            continue;
        }

        node->element = null;
        node->tag = null;

#if 0
        if (_msize(node) != sizeof (Node)) /* debug */
            fprintf(stderr,
            "Error in FreeNode() - trying to free corrupted node size %d vs %d\n",
                _msize(node), sizeof(Node));
#endif
        MemFree(node);
        break;
    }
}

Node *TextToken(Lexer *lexer)
{
    Node *node;

    node = NewNode();
    node->start = lexer->txtstart;
    node->end = lexer->txtend;
    return node;
}

/* used for creating preformatted text from Word2000 */
Node *NewLineNode(Lexer *lexer)
{
    Node *node = NewNode();

    node->start = lexer->lexsize;
    AddCharToLexer(lexer, (uint)'\n');
    node->end = lexer->lexsize;
    return node;
}

static Node *TagToken(Lexer *lexer, uint type)
{
    Node *node;

    node = NewNode();
    node->type = type;
    node->element = wstrndup(lexer->lexbuf + lexer->txtstart,
                        lexer->txtend - lexer->txtstart);
    node->start = lexer->txtstart;
    node->end = lexer->txtstart;

    if (type == StartTag || type == StartEndTag || type == EndTag)
        FindTag(node);

    return node;
}

Node *CommentToken(Lexer *lexer)
{
    Node *node;

    node = NewNode();
    node->type = CommentTag;
    node->start = lexer->txtstart;
    node->end = lexer->txtend;
    return node;
}


static Node *DocTypeToken(Lexer *lexer)
{
    Node *node;

    node = NewNode();
    node->type = DocTypeTag;
    node->start = lexer->txtstart;
    node->end = lexer->txtend;
    return node;
}


static Node *PIToken(Lexer *lexer)
{
    Node *node;

    node = NewNode();
    node->type = ProcInsTag;
    node->start = lexer->txtstart;
    node->end = lexer->txtend;
    return node;
}

static Node *AspToken(Lexer *lexer)
{
    Node *node;

    node = NewNode();
    node->type = AspTag;
    node->start = lexer->txtstart;
    node->end = lexer->txtend;
    return node;
}

static Node *JsteToken(Lexer *lexer)
{
    Node *node;

    node = NewNode();
    node->type = JsteTag;
    node->start = lexer->txtstart;
    node->end = lexer->txtend;
    return node;
}

/* Added by Baruch Even - handle PHP code too. */
static Node *PhpToken(Lexer *lexer)
{
    Node *node;

    node = NewNode();
    node->type = PhpTag;
    node->start = lexer->txtstart;
    node->end = lexer->txtend;
    return node;
}

/* Word2000 uses <![if ... ]> and <![endif]> */
static Node *SectionToken(Lexer *lexer)
{
    Node *node;

    node = NewNode();
    node->type = SectionTag;
    node->start = lexer->txtstart;
    node->end = lexer->txtend;
    return node;
}

/* CDATA uses <![CDATA[ ... ]]> */
static Node *CDATAToken(Lexer *lexer)
{
    Node *node;

    node = NewNode();
    node->type = CDATATag;
    node->start = lexer->txtstart;
    node->end = lexer->txtend;
    return node;
}

void AddStringLiteral(Lexer *lexer, char *str)
{
    unsigned char c;

    while((c = *str++) != '\0')
        AddCharToLexer(lexer, c);
}

/* find doctype element */
Node *FindDocType(Node *root)
{
    Node *node;

    for (node = root->content;
            node && node->type != DocTypeTag; node = node->next);

    return node;
}

/* find html element */
Node *FindHTML(Node *root)
{
    Node *node;

    for (node = root->content;
            node && node->tag != tag_html; node = node->next);

    return node;
}

Node *FindHEAD(Node *root)
{
    Node *node;

    node = FindHTML(root);

    if (node)
    {
        for (node = node->content;
            node && node->tag != tag_head; node = node->next);
    }

    return node;
}

/* add meta element for Tidy */
Bool AddGenerator(Lexer *lexer, Node *root)
{
    AttVal *attval;
    Node *node;
    Node *head = FindHEAD(root);

    if (head)
    {
        for (node = head->content; node; node = node->next)
        {
            if (node->tag == tag_meta)
            {
                attval = GetAttrByName(node, "name");

                if (attval && attval->value &&
                    wstrcasecmp(attval->value, "generator") == 0)
                {
                    attval = GetAttrByName(node, "content");

                    if (attval && attval->value &&
                        wstrncasecmp(attval->value, "HTML Tidy", 9) == 0)
                    {
                        return no;
                    }
                }
            }
        }

        node = InferredTag(lexer, "meta");
        AddAttribute(node, "content", "HTML Tidy, see www.w3.org");
        AddAttribute(node, "name", "generator");
        InsertNodeAtStart(head, node);
        return yes;
    }

    return no;
}

/* examine <!DOCTYPE> to identify version */
static int FindGivenVersion(Lexer *lexer, Node *doctype)
{
    char *p, *s = lexer->lexbuf+doctype->start;
    uint i, j;
    int len;

    /* if root tag for doctype isn't html give up now */
    if (wstrncasecmp(s, "html ", 5) != 0)
        return 0;

    s += 5; /* if all is well s -> SYSTEM or PUBLIC */

    if  (!CheckDocTypeKeyWords(lexer, doctype))
            ReportWarning(lexer, doctype, null, DTYPE_NOT_UPPER_CASE);


   /* give up if all we are given is the system id for the doctype */
    if (wstrncasecmp(s, "SYSTEM ", 7) == 0)
    {
            /* but at least ensure the case is correct */
        if (wstrncmp(s, "SYSTEM", 6) != 0)
            memcpy(s, "SYSTEM", 6);

        return 0;  /* unrecognized */
    }

    if (wstrncasecmp(s, "PUBLIC ", 7) == 0)
    {
        if (wstrncmp(s, "PUBLIC", 6) != 0)
            memcpy(s, "PUBLIC", 6);
    }
    else
        lexer->bad_doctype = yes;

    for (i = doctype->start; i < doctype->end; ++i)
    {
        if (lexer->lexbuf[i] == '"')
        {
            if (wstrncmp(lexer->lexbuf+i+1, "-//W3C//DTD ", 12) == 0)
            {
                p = lexer->lexbuf + i + 13;

                /* compute length of identifier e.g. "HTML 4.0 Transitional" */
                for (j = i + 13; j < doctype->end && lexer->lexbuf[j] != '/'; ++j);
                len = j - i - 13;

                for (j = 1; j < W3C_VERSIONS; ++j)
                {
                    s = W3C_Version[j].name;
                    if (len == wstrlen(s) && wstrncmp(p, s, len) == 0)
                        return W3C_Version[j].code;
                }

                /* else unrecognized version */
            }
            else if (wstrncmp(lexer->lexbuf+i+1, "-//IETF//DTD ", 13) == 0)
            {
                p = lexer->lexbuf + i + 14;

                /* compute length of identifier e.g. "HTML 2.0" */
                for (j = i + 14; j < doctype->end && lexer->lexbuf[j] != '/'; ++j);
                len = j - i - 14;

                s = W3C_Version[0].name;
                if (len == wstrlen(s) && wstrncmp(p, s, len) == 0)
                    return W3C_Version[0].code;

                /* else unrecognized version */
            }
            break;
        }
    }

    return 0;
}

/* return true if substring s is in p and isn't all in upper case */
/* this is used to check the case of SYSTEM, PUBLIC, DTD and EN */
/* len is how many chars to check in p */
static Bool FindBadSubString(char *s, char *p, int len)
{
    int n = wstrlen(s);

    while (n < len)
    {
        if (wstrncasecmp(s, p, n) == 0)
            return (wstrncmp(s, p, n) != 0);

        ++p;
        --len;
    }

    return 0;
}

Bool CheckDocTypeKeyWords(Lexer *lexer, Node *doctype)
{
    char *s = lexer->lexbuf+doctype->start;
    int len = doctype->end - doctype->start;

    return !(
        FindBadSubString("SYSTEM", s, len) ||
        FindBadSubString("PUBLIC", s, len) ||
        FindBadSubString("//DTD", s, len) ||
        FindBadSubString("//W3C", s, len) ||
        FindBadSubString("//EN", s, len)
        );
}

char *HTMLVersionName(Lexer *lexer)
{
    int guessed, j;

    guessed = ApparentVersion(lexer);

    for (j = 0; j < W3C_VERSIONS; ++j)
    {
        if (guessed == W3C_Version[j].code)
        {
            if (lexer->isvoyager)
                return W3C_Version[j].voyager_name;

            return W3C_Version[j].name;
        }
    }

    return null;
}

static void FixHTMLNameSpace(Lexer *lexer, Node *root, char *profile)
{
    Node *node;
    AttVal *prev, *attr;

    for (node = root->content;
            node && node->tag != tag_html; node = node->next);

    if (node)
    {
        prev = null;

        for (attr = node->attributes; attr; attr = attr->next)
        {
            if (wstrcmp(attr->attribute, "xmlns") == 0)
                break;

            prev = attr;
        }

        if (attr)
        {
            if (wstrcmp(attr->value, profile))
            {
                ReportWarning(lexer, node, null, INCONSISTENT_NAMESPACE);
                MemFree(attr->value);
                attr->value = wstrdup(profile);
            }
        }
        else
        {
            attr = NewAttribute();
            attr->delim = '"';
            attr->attribute = wstrdup("xmlns");
            attr->value = wstrdup(profile);
            attr->dict = FindAttribute(attr);
            attr->next = node->attributes;
            node->attributes = attr;
        }
    }
}

Bool SetXHTMLDocType(Lexer *lexer, Node *root)
{
    char *fpi = NULL, *sysid = NULL, *name_space = XHTML_NAMESPACE;
    Node *doctype;

    doctype = FindDocType(root);

    if (doctype_mode == doctype_omit)
    {
        if (doctype)
            DiscardElement(doctype);

        return yes;
    }

    if (doctype_mode == doctype_auto)
    {
        /* see what flavor of XHTML this document matches */
        if (lexer->versions & VERS_HTML40_STRICT)
        {  /* use XHTML strict */
            fpi = "-//W3C//DTD XHTML 1.0 Strict//EN";
            sysid = voyager_strict;
        }
        else if (lexer->versions & VERS_LOOSE)
        {
            fpi = "-//W3C//DTD XHTML 1.0 Transitional//EN";
            sysid = voyager_loose;
        }
        else if (lexer->versions & VERS_FRAMES)
        {   /* use XHTML frames */
            fpi = "-//W3C//DTD XHTML 1.0 Frameset//EN";
            sysid = voyager_frameset;
        }
        else /* lets assume XHTML transitional */
        {
            fpi = "-//W3C//DTD XHTML 1.0 Transitional//EN";
            sysid = voyager_loose;
        }
    }
    else if (doctype_mode == doctype_strict)
    {
        fpi = "-//W3C//DTD XHTML 1.0 Strict//EN";
        sysid = voyager_strict;
    }
    else if (doctype_mode == doctype_loose)
    {
        fpi = "-//W3C//DTD XHTML 1.0 Transitional//EN";
        sysid = voyager_loose;
    }

    FixHTMLNameSpace(lexer, root, name_space);

    if (!doctype)
    {
        doctype = NewNode();
        doctype->type = DocTypeTag;
        doctype->next = root->content;
        doctype->parent = root;
        doctype->prev = null;
        root->content = doctype;
    }

    if (doctype_mode == doctype_user && doctype_str)
    {
        fpi = doctype_str;
        sysid = "";
    }

    lexer->txtstart = lexer->txtend = lexer->lexsize;

   /* add public identifier */
    AddStringLiteral(lexer, "html PUBLIC ");

    /* check if the fpi is quoted or not */
    if (fpi[0] == '"')
        AddStringLiteral(lexer, fpi);
    else
    {
        AddStringLiteral(lexer, "\"");
        AddStringLiteral(lexer, fpi);
        AddStringLiteral(lexer, "\"");
    }

    if ((unsigned)(wstrlen(sysid) + 6) >= wraplen)
        AddStringLiteral(lexer, "\n\"");
    else
        AddStringLiteral(lexer, "\n    \"");

    /* add system identifier */
    AddStringLiteral(lexer, sysid);
    AddStringLiteral(lexer, "\"");

    lexer->txtend = lexer->lexsize;

    doctype->start = lexer->txtstart;
    doctype->end = lexer->txtend;

    return no;
}

int ApparentVersion(Lexer *lexer)
{
    switch (lexer->doctype)
    {
    case VERS_UNKNOWN:
        return HTMLVersion(lexer);

    case VERS_HTML20:
        if (lexer->versions & VERS_HTML20)
            return VERS_HTML20;

        break;

    case VERS_HTML32:
        if (lexer->versions & VERS_HTML32)
            return VERS_HTML32;

        break; /* to replace old version by new */

    case VERS_HTML40_STRICT:
        if (lexer->versions & VERS_HTML40_STRICT)
            return VERS_HTML40_STRICT;

        break;

    case VERS_HTML40_LOOSE:
        if (lexer->versions & VERS_HTML40_LOOSE)
            return VERS_HTML40_LOOSE;

        break; /* to replace old version by new */

    case VERS_FRAMES:
        if (lexer->versions & VERS_FRAMES)
            return VERS_FRAMES;

        break;
    }

    ReportWarning(lexer, null, null, INCONSISTENT_VERSION);
    return HTMLVersion(lexer);
}

/* fixup doctype if missing */
Bool FixDocType(Lexer *lexer, Node *root)
{
    Node *doctype;
    int guessed = VERS_HTML40_STRICT, i;

    if (lexer->bad_doctype)
        ReportWarning(lexer, null, null, MALFORMED_DOCTYPE);

    if (XmlOut)
        return yes;

    doctype = FindDocType(root);

    if (doctype_mode == doctype_omit)
    {
        if (doctype)
            DiscardElement(doctype);

        return yes;
    }

    if (doctype_mode == doctype_strict)
    {
        DiscardElement(doctype);
        doctype = null;
        guessed = VERS_HTML40_STRICT;
    }
    else if (doctype_mode == doctype_loose)
    {
        DiscardElement(doctype);
        doctype = null;
        guessed = VERS_HTML40_LOOSE;
    }
    else if (doctype_mode == doctype_auto)
    {
        if (doctype)
        {
            if (lexer->doctype == VERS_UNKNOWN)
                return no;

            switch (lexer->doctype)
            {
            case VERS_UNKNOWN:
                return no;

            case VERS_HTML20:
                if (lexer->versions & VERS_HTML20)
                    return yes;

                break; /* to replace old version by new */

            case VERS_HTML32:
                if (lexer->versions & VERS_HTML32)
                    return yes;

                break; /* to replace old version by new */

            case VERS_HTML40_STRICT:
                if (lexer->versions & VERS_HTML40_STRICT)
                    return yes;

                break; /* to replace old version by new */

            case VERS_HTML40_LOOSE:
                if (lexer->versions & VERS_HTML40_LOOSE)
                    return yes;

                break; /* to replace old version by new */

            case VERS_FRAMES:
                if (lexer->versions & VERS_FRAMES)
                    return yes;

                break; /* to replace old version by new */
            }

            /* INCONSISTENT_VERSION warning is now issued by ApparentVersion() */
        }

        /* choose new doctype */
        guessed = HTMLVersion(lexer);
    }

    if (guessed == VERS_UNKNOWN)
        return no;

    /* for XML use the Voyager system identifier */
    if (XmlOut || XmlTags || lexer->isvoyager)
    {
        if (doctype)
            DiscardElement(doctype);

        for (i = 0; i < W3C_VERSIONS; ++i)
        {
            if (guessed == W3C_Version[i].code)
            {
                FixHTMLNameSpace(lexer, root, W3C_Version[i].profile);
                break;
            }
        }

        return yes;
    }

    if (!doctype)
    {
        doctype = NewNode();
        doctype->type = DocTypeTag;
        doctype->next = root->content;
        doctype->parent = root;
        doctype->prev = null;
        root->content = doctype;
    }

    lexer->txtstart = lexer->txtend = lexer->lexsize;

   /* use the appropriate public identifier */
    AddStringLiteral(lexer, "html PUBLIC ");

    if (doctype_mode == doctype_user && doctype_str)
        AddStringLiteral(lexer, doctype_str);
    else if (guessed == VERS_HTML20)
        AddStringLiteral(lexer, "\"-//IETF//DTD HTML 2.0//EN\"");
    else
    {
        AddStringLiteral(lexer, "\"-//W3C//DTD ");

        for (i = 0; i < W3C_VERSIONS; ++i)
        {
            if (guessed == W3C_Version[i].code)
            {
                AddStringLiteral(lexer, W3C_Version[i].name);
                break;
            }
        }

        AddStringLiteral(lexer, "//EN\"");
    }

    lexer->txtend = lexer->lexsize;

    doctype->start = lexer->txtstart;
    doctype->end = lexer->txtend;

    return yes;
}

/* ensure XML document starts with <?XML version="1.0"?> */
Bool FixXMLPI(Lexer *lexer, Node *root)
{
    Node *xml;
    char *s;

    if( root->content && root->content->type == ProcInsTag)
    {
        s = &lexer->lexbuf[root->content->start];

        if (s[0] == 'x' && s[1] == 'm' && s[2] == 'l')
            return yes;
    }

    xml = NewNode();
    xml->type = ProcInsTag;
    xml->next = root->content;

    if (root->content)
    {
        root->content->prev = xml;
        xml->next = root->content;
    }

    root->content = xml;

    lexer->txtstart = lexer->txtend = lexer->lexsize;
    AddStringLiteral(lexer, "xml version=\"1.0\"");
    lexer->txtend = lexer->lexsize;

    xml->start = lexer->txtstart;
    xml->end = lexer->txtend;
    return no;
}

Node *InferredTag(Lexer *lexer, char *name)
{
    Node *node;

    node = NewNode();
    node->type = StartTag;
    node->implicit = yes;
    node->element = wstrdup(name);
    node->start = lexer->txtstart;
    node->end = lexer->txtend;
    FindTag(node);
    return node;
}

Bool ExpectsContent(Node *node)
{
    if (node->type != StartTag)
        return no;

    /* unknown element? */
    if (node->tag == null)
        return yes;

    if (node->tag->model & CM_EMPTY)
        return no;

    return yes;
}

/*
  create a text node for the contents of
  a CDATA element like style or script
  which ends with </foo> for some foo.
*/
Node *GetCDATA(Lexer *lexer, Node *container)
{
    int c, lastc, start, i, len;
    Bool endtag = no;

    lexer->lines = lexer->in->curline;
    lexer->columns = lexer->in->curcol;
    lexer->waswhite = no;
    lexer->txtstart = lexer->txtend = lexer->lexsize;

    lastc = '\0';
    start = -1;

    while ((c = ReadChar(lexer->in)) != EndOfStream)
    {
        /* treat \r\n as \n and \r as \n */

        if (c == '/' && lastc == '<')
        {
            if (endtag)
            {
                lexer->lines = lexer->in->curline;
                lexer->columns = lexer->in->curcol - 3;

                ReportWarning(lexer, null, null, BAD_CDATA_CONTENT);
            }

            start = lexer->lexsize + 1;  /* to first letter */
            endtag = yes;
        }
        else if (c == '>' && start >= 0)
        {
            if (((len = lexer->lexsize - start) == wstrlen(container->element)) &&
                wstrncasecmp(lexer->lexbuf+start, container->element, len) == 0)
            {
                lexer->txtend = start - 2;
                break;
            }

            lexer->lines = lexer->in->curline;
            lexer->columns = lexer->in->curcol - 3;

            ReportWarning(lexer, null, null, BAD_CDATA_CONTENT);

            /* if javascript insert backslash before / */

            if (IsJavaScript(container))
            {
                for (i = lexer->lexsize; i > start-1; --i)
                    lexer->lexbuf[i] = lexer->lexbuf[i-1];

                lexer->lexbuf[start-1] = '\\';
                lexer->lexsize++;
            }

            start = -1;
        }
        else if (c == '\r')
        {
            c = ReadChar(lexer->in);

            if (c != '\n')
                UngetChar(c, lexer->in);

            c = '\n';
        }

        AddCharToLexer(lexer, (uint)c);
        lexer->txtend = lexer->lexsize;
        lastc = c;
    }

    if (c == EndOfStream)
        ReportWarning(lexer, container, null, MISSING_ENDTAG_FOR);

    if (lexer->txtend > lexer->txtstart)
        return lexer->token = TextToken(lexer);

    return null;
}

void UngetToken(Lexer *lexer)
{
    lexer->pushed = yes;
}

/*
  modes for GetToken()

  MixedContent   -- for elements which don't accept PCDATA
  Preformatted       -- white space preserved as is
  IgnoreMarkup       -- for CDATA elements such as script, style
*/

Node *GetToken(Lexer *lexer, uint mode)
{
    uint map;
    int c, lastc, badcomment = 0;
    Bool isempty;
    AttVal *attributes;

    if (lexer->pushed)
    {
        /* duplicate inlines in preference to pushed text nodes when appropriate */
        if (lexer->token->type != TextNode || (!lexer->insert && !lexer->inode))
        {
            lexer->pushed = no;
            return lexer->token;
        }
    }

    /* at start of block elements, unclosed inline
       elements are inserted into the token stream */

    if (lexer->insert || lexer->inode)
        return InsertedToken(lexer);

    lexer->lines = lexer->in->curline;
    lexer->columns = lexer->in->curcol;
    lexer->waswhite = no;

    lexer->txtstart = lexer->txtend = lexer->lexsize;

    while ((c = ReadChar(lexer->in)) != EndOfStream)
    {
        if (lexer->insertspace && mode != IgnoreWhitespace)
        {
            AddCharToLexer(lexer, ' ');
            lexer->waswhite = yes;
            lexer->insertspace = no;
        }

        /* treat \r\n as \n and \r as \n */

        if (c == '\r')
        {
            c = ReadChar(lexer->in);

            if (c != '\n')
                UngetChar(c, lexer->in);

            c = '\n';
        }

        AddCharToLexer(lexer, (uint)c);

        switch (lexer->state)
        {
            case LEX_CONTENT:  /* element content */
                map = MAP(c);

                /*
                 Discard white space if appropriate. Its cheaper
                 to do this here rather than in parser methods
                 for elements that don't have mixed content.
                */
                if ((map & white) && (mode == IgnoreWhitespace)
                      && lexer->lexsize == lexer->txtstart + 1)
                {
                    --(lexer->lexsize);
                    lexer->waswhite = no;
                    lexer->lines = lexer->in->curline;
                    lexer->columns = lexer->in->curcol;
                    continue;
                }

                if (c == '<')
                {
                    lexer->state = LEX_GT;
                    continue;
                }

                if ((map & white) != 0)
                {
                    /* was previous char white? */
                    if (lexer->waswhite)
                    {
                        if (mode != Preformatted && mode != IgnoreMarkup)
                        {
                            --(lexer->lexsize);
                            lexer->lines = lexer->in->curline;
                            lexer->columns = lexer->in->curcol;
                        }
                    }
                    else /* prev char wasn't white */
                    {
                        lexer->waswhite = yes;
                        lastc = c;

                        if (mode != Preformatted && mode != IgnoreMarkup && c != ' ')
                            ChangeChar(lexer, ' ');
                    }

                    continue;
                }
                else if (c == '&' && mode != IgnoreMarkup)
                    ParseEntity(lexer, mode);

                /* this is needed to avoid trimming trailing whitespace */
                if (mode == IgnoreWhitespace)
                    mode = MixedContent;

                lexer->waswhite = no;
                continue;

            case LEX_GT:  /* < */

                /* check for endtag */
                if (c == '/')
                {
                    if ((c = ReadChar(lexer->in)) == EndOfStream)
                    {
                        UngetChar(c, lexer->in);
                        continue;
                    }

                    AddCharToLexer(lexer, c);
                    map = MAP(c);

                    if ((map & letter) != 0)
                    {
                        lexer->lexsize -= 3;
                        lexer->txtend = lexer->lexsize;
                        UngetChar(c, lexer->in);
                        lexer->state = LEX_ENDTAG;
                        lexer->lexbuf[lexer->lexsize] = '\0';  /* debug */
                        lexer->in->curcol -= 2;

                        /* if some text before the </ return it now */
                        if (lexer->txtend > lexer->txtstart)
                        {
                            /* trim space char before end tag */
                            if (mode == IgnoreWhitespace && lexer->lexbuf[lexer->lexsize - 1] == ' ')
                            {
                                lexer->lexsize -= 1;
                                lexer->txtend = lexer->lexsize;
                            }

                            return lexer->token = TextToken(lexer);
                        }

                        continue;       /* no text so keep going */
                    }

                    /* otherwise treat as CDATA */
                    lexer->waswhite = no;
                    lexer->state = LEX_CONTENT;
                    continue;
                }

                if (mode == IgnoreMarkup)
                {
                    /* otherwise treat as CDATA */
                    lexer->waswhite = no;
                    lexer->state = LEX_CONTENT;
                    continue;
                }

                /*
                   look out for comments, doctype or marked sections
                   this isn't quite right, but its getting there ...
                */
                if (c == '!')
                {
                    c = ReadChar(lexer->in);

                    if (c == '-')
                    {
                        c = ReadChar(lexer->in);

                        if (c == '-')
                        {
                            lexer->state = LEX_COMMENT;  /* comment */
                            lexer->lexsize -= 2;
                            lexer->txtend = lexer->lexsize;

                            /* if some text before < return it now */
                            if (lexer->txtend > lexer->txtstart)
                                return lexer->token = TextToken(lexer);

                            lexer->txtstart = lexer->lexsize;
                            continue;
                        }

                        ReportWarning(lexer, null, null, MALFORMED_COMMENT);
                    }
                    else if (c == 'd' || c == 'D')
                    {
                        lexer->state = LEX_DOCTYPE; /* doctype */
                        lexer->lexsize -= 2;
                        lexer->txtend = lexer->lexsize;
                        mode = IgnoreWhitespace;

                        /* skip until white space or '>' */

                        for (;;)
                        {
                            c = ReadChar(lexer->in);

                            if (c == EndOfStream || c == '>')
                            {
                                UngetChar(c, lexer->in);
                                break;
                            }

                            map = MAP(c);

                            if (!(map & white))
                                continue;

                            /* and skip to end of whitespace */

                            for (;;)
                            {
                                c = ReadChar(lexer->in);

                                if (c == EndOfStream || c == '>')
                                {
                                    UngetChar(c, lexer->in);
                                    break;
                                }

                                map = MAP(c);

                                if (map & white)
                                    continue;

                                UngetChar(c, lexer->in);
                                    break;
                            }

                            break;
                        }

                        /* if some text before < return it now */
                        if (lexer->txtend > lexer->txtstart)
                            return lexer->token = TextToken(lexer);

                        lexer->txtstart = lexer->lexsize;
                        continue;
                    }
                    else if (c == '[')
                    {
                        /* Word 2000 embeds <![if ...]> ... <![endif]> sequences */
                        lexer->lexsize -= 2;
                        lexer->state = LEX_SECTION;
                        lexer->txtend = lexer->lexsize;

                        /* if some text before < return it now */
                        if (lexer->txtend > lexer->txtstart)
                            return lexer->token = TextToken(lexer);

                        lexer->txtstart = lexer->lexsize;
                        continue;
                    }



                    /* otherwise swallow chars up to and including next '>' */
                    while ((c = ReadChar(lexer->in)) != '>')
                    {
                        if (c == -1)
                        {
                            UngetChar(c, lexer->in);
                            break;
                        }
                    }

                    lexer->lexsize -= 2;
                    lexer->lexbuf[lexer->lexsize] = '\0';
                    lexer->state = LEX_CONTENT;
                    continue;
                }

                /*
                   processing instructions
                */

                if (c == '?')
                {
                    lexer->lexsize -= 2;
                    lexer->state = LEX_PROCINSTR;
                    lexer->txtend = lexer->lexsize;

                    /* if some text before < return it now */
                    if (lexer->txtend > lexer->txtstart)
                        return lexer->token = TextToken(lexer);

                    lexer->txtstart = lexer->lexsize;
                    continue;
                }

                /* Microsoft ASP's e.g. <% ... server-code ... %> */
                if (c == '%')
                {
                    lexer->lexsize -= 2;
                    lexer->state = LEX_ASP;
                    lexer->txtend = lexer->lexsize;

                    /* if some text before < return it now */
                    if (lexer->txtend > lexer->txtstart)
                        return lexer->token = TextToken(lexer);

                    lexer->txtstart = lexer->lexsize;
                    continue;
                }

                /* Netscapes JSTE e.g. <# ... server-code ... #> */
                if (c == '#')
                {
                    lexer->lexsize -= 2;
                    lexer->state = LEX_JSTE;
                    lexer->txtend = lexer->lexsize;

                    /* if some text before < return it now */
                    if (lexer->txtend > lexer->txtstart)
                        return lexer->token = TextToken(lexer);

                    lexer->txtstart = lexer->lexsize;
                    continue;
                }

                map = MAP(c);

                /* check for start tag */
                if ((map & letter) != 0)
                {
                    UngetChar(c, lexer->in);     /* push back letter */
                    lexer->lexsize -= 2;      /* discard "<" + letter */
                    lexer->txtend = lexer->lexsize;
                    lexer->state = LEX_STARTTAG;         /* ready to read tag name */

                    /* if some text before < return it now */
                    if (lexer->txtend > lexer->txtstart)
                        return lexer->token = TextToken(lexer);

                    continue;       /* no text so keep going */
                }

                /* otherwise treat as CDATA */
                lexer->state = LEX_CONTENT;
                lexer->waswhite = no;
                continue;

            case LEX_ENDTAG:  /* </letter */
                lexer->txtstart = lexer->lexsize - 1;
                lexer->in->curcol += 2;
                c = ParseTagName(lexer);
                lexer->token = TagToken(lexer, EndTag);  /* create endtag token */
                lexer->lexsize = lexer->txtend = lexer->txtstart;

                /* skip to '>' */
                while (c != '>')
                {
                    c = ReadChar(lexer->in);

                    if (c == EndOfStream)
                        break;
                }

                if (c == EndOfStream)
                {
                    UngetChar(c, lexer->in);
                    continue;
                }

                lexer->state = LEX_CONTENT;
                lexer->waswhite = no;
                return lexer->token;  /* the endtag token */

            case LEX_STARTTAG: /* first letter of tagname */
                lexer->txtstart = lexer->lexsize - 1; /* set txtstart to first letter */
                c = ParseTagName(lexer);
                isempty = no;
                attributes = null;
                lexer->token = TagToken(lexer, (isempty ? StartEndTag : StartTag));

                /* parse attributes, consuming closing ">" */
                if (c != '>')
                {
                    if (c == '/')
                        UngetChar(c, lexer->in);

                    attributes = ParseAttrs(lexer, &isempty);
                }

                if (isempty)
                    lexer->token->type = StartEndTag;

                lexer->token->attributes = attributes;
                lexer->lexsize = lexer->txtend = lexer->txtstart;


                /* swallow newline following start tag */
                /* special check needed for CRLF sequence */
                /* this doesn't apply to empty elements */

                if (ExpectsContent(lexer->token) ||
                    lexer->token->tag == tag_br)
                {
                    c = ReadChar(lexer->in);

                    if (c == '\r')
                    {
                        c = ReadChar(lexer->in);

                        if (c != '\n')
                            UngetChar(c, lexer->in);
                    }
                    else if (c != '\n' && c != '\f')
                        UngetChar(c, lexer->in);

                    lexer->waswhite = yes;  /* to swallow leading whitespace */
                }
                else
                    lexer->waswhite = no;

                lexer->state = LEX_CONTENT;
                if (lexer->token->tag == null)
                    ReportError(lexer, null, lexer->token, UNKNOWN_ELEMENT);
                else if (!XmlTags)
                {
                    lexer->versions &= lexer->token->tag->versions;

                    if (lexer->token->tag->versions & VERS_PROPRIETARY)
                    {
                        if (!MakeClean && (lexer->token->tag == tag_nobr ||
                                                lexer->token->tag == tag_wbr))
                            ReportWarning(lexer, null, lexer->token, PROPRIETARY_ELEMENT);
                    }

                    if (lexer->token->tag->chkattrs)
                    {
                        CheckUniqueAttributes(lexer, lexer->token);
                        lexer->token->tag->chkattrs(lexer, lexer->token);
                    }
                    else
                        CheckAttributes(lexer, lexer->token);
                }

                 return lexer->token;  /* return start tag */

            case LEX_COMMENT:  /* seen <!-- so look for --> */

                if (c != '-')
                    continue;

                c = ReadChar(lexer->in);
                AddCharToLexer(lexer, c);

                if (c != '-')
                    continue;

            end_comment:
                c = ReadChar(lexer->in);

                if (c == '>')
                {
                    if (badcomment)
                        ReportWarning(lexer, null, null, MALFORMED_COMMENT);

                    lexer->txtend = lexer->lexsize;
                    lexer->lexbuf[lexer->lexsize] = '\0';
                    lexer->state = LEX_CONTENT;
                    lexer->waswhite = no;
                    lexer->token = CommentToken(lexer);

                    /* now look for a line break */

                    c = ReadChar(lexer->in);

                    if (c == '\r')
                    {
                        c = ReadChar(lexer->in);

                        if (c != '\n')
                            lexer->token->linebreak = yes;
                    }

                    if (c == '\n')
                        lexer->token->linebreak = yes;
                    else
                        UngetChar(c, lexer->in);

                    return lexer->token;
                }

                /* note position of first such error in the comment */
                if (!badcomment)
                {
                    lexer->lines = lexer->in->curline;
                    lexer->columns = lexer->in->curcol - 3;
                }

                badcomment++;

                if (FixComments)
                    lexer->lexbuf[lexer->lexsize - 2] = '=';

                AddCharToLexer(lexer, c);

                /* if '-' then look for '>' to end the comment */
                if (c == '-')
                    goto end_comment;

                /* otherwise continue to look for --> */
                lexer->lexbuf[lexer->lexsize - 2] = '=';
                continue;

            case LEX_DOCTYPE:  /* seen <!d so look for '>' munging whitespace */
                map = MAP(c);

                if (map & white)
                {
                    if (lexer->waswhite)
                        lexer->lexsize -= 1;

                    lexer->waswhite = yes;
                }
                else
                    lexer->waswhite = no;

                if (c != '>')
                    continue;

                lexer->lexsize -= 1;
                lexer->txtend = lexer->lexsize;
                lexer->lexbuf[lexer->lexsize] = '\0';
                lexer->state = LEX_CONTENT;
                lexer->waswhite = no;
                lexer->token = DocTypeToken(lexer);
                /* make a note of the version named by the doctype */
                lexer->doctype = FindGivenVersion(lexer, lexer->token);
                return lexer->token;

            case LEX_PROCINSTR:  /* seen <? so look for '>' */
                /* check for PHP preprocessor instructions <?php ... ?> */

                if  (lexer->lexsize - lexer->txtstart == 3)
                {
                    if (wstrncmp(lexer->lexbuf + lexer->txtstart, "php", 3) == 0)
                    {
                        lexer->state = LEX_PHP;
                        continue;
                    }
                }

                if (XmlPIs)  /* insist on ?> as terminator */
                {
                    if (c != '?')
                        continue;

                    /* now look for '>' */
                    c = ReadChar(lexer->in);

                    if (c == EndOfStream)
                    {
                        ReportWarning(lexer, null, null, UNEXPECTED_END_OF_FILE);
                        UngetChar(c, lexer->in);
                        continue;
                    }

                    AddCharToLexer(lexer, c);
                }


                if (c != '>')
                    continue;

                lexer->lexsize -= 1;
                lexer->txtend = lexer->lexsize;
                lexer->lexbuf[lexer->lexsize] = '\0';
                lexer->state = LEX_CONTENT;
                lexer->waswhite = no;
                return lexer->token = PIToken(lexer);

            case LEX_ASP:  /* seen <% so look for "%>" */
                if (c != '%')
                    continue;

                /* now look for '>' */
                c = ReadChar(lexer->in);


                if (c != '>')
                {
                    UngetChar(c, lexer->in);
                    continue;
                }

                lexer->lexsize -= 1;
                lexer->txtend = lexer->lexsize;
                lexer->lexbuf[lexer->lexsize] = '\0';
                lexer->state = LEX_CONTENT;
                lexer->waswhite = no;
                return lexer->token = AspToken(lexer);

            case LEX_JSTE:  /* seen <# so look for "#>" */
                if (c != '#')
                    continue;

                /* now look for '>' */
                c = ReadChar(lexer->in);


                if (c != '>')
                {
                    UngetChar(c, lexer->in);
                    continue;
                }

                lexer->lexsize -= 1;
                lexer->txtend = lexer->lexsize;
                lexer->lexbuf[lexer->lexsize] = '\0';
                lexer->state = LEX_CONTENT;
                lexer->waswhite = no;
                return lexer->token = JsteToken(lexer);

            case LEX_PHP: /* seen "<?php" so look for "?>" */
                if (c != '?')
                    continue;

                /* now look for '>' */
                c = ReadChar(lexer->in);

                if (c != '>')
                {
                    UngetChar(c, lexer->in);
                    continue;
                }

                lexer->lexsize -= 1;
                lexer->txtend = lexer->lexsize;
                lexer->lexbuf[lexer->lexsize] = '\0';
                lexer->state = LEX_CONTENT;
                lexer->waswhite = no;
                return lexer->token = PhpToken(lexer);

            case LEX_SECTION: /* seen "<![" so look for "]>" */
                if (c == '[')
                {
                    if (lexer->lexsize == (lexer->txtstart + 6) &&
                        wstrncmp(lexer->lexbuf+lexer->txtstart, "CDATA[", 6) == 0)
                    {
                        lexer->state = LEX_CDATA;
                        lexer->lexsize -= 6;
                        continue;
                    }
                }

                if (c != ']')
                    continue;

                /* now look for '>' */
                c = ReadChar(lexer->in);

                if (c != '>')
                {
                    UngetChar(c, lexer->in);
                    continue;
                }

                lexer->lexsize -= 1;
                lexer->txtend = lexer->lexsize;
                lexer->lexbuf[lexer->lexsize] = '\0';
                lexer->state = LEX_CONTENT;
                lexer->waswhite = no;
                return lexer->token = SectionToken(lexer);

            case LEX_CDATA: /* seen "<![CDATA[" so look for "]]>" */
                if (c != ']')
                    continue;

                /* now look for ']' */
                c = ReadChar(lexer->in);

                if (c != ']')
                {
                    UngetChar(c, lexer->in);
                    continue;
                }

                /* now look for '>' */
                c = ReadChar(lexer->in);

                if (c != '>')
                {
                    UngetChar(c, lexer->in);
                    continue;
                }

                lexer->lexsize -= 1;
                lexer->txtend = lexer->lexsize;
                lexer->lexbuf[lexer->lexsize] = '\0';
                lexer->state = LEX_CONTENT;
                lexer->waswhite = no;
                return lexer->token = CDATAToken(lexer);
        }
    }

    if (lexer->state == LEX_CONTENT)  /* text string */
    {
        lexer->txtend = lexer->lexsize;

        if (lexer->txtend > lexer->txtstart)
        {
            UngetChar(c, lexer->in);

            if (lexer->lexbuf[lexer->lexsize - 1] == ' ')
            {
                lexer->lexsize -= 1;
                lexer->txtend = lexer->lexsize;
            }

            return lexer->token = TextToken(lexer);
        }
    }
    else if (lexer->state == LEX_COMMENT) /* comment */
    {
        if (c == EndOfStream)
            ReportWarning(lexer, null, null, MALFORMED_COMMENT);

        lexer->txtend = lexer->lexsize;
        lexer->lexbuf[lexer->lexsize] = '\0';
        lexer->state = LEX_CONTENT;
        lexer->waswhite = no;
        return lexer->token = CommentToken(lexer);
    }

    return 0;
}

static void MapStr(char *str, uint code)
{
    uint i;

    while (*str)
    {
        i = (uint)(*str++);
        lexmap[i] |= code;
    }
}

void InitMap(void)
{
    MapStr("\r\n\f", newline|white);
    MapStr(" \t", white);
    MapStr("-.:_", namechar);
    MapStr("0123456789", digit|namechar);
    MapStr("abcdefghijklmnopqrstuvwxyz", lowercase|letter|namechar);
    MapStr("ABCDEFGHIJKLMNOPQRSTUVWXYZ", uppercase|letter|namechar);
}

/*
 parser for ASP within start tags

 Some people use ASP for to customize attributes
 Tidy isn't really well suited to dealing with ASP
 This is a workaround for attributes, but won't
 deal with the case where the ASP is used to tailor
 the attribute value. Here is an example of a work
 around for using ASP in attribute values:

  href="<%=rsSchool.Fields("ID").Value%>"

 where the ASP that generates the attribute value
 is masked from Tidy by the quotemarks.

*/

static Node *ParseAsp(Lexer *lexer)
{
    uint c;
    Node *asp = null;

    lexer->txtstart = lexer->lexsize;

    for (;;)
    {
        c = ReadChar(lexer->in);
        AddCharToLexer(lexer, c);


        if (c != '%')
            continue;

        c = ReadChar(lexer->in);
        AddCharToLexer(lexer, c);

        if (c == '>')
            break;
    }

    lexer->lexsize -= 2;
    lexer->txtend = lexer->lexsize;

    if (lexer->txtend > lexer->txtstart)
        asp = AspToken(lexer);

    lexer->txtstart = lexer->txtend;
    return asp;
}


/*
 PHP is like ASP but is based upon XML
 processing instructions, e.g. <?php ... ?>
*/
static Node *ParsePhp(Lexer *lexer)
{
    uint c;
    Node *php = null;

    lexer->txtstart = lexer->lexsize;

    for (;;)
    {
        c = ReadChar(lexer->in);
        AddCharToLexer(lexer, c);


        if (c != '?')
            continue;

        c = ReadChar(lexer->in);
        AddCharToLexer(lexer, c);

        if (c == '>')
            break;
    }

    lexer->lexsize -= 2;
    lexer->txtend = lexer->lexsize;

    if (lexer->txtend > lexer->txtstart)
        php = PhpToken(lexer);

    lexer->txtstart = lexer->txtend;
    return php;
}

/* consumes the '>' terminating start tags */
static char  *ParseAttribute(Lexer *lexer, Bool *isempty,
                             Node **asp, Node **php)
{
    int map, start, len = 0;
    char *attr;
    uint c;

    *asp = null;  /* clear asp pointer */
    *php = null;  /* clear php pointer */

 /* skip white space before the attribute */

    for (;;)
    {
        c = ReadChar(lexer->in);


        if (c == '/')
        {
            c = ReadChar(lexer->in);

            if (c == '>')
            {
                *isempty = yes;
                return null;
            }

            UngetChar(c, lexer->in);
            c = '/';
            break;
        }

        if (c == '>')
            return null;

        if (c =='<')
        {
            c = ReadChar(lexer->in);

            if (c == '%')
            {
                *asp = ParseAsp(lexer);
                return null;
            }
            else if (c == '?')
            {
                *php = ParsePhp(lexer);
                return null;
            }

            UngetChar(c, lexer->in);
            ReportAttrError(lexer, lexer->token, null, UNEXPECTED_GT);
            return null;
        }

        if (c == '"' || c == '\'')
        {
            ReportAttrError(lexer, lexer->token, null, UNEXPECTED_QUOTEMARK);
            continue;
        }

        if (c == EndOfStream)
        {
            ReportAttrError(lexer, lexer->token, null, UNEXPECTED_END_OF_FILE);
            UngetChar(c, lexer->in);
            return null;
        }

        map = MAP(c);

        if ((map & white) == 0)
           break;
    }

    start = lexer->lexsize;

    for (;;)
    {
     /* but push back '=' for parseValue() */
        if (c == '=' || c == '>')
        {
            UngetChar(c, lexer->in);
            break;
        }

        if (c == '<' || c == EndOfStream)
        {
            UngetChar(c, lexer->in);
            break;
        }

        map = MAP(c);

        if ((map & white) != 0)
            break;

     /* what should be done about non-namechar characters? */
     /* currently these are incorporated into the attr name */

        if (!XmlTags && (map & uppercase) != 0)
            c += (uint)('a' - 'A');

        ++len;
        AddCharToLexer(lexer, c);

        c = ReadChar(lexer->in);
    }

    attr = (len > 0 ? wstrndup(lexer->lexbuf+start, len) : null);
    lexer->lexsize = start;

    return attr;
}

/*
 invoked when < is seen in place of attribute value
 but terminates on whitespace if not ASP, PHP or Tango
 this routine recognizes ' and " quoted strings
*/
static int ParseServerInstruction(Lexer *lexer)
{
    int c, map, delim = '"';
    Bool isrule = no;

    c = ReadChar(lexer->in);
    AddCharToLexer(lexer, c);

    /* check for ASP, PHP or Tango */
    if (c == '%' || c == '?' || c == '@')
        isrule = yes;

    for (;;)
    {
        c = ReadChar(lexer->in);

        if (c == EndOfStream)
            break;

        if (c == '>')
        {
            if (isrule)
                AddCharToLexer(lexer, c);
            else
                UngetChar(c, lexer->in);

            break;
        }

        /* if not recognized as ASP, PHP or Tango */
        /* then also finish value on whitespace */
        if (!isrule)
        {
            map = MAP(c);

            if ((map & white) != 0)
                break;
        }

        AddCharToLexer(lexer, c);

        if (c == '"')
        {
            do
            {
                c = ReadChar(lexer->in);
                AddCharToLexer(lexer, c);
            }
            while (c != '"');
            delim = '\'';
            continue;
        }

        if (c == '\'')
        {
            do
            {
                c = ReadChar(lexer->in);
                AddCharToLexer(lexer, c);
            }
            while (c != '\'');
        }
    }

    return delim;
}

/* values start with "=" or " = " etc. */
/* doesn't consume the ">" at end of start tag */

static char *ParseValue(Lexer *lexer, char *name,
                        Bool foldCase, Bool *isempty, int *pdelim)
{
    int len = 0, start, map;
    Bool seen_gt = no;
    Bool munge = yes;
    uint c, lastc, delim, quotewarning;
    char *value;

    delim = (char) 0;
    *pdelim = '"';

    /*
     Henry Zrepa reports that some folk are using the
     embed element with script attributes where newlines
     are significant and must be preserved
    */
    if (LiteralAttribs)
        munge = no;

 /* skip white space before the '=' */

    for (;;)
    {
        c = ReadChar(lexer->in);

        if (c == EndOfStream)
        {
            UngetChar(c, lexer->in);
            break;
        }

        map = MAP(c);

        if ((map & white) == 0)
           break;
    }

/*
  c should be '=' if there is a value
  other legal possibilities are white
  space, '/' and '>'
*/

    if (c != '=')
    {
        UngetChar(c, lexer->in);
        return null;
    }

 /* skip white space after '=' */

    for (;;)
    {
        c = ReadChar(lexer->in);

        if (c == EndOfStream)
        {
            UngetChar(c, lexer->in);
            break;
        }

        map = MAP(c);

        if ((map & white) == 0)
           break;
    }

 /* check for quote marks */

    if (c == '"' || c == '\'')
        delim = c;
    else if (c == '<')
    {
        start = lexer->lexsize;
        AddCharToLexer(lexer, c);
        *pdelim = ParseServerInstruction(lexer);
        len = lexer->lexsize - start;
        lexer->lexsize = start;
        return (len > 0 ? wstrndup(lexer->lexbuf+start, len) : null);
    }
    else
        UngetChar(c, lexer->in);

 /*
   and read the value string
   check for quote mark if needed
 */

    quotewarning = 0;
    start = lexer->lexsize;
    c = '\0';

    for (;;)
    {
        lastc = c;  /* track last character */
        c = ReadChar(lexer->in);

        if (c == EndOfStream)
        {
            ReportAttrError(lexer, lexer->token, null, UNEXPECTED_END_OF_FILE);
            UngetChar(c, lexer->in);
            break;
        }

        if (delim == (char)0)
        {
            if (c == '>')
            {
                UngetChar(c, lexer->in);
                break;
            }

            if (c == '"' || c == '\'')
            {
                ReportAttrError(lexer, lexer->token, null, UNEXPECTED_QUOTEMARK);
                break;
            }

            if (c == '<')
            {
                /* UngetChar(c, lexer->in); */
                ReportAttrError(lexer, lexer->token, null, UNEXPECTED_GT);
                /* break; */
            }

            /*
             For cases like <br clear=all/> need to avoid treating /> as
             part of the attribute value, however care is needed to avoid
             so treating <a href=http://www.acme.com/> in this way, which
             would map the <a> tag to <a href="http://www.acme.com"/>
            */
            if (c == '/')
            {
                /* peek ahead in case of /> */
                c = ReadChar(lexer->in);

                if (c == '>' && !IsUrl(name))
                {
                    *isempty = yes;
                    UngetChar(c, lexer->in);
                    break;
                }

                /* unget peeked char */
                UngetChar(c, lexer->in);
                c = '/';
            }
        }
        else  /* delim is '\'' or '"' */
        {
            if (c == delim)
                break;

            /* treat CRLF, CR and LF as single line break */

            if (c == '\r')
            {
                if ((c = ReadChar(lexer->in)) != '\n')
                    UngetChar(c, lexer->in);

                c = '\n';
            }

            if (c == '\n' || c == '<' || c == '>')
                ++quotewarning;

            if (c == '>')
                seen_gt = yes;
        }

        if (c == '&')
        {
            AddCharToLexer(lexer, c);
            ParseEntity(lexer, null);
            continue;
        }

        /*
         kludge for JavaScript attribute values
         with line continuations in string literals
        */
        if (c == '\\')
        {
            c = ReadChar(lexer->in);

            if (c != '\n')
            {
                UngetChar(c, lexer->in);
                c = '\\';
            }
        }

        map = MAP(c);

        if (map & white)
        {
            if (delim == (char)0)
                break;

            if (munge)
            {
                c = ' ';

                if (lastc == ' ')
                    continue;
            }
        }
        else if (foldCase && (map & uppercase) != 0)
            c += (uint)('a' - 'A');

        AddCharToLexer(lexer, c);
    }

    if (quotewarning > 10 && seen_gt && munge)
    {
        /*
           there is almost certainly a missing trailling quote mark
           as we have see too many newlines, < or > characters.

           an exception is made for Javascript attributes and the
           javascript URL scheme which may legitimately include < and >
        */
        if (!IsScript(name) &&
            !(IsUrl(name) && wstrncmp(lexer->lexbuf+start, "javascript:", 11) == 0))
                ReportError(lexer, null, null, SUSPECTED_MISSING_QUOTE);
    }

    len = lexer->lexsize - start;
    lexer->lexsize = start;


    if (len > 0 || delim)
        value = wstrndup(lexer->lexbuf+start, len);
    else
        value = null;

    /* note delimiter if given */
    *pdelim = (delim ? delim : '"');

    return value;
}

/* attr must be non-null */
Bool IsValidAttrName( char *attr)
{
    uint map, c;
    int i;

    /* first character should be a letter */
    c = attr[0];
    map = MAP(c);

    if (!(map & letter))
        return no;

    /* remaining characters should be namechars */
    for( i = 1; i < wstrlen(attr); i++)
    {
        c = attr[i];
        map = MAP(c);

        if (map & namechar)
            continue;

        return no;
    }

    return yes;
}


/* create a new attribute */
AttVal *NewAttribute()
{
    AttVal *av;

    av = (AttVal *)MemAlloc(sizeof(AttVal));
    ClearMemory (av, sizeof(AttVal));
    return av;
}


/* swallows closing '>' */

AttVal *ParseAttrs(Lexer *lexer, Bool *isempty)
{
    AttVal *av, *list;
    char *attribute, *value;
    int delim;
    Node *asp, *php;

    list = null;

    for (; !EndOfInput(lexer);)
    {
        attribute = ParseAttribute(lexer, isempty, &asp, &php);

        if (attribute == null)
        {
            /* check if attributes are created by ASP markup */
            if (asp)
            {
                av = NewAttribute();
                av->next = list;
                av->asp = asp;
                list = av;
                continue;
            }

            /* check if attributes are created by PHP markup */
            if (php)
            {
                av = NewAttribute();
                av->next = list;
                av->php = php;
                list = av;
                continue;
            }

            break;
        }

        value = ParseValue(lexer, attribute, no, isempty, &delim);

        if (attribute && IsValidAttrName(attribute))
        {
            av = NewAttribute();
            av->next = list;
            av->delim = delim;
            av->attribute = attribute;
            av->value = value;
            av->dict = FindAttribute(av);
            list = av;
        }
        else
        {
            av = NewAttribute();
            av->attribute = attribute;
            av->value = value;
            ReportAttrError(lexer, lexer->token, attribute, BAD_ATTRIBUTE_VALUE);
            FreeAttribute(av);
        }
    }

    return list;
}

