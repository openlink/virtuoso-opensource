/*
 *  Dktrace.h
 *
 *  $Id$
 *
 *  Tracing & Debugging
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

#ifndef _DKTRACE_H
#define _DKTRACE_H

#define GPF_T \
	gpf_notice (__FILE__, __LINE__, NULL)

#define GPF_T1(tx) \
	gpf_notice (__FILE__, __LINE__, tx)

#ifdef NDEBUG
#undef DBG_PRINTF
#endif

#ifdef DBG_PRINTF
# ifdef __GNUC__
/* This macro uses a gcc specific preprocessor extension */
#  define _dbg_print(fmt, args...) \
	fprintf (stderr,"%s(%d) " fmt "\n", __FILE__, __LINE__ , ##args)
#  define _dbg_print_ncr(fmt, args...) \
	fprintf (stderr,"%s(%d) " fmt, __FILE__, __LINE__ , ##args)

#  define dbg_printf(X)		_dbg_print_ncr X
#  define dbg_printf_1(X)	_dbg_print X
#  define dbg_printf_2(X)	_dbg_print X
#  define dbg_printf_3(X)	_dbg_print X
#  define dbg_printf_4(X)	_dbg_print X

# else /* !__GNUC__, portable debugging macros */
# define dbg_printf(X)		printf X
# define dbg_printf_1(X)	(printf X ? printf ("\n") : 0)
# define dbg_printf_2(X)	(printf X ? printf ("\n") : 0)
# define dbg_printf_3(X)	(printf X ? printf ("\n") : 0)
# define dbg_printf_4(X)	(printf X ? printf ("\n") : 0)
# endif

# define ss_dprintf_1(X)	dbg_printf_1(X)
# define ss_dprintf_2(X)	dbg_printf_2(X)
# define ss_dprintf_3(X)	dbg_printf_3(X)
# define ss_dprintf_4(X)	dbg_printf_4(X)

#else /* not debugging */
# define dbg_printf(X)
# define dbg_printf_1(X)
# define dbg_printf_2(X)
# define dbg_printf_3(X)
# define dbg_printf_4(X)

# define ss_dprintf_1(X)
# define ss_dprintf_2(X)
# define ss_dprintf_3(X)
# define ss_dprintf_4(X)

#endif

#ifdef DEBUG
# define dbg_assert(X) \
	if (!(X)) \
	  GPF_T1 ("Assertion failed: " #X);
# define dbg_perror(a) \
	{\
	  perror (a); \
	  fprintf (stderr, "\n"); \
	  fflush (stderr); \
	}

# define ss_assert(X)		dbg_assert(X)
#else

# define dbg_assert(X)
# define dbg_perror(X)
# define ss_assert(X)

#endif

/* IvAn/0/001025 memview_t added */

/*! This structure is very convenient for memory inspecting if you
   do not know what it is under the pointer. Just cast this pointer to
   memview_t * and find the member with readable data.
   Note that in MSVC you should cast to (union memview_u) */
union memview_u
{
  union
  {
    char one;
    char ten[10];
    char hun[100];
  } chars;
  union
  {
    long one;
    long ten[10];
    long hun[100];
  } longs;
  union
  {
    char *one;
    char *ten[10];
    char *hun[100];
  } strings;
  union
  {
    union memview_u *one;
    union memview_u *ten[10];
    union memview_u *hun[100];
  } children;
};

typedef union memview_u memview_t;

BEGIN_CPLUSPLUS

int gpf_notice (const char *file, int line, const char *text);

END_CPLUSPLUS

#endif
