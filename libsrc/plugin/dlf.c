/*
 *  dlf.c
 *
 *  $Id$
 *
 *  dynamic load functions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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
#include "dlf.h"
#include <errno.h>

#ifdef	DLDAPI_DEFINED
#undef DLDAPI_DEFINED
#endif


/*********************************
 *
 *	SRV4 compatible dlopen
 *
 *********************************/
#ifdef	DLDAPI_SVR4_DLFCN
#define DLDAPI_DEFINED

DLF_VERSION ("SVR4 (dlfcn)");
#endif


/*********************************
 *
 *	HP/UX
 *
 *********************************/

#ifdef	DLDAPI_HP_SHL
#define	DLDAPI_DEFINED

DLF_VERSION ("HP/UX (shl)");

#include <dl.h>

void *
dlopen (char *path, int mode)
{
  return (void *) shl_load ((char *) (path), BIND_IMMEDIATE | BIND_NONFATAL, 0L);
}


void *
dlsym (void *hdll, char *sym)
{
  void *symaddr = 0;
  int ret;

#if 0
  /*
   *  VOS does not need a handle to itself
   */
  if (!hdll)
    hdll = (void *) PROG_HANDLE;
#endif

  /*
   * Remember, a driver may export calls as function pointers (i.e. with type TYPE_DATA) rather than as functions (i.e. with
   * type TYPE_PROCEDURE). Thus, to be safe, we uses TYPE_UNDEFINED to cover all of them.
   */
  ret = shl_findsym ((shl_t *) & hdll, sym, TYPE_UNDEFINED, &symaddr);

  if (ret == -1)
    return 0;

  return symaddr;
}


char *
dlerror ()
{
  extern char *strerror ();

  return strerror (errno);
}


int
dlclose (void *hdll)
{
  struct shl_descriptor d;

  /*
   *  As HP/UX does not use a reference counter for unloading,
   *  we can only unload the driver when it is loaded once.
   */
  if (shl_gethandle_r ((shl_t) hdll, &d) < 0 || d.ref_count > 1)
    {
      return 0;
    }
  return shl_unload ((shl_t) hdll);
}
#endif /* end of HP/UX Section */


/*********************************
 *
 *	IBM AIX
 *
 *********************************/

#ifdef	DLDAPI_AIX_LOAD
#define	DLDAPI_DEFINED
DLF_VERSION ("AIX (ldr)");

#include <sys/types.h>
#include <sys/ldr.h>
#include <sys/stat.h>
#include <nlist.h>

#ifndef	HTAB_SIZE
#define	HTAB_SIZE	256
#endif

#define	FACTOR		0.618039887	/* i.e. (sqrt(5) - 1)/2 */

#ifndef	ENTRY_SYM
#define	ENTRY_SYM	".__start"	/* default entry point for aix */
#endif

typedef struct slot_s
{
  char *sym;
  long fdesc[3];		/* 12 bytes function descriptor */
  struct slot_s *next;
}
slot_t;

/*
 *  Note: on AIX, a function pointer actually points to a function descriptor,
 *  a 12 bytes data.
 *
 *  The first 4 bytes is the virtual address of the function.
 *  The next 4 bytes is the virtual address of TOC (Table of Contents) of the
 *  object module the function belong to.
 *  The last 4 bytes are always 0 for C and Fortran functions.
 *
 *  Every object module has an entry point (which can be specified at link
 *  time by -e ld option). iODBC driver manager requires ODBC driver shared
 *  library always use the default entry point (so you shouldn't use -e ld
 *  option when creating a driver share library).
 *
 *  load() returns the function descriptor of a module's entry point.
 *  From which we can calculate function descriptors of other functions in the
 *  same module by using the fact that the load() does not change the relative
 *  offset of functions to their module entry point (i.e the offset in memory
 *  loaded by load() will be as same as in the module library file).
 */

typedef slot_t *hent_t;
typedef struct nlist nlist_t;
typedef struct stat stat_t;

typedef struct obj
{
  int dev;			/* device id */
  int ino;			/* inode number */
  char *path;			/* file name */
  int (*pentry) ();		/* entry point of this share library */
  int refn;			/* number of reference */
  hent_t htab[HTAB_SIZE];
  struct obj *next;
}
obj_t;

static char *errmsg = 0;

static void
init_htab (hent_t * ht)
/* initialize a hashing table */
{
  int i;

  for (i = 0; i < HTAB_SIZE; i++)
    ht[i] = (slot_t *) 0;

  return;
}


static void
clean_htab (hent_t * ht)
/* free all slots */
{
  int i;
  slot_t *ent;
  slot_t *tent;

  for (i = 0; i < HTAB_SIZE; i++)
    {
      for (ent = ht[i]; ent;)
	{
	  tent = ent->next;

	  free (ent->sym);
	  free (ent);

	  ent = tent;
	}

      ht[i] = 0;
    }

  return;
}


static int
hash (char *sym)
{
  int a, key;
  double f;

  if (!sym || !*sym)
    return 0;

  for (key = *sym; *sym; sym++)
    {
      key += *sym;
      a = key;

      key = (int) ((a << 8) + (key >> 8));
      key = (key > 0) ? key : -key;
    }

  f = key * FACTOR;
  a = (int) f;

  return (int) ((HTAB_SIZE - 1) * (f - a));
}


static hent_t
search (hent_t * htab, char *sym)
/* search hashing table to find a matched slot */
{
  int key;
  slot_t *ent;

  key = hash (sym);

  for (ent = htab[key]; ent; ent = ent->next)
    {
      if (!strcmp (ent->sym, sym))
	return ent;
    }

  return 0;			/* no match */
}


static void
insert (hent_t * htab, slot_t * ent)
/* insert a new slot to hashing table */
{
  int key;

  key = hash (ent->sym);

  ent->next = htab[key];
  htab[key] = ent;

  return;
}


static slot_t *
slot_alloc (char *sym)
/* allocate a new slot with symbol */
{
  slot_t *ent;

  ent = (slot_t *) malloc (sizeof (slot_t));

  ent->sym = (char *) malloc (strlen (sym) + 1);

  if (!ent->sym)
    {
      free (ent);
      return 0;
    }
  strcpy (ent->sym, sym);

  return ent;
}


static obj_t *obj_list = 0;

void *
dlopen (char *file, int mode)
{
  stat_t st;
  obj_t *pobj;
  char buf[1024];

  if (!file || !*file)
    {
      errno = EINVAL;
      return 0;
    }
  errno = 0;
  errmsg = 0;

  if (stat (file, &st))
    return 0;

  for (pobj = obj_list; pobj; pobj = pobj->next)
    /* find a match object */
    {
      if (pobj->ino == st.st_ino && pobj->dev == st.st_dev)
	{
	  /*
	   * found a match. increase its reference count and return its address
	   */
	  pobj->refn++;
	  return pobj;
	}
    }

  pobj = (obj_t *) malloc (sizeof (obj_t));

  if (!pobj)
    return 0;

  pobj->path = (char *) malloc (strlen (file) + 1);

  if (!pobj->path)
    {
      free (pobj);
      return 0;
    }
  strcpy (pobj->path, file);

  pobj->dev = st.st_dev;
  pobj->ino = st.st_ino;
  pobj->refn = 1;

  pobj->pentry = (int (*)()) load (file, 0, 0);

  if (!pobj->pentry)
    {
      free (pobj->path);
      free (pobj);
      return 0;
    }
  init_htab (pobj->htab);

  pobj->next = obj_list;
  obj_list = pobj;

  return pobj;
}


int
dlclose (void *hobj)
{
  obj_t *pobj = (obj_t *) hobj;
  obj_t *tpobj;
  int match = 0;

  if (!hobj)
    {
      errno = EINVAL;
      return -1;
    }
  errno = 0;
  errmsg = 0;

  if (pobj == obj_list)
    {
      pobj->refn--;

      if (pobj->refn)
	return 0;

      match = 1;
      obj_list = pobj->next;
    }
  for (tpobj = obj_list; !match && tpobj; tpobj = tpobj->next)
    {
      if (tpobj->next == pobj)
	{
	  pobj->refn--;

	  if (pobj->refn)
	    return 0;

	  match = 1;
	  tpobj->next = pobj->next;
	}
    }

  if (match)
    {
      unload ((void *) (pobj->pentry));
      clean_htab (pobj->htab);
      free (pobj->path);
      free (pobj);
    }
  return 0;
}


char *
dlerror ()
{
  extern char *sys_errlist[];

  if (!errmsg || !errmsg[0])
    {
      if (errno >= 0)
	return sys_errlist[errno];

      return "";
    }
  return errmsg;
}


void *
dlsym (void *hdl, char *sym)
{
  nlist_t nl[3];
  obj_t *pobj = (obj_t *) hdl;
  slot_t *ent;
  int (*fp) ();
  long lbuf[3];

  if (!hdl || !(pobj->htab) || !sym || !*sym)
    {
      errno = EINVAL;
      return 0;
    }
  errno = 0;
  errmsg = 0;

  ent = search (pobj->htab, sym);

  if (ent)
    return ent->fdesc;

#define	n_name	_n._n_name

  nl[0].n_name = ENTRY_SYM;
  nl[1].n_name = sym;
  nl[2].n_name = 0;

  /*
   *  There is a potential problem here.
   *  If application did not pass a full path name, and changed the working
   *  directory after the load(), then nlist() will be unable to open the
   *  original shared library file to resolve the symbols. There are 3 ways
   *  to working round this:
   *   1. convert to full pathname in driver manager.
   *   2. applications always pass driver's full path name.
   *   3. if driver itself do not support SQLGetFunctions(), call it with
   *      SQL_ALL_FUNCTIONS as flag immediately after SQLConnect(),
   *      SQLDriverConnect() and SQLBrowseConnect() to force the driver
   *      manager resolving all will be used symbols.
   */
  if (nlist (pobj->path, nl) == -1)
    return 0;

  if (!nl[0].n_type && !nl[0].n_value)
    {
      errmsg = "can't locate module entry symbol";
      return 0;
    }

  /*
   *  Note: On AIX 3.x if the object library is not built with -g compiling
   *  option, .n_type field is always 0. While on 4.x it will be 32.
   *  On AIX 4.x, if the symbol is a entry point, n_value will be 0.
   *  However, one thing is for sure that if a symbol does not exist in the
   *  file, both .n_type and .n_value would be 0.
   */
  if (!nl[1].n_type && !nl[1].n_value)
    {
      errmsg = "symbol does not exist in this module";
      return 0;
    }
  ent = slot_alloc (sym);

  if (!ent)
    return 0;

  /* catch it with a slot in the hashing table */
  insert (pobj->htab, ent);

  memcpy (ent->fdesc, pobj->pentry, sizeof (ent->fdesc));

  /*
   *  now ent->fdesc[0] is the virtual address of entry point and
   *  ent->fdesc[1] is the TOC of the module
   *
   *  let's calculate the virtual address of the symbol by adding a relative
   *  offset getting from the module file symbol table, i.e
   *
   *   function virtual address = entry point virtual address +
   *    ( function offset in file - entry point offset in file )
   */
  (ent->fdesc)[0] = (ent->fdesc)[0] + (nl[1].n_value - nl[0].n_value);

  /* return the function descriptor */
  return ent->fdesc;
}
#endif /* end of IBM AIX Section */


/*********************************
 *
 *	Windows 3.x, 95, NT
 *
 *********************************/

#ifdef	DLDAPI_WINDOWS
#define	DLDAPI_DEFINED
DLF_VERSION ("Windows (loadlibrary)");

#include <windows.h>

void *
dlopen (char * dll, int mode)
{
  HINSTANCE hint;

  if (dll == NULL)
    {
      return (void *) GetWindowLongPtr (NULL, GWLP_HINSTANCE);
    }
  hint = LoadLibrary (dll);

  if (hint < (HINSTANCE) HINSTANCE_ERROR)
    {
      return NULL;
    }
  return (void *) hint;
}


void *
dlsym (void * hdll, char * sym)
{
  return (void *) GetProcAddress (hdll, sym);
}


char *
dlerror ()
{
  static char lpMsgBuf[512];
  if (!FormatMessage (FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, NULL, GetLastError (), MAKELANGID (LANG_NEUTRAL, SUBLANG_DEFAULT),	/* Default language */
	  (LPTSTR) & lpMsgBuf, sizeof (lpMsgBuf), NULL))
    {
      /* Handle the error. */
      return "";
    }
  /* Process any inserts in lpMsgBuf. */
  /* ... */

  return (char *) &(lpMsgBuf[0]);
}


int
dlclose (void * hdll)
{
  FreeLibrary ((HINSTANCE) hdll);
  return 0;
}
#endif /* end of Windows family */


/***********************************
 *
 * 	VMS
 *
 ***********************************/

#ifdef VMS
#define	DLDAPI_DEFINED
DLF_VERSION ("VMS");

#include <stdio.h>
#include <descrip.h>
#include <starlet.h>
#include <ssdef.h>
#include <libdef.h>
#include <lib$routines>
#include <rmsdef.h>
#include <fabdef.h>
#include <namdef.h>

#ifndef LIB$M_FIS_MIXCASE
#define LIB$M_FIS_MIXCASE 1<<4
#endif

typedef struct
{
  struct dsc$descriptor_s filename_d;
  struct dsc$descriptor_s image_d;
  char filename[NAM$C_MAXRSS];	/* $PARSEd image name */
}
dll_t;

/*
 *  The following static int contains the last VMS error returned. It is kept
 *  static so that dlerror() can get it. This method is dangerous if you have
 *  threaded applications, but this is the way the UNIX dlopen() etc
 *  is defined.
 */
static int saved_status = SS$_NORMAL;
static char dlerror_buf[256];


static int
__virtuoso_find_image_symbol (struct dsc$descriptor_s *filename_d,
    struct dsc$descriptor_s *symbol_d, void **rp, struct dsc$descriptor_s *image_d, int flag)
{
  lib$establish (lib$sig_to_ret);
  return lib$find_image_symbol (filename_d, symbol_d, rp, image_d, flag);
}


void *
dlopen (char *path, int unused_flag)
{
  int status;
  dll_t *dll;
  struct FAB imgfab;
  struct NAM imgnam;
  static char defimg[] = "SYS$SHARE:.EXE";

  if (path == NULL)
    {
      saved_status = SS$_UNSUPPORTED;
      return NULL;
    }
  dll = malloc (sizeof (dll_t));
  if (dll == NULL)
    {
      saved_status = SS$_INSFMEM;
      return NULL;
    }
  imgfab = cc$rms_fab;
  imgfab.fab$l_fna = path;
  imgfab.fab$b_fns = strlen (path);
  imgfab.fab$w_ifi = 0;
  imgfab.fab$l_dna = defimg;
  imgfab.fab$b_dns = sizeof (defimg);
  imgfab.fab$l_fop = FAB$M_NAM;
  imgfab.fab$l_nam = &imgnam;
  imgnam = cc$rms_nam;
  imgnam.nam$l_esa = dll->filename;
  imgnam.nam$b_ess = NAM$C_MAXRSS;
  status = sys$parse (&imgfab);
  if (!(status & 1))
    {
      free (dll);
      saved_status = status;
      return NULL;
    }
  dll->filename_d.dsc$b_dtype = DSC$K_DTYPE_T;
  dll->filename_d.dsc$b_class = DSC$K_CLASS_S;
  dll->filename_d.dsc$a_pointer = imgnam.nam$l_name;
  dll->filename_d.dsc$w_length = imgnam.nam$b_name;
  dll->image_d.dsc$b_dtype = DSC$K_DTYPE_T;
  dll->image_d.dsc$b_class = DSC$K_CLASS_S;
  dll->image_d.dsc$a_pointer = dll->filename;
  dll->image_d.dsc$w_length = imgnam.nam$b_esl;

  /*
   *  VMS does not have the concept of first opening a shared library and then
   *  asking for symbols; the LIB$FIND_IMAGE_SYMBOL routine does both.
   *  Since I want my implementation of dlopen() to return an error if the
   *  shared library can not be loaded, I try to find a dummy symbol in the
   *  library.
   */
  dlsym (dll, "THIS_ROUTINE_MIGHT_NOT_EXIST");
  if (!((saved_status ^ LIB$_KEYNOTFOU) & ~7))
    {
      saved_status = SS$_NORMAL;
    }
  if (saved_status & 1)
    {
      return dll;
    }
  else
    {
      free (dll);
      return NULL;
    }
}


void *
dlsym (void *hdll, char *sym)
{
  int status;
  dll_t *dll;
  struct dsc$descriptor_s symbol_d;
  void *rp;

  dll = hdll;
  if (dll == NULL)
    return NULL;

  symbol_d.dsc$b_dtype = DSC$K_DTYPE_T;
  symbol_d.dsc$b_class = DSC$K_CLASS_S;
  symbol_d.dsc$a_pointer = sym;
  symbol_d.dsc$w_length = strlen (sym);
  status = __virtuoso_find_image_symbol (&dll->filename_d, &symbol_d, &rp, &dll->image_d, 0);
  if (!((saved_status ^ LIB$_KEYNOTFOU) & ~7))
    {
      status = __virtuoso_find_image_symbol (&dll->filename_d, &symbol_d, &rp, &dll->image_d, LIB$M_FIS_MIXCASE);
    }
  if (status & 1)
    {
      return rp;
    }
  else
    {
      saved_status = status;
      return NULL;
    }
}


char *
dlerror ()
{
  struct dsc$descriptor desc;
  short outlen;
  int status;

  if (saved_status & 1)
    {
      return NULL;
    }
  desc.dsc$b_dtype = DSC$K_DTYPE_T;
  desc.dsc$b_class = DSC$K_CLASS_S;
  desc.dsc$a_pointer = dlerror_buf;
  desc.dsc$w_length = sizeof (dlerror_buf);
  status = sys$getmsg (saved_status, &outlen, &desc, 15, 0);
  if (status & 1)
    {
      dlerror_buf[outlen] = '\0';
    }
  else
    {
      snprintf (dlerror_buf, sizeof (dlerror_buf), "Message number %8X", saved_status);
    }
  saved_status = SS$_NORMAL;
  return (dlerror_buf);
}


int
dlclose (void *hdll)
{
  /*
   *  Not really implemented since VMS does not support unloading images.
   *  The hdll pointer is released though.
   */
  free (hdll);
  return 0;
}
#endif /* VMS */


/*********************************
 *
 *	Apple MacOS X Rhapsody
 *
 *********************************/
#ifdef	DLDAPI_DYLD
#define	DLDAPI_DEFINED
DLF_VERSION ("Mac OS X (dyld)");
#include <stdio.h>
#include <mach-o/dyld.h>

static void
undefined_symbol_handler (const char *symbolName)
{
  fprintf (stderr, "dyld found undefined symbol: %s\n", symbolName);

  abort ();
}


static NSModule
multiple_symbol_handler (NSSymbol s, NSModule old, NSModule new)
{
  /*
   *  Since we can't unload symbols, we're going to run into this
   *  every time we reload a module. Workaround here is to just
   *  rebind to the new symbol, and forget about the old one.
   *  This is crummy, because it's basically a memory leak.
   */

  return (new);
}


static void
linkEdit_symbol_handler (NSLinkEditErrors c, int errorNumber, const char *fileName, const char *errorString)
{
  fprintf (stderr, "dyld errors during link edit for file %s\n%s\n", fileName, errorString);

  abort ();
}


void *
dlopen (char *path, int mode)
{
  NSObjectFileImage image;
  NSLinkEditErrorHandlers handlers;
  NSModule handle = NULL;
  int i;

  /*
   *  Install error handler
   */
  handlers.undefined = undefined_symbol_handler;
#if !defined (NSLINKMODULE_OPTION_PRIVATE)
  handlers.multiple = multiple_symbol_handler;
#endif
  handlers.linkEdit = linkEdit_symbol_handler;

  NSInstallLinkEditErrorHandlers (&handlers);

  /*
   *  Load object
   */
  i = NSCreateObjectFileImageFromFile (path, &image);
  if (i != NSObjectFileImageSuccess)
    {
      static char *ErrorStrings[] = {
	"%s(%d): Object Image Load Failure\n",
	"%s(%d): Object Image Load Success\n",
	"%s(%d): Not an recognizable object file\n",
	"%s(%d): No valid architecture\n",
	"%s(%d): Object image has an invalid format\n",
	"%s(%d): Invalid access (permissions?)\n",
	"%s(%d): Unknown error code from NSCreateObjectFileImageFromFile\n",
      };

      if (i < 0 || i > 6)
	i = 6;

      fprintf (stderr, ErrorStrings[i], path, i);
    }
  else
    {
#if !defined (NSLINKMODULE_OPTION_PRIVATE)
      handle = NSLinkModule (image, path, TRUE);
#else
      handle = NSLinkModule (image, path, NSLINKMODULE_OPTION_PRIVATE);
#endif
    }

  return (void *) handle;
}


void *
dlsym (void *hdll, char *sym)
{
  NSSymbol symbol;
  char sym2[255];

  snprintf (sym2, sizeof (sym2), "_%s", sym);

#if !defined (NSLINKMODULE_OPTION_PRIVATE)
  if (NSIsSymbolNameDefined (sym2))
    {
      symbol = NSLookupAndBindSymbol (sym2);

      return NSAddressOfSymbol (symbol);
    }
  return NULL;
#else
  symbol = NSLookupSymbolInModule ((NSModule) hdll, sym2);

  return NSAddressOfSymbol (symbol);
#endif
}


char *
dlerror ()
{
  return NULL;
}


int
dlclose (void *hdll)
{
  NSUnLinkModule (hdll, FALSE);
  return 0;
}
#endif /* end of Rhapsody Section */


/*********************************
 *
 *	Apple MacOS X Rhapsody
 *
 *********************************/
#ifdef	DLDAPI_MACX
#define	DLDAPI_DEFINED
DLF_VERSION ("Mac OS X 10.x (dyld)");

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "mach-o/dyld.h"

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

static struct dlopen_handle *dlopen_handles = NULL;
static const struct dlopen_handle main_program_handle = { 0 };
static char *dlerror_pointer = NULL;

/*
 * NSMakePrivateModulePublic() is not part of the public dyld API so we define
 * it here.  The internal dyld function pointer for
 * __dyld_NSMakePrivateModulePublic is returned so thats all that matters to get
 * the functionality need to implement the dlopen() interfaces.
 */
static int
NSMakePrivateModulePublic (NSModule module)
{
  static int (*p) (NSModule module) = NULL;

  if (p == NULL)
    _dyld_func_lookup ("__dyld_NSMakePrivateModulePublic", (void *) &p);
  if (p == NULL)
    {
#ifdef DEBUG
      printf ("_dyld_func_lookup of __dyld_NSMakePrivateModulePublic " "failed\n");
#endif
      return (FALSE);
    }
  return (p (module));
}


/*
 * dlopen() the MacOS X version of the FreeBSD dlopen() interface.
 */
void *
dlopen (char * path, int mode)
{
  void *retval;
  struct stat stat_buf;
  NSObjectFileImage objectFileImage;
  NSObjectFileImageReturnCode ofile_result_code;
  NSModule module;
  struct dlopen_handle *p;
  unsigned long options;
  NSSymbol NSSymbol;
  void (*init) (void);
  static char errbuf[640];

  dlerror_pointer = NULL;

  /*
   * A NULL path is to indicate the caller wants a handle for the
   * main program.
   */
  if (path == NULL)
    {
      retval = (void *) &main_program_handle;
      return (retval);
    }
  /* see if the path exists and if so get the device and inode number */
  if (stat (path, &stat_buf) == -1)
    {
      dlerror_pointer = strerror (errno);
      return (NULL);
    }
  /*
   * If we do not want an unshared handle see if we already have a handle
   * for this path.
   */
  if ((mode & RTLD_UNSHARED) != RTLD_UNSHARED)
    {
      p = dlopen_handles;
      while (p != NULL)
	{
	  if (p->dev == stat_buf.st_dev && p->ino == stat_buf.st_ino)
	    {
	      /* skip unshared handles */
	      if ((p->dlopen_mode & RTLD_UNSHARED) == RTLD_UNSHARED)
		continue;
	      /*
	       * We have already created a handle for this path.  The
	       * caller might be trying to promote an RTLD_LOCAL handle
	       * to a RTLD_GLOBAL.  Or just looking it up with
	       * RTLD_NOLOAD.
	       */
	      if ((p->dlopen_mode & RTLD_LOCAL) == RTLD_LOCAL && (mode & RTLD_GLOBAL) == RTLD_GLOBAL)
		{
		  /* promote the handle */
		  if (NSMakePrivateModulePublic (p->module) == TRUE)
		    {
		      p->dlopen_mode &= ~RTLD_LOCAL;
		      p->dlopen_mode |= RTLD_GLOBAL;
		      p->dlopen_count++;
		      return (p);
		    }
		  else
		    {
		      dlerror_pointer = "can't promote handle from RTLD_LOCAL to RTLD_GLOBAL";
		      return (NULL);
		    }
		}
	      p->dlopen_count++;
	      return (p);
	    }
	  p = p->next;
	}
    }
  /*
   * We do not have a handle for this path if we were just trying to
   * look it up return NULL to indicate we do not have it.
   */
  if ((mode & RTLD_NOLOAD) == RTLD_NOLOAD)
    {
      dlerror_pointer = "no existing handle for path RTLD_NOLOAD test";
      return (NULL);
    }
  /* try to create an object file image from this path */
  ofile_result_code = NSCreateObjectFileImageFromFile (path, &objectFileImage);
  if (ofile_result_code != NSObjectFileImageSuccess)
    {
      switch (ofile_result_code)
	{
	case NSObjectFileImageFailure:
	  dlerror_pointer = "object file setup failure";
	  return (NULL);

	case NSObjectFileImageInappropriateFile:
	  dlerror_pointer = "not a Mach-O MH_BUNDLE file type";
	  return (NULL);

	case NSObjectFileImageArch:
	  dlerror_pointer = "no object for this architecture";
	  return (NULL);

	case NSObjectFileImageFormat:
	  dlerror_pointer = "bad object file format";
	  return (NULL);

	case NSObjectFileImageAccess:
	  dlerror_pointer = "can't read object file";
	  return (NULL);

	default:
	  dlerror_pointer = "unknown error from " "NSCreateObjectFileImageFromFile()";
	  return (NULL);
	}
    }

  /* try to link in this object file image */
  options = NSLINKMODULE_OPTION_NONE | NSLINKMODULE_OPTION_PRIVATE | NSLINKMODULE_OPTION_RETURN_ON_ERROR;
  if ((mode & RTLD_NOW) == RTLD_NOW)
    options |= NSLINKMODULE_OPTION_BINDNOW;
  module = NSLinkModule (objectFileImage, path, options);
  NSDestroyObjectFileImage (objectFileImage);
  if (module == NULL)
    {
      NSLinkEditErrors lerr;
      int errNum;
      const char *fname;
      const char *errStr;
      NSLinkEditError (&lerr, &errNum, &fname, &errStr);
      snprintf (errbuf, sizeof(errbuf), "NSLinkModule() failed for dlopen() ([%.256s][%.256s])", fname, errStr);
      dlerror_pointer = errbuf;
      return (NULL);
    }

  /*
   * If the handle is to be global promote the handle.  It is done this
   * way to avoid multiply defined symbols.
   */
  if ((mode & RTLD_GLOBAL) == RTLD_GLOBAL)
    {
      if (NSMakePrivateModulePublic (module) == FALSE)
	{
	  dlerror_pointer = "can't promote handle from RTLD_LOCAL to " "RTLD_GLOBAL";
	  return (NULL);
	}
    }
  p = malloc (sizeof (struct dlopen_handle));
  if (p == NULL)
    {
      dlerror_pointer = "can't allocate memory for the dlopen handle";
      return (NULL);
    }
  /* fill in the handle */
  p->dev = stat_buf.st_dev;
  p->ino = stat_buf.st_ino;
  if (mode & RTLD_GLOBAL)
    p->dlopen_mode = RTLD_GLOBAL;
  else
    p->dlopen_mode = RTLD_LOCAL;
  p->dlopen_mode |= (mode & RTLD_UNSHARED) | (mode & RTLD_NODELETE) | (mode & RTLD_LAZY_UNDEF);
  p->dlopen_count = 1;
  p->module = module;
  p->prev = NULL;
  p->next = dlopen_handles;
  if (dlopen_handles != NULL)
    dlopen_handles->prev = p;
  dlopen_handles = p;

  /* call the init function if one exists */
  NSSymbol = NSLookupSymbolInModule (p->module, "__init");
  if (NSSymbol != NULL)
    {
      init = NSAddressOfSymbol (NSSymbol);
      init ();
    }
  return (p);
}


/*
 * dlsym() the MacOS X version of the FreeBSD dlopen() interface.
 */
void *
dlsym (void * handle, char * symbol)
{
  struct dlopen_handle *dlopen_handle, *p;
  char symbol2[1024];
  NSSymbol NSSymbol;
  void *address;

  snprintf (symbol2, "_%s", symbol);

  dlopen_handle = (struct dlopen_handle *) handle;

  /*
   * If this is the handle for the main program do a global lookup.
   */
  if (dlopen_handle == (struct dlopen_handle *) &main_program_handle)
    {
      if (NSIsSymbolNameDefined (symbol2) == TRUE)
	{
	  NSSymbol = NSLookupAndBindSymbol (symbol2);
	  address = NSAddressOfSymbol (NSSymbol);
	  dlerror_pointer = NULL;
	  return (address);
	}
      else
	{
	  dlerror_pointer = "symbol not found";
	  return (NULL);
	}
    }
  /*
   * Find this handle and do a lookup in just this module.
   */
  p = dlopen_handles;
  while (p != NULL)
    {
      if (dlopen_handle == p)
	{
	  NSSymbol = NSLookupSymbolInModule (p->module, symbol2);
	  if (NSSymbol != NULL)
	    {
	      address = NSAddressOfSymbol (NSSymbol);
	      dlerror_pointer = NULL;
	      return (address);
	    }
	  else
	    {
	      dlerror_pointer = "symbol not found";
	      return (NULL);
	    }
	}
      p = p->next;
    }

  dlerror_pointer = "bad handle passed to dlsym()";
  return (NULL);
}


/*
 * dlerror() the MacOS X version of the FreeBSD dlopen() interface.
 */
char *
dlerror (void)
{
  const char *p;

  p = (const char *) dlerror_pointer;
  dlerror_pointer = NULL;
  return (p);
}


/*
 * dlclose() the MacOS X version of the FreeBSD dlopen() interface.
 */
int
dlclose (void * handle)
{
  struct dlopen_handle *p, *q;
  unsigned long options;
  NSSymbol NSSymbol;
  void (*fini) (void);

  dlerror_pointer = NULL;
  q = (struct dlopen_handle *) handle;
  p = dlopen_handles;
  while (p != NULL)
    {
      if (p == q)
	{
	  /* if the dlopen() count is not zero we are done */
	  p->dlopen_count--;
	  if (p->dlopen_count != 0)
	    return (0);

	  /* call the fini function if one exists */
	  NSSymbol = NSLookupSymbolInModule (p->module, "__fini");
	  if (NSSymbol != NULL)
	    {
	      fini = NSAddressOfSymbol (NSSymbol);
	      fini ();
	    }
	  /* unlink the module for this handle */
	  options = 0;
	  if (p->dlopen_mode & RTLD_NODELETE)
	    options |= NSUNLINKMODULE_OPTION_KEEP_MEMORY_MAPPED;
	  if (p->dlopen_mode & RTLD_LAZY_UNDEF)
	    options |= NSUNLINKMODULE_OPTION_RESET_LAZY_REFERENCES;
	  if (NSUnLinkModule (p->module, options) == FALSE)
	    {
	      dlerror_pointer = "NSUnLinkModule() failed for dlclose()";
	      return (-1);
	    }
	  if (p->prev != NULL)
	    p->prev->next = p->next;
	  if (p->next != NULL)
	    p->next->prev = p->prev;
	  if (dlopen_handles == p)
	    dlopen_handles = p->next;
	  free (p);
	  return (0);
	}
      p = p->next;
    }
  dlerror_pointer = "invalid handle passed to dlclose()";
  return (-1);
}

#endif /* end of Rhapsody Section */


/*********************************
 *
 *	Macintosh
 *
 *********************************/
#ifdef	DLDAPI_MAC
#define	DLDAPI_DEFINED
DLF_VERSION ("Macintosh");

#include <CodeFragments.h>
#include <strconv.h>

static char *msg_error = NULL;

void *
dlopen (char *dll, int mode)
{
#ifdef __POWERPC__
  CFragConnectionID conn_id;
  Ptr main_addr;
  Str255 name;
  OSErr err;

  if (dll == NULL)
    {
      msg_error = "Library name not valid.";
      return NULL;
    }

  if ((err = GetSharedLibrary ((unsigned char *) str_to_Str255 (dll),
	      kPowerPCCFragArch, kLoadCFrag, &conn_id, &main_addr, name)) != noErr)
    {
      msg_error = "Library cannot be loaded.";
      return NULL;
    }

  msg_error = NULL;
  return (void *) conn_id;
#else
  CFragConnectionID conn_id;
  Ptr main_addr;
  Str255 name;
  OSErr err;

  if (dll == NULL)
    {
      msg_error = "Library name not valid.";
      return NULL;
    }

  if ((err = GetSharedLibrary ((unsigned char *) str_to_Str255 (dll),
	      kMotorola68KCFragArch, kLoadCFrag, &conn_id, &main_addr, name)) != noErr)
    {
      msg_error = "Library cannot be loaded.";
      return NULL;
    }

  msg_error = NULL;
  return (void *) conn_id;
#endif
}


void *
dlsym (void *hdll, char *sym)
{
#ifdef __POWERPC__
  Ptr symbol;
  CFragSymbolClass symbol_type;
  OSErr err;

  if (sym == NULL)
    {
      msg_error = "Symbol name not valid.";
      return NULL;
    }

  if ((err = FindSymbol ((CFragConnectionID) hdll, (unsigned char *) str_to_Str255 (sym), &symbol, &symbol_type)) != noErr)
    {
      msg_error = "Symbol cannot be loaded.";
      return NULL;
    }

  msg_error = NULL;
  return symbol;
#else
  Ptr symbol;
  CFragSymbolClass symbol_type;

  if (sym == NULL)
    {
      msg_error = "Symbol name not valid.";
      return NULL;
    }

  if (FindSymbol ((CFragConnectionID) hdll, (unsigned char *) str_to_Str255 (sym), &symbol, &symbol_type) != noErr)
    {
      msg_error = "Symbol cannot be loaded.";
      return NULL;
    }

  msg_error = NULL;
  return symbol;
#endif
}


char *
dlerror ()
{
  return (msg_error) ? msg_error : "No error detected.";
}


int
dlclose (void *hdll)
{
#ifdef __POWERPC__
#if 0
  /*
   *  It should be something like this but some applications like Office 2001 have a problem with that.
   *  Just let the Mac unload the library when the application stops.
   */
  if (CloseConnection ((CFragConnectionID *) hdll))
    {
      msg_error = "Library cannot be unloaded.";
      return 1;
    }
msg_error = NULL;
#endif
#else
  if (CloseConnection ((CFragConnectionID *) hdll))
    {
      msg_error = "Library cannot be unloaded.";
      return 1;
    }

  msg_error = NULL;
#endif
  return 0;
}


#endif /* end of Macintosh family */


/*********************************
 *
 *	BeOS
 *
 *********************************/
#ifdef	DLDAPI_BE
#define	DLDAPI_DEFINED
DLF_VERSION ("BeOS");


#include <kernel/image.h>
#include <be/support/Errors.h>

static char *msg_error = NULL;

void *
dlopen (char *dll, int mode)
{
  image_id dll_id;

  if (dll == NULL)
    {
      msg_error = "Library name not valid.";
      return NULL;
    }
  dll_id = load_add_on (dll);

  if (dll_id == B_ERROR)
    {
      msg_error = "Library cannot be loaded.";
      return NULL;
    }
  msg_error = NULL;
  return (void *) dll_id;
}


void *
dlsym (void *hdll, char *sym)
{
  void *address = NULL;

  if (sym == NULL)
    {
      msg_error = "Symbol name not valid.";
      return NULL;
    }
  if (get_image_symbol ((image_id) hdll, sym, B_SYMBOL_TYPE_ANY, &address) != B_OK)
    {
      msg_error = "Symbol cannot be loaded.";
      return NULL;
    }
  msg_error = NULL;
  return address;
}


char *
dlerror ()
{
  return (msg_error) ? msg_error : "No error detected.";
}


int
dlclose (void *hdll)
{
  if (unload_add_on ((image_id) hdll) != B_OK)
    {
      msg_error = "Library cannot be unloaded.";
      return 1;
    }
  msg_error = NULL;
  return 0;
}

#endif /* end of BeOS */



/***********************************
 *
 * 	other platforms
 *
 ***********************************/

#ifndef DLDAPI_DEFINED
#error	"dynamic load editor undefined"
#endif
