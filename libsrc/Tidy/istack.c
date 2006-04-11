/*
  ilstack.c - inline stack for compatibility with Mosaic

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

#include "platform.h"
#include "html.h"

extern Bool   debug_flag;
extern Node  *debug_element;
extern Lexer *debug_lexer;

/* duplicate attributes */
AttVal *DupAttrs(AttVal *attrs)
{
    AttVal *newattrs;

    if (attrs == null)
        return attrs;

    newattrs = NewAttribute();
    *newattrs = *attrs;
    newattrs->next = DupAttrs(attrs->next);
    newattrs->attribute = wstrdup(attrs->attribute);
    newattrs->value = wstrdup(attrs->value);
    newattrs->dict = FindAttribute(newattrs);
    return newattrs;
}

/*
  push a copy of an inline node onto stack
  but don't push if implicit or OBJECT or APPLET
  (implicit tags are ones generated from the istack)

  One issue arises with pushing inlines when
  the tag is already pushed. For instance:

      <p><em>text
      <p><em>more text

  Shouldn't be mapped to

      <p><em>text</em></p>
      <p><em><em>more text</em></em>
*/
void PushInline(Lexer *lexer, Node *node)
{
    IStack *istack;

    if (node->implicit)
        return;

    if (node->tag == null)
        return;

    if (!(node->tag->model & CM_INLINE))
        return;

    if (node->tag->model & CM_OBJECT)
        return;

    if (node->tag != tag_font && IsPushed(lexer, node))
        return;

    /* make sure there is enough space for the stack */
    if (lexer->istacksize + 1 > lexer->istacklength)
    {
        if (lexer->istacklength == 0)
            lexer->istacklength = 6;   /* this is perhaps excessive */

        lexer->istacklength = lexer->istacklength * 2;
        lexer->istack = (IStack *)MemRealloc(lexer->istack,
                            sizeof(IStack)*(lexer->istacklength));
    }

    istack = &(lexer->istack[lexer->istacksize]);
    istack->tag = node->tag;

    istack->element = wstrdup(node->element);
    istack->attributes = DupAttrs(node->attributes);
    ++(lexer->istacksize);
}

/* pop inline stack */
void PopInline(Lexer *lexer, Node *node)
{
    AttVal *av;
    IStack *istack;

    if (node)
    {
        if (node->tag == null)
            return;

        if (!(node->tag->model & CM_INLINE))
            return;

        if (node->tag->model & CM_OBJECT)
            return;

        /* if node is </a> then pop until we find an <a> */
        if (node->tag == tag_a)
        {
            while (lexer->istacksize > 0)
            {
                --(lexer->istacksize);
                istack = &(lexer->istack[lexer->istacksize]);

                while (istack->attributes)
                {
                    av = istack->attributes;

                    if (av->attribute)
                        MemFree(av->attribute);
                    if (av->value)
                        MemFree(av->value);

                    istack->attributes = av->next;
                    MemFree(av);
                }

                if (istack->tag == tag_a)
                {
                    MemFree(istack->element);
                    break;
                }

                MemFree(istack->element);
            }

            return;
        }
    }

    if (lexer->istacksize > 0)
    {
        --(lexer->istacksize);
        istack = &(lexer->istack[lexer->istacksize]);

        while (istack->attributes)
        {
            av = istack->attributes;

            if (av->attribute)
                MemFree(av->attribute);
            if (av->value)
                MemFree(av->value);

            istack->attributes = av->next;
            MemFree(av);
        }

        MemFree(istack->element);
    }
}

Bool IsPushed(Lexer *lexer, Node *node)
{
    int i;

    for (i = lexer->istacksize - 1; i >= 0; --i)
    {
        if (lexer->istack[i].tag == node->tag)
            return yes;
    }

    return no;
}

/*
  This has the effect of inserting "missing" inline
  elements around the contents of blocklevel elements
  such as P, TD, TH, DIV, PRE etc. This procedure is
  called at the start of ParseBlock. when the inline
  stack is not empty, as will be the case in:

    <i><h1>italic heading</h1></i>

  which is then treated as equivalent to

    <h1><i>italic heading</i></h1>

  This is implemented by setting the lexer into a mode
  where it gets tokens from the inline stack rather than
  from the input stream.
*/
int InlineDup(Lexer *lexer, Node *node)
{
    int n;

    if ((n = lexer->istacksize - lexer->istackbase) > 0)
    {
        lexer->insert = &(lexer->istack[lexer->istackbase]);
        lexer->inode = node;
    }

    return n;
}

/*
 defer duplicates when entering a table or other
 element where the inlines shouldn't be duplicated
*/
void DeferDup(Lexer *lexer)
{
    lexer->insert = null;
    lexer->inode = null;
}

Node *InsertedToken(Lexer *lexer)
{
    Node *node;
    IStack *istack;
    uint n;

    /* this will only be null if inode != null */
    if (lexer->insert == null)
    {
        node = lexer->inode;
        lexer->inode = null;
        return node;
    }

    /*
    
      is this is the "latest" node then update
      the position, otherwise use current values
    */

    if (lexer->inode == null)
    {
        lexer->lines = lexer->in->curline;
        lexer->columns = lexer->in->curcol;
    }

    node = NewNode();
    node->type = StartTag;
    node->implicit = yes;
    node->start = lexer->txtstart;
    node->end = lexer->txtstart;
    istack = lexer->insert;
    node->element = wstrdup(istack->element);
    node->tag = istack->tag;
    node->attributes = DupAttrs(istack->attributes);

    /* advance lexer to next item on the stack */
    n = lexer->insert - &(lexer->istack[0]);

    /* and recover state if we have reached the end */
    if (++n < lexer->istacksize)
        lexer->insert = &(lexer->istack[n]);
    else
        lexer->insert = null;

    return node;
}




