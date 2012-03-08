/*
 *  Dkconfig.h
 *
 *  $Id$
 *
 *  Configuration
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
 *  
 */
#ifndef _DKCONFIG_H
#define _DKCONFIG_H

#if defined (HAVE_CONFIG_H) && !defined (_CONFIG_H)
#define _CONFIG_H
#include "config.h"
#endif

#if defined (WIN64)
#include "Dkconfig.w64"
#elif defined (WIN32)
#include "Dkconfig.w32"
#endif


/*
 *  Mac OS X Universal build (Mac OS X 10.4U)
 *
 *  We cannot rely on config.h to provide all settings, so we need to
 *  overrule them at compile time.
 */
#if defined (__APPLE__)

/*
 *  Avoid compiler warnings about duplicate defines
 */
#  undef	SIZEOF_INT
#  undef	SIZEOF_LONG
#  undef 	SIZEOF_CHAR_P
#  undef	SIZEOF_VOID_P
#  undef	POINTER_64
#  undef	WORDS_BIGENDIAN

# if defined (__ppc64__)

#  define	SIZEOF_INT 	4
#  define	SIZEOF_LONG 	8
#  define	SIZEOF_CHAR_P 	8
#  define	SIZEOF_VOID_P 	8

#  define	WORDS_BIGENDIAN 1
#  ifndef _BIG_ENDIAN
#   define	_BIG_ENDIAN
#  endif

#  define	POINTER_64

# elif defined (__x86_64__)

#  define	SIZEOF_INT 	4
#  define	SIZEOF_LONG 	8
#  define	SIZEOF_CHAR_P 	8
#  define	SIZEOF_VOID_P 	8

#  undef	_BIG_ENDIAN

#  define	POINTER_64


# elif defined (__ppc__)

#  define	SIZEOF_INT 	4
#  define	SIZEOF_LONG 	4
#  define	SIZEOF_CHAR_P 	4
#  define	SIZEOF_VOID_P 	4

#  define	WORDS_BIGENDIAN 1
#  ifndef _BIG_ENDIAN
#   define	_BIG_ENDIAN
#  endif

# elif defined (__i386__)

#  define	SIZEOF_INT 	4
#  define	SIZEOF_LONG 	4
#  define	SIZEOF_CHAR_P 	4
#  define	SIZEOF_VOID_P 	4

#  undef	_BIG_ENDIAN

# else
# error "Unknown Apple architecture"
# endif
#endif /* __APPLE__ */


#endif
