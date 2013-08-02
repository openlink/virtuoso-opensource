/*
 *  html_mode.h
 *
 *  HTML 4.01 processing
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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
 *
 */

#ifndef _HTML_MODE_H
#define _HTML_MODE_H

/*                0         1         2         */
/*                01234567890123456789012345678 */
#define XHTML_NS "http://www.w3.org/1999/xhtml"
#define XHTML_NS_LEN 28

/* Auto-closing masks.

Every tag T has four bitmasks associated with it, I will name them
'own mask' (To)
'should-close-on-opening mask' (Ts1)
'may-close-on-opening mask' (Tm1)
'may-close-on-closing mask' (Tm2)

If (
  tag T is now opening
  and
  the stack contains such not-yet-closed tag A that ((Ao & Ts1) == Ao)
  and
  every tag B in stack that is above A satisfies ((Bo & Tm1) == Bo)
  )
then
 before opening A parser should close all tags from the top of the stack to A inclusive.

If (
  tag T is now closing
  and
  the name of T is not equal to the name of the last not-yet-closed tag in stack
  and
  the stack contains elements with the required name
  and
  A is the topmost among such elements
  and
  every tag B in stack that is above A satisfies ((Bo & Tm2) == Bo)
  )
then
  parser should close all tags from the top of the stack to A inclusive.

Every mask is an OR of the following bits: */

#define HTMLTM_PCDATA		0x00000001
#define HTMLTM_INLINE		0x00000002
#define HTMLTM_A		0x00000004
#define HTMLTM_LABEL		0x00000008

#define HTMLTM_BOX_FOR_INLINE   0x00000010
#define HTMLTM_BOX_FOR_BLOCKS	0x00000020
#define HTMLTM_BOX_FOR_SCRIPTS	0x00000040

#define HTMLTM_LIST		0x00000100
#define HTMLTM_LISTITEM		0x00000200
#define HTMLTM_DICT		0x00000400
#define HTMLTM_DICTITEM		0x00000800

#define HTMLTM_FORM		0x00001000
#define HTMLTM_SELECT		0x00002000
#define HTMLTM_OPTGROUP		0x00004000
#define HTMLTM_BUTTON		0x00008000

#define HTMLTM_TABLE		0x00010000
#define HTMLTM_TABLECONT	0x00020000
#define HTMLTM_TABLE_ROW	0x00040000
#define HTMLTM_TABLE_COLUMN	0x00080000

#define HTMLTM_HEAD		0x01000000
#define HTMLTM_FRAMESET		0x02000000
#define HTMLTM_NOFRAMES		0x04000000

#define HTMLTM_HTML		0x10000000
#define HTMLTM_BODY		0x20000000
#define HTMLTM_INSDEL		0x40000000
#define HTMLTM_XMP		0x80000000


typedef struct html_tag_descr_s
{
/*! Tag name */
  const char *htmltd_name;
/*! 'own mask' */
  unsigned htmltd_mask_o;
/*! 'should-close-on-opening mask' */
  unsigned htmltd_mask_s1;
/*! 'may-close-on-opening mask' */
  unsigned htmltd_mask_m1;
/*! 'may-close-on-closing mask' */
  unsigned htmltd_mask_m2;
/*! True if the tag is declared as EMPTY (and closing tag is forbidden) */
  unsigned char htmltd_is_empty;
/*! True if the < / tag > may be omitted after < tag > */
  unsigned char htmltd_is_closing_optional;
/*! True if the tag is listed in <!ENTITY % block ... >, i.e. it is structure tag, not layout, (thus affects indents) */
  unsigned char htmltd_is_block;
/*! True if the content of tag is whitespace-sensitive */
  unsigned char htmltd_is_ws_sensitive;
/*! True if internal content of the tag is a special data so indentation must be disabled. */
  unsigned char htmltd_is_script;
/*! True if internal content of the tag is a special data so escaping may be disabled. */
  unsigned char htmltd_is_ptext;
/*! True if the tag is a HEAD of the document (i.e. it can contain META) */
  unsigned char htmltd_is_head;
} html_tag_descr_t;

typedef struct html_attr_descr_s
{
  const char *htmlad_name;		/* Attribute name */
  int htmlad_is_boolean;	/* True if the attribute is boolean */
} html_attr_descr_t;

extern id_hash_t *html_tag_hash;
extern id_hash_t *html_attr_hash;

#endif /* _HTML_MODE_H */
