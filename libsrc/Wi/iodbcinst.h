/*
 *  iodbcinst.h
 *
 *  $Id$
 *
 *  iODBC Installer defines
 *
 *  The iODBC driver manager.
 *
 *  Copyright (C) 1996-2019 OpenLink Software <iodbc@openlinksw.com>
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU Library General Public
 *  License along with this library; if not, write to the Free
 *  Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 */

#ifndef _IODBCINST_H
#define _IODBCINST_H


/*
 *  Trigger odbccat.c to add DSN handling bif functions
 */
#ifndef HAVE_ODBCINST_H
#define HAVE_ODBCINST_H
#endif

/*
 *  Set default specification to ODBC 3.00
 */
#ifndef ODBCVER
#define ODBCVER 0x0300
#endif

/*
 *  Backward compatible types for Windows
 */
#if !defined (UNIX_ODBC) /* already in sqltypes.h */
#if !defined (WIN32) && !defined (__SQLUNX)
typedef const char *LPCSTR;
typedef char *LPSTR;
typedef unsigned short WORD;
typedef unsigned long DWORD;
typedef DWORD *LPDWORD;
typedef void *HWND;
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef EXPORT
#define EXPORT
#endif

#ifndef SYS_ODBCINST_INI
#  if defined(__BEOS__)
#    define SYS_ODBCINST_INI	"/boot/beos/etc/odbcinst.ini"
#  endif
#  if defined(macintosh)
#    ifdef __POWERPC__
#      define SYS_ODBCINST_INI "Boot:System Folder:Preferences:ODBC Installer Preferences PPC"
#    else
#      define SYS_ODBCINST_INI "Boot:System Folder:Preferences:ODBC Installer Preferences"
#    endif
#  else
#    define SYS_ODBCINST_INI	"/etc/odbcinst.ini"
#  endif
#endif

#ifndef SYS_ODBC_INI
#  if defined(__BEOS__)
#    define SYS_ODBC_INI	"/boot/beos/etc/odbc.ini"
#  endif
#  if defined(macintosh)
#    ifdef __POWERPC__
#      define SYS_ODBC_INI "Boot:System Folder:Preferences:ODBC Preferences PPC"
#    else
#      define SYS_ODBC_INI "Boot:System Folder:Preferences:ODBC Preferences"
#    endif
#  else
#    define SYS_ODBC_INI	"/etc/odbc.ini"
#  endif
#endif

#define USERDSN_ONLY  0
#define SYSTEMDSN_ONLY  1

#ifdef WIN32
#define INSTAPI __stdcall
#else
#define INSTAPI
#endif

/*
 *  SQLConfigDataSource
 */
#define ODBC_ADD_DSN			1
#define ODBC_CONFIG_DSN			2
#define ODBC_REMOVE_DSN			3

#if (ODBCVER >= 0x0250)
#define ODBC_ADD_SYS_DSN 		4
#define ODBC_CONFIG_SYS_DSN		5
#define ODBC_REMOVE_SYS_DSN		6
#if (ODBCVER >= 0x0300)
#define	 ODBC_REMOVE_DEFAULT_DSN	7
#endif  /* ODBCVER >= 0x0300 */

/* install request flags */
#define	ODBC_INSTALL_INQUIRY		1
#define ODBC_INSTALL_COMPLETE		2

/* config driver flags */
#define ODBC_INSTALL_DRIVER			1
#define ODBC_REMOVE_DRIVER			2
#define ODBC_CONFIG_DRIVER			3
#define ODBC_CONFIG_DRIVER_MAX	100
#endif

/* SQLGetConfigMode and SQLSetConfigMode flags */
#if (ODBCVER >= 0x0300)
#define ODBC_BOTH_DSN		0
#define ODBC_USER_DSN		1
#define ODBC_SYSTEM_DSN		2
#endif  /* ODBCVER >= 0x0300 */

/* SQLInstallerError code */
#if (ODBCVER >= 0x0300)
#define ODBC_ERROR_GENERAL_ERR                   1
#define ODBC_ERROR_INVALID_BUFF_LEN              2
#define ODBC_ERROR_INVALID_HWND                  3
#define ODBC_ERROR_INVALID_STR                   4
#define ODBC_ERROR_INVALID_REQUEST_TYPE          5
#define ODBC_ERROR_COMPONENT_NOT_FOUND           6
#define ODBC_ERROR_INVALID_NAME                  7
#define ODBC_ERROR_INVALID_KEYWORD_VALUE         8
#define ODBC_ERROR_INVALID_DSN                   9
#define ODBC_ERROR_INVALID_INF                  10
#define ODBC_ERROR_REQUEST_FAILED               11
#define ODBC_ERROR_INVALID_PATH                 12
#define ODBC_ERROR_LOAD_LIB_FAILED              13
#define ODBC_ERROR_INVALID_PARAM_SEQUENCE       14
#define ODBC_ERROR_INVALID_LOG_FILE             15
#define ODBC_ERROR_USER_CANCELED                16
#define ODBC_ERROR_USAGE_UPDATE_FAILED          17
#define ODBC_ERROR_CREATE_DSN_FAILED            18
#define ODBC_ERROR_WRITING_SYSINFO_FAILED       19
#define ODBC_ERROR_REMOVE_DSN_FAILED            20
#define ODBC_ERROR_OUT_OF_MEM                   21
#define ODBC_ERROR_OUTPUT_STRING_TRUNCATED      22
#define ODBC_ERROR_DRIVER_SPECIFIC		23
#endif /* ODBCVER >= 0x0300 */

/*
 *  Function Prototypes
 */

BOOL INSTAPI
SQLGetConfigMode (
    UWORD* pwConfigMode);

BOOL INSTAPI
SQLInstallDriverEx (
    LPCSTR lpszDriver,
    LPCSTR lpszPathIn,
    LPSTR lpszPathOut,
    WORD cbPathOutMax,
    WORD* pcbPathOut,
    WORD fRequest,
    LPDWORD lpdwUsageCount);

RETCODE INSTAPI
SQLInstallerError (
    WORD iError,
    DWORD* pfErrorCode,
    LPSTR lpszErrorMsg,
    WORD cbErrorMsgMax,
    WORD* pcbErrorMsg);

RETCODE INSTAPI
SQLPostInstallerError (
    DWORD fErrorCode,
    LPSTR szErrorMsg);

BOOL INSTAPI
SQLInstallTranslatorEx (
    LPCSTR lpszTranslator,
    LPCSTR lpszPathIn,
    LPSTR lpszPathOut,
    WORD cbPathOutMax,
    WORD* pcbPathOut,
    WORD fRequest,
    LPDWORD lpdwUsageCount);

BOOL INSTAPI
SQLReadFileDSN (
    LPCSTR lpszFileName,
    LPCSTR lpszAppName,
    LPCSTR lpszKeyName,
    LPSTR lpszString,
    WORD cbString,
    WORD* pcbString);

BOOL INSTAPI
SQLWriteFileDSN (
    LPCSTR lpszFileName,
    LPCSTR lpszAppName,
    LPCSTR lpszKeyName,
    LPSTR lpszString);

BOOL INSTAPI
SQLSetConfigMode (
    UWORD wConfigMode);

BOOL INSTAPI SQLInstallODBC (
    HWND hwndParent,
    LPCSTR lpszInfFile,
    LPCSTR lpszSrcPath,
    LPCSTR lpszDrivers);

BOOL INSTAPI SQLManageDataSources (HWND hwndParent);

BOOL INSTAPI SQLCreateDataSource (
    HWND hwndParent,
    LPCSTR lpszDSN);

BOOL INSTAPI SQLGetTranslator (
    HWND hwnd,
    LPSTR lpszName,
    WORD cbNameMax,
    WORD * pcbNameOut,
    LPSTR lpszPath,
    WORD cbPathMax,
    WORD * pcbPathOut,
    DWORD * pvOption);

/*  Low level APIs
 *  NOTE: The high-level APIs should always be used. These APIs
 *        have been left for compatibility.
 */
BOOL INSTAPI SQLInstallDriver (
    LPCSTR lpszInfFile,
    LPCSTR lpszDriver,
    LPSTR lpszPath,
    WORD cbPathMax,
    WORD * pcbPathOut);

BOOL INSTAPI SQLInstallDriverManager (
    LPSTR lpszPath,
    WORD cbPathMax,
    WORD * pcbPathOut);

BOOL INSTAPI SQLGetInstalledDrivers (
    LPSTR lpszBuf,
    WORD cbBufMax,
    WORD * pcbBufOut);

BOOL INSTAPI SQLGetAvailableDrivers (
    LPCSTR lpszInfFile,
    LPSTR lpszBuf,
    WORD cbBufMax,
    WORD * pcbBufOut);

BOOL INSTAPI SQLConfigDataSource (
    HWND hwndParent,
    WORD fRequest,
    LPCSTR lpszDriver,
    LPCSTR lpszAttributes);

BOOL INSTAPI SQLRemoveDefaultDataSource (void);

BOOL INSTAPI SQLWriteDSNToIni (
    LPCSTR lpszDSN,
    LPCSTR lpszDriver);

BOOL INSTAPI SQLRemoveDSNFromIni (LPCSTR lpszDSN);

BOOL INSTAPI SQLValidDSN (LPCSTR lpszDSN);

BOOL INSTAPI SQLWritePrivateProfileString (
    LPCSTR lpszSection,
    LPCSTR lpszEntry,
    LPCSTR lpszString,
    LPCSTR lpszFilename);

int INSTAPI SQLGetPrivateProfileString (
    LPCSTR lpszSection,
    LPCSTR lpszEntry,
    LPCSTR lpszDefault,
    LPSTR lpszRetBuffer,
    int cbRetBuffer,
    LPCSTR lpszFilename);

BOOL INSTAPI SQLRemoveDriverManager (LPDWORD lpdwUsageCount);

BOOL INSTAPI SQLInstallTranslator (
    LPCSTR lpszInfFile,
    LPCSTR lpszTranslator,
    LPCSTR lpszPathIn,
    LPSTR lpszPathOut,
    WORD cbPathOutMax,
    WORD * pcbPathOut,
    WORD fRequest,
    LPDWORD lpdwUsageCount);

BOOL INSTAPI SQLRemoveTranslator (
    LPCSTR lpszTranslator,
    LPDWORD lpdwUsageCount);

BOOL INSTAPI SQLRemoveDriver (
    LPCSTR lpszDriver,
    BOOL fRemoveDSN,
    LPDWORD lpdwUsageCount);

BOOL INSTAPI SQLConfigDriver (
    HWND hwndParent,
    WORD fRequest,
    LPCSTR lpszDriver,
    LPCSTR lpszArgs,
    LPSTR lpszMsg,
    WORD cbMsgMax,
    WORD * pcbMsgOut);

/* Driver specific Setup APIs called by installer */

typedef BOOL INSTAPI (*pConfigDSNFunc) (
    HWND hwndParent,
    WORD fRequest,
    LPCSTR lpszDriver,
    LPCSTR lpszAttributes);

typedef BOOL INSTAPI (*pConfigDriverFunc) (
    HWND hwndParent,
    WORD fRequest,
    LPCSTR lpszDriver,
    LPCSTR lpszArgs,
    LPSTR lpszMsg,
    WORD cbMsgMax,
    WORD * pcbMsgOut);

typedef BOOL INSTAPI (*pConfigTranslatorFunc) (
    HWND hwndParent,
    DWORD *pvOption);

BOOL INSTAPI ConfigDSN (
    HWND hwndParent,
    WORD fRequest,
    LPCSTR lpszDriver,
    LPCSTR lpszAttributes);

BOOL INSTAPI ConfigTranslator (HWND hwndParent,
    DWORD * pvOption);

BOOL INSTAPI ConfigDriver (
    HWND hwndParent,
    WORD fRequest,
    LPCSTR lpszDriver,
    LPCSTR lpszArgs,
    LPSTR lpszMsg,
    WORD cbMsgMax,
    WORD * pcbMsgOut);

#ifdef __cplusplus
}
#endif

#endif /* _IODBCINST_H */
