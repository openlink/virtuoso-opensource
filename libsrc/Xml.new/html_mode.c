/*
 *  html_mode.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

#include <stdlib.h>
#include "xmlparser.h"
#include "html_mode.h"

#define o 0

static html_tag_descr_t 
html_tag_descrs[] = {
/*| Name		| To		| Ts1		| Tm1		| Tm2		| Empty	| Opt./	| Block	|WsSens	|Script	| PText | Head	*/
  { "A"			, 0x00000007	, 0x00008005	, 0x00008005	, 0x0000000F	, o	, o	, o	, o	, o	, o	, o	},
  { "ABBR"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "ACRONYM"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "ADDRESS"		, 0x00000010	, 0x00000011	, 0x0000001F	, 0x0000000F	, o	, o	, 1	, o	, o	, o	, o	},
  { "APPLET"		, 0x00000010	, 0x00000011	, 0x0000001F	, 0x0000000F	, o	, o	, 1	, o	, o	, o	, o	},
  { "AREA"		, 0x00000000	, 0x00000001	, 0x00000001	, 0x00000001	, 1	, 1	, 1	, o	, o	, o	, o	},
  { "B"			, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "BASE"		, 0x00000000	, 0x00000001	, 0x00000001	, 0x00000000	, 1	, 1	, 1	, o	, o	, o	, o	},
  { "BASEFONT"		, 0x00000000	, 0x00000000	, 0x00000000	, 0x00000000	, 1	, 1	, o	, o	, o	, o	, o	},
  { "BDO"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "BIG"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "BLOCKQUOTE"	, 0x00000070	, 0x00000011	, 0x0000001F	, 0x0000000F	, o	, o	, 1	, o	, o	, o	, o	},
  { "BODY"		, 0x20000000	, 0x01000001	, 0x01000001	, 0x4FFFFFFF	, o	, o	, 1	, o	, o	, o	, o	},
  { "BR"		, 0x00000000	, 0x00000001	, 0x00000001	, 0x00000000	, 1	, 1	, 1	, o	, o	, o	, o	},
  { "BUTTON"		, 0x00008030	, 0x00008011	, 0x0000801F	, 0x0000000F	, o	, o	, 1	, o	, o	, o	, o	},
  { "CAPTION"		, 0x0000000F	, 0x00000001	, 0x00000001	, 0x0000000F	, o	, o	, 1	, o	, o	, o	, o	},
  { "CENTER"		, 0x00000030	, 0x00000011	, 0x0000001F	, 0x0000000F	, o	, o	, 1	, o	, o	, o	, o	},
  { "CITE"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "CODE"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "COL"		, 0x00000000	, 0x00000001	, 0x00000001	, 0x00000000	, 1	, 1	, 1	, o	, o	, o	, o	},
  { "COLGROUP"		, 0x00020000	, 0x00020001	, 0x00020001	, 0x00000000	, o	, 1	, 1	, o	, o	, o	, o	},
  { "DD"		, 0x00000830	, 0x00000831	, 0x0000087F	, 0x0000003F	, o	, 1	, 1	, o	, o	, o	, o	},
  { "DEL"		, 0x40000000	, 0x4FFFFFFF	, 0x4FFFFFFF	, 0x4FFFFFFF	, o	, o	, 1	, o	, o	, o	, o	},
  { "DFN"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "DIR"		, 0x00000100	, 0x00000111	, 0x0000037F	, 0x0000027F	, o	, o	, 1	, o	, o	, o	, o	},
  { "DIV"		, 0x00000030	, 0x00000011	, 0x0000001F	, 0x0000000F	, o	, o	, 1	, o	, o	, o	, o	},
  { "DL"		, 0x00000430	, 0x00000411	, 0x0000001F	, 0x0000087F	, o	, o	, 1	, o	, o	, o	, o	},
  { "DT"		, 0x00000830	, 0x00000831	, 0x0000087F	, 0x0000000F	, o	, 1	, 1	, o	, o	, o	, o	},
  { "EM"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "FIELDSET"		, 0x00000030	, 0x00008011	, 0x0000801F	, 0x0000000F	, o	, o	, 1	, o	, o	, o	, o	},
  { "FONT"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "FORM"		, 0x00001030	, 0x00000011	, 0x0000001F	, 0x0000FFFF	, o	, o	, 1	, 1	, o	, o	, o	},
  { "FRAME"		, 0x00000000	, 0x00000011	, 0x0000001F	, 0x00000000	, 1	, 1	, 1	, o	, o	, o	, o	},
  { "FRAMESET"		, 0x02000000	, 0x00000011	, 0x0000001F	, 0x00000000	, o	, o	, 1	, o	, o	, o	, o	},
  { "H1"		, 0x00000010	, 0x00000011	, 0x0000001F	, 0x0000000F	, o	, o	, 1	, o	, o	, o	, o	},
  { "H2"		, 0x00000010	, 0x00000011	, 0x0000001F	, 0x0000000F	, o	, o	, 1	, o	, o	, o	, o	},
  { "H3"		, 0x00000010	, 0x00000011	, 0x0000001F	, 0x0000000F	, o	, o	, 1	, o	, o	, o	, o	},
  { "H4"		, 0x00000010	, 0x00000011	, 0x0000001F	, 0x0000000F	, o	, o	, 1	, o	, o	, o	, o	},
  { "H5"		, 0x00000010	, 0x00000011	, 0x0000001F	, 0x0000000F	, o	, o	, 1	, o	, o	, o	, o	},
  { "H6"		, 0x00000010	, 0x00000011	, 0x0000001F	, 0x0000000F	, o	, o	, 1	, o	, o	, o	, o	},
  { "HEAD"		, 0x01000000	, 0x00000011	, 0x0000001F	, 0x00FFFFFF	, o	, o	, 1	, o	, o	, o	, 1	},
  { "HR"		, 0x00000000	, 0x00000011	, 0x0000001F	, 0x00000000	, 1	, 1	, 1	, o	, o	, o	, o	},
  { "HTML"		, 0x10000000	, 0xFFFFFFFF	, 0xFFFFFFFF	, 0xFFFFFFFF	, o	, o	, 1	, o	, o	, o	, o	},
  { "I"			, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "IFRAME"		, 0x00000030	, 0x00008011	, 0x0000801F	, 0x0000000F	, o	, o	, 1	, 1	, o	, o	, o	},
  { "IMG"		, 0x00000000	, 0x00000001	, 0x00000001	, 0x00000000	, 1	, 1	, o	, o	, o	, o	, o	},
  { "INPUT"		, 0x00000000	, 0x00008001	, 0x00008001	, 0x00000000	, 1	, 1	, o	, o	, o	, o	, o	},
  { "INS"		, 0x40000000	, 0x4FFFFFFF	, 0x4FFFFFFF	, 0x4FFFFFFF	, o	, o	, 1	, o	, o	, o	, o	},
  { "ISINDEX"		, 0x00000000	, 0x00008001	, 0x00008001	, 0x00000000	, 1	, 1	, 1	, o	, o	, o	, o	},
  { "KBD"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "LABEL"		, 0x00000010	, 0x00008011	, 0x0000801F	, 0x0000000F	, o	, o	, o	, o	, o	, o	, o	},
  { "LEGEND"		, 0x00000010	, 0x00000011	, 0x0000001F	, 0x0000000F	, o	, o	, 1	, o	, o	, o	, o	},
  { "LI"		, 0x00000230	, 0x00000231	, 0x0000027F	, 0x0000003F	, o	, 1	, 1	, o	, o	, o	, o	},
  { "LINK"		, 0x00000000	, 0x00000001	, 0x00000001	, 0x00000000	, 1	, 1	, 1	, o	, o	, o	, o	},
  { "MAP"		, 0x00000020	, 0x00000001	, 0x00000001	, 0x0000003F	, o	, o	, 1	, o	, o	, o	, o	},
  { "MENU"		, 0x00000100	, 0x00000111	, 0x0000037F	, 0x0000027F	, o	, o	, 1	, o	, o	, o	, o	},
  { "META"		, 0x00000000	, 0x00000001	, 0x00000001	, 0x00000000	, 1	, 1	, 1	, o	, o	, o	, o	},
  { "NOFRAMES"		, 0x04000070	, 0x00000011	, 0x0000001F	, 0x04FFFFFF	, o	, o	, 1	, o	, o	, o	, o	},
  { "NOSCRIPT"		, 0x00000030	, 0x00000011	, 0x0000001F	, 0x0000003F	, o	, o	, 1	, o	, o	, o	, o	},
  { "OBJECT"		, 0x00000030	, 0x00000001	, 0x00000001	, 0x0000000F	, o	, o	, o	, o	, o	, o	, o	},
  { "OL"		, 0x00000100	, 0x00000111	, 0x0000007F	, 0x0000027F	, o	, o	, 1	, o	, o	, o	, o	},
  { "OPTGROUP"		, 0x00004000	, 0x00004011	, 0x0000401F	, 0x0000000F	, o	, o	, 1	, o	, o	, o	, o	},
  { "OPTION"		, 0x00000001	, 0x00000001	, 0x00000001	, 0x0000000F	, o	, 1	, o	, o	, o	, o	, o	},
  { "P"			, 0x00000010	, 0x00000011	, 0x0000001F	, 0x0000000F	, o	, 1	, 1	, o	, o	, o	, o	},
  { "PARAM"		, 0x00000000	, 0x00000001	, 0x00000001	, 0x00000000	, 1	, 1	, o	, o	, o	, o	, o	},
  { "PRE"		, 0x00000010	, 0x00000011	, 0x0000001F	, 0x0000000F	, o	, o	, 1	, 1	, 1	, o	, o	},
  { "Q"			, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "S"			, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "SAMP"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "SCRIPT"		, 0x00000000	, 0x00000001	, 0x00000001	, 0x00000000	, o	, o	, 1	, 1	, 1	, 1	, o	},
  { "SELECT"		, 0x00002000	, 0x00008011	, 0x0000801F	, 0x0000400F	, o	, o	, o	, o	, o	, o	, o	},
  { "SMALL"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "SPAN"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "STRIKE"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "STRONG"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "STYLE"		, 0x00000000	, 0x00000001	, 0x00000001	, 0x00000000	, o	, o	, 1	, 1	, 1	, 1	, o	},
  { "SUB"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "SUP"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "TABLE"		, 0x00010030	, 0x00000011	, 0x0000001F	, 0x000EFFFF	, o	, o	, 1	, o	, o	, o	, o	},
  { "TBODY"		, 0x00020030	, 0x000EEFFF	, 0x000EFFFF	, 0x000EFFFF	, o	, 1	, 1	, o	, o	, o	, o	},
  { "TD"		, 0x00080030	, 0x0008EFFF	, 0x0008FFFF	, 0x0008FFFF	, o	, 1	, 1	, 1	, o	, o	, o	},
  { "TEXTAREA"		, 0x00000001	, 0x00008000	, 0x00008000	, 0x0000000F	, o	, o	, o	, o	, o	, o	, o	},
  { "TFOOT"		, 0x00020030	, 0x000EEFFF	, 0x000EFFFF	, 0x000EFFFF	, o	, 1	, 1	, o	, o	, o	, o	},
  { "TH"		, 0x00080030	, 0x0008EFFF	, 0x0008FFFF	, 0x0008FFFF	, o	, 1	, 1	, 1	, o	, o	, o	},
  { "THEAD"		, 0x00020030	, 0x000EEFFF	, 0x000EFFFF	, 0x000EFFFF	, o	, 1	, 1	, o	, o	, o	, o	},
  { "TITLE"		, 0x00000001	, 0x00000001	, 0x00000001	, 0x0000000F	, o	, o	, 1	, o	, o	, o	, o	},
  { "TR"		, 0x00040030	, 0x000CEFFF	, 0x000CFFFF	, 0x000CFFFF	, o	, 1	, 1	, o	, o	, o	, o	},
  { "TT"		, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "U"			, 0x00000002	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "UL"		, 0x00000100	, 0x00000111	, 0x0000007F	, 0x0000027F	, o	, o	, 1	, o	, o	, o	, o	},
  { "VAR"		, 0x00000000	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	},
  { "XBODY"		, 0x00FFFFFF	, 0x00000011	, 0x0000001F	, 0x00FFFFFF	, o	, o	, 1	, o	, o	, o	, o	},
  { "XHEAD"		, 0x00FFFFFF	, 0x00000011	, 0x0000001F	, 0x00FFFFFF	, o	, o	, 1	, o	, o	, o	, 1	},
  { "XMP"		, 0x80000000	, 0x00000000	, 0x00000000	, 0x7FFFFFFF	, o	, o	, 1	, 1	, 1	, o	, o	},
  { NULL		, 0x00000000	, 0x00000000	, 0x00000000	, 0x00000000	, o	, o	, o	, o	, o	, o	, o	}
};

static html_attr_descr_t 
html_attr_descrs[] = {
  { "CHECKED"		, 1	},
  { "COMPACT"		, 1	},
  { "DECLARE"		, 1	},
  { "DEFER"		, 1	},
  { "DISABLED"		, 1	},
  { "ISMAP"		, 1	},
  { "MULTIPLE"		, 1	},
  { "NOHREF"		, 1	},
  { "NORESIZE"		, 1	},
  { "NOSHADE"		, 1	},
  { "NOWRAP"		, 1	},
  { "READONLY"		, 1	},
  { "SELECTED"		, 1	},
  { NULL		, 1	}
};


id_hash_t *html_tag_hash = NULL;
id_hash_t *html_attr_hash = NULL;


void
html_hash_init (void)
{
  html_tag_descr_t *tag;
  html_attr_descr_t *attr;
  html_tag_hash = id_hash_allocate (253, sizeof (char *), sizeof (html_tag_descr_t), strhashcase, strhashcasecmp);
  html_attr_hash = id_hash_allocate (29, sizeof (char *), sizeof (html_attr_descr_t), strhashcase, strhashcasecmp);
  for (tag = html_tag_descrs; NULL != tag->htmltd_name; tag++)
    {
      caddr_t id = box_dv_short_string (tag->htmltd_name);
      id_hash_set (html_tag_hash, (caddr_t) &id, (caddr_t)(tag));
    }
  for (attr = html_attr_descrs; NULL != attr->htmlad_name; attr++)
    {
      caddr_t id = box_dv_short_string (attr->htmlad_name);
      id_hash_set (html_attr_hash, (caddr_t) &id, (caddr_t)(attr));
    }
}
