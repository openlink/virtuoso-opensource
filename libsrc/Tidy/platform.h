#ifndef __PLATFORM_H_010606
#define __PLATFORM_H_010606

/* platform.h

  (c) 1998-2000 (W3C) MIT, INRIA, Keio University
  See tidy.c for the copyright notice.
 *
 * $Id$
 *
 *  Changes are (C)Copyright 2001 OpenLink Software.
 *  All Rights Reserved.
 *
 *  The copyright above and this notice must be preserved in all
 *  copies of this source code.  The copyright above does not
 *  evidence any actual or intended publication of this source code.
 *
 *  This is unpublished proprietary trade secret of OpenLink Software.
 *  This source code may not be copied, disclosed, distributed, demonstrated
 *  or licensed except as authorized by OpenLink Software.
 *
*/

/*
  Uncomment and edit this #define if you want
  to specify the config file at compile-time

#define CONFIG_FILE "/etc/tidy_config.txt"
*/

/*
  Uncomment this if you are on a Unix system supporting
  the call getpwnam() and the HOME environment variable.
  It enables tidy to find config files named ~/.tidyrc
  and ~your/.tidyrc etc if the HTML_TIDY environment
  variable is not set. Contributed by Todd Lewis.

#define SUPPORT_GETPWNAM
*/
#ifdef HAVE_CONFIG_H

#include "config.h"
#endif

#include <ctype.h>
#include <stdio.h>
#include <setjmp.h>  /* for longjmp on error exit */
#include <stdlib.h>
#include <stdarg.h>  /* may need <varargs.h> for Unix V */
#include <string.h>
#include <assert.h>

#ifdef SUPPORT_GETPWNAM
#include <pwd.h>
#endif

#ifdef NEEDS_UNISTD_H
#include <unistd.h>  /* needed for unlink on some Unix systems */
#endif

/*
 Tidy preserves the last modified time for the files it
 cleans up. If your platform doesn't support <sys/utime.h>
 and the futime function, then set PRESERVEFILETIMES to 0
*/
#define PRESERVEFILETIMES 0

#if PRESERVEFILETIMES
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/utime.h>

/*
   MS Windows needs _ prefix for Unix file functions
   Tidy uses for preserving the lasted modified time
*/
#ifdef _WIN32
#define futime _futime
#define fstat _fstat
#define utimbuf _utimbuf
#define stat _stat
#endif /* _WIN32 */
#endif /* PRESERVEFILETIMES */

#ifdef _WIN64
typedef unsigned int uint;
#endif /* _WIN64 */

/* hack for gnu sys/types.h file  which defines uint and ulong */
/* you may need to delete the #ifndef and #endif on your system */

#ifndef __USE_MISC
#if !defined(_BSD_TYPES)
#ifdef __FreeBSD__
#include <sys/types.h>
#else
#ifndef _INCLUDE_HPUX_SOURCE
typedef unsigned int uint;
#endif /* _INCLUDE_HPUX_SOURCE */
#endif /* __FreeBSD__ */
typedef unsigned long ulong;
#endif /* _BSD_TYPES */
#endif  /* __USE_MISC */
typedef unsigned char byte;

typedef char *UTF8;

/*
  bool is a reserved word in some but
  not all C++ compilers depending on age
  work around is to avoid bool altogether
  by introducing a new enum called Bool
*/
typedef enum
{
   no,
   yes
} Bool;

/* for null pointers */
#define null 0

/*
  portability hack for deleting files - this is used
  in pprint.c for deleting superfluous slides.

  Win32 defines _unlink as per Unix unlink function.
*/

#ifdef WINDOWS
#define unlink _unlink
#endif

#ifdef BIF_TIDY

#include "Dk.h"

struct tidy_io_s
{
  lenmem_t tio_data;
  int tio_pos;
};

typedef struct tidy_io_s tidy_io_t;

#endif

#endif /* __PLATFORM_H_010606 */
