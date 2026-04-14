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
 *  Copyright (C) 1998-2026 OpenLink Software
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


int
vsnprintf_ck (char *str, size_t size, const char *format, va_list ap)
{
  int written;
#ifdef WIN32
  written = _vsnprintf (str, size, format, ap);
#elif defined (HAVE_VSNPRINTF)
  written = vsnprintf (str, size, format, ap);
#else
  GPF_T1 ("vsnprintf_ck requires a native vsnprintf implementation");
#endif
  if (written > (int) (size))
    GPF_T1 ("Not enough buffer length for writing by vsnprintf_ck");
  if (size > 0)
    str[size - 1] = '\0';
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
#elif defined(HAVE_VSNPRINTF)
  written = vsnprintf (str, size, format, ap);
#else
  GPF_T1 ("snprintf_ck requires a native snprintf implementation");
#endif
  if (written > (int) (size))
    GPF_T1 ("Not enough buffer length for writing by snprintf_ck");
  va_end (ap);
  if (size > 0)
    str[size - 1] = '\0';
  return written;
}
