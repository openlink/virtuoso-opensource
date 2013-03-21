/*
 *  $Id$
 *
 *  localize.c
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
  You should only need to edit this file and tidy.c
  to localize HTML tidy.
*/

#include "platform.h"
#include "html.h"

/* used to point to Web Accessibility Guidelines */
#define ACCESS_URL  "http://www.w3.org/WAI/GL"

char *release_date = "4th August 2000";

#ifndef BIF_TIDY
static char *currentFile; /* sasdjb 01May00 for GNU Emacs error parsing */
#endif

extern uint optionerrors;

#ifdef BIF_TIDY
void tidy_out_tio(tidy_io_t *tio, int maxlength, const char* msg, ...)
{
    va_list args;
    int newlen;
    int vsprintf_len;
    maxlength += 0x100;
    newlen = tio->tio_pos+maxlength;
    if (newlen > 20000000)
      return;
    if (newlen >= tio->tio_data.lm_length)
      {
	caddr_t new_buf;
	newlen *= 2;
        new_buf = dk_alloc (newlen);
	if (0 != tio->tio_pos)
	  memcpy (new_buf, tio->tio_data.lm_memblock, tio->tio_pos);
        if (NULL != tio->tio_data.lm_memblock)
	  dk_free (tio->tio_data.lm_memblock, tio->tio_data.lm_length);
        tio->tio_data.lm_memblock = new_buf;
        tio->tio_data.lm_length = newlen;
      }
    va_start(args, msg);
    vsprintf_len = vsprintf (tio->tio_data.lm_memblock + tio->tio_pos, msg, args);
    va_end(args);
    if (vsprintf_len > 0)
      {
#ifdef DEBUG
	if (vsprintf_len > maxlength)
	  GPF_T;
#endif
        tio->tio_pos += vsprintf_len;
	tio->tio_data.lm_memblock[tio->tio_pos] = '\0';
      }
}
#else
/*
 This routine is the single point via which
 all output is written and as such is a good
 way to interface Tidy to other code when
 embedding Tidy in a GUI application.
*/
void tidy_out_file(FILE *fp, int maxlength, const char* msg, ...)
{
    va_list args;
    va_start(args, msg);
    vfprintf(fp, msg, args);
    va_end(args);
}
#endif

void ReadingFromStdin(void)
{
    fprintf(stderr, "Reading markup from standard input ...\n");
}

#ifndef BIF_TIDY
void ShowVersion(FILE *fp)
{
    tidy_out(fp, 0, "HTML Tidy release date: %s\n"
            "See http://www.w3.org/People/Raggett for details\n", release_date);
}
#endif

#ifdef BIF_TIDY
/* Bif have no file i/o, and no such errors */
#else
void FileError(FILE *fp, const char *file)
{
    tidy_out(fp, strlen(file), "Can't open \"%s\"\n", file);
}
#endif

static void ReportTag(Lexer *lexer, Node *tag)
{
    if (tag)
    {
        if (tag->type == StartTag)
            tidy_out(lexer->errout, strlen(tag->element), "<%s>", tag->element);
        else if (tag->type == EndTag)
            tidy_out(lexer->errout, strlen(tag->element), "</%s>", tag->element);
        else if (tag->type == DocTypeTag)
            tidy_out(lexer->errout, 0, "<!DOCTYPE>");
        else if (tag->type == TextNode)
            tidy_out(lexer->errout, 0, "plain text");
        else
            tidy_out(lexer->errout, strlen(tag->element), "%s", tag->element);
    }
}

/* lexer is not defined when this is called */
void ReportUnknownOption(char *option)
{
    optionerrors++;
    fprintf(stderr, "Warning - unknown option: %s\n", option);
}

/* lexer is not defined when this is called */
void ReportBadArgument(char *option)
{
    optionerrors++;
    fprintf(stderr, "Warning - missing or malformed argument for option: %s\n", option);
}

static void NtoS(int n, char *str)
{
    char buf[40];
    int i;

    for (i = 0;; ++i)
    {
        buf[i] = (n % 10) + '0';

        n = n /10;

        if (n == 0)
            break;
    }

    n = i;

    while (i >= 0)
    {
        str[n-i] = buf[i];
        --i;
    }

    str[n+1] = '\0';
}

static void ReportPosition(Lexer *lexer)
{
    /* Change formatting to be parsable by GNU Emacs */
    if (Emacs)
    {
#ifndef BIF_TIDY
        tidy_out(lexer->errout, strlen(currentFile), "%s", currentFile);
#endif
        tidy_out(lexer->errout, 0, ":%d:", lexer->lines);
        tidy_out(lexer->errout, 0, "%d: ", lexer->columns);
    }
    else /* traditional format */
    {
        tidy_out(lexer->errout, 0, "line %d", lexer->lines);
        tidy_out(lexer->errout, 0, " column %d - ", lexer->columns);
    }
}

void ReportEncodingError(Lexer *lexer, uint code, uint c)
{
    char buf[32];

    lexer->warnings++;

    if (ShowWarnings)
    {
        ReportPosition(lexer);

        if (code == WINDOWS_CHARS)
        {
            NtoS(c, buf);
            lexer->badChars |= WINDOWS_CHARS;
            tidy_out(lexer->errout, strlen(buf), "Warning: replacing illegal character code %s", buf);
        }

        tidy_out(lexer->errout, 0, "\n");
    }
}

void ReportEntityError(Lexer *lexer, uint code, char *entity, int c)
{
    lexer->warnings++;

    if (ShowWarnings)
    {
        ReportPosition(lexer);

        if (code == MISSING_SEMICOLON)
        {
            tidy_out(lexer->errout, strlen(entity), "Warning: entity \"%s\" doesn't end in ';'", entity);
        }
        else if (code == UNKNOWN_ENTITY)
        {
            tidy_out(lexer->errout, strlen(entity), "Warning: unescaped & or unknown entity \"%s\"", entity);
        }
        else if (code == UNESCAPED_AMPERSAND)
        {
            tidy_out(lexer->errout, 0, "Warning: unescaped & which should be written as &amp;");
        }

        tidy_out(lexer->errout, 0, "\n");
    }
}

void ReportAttrError(Lexer *lexer, Node *node, char *attr, uint code)
{
    lexer->warnings++;

    /* keep quiet after 6 errors */
    if (lexer->errors > 6)
        return;

    if (NULL == attr)
      attr = "";

    if (ShowWarnings)
    {
        /* on end of file adjust reported position to end of input */
        if (code == UNEXPECTED_END_OF_FILE)
        {
            lexer->lines = lexer->in->curline;
            lexer->columns = lexer->in->curcol;
        }

        ReportPosition(lexer);

        if (code == UNKNOWN_ATTRIBUTE)
            tidy_out(lexer->errout, strlen(attr), "Warning: unknown attribute \"%s\"", attr);
        else if (code == MISSING_ATTRIBUTE)
        {
            tidy_out(lexer->errout, 0, "Warning: ");
            ReportTag(lexer, node);
            tidy_out(lexer->errout, strlen(attr), " lacks \"%s\" attribute", attr);
        }
        else if (code == MISSING_ATTR_VALUE)
        {
            tidy_out(lexer->errout, 0, "Warning: ");
            ReportTag(lexer, node);
            tidy_out(lexer->errout, strlen(attr), " attribute \"%s\" lacks value", attr);
        }
        else if (code == MISSING_IMAGEMAP)
        {
            tidy_out(lexer->errout, 0, "Warning: ");
            ReportTag(lexer, node);
            tidy_out(lexer->errout, 0, " should use client-side image map");
            lexer->badAccess |= MISSING_IMAGE_MAP;
        }
        else if (code == BAD_ATTRIBUTE_VALUE)
        {
            tidy_out(lexer->errout, 0, "Warning: ");
            ReportTag(lexer, node);
            tidy_out(lexer->errout, strlen(attr), " unknown attribute value \"%s\"", attr);
        }
        else if (code == XML_ATTRIBUTE_VALUE)
        {
            tidy_out(lexer->errout, 0, "Warning: ");
            ReportTag(lexer, node);
            tidy_out(lexer->errout, strlen(attr), " has XML attribute \"%s\"", attr);
        }
        else if (code == UNEXPECTED_GT)
        {
            tidy_out(lexer->errout, 0, "Error: ");
            ReportTag(lexer, node);
            tidy_out(lexer->errout, 0, " missing '>' for end of tag");
            lexer->errors++;;
        }
        else if (code == UNEXPECTED_QUOTEMARK)
        {
            tidy_out(lexer->errout, 0, "Warning: ");
            ReportTag(lexer, node);
            tidy_out(lexer->errout, 0, " unexpected or duplicate quote mark");
        }
        else if (code == REPEATED_ATTRIBUTE)
        {
            tidy_out(lexer->errout, 0, "Warning: ");
            ReportTag(lexer, node);
            tidy_out(lexer->errout, strlen(attr), " repeated attribute \"%s\"", attr);
        }
        else if (code == PROPRIETARY_ATTR_VALUE)
        {
            tidy_out(lexer->errout, 0, "Warning: ");
            ReportTag(lexer, node);
            tidy_out(lexer->errout, strlen(attr), " proprietary attribute value \"%s\"", attr);
        }
        else if (code == UNEXPECTED_END_OF_FILE)
        {
            tidy_out(lexer->errout, 0, "Warning: end of file while parsing attributes");
        }
        else if (code == ID_NAME_MISMATCH)
        {
            tidy_out(lexer->errout, 0, "Warning: ");
            ReportTag(lexer, node);
            tidy_out(lexer->errout, 0, " id and name attribute value mismatch");
        }

        tidy_out(lexer->errout, 0, "\n");
    }
    else if (code == UNEXPECTED_GT)
    {
        ReportPosition(lexer);
        tidy_out(lexer->errout, 0, "Error: ");
        ReportTag(lexer, node);
        tidy_out(lexer->errout, 0, " missing '>' for end of tag\n");
        lexer->errors++;;
    }
}

void ReportWarning(Lexer *lexer, Node *element, Node *node, uint code)
{
    lexer->warnings++;

    /* keep quiet after 6 errors */
    if (lexer->errors > 6)
        return;

    if (ShowWarnings)
    {
        /* on end of file adjust reported position to end of input */
        if (code == UNEXPECTED_END_OF_FILE)
        {
            lexer->lines = lexer->in->curline;
            lexer->columns = lexer->in->curcol;
        }

        ReportPosition(lexer);

        if (code == MISSING_ENDTAG_FOR)
            tidy_out(lexer->errout, strlen(element->element), "Warning: missing </%s>", element->element);
        else if (code == MISSING_ENDTAG_BEFORE)
        {
            tidy_out(lexer->errout, strlen(element->element), "Warning: missing </%s> before ", element->element);
            ReportTag(lexer, node);
        }
        else if (code == DISCARDING_UNEXPECTED)
        {
            tidy_out(lexer->errout, 0, "Warning: discarding unexpected ");
            ReportTag(lexer, node);
        }
        else if (code == NESTED_EMPHASIS)
        {
            tidy_out(lexer->errout, 0, "Warning: nested emphasis ");
            ReportTag(lexer, node);
        }
        else if (code == COERCE_TO_ENDTAG)
        {
            tidy_out(lexer->errout, 2 * strlen(node->element), "Warning: <%s> is probably intended as </%s>",
                node->element, node->element);
        }
        else if (code == NON_MATCHING_ENDTAG)
        {
            tidy_out(lexer->errout, 0, "Warning: replacing unexpected ");
            ReportTag(lexer, node);
            tidy_out(lexer->errout, strlen(element->element), " by </%s>", element->element);
        }
        else if (code == TAG_NOT_ALLOWED_IN)
        {
            tidy_out(lexer->errout, 0, "Warning: ");
            ReportTag(lexer, node);
            tidy_out(lexer->errout, strlen(element->element), " isn't allowed in <%s> elements", element->element);
        }
        else if (code == DOCTYPE_AFTER_TAGS)
        {
            tidy_out(lexer->errout, 0, "Warning: <!DOCTYPE> isn't allowed after elements");
        }
        else if (code == MISSING_STARTTAG)
            tidy_out(lexer->errout, strlen(node->element), "Warning: missing <%s>", node->element);
        else if (code == UNEXPECTED_ENDTAG)
        {
            tidy_out(lexer->errout, strlen(node->element), "Warning: unexpected </%s>", node->element);

            if (element)
                tidy_out(lexer->errout, strlen(element->element), " in <%s>", element->element);
        }
        else if (code == TOO_MANY_ELEMENTS)
        {
            tidy_out(lexer->errout, strlen(node->element), "Warning: too many %s elements", node->element);

            if (element)
                tidy_out(lexer->errout, strlen(element->element), " in <%s>", element->element);
        }
        else if (code == USING_BR_INPLACE_OF)
        {
            tidy_out(lexer->errout, 0, "Warning: using <br> in place of ");
            ReportTag(lexer, node);
        }
        else if (code == INSERTING_TAG)
            tidy_out(lexer->errout, strlen(node->element), "Warning: inserting implicit <%s>", node->element);
        else if (code == CANT_BE_NESTED)
        {
            tidy_out(lexer->errout, 0, "Warning: ");
            ReportTag(lexer, node);
            tidy_out(lexer->errout, 0, " can't be nested");
        }
        else if (code == PROPRIETARY_ELEMENT)
        {
            tidy_out(lexer->errout, 0, "Warning: ");
            ReportTag(lexer, node);
            tidy_out(lexer->errout, 0, " is not approved by W3C");

            if (node->tag == tag_layer)
                lexer->badLayout |= USING_LAYER;
            else if (node->tag == tag_spacer)
                lexer->badLayout |= USING_SPACER;
            else if (node->tag == tag_nobr)
                lexer->badLayout |= USING_NOBR;
        }
        else if (code == OBSOLETE_ELEMENT)
        {
            if (element->tag && (element->tag->model & CM_OBSOLETE))
                tidy_out(lexer->errout, 0, "Warning: replacing obsolete element ");
            else
                tidy_out(lexer->errout, 0, "Warning: replacing element ");

            ReportTag(lexer, element);
            tidy_out(lexer->errout, 0, " by ");
            ReportTag(lexer, node);
        }
        else if (code == TRIM_EMPTY_ELEMENT)
        {
            tidy_out(lexer->errout, 0, "Warning: trimming empty ");
            ReportTag(lexer, element);
        }
        else if (code == MISSING_TITLE_ELEMENT)
            tidy_out(lexer->errout, 0, "Warning: inserting missing 'title' element");
        else if (code == ILLEGAL_NESTING)
        {
            tidy_out(lexer->errout, 0, "Warning: ");
            ReportTag(lexer, element);
            tidy_out(lexer->errout, 0, " shouldn't be nested");
        }
        else if (code == NOFRAMES_CONTENT)
        {
            tidy_out(lexer->errout, 0, "Warning: ");
            ReportTag(lexer, node);
            tidy_out(lexer->errout, 0, " not inside 'noframes' element");
        }
        else if (code == INCONSISTENT_VERSION)
        {
            tidy_out(lexer->errout, 0, "Warning: html doctype doesn't match content");
        }
        else if (code == MALFORMED_DOCTYPE)
        {
            tidy_out(lexer->errout, 0, "Warning: expected \"html PUBLIC\" or \"html SYSTEM\"");
        }
        else if (code == CONTENT_AFTER_BODY)
        {
            tidy_out(lexer->errout, 0, "Warning: content occurs after end of body");
        }
        else if (code == MALFORMED_COMMENT)
        {
            tidy_out(lexer->errout, 0, "Warning: adjacent hyphens within comment");
        }
        else if (code == BAD_COMMENT_CHARS)
        {
            tidy_out(lexer->errout, 0, "Warning: expecting -- or >");
        }
        else if (code == BAD_XML_COMMENT)
        {
            tidy_out(lexer->errout, 0, "Warning: XML comments can't contain --");
        }
        else if (code == BAD_CDATA_CONTENT)
        {
            tidy_out(lexer->errout, 0, "Warning: '<' + '/' + letter not allowed here");
        }
        else if (code == INCONSISTENT_NAMESPACE)
        {
            tidy_out(lexer->errout, 0, "Warning: html namespace doesn't match content");
        }
        else if (code == DTYPE_NOT_UPPER_CASE)
        {
            tidy_out(lexer->errout, 0, "Warning: SYSTEM, PUBLIC, W3C, DTD, EN must be upper case");
        }
        else if (code == UNEXPECTED_END_OF_FILE)
        {
            tidy_out(lexer->errout, 0, "Warning: unexpected end of file");
            ReportTag(lexer, element);
        }

        tidy_out(lexer->errout, 0, "\n");
    }
}

void ReportError(Lexer *lexer, Node *element, Node *node, uint code)
{
    lexer->warnings++;

    /* keep quiet after 6 errors */
    if (lexer->errors > 6)
        return;

    lexer->errors++;

    ReportPosition(lexer);

    if (code == SUSPECTED_MISSING_QUOTE)
    {
        tidy_out(lexer->errout, 0, "Error: missing quotemark for attribute value");
    }
    else if (code == DUPLICATE_FRAMESET)
    {
        tidy_out(lexer->errout, 0, "Error: repeated FRAMESET element");
    }
    else if (code == UNKNOWN_ELEMENT)
    {
        tidy_out(lexer->errout, 0, "Error: ");
        ReportTag(lexer, node);
        tidy_out(lexer->errout, 0, " is not recognized!");
    }
    else if (code == UNEXPECTED_ENDTAG)  /* generated by XML docs */
    {
        tidy_out(lexer->errout, strlen(node->element), "Warning: unexpected </%s>", node->element);

        if (element)
            tidy_out(lexer->errout, strlen(element->element), " in <%s>", element->element);
    }

    tidy_out(lexer->errout, 0, "\n");
}

void ErrorSummary(Lexer *lexer)
{
    /* adjust badAccess to that its null if frames are ok */
    if (lexer->badAccess & (USING_FRAMES | USING_NOFRAMES))
    {
        if (!((lexer->badAccess & USING_FRAMES) && !(lexer->badAccess & USING_NOFRAMES)))
            lexer->badAccess &= ~(USING_FRAMES | USING_NOFRAMES);
    }

    if (lexer->badChars)
    {
        if (lexer->badChars & WINDOWS_CHARS)
        {
            tidy_out(lexer->errout, 0, "Characters codes for the Microsoft Windows fonts in the range\n");
            tidy_out(lexer->errout, 0, "128 - 159 may not be recognized on other platforms. You are\n");
            tidy_out(lexer->errout, 0, "instead recommended to use named entities, e.g. &trade; rather\n");
            tidy_out(lexer->errout, 0, "than Windows character code 153 (0x2122 in Unicode). Note that\n");
            tidy_out(lexer->errout, 0, "as of February 1998 few browsers support the new entities.\n\n");
        }
    }

    if (lexer->badForm)
    {
        tidy_out(lexer->errout, 0, "You may need to move one or both of the <form> and </form>\n");
        tidy_out(lexer->errout, 0, "tags. HTML elements should be properly nested and form elements\n");
        tidy_out(lexer->errout, 0, "are no exception. For instance you should not place the <form>\n");
        tidy_out(lexer->errout, 0, "in one table cell and the </form> in another. If the <form> is\n");
        tidy_out(lexer->errout, 0, "placed before a table, the </form> cannot be placed inside the\n");
        tidy_out(lexer->errout, 0, "table! Note that one form can't be nested inside another!\n\n");
    }

    if (lexer->badAccess)
    {
        if (lexer->badAccess & MISSING_SUMMARY)
        {
            tidy_out(lexer->errout, 0, "The table summary attribute should be used to describe\n");
            tidy_out(lexer->errout, 0, "the table structure. It is very helpful for people using\n");
            tidy_out(lexer->errout, 0, "non-visual browsers. The scope and headers attributes for\n");
            tidy_out(lexer->errout, 0, "table cells are useful for specifying which headers apply\n");
            tidy_out(lexer->errout, 0, "to each table cell, enabling non-visual browsers to provide\n");
            tidy_out(lexer->errout, 0, "a meaningful context for each cell.\n\n");
        }

        if (lexer->badAccess & MISSING_IMAGE_ALT)
        {
            tidy_out(lexer->errout, 0, "The alt attribute should be used to give a short description\n");
            tidy_out(lexer->errout, 0, "of an image; longer descriptions should be given with the\n");
            tidy_out(lexer->errout, 0, "longdesc attribute which takes a URL linked to the description.\n");
            tidy_out(lexer->errout, 0, "These measures are needed for people using non-graphical browsers.\n\n");
        }

        if (lexer->badAccess & MISSING_IMAGE_MAP)
        {
            tidy_out(lexer->errout, 0, "Use client-side image maps in preference to server-side image\n");
            tidy_out(lexer->errout, 0, "maps as the latter are inaccessible to people using non-\n");
            tidy_out(lexer->errout, 0, "graphical browsers. In addition, client-side maps are easier\n");
            tidy_out(lexer->errout, 0, "to set up and provide immediate feedback to users.\n\n");
        }

        if (lexer->badAccess & MISSING_LINK_ALT)
        {
            tidy_out(lexer->errout, 0, "For hypertext links defined using a client-side image map, you\n");
            tidy_out(lexer->errout, 0, "need to use the alt attribute to provide a textual description\n");
            tidy_out(lexer->errout, 0, "of the link for people using non-graphical browsers.\n\n");
        }

        if ((lexer->badAccess & USING_FRAMES) && !(lexer->badAccess & USING_NOFRAMES))
        {
            tidy_out(lexer->errout, 0, "Pages designed using frames presents problems for\n");
            tidy_out(lexer->errout, 0, "people who are either blind or using a browser that\n");
            tidy_out(lexer->errout, 0, "doesn't support frames. A frames-based page should always\n");
            tidy_out(lexer->errout, 0, "include an alternative layout inside a NOFRAMES element.\n\n");
        }

        tidy_out(lexer->errout, 0, "For further advice on how to make your pages accessible\n");
        tidy_out(lexer->errout, 0, "see \"%s\". You may also want to try\n", ACCESS_URL);
        tidy_out(lexer->errout, 0, "\"http://www.cast.org/bobby/\" which is a free Web-based\n");
        tidy_out(lexer->errout, 0, "service for checking URLs for accessibility.\n\n");
    }

    if (lexer->badLayout)
    {
        if (lexer->badLayout & USING_LAYER)
        {
            tidy_out(lexer->errout, 0, "The Cascading Style Sheets (CSS) Positioning mechanism\n");
            tidy_out(lexer->errout, 0, "is recommended in preference to the proprietary <LAYER>\n");
            tidy_out(lexer->errout, 0, "element due to limited vendor support for LAYER.\n\n");
        }

        if (lexer->badLayout & USING_SPACER)
        {
            tidy_out(lexer->errout, 0, "You are recommended to use CSS for controlling white\n");
            tidy_out(lexer->errout, 0, "space (e.g. for indentation, margins and line spacing).\n");
            tidy_out(lexer->errout, 0, "The proprietary <SPACER> element has limited vendor support.\n\n");
        }

        if (lexer->badLayout & USING_FONT)
        {
            tidy_out(lexer->errout, 0, "You are recommended to use CSS to specify the font and\n");
            tidy_out(lexer->errout, 0, "properties such as its size and color. This will reduce\n");
            tidy_out(lexer->errout, 0, "the size of HTML files and make them easier maintain\n");
            tidy_out(lexer->errout, 0, "compared with using <FONT> elements.\n\n");
        }

        if (lexer->badLayout & USING_NOBR)
        {
            tidy_out(lexer->errout, 0, "You are recommended to use CSS to control line wrapping.\n");
            tidy_out(lexer->errout, 0, "Use \"white-space: nowrap\" to inhibit wrapping in place\n");
            tidy_out(lexer->errout, 0, "of inserting <NOBR>...</NOBR> into the markup.\n\n");
        }

        if (lexer->badLayout & USING_BODY)
        {
            tidy_out(lexer->errout, 0, "You are recommended to use CSS to specify page and link colors\n");
        }
    }
}

#ifndef BIF_TIDY
void UnknownOption(FILE *errout, char c)
{
    tidy_out(errout, 0, "unrecognized option -%c use -help to list options\n", c);
}
#endif

#ifndef BIF_TIDY
void UnknownFile(FILE *errout, char *program, char *file)
{
    tidy_out(errout, strlen(program)+strlen(file), "%s: can't open file \"%s\"\n", program, file);
}
#endif

void NeedsAuthorIntervention(errout_t *errout)
{
    tidy_out(errout, 0, "This document has errors that must be fixed before\n");
    tidy_out(errout, 0, "using HTML Tidy to generate a tidied up version.\n\n");
}

void MissingBody(errout_t *errout)
{
    tidy_out(errout, 0, "Can't create slides - document is missing a body element.\n");
}

void ReportNumberOfSlides(errout_t *errout, int count)
{
    tidy_out(errout, 0, "%d Slides found\n", count);
}

void GeneralInfo(errout_t *errout)
{
    tidy_out(errout, 0, "HTML & CSS specifications are available from http://www.w3.org/\n");
    tidy_out(errout, 0, "To learn more about Tidy see http://www.w3.org/People/Raggett/tidy/\n");
    tidy_out(errout, 0, "Please send bug reports to Dave Raggett care of <html-tidy@w3.org>\n");
    tidy_out(errout, 0, "Lobby your company to join W3C, see http://www.w3.org/Consortium\n");
}

#ifndef BIF_TIDY
void HelloMessage(FILE *errout, char *date, char *filename)
{
    currentFile = filename;  /* for use with Gnu Emacs */

    if (wstrcmp(filename, "stdin") == 0)
        tidy_out(errout, 0, "\nTidy (vers %s) Parsing console input (stdin)\n", date);
    else
        tidy_out(errout, strlen(filename), "\nTidy (vers %s) Parsing \"%s\"\n", date, filename);
}
#endif

#ifdef BIF_TIDY
void ReportVersion4bif(errout_t *errout, Lexer *lexer, Node *doctype)
#else
void ReportVersion(FILE *errout, Lexer *lexer, char *filename, Node *doctype)
#endif
{
    unsigned int i, c;
    int state = 0;
    char *vers = HTMLVersionName(lexer);

    if (doctype)
    {
#ifdef BIF_TIDY
        tidy_out(errout, 0, "\nDoctype given is \"");
#else
        tidy_out(errout, strlen(filename), "\n%s: Doctype given is \"", filename);
#endif
        for (i = doctype->start; i < doctype->end; ++i)
        {
            c = (unsigned char)lexer->lexbuf[i];

            /* look for UTF-8 multibyte character */
            if (c > 0x7F)
                 i += GetUTF8((unsigned char *)lexer->lexbuf + i, &c);

            if (c == '"')
                ++state;
            else if (state == 1)
                tidy_out(errout, 0, "%c", c);
        }

        tidy_out(errout, 0, "\"");
    }
#ifdef BIF_TIDY
    tidy_out(errout, (vers ? strlen(vers) : 0),
        "\nDocument content looks like %s\n",
        (vers ? vers : "HTML proprietary"));
#else
    tidy_out(errout, strlen (filename) + (vers ? strlen(vers) : 0),
        "\n%s: Document content looks like %s\n",
        filename, (vers ? vers : "HTML proprietary"));
#endif
}



void ReportNumWarnings(errout_t *errout, Lexer *lexer)
{
    if (lexer->warnings > 0)
        tidy_out(errout, 0, "%d warnings/errors were found!\n\n", lexer->warnings);
    else
        tidy_out(errout, 0, "no warnings or errors were found\n\n");
}

#ifndef BIF_TIDY
void HelpText(FILE *out, char *prog)
{
#if 0  /* old style help text */
    tidy_out(out, "%s: file1 file2 ...\n", prog);
    tidy_out(out, "Utility to clean up & pretty print html files\n");
    tidy_out(out, "see http://www.w3.org/People/Raggett/tidy/\n");
    tidy_out(out, "options for tidy released on %s\n", release_date);
    tidy_out(out, "  -config <file>  set options from config file\n");
    tidy_out(out, "  -indent or -i   indent element content\n");
    tidy_out(out, "  -omit   or -o   omit optional endtags\n");
    tidy_out(out, "  -wrap 72        wrap text at column 72 (default is 68)\n");
    tidy_out(out, "  -upper  or -u   force tags to upper case (default is lower)\n");
    tidy_out(out, "  -clean  or -c   replace font, nobr & center tags by CSS\n");
    tidy_out(out, "  -raw            leave chars > 128 unchanged upon output\n");
    tidy_out(out, "  -ascii          use ASCII for output, Latin-1 for input\n");
    tidy_out(out, "  -latin1         use Latin-1 for both input and output\n");
    tidy_out(out, "  -iso2022        use ISO2022 for both input and output\n");
    tidy_out(out, "  -utf8           use UTF-8 for both input and output\n");
    tidy_out(out, "  -mac            use the Apple MacRoman character set\n");
    tidy_out(out, "  -numeric or -n  output numeric rather than named entities\n");
    tidy_out(out, "  -modify or -m   to modify original files\n");
    tidy_out(out, "  -errors or -e   only show errors\n");
    tidy_out(out, "  -quiet or -q    suppress nonessential output\n");
    tidy_out(out, "  -f <file>       write errors to named <file>\n");
    tidy_out(out, "  -xml            use this when input is wellformed xml\n");
    tidy_out(out, "  -asxml          to convert html to wellformed xml\n");
    tidy_out(out, "  -slides         to burst into slides on h2 elements\n");
    tidy_out(out, "  -version or -v  show version\n");
    tidy_out(out, "  -help   or -h   list command line options\n");
    tidy_out(out, "Input/Output default to stdin/stdout respectively\n");
    tidy_out(out, "Single letter options apart from -f may be combined\n");
    tidy_out(out, "as in:  tidy -f errs.txt -imu foo.html\n");
    tidy_out(out, "You can also use --blah for any config file option blah\n");
    tidy_out(out, "For further info on HTML see http://www.w3.org/MarkUp\n");
#endif
    tidy_out(out, 0, "%s: file1 file2 ...\n", prog);
    tidy_out(out, 0, "Utility to clean up & pretty print html files\n");
    tidy_out(out, 0, "see http://www.w3.org/People/Raggett/tidy/\n");
    tidy_out(out, 0, "options for tidy released on %s\n", release_date);
    tidy_out(out, 0, "\n");

    tidy_out(out, 0, "Processing directives\n");
    tidy_out(out, 0, "--------------------\n");
    tidy_out(out, 0, "  -indent or -i   indent element content\n");
    tidy_out(out, 0, "  -omit   or -o   omit optional endtags\n");
    tidy_out(out, 0, "  -wrap 72        wrap text at column 72 (default is 68)\n");
    tidy_out(out, 0, "  -upper  or -u   force tags to upper case (default is lower)\n");
    tidy_out(out, 0, "  -clean  or -c   replace font, nobr & center tags by CSS\n");
    tidy_out(out, 0, "  -numeric or -n  output numeric rather than named entities\n");
    tidy_out(out, 0, "  -errors or -e   only show errors\n");
    tidy_out(out, 0, "  -quiet or -q    suppress nonessential output\n");
    tidy_out(out, 0, "  -xml            use this when input is wellformed xml\n");
    tidy_out(out, 0, "  -asxml          to convert html to wellformed xml\n");
    tidy_out(out, 0, "  -slides         to burst into slides on h2 elements\n");
    tidy_out(out, 0, "\n");

    tidy_out(out, 0, "Character encodings\n");
    tidy_out(out, 0, "------------------\n");
    tidy_out(out, 0, "  -raw            leave chars > 128 unchanged upon output\n");
    tidy_out(out, 0, "  -ascii          use ASCII for output, Latin-1 for input\n");
    tidy_out(out, 0, "  -latin1         use Latin-1 for both input and output\n");
    tidy_out(out, 0, "  -iso2022        use ISO2022 for both input and output\n");
    tidy_out(out, 0, "  -utf8           use UTF-8 for both input and output\n");
    tidy_out(out, 0, "  -mac            use the Apple MacRoman character set\n");
    tidy_out(out, 0, "\n");
    tidy_out(out, 0, "\n");

    tidy_out(out, 0, "File manipulation\n");
    tidy_out(out, 0, "---------------\n");
    tidy_out(out, 0, "  -config <file>  set options from config file\n");
    tidy_out(out, 0, "  -f <file>       write errors to named <file>\n");
    tidy_out(out, 0, "  -modify or -m   to modify original files\n");
    tidy_out(out, 0, "\n");

    tidy_out(out, 0, "Miscellaneous\n");
    tidy_out(out, 0, "------------\n");
    tidy_out(out, 0, "  -version or -v  show version\n");
    tidy_out(out, 0, "  -help   or -h   list command line options\n");
    tidy_out(out, 0, "You can also use --blah for any config file option blah\n");
    tidy_out(out, 0, "\n");

    tidy_out(out, 0, "Input/Output default to stdin/stdout respectively\n");
    tidy_out(out, 0, "Single letter options apart from -f may be combined\n");
    tidy_out(out, 0, "as in:  tidy -f errs.txt -imu foo.html\n");
    tidy_out(out, 0, "For further info on HTML see http://www.w3.org/MarkUp\n");
    tidy_out(out, 0, "\n");
}
#endif
