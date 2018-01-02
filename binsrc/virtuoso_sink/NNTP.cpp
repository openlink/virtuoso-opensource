// NNTP.cpp : Implementation of CNNTP
/*
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
#include "stdafx.h"
#include "VirtuosoSink.h"
#include "NNTP.h"
#include "DBConnectionPool.h"

/////////////////////////////////////////////////////////////////////////////
// CNNTP

HRESULT CNNTP::OnPost(IMessage * Msg, CdoEventStatus * EventStatus)
{
    HRESULT res;
    RETCODE rc;
    long global_read = 0;
    int to_inx = 0;
    SDWORD cbRet = SQL_DATA_AT_EXEC;
    if (EventStatus == NULL)
	return E_POINTER;

//    _Module.LogEvent ("Message");
    CComBSTR bStrTo, bStrBody, bStrFrom, bStrSubj, bStrCC, bStrBCC, bStrSentDate;
    CComPtr<_Stream> st;
    VARIANT sent_date;
    ::VariantInit (&sent_date);
    sent_date.vt = VT_DATE;

//    _Module.LogEvent ("After Subj");
    if (S_OK != (res = Msg->GetStream (&st)))
        return res;

//    _Module.LogEvent ("After Stream");

    CDBConnection *conn = _ppool->getConnection();
//    _Module.LogEvent ("After conn");
//    _Module.LogEvent ("From: %s, To: %s, CC: %s, BCC: %s, Subject: %s, SentOn :%s", 
//	szStrFrom, szStrTo, szStrCC, szStrBCC, szStrSubj, szStrSent);
    HSTMT hstmt = SQL_NULL_HSTMT;
    try 
    {
	int read, reconnect_count = 0;
	char szBuffer[4096];
again:
	hstmt = SQL_NULL_HSTMT;
	if (SQL_SUCCESS != SQLAllocStmt (conn->hdbc, &hstmt)) 
	    throw _T("SQLAllocStmt error");

//	SQLSetStmtOption (conn->hstmt, SQL_QUERY_TIMEOUT, 10);
	SQLSetParam (hstmt, 1, SQL_C_CHAR, SQL_LONGVARCHAR, 0, 0, (SQLPOINTER)2, &cbRet);
//        _Module.LogEvent ("After setparam");
	rc = SQLExecDirect (hstmt, (SQLCHAR *)"NS_POST (?)", SQL_NTS);
	if (rc != SQL_NEED_DATA && !reconnect_count)
	{
	    conn->ReportODBCError (hstmt, "Retry SQLExec error");
	    SQLFreeStmt (hstmt, SQL_DROP);
	    hstmt = SQL_NULL_HSTMT;
	    _Module.LogEvent ("Reconnecting ...");
	    reconnect_count = 1;
	    delete conn;
	    conn = new CDBConnection ();
	    goto again;
	}
	else if (rc != SQL_NEED_DATA)
	{
	    throw _T("SQLExec Error");
	}


  //      _Module.LogEvent ("After Exec");
	rc = SQLParamData (hstmt, NULL);
	if (rc != SQL_NEED_DATA)
	    throw _T("SQLParamData error");
//        _Module.LogEvent ("After ParamData");
	while (1) 
	{
	    st->ReadText (4096, &bStrBody);
	    read = wcslen (bStrBody);
	    global_read += read;
//	    _Module.LogEvent ("After ReadText");
	    if (!read)
		break;
	    ::WideCharToMultiByte (CP_ACP, 0, bStrBody, -1, szBuffer, sizeof (szBuffer), NULL, NULL);
	    rc = SQLPutData (hstmt, szBuffer, SQL_NTS);
//	    _Module.LogEvent ("After PutData");
	    if (rc != SQL_SUCCESS)
		throw _T("SQLPutData error");
	}
	rc = SQLParamData (hstmt, NULL);
//	_Module.LogEvent ("After ParamData");
	if (rc != SQL_SUCCESS)
	    throw _T("SQLParamData error");
	SQLFreeStmt (hstmt, SQL_DROP);
//	SQLFreeStmt (conn->hstmt, SQL_RESET_PARAMS);
	_Module.LogEvent ("NNTP Message (%ld chars) routed", global_read);
    }
    catch (TCHAR *ch)
    {
	conn->ReportODBCError (hstmt, ch);
	SQLFreeStmt (hstmt, SQL_DROP);
//	SQLFreeStmt (conn->hstmt, SQL_RESET_PARAMS);
	_ppool->releaseConnection(conn);
	return E_POINTER;
    }
    _ppool->releaseConnection(conn);
    return S_OK;
}
