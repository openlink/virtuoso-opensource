/*
 *  charclasses.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

#ifndef _CHARCLASSES_H
#define _CHARCLASSES_H

#include "xmlparser.h"

typedef struct xml_char_range
{
  unichar start;
  unichar end;
}
xml_char_range_t;

typedef xml_char_range_t xml_char_class_t[];

extern xml_char_range_t XML_CLASS_DIGIT[], XML_CLASS_HEX[],
    XML_CLASS_NMSTART[], XML_CLASS_NMCHAR[];

#endif /* _CHARCLASSES_H */
