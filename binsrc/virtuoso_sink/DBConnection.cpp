// DBConnection.cpp: implementation of the CDBConnection class.
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
 *  
*/
//
//////////////////////////////////////////////////////////////////////

#include "stdafx.h"
#include "DBConnection.h"
#include "resource.h"
#include "VirtuosoSink.h"
#include "SMTP.h"

//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////

CDBConnection::CDBConnection()
{
    RETCODE rc;
    hdbc = SQL_NULL_HDBC;
    rc = SQLAllocConnect (henv, &hdbc);
    if (rc != SQL_SUCCESS)
    {
	ReportODBCError (SQL_NULL_HSTMT, "SQLAllocConnect error");
	throw rc;
    }
    rc = SQLConnect (hdbc, (SQLCHAR *)szDSN, SQL_NTS, (SQLCHAR *)szUID, SQL_NTS,
	(SQLCHAR *)szPWD, SQL_NTS);
    if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
	ReportODBCError (SQL_NULL_HSTMT, "SQLConnect error");
	SQLFreeConnect (hdbc);
	hdbc = SQL_NULL_HDBC;
	throw rc;
    }
}

CDBConnection::~CDBConnection()
{
    if (hdbc != SQL_NULL_HDBC)
    {
	SQLDisconnect (hdbc);
	SQLFreeConnect (hdbc);
    }
}


TCHAR CDBConnection::szPWD[512] = _T("dba");
TCHAR CDBConnection::szUID[512] = _T("dba");
TCHAR CDBConnection::szDSN[512] = _T("Virtuoso");
HENV CDBConnection::henv = SQL_NULL_HENV;
CRegKey CDBConnection::key;
bstrstack_t CDBConnection::stack;

int CDBConnection::AllocEnv()
{
    TCHAR keyname[256];
    ::LoadString (_Module.GetModuleInstance(), IDS_KEYNAME, keyname, sizeof (keyname));

    if (ERROR_SUCCESS != key.Open (HKEY_LOCAL_MACHINE, keyname))
    {
	if (ERROR_SUCCESS != key.Create (HKEY_LOCAL_MACHINE, keyname))
	{
	    _Module.LogEvent ("Can't create the data key");
	}
	else
	{
	    key.SetValue (szUID, _T("User"));
	    key.SetValue (szPWD, _T("Password"));
	    key.SetValue (szDSN, _T("DSN"));
	}
    }
    else
    {
	DWORD len; 
	len = sizeof (szDSN); key.QueryValue (szDSN, _T("DSN"), &len);
	len = sizeof (szUID); key.QueryValue (szUID, _T("User"), &len);
	len = sizeof (szPWD); key.QueryValue (szPWD, _T("Password"), &len);
    }
    if (henv == SQL_NULL_HENV)
    {
	if (SQL_SUCCESS != SQLAllocEnv (&henv))
	{
	    _Module.LogFatal ("Can\'t allocate the environment");
	    throw -1;
	}
    }
    RegisterSinks();
    return 1;
}

int CDBConnection::ReportODBCError(HSTMT hstmt, TCHAR *szUsrMessage)
{
    SQLCHAR szState[10], szMessage[512];

    while (SQL_SUCCESS == SQLError (henv, hdbc, hstmt,
	szState, NULL, szMessage, sizeof (szMessage), NULL))
    {
	_Module.LogFatal ("%s [%s] %s", szUsrMessage, szState, szMessage);
	if (!strcmp ((const char *)szState, "40001"))
	    return 1;
    }
    return 0;
}

void CDBConnection::RegisterSinks()
{
    return;
    //DebugBreak();
    int nValInx = 0, nSinks = 0;
    TCHAR SinkName[1024], SinkValue[1024];
    DWORD type, cSinkName = sizeof (SinkName), cSinkValue = sizeof (SinkValue);
    CComBSTR bStrOutGUID;
    while (ERROR_SUCCESS == ::RegEnumValue (key, nValInx++, SinkName, &cSinkName, NULL, &type, (LPBYTE)SinkValue, &cSinkValue))
    {
	if (type == REG_SZ && ! lstrcmpi (SinkName, _T("SMTPBinding")))
	{
	    TCHAR szDisplayName[50];
	    wsprintf (szDisplayName, "Virtuoso.SMTP.%d", nSinks);
	    if (S_OK != CSMTP::RegisterSink (1, CComBSTR(szDisplayName), NULL, true, &bStrOutGUID, SinkValue))
	    {
		_Module.LogFatal ("Can\'t register sink %s", SinkValue);
		throw -1;
	    }
	    _Module.LogEvent ("Registered %s (%s)", szDisplayName, (TCHAR *)_bstr_t (bStrOutGUID));
	    stack.push (CComBSTR (bStrOutGUID));
	}
	cSinkName = sizeof (SinkName), cSinkValue = sizeof (SinkValue);
    }
}

void CDBConnection::UnregisterSinks()
{
    return;
    while (!stack.empty())
    {
	CSMTP::UnregisterSink (1, stack.top());
	stack.pop();
    }
}

