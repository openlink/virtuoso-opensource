/*
 *  $Id$
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

#ifndef ISQL_TCHAR_H
#define ISQL_TCHAR_H

#ifndef WIN32
#define __cdecl
#endif

#ifdef _UNICODE

#if defined (linux)
#undef WITH_READLINE
#endif

#ifndef WIN32
#undef HAVE_SWPRINTF
#else
#undef HAVE_FPUTWS
#undef HAVE_WPRINTF
#undef HAVE_FWPRINTF
#undef HAVE_PUTWC
#undef HAVE_FGETWS
#endif

#ifdef HAVE_WCHAR_H
#include <wchar.h>
#endif

#ifdef HAVE_WCTYPE_H
#include <wctype.h>
#endif

#define _T(x) L##x
#define TCHAR wchar_t

#ifdef WIN32
#define PCT_S	_T("s")
#else
#define PCT_S	_T("ls")
#endif
#define _tmain wmain

#ifdef HAVE_WPRINTF
#define isqlt_tprintf	wprintf
#else
#define isqlt_tprintf	isqlt_wprintf
int isqlt_wprintf (const wchar_t * format, ...);
#endif

#ifdef HAVE_FPUTWS
#define isqlt_fputts  	fputws
#else
#define isqlt_fputts	isqlt_fputws
int isqlt_fputws (const wchar_t * s, FILE * stream);
#endif

#ifdef HAVE_WCSCMP
#define	isqlt_tcscmp	wcscmp
#else
#define	isqlt_tcscmp	isqlt_wcscmp
int isqlt_wcscmp (const wchar_t * s1, const wchar_t * s2);
#endif

#ifdef HAVE_PUTWC
#define	isqlt_puttc	putwc
#else
#define isqlt_puttc	isqlt_putwc
int isqlt_putwc (int c, FILE * stream);
#endif

#ifdef HAVE_WCSLEN
#define isqlt_tcslen	wcslen
#else
#define isqlt_tcslen	isqlt_wcslen
size_t isqlt_wcslen (const wchar_t * s);
#endif

#ifdef HAVE_WCSNCAT
#define isqlt_tcsncat	wcsncat
#else
#define isqlt_tcsncat	isqlt_wcsncat
wchar_t *isqlt_wcsncat (wchar_t * dest, const wchar_t * src, size_t n);
#endif

#ifdef HAVE_SWPRINTF
#define	isqlt_stprintf	swprintf
#else
#define isqlt_stprintf  isqlt_swprintf
int isqlt_swprintf (wchar_t * str, const wchar_t * format, ...);
#endif

#ifdef HAVE_WCSDUP
#define isqlt_tcsdup	wcsdup
#else
#define isqlt_tcsdup	isqlt_wcsdup
wchar_t *isqlt_wcsdup (const wchar_t * s);
#endif

#ifdef HAVE_WCSICMP
#define isqlt_tcsicmp	wcsicmp
#elif defined(HAVE_WCSCASECMP)
#define isqlt_tcsicmp	wcscasecmp
#else
#define isqlt_tcsicmp	isqlt_wcsicmp
int isqlt_wcsicmp (const wchar_t * s1, const wchar_t * s2);
#endif

#ifdef HAVE_WCSNICMP
#define isqlt_tcsnicmp	wcsnicmp
#elif defined (HAVE_WCSNCASECMP)
#define isqlt_tcsnicmp	wcsncasecmp
#else
#define isqlt_tcsnicmp	isqlt_wcsnicmp
int isqlt_wcsnicmp (const wchar_t * s1, const wchar_t * s2, size_t n);
#endif

#ifdef HAVE_WCSNCMP
#define isqlt_tcsncmp	wcsncmp
#else
#define isqlt_tcsncmp	isqlt_wcsncmp
int isqlt_wcsncmp (const wchar_t * s1, const wchar_t * s2, size_t n);
#endif

#ifdef HAVE_FWPRINTF
#define isqlt_ftprintf	fwprintf
#else
#define isqlt_ftprintf	isqlt_fwprintf
int isqlt_fwprintf (FILE * stream, const wchar_t * format, ...);
#endif

#ifdef HAVE_WPERROR
#define	isqlt_tperror	wperror
#else
#define isqlt_tperror	isqlt_wperror
void isqlt_wperror (const wchar_t * s);
#endif

#ifdef HAVE_WCSCPY
#define	isqlt_tcscpy	wcscpy
#else
#define isqlt_tcscpy	isqlt_wcscpy
wchar_t *isqlt_tcscpy (wchar_t * dest, const wchar_t * src);
#endif

#ifdef HAVE_WSYSTEM
#define isqlt_tsystem	wsystem
#else
#define isqlt_tsystem	isqlt_wsystem
int isqlt_wsystem (const wchar_t * string);
#endif

#ifdef HAVE_SWSCANF
#define isqlt_stscanf	swscanf
#else
#define isqlt_stscanf	isqlt_swscanf
int isqlt_swscanf (const wchar_t * str, const wchar_t * format, ...);
#endif

#ifdef HAVE_ISWSPACE
#define isqlt_istspace	iswspace
#else
#define isqlt_istspace	isqlt_iswspace
int isqlt_iswspace (int c);
#endif

#ifdef HAVE_ISWDIGIT
#define isqlt_istdigit	iswdigit
#else
#define isqlt_istdigit	isqlt_iswdigit
int isqlt_iswdigit (int c);
#endif

#ifdef HAVE_WCSNCPY
#define isqlt_tcsncpy	wcsncpy
#else
#define isqlt_tcsncpy	isqlt_wcsncpy
wchar_t *isqlt_wcsncpy (wchar_t * dest, const wchar_t * src, size_t n);
#endif

#ifdef HAVE_WTOI
#define isqlt_tstoi	wtoi
#else
#define isqlt_tstoi	isqlt_wtoi
int isqlt_wtoi (const wchar_t * nptr);
#endif

#ifdef HAVE_WTOL
#define isqlt_tstol	wtol
#else
#define isqlt_tstol	isqlt_wtol
long isqlt_wtol (const wchar_t * nptr);
#endif

#ifdef HAVE_WCSCHR
#define isqlt_tcschr	wcschr
#else
#define isqlt_tcschr	isqlt_wcschr
wchar_t *isqlt_wcschr (const wchar_t * s, int c);
#endif

#ifdef HAVE_WCSRCHR
#define isqlt_tcsrchr	wcsrchr
#else
#define isqlt_tcsrchr	isqlt_wcsrchr
wchar_t *isqlt_tcsrchr (const wchar_t * s, int c);
#endif

#ifdef HAVE_FGETWS
#define isqlt_fgetts	fgetws
#else
#define isqlt_fgetts	isqlt_fgetws
wchar_t *isqlt_fgetts (wchar_t * s, int size, FILE * stream);
#endif

#ifdef HAVE_WCSSTR
#define isqlt_tcsstr	wcsstr
#else
#define isqlt_tcsstr	isqlt_wcsstr
wchar_t *isqlt_wcsstr (const wchar_t * haystack, const wchar_t * needle);
#endif

#ifdef HAVE_WCSCAT
#define isqlt_tcscat	wcscat
#else
#define isqlt_tcscat	isqlt_wcscat
wchar_t *isqlt_wcscat (wchar_t * dest, const wchar_t * src);
#endif

#ifdef HAVE_PUTWCHAR
#define isqlt_puttchar	putwchar
#else
#define isqlt_puttchar	isqlt_putwchar
int isqlt_putwchar (wchar_t c);
#endif

#ifdef HAVE_PUTWS
#define isqlt_putts	putws
#else
#define isqlt_putts	isqlt_putws
int isqlt_putws (const wchar_t * s);
#endif

#ifdef HAVE_WFOPEN
#define isqlt_tfopen	wfopen
#else
#define	isqlt_tfopen	isqlt_wfopen
FILE *isqlt_wfopen (const wchar_t * path, const wchar_t * mode);
#endif

#ifdef HAVE_WGETENV
#define isqlt_tgetenv	wgetenv
#else
#define isqlt_tgetenv	isqlt_wgetenv
wchar_t *isqlt_wgetenv (const wchar_t * name);
#endif

#ifdef HAVE_CWPRINTF
#define isqlt_tcprintf	cwprintf
#else
#define isqlt_tcprintf	isqlt_cwprintf
int isqlt_cwprintf (const wchar_t * format, ...);
#endif

#define isqlt_tcstok(a,b,c) wcstok(a,b,c)

#ifdef HAVE_WEXECVP
#define isqlt_texecvp	wexecvp
#else
#define isqlt_texecvp	isqlt_wexecvp
int isqlt_wexecvp (const wchar_t * file, wchar_t * const argv[]);
#endif

#if !(defined (WIN32) || defined (HPUX_10) || defined (HPUX_11))
#ifdef HAVE_WGETPASS
#define isqlt_tgetpass	wgetpass
#else
#define isqlt_tgetpass	isqlt_wgetpass
wchar_t *isqlt_wgetpass (const wchar_t * prompt);
#endif
#endif

#if defined (SOLARIS)
#ifdef HAVE_WGETPASSPHRASE
#define isqlt_tgetpassphrase	wgetpassfrase
#else
#define isqlt_tgetpassphrase	isqlt_wgetpassphrase
wchar_t *isqlt_wgetpassphrase (const wchar_t * prompt);
#endif
#endif


#ifdef WIN32
#define wcsdup          _wcsdup
#define wcsicmp         _wcsicmp
#define wcsnicmp        _wcsnicmp
#define wperror         _wperror
#define wsystem         _wsystem
#define wtoi            _wtoi
#define wtol            _wtol
#define wfopen          _wfopen
#define wgetenv         _wgetenv
#define cwprintf	_cwprintf
#endif


#else

#define _T(x) x
#define TCHAR char
#define _tmain main
#define PCT_S	_T("s")
#ifndef SQL_C_TCHAR
#define SQL_C_TCHAR                             SQL_C_CHAR
#endif

#define isqlt_tprintf		printf
#define isqlt_fputts		fputs
#define isqlt_tcscmp		strcmp
#define isqlt_puttc		putc
#define isqlt_tcslen		strlen
#define isqlt_tcsncat		strncat
#define isqlt_stprintf		sprintf
#define isqlt_tcsdup		strdup
#define isqlt_tcsicmp		stricmp
#define isqlt_tcsnicmp		strnicmp
#define isqlt_tcsncmp		strncmp
#define isqlt_ftprintf		fprintf
#define isqlt_tperror		perror
#define isqlt_tcscpy		strcpy
#define isqlt_tsystem		system
#define isqlt_stscanf		sscanf
#define isqlt_istspace		isspace
#define isqlt_istdigit		isdigit
#define isqlt_tcsncpy		strncpy
#define isqlt_tstoi		atoi
#define isqlt_tstol		atol
#define isqlt_tcschr		strchr
#define isqlt_tcsrchr		strrchr
#define isqlt_fgetts		fgets
#define isqlt_tcsstr		strstr
#define isqlt_tcscat		strcat
#define isqlt_fwrite		fwrite
#define isqlt_puttchar		putchar
#define isqlt_putts		puts
#define isqlt_tfopen		fopen
#define isqlt_tgetenv		getenv
#define isqlt_texecvp		execvp
#ifdef HAVE_STRTOK_R
#define isqlt_tcstok(a,b,c)     strtok_r(a,b,c)
#else
#define isqlt_tcstok(a,b,c)     strtok(a,b)
#endif
#if !(defined (WIN32) || defined (HPUX_10) || defined (HPUX_11))
#define isqlt_tgetpass		getpass
#endif
#ifdef WIN32
#define isqlt_tcprintf		cprintf
#endif
#if defined (SOLARIS)
#define isqlt_tgetpassphrase	getpassfrase
#endif

#endif

#endif
