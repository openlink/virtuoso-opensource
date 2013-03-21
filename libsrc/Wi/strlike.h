/*
 *  strlike.h
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

#ifndef _WI_STRLIKE_H
#define _WI_STRLIKE_H

#include "wi.h" /* for collation_t */

#define LIKE_ARG_CHAR	1
#define LIKE_ARG_WCHAR	2
#define LIKE_ARG_UTF	3

extern int cmp_like (const char *string, const char *pattern, collation_t *collation, char escape_char, int strtype, int patterntype );
extern unsigned char *nc_strstr (const unsigned char *string1, const unsigned char *string2);
extern wchar_t *nc_strstr__wide (const wchar_t *string1, const wchar_t *string2);


#endif /* _WI_STRLIKE_H */
