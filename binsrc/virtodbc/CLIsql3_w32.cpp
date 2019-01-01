/*
 *  $Id$
 *
 *  Win32 specific version of CLIsql3
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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
 */

#define UNICODE
#define _UNICODE

extern "C" {
#include "Dk.h"
#include "CLI.h"
#include "sqlver.h"
#include "libutil.h"
};
#include "w32util.h"
#include "kvlist.h"
#include "zcbrowser.h"

/* Remove funA/funW mapping */
#undef SQLDriverConnect
#undef SQLConnect

#define MAX_SERVER_LEN		1024
#define MAX_UID_LEN		64
#define MAX_PWD_LEN		64

extern PTSTR _virtuoso_tags;
extern BOOL virtodbc_LoginDlg (TKVList &props, HWND hWnd);
extern TZCBrowser _zcbrowser;
extern "C" int isdts_mode;


static LPWSTR
StrCopyInW (SQLCHAR *inStr, int size)
{
  WCHAR *outStr;
  int len;

  if (inStr == NULL)
    {
      inStr = (SQLCHAR *) "";
      size = -1;
    }
  else if (size == SQL_NTS)
    size = -1;

  len = MultiByteToWideChar (CP_ACP, MB_PRECOMPOSED, (char *) inStr, size, NULL, 0);
  outStr = (LPWSTR) malloc (len * sizeof (WCHAR));
  if (outStr)
    MultiByteToWideChar (CP_ACP, MB_PRECOMPOSED, (char *) inStr, size, outStr, len);

  return outStr;
}


static LPWSTR
StrCopyInW (SQLWCHAR *inStr, int size)
{
  WCHAR *outStr;

  if (inStr == NULL)
    inStr = (SQLWCHAR *) L"";

  if (size == SQL_NTS)
    return _tcsdup (inStr);
  if ((outStr = (WCHAR *) malloc ((size + 1) * sizeof (WCHAR))) != NULL)
    {
      memcpy (outStr, inStr, size * sizeof (WCHAR));
      outStr[size] = '\0';
    }
  return outStr;
}


static int
StrCopyOut (
    LPCWSTR inStr,
    SQLWCHAR *outStr,
    SQLSMALLINT size,
    SQLSMALLINT *result)
{
  size_t length;

  if (!inStr)
    inStr = L"";

  length = (wcslen (inStr) + 1) * sizeof (WCHAR);

  if (!outStr || size <= 0)
    {
      if (result)
	*result = (SQLSMALLINT) length;
      return -1;
    }

  if ((size_t) size >= length)
    {
      memcpy (outStr, inStr, length);
      if (result)
	*result = (SQLSMALLINT) (length - sizeof (WCHAR));
      return 0;
    }

  memcpy (outStr, inStr, size);
  size--;
  outStr[size / sizeof (WCHAR)] = 0;
  if (result)
    *result = (SQLSMALLINT) size;

  return -1;
}


static int
StrCopyOut (
    LPCWSTR inStr,
    SQLCHAR *outStr,
    SQLSMALLINT size,
    SQLSMALLINT *result)
{
  int length;

  if (!inStr)
    inStr = L"";

  length = WideCharToMultiByte (CP_ACP, 0, inStr, -1, NULL, 0, NULL, NULL);

  if (!outStr || size <= 0)
    {
      if (result)
	*result = (SQLSMALLINT) length;
      return -1;
    }

  if (size >= length)
    {
      length = WideCharToMultiByte (CP_ACP, 0, inStr, -1, (char *) outStr, size, NULL, NULL);
      if (result)
	*result = ((SQLSMALLINT) length - sizeof (CHAR));
      return 0;
    }

  outStr[0] = 0;
  WideCharToMultiByte (CP_ACP, 0, inStr, -1, (char *) outStr, size, NULL, NULL);
  size--;
  outStr[size / sizeof (CHAR)] = 0;
  if (result)
    *result = (SQLSMALLINT) size;

  return -1;
}


static char *
virt_wide_to_ansi (LPCWSTR in)
{
  int len;
  char *ret;

  if (!in)
    return NULL;

  len = WideCharToMultiByte(CP_ACP, 0, in, -1, NULL, 0, NULL , NULL );

  if (len == 0)
    return NULL;

  ret = (char *) dk_alloc_box (len, DV_SHORT_STRING);

  WideCharToMultiByte (CP_ACP, 0, in, -1, ret, len, NULL, NULL);

  return ret;
}


static LPWSTR
virt_ansi_to_wide (LPCSTR in)
{
  int len;
  LPWSTR ret;

  if (!in)
    return NULL;

  len = MultiByteToWideChar(CP_ACP, 0, in, -1,
      NULL, 0);

  if (len == 0)
    return NULL;

  ret = (LPWSTR) dk_alloc_box (len * sizeof (WCHAR), DV_SHORT_STRING);

  MultiByteToWideChar (CP_ACP, 0, in, -1,
      ret, len);

  return ret;
}


#define PUT_CONN_OPT(opt, o_inx) \
  if (opt) \
    { \
      LPWSTR wide = virt_ansi_to_wide ((LPCSTR) opt); \
      \
      props.Define (o_inx, wide); \
      dk_free_box ((box_t) wide); \
      \
      dk_free_box ((box_t) opt); \
      opt = NULL; \
    }

static void
PutConnectionOptions (cli_connection_t *con, TKVList& props)
{
  PUT_CONN_OPT (con->con_qualifier, _T("Database"));
  PUT_CONN_OPT (con->con_charset, _T("Charset"));
/*#ifdef _SSL
  PUT_CONN_OPT (con->con_encrypt, _T("Encrypt"));
#endif*/
}


static SQLRETURN
virtodbc_connect (
    SQLHDBC hdbc,
    HWND hWnd,
    TKVList& props,
    int completion)
{
  TCHAR szValue[256];
  TCHAR szEncrypt[MAX_PATH];
  TCHAR szUID[MAX_PATH]; /* could be certificate */
  TCHAR szPWD[MAX_PWD_LEN + 1];
  TCHAR szHost[MAX_SERVER_LEN + 1];
  SQLCHAR szUIDa[MAX_UID_LEN + 1];
  SQLCHAR szPWDa[MAX_PWD_LEN + 1];
  SQLCHAR szHosta[MAX_SERVER_LEN + 1];
  SQLRETURN rc = SQL_ERROR;
  LPCTSTR szStr;
  BOOL bResolveRV;
  BOOL bPrompt;
  CON (con, hdbc);

  PutConnectionOptions (con, props);
  /* Should we prompt? */
  if (completion == SQL_DRIVER_COMPLETE ||
      completion == SQL_DRIVER_COMPLETE_REQUIRED)
    {
      if (!props.Get (_T("HOST"), szHost, NUMCHARS (szHost)) ||
	  !props.Get (_T("UID"),  szUID, NUMCHARS (szUID)) ||
	  !props.Get (_T("PWD"), szPWD, NUMCHARS (szPWD)))
	{
	  bPrompt = TRUE;
	}
      else
	bPrompt = FALSE;
    }
  else
    bPrompt = (completion == SQL_DRIVER_PROMPT);

  /* User's dialog */
  if (bPrompt && !virtodbc_LoginDlg (props, hWnd))
    return SQL_NO_DATA_FOUND;

  /* UID */
  props.Get (_T("UID"), szUID, NUMCHARS (szUID));
  props.Get (_T("Encrypt"), szEncrypt, NUMCHARS (szEncrypt));

  /* PWD */
  props.Get (_T("PWD"), szPWD, NUMCHARS (szPWD));

  /* Address, Host - this needs some explanation
   *  Host : rendezvous name / host name / ip address
   *  Address : (not persisted, optional) resolved rendezvous IP from login dlg
   */
  if (props.Get (_T("Address"), szHost, NUMCHARS (szHost)))
    {
      /* Save ourselves time - the login dialog just looked up the rv name.
       * This is only for short-term caching and never persisted anywhere
       */
      bResolveRV = FALSE;
    }
  else if (props.Get (_T("Host"), szHost, NUMCHARS (szHost)))
    {
      /* Server is persisted in a DSN and may contain a rendezvous name */
      bResolveRV = (_tcschr (szHost, ':') == NULL && _tcschr (szHost, ',') == NULL);
    }

#ifdef _RENDEZVOUS
  /* Now attempt to resolve the rendezvous name */
  if (bResolveRV)
    {
      TZCPublication *p;

      /* Attempt resolve for 2 seconds - TODO use login timeout or such */
      if ((p = _zcbrowser.Resolve (szHost, 2000)) == NULL)
	{
	  /* TODO set error code & message */
	  return SQL_NO_DATA_FOUND;
	}
      DNSNetworkAddressToString (&p->address, szHost);
      p->Unref ();
    }
#endif

  mutex_enter (con->con_environment->env_mtx);

  /* Daylight */
  props.Get (_T("Daylight"), szValue, NUMCHARS (szValue));
  isdts_mode = OPTION_TRUE (szValue[0]);

  /* Charset */
  con->con_charset_name = virt_wide_to_ansi (props.Value (_T("Charset")));

  /* PWDCleartext */
  props.Get (_T("PWDClearText"), szValue, NUMCHARS (szValue));
  con->con_pwd_cleartext = _ttoi (szValue);

  if (props.Get (_T("RoundRobin"), szValue, NUMCHARS (szValue)))
    con->con_round_robin = OPTION_TRUE (szValue[0]) ? 1 : 0;


  /* Encrypt */
  if (con->con_encrypt)
    dk_free_box (con->con_encrypt);
  con->con_encrypt = NULL;
  if (con->con_pwd_cleartext == 3)
    {
      /* UID should hold the certificate filename the user selected at login */
      con->con_encrypt = virt_wide_to_ansi (szEncrypt);
      szUID[0] = 0;
    }
  else if ((szStr = props.Value (_T("Encrypt"))) != NULL &&
      _tcscmp (szStr, _T("0")))
    {
      con->con_encrypt = virt_wide_to_ansi (szStr);
    }

  /* ServerCert */
  if (con->con_ca_list)
    dk_free_box (con->con_ca_list);
  con->con_ca_list = NULL;
  if ((szStr = props.Value (_T("ServerCert"))) != NULL)
    {
      con->con_ca_list = virt_wide_to_ansi (szStr);
    }
  if ((szStr = props.Value (_T("FORCE_DBMS_NAME"))) != NULL ||
      (szStr = props.Value (_T("ForceDBMSName"))) != NULL)
    {
      char *force_dbms_name = virt_wide_to_ansi (szStr);
      strncpy (__virtodbc_dbms_name, force_dbms_name, sizeof (__virtodbc_dbms_name));
      __virtodbc_dbms_name[sizeof (__virtodbc_dbms_name) - 1] = 0;
      dk_free_box (force_dbms_name);
    }
  else
    strcpy_ck (__virtodbc_dbms_name, PRODUCT_DBMS);

  /* convert connect params from wide to ansi */
  StrCopyOut (szUID, szUIDa, sizeof (szUIDa), NULL);
  StrCopyOut (szPWD, szPWDa, sizeof (szPWDa), NULL);
  StrCopyOut (szHost, szHosta, sizeof (szHosta), NULL);

  if (props.Get (_T("NoSystemTables"), szValue, NUMCHARS (szValue)))
    con->con_no_system_tables = OPTION_TRUE (szValue[0]) ? 1 : 0;

  if (props.Get (_T("TreatViewsAsTables"), szValue, NUMCHARS (szValue)))
    con->con_treat_views_as_tables = OPTION_TRUE (szValue[0]) ? 1 : 0;

  rc = internal_sql_connect (hdbc,
      szHosta, SQL_NTS, szUIDa, SQL_NTS, szPWDa, SQL_NTS);

  /* Database */
  if ((rc == SQL_SUCCESS || rc == SQL_SUCCESS_WITH_INFO))
    {
      if (props.Get (_T("Database"), szValue, NUMCHARS (szValue)))
        {
          rc = SQLSetConnectAttr (hdbc, SQL_CURRENT_QUALIFIER,
	      (SQLTCHAR *) szValue, SQL_NTS);
        }
    }

  /* Isolation level */
  if ((rc == SQL_SUCCESS || rc == SQL_SUCCESS_WITH_INFO))
    {
      if (props.Get (_T("IsolationLevel"), szValue, NUMCHARS (szValue)))
	{
	  /* GK: this is kind of a hack localization-wise - the strings here should really come from the resource */
	  if (!_tcsicmp (szValue, _T("Read Uncommitted")))
	    con->con_isolation = SQL_TXN_READ_UNCOMMITTED;
	  else if (!_tcsicmp (szValue, _T("Read Committed")))
	    con->con_isolation = SQL_TXN_READ_COMMITTED;
	  else if (!_tcsicmp (szValue, _T("Repeatable Read")))
	    con->con_isolation = SQL_TXN_REPEATABLE_READ;
	  else if (!_tcsicmp (szValue, _T("Serializable")))
	    con->con_isolation = SQL_TXN_SERIALIZABLE;
	}
    }

  /* hmm- this should probably be somewhere else */
  dk_free_box (con->con_charset_name);
  con->con_charset_name = NULL;

  mutex_leave (con->con_environment->env_mtx);

  return rc;
}


static SQLRETURN SQL_API
virtodbc_SQLConnectW (
    SQLHDBC         hdbc,
    LPWSTR          szDSN,
    LPWSTR          szUID,
    LPWSTR          szPWD)
{
  TKVList props;

  if (szDSN)
    {
      props.Define (_T("DSN"), szDSN);
      props.ReadODBCIni (szDSN, _virtuoso_tags);
    }
  else
    props.ReadODBCIni (_T("Default"), _virtuoso_tags);

  if (szUID)
    props.Define (_T("UID"), szUID);

  if (szPWD)
    props.Define (_T("PWD"), szPWD);

  return virtodbc_connect (hdbc, NULL, props, SQL_DRIVER_NOPROMPT);
}


static SQLRETURN SQL_API
virtodbc_SQLDriverConnectW (
    SQLHDBC         hdbc,
    SQLHWND         hWnd,
    LPWSTR          szConnStrIn,
    LPWSTR *        pszConnStrOut,
    SQLUSMALLINT    fDriverCompletion)
{
  TCHAR szValue[MAX_PATH];
  TKVList props;
  SQLRETURN rc;

  props.FromDSN (szConnStrIn);
  if (props.Get (_T("DSN"), szValue, NUMCHARS (szValue)))
    {
      /* Read DSN information from registry */
      props.ReadODBCIni (szValue, _virtuoso_tags);
      props.FromDSN (szConnStrIn);
    }
  else if (props.Get (_T("FILEDSN"), szValue, NUMCHARS (szValue)))
    {
      /* Read DSN information from filedsn */
      props.ReadFileDSN (szValue, _virtuoso_tags);
      props.FromDSN (szConnStrIn);
    }
  else
    props.ReadODBCIni (_T("Default"), _virtuoso_tags);

  rc = virtodbc_connect (hdbc, hWnd, props, fDriverCompletion);

  if (rc == SQL_SUCCESS || rc == SQL_SUCCESS_WITH_INFO)
    {
      /* undefine Address, so an app doesn't persist it (it's rendezvous) */
      props.Undefine (_T("Address"));
      if (props.Find (_T("SERVER")) == NOT_FOUND && props.Find (_T("DRIVER")) != NOT_FOUND)
	props.Define (_T("SERVER"), _T("OpenLink Virtuoso"));
      *pszConnStrOut = props.ToDSN ();
    }
  else
    *pszConnStrOut = NULL;

  return rc;
}


SQLRETURN SQL_API
SQLDriverConnect (
    SQLHDBC         hdbc,
    SQLHWND         hwnd,
    SQLCHAR        *szConnStrIn,
    SQLSMALLINT     cbConnStrIn,
    SQLCHAR        *szConnStrOut,
    SQLSMALLINT     cbConnStrOutMax,
    SQLSMALLINT    *pcbConnStrOut,
    SQLUSMALLINT    fDriverCompletion)
{
  LPWSTR wszConnStrIn = StrCopyInW (szConnStrIn, cbConnStrIn);
  LPWSTR wszConnStrOut = NULL;
  SQLRETURN rc;
  CON(con, hdbc);


  rc = virtodbc_SQLDriverConnectW (hdbc, hwnd, wszConnStrIn, &wszConnStrOut,
      fDriverCompletion);

  if (-1 == StrCopyOut (wszConnStrOut, szConnStrOut, cbConnStrOutMax, pcbConnStrOut))
    {
      rc = SQL_SUCCESS_WITH_INFO;
      set_success_info (&con->con_error, "01004", "CLW02", "String data, right truncated", 0);
    }

  if (wszConnStrIn)
    free (wszConnStrIn);
  if (wszConnStrOut)
    free (wszConnStrOut);

  return rc;
}


SQLRETURN SQL_API
SQLConnect (
    SQLHDBC         hdbc,
    SQLCHAR        *szDSN,
    SQLSMALLINT     cbDSN,
    SQLCHAR        *szUID,
    SQLSMALLINT     cbUID,
    SQLCHAR        *szAuthStr,
    SQLSMALLINT     cbAuthStr)
{
  LPWSTR wszDSN = StrCopyInW (szDSN, cbDSN);
  LPWSTR wszUID = StrCopyInW (szUID, cbUID);
  LPWSTR wszPWD = StrCopyInW (szAuthStr, cbAuthStr);
  SQLRETURN rc;

  rc = virtodbc_SQLConnectW (hdbc, wszDSN, wszUID, wszPWD);

  if (wszDSN)
    free (wszDSN);
  if (wszUID)
    free (wszUID);
  if (wszPWD)
    free (wszPWD);

  return rc;
}


SQLRETURN SQL_API
SQLDriverConnectW (
    SQLHDBC         hdbc,
    SQLHWND         hwnd,
    SQLWCHAR       *szConnStrIn,
    SQLSMALLINT     cbConnStrIn,
    SQLWCHAR       *szConnStrOut,
    SQLSMALLINT     cbConnStrOutMax,
    SQLSMALLINT    *pcbConnStrOut,
    SQLUSMALLINT    fDriverCompletion)
{
  LPWSTR wszConnStrIn = StrCopyInW (szConnStrIn, cbConnStrIn);
  LPWSTR wszConnStrOut = NULL;
  SQLRETURN rc;
  CON(con, hdbc);

  rc = virtodbc_SQLDriverConnectW (hdbc, hwnd, wszConnStrIn, &wszConnStrOut,
      fDriverCompletion);

  if (-1 == StrCopyOut (wszConnStrOut, szConnStrOut, cbConnStrOutMax, pcbConnStrOut))
    {
      if (rc == SQL_SUCCESS || rc == SQL_SUCCESS_WITH_INFO)
        {
          rc = SQL_SUCCESS_WITH_INFO;
          set_success_info (&con->con_error, "01004", "CLW03", "String data, right truncated", 0);
        }
    }

  if (wszConnStrIn)
    free (wszConnStrIn);
  if (wszConnStrOut)
    free (wszConnStrOut);

  return rc;
}


SQLRETURN SQL_API
SQLConnectW (
    SQLHDBC         hdbc,
    SQLWCHAR       *szDSN,
    SQLSMALLINT     cbDSN,
    SQLWCHAR       *szUID,
    SQLSMALLINT     cbUID,
    SQLWCHAR       *szAuthStr,
    SQLSMALLINT     cbAuthStr)
{
  LPWSTR wszDSN = StrCopyInW (szDSN, cbDSN);
  LPWSTR wszUID = StrCopyInW (szUID, cbUID);
  LPWSTR wszPWD = StrCopyInW (szAuthStr, cbAuthStr);
  SQLRETURN rc;

  rc = virtodbc_SQLConnectW (hdbc, wszDSN, wszUID, wszPWD);

  if (wszDSN)
    free (wszDSN);
  if (wszUID)
    free (wszUID);
  if (wszPWD)
    free (wszPWD);

  return rc;
}
