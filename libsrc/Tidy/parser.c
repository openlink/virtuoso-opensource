/*
  parser.c - HTML Parser

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

int SeenBodyEndTag;  /* could be moved into lexer structure */

Bool CheckNodeIntegrity(Node *node)
{
    Node *child;
    Bool found = no;

    if (node->prev)
    {
        if (node->prev->next != node)
            return no;
    }

    if (node->next)
    {
        if (node->next->prev != node)
            return no;
    }

    if (node->parent)
    {
        if (node->prev == null && node->parent->content != node)
            return no;

        if (node->next == null && node->parent->last != node)
            return no;

        for (child = node->parent->content; child; child = child->next)
            if (child == node)
            {
                found = yes;
                break;
            }

        if (!found)
            return no;
    }

    for (child = node->content; child; child = child->next)
        if (!CheckNodeIntegrity(child))
            return no;

    return yes;
}

/*
 used to determine how attributes
 without values should be printed
 this was introduced to deal with
 user defined tags e.g. Cold Fusion
*/
Bool IsNewNode(Node *node)
{
    if (node && node->tag)
    {
        return (node->tag->model & CM_NEW);
    }

    return yes;
}

void CoerceNode(Lexer *lexer, Node *node, Dict *tag)
{
    Node *tmp = InferredTag(lexer, tag->name);
    ReportWarning(lexer, node, tmp, OBSOLETE_ELEMENT);
    MemFree(tmp->element);
    MemFree(tmp);
    MemFree(node->element);
    node->was = node->tag;
    node->tag = tag;
    node->type = StartTag;
    node->implicit = yes;
    node->element = wstrdup(tag->name);
}

/* extract a node and its children from a markup tree */
void RemoveNode(Node *node)
{
    if (node->prev)
        node->prev->next = node->next;

    if (node->next)
        node->next->prev = node->prev;

    if (node->parent)
    {
        if (node->parent->content == node)
            node->parent->content = node->next;

        if (node->parent->last == node)
            node->parent->last = node->prev;
    }

    node->parent = node->prev = node->next = null;
}

/* remove node from markup tree and discard it */
Node *DiscardElement(Node *element)
{
    Node *next = null;

    if (element)
    {
        next = element->next;
        RemoveNode(element);
        FreeNode(element);
    }

    return next;
}

/* insert node into markup tree */
void InsertNodeAtStart(Node *element, Node *node)
{
    node->parent = element;

    if (element->content == null)
        element->last = node;

    node->next = element->content;
    node->prev = null;
    element->content = node;
}

/* insert node into markup tree */
void InsertNodeAtEnd(Node *element, Node *node)
{
    node->parent = element;
    node->prev = element->last;

    if (element->last != null)
        element->last->next = node;
    else
        element->content = node;

    element->last = node;
}

/*
 insert node into markup tree in pace of element
 which is moved to become the child of the node
*/
static void InsertNodeAsParent(Node *element, Node *node)
{
    node->content = element;
    node->last = element;
    node->parent = element->parent;
    element->parent = node;
    
    if (node->parent->content == element)
        node->parent->content = node;

    if (node->parent->last == element)
        node->parent->last = node;

    node->prev = element->prev;
    element->prev = null;

    if (node->prev)
        node->prev->next = node;

    node->next = element->next;
    element->next = null;

    if (node->next)
        node->next->prev = node;
}

/* insert node into markup tree before element */
void InsertNodeBeforeElement(Node *element, Node *node)
{
    Node *parent;

    parent = element->parent;
    node->parent = parent;
    node->next = element;
    node->prev = element->prev;
    element->prev = node;

    if (node->prev)
        node->prev->next = node;

    if (parent->content == element)
        parent->content = node;
}

/* insert node into markup tree after element */
void InsertNodeAfterElement(Node *element, Node *node)
{
    Node *parent;

    parent = element->parent;
    node->parent = parent;

    if (parent->last == element)
        parent->last = node;
    else
    {
        node->next = element->next;
        node->next->prev = node;
    }

    element->next = node;
    node->prev = element;
}

static Bool CanPrune(Node *element)
{
    if (element->type == TextNode)
        return yes;

    if (element->content)
        return no;

    if (element->tag == tag_a && element->attributes != null)
        return no;

    if (element->tag == tag_p && !DropEmptyParas)
        return no;

    if (element->tag == null)
        return no;

    if (element->tag->model & CM_ROW)
        return no;

    if (element->tag == tag_applet)
        return no;

    if (element->tag == tag_object)
        return no;

    if ( element->attributes != null &&
            (GetAttrByName(element, "id") ||
               GetAttrByName(element, "name")) )
        return no;

    return yes;
}

static void TrimEmptyElement(Lexer *lexer, Node *element)
{
    if (CanPrune(element))
    {
       if (element->type != TextNode)
            ReportWarning(lexer, element, null, TRIM_EMPTY_ELEMENT);

        DiscardElement(element);
    }
    else if (element->tag == tag_p && element->content == null)
    {
        /* replace <p></p> by <br><br> to preserve formatting */
        Node *node = InferredTag(lexer, "br");
        CoerceNode(lexer, element, tag_br);
        InsertNodeAfterElement(element, node);
    }
}

/*
  This maps 
       <em>hello </em><strong>world</strong>
  to
       <em>hello</em> <strong>world</strong>

  If last child of element is a text node
  then trim trailing white space character
  moving it to after element's end tag.
*/
static void TrimTrailingSpace(Lexer *lexer, Node *element, Node *last)
{
    unsigned char c;

    if (last != null && last->type == TextNode && last->end > last->start)
    {
        c = (unsigned char)lexer->lexbuf[last->end - 1];

        if (c == 160 || c == ' ')
        {
            /* take care with <td>&nbsp;</td> */
            if (element->tag == tag_td || element->tag == tag_th)
            {
                if (last->end > last->start + 1)
                    last->end -= 1;
            }
            else
            {
                last->end -= 1;

                if ((element->tag->model & CM_INLINE) &&
                        !(element->tag->model & CM_FIELD))
                    lexer->insertspace = yes;

                /* if empty string then delete from parse tree */
                if (last->start == last->end)
                    TrimEmptyElement(lexer, last);
            }
        }
    }
}

/*
  This maps 
       <p>hello<em> world</em>
  to
       <p>hello <em>world</em>

  Trims initial space, by moving it before the
  start tag, or if this element is the first in
  parent's content, then by discarding the space
*/
static void TrimInitialSpace(Lexer *lexer, Node *element, Node *text)
{
    Node *prev, *node;

    if (text->type == TextNode && lexer->lexbuf[text->start] == ' ')
    {
        if ((element->tag->model & CM_INLINE) &&
            !(element->tag->model & CM_FIELD) &&
            element->parent->content != element)
        {
            prev = element->prev;

            if (prev && prev->type == TextNode)
            {
                if (lexer->lexbuf[prev->end - 1] != ' ')
                    lexer->lexbuf[(prev->end)++] = ' ';

                ++(element->start);
            }
            else /* create new node */
            {
                node = NewNode();
                node->start = (element->start)++;
                node->end = element->start;
                lexer->lexbuf[node->start] = ' ';
                node->prev = prev;

                if (prev)
                    prev->next = node;

                node->next = element;
                element->prev = node;
                node->parent = element->parent;
            }
        }

        /* discard the space  in current node */
        ++(text->start);
    }
}

/* 
  Move initial and trailing space out.
  This routine maps:

       hello<em> world</em>
  to
       hello <em>world</em>
  and
       <em>hello </em><strong>world</strong>
  to
       <em>hello</em> <strong>world</strong>
*/
static void TrimSpaces(Lexer *lexer, Node *element)
{
    Node *text = element->content;

    if (text && text->type == TextNode && element->tag != tag_pre)
        TrimInitialSpace(lexer, element, text);

    text = element->last;

    if (text && text->type == TextNode)
        TrimTrailingSpace(lexer, element, text);
}

static Bool DescendantOf(Node *element, Dict *tag)
{
    Node *parent;

    for (parent = element->parent;
            parent != null; parent = parent->parent)
    {
        if (parent->tag == tag)
            return yes;
    }

    return no;
}

static Bool InsertMisc(Node *element, Node *node)
{
    if (node->type == CommentTag ||
        node->type == ProcInsTag ||
        node->type == CDATATag ||
        node->type == SectionTag ||
        node->type == AspTag ||
        node->type == JsteTag ||
        node->type == PhpTag)
    {
        InsertNodeAtEnd(element, node);
        return yes;
    }

    return no;
}


static void ParseTag(Lexer *lexer, Node *node, uint mode)
{
    if (node->tag->model & CM_EMPTY)
    {
        lexer->waswhite = no;
        return;
    }
    else if (!(node->tag->model & CM_INLINE))
        lexer->insertspace = no;

    if (node->tag->parser == null || node->type == StartEndTag)
        return;

    (*node->tag->parser)(lexer, node, mode);
}

/*
 the doctype has been found after other tags,
 and needs moving to before the html element
*/
static void InsertDocType(Lexer *lexer, Node *element, Node *doctype)
{
    ReportWarning(lexer, element, doctype, DOCTYPE_AFTER_TAGS);

    while (element->tag != tag_html)
        element = element->parent;

    InsertNodeBeforeElement(element, doctype);
}

/* duplicate name attribute as an id */
void FixId(Lexer *lexer, Node *node)
{
    AttVal *name = GetAttrByName(node, "name");
    AttVal *id = GetAttrByName(node, "id");

    if (name)
    {
        if (id)
        {
            if (wstrcmp(id->value, name->value) != 0)
                ReportAttrError(lexer, node, "name", ID_NAME_MISMATCH);
        }
        else if (XmlOut)
            AddAttribute(node, "id", name->value);
    }
}

static void MoveToHead(Lexer *lexer, Node *element, Node *node)
{
    Node *head;


    if (node->type == StartTag || node->type == StartEndTag)
    {
        ReportWarning(lexer, element, node, TAG_NOT_ALLOWED_IN);

        while (element->tag != tag_html)
            element = element->parent;

        for (head = element->content; head; head = head->next)
        {
            if (head->tag == tag_head)
            {
                InsertNodeAtEnd(head, node);
                break;
            }
        }

        if (node->tag->parser)
            ParseTag(lexer, node, IgnoreWhitespace);
    }
    else
    {
        ReportWarning(lexer, element, node, DISCARDING_UNEXPECTED);
        FreeNode(node);
    }
}

/*
   element is node created by the lexer
   upon seeing the start tag, or by the
   parser when the start tag is inferred
*/
void ParseBlock(Lexer *lexer, Node *element, uint mode)
{
    Node *node, *parent;
    Bool checkstack;
    uint istackbase = 0;

    checkstack = yes;

    if (element->tag->model & CM_EMPTY)
        return;

    if (element->tag == tag_form && DescendantOf(element, tag_form))
        ReportWarning(lexer, element, null, ILLEGAL_NESTING);

    /*
     InlineDup() asks the lexer to insert inline emphasis tags
     currently pushed on the istack, but take care to avoid
     propagating inline emphasis inside OBJECT or APPLET.
     For these elements a fresh inline stack context is created
     and disposed of upon reaching the end of the element.
     They thus behave like table cells in this respect.
    */
    if (element->tag->model & CM_OBJECT)
    {
        istackbase = lexer->istackbase;
        lexer->istackbase = lexer->istacksize;
    }

    if (!(element->tag->model & CM_MIXED))
        InlineDup(lexer, null);

    mode = IgnoreWhitespace;

    while ((node = GetToken(lexer, mode /*MixedContent*/)) != null)
    {
        /* end tag for this element */
        if (node->type == EndTag && node->tag &&
            (node->tag == element->tag || element->was == node->tag))
        {
            FreeNode(node);

            if (element->tag->model & CM_OBJECT)
            {
                /* pop inline stack */
                while (lexer->istacksize > lexer->istackbase)
                    PopInline(lexer, null);
                lexer->istackbase = istackbase;
            }

            element->closed = yes;
            TrimSpaces(lexer, element);
            TrimEmptyElement(lexer, element);
            return;
        }

        if (node->tag == tag_html || node->tag == tag_head || node->tag == tag_body)
        {
            if (node->type == StartTag || node->type == StartEndTag)
                ReportWarning(lexer, element, node, DISCARDING_UNEXPECTED);

            FreeNode(node);
            continue;
        }


        if (node->type == EndTag)
        {
            if (node->tag == null)
            {
                ReportWarning(lexer, element, node, DISCARDING_UNEXPECTED);

                FreeNode(node);
                continue;
            }
            else if (node->tag == tag_br)
                node->type = StartTag;
            else if (node->tag == tag_p)
            {
                CoerceNode(lexer, node, tag_br);
                InsertNodeAtEnd(element, node);
                node = InferredTag(lexer, "br");
            }
            else
            {
                /* 
                  if this is the end tag for an ancestor element
                  then infer end tag for this element
                */
                for (parent = element->parent;
                        parent != null; parent = parent->parent)
                {
                    if (node->tag == parent->tag)
                    {
                        if (!(element->tag->model & CM_OPT))
                            ReportWarning(lexer, element, node, MISSING_ENDTAG_BEFORE);

                        UngetToken(lexer);

                        if (element->tag->model & CM_OBJECT)
                        {
                            /* pop inline stack */
                            while (lexer->istacksize > lexer->istackbase)
                                PopInline(lexer, null);
                            lexer->istackbase = istackbase;
                        }

                        TrimSpaces(lexer, element);
                        TrimEmptyElement(lexer, element);
                        return;
                    }
                }

                /* special case </tr> etc. for stuff moved in front of table */
                if (lexer->exiled
                            && node->tag->model
                            && (node->tag->model & CM_TABLE))
                {
                    UngetToken(lexer);
                    TrimSpaces(lexer, element);
                    TrimEmptyElement(lexer, element);
                    return;
                }
            }
        }

        /* mixed content model permits text */
        if (node->type == TextNode)
        {
            Bool iswhitenode = no;

            if (node->type == TextNode &&
                   node->end <= node->start + 1 &&
                   lexer->lexbuf[node->start] == ' ')
                iswhitenode = yes;

            if (EncloseBlockText && !iswhitenode)
            {
                UngetToken(lexer);
                node = InferredTag(lexer, "p");
                InsertNodeAtEnd(element, node);
                ParseTag(lexer, node, MixedContent);
                continue;
            }

            if (checkstack)
            {
                checkstack = no;

                if (!(element->tag->model & CM_MIXED))
                {
                    if (InlineDup(lexer, node) > 0)
                        continue;
                }
            }

            InsertNodeAtEnd(element, node);
            mode = MixedContent;

            /*
              HTML4 strict doesn't allow mixed content for
              elements with %block; as their content model
            */
            lexer->versions &= ~VERS_HTML40_STRICT;
            continue;
        }

        if (InsertMisc(element, node))
            continue;

        /* allow PARAM elements? */
        if (node->tag == tag_param)
        {
            if ((element->tag->model & CM_PARAM) &&
                    (node->type == StartEndTag ||
                    node->type == StartTag))
            {
                InsertNodeAtEnd(element, node);
                continue;
            }

            /* otherwise discard it */
            ReportWarning(lexer, element, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        /* allow AREA elements? */
        if (node->tag == tag_area)
        {
            if ((element->tag == tag_map) &&
                    (node->type == StartTag || node->type == StartEndTag))
            {
                InsertNodeAtEnd(element, node);
                continue;
            }

            /* otherwise discard it */
            ReportWarning(lexer, element, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        /* ignore unknown start/end tags */
        if (node->tag == null)
        {
            ReportWarning(lexer, element, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        /*
          Allow CM_INLINE elements here.

          Allow CM_BLOCK elements here unless
          lexer->excludeBlocks is yes.

          LI and DD are special cased.

          Otherwise infer end tag for this element.
        */

        if (!(node->tag->model & CM_INLINE))
        {
            if (node->type != StartTag && node->type != StartEndTag)
            {
                ReportWarning(lexer, element, node, DISCARDING_UNEXPECTED);
                continue;
            }

            if (element->tag == tag_td || element->tag == tag_th)
            {
                /* if parent is a table cell, avoid inferring the end of the cell */

                if (node->tag->model & CM_HEAD)
                {
                    MoveToHead(lexer, element, node);
                    continue;
                }

                if (node->tag->model & CM_LIST)
                {
                    UngetToken(lexer);
                    node = InferredTag(lexer, "ul");
                    AddClass(node, "noindent");
                    lexer->excludeBlocks = yes;
                }
                else if (node->tag->model & CM_DEFLIST)
                {
                    UngetToken(lexer);
                    node = InferredTag(lexer, "dl");
                    lexer->excludeBlocks = yes;
                }

                /* infer end of current table cell */
                if (!(node->tag->model & CM_BLOCK))
                {
                    UngetToken(lexer);
                    TrimSpaces(lexer, element);
                    TrimEmptyElement(lexer, element);
                    return;
                }
            }
            else if (node->tag->model & CM_BLOCK)
            {
                if (lexer->excludeBlocks)
                {
                    if (!(element->tag->model & CM_OPT))
                        ReportWarning(lexer, element, node, MISSING_ENDTAG_BEFORE);

                    UngetToken(lexer);

                    if (element->tag->model & CM_OBJECT)
                        lexer->istackbase = istackbase;

                    TrimSpaces(lexer, element);
                    TrimEmptyElement(lexer, element);
                    return;
                }
            }
            else /* things like list items */
            {
                if (!(element->tag->model & CM_OPT) && !element->implicit)
                    ReportWarning(lexer, element, node, MISSING_ENDTAG_BEFORE);

                if (node->tag->model & CM_HEAD)
                {
                    MoveToHead(lexer, element, node);
                    continue;
                }

                UngetToken(lexer);

                if (node->tag->model & CM_LIST)
                {
                    if (element->parent && element->parent->tag &&
                        element->parent->tag->parser == ParseList)
                    {
                        TrimSpaces(lexer, element);
                        TrimEmptyElement(lexer, element);
                        return;
                    }

                    node = InferredTag(lexer, "ul");
                    AddClass(node, "noindent");
                }
                else if (node->tag->model & CM_DEFLIST)
                {
                    if (element->parent->tag == tag_dl)
                    {
                        TrimSpaces(lexer, element);
                        TrimEmptyElement(lexer, element);
                        return;
                    }

                    node = InferredTag(lexer, "dl");
                }
                else if (node->tag->model & CM_TABLE || node->tag->model & CM_ROW)
                {
                    node = InferredTag(lexer, "table");
                }
                else if (element->tag->model & CM_OBJECT)
                {
                    /* pop inline stack */
                    while (lexer->istacksize > lexer->istackbase)
                        PopInline(lexer, null);
                    lexer->istackbase = istackbase;
                    TrimSpaces(lexer, element);
                    TrimEmptyElement(lexer, element);
                    return;

                }
                else
                {
                    TrimSpaces(lexer, element);
                    TrimEmptyElement(lexer, element);
                    return;
                }
            }
        }

        /* parse known element */
        if (node->type == StartTag || node->type == StartEndTag)
        {
            if (node->tag->model & CM_INLINE)
            {
                if (checkstack && !node->implicit)
                {
                    checkstack = no;

                    if (InlineDup(lexer, node) > 0)
                        continue;
                }

                mode = MixedContent;
            }
            else
            {
                checkstack = yes;
                mode = IgnoreWhitespace;
            }

            /* trim white space before <br> */
            if (node->tag == tag_br)
                TrimSpaces(lexer, element);

            InsertNodeAtEnd(element, node);
            
            if (node->implicit)
                ReportWarning(lexer, element, node, INSERTING_TAG);

            ParseTag(lexer, node, IgnoreWhitespace /*MixedContent*/);
            continue;
        }

        /* discard unexpected tags */
        if (node->type == EndTag)
            PopInline(lexer, node);  /* if inline end tag */

        ReportWarning(lexer, element, node, DISCARDING_UNEXPECTED);
        FreeNode(node);
    }

    if (!(element->tag->model & CM_OPT))
        ReportWarning(lexer, element, node, MISSING_ENDTAG_FOR);

    if (element->tag->model & CM_OBJECT)
    {
        /* pop inline stack */
        while (lexer->istacksize > lexer->istackbase)
            PopInline(lexer, null);
        lexer->istackbase = istackbase;
    }

    TrimSpaces(lexer, element);
    TrimEmptyElement(lexer, element);
}

void ParseInline(Lexer *lexer, Node *element, uint mode)
{
    Node *node, *parent;

    if (element->tag->model & CM_EMPTY)
        return;

    if (element->tag == tag_a)
    {
        if (element->attributes == null)
        {
            ReportWarning(lexer, element->parent, element, DISCARDING_UNEXPECTED);
            DiscardElement(element);
            return;
        }
    }

    /*
     ParseInline is used for some block level elements like H1 to H6
     For such elements we need to insert inline emphasis tags currently
     on the inline stack. For Inline elements, we normally push them
     onto the inline stack provided they aren't implicit or OBJECT/APPLET.
     This test is carried out in PushInline and PopInline, see istack.c
     We don't push A or SPAN to replicate current browser behavior
    */
    if ((element->tag->model & CM_BLOCK) || (element->tag == tag_dt))
        InlineDup(lexer, null);
    else if (element->tag->model & CM_INLINE &&
                element->tag != tag_a && element->tag != tag_span)
        PushInline(lexer, element);

    if (element->tag == tag_nobr)
        lexer->badLayout |= USING_NOBR;
    else if (element->tag == tag_font)
        lexer->badLayout |= USING_FONT;

    /* Inline elements may or may not be within a preformatted element */
    if (mode != Preformatted)
        mode = MixedContent;

    while ((node = GetToken(lexer, mode)) != null)
    {
        /* end tag for current element */
        if (node->tag == element->tag && node->type == EndTag)
        {
            if (element->tag->model & CM_INLINE && element->tag != tag_a)
                PopInline(lexer, node);

            FreeNode(node);

            if (!(mode & Preformatted))
                TrimSpaces(lexer, element);

            /*
             if a font element wraps an anchor and nothing else
             then move the font element inside the anchor since
             otherwise it won't alter the anchor text color
            */
            if (element->tag == tag_font && element->content && element->content == element->last)
            {
                Node *child = element->content;

                if (child->tag == tag_a)
                {
                    child->parent = element->parent;
                    child->next = element->next;
                    child->prev = element->prev;

                    if (child->prev)
                        child->prev->next = child;
                    else
                        child->parent->content = child;

                    if (child->next)
                        child->next->prev = child;
                    else
                        child->parent->last = child;

                    element->next = null;
                    element->prev = null;
                    element->parent = child;
                    element->content = child->content;
                    element->last = child->last;
                    child->content = child->last = element;

                    for (child = element->content; child; child = child->next)
                        child->parent = element;
                }
            }

            element->closed = yes;
            TrimSpaces(lexer, element);
            TrimEmptyElement(lexer, element);
            return;
        }

        /* <u>...<u>  map 2nd <u> to </u> if 1st is explicit */
        /* otherwise emphasis nesting is probably unintentional */
        /* big and small have cumulative effect to leave them alone */
        if (node->type == StartTag
                && node->tag == element->tag
                && IsPushed(lexer, node)
                && !node->implicit
                && !element->implicit
                && node->tag && (node->tag->model & CM_INLINE)
                && node->tag != tag_a
                && node->tag != tag_font
                && node->tag != tag_big
                && node->tag != tag_small)
        {
            if (element->content != null && node->attributes == null)
            {
                ReportWarning(lexer, element, node, COERCE_TO_ENDTAG);
                node->type = EndTag;
                UngetToken(lexer);
                continue;
            }

            ReportWarning(lexer, element, node, NESTED_EMPHASIS);
        }

        if (node->type == TextNode)
        {
            /* only called for 1st child */
            if (element->content == null && !(mode & Preformatted))
                TrimSpaces(lexer, element);

            if (node->start >= node->end)
            {
                FreeNode(node);
                continue;
            }

            InsertNodeAtEnd(element, node);
            continue;
        }

        /* mixed content model so allow text */
        if (InsertMisc(element, node))
            continue;

        /* deal with HTML tags */
        if (node->tag == tag_html)
        {
            if (node->type == StartTag || node->type == StartEndTag)
            {
                ReportWarning(lexer, element, node, DISCARDING_UNEXPECTED);
                FreeNode(node);
                continue;
            }

            /* otherwise infer end of inline element */
            UngetToken(lexer);

            if (!(mode & Preformatted))
                TrimSpaces(lexer, element);

            TrimEmptyElement(lexer, element);
            return;
        }

        /* within <dt> or <pre> map <p> to <br> */
        if (node->tag == tag_p &&
              node->type == StartTag &&
              ((mode & Preformatted) ||
               element->tag == tag_dt ||
               DescendantOf(element, tag_dt)))
        {
            node->tag = tag_br;
            MemFree(node->element);
            node->element = wstrdup("br");
            TrimSpaces(lexer, element);
            InsertNodeAtEnd(element, node);
            continue;
        }

        /* ignore unknown and PARAM tags */
        if (node->tag == null || node->tag == tag_param)
        {
            ReportWarning(lexer, element, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        if (node->tag == tag_br && node->type == EndTag)
            node->type = StartTag;

        if (node->type == EndTag)
        {
           /* coerce </br> to <br> */
           if (node->tag == tag_br)
                node->type = StartTag;
           else if (node->tag == tag_p)
           {
               /* coerce unmatched </p> to <br><br> */
                if (!DescendantOf(element, tag_p))
                {
                    CoerceNode(lexer, node, tag_br);
                    TrimSpaces(lexer, element);
                    InsertNodeAtEnd(element, node);
                    node = InferredTag(lexer, "br");
                    continue;
                }
           }
           else if (node->tag->model & CM_INLINE
                        && node->tag != tag_a
                        && !(node->tag->model & CM_OBJECT)
                        && element->tag->model & CM_INLINE)
            {
                /* allow any inline end tag to end current element */
                PopInline(lexer, element);

                if (element->tag != tag_a)
                {
                    if (node->tag == tag_a && node->tag != element->tag)
                    {
                       ReportWarning(lexer, element, node, MISSING_ENDTAG_BEFORE);
                       UngetToken(lexer);
                    }
                    else
                    {
                        ReportWarning(lexer, element, node, NON_MATCHING_ENDTAG);
                        FreeNode(node);
                    }

                    if (!(mode & Preformatted))
                        TrimSpaces(lexer, element);

                    TrimEmptyElement(lexer, element);
                    return;
                }

                /* if parent is <a> then discard unexpected inline end tag */
                ReportWarning(lexer, element, node, DISCARDING_UNEXPECTED);
                FreeNode(node);
                continue;
            }  /* special case </tr> etc. for stuff moved in front of table */
            else if (lexer->exiled
                        && node->tag->model
                        && (node->tag->model & CM_TABLE))
            {
                UngetToken(lexer);
                TrimSpaces(lexer, element);
                TrimEmptyElement(lexer, element);
                return;
            }
        }

        /* allow any header tag to end current header */
        if (node->tag->model & CM_HEADING && element->tag->model & CM_HEADING)
        {

            if (node->tag == element->tag)
            {
                ReportWarning(lexer, element, node, NON_MATCHING_ENDTAG);
                FreeNode(node);
            }
            else
            {
                ReportWarning(lexer, element, node, MISSING_ENDTAG_BEFORE);
                UngetToken(lexer);
            }

            if (!(mode & Preformatted))
                TrimSpaces(lexer, element);

            TrimEmptyElement(lexer, element);
            return;
        }

        /*
           an <A> tag to ends any open <A> element
           but <A href=...> is mapped to </A><A href=...>
        */
        if (node->tag == tag_a && !node->implicit && IsPushed(lexer, node))
        {
         /* coerce <a> to </a> unless it has some attributes */
            if (node->attributes == null)
            {
                node->type = EndTag;
                ReportWarning(lexer, element, node, COERCE_TO_ENDTAG);
                PopInline(lexer, node);
                UngetToken(lexer);
                continue;
            }

            UngetToken(lexer);
            ReportWarning(lexer, element, node, MISSING_ENDTAG_BEFORE);
            PopInline(lexer, element);

            if (!(mode & Preformatted))
                TrimSpaces(lexer, element);

            TrimEmptyElement(lexer, element);
            return;
        }

        if (element->tag->model & CM_HEADING)
        {
            if (node->tag == tag_center || node->tag == tag_div)
            {
                if (node->type != StartTag && node->type != StartEndTag)
                {
                    ReportWarning(lexer, element, node, DISCARDING_UNEXPECTED);
                    FreeNode(node);
                    continue;
                }

                ReportWarning(lexer, element, node, TAG_NOT_ALLOWED_IN);

                /* insert center as parent if heading is empty */
                if (element->content == null)
                {
                    InsertNodeAsParent(element, node);
                    continue;
                }

                /* split heading and make center parent of 2nd part */
                InsertNodeAfterElement(element, node);

                if (!(mode & Preformatted))
                    TrimSpaces(lexer, element);

                element = CloneNode(lexer, element);
                InsertNodeAtEnd(node, element);
                continue;
            }

            if (node->tag == tag_hr)
            {
                if (node->type != StartTag && node->type != StartEndTag)
                {
                    ReportWarning(lexer, element, node, DISCARDING_UNEXPECTED);
                    FreeNode(node);
                    continue;
                }

                ReportWarning(lexer, element, node, TAG_NOT_ALLOWED_IN);

                /* insert hr before heading if heading is empty */
                if (element->content == null)
                {
                    InsertNodeBeforeElement(element, node);
                    continue;
                }

                /* split heading and insert hr before 2nd part */
                InsertNodeAfterElement(element, node);

                if (!(mode & Preformatted))
                    TrimSpaces(lexer, element);

                element = CloneNode(lexer, element);
                InsertNodeAfterElement(node, element);
                continue;
            }
        }

        if (element->tag == tag_dt)
        {
            if (node->tag == tag_hr)
            {
                Node *dd;

                if (node->type != StartTag && node->type != StartEndTag)
                {
                    ReportWarning(lexer, element, node, DISCARDING_UNEXPECTED);
                    FreeNode(node);
                    continue;
                }

                ReportWarning(lexer, element, node, TAG_NOT_ALLOWED_IN);
                dd = InferredTag(lexer, "dd");

                /* insert hr within dd before dt if dt is empty */
                if (element->content == null)
                {
                    InsertNodeBeforeElement(element, dd);
                    InsertNodeAtEnd(dd, node);
                    continue;
                }

                /* split dt and insert hr within dd before 2nd part */
                InsertNodeAfterElement(element, dd);
                InsertNodeAtEnd(dd, node);

                if (!(mode & Preformatted))
                    TrimSpaces(lexer, element);

                element = CloneNode(lexer, element);
                InsertNodeAfterElement(dd, element);
                continue;
            }
        }


        /* 
          if this is the end tag for an ancestor element
          then infer end tag for this element
        */
        if (node->type == EndTag)
        {
            for (parent = element->parent;
                    parent != null; parent = parent->parent)
            {
                if (node->tag == parent->tag)
                {
                    if (!(element->tag->model & CM_OPT) && !element->implicit)
                        ReportWarning(lexer, element, node, MISSING_ENDTAG_BEFORE);

                    if (element->tag == tag_a)
                        PopInline(lexer, element);

                    UngetToken(lexer);

                    if (!(mode & Preformatted))
                        TrimSpaces(lexer, element);

                    TrimEmptyElement(lexer, element);
                    return;
                }
            }
        }

        /* block level tags end this element */
        if (!(node->tag->model & CM_INLINE))
        {
            if (node->type != StartTag)
            {
                ReportWarning(lexer, element, node, DISCARDING_UNEXPECTED);
                continue;
            }

            if (!(element->tag->model & CM_OPT))
                ReportWarning(lexer, element, node, MISSING_ENDTAG_BEFORE);

            if (node->tag->model & CM_HEAD && !(node->tag->model & CM_BLOCK))
            {
                MoveToHead(lexer, element, node);
                continue;
            }

            /*
               prevent anchors from propagating into block tags
               except for headings h1 to h6
            */
            if (element->tag == tag_a)
            {
                if (node->tag && !(node->tag->model & CM_HEADING))
                    PopInline(lexer, element);
                else if (!(element->content))
                {
                    DiscardElement(element);
                    UngetToken(lexer);
                    return;
                }
            }

            UngetToken(lexer);

            if (!(mode & Preformatted))
                TrimSpaces(lexer, element);

            TrimEmptyElement(lexer, element);
            return;
        }

        /* parse inline element */
        if (node->type == StartTag || node->type == StartEndTag)
        {
            if (node->implicit)
                ReportWarning(lexer, element, node, INSERTING_TAG);

            /* trim white space before <br> */
            if (node->tag == tag_br)
                TrimSpaces(lexer, element);
            
            InsertNodeAtEnd(element, node);
            ParseTag(lexer, node, mode);
            continue;
        }

        /* discard unexpected tags */
        ReportWarning(lexer, element, node, DISCARDING_UNEXPECTED);
        FreeNode(node);
    }

    if (!(element->tag->model & CM_OPT))
        ReportWarning(lexer, element, node, MISSING_ENDTAG_FOR);

    TrimEmptyElement(lexer, element);
}

void ParseDefList(Lexer *lexer, Node *list, uint mode)
{
    Node *node, *parent;

    if (list->tag->model & CM_EMPTY)
        return;

    lexer->insert = null;  /* defer implicit inline start tags */

    while ((node = GetToken(lexer, IgnoreWhitespace)) != null)
    {
        if (node->tag == list->tag && node->type == EndTag)
        {
            FreeNode(node);
            list->closed = yes;
            TrimEmptyElement(lexer, list);
            return;
        }

        /* deal with comments etc. */
        if (InsertMisc(list, node))
            continue;

        if (node->type == TextNode)
        {
            UngetToken(lexer);
            node = InferredTag(lexer, "dt");
            ReportWarning(lexer, list, node, MISSING_STARTTAG);
        }

        if (node->tag == null)
        {
            ReportWarning(lexer, list, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        /* 
          if this is the end tag for an ancestor element
          then infer end tag for this element
        */
        if (node->type == EndTag)
        {
            if (node->tag == tag_form)
            {
                lexer->badForm = yes;
                ReportWarning(lexer, list, node, DISCARDING_UNEXPECTED);
                continue;
            }

            for (parent = list->parent;
                    parent != null; parent = parent->parent)
            {
                if (node->tag == parent->tag)
                {
                    ReportWarning(lexer, list, node, MISSING_ENDTAG_BEFORE);

                    UngetToken(lexer);
                    TrimEmptyElement(lexer, list);
                    return;
                }
            }
        }

        /* center in a dt or a dl breaks the dl list in two */
        if (node->tag == tag_center)
        {
            if (list->content)
                InsertNodeAfterElement(list, node);
            else /* trim empty dl list */
            {
                InsertNodeBeforeElement(list, node);
                DiscardElement(list);
            }

            /* and parse contents of center */
            ParseTag(lexer, node, mode);

            /* now create a new dl element */
            list = InferredTag(lexer, "dl");
            InsertNodeAfterElement(node, list);
            continue;
        }

        if (!(node->tag == tag_dt || node->tag == tag_dd))
        {
            UngetToken(lexer);

            if (!(node->tag->model & (CM_BLOCK | CM_INLINE)))
            {
                ReportWarning(lexer, list, node, TAG_NOT_ALLOWED_IN);
                TrimEmptyElement(lexer, list);
                return;
            }

            /* if DD appeared directly in BODY then exclude blocks */
            if (!(node->tag->model & CM_INLINE) && lexer->excludeBlocks)
            {
                TrimEmptyElement(lexer, list);
                return;
            }

            node = InferredTag(lexer, "dd");
            ReportWarning(lexer, list, node, MISSING_STARTTAG);
        }

        if (node->type == EndTag)
        {
            ReportWarning(lexer, list, node, DISCARDING_UNEXPECTED);
            continue;
        }
        
        /* node should be <DT> or <DD>*/
        InsertNodeAtEnd(list, node);
        ParseTag(lexer, node, IgnoreWhitespace);
    }

    ReportWarning(lexer, list, node, MISSING_ENDTAG_FOR);
    TrimEmptyElement(lexer, list);
}

void ParseList(Lexer *lexer, Node *list, uint mode)
{
    Node *node, *parent;

    if (list->tag->model & CM_EMPTY)
        return;

    lexer->insert = null;  /* defer implicit inline start tags */

    while ((node = GetToken(lexer, IgnoreWhitespace)) != null)
    {
        if (node->tag == list->tag && node->type == EndTag)
        {
            FreeNode(node);

            if (list->tag->model & CM_OBSOLETE)
                CoerceNode(lexer, list, tag_ul);

            list->closed = yes;
            TrimEmptyElement(lexer, list);
            return;
        }

        /* deal with comments etc. */
        if (InsertMisc(list, node))
            continue;

        if (node->type != TextNode && node->tag == null)
        {
            ReportWarning(lexer, list, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        /* 
          if this is the end tag for an ancestor element
          then infer end tag for this element
        */
        if (node->type == EndTag)
        {
            if (node->tag == tag_form)
            {
                lexer->badForm = yes;
                ReportWarning(lexer, list, node, DISCARDING_UNEXPECTED);
                continue;
            }

            if (node->tag && node->tag->model & CM_INLINE)
            {
                ReportWarning(lexer, list, node, DISCARDING_UNEXPECTED);
                PopInline(lexer, node);
                FreeNode(node);
                continue;
            }

            for (parent = list->parent;
                    parent != null; parent = parent->parent)
            {
                if (node->tag == parent->tag)
                {
                    ReportWarning(lexer, list, node, MISSING_ENDTAG_BEFORE);
                    UngetToken(lexer);

                    if (list->tag->model & CM_OBSOLETE)
                        CoerceNode(lexer, list, tag_ul);

                    TrimEmptyElement(lexer, list);
                    return;
                }
            }

            ReportWarning(lexer, list, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        if (node->tag != tag_li)
        {
            UngetToken(lexer);

            if (node->tag && (node->tag->model & CM_BLOCK) && lexer->excludeBlocks)
            {
                ReportWarning(lexer, list, node, MISSING_ENDTAG_BEFORE);
                TrimEmptyElement(lexer, list);
                return;
            }

            node = InferredTag(lexer, "li");
            AddAttribute(node, "style", "list-style: none");
            ReportWarning(lexer, list, node, MISSING_STARTTAG);
        }

        /* node should be <LI> */
        InsertNodeAtEnd(list,node);
        ParseTag(lexer, node, IgnoreWhitespace);
    }

    if (list->tag->model & CM_OBSOLETE)
        CoerceNode(lexer, list, tag_ul);

    ReportWarning(lexer, list, node, MISSING_ENDTAG_FOR);
    TrimEmptyElement(lexer, list);
}

/*
 unexpected content in table row is moved to just before
 the table in accordance with Netscape and IE. This code
 assumes that node hasn't been inserted into the row.
*/
static void MoveBeforeTable(Node *row, Node *node)
{
    Node *table;

    /* first find the table element */
    for (table = row->parent; table; table = table->parent)
    {
        if (table->tag == tag_table)
        {
            if (table->parent->content == table)
                table->parent->content = node;

            node->prev = table->prev;
            node->next = table;
            table->prev = node;
            node->parent = table->parent;
        
            if (node->prev)
                node->prev->next = node;

            break;
        }
    }
}

/*
 if a table row is empty then insert an empty cell
 this practice is consistent with browser behavior
 and avoids potential problems with row spanning cells
*/
static void FixEmptyRow(Lexer *lexer, Node *row)
{
    Node *cell;

    if (row->content == null)
    {
        cell = InferredTag(lexer, "td");
        InsertNodeAtEnd(row, cell);
        ReportWarning(lexer, row, cell, MISSING_STARTTAG);
    }
}

void ParseRow(Lexer *lexer, Node *row, uint mode)
{
    Node *node, *parent;
    Bool exclude_state;

    if (row->tag->model & CM_EMPTY)
        return;

    while ((node = GetToken(lexer, IgnoreWhitespace)) != null)
    {
        if (node->tag == row->tag)
        {
            if (node->type == EndTag)
            {
                FreeNode(node);
                row->closed = yes;
                FixEmptyRow(lexer, row);
                return;
            }

            UngetToken(lexer);
            FixEmptyRow(lexer, row);
            return;
        }

        /* 
          if this is the end tag for an ancestor element
          then infer end tag for this element
        */
        if (node->type == EndTag)
        {
            if (node->tag == tag_form)
            {
                lexer->badForm = yes;
                ReportWarning(lexer, row, node, DISCARDING_UNEXPECTED);
                continue;
            }

            if (node->tag == tag_td || node->tag == tag_th)
            {
                ReportWarning(lexer, row, node, DISCARDING_UNEXPECTED);
                FreeNode(node);
                continue;
            }

            for (parent = row->parent;
                    parent != null; parent = parent->parent)
            {
                if (node->tag == parent->tag)
                {
                    UngetToken(lexer);
                    TrimEmptyElement(lexer, row);
                    return;
                }
            }
        }

        /* deal with comments etc. */
        if (InsertMisc(row, node))
            continue;

        /* discard unknown tags */
        if (node->tag == null && node->type != TextNode)
        {
            ReportWarning(lexer, row, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        /* discard unexpected <table> element */
        if (node->tag == tag_table)
        {
            ReportWarning(lexer, row, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        /* THEAD, TFOOT or TBODY */
        if (node->tag && (node->tag->model & CM_ROWGRP))
        {
            UngetToken(lexer);
            TrimEmptyElement(lexer, row);
            return;
        }

        if (node->type == EndTag)
        {
            ReportWarning(lexer, row, node, DISCARDING_UNEXPECTED);
            continue;
        }

        /*
          if text or inline or block move before table
          if head content move to head
        */

        if (node->type != EndTag)
        {
            if (node->tag == tag_form)
            {
                UngetToken(lexer);
                node = InferredTag(lexer, "td");
                ReportWarning(lexer, row, node, MISSING_STARTTAG);
            }
            else if (node->type == TextNode
                    || (node->tag->model & (CM_BLOCK | CM_INLINE)))
            {
                MoveBeforeTable(row, node);
                ReportWarning(lexer, row, node, TAG_NOT_ALLOWED_IN);
                lexer->exiled = yes;

                if (node->type != TextNode)
                    ParseTag(lexer, node, IgnoreWhitespace);

                lexer->exiled = no;
                continue;
            }
            else if (node->tag->model & CM_HEAD)
            {
                ReportWarning(lexer, row, node, TAG_NOT_ALLOWED_IN);
                MoveToHead(lexer, row, node);
                continue;
            }
        }

        if (!(node->tag == tag_td || node->tag == tag_th))
        {
            ReportWarning(lexer, row, node, TAG_NOT_ALLOWED_IN);
            FreeNode(node);
            continue;
        }
        
        /* node should be <TD> or <TH> */
        InsertNodeAtEnd(row, node);
        exclude_state = lexer->excludeBlocks;
        lexer->excludeBlocks = no;
        ParseTag(lexer, node, IgnoreWhitespace);
        lexer->excludeBlocks = exclude_state;

        /* pop inline stack */

        while (lexer->istacksize > lexer->istackbase)
            PopInline(lexer, null);
    }

    TrimEmptyElement(lexer, row);
}

void ParseRowGroup(Lexer *lexer, Node *rowgroup, uint mode)
{
    Node *node, *parent;

    if (rowgroup->tag->model & CM_EMPTY)
        return;

    while ((node = GetToken(lexer, IgnoreWhitespace)) != null)
    {
        if (node->tag == rowgroup->tag)
        {
            if (node->type == EndTag)
            {
                rowgroup->closed = yes;
                TrimEmptyElement(lexer, rowgroup);
                FreeNode(node);
                return;
            }

            UngetToken(lexer);
            return;
        }

        /* if </table> infer end tag */
        if (node->tag == tag_table && node->type == EndTag)
        {
            UngetToken(lexer);
            TrimEmptyElement(lexer, rowgroup);
            return;
        }

        /* deal with comments etc. */
        if (InsertMisc(rowgroup, node))
            continue;

        /* discard unknown tags */
        if (node->tag == null && node->type != TextNode)
        {
            ReportWarning(lexer, rowgroup, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        /*
          if TD or TH then infer <TR>
          if text or inline or block move before table
          if head content move to head
        */

        if (node->type != EndTag)
        {
            if (node->tag == tag_td || node->tag == tag_th)
            {
                UngetToken(lexer);
                node = InferredTag(lexer, "tr");
                ReportWarning(lexer, rowgroup, node, MISSING_STARTTAG);
            }
            else if (node->type == TextNode
                    || (node->tag->model & (CM_BLOCK | CM_INLINE)))
            {
                MoveBeforeTable(rowgroup, node);
                ReportWarning(lexer, rowgroup, node, TAG_NOT_ALLOWED_IN);
                lexer->exiled = yes;

                if (node->type != TextNode)
                    ParseTag(lexer, node, IgnoreWhitespace);

                lexer->exiled = no;
                continue;
            }
            else if (node->tag->model & CM_HEAD)
            {
                ReportWarning(lexer, rowgroup, node, TAG_NOT_ALLOWED_IN);
                MoveToHead(lexer, rowgroup, node);
                continue;
            }
        }

        /* 
          if this is the end tag for ancestor element
          then infer end tag for this element
        */
        if (node->type == EndTag)
        {
            if (node->tag == tag_form)
            {
                lexer->badForm = yes;
                ReportWarning(lexer, rowgroup, node, DISCARDING_UNEXPECTED);
                continue;
            }

            if (node->tag == tag_tr || node->tag == tag_td || node->tag == tag_th)
            {
                ReportWarning(lexer, rowgroup, node, DISCARDING_UNEXPECTED);
                FreeNode(node);
                continue;
            }

            for (parent = rowgroup->parent;
                    parent != null; parent = parent->parent)
            {
                if (node->tag == parent->tag)
                {
                    UngetToken(lexer);
                    TrimEmptyElement(lexer, rowgroup);
                    return;
                }
            }
        }

        /*
          if THEAD, TFOOT or TBODY then implied end tag

        */
        if (node->tag->model & CM_ROWGRP)
        {
            if (node->type != EndTag)
                UngetToken(lexer);

            TrimEmptyElement(lexer, rowgroup);
            return;
        }

        if (node->type == EndTag)
        {
            ReportWarning(lexer, rowgroup, node, DISCARDING_UNEXPECTED);
            continue;
        }
        
        if (!(node->tag == tag_tr))
        {
            node = InferredTag(lexer, "tr");
            ReportWarning(lexer, rowgroup, node, MISSING_STARTTAG);
            UngetToken(lexer);
        }

       /* node should be <TR> */
        InsertNodeAtEnd(rowgroup, node);
        ParseTag(lexer, node, IgnoreWhitespace);
    }

    TrimEmptyElement(lexer, rowgroup);
}

void ParseColGroup(Lexer *lexer, Node *colgroup, uint mode)
{
    Node *node, *parent;

    if (colgroup->tag->model & CM_EMPTY)
        return;

    while ((node = GetToken(lexer, IgnoreWhitespace)) != null)
    {
        if (node->tag == colgroup->tag && node->type == EndTag)
        {
            FreeNode(node);
            colgroup->closed = yes;
            return;
        }

        /* 
          if this is the end tag for an ancestor element
          then infer end tag for this element
        */
        if (node->type == EndTag)
        {
            if (node->tag == tag_form)
            {
                lexer->badForm = yes;
                ReportWarning(lexer, colgroup, node, DISCARDING_UNEXPECTED);
                continue;
            }

            for (parent = colgroup->parent;
                    parent != null; parent = parent->parent)
            {

                if (node->tag == parent->tag)
                {
                    UngetToken(lexer);
                    return;
                }
            }
        }

        if (node->type == TextNode)
        {
            UngetToken(lexer);
            return;
        }

        /* deal with comments etc. */
        if (InsertMisc(colgroup, node))
            continue;

        /* discard unknown tags */
        if (node->tag == null)
        {
            ReportWarning(lexer, colgroup, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        if (node->tag != tag_col)
        {
            UngetToken(lexer);
            return;
        }

        if (node->type == EndTag)
        {
            ReportWarning(lexer, colgroup, node, DISCARDING_UNEXPECTED);
            continue;
        }
        
        /* node should be <COL> */
        InsertNodeAtEnd(colgroup, node);
        ParseTag(lexer, node, IgnoreWhitespace);
    }
}

void ParseTableTag(Lexer *lexer, Node *table, uint mode)
{
    Node *node, *parent;
    uint istackbase;

    DeferDup(lexer);
    istackbase = lexer->istackbase;
    lexer->istackbase = lexer->istacksize;
    
    while ((node = GetToken(lexer, IgnoreWhitespace)) != null)
    {
        if (node->tag == table->tag && node->type == EndTag)
        {
            FreeNode(node);
            lexer->istackbase = istackbase;
            table->closed = yes;
            TrimEmptyElement(lexer, table);
            return;
        }

        /* deal with comments etc. */
        if (InsertMisc(table, node))
            continue;

        /* discard unknown tags */
        if (node->tag == null && node->type != TextNode)
        {
            ReportWarning(lexer, table, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        /* if TD or TH or text or inline or block then infer <TR> */

        if (node->type != EndTag)
        {
            if (node->tag == tag_td || 
                node->tag == tag_th ||
                node->tag == tag_table)
            {
                UngetToken(lexer);
                node = InferredTag(lexer, "tr");
                ReportWarning(lexer, table, node, MISSING_STARTTAG);
            }
            else if (node->type == TextNode
                       || (node->tag->model & (CM_BLOCK | CM_INLINE)))
            {
                InsertNodeBeforeElement(table, node);
                ReportWarning(lexer, table, node, TAG_NOT_ALLOWED_IN);
                lexer->exiled = yes;

                if (!node->type == TextNode)
                    ParseTag(lexer, node, IgnoreWhitespace);

                lexer->exiled = no;
                continue;
            }
            else if (node->tag->model & CM_HEAD)
            {
                MoveToHead(lexer, table, node);
                continue;
            }
        }

        /* 
          if this is the end tag for an ancestor element
          then infer end tag for this element
        */
        if (node->type == EndTag)
        {
            if (node->tag == tag_form)
            {
                lexer->badForm = yes;
                ReportWarning(lexer, table, node, DISCARDING_UNEXPECTED);
                continue;
            }

            if (node->tag && node->tag->model & (CM_TABLE|CM_ROW))
            {
                ReportWarning(lexer, table, node, DISCARDING_UNEXPECTED);
                FreeNode(node);
                continue;
            }

            for (parent = table->parent;
                    parent != null; parent = parent->parent)
            {
                if (node->tag == parent->tag)
                {
                    ReportWarning(lexer, table, node, MISSING_ENDTAG_BEFORE);
                    UngetToken(lexer);
                    lexer->istackbase = istackbase;
                    TrimEmptyElement(lexer, table);
                    return;
                }
            }
        }

        if (!(node->tag->model & CM_TABLE))
        {
            UngetToken(lexer);
            ReportWarning(lexer, table, node, TAG_NOT_ALLOWED_IN);
            lexer->istackbase = istackbase;
            TrimEmptyElement(lexer, table);
            return;
        }

        if (node->type == StartTag || node->type == StartEndTag)
        {
            InsertNodeAtEnd(table, node);;
            ParseTag(lexer, node, IgnoreWhitespace);
            continue;
        }

        /* discard unexpected text nodes and end tags */
        ReportWarning(lexer, table, node, DISCARDING_UNEXPECTED);
        FreeNode(node);
    }

    ReportWarning(lexer, table, node, MISSING_ENDTAG_FOR);
    TrimEmptyElement(lexer, table);
    lexer->istackbase = istackbase;
}

void ParsePre(Lexer *lexer, Node *pre, uint mode)
{
    Node *node, *parent;

    if (pre->tag->model & CM_EMPTY)
        return;

    if (pre->tag->model & CM_OBSOLETE)
        CoerceNode(lexer, pre, tag_pre);

    InlineDup(lexer, null); /* tell lexer to insert inlines if needed */

    while ((node = GetToken(lexer, Preformatted)) != null)
    {
        if (node->tag == pre->tag && node->type == EndTag)
        {
            FreeNode(node);
            TrimSpaces(lexer, pre);
            pre->closed = yes;
            TrimEmptyElement(lexer, pre);
            return;
        }

        if (node->tag == tag_html)
        {
            if (node->type == StartTag || node->type == StartEndTag)
                ReportWarning(lexer, pre, node, DISCARDING_UNEXPECTED);

            FreeNode(node);
            continue;
        }

        if (node->type == TextNode)
        {
            /* if first check for inital newline */
            if (pre->content == null)
            {
                if (lexer->lexbuf[node->start] == '\n')
                    ++(node->start);

                if (node->start >= node->end)
                {
                    FreeNode(node);
                    continue;
                }
            }

            InsertNodeAtEnd(pre, node);
            continue;
        }

        /* deal with comments etc. */
        if (InsertMisc(pre, node))
            continue;

        /* discard unknown  and PARAM tags */
        if (node->tag == null || node->tag == tag_param)
        {
            ReportWarning(lexer, pre, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        if (node->tag == tag_p)
        {
            if (node->type == StartTag)
            {
                ReportWarning(lexer, pre, node, USING_BR_INPLACE_OF);

                /* trim white space before <p> in <pre>*/
                TrimSpaces(lexer, pre);
            
                /* coerce both <p> and </p> to <br> */
                CoerceNode(lexer, node, tag_br);
                InsertNodeAtEnd(pre, node);
            }
            else
            {
                ReportWarning(lexer, pre, node, DISCARDING_UNEXPECTED);
                FreeNode(node);
            }
            continue;
        }

        if (node->tag->model & CM_HEAD && !(node->tag->model & CM_BLOCK))
        {
            MoveToHead(lexer, pre, node);
            continue;
        }

        /* 
          if this is the end tag for an ancestor element
          then infer end tag for this element
        */
        if (node->type == EndTag)
        {
            if (node->tag == tag_form)
            {
                lexer->badForm = yes;
                ReportWarning(lexer, pre, node, DISCARDING_UNEXPECTED);
                continue;
            }

            for (parent = pre->parent;
                    parent != null; parent = parent->parent)
            {
                if (node->tag == parent->tag)
                {
                    ReportWarning(lexer, pre, node, MISSING_ENDTAG_BEFORE);

                    UngetToken(lexer);
                    TrimSpaces(lexer, pre);
                    TrimEmptyElement(lexer, pre);
                    return;
                }
            }
        }

        /* what about head content, HEAD, BODY tags etc? */
        if (!(node->tag->model & CM_INLINE))
        {
            if (node->type != StartTag)
            {
                ReportWarning(lexer, pre, node, DISCARDING_UNEXPECTED);
                continue;
            }
 
            ReportWarning(lexer, pre, node, MISSING_ENDTAG_BEFORE);
            lexer->excludeBlocks = yes;

            /* check if we need to infer a container */
            if (node->tag->model & CM_LIST)
            {
                UngetToken(lexer);
                node = InferredTag(lexer, "ul");
                AddClass(node, "noindent");
            }
            else if (node->tag->model & CM_DEFLIST)
            {
                UngetToken(lexer);
                node = InferredTag(lexer, "dl");
            }
            else if (node->tag->model & CM_TABLE)
            {
                UngetToken(lexer);
                node = InferredTag(lexer, "table");
            }

            InsertNodeAfterElement(pre, node);
            pre = InferredTag(lexer, "pre");
            InsertNodeAfterElement(node, pre);
            ParseTag(lexer, node, IgnoreWhitespace);
            lexer->excludeBlocks = no;
            continue;
        }
#if 0
        if (!(node->tag->model & CM_INLINE))
        {
            ReportWarning(lexer, pre, node, MISSING_ENDTAG_BEFORE);
            UngetToken(lexer);
            return;
        }
#endif
        if (node->type == StartTag || node->type == StartEndTag)
        {
            /* trim white space before <br> */
            if (node->tag == tag_br)
                TrimSpaces(lexer, pre);
            
            InsertNodeAtEnd(pre, node);
            ParseTag(lexer, node, Preformatted);
            continue;
        }

        /* discard unexpected tags */
        ReportWarning(lexer, pre, node, DISCARDING_UNEXPECTED);
        FreeNode(node);
    }

    ReportWarning(lexer, pre, node, MISSING_ENDTAG_FOR);
    TrimEmptyElement(lexer, pre);
}

void ParseOptGroup(Lexer *lexer, Node *field, uint mode)
{
    Node *node;

    lexer->insert = null;  /* defer implicit inline start tags */

    while ((node = GetToken(lexer, IgnoreWhitespace)) != null)
    {
        if (node->tag == field->tag && node->type == EndTag)
        {
            FreeNode(node);
            field->closed = yes;
            TrimSpaces(lexer, field);
            return;
        }

        /* deal with comments etc. */
        if (InsertMisc(field, node))
            continue;

        if (node->type == StartTag && 
             (node->tag == tag_option || node->tag == tag_optgroup))
        {
            if (node->tag == tag_optgroup)
                ReportWarning(lexer, field, node, CANT_BE_NESTED);

            InsertNodeAtEnd(field, node);
            ParseTag(lexer, node, MixedContent);
            continue;
        }

        /* discard unexpected tags */
        ReportWarning(lexer, field, node, DISCARDING_UNEXPECTED);
        FreeNode(node);
    }
}


void ParseSelect(Lexer *lexer, Node *field, uint mode)
{
    Node *node;

    lexer->insert = null;  /* defer implicit inline start tags */

    while ((node = GetToken(lexer, IgnoreWhitespace)) != null)
    {
        if (node->tag == field->tag && node->type == EndTag)
        {
            FreeNode(node);
            field->closed = yes;
            TrimSpaces(lexer, field);
            return;
        }

        /* deal with comments etc. */
        if (InsertMisc(field, node))
            continue;

        if (node->type == StartTag && 
             (node->tag == tag_option ||
               node->tag == tag_optgroup ||
               node->tag == tag_script))
        {
            InsertNodeAtEnd(field, node);
            ParseTag(lexer, node, IgnoreWhitespace);
            continue;
        }

        /* discard unexpected tags */
        ReportWarning(lexer, field, node, DISCARDING_UNEXPECTED);
        FreeNode(node);
    }

    ReportWarning(lexer, field, node, MISSING_ENDTAG_FOR);
}

void ParseText(Lexer *lexer, Node *field, uint mode)
{
    Node *node;

    lexer->insert = null;  /* defer implicit inline start tags */

    if (field->tag == tag_textarea)
        mode = Preformatted;

    while ((node = GetToken(lexer, mode)) != null)
    {
        if (node->tag == field->tag && node->type == EndTag)
        {
            FreeNode(node);
            field->closed = yes;
            TrimSpaces(lexer, field);
            return;
        }

        /* deal with comments etc. */
        if (InsertMisc(field, node))
            continue;

        if (node->type == TextNode)
        {
            /* only called for 1st child */
            if (field->content == null && !(mode & Preformatted))
                TrimSpaces(lexer, field);

            if (node->start >= node->end)
            {
                FreeNode(node);
                continue;
            }

            InsertNodeAtEnd(field, node);
            continue;
        }

        if (node->tag == tag_font)
        {
            ReportWarning(lexer, field, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        /* terminate element on other tags */
        if (!(field->tag->model & CM_OPT))
                ReportWarning(lexer, field, node, MISSING_ENDTAG_BEFORE);

        UngetToken(lexer);
        TrimSpaces(lexer, field);
        return;
    }

    if (!(field->tag->model & CM_OPT))
        ReportWarning(lexer, field, node, MISSING_ENDTAG_FOR);
}


void ParseTitle(Lexer *lexer, Node *title, uint mode)
{
    Node *node;

    while ((node = GetToken(lexer, MixedContent)) != null)
    {
        if (node->tag == title->tag && node->type == EndTag)
        {
            FreeNode(node);
            title->closed = yes;
            TrimSpaces(lexer, title);
            return;
        }

        if (node->type == TextNode)
        {
            /* only called for 1st child */
            if (title->content == null)
                TrimInitialSpace(lexer, title, node);

            if (node->start >= node->end)
            {
                FreeNode(node);
                continue;
            }

            InsertNodeAtEnd(title, node);
            continue;
        }

        /* deal with comments etc. */
        if (InsertMisc(title, node))
            continue;

        /* discard unknown tags */
        if (node->tag == null)
        {
            ReportWarning(lexer, title, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        /* pushback unexpected tokens */
        ReportWarning(lexer, title, node, MISSING_ENDTAG_BEFORE);
        UngetToken(lexer);
        TrimSpaces(lexer, title);
        return;
    }

    ReportWarning(lexer, title, node, MISSING_ENDTAG_FOR);
}

/*
  This isn't quite right for CDATA content as it recognises
  tags within the content and parses them accordingly.
  This will unfortunately screw up scripts which include
  < + letter,  < + !, < + ?  or  < + / + letter
*/

void ParseScript(Lexer *lexer, Node *script, uint mode)
{
    Node *node;

    node = GetCDATA(lexer, script);

    if (node)
        InsertNodeAtEnd(script, node);
}

Bool IsJavaScript(Node *node)
{
    Bool result = no;
    AttVal *attr;

    if (node->attributes == null)
        return yes;

    for (attr = node->attributes; attr; attr = attr->next)
    {
        if ( (wstrcasecmp(attr->attribute, "language") == 0
                || wstrcasecmp(attr->attribute, "type") == 0)
                && wsubstr(attr->value, "javascript"))
            result = yes;
    }

    return result;
}

void ParseHead(Lexer *lexer, Node *head, uint mode)
{
    Node *node;
    int HasTitle = 0;
    int HasBase = 0;

    while ((node = GetToken(lexer, IgnoreWhitespace)) != null)
    {
        if (node->tag == head->tag && node->type == EndTag)
        {
            FreeNode(node);
            head->closed = yes;
            break;
        }

        if (node->type == TextNode)
        {
            UngetToken(lexer);
            break;
        }

        /* deal with comments etc. */
        if (InsertMisc(head, node))
            continue;

        if (node->type == DocTypeTag)
        {
            InsertDocType(lexer, head, node);
            continue;
        }

        /* discard unknown tags */
        if (node->tag == null)
        {
            ReportWarning(lexer, head, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }
        
        if (!(node->tag->model & CM_HEAD))
        {
            UngetToken(lexer);
            break;
        }

        if (node->type == StartTag || node->type == StartEndTag)
        {
            if (node->tag == tag_title)
            {
                ++HasTitle;

                if (HasTitle > 1)
                    ReportWarning(lexer, head, node, TOO_MANY_ELEMENTS);
            }
            else if (node->tag == tag_base)
            {
                ++HasBase;

                if (HasBase > 1)
                    ReportWarning(lexer, head, node, TOO_MANY_ELEMENTS);
            }
            else if (node->tag == tag_noscript)
                ReportWarning(lexer, head, node, TAG_NOT_ALLOWED_IN);

            InsertNodeAtEnd(head, node);
            ParseTag(lexer, node, IgnoreWhitespace);
            continue;
        }

        /* discard unexpected text nodes and end tags */
        ReportWarning(lexer, head, node, DISCARDING_UNEXPECTED);
        FreeNode(node);
    }
  
    if (HasTitle == 0)
    {
        ReportWarning(lexer, head, null, MISSING_TITLE_ELEMENT);
        InsertNodeAtEnd(head, InferredTag(lexer, "title"));
    }
}

void ParseBody(Lexer *lexer, Node *body, uint mode)
{
    Node *node;
    Bool checkstack, iswhitenode;

    mode = IgnoreWhitespace;
    checkstack = yes;

    while ((node = GetToken(lexer, mode)) != null)
    {
        if (node->tag == body->tag && node->type == EndTag)
        {
            body->closed = yes;
            TrimSpaces(lexer, body);
            FreeNode(node);
            SeenBodyEndTag = 1;
            mode = IgnoreWhitespace;

            if (body->parent->tag == tag_noframes)
                break;

            continue;
        }

        if (node->tag == tag_noframes)
        {
            if (node->type == StartTag)
            {
                InsertNodeAtEnd(body, node);
                ParseBlock(lexer, node, mode);
                continue;
            }

            if (node->type == EndTag && body->parent->tag == tag_noframes)
            {
                TrimSpaces(lexer, body);
                UngetToken(lexer);
                break;
            }
        }

        if ((node->tag == tag_frame || node->tag == tag_frameset)
            && body->parent->tag == tag_noframes)
        {
            TrimSpaces(lexer, body);
            UngetToken(lexer);
            break;
        }
        
        if (node->tag == tag_html)
        {
            if (node->type == StartTag || node->type == StartEndTag)
                ReportWarning(lexer, body, node, DISCARDING_UNEXPECTED);

            FreeNode(node);
            continue;
        }

        iswhitenode = no;

        if (node->type == TextNode &&
               node->end <= node->start + 1 &&
               lexer->lexbuf[node->start] == ' ')
            iswhitenode = yes;

        /* deal with comments etc. */
        if (InsertMisc(body, node))
            continue;

        if (SeenBodyEndTag == 1 && !iswhitenode)
        {
            ++SeenBodyEndTag;
            ReportWarning(lexer, body, node, CONTENT_AFTER_BODY);
        }

        /* mixed content model permits text */
        if (node->type == TextNode)
        {
            if (iswhitenode && mode == IgnoreWhitespace)
            {
                FreeNode(node);
                continue;
            }

            if (EncloseBodyText && !iswhitenode)
            {
                Node *para;
                
                UngetToken(lexer);
                para = InferredTag(lexer, "p");
                InsertNodeAtEnd(body, para);
                ParseTag(lexer, para, mode);
                mode = MixedContent;
                continue;
            }
            else /* strict doesn't allow text here */
                lexer->versions &= ~(VERS_HTML40_STRICT | VERS_HTML20);


            if (checkstack)
            {
                checkstack = no;

                if (InlineDup(lexer, node) > 0)
                    continue;
            }

            InsertNodeAtEnd(body, node);
            mode = MixedContent;
            continue;
        }

        if (node->type == DocTypeTag)
        {
            InsertDocType(lexer, body, node);
            continue;
        }
        /* discard unknown  and PARAM tags */
        if (node->tag == null || node->tag == tag_param)
        {
            ReportWarning(lexer, body, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        /*
          Netscape allows LI and DD directly in BODY
          We infer UL or DL respectively and use this
          Bool to exclude block-level elements so as
          to match Netscape's observed behaviour.
        */
        lexer->excludeBlocks = no;
        
        if (!(node->tag->model & CM_BLOCK) &&
            !(node->tag->model & CM_INLINE))
        {
            /* avoid this error message being issued twice */
            if (!(node->tag->model & CM_HEAD))
                ReportWarning(lexer, body, node, TAG_NOT_ALLOWED_IN);

            if (node->tag->model & CM_HTML)
            {
                /* copy body attributes if current body was inferred */
                if (node->tag == tag_body && body->implicit 
                                    && body->attributes == null)
                {
                    body->attributes = node->attributes;
                    node->attributes = null;
                }

                FreeNode(node);
                continue;
            }

            if (node->tag->model & CM_HEAD)
            {
                MoveToHead(lexer, body, node);
                continue;
            }

            if (node->tag->model & CM_LIST)
            {
                UngetToken(lexer);
                node = InferredTag(lexer, "ul");
                AddClass(node, "noindent");
                lexer->excludeBlocks = yes;
            }
            else if (node->tag->model & CM_DEFLIST)
            {
                UngetToken(lexer);
                node = InferredTag(lexer, "dl");
                lexer->excludeBlocks = yes;
            }
            else if (node->tag->model & (CM_TABLE | CM_ROWGRP | CM_ROW))
            {
                UngetToken(lexer);
                node = InferredTag(lexer, "table");
                lexer->excludeBlocks = yes;
            }
            else
            {
                if (!(node->tag->model & (CM_ROW | CM_FIELD)))
                {
                    UngetToken(lexer);
                    return;
                }

                /* ignore </td> </th> <option> etc. */
                continue;
            }
        }

        if (node->type == EndTag)
        {
            if (node->tag == tag_br)
                node->type = StartTag;
            else if (node->tag == tag_p)
            {
                CoerceNode(lexer, node, tag_br);
                InsertNodeAtEnd(body, node);
                node = InferredTag(lexer, "br");
            }
            else if (node->tag->model & CM_INLINE)
                PopInline(lexer, node);
        }

        if (node->type == StartTag || node->type == StartEndTag)
        {
            if ((node->tag->model & CM_INLINE) && !(node->tag->model & CM_MIXED))
            {
                /* HTML4 strict doesn't allow inline content here */
                /* but HTML2 does allow img elements as children of body */
                if (node->tag == tag_img)
                    lexer->versions &= ~VERS_HTML40_STRICT;
                else
                    lexer->versions &= ~(VERS_HTML40_STRICT | VERS_HTML20);

                if (checkstack && !node->implicit)
                {
                    checkstack = no;

                    if (InlineDup(lexer, node) > 0)
                        continue;
                }

                mode = MixedContent;
            }
            else
            {
                checkstack = yes;
                mode = IgnoreWhitespace;
            }

            if (node->implicit)
                ReportWarning(lexer, body, node, INSERTING_TAG);

            InsertNodeAtEnd(body, node);
            ParseTag(lexer, node, mode);
            continue;
        }

        /* discard unexpected tags */
        ReportWarning(lexer, body, node, DISCARDING_UNEXPECTED);
        FreeNode(node);
    }
}

void ParseNoFrames(Lexer *lexer, Node *noframes, uint mode)
{
    Node *node;
    Bool checkstack;

    lexer->badAccess |=  USING_NOFRAMES;
    mode = IgnoreWhitespace;
    checkstack = yes;

    while ((node = GetToken(lexer, mode)) != null)
    {
        if (node->tag == noframes->tag && node->type == EndTag)
        {
            FreeNode(node);
            noframes->closed = yes;
            TrimSpaces(lexer, noframes);
            return;
        }

        if ((node->tag == tag_frame || node->tag == tag_frameset))
        {
            ReportWarning(lexer, noframes, node, MISSING_ENDTAG_BEFORE);
            TrimSpaces(lexer, noframes);
            UngetToken(lexer);
            return;
        }

        if (node->tag == tag_html)
        {
            if (node->type == StartTag || node->type == StartEndTag)
                ReportWarning(lexer, noframes, node, DISCARDING_UNEXPECTED);

            FreeNode(node);
            continue;
        }

        /* deal with comments etc. */
        if (InsertMisc(noframes, node))
            continue;

        if (node->tag == tag_body && node->type == StartTag)
        {
            InsertNodeAtEnd(noframes, node);
            ParseTag(lexer, node, IgnoreWhitespace /*MixedContent*/);
            continue;
        }

        /* implicit body element inferred */
        if (node->type == TextNode || node->tag)
        {
            UngetToken(lexer);
            node = InferredTag(lexer, "body");

            if (XmlOut)
                ReportWarning(lexer, noframes, node, INSERTING_TAG);

            InsertNodeAtEnd(noframes, node);
            ParseTag(lexer, node, IgnoreWhitespace /*MixedContent*/);
            continue;
        }

        /* discard unexpected end tags */
        ReportWarning(lexer, noframes, node, DISCARDING_UNEXPECTED);
        FreeNode(node);
    }

    ReportWarning(lexer, noframes, node, MISSING_ENDTAG_FOR);
}

void ParseFrameSet(Lexer *lexer, Node *frameset, uint mode)
{
    Node *node;

    lexer->badAccess |=  USING_FRAMES;

    while ((node = GetToken(lexer, IgnoreWhitespace)) != null)
    {
        if (node->tag == frameset->tag && node->type == EndTag)
        {
            FreeNode(node);
            frameset->closed = yes;
            TrimSpaces(lexer, frameset);
            return;
        }

        /* deal with comments etc. */
        if (InsertMisc(frameset, node))
            continue;

        if (node->tag == null)
        {
            ReportWarning(lexer, frameset, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue; 
        }

        if (node->type == StartTag || node->type == StartEndTag)
        {
            if (node->tag && node->tag->model & CM_HEAD)
            {
                MoveToHead(lexer, frameset, node);
                continue;
            }
        }

        if (node->tag == tag_body)
        {
            UngetToken(lexer);
            node = InferredTag(lexer, "noframes");
            ReportWarning(lexer, frameset, node, INSERTING_TAG);
        }

        if (node->type == StartTag && (node->tag->model & CM_FRAMES))
        {
            InsertNodeAtEnd(frameset, node);
            lexer->excludeBlocks = no;
            ParseTag(lexer, node, MixedContent);
            continue;
        }
        else if (node->type == StartEndTag && (node->tag->model & CM_FRAMES))
        {
            InsertNodeAtEnd(frameset, node);
            continue;
        }

        /* discard unexpected tags */
        ReportWarning(lexer, frameset, node, DISCARDING_UNEXPECTED);
        FreeNode(node);
    }

    ReportWarning(lexer, frameset, node, MISSING_ENDTAG_FOR);
}

void ParseHTML(Lexer *lexer, Node *html, uint mode)
{
    Node *node, *head;
    Node *frameset = null;
    Node *noframes = null;

    XmlTags = no;
    SeenBodyEndTag = 0;

    for (;;)
    {
        node = GetToken(lexer, IgnoreWhitespace);

        if (node == null)
        {
            node = InferredTag(lexer, "head");
            break;
        }

        if (node->tag == tag_head)
            break;

        if (node->tag == html->tag && node->type == EndTag)
        {
            ReportWarning(lexer, html, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        /* deal with comments etc. */
        if (InsertMisc(html, node))
            continue;

        UngetToken(lexer);
        node = InferredTag(lexer, "head");
        break;
    }

    head = node;
    InsertNodeAtEnd(html, head);
    ParseHead(lexer, head, mode);

    for (;;)
    {
        node = GetToken(lexer, IgnoreWhitespace);

        if (node == null)
        {
            if (frameset == null) /* create an empty body */
                node = InferredTag(lexer, "body");

            return;
        }

        /* robustly handle html tags */
        if (node->tag == html->tag)
        {
            if (node->type != StartTag && frameset == null)
                ReportWarning(lexer, html, node, DISCARDING_UNEXPECTED);

            FreeNode(node);
            continue;
        }

        /* deal with comments etc. */
        if (InsertMisc(html, node))
            continue;

        /* if frameset document coerce <body> to <noframes> */
        if (node->tag == tag_body)
        {
            if (node->type != StartTag)
            {
                ReportWarning(lexer, html, node, DISCARDING_UNEXPECTED);
                FreeNode(node);
                continue;
            }

            if (frameset != null)
            {
                UngetToken(lexer);

                if (noframes == null)
                {
                    noframes = InferredTag(lexer, "noframes");
                    InsertNodeAtEnd(frameset, noframes);
                    ReportWarning(lexer, html, noframes, INSERTING_TAG);
                }

                ParseTag(lexer, noframes, mode);
                continue;
            }

            break;  /* to parse body */
        }

        /* flag an error if we see more than one frameset */
        if (node->tag == tag_frameset)
        {
            if (node->type != StartTag)
            {
                ReportWarning(lexer, html, node, DISCARDING_UNEXPECTED);
                FreeNode(node);
                continue;
            }

            if (frameset != null)
                ReportError(lexer, html, node, DUPLICATE_FRAMESET);
            else
                frameset = node;

            InsertNodeAtEnd(html, node);
            ParseTag(lexer, node, mode);

            /*
              see if it includes a noframes element so
              that we can merge subsequent noframes elements
            */

            for (node = frameset->content; node; node = node->next)
            {
                if (node->tag == tag_noframes)
                    noframes = node;
            }
            continue;
        }

        /* if not a frameset document coerce <noframes> to <body> */
        if (node->tag == tag_noframes)
        {
            if (node->type != StartTag)
            {
                ReportWarning(lexer, html, node, DISCARDING_UNEXPECTED);
                FreeNode(node);
                continue;
            }

            if (frameset == null)
            {
                ReportWarning(lexer, html, node, DISCARDING_UNEXPECTED);
                FreeNode(node);
                node = InferredTag(lexer, "body");
                break;
            }

            if (noframes == null)
            {
                noframes = node;
                InsertNodeAtEnd(frameset, noframes);
            }
            else
                FreeNode(node);

            ParseTag(lexer, noframes, mode);
            continue;
        }

        if (node->type == StartTag || node->type == StartEndTag)
        {
            if (node->tag && node->tag->model & CM_HEAD)
            {
                MoveToHead(lexer, html, node);
                continue;
            }
        }

        UngetToken(lexer);

        /* insert other content into noframes element */

        if (frameset)
        {
            if (noframes == null)
            {
                noframes = InferredTag(lexer, "noframes");
                InsertNodeAtEnd(frameset, noframes);
            }
            else
                ReportWarning(lexer, html, node, NOFRAMES_CONTENT);

            ParseTag(lexer, noframes, mode);
            continue;
        }

        node = InferredTag(lexer, "body");
        break;
    }

    /* node must be body */

    InsertNodeAtEnd(html, node);
    ParseTag(lexer, node, mode);
}

/*
  HTML is the top level element
*/
Node *ParseDocument(Lexer *lexer)
{
    Node *node, *document, *html, *doctype = null;

    document = NewNode();
    document->type = RootNode;

    while ((node = GetToken(lexer, IgnoreWhitespace)) != null)
    {
        /* deal with comments etc. */
        if (InsertMisc(document, node))
            continue;

        if (node->type == DocTypeTag)
        {
            if (doctype == null)
            {
                InsertNodeAtEnd(document, node);
                doctype = node;
            }
            else
                ReportWarning(lexer, RootNode, node, DISCARDING_UNEXPECTED);
            continue;
        }

        if (node->type == EndTag)
        {
            ReportWarning(lexer, RootNode, node, DISCARDING_UNEXPECTED);
            FreeNode(node);
            continue;
        }

        if (node->type != StartTag || node->tag != tag_html)
        {
            UngetToken(lexer);
            html = InferredTag(lexer, "html");
        }
        else
            html = node;

        InsertNodeAtEnd(document, html);
        ParseHTML(lexer, html, no);
        break;
    }

    return document;
}

Bool XMLPreserveWhiteSpace(Node *element)
{
    AttVal *attribute;

    /* search attributes for xml:space */
    for (attribute = element->attributes; attribute; attribute = attribute->next)
    {
        if (wstrcmp(attribute->attribute, "xml:space") == 0)
        {
            if (wstrcmp(attribute->value, "preserve") == 0)
                return yes;

            return no;
        }
    }

    /* kludge for html docs without explicit xml:space attribute */
    if (wstrcasecmp(element->element, "pre") == 0
        || wstrcasecmp(element->element, "script") == 0
        || wstrcasecmp(element->element, "style") == 0
        || FindParser(element) == ParsePre)
        return yes;

    /* kludge for XSL docs */
    if (wstrcasecmp(element->element, "xsl:text") == 0)
        return yes;

    return no;
}

/*
  XML documents
*/
static void ParseXMLElement(Lexer *lexer, Node *element, uint mode)
{
    Node *node;

    /* Jeff Young's kludge for XSL docs */

    if (wstrcasecmp(element->element, "xsl:text") == 0)
        return;

    /* if node is pre or has xml:space="preserve" then do so */

    if (XMLPreserveWhiteSpace(element))
        mode = Preformatted;

    while ((node = GetToken(lexer, mode)) != null)
    {
        if (node->type == EndTag && wstrcmp(node->element, element->element) == 0)
        {
            FreeNode(node);
            element->closed = yes;
            break;
        }

        /* discard unexpected end tags */
        if (node->type == EndTag)
        {
            ReportError(lexer, element, node, UNEXPECTED_ENDTAG);
            FreeNode(node);
            continue;
        }

        /* parse content on seeing start tag */
        if (node->type == StartTag)
            ParseXMLElement(lexer, node, mode);

        InsertNodeAtEnd(element, node);
    }

    /*
     if first child is text then trim initial space and
     delete text node if it is empty.
    */

    node = element->content;

    if (node && node->type == TextNode && mode != Preformatted)
    {
        if (lexer->lexbuf[node->start] == ' ')
        {
            node->start++;

            if (node->start >= node->end)
                DiscardElement(node);
        }
    }

    /*
     if last child is text then trim final space and
     delete the text node if it is empty
    */

    node = element->last;

    if (node && node->type == TextNode && mode != Preformatted)
    {
        if (lexer->lexbuf[node->end - 1] == ' ')
        {
            node->end--;

            if (node->start >= node->end)
                DiscardElement(node);
        }
    }
}

Node *ParseXMLDocument(Lexer *lexer)
{
    Node *node, *document, *doctype;

    document = NewNode();
    document->type = RootNode;
    doctype = null;
    XmlTags = yes;

    while ((node = GetToken(lexer, IgnoreWhitespace)) != null)
    {
        /* discard unexpected end tags */
        if (node->type == EndTag)
        {
            ReportWarning(lexer, null, node, UNEXPECTED_ENDTAG);
            FreeNode(node);
            continue;
        }

         /* deal with comments etc. */
        if (InsertMisc(document, node))
            continue;

        if (node->type == DocTypeTag)
        {
            if (doctype == null)
            {
                InsertNodeAtEnd(document, node);
                doctype = node;
            }
            else
                ReportWarning(lexer, RootNode, node, DISCARDING_UNEXPECTED);
            continue;
        }

       /* if start tag then parse element's content */
        if (node->type == StartTag)
        {
            InsertNodeAtEnd(document, node);
            ParseXMLElement(lexer, node, IgnoreWhitespace);
        }

    }

#if 0
    /* discard the document type */
    node = FindDocType(document);

    if (node)
        DiscardElement(node);
#endif

    if  (doctype && !CheckDocTypeKeyWords(lexer, doctype))
            ReportWarning(lexer, doctype, null, DTYPE_NOT_UPPER_CASE);

    /* ensure presence of initial <?XML version="1.0"?> */
    if (XmlPi)
        FixXMLPI(lexer, document);

    return document;
}

