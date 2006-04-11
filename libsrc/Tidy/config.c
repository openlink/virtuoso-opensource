/*
  config.c - read config file and manage config properties
  
  (c) 1998-2000 (W3C) MIT, INRIA, Keio University
  See tidy.c for the copyright notice.
 *
 * $Id$
 *
 *  Changes are (C)Copyright 2001 OpenLink Software.
 *  All Rights Reserved.
 *
 *  The copyright above and this notice must be preserved in all
 *  copies of this source code.  The copyright above does not
 *  evidence any actual or intended publication of this source code.
 *
 *  This is unpublished proprietary trade secret of OpenLink Software.
 *  This source code may not be copied, disclosed, distributed, demonstrated
 *  or licensed except as authorized by OpenLink Software.
 *
*/

/*
  config files associate a property name with a value.

  // comments can start at the beginning of a line
  name: short values fit onto one line
  name: a really long value that
   continues on the next line

  property names are case insensitive and should be less than
  60 characters in length and must start at the begining of
  the line, as whitespace at the start of a line signifies a
  line continuation.
*/

#include "platform.h"
#include "html.h"

typedef union
{
    int *number;
    Bool *logical;
    char **string;
} Location;

typedef void (ParseProperty)(Location location, char *option);

ParseProperty ParseInt;     /* parser for integer values */
ParseProperty ParseBool;    /* parser for 'true' or 'false' or 'yes' or 'no' */
ParseProperty ParseInvBool; /* parser for 'true' or 'false' or 'yes' or 'no' */
ParseProperty ParseName;    /* a string excluding whitespace */
ParseProperty ParseString;  /* a string including whitespace */
ParseProperty ParseTagNames; /* a space separated list of tag names */
ParseProperty ParseCharEncoding; /* RAW, ASCII, LATIN1, UTF8 or ISO2022 */
ParseProperty ParseIndent;   /* specific to the indent option */
ParseProperty ParseDocType;  /* omit | auto | strict | loose | <fpi> */

uint spaces =  2;           /* default indentation */
uint wraplen = 68;          /* default wrap margin */
int CharEncoding = ASCII;
int tabsize = 4;

DocTypeMode doctype_mode = doctype_auto; /* see doctype property */
char *alt_text = null;      /* default text for alt attribute */
char *slide_style = null;   /* style sheet for slides */
char *doctype_str = null;   /* user specified doctype */
char *errfile = null;       /* file name to write errors to */
Bool writeback = no;        /* if true then output tidied markup */

Bool OnlyErrors = no;       /* if true normal output is suppressed */
Bool ShowWarnings = yes;    /* however errors are always shown */
Bool Quiet = no;            /* no 'Parsing X', guessed DTD or summary */
Bool IndentContent = no;    /* indent content of appropriate tags */
Bool SmartIndent = no;      /* does text/block level content effect indentation */
Bool HideEndTags = no;      /* suppress optional end tags */
Bool XmlTags = no;          /* treat input as XML */
Bool XmlOut = no;           /* create output as XML */
Bool xHTML = no;            /* output extensible HTML */
Bool XmlPi = no;            /* add <?xml?> for XML docs */
Bool RawOut = no;           /* avoid mapping values > 127 to entities */
Bool UpperCaseTags = no;    /* output tags in upper not lower case */
Bool UpperCaseAttrs = no;   /* output attributes in upper not lower case */
Bool MakeClean = no;        /* replace presentational clutter by style rules */
Bool LogicalEmphasis = no;  /* replace i by em and b by strong */
Bool DropFontTags = no;     /* discard presentation tags */
Bool DropEmptyParas = yes;  /* discard empty p elements */
Bool FixComments = yes;     /* fix comments with adjacent hyphens */
Bool BreakBeforeBR = no;    /* o/p newline before <br> or not? */
Bool BurstSlides = no;      /* create slides on each h2 element */
Bool NumEntities = no;      /* use numeric entities */
Bool QuoteMarks = no;       /* output " marks as &quot; */
Bool QuoteNbsp = yes;       /* output non-breaking space as entity */
Bool QuoteAmpersand = yes;  /* output naked ampersand as &amp; */
Bool WrapAttVals = no;      /* wrap within attribute values */
Bool WrapScriptlets = no;   /* wrap within JavaScript string literals */
Bool WrapSection = yes;     /* wrap within <![ ... ]> section tags */
Bool WrapAsp = yes;         /* wrap within ASP pseudo elements */
Bool WrapJste = yes;        /* wrap within JSTE pseudo elements */
Bool WrapPhp = yes;         /* wrap within PHP pseudo elements */
Bool FixBackslash = yes;    /* fix URLs by replacing \ with / */
Bool IndentAttributes = no; /* newline+indent before each attribute */
Bool XmlPIs = no;           /* if set to yes PIs must end with ?> */
Bool XmlSpace = no;         /* if set to yes adds xml:space attr as needed */
Bool EncloseBodyText = no;  /* if yes text at body is wrapped in <p>'s */
Bool EncloseBlockText = no; /* if yes text in blocks is wrapped in <p>'s */
Bool KeepFileTimes = yes;   /* if yes last modied time is preserved */
Bool Word2000 = no;         /* draconian cleaning for Word2000 */
Bool TidyMark = yes;        /* add meta element indicating tidied doc */
Bool Emacs = no;            /* if true format error output for GNU Emacs */
Bool LiteralAttribs = no;   /* if true attributes may use newlines */

typedef struct _lex PLex;

static uint c;      /* current char in input stream */
#ifdef BIF_TIDY
static tidy_io_t fin;   /* quasi-file pointer for configuration input */
#else
static FILE *fin;   /* file pointer for input stream */
#endif

/* not used to store anything */
static char *inline_tags;
static char *block_tags;
static char *empty_tags;
static char *pre_tags;


typedef struct _plist PList;

struct _plist
{
    char *name;                     /* property name */
    Location location;              /* place to store value */
    ParseProperty *parser;          /* parsing method */
    PList *next;                    /* linear hash chaining */
};

#define HASHSIZE 101

static PList *hashtable[HASHSIZE];   /* private hash table */

/* used parsing the command line */
static char *config_text;

static struct Flag
{
    char *name;                     /* property name */
    Location location;              /* place to store value */
    ParseProperty *parser;          /* parsing method */
} flags[] =
{
    {"indent-spaces",   {(int *)&spaces},           ParseInt},
    {"wrap",            {(int *)&wraplen},          ParseInt},
    {"wrap-attributes", {(int *)&WrapAttVals},      ParseBool},
    {"wrap-script-literals", {(int *)&WrapScriptlets}, ParseBool},
    {"wrap-sections",   {(int *)&WrapSection},      ParseBool},
    {"wrap-asp",        {(int *)&WrapAsp},          ParseBool},
    {"wrap-jste",       {(int *)&WrapJste},         ParseBool},
    {"wrap-php",        {(int *)&WrapPhp},          ParseBool},
    {"literal-attributes", {(int *)&LiteralAttribs}, ParseBool},
    {"tab-size",        {(int *)&tabsize},          ParseInt},
    {"markup",          {(int *)&OnlyErrors},       ParseInvBool},
    {"quiet",           {(int *)&Quiet},            ParseBool},
    {"tidy-mark",       {(int *)&TidyMark},         ParseBool},
    {"indent",          {(int *)&IndentContent},    ParseIndent},
    {"indent-attributes", {(int *)&IndentAttributes}, ParseBool},
    {"hide-endtags",    {(int *)&HideEndTags},      ParseBool},
    {"input-xml",       {(int *)&XmlTags},          ParseBool},
    {"output-xml",      {(int *)&XmlOut},           ParseBool},
    {"output-xhtml",    {(int *)&xHTML},            ParseBool},
    {"add-xml-pi",      {(int *)&XmlPi},            ParseBool},
    {"add-xml-decl",    {(int *)&XmlPi},            ParseBool},
    {"assume-xml-procins",  {(int *)&XmlPIs},       ParseBool},
    {"raw",             {(int *)&RawOut},           ParseBool},
    {"uppercase-tags",  {(int *)&UpperCaseTags},    ParseBool},
    {"uppercase-attributes", {(int *)&UpperCaseAttrs}, ParseBool},
    {"clean",           {(int *)&MakeClean},        ParseBool},
    {"logical-emphasis", {(int *)&LogicalEmphasis}, ParseBool},
    {"word-2000",       {(int *)&Word2000},         ParseBool},
    {"drop-empty-paras", {(int *)&DropEmptyParas},  ParseBool},
    {"drop-font-tags",  {(int *)&DropFontTags},     ParseBool},
    {"enclose-text",    {(int *)&EncloseBodyText},  ParseBool},
    {"enclose-block-text", {(int *)&EncloseBlockText}, ParseBool},
    {"alt-text",        {(int *)&alt_text},         ParseString},
    {"add-xml-space",   {(int *)&XmlSpace},         ParseBool},
    {"fix-bad-comments", {(int *)&FixComments},     ParseBool},
    {"split",           {(int *)&BurstSlides},      ParseBool},
    {"break-before-br", {(int *)&BreakBeforeBR},    ParseBool},
    {"numeric-entities", {(int *)&NumEntities},     ParseBool},
    {"quote-marks",     {(int *)&QuoteMarks},       ParseBool},
    {"quote-nbsp",      {(int *)&QuoteNbsp},        ParseBool},
    {"quote-ampersand", {(int *)&QuoteAmpersand},   ParseBool},
    {"write-back",      {(int *)&writeback},        ParseBool},
    {"keep-time",       {(int *)&KeepFileTimes},    ParseBool},
    {"show-warnings",   {(int *)&ShowWarnings},     ParseBool},
    {"error-file",      {(int *)&errfile},          ParseString},
    {"slide-style",     {(int *)&slide_style},      ParseName},
    {"new-inline-tags",     {(int *)&inline_tags},  ParseTagNames},
    {"new-blocklevel-tags", {(int *)&block_tags},   ParseTagNames},
    {"new-empty-tags",  {(int *)&empty_tags},       ParseTagNames},
    {"new-pre-tags",    {(int *)&pre_tags},         ParseTagNames},
    {"char-encoding",   {(int *)&CharEncoding},     ParseCharEncoding},
    {"doctype",         {(int *)&doctype_str},      ParseDocType},
    {"fix-backslash",   {(int *)&FixBackslash},     ParseBool},
    {"gnu-emacs",       {(int *)&Emacs},            ParseBool},

  /* this must be the final entry */
    {0,          0,             0}
};

static unsigned hash(char *s)
{
    unsigned hashval;

    for (hashval = 0; *s != '\0'; s++)
        hashval = toupper(*s) + 31*hashval;

    return hashval % HASHSIZE;
}

static PList *lookup(char *s)
{
    PList *np;

    for (np = hashtable[hash(s)]; np != null; np = np->next)
        if (wstrcmp(s, np->name) == 0)
            return np;
    return null;
}

static PList *install(char *name, Location location, ParseProperty *parser)
{
    PList *np;
    unsigned hashval;

    if (null == name)
      return null;

    np = lookup(name);
    if (null == np)
    {
        np = (PList *)MemAlloc(sizeof(*np));
        np->name = wstrdup(name);
        hashval = hash(name);
        np->next = hashtable[hashval];
        hashtable[hashval] = np;
    }

    np->location = location;
    np->parser = parser;
    return np;
}

void InitConfig(void)
{
    struct Flag *p;

    for(p = flags; p->name != null; ++p)
	install(p->name, p->location, p->parser);

    c = 0;  /* init single char buffer */
}

void FreeConfig(void)
{
    PList *prev, *next;
    int i;

    for (i = 0; i < HASHSIZE; ++i)
    {
        prev = null;
        next = hashtable[i];

        while(next)
        {
            prev = next->next;
            MemFree(next->name);
            MemFree(next);
            next = prev;
        }

        hashtable[i] = null;
    }

    if (slide_style)
        MemFree(slide_style);

    if (doctype_str)
        MemFree(doctype_str);

    if (errfile)
        MemFree(errfile);
}

#ifdef BIF_TIDY

#define GetC(fin) \
 ((fin.tio_pos >= fin.tio_data.lm_length) ? \
  (((NULL == config_text) || ('\0' == config_text[0])) ? EOF : *config_text++) : \
  (fin.tio_data.lm_memblock[fin.tio_pos++]) )

#else

static unsigned GetC(FILE *fp)
{
    if (fp)
        return getc(fp);

    if (!config_text)
        return EOF;
 
    if (*config_text)
        return *config_text++;

    return EOF;
}

#endif

static int AdvanceChar()
{
    if (c != EOF)
        c = (uint)GetC(fin);
    return c;
}

static int SkipWhite()
{
    while (IsWhite((uint) c))
        c = (uint)GetC(fin);
    return c;
}

/* skip until end of line */
static void SkipToEndofLine()
{
    while (c != EOF)
    {
        c = (uint)GetC(fin);

        if (c == '\n' || c == '\r')
            break;
    }
}

/*
 skip over line continuations
 to start of next property
*/
static int NextProperty()
{
    do
    {
        /* skip to end of line */
        while (c != '\n' && c != '\r' && c != EOF)
            c = (uint)GetC(fin);

        /* treat  \r\n   \r  or  \n as line ends */
        if (c == '\r')
            c = (uint)GetC(fin);

        if (c == '\n')
            c = (uint)GetC(fin);
    }
    while (IsWhite(c));  /* line continuation? */

    return c;
}

#ifndef BIF_TIDY

#ifdef SUPPORT_GETPWNAM
/*
 Tod Lewis contributed this code for expanding
 ~/foo or ~your/foo according to $HOME and your
 user name. This will only work on Unix systems.
*/
const char *ExpandTilde(const char *filename)
{
    static char *expanded_filename;

    char *home_dir, *p;
    struct passwd *passwd = NULL;

    if (!filename) return(NULL);

    if (filename[0] != '~')
        return(filename);

    if (filename[1] == '/')
    {
        home_dir = getenv("HOME");
        filename++;
    }
    else
    {
        const char *s;
        char *t;

        s = filename+1;

        while(*s && *s != '/') s++;

        if (t = MemAlloc(s - filename))
        {
            memcpy(t, filename+1, s-filename-1);
            t[s-filename-1] = 0;

            passwd = getpwnam(t);

            MemFree(t);
        }

        if (!passwd)
            return(filename);

        filename = s;
        home_dir = passwd->pw_dir;
    }

    if (p = realloc(expanded_filename, strlen(filename)+strlen(home_dir)+1))
    {
        strcat(strcpy(expanded_filename = p, home_dir), filename);
        return(expanded_filename);
    }

    return(filename);
}
#endif /* SUPPORT_GETPWNAM */

#endif

#ifdef BIF_TIDY

void ParseConfigBoxString(caddr_t data)
{
    int i;
    char name[64];
    PList *entry;

    /* setup property name -> parser table*/

    InitConfig();

    /* open the file and parse its contents */

    fin.tio_data.lm_memblock = data;
    fin.tio_data.lm_length = box_length(data)-1;
    fin.tio_pos = 0;
    {
        config_text = null;
        AdvanceChar();  /* first char */

        while (c != EOF)
        {
            /* // starts a comment */
            while (c == '/')
                NextProperty();

            i = 0;

            while (c != ':' && c != EOF && i < 60)
            {
                name[i++] = (char)c;
                AdvanceChar();
            }

            name[i] = '\0';
            entry = lookup(name);

            if (c == ':' && entry)
            {
                AdvanceChar();
                entry->parser(entry->location, name);
            }
            else
                NextProperty();
        }

    }
}

/* returns false if unknown or doesn't use parameter */
Bool ParseConfig(char *option, char *parameter)
{
    PList *entry;
    int tio_pos_save;
    if (option && parameter)
    {
        tio_pos_save = fin.tio_pos;
        fin.tio_pos = fin.tio_data.lm_length;
        c = *parameter;
        parameter++;
        entry = lookup(option);
        if (!entry)
        {
            fin.tio_pos = tio_pos_save;
            ReportUnknownOption(option);
            return no;
        }
        config_text = parameter;
        entry->parser(entry->location, option);
        fin.tio_pos = tio_pos_save;
    }
    return yes;
}

#else

void ParseConfigFile(char *file)
{
    int i;
    char name[64];
    const char *fname;
    PList *entry;

    /* setup property name -> parser table*/

    InitConfig();

#ifdef SUPPORT_GETPWNAM
    /* expand filenames starting with ~ */
    fname = ExpandTilde( file );
#else
    fname = file;
#endif

    /* open the file and parse its contents */

    if ((fin = fopen(fname, "r")) == null)
        FileError(stderr, fname);
    else
    {
        config_text = null;
        AdvanceChar();  /* first char */

        while (c != EOF)
        {
            /* // starts a comment */
            while (c == '/')
                NextProperty();

            i = 0;

            while (c != ':' && c != EOF && i < 60)
            {
                name[i++] = (char)c;
                AdvanceChar();
            }

            name[i] = '\0';
            entry = lookup(name);

            if (c == ':' && entry)
            {
                AdvanceChar();
                entry->parser(entry->location, name);
            }
            else
                NextProperty();
        }

        fclose(fin);
    }
}

/* returns false if unknown or doesn't use parameter */
Bool ParseConfig(char *option, char *parameter)
{
    PList *entry;
    FILE *ffp;

    if (option && parameter)
    {
        ffp = fin;
    
        fin = null;
    
        c = *parameter;
        parameter++;
    
        entry = lookup(option);
    
        if (!entry)
        {
            fin = ffp;
            ReportUnknownOption(option);
            return no;
        }

        config_text = parameter;
        entry->parser(entry->location, option);
    
        fin = ffp;
    }

    return yes;
}

#endif
/* ensure that config is self consistent */
void AdjustConfig(void)
{
    if (EncloseBlockText)
        EncloseBodyText = yes;

 /* avoid the need to set IndentContent when SmartIndent is set */

    if (SmartIndent)
        IndentContent = yes;

 /* disable wrapping */
    if (wraplen == 0)
        wraplen = 0x7FFFFFFF;

 /* Word 2000 needs o:p to be declared as inline */
    if (Word2000)
    {
        DefineInlineTag("o:p");
    }

 /* XHTML is written in lower case */
    if (xHTML)
    {
        XmlOut = yes;
        UpperCaseTags = no;
        UpperCaseAttrs = no;
    }

 /* if XML in, then XML out */
    if (XmlTags)
    {
        XmlOut = yes;
        XmlPIs = yes;
    }

 /* XML requires end tags */
    if (XmlOut)
    {
        QuoteAmpersand = yes;
        HideEndTags = no;
    }
}

/* unsigned integers */
void ParseInt(Location location, char *option)
{
    int number = 0;
    Bool digits = no;

    SkipWhite();

    while(IsDigit(c))
    {
        number = c - '0' + (10 * number);
        digits = yes;
        AdvanceChar();
    }

    if (!digits)
        ReportBadArgument(option);
    
    *location.number = number;
    NextProperty();
}

/* true/false or yes/no only looks at 1st char */
void ParseBool(Location location, char *option)
{
    Bool flag = no;
    SkipWhite();

    if (c == 't' || c == 'T' || c == 'y' || c == 'Y' || c == '1')
        flag = yes;
    else if (c == 'f' || c == 'F' || c == 'n' || c == 'N' || c == '0')
        flag = no;
    else
        ReportBadArgument(option);

    *location.logical = flag;
    NextProperty();
}

void ParseInvBool(Location location, char *option)
{
    Bool flag = no;
    SkipWhite();

    if (c == 't' || c == 'T' || c == 'y' || c == 'Y')
        flag = yes;
    else if (c == 'f' || c == 'F' || c == 'n' || c == 'N')
        flag = no;
    else
        ReportBadArgument(option);

    *location.logical = (Bool)(!flag);
    NextProperty();
}

/* a string excluding whitespace */
void ParseName(Location location, char *option)
{
    char buf[256];
    int i = 0;

    SkipWhite();

    while (i < 254 && c != EOF && !IsWhite(c))
    {
        buf[i++] = c;
        AdvanceChar();
    }

    buf[i] = '\0';

    if (i == 0)
        ReportBadArgument(option);

    *location.string = wstrdup(buf);
    NextProperty();
}

/* a space or comma separated list of tag names */
void ParseTagNames(Location location, char *option)
{
    char buf[1024];
    int i = 0;

    do
    {
        if (c == ' ' || c == '\t' || c == ',')
        {
            AdvanceChar();
            continue;
        }

        if (c == '\r')
        {
            AdvanceChar();

            if (c == '\n')
                AdvanceChar();

            if (!(IsWhite((uint) c)))
                break;
        }

        if (c == '\n')
        {
            AdvanceChar();

            if (!(IsWhite((uint) c)))
                break;
        }

        while (i < 1022 && c != EOF && !IsWhite(c) && c != ',')
        {
            buf[i++] = ToLower(c);
            AdvanceChar();
        }

        buf[i] = '\0';

        /* add tag to dictionary */

        if(location.string == &inline_tags)
            DefineInlineTag(buf);
        else if (location.string == &block_tags)
            DefineBlockTag(buf);
        else if (location.string == &empty_tags)
            DefineEmptyTag(buf);
        else if (location.string == &pre_tags)
            DefinePreTag(buf);

        i = 0;
    }
    while (c != EOF);
}

/* a string including whitespace */
/* munges whitespace sequences */
void ParseString(Location location, char *option)
{
    char buf[8192];
    int i = 0;
    unsigned delim = 0;
    Bool waswhite = yes;

    SkipWhite();

    if (c == '"' || c == '\'')
        delim = c;

    while (i < 8190 && c != EOF)
    {
        /* treat  \r\n   \r  or  \n as line ends */
        if (c == '\r')
        {
            AdvanceChar();

            if (c != '\n' && !IsWhite(c))
                break;
        }

        if (c == '\n')
        {
            AdvanceChar();

            if (!IsWhite(c))
                break;
        }

        if (c == delim && delim != '\0')
            break;

        if (IsWhite(c))
        {
            if (waswhite)
            {
                AdvanceChar();
                continue;
            }

            c = ' ';
        }
        else
            waswhite = no;

        buf[i++] = c;
        AdvanceChar();
    }

    buf[i] = '\0';

    if (*location.string)
        MemFree(*location.string);
#if 0
    if (i == 0)
        ReportBadArgument(option);
#endif
    *location.string = wstrdup(buf);
}

void ParseCharEncoding(Location location, char *option)
{
    char buf[64];
    int i = 0;

    SkipWhite();

    while (i < 62 && c != EOF && !IsWhite(c))
    {
        buf[i++] = c;
        AdvanceChar();
    }

    buf[i] = '\0';

    if (wstrcasecmp(buf, "ascii") == 0)
        *location.number = ASCII;
    else if (wstrcasecmp(buf, "latin1") == 0)
        *location.number = LATIN1;
    else if (wstrcasecmp(buf, "raw") == 0)
        *location.number = RAW;
    else if (wstrcasecmp(buf, "utf8") == 0)
        *location.number = UTF8;
    else if (wstrcasecmp(buf, "iso2022") == 0)
        *location.number = ISO2022;
    else if (wstrcasecmp(buf, "mac") == 0)
        *location.number = MACROMAN;
    else
        ReportBadArgument(option);

    NextProperty();
}

/* slight hack to avoid changes to pprint.c */
void ParseIndent(Location location, char *option)
{
    char buf[64];
    int i = 0;

    SkipWhite();

    while (i < 62 && c != EOF && !IsWhite(c))
    {
        buf[i++] = c;
        AdvanceChar();
    }

    buf[i] = '\0';

    if (wstrcasecmp(buf, "yes") == 0)
    {
        IndentContent = yes;
        SmartIndent = no;
    }
    else if (wstrcasecmp(buf, "true") == 0)
    {
        IndentContent = yes;
        SmartIndent = no;
    }
    else if (wstrcasecmp(buf, "no") == 0)
    {
        IndentContent = no;
        SmartIndent = no;
    }
    else if (wstrcasecmp(buf, "false") == 0)
    {
        IndentContent = no;
        SmartIndent = no;
    }
    else if (wstrcasecmp(buf, "auto") == 0)
    {
        IndentContent = yes;
        SmartIndent = yes;
    }
    else
        ReportBadArgument(option);

    NextProperty();
}

/*
   doctype: omit | auto | strict | loose | <fpi>

   where the fpi is a string similar to

      "-//ACME//DTD HTML 3.14159//EN"
*/
void ParseDocType(Location location, char *option)
{
    char buf[64];
    int i = 0;

    SkipWhite();

    /* "-//ACME//DTD HTML 3.14159//EN" or similar */

    if (c == '"')
    {
        ParseString(location, option);
        doctype_mode = doctype_user;
        return;
    }

    /* read first word */
    while (i < 62 && c != EOF && !IsWhite(c))
    {
        buf[i++] = c;
        AdvanceChar();
    }

    buf[i] = '\0';

    doctype_mode = doctype_auto;

    if (wstrcasecmp(buf, "omit") == 0)
        doctype_mode = doctype_omit;
    else if (wstrcasecmp(buf, "strict") == 0)
        doctype_mode = doctype_strict;
    else if (wstrcasecmp(buf, "loose") == 0 ||
             wstrcasecmp(buf, "transitional") == 0)
        doctype_mode = doctype_loose;
    else if (i == 0)
        ReportBadArgument(option);

    NextProperty();
}
