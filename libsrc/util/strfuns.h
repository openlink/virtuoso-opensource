/*
 *  strfuns.h
 *
 *  $Id$
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
 *  
*/

#ifndef _STRFUNS_H
#define _STRFUNS_H

#ifndef VMS
struct tm;	/* VAX C complains on this type of declarations */
#endif


BEGIN_CPLUSPLUS

char *	cslentry (const char *list, int entry);
int	cslnumentries (const char *list);
int	csllookup (const char *list, const char *expr);
int	make_env (const char *id, const char *value);
int	stricmp (const char *, const char *);
int	strnicmp (const char *, const char *, size_t);
char *	strlwr (char *);
char *	strupr (char *);
char *	rtrim (char *);
const char *ltrim (const char *);
char *	strindex (const char *str, const char *find);
void	strinsert (char *where, const char *what);
char *	strexpect (char *keyword, char *source);
int	build_argv_from_string (const char *s, int *pargc, char ***pargv);
void	free_argv (char **argv);
char *	fntodos (char *filename);
char *	fnundos (char *filename);
char *	fnqualify (char *filename);
char *	fnsearch (const char *filename, const char *path);
char *	quotelist (char* szIn);
int	StrCopyIn (char **poutStr, char *inStr, ssize_t size);
int	StrCopyInUQ (char **poutStr, char *inStr, ssize_t size);
char *	strquote (char *s, ssize_t size, int quoteChr);
char *	strunquote (char *s, ssize_t size, int quoteChr);

#if !defined (HAVE_STRDUP) && !defined (MALLOC_DEBUG)
#undef strdup
char *	strdup (const char *);
#endif

#ifndef HAVE_STPCPY
#undef stpcpy
char *	stpcpy (char *, const char *);
#endif

#ifndef HAVE_STRFTIME
size_t	strftime (char *, size_t, const char *, const struct tm *);
#endif

#ifndef HAVE_MEMMOVE
void *	memmove (void *dest, const void *src, size_t count);
#endif

char *	opl_strerror (int err);

END_CPLUSPLUS

#endif
