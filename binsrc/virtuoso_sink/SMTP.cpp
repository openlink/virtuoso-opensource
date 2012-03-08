// SMTP.cpp : Implementation of CSMTP
/*
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
 *  
*/
#include "stdafx.h"
#include "VirtuosoSink.h"
#include "SMTP.h"

int 
GetNextID (char *szMsg, int offset, char *ID)
{
  while (1)
    {
      char *colon = strchr (szMsg + offset, ',');
      char *left;
      char *at , *at_start;
      if (colon)
	*colon = 0;
      left = strchr (szMsg + offset, '<');
      if (left)
	offset = left - szMsg;
      at_start = at = strrchr (szMsg + offset, '@');
      if (colon)
	*colon = ',';

      if (at)
      {
	if (at > szMsg + offset && !isspace (at[-1]) && at[-1] != '<')
	{
	    at_start = at;
	    while (at_start > szMsg + offset && !isspace (at_start[-1]) && at_start[-1] != '<')
		at_start--;
	    *at = 0;
	    strcpy (ID, at_start);
	    *at = '@';
	    return colon ? colon - szMsg + 1 : at - szMsg + 1;
	}
	else
	    offset += colon ? colon - szMsg + 1 : at - szMsg + 1;
      }
      else if (left)
      {
	  char *right = strchr (left, '>');
	  if (right)
	  {
	      *right = 0;
	      strcpy (ID, left + 1);
	      *right = '>';
	      return right - szMsg;
	  }
	  else
	      return -1;
      }
      else
	return -1; 
    }
  return -1;
}

typedef struct {
    CComBSTR bStrTo, bStrBody, bStrFrom, bStrSubj, bStrCC, bStrBCC, bStrSent, bStrContent;
} thread_t;

DWORD WINAPI thread_func (LPVOID param)
{
    thread_t *t = (thread_t *)param;
    char szStrTo[512];
    RETCODE rc;
    SDWORD cbRet = SQL_DATA_AT_EXEC,
	cb1 = SQL_NULL_DATA,
	cb2 = SQL_NULL_DATA,
	cb3 = SQL_NULL_DATA,
	cb4 = SQL_NULL_DATA,
	cb5 = SQL_NULL_DATA,
	cb6 = SQL_NULL_DATA,
	cb7 = SQL_NULL_DATA,
	cb8 = SQL_NULL_DATA;
    szStrTo[0] = 0;
    ::WideCharToMultiByte (CP_ACP, 0, t->bStrTo, -1, szStrTo, sizeof (szStrTo), NULL, NULL);
    CDBConnection *conn = _ppool->getConnection();
//    _Module.LogEvent ("After conn");
//    _Module.LogEvent ("From: %s, To: %s, CC: %s, BCC: %s, Subject: %s, SentOn :%s", 
//	szStrFrom, szStrTo, szStrCC, szStrBCC, szStrSubj, szStrSent);
    long ofs = 0;
    char szTo[512];
    while (-1 != (ofs = GetNextID (szStrTo, ofs, szTo)))
    {
    cb1 = SQL_NULL_DATA;
    HSTMT hstmt = SQL_NULL_HSTMT;
    try 
    {
	int reconnect_count;
again:
	reconnect_count = 0;
	hstmt = SQL_NULL_HSTMT;
	if (SQL_SUCCESS != SQLAllocStmt (conn->hdbc, &hstmt))
	    throw _T ("SQLAllocStmt error");

//	SQLSetStmtOption (hstmt, SQL_QUERY_TIMEOUT, 10);
	SQLSetParam (hstmt, 1, SQL_C_CHAR, SQL_CHAR, 0, 0, szTo, szTo[0] ? NULL : &cb1);
	SQLSetParam (hstmt, 2, SQL_C_WCHAR, SQL_CHAR, 0, 0, t->bStrSubj, t->bStrSubj[0] ? NULL : &cb2);
	SQLSetParam (hstmt, 3, SQL_C_WCHAR, SQL_CHAR, 0, 0, t->bStrCC, t->bStrCC[0] ? NULL : &cb3);
	SQLSetParam (hstmt, 4, SQL_C_WCHAR, SQL_CHAR, 0, 0, t->bStrBCC, t->bStrBCC[0] ? NULL : &cb4);
	SQLSetParam (hstmt, 5, SQL_C_WCHAR, SQL_CHAR, 0, 0, t->bStrSent, t->bStrSent[0] ? NULL : &cb5);
	SQLSetParam (hstmt, 6, SQL_C_WCHAR, SQL_CHAR, 0, 0, t->bStrTo, t->bStrTo[0] ? NULL : &cb6);
	SQLSetParam (hstmt, 7, SQL_C_WCHAR, SQL_CHAR, 0, 0, t->bStrFrom, t->bStrFrom[0] ? NULL : &cb7);
	SQLSetParam (hstmt, 8, SQL_C_WCHAR, SQL_LONGVARCHAR, 0, 0, t->bStrContent, t->bStrContent[0] ? NULL : &cb8);
//        _Module.LogEvent ("After setparam");
	rc = SQLExecDirect (hstmt, 
	    (SQLCHAR *)"BARE_NEW_MAIL (?, ?, ?, ?, ?, ?, ?, ?)", SQL_NTS);
	if (rc != SQL_SUCCESS && !reconnect_count)
	{
	    conn->ReportODBCError (hstmt, "Retry SQLExec error");
	    _Module.LogEvent ("Reconnecting ...");
	    reconnect_count = 1;
	    SQLFreeStmt (hstmt, SQL_DROP);
	    hstmt = SQL_NULL_HSTMT;
	    delete conn;
	    conn = new CDBConnection ();
	    goto again;
	}
	else if (rc != SQL_SUCCESS)
	{
	    throw _T("SQLExec Error");
	}


	SQLFreeStmt (hstmt, SQL_DROP);
//	SQLFreeStmt (hstmt, SQL_RESET_PARAMS);
	_Module.LogEvent ("Message (%ld chars) from %s routed to %s", wcslen (t->bStrContent), (char *)(bstr_t)t->bStrFrom, (char *)(bstr_t)t->bStrTo);
    }
    catch (TCHAR *ch)
    {
	int deadlock = conn->ReportODBCError (hstmt, ch);
//	SQLFreeStmt (hstmt, SQL_RESET_PARAMS);
	if (deadlock)
	    goto again;
	_ppool->releaseConnection(conn);
	delete t;
    }
    }
    _ppool->releaseConnection(conn);
    delete t;
    return 0;
}


/////////////////////////////////////////////////////////////////////////////
// CSMTP

HRESULT CSMTP::OnArrival(IMessage * Msg, CdoEventStatus * EventStatus)
{
    HRESULT res;
    int to_inx = 0;
    if (EventStatus == NULL)
	return E_POINTER;

//    _Module.LogEvent ("Message");
    
    CComPtr<_Stream> st;
    VARIANT sent_date;
    ::VariantInit (&sent_date);
    sent_date.vt = VT_DATE;
    thread_t *thr = new thread_t;

    if (S_OK != (res = Msg->get_To(&thr->bStrTo)))
        return res;
//    _Module.LogEvent ("After To");
    if (S_OK != (res = Msg->get_From (&thr->bStrFrom)))
        return res;
//    _Module.LogEvent ("After From");
    if (S_OK != (res = Msg->get_CC (&thr->bStrCC)))
        return res;
//    _Module.LogEvent ("After CC");
    if (S_OK != (res = Msg->get_BCC (&thr->bStrBCC)))
        return res;
//    _Module.LogEvent ("After BCC");
    if (S_OK != (res = Msg->get_SentOn (&sent_date.date)))
        return res;
//    _Module.LogEvent ("After RecTime");
    if (S_OK != (res = Msg->get_Subject (&thr->bStrSubj)))
        return res;
    if (S_OK !=::VariantChangeType (&sent_date, &sent_date, 0, VT_BSTR))
    {
//	_Module.LogEvent ("Conversion from VT_DATE to VT_BSTR not possible");
	thr->bStrSent = _T("");
    }
    else
	thr->bStrSent = sent_date.bstrVal;


//    _Module.LogEvent ("After Subj");
    if (S_OK != (res = Msg->GetStream (&st)))
        return res;

    st->ReadText (-1, &thr->bStrContent);
//    _Module.LogEvent ("After Stream");

    if (::CreateThread (NULL, 40000, thread_func, thr, 0, NULL))
    {
	*EventStatus = cdoSkipRemainingSinks;
	return S_OK;
    }
    else
    {
	*EventStatus = cdoRunNextSink;
	return E_POINTER;
    }
}

char *GUID_ComCatOnArrival = "{ff3caa23-00b9-11d2-9dfb-00C04FA322BA}";

HRESULT CSMTP::RegisterSink(long lInstance, BSTR DisplayName, BSTR BindingGUID/*, BSTR LogFilePath*/, VARIANT_BOOL fEnabled, BSTR* OutBindingGUID, TCHAR *rule)
{
    IEventManager*        pEvtMan       =    NULL;
    IEventUtil*           pEvtUtil      =    NULL;
    IEventSourceTypes*    pSrcTypes     =    NULL;
    IEventSourceType*     pSrcType      =    NULL;
    IEventSources*        pSrcs         =    NULL;
    IEventSource*         pSrc          =    NULL;
    IEventBindingManager* pBindingMan   =    NULL;
    IEventBindings*       pBindings     =    NULL;
    IEventBinding*        pBinding      =    NULL;
    IEventPropertyBag*    pSourceProps  =    NULL;
    IEventPropertyBag*    pSinkProps    =    NULL;
    HRESULT               hr            =    S_OK;
    BSTR                  bstrSourceGUID;

    hr = CoCreateInstance(__uuidof(CEventUtil),
                            NULL,
                            CLSCTX_INPROC_SERVER,
                            __uuidof(IEventUtil),
                            (void**)&pEvtUtil);



    // Get the Source GUID for the SMTP Server Instance
    hr = pEvtUtil->GetIndexedGUID(CComBSTR(g_szGuidSmtpSvcSource),lInstance,&bstrSourceGUID);
    if(FAILED(hr)) {
        pEvtUtil->Release();
        return hr;
    }


    // Use the EventManager to create the binding
    hr = CoCreateInstance(__uuidof(CEventManager),
                            NULL,
                            CLSCTX_INPROC_SERVER,
                            __uuidof(IEventManager),
                            (void**)&pEvtMan);

    if(FAILED(hr)) 
        return hr;


        hr = E_FAIL;
    if(SUCCEEDED(pEvtMan->get_SourceTypes(&pSrcTypes))) {
      if(SUCCEEDED(pSrcTypes->Item(&CComVariant(g_szGuidSmtpSourceType),&pSrcType))) {
        if(SUCCEEDED(pSrcType->get_Sources(&pSrcs))) {    
          if(SUCCEEDED(pSrcs->Item(&CComVariant(bstrSourceGUID),&pSrc))) {
            if(SUCCEEDED(pSrc->GetBindingManager(&pBindingMan))) {
              if(SUCCEEDED(pBindingMan->get_Bindings(CComBSTR(GUID_ComCatOnArrival),&pBindings))) {
                // BindingGUID was passed by the caller
                hr = pBindings->Add(BindingGUID,&pBinding);
                if(SUCCEEDED(hr)) {
                  // error checking is omitted for clarity.
                  // each result _should_ be checked
                  // but these work most of the time
                  pBinding->put_SinkClass(CComBSTR("VirtuosoSink.SMTP"));
                  pBinding->put_DisplayName(DisplayName);
                  pBinding->put_Enabled(fEnabled);

                  // Source Properties
                  pBinding->get_SourceProperties(&pSourceProps);
                  // Rule is: EHLO command (all)
                  pSourceProps->Add(CComBSTR("Rule"),&CComVariant(rule));
                  // highest prio
                  pSourceProps->Add(CComBSTR("Priority"),&CComVariant((long) SMTP_TRANSPORT_DEFAULT_PRIORITY));
                  pSourceProps->Release();

                  // Sink Properties
                  pBinding->get_SinkProperties(&pSinkProps);
//                  pSinkProps->Add(CComBSTR("LogFilePath"),&CComVariant(LogFilePath));

//                  hr = pBinding->Save();
                  // If the caller did not specify a GUID, we return it.
                  // If they did, we return it anyway
                  hr = pBinding->get_ID(OutBindingGUID);
                  pSinkProps->Release();
                  pBinding->Release();
                }
                pBindings->Release();
              }
              pBindingMan->Release();
            }
            pSrc->Release();
          }
          pSrcs->Release();
        }
        pSrcType->Release();
      }
      pSrcTypes->Release();
    }
    pEvtMan->Release();


    ATLASSERT(SUCCEEDED(hr));


    return S_OK;
}

HRESULT CSMTP::UnregisterSink(long lInstance, BSTR BindingGUID)
{
    IEventManager*        pEvtMan      =    NULL;
    IEventUtil*           pEvtUtil     =    NULL;
    IEventSourceTypes*    pSrcTypes    =    NULL;
    IEventSourceType*     pSrcType     =    NULL;
    IEventSources*        pSrcs        =    NULL;
    IEventSource*         pSrc         =    NULL;
    IEventBindingManager* pBindingMan  =    NULL;
    IEventBindings*       pBindings    =    NULL;
    IEventBinding*        pBinding     =    NULL;
    HRESULT               hr           =    S_OK;
    BSTR                  bstrSourceGUID;

    hr = CoCreateInstance(__uuidof(CEventUtil),
                            NULL,
                            CLSCTX_INPROC_SERVER,
                            __uuidof(IEventUtil),
                            (void**)&pEvtUtil);



    // Get the Source GUID for the SMTP Server Instance
    hr = pEvtUtil->GetIndexedGUID(CComBSTR(g_szGuidSmtpSvcSource),lInstance,&bstrSourceGUID);
    if(FAILED(hr)) {
        pEvtUtil->Release();
        return hr;
    }

    pEvtUtil->Release();

    // Use the EventManager to create the binding
    hr = CoCreateInstance(__uuidof(CEventManager),
                            NULL,
                            CLSCTX_INPROC_SERVER,
                            __uuidof(IEventManager),
                            (void**)&pEvtMan);

    if(FAILED(hr)) 
        return hr;

    hr = E_FAIL;
    if(SUCCEEDED(pEvtMan->get_SourceTypes(&pSrcTypes))) {
      if(SUCCEEDED(pSrcTypes->Item(&CComVariant(g_szGuidSmtpSourceType),&pSrcType))) {
        if(SUCCEEDED(pSrcType->get_Sources(&pSrcs))) {    
          if(SUCCEEDED(pSrcs->Item(&CComVariant(bstrSourceGUID),&pSrc))) {
            if(SUCCEEDED(pSrc->GetBindingManager(&pBindingMan))) {
              if(SUCCEEDED(pBindingMan->get_Bindings(CComBSTR(GUID_ComCatOnArrival),&pBindings))) {
                hr = pBindings->Remove(&CComVariant(BindingGUID));
                pBindings->Release();
              }
              pBindingMan->Release();
            }
            pSrc->Release();
          }
          pSrcs->Release();
        }
        pSrcType->Release();
      }
      pSrcTypes->Release();
    }
    pEvtMan->Release();

    return hr;
}
