/*
 *  Dksystem.h
 *
 *  $Id$
 *
 *  system common include files
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
 *
*/

#ifndef _DKSYSTEM_H
#define _DKSYSTEM_H

#ifdef _WIN64
# include "Dkconfig.w64"
#elif defined (WIN32)
# include "Dkconfig.w32"
#else
# include "Dkconfig.h"
#endif

#if 0
/* XXX cleanup for final version */
#ifndef NO_THREAD
# if defined (WITH_PTHREADS) || defined (PTHREAD)
#  include <pthread.h>
#  ifndef _REENTRANT
#   define _REENTRANT
#  endif
#  ifndef PTHREAD
#   define PTHREAD
#  endif
#  define PREEMPT
# endif
#endif
#endif

#if !defined (NO_THREAD) && defined (WITH_PTHREADS) && !defined (_REENTRANT)
#define _REENTRANT
#endif

#include <stdio.h>
#include <ctype.h>
#include <signal.h>
#include <setjmp.h>
#include <sys/types.h>
#include <sys/stat.h>

#ifdef HAVE_SYS_TIMEB_H
/* SCO 3.2 "devsys 4.2" has a prototype for `ftime' in <time.h> that bombs
   unless <sys/timeb.h> has been included first.  Does every system have a
   <sys/timeb.h>?  If any does not, configure should check for it.  */
# include <sys/timeb.h>
#endif

#ifdef TIME_WITH_SYS_TIME
# include <sys/time.h>
# include <time.h>
#else
# ifdef HAVE_SYS_TIME_H
#  include <sys/time.h>
# else
#  include <time.h>
# endif
#endif

#ifdef STDC_HEADERS
# include <stdlib.h>
# include <string.h>
# include <stdarg.h>
# include <memory.h>
#else
# ifdef HAVE_STRING_H
#  include <string.h>
# else
#  include <strings.h>
# endif
# ifdef	HAVE_MEMORY_H
#  include <memory.h>
# endif
#endif

#if !defined(__FreeBSD__)
#ifdef HAVE_MALLOC_H
# include <malloc.h>
#else
void *malloc ();
void *calloc ();
void *realloc ();
void free ();
#endif
#endif

#ifdef HAVE_UNISTD_H
# include <unistd.h>
#endif

#ifdef	HAVE_LIMITS_H
#include <limits.h>
#endif

#ifdef	HAVE_SYS_PARAM_H
#include <sys/param.h>
#endif

#ifdef HAVE_SYS_SELECT_H
# include <sys/select.h>
#endif

#if defined (WINDOWS) || defined (WIN32) || defined (OS2)
# include <io.h>
# include <process.h>
#endif

#ifdef HAVE_FCNTL_H
# include <fcntl.h>
#else
# include <sys/file.h>
#endif

#ifndef O_BINARY
# define O_BINARY 0
#endif

#include <errno.h>
#if !defined(linux) && !defined(__APPLE__) && !defined (WIN32) && !defined (__CYGWIN__) && !defined(__FreeBSD__) && !defined (__cplusplus)
extern char *sys_errlist[];
extern int sys_nerr;
#endif

#ifndef	errno
extern int errno;
#endif

#if defined (NO_THREAD)
# undef strtok_r
# define strtok_r(X,Y,Z)	strtok((X),(Y))
#elif !defined (strtok_r)
#ifdef __GNUC__
extern char *strtok_r (char *s, const char *delim, char **ptrptr);
#else
char *strtok_r ();
#endif
#endif

#ifdef linux
# define _P __P						   /* Fixes bug in sched.h */
#endif

#ifndef MAX
# define MAX(X,Y)	(X > Y ? X : Y)
# define MIN(X,Y)	(X < Y ? X : Y)
#endif

#ifdef __cplusplus
# define BEGIN_CPLUSPLUS	extern "C" {
# define END_CPLUSPLUS		}
#else
# define BEGIN_CPLUSPLUS
# define END_CPLUSPLUS
#endif

/*
 *  Solve the `weak external' problem
 */
#if defined(VMS) && VMS_TARG == VAX
# define GLOBALDEF globaldef
# define GLOBALREF globalref
#else
# ifndef GLOBALDEF
#  define GLOBALDEF
# endif
# define GLOBALREF extern
#endif

#ifdef __GNUC__
# define DK_INLINE	__inline__
#else
# define DK_INLINE
#endif

#endif
