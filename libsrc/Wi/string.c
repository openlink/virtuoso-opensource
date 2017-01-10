/*
 *  string.c
 *
 *  $Id$
 *
 *  Wildcard and fuzzy matching functions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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

#include "wi.h"
#include "strlike.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "langfunc.h"
#ifdef __cplusplus
}
#endif
#include "multibyte.h"

#define GROUP_BEG_CHAR      ((unsigned char)'[')
#define GROUP_END_CHAR      ((unsigned char)']')
#define GROUP_NEGATE_CHAR   ((unsigned char)'^')
#define GROUP_RANGE_CHAR    ((unsigned char)'-')
#define MATCH_ONE_CHAR      ((unsigned char)'_')
#define MATCH_TO_LAST_CHAR  ((unsigned char)'@')
#define MATCH_ZERO_OR_MORE  ((unsigned char)'*')
#define MATCH_ZERO_OR_MORE_2  ((unsigned char)'%')
#define LIKE_ESCAPE_CHARACTER ((unsigned char)'\\')

#define GROUP_BEG_CHAR__wide      ((wchar_t)L'[')
#define GROUP_END_CHAR__wide      ((wchar_t)L']')
#define GROUP_NEGATE_CHAR__wide   ((wchar_t)L'^')
#define GROUP_RANGE_CHAR__wide    ((wchar_t)L'-')
#define MATCH_ONE_CHAR__wide      ((wchar_t)L'_')
#define MATCH_TO_LAST_CHAR__wide  ((wchar_t)L'@')
#define MATCH_ZERO_OR_MORE__wide  ((wchar_t)L'*')
#define MATCH_ZERO_OR_MORE_2__wide  ((wchar_t)L'%')
#define LIKE_ESCAPE_CHARACTER__wide ((wchar_t)L'\\')


size_t
strlen__wide (const wchar_t *str)
{
  int ret = 0;
  while (0 != str[ret])
    ret++;
  return ret;
}


const wchar_t *
strchr__wide (const wchar_t *str, int c )
{
  int ret = 0;
  while ((wchar_t)c != str[ret] && 0 != str[ret])
    ret++;
  return (0 == str[ret])? NULL : (str+ret);
}

#define SLPREFIX
#define SLPOSTFIX

#define SLCHAR char
#define SLUCHAR unsigned char
#define STRLIKE_NAME(name) name
#include "string_tmpl.c"


#undef SLCHAR
#undef SLUCHAR
#undef STRLIKE_NAME
#undef SLPREFIX
#undef SLPOSTFIX

#define SLPREFIX L
#define SLPOSTFIX __wide
#define SLCHAR_WIDE 1
#define SLUCHAR wchar_t
#define SLCHAR wchar_t
#define STRLIKE_NAME(name) name##__wide
#include "string_tmpl.c"

static wchar_t *
__convert_arg (const char *str, int type, int *need_free)
{
  assert (NULL != str && NULL != need_free);
  if (LIKE_ARG_UTF == type || LIKE_ARG_CHAR == type)
    {
      *need_free = 1;
      return (wchar_t *)(box_utf8_as_wide_char (str, NULL, strlen (str), 0));
    }
  *need_free = 0;
  return (wchar_t *)str;
}

int
cmp_like (const char *string, const char * pattern, collation_t *collation, char escape_char, int strtype, int patterntype )
{
  int ret = DVC_LESS;

/*  if (LIKE_ARG_CHAR == strtype && (LIKE_ARG_WCHAR == patterntype || LIKE_ARG_UTF == patterntype))
    return DVC_LESS;
  if (LIKE_ARG_CHAR == patterntype && (LIKE_ARG_WCHAR == strtype || LIKE_ARG_UTF == strtype))
    return DVC_LESS;*/

  if (LIKE_ARG_CHAR == strtype && LIKE_ARG_CHAR == patterntype)
    ret = __cmp_like (string, pattern, collation, escape_char);
  else
    {
      int free1, free2;
      wchar_t *wstr = __convert_arg (string, strtype, &free1);
      wchar_t *wpat = __convert_arg ((char *) pattern, patterntype, &free2);
      if (NULL == wstr || NULL == wpat)
	return ret;

      ret = __cmp_like__wide (wstr, wpat, (wchar_t)escape_char);

      if (free1)
	dk_free_box ((box_t) wstr);
      if (free2)
	dk_free_box ((box_t) wpat);
    }
  return ret;
}
