/*
 *  ccdefs.c
 *
 *  $Id$
 *
 *  Determine & report the Makeconfig variables
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

#include <stdio.h>
#include <ctype.h>
#include <string.h>


/*
 *  Check for toupper problems
 */
int
working_toupper ()
{
  /*
   *  Toupper ok?
   */
  if (toupper ('9') == '9')
    return 1;
  else
    {
      fputs ("NOTE: toupper() gives problems\n", stderr);
      return 0;
    }
}


int
main (argc, argv)
int argc;
char **argv;
{
  static char CCDEFS[800];
  static char CCWARN[800];
  static char CCOPT[800];
  static char CCDEBUG[800];
  static char CCLIBS[800];

  CCDEFS[0] = CCWARN[0] = CCOPT[0] = CCDEBUG[0] = CCLIBS[0] = 0;

  /*
   *  Build releases by default
   */
  strcat (CCDEBUG, "-DNDEBUG");

  /*
   *  Check ctypes
   */
  if (!working_toupper ())
    strcat (CCDEFS, "-DBROKEN_CTYPES ");

  if (sizeof (void *) == 8)
    strcat (CCDEFS, "-DPOINTER_64 ");

#if defined (__GNUC__)
  /*
   *  For GNU C COMPILER (Linux ea)
   *  --with-pthreads works on linux redhat >= 5
   */

# if !defined (M_I386) && !defined (__i386__) && defined (NOTDEF)
  /*
   *  GNU C library bug work around (See spromo.c)
   *  libudbc.a causes core dumps when stdarg.h doesn't work...
   */
  strcat (CCDEFS, "-D__i386__ ");
# endif

# if defined (i386)
  strcat (CCOPT, "-fomit-frame-pointer ");
# endif
# if (__GNUC__ > 3)
  strcat (CCOPT, "-fno-strict-aliasing ");
# endif
  strcat (CCOPT, "-O2 ");
  strcat (CCWARN, "-Wall ");
  strcat (CCLIBS, "`gcc -print-libgcc-file-name` ");


  /* NATIVE C COMPILERS FOR VARIOUS PLATFORMS */

#elif defined (_AIX)
  /*
   *  For IBM Aix (tested with 4.2)
   *  --with-pthreads works if configured with CC="cc_r" ./configure
   */
  strcat (CCOPT, "-O2 ");

#elif defined (__osf__)
  /*
   *  For DEC OSF (tested with 3.2, 4.0)
   *  --with-pthreads works on 3.2
   *  --with-pthreads fails on 4.0
   */
  strcat (CCOPT, "-O2 ");
  strcat (CCDEFS, "-std1 -readonly_strings ");
  strcat (CCWARN, "-verbose ");

#elif defined (__hpux)
  /*
   *  For HP/UX (tested with 10.0 and 11.0)
   *  --with-pthreads : only for release 11
   */
  strcat (CCDEFS, "-D_PROTOTYPES ");
  strcat (CCDEFS, "-D_INCLUDE_HPUX_SOURCE ");
  strcat (CCDEFS, "-D_INCLUDE_POSIX_SOURCE ");
  strcat (CCDEFS, "-D_INCLUDE_XOPEN_SOURCE ");
  strcat (CCDEFS, "-D_INCLUDE_XOPEN_SOURCE_EXTENDED ");
  /* strcat (CCDEFS, "-DSUSPICIOUS_C_COMPILER "); */
  strcat (CCDEFS, "-Dconst= ");
  strcat (CCDEFS, "-Aa +ESlit +e ");
  strcat (CCOPT, "-O ");

#elif defined (__sgi)
  /*
   *  For Silicon Graphics IRIX (tested with 6.4 with MIPSProC compiler)
   *  --with-pthreads works
   */
# if _MIPS_SZLONG == 32
  /* 32 bit mode */
  strcat (CCDEFS, "-DSTDC_HEADERS -D_BSD_TYPES -D_BSD_COMPAT -common ");
  strcat (CCOPT, "-O2 -use_readonly_const");

# elif _MIPS_SZLONG == 64
  /* 64 bit mode - TODO Make this work! */
#  error 64 bit is broken because of struct timeval assumptions

# else
#  error *****************************************************
#  error *** Please restart with : CC="cc -32" ./configure ***
#  error *****************************************************
# endif

#elif defined (sun)
  /*
   *  For Sun Solaris (tested with 5.5.1 with Sun PRO C compiler - SUNWspro)
   *  --with-pthreads works
   */
  strcat (CCOPT, "-O ");

#elif defined (_SCO_DS)
  /*
   *  For SCO 5 ODT
   *  No support for pthreads
   */
  strcat (CCOPT, "-O ");
  strcat (CCDEFS, "-belf -Kalloca,i486 ");
  strcat (CCWARN, "-w3 ");

#else /* No special rules for this platform */

  strcat (CCOPT, "-O ");

#endif

  /*
   *  Output Makeconfig flags
   */
  printf ("CCOPT=\"%s\"\n", CCOPT);
  printf ("CCDEFS=\"%s\"\n", CCDEFS);
  printf ("CCWARN=\"%s\"\n", CCWARN);
  printf ("CCDEBUG=\"%s\"\n", CCDEBUG);
  printf ("CCLIBS=\"%s\"\n", CCLIBS);

  return 0;
}
