/*
  clean.c -- clean up misuse of presentation markup

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

  Filters from other formats such as Microsoft Word
  often make excessive use of presentation markup such
  as font tags, B, I, and the align attribute. By applying
  a set of production rules, it is straight forward to
  transform this to use CSS.

  Some rules replace some of the children of an element by
  style properties on the element, e.g.

  <p><b>...</b></p> -> <p style="font-weight: bold">...</p>

  Such rules are applied to the element's content and then
  to the element itself until none of the rules more apply.
  Having applied all the rules to an element, it will have
  a style attribute with one or more properties.

  Other rules strip the element they apply to, replacing
  it by style properties on the contents, e.g.

  <dir><li><p>...</li></dir> -> <p style="margin-left 1em">...

  These rules are applied to an element before processing
  its content and replace the current element by the first
  element in the exposed content.

  After applying both sets of rules, you can replace the
  style attribute by a class value and style rule in the
  document head. To support this, an association of styles
  and class names is built.

  A naive approach is to rely on string matching to test
  when two property lists are the same. A better approach
  would be to first sort the properties before matching.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "platform.h"
#include "html.h"

Node *CleanNode(Lexer *lexer, Node *node);

static void FreeStyleProps(StyleProp *props)
{
    StyleProp *next;

    while (props)
    {
        next = props->next;
        MemFree(props->name);
        MemFree(props->value);
        MemFree(props);
        props = next;
    }
}

static StyleProp *InsertProperty(StyleProp *props, char *name, char *value)
{
    StyleProp *first, *prev, *prop;
    int cmp;

    prev = null;
    first = props;

    while (props)
    {
        cmp = wstrcmp(props->name, name);

        if (cmp == 0)
        {
            /* this property is already defined, ignore new value */
            return first;
        }

        if (cmp > 0)
        {
            /* insert before this */

            prop = (StyleProp *)MemAlloc(sizeof(StyleProp));
            prop->name = wstrdup(name);
            prop->value = wstrdup(value);
            prop->next = props;

            if (prev)
                prev->next = prop;
            else
                first = prop;

            return first;
        }

        prev = props;
        props = props->next;
    }

    prop = (StyleProp *)MemAlloc(sizeof(StyleProp));
    prop->name = wstrdup(name);
    prop->value = wstrdup(value);
    prop->next = null;

    if (prev)
        prev->next = prop;
    else
        first = prop;

    return first;
}

/*
 Create sorted linked list of properties from style string
 It temporarily places nulls in place of ':' and ';' to
 delimit the strings for the property name and value.
 Some systems don't allow you to null literal strings,
 so to avoid this, a copy is made first.
*/
static StyleProp *CreateProps(StyleProp *prop, char *style)
{
    char *name, *value = NULL, *name_end, *value_end;
    Bool more;

    style = wstrdup(style);
    name = style;

    while (*name)
    {
        while (*name == ' ')
            ++name;

        name_end = name;

        while (*name_end)
        {
            if (*name_end == ':')
            {
                value = name_end + 1;
                break;
            }

            ++name_end;
        }

        if (*name_end != ':')
            break;

        while (*value == ' ')
            ++value;

        value_end = value;
        more = no;

        while (*value_end)
        {
            if (*value_end == ';')
            {
                more = yes;
                break;
            }

            ++value_end;
        }

        *name_end = '\0';
        *value_end = '\0';

        prop = InsertProperty(prop, name, value);
        *name_end = ':';

        if (more)
        {
            *value_end = ';';
            name = value_end + 1;
            continue;
        }

        break;
    }

    MemFree(style);  /* free temporary copy */
    return prop;
}

static char *CreatePropString(StyleProp *props)
{
    char *style, *p, *s;
    int len;
    StyleProp *prop;

    /* compute length */

    for (len = 0, prop = props; prop; prop = prop->next)
    {
        len += wstrlen(prop->name) + 2;
        len += wstrlen(prop->value) + 2;
    }

    style = (char *)MemAlloc(len+1);

    for (p = style, prop = props; prop; prop = prop->next)
    {
        s = prop->name;

        while((*p++ = *s++));

        *--p = ':';
        *++p = ' ';
        ++p;

        s = prop->value;
        while((*p++ = *s++));

        if (prop->next == null)
            break;

        *--p = ';';
        *++p = ' ';
        ++p;
    }

    return style;
}

/*
  create string with merged properties
*/
static char *AddProperty(char *style, char *property)
{
    StyleProp *prop;

    prop = CreateProps(null, style);
    prop = CreateProps(prop, property);
    style = CreatePropString(prop);
    FreeStyleProps(prop);
    return style;
}

void FreeStyles(Lexer *lexer)
{
    Style *style, *next;

    for (style = lexer->styles; style; style = next)
    {
        next = style->next;

        MemFree(style->tag);
        MemFree(style->tag_class);
        MemFree(style->properties);
        MemFree(style);
    }
}

static char *GensymClass(char *tag)
{
    static int n = 1;
    char buf[128];

    snprintf (buf, sizeof (buf), "c%d", n++);
    return wstrdup(buf);
}

static char *FindStyle(Lexer *lexer, char *tag, char *properties)
{
    Style *style;

    for (style = lexer->styles; style; style=style->next)
    {
        if (wstrcmp(style->tag, tag) == 0 &&
            wstrcmp(style->properties, properties) == 0)
            return style->tag_class;
    }

    style = (Style *)MemAlloc(sizeof(Style));
    style->tag = wstrdup(tag);
    style->tag_class = GensymClass(tag);
    style->properties = wstrdup(properties);
    style->next = lexer->styles;
    lexer->styles = style;
    return style->tag_class;
}

/*
 Add class="foo" to node
*/
void AddClass(Node *node, char *classname)
{
    AttVal *classattr = GetAttrByName(node, "class");

    /*
     if there already is a class attribute
     then append class name after a space
    */
    if (classattr)
    {
        int len = wstrlen(classattr->value) +
                            wstrlen(classname) + 2;
        char *s = (char *)malloc(len *sizeof(char));
        wstrcpy(s, classattr->value);
        wstrcat(s, " ");
        wstrcat(s, classname);
        MemFree(classattr->value);
        classattr->value = s;
    }
    else /* create new class attribute */
        AddAttribute(node, "class", classname);
}


/*
 Find style attribute in node, and replace it
 by corresponding class attribute. Search for
 class in style dictionary otherwise gensym
 new class and add to dictionary.

 Assumes that node doesn't have a class attribute
*/
static void Style2Rule(Lexer *lexer, Node *node)
{
    AttVal *styleattr, *classattr;
    char *classname;

    styleattr = GetAttrByName(node, "style");

    if (styleattr)
    {
        classname = FindStyle(lexer, node->element, styleattr->value);
        classattr = GetAttrByName(node, "class");

        /*
         if there already is a class attribute
         then append class name after a space
        */
        if (classattr)
        {
            int len = wstrlen(classattr->value) +
                                wstrlen(classname) + 2;
            char *s = (char *)malloc(len *sizeof(char));
            wstrcpy(s, classattr->value);
            wstrcat(s, " ");
            wstrcat(s, classname);
            MemFree(classattr->value);
            classattr->value = s;
            RemoveAttribute(node, styleattr);
        }
        else /* reuse style attribute for class attribute */
        {
            MemFree(styleattr->attribute);
            MemFree(styleattr->value);
            styleattr->attribute = wstrdup("class");
            styleattr->value = wstrdup(classname);
        }
    }
}

static void AddColorRule(Lexer *lexer, char *selector, char *color)
{
    if (color)
    {
        AddStringLiteral(lexer, selector);
        AddStringLiteral(lexer, " { color: ");
        AddStringLiteral(lexer, color);
        AddStringLiteral(lexer, " }\n");
    }
}

/*
 move presentation attribs from body to style element

 background="foo" ->  body { background-image: url(foo) }
 bgcolor="foo"    ->  body { background-color: foo }
 text="foo"       ->  body { color: foo }
 link="foo"       ->  :link { color: foo }
 vlink="foo"      ->  :visited { color: foo }
 alink="foo"      ->  :active { color: foo }
*/
static void CleanBodyAttrs(Lexer *lexer, Node *body)
{
    AttVal *attr;
    char *bgurl = null;
    char *bgcolor = null;
    char *color = null;

    attr = GetAttrByName(body, "background");

    if (attr)
    {
        bgurl = attr->value;
        attr->value = null;
        RemoveAttribute(body, attr);
    }

    attr = GetAttrByName(body, "bgcolor");

    if (attr)
    {
        bgcolor = attr->value;
        attr->value = null;
        RemoveAttribute(body, attr);
    }

    attr = GetAttrByName(body, "text");

    if (attr)
    {
        color = attr->value;
        attr->value = null;
        RemoveAttribute(body, attr);
    }

    if (bgurl || bgcolor || color)
    {
        AddStringLiteral(lexer, " body {\n");

        if (bgurl)
        {
            AddStringLiteral(lexer, "  background-image: url(");
            AddStringLiteral(lexer, bgurl);
            AddStringLiteral(lexer, ");\n");
            MemFree(bgurl);
        }

        if (bgcolor)
        {
            AddStringLiteral(lexer, "  background-color: ");
            AddStringLiteral(lexer, bgcolor);
            AddStringLiteral(lexer, ";\n");
            MemFree(bgcolor);
        }

        if (color)
        {
            AddStringLiteral(lexer, "  color: ");
            AddStringLiteral(lexer, color);
            AddStringLiteral(lexer, ";\n");
            MemFree(color);
        }

        AddStringLiteral(lexer, " }\n");
    }

    attr = GetAttrByName(body, "link");

    if (attr)
    {
        AddColorRule(lexer, " :link", attr->value);
        RemoveAttribute(body, attr);
    }

    attr = GetAttrByName(body, "vlink");

    if (attr)
    {
        AddColorRule(lexer, " :visited", attr->value);
        RemoveAttribute(body, attr);
    }

    attr = GetAttrByName(body, "alink");

    if (attr)
    {
        AddColorRule(lexer, " :active", attr->value);
        RemoveAttribute(body, attr);
    }
}

static Bool NiceBody(Lexer *lexer, Node *doc)
{
    Node *body = FindBody(doc);

    if (body)
    {
        if (
            GetAttrByName(body, "background") ||
            GetAttrByName(body, "bgcolor") ||
            GetAttrByName(body, "text") ||
            GetAttrByName(body, "link") ||
            GetAttrByName(body, "vlink") ||
            GetAttrByName(body, "alink")
           )
        {
            lexer->badLayout |= USING_BODY;
            return no;
        }
    }

    return yes;
}

/* create style element using rules from dictionary */
static void CreateStyleElement(Lexer *lexer, Node *doc)
{
    Node *node, *head, *body;
    Style *style;
    AttVal *av;

    if (lexer->styles == null && NiceBody(lexer, doc))
        return;

    node = NewNode();
    node->type = StartTag;
    node->implicit = yes;
    node->element = wstrdup("style");
    FindTag(node);

    /* insert type attribute */
    av = NewAttribute();
    av->attribute = wstrdup("type");
    av->value = wstrdup("text/css");
    av->delim = '"';
    av->dict = FindAttribute(av);
    node->attributes = av;

    body = FindBody(doc);

    lexer->txtstart = lexer->lexsize;

    if (body)
        CleanBodyAttrs(lexer, body);

    for (style = lexer->styles; style; style = style->next)
    {
        AddCharToLexer(lexer, ' ');
        AddStringLiteral(lexer, style->tag);
        AddCharToLexer(lexer, '.');
        AddStringLiteral(lexer, style->tag_class);
        AddCharToLexer(lexer, ' ');
        AddCharToLexer(lexer, '{');
        AddStringLiteral(lexer, style->properties);
        AddCharToLexer(lexer, '}');
        AddCharToLexer(lexer, '\n');
    }

    lexer->txtend = lexer->lexsize;

    InsertNodeAtEnd(node, TextToken(lexer));

    /*
     now insert style element into document head

     doc is root node. search its children for html node
     the head node should be first child of html node
    */

    head = FindHead(doc);

    if (head)
        InsertNodeAtEnd(head, node);
}


/* ensure bidirectional links are consistent */
static void FixNodeLinks(Node *node)
{
    Node *child;

    if (node->prev)
        node->prev->next = node;
    else
        node->parent->content = node;

    if (node->next)
        node->next->prev = node;
    else
        node->parent->last = node;

    for (child = node->content; child; child = child->next)
        child->parent = node;
}

/*
 used to strip child of node when
 the node has one and only one child
*/
static void StripOnlyChild(Node *node)
{
    Node *child;

    child = node->content;
    node->content = child->content;
    node->last = child->last;
    child->content = null;
    FreeNode(child);

    for (child = node->content; child; child = child->next)
        child->parent = node;
}

/* used to strip font start and end tags */
static void DiscardContainer(Node *element, Node **pnode)
{
    Node *node, *parent = element->parent;

    if (element->content)
    {
        element->last->next = element->next;

        if (element->next)
        {
            element->next->prev = element->last;
            element->last->next = element->next;
        }
        else
            parent->last = element->last;

        if (element->prev)
        {
            element->content->prev = element->prev;
            element->prev->next = element->content;
        }
        else
            parent->content = element->content;

        for (node = element->content; node; node = node->next)
            node->parent = parent;

        *pnode = element->content;
    }
    else
    {
        if (element->next)
            element->next->prev = element->prev;
        else
            parent->last = element->prev;

        if (element->prev)
            element->prev->next = element->next;
        else
            parent->content = element->next;

        *pnode = element->next;
    }

    element->next = element->content = null;
    FreeNode(element);
}

/*
 Add style property to element, creating style
 attribute as needed and adding ; delimiter
*/
static void AddStyleProperty(Node *node, char *property)
{
    AttVal *av;

    for (av = node->attributes; av; av = av->next)
    {
        if (wstrcmp(av->attribute, "style") == 0)
            break;
    }

    /* if style attribute already exists then insert property */

    if (av)
    {
        char *s;

        s = AddProperty(av->value, property);
        MemFree(av->value);
        av->value = s;
    }
    else /* else create new style attribute */
    {
        av = NewAttribute();
        av->attribute = wstrdup("style");
        av->value = wstrdup(property);
        av->delim = '"';
        av->dict = FindAttribute(av);
        av->next = node->attributes;
        node->attributes = av;
    }
}

/*
  Create new string that consists of the
  combined style properties in s1 and s2

  To merge property lists, we build a linked
  list of property/values and insert properties
  into the list in order, merging values for
  the same property name.
*/
static char *MergeProperties(char *s1, char *s2)
{
    char *s;
    StyleProp *prop;

    prop = CreateProps(null, s1);
    prop = CreateProps(prop, s2);
    s = CreatePropString(prop);
    FreeStyleProps(prop);
    return s;
}

static void MergeStyles(Node *node, Node *child)
{
    AttVal *av;
    char *s1, *s2, *style;

    for (s2 = null, av = child->attributes; av; av = av->next)
    {
        if (wstrcmp(av->attribute, "style") == 0)
        {
            s2 = av->value;
            break;
        }
    }

    for (s1 = null, av = node->attributes; av; av = av->next)
    {
        if (wstrcmp(av->attribute, "style") == 0)
        {
            s1 = av->value;
            break;
        }
    }

    if (s1)
    {
        if (s2)  /* merge styles from both */
        {
            style = MergeProperties(s1, s2);
            MemFree(av->value);
            av->value = style;
        }
    }
    else if (s2)  /* copy style of child */
    {
        av = NewAttribute();
        av->attribute = wstrdup("style");
        av->value = wstrdup(s2);
        av->delim = '"';
        av->dict = FindAttribute(av);
        av->next = node->attributes;
        node->attributes = av;
    }
}

static char *FontSize2Name(char *size)
{
#if 0
    static char *sizes[7] =
      {
        "50%", "60%", "80%", null,
        "120%", "150%", "200%"
      };
#else
    static char *sizes[7] =
      {
        "60%", "70%", "80%", null,
        "120%", "150%", "200%"
      };
#endif
    static char buf[16];

    if ('0' <= size[0] && size[0] <= '6')
    {
        int n = size[0] - '0';
        return sizes[n];
    }

    if (size[0] == '-')
    {
        if ('0' <= size[1] && size[1] <= '6')
        {
            int n = size[1] - '0';
            double x;

            for (x = 1; n > 0; --n)
                x *= 0.8;

            x *= 100;
            snprintf (buf, sizeof (buf), "%d%%", (int)(x));

            return buf;
        }

        return "smaller"; /*"70%"; */
    }

    if ('0' <= size[1] && size[1] <= '6')
    {
        int n = size[1] - '0';
        double x;

        for (x = 1; n > 0; --n)
            x *= 1.2;

        x *= 100;
        snprintf (buf, sizeof (buf), "%d%%", (int)(x));

        return buf;
    }

    return "larger"; /* "140%" */
}

static void AddFontFace(Node *node, char *face)
{
    char buf[1024];

    snprintf (buf, sizeof (buf), "font-family: %s", face);
    AddStyleProperty(node, buf);
}

static void AddFontSize(Node *node, char *size)
{
    char *value, buf[1024];

    if (wstrcmp(size, "6") == 0 && node->tag == tag_p)
    {
        MemFree(node->element);
        node->element = wstrdup("h1");
        FindTag(node);
        return;
    }

    if (wstrcmp(size, "5") == 0 && node->tag == tag_p)
    {
        MemFree(node->element);
        node->element = wstrdup("h2");
        FindTag(node);
        return;
    }

    if (wstrcmp(size, "4") == 0 && node->tag == tag_p)
    {
        MemFree(node->element);
        node->element = wstrdup("h3");
        FindTag(node);
        return;
    }

    value = FontSize2Name(size);

    if (value)
    {
        snprintf (buf, sizeof (buf), "font-size: %s", value);
        AddStyleProperty(node, buf);
    }
}

static void AddFontColor(Node *node, char *color)
{
    char buf[1024];

    snprintf (buf, sizeof (buf), "color: %s", color);
    AddStyleProperty(node, buf);
}

static void AddAlign(Node *node, char *align)
{
    char buf[1024], *p, *q;

    /* force alignment value to lower case */
    for (p = buf, q = "text-align: "; (*p++ = *q++););
    for (p = p-1; (*p++ = ToLower(*align++)););
    AddStyleProperty(node, buf);
}

/*
 add style properties to node corresponding to
 the font face, size and color attributes
*/
static void AddFontStyles(Node *node, AttVal *av)
{
    while (av)
    {
        if (wstrcmp(av->attribute, "face") == 0)
            AddFontFace(node, av->value);
        else if (wstrcmp(av->attribute, "size") == 0)
            AddFontSize(node, av->value);
        else if (wstrcmp(av->attribute, "color") == 0)
            AddFontColor(node, av->value);

        av = av->next;
    }
}

/*
    Symptom: <p align=center>
    Action: <p style="text-align: center">
*/
static void TextAlign(Lexer *lexer, Node *node)
{
    AttVal *av, *prev;

    prev = null;

    for (av = node->attributes; av; av = av->next)
    {
        if (wstrcmp(av->attribute, "align") == 0)
        {
            if (prev)
                prev->next = av->next;
            else
                node->attributes = av->next;

            MemFree(av->attribute);

            if (av->value)
            {
                AddAlign(node, av->value);
                MemFree(av->value);
            }

            MemFree(av);
            break;
        }

        prev = av;
    }
}

/*
   The clean up rules use the pnode argument to return the
   next node when the orignal node has been deleted
*/

/*
    Symptom: <dir> <li> where <li> is only child
    Action: coerce <dir> <li> to <div> with indent.
*/

static Bool Dir2Div(Lexer *lexer, Node *node, Node **pnode)
{
    Node *child;

    if (node->tag == tag_dir || node->tag == tag_ul || node->tag == tag_ol)
    {
        child = node->content;

        if (child == null)
            return no;

        /* check child has no peers */

        if (child->next)
            return no;

        if (child->tag != tag_li)
            return no;

        if (!child->implicit)
            return no;

        /* coerce dir to div */

        node->tag = tag_div;
        MemFree(node->element);
        node->element = wstrdup("div");
        AddStyleProperty(node, "margin-left: 2em");
        StripOnlyChild(node);
        return yes;

#if 0
        content = child->content;
        last = child->last;
        child->content = null;

        /* adjust parent and set margin on contents of <li> */

        for (child = content; child; child = child->next)
        {
            child->parent = node->parent;
            AddStyleProperty(child, "margin-left: 1em");
        }

        /* hook first/last into sequence */

        if (content)
        {
            content->prev = node->prev;
            last->next = node->next;
            FixNodeLinks(content);
            FixNodeLinks(last);
        }

        node->next = null;
        FreeNode(node);

        /* ensure that new node is cleaned */
        *pnode = CleanNode(lexer, content);
        return yes;
#endif
    }

    return no;
}

/*
    Symptom: <center>
    Action: replace <center> by <div style="text-align: center">
*/

static Bool Center2Div(Lexer *lexer, Node *node, Node **pnode)
{
    if (node->tag == tag_center)
    {
        if (DropFontTags)
        {
            if (node->content)
            {
                Node *last = node->last, *parent = node->parent;

                DiscardContainer(node, pnode);

                node = InferredTag(lexer, "br");

                if (last->next)
                    last->next->prev = node;

                node->next = last->next;
                last->next = node;
                node->prev = last;

                if (parent->last == last)
                    parent->last = node;

                node->parent = parent;
            }
            else
            {
                Node *prev = node->prev, *next = node->next, *parent = node->parent;
                DiscardContainer(node, pnode);

                node = InferredTag(lexer, "br");
                node->next = next;
                node->prev = prev;
                node->parent = parent;

                if (next)
                    next->prev = node;
                else
                    parent->last = node;

                if (prev)
                    prev->next = node;
                else
                    parent->content = node;
            }

            return yes;
        }

        node->tag = tag_div;
        MemFree(node->element);
        node->element = wstrdup("div");
        AddStyleProperty(node, "text-align: center");
        return yes;
    }

    return no;
}

/*
    Symptom <div><div>...</div></div>
    Action: merge the two divs

  This is useful after nested <dir>s used by Word
  for indenting have been converted to <div>s
*/
static Bool MergeDivs(Lexer *lexer, Node *node, Node **pnode)
{
    Node *child;

    if (node->tag != tag_div)
        return no;

    child = node->content;

    if (!child)
        return no;

    if (child->tag != tag_div)
        return no;

    if (child->next != null)
        return no;

    MergeStyles(node, child);
    StripOnlyChild(node);
    return yes;
}

/*
    Symptom: <ul><li><ul>...</ul></li></ul>
    Action: discard outer list
*/

static Bool NestedList(Lexer *lexer, Node *node, Node **pnode)
{
    Node *child, *list;

    if (node->tag == tag_ul || node->tag == tag_ol)
    {
        child = node->content;

        if (child == null)
            return no;

        /* check child has no peers */

        if (child->next)
            return no;

        list = child->content;

        if (!list)
            return no;

        if (list->tag != node->tag)
            return no;

        *pnode = node->next;

        /* move inner list node into position of outer node */
        list->prev = node->prev;
        list->next = node->next;
        list->parent = node->parent;
        FixNodeLinks(list);

        /* get rid of outer ul and its li */
        child->content = null;
        node->content = null;
        node->next = null;
        FreeNode(node);

        /*
          If prev node was a list the chances are this node
          should be appended to that list. Word has no way of
          recognizing nested lists and just uses indents
        */

        if (list->prev)
        {
            node = list;
            list = node->prev;

            if (list->tag == tag_ul || list->tag == tag_ol)
            {
                list->next = node->next;

                if (list->next)
                    list->next->prev = list;

                child = list->last;  /* <li> */

                node->parent = child;
                node->next = null;
                node->prev = child->last;
                FixNodeLinks(node);
            }
        }

        CleanNode(lexer, node);
        return yes;
    }

    return no;
}

/*
  Symptom: the only child of a block-level element is a
  presentation element such as B, I or FONT

  Action: add style "font-weight: bold" to the block and
  strip the <b> element, leaving its children.

  example:

    <p>
      <b><font face="Arial" size="6">Draft Recommended Practice</font></b>
    </p>

  becomes:

      <p style="font-weight: bold; font-family: Arial; font-size: 6">
        Draft Recommended Practice
      </p>

  This code also replaces the align attribute by a style attribute.
  However, to avoid CSS problems with Navigator 4, this isn't done
  for the elements: caption, tr and table
*/
static Bool BlockStyle(Lexer *lexer, Node *node, Node **pnode)
{
    Node *child;

    if (node->tag->model & (CM_BLOCK | CM_LIST | CM_DEFLIST | CM_TABLE))
    {
        if (node->tag != tag_table
                && node->tag != tag_tr
                && node->tag != tag_li)
        {
            /* check for align attribute */
            if (node->tag != tag_caption)
                TextAlign(lexer, node);

            child = node->content;

            if (child == null)
                return no;

            /* check child has no peers */

            if (child->next)
                return no;

            if (child->tag == tag_b)
            {
                MergeStyles(node, child);
                AddStyleProperty(node, "font-weight: bold");
                StripOnlyChild(node);
                return yes;
            }

            if (child->tag == tag_i)
            {
                MergeStyles(node, child);
                AddStyleProperty(node, "font-style: italic");
                StripOnlyChild(node);
                return yes;
            }

            if (child->tag == tag_font)
            {
                MergeStyles(node, child);
                AddFontStyles(node, child->attributes);
                StripOnlyChild(node);
                return yes;
            }
        }
    }

    return no;
}

/* the only child of table cell or an inline element such as em */
static Bool InlineStyle(Lexer *lexer, Node *node, Node **pnode)
{
    Node *child;

    if (node->tag != tag_font && (node->tag->model & (CM_INLINE|CM_ROW)))
    {
        child = node->content;

        if (child == null)
            return no;

        /* check child has no peers */

        if (child->next)
            return no;

        if (child->tag == tag_b && LogicalEmphasis)
        {
            MergeStyles(node, child);
            AddStyleProperty(node, "font-weight: bold");
            StripOnlyChild(node);
            return yes;
        }

        if (child->tag == tag_i && LogicalEmphasis)
        {
            MergeStyles(node, child);
            AddStyleProperty(node, "font-style: italic");
            StripOnlyChild(node);
            return yes;
        }

        if (child->tag == tag_font)
        {
            MergeStyles(node, child);
            AddFontStyles(node, child->attributes);
            StripOnlyChild(node);
            return yes;
        }
    }

    return no;
}

/*
  Replace font elements by span elements, deleting
  the font element's attributes and replacing them
  by a single style attribute.
*/
static Bool Font2Span(Lexer *lexer, Node *node, Node **pnode)
{
    AttVal *av, *style, *next;

    if (node->tag == tag_font)
    {
        if (DropFontTags)
        {
            DiscardContainer(node, pnode);
            return no;
        }

        /* if FONT is only child of parent element then leave alone */
        if (node->parent->content == node
            && node->next == null)
            return no;

        AddFontStyles(node, node->attributes);

        /* extract style attribute and free the rest */
        av = node->attributes;
        style = null;

        while (av)
        {
            next = av->next;

            if (wstrcmp(av->attribute, "style") == 0)
            {
                av->next = null;
                style = av;
            }
            else
            {
                if (av->attribute)
                    MemFree(av->attribute);
                if (av->value)
                    MemFree(av->value);

                MemFree(av);
            }

            av = next;
        }

        node->attributes = style;

        node->tag = tag_span;
        MemFree(node->element);
        node->element = wstrdup("span");

        return yes;
    }

    return no;
}

static Bool IsElement(Node *node)
{
    return (node->type == StartTag || node->type == StartEndTag ? yes : no);
}

/*
  Applies all matching rules to a node.
*/
Node *CleanNode(Lexer *lexer, Node *node)
{
    Node *next = null;

    for (next = node; IsElement(node); node = next)
    {
        if (Dir2Div(lexer, node, &next))
            continue;

        if (NestedList(lexer, node, &next))
            continue;

        if (Center2Div(lexer, node, &next))
            continue;

        if (MergeDivs(lexer, node, &next))
            continue;

        if (BlockStyle(lexer, node, &next))
            continue;

        if (InlineStyle(lexer, node, &next))
            continue;

        if (Font2Span(lexer, node, &next))
            continue;

        break;
    }

    return next;
}

static Node *CreateStyleProperties(Lexer *lexer, Node *node)
{
    Node *child;

    if (node->content)
    {
        for (child = node->content; child != null; child = child->next)
        {
            child = CreateStyleProperties(lexer, child);
        }
    }

    return CleanNode(lexer, node);
}

static void DefineStyleRules(Lexer *lexer, Node *node)
{
    Node *child;

    if (node->content)
    {
        for (child = node->content;
                child != null; child = child->next)
        {
            DefineStyleRules(lexer, child);
        }
    }

    Style2Rule(lexer, node);
}

void CleanTree(Lexer *lexer, Node *doc)
{
    doc = CreateStyleProperties(lexer, doc);

    if (MakeClean)
    {
        DefineStyleRules(lexer, doc);
        CreateStyleElement(lexer, doc);
    }
}

/* simplifies <b><b> ... </b> ...</b> etc. */
void NestedEmphasis(Node *node)
{
    Node *next;

    while (node)
    {
        next = node->next;

        if ((node->tag == tag_b || node->tag == tag_i)
            && node->parent && node->parent->tag == node->tag)
        {
            /* strip redundant inner element */
            DiscardContainer(node, &next);
            node = next;
            continue;
        }

        if (node->content)
            NestedEmphasis(node->content);

        node = next;
    }
}

/* replace i by em and b by strong */
void EmFromI(Node *node)
{
    while (node)
    {
        if (node->tag == tag_i)
        {
            MemFree(node->element);
            node->element = wstrdup(tag_em->name);
            node->tag = tag_em;
        }
        else if (node->tag == tag_b)
        {
            MemFree(node->element);
            node->element = wstrdup(tag_strong->name);
            node->tag = tag_strong;
        }

        if (node->content)
            EmFromI(node->content);

        node = node->next;
    }
}

static Bool HasOneChild(Node *node)
{
    return (node->content && node->content->next == null);
}

/*
 Some people use dir or ul without an li
 to indent the content. The pattern to
 look for is a list with a single implicit
 li. This is recursively replaced by an
 implicit blockquote.
*/
void List2BQ(Node *node)
{
    while (node)
    {
        if (node->content)
            List2BQ(node->content);

        if (node->tag && node->tag->parser == ParseList &&
            HasOneChild(node) && node->content->implicit)
        {
            StripOnlyChild(node);
            MemFree(node->element);
            node->element = wstrdup(tag_blockquote->name);
            node->tag = tag_blockquote;
            node->implicit = yes;
        }

        node = node->next;
    }
}

static char indent_buf[32];

/*
 Replace implicit blockquote by div with an indent
 taking care to reduce nested blockquotes to a single
 div with the indent set to match the nesting depth
*/
void BQ2Div(Node *node)
{
    int indent;

    while (node)
    {
        if (node->tag == tag_blockquote && node->implicit)
        {
            indent = 1;

            while(HasOneChild(node) &&
                  node->content->tag == tag_blockquote &&
                  node->implicit)
            {
                ++indent;
                StripOnlyChild(node);
            }

            if (node->content)
                BQ2Div(node->content);

            snprintf (indent_buf, sizeof (indent_buf), "margin-left: %dem", 2*indent);

            MemFree(node->element);
            node->element = wstrdup(tag_div->name);
            node->tag = tag_div;
            AddAttribute(node, "style", indent_buf);
        }
        else if (node->content)
            BQ2Div(node->content);


        node = node->next;
    }
}

/* node is <![if ...]> prune up to <![endif]> */
static Node *PruneSection(Lexer *lexer, Node *node)
{
    for (;;)
    {
        /* discard node and returns next */
        node = DiscardElement(node);

        if (node == null)
            return null;

        if (node->type == SectionTag)
        {
            if (wstrncmp(lexer->lexbuf + node->start, "if", 2) == 0)
            {
                node = PruneSection(lexer, node);
                continue;
            }

            if (wstrncmp(lexer->lexbuf + node->start, "endif", 5) == 0)
            {
                node = DiscardElement(node);
                break;
            }
        }
    }

    return node;
}

void DropSections(Lexer *lexer, Node *node)
{
    while (node)
    {
        if (node->type == SectionTag)
        {
            /* prune up to matching endif */
            if (wstrncmp(lexer->lexbuf + node->start, "if", 2) == 0)
            {
                node = PruneSection(lexer, node);
                continue;
            }

            /* discard others as well */
            node = DiscardElement(node);
            continue;
        }

        if (node->content)
            DropSections(lexer, node->content);

        node = node->next;
    }
}

static void PurgeAttributes(Node *node)
{
    AttVal *attr = node->attributes, *next, *prev = null;

    while (attr)
    {
        next = attr->next;

        /* special check for class="Code" denoting pre text */
        if (wstrcmp(attr->attribute, "class") == 0 &&
            wstrcmp(attr->value, "Code") == 0)
        {
            prev = attr;
        }
        else if (wstrcmp(attr->attribute, "class") == 0 ||
            wstrcmp(attr->attribute, "style") == 0 ||
            wstrcmp(attr->attribute, "lang") == 0 ||
            wstrncmp(attr->attribute, "x:", 2) == 0 ||
            ((wstrcmp(attr->attribute, "heigy") == 0 ||
              wstrcmp(attr->attribute, "width") == 0) &&
                (node->tag == tag_td ||
                 node->tag == tag_tr ||
                 node->tag == tag_th)))
        {
            if (prev)
                prev->next = next;
            else
                node->attributes = next;

            FreeAttribute(attr);
        }
        else
            prev = attr;

        attr = next;
    }
}

/* Word2000 uses span excessively, so we strip span out */
static Node *StripSpan(Lexer *lexer, Node *span)
{
    Node *node, *prev = null, *content;

    /*
     deal with span elements that have content
     by splicing the content in place of the span
     after having processed it
    */

    CleanWord2000(lexer, span->content);
    content = span->content;

    if (span->prev)
        prev = span->prev;
    else if (content)
    {
        node = content;
        content = content->next;
        RemoveNode(node);
        InsertNodeBeforeElement(span, node);
        prev = node;
    }

    while (content)
    {
        node = content;
        content = content->next;
        RemoveNode(node);
        InsertNodeAfterElement(prev, node);
        prev = node;
    }

    if (span->next == null)
        span->parent->last = prev;

    node = span->next;
    span->content = null;
    DiscardElement(span);
    return node;
}

/* map non-breaking spaces to regular spaces */
static void NormalizeSpaces(Lexer *lexer, Node *node)
{
    while (node)
    {
        if (node->content)
            NormalizeSpaces(lexer, node->content);

        if (node->type == TextNode)
        {
            unsigned int i, c;
            char *p = lexer->lexbuf + node->start;

            for (i = node->start; i < node->end; ++i)
            {
                c = (unsigned char)lexer->lexbuf[i];

                /* look for UTF-8 multibyte character */
                if (c > 0x7F)
                    i += GetUTF8((unsigned char *)(lexer->lexbuf + i), &c);

                if (c == 160)
                    c = ' ';

                p = PutUTF8(p, c);
            }
        }

        node = node->next;
    }
}

/*
 This is a major clean up to strip out all the extra stuff you get
 when you save as web page from Word 2000. It doesn't yet know what
 to do with VML tags, but these will appear as errors unless you
 declare them as new tags, such as o:p which needs to be declared
 as inline.
*/
void CleanWord2000(Lexer *lexer, Node *node)
{
    /* used to a list from a sequence of bulletted p's */
    Node *list = null;

    while (node)
    {
        /* discard Word's style verbiage */
        if (node->tag == tag_style || node->tag == tag_meta || node->type == CommentTag)
        {
            node = DiscardElement(node);
            continue;
        }

        /* strip out all span tags Word scatters so liberally! */
        if (node->tag == tag_span)
        {
            node = StripSpan(lexer, node);
            continue;
        }

        /* get rid of Word's xmlns attributes */
        if (node->tag == tag_html)
        {
            /* check that it's a Word 2000 document */
            if (!GetAttrByName(node, "xmlns:o"))
                return;

            FreeAttrs(node);
        }

        if (node->tag == tag_link)
        {
            AttVal *attr = GetAttrByName(node, "rel");

            if (attr && wstrcmp(attr->value, "File-List") == 0)
            {
                node = DiscardElement(node);
                continue;
            }
        }

        /* discard empty paragraphs */
        if (node->content == null && node->tag == tag_p)
        {
            node = DiscardElement(node);
            continue;
        }

        if (node->tag == tag_p)
        {
            AttVal *attr = GetAttrByName(node, "class");

            /* map sequence of <p class="MsoListBullet"> to <ul>...</ul> */
            if (attr && wstrcmp(attr->value, "MsoListBullet") == 0)
            {
                CoerceNode(lexer, node, tag_li);

                if (!list || list->tag != tag_ul)
                {
                    list = InferredTag(lexer, "ul");
                    InsertNodeBeforeElement(node, list);
                }

                PurgeAttributes(node);

                if (node->content)
                    CleanWord2000(lexer, node->content);

                /* remove node and append to contents of list */
                RemoveNode(node);
                InsertNodeAtEnd(list, node);
                node = list->next;
            }
            /* map sequence of <p class="Code"> to <pre>...</pre> */
            else if (attr && wstrcmp(attr->value, "Code") == 0)
            {
                Node *br = NewLineNode(lexer);
                NormalizeSpaces(lexer, node);

                if (!list || list->tag != tag_pre)
                {
                    list = InferredTag(lexer, "pre");
                    InsertNodeBeforeElement(node, list);
                }

                /* remove node and append to contents of list */
                RemoveNode(node);
                InsertNodeAtEnd(list, node);
                StripSpan(lexer, node);
                InsertNodeAtEnd(list, br);
                node = list->next;
            }
            else
                list = null;
        }
        else
            list = null;

        /* strip out style and class attributes */
        if (node->type == StartTag || node->type == StartEndTag)
            PurgeAttributes(node);

        if (node->content)
            CleanWord2000(lexer, node->content);

        node = node->next;
    }
}

Bool IsWord2000(Node *root)
{
    Node *html = FindHTML(root);

    return (html && GetAttrByName(html, "xmlns:o"));
}
