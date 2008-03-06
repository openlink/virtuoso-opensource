/* attrs.c -- recognize HTML attributes

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


#include "platform.h"   /* platform independent stuff */
#include "html.h"       /* to pull in definition of nodes */

Attribute *attr_href;
Attribute *attr_src;
Attribute *attr_id;
Attribute *attr_name;
Attribute *attr_summary;
Attribute *attr_alt;
Attribute *attr_longdesc;
Attribute *attr_usemap;
Attribute *attr_ismap;
Attribute *attr_language;
Attribute *attr_type;
Attribute *attr_value;
Attribute *attr_content;
Attribute *attr_title;
Attribute *attr_xmlns;
Attribute *attr_datafld;
Attribute *attr_width;
Attribute *attr_height;

AttrCheck CheckUrl;
AttrCheck CheckScript;
AttrCheck CheckName;
AttrCheck CheckId;
AttrCheck CheckAlign;
AttrCheck CheckValign;
AttrCheck CheckBool;

extern Bool XmlTags;
extern Bool XmlOut;
extern char *alt_text;


#define HASHSIZE 357

static Attribute *hashtab[HASHSIZE];

/*
 Bind attribute types to procedures to check values.
 You can add new procedures for better validation
 and each procedure has access to the node in which
 the attribute occurred as well as the attribute name
 and its value.

 By default, attributes are checked without regard
 to the element they are found on. You have the choice
 of making the procedure test which element is involved
 or in writing methods for each element which controls
 exactly how the attributes of that element are checked.
 This latter approach is best for detecting the absence
 of required attributes.
*/

#define TEXT_CHK    null
#define CHARSET     null
#define TYPE        null
#define CHARACTER   null
#define URLS        null
#define URL         CheckUrl
#define SCRIPT      CheckScript
#undef ALIGN
#define ALIGN       CheckAlign
#define VALIGN      CheckValign
#define COLOR       null
#define CLEAR       null
#define BORDER      CheckBool     /* kludge */
#define LENGTH      null
#define CHARSET     null
#define LANG        null
#define BOOL        CheckBool
#define COLS        null
#define NUMBER      null
#define LENGTH      null
#define COORDS      null
#define DATE        null
#define TEXTDIR     null
#define IDREFS      null
#define IDREF       null
#define IDDEF       CheckId
#define NAME        CheckName
#define TFRAME      null
#define FBORDER     null
#define MEDIA       null
#define FSUBMIT     null
#define LINKTYPES   null
#define TRULES      null
#define SCOPE       null
#define SHAPE       null
#define SCROLL      null
#define TARGET      null
#define VTYPE       null

static struct _attrlist
{
    char *name;
    unsigned versions;
    AttrCheck *attrchk;
} attrlist[] =
{
    {"abbr",             VERS_HTML40,            TEXT_CHK},
    {"accept-charset",   VERS_HTML40,            CHARSET},
    {"accept",           VERS_ALL,               TYPE},
    {"accesskey",        VERS_HTML40,            CHARACTER},
    {"action",           VERS_ALL,               URL},
    {"add_date",         VERS_NETSCAPE,          TEXT_CHK}, /* A */
    {"align",            VERS_ALL,               ALIGN},    /* set varies with element */
    {"alink",            VERS_LOOSE,             COLOR},
    {"alt",              VERS_ALL,               TEXT_CHK},
    {"archive",          VERS_HTML40,            URLS},     /* space or comma separated list */
    {"axis",             VERS_HTML40,            TEXT_CHK},
    {"background",       VERS_LOOSE,             URL},
    {"bgcolor",          VERS_LOOSE,             COLOR},
    {"bgproperties",     VERS_PROPRIETARY,       TEXT_CHK}, /* BODY "fixed" fixes background */
    {"border",           VERS_ALL,               BORDER},   /* like LENGTH + "border" */
    {"bordercolor",      VERS_MICROSOFT,         COLOR},    /* used on TABLE */
    {"bottommargin",     VERS_MICROSOFT,         NUMBER},   /* used on BODY */
    {"cellpadding",      VERS_FROM32,            LENGTH},   /* % or pixel values */
    {"cellspacing",      VERS_FROM32,            LENGTH},
    {"char",             VERS_HTML40,            CHARACTER},
    {"charoff",          VERS_HTML40,            LENGTH},
    {"charset",          VERS_HTML40,            CHARSET},
    {"checked",          VERS_ALL,               BOOL},     /* i.e. "checked" or absent */
    {"cite",             VERS_HTML40,            URL},
    {"class",            VERS_HTML40,            TEXT_CHK},
    {"classid",          VERS_HTML40,            URL},
    {"clear",            VERS_LOOSE,             CLEAR},    /* BR: left, right, all */
    {"code",             VERS_LOOSE,             TEXT_CHK}, /* APPLET */
    {"codebase",         VERS_HTML40,            URL},      /* OBJECT */
    {"codetype",         VERS_HTML40,            TYPE},     /* OBJECT */
    {"color",            VERS_LOOSE,             COLOR},    /* BASEFONT, FONT */
    {"cols",             VERS_IFRAMES,           COLS},     /* TABLE & FRAMESET */
    {"colspan",          VERS_FROM32,            NUMBER},
    {"compact",          VERS_ALL,               BOOL},     /* lists */
    {"content",          VERS_ALL,               TEXT_CHK}, /* META */
    {"coords",           VERS_FROM32,            COORDS},   /* AREA, A */    
    {"data",             VERS_HTML40,            URL},      /* OBJECT */
    {"datafld",          VERS_MICROSOFT,         TEXT_CHK}, /* used on DIV, IMG */
    {"dataformatas",    VERS_MICROSOFT,         TEXT_CHK}, /* used on DIV, IMG */
    {"datapagesize",     VERS_MICROSOFT,         NUMBER},   /* used on DIV, IMG */
    {"datasrc",          VERS_MICROSOFT,         URL},      /* used on TABLE */
    {"datetime",         VERS_HTML40,            DATE},     /* INS, DEL */
    {"declare",          VERS_HTML40,            BOOL},     /* OBJECT */
    {"defer",            VERS_HTML40,            BOOL},     /* SCRIPT */
    {"dir",              VERS_HTML40,            TEXTDIR},  /* ltr or rtl */
    {"disabled",         VERS_HTML40,            BOOL},     /* form fields */
    {"enctype",          VERS_ALL,               TYPE},     /* FORM */
    {"face",             VERS_LOOSE,             TEXT_CHK}, /* BASEFONT, FONT */
    {"for",              VERS_HTML40,            IDREF},    /* LABEL */
    {"frame",            VERS_HTML40,            TFRAME},   /* TABLE */
    {"frameborder",      VERS_FRAMES,            FBORDER},  /* 0 or 1 */
    {"framespacing",     VERS_PROPRIETARY,       NUMBER},   /* pixel value */
    {"gridx",            VERS_PROPRIETARY,       NUMBER},   /* TABLE Adobe golive*/
    {"gridy",            VERS_PROPRIETARY,       NUMBER},   /* TABLE Adobe golive */
    {"headers",          VERS_HTML40,            IDREFS},   /* table cells */
    {"height",           VERS_ALL,               LENGTH},   /* pixels only for TH/TD */
    {"href",             VERS_ALL,               URL},      /* A, AREA, LINK and BASE */
    {"hreflang",         VERS_HTML40,            LANG},     /* A, LINK */
    {"hspace",           VERS_ALL,               NUMBER},   /* APPLET, IMG, OBJECT */
    {"http-equiv",       VERS_ALL,               TEXT_CHK}, /* META */
    {"id",               VERS_HTML40,            IDDEF},
    {"ismap",            VERS_ALL,               BOOL},     /* IMG */
    {"label",            VERS_HTML40,            TEXT_CHK}, /* OPT, OPTGROUP */
    {"lang",             VERS_HTML40,            LANG},
    {"language",         VERS_LOOSE,             TEXT_CHK}, /* SCRIPT */
    {"last_modified",    VERS_NETSCAPE,          TEXT_CHK}, /* A */
    {"last_visit",       VERS_NETSCAPE,          TEXT_CHK}, /* A */
    {"leftmargin",       VERS_MICROSOFT,         NUMBER},   /* used on BODY */
    {"link",             VERS_LOOSE,             COLOR},    /* BODY */
    {"longdesc",         VERS_HTML40,            URL},      /* IMG */
    {"lowsrc",           VERS_PROPRIETARY,       URL},      /* IMG */
    {"marginheight",     VERS_IFRAMES,           NUMBER},   /* FRAME, IFRAME, BODY */
    {"marginwidth",      VERS_IFRAMES,           NUMBER},   /* ditto */
    {"maxlength",        VERS_ALL,               NUMBER},   /* INPUT */
    {"media",            VERS_HTML40,            MEDIA},    /* STYLE, LINK */
    {"method",           VERS_ALL,               FSUBMIT},  /* FORM: get or post */
    {"multiple",         VERS_ALL,               BOOL},     /* SELECT */
    {"name",             VERS_ALL,               NAME},
    {"nohref",           VERS_FROM32,            BOOL},     /* AREA */
    {"noresize",         VERS_FRAMES,            BOOL},     /* FRAME */
    {"noshade",          VERS_LOOSE,             BOOL},     /* HR */
    {"nowrap",           VERS_LOOSE,             BOOL},     /* table cells */
    {"object",           VERS_HTML40_LOOSE,      TEXT_CHK}, /* APPLET */
    {"onblur",           VERS_HTML40,            SCRIPT},   /* event */
    {"onchange",         VERS_HTML40,            SCRIPT},   /* event */
    {"onclick",          VERS_HTML40,            SCRIPT},   /* event */
    {"ondblclick",       VERS_HTML40,            SCRIPT},   /* event */
    {"onkeydown",        VERS_HTML40,            SCRIPT},   /* event */
    {"onkeypress",       VERS_HTML40,            SCRIPT},   /* event */
    {"onkeyup",          VERS_HTML40,            SCRIPT},   /* event */
    {"onload",           VERS_HTML40,            SCRIPT},   /* event */
    {"onmousedown",      VERS_HTML40,            SCRIPT},   /* event */
    {"onmousemove",      VERS_HTML40,            SCRIPT},   /* event */
    {"onmouseout",       VERS_HTML40,            SCRIPT},   /* event */
    {"onmouseover",      VERS_HTML40,            SCRIPT},   /* event */
    {"onmouseup",        VERS_HTML40,            SCRIPT},   /* event */
    {"onsubmit",         VERS_HTML40,            SCRIPT},   /* event */
    {"onreset",          VERS_HTML40,            SCRIPT},   /* event */
    {"onselect",         VERS_HTML40,            SCRIPT},   /* event */
    {"onunload",         VERS_HTML40,            SCRIPT},   /* event */
    {"onafterupdate",    VERS_MICROSOFT,         SCRIPT},   /* form fields */
    {"onbeforeupdate",   VERS_MICROSOFT,         SCRIPT},   /* form fields */
    {"onerrorupdate",    VERS_MICROSOFT,         SCRIPT},   /* form fields */
    {"onrowenter",       VERS_MICROSOFT,         SCRIPT},   /* form fields */
    {"onrowexit",        VERS_MICROSOFT,         SCRIPT},   /* form fields */
    {"onbeforeunload",   VERS_MICROSOFT,         SCRIPT},   /* form fields */
    {"ondatasetchanged", VERS_MICROSOFT,         SCRIPT},   /* object, applet */
    {"ondataavailable",  VERS_MICROSOFT,         SCRIPT},   /* object, applet */
    {"ondatasetcomplete",VERS_MICROSOFT,         SCRIPT},   /* object, applet */
    {"profile",          VERS_HTML40,            URL},      /* HEAD */
    {"prompt",           VERS_LOOSE,             TEXT_CHK}, /* ISINDEX */
    {"readonly",         VERS_HTML40,            BOOL},     /* form fields */
    {"rel",              VERS_ALL,               LINKTYPES}, /* A, LINK */
    {"rev",              VERS_ALL,               LINKTYPES}, /* A, LINK */
    {"rightmargin",      VERS_MICROSOFT,         NUMBER},   /* used on BODY */
    {"rows",             VERS_ALL,               NUMBER},   /* TEXTAREA */
    {"rowspan",          VERS_ALL,               NUMBER},   /* table cells */
    {"rules",            VERS_HTML40,            TRULES},   /* TABLE */
    {"scheme",           VERS_HTML40,            TEXT_CHK}, /* META */
    {"scope",            VERS_HTML40,            SCOPE},    /* table cells */
    {"scrolling",        VERS_IFRAMES,           SCROLL},   /* yes, no or auto */
    {"selected",         VERS_ALL,               BOOL},     /* OPTION */
    {"shape",            VERS_FROM32,            SHAPE},    /* AREA, A */
    {"showgrid",         VERS_PROPRIETARY,       BOOL},     /* TABLE Adobe golive */
    {"showgridx",        VERS_PROPRIETARY,       BOOL},     /* TABLE Adobe golive*/
    {"showgridy",        VERS_PROPRIETARY,       BOOL},     /* TABLE Adobe golive*/
    {"size",             VERS_LOOSE,             NUMBER},   /* HR, FONT, BASEFONT, SELECT */
    {"span",             VERS_HTML40,            NUMBER},   /* COL, COLGROUP */
    {"src",              (VERS_ALL|VERS_FRAMES), URL},      /* IMG, FRAME, IFRAME */
    {"standby",          VERS_HTML40,            TEXT_CHK}, /* OBJECT */
    {"start",            VERS_ALL,               NUMBER},   /* OL */
    {"style",            VERS_HTML40,            TEXT_CHK},
    {"summary",          VERS_HTML40,            TEXT_CHK}, /* TABLE */
    {"tabindex",         VERS_HTML40,            NUMBER},   /* fields, OBJECT  and A */
    {"target",           VERS_HTML40,            TARGET},   /* names a frame/window */
    {"text",             VERS_LOOSE,             COLOR},    /* BODY */
    {"title",            VERS_HTML40,            TEXT_CHK}, /* text tool tip */
    {"topmargin",        VERS_MICROSOFT,         NUMBER},   /* used on BODY */
    {"type",             VERS_FROM32,            TYPE},     /* also used by SPACER */
    {"usemap",           VERS_ALL,               BOOL},     /* things with images */
    {"valign",           VERS_FROM32,            VALIGN},
    {"value",            VERS_ALL,               TEXT_CHK}, /* OPTION, PARAM */
    {"valuetype",        VERS_HTML40,            VTYPE},    /* PARAM: data, ref, object */
    {"version",          VERS_ALL,               TEXT_CHK}, /* HTML */
    {"vlink",            VERS_LOOSE,             COLOR},    /* BODY */
    {"vspace",           VERS_LOOSE,             NUMBER},   /* IMG, OBJECT, APPLET */
    {"width",            VERS_ALL,               LENGTH},   /* pixels only for TD/TH */
    {"wrap",             VERS_NETSCAPE,          TEXT_CHK}, /* textarea */
    {"xml:lang",         VERS_XML,               TEXT_CHK}, /* XML language */
    {"xmlns",            VERS_ALL,               TEXT_CHK}, /* name space */
   
   /* this must be the final entry */
    {null,               0,                      0}
};

static unsigned hash(char *s)
{
    unsigned hashval;

    for (hashval = 0; *s != '\0'; s++)
        hashval = *s + 31*hashval;

    return hashval % HASHSIZE;
}

static Attribute *lookup(char *s)
{
    Attribute *np;

    for (np = hashtab[hash(s)]; np != null; np = np->next)
        if (wstrcmp(s, np->name) == 0)
            return np;
    return null;
}

static Attribute *install(char *name, uint versions, AttrCheck *attrchk)
{
    Attribute *np;
    unsigned hashval;

    if (null == name)
      return null;
    
    np = lookup(name);
    if (null == np)
    {
        np = (Attribute *)MemAlloc(sizeof(*np));
        np->name = wstrdup(name);
        hashval = hash(name);
        np->next = hashtab[hashval];
        hashtab[hashval] = np;
    }

    np->versions = versions;
    np->attrchk = attrchk;
    np->nowrap = no;
    np->literal = no;
    return np;
}

static void SetNoWrap(Attribute *attr)
{
    attr->nowrap = yes;  /* defaults to no */
}

/* public method for finding attribute definition by name */
Attribute *FindAttribute(AttVal *attval)
{
    Attribute *np;

    if (attval->attribute && (np = lookup(attval->attribute)))
        return np;

    return null;
}

AttVal *GetAttrByName(Node *node, char *name)
{
    AttVal *attr;

    for (attr = node->attributes; attr; attr = attr->next)
    {
        if (wstrcmp(attr->attribute, name) == 0)
            break;
    }

    return attr;
}

void AddAttribute(Node *node, char *name, char *value)
{
    AttVal *av = NewAttribute();
    av->delim = '"';
    av->attribute = wstrdup(name);
    av->value = wstrdup(value);
    av->dict = FindAttribute(av);

    if (node->attributes == null)
        node->attributes = av;
    else /* append to end of attributes */
    {
        AttVal *here = node->attributes;

        while (here->next)
            here = here->next;

        here->next = av;
    }
}

Bool IsUrl(char *attrname)
{
    Attribute *np;

    return (Bool)((np = lookup(attrname)) && np->attrchk == URL);
}

Bool IsScript(char *attrname)
{
    Attribute *np;

    return (Bool)((np = lookup(attrname)) && np->attrchk == SCRIPT);
}

Bool IsLiteralAttribute(char *attrname)
{
    Attribute *np;

    return (Bool)((np = lookup(attrname)) && np->literal);
}

/* public method for inititializing attribute dictionary */
void InitAttrs(void)
{
    struct _attrlist *ap;
    
    for(ap = attrlist; ap->name != null; ++ap)
        install(ap->name, ap->versions, ap->attrchk);

    attr_href = lookup("href");
    attr_src = lookup("src");
    attr_id = lookup("id");
    attr_name = lookup("name");
    attr_summary = lookup("summary");
    attr_alt = lookup("alt");
    attr_longdesc = lookup("longdesc");
    attr_usemap = lookup("usemap");
    attr_ismap = lookup("ismap");
    attr_language = lookup("language");
    attr_type = lookup("type");
    attr_title = lookup("title");
    attr_xmlns = lookup("xmlns");
    attr_datafld = lookup("datafld");
    attr_value = lookup("value");
    attr_content = lookup("content");
    attr_width = lookup("width");
    attr_height = lookup("height");

    SetNoWrap(attr_alt);
    SetNoWrap(attr_value);
    SetNoWrap(attr_content);
}

/*
Henry Zrepa reports that some folk are
using embed with script attributes where
newlines are signficant. These need to be
declared and handled specially!
*/
void DeclareLiteralAttrib(char *name)
{
    Attribute *attrib = lookup(name);

    if (attrib == null)
        attrib = install(name, VERS_PROPRIETARY, null);

    attrib->literal = yes;
}

void FreeAttrTable(void)
{
    Attribute *dict, *next;
    int i;

    for (i = 0; i < HASHSIZE; ++i)
    {
        dict = hashtab[i];

        while(dict)
        {
            next = dict->next;
            MemFree(dict->name);
            MemFree(dict);
            dict = next;
        }

        hashtab[i] = null;
    }
}

/*
 the same attribute name can't be used
 more than once in each element
*/

static void CheckUniqueAttribute(Lexer *lexer, Node *node, AttVal *attval)
{
    AttVal *attr;
    int count = 0;

    for (attr = attval->next; attr; attr = attr->next)
    {
        if (attr->asp == null && attr->php == null &&
            wstrcasecmp(attval->attribute, attr->attribute) == 0)
                ++count;
    }

    if (count > 0)
        ReportAttrError(lexer, node, attval->attribute, REPEATED_ATTRIBUTE);
}

void CheckUniqueAttributes(Lexer *lexer, Node *node)
{
    AttVal *attval;

    for (attval = node->attributes; attval != null; attval = attval->next)
    {
        if (attval->asp == null && attval->php == null)
            CheckUniqueAttribute(lexer, node, attval);
    }
}

/* ignore unknown attributes for proprietary elements */
Attribute *CheckAttribute(Lexer *lexer, Node *node, AttVal *attval)
{
    Attribute *attribute;

    if (attval->asp == null && attval->php == null)
        CheckUniqueAttribute(lexer, node, attval);

    if ((attribute = attval->dict) != null)
    {
        /* title is vers 2.0 for A and LINK otherwise vers 4.0 */
        if (attribute == attr_title &&
                (node->tag == tag_a || node->tag == tag_link))
                lexer->versions &= VERS_ALL;
        else if (attribute->versions & VERS_XML)
        {
            if (!(XmlTags || XmlOut))
                ReportAttrError(lexer, node, attval->attribute, XML_ATTRIBUTE_VALUE);
        }
        else
            lexer->versions &= attribute->versions;
        
        if (attribute->attrchk)
            attribute->attrchk(lexer, node, attval);
    }
    else if (!XmlTags && !(node->tag == null) && attval->asp == null &&
             !(node->tag && (node->tag->versions & VERS_PROPRIETARY)))
        ReportAttrError(lexer, node, attval->attribute, UNKNOWN_ATTRIBUTE);

    return attribute;
}

Bool IsBoolAttribute(AttVal *attval)
{
    Attribute *attribute;

    if ((attribute = attval->dict) != null)
    {
        if (attribute->attrchk == CheckBool)
            return yes;
    }

    return no;
}

/* methods for checking value of a specific attribute */

void CheckUrl(Lexer *lexer, Node *node, AttVal *attval)
{
    char c, *p = attval->value;

    if (p == null)
        ReportAttrError(lexer, node, attval->attribute, MISSING_ATTR_VALUE);
    else if (FixBackslash)
    {
        while ((c = *p))
        {
            if (c =='\\')
                *p = '/';

            ++p;
        }
    }
}

void CheckScript(Lexer *lexer, Node *node, AttVal *attval)
{
}

void CheckName(Lexer *lexer, Node *node, AttVal *attval)
{
}

void CheckId(Lexer *lexer, Node *node, AttVal *attval)
{
}

void CheckBool(Lexer *lexer, Node *node, AttVal *attval)
{
}

void CheckAlign(Lexer *lexer, Node *node, AttVal *attval)
{
    char *value;

    /* IMG, OBJECT, APPLET and EMBED use align for vertical position */
    if (node->tag && (node->tag->model & CM_IMG))
    {
        CheckValign(lexer, node, attval);
        return;
    }

    value = attval->value;

    if (value == null)
        ReportAttrError(lexer, node, attval->attribute, MISSING_ATTR_VALUE);
    else if (! (wstrcasecmp(value, "left") == 0 ||
                wstrcasecmp(value, "center") == 0 ||
                wstrcasecmp(value, "right") == 0 ||
                wstrcasecmp(value, "justify") == 0))
          ReportAttrError(lexer, node, attval->value, BAD_ATTRIBUTE_VALUE);
}

void CheckValign(Lexer *lexer, Node *node, AttVal *attval)
{
    char *value;

    value = attval->value;

    if (value == null)
        ReportAttrError(lexer, node, attval->attribute, MISSING_ATTR_VALUE);
    else if (wstrcasecmp(value, "top") == 0 ||
           wstrcasecmp(value, "middle") == 0 ||
           wstrcasecmp(value, "bottom") == 0 ||
          wstrcasecmp(value, "baseline") == 0)
    {
        /* all is fine */
    }
    else if (wstrcasecmp(value, "left") == 0 ||
              wstrcasecmp(value, "right") == 0)
    {
        if (!(node->tag && (node->tag->model & CM_IMG)))
            ReportAttrError(lexer, node, value, BAD_ATTRIBUTE_VALUE);
    }
    else if (wstrcasecmp(value, "texttop") == 0 ||
           wstrcasecmp(value, "absmiddle") == 0 ||
           wstrcasecmp(value, "absbottom") == 0 ||
           wstrcasecmp(value, "textbottom") == 0)
    {
        lexer->versions &= VERS_PROPRIETARY;
        ReportAttrError(lexer, node, value, PROPRIETARY_ATTR_VALUE);
    }
    else
          ReportAttrError(lexer, node, value, BAD_ATTRIBUTE_VALUE);
}


/* default method for checking an element's attributes */
void CheckAttributes(Lexer *lexer, Node *node)
{
    AttVal *attval;

    for (attval = node->attributes; attval != null; attval = attval->next)
        CheckAttribute(lexer, node, attval);
}

/* methods for checking attributes for specific elements */

void CheckHR(Lexer *lexer, Node *node)
{
    if (GetAttrByName(node, "src"))
        ReportAttrError(lexer, node, "src", PROPRIETARY_ATTR_VALUE);
}

void CheckIMG(Lexer *lexer, Node *node)
{
    AttVal *attval;
    Attribute *attribute;
    Bool HasAlt = no;
    Bool HasSrc = no;
    Bool HasUseMap = no;
    Bool HasIsMap = no;
    Bool HasDataFld = no;

    CheckUniqueAttributes(lexer, node);

    for (attval = node->attributes; attval != null; attval = attval->next)
    {
        attribute = CheckAttribute(lexer, node, attval);

        if (attribute == attr_alt)
            HasAlt = yes;
        else if (attribute == attr_src)
            HasSrc = yes;
        else if (attribute == attr_usemap)
            HasUseMap = yes;
        else if (attribute == attr_ismap)
            HasIsMap = yes;
        else if (attribute == attr_datafld)
            HasDataFld = yes;
        else if (attribute == attr_width || attribute == attr_height)
            lexer->versions &= ~VERS_HTML20;
    }

    if (!HasAlt)
    {
        lexer->badAccess |= MISSING_IMAGE_ALT;
        ReportAttrError(lexer, node, "alt", MISSING_ATTRIBUTE);

        if (alt_text)
            AddAttribute(node, "alt", alt_text);
    }

    if (!HasSrc && !HasDataFld)
        ReportAttrError(lexer, node, "src", MISSING_ATTRIBUTE);

    if (HasIsMap && !HasUseMap)
        ReportAttrError(lexer, node, "ismap", MISSING_IMAGEMAP);
}

void CheckAnchor(Lexer *lexer, Node *node)
{
    CheckUniqueAttributes(lexer, node);

    FixId(lexer, node);
}

void CheckMap(Lexer *lexer, Node *node)
{
    CheckUniqueAttributes(lexer, node);

    FixId(lexer, node);
}

void CheckTableCell(Lexer *lexer, Node *node)
{
    CheckUniqueAttributes(lexer, node);

    /*
      HTML4 strict doesn't allow mixed content for
      elements with %block; as their content model
    */
    if (GetAttrByName(node, "width") || GetAttrByName(node, "height"))
        lexer->versions &= ~VERS_HTML40_STRICT;
}

void CheckCaption(Lexer *lexer, Node *node)
{
    AttVal *attval;
    char *value = null;

    CheckUniqueAttributes(lexer, node);

    for (attval = node->attributes; attval != null; attval = attval->next)
    {
        if (wstrcasecmp(attval->attribute, "align") == 0)
        {
            value = attval->value;
            break;
        }
    }

    if (value != null)
    {
        if (wstrcasecmp(value, "left") == 0 || wstrcasecmp(value, "right") == 0)
            lexer->versions &= (VERS_HTML40_LOOSE|VERS_FRAMES);
        else if (wstrcasecmp(value, "top") == 0 || wstrcasecmp(value, "bottom") == 0)
            lexer->versions &= VERS_FROM32;
        else
            ReportAttrError(lexer, node, value, BAD_ATTRIBUTE_VALUE);
    }
}

void CheckHTML(Lexer *lexer, Node *node)
{
    AttVal *attval;
    Attribute *attribute;

    CheckUniqueAttributes(lexer, node);

    for (attval = node->attributes; attval != null; attval = attval->next)
    {
        attribute = CheckAttribute(lexer, node, attval);

        if (attribute == attr_xmlns)
            lexer->isvoyager = yes;
    }
}

void CheckAREA(Lexer *lexer, Node *node)
{
    AttVal *attval;
    Attribute *attribute;
    Bool HasAlt = no;
    Bool HasHref = no;

    CheckUniqueAttributes(lexer, node);

    for (attval = node->attributes; attval != null; attval = attval->next)
    {
        attribute = CheckAttribute(lexer, node, attval);

        if (attribute == attr_alt)
            HasAlt = yes;
        else if (attribute == attr_href)
            HasHref = yes;
    }

    if (!HasAlt)
    {
        lexer->badAccess |= MISSING_LINK_ALT;
        ReportAttrError(lexer, node, "alt", MISSING_ATTRIBUTE);
    }
    if (!HasHref)
        ReportAttrError(lexer, node, "href", MISSING_ATTRIBUTE);
}

void CheckTABLE(Lexer *lexer, Node *node)
{
    AttVal *attval;
    Attribute *attribute;
    Bool HasSummary = no;

    CheckUniqueAttributes(lexer, node);

    for (attval = node->attributes; attval != null; attval = attval->next)
    {
        attribute = CheckAttribute(lexer, node, attval);

        if (attribute == attr_summary)
            HasSummary = yes;
    }

    /* suppress warning for missing summary for HTML 2.0 and HTML 3.2 */
    if (!HasSummary && lexer->doctype != VERS_HTML20 && lexer->doctype != VERS_HTML32)
    {
        lexer->badAccess |= MISSING_SUMMARY;
        ReportAttrError(lexer, node, "summary", MISSING_ATTRIBUTE);
    }

    /* convert <table border> to <table border="1"> */
    if (XmlOut && (attval = GetAttrByName(node, "border")))
    {
        if (attval->value == null)
            attval->value = wstrdup("1");
    }
}

/* add missing type attribute when appropriate */
void CheckSCRIPT(Lexer *lexer, Node *node)
{
    AttVal *lang, *type;
    char buf[16];

    CheckUniqueAttributes(lexer, node);

    lang = GetAttrByName(node, "language");
    type = GetAttrByName(node, "type");

    if (!type)
    {
        ReportAttrError(lexer, node, "type", MISSING_ATTRIBUTE);

        /* check for javascript */

        if (lang)
        {
            wstrncpy(buf, lang->value, 10);
            buf[10] = '\0';

            if ( (wstrncasecmp(buf, "javascript", 10) == 0) ||
                 (wstrncasecmp(buf, "jscript", 7) == 0) )
            {
                AddAttribute(node, "type", "text/javascript");
            }
        }
        else
            AddAttribute(node, "type", "text/javascript");
    }
}


/* add missing type attribute when appropriate */
void CheckSTYLE(Lexer *lexer, Node *node)
{
    AttVal *type = GetAttrByName(node, "type");

    CheckUniqueAttributes(lexer, node);

    if (!type)
    {
        ReportAttrError(lexer, node, "type", MISSING_ATTRIBUTE);

        AddAttribute(node, "type", "text/css");
    }
}

/* add missing type attribute when appropriate */
void CheckLINK(Lexer *lexer, Node *node)
{
    AttVal *rel = GetAttrByName(node, "rel");

    CheckUniqueAttributes(lexer, node);

    if (rel && rel->value &&
          wstrcmp(rel->value, "stylesheet") == 0)
    {
        AttVal *type = GetAttrByName(node, "type");

        if (!type)
        {
            ReportAttrError(lexer, node, "type", MISSING_ATTRIBUTE);

            AddAttribute(node, "type", "text/css");
        }
    }
}
