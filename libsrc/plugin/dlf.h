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
 *  Copyright (C) 1998-2006 OpenLink Software
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
#ifndef __DLF_H__
#define __DLF_H__

#if defined (__APPLE__)

/* 10.3 has dlopen, but it somehow compiles the exported symbols from shared objects w/ leading underscores */
#if defined (HAVE_LIBDL)
#undef HAVE_LIBDL
#endif

/* for the same reason as above we want the DLDAPI_DYLD and nothing but */
#ifndef DLDAPI_DYLD
#define DLDAPI_DYLD 1
#endif

#endif /* defined (__APPLE_) */

/* dlopen stuff */
#if defined(HAVE_LIBDL) || defined(__FreeBSD__)
#define DLDAPI_SVR4_DLFCN
#elif defined(HAVE_SHL_LOAD)
#define DLDAPI_HP_SHL
#elif defined(HAVE_DYLD)
#define DLDAPI_DYLD
#endif

#ifdef DLDAPI_DYLD
/* we want to alias the dlopen functions so they do not mess w/ the iODBC ones */
#define dlopen __virtuoso_dlopen
#define dlsym __virtuoso_dlsym
#define dlerror __virtuoso_dlerror
#define dlclose __virtuoso_dlclose
#endif

#if defined(DLDAPI_SVR4_DLFCN)
#include <dlfcn.h>
#elif defined(DLDAPI_AIX_LOAD)
#include <dlfcn.h>
#elif defined(DLDAPI_VMS_IODBC)
extern void FAR *iodbc_dlopen (char FAR * path, int mode);
extern void FAR *iodbc_dlsym (void FAR * hdll, char FAR * sym);
extern char FAR *iodbc_dlerror ();
extern int iodbc_dlclose (void FAR * hdll);
#else
extern void *dlopen (char * path, int mode);
extern void *dlsym (void * hdll, char * sym);
extern char *dlerror ();
extern int dlclose (void * hdll);
#endif

#ifdef DLDAPI_MACX
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "mach-o/dyld.h"

#ifndef FAR
#define FAR
#endif

#ifndef bool
enum bool { false, true };
#endif

#define RTLD_LAZY		0x1
#define RTLD_NOW		0x2
#define RTLD_LOCAL		0x4
#define RTLD_GLOBAL		0x8
#define RTLD_NOLOAD		0x10
#define RTLD_SHARED		0x20	/* not used, the default */
#define RTLD_UNSHARED		0x40
#define RTLD_NODELETE		0x80
#define RTLD_LAZY_UNDEF		0x100


enum ofile_type
{
  OFILE_UNKNOWN,
  OFILE_FAT,
  OFILE_ARCHIVE,
  OFILE_Mach_O
};

enum byte_sex
{
  UNKNOWN_BYTE_SEX,
  BIG_ENDIAN_BYTE_SEX,
  LITTLE_ENDIAN_BYTE_SEX
};


/*
 * The structure describing an architecture flag with the string of the flag
 * name, and the cputype and cpusubtype.
 */
struct arch_flag
{
  char *name;
  cpu_type_t cputype;
  cpu_subtype_t cpusubtype;
};

/*
 * The structure used by ofile_*() routines for object files.
 */
struct ofile
{
  char *file_name;		   /* pointer to name malloc'ed by ofile_map */
  char *file_addr;		   /* pointer to vm_allocate'ed memory       */
  unsigned long file_size;	   /* size of vm_allocate'ed memory          */
  enum ofile_type file_type;	   /* type of the file                       */

  struct fat_header *fat_header;   /* If a fat file these are filled in and  */
  struct fat_arch *fat_archs;	   /*   if needed converted to host byte sex */

  /*
   *  If this is a fat file then these are valid and filled in
   */
  unsigned long narch;		   /* the current architecture               */
  enum ofile_type arch_type;	   /* the type of file for this arch.        */
  struct arch_flag arch_flag;	   /* the arch_flag for this arch, the name  */
				   /*   field is pointing at space malloc'ed */
				   /*   by ofile_map.                        */

  /*
   *  If this structure is currently referencing an archive member or
   *  an object file that is an archive member these are valid and filled in.
   */
  unsigned long member_offset;	   /* logical offset to the member starting  */
  char *member_addr;		   /* pointer to the member contents         */
  unsigned long member_size;	   /* actual size of the member (not rounded)*/
  struct ar_hdr *member_ar_hdr;	   /* pointer to the ar_hdr for this member  */
  char *member_name;		   /* name of this member                    */
  unsigned long member_name_size;  /* size of the member name                */
  enum ofile_type member_type;	   /* the type of file for this member       */
  cpu_type_t archive_cputype;	   /* if the archive contains objects then   */
   cpu_subtype_t		   /*   these two fields reflect the object  */
   archive_cpusubtype;		   /*   at are in the archive.               */

  /*
   *  If this structure is currently referencing a dynamic library module
   *  these are valid and filled in.
   */
  struct dylib_module *modtab;	   /* the module table                       */
  unsigned long nmodtab;	   /* the number of module table entries     */
  struct dylib_module		   /* pointer to the dylib_module for this   */
      *dylib_module;		   /*   module                               */
  char *dylib_module_name;	   /* the name of the module                 */

  /*
   *  If this structure is currently referencing an object file these are
   *  valid and filled in.  The mach_header and load commands have been
   *  converted to the host byte sex if needed
   */
  char *object_addr;		   /* the address of the object file         */
  unsigned long object_size;	   /* the size of the object file            */
  enum byte_sex object_byte_sex;   /* the byte sex of the object file        */
  struct mach_header *mh;	   /* the mach_header of the object file     */
  struct load_command		   /* the start of the load commands         */
      *load_commands;
};


/*
 * The structure of a dlopen() handle.
 */
struct dlopen_handle
{
  dev_t dev;		/* the path's device and inode number from stat(2) */
  ino_t ino;
  int dlopen_mode;	/* current dlopen mode for this handle */
  int dlopen_count;	/* number of times dlopen() called on this handle */
  NSModule module;	/* the NSModule returned by NSLinkModule() */
  struct dlopen_handle *prev;
  struct dlopen_handle *next;
};
#endif /* DLDAPI_MACX */


#ifndef	RTLD_LAZY
#define	RTLD_LAZY       1
#endif

#ifndef	RTLD_GLOBAL
#define RTLD_GLOBAL   0x00100
#endif


#if defined(DLDAPI_VMS_IODBC)
#define	DLL_OPEN(dll)		(void*)iodbc_dlopen((char*)(dll), RTLD_LAZY)
#define	DLL_OPEN_GLOBAL(dll)	(void*)iodbc_dlopen((char*)(dll), RTLD_LAZY | RLTD_GLOBAL)
#define	DLL_PROC(hdll, sym)	(void*)iodbc_dlsym((void*)(hdll), (char*)sym)
#define	DLL_ERROR()		(char*)iodbc_dlerror()
#define	DLL_CLOSE(hdll)		iodbc_dlclose((void*)(hdll))
#else
#define	DLL_OPEN(dll)		(void*)dlopen((char*)(dll), RTLD_LAZY)
#define	DLL_OPEN_GLOBAL(dll)	(void*)dlopen((char*)(dll), RTLD_LAZY | RTLD_GLOBAL)
#define	DLL_PROC(hdll, sym)	(void*)dlsym((void*)(hdll), (char*)sym)
#define	DLL_ERROR()		(char*)dlerror()
#define	DLL_CLOSE(hdll)		dlclose((void*)(hdll))
#endif

#endif /* __DLF_H__ */
