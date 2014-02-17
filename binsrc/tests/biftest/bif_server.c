/*
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

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#define uint16  unsigned short
#define uint8   unsigned char
#include <ksrvext.h>

#if defined (MONO) && defined (CLR)
#error Cannot combine MONO and CLR hosting in one binary
#endif

#if defined (PHP)
extern void init_func_php ();
extern char *phplib_version_string ();
#endif

#if defined (JAVAVM)
extern void bif_init_func_javavm ();
extern char *javavm_version_string ();
#endif
#if defined (MONO) || defined (CLR)
extern void bif_init_func_clr ();
#endif

static void
bif_init_java_clr_php (void)
{
#if defined (MONO) || defined (CLR)
  bif_init_func_clr ();
#endif
#if defined (JAVAVM)
  bif_init_func_javavm ();
#endif
#if defined (PHP)
  init_func_php ();
#endif
}

#ifdef MALLOC_DEBUG
void   dbg_malloc_enable(void);
#endif

#if defined (MONO)
extern char *mono_outp_virt_init ();
#endif

#if defined (CLR)
extern char * clr_version_string ();
#endif

int
main (int argc, char *argv[])
{
  static char brand_buffer[200];
#ifdef MALLOC_DEBUG
  dbg_malloc_enable ();
#endif

#if defined (MONO) && defined (PHP) && defined (JAVAVM)
  sprintf (brand_buffer, "%s%s %s, Java VM %s and PHP%s", _MONO_NAME_, mono_outp_virt_init (),
      _MONO_VERSION_, javavm_version_string (), phplib_version_string ());
#elif defined (MONO) && defined (JAVAVM)
  sprintf (brand_buffer, "%s%s %s and Java VM %s", _MONO_NAME_, mono_outp_virt_init (),
      _MONO_VERSION_, javavm_version_string ());
#elif defined (MONO) && defined (PHP)
  sprintf (brand_buffer, "%s%s %s and PHP%s", _MONO_NAME_, mono_outp_virt_init (), _MONO_VERSION_, phplib_version_string ());
#elif defined (PHP) && defined (JAVAVM)
  sprintf (brand_buffer, "Java VM %s and PHP%s", javavm_version_string (), phplib_version_string ());
#elif defined (MONO)
  sprintf (brand_buffer, "%s%s %s", _MONO_NAME_, mono_outp_virt_init (), _MONO_VERSION_);
#elif defined (CLR) && defined (PHP) && defined (JAVAVM)
  sprintf (brand_buffer, ".NET CLR %s, Java VM %s and PHP%s", clr_version_string (), javavm_version_string (), phplib_version_string ());
#elif defined (CLR) && defined (JAVAVM)
  sprintf (brand_buffer, ".NET CLR %s and Java VM %s", clr_version_string (), javavm_version_string ());
#elif defined (CLR) && defined (PHP)
  sprintf (brand_buffer, ".NET CLR %s and PHP%s", clr_version_string (), phplib_version_string ());
#elif defined (PHP) && defined (JAVAVM)
  sprintf (brand_buffer, "Java VM %s and PHP%s", javavm_version_string (), phplib_version_string ());
#elif defined (MONO)
  sprintf (brand_buffer, "%s%s %s", _MONO_NAME_, mono_outp_virt_init (), _MONO_VERSION_);
#elif defined (JAVAVM)
  sprintf (brand_buffer, "Java VM %s", javavm_version_string ());
#elif defined (PHP)
  sprintf (brand_buffer, "PHP%s", phplib_version_string ());
#elif defined (CLR)
  sprintf (brand_buffer, ".NET CLR %s", clr_version_string ());
#endif

  build_set_special_server_model (brand_buffer);
  VirtuosoServerSetInitHook (bif_init_java_clr_php);
  return VirtuosoServerMain (argc, argv);
}
