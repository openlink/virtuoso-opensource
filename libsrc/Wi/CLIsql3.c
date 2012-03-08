/*
 *  CLIsql3.c
 *
 *  $Id$
 *
 *  ODBC API - SQLDriverConnect & SQLConnect
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

#ifdef WIN32
#ifdef __MINGW32__
#include <wchar.h>
#endif
#include <tchar.h>		/* SQLGetPrivateProfileString */
#endif

#include "Dk.h"
#include "CLI.h"
#include "sqlver.h"
#include "libutil.h"
#include "multibyte.h"

#ifndef WIN32
#include <pwd.h>
#endif

#ifndef WIN32

# if defined (__APPLE__)
#  undef _T
# endif

# ifdef UNICODE

# define _T(A) L##A

typedef wchar_t TCHAR;
# if defined (HAVE_WCSCASECMP)
#  define _tcsicmp wcscasecmp
# elif defined (HAVE_WCSICMP)
#  define _tcsicmp wcsicmp
# else
#  define _tcsicmp virt_wcscasecmp
# endif

# ifdef HAVE_WCSDUP
#  define _tcsdup wcsdup
# else
#  define _tcsdup virt_wcsdup
# endif

# define _tcscpy wcscpy
# define _tcsncpy wcsncpy
# define _tcslen wcslen
# define _tcscmp wcscmp
# define _ttoi(a) wide_atoi ((caddr_t) (a))

#else /*WIN32*/

# define _T(A) A

typedef char TCHAR;

# define _tcsicmp stricmp
# define _tcsdup strdup
# define _tcscpy strcpy
# define _tcsncpy strncpy
# define _tcslen strlen
# define _tcscmp strcmp
# define _ttoi atoi

# endif /* UNICODE */
#endif /* WIN32*/

#ifdef MALLOC_DEBUG
#define _tcscpy_size_ck(dest, src, len)  \
	do { \
	    if (((len) - 1) < _tcslen (src)) \
		GPF_T; \
	    _tcsncpy ((dest), (src), (len) - 1); \
	    (dest)[(len) - 1] = 0; \
	} while (0)
#else
#define _tcscpy_size_ck(dest, src, len)  \
	do { \
	    _tcsncpy ((dest), (src), (len) - 1); \
	    (dest)[(len) - 1] = 0; \
	} while (0)
#endif

#define _tcscpy_ck(dest, src)  \
	_tcscpy_size_ck (dest, src, sizeof (dest) / sizeof (TCHAR))

#define _tcscpy_box_ck(dest, src)  \
	_tcscpy_size_ck (dest, src, box_length (dest) / sizeof (TCHAR))


/*
 *  NOTE : DSN_TRANSLATION must be defined when building an ODBC driver.
 *
 *  If not defined, this file will be used for the libwic, the internal
 *  library that the dbms server uses for native connections.
 */
#ifdef DSN_TRANSLATION
# ifdef WIN32
#  include <odbcinc.h>
#  include <odbcinst.h>		/* SQLGetPrivateProfileString */
#  include "virtodbc.h"		/* resource identifiers */
# endif
#endif

#ifndef TRUE
# define TRUE 1
# define FALSE 0
#endif

#define OPTION_TRUE(X)	((X) && (X) != 'N' && (X) != '0')

static SQLRETURN SQL_API virtodbc__SQLDriverConnect (SQLHDBC hdbc, HWND hwnd, SQLTCHAR * szConnStrIn, SQLSMALLINT cbConnStrIn, SQLTCHAR * szConnStrOut, SQLSMALLINT cbConnStrOutMax, SQLSMALLINT * pcbConnStrOutMax, SQLUSMALLINT fDriverCompletion);


#define DEFAULT_DATABASE_PER_USER _T("<Server Default>")


typedef struct
{
  TCHAR *shortName;
  TCHAR *longName;
  short maxLength;
  TCHAR *defVal;
} CfgRecord;

typedef struct
{
  int supplied;
  TCHAR *data;
} CfgData;


typedef enum
{
  oDSN,
  oDESC,
  oHOST,
  oUID,
  oPWD,
  oDRIVER,
  oDATABASE,
  oCHARSET,
  oDAYLIGHT,
#ifdef _SSL
  oENCRYPT,
  oPWDCLEAR,
  oSERVERCERT,
#endif
  oROUNDROBIN,
  oFORCE_DBMS_NAME,
  oIsolationLevel,
  oNoSystemTables,
  oTreatViewsAsTables,
  oWideUTF16
} CfgOptions;


/*
 *  If you make any changes here, please reflect them
 *  in the ~/driver/virtodbc.c file as well (setup)
 */
static CfgRecord attrs[] = {
  /* shortName                  longName                  maxLength 	defVal */
  { _T ("DSN"),			NULL,				63,	_T ("")},
  { NULL,			_T ("Description"),		511,	_T ("")},
  { _T ("HOST"),		_T ("Address"),			160,	_T ("localhost:1111")},
#if defined (WIN32) && !defined (UDBC)
  { _T ("UID"),			_T ("LastUser"),		32,	_T ("dba")},
  { _T ("PWD"),			NULL,				32,	_T ("")},
#else
  { _T ("UID"),			_T ("UserName"),		32,	_T ("dba")},
  { _T ("PWD"),			_T ("Password"),		32,	_T ("")},
#endif
  { _T ("DRIVER"),		NULL,				160,	_T ("")},
  { _T ("DATABASE"),		_T ("Database"),		64,	DEFAULT_DATABASE_PER_USER},
  { _T ("CHARSET"),		_T ("Charset"),			200,	_T ("")},
  { _T ("DAYLIGHT"),		_T ("Daylight"),		64,	_T ("")},
#ifdef _SSL
  { _T ("ENCRYPT"),		_T ("Encrypt"),			511,	_T ("")},
  { _T ("PWDCLEAR"),		_T ("PWDClearText"),		32,	_T ("")},
  { _T ("SERVERCERT"),		_T ("ServerCert"),		511,	_T ("")},
#endif
  { _T ("ROUNDROBIN"),		_T ("RoundRobin"),		32,	_T ("")},
  { _T ("FORCE_DBMS_NAME"),	_T ("ForceDBMSName"),		511,	_T ("")},
  { _T ("IsolationLevel"),	_T ("IsolationLevel"),		32,	_T ("")},
  { _T ("NoSystemTables"),	_T ("NoSystemTables"),		32,	_T ("")},
  { _T ("TreatViewsAsTables"),	_T ("TreatViewsAsTables"),	32,	_T ("")},
  { _T ("WideAsUTF16"),		_T ("WideAsUTF16"),		32,	_T ("")}
};


#ifdef UNICODE
#ifdef WIN32
static char *
virt_wide_to_ansi (TCHAR * in)
{
  int len;
  caddr_t ret;

  if (!in)
    return NULL;

  len = WideCharToMultiByte (CP_ACP, 0, in, -1, NULL, 0, NULL, NULL);

  if (len == 0)
    return NULL;

  ret = dk_alloc_box (len, DV_SHORT_STRING);

  WideCharToMultiByte (CP_ACP, 0, in, -1, ret, len, NULL, NULL);

  return ret;
}


static TCHAR *
virt_ansi_to_wide (char *in)
{
  int len;
  TCHAR *ret;

  if (!in)
    return NULL;

  len = MultiByteToWideChar (CP_ACP, 0, in, -1, NULL, 0);

  if (len == 0)
    return NULL;

  ret = (TCHAR *) dk_alloc_box (len * sizeof (TCHAR), DV_SHORT_STRING);

  MultiByteToWideChar (CP_ACP, 0, in, -1, ret, len);

  return ret;
}
#else
#  define virt_wide_to_ansi cli_box_wide_to_narrow
#  define virt_ansi_to_wide cli_box_narrow_to_wide
#endif
#define free_wide_buffer(A) dk_free_box((box_t) (A))
#else
#define virt_wide_to_ansi(A) A
#define virt_ansi_to_wide(A) A
#define free_wide_buffer(A)
#endif

#define PUT_CONN_OPT(opt, o_inx) \
	if (opt) \
	  { \
	    TCHAR *wide = (TCHAR *) virt_ansi_to_wide ((char *) opt); \
	    \
	    cfgdata[o_inx].data = _tcsdup (wide); \
	    cfgdata[o_inx].supplied = TRUE; \
	    free_wide_buffer (wide); \
	    \
	    dk_free_box ((box_t) opt); \
	    opt = NULL; \
	  }


static void
PutConnectionOptions (CfgData cfgdata[], cli_connection_t * con)
{
  PUT_CONN_OPT (con->con_qualifier, oDATABASE);
  PUT_CONN_OPT (con->con_charset, oCHARSET);
#ifdef _SSL
  PUT_CONN_OPT (con->con_encrypt, oENCRYPT);
#endif
}


static void
ParseOptions (CfgData cfgdata[], TCHAR * s, int clean_up)
{
  TCHAR *cp, *n;
  TCHAR *section;
  int count;
  int i;

  if (clean_up)
    for (i = 0; i < sizeof (attrs) / sizeof (attrs[0]); i++)
      {
	if (cfgdata[i].data)
	  free (cfgdata[i].data);
	cfgdata[i].data = NULL;
	cfgdata[i].supplied = FALSE;
      }

  if (s == NULL)
    return;

  for (count = 0; *s; count++)
    {
      for (cp = s; *cp && *cp != ';'; cp++)
	;
      if (*cp)
	{
	  *cp = 0;
	  n = cp + 1;
	}
      else
	n = cp;
      for (cp = s; *cp && *cp != '='; cp++)
	;
      if (*cp)
	{
	  *cp++ = 0;
	  if (_tcsicmp (s, attrs[oDATABASE].shortName) || _tcsicmp (cp, DEFAULT_DATABASE_PER_USER))
	    for (i = 0; i < sizeof (attrs) / sizeof (attrs[0]); i++)
	      {
		if (attrs[i].shortName && !_tcsicmp (attrs[i].shortName, s))
		  {
		    cfgdata[i].data = _tcsdup (cp);
		    cfgdata[i].supplied = TRUE;
		    break;
		  }
	      }
	}
      /*
       *  Handle missing DSN=... from the beginning:
       *  'dsn_ora7;UID=scott;PWD=tiger'
       */
      else if (count == 0)
	{
	  cfgdata[oDSN].data = _tcsdup (s);
	  cfgdata[oDSN].supplied = TRUE;
	}
      s = n;
    }

  section = cfgdata[oDSN].data;

  if (section == NULL || !section[0])
    section = _T ("Default");

#if defined (DSN_TRANSLATION) && !defined (WIN32)
  {
    PCONFIG pConfig, cfg_odbc_sys, cfg_odbc_usr;
    char *odbcini_sys, *odbcini_usr, *ptr;
    char path[1024];
    char *long_name, *section_narrow;
    TCHAR *valueW;

    /*
     *  1a. Find out where system odbc.ini resides
     */
    if ((odbcini_sys = getenv ("ODBCINI")) == NULL || access (odbcini_sys, R_OK))
      odbcini_sys = "/etc/odbc.ini";

    /*
     *  1b. The default system odbc.ini on Mac OS X is located in
     *      /Library/ODBC/odbc.ini
     */
#ifdef __APPLE__
    if (access (odbcini_sys, R_OK) != 0)
      odbcini_sys = "/Library/ODBC/odbc.ini";
#endif

    /*
     *  1c. Open system odbc.ini
     */
    cfg_init (&cfg_odbc_sys, odbcini_sys);


    /*
     *  2a. Find out where user odbc.ini resides
     */
    if ((ptr = getenv ("HOME")) == NULL)
      {
	ptr = (char *) getpwuid (getuid ());

	if (ptr != NULL)
	  ptr = ((struct passwd *) ptr)->pw_dir;
      }

    if (ptr != NULL)
      snprintf (path, sizeof (path), "%.200s/.odbc.ini", ptr);
    else
      snprintf (path, sizeof (path), ".odbc.ini");

    /*
     *  2b. The default user odbc.ini on Mac OS X is located in
     *      ~/Library/ODBC/odbc.ini
     */
#ifdef __APPLE__
    if (access (path, R_OK) != 0)
      {
	snprintf (path, sizeof (path), "%.200s/Library/ODBC/odbc.ini", ptr ? ptr : "");
      }
#endif

    /*
     *  2c. Open user odbc.ini
     */
    odbcini_usr = path;
    cfg_init (&cfg_odbc_usr, odbcini_usr);

    cli_dbg_printf (("USING %s\n", iniFile));

    section_narrow = virt_wide_to_ansi (section);

    /*
     *  Check where DSN is registered
     */
    if (cfg_find (cfg_odbc_usr, section_narrow, NULL) == 0)
      pConfig = cfg_odbc_usr;
    else
      pConfig = cfg_odbc_sys;
#endif

    for (i = 0; i < sizeof (attrs) / sizeof (attrs[0]); i++)
      if (!cfgdata[i].supplied && attrs[i].longName)
	{
	  if ((cfgdata[i].data = (TCHAR *) malloc ((attrs[i].maxLength + 1) * sizeof (TCHAR))) == NULL)
	    break;
#ifdef DSN_TRANSLATION
# ifdef WIN32
	  SQLGetPrivateProfileString (section, attrs[i].longName, _T (""), cfgdata[i].data, attrs[i].maxLength, _T ("odbc.ini"));
# else
	  valueW = NULL;
	  long_name = virt_wide_to_ansi (attrs[i].longName);
	  if (cfg_find (pConfig, section_narrow, long_name) == -1)
	    valueW = attrs[i].defVal;
	  else
	    valueW = virt_ansi_to_wide (pConfig->value);
	  free_wide_buffer (long_name);
	  _tcsncpy (cfgdata[i].data, valueW, attrs[i].maxLength);
	  cfgdata[i].data[attrs[i].maxLength] = 0;
	  if (valueW != attrs[i].defVal)
	    free_wide_buffer (valueW);
# endif
#else
	  _tcsncpy (cfgdata[i].data, _T (""), attrs[i].maxLength);
#endif
	}

#if defined (DSN_TRANSLATION) && !defined (WIN32)
    cfg_done (cfg_odbc_usr);
    cfg_done (cfg_odbc_sys);
    free_wide_buffer (section_narrow);
  }
#endif
}


#ifdef DEBUG
static void
DumpOpts (TCHAR * connStr, CfgData cfgdata[])
{
  int i;
  printf (_T ("connStr=[%s]\n"), connStr);
  for (i = 0; i < sizeof (attrs) / sizeof (attrs[0]); i++)
    {
      printf (_T ("  key=[%s] data=[%s] supplied=%d\n"), attrs[i].shortName, cfgdata[i].data, cfgdata[i].supplied);
    }
}
#endif


static int
StrCopyOut (TCHAR * inStr, SQLTCHAR * outStr, SQLUSMALLINT size, SQLUSMALLINT * result)
{
  size_t length = _tcslen (inStr) * sizeof (TCHAR);

  if (!inStr)
    return -1;

  if (result)
    *result = (SQLUSMALLINT) length;

  if (!outStr)
    return 0;

  if (size >= length + sizeof (TCHAR))
    {
      memcpy (outStr, inStr, length + sizeof (TCHAR));
      return 0;
    }

  if (size > 0)
    {
      memcpy (outStr, inStr, size);
      size--;
      outStr[size / sizeof (TCHAR)] = 0;
    }

  return -1;
}


/* Don't know how to, or cannot have connection dialog */
static SQLRETURN
DriverConnectDialog (void *hwnd)
{
  return SQL_SUCCESS;
}


#ifdef HOST			/* Some memory checking tools define HOST="Windows" */
#undef HOST
#endif

#ifdef UNICODE
static int
StrCopyInW (TCHAR ** poutStr, TCHAR * inStr, short size)
{
  TCHAR *outStr;

  if (inStr == NULL)
    inStr = _T ("");

  if (size == SQL_NTS)
    *poutStr = _tcsdup ((TCHAR *) inStr);
  else
    {
      if ((outStr = (TCHAR *) malloc ((size + 1) * sizeof (TCHAR))) != NULL)
	{
	  memcpy (outStr, inStr, size * sizeof (TCHAR));
	  outStr[size] = (TCHAR) '\0';
	}
      *poutStr = outStr;
    }

  return 0;
}
#else
#define StrCopyInW StrCopyIn
#endif

static TCHAR *
stpcpyw (TCHAR * dst, const TCHAR * src)
{
  while ((*dst++ = *src++) != (TCHAR) '\0')
    ;

  return --dst;
}

static SQLRETURN SQL_API
virtodbc__SQLDriverConnect (SQLHDBC hdbc,
    HWND hwnd,
    SQLTCHAR * szConnStrIn,
    SQLSMALLINT cbConnStrIn,
    SQLTCHAR * szConnStrOut, SQLSMALLINT cbConnStrOutMax, SQLSMALLINT * pcbConnStrOutMax, SQLUSMALLINT fDriverCompletion)
{
  char tempHostName[1024];
  TCHAR cmd[2500];
  short fPrompt;
  TCHAR *connStr;
  TCHAR *DSN;
  char *UID;
  char *PWD;
  char *HOST;
  char *szHost;
  char *CHARSET;
  char *DATABASE;
  TCHAR *UIDW;
  TCHAR *PWDW;
  TCHAR *HOSTW;
  TCHAR *CHARSETW;
  TCHAR *ENCRYPTW;
  TCHAR *SERVERCERTW;
  TCHAR *FORCE_DMBS_NAMEW;
  TCHAR *DAYLIGHTW;
  TCHAR *ROUNDROBINW;
#ifdef _SSL
  TCHAR *PWDCLEARW;
#endif
  TCHAR *DATABASEW;
  SQLRETURN rc;
  CON (con, hdbc);
  CfgData cfgdata[sizeof (attrs) / sizeof (CfgRecord)];

  memset (cfgdata, 0, sizeof (cfgdata));

  mutex_enter (con->con_environment->env_mtx);

  if ((szConnStrIn == NULL) || (!cbConnStrIn) || ((cbConnStrIn == SQL_NTS) && (!szConnStrIn[0])))
    {
      connStr = _tcsdup (_T (""));
    }
  else
    StrCopyInW (&connStr, (TCHAR *) szConnStrIn, cbConnStrIn);

  ParseOptions (cfgdata, NULL, 1);
  PutConnectionOptions (cfgdata, con);
  ParseOptions (cfgdata, connStr, 0);

#ifdef DEBUG
  DumpOpts (connStr, cfgdata);
#endif

  fPrompt = FALSE;
  if (fDriverCompletion == SQL_DRIVER_COMPLETE || fDriverCompletion == SQL_DRIVER_COMPLETE_REQUIRED)
    {
      if (!cfgdata[oUID].data || !cfgdata[oUID].data[0]
	  || cfgdata[oUID].data[0] == ' ' || !cfgdata[oPWD].data
	  || !cfgdata[oPWD].data[0] || cfgdata[oPWD].data[0] == ' '
	  || !cfgdata[oHOST].data || !cfgdata[oHOST].data[0] || cfgdata[oHOST].data[0] == ' ')
	fPrompt = TRUE;
    }
  else if (fDriverCompletion == SQL_DRIVER_PROMPT)
    {
      fPrompt = TRUE;
    }

  if (fPrompt)
    {
      if ((rc = DriverConnectDialog ((void *) hwnd)) != SQL_SUCCESS)
	{
	  ParseOptions (cfgdata, NULL, 1);

	  mutex_leave (con->con_environment->env_mtx);
	  return rc;
	}
    }

#ifdef _SSL
  if (con->con_encrypt)
    {
      dk_free_box (con->con_encrypt);
    }

  ENCRYPTW = cfgdata[oENCRYPT].data && _tcslen (cfgdata[oENCRYPT].data) ? (cfgdata[oENCRYPT].data) : NULL;
  con->con_encrypt = virt_wide_to_ansi (ENCRYPTW);
  PWDCLEARW = cfgdata[oPWDCLEAR].data && _tcslen (cfgdata[oPWDCLEAR].data) ? (cfgdata[oPWDCLEAR].data) : NULL;
  con->con_pwd_cleartext = PWDCLEARW ? _ttoi (PWDCLEARW) : 0;
  SERVERCERTW = cfgdata[oSERVERCERT].data && _tcslen (cfgdata[oSERVERCERT].data) ? (cfgdata[oSERVERCERT].data) : NULL;
  con->con_ca_list = virt_wide_to_ansi (SERVERCERTW);
#else
  con->con_encrypt = NULL;
  ENCRYPTW = NULL;
  con->con_pwd_cleartext = 0;
  SERVERCERTW = NULL;
  con->con_ca_list = NULL;
  con->con_pwd_cleartext = 0;
#endif

  if (cfgdata[oROUNDROBIN].data && _tcslen (cfgdata[oROUNDROBIN].data))
    {
      char *nst, nst1;

      nst = virt_wide_to_ansi (cfgdata[oROUNDROBIN].data);
      nst1 = toupper (*nst);
      con->con_round_robin = OPTION_TRUE (nst1) ? 1 : 0;
      free_wide_buffer (nst);
    }
  if (cfgdata[oWideUTF16].data && _tcslen (cfgdata[oWideUTF16].data))
    {
      char *nst, nst1;

      nst = virt_wide_to_ansi (cfgdata[oWideUTF16].data);
      nst1 = toupper (*nst);
      con->con_wide_as_utf16 = OPTION_TRUE (nst1) ? 1 : 0;
      free_wide_buffer (nst);
    }

  FORCE_DMBS_NAMEW = cfgdata[oFORCE_DBMS_NAME].data && _tcslen (cfgdata[oFORCE_DBMS_NAME].data) ? cfgdata[oFORCE_DBMS_NAME].data : NULL;
  if (FORCE_DMBS_NAMEW)
    {
      char *force_dbms_name = virt_wide_to_ansi (FORCE_DMBS_NAMEW);
      strncpy (__virtodbc_dbms_name, force_dbms_name, sizeof (__virtodbc_dbms_name));
      __virtodbc_dbms_name[sizeof (__virtodbc_dbms_name) - 1] = 0;
      free_wide_buffer (force_dbms_name);
    }
  else
    strcpy_ck (__virtodbc_dbms_name, PRODUCT_DBMS);

  DSN = cfgdata[oDSN].data;

  UIDW = cfgdata[oUID].data ? cfgdata[oUID].data : (TCHAR *) _T ("");
  UID = virt_wide_to_ansi (UIDW);

  PWDW = cfgdata[oPWD].data ? cfgdata[oPWD].data : (TCHAR *) _T ("");
  PWD = virt_wide_to_ansi (PWDW);

  HOSTW = cfgdata[oHOST].data ? cfgdata[oHOST].data : attrs[oHOST].defVal;
  HOST = virt_wide_to_ansi (HOSTW);

  DATABASEW = cfgdata[oDATABASE].data;
  DATABASE = virt_wide_to_ansi (DATABASEW);

  if (cfgdata[oCHARSET].data && _tcslen (cfgdata[oCHARSET].data))
    {
      char * cs = virt_wide_to_ansi (cfgdata[oCHARSET].data);
      if (!strcmp (cs, "UTF-8"))
	{
	  free (cfgdata[oCHARSET].data);
	  cfgdata[oCHARSET].data = NULL;
	  cfgdata[oCHARSET].supplied = FALSE;
	  con->con_string_is_utf8 = 1;
	}
    }

  CHARSETW = (cfgdata[oCHARSET].data && _tcslen (cfgdata[oCHARSET].data)) ? cfgdata[oCHARSET].data : NULL;
  CHARSET = con->con_charset_name = virt_wide_to_ansi (CHARSETW);

  if (strchr (HOST, ':') == NULL && strchr(HOST,',') == NULL)
    {
      snprintf (tempHostName, sizeof (tempHostName), "%s:1111", HOST);
      szHost = tempHostName;
    }
  else
    szHost = HOST;

  DAYLIGHTW = cfgdata[oDAYLIGHT].data && _tcslen (cfgdata[oDAYLIGHT].data) ? cfgdata[oDAYLIGHT].data : NULL;
  if (DAYLIGHTW)
    {
      char *daylight = virt_wide_to_ansi (DAYLIGHTW);
      isdts_mode = (toupper (*daylight) == 'Y');
      free_wide_buffer (daylight);
    }

  if (cfgdata[oNoSystemTables].data && _tcslen (cfgdata[oNoSystemTables].data))
    {
      char *nst, nst1;

      nst = virt_wide_to_ansi (cfgdata[oNoSystemTables].data);
      nst1 = toupper (*nst);
      con->con_no_system_tables = OPTION_TRUE (nst1) ? 1 : 0;
      free_wide_buffer (nst);
    }

  if (cfgdata[oTreatViewsAsTables].data && _tcslen (cfgdata[oTreatViewsAsTables].data))
    {
      char *nst, nst1;

      nst = virt_wide_to_ansi (cfgdata[oTreatViewsAsTables].data);
      nst1 = toupper (*nst);
      con->con_treat_views_as_tables = OPTION_TRUE (nst1) ? 1 : 0;
      free_wide_buffer (nst);
    }

#ifdef DEBUG
  DumpOpts (connStr, cfgdata);

  printf (_T ("CONNECT(%s,%s,%s)\n"), szHost, UID, PWD);
#endif

  rc = internal_sql_connect (hdbc, (SQLCHAR *) szHost, SQL_NTS, (SQLCHAR *) UID, SQL_NTS, (SQLCHAR *) PWD, SQL_NTS);

  if (rc == SQL_SUCCESS || rc == SQL_SUCCESS_WITH_INFO)
    {
      if (DATABASEW && _tcslen (DATABASEW) && _tcscmp (DATABASEW, DEFAULT_DATABASE_PER_USER))
	rc = virtodbc__SQLSetConnectAttr (hdbc, SQL_CURRENT_QUALIFIER, DATABASE, SQL_NTS);
      else
	DATABASEW = NULL;
    }

  if (rc == SQL_SUCCESS || rc == SQL_SUCCESS_WITH_INFO)
    {
      if (cfgdata[oIsolationLevel].data && _tcslen (cfgdata[oIsolationLevel].data))
	{
	  TCHAR *szValue = cfgdata[oIsolationLevel].data;
	  if (!_tcsicmp (szValue, _T ("Read Uncommitted")))
	    con->con_isolation = SQL_TXN_READ_UNCOMMITTED;
	  else if (!_tcsicmp (szValue, _T ("Read Committed")))
	    con->con_isolation = SQL_TXN_READ_COMMITTED;
	  else if (!_tcsicmp (szValue, _T ("Repeatable Read")))
	    con->con_isolation = SQL_TXN_REPEATABLE_READ;
	  else if (!_tcsicmp (szValue, _T ("Serializable")))
	    con->con_isolation = SQL_TXN_SERIALIZABLE;
	}
    }
  if (rc == SQL_SUCCESS || rc == SQL_SUCCESS_WITH_INFO)
    {
      TCHAR *p = cmd;
      if (cfgdata[oDRIVER].supplied && cfgdata[oDRIVER].data)
	{
	  p = stpcpyw (p, _T ("DRIVER="));
	  p = stpcpyw (p, cfgdata[oDRIVER].data);
	  p = stpcpyw (p, _T (";SERVER=OpenLink"));
	}
      else if (DSN)
	{
	  p = stpcpyw (p, _T ("DSN="));
	  p = stpcpyw (p, DSN);
	}
      else
	p = stpcpyw (p, _T ("DSN=default"));

      if (DATABASEW)
	{
	  p = stpcpyw (p, _T (";DATABASE="));
	  p = stpcpyw (p, DATABASEW);
	}

      if (FORCE_DMBS_NAMEW)
	{
	  p = stpcpyw (p, _T (";FORCE_DBMS_NAME="));
	  p = stpcpyw (p, FORCE_DMBS_NAMEW);
	}

      if (CHARSET)
	{
	  p = stpcpyw (p, _T (";CHARSET="));
	  p = stpcpyw (p, CHARSETW);
	}

#ifdef _SSL
      if (con->con_encrypt)
	{
	  p = stpcpyw (p, _T (";ENCRYPT="));
	  p = stpcpyw (p, ENCRYPTW);
	}

      if (con->con_ca_list)
	{
	  p = stpcpyw (p, _T (";SERVERCERT="));
	  p = stpcpyw (p, SERVERCERTW);
	}

      if (con->con_pwd_cleartext)
	{
	  p = stpcpyw (p, _T (";PWDCLEAR="));
	  p = stpcpyw (p, PWDCLEARW);
	}
#endif

      if (DAYLIGHTW)
	{
	  p = stpcpyw (p, isdts_mode ? _T (";DAYLIGHT=Y") : _T (";DAYLIGHT=N"));
	}

      p = stpcpyw (p, _T (";UID="));
      p = stpcpyw (p, UIDW);
      p = stpcpyw (p, _T (";PWD="));
      p = stpcpyw (p, PWDW);
      p = stpcpyw (p, _T (";HOST="));
      p = stpcpyw (p, HOSTW);

      if (-1 == StrCopyOut (cmd, szConnStrOut, cbConnStrOutMax, (u_short *) pcbConnStrOutMax))
	{
	  rc = SQL_SUCCESS_WITH_INFO;
	  set_success_info (&con->con_error, "01004", "CLW01", "String data, right truncated", 0);
	}
    }

  free_wide_buffer (HOST);
  free_wide_buffer (UID);
  free_wide_buffer (PWD);
  free_wide_buffer (CHARSET);
  free_wide_buffer (DATABASE);

  /* Cleanup */
  ParseOptions (cfgdata, NULL, 1);

  if (connStr)
    free (connStr);

  mutex_leave (con->con_environment->env_mtx);

  return rc;
}


SQLRETURN SQL_API
SQLDriverConnect (SQLHDBC hdbc,
#ifdef WIN32
    HWND hwnd,
#else
    void *hwnd,
#endif
    SQLTCHAR * szConnStrIn,
    SQLSMALLINT cbConnStrIn,
    SQLTCHAR * szConnStrOut,
    SQLSMALLINT cbConnStrOutMax,
    SQLSMALLINT * pcbConnStrOutMax,
    SQLUSMALLINT fDriverCompletion)
{
  return virtodbc__SQLDriverConnect (hdbc, hwnd, szConnStrIn, cbConnStrIn, szConnStrOut, cbConnStrOutMax, pcbConnStrOutMax, fDriverCompletion);
}


SQLRETURN SQL_API
SQLConnect (SQLHDBC hdbc,
    SQLTCHAR * szDSN, SQLSMALLINT cbDSN, SQLTCHAR * szUID, SQLSMALLINT cbUID, SQLTCHAR * szPWD, SQLSMALLINT cbPWD)
{
#ifndef DSN_TRANSLATION

  return internal_sql_connect (hdbc, szDSN, cbDSN, szUID, cbUID, szPWD, cbPWD);

#else
  CON (con, hdbc);
  TCHAR cmd[200];
  TCHAR *dsn;
  TCHAR *uid;
  TCHAR *pwd;
  TCHAR *pcmd = &(cmd[0]);

  StrCopyInW (&dsn, (TCHAR *) szDSN, cbDSN);
  StrCopyInW (&uid, (TCHAR *) szUID, cbUID);
  StrCopyInW (&pwd, (TCHAR *) szPWD, cbPWD);

  if ((cbDSN < 0 && cbDSN != SQL_NTS) || (cbUID < 0 && cbUID != SQL_NTS) || (cbPWD < 0 && cbPWD != SQL_NTS))
    {
      set_error (&con->con_error, "S1090", "CL062", "Invalid string or buffer length");
      return SQL_ERROR;
    }

  pcmd = stpcpyw (pcmd, _T ("DSN="));
  pcmd = stpcpyw (pcmd, dsn);
  pcmd = stpcpyw (pcmd, _T (";UID="));
  pcmd = stpcpyw (pcmd, uid);
  pcmd = stpcpyw (pcmd, _T (";PWD="));
  pcmd = stpcpyw (pcmd, pwd);

  free (dsn);
  free (uid);
  free (pwd);

  return virtodbc__SQLDriverConnect (hdbc, NULL, (SQLTCHAR *) cmd, SQL_NTS, NULL, 0, NULL, SQL_DRIVER_NOPROMPT);
#endif
}
