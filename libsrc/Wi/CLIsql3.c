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
#if defined (__APPLE__)
#undef _T
#endif
#ifdef UNICODE

#define _T(A) L##A

typedef  wchar_t TCHAR;
#if defined (HAVE_WCSCASECMP)
#define _tcsicmp wcscasecmp
#elif defined (HAVE_WCSICMP)
#define _tcsicmp wcsicmp
#else
#define _tcsicmp virt_wcscasecmp
#endif

#ifdef HAVE_WCSDUP
#define _tcsdup wcsdup
#else
#define _tcsdup virt_wcsdup
#endif

#define _tcscpy wcscpy
#define _tcsncpy wcsncpy
#define _tcslen wcslen
#define _tcscmp wcscmp
#define _ttoi(a) wide_atoi ((caddr_t) (a))

#else

#define _T(A) A

typedef  char TCHAR;
#define _tcsicmp stricmp
#define _tcsdup strdup
#define _tcscpy strcpy
#define _tcsncpy strncpy
#define _tcslen strlen
#define _tcscmp strcmp
#define _ttoi atoi

#endif
#endif

#ifdef MALLOC_DEBUG
#define _tcscpy_size_ck(dest, src, len)  do { \
  				   if (((len) - 1) < _tcslen (src)) \
			     	     GPF_T; \
			 	   _tcsncpy ((dest), (src), (len) - 1); \
			      	   (dest)[(len) - 1] = 0; \
				 } while (0)
#else

#define _tcscpy_size_ck(dest, src, len)  do { \
			 	   _tcsncpy ((dest), (src), (len) - 1); \
			      	   (dest)[(len) - 1] = 0; \
				 } while (0)
#endif
#define _tcscpy_ck(dest, src)  _tcscpy_size_ck (dest, src, sizeof (dest) / sizeof (TCHAR))
#define _tcscpy_box_ck(dest, src)  _tcscpy_size_ck (dest, src, box_length (dest) / sizeof (TCHAR))

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
# else
#/* include <wiutil/ncfg.h> */
# endif
#endif

#ifndef TRUE
# define TRUE 1
# define FALSE 0
#endif

#define OPTION_TRUE(X)	((X) && (X) != 'N' && (X) != '0')

static SQLRETURN SQL_API virtodbc__SQLDriverConnect (SQLHDBC hdbc,
   HWND hwnd, SQLTCHAR * szConnStrIn, SQLSMALLINT cbConnStrIn,
    SQLTCHAR * szConnStrOut, SQLSMALLINT cbConnStrOutMax,
    SQLSMALLINT * pcbConnStrOutMax, SQLUSMALLINT fDriverCompletion);

#ifdef WIN32
BOOL ConfigDSN_virt (
    HWND hWinParent,
    WORD fRequest,
    LPTSTR lpszDriver,
    LPTSTR lpszAttributes,
    TCHAR *ret_str);
#endif
#define DEFAULT_DATABASE_PER_USER _T("<Server Default>")
typedef struct
  {
    TCHAR *	shortName;
    TCHAR *	longName;
    short	maxLength;
    TCHAR *	defVal;
    int		supplied;
    TCHAR *	data;
  } CfgRecord;

typedef enum
  {
    oDSN, oDESC, oHOST, oUID, oPWD, oDRIVER, oDATABASE, oCHARSET, oDAYLIGHT
#ifdef _SSL
	, oENCRYPT, oPWDCLEAR, oSERVERCERT
#endif
    , oFORCE_DBMS_NAME, oIsolationLevel, oNoSystemTables
  } CfgOptions;

/*
 *  If you make any changes here, please reflect them
 *  in the ~/driver/virtodbc.c file as well (setup)
 */
static CfgRecord attrs[] = {
  /* shortName			longName      		maxLength defVal */
  { _T("DSN"),			NULL,			63,	_T("") },
  { NULL,			_T ("Description"),	511,	_T ("") },
  { _T ("HOST"),		_T ("Address"),		160,	_T ("localhost:1111") },
#if defined (WIN32) && !defined (UDBC)
  { _T ("UID"),			_T ("LastUser"),	32,	_T ("dba") },
  { _T ("PWD"),			NULL,			32,	_T ("") },
#else
  { _T ("UID"),			_T ("UserName"),	32,	_T ("dba") },
  { _T ("PWD"),			_T ("Password"),	32,	_T ("") },
#endif
  { _T ("DRIVER"),		NULL,			160,	_T ("") },
  { _T ("DATABASE"),		_T ("Database"),	64,	DEFAULT_DATABASE_PER_USER },
  { _T ("CHARSET"),		_T ("Charset"),		200,	_T ("") },
  { _T ("DAYLIGHT"), 		_T ("Daylight"),     	64,	_T ("") }
#ifdef _SSL
  ,{ _T ("ENCRYPT"),		_T ("Encrypt"),		511,	_T ("") }
  ,{ _T ("PWDCLEAR"),		_T ("PWDClearText"),	32,	_T ("") }
  ,{ _T ("SERVERCERT"),		_T ("ServerCert"),	511,	_T ("") }
#endif
  ,{ _T ("FORCE_DBMS_NAME"),	_T ("ForceDBMSName"),	511,	_T ("") }
  ,{ _T ("IsolationLevel"),	_T ("IsolationLevel"),	32,	_T ("") }
  ,{ _T ("NoSystemTables"),	_T ("NoSystemTables"),	32,	_T ("") }
  };

#ifdef UNICODE
extern TCHAR drv_name [800];
#else
char drv_name_n [200];
#define drv_name drv_name_n
#endif


#ifdef WIN32
static TCHAR connect_string [8000];
#endif
static TCHAR connect_string_file_dsn [8000];

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
virt_ansi_to_wide (char * in)
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
#define virt_wide_to_ansi cli_box_wide_to_narrow
#define virt_ansi_to_wide cli_box_narrow_to_wide
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
      attrs[o_inx].data = _tcsdup (wide); \
      attrs[o_inx].supplied = TRUE; \
      free_wide_buffer (wide); \
      \
      dk_free_box ((box_t) opt); \
      opt = NULL; \
    }

static void
PutConnectionOptions (cli_connection_t *con)
{
  PUT_CONN_OPT (con->con_qualifier, oDATABASE);
  PUT_CONN_OPT (con->con_charset, oCHARSET);

#ifdef _SSL
  PUT_CONN_OPT (con->con_encrypt, oENCRYPT);
#endif
}


static void
ParseOptions (TCHAR *s, int clean_up)
{
  TCHAR *cp, *n;
  TCHAR *section;
  int count;
  int i;

  if (clean_up)
    for (i = 0; i < sizeof (attrs) / sizeof (attrs[0]); i++)
      {
	if (attrs[i].data)
	  free (attrs[i].data);

	attrs[i].data = NULL;
	attrs[i].supplied = FALSE;
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
		    attrs[i].data = _tcsdup (cp);
		    attrs[i].supplied = TRUE;
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
	  attrs[oDSN].data = _tcsdup (s);
	  attrs[oDSN].supplied = TRUE;
	}
      s = n;
    }

  section = attrs[oDSN].data;

  if (section == NULL || !section[0])
    section = _T ("Default");

#if defined (DSN_TRANSLATION) && !defined (WIN32)
  {
    PCONFIG pConfig;
    char iniFile[1024];
    char *value, *long_name, *section_narrow;
    TCHAR *valueW;

    if ((value = getenv ("ODBCINI")) != NULL)
      snprintf (iniFile, sizeof (iniFile), value);
    else
      {
	if ((value = getenv ("HOME")) != NULL)
	  snprintf (iniFile, sizeof (iniFile), "%s/.odbc.ini", value);
	else
	  strcpy_ck (iniFile, "odbc.ini");
      }

    cli_dbg_printf (("USING %s\n", iniFile));

    cfg_init (&pConfig, iniFile);
    section_narrow = virt_wide_to_ansi (section);
#endif

    for (i = 0; i < sizeof (attrs) / sizeof (attrs[0]); i++)
      if (!attrs[i].supplied && attrs[i].longName)
	{
	  if ((attrs[i].data = (TCHAR *) malloc ((attrs[i].maxLength + 1) * sizeof (TCHAR))) == NULL)
	    break;
#ifdef DSN_TRANSLATION
# ifdef WIN32
	  SQLGetPrivateProfileString (section, attrs[i].longName, _T (""), attrs[i].data, attrs[i].maxLength, _T ("odbc.ini"));
# else
	  valueW = NULL;
	  long_name = virt_wide_to_ansi (attrs[i].longName);
	  if (cfg_find (pConfig, section_narrow, long_name) == -1)
	    valueW = attrs[i].defVal;
	  else
	    valueW = virt_ansi_to_wide (pConfig->value);
	  free_wide_buffer (long_name);
	  _tcsncpy (attrs[i].data, valueW, attrs[i].maxLength);
	  attrs[i].data[attrs[i].maxLength] = 0;
	  if (valueW != attrs[i].defVal)
	    free_wide_buffer (valueW);
# endif
#else
	  _tcsncpy (attrs[i].data, _T (""), attrs[i].maxLength);
#endif
	}

#if defined (DSN_TRANSLATION) && !defined (WIN32)
    cfg_done (pConfig);
    free_wide_buffer (section_narrow);
  }
#endif
}


#ifdef DEBUG
static void
DumpOpts (TCHAR *connStr)
{
  int i;
  printf (_T ("connStr=[%s]\n"), connStr);
  for (i = 0; i < sizeof (attrs) / sizeof (attrs[0]); i++)
    {
      printf (_T ("  key=[%s] data=[%s] supplied=%d\n"), attrs[i].shortName, attrs[i].data, attrs[i].supplied);
    }
}
#endif


static int
StrCopyOut (TCHAR *inStr, SQLTCHAR *outStr, SQLUSMALLINT size, SQLUSMALLINT *result)
{
  size_t length;

  if (inStr && result)
    *result = (SQLUSMALLINT) _tcslen (inStr) * sizeof (TCHAR);

  if (!outStr || !inStr)
    return -1;

  length = _tcslen (inStr) * sizeof (TCHAR);

  if (size >= length + sizeof (TCHAR))
    {
      memcpy (outStr, inStr, length + sizeof (TCHAR));
      if (result)
	*result = (SQLUSMALLINT) length;
      return 0;
    }

  if (size > 0)
    {
      memcpy (outStr, inStr, size);
      size--;
      outStr[size / sizeof (TCHAR)] = 0;

      if (result)
	*result = size;
    }

  return -1;
}


#if defined (WIN32) && defined (DSN_TRANSLATION)

extern HINSTANCE s_hModule;

static SQLHDBC driver_connect_dbc = NULL;

extern void CenterDialog (HWND hDlg);


static void
CollectData(HWND hDlg)
{
  TCHAR buf[80];

  GetDlgItemText (hDlg, IDC_HOST, buf, sizeof (buf));
  if (attrs[oHOST].data)
    free (attrs[oHOST].data);
  attrs[oHOST].data = _tcsdup (buf);
  attrs[oHOST].supplied = TRUE;

  GetDlgItemText (hDlg, IDC_UID, buf, sizeof (buf));
  if (attrs[oUID].data)
    free (attrs[oUID].data);
  attrs[oUID].data = _tcsdup (buf);
  attrs[oUID].supplied = TRUE;

  GetDlgItemText (hDlg, IDC_PWD, buf, sizeof (buf));
  if (attrs[oPWD].data)
    free (attrs[oPWD].data);
  attrs[oPWD].data = _tcsdup (buf);
  attrs[oPWD].supplied = TRUE;

  GetDlgItemText (hDlg, IDC_DATABASE, buf, sizeof (buf));
  if (attrs[oDATABASE].data)
    free (attrs[oDATABASE].data);
  attrs[oDATABASE].data = _tcsdup (buf);
  if (_tcslen (attrs[oDATABASE].data))
    attrs[oDATABASE].supplied = TRUE;

#if 0
  if (attrs[oENCRYPT].data)
    {
      free (attrs[oENCRYPT].data);
      attrs[oENCRYPT].data = NULL;
      attrs[oENCRYPT].supplied = FALSE;
    }
  if (SendDlgItemMessage (hDlg, IDC_ENCRYPT_CHECK, BM_GETCHECK, 0, 0) != 0)
    {
      TCHAR buf2[255];
      GetDlgItemText (hDlg, IDC_ENCRYPT_FILE, buf2, sizeof (buf2));
      if (attrs[oENCRYPT].data)
	free (attrs[oENCRYPT].data);
      if (buf2[0] > 0 && atoi (buf2) = 0)
	attrs[oENCRYPT].data = strdup (buf2);
      else
	attrs[oENCRYPT].data = strdup (_T ("1"));
      attrs[oENCRYPT].supplied = TRUE;
    }
#endif
}

static void
FillUpLoginDatabaseCombo (HWND hDlg)
{
  int nItems = SendDlgItemMessage (hDlg, IDC_DATABASE, CB_GETCOUNT, 0, 0);
  int selection_index;
  SDWORD data_len;

  SQLHSTMT stmt;
  TCHAR szMessage[512], szState[10], szHostW[1024], szUIDW[128], szPWDW[128], szMsg1[512];
  char *UID, *PWD, *HOST;
  short len;
  SQLRETURN rc;

  GetDlgItemText (hDlg, IDC_HOST, szHostW, sizeof (szHostW));

  if (!szHostW[0])
    _tcscpy_ck (szHostW, _T ("localhost:1111"));

  if (_tcschr (szHostW, ':') == NULL)
    _tcsncat (szHostW, _T (":1111"), sizeof (szHostW) / sizeof (TCHAR) - _tcslen (szHostW));

  GetDlgItemText (hDlg, IDC_UID, szUIDW, sizeof (szUIDW));
  GetDlgItemText (hDlg, IDC_PWD, szPWDW, sizeof (szPWDW));

  HOST = virt_wide_to_ansi (szHostW);
  UID = virt_wide_to_ansi (szUIDW);
  PWD = virt_wide_to_ansi (szPWDW);

  rc = internal_sql_connect (driver_connect_dbc, HOST, SQL_NTS, UID, SQL_NTS, PWD, SQL_NTS);

  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      SQLError (NULL, driver_connect_dbc, NULL, szState, NULL, szMessage, sizeof (szMessage), &len);
      wsprintf (szMsg1, _T ("Error getting the databases list : \n %.200s"), szMessage);
      MessageBox (hDlg, szMsg1, _T ("Server databases list"), MB_OK | MB_ICONSTOP);

      return;
    }

  rc = SQLAllocStmt (driver_connect_dbc, &stmt);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      SQLError (NULL, driver_connect_dbc, stmt, szState, NULL, szMessage, sizeof (szMessage), &len);
      wsprintf (szMsg1, _T ("Error getting the databases list : \n %.200s"), szMessage);
      MessageBox (hDlg, szMsg1, _T ("Server databases list"), MB_OK | MB_ICONSTOP);
      SQLDisconnect (driver_connect_dbc);

      return;
    }

  if (SQL_SUCCESS != SQLTables (stmt, _T (SQL_ALL_CATALOGS), SQL_NTS, _T (""), SQL_NTS, _T (""), SQL_NTS, _T (""), SQL_NTS))
    {
      SQLError (SQL_NULL_HENV, driver_connect_dbc, stmt, szState, NULL, szMessage, sizeof (szMessage), &len);
      wsprintf (szMsg1, _T ("Error getting the databases list : \n %.200s"), szMessage);
      MessageBox (hDlg, szMsg1, _T ("Server databases list"), MB_OK | MB_ICONSTOP);
      SQLFreeStmt (stmt, SQL_DROP);
      SQLDisconnect (driver_connect_dbc);

      return;
    }

  SendDlgItemMessage (hDlg, IDC_DATABASE, CB_RESETCONTENT, 0, 0);
  SendDlgItemMessage (hDlg, IDC_DATABASE, CB_ADDSTRING, 0, (LPARAM) DEFAULT_DATABASE_PER_USER);

  while (SQL_SUCCESS == SQLFetch (stmt))
    {
      if (SQL_SUCCESS == SQLGetData (stmt, 1, SQL_C_TCHAR, szMessage, sizeof (szMessage), &data_len))
	{
	  if (!data_len || data_len == SQL_NULL_DATA)
	    break;
	  else if (data_len > 0 && data_len < sizeof (szMessage))
	    szMessage[data_len / sizeof (TCHAR)] = 0;

	  SendDlgItemMessage (hDlg, IDC_DATABASE, CB_ADDSTRING, 0, (LPARAM) szMessage);
	}
    }

  selection_index = (int) SendDlgItemMessage (hDlg, IDC_DATABASE, CB_FINDSTRINGEXACT, -1, (LPARAM) attrs[oDATABASE].data);
  SendDlgItemMessage (hDlg, IDC_DATABASE, CB_SETCURSEL, selection_index == CB_ERR ? -1 : selection_index, (LPARAM) 0);

  SQLFreeStmt (stmt, SQL_CLOSE);

  if (SQL_SUCCESS != SQLExecDirect (stmt, _T ("select CS_NAME from DB.DBA.SYS_CHARSETS"), SQL_NTS))
    {
      SQLError (SQL_NULL_HENV, driver_connect_dbc, stmt, szState, NULL, szMessage, sizeof (szMessage), &len);
      MessageBox (hDlg, szMessage, _T ("Error getting the charsets list"), MB_OK | MB_ICONSTOP);
      SQLFreeStmt (stmt, SQL_DROP);
      SQLFreeConnect (driver_connect_dbc);

      return;
    }

  SendDlgItemMessage (hDlg, IDC_CHARSET, CB_RESETCONTENT, 0, 0);
  SendDlgItemMessage (hDlg, IDC_CHARSET, CB_ADDSTRING, 0, (LPARAM) DEFAULT_DATABASE_PER_USER);

  while (SQL_SUCCESS == SQLFetch (stmt))
    {
      if (SQL_SUCCESS == SQLGetData (stmt, 1, SQL_C_TCHAR, szMessage, sizeof (szMessage), &data_len))
	{
	  if (!data_len || data_len == SQL_NULL_DATA)
	    break;
	  else if (data_len > 0 && data_len < sizeof (szMessage))
	    szMessage[data_len / sizeof (TCHAR)] = 0;

	  SendDlgItemMessage (hDlg, IDC_CHARSET, CB_ADDSTRING, 0, (LPARAM) szMessage);
	}
    }

  selection_index =
      (int) SendDlgItemMessage (hDlg, IDC_CHARSET, CB_FINDSTRINGEXACT, -1,
      (LPARAM) (attrs[oCHARSET].data[0] ? attrs[oCHARSET].data : DEFAULT_DATABASE_PER_USER));
  SendDlgItemMessage (hDlg, IDC_CHARSET, CB_SETCURSEL, selection_index == CB_ERR ? -1 : selection_index, (LPARAM) 0);

  SQLFreeStmt (stmt, SQL_DROP);
  SQLDisconnect (driver_connect_dbc);
}


BOOL PASCAL
FDriverConnectProc(
    HWND	hDlg,
    WORD	wMsg,
    WPARAM	wParam,
    LPARAM	lParam)
{
  TCHAR *HOST;
  TCHAR *DSN;
  TCHAR *UID;
  TCHAR *PWD;
  TCHAR *DATABASE;

  switch (wMsg)
    {
    case WM_INITDIALOG:
      DSN = attrs[oDSN].data;
      if (DSN == NULL || !DSN[0])
	DSN = _T ("(File DSN)");

      UID = attrs[oUID].data ? attrs[oUID].data : _T ("");
      PWD = attrs[oPWD].data ? attrs[oPWD].data : _T ("");
      HOST = attrs[oHOST].data ? attrs[oHOST].data : _T ("");
      DATABASE = (attrs[oDATABASE].data && _tcslen (attrs[oDATABASE].data)) ? attrs[oDATABASE].data : DEFAULT_DATABASE_PER_USER;

      SendDlgItemMessage (hDlg, IDC_UID, EM_LIMITTEXT, attrs[oUID].maxLength, 0);
      SendDlgItemMessage (hDlg, IDC_PWD, EM_LIMITTEXT, attrs[oPWD].maxLength, 0);
      SendDlgItemMessage (hDlg, IDC_HOST, EM_LIMITTEXT, attrs[oHOST].maxLength, 0);
      SendDlgItemMessage (hDlg, IDC_DRV, EM_LIMITTEXT, 200, 0);

      SetDlgItemText (hDlg, IDC_DRV, drv_name);
      SetDlgItemText (hDlg, IDC_DSN, DSN);
      SetDlgItemText (hDlg, IDC_UID, UID);
      SetDlgItemText (hDlg, IDC_PWD, PWD);
      SetDlgItemText (hDlg, IDC_HOST, HOST);
      SetDlgItemText (hDlg, IDC_DATABASE, DATABASE);

      if (0 == SendDlgItemMessage (hDlg, IDC_DATABASE, CB_GETCOUNT, 0, 0))
	SendDlgItemMessage (hDlg, IDC_DATABASE, CB_ADDSTRING, 0, (LPARAM) DATABASE);
      SendDlgItemMessage (hDlg, IDC_DATABASE, CB_SELECTSTRING, 0, (LPARAM) DATABASE);

      if (!HOST[0])
	SetDlgItemText (hDlg, IDC_HOST, HOST = _T ("localhost:1111"));

      if (!UID[0])
	SetDlgItemText (hDlg, IDC_UID, UID = _T ("dba"));

#if 0
#ifdef _SSL
      SendDlgItemMessage (hDlg, IDC_ENCRYPT, BM_SETCHECK,
	  attrs[oENCRYPT].data &&
	  (toupper (attrs[oENCRYPT].data[0]) == 'Y' ||
	      toupper (attrs[oENCRYPT].data[0]) == 'T' || attrs[oENCRYPT].data[0] == '1'), 0);
#endif
#endif

      CenterDialog (hDlg);
      SetForegroundWindow (hDlg);

      if (HOST[0] && UID[0])
	{
	  SetFocus (GetDlgItem (hDlg, IDC_PWD));
	  return FALSE;
	}
      return TRUE;

    case WM_COMMAND:
      switch (LOWORD (wParam))
	{
	case IDC_ADV_BTN:
	  if (_tcslen (connect_string_file_dsn) < 15)
	    connect_string_file_dsn[0] = 0;
	  ConfigDSN_virt (hDlg, 7, _T ("Virtuoso"), connect_string_file_dsn, connect_string);
	  if (connect_string[0])
	    {
	      ParseOptions (connect_string, 0);
	      DSN = attrs[oDSN].data;
	      if (DSN == NULL || !DSN[0])
		DSN = _T ("(File DSN)");

	      UID = attrs[oUID].data ? attrs[oUID].data : _T ("");
	      PWD = attrs[oPWD].data ? attrs[oPWD].data : _T ("");
	      HOST = attrs[oHOST].data ? attrs[oHOST].data : _T ("");
	      DATABASE = (attrs[oDATABASE].data
		  && _tcslen (attrs[oDATABASE].data)) ? attrs[oDATABASE].data : DEFAULT_DATABASE_PER_USER;

	      SendDlgItemMessage (hDlg, IDC_UID, EM_LIMITTEXT, attrs[oUID].maxLength, 0);
	      SendDlgItemMessage (hDlg, IDC_PWD, EM_LIMITTEXT, attrs[oPWD].maxLength, 0);
	      SendDlgItemMessage (hDlg, IDC_HOST, EM_LIMITTEXT, attrs[oHOST].maxLength, 0);
	      SendDlgItemMessage (hDlg, IDC_DRV, EM_LIMITTEXT, 200, 0);

	      SetDlgItemText (hDlg, IDC_DRV, drv_name);
	      SetDlgItemText (hDlg, IDC_DSN, DSN);
	      SetDlgItemText (hDlg, IDC_UID, UID);
	      SetDlgItemText (hDlg, IDC_PWD, PWD);
	      SetDlgItemText (hDlg, IDC_HOST, HOST);
	      SetDlgItemText (hDlg, IDC_DATABASE, DATABASE);

	      if (0 == SendDlgItemMessage (hDlg, IDC_DATABASE, CB_GETCOUNT, 0, 0))
		SendDlgItemMessage (hDlg, IDC_DATABASE, CB_ADDSTRING, 0, (LPARAM) DATABASE);
	      SendDlgItemMessage (hDlg, IDC_DATABASE, CB_SELECTSTRING, 0, (LPARAM) DATABASE);

	      if (!HOST[0])
		SetDlgItemText (hDlg, IDC_HOST, HOST = _T ("localhost:1111"));

	      if (!UID[0])
		SetDlgItemText (hDlg, IDC_UID, UID = _T ("dba"));
	    }
	  /*return TRUE; */
	  break;

	case IDOK:
	  CollectData (hDlg);

	case IDCANCEL:
	  EndDialog (hDlg, wParam);
	  return TRUE;

	case IDC_DATABASE:
	  if (HIWORD (wParam) == CBN_DROPDOWN)
	    FillUpLoginDatabaseCombo (hDlg);
	  break;
	}
    }

  return FALSE;
}


static SQLRETURN
DriverConnectDialog (void *hwnd)
{
  int iRet;

  connect_string[0] = 0;

  iRet = DialogBox (s_hModule, MAKEINTRESOURCE (DlgLogin), (HWND) hwnd, FDriverConnectProc);

  if (iRet == IDCANCEL || iRet == -1)
    return SQL_NO_DATA_FOUND;

  return SQL_SUCCESS;
}

#else

/* Don't know how to, or cannot have connection dialog */
static SQLRETURN
DriverConnectDialog (void *hwnd)
{
  return SQL_SUCCESS;
}
#endif

#ifdef HOST /* Some memory checking tools define HOST="Windows" */
#undef HOST
#endif

#ifdef UNICODE
static int
StrCopyInW (TCHAR **poutStr, TCHAR *inStr, short size)
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
/*          memcpy (outStr, inStr, size);*/
	  outStr[size] = (TCHAR) '\0';
/*          outStr[size * sizeof(TCHAR)] = (TCHAR) '\0';*/
	}
      *poutStr = outStr;
    }

  return 0;
}
#else
  #define StrCopyInW StrCopyIn
#endif

static TCHAR *
stpcpyw (TCHAR *dst, const TCHAR *src)
{
  while ((*dst++ = *src++) != (TCHAR) '\0')
    ;

  return --dst;
}

static SQLRETURN SQL_API
virtodbc__SQLDriverConnect (
    SQLHDBC hdbc,
    HWND hwnd,
    SQLTCHAR * szConnStrIn,
    SQLSMALLINT cbConnStrIn,
    SQLTCHAR * szConnStrOut,
    SQLSMALLINT cbConnStrOutMax,
    SQLSMALLINT * pcbConnStrOutMax,
    SQLUSMALLINT fDriverCompletion)
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
#ifdef _SSL
  TCHAR *PWDCLEARW;
#endif
  TCHAR *DATABASEW;
  SQLRETURN rc;
  CON (con, hdbc);

  mutex_enter (con->con_environment->env_mtx);

  if ((szConnStrIn == NULL) || (!cbConnStrIn) || ((cbConnStrIn == SQL_NTS) && (!szConnStrIn[0])))
    {
      connStr = _tcsdup (_T (""));
    }
  else
    StrCopyInW (&connStr, (TCHAR *) szConnStrIn, cbConnStrIn);

  _tcscpy_ck (connect_string_file_dsn, connStr);
  ParseOptions (NULL, 1);
  PutConnectionOptions (con);
  ParseOptions (connStr, 0);

#ifdef DEBUG
  DumpOpts (connStr);
#endif

  fPrompt = FALSE;
  if (fDriverCompletion == SQL_DRIVER_COMPLETE || fDriverCompletion == SQL_DRIVER_COMPLETE_REQUIRED)
    {
      if (!attrs[oUID].data || !attrs[oUID].data[0]
	  || attrs[oUID].data[0] == ' ' || !attrs[oPWD].data
	  || !attrs[oPWD].data[0] || attrs[oPWD].data[0] == ' '
	  || !attrs[oHOST].data || !attrs[oHOST].data[0] || attrs[oHOST].data[0] == ' ')
	fPrompt = TRUE;
    }
  else if (fDriverCompletion == SQL_DRIVER_PROMPT)
    {
      fPrompt = TRUE;
    }

  if (fPrompt)
    {
#if defined (WIN32) && defined (DSN_TRANSLATION)
      driver_connect_dbc = hdbc;
#endif
      if ((rc = DriverConnectDialog ((void *) hwnd)) != SQL_SUCCESS)
	{
	  mutex_leave (con->con_environment->env_mtx);
	  return rc;
	}
    }

#ifdef _SSL
  if (con->con_encrypt)
    {
      dk_free_box (con->con_encrypt);
    }

  ENCRYPTW = attrs[oENCRYPT].data && _tcslen (attrs[oENCRYPT].data) ? (attrs[oENCRYPT].data) : NULL;
  con->con_encrypt = virt_wide_to_ansi (ENCRYPTW);

  PWDCLEARW = attrs[oPWDCLEAR].data && _tcslen (attrs[oPWDCLEAR].data) ? (attrs[oPWDCLEAR].data) : NULL;
  con->con_pwd_cleartext = PWDCLEARW ? _ttoi (PWDCLEARW) : 0;

  SERVERCERTW = attrs[oSERVERCERT].data && _tcslen (attrs[oSERVERCERT].data) ? (attrs[oSERVERCERT].data) : NULL;
  con->con_ca_list = virt_wide_to_ansi (SERVERCERTW);
#else
  con->con_encrypt = NULL;
  ENCRYPTW = NULL;
  con->con_pwd_cleartext = 0;
  SERVERCERTW = NULL;
  con->con_ca_list = NULL;
  con->con_pwd_cleartext = 0;
#endif
  FORCE_DMBS_NAMEW = attrs[oFORCE_DBMS_NAME].data && _tcslen (attrs[oFORCE_DBMS_NAME].data) ? attrs[oFORCE_DBMS_NAME].data : NULL;
  if (FORCE_DMBS_NAMEW)
    {
      char *force_dbms_name = virt_wide_to_ansi (FORCE_DMBS_NAMEW);
      strncpy (__virtodbc_dbms_name, force_dbms_name, sizeof (__virtodbc_dbms_name));
      __virtodbc_dbms_name[sizeof (__virtodbc_dbms_name) - 1] = 0;
      free_wide_buffer (force_dbms_name);
    }
  else
    strcpy_ck (__virtodbc_dbms_name, PRODUCT_DBMS);

  DSN = attrs[oDSN].data;

  UIDW = attrs[oUID].data ? attrs[oUID].data : (TCHAR *) _T ("");
  UID = virt_wide_to_ansi (UIDW);

  PWDW = attrs[oPWD].data ? attrs[oPWD].data : (TCHAR *) _T ("");
  PWD = virt_wide_to_ansi (PWDW);

  HOSTW = attrs[oHOST].data ? attrs[oHOST].data : attrs[oHOST].defVal;
  HOST = virt_wide_to_ansi (HOSTW);

  DATABASEW = attrs[oDATABASE].data;
  DATABASE = virt_wide_to_ansi (DATABASEW);

  CHARSETW = (attrs[oCHARSET].data && _tcslen (attrs[oCHARSET].data)) ? attrs[oCHARSET].data : NULL;
  CHARSET = con->con_charset_name = virt_wide_to_ansi (CHARSETW);

  if (strchr (HOST, ':') == NULL)
    {
      snprintf (tempHostName, sizeof (tempHostName), "%s:1111", HOST);
      szHost = tempHostName;
    }
  else
    szHost = HOST;

  DAYLIGHTW = attrs[oDAYLIGHT].data && _tcslen (attrs[oDAYLIGHT].data) ? attrs[oDAYLIGHT].data : NULL;
  if (DAYLIGHTW)
    {
      char *daylight = virt_wide_to_ansi (DAYLIGHTW);
      isdts_mode = (toupper (*daylight) == 'Y');
      free_wide_buffer (daylight);
    }

  if (attrs[oNoSystemTables].data && _tcslen (attrs[oNoSystemTables].data))
    {
      char *nst, nst1;

      nst = virt_wide_to_ansi (attrs[oNoSystemTables].data);
      nst1 = toupper (*nst);
      con->con_no_system_tables = OPTION_TRUE (nst1) ? 1 : 0;
      free_wide_buffer (nst);
    }

#ifdef DEBUG
  DumpOpts (connStr);

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
      if (attrs[oIsolationLevel].data && _tcslen (attrs[oIsolationLevel].data))
	{
	  TCHAR *szValue = attrs[oIsolationLevel].data;
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
      if (attrs[oDRIVER].supplied && attrs[oDRIVER].data)
	{
	  p = stpcpyw (p, _T ("DRIVER="));
	  p = stpcpyw (p, attrs[oDRIVER].data);
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

  ParseOptions (NULL, 1);

  if (connStr)
    free (connStr);

  mutex_leave (con->con_environment->env_mtx);

  return rc;
}


SQLRETURN SQL_API
SQLDriverConnect (
    SQLHDBC hdbc,
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
  return virtodbc__SQLDriverConnect (hdbc, hwnd, szConnStrIn, cbConnStrIn,
      szConnStrOut, cbConnStrOutMax, pcbConnStrOutMax, fDriverCompletion);
}


/*
#define _StrCopyIn(dest, src, len) \
{
  if (len == SQL_NTS)
    len = strlen (src);
  *dest = dk_alloc_box (len + 1, DV_SHORT_STRING);
  memcpy (*dest, src, len);
  (*dest)[len] = 0;
}
*/

SQLRETURN SQL_API
SQLConnect (
	SQLHDBC hdbc,
	SQLTCHAR * szDSN,
	SQLSMALLINT cbDSN,
	SQLTCHAR * szUID,
	SQLSMALLINT cbUID,
	SQLTCHAR * szPWD,
	SQLSMALLINT cbPWD)
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
