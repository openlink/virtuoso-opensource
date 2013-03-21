/*
 *  $Id$
 *
 *  html.h
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

#ifndef __HTML_H_010606
#define __HTML_H_010606

#ifndef __PLATFORM_H_010606
#include "platform.h"
#endif

/* indentation modes */

#define NO_INDENT      0
#define BLOCK_INDENT   1
#define SMART_INDENT   2

/* character encodings */

#define RAW         0
#define ASCII       1
#define LATIN1      2
#define UTF8        3
#define ISO2022     4
#define MACROMAN    5

typedef struct
{
    int encoding;
    int state;     /* for ISO 2022 */
#ifdef BIF_TIDY
    tidy_io_t tio;
#else
    FILE *fp;
#endif
} Out;

void outc(uint c, Out *out);

/* states for ISO 2022

 A document in ISO-2022 based encoding uses some ESC sequences called
 "designator" to switch character sets. The designators defined and
 used in ISO-2022-JP are:

    "ESC" + "(" + ?     for ISO646 variants

    "ESC" + "$" + ?     and
    "ESC" + "$" + "(" + ?   for multibyte character sets
*/
#define FSM_ASCII   0
#define FSM_ESC     1
#define FSM_ESCD    2
#define FSM_ESCDP   3
#define FSM_ESCP    4
#define FSM_NONASCII 5

/* lexer char types */

#define digit       1
#define letter      2
#define namechar    4
#define white       8
#define newline     16
#define lowercase   32
#define uppercase   64

/* lexer GetToken states */

#define LEX_CONTENT     0
#define LEX_GT          1
#define LEX_ENDTAG      2
#define LEX_STARTTAG    3
#define LEX_COMMENT     4
#define LEX_DOCTYPE     5
#define LEX_PROCINSTR   6
#define LEX_ENDCOMMENT  7
#define LEX_CDATA       8
#define LEX_SECTION     9
#define LEX_ASP         10
#define LEX_JSTE        11
#define LEX_PHP         12

/* content model shortcut encoding */

#define CM_UNKNOWN         0
#define CM_EMPTY        (1 << 0)
#define CM_HTML         (1 << 1)
#define CM_HEAD         (1 << 2)
#define CM_BLOCK        (1 << 3)
#define CM_INLINE       (1 << 4)
#define CM_LIST         (1 << 5)
#define CM_DEFLIST      (1 << 6)
#define CM_TABLE        (1 << 7)
#define CM_ROWGRP       (1 << 8)
#define CM_ROW          (1 << 9)
#define CM_FIELD        (1 << 10)
#define CM_OBJECT       (1 << 11)
#define CM_PARAM        (1 << 12)
#define CM_FRAMES       (1 << 13)
#define CM_HEADING      (1 << 14)
#define CM_OPT          (1 << 15)
#define CM_IMG          (1 << 16)
#define CM_MIXED        (1 << 17)
#define CM_NO_INDENT    (1 << 18)
#define CM_OBSOLETE     (1 << 19)
#define CM_NEW          (1 << 20)
#define CM_OMITST       (1 << 21)

/*
 Linked list of class names and styles
*/
struct _style
{
    char *tag;
    char *tag_class;
    char *properties;
    struct _style *next;
};

typedef struct _style Style;

/*
 Linked list of style properties
*/
struct _styleprop
{
    char *name;
    char *value;
    struct _styleprop *next;
};

typedef struct _styleprop StyleProp;

/* mode controlling treatment of doctype */
typedef enum
{
    doctype_omit,
    doctype_auto,
    doctype_strict,
    doctype_loose,
    doctype_user
} DocTypeMode;


/*
 Attribute/Value linked list node
*/

struct _attval
{
    struct _attval *next;
    struct _attribute *dict;
    struct _node *asp;
    struct _node *php;
    int delim;
    char *attribute;
    char *value;
};

typedef struct _attval AttVal;

/*
  node->type is one of these values
*/
#define RootNode        0
#define DocTypeTag      1
#define CommentTag      2
#define ProcInsTag      3
#define TextNode        4
#define StartTag        5
#define EndTag          6
#define StartEndTag     7
#define CDATATag        8
#define SectionTag      9
#define AspTag          10
#define JsteTag         11
#define PhpTag          12

struct _node
{
    struct _node *parent;
    struct _node *prev;
    struct _node *next;
    struct _node *content;
    struct _node *last;
    struct _attval *attributes;
    char *element;          /* name (null for text nodes) */
    uint start;             /* start of span onto text array */
    uint end;               /* end of span onto text array */
    uint type;              /* TextNode, StartTag, EndTag etc. */
    Bool closed;            /* true if closed by explicit end tag */
    Bool implicit;          /* true if inferred */
    Bool linebreak;         /* true if followed by a line break */
    struct _tagdict *was;   /* old tag when it was changed */
    struct _tagdict *tag;   /* tag's dictionary definition */
};

typedef struct _node Node;

/*

 If the document uses just HTML 2.0 tags and attributes described it as HTML 2.0
 Similarly for HTML 3.2 and the 3 flavors of HTML 4.0. If there are proprietary
 tags and attributes then describe it as HTML Proprietary. If it includes the
 xml-lang or xmlns attributes but is otherwise HTML 2.0, 3.2 or 4.0 then describe
 it as one of the flavors of Voyager (strict, loose or frameset).
*/

#define VERS_UNKNOWN       0

#define VERS_HTML20        1
#define VERS_HTML32        2
#define VERS_HTML40_STRICT 4
#define VERS_HTML40_LOOSE  8
#define VERS_FRAMES       16
#define VERS_XML          32

#define VERS_NETSCAPE     64
#define VERS_MICROSOFT   128
#define VERS_SUN         256

#define VERS_MALFORMED   512

#define VERS_ALL (VERS_HTML20|VERS_HTML32|VERS_HTML40_STRICT|VERS_HTML40_LOOSE|VERS_FRAMES)
#define VERS_HTML40 (VERS_HTML40_STRICT|VERS_HTML40_LOOSE|VERS_FRAMES)
#define VERS_LOOSE (VERS_HTML32|VERS_HTML40_LOOSE|VERS_FRAMES)
#define VERS_IFRAMES (VERS_HTML40_LOOSE|VERS_FRAMES)
#define VERS_FROM32  (VERS_HTML40_STRICT|VERS_LOOSE)
#define VERS_PROPRIETARY (VERS_NETSCAPE|VERS_MICROSOFT|VERS_SUN)

#define VERS_EVERYTHING (VERS_ALL|VERS_PROPRIETARY)

/*
  Mosaic handles inlines via a separate stack from other elements
  We duplicate this to recover from inline markup errors such as:

     <i>italic text
     <p>more italic text</b> normal text

  which for compatibility with Mosaic is mapped to:

     <i>italic text</i>
     <p><i>more italic text</i> normal text

  Note that any inline end tag pop's the effect of the current
  inline start tag, so that </b> pop's <i> in the above example.
*/

struct _inode
{
    struct _inode *next;
    struct _tagdict *tag;   /* tag's dictionary definition */
    char *element;          /* name (null for text nodes) */
    struct _attval *attributes;
};

typedef struct _inode IStack;
typedef struct _lexer Lexer;

/* tidy.c */

#ifdef BIF_TIDY
extern int do_tidy (caddr_t html_input, caddr_t config_input, caddr_t *html_output);
#endif

#define EndOfStream EOF

/* non-raw input is cleaned up*/
typedef struct
{
    int state;     /* FSM for ISO2022 */
    Bool pushed;
    int c;
    int tabs;
    int lastcol;
    int curcol;
    int curline;
    int encoding;
#ifdef BIF_TIDY
    tidy_io_t input;
#else
    FILE *file;
#endif
    Lexer *lexer;  /* needed for error reporting */
} StreamIn;

#ifdef BIF_TIDY
StreamIn *OpenInputBoxString(caddr_t html_input);
#else
StreamIn *OpenInputFile(FILE *fp);
#endif
int ReadChar(StreamIn *in);
void UngetChar(int c, StreamIn *in);


#ifdef BIF_TIDY
typedef tidy_io_t errout_t;
#define errout errout_tio
extern errout_t *errout;
#else
typedef FILE errout_t;
#define errout errout_file
#endif

/*
  The following are private to the lexer
  Use NewLexer(fp) to create a lexer, and
  FreeLexer(lexer) to free it.
*/

struct _lexer
{
    StreamIn *in;   /* file stream */
#ifdef BIF_TIDY
    tidy_io_t *errout_tio;   /* error output stream */
#else
    FILE *errout_file;   /* error output stream */
#endif
    uint badAccess; /* for accessibility errors */
    uint badLayout; /* for bad style errors */
    uint badChars;  /* for bad char encodings */
    uint badForm;   /* for mismatched/mispositioned form tags */
    uint warnings;  /* count of warnings in this document */
    uint errors;    /* count of errors */
    uint lines;     /* lines seen */
    uint columns;   /* at start of current token */
    Bool waswhite;  /* used to collapse contiguous white space */
    Bool pushed;    /* true after token has been pushed back */
    Bool insertspace;   /* when space is moved after end tag */
    Bool excludeBlocks;  /* Netscape compatibility */
    Bool exiled;    /* true if moved out of table */
    Bool isvoyager; /* true if xmlns attribute on html element */
    uint versions;  /* bit vector of HTML versions */
    int doctype;    /* version as given by doctype (if any) */
    Bool bad_doctype; /* e.g. if html or PUBLIC is missing */
    uint txtstart;  /* start of current node */
    uint txtend;    /* end of current node */
    uint state;     /* state of lexer's finite state machine */
    struct _node *token;

    /*
      lexer character buffer

      parse tree nodes span onto this buffer
      which contains the concatenated text
      contents of all of the elements.

     lexsize must be reset for each file.
    */
    char *lexbuf;     /* char buffer */
    uint lexlength;   /* allocated */
    uint lexsize;     /* used */

    /* Inline stack for compatibility with Mosaic */
    Node *inode;        /* for deferring text node */
    IStack *insert;     /* for inferring inline tags */
    IStack *istack;
    uint istacklength;  /* allocated */
    uint istacksize;    /* used */
    uint istackbase;    /* start of frame */

    Style *styles;      /* used for cleaning up presentation markup */
};

typedef void (Parser)(Lexer *lexer, Node *node, uint mode);
typedef void (CheckAttribs)(Lexer *lexer, Node *node);

/* declaration for methods that check attribute values */
typedef void (AttrCheck)(Lexer *lexer, Node *node, AttVal *attval);

struct _attribute
{
    struct _attribute *next;
    char *name;
    Bool nowrap;
    Bool literal;
    unsigned versions;
    AttrCheck *attrchk;
};

typedef struct _attribute Attribute;

/* well known attributes */
extern Attribute *attr_href;
extern Attribute *attr_src;
extern Attribute *attr_id;
extern Attribute *attr_name;
extern Attribute *attr_summary;
extern Attribute *attr_alt;
extern Attribute *attr_longdesc;
extern Attribute *attr_title;

/*
 Tag dictionary node
*/

struct _tagdict
{
    struct _tagdict *next;
    char *name;
    uint versions;
    uint model;
    Parser *parser;
    CheckAttribs *chkattrs;
};

typedef struct _tagdict Dict;

/* modes for GetToken() */
#define IgnoreWhitespace    0
#define MixedContent        1
#define Preformatted        2
#define IgnoreMarkup        3

#ifdef BIF_TIDY
/* void FatalError(char *msg); */
/* void FileError(FILE *fp, const char *file); -- bif have no file i/o */
#else
extern void FatalError(char *msg);
extern void FileError(FILE *fp, const char *file);
#endif

Node *GetToken(Lexer *lexer, uint mode);

/* one level unget only */
void UngetToken(Lexer *lexer);

/* create lexer for a file stream */
Lexer *NewLexer(StreamIn *in);

/* delete lexer */
void FreeLexer(Lexer *lexer);

Bool EndOfInput(Lexer *lexer);

/* used for script or style */
Node *GetCDATA(Lexer *lexer, Node *container);

/* use this to create node for inferred start tag */
Node *InferredTag(Lexer *lexer, char *name);

/* used to create line break in preformatted text
   when cleaning the augean stables (Word2000) */
Node *NewLineNode(Lexer *lexer);

/* Parser calls this to create RootNode */
Node *NewNode(void);
AttVal *NewAttribute(void);

void FreeAttrs(Node *node);
void FreeAttribute(AttVal *av);
void RemoveAttribute(Node *node, AttVal *attr);

/* use this to free parse tree node and all its children */
void FreeNode(Node *node);

/* used to clone heading nodes when split by an <HR> */
Node *CloneNode(Lexer *lexer, Node *element);

/* lexer char map - must be initialized */
void InitMap(void);

void AddCharToLexer(Lexer *lexer, uint c);
void AddStringLiteral(Lexer *lexer, char *str);
Node *TextToken(Lexer *lexer);

/* used by pretty printer for tag names */
char FoldCase(char c, Bool tocaps);

Bool IsLetter(uint c);
Bool IsDigit(uint c);
Bool IsWhite(uint c);

/* used to fixup doctype to match contents */
Node *FindDocType(Node *root);
Node *FindHTML(Node *root);
Node *FindHEAD(Node *root);
Bool AddGenerator(Lexer *lexer, Node *root);
void DiscardDocType(Node *root);
Bool FixDocType(Lexer *lexer, Node *node);
char *HTMLVersionName(Lexer *lexer);
int ApparentVersion(Lexer *lexer);
Bool FixXMLPI(Lexer *lexer, Node *root);
Bool SetXHTMLDocType(Lexer *lexer, Node *root);
void FixId(Lexer *lexer, Node *node);
Bool CheckDocTypeKeyWords(Lexer *lexer, Node *doctype);

/* used to detect faulty attributes */
Bool IsValidAttrName( char *attr);

/* parser.c */
Node *ParseDocument(Lexer *lexer);
Node *ParseXMLDocument(Lexer *lexer);
Bool XMLPreserveWhiteSpace(Node *element);
void CoerceNode(Lexer *lexer, Node *node, Dict *tag);
Bool CheckNodeIntegrity(Node *node);
Bool IsNewNode(Node *node);
void RemoveNode(Node *node);
Node *DiscardElement(Node *element);
void InsertNodeAtStart(Node *element, Node *node);
void InsertNodeAtEnd(Node *element, Node *node);
void InsertNodeBeforeElement(Node *element, Node *node);
void InsertNodeAfterElement(Node *element, Node *node);
Bool IsJavaScript(Node *node);

/* attrs.c */
void InitAttrs(void);
void FreeAttrTable(void);
Attribute *FindAttribute(AttVal *attval);
AttVal *GetAttrByName(Node *node, char *name);
void AddAttribute(Node *node, char *name, char *value);
void CheckUniqueAttributes(Lexer *lexer, Node *node);
void CheckAttributes(Lexer *lexer, Node *node);
Attribute *CheckAttribute(Lexer *lexer, Node *node, AttVal *attval);
Bool IsUrl(char *attrname);
Bool IsScript(char *attrname);
void DeclareLiteralAttrib(char *name);
Bool IsLiteralAttribute(char *attrname);

/* istack.c */
void PushInline(Lexer *lexer, Node *node);
void PopInline(Lexer *lexer, Node *node);
Bool IsPushed(Lexer *lexer, Node *node);
int InlineDup(Lexer *lexer, Node *node);
Node *InsertedToken(Lexer *lexer);
AttVal *DupAttrs(AttVal *attrs);
void DeferDup(Lexer *lexer);
void InsertNode(Node *element, Node *node);

/* clean.c */
void FreeStyles(Lexer *lexer);
void AddClass(Node *node, char *classname);
void CleanTree(Lexer *lexer, Node *node);
void NestedEmphasis(Node *node);
void EmFromI(Node *node);
void CleanWord2000(Lexer *lexer, Node *node);
void DropSections(Lexer *lexer, Node *node);
void List2BQ(Node *node);
void BQ2Div(Node *node);
Bool IsWord2000(Node *root);

/* entities.c */
void InitEntities(void);
void FreeEntities(void);
uint EntityCode(char *name);
char *EntityName(uint n);

/* tags.c */
void DefineEmptyTag(char *name);
void DefineInlineTag(char *name);
void DefineBlockTag(char *name);
void DefinePreTag(char *name);

Bool FindTag(Node *node);
void InitTags(void);
void FreeTags(void);
Parser *FindParser(Node *node);
int HTMLVersion(Lexer *lexer);

/* localize.c -- used for all message text */
#ifdef BIF_TIDY
extern void tidy_out_tio (errout_t *tio, int maxlen, const char* msg, ...);
#define tidy_out tidy_out_tio
#else
extern void tidy_out_file(errout_t *fp, int maxlen, const char* msg, ...);
#define tidy_out tidy_out_file
#endif

#ifdef BIF_TIDY
/* void ShowVersion(FILE *fp); -- Bif will never show its version on screen */
#else
void ShowVersion(FILE *fp);
#endif
void ReadingFromStdin(void);
void ReportUnknownOption(char *option);
void ReportBadArgument(char *option);
void NeedsAuthorIntervention(errout_t *errout);
void MissingBody(errout_t *errout);
void ReportNumberOfSlides(errout_t *errout, int count);
void GeneralInfo(errout_t *errout);
void HelloMessage(errout_t *errout, char *date, char *filename);
#ifdef BIF_TIDY
extern void ReportVersion4bif(errout_t *errout, Lexer *lexer, Node *doctype);
#else
extern void ReportVersion(errout_t *errout, Lexer *lexer, char *filename, Node *doctype);
#endif
void ReportNumWarnings(errout_t *errout, Lexer *lexer);

/* pprint.c */
uint GetUTF8(unsigned char *str, uint *ch);
char *PutUTF8(char *buf, uint c);
void FreePrintBuf(void);
void PPrintTree(Out *out, uint mode, uint indent,
                    Lexer *lexer, Node *node);
void PPrintXMLTree(Out *fout, uint mode, uint indent,
                    Lexer *lexer, Node *node);
void PFlushLine(Out *out, uint indent);
void PCondFlushLine(Out *out, uint indent);
void AddTransitionEffect(Lexer *lexer, Node *root, int effect, float duration);
Node *FindHead(Node *root);
Node *FindBody(Node *root);

/* tidy.c */
#define EndOfStream EOF

#ifdef BIF_TIDY
extern mem_pool_t *tidy_mp;
#define MemAlloc(size) mp_alloc_box(tidy_mp, (size), DV_NON_BOX)
#define MemFree(mem) /**/
#define ClearMemory(mem, size) memset((mem), 0, (size))
#else
extern void *MemAlloc(uint size);
extern void MemFree(void *mem);
extern void ClearMemory(void *, uint size);
#endif
extern void *MemRealloc(void *mem, uint newsize);

/* string functions */
uint ToLower(uint c);
char *wstrdup(char *str);
char *wstrndup(char *str, int len);
void wstrncpy(char *s1, char *s2, int size);
void wstrcat(char *s1, char *s2);
void wstrcpy(char *s1, char *s2);
int wstrcmp(char *s1, char *s2);
int wstrcasecmp(char *s1, char *s2);
int wstrncmp(char *s1, char *s2, int n);
int wstrncasecmp(char *s1, char *s2, int n);
int wstrlen(char *str);
Bool wsubstr(char *s1, char *s2);

#define uprintf fprintf

/* error codes for entities */

#define MISSING_SEMICOLON       1
#define UNKNOWN_ENTITY          2
#define UNESCAPED_AMPERSAND     3

/* error codes for element messages */

#define MISSING_ENDTAG_FOR      1
#define MISSING_ENDTAG_BEFORE   2
#define DISCARDING_UNEXPECTED   3
#define NESTED_EMPHASIS         4
#define NON_MATCHING_ENDTAG     5
#define TAG_NOT_ALLOWED_IN      6
#define MISSING_STARTTAG        7
#define UNEXPECTED_ENDTAG       8
#define USING_BR_INPLACE_OF     9
#define INSERTING_TAG           10
#define SUSPECTED_MISSING_QUOTE 11
#define MISSING_TITLE_ELEMENT   12
#define DUPLICATE_FRAMESET      13
#define CANT_BE_NESTED          14
#define OBSOLETE_ELEMENT        15
#define PROPRIETARY_ELEMENT     16
#define UNKNOWN_ELEMENT         17
#define TRIM_EMPTY_ELEMENT      18
#define COERCE_TO_ENDTAG        19
#define ILLEGAL_NESTING         20
#define NOFRAMES_CONTENT        21
#define CONTENT_AFTER_BODY      22
#define INCONSISTENT_VERSION    23
#define MALFORMED_COMMENT       24
#define BAD_COMMENT_CHARS       25
#define BAD_XML_COMMENT         26
#define BAD_CDATA_CONTENT       27
#define INCONSISTENT_NAMESPACE  28
#define DOCTYPE_AFTER_TAGS      29
#define MALFORMED_DOCTYPE       30
#define UNEXPECTED_END_OF_FILE  31
#define DTYPE_NOT_UPPER_CASE    32
#define TOO_MANY_ELEMENTS       33

/* error codes used for attribute messages */

#define UNKNOWN_ATTRIBUTE       1
#define MISSING_ATTRIBUTE       2
#define MISSING_ATTR_VALUE      3
#define BAD_ATTRIBUTE_VALUE     4
#define UNEXPECTED_GT           5
#define PROPRIETARY_ATTR_VALUE  6
#define REPEATED_ATTRIBUTE      7
#define MISSING_IMAGEMAP        8
#define XML_ATTRIBUTE_VALUE     9
#define UNEXPECTED_QUOTEMARK    10
#define ID_NAME_MISMATCH        11

/* page transition effects */

#define EFFECT_BLEND               -1
#define EFFECT_BOX_IN               0
#define EFFECT_BOX_OUT              1
#define EFFECT_CIRCLE_IN            2
#define EFFECT_CIRCLE_OUT           3
#define EFFECT_WIPE_UP              4
#define EFFECT_WIPE_DOWN            5
#define EFFECT_WIPE_RIGHT           6
#define EFFECT_WIPE_LEFT            7
#define EFFECT_VERT_BLINDS          8
#define EFFECT_HORZ_BLINDS          9
#define EFFECT_CHK_ACROSS          10
#define EFFECT_CHK_DOWN            11
#define EFFECT_RND_DISSOLVE        12
#define EFFECT_SPLIT_VIRT_IN       13
#define EFFECT_SPLIT_VIRT_OUT      14
#define EFFECT_SPLIT_HORZ_IN       15
#define EFFECT_SPLIT_HORZ_OUT      16
#define EFFECT_STRIPS_LEFT_DOWN    17
#define EFFECT_STRIPS_LEFT_UP      18
#define EFFECT_STRIPS_RIGHT_DOWN   19
#define EFFECT_STRIPS_RIGHT_UP     20
#define EFFECT_RND_BARS_HORZ       21
#define EFFECT_RND_BARS_VERT       22
#define EFFECT_RANDOM              23

/* accessibility flaws */

#define MISSING_IMAGE_ALT       1
#define MISSING_LINK_ALT        2
#define MISSING_SUMMARY         4
#define MISSING_IMAGE_MAP       8
#define USING_FRAMES            16
#define USING_NOFRAMES          32

/* presentation flaws */

#define USING_SPACER            1
#define USING_LAYER             2
#define USING_NOBR              4
#define USING_FONT              8
#define USING_BODY              16

/* character encoding errors */
#define WINDOWS_CHARS           1
#define NON_ASCII               2
#define FOUND_UTF16             4

#ifdef BIF_TIDY
/* extern void HelpText(errout_t *errout, char *prog); -- bif emits no help texts */
#else
extern void HelpText(errout_t *errout, char *prog);
#endif
void GeneralInfo(errout_t *errout);
void UnknownOption(errout_t *errout, char c);
void UnknownFile(errout_t *errout, char *program, char *file);
void ErrorSummary(Lexer *lexer);
void ReportEncodingError(Lexer *lexer, uint code, uint c);
void ReportEntityError(Lexer *lexer, uint code, char *entity, int c);
void ReportAttrError(Lexer *lexer, Node *node, char *attr, uint code);
void ReportWarning(Lexer *lexer, Node *element, Node *node, uint code);
void ReportError(Lexer *lexer, Node *element, Node *node, uint code);

/* slide maker functions */
Node *FindBody(Node *node);

#ifdef BIF_TIDY
/* bif version does not support cutting of HTML into slides */
#else
/* counts number of h1 children belonging to node */
int CountSlides(Node *node);
void PPrintSlide(Out *fout, uint mode, uint indent, Lexer *lexer);
void CreateSlides(Lexer *lexer, Node *root);
#endif

/* config parameters, see config.c for defaults */

void InitConfig(void);
void FreeConfig(void);
#ifdef BIF_TIDY
extern void ParseConfigBoxString(caddr_t data);
#else
extern void ParseConfigFile(char *file);
#endif
Bool ParseConfig(char *option, char *parameter);
void AdjustConfig(void);

extern uint spaces;         /* default indentation */
extern uint wraplen;        /* default wrap margin */
extern int CharEncoding;
extern int tabsize;

extern DocTypeMode doctype_mode;   /* see doctype property */
extern char *doctype_str;   /* user specified doctype */
extern char *slide_style;   /* style sheet for slides */

extern char *errfile;       /* file name to write errors to */
extern Bool writeback;      /* if true then output tidied markup */
extern Bool KeepFileTimes;  /* if true keeps last modified time */

extern Bool TidyMark;       /* add meta element indicating tidied doc */
extern Bool OnlyErrors;     /* if true normal output is suppressed */
extern Bool ShowWarnings;   /* errors are always shown */
extern Bool Quiet;
extern Bool IndentContent;
extern Bool SmartIndent;
extern Bool HideEndTags;
extern Bool XmlTags;
extern Bool XmlOut;
extern Bool xHTML;
extern Bool XmlPi;      /* add <?xml?> */
extern Bool XmlPIs;     /* assume PIs end with ?> as per XML */
extern Bool XmlSpace;
extern Bool RawOut;
extern Bool UpperCaseTags;
extern Bool UpperCaseAttrs;
extern Bool MakeClean;
extern Bool LogicalEmphasis;
extern Bool DropEmptyParas;
extern Bool FixComments;
extern Bool DropFontTags;
extern Bool EncloseBodyText;
extern Bool EncloseBlockText;
extern Bool BurstSlides;
extern Bool BreakBeforeBR;
extern Bool NumEntities;
extern Bool QuoteMarks;
extern Bool QuoteNbsp;
extern Bool QuoteAmpersand;
extern Bool WrapAttVals;
extern Bool WrapScriptlets;
extern Bool WrapSection;
extern Bool WrapAsp;
extern Bool WrapJste;
extern Bool WrapPhp;
extern Bool FixBackslash;
extern Bool IndentAttributes;
extern Bool Word2000;
extern Bool Emacs;  /* sasdjb 01May00 GNU Emacs error output format */
extern Bool LiteralAttribs;

/* Parser methods for tags */

Parser ParseHTML;
Parser ParseHead;
Parser ParseTitle;
Parser ParseScript;
Parser ParseFrameSet;
Parser ParseNoFrames;
Parser ParseBody;
Parser ParsePre;
Parser ParseList;
Parser ParseLI;
Parser ParseDefList;
Parser ParseBlock;
Parser ParseInline;
Parser ParseTableTag;
Parser ParseColGroup;
Parser ParseRowGroup;
Parser ParseRow;
Parser ParseSelect;
Parser ParseOptGroup;
Parser ParseText;
Parser ParseObject;
Parser ParseMap;

/* Attribute checking methods */

CheckAttribs CheckHR;
CheckAttribs CheckIMG;
CheckAttribs CheckAnchor;
CheckAttribs CheckLINK;
CheckAttribs CheckMap;
CheckAttribs CheckAREA;
CheckAttribs CheckTABLE;
CheckAttribs CheckTableCell;
CheckAttribs CheckCaption;
CheckAttribs CheckSCRIPT;
CheckAttribs CheckSTYLE;
CheckAttribs CheckHTML;

/* used to control printing of null attributes */
Bool IsBoolAttribute(AttVal *attval);

extern Dict *tag_html;
extern Dict *tag_head;
extern Dict *tag_body;
extern Dict *tag_frameset;
extern Dict *tag_frame;
extern Dict *tag_noframes;
extern Dict *tag_title;
extern Dict *tag_base;
extern Dict *tag_hr;
extern Dict *tag_meta;
extern Dict *tag_pre;
extern Dict *tag_listing;
extern Dict *tag_h1;
extern Dict *tag_h2;
extern Dict *tag_p;
extern Dict *tag_ul;
extern Dict *tag_ol;
extern Dict *tag_dir;
extern Dict *tag_li;
extern Dict *tag_dt;
extern Dict *tag_dd;
extern Dict *tag_dl;
extern Dict *tag_td;
extern Dict *tag_th;
extern Dict *tag_tr;
extern Dict *tag_col;
extern Dict *tag_br;
extern Dict *tag_a;
extern Dict *tag_link;
extern Dict *tag_b;
extern Dict *tag_i;
extern Dict *tag_strong;
extern Dict *tag_em;
extern Dict *tag_big;
extern Dict *tag_small;
extern Dict *tag_param;
extern Dict *tag_option;
extern Dict *tag_optgroup;
extern Dict *tag_img;
extern Dict *tag_map;
extern Dict *tag_area;
extern Dict *tag_nobr;
extern Dict *tag_wbr;
extern Dict *tag_layer;
extern Dict *tag_center;
extern Dict *tag_spacer;
extern Dict *tag_font;
extern Dict *tag_style;
extern Dict *tag_script;
extern Dict *tag_noscript;
extern Dict *tag_table;
extern Dict *tag_caption;
extern Dict *tag_form;
extern Dict *tag_textarea;
extern Dict *tag_blockquote;
extern Dict *tag_applet;
extern Dict *tag_object;
extern Dict *tag_div;
extern Dict *tag_span;

#endif /* __HTML_H_010606 */
