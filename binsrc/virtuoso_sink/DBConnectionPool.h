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
// DBConnectionPool.h: interface for the CDBConnectionPool class.
//
//////////////////////////////////////////////////////////////////////

#if !defined(AFX_DBCONNECTIONPOOL_H__C9C5064F_AE52_11D4_8986_00E018001CA1__INCLUDED_)
#define AFX_DBCONNECTIONPOOL_H__C9C5064F_AE52_11D4_8986_00E018001CA1__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#include <stack>
#include "DBConnection.h"

typedef std::stack<CDBConnection *> con_stack_t;
class CDBConnectionPool  
{
public:
	void releaseConnection (CDBConnection *conn);
	CDBConnection * getConnection();
	CDBConnectionPool();
	virtual ~CDBConnectionPool();

protected:
	HANDLE m_sem;
	CRITICAL_SECTION m_critical;
	con_stack_t m_cons;
};
extern CDBConnectionPool *_ppool;
#endif // !defined(AFX_DBCONNECTIONPOOL_H__C9C5064F_AE52_11D4_8986_00E018001CA1__INCLUDED_)
