/*
 *  Dkstubs.c
 *
 *  $Id$
 *
 *  Systems specific code
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

#include "Dk.h"

#ifdef DK_NEED_VSNPRINTF

#ifndef HAVE_VSNPRINTF
int
vsnprintf (char *str, size_t size, const char *format, va_list ap)
{
#ifdef WIN32
  return _vsnprintf (str, size, format, ap);
#else
  int written = vsprintf (str, format, ap);
  if (written > size)
    GPF_T1 ("Not enough buffer length for writing");
  return written;
#endif /* WIN32 */
}
#endif

#ifndef HAVE_SNPRINTF
int
snprintf (char *str, size_t size, const char *format, ...)
{
  int res;
  va_list ap;
  va_start (ap, format);
#ifdef WIN32
  res = _vsnprintf (str, size, format, ap);
#else
  res = vsprintf (str, format, ap);
  if (res > size)
    GPF_T1 ("Not enough buffer length for writing");
#endif /* WIN32 */
  va_end (ap);
  return res;
}
#endif

#endif /* DK_NEED_VSNPRINTF */

int
vsnprintf_ck (char *str, size_t size, const char *format, va_list ap)
{
  int written;
#ifdef WIN32
  written = _vsnprintf (str, size, format, ap);
#else
#ifdef HAVE_VSNPRINTF
  written = vsnprintf (str, size, format, ap);
#else
  written = vsprintf (str, format, ap);
#endif
#endif
  if (written > (int) (size))
    GPF_T1 ("Not enough buffer length for writing by vsnprintf_ck");
  return written;
}


int
snprintf_ck (char *str, size_t size, const char *format, ...)
{
  va_list ap;
  int written;
  va_start (ap, format);
#ifdef WIN32
  written = _vsnprintf (str, size, format, ap);
#else
#ifdef HAVE_VSNPRINTF
  written = vsnprintf (str, size, format, ap);
#else
  written = vsprintf (str, format, ap);
#endif
#endif
  if (written > (int) (size))
    GPF_T1 ("Not enough buffer length for writing by snprintf_ck");
  va_end (ap);
  return written;
}
