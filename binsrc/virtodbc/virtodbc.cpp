/*
 *  virtodbc.cpp
 *
 *  $Id$
 *
 *  Common includes for win32 utilties
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
 */

#include "w32util.h"
#include "waitcursor.h"
#include "winctl.h"
#include "dialog.h"
#include "wizard.h"
#include "zcbrowser.h"
#include "zcbrowsercombo.h"
#include "kvlist.h"
#include "resource.h"

/* authentication methods, in combobox list order */
#define AUTHMETHOD_CHALLENGE	0	/* PWDClearText == 0 */
#define AUTHMETHOD_ENCRYPTED	1	/* PWDClearText == 2 */
#define AUTHMETHOD_CLEAR	2	/* PWDClearText == 1 */
#define AUTHMETHOD_PKCS12	3	/* PWDClearText == 3 */

/* string lengths */
#define MAX_DSN_LEN		64
#define MAX_COMMENT_LEN		255
#define MAX_SERVER_LEN		1024
#define MAX_UID_LEN		64
#define MAX_PWD_LEN		64
#define MAX_DB_LEN		64
#define MAX_CS_LEN		100
#define MAX_IL_LEN		32
#define MAX_BOOL_LEN		10
#define MAX_ENC_LEN		255

#define ISFILENAME(X)		(_tcschr (X, '.') != NULL)
#define ONLY_ONE_OF(A,B)	(((A) && !(B)) || (!(A) && (B)))

#ifndef UNICODE
#define _SQLCHAR	SQLCHAR
#define _SQL_C_CHAR	SQL_C_CHAR
#else
#define _SQLCHAR	SQLWCHAR
#define _SQL_C_CHAR	SQL_C_WCHAR
#endif

/* ODBC test connection */
struct TODBCConn : TDialog
  {
    SQLHENV m_hEnv;
    SQLHDBC m_hDbc;
    SQLHSTMT m_hStmt;
    TCHAR m_szSQLState[10];
    TCHAR m_szSQLMessage[512];

    TODBCConn ();
    ~TODBCConn ();
    virtual BOOL OnInitDialog (void);
    void ShowError (HINSTANCE hInstance, HWND hParentWnd);
    void ShowStmtError (HINSTANCE hInstance, HWND hParentWnd);
    BOOL Connect (HWND hWnd, LPCTSTR szDsn);
  };

/* Setup Dialog */
struct TSetupDlg : public TWizard
  {
    TEditCtl m_DSN;
    TEditCtl m_COMMENT;
    TZCBrowserCombo m_SERVER;
    TCheckCtl m_USESSL;
    TComboCtl m_AUTHMETHOD;
    TCheckCtl m_USEUID;
    TTextCtl m_UIDLBL;
    TEditCtl m_UID;
    TCtl m_BROWSEUIDCERT;
    TTextCtl m_PWDLBL;
    TEditCtl m_PWD;
    TCheckCtl m_USESERVERCERT;
    TTextCtl m_SERVERCERTLBL;
    TEditCtl m_SERVERCERT;
    TCtl m_BROWSESERVERCERT;
    TCheckCtl m_NOLOGINBOX;
    TCheckCtl m_USEDEFAULTDB;
    TComboCtl m_DEFAULTDB;
    TCheckCtl m_USEDEFAULTCS;
    TComboCtl m_DEFAULTCS;
    TCheckCtl m_USEDEFAULTIL;
    TComboCtl m_DEFAULTIL;
    TCheckCtl m_USEDSTCORRECT;
    TCheckCtl m_NOSYSTEMTABLES;
    TCheckCtl m_TREATVIEWSASTABLES;
    TCheckCtl m_ROUNDROBIN;

    BOOL m_bFileDSN;
    TKVList& m_props;
    LPARAM m_dwNotifyCode;
    DWORD m_dwClearText;

    TSetupDlg (TKVList& props) : m_props(props) {}
    BOOL IsDlgComboEmpty (TComboCtl& ctl);
    virtual BOOL IsPageValid (void);
    void LoadFromProps (void);
    void SaveToProps (void);
    virtual BOOL OnInitDialog (void);
    virtual void OnCommand (DWORD dwCmd, LPARAM lParam);
    virtual BOOL OnOtherMsg (UINT uMsg, WPARAM wParam, LPARAM lParam);

    void SetUseServerCert (BOOL bForceBrowse);
    void SetUseUID (void);
    void SetUseDefaultDB (void);
    void SetUseDefaultCS (void);
    void SetUseDefaultIL (void);
    void SetAuthMethod (void);
    BOOL ODBCConnect (TODBCConn &conn);
    BOOL FillDBCombos (void);
    void FillIsolationLevels (void);
    void FillAuthMethods (void);
  };

/* Login Dialog */
struct TLoginDlg : public TDialog
  {
    TEditCtl m_DSN;
    TTextCtl m_UIDLBL;
    TEditCtl m_UID;
    TEditCtl m_PWD;
    TCtl m_BROWSEUIDCERT;

    TKVList& m_props;
    DWORD m_dwClearText;

    TLoginDlg (TKVList& props) : m_props(props) {}
    void LoadFromProps (void);
    void SaveToProps (void);
    virtual BOOL OnInitDialog (void);
    virtual void OnCommand (DWORD dwCmd, LPARAM lParam);
    void OnOptions (void);
  };


PTSTR _virtuoso_tags =
  _T("Charset\0")
  _T("Database\0")
  _T("Daylight\0")
  _T("Description\0")
  _T("Encrypt\0")
  _T("Host\0")
  _T("NoLoginBox\0")
  _T("PWD\0")
  _T("PWDClearText\0")
  _T("ServerCert\0")
  _T("UID\0")
  _T("Address\0")
  _T("ForceDBMSName\0")
  _T("IsolationLevel\0")
  _T("NoSystemTables\0")
  _T("TreatViewsAsTables\0")
  _T("RoundRobin\0")
  ;

static HINSTANCE g_hInstance;

////////////////////////////////////////////////////////////////////////////////
// UTILITIES
////////////////////////////////////////////////////////////////////////////////

#if 0
void
trace (LPCTSTR fmt, ...)
{
  static TCHAR buf[1024];
  va_list ap;
  va_start (ap,fmt);
  _vstprintf (buf, fmt, ap);
#if 0
  OutputDebugString(buf);
#else
  _fputts (buf, stderr);
  fputc ('\n', stderr);
#endif
}
#endif


static BOOL
CalledFromODBCAD32 (void)
{
  static LPTSTR szODBCAD32 = _T("ODBCAD32.EXE");
  LPTSTR szArg;

#ifdef UNICODE
  szArg = GetCommandLineW ();
#else
  szArg = GetCommandLine ();
#endif
  if ((szArg = _tcsrchr (szArg, '\\')) != NULL)
    {
      szArg++;
      if (!_tcsnicmp (szArg, szODBCAD32, _tcslen (szODBCAD32)))
	return TRUE;
    }

  return FALSE;
}


BOOL
BrowseForFile (HINSTANCE hInstance, TTextCtl& ctl, DWORD dwResId)
{
  OPENFILENAME OpenFileName;
  TCHAR szFileName[MAX_PATH];
  TCHAR szFormat[256];
  PTSTR cp;

  LoadString (hInstance, dwResId, szFormat, sizeof (szFormat));
  while ((cp = _tcsrchr (szFormat, '|')) != NULL)
    *cp = '\0';

  _tcscpy (szFileName, ctl.Text ());
  OpenFileName.lStructSize = sizeof (OPENFILENAME);
  OpenFileName.hwndOwner = GetParent (ctl.m_hCtl);
  OpenFileName.hInstance = NULL;
  OpenFileName.lpstrFilter = szFormat;
  OpenFileName.lpstrCustomFilter = (LPTSTR) 0;
  OpenFileName.nMaxCustFilter = 0L;
  OpenFileName.nFilterIndex = 1L;
  OpenFileName.lpstrFileTitle = NULL;
  OpenFileName.nMaxFileTitle = 0;
  OpenFileName.lpstrFile = szFileName;
  OpenFileName.nMaxFile = MAX_PATH;
  OpenFileName.lpstrInitialDir = NULL;
  OpenFileName.lpstrTitle = NULL;
  OpenFileName.nFileOffset = 0;
  OpenFileName.nFileExtension = 0;
  OpenFileName.lpstrDefExt = _T("p12");
  OpenFileName.lCustData = 0;
  OpenFileName.Flags = OFN_EXPLORER | OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST |
      OFN_HIDEREADONLY;

  if (GetOpenFileName (&OpenFileName))
    {
      ctl.Text (szFileName);
      return TRUE;
    }
  else
    return FALSE;
}

////////////////////////////////////////////////////////////////////////////////
// SETUP DIALOG
////////////////////////////////////////////////////////////////////////////////

BOOL
TSetupDlg::ODBCConnect (TODBCConn &conn)
{
  TCHAR szDSN[MAX_SERVER_LEN + MAX_PATH + MAX_PWD_LEN + 100];
  LPCTSTR szHost;

  /* Make sure we have resolved the ZC name,
   * or that the user type <host>:<port> in the server name window
   */
  if ((szHost = m_SERVER.GetHost ()) == NULL)
    {
      conn.m_szSQLState[0] = 0;
      LoadString (m_hInstance,
	  IDS_ZCUNRESOLVED,
	  conn.m_szSQLMessage, NUMCHARS (conn.m_szSQLMessage));
      conn.ShowError (m_hInstance, m_hWnd);
      ChangePage (0);
      return FALSE;
    }

  if (m_AUTHMETHOD.CurSel () == AUTHMETHOD_PKCS12)
    {
      _stprintf (szDSN, _T("HOST=%s;UID=;ENCRYPT=%s;PWD=%s;SERVERCERT=%s"),
	  szHost,
	  m_UID.Text (),
	  m_PWD.Text (),
	  m_USESERVERCERT.Checked () ? m_SERVERCERT.Text () : _T(""));
    }
  else
    {
      _stprintf (szDSN, _T("HOST=%s;UID=%s;PWD=%s"),
	  szHost,
	  m_UID.Text (),
	  m_PWD.Text ());
      if (m_USESSL.Checked ())
	_tcscat (szDSN, _T(";ENCRYPT=1"));
    }

  if (!conn.Connect (m_hWnd, szDSN))
    {
      conn.ShowError (m_hInstance, m_hWnd);
      return FALSE;
    }

  return TRUE;
}


BOOL
TSetupDlg::IsDlgComboEmpty (TComboCtl& ctl)
{
  if (m_dwNotifyCode == MAKELPARAM (ctl.m_dwResId, CBN_SELCHANGE))
    return ctl.CurSel () == CB_ERR;
  else
    return ctl.TextLength () == 0;
}


BOOL
TSetupDlg::IsPageValid (void)
{
  switch (m_iCurPage)
    {
    case 0:
      /* DSN not blank */
      if (!m_bFileDSN)
	{
	  if (m_DSN.TextLength() == 0)
	    return FALSE;

	  /* DSN valid, except for file dsns */
	  if (!SQLValidDSN (m_DSN.Text ()))
	    return FALSE;
	}

      /* Server not blank */
      if (IsDlgComboEmpty (m_SERVER))
	return FALSE;
      break;

    case 1:
      /* If using login to connect to db for settings, then not blank */
      if (m_USEUID.Checked () && m_UID.TextLength() == 0)
	return FALSE;

      /* If using server certificate, then not blank */
      if (m_USESERVERCERT.Checked () && m_SERVERCERT.TextLength() == 0)
	return FALSE;

      break;

    case 2:
      /* If not using default database, then not blank */
      if (m_USEDEFAULTDB.Checked () && IsDlgComboEmpty (m_DEFAULTDB))
	return FALSE;

      /* If not using default charset, then not blank */
      if (m_USEDEFAULTCS.Checked () && IsDlgComboEmpty (m_DEFAULTCS))
	return FALSE;

      /* If not using default isolation level, then not blank */
      if (m_USEDEFAULTIL.Checked () && IsDlgComboEmpty (m_DEFAULTIL))
	return FALSE;
      break;

    default:
      break;
    }

  return TRUE;
}


void
TSetupDlg::SetUseServerCert (BOOL bForceBrowse)
{
  BOOL bOn = m_USESERVERCERT.Checked ();

  /* If checked, then browse for cert.
   * if the user canceled the browse, then uncheck
   */
  if (bOn && bForceBrowse &&
      m_SERVERCERT.TextLength () == 0 &&
      !BrowseForFile (m_hInstance, m_SERVERCERT, IDS_X509BROWSE))
    {
      bOn = FALSE;
      m_USESERVERCERT.Check (bOn);
    }
  m_SERVERCERT.Enable (bOn);
  m_BROWSESERVERCERT.Enable (bOn);
}


void
TSetupDlg::SetUseUID (void)
{
  BOOL bOn = m_USEUID.Checked ();
  m_UIDLBL.Enable (bOn);
  m_UID.Enable (bOn);
  m_PWDLBL.Enable (bOn);
  m_PWD.Enable (bOn);
  m_BROWSEUIDCERT.Enable (bOn);
}


void
TSetupDlg::SetUseDefaultDB (void)
{
  m_DEFAULTDB.Enable (m_USEDEFAULTDB.Checked ());
}


void
TSetupDlg::SetUseDefaultIL (void)
{
  m_DEFAULTIL.Enable (m_USEDEFAULTIL.Checked ());
}

void
TSetupDlg::SetUseDefaultCS (void)
{
  m_DEFAULTCS.Enable (m_USEDEFAULTCS.Checked ());
}


void
TSetupDlg::SetAuthMethod (void)
{
  TCHAR szText[32];
  BOOL bCertBased;
  PTSTR szUID;

  bCertBased = (m_AUTHMETHOD.CurSel () == AUTHMETHOD_PKCS12) ? 1 : 0;

  /* change label from 'Login ID' <--> 'PKCS12 File' */
  LoadString (m_hInstance, bCertBased ? IDS_PKCS12LBL : IDS_UIDLBL,
      szText, NUMCHARS (szText));
  m_UIDLBL.Text (szText);

  /* Re-limit the length for the UID edit control */
  SendMessage (m_UID.m_hCtl, EM_LIMITTEXT,
      bCertBased ? MAX_PATH : MAX_UID_LEN, 0);

  /* Clear UID if authmethod changed from certbased <--> normal */
  szUID = m_UID.Text ();
  if (ONLY_ONE_OF (bCertBased, ISFILENAME (szUID)))
    {
      m_UID.Text (_T(""));
      m_PWD.Text (_T(""));
    }
  m_UID.ReadOnly (bCertBased);

  /* Show browse button for PKCS12 File authentication */
  m_BROWSEUIDCERT.Show (bCertBased);
}


BOOL
TSetupDlg::FillDBCombos (void)
{
  TWaitCursor wc;
  LPTSTR szValue;
  TCHAR szText[256];
  TODBCConn conn;
  //SQLLEN datalen;
  SQLLEN datalen;
  int rc;
  int iIndex;

  if (!m_USEUID.Checked ())
    return TRUE;

  if (!ODBCConnect (conn))
    return FALSE;

  /* Get current text */
  szValue = m_DEFAULTDB.Text ();
  m_DEFAULTDB.Clear ();

  /* Add Items */
  rc = SQLTables (conn.m_hStmt,
      (_SQLCHAR *) _T(SQL_ALL_CATALOGS), SQL_NTS,
      (_SQLCHAR *) _T(""), SQL_NTS,
      (_SQLCHAR *) _T(""), SQL_NTS,
      (_SQLCHAR *) _T(""), SQL_NTS);
  if (rc == SQL_SUCCESS)
    {
      while ((rc = SQLFetch (conn.m_hStmt)) == SQL_SUCCESS)
	{
	  rc = SQLGetData (conn.m_hStmt, 1, _SQL_C_CHAR,
		  szText, sizeof (szText), &datalen);
	  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	    break;
	  if (datalen > 0 && datalen < sizeof (szText))
	    {
	      szText[datalen / sizeof (TCHAR)] = 0;
	      m_DEFAULTDB.AddString (szText);
	    }
	}
    }
  if (rc == SQL_ERROR)
    conn.ShowStmtError (m_hInstance, m_hWnd);

  /* Set old value */
  m_DEFAULTDB.Text (szValue);
  iIndex = m_DEFAULTDB.FindExact (szValue);
  if (iIndex != CB_ERR)
    m_DEFAULTDB.CurSel (iIndex);

  /* Same trick, now for character set combo */

  /* Get current text */
  szValue = m_DEFAULTCS.Text ();
  m_DEFAULTCS.Clear ();

  /* Add Items */
  rc = SQLExecDirect (conn.m_hStmt,
      (_SQLCHAR *) _T ("SELECT CS_NAME FROM DB.DBA.SYS_CHARSETS"), SQL_NTS);
  if (rc == SQL_SUCCESS)
    {
      while ((rc = SQLFetch (conn.m_hStmt)) == SQL_SUCCESS)
	{
	  rc = SQLGetData (conn.m_hStmt, 1, _SQL_C_CHAR,
	      szText, sizeof (szText), &datalen);
	  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	    break;
	  if (datalen > 0 && datalen < sizeof (szText))
	    {
	      szText[datalen / sizeof (TCHAR)] = 0;
	      m_DEFAULTCS.AddString (szText);
	    }
	}
    }
  if (rc == SQL_ERROR)
    conn.ShowStmtError (m_hInstance, m_hWnd);

  /* Set old value */
  m_DEFAULTCS.Text (szValue);
  iIndex = m_DEFAULTCS.FindExact (szValue);
  if (iIndex != CB_ERR)
    m_DEFAULTCS.CurSel (iIndex);

  return TRUE;
}


void
TSetupDlg::FillAuthMethods (void)
{
  LPTSTR szValue;
  TCHAR szText[256];
  int iIndex;
  int i;

  /* Get current text */
  szValue = m_AUTHMETHOD.Text ();
  m_AUTHMETHOD.Clear ();
  for (i = 0; i < 3; i++)
    {
      LoadString (m_hInstance, IDS_AUTHMETHOD1 + i, szText, NUMCHARS (szText));
      m_AUTHMETHOD.AddString (szText);
    }

  BOOL bOn;
  if ((bOn = m_USESSL.Checked ()))
    {
      LoadString (m_hInstance, IDS_AUTHMETHOD4, szText, NUMCHARS (szText));
      m_AUTHMETHOD.AddString (szText);
    }
  m_USESERVERCERT.Show (bOn);
  m_SERVERCERTLBL.Show (bOn);
  m_SERVERCERT.Show (bOn);
  m_BROWSESERVERCERT.Show (bOn);

  /* Set + select old value */
  m_AUTHMETHOD.Text (szValue);
  iIndex = m_AUTHMETHOD.FindExact (szValue);
  if (iIndex == CB_ERR)
    {
      switch (m_dwClearText)
	{
	case 1: /* clear text */
	  iIndex = AUTHMETHOD_CLEAR;
	  break;
	case 2: /* encrypted */
	  iIndex = AUTHMETHOD_ENCRYPTED;
	  break;
	case 3: /* cert. based */
	  iIndex = AUTHMETHOD_PKCS12;
	  break;
	default:
	  iIndex = AUTHMETHOD_CHALLENGE;
	  break;
	};
    }
  m_AUTHMETHOD.CurSel (iIndex);
  SetAuthMethod ();
}


void
TSetupDlg::LoadFromProps (void)
{
  TCHAR szValue[1024];
  HWND hFocusWnd;

  hFocusWnd = GetFocus ();

  /* page 1 */

  /* DSN */
  if (!m_props.Get (_T("DSN"), szValue, NUMCHARS (szValue)))
    m_props.Get (_T("FILEDSN"), szValue, NUMCHARS (szValue));
  m_DSN.Text (szValue);

  /* Comment */
  m_props.Get (_T("Description"), szValue, NUMCHARS (szValue));
  m_COMMENT.Text (szValue);

  /* Server */
  m_props.Get (_T("Host"), szValue, NUMCHARS (szValue));
  m_SERVER.CurSel (m_SERVER.AddString (szValue));

  /* Require SSL */
  if (m_props.Get (_T("Encrypt"), szValue, NUMCHARS (szValue)))
    m_USESSL.Check (OPTION_TRUE (szValue[0]));
  else
    m_USESSL.Check (FALSE);

#ifndef _SSL
  m_USESSL.Check (FALSE);
  m_USESSL.Enable (FALSE);
  m_USESSL.Show (FALSE);
#endif

  /* Page 2 */

  /* Authentication method */
  if (m_props.Get (_T("PWDClearText"), szValue, NUMCHARS (szValue)))
    m_dwClearText = _ttoi (szValue);
  else
    m_dwClearText = 0;

  /* Connect with this UID/PWD to get settings */
  m_props.Get (_T("PWD"), szValue, NUMCHARS (szValue));
  m_PWD.Text (szValue);

  m_props.Get (_T("UID"), szValue, NUMCHARS (szValue));
  if (ONLY_ONE_OF (m_dwClearText == 3, ISFILENAME (szValue)))
    szValue[0] = 0;
  m_UID.Text (szValue);
  m_USEUID.Check (m_bFileDSN || szValue[0]);
  SetUseUID ();

  /* Server's certificate */
  m_props.Get (_T("ServerCert"), szValue, NUMCHARS (szValue));
  m_SERVERCERT.Text (szValue);
  m_USESERVERCERT.Check (szValue[0]);
  SetUseServerCert (FALSE);

  /* Skip login if possible */
  m_props.Get (_T("NoLoginBox"), szValue, NUMCHARS (szValue));
  m_NOLOGINBOX.Check (OPTION_TRUE (szValue[0]));

  /* Page 3 */

  /* Use another database */
  m_props.Get (_T("Database"), szValue, NUMCHARS (szValue));
  m_USEDEFAULTDB.Check (szValue[0]);
  m_DEFAULTDB.Text (szValue);
  SetUseDefaultDB ();

  /* Use another isolation level */
  m_props.Get (_T("IsolationLevel"), szValue, NUMCHARS (szValue));
  m_USEDEFAULTIL.Check (szValue[0]);
  m_DEFAULTIL.Text (szValue);
  SetUseDefaultIL ();

  /* Use another charset */
  m_props.Get (_T("Charset"), szValue, NUMCHARS (szValue));
  m_USEDEFAULTCS.Check (szValue[0]);
  m_DEFAULTCS.Text (szValue);
  SetUseDefaultCS ();

  m_props.Get (_T("Daylight"), szValue, NUMCHARS (szValue));
  m_USEDSTCORRECT.Check (OPTION_TRUE (szValue[0]));

  m_props.Get (_T("NoSystemTables"), szValue, NUMCHARS (szValue));
  m_NOSYSTEMTABLES.Check (OPTION_TRUE (szValue[0]));

  m_props.Get (_T("TreatViewsAsTables"), szValue, NUMCHARS (szValue));
  m_TREATVIEWSASTABLES.Check (OPTION_TRUE (szValue[0]));

  m_props.Get (_T("RoundRobin"), szValue, NUMCHARS (szValue));
  m_ROUNDROBIN.Check (OPTION_TRUE (szValue[0]));

  SetFocus (hFocusWnd);
}


void
TSetupDlg::SaveToProps (void)
{
  int iIndex;

  /* Page 1 */
  if (!m_bFileDSN)
    m_props.Define (_T("DSN"), m_DSN.Text ());

  m_props.Define (_T("Description"), m_COMMENT.Text ());

  TCHAR *szServer = m_SERVER.Text ();
  m_props.Define (_T("Host"), szServer);

  if (m_SERVER.IsResolved ())
    m_props.Define (_T("Address"), m_SERVER.GetHost ());
  else
    m_props.Define (_T("Address"), szServer);

  if (m_USESSL.Checked ())
    m_props.Define (_T("Encrypt"), _T("1"));
  else
    m_props.Define (_T("Encrypt"), _T("0"));

  /* Page 2 */
  iIndex = m_AUTHMETHOD.CurSel ();
  switch (iIndex)
    {
    case AUTHMETHOD_CHALLENGE:
      m_props.Define (_T("PWDClearText"), _T("0"));
      break;
    case AUTHMETHOD_ENCRYPTED:
      m_props.Define (_T("PWDClearText"), _T("2"));
      break;
    case AUTHMETHOD_CLEAR:
      m_props.Define (_T("PWDClearText"), _T("1"));
      break;
    case AUTHMETHOD_PKCS12:
      m_props.Define (_T("PWDClearText"), _T("3"));
      //m_props.Define (_T("Encrypt"), m_UID.Text ());
      break;
    }

  if (m_USEUID.Checked ())
    {
      m_props.Define (_T("UID"), m_UID.Text ());
      m_props.Define (_T("PWD"), m_PWD.Text ());
    }
  else
    {
      m_props.Undefine (_T("UID"));
      m_props.Undefine (_T("PWD"));
    }

  if (m_USESERVERCERT.Checked () && m_USESSL.Checked ())
    {
      m_props.Define (_T("ServerCert"), m_SERVERCERT.Text ());
    }
  else
    {
      m_props.Undefine (_T("ServerCert"));
    }

  if (m_NOLOGINBOX.Checked ())
    m_props.Define (_T("NoLoginBox"), _T("1"));
  else
    m_props.Undefine (_T("NoLoginBox"));

  /* Page 3 */
  if (m_USEDEFAULTDB.Checked ())
    m_props.Define (_T("Database"), m_DEFAULTDB.Text ());
  else
    m_props.Undefine (_T("Database"));

  if (m_USEDEFAULTIL.Checked ())
    m_props.Define (_T("IsolationLevel"), m_DEFAULTIL.Text ());
  else
    m_props.Undefine (_T("IsolationLevel"));

  if (m_USEDEFAULTCS.Checked ())
    m_props.Define (_T("Charset"), m_DEFAULTCS.Text ());
  else
    m_props.Undefine (_T("Charset"));

  if (m_USEDSTCORRECT.Checked ())
    m_props.Define (_T("Daylight"), _T("Yes"));
  else
    m_props.Undefine (_T("Daylight"));

  if (m_NOSYSTEMTABLES.Checked ())
    m_props.Define (_T("NoSystemTables"), _T("Yes"));
  else
    m_props.Undefine (_T("NoSystemTables"));

  if (m_TREATVIEWSASTABLES.Checked ())
    m_props.Define (_T("TreatViewsAsTables"), _T("Yes"));
  else
    m_props.Define (_T("TreatViewsAsTables"), _T("No"));

  if (m_ROUNDROBIN.Checked ())
    m_props.Define (_T("RoundRobin"), _T("Yes"));
  else
    m_props.Define (_T("RoundRobin"), _T("No"));
}

void
TSetupDlg::FillIsolationLevels (void)
{
  LPTSTR szValue;
  TCHAR szText[256];
  int i, iIndex;

  szValue = m_DEFAULTIL.Text ();
  m_DEFAULTIL.Clear ();
  for (i =0; i < 4; i++)
    {
      LoadString (m_hInstance, IDS_ISOLATIONLEVEL1 + i, szText, NUMCHARS (szText));
      m_DEFAULTIL.AddString (szText);
    }
  m_DEFAULTIL.Text (szValue);
  iIndex = m_DEFAULTIL.FindExact (szValue);
  if (iIndex != CB_ERR)
    m_DEFAULTIL.CurSel (iIndex);
}

BOOL
TSetupDlg::OnInitDialog (void)
{
  HWND hWnd;

  TWizard::OnInitDialog ();

  /* Page 1 */
  hWnd = AddPage (IDD_CONFIGPAGE1);
  m_DSN.Attach (hWnd, IDC_DSN, MAX_DSN_LEN);
  m_COMMENT.Attach (hWnd, IDC_COMMENT, MAX_COMMENT_LEN);
  m_SERVER.Attach (m_hWnd, hWnd, IDC_SERVER, MAX_SERVER_LEN);
  m_USESSL.Attach (hWnd, IDC_USESSL);
  m_ROUNDROBIN.Attach (hWnd, IDC_RROBIN);

  /* Page 2 */
  hWnd = AddPage (IDD_CONFIGPAGE2);
  m_AUTHMETHOD.Attach (hWnd, IDC_AUTHMETHOD, 64);
  m_USEUID.Attach (hWnd, IDC_USEUID);
  m_UIDLBL.Attach (hWnd, IDC_UIDLBL, 64);
  m_UID.Attach (hWnd, IDC_UID, MAX_PATH);	/* limited in SetAuthMethod */
  m_BROWSEUIDCERT.Attach (hWnd, IDC_BROWSEUIDCERT);
  m_PWDLBL.Attach (hWnd, IDC_PWDLBL, 64);
  m_PWD.Attach (hWnd, IDC_PWD, MAX_PWD_LEN);
  m_USESERVERCERT.Attach (hWnd, IDC_USESERVERCERT);
  m_SERVERCERTLBL.Attach (hWnd, IDC_SERVERCERTLBL, 64);
  m_SERVERCERT.Attach (hWnd, IDC_SERVERCERT, MAX_PATH);
  m_BROWSESERVERCERT.Attach (hWnd, IDC_BROWSESERVERCERT);
  m_NOLOGINBOX.Attach (hWnd, IDC_NOLOGINBOX);

  /* Page 3 */
  hWnd = AddPage (IDD_CONFIGPAGE3);
  m_USEDEFAULTDB.Attach (hWnd, IDC_USEDEFAULTDB);
  m_DEFAULTDB.Attach (hWnd, IDC_DEFAULTDB, MAX_DB_LEN);
  m_USEDEFAULTIL.Attach (hWnd, IDC_USEDEFAULTIL);
  m_DEFAULTIL.Attach (hWnd, IDC_DEFAULTIL, MAX_IL_LEN);
  m_USEDEFAULTCS.Attach (hWnd, IDC_USEDEFAULTCS);
  m_DEFAULTCS.Attach (hWnd, IDC_DEFAULTCS, MAX_CS_LEN);
  m_USEDSTCORRECT.Attach (hWnd, IDC_USEDSTCORRECT);
  m_NOSYSTEMTABLES.Attach (hWnd, IDC_NOSYSTEMTABLES);
  m_TREATVIEWSASTABLES.Attach (hWnd, IDC_TREATVIEWSASTABLES);

  LoadFromProps ();

  m_SERVER.TryResolve ();

  m_USEUID.Check (TRUE);
  SetUseUID ();

  if (m_bFileDSN)
    {
      m_DSN.ReadOnly (TRUE);
      m_hFirstCtl[0] = m_COMMENT.m_hCtl;
      m_USEUID.Enable (FALSE);
    }

  ChangePage (0);

  /* WM_INITDIALOG: return FALSE because we have set the focus */
  return FALSE;
}


void
TSetupDlg::OnCommand (DWORD dwCmd, LPARAM lParam)
{
  m_dwNotifyCode = dwCmd;

  switch (dwCmd)
    {
    /* Page 1 */
    case MAKELPARAM (IDC_DSN, EN_CHANGE):
      ValidatePage ();
      break;

    case MAKELPARAM (IDC_SERVER, CBN_DROPDOWN):
      m_SERVER.OnCbnDropDown ();
      break;

    case MAKELPARAM (IDC_SERVER, CBN_CLOSEUP):
      m_SERVER.OnCbnCloseUp ();
      break;

    case MAKELPARAM (IDC_SERVER, CBN_EDITCHANGE):
      m_SERVER.OnCbnEditChange ();
      ValidatePage ();
      break;

    /* Page 2 */
    case MAKELPARAM (IDC_AUTHMETHOD, CBN_SELCHANGE):
      SetAuthMethod ();
      break;

    case MAKELPARAM (IDC_USEUID, BN_CLICKED):
      SetUseUID ();
      ValidatePage ();
      break;

    case MAKELPARAM (IDC_UID, EN_CHANGE):
      ValidatePage ();
      break;

    case MAKELPARAM (IDC_BROWSEUIDCERT, BN_CLICKED):
      if (BrowseForFile (m_hInstance, m_UID, IDS_PKCS12BROWSE))
	m_PWD.SetFocus ();
      break;

    case MAKELPARAM (IDC_USESERVERCERT, BN_CLICKED):
      SetUseServerCert (TRUE);
      ValidatePage ();
      break;

    case MAKELPARAM (IDC_SERVERCERT, EN_CHANGE):
      ValidatePage ();
      break;

    case MAKELPARAM (IDC_BROWSESERVERCERT, BN_CLICKED):
      BrowseForFile (m_hInstance, m_SERVERCERT, IDS_X509BROWSE);
      break;

    /* Page 3 */
    case MAKELPARAM (IDC_USEDEFAULTDB, BN_CLICKED):
      SetUseDefaultDB ();
      ValidatePage ();
      break;

    case MAKELPARAM (IDC_USEDEFAULTIL, BN_CLICKED):
      SetUseDefaultIL ();
      ValidatePage ();
      break;

    case MAKELPARAM (IDC_USEDEFAULTCS, BN_CLICKED):
      SetUseDefaultCS ();
      ValidatePage ();
      break;

    case MAKELPARAM (IDC_DEFAULTDB, CBN_SELCHANGE):
    case MAKELPARAM (IDC_DEFAULTDB, CBN_EDITCHANGE):
    case MAKELPARAM (IDC_DEFAULTCS, CBN_SELCHANGE):
    case MAKELPARAM (IDC_DEFAULTCS, CBN_EDITCHANGE):
    case MAKELPARAM (IDC_DEFAULTIL, CBN_SELCHANGE):
    case MAKELPARAM (IDC_DEFAULTIL, CBN_EDITCHANGE):
      ValidatePage ();
      break;

    /* Global buttons */
    case MAKELPARAM (IDC_BACKBTN, BN_CLICKED):
      ChangePage (m_iCurPage - 1);
      break;

    case MAKELPARAM (IDC_NEXTBTN, BN_CLICKED):
      if (m_iCurPage == 0)
	FillAuthMethods ();
      else if (m_iCurPage == 1)
	{
          FillIsolationLevels ();
          if (!FillDBCombos ())
            {
	      SetFocus (GetDlgItem (m_hPageWnd[1], IDC_PWD));
	      break;
            }
	}

      if (m_iCurPage == m_iNumPages - 1)
	{
	  SaveToProps ();
	  EndDialog (m_hWnd, IDOK);
	}
      else
	ChangePage (m_iCurPage + 1);
      break;

    case MAKELPARAM (IDCANCEL, BN_CLICKED):
      EndDialog (m_hWnd, dwCmd);
      break;
    }
}


BOOL
TSetupDlg::OnOtherMsg (UINT uMsg, WPARAM wParam, LPARAM lParam)
{
  LPCTSTR szDSN;

  switch (uMsg)
    {
    case WM_ZCNOTIFY:
      /* Notification from the resolver that it found a new publication
       */
      m_SERVER.TryResolve ();
      return TRUE;

    case WM_ZCRESOLVED:
      /* Notification from server combo box that entry is now valid
       * Use DSN info from the server as a policy
       */
      if ((szDSN = m_SERVER.GetDSN ()) != NULL)
	{
	  TKVList dsnprops;

	  SaveToProps ();
	  dsnprops.FromDSN (szDSN);
	  if (dsnprops.Find (_T("Encrypt")) == NOT_FOUND)
	    m_props.Undefine (_T("Encrypt"));
	  m_props.Merge (dsnprops);
	  LoadFromProps ();
	}
      /* else case (GetDSN returned NULL):
       * definitely NOT using zero config - the user typed <host>:<port>
       */
      return TRUE;
    }

  return FALSE;
}

////////////////////////////////////////////////////////////////////////////////
// LOGIN DIALOG
////////////////////////////////////////////////////////////////////////////////

void
TLoginDlg::LoadFromProps (void)
{
  TCHAR szValue[1024];
  BOOL bCertBased;

  m_props.Get (_T("DSN"), szValue, NUMCHARS (szValue));
  m_DSN.Text (szValue);

  if (m_props.Get (_T("PWDClearText"), szValue, NUMCHARS (szValue)))
    bCertBased = (_ttoi (szValue) == 3);
  else
    bCertBased = FALSE;

  m_props.Get (_T("UID"), szValue, NUMCHARS (szValue));
  if (ONLY_ONE_OF (bCertBased, ISFILENAME (szValue)))
    szValue[0] = 0;
  m_UID.Text (szValue);

  m_props.Get (_T("PWD"), szValue, NUMCHARS (szValue));
  m_PWD.Text (szValue);

  m_BROWSEUIDCERT.Show (bCertBased);
  m_UID.ReadOnly (bCertBased);
  LoadString (m_hInstance, bCertBased ? IDS_PKCS12LBL : IDS_UIDLBL,
      szValue, NUMCHARS (szValue));
  m_UIDLBL.Text (szValue);
}


void
TLoginDlg::SaveToProps (void)
{
  m_props.Define (_T("UID"), m_UID.Text ());
  m_props.Define (_T("PWD"), m_PWD.Text ());
}


BOOL
TLoginDlg::OnInitDialog (void)
{
  BOOL bRC;

  bRC = TDialog::OnInitDialog ();
  m_DSN.Attach (m_hWnd, IDC_DSN, MAX_DSN_LEN);
  m_UIDLBL.Attach (m_hWnd, IDC_UIDLBL, 64);
  m_UID.Attach (m_hWnd, IDC_UID, MAX_PATH);
  m_PWD.Attach (m_hWnd, IDC_PWD, MAX_PWD_LEN);
  m_BROWSEUIDCERT.Attach (m_hWnd, IDC_BROWSEUIDCERT);

  LoadFromProps ();

  return bRC;
}


void
TLoginDlg::OnOptions (void)
{
  TKVList props;
  TSetupDlg setupDlg (props);

  SaveToProps ();
  props.Merge (m_props);

  setupDlg.m_bFileDSN = TRUE;
  if (setupDlg.RunModal (m_hInstance, IDD_CONFIGDSN, m_hWnd) == IDOK)
    {
      m_props.Empty ();
      m_props.Merge (props);
      LoadFromProps ();
    }
}


void
TLoginDlg::OnCommand (DWORD dwCmd, LPARAM lParam)
{
  switch (dwCmd)
    {
    case MAKELPARAM (IDC_BROWSEUIDCERT, BN_CLICKED):
      BrowseForFile (m_hInstance, m_UID, IDS_PKCS12BROWSE);
      break;

    case MAKELPARAM (IDC_OPTIONS, BN_CLICKED):
      OnOptions ();
      break;

    case MAKELPARAM (IDOK, BN_CLICKED):
      SaveToProps ();
      EndDialog (m_hWnd, dwCmd);
      break;

    case MAKELPARAM (IDCANCEL, BN_CLICKED):
      EndDialog (m_hWnd, dwCmd);
      break;
    }
}

////////////////////////////////////////////////////////////////////////////////
// ODBC TEST CONNECTION
////////////////////////////////////////////////////////////////////////////////

TODBCConn::TODBCConn ()
{
  m_hEnv = SQL_NULL_HENV;
  m_hDbc = SQL_NULL_HDBC;
  m_hStmt = SQL_NULL_HSTMT;
}


TODBCConn::~TODBCConn ()
{
  if (m_hStmt != SQL_NULL_HSTMT)
    SQLFreeStmt (m_hStmt, SQL_DROP);
  if (m_hDbc != SQL_NULL_HDBC)
    {
      SQLDisconnect (m_hDbc);
      SQLFreeConnect (m_hDbc);
    }
  if (m_hEnv)
    SQLFreeEnv (m_hEnv);
}


BOOL
TODBCConn::OnInitDialog (void)
{
  BOOL bRC;

  bRC = TDialog::OnInitDialog ();
  SetDlgItemText (m_hWnd, IDC_SQLSTATE, m_szSQLState);
  SetDlgItemText (m_hWnd, IDC_SQLERROR, m_szSQLMessage);

  return bRC;
}


void
TODBCConn::ShowError (HINSTANCE hInstance, HWND hParentWnd)
{
  HWND hFocusWnd = GetFocus ();
  MessageBeep (MB_ICONEXCLAMATION);
  RunModal (hInstance, IDD_ODBCERROR, hParentWnd);
  SetFocus (hFocusWnd);
}


void
TODBCConn::ShowStmtError (HINSTANCE hInstance, HWND hParentWnd)
{
  SQLSMALLINT wSize;
  SQLError (
      m_hEnv,
      m_hDbc,
      SQL_NULL_HSTMT,
      (_SQLCHAR *) m_szSQLState,
      NULL,
      (_SQLCHAR *) m_szSQLMessage,
      NUMCHARS (m_szSQLMessage),
      &wSize);
  ShowError (hInstance, hParentWnd);
}


BOOL
TODBCConn::Connect (HWND hWnd, LPCTSTR szDsn)
{
  TCHAR szOutDsn[1024];
  SQLSMALLINT wSize;

  m_szSQLState[0] = m_szSQLMessage[0] = 0;
  if (SQLAllocEnv (&m_hEnv) == SQL_ERROR)
    {
      SQLError (
	  SQL_NULL_HENV,
	  SQL_NULL_HDBC,
	  SQL_NULL_HSTMT,
	  (_SQLCHAR *) m_szSQLState,
	  NULL,
	  (_SQLCHAR *) m_szSQLMessage,
	  NUMCHARS (m_szSQLMessage),
	  &wSize);
      return FALSE;
    }
  if (SQLAllocConnect (m_hEnv, &m_hDbc) == SQL_ERROR)
    {
      SQLError (
	  m_hEnv,
	  SQL_NULL_HDBC,
	  SQL_NULL_HSTMT,
	  (_SQLCHAR *) m_szSQLState,
	  NULL,
	  (_SQLCHAR *) m_szSQLMessage,
	  NUMCHARS (m_szSQLMessage),
	  &wSize);
      return FALSE;
    }
  if (SQLDriverConnect (
	m_hDbc,
	hWnd,
	(_SQLCHAR *) szDsn, SQL_NTS,
	(_SQLCHAR *) szOutDsn, NUMCHARS (szOutDsn),
	&wSize,
	SQL_DRIVER_NOPROMPT) == SQL_ERROR)
    {
      SQLError (
	  m_hEnv,
	  m_hDbc,
	  SQL_NULL_HSTMT,
	  (_SQLCHAR *) m_szSQLState,
	  NULL,
	  (_SQLCHAR *) m_szSQLMessage,
	  NUMCHARS (m_szSQLMessage),
	  &wSize);
      return FALSE;
    }
  if (SQLAllocStmt (m_hDbc, &m_hStmt) == SQL_ERROR)
    {
      SQLError (
	  m_hEnv,
	  m_hDbc,
	  SQL_NULL_HSTMT,
	  (_SQLCHAR *) m_szSQLState,
	  NULL,
	  (_SQLCHAR *) m_szSQLMessage,
	  NUMCHARS (m_szSQLMessage),
	  &wSize);
      return FALSE;
    }

  return TRUE;
}

////////////////////////////////////////////////////////////////////////////////
// DLL ENTRYPOINTS
////////////////////////////////////////////////////////////////////////////////

BOOL
LoadByOrdinal (void)
{
  return TRUE;
}


/* Called from SQLConnect/SQLDriverConnect */
BOOL
virtodbc_LoginDlg (TKVList &props, HWND hWnd)
{
  /* Run ConfigDSN if setting up a file dsn from ODBCAD32 */
  if (props.Value (_T("Driver")) && CalledFromODBCAD32 ())
    {
      TSetupDlg dlg (props);
      dlg.m_bFileDSN = TRUE;
      return (dlg.RunModal (g_hInstance, IDD_CONFIGDSN, hWnd) == IDOK);
    }
  else
    {
      TLoginDlg dlg (props);
      return (dlg.RunModal (g_hInstance, IDD_LOGINDLG, hWnd) == IDOK);
    }
}


BOOL APIENTRY
ConfigDSNW (
    HWND hWinParent,
    WORD fRequest,
    LPCTSTR lpszDriver,
    LPCTSTR lpszAttributes)
{
  TCHAR szNewDSN[MAX_DSN_LEN + 1];
  TCHAR szDSN[MAX_DSN_LEN + 1];
  TKVList props;
  TSetupDlg setupDlg (props);

  props.FromAttributes (lpszAttributes);
  if (props.Get (_T("DSN"), szDSN, NUMCHARS (szDSN)))
    {
      props.ReadODBCIni (szDSN, _virtuoso_tags);
      props.FromAttributes (lpszAttributes);
    }

  if (fRequest == ODBC_REMOVE_DSN)
    {
      SQLRemoveDSNFromIni (szDSN);
    }
  else if (fRequest == ODBC_CONFIG_DSN || fRequest == ODBC_ADD_DSN)
    {
      if (hWinParent)
        {
          setupDlg.m_bFileDSN = FALSE;
          if (setupDlg.RunModal (g_hInstance, IDD_CONFIGDSN, hWinParent) == IDOK)
	    {
	      if (props.Get (_T("DSN"), szNewDSN, NUMCHARS (szNewDSN)))
	        {
	          props.Undefine (_T("PWD"));
	          SQLWriteDSNToIni (szNewDSN, lpszDriver);
	          props.WriteODBCIni (szNewDSN, _virtuoso_tags);

	          /* If the DSN has changed, delete the old one */
	          if (fRequest == ODBC_CONFIG_DSN && _tcsicmp (szDSN, szNewDSN))
		    SQLRemoveDSNFromIni (szDSN);
	        }
	    }
        }
      else
        {
	  if (props.Get (_T("DSN"), szNewDSN, NUMCHARS (szNewDSN)))
	    {
	       props.Undefine (_T("PWD"));
	       SQLWriteDSNToIni (szNewDSN, lpszDriver);
	       props.WriteODBCIni (szNewDSN, _virtuoso_tags);

	       /* If the DSN has changed, delete the old one */
	       if (fRequest == ODBC_CONFIG_DSN && _tcsicmp (szDSN, szNewDSN))
	          SQLRemoveDSNFromIni (szDSN);
	    }
        }
    }

  return TRUE;
}


#ifndef VIRTOLEDB_CLI
BOOL WINAPI
DllMain (HINSTANCE hModule, DWORD fdReason, LPVOID lpvReserved)
{
  if (fdReason == DLL_PROCESS_ATTACH)
    {
      g_hInstance = hModule;
      DisableThreadLibraryCalls (hModule);
    }

  return TRUE;
}

STDAPI
DllRegisterServer()
{
  HKEY hkey;
  DWORD disposition;
  LONG stat;
  TCHAR buffer[1024] = TEXT("");
  int size = 0;
  TCHAR module_file_name[MAX_PATH + 1];

  if (0 == GetModuleFileName(g_hInstance, module_file_name, sizeof module_file_name / sizeof (TCHAR)))
    return E_FAIL;

  stat = RegCreateKeyEx(HKEY_LOCAL_MACHINE, TEXT ("SOFTWARE\\ODBC\\ODBCINST.INI\\Virtuoso (Open Source)"), 0, NULL,
      REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &hkey, &disposition);

  if (stat != ERROR_SUCCESS)
    return E_FAIL;

  _stprintf(buffer, TEXT ("%s"), module_file_name);
  size = ( _tcslen(buffer) * sizeof (TCHAR) ) + 1;

  stat = RegSetValueEx(hkey, TEXT ("Driver"), 0, REG_SZ, (BYTE*) buffer, size);
  if (stat != ERROR_SUCCESS)
    return E_FAIL;
  stat = RegSetValueEx(hkey, TEXT ("Setup"), 0, REG_SZ, (BYTE*) buffer, size);
  RegCloseKey(hkey);
  if (stat != ERROR_SUCCESS)
    return E_FAIL;

  stat = RegCreateKeyEx(HKEY_LOCAL_MACHINE, TEXT ("SOFTWARE\\ODBC\\ODBCINST.INI\\ODBC Drivers"), 0, NULL,
      REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL, &hkey, &disposition);
  if (stat != ERROR_SUCCESS)
    return E_FAIL;

  _stprintf(buffer, TEXT ("%s"), TEXT ("Installed"));
  size = ( _tcslen(buffer) * sizeof (TCHAR) ) + 1;
  stat = RegSetValueEx(hkey, TEXT ("Virtuoso (Open Source)"), 0, REG_SZ, (BYTE*) buffer, size);
  RegCloseKey(hkey);
  if (stat != ERROR_SUCCESS)
    return E_FAIL;

  return S_OK;
}

STDAPI
DllUnregisterServer()
{
  HKEY hkey;
  LONG stat = RegDeleteKey(HKEY_LOCAL_MACHINE, TEXT ("SOFTWARE\\ODBC\\ODBCINST.INI\\Virtuoso (Open Source)"));
  if ((stat != ERROR_SUCCESS) && (stat != ERROR_FILE_NOT_FOUND))
    return E_FAIL;

  stat = RegOpenKeyEx (HKEY_LOCAL_MACHINE, TEXT ("SOFTWARE\\ODBC\\ODBCINST.INI\\ODBC Drivers"), 0, KEY_ALL_ACCESS, &hkey);
  if (stat != ERROR_SUCCESS)
    return E_FAIL;

  stat = RegDeleteValue (hkey, TEXT ("Virtuoso (Open Source)"));
  if (stat != ERROR_SUCCESS)
    return E_FAIL;

  return S_OK;
}
#else
extern "C" {
void
SetOdbcInstanceHandle (HINSTANCE hModule)
{
  g_hInstance = hModule;
}
}
#endif
