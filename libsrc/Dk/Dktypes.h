/*
 *  Dktypes.c
 *
 *  $Id$
 *
 *  Global types
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

#ifndef _DKTYPES_H
#define _DKTYPES_H
#ifdef HAVE_STDINT_H
#include <stdint.h>					   /* for INT64_MAX etc */
#endif

#ifdef _MSC_VER
#include <limits.h>
#endif
#ifndef _ITYPES_H
# if SIZEOF_LONG == 4
#  define int32			long
#  define uint32		unsigned long
# elif SIZEOF_INT == 4
#  define int32			int
#  define uint32		unsigned int
# elif defined (ULONG_MAX) && ULONG_MAX == 4294967295U	   /* (4 bytes) */
#  define int32			long
#  define uint32		unsigned long
# elif defined (UINT_MAX) && UINT_MAX == 4294967295U	   /* (4 bytes) */
#  define int32			int
#  define uint32		unsigned int
# elif defined (MAXLONG) && MAXLONG == 2147483647U	   /* (4 bytes) */
#  define int32			long
#  define uint32		unsigned long
# else
#  error Unable to guess the int32/uint32 types. Try including the <limits.h>
# endif
#endif

#ifndef INT16_MAX
# define INT16_MAX		(32767)
#endif

#ifndef INT16_MIN
# define INT16_MIN		(-32767-1)
#endif

#ifndef INT32_MIN
#define INT32_MIN 		(-2147483647-1)
#endif

#ifndef INT32_MAX
#define INT32_MAX		(2147483647)
#endif

#ifndef INT64_MIN
#define INT64_MIN		(-9223372036854775807LL-1)
#endif

#ifndef INT64_MAX
# define INT64_MAX		(9223372036854775807LL)
#endif

/* true for most compilers, subject to change */
#if 1
# if SIZEOF_SHORT == 2
#define	uint16			unsigned short
# endif
# if SIZEOF_CHAR == 1
#define uint8			unsigned char
# endif	/* SIZEOF_CHAR */
#endif /* 1 */

#ifndef uint16
# error Unable to guess uint16 type
#endif
#ifndef uint8
# error Unable to guess uint8 type
#endif

#if defined (WIN32) && !defined (_PHP) && !defined(BIF_SAMPLES)
#define int64 __int64
#elif SIZEOF_LONG_LONG == 8
#define int64 			long long
#endif

#if defined (_WIN64)
#define ptrlong int64					  /* integer type with size of pointer */
#define uptrlong 		unsigned int64		  /* integer type with size of pointer */
#else
#define ptrlong 		long			  /* integer type with size of pointer */
#define uptrlong 		unsigned long		  /* integer type with size of pointer */
#endif
#define ptr_long 		ptrlong
#define ptr_ulong 		uptrlong
#define uint64 unsigned int64

#if defined (OS2) || defined (WIN32)
# define ssize_t		signed int
# ifndef _ITYPES_H
typedef char *			caddr_t;
# endif
#endif
typedef const char *		ccaddr_t;

typedef unsigned char 		dtp_t;

/* Interface to a certain communication device */
typedef struct device_s 	device_t;

/* Interface to a certain session */
typedef struct session_s 	session_t;

#if 0
typedef struct du_thread_s 	du_thread_t;
typedef struct du_semaphore_s 	du_semaphore_t;
typedef struct du_semaphore_s 	semaphore_t;
typedef struct dk_mutex_s 	dk_mutex_t;
#endif

/* General type for specifying timeout values for select, read and write */
typedef struct
{
  int32	to_sec;			/* seconds */
  int32	to_usec;		/* microseconds */
} timeout_t;

#ifdef FILE64

#define OFF_T			off64_t
#define LSEEK(x,y,z)		lseek64((x),(y),(z))
#define FTRUNCATE(x,y)		ftruncate64((x),(y))
#define V_STAT(x,y)		stat64((x), (y))
#define V_FSTAT(x,y)		fstat64((x), (y))
typedef struct stat64 		STAT_T;

#else /* FILE64 */

#ifdef WIN32
#define OFF_T			__int64
#define LSEEK(x,y,z)		_lseeki64((x),(y),(z))
#define FTRUNCATE(x,y)		ftruncate64((x),(y))
#define V_STAT(x,y)		_stati64((x), (y))
#define V_FSTAT(x,y)		_fstati64((x), (y))
typedef struct _stati64 	STAT_T;
#else /* WIN32 */
#define OFF_T			off_t
#define LSEEK(x,y,z)		lseek((x),(y),(z))
#define FTRUNCATE(x,y)		ftruncate((x),(y))
#define V_STAT(x,y)		stat((x), (y))
#define V_FSTAT(x,y)		fstat((x), (y))
typedef struct stat 		STAT_T;
#endif
#endif /* FILE64 */

#if defined (WIN32)
#define OFF_T_PRINTF_FMT	"%I64d"
#define OFF_T_PRINTF_DTP	unsigned __int64
#elif defined (ULLONG_MAX)
#define OFF_T_PRINTF_FMT	"%llu"
#define OFF_T_PRINTF_DTP	unsigned long long
#else
#define OFF_T_PRINTF_FMT	"%lu"
#define OFF_T_PRINTF_DTP	unsigned long
#endif

#ifndef int64
#ifdef WIN32
typedef __int64 		int64;
#else
typedef long long 		int64;
#endif
#endif

struct mem_pool_s;
typedef struct mem_pool_s 	mem_pool_t;

#endif
