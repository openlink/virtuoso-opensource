/*
 *  Dk.h
 *
 *  $Id$
 *
 *  All configuration options
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2015 OpenLink Software
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

#ifndef _DK_H
#define _DK_H	/* libutil needs this name !!! */

#include "plugin/exe_export.h"

#ifdef LONGJMP_DEBUG
#include <setjmp.h>
extern void ldbg_longjmp (jmp_buf env, int value);
#define longjmp(buf,val) ldbg_longjmp((buf),(val))
#endif

#include "Dk/Dksystem.h"

/* These are about to disappear when merge is complete */
#define PMN_THREADS	/* Activate new threading model */
#define PMN_LOG		/* Activate new logging */
#define PMN_NMARSH	/* Activate new marshaller */
#define PMN_MODS	/* Subtle changes to dksrv library */

/* Align all boxes on an 8 byte boundary
   Could do without on most systems, but this is usually faster */
#if !defined (NO_DOUBLE_ALIGN)
# define DOUBLE_ALIGN
#endif

#ifdef WIN32
# define PCTCP
# define DOSFS
#else
# define UNIX 1
# define COM_UNIXSOCK
#endif

#if defined (UNIX) && !defined (unix)
# define unix
#endif

#define COM_TCPIP

#ifndef WORDS_BIGENDIAN
# define LOW_ORDER_FIRST
#endif

#ifndef MALLOC_DEBUG
#include "util/dbgmal.h"
#endif

#include "Dk/Dkparam.h"
#include "Dk/Dktypes.h"
#include "Dk/Dktrace.h"
#include "Dk/Dkutil.h"

#include "Thread/Dkthread.h"

#include "Dk/Dkalloc.h"
#include "Dk/Dkbasket.h"
#include "Dk/Dkbox.h"
#include "Dk/Dkhash.h"
#include "Dk/Dkhash64.h"
#include "Dk/Dkhashext.h"
#include "Dk/Dkresource.h"
#include "Dk/Dksets.h"
#include "Dk/Dkpool.h"
#include "Dk/Dkdevice.h"
#include "Dk/Dksession.h"
#include "Dk/Dkernel.h"

#include "Thread/thread_int.h"
#include "Dk/tlsf.h"

#ifdef PMN_LOG
# include "util/logmsg.h"
#endif

#include "Dk/Dkstubs.h"

/*
 * Localization macros
 */
#if defined(ENABLE_NLS)

#if defined(HAVE_LOCALE_H)
#include <locale.h>
#endif

#include <libintl.h>

#  define _(X)			gettext(X)
#  define N_(X) 		X

#else

#  define _(X)			X
#  define N_(X) 		X
#  define gettext(X)		X

#endif /* ENABLE_NLS */

#if defined (MAC_OS_X_VERSION_10_9) && (MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_9)
#include <xmmintrin.h>
#define __builtin_ia32_loadups(p) _mm_loadu_ps((p))
#endif

#endif /* _DK_H */
