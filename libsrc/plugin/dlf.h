/*
 *  dlf.h
 *
 *  $Id$
 *
 *  dynamic load functions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

#ifndef __DLF_H__
#define __DLF_H__

#if defined (__APPLE__)
#include <AvailabilityMacros.h>

/*
 *  Mac OS X < 10.3 does not have dlopen
 *  Mac OS X 10.3 has dlopen, but has some problems so we use DLDAPI_MACX instead
 */
# if MAC_OS_X_VERSION_MIN_REQUIRED <= 1030
#  undef HAVE_LIBDL
#  define DLDAPI_MACX 1
# else
#  define DLDAPI_SVR4_DLFCN 1
# endif /* MAC_OS_X_VERSION_MIN_REQUIRED */
#endif /* defined (__APPLE_) */

/* dlopen stuff */
#if defined(HAVE_LIBDL) || defined(__FreeBSD__)
#define DLDAPI_SVR4_DLFCN
#elif defined(HAVE_SHL_LOAD)
#define DLDAPI_HP_SHL
#elif defined(HAVE_DYLD)
#define DLDAPI_DYLD
#endif

#ifndef DLDAPI_SVR4_DLFCN
/*
 *  Create internal namespace for dlopen functions
 */
#define dlopen		__virtuoso_dlopen
#define dlsym		__virtuoso_dlsym
#define dlerror		__virtuoso_dlerror
#define dlclose		__virtuoso_dlclose

extern void *dlopen (char * path, int mode);
extern void *dlsym (void * hdll, char * sym);
extern char *dlerror ();
extern int dlclose (void * hdll);
#endif

#if defined(DLDAPI_SVR4_DLFCN)
#include <dlfcn.h>
#elif defined(DLDAPI_AIX_LOAD)
#include <dlfcn.h>
#endif

#ifndef	RTLD_LAZY
#define	RTLD_LAZY       1
#endif

#ifndef	RTLD_GLOBAL
#define RTLD_GLOBAL   0x00100
#endif


#define	DLL_OPEN(dll)		(void*)dlopen((char*)(dll), RTLD_LAZY)
#define	DLL_OPEN_GLOBAL(dll)	(void*)dlopen((char*)(dll), RTLD_LAZY | RTLD_GLOBAL)
#define	DLL_PROC(hdll, sym)	(void*)dlsym((void*)(hdll), (char*)sym)
#define	DLL_ERROR()		(char*)dlerror()
#define	DLL_CLOSE(hdll)		dlclose((void*)(hdll))


#define DLF_VERSION(msg) \
	char __virtuoso_dlf_sccsid[] = "@(#)dynamic load interface -- " msg

#endif /* __DLF_H__ */
