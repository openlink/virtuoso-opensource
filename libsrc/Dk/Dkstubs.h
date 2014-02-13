/*
 *  Dkstubs.h
 *
 *  $Id$
 *
 *  Systems specific code
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

#ifndef _DKSTUBS_H
#define _DKSTUBS_H
#include <stdarg.h>

#ifdef DK_NEED_VSNPRINTF
int vsnprintf (char *str, size_t size, const char *format, va_list ap);
int snprintf (char *str, size_t size, const char *format, ...);
#endif /* DK_NEED_VSNPRINTF */

int vsnprintf_ck (char *str, size_t size, const char *format, va_list ap);
int snprintf_ck (char *str, size_t size, const char *format, ...);

/* strcpy/strcat checking macros */

#ifdef MALLOC_DEBUG

#define strcat_size_ck(dest, src, sizeof_dest)  do { \
  				   if ((sizeof_dest - strlen (dest) - 1) < strlen (src)) \
			     	     GPF_T; \
  				   strncat ((dest), (src), sizeof_dest - strlen (dest) - 1); \
				 } while (0)

#define strncat_size_ck(dest, src, len, sizeof_dest)  do { \
                                   int src_len = (int) MIN (len, strlen (src)); \
                                   int dst_len = (int) MIN (len,  (sizeof_dest) - strlen (dest) - 1); \
  				   if (((int) ((sizeof_dest) - strlen (dest) - 1)) < src_len) \
			     	     GPF_T; \
  				   strncat ((dest), (src), dst_len); \
				 } while (0)


#define strcpy_size_ck(dest, src, sizeof_dest)  do { \
  				   if ((sizeof_dest - 1) < strlen (src)) \
			     	     GPF_T; \
			 	   strncpy ((dest), (src), sizeof_dest - 1); \
			      	   (dest)[sizeof_dest - 1] = 0; \
				 } while (0)
#else

#define strcat_size_ck(dest, src, sizeof_dest)  strncat ((dest), (src), sizeof_dest - strlen (dest) - 1)

#define strncat_size_ck(dest, src, len, sizeof_dest)  do { \
                                   int dst_len = (int) MIN (len,  sizeof_dest - strlen (dest) - 1); \
  				   strncat ((dest), (src), dst_len); \
				 } while (0)

#define strcpy_size_ck(dest, src, sizeof_dest)  do { \
			 		strncpy ((dest), (src), sizeof_dest - 1); \
			      		(dest)[sizeof_dest - 1] = 0; \
				 } while (0)

#endif

#define strncat_ck(dest, src, len)  	strncat_size_ck (dest, src, len, sizeof (dest))
#define strncat_box_ck(dest, src, len)  strncat_size_ck (dest, src, len, box_length (dest))

#define strcat_ck(dest, src) 		strcat_size_ck (dest, src, sizeof (dest))
#define strcat_box_ck(dest, src) 	strcat_size_ck (dest, src, box_length (dest))

#define strcpy_ck(dest, src) 		strcpy_size_ck (dest, src, sizeof (dest))
#define strcpy_box_ck(dest, src) 	strcpy_size_ck (dest, src, box_length (dest))
#endif /* _DKSTUBS_H */
