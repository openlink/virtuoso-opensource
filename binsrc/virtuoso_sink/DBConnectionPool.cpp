// DBConnectionPool.cpp: implementation of the CDBConnectionPool class.
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
//
//////////////////////////////////////////////////////////////////////

#include "stdafx.h"
#include "DBConnectionPool.h"

CDBConnectionPool *_ppool = NULL;
//////////////////////////////////////////////////////////////////////
// Construction/Destruction
//////////////////////////////////////////////////////////////////////

CDBConnectionPool::CDBConnectionPool()
{
    CDBConnection::AllocEnv();
    DWORD connCount = 1;
    ::InitializeCriticalSection (&m_critical);
    if (ERROR_SUCCESS != CDBConnection::key.QueryValue (connCount, _T("ConnectionCount")))
	CDBConnection::key.SetValue (connCount, _T("ConnectionCount"));
    m_sem = ::CreateSemaphore (NULL, connCount, connCount, NULL);
    for (DWORD inx = 0; inx < connCount; inx++)
    {
	CDBConnection *conn = new CDBConnection();
	m_cons.push (conn);
    }
}

CDBConnectionPool::~CDBConnectionPool()
{
    while (!m_cons.empty())
    {
	CDBConnection *conn = m_cons.top();
	delete conn;
	m_cons.pop();
    }
    ::DeleteCriticalSection (&m_critical);
    ::CloseHandle (m_sem);
    CDBConnection::UnregisterSinks ();
}

CDBConnection * CDBConnectionPool::getConnection()
{
    CDBConnection *conn = NULL;
    ::WaitForSingleObject (m_sem, INFINITE);
    ::EnterCriticalSection (&m_critical);
    if (!m_cons.empty())
    {
	conn = m_cons.top();
	m_cons.pop();
    }
    ::LeaveCriticalSection (&m_critical);
//    _Module.LogEvent ("Connection get");
    return conn;
}

void CDBConnectionPool::releaseConnection(CDBConnection *conn)
{
    ::EnterCriticalSection (&m_critical);
    m_cons.push (conn);
    ::LeaveCriticalSection (&m_critical);
    ::ReleaseSemaphore (m_sem, 1, NULL);
//    _Module.LogEvent ("Connection released");
}
