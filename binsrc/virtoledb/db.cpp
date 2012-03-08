/*  db.cpp
 *
 *  $Id$
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

#include "headers.h"
#include "asserts.h"
#include "syncobj.h"
#include "db.h"
#include "rowsetprops.h"
#include "util.h"
#include "error.h"
#include "virtext.h"

#define MAX_BUFFER_SIZE 2000

/**********************************************************************/
/* DoDiagnostics                                                      */

static void
DoDiagnostics(SQLSMALLINT handle_type, SQLHANDLE handle)
{
  SQLTCHAR sql_state[6], error_msg[SQL_MAX_MESSAGE_LENGTH];
  SQLSMALLINT i, error_msg_len;
  SQLINTEGER native_error;

  i = 1;
  while (SQL_NO_DATA != SQLGetDiagRec(handle_type, handle, i,
				      sql_state, &native_error,
				      error_msg, sizeof error_msg, &error_msg_len))
    {
      LOG(("SQLSTATE:        %s\n", sql_state));
      LOG(("NativeError:     %d\n", native_error));
      LOG(("Diagnostic Msg:  %s\n", error_msg));
      i++;
    }
}

static bool
GetSQLSTATE(SQLSMALLINT handle_type, SQLHANDLE handle, char sqlstate[])
{
  SQLSMALLINT length;
  SQLRETURN rv = SQLGetDiagField(handle_type, handle,
				 1, SQL_DIAG_SQLSTATE,
				 sqlstate, 6, &length);
  if (rv != SQL_SUCCESS)
    {
      sqlstate[0] = 0;
      return false;
    }
  return true;
}

/**********************************************************************/
/* ConnectionInfo                                                     */

ConnectionInfo::ConnectionInfo()
{
}

ConnectionInfo::ConnectionInfo(const ConnectionInfo &info)
{
  ci_userid = info.ci_userid;
  ci_password = info.ci_password;
  ci_datasource = info.ci_datasource;
  ci_catalog = info.ci_catalog;
  ci_providerstring = info.ci_providerstring;
  ci_prompt = info.ci_prompt;
  ci_hwnd = info.ci_hwnd;
  ci_timeout = info.ci_timeout;
  ci_encrypt = info.ci_encrypt;
  ci_show_systemtables = info.ci_show_systemtables;
  ci_pkcs12_file = info.ci_pkcs12_file;
}

ConnectionInfo&
ConnectionInfo::operator=(const ConnectionInfo &info)
{
  if (this == &info)
    return *this;
  ci_userid = info.ci_userid;
  ci_password = info.ci_password;
  ci_datasource = info.ci_datasource;
  ci_catalog = info.ci_catalog;
  ci_providerstring = info.ci_providerstring;
  ci_prompt = info.ci_prompt;
  ci_hwnd = info.ci_hwnd;
  ci_timeout = info.ci_timeout;
  ci_encrypt = info.ci_encrypt;
  ci_show_systemtables = info.ci_show_systemtables;
  ci_pkcs12_file = info.ci_pkcs12_file;
  return *this;
}

/**********************************************************************/
/* EnvironmentImpl                                                    */

class EnvironmentImpl : public RefCountedImpl
{
private:

  EnvironmentImpl()
    : RefCountedImpl("EnvironmentImpl"), m_henv(NULL)
  {
  }

  ~EnvironmentImpl()
  {
    Fini();
  }

public:

  static EnvironmentImpl *Instance();

  virtual void Unreferenced();

  HRESULT Init();
  void Fini();

  SQLHENV
  GetHENV()
  {
    return m_henv;
  }

  void
  DoDiagnostics()
  {
    ::DoDiagnostics(SQL_HANDLE_ENV, m_henv);
  }

  static DBTYPE ConvertDataSourceType(const LPOLESTR pwszDataSourceType);

private:

  SQLHENV m_henv;
  static EnvironmentImpl *m_environment_instance;
};

EnvironmentImpl* EnvironmentImpl::m_environment_instance = NULL;


EnvironmentImpl *
EnvironmentImpl::Instance()
{
  LOGCALL (("EnvironmentImpl::Instance()\n"));

  CriticalSection critical_section(&Module::m_GlobalSync);
  if (m_environment_instance == NULL)
    m_environment_instance = new EnvironmentImpl();
  if (m_environment_instance != NULL)
    m_environment_instance->AddRef();
  return m_environment_instance;
}

void
EnvironmentImpl::Unreferenced()
{
  LOGCALL (("EnvironmentImpl::Unreferenced()\n"));

  CriticalSection critical_section(&Module::m_GlobalSync);
  delete m_environment_instance;
  m_environment_instance = NULL;
}

HRESULT
EnvironmentImpl::Init()
{
  LOGCALL (("EnvironmentImpl::Init()\n"));

  CriticalSection critical_section(&Module::m_GlobalSync);
  if (m_henv != NULL)
    return S_OK;

  SQLRETURN rc = SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &m_henv);
  if (rc == SQL_SUCCESS_WITH_INFO)
    DoDiagnostics();
  else if (rc != SQL_SUCCESS)
    {
      TRACE((__FILE__, __LINE__, "Environment::Init(): SQLAllocHandle() failed.\n"));
      DoDiagnostics();
      m_henv = NULL;
      return ErrorInfo::Set(E_OUTOFMEMORY);
    }

  rc = SQLSetEnvAttr(m_henv, SQL_ATTR_ODBC_VERSION, (SQLPOINTER) SQL_OV_ODBC3, SQL_IS_INTEGER);
  if (rc == SQL_SUCCESS_WITH_INFO)
    DoDiagnostics();
  else if (rc != SQL_SUCCESS)
    {
      HRESULT hr;
      TRACE((__FILE__, __LINE__, "Environment::Init(): SQLSetEnvAttr() failed.\n"));
      DoDiagnostics();
      hr = ErrorInfo::Set(E_FAIL, SQL_HANDLE_ENV, m_henv);
      SQLFreeHandle(SQL_HANDLE_ENV, m_henv);
      return hr;
    }

  return S_OK;
}

void
EnvironmentImpl::Fini()
{
  LOGCALL (("EnvironmentImpl::Fini()\n"));

  CriticalSection critical_section(&Module::m_GlobalSync);
  if (m_henv == NULL)
    return;

  SQLFreeHandle(SQL_HANDLE_ENV, m_henv);
  m_henv = NULL;
}

/**********************************************************************/
/* Environment                                                        */

Environment::Environment()
{
}

Environment::~Environment()
{
}

Environment::Environment(const Environment &env)
{
  CopyCtor(env);
}

Environment &
Environment::operator=(const Environment &env)
{
  if (this != &env)
    CopyOp(env);
  return *this;
}

HRESULT
Environment::Init()
{
  impl = EnvironmentImpl::Instance();
  if (impl == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  return impl->Init();
}

SQLHENV
Environment::GetHENV() const
{
  if (impl == NULL)
    return NULL;
  return impl->GetHENV();
}

void
Environment::DoDiagnostics() const
{
  if (impl != NULL)
    impl->DoDiagnostics();
}

/**********************************************************************/
/* ConnectionPoolImpl                                                 */

struct ConnectionEntry
{
  ConnectionEntry()
    : hdbc(NULL)
  {
  }

  SQLHDBC hdbc;
};

typedef std::list<ConnectionEntry> ConnectionList;
typedef ConnectionList::iterator ConnectionIter;
typedef ConnectionList::const_iterator ConstConnectionIter;

class ConnectionPoolImpl : public RefCountedImpl, public SyncObj
{
public:

  ConnectionPoolImpl();
  ~ConnectionPoolImpl();

  HRESULT Init
  (
    Environment &environment,
    const ConnectionPoolInfo &pool_info,
    const ConnectionInfo &conn_info
  );

  void Fini();

  const ConnectionInfo&
  GetConnectionInfo() const
  {
    return m_conn_info;
  }

  HRESULT GetActiveSessions(LONG& value);
  HRESULT GetCurrentCatalog(std::string& catalog) const;
  HRESULT SetCurrentCatalog(const std::string& catalog);
  HRESULT GetDBMSName(std::string& value);
  HRESULT GetDBMSVer(std::string& value);
  HRESULT GetIdentifierCase(LONG& value);
  HRESULT GetServerName(std::string& value);
  HRESULT GetUserName(std::string& value);

  HRESULT CreateConnectionEntry
  (
    ConnectionIter &iter,
    bool multiple_connections
  );

  HRESULT ReleaseConnectionEntry
  (
    ConnectionIter &iter
  );

private:

  HRESULT BuildConnectionString();
  HRESULT ParseConnectionString(const char *conn_str);
  HRESULT CreateListEntry(ConnectionList &list, ConnectionIter &iter);
  HRESULT OpenFirstConnection(ConnectionEntry &entry);
  HRESULT OpenExtraConnection(ConnectionEntry &entry);
  void CloseConnection(ConnectionEntry &entry);

  Environment m_environment;
  int m_conn_min;
  int m_conn_max_soft;
  int m_conn_max_hard;
  ConnectionInfo m_conn_info;
  int m_prompt;
  std::string m_connection_string;
  std::string m_catalog;

  long m_conn_count;
  ConnectionList m_busy_conn_list;
  ConnectionList m_free_conn_list;
};

ConnectionPoolImpl::ConnectionPoolImpl()
  : RefCountedImpl("ConnectionPoolImpl")
{
  m_conn_min = 0;
  m_conn_max_soft = 0;
  m_conn_max_hard = 0;
  m_conn_count = 0;
}

ConnectionPoolImpl::~ConnectionPoolImpl()
{
  Fini();
}

HRESULT
ConnectionPoolImpl::Init(
  Environment &environment,
  const ConnectionPoolInfo &pool_info,
  const ConnectionInfo &conn_info
)
{
  m_environment = environment;

  m_conn_min = pool_info.cpi_conn_min;
  m_conn_max_soft = pool_info.cpi_conn_max_soft;
  m_conn_max_hard = pool_info.cpi_conn_max_hard;

  m_conn_info = conn_info;

  HRESULT hr = ParseConnectionString(m_conn_info.ci_providerstring.c_str());
  if (FAILED(hr))
    return hr;
  hr = BuildConnectionString();
  if (FAILED(hr))
    return hr;

  switch (m_conn_info.ci_prompt)
    {
    case DBPROMPT_PROMPT:
      m_prompt = SQL_DRIVER_PROMPT;
      break;
    case DBPROMPT_COMPLETE:
      m_prompt = SQL_DRIVER_COMPLETE;
      break;
    case DBPROMPT_COMPLETEREQUIRED:
      m_prompt = SQL_DRIVER_COMPLETE_REQUIRED;
      break;
    case DBPROMPT_NOPROMPT:
      m_prompt = SQL_DRIVER_NOPROMPT;
      break;
    default:
      assert(0);
    }

  ConnectionIter iter;
  hr = CreateListEntry(m_free_conn_list, iter);
  if (FAILED(hr))
    return hr;
  hr = OpenFirstConnection(*iter);
  if (FAILED(hr))
    {
      m_free_conn_list.erase(iter);
      return hr;
    }
  while (m_conn_count < m_conn_min)
    {
      hr = CreateListEntry(m_free_conn_list, iter);
      if (FAILED(hr))
	break;
      hr = OpenExtraConnection(*iter);
      if (FAILED(hr))
	{
	  m_free_conn_list.erase(iter);
	  return hr;
	}
    }

  return S_OK;
}

void
ConnectionPoolImpl::Fini()
{
  assert(m_busy_conn_list.empty() == true);

  LOG(("connections: %d\n", m_conn_count));
  while (!m_free_conn_list.empty())
    {
      ConnectionEntry &entry = m_free_conn_list.front();
      CloseConnection(entry);
      m_free_conn_list.pop_front();
    }
  LOG(("connections: %d\n", m_conn_count));
}

HRESULT
ConnectionPoolImpl::GetActiveSessions(LONG& value)
{
  LOGCALL(("ConnectionPoolImpl::GetActiveSessions()\n"));

  CriticalSection critical_section(this);
  ConnectionIter iter = m_free_conn_list.begin();
  if (iter == m_free_conn_list.end())
    {
      iter = m_busy_conn_list.begin();
      if (iter == m_busy_conn_list.end())
	return ErrorInfo::Set(E_FAIL);
    }

  SQLHSTMT hstmt;
  SQLRETURN rc = SQLAllocHandle(SQL_HANDLE_STMT, iter->hdbc, &hstmt);
  if (rc != SQL_SUCCESS)
    {
      TRACE((__FILE__, __LINE__, "ConnectionPoolImpl::GetActiveSessions(): SQLAllocHandle() failed.\n"));
      DoDiagnostics(SQL_HANDLE_DBC, iter->hdbc);
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_DBC, iter->hdbc);
    }

  SQLINTEGER conns = 0;
  SQLLEN conns_ind = sizeof conns;
#if 0
  rc = SQLBindParameter(hstmt, 1, SQL_PARAM_OUTPUT, SQL_C_SLONG, SQL_INTEGER, 0, 0, &conns, 0, &conns_ind);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ConnectionPoolImpl::GetActiveSessions(): SQLBindParameter() failed.\n"));
      DoDiagnostics(SQL_HANDLE_STMT, hstmt);
      SQLFreeHandle(SQL_HANDLE_STMT, hstmt);
      return ErrorInfo::Set(E_FAIL);
    }

  try
  {
    rc = SQLExecDirect(hstmt, (SQLCHAR*) "{?=call sys_stat('st_lic_max_connections')}", SQL_NTS);
  }
  catch (...)
  {
      SQLFreeHandle(SQL_HANDLE_STMT, hstmt);
      return ErrorInfo::Set(E_FAIL, "Internal Error");
  }
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ConnectionPoolImpl::GetActiveSessions(): SQLExecDirect() failed.\n"));
      DoDiagnostics(SQL_HANDLE_STMT, hstmt);
      SQLFreeHandle(SQL_HANDLE_STMT, hstmt);
      return ErrorInfo::Set(E_FAIL);
    }
#else
  rc = SQLBindCol(hstmt, 1, SQL_C_SLONG, &conns, sizeof conns, &conns_ind);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      HRESULT hr;
      TRACE((__FILE__, __LINE__, "ConnectionPoolImpl::GetActiveSessions(): SQLBindCol() failed.\n"));
      DoDiagnostics(SQL_HANDLE_STMT, hstmt);
      hr = ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
      SQLFreeHandle(SQL_HANDLE_STMT, hstmt);
      return hr;
    }

  rc = SQLExecDirect(hstmt, (SQLCHAR*) "select sys_stat('st_lic_max_connections')", SQL_NTS);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      HRESULT hr;
      TRACE((__FILE__, __LINE__, "ConnectionPoolImpl::GetActiveSessions(): SQLExecDirect() failed.\n"));
      DoDiagnostics(SQL_HANDLE_STMT, hstmt);
      hr = ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
      SQLFreeHandle(SQL_HANDLE_STMT, hstmt);
      return hr;
    }

  rc = SQLFetch(hstmt);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      HRESULT hr;
      TRACE((__FILE__, __LINE__, "ConnectionPoolImpl::GetActiveSessions(): SQLFetch() failed.\n"));
      DoDiagnostics(SQL_HANDLE_STMT, hstmt);
      hr = ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, hstmt);
      SQLFreeHandle(SQL_HANDLE_STMT, hstmt);
      return hr;
    }
#endif

  value = conns;

  SQLFreeHandle(SQL_HANDLE_STMT, hstmt);
  return S_OK;
}

HRESULT
ConnectionPoolImpl::GetCurrentCatalog(std::string& catalog) const
{
  LOGCALL (("ConnectionPoolImpl::GetCurrentCatalog()\n"));

  CriticalSection critical_section(const_cast<ConnectionPoolImpl*>(this));
  catalog = m_catalog;
  return S_OK;
}

HRESULT
ConnectionPoolImpl::SetCurrentCatalog(const std::string& catalog)
{
  LOGCALL (("ConnectionPoolImpl::SetCurrentCatalog()\n"));

  CriticalSection critical_section(this);

  m_catalog = catalog;
  HRESULT hr = BuildConnectionString();
  if (FAILED(hr))
    return hr;

  for (ConnectionIter iter = m_busy_conn_list.begin(); iter != m_busy_conn_list.end(); iter++)
    {
      SQLRETURN rc = SQLSetConnectAttr(iter->hdbc, SQL_ATTR_CURRENT_CATALOG,
				       (SQLPOINTER*) m_catalog.c_str(), SQL_NTS);
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  TRACE((__FILE__, __LINE__, "ConnectionPoolImpl::SetCurrentCatalog(): SQLSetConnectAttr() failed.\n"));
	  DoDiagnostics(SQL_HANDLE_DBC, iter->hdbc);
	  return ErrorInfo::Set(E_FAIL, SQL_HANDLE_DBC, iter->hdbc);
	}
    }
  for (ConnectionIter iter = m_free_conn_list.begin(); iter != m_free_conn_list.end(); iter++)
    {
      SQLRETURN rc = SQLSetConnectAttr(iter->hdbc, SQL_ATTR_CURRENT_CATALOG,
				       (SQLPOINTER*) m_catalog.c_str(), SQL_NTS);
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  TRACE((__FILE__, __LINE__, "ConnectionPoolImpl::SetCurrentCatalog(): SQLSetConnectAttr() failed.\n"));
	  DoDiagnostics(SQL_HANDLE_DBC, iter->hdbc);
	  return ErrorInfo::Set(E_FAIL, SQL_HANDLE_DBC, iter->hdbc);
	}
    }

  return S_OK;
}

HRESULT
ConnectionPoolImpl::GetDBMSName(std::string& value)
{
  LOGCALL (("ConnectionPoolImpl::GetDBMSName()\n"));

  CriticalSection critical_section(this);

  ConnectionIter iter = m_free_conn_list.begin();
  if (iter == m_free_conn_list.end())
    {
      iter = m_busy_conn_list.begin();
      if (iter == m_busy_conn_list.end())
	return ErrorInfo::Set(E_FAIL);
    }

  SQLCHAR buffer[1024];
  SQLSMALLINT length;
  SQLRETURN rc = SQLGetInfo(iter->hdbc, SQL_DBMS_NAME, buffer, sizeof buffer, &length);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      DoDiagnostics(SQL_HANDLE_DBC, iter->hdbc);
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_DBC, iter->hdbc);
    }

  value = (char*) buffer;
  return S_OK;
}

HRESULT
ConnectionPoolImpl::GetDBMSVer(std::string& value)
{
  LOGCALL (("ConnectionPoolImpl::GetDBMSVer()\n"));

  CriticalSection critical_section(this);

  ConnectionIter iter = m_free_conn_list.begin();
  if (iter == m_free_conn_list.end())
    {
      iter = m_busy_conn_list.begin();
      if (iter == m_busy_conn_list.end())
	return ErrorInfo::Set(E_FAIL);
    }

  SQLCHAR buffer[1024];
  SQLSMALLINT length;
  SQLRETURN rc = SQLGetInfo(iter->hdbc, SQL_DBMS_VER, buffer, sizeof buffer, &length);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      DoDiagnostics(SQL_HANDLE_DBC, iter->hdbc);
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_DBC, iter->hdbc);
    }

  value = (char*) buffer;
  return S_OK;
}

HRESULT
ConnectionPoolImpl::GetIdentifierCase(LONG& value)
{
  LOGCALL (("ConnectionPoolImpl::GetIdentifierCase()\n"));

  CriticalSection critical_section(this);

  ConnectionIter iter = m_free_conn_list.begin();
  if (iter == m_free_conn_list.end())
    {
      iter = m_busy_conn_list.begin();
      if (iter == m_busy_conn_list.end())
	return ErrorInfo::Set(E_FAIL);
    }

  SQLUSMALLINT idcase;
  SQLRETURN rc = SQLGetInfo(iter->hdbc, SQL_IDENTIFIER_CASE, &idcase, sizeof idcase, NULL);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      DoDiagnostics(SQL_HANDLE_DBC, iter->hdbc);
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_DBC, iter->hdbc);
    }

  switch(idcase)
    {
    case SQL_IC_UPPER:
      value = DBPROPVAL_IC_UPPER;
      break;
    case SQL_IC_LOWER:
      value = DBPROPVAL_IC_LOWER;
      break;
    case SQL_IC_SENSITIVE:
      value = DBPROPVAL_IC_SENSITIVE;
      break;
    case SQL_IC_MIXED:
      value = DBPROPVAL_IC_MIXED;
      break;
    }
  return S_OK;
}

HRESULT
ConnectionPoolImpl::GetServerName(std::string& value)
{
  LOGCALL (("ConnectionPoolImpl::GetServerName()\n"));

  CriticalSection critical_section(this);

  ConnectionIter iter = m_free_conn_list.begin();
  if (iter == m_free_conn_list.end())
    {
      iter = m_busy_conn_list.begin();
      if (iter == m_busy_conn_list.end())
	return ErrorInfo::Set(E_FAIL);
    }

  SQLCHAR buffer[1024];
  SQLSMALLINT length;
  SQLRETURN rc = SQLGetInfo(iter->hdbc, SQL_SERVER_NAME, buffer, sizeof buffer, &length);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      DoDiagnostics(SQL_HANDLE_DBC, iter->hdbc);
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_DBC, iter->hdbc);
    }

  value = (char*) buffer;
  return S_OK;
}

HRESULT
ConnectionPoolImpl::GetUserName(std::string& value)
{
  LOGCALL (("ConnectionPoolImpl::GetUserName()\n"));

  CriticalSection critical_section(this);

  ConnectionIter iter = m_free_conn_list.begin();
  if (iter == m_free_conn_list.end())
    {
      iter = m_busy_conn_list.begin();
      if (iter == m_busy_conn_list.end())
	return ErrorInfo::Set(E_FAIL);
    }

  SQLCHAR buffer[1024];
  SQLSMALLINT length;
  SQLRETURN rc = SQLGetInfo(iter->hdbc, SQL_USER_NAME, buffer, sizeof buffer, &length);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      DoDiagnostics(SQL_HANDLE_DBC, iter->hdbc);
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_DBC, iter->hdbc);
    }

  value = (char*) buffer;
  return S_OK;
}

HRESULT
ConnectionPoolImpl::CreateConnectionEntry(ConnectionIter &iter, bool multiple_connections)
{
  LOGCALL (("ConnectionPoolImpl::CreateConnectionEntry()\n"));

  CriticalSection critical_section(this);

  if (!m_free_conn_list.empty())
    {
      m_busy_conn_list.splice(m_busy_conn_list.begin(), m_free_conn_list, m_free_conn_list.begin());
      iter = m_busy_conn_list.begin();
      return S_OK;
    }

  if (!multiple_connections)
    return ErrorInfo::Set(DB_E_OBJECTOPEN);
  if (m_conn_max_hard > 0 && m_conn_max_hard <= m_conn_count)
    return ErrorInfo::Set(DB_E_OBJECTOPEN);

  HRESULT hr = CreateListEntry(m_busy_conn_list, iter);
  if (FAILED(hr))
    return hr;
  hr = OpenExtraConnection(*iter);
  if (FAILED(hr))
    {
      critical_section.Enter();
      m_busy_conn_list.erase(iter);
      return hr;
    }

  return S_OK;
}

HRESULT
ConnectionPoolImpl::ReleaseConnectionEntry(ConnectionIter &iter)
{
  LOGCALL (("ConnectionPoolImpl::ReleaseConnectionEntry()\n"));

  CriticalSection critical_section(this);

  if (m_conn_count <= m_conn_max_soft)
    {
      m_free_conn_list.splice(m_free_conn_list.begin(), m_busy_conn_list, iter);
      return S_OK;
    }

  ConnectionEntry entry = *iter;
  m_busy_conn_list.erase(iter);

  critical_section.Leave();

  CloseConnection(entry);
  return S_OK;
}

HRESULT
ConnectionPoolImpl::BuildConnectionString()
{
  m_connection_string.erase();

  m_connection_string.append("DRIVER={OpenLink Virtuoso Driver};");
  if (m_conn_info.ci_datasource.length())
    m_connection_string.append("HOST=").append(m_conn_info.ci_datasource).append(";");
  if (m_conn_info.ci_userid.length())
    m_connection_string.append("UID=").append(m_conn_info.ci_userid).append(";");
  if (m_conn_info.ci_password.length())
    m_connection_string.append("PWD=").append(m_conn_info.ci_password).append(";");
  if (m_catalog.length())
    m_connection_string.append("DATABASE=").append(m_catalog).append(";");
  else if (m_conn_info.ci_catalog.length())
    m_connection_string.append("DATABASE=").append(m_conn_info.ci_catalog).append(";");
  if (m_conn_info.ci_pkcs12_file.length())
    m_connection_string.append("ENCRYPT=").append(m_conn_info.ci_pkcs12_file).append(";");
  else if (m_conn_info.ci_encrypt)
    m_connection_string.append("ENCRYPT=1;");
  if (m_conn_info.ci_providerstring.length())
    m_connection_string.append(m_conn_info.ci_providerstring);
  if (m_conn_info.ci_show_systemtables)
    m_connection_string.append("NoSystemTables=1;");

  return S_OK;
}

HRESULT
ConnectionPoolImpl::ParseConnectionString(const char *conn_str)
{
  if (conn_str == NULL)
    return S_OK;

  std::string providerstring;
  const char *cp = conn_str;
  while (*cp)
    {
      int n = strcspn(cp, "=;");
      if (n > 0 && cp[n] == '=')
	{
	  int m = strcspn(cp + n + 1, ";");
	  int t = n + m + 1 + (cp[n + m + 1] ? 1 : 0);

	  if (n == 6 && (_strnicmp("DRIVER", cp, n) == 0 || _strnicmp("SERVER", cp, n) == 0))
	    /* noop */;
	  else if (n == 4 && _strnicmp("HOST", cp, n) == 0)
	    m_conn_info.ci_datasource.assign(cp + n + 1, m);
	  else if (n == 3 && _strnicmp("UID", cp, n) == 0)
	    m_conn_info.ci_userid.assign(cp + n + 1, m);
	  else if (n == 3 && _strnicmp("PWD", cp, n) == 0)
	    m_conn_info.ci_password.assign(cp + n + 1, m);
	  else if (n == 8 && _strnicmp("DATABASE", cp, n) == 0)
	    m_conn_info.ci_catalog.assign(cp + n + 1, m);
	  else if (n == 14 && _strnicmp("NoSystemTables", cp, n) == 0)
	    {
	      m_conn_info.ci_show_systemtables = false;
	      if (m == 1 && *(cp + n + 1) == '1')
		m_conn_info.ci_show_systemtables = true;
	      else if (m == 3 && _strnicmp ("YES", cp + n + 1, m))
		m_conn_info.ci_show_systemtables = true;
	    }
	  else if (n == 7 && _strnicmp("ENCRYPT", cp, n) == 0)
	    {
	      m_conn_info.ci_encrypt = true;
	      if (m == 1 && *(cp + n + 1) == '1')
		m_conn_info.ci_pkcs12_file.clear();
	      else
		m_conn_info.ci_pkcs12_file.assign(cp + n + 1, m);
	    }
	  else
	    providerstring.append(cp, t);
	  cp += t;
	}
      else if (cp[n])
	{
	  providerstring.append(cp, n + 1);
	  cp += n + 1;
	}
      else
	{
	  providerstring.append(cp);
	  cp += n;
	}
    }
  m_conn_info.ci_providerstring = providerstring;

  return S_OK;
}

HRESULT
ConnectionPoolImpl::CreateListEntry(ConnectionList &list, ConnectionIter &iter)
{
  HRESULT hr = S_OK;
  try {
    iter = list.insert(list.begin(), ConnectionEntry());
  } catch (std::bad_alloc &) {
    hr = E_OUTOFMEMORY;
  }
  return hr;
}

HRESULT
ConnectionPoolImpl::OpenFirstConnection(ConnectionEntry &entry)
{
  LOGCALL(("ConnectionPoolImpl::OpenFirstConnection()\n"));

  SQLHDBC hdbc;
  SQLRETURN rc;

  SQLHENV henv = m_environment.GetHENV();
  rc = SQLAllocHandle(SQL_HANDLE_DBC, henv, &hdbc);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ConnectionPoolImpl::OpenFirstConnection(): SQLAllocHandle() failed.\n"));
      m_environment.DoDiagnostics();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_ENV, henv);
    }

#if 1
  LOG(("SQLDriverConnect(hwnd = %d, connstr = '%s', prompt = %d)\n",
       m_conn_info.ci_hwnd, m_connection_string.c_str(), m_prompt));
#endif

  SQLCHAR buffer[1024];
  SQLSMALLINT length;
  rc = SQLDriverConnect(hdbc, m_conn_info.ci_hwnd,
			(SQLCHAR *) m_connection_string.c_str(), SQL_NTS,
			buffer, sizeof buffer, &length,
			m_prompt);
  if (rc == SQL_NO_DATA)
  {
    HRESULT hr;
    hr = ErrorInfo::Set(DB_E_CANCELED);
    SQLFreeHandle (SQL_HANDLE_DBC, hdbc);
    return hr;
  }
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ConnectionPoolImpl::OpenFirstConnection(): SQLDriverConnect() failed.\n"));
      ::DoDiagnostics(SQL_HANDLE_DBC, hdbc);

      char sqlstate[6];
      bool hasState = GetSQLSTATE(SQL_HANDLE_DBC, hdbc, sqlstate);
      HRESULT hr = S_OK;
      if (hasState)
	{
	  if (strcmp(sqlstate, "08004") == 0)
	    hr = ErrorInfo::Set(DB_E_OBJECTCREATIONLIMITREACHED, SQL_HANDLE_DBC, hdbc);
	  if (strcmp(sqlstate, "28000") == 0)
	    hr = ErrorInfo::Set(DB_SEC_E_AUTH_FAILED, SQL_HANDLE_DBC, hdbc);
	}
      if (hr == S_OK)
	hr = ErrorInfo::Set(E_FAIL, SQL_HANDLE_DBC, hdbc);
      SQLFreeHandle (SQL_HANDLE_DBC, hdbc);
      return hr;
    }
  entry.hdbc = hdbc;

  HRESULT hr = ParseConnectionString((char *) buffer);
  if (FAILED(hr))
    {
      CloseConnection(entry);
      return hr;
    }
  SQLINTEGER catalog_length;
  rc = SQLGetConnectAttr(hdbc, SQL_ATTR_CURRENT_CATALOG, buffer, sizeof buffer, &catalog_length);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ConnectionPoolImpl::OpenFirstConnection(): SQLGetConnectAttr() failed.\n"));
      DoDiagnostics(SQL_HANDLE_DBC, hdbc);
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_DBC, hdbc);
    }
  LOG (("current catalog: %s\n", buffer));
  m_catalog = (char*) buffer;
  hr = BuildConnectionString();
  if (FAILED(hr))
    {
      CloseConnection(entry);
      return hr;
    }

  InterlockedIncrement(&m_conn_count);
  return S_OK;
}

HRESULT
ConnectionPoolImpl::OpenExtraConnection(ConnectionEntry &entry)
{
  LOGCALL(("ConnectionPoolImpl::OpenExtraConnection()\n"));

  SQLHDBC hdbc;
  SQLRETURN rv;

  SQLHENV henv = m_environment.GetHENV();
  rv = SQLAllocHandle(SQL_HANDLE_DBC, henv, &hdbc);
  if (rv != SQL_SUCCESS && rv != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ConnectionPoolImpl::OpenExtraConnection(): SQLAllocHandle() failed.\n"));
      m_environment.DoDiagnostics();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_ENV, henv);
    }

  rv = SQLDriverConnect(hdbc, m_conn_info.ci_hwnd,
			(SQLCHAR *) m_connection_string.c_str(), SQL_NTS,
			NULL, NULL, NULL,
			SQL_DRIVER_NOPROMPT);
  if (rv != SQL_SUCCESS && rv != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ConnectionPoolImpl::OpenExtraConnection(): SQLDriverConnect() failed.\n"));
      DoDiagnostics(SQL_HANDLE_DBC, hdbc);

      char sqlstate[6];
      if (GetSQLSTATE(SQL_HANDLE_DBC, hdbc, sqlstate) && strcmp(sqlstate, "08004") == 0)
	ErrorInfo::Set(DB_E_OBJECTCREATIONLIMITREACHED, SQL_HANDLE_DBC, hdbc);
      else
	ErrorInfo::Set(E_FAIL, SQL_HANDLE_DBC, hdbc);

      SQLFreeHandle(SQL_HANDLE_DBC, hdbc);
      return ErrorInfo::Get()->GetErrorCode();
    }

  entry.hdbc = hdbc;
  InterlockedIncrement(&m_conn_count);
  return S_OK;
}

void
ConnectionPoolImpl::CloseConnection(ConnectionEntry &entry)
{
  LOGCALL(("ConnectionPoolImpl::CloseConnection()\n"));

  SQLRETURN rv;

  rv = SQLDisconnect(entry.hdbc);
  if (rv != SQL_SUCCESS && rv != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ConnectionPoolImpl::CloseConnection(): SQLDisconnect() failed.\n"));
      DoDiagnostics(SQL_HANDLE_DBC, entry.hdbc);
    }

  rv = SQLFreeHandle(SQL_HANDLE_DBC, entry.hdbc);
  if (rv != SQL_SUCCESS && rv != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ConnectionPoolImpl::CloseConnection(): SQLFreeHandle() failed.\n"));
    }

  entry.hdbc = NULL;
  InterlockedDecrement(&m_conn_count);
}

/**********************************************************************/
/* ConnectionPool                                                     */

ConnectionPool::ConnectionPool()
{
}

ConnectionPool::~ConnectionPool()
{
}

ConnectionPool::ConnectionPool(const ConnectionPool& pool)
{
  CopyCtor(pool);
}

ConnectionPool&
ConnectionPool::operator=(const ConnectionPool& pool)
{
  if (this != &pool)
    CopyOp(pool);
  return *this;
}

HRESULT
ConnectionPool::Init(
  Environment &environment,
  const ConnectionPoolInfo &pool_info,
  const ConnectionInfo &conn_info
)
{
  impl = new ConnectionPoolImpl();
  if (impl == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  impl->AddRef();
  return impl->Init(environment, pool_info, conn_info);
}

const ConnectionInfo&
ConnectionPool::GetConnectionInfo() const
{
  assert(impl != NULL);
  return impl->GetConnectionInfo();
}

HRESULT
ConnectionPool::GetActiveSessions(LONG& value)
{
  assert(impl != NULL);
  return impl->GetActiveSessions(value);
}

HRESULT
ConnectionPool::GetCurrentCatalog(std::string& catalog) const
{
  assert(impl != NULL);
  return impl->GetCurrentCatalog(catalog);
}

HRESULT
ConnectionPool::SetCurrentCatalog(const std::string& catalog)
{
  assert(impl != NULL);
  return impl->SetCurrentCatalog(catalog);
}

HRESULT
ConnectionPool::GetDBMSName(std::string& value)
{
  assert(impl != NULL);
  return impl->GetDBMSName(value);
}

HRESULT
ConnectionPool::GetDBMSVer(std::string& value)
{
  assert(impl != NULL);
  return impl->GetDBMSVer(value);
}

HRESULT
ConnectionPool::GetIdentifierCase(LONG& value)
{
  assert(impl != NULL);
  return impl->GetIdentifierCase(value);
}

HRESULT
ConnectionPool::GetServerName(std::string& value)
{
  assert(impl != NULL);
  return impl->GetServerName(value);
}

HRESULT
ConnectionPool::GetUserName(std::string& value)
{
  assert(impl != NULL);
  return impl->GetUserName(value);
}

/**********************************************************************/
/* ConnectionImpl                                                     */

class ConnectionImpl : public RefCountedImpl
{
public:

  ConnectionImpl()
    : RefCountedImpl("ConnectionImpl"),
      m_open(false)
  {
  }

  ~ConnectionImpl()
  {
    Fini();
  }

  HRESULT Init(ConnectionPool &pool, bool multiple_connections);
  void Fini();

  HRESULT SetTransactionAttrs(bool auto_commit, ULONG isolation);
  HRESULT EndTransaction(bool commit);
  HRESULT EnlistInDTC(ITransaction* pTransaction);

  SQLHDBC
  GetHDBC()
  {
    return m_open ? m_iter->hdbc : NULL;
  }

private:

  ConnectionPool m_pool;
  bool m_open;
  ConnectionIter m_iter;
};

HRESULT
ConnectionImpl::Init(ConnectionPool &pool, bool multiple_connections)
{
  assert(m_open == false);

  m_pool = pool;

  HRESULT hr = m_pool.impl->CreateConnectionEntry(m_iter, multiple_connections);
  if (hr == S_OK)
    m_open = true;
  return hr;
}

void
ConnectionImpl::Fini()
{
  if (m_open)
    {
      m_open = false;
      m_pool.impl->ReleaseConnectionEntry(m_iter);
    }
}

HRESULT
ConnectionImpl::SetTransactionAttrs(bool auto_commit, ULONG isolation)
{
  assert(m_open);

  SQLUINTEGER ulAutoCommit = auto_commit ? SQL_AUTOCOMMIT_ON : SQL_AUTOCOMMIT_OFF;

  SQLUINTEGER ulIsolation;
  switch (isolation)
    {
    case ISOLATIONLEVEL_CHAOS:
    case ISOLATIONLEVEL_READUNCOMMITTED:
      ulIsolation = SQL_TXN_READ_UNCOMMITTED;
      break;

    case ISOLATIONLEVEL_READCOMMITTED:
      ulIsolation = SQL_TXN_READ_COMMITTED;
      break;

    case ISOLATIONLEVEL_REPEATABLEREAD:
      ulIsolation = SQL_TXN_REPEATABLE_READ;
      break;

    case ISOLATIONLEVEL_SERIALIZABLE:
      ulIsolation = SQL_TXN_SERIALIZABLE;
      break;

    case ISOLATIONLEVEL_UNSPECIFIED:
      // TODO: check the isolation level that the upstream component uses.
      ulIsolation = SQL_TXN_SERIALIZABLE;
      break;

    default:
      return XACT_E_ISOLATIONLEVEL;
    }

  SQLRETURN rc;

  rc = SQLSetConnectAttr(m_iter->hdbc, SQL_ATTR_AUTOCOMMIT, (SQLPOINTER) ulAutoCommit, SQL_IS_UINTEGER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ConnectionImpl::SetTransactionAttrs(): SQLSetConnectAttr() failed.\n"));
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_DBC, m_iter->hdbc);
    }

  rc = SQLSetConnectAttr(m_iter->hdbc, SQL_ATTR_TXN_ISOLATION, (SQLPOINTER) ulIsolation, SQL_IS_UINTEGER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ConnectionImpl::SetTransactionAttrs(): SQLSetConnectAttr() failed.\n"));
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_DBC, m_iter->hdbc);
    }

  return S_OK;
}

HRESULT
ConnectionImpl::EndTransaction(bool commit)
{
  SQLRETURN rc = SQLEndTran(SQL_HANDLE_DBC, m_iter->hdbc, commit ? SQL_COMMIT : SQL_ROLLBACK);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ConnectionImpl::EndTransaction(): SQLEndTran() failed.\n"));
      DoDiagnostics(SQL_HANDLE_DBC, m_iter->hdbc);
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_DBC, m_iter->hdbc);
    }

  return S_OK;
}

HRESULT
ConnectionImpl::EnlistInDTC(ITransaction* pTransaction)
{
  SQLRETURN rc = SQLSetConnectAttr(m_iter->hdbc, SQL_ATTR_ENLIST_IN_DTC, pTransaction, SQL_IS_POINTER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "ConnectionImpl::EnlistInDTC(): SQLSetConnectAttr() failed.\n"));
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_DBC, m_iter->hdbc);
    }

  return S_OK;
}

/**********************************************************************/
/* Connection                                                         */

Connection::Connection()
{
}

Connection::~Connection()
{
}

Connection::Connection(const Connection& conn)
{
  CopyCtor(conn);
}

Connection&
Connection::operator=(const Connection& conn)
{
  if (this != &conn)
    CopyOp(conn);
  return *this;
}

HRESULT
Connection::Init(ConnectionPool& pool, bool multiple_connections)
{
  assert(impl == NULL);
  impl = new ConnectionImpl();
  if (impl == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  impl->AddRef();
  return impl->Init(pool, multiple_connections);
}

HRESULT
Connection::SetTransactionAttrs(bool auto_commit, ULONG isolation)
{
  assert(impl != NULL);
  return impl->SetTransactionAttrs(auto_commit, isolation);
}

HRESULT
Connection::EndTransaction(bool commit)
{
  assert(impl != NULL);
  return impl->EndTransaction(commit);
}

HRESULT
Connection::EnlistInDTC(ITransaction* pTransaction)
{
  assert(impl != NULL);
  return impl->EnlistInDTC(pTransaction);
}

SQLHDBC
Connection::GetHDBC() const
{
  if (impl == NULL)
    return NULL;
  return impl->GetHDBC();
}

/**********************************************************************/
/* StatementImpl                                                      */

class StatementImpl : public RefCountedImpl
{
public:

  StatementImpl();
  ~StatementImpl();

  HRESULT Init(const Connection& conn);
  HRESULT Init(const Connection& conn, const RowsetPropertySet* props);
  HRESULT SetQueryTimeout(int timeout);

  void Fini();

  SQLHSTMT
  GetHSTMT() const
  {
    return m_hstmt;
  }

  HRESULT Execute(const ostring& query);
  HRESULT Prepare(const ostring& query);
  HRESULT CheckDataAtExec(SQLPOINTER* pNextData);
  HRESULT Execute();
  HRESULT CloseCursor();
  HRESULT MoreResults();
  HRESULT Cancel();
  HRESULT Reexecute();
  HRESULT GetRowsAffected(DBROWCOUNT* rows_affected);

  bool
  IsPrepared() const
  {
    return (m_state & S_Prepared) != 0;
  }

  bool
  IsExecuted() const
  {
    return (m_state & S_Executed) != 0;
  }

  bool
  CreatesRowset() const
  {
    return (m_state & S_Creates_Rowset) != 0;
  }

  bool
  HasBookmark() const
  {
    return m_bookmark;
  }

  DBORDINAL
  GetColumnCount() const
  {
    return (DBORDINAL)m_column_count;
  }

  SQLUINTEGER GetCursorType() const;
  SQLUINTEGER GetConcurrency() const;
  bool GetUniqueRows() const;

  void
  DoDiagnostics() const
  {
    ::DoDiagnostics(SQL_HANDLE_STMT, m_hstmt);
  }

  bool
  GetSqlState(char state[6]) const
  {
    return ::GetSQLSTATE(SQL_HANDLE_STMT, m_hstmt, state);
  }

private:

  enum StatementState
  {
    S_Uninitialized = 0,
    S_Initialized = 1,
    S_Prepared = 2,
    S_Executed = 4,
    S_Creates_Rowset = 8,
    S_Executing = 16
  };

  HRESULT CheckResult();

  StatementState m_state;
  ostring m_query;
  Connection m_connection;
  SQLHSTMT m_hstmt;
  bool m_bookmark;
  SQLSMALLINT m_column_count;
};

StatementImpl::StatementImpl()
  : RefCountedImpl("StatementImpl")
{
  LOGCALL(("StatementImpl::StatementImpl()\n"));

  m_state = S_Uninitialized;
  m_column_count = 0;
}

StatementImpl::~StatementImpl()
{
  LOGCALL(("StatementImpl::~StatementImpl()\n"));

  Fini();
}

HRESULT
StatementImpl::Init(const Connection& conn)
{
  assert(m_state == S_Uninitialized);

  m_connection = conn; // does reference counting.

  HDBC hdbc = conn.GetHDBC();

  SQLRETURN rv = SQLAllocHandle(SQL_HANDLE_STMT, hdbc, &m_hstmt);
  if (rv != SQL_SUCCESS && rv != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "Statement::Init(): SQLAllocHandle() failed."));
      ::DoDiagnostics(SQL_HANDLE_DBC, hdbc);
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_DBC, hdbc);
    }

  m_state = S_Initialized;
  return S_OK;
}

HRESULT
StatementImpl::Init(const Connection& conn, const RowsetPropertySet* props)
{
  assert(m_state == S_Uninitialized);

  m_connection = conn; // does reference counting.
  HDBC hdbc = conn.GetHDBC();

  SQLRETURN rc = SQLAllocHandle(SQL_HANDLE_STMT, hdbc, &m_hstmt);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "Statement::Init(): SQLAllocHandle() failed."));
      ::DoDiagnostics(SQL_HANDLE_DBC, hdbc);
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_DBC, hdbc);
    }

  m_bookmark = props->HasBookmark();
  if (m_bookmark)
    {
      rc = SQLSetStmtAttr(m_hstmt, SQL_ATTR_USE_BOOKMARKS, (SQLPOINTER) SQL_UB_FIXED, SQL_IS_INTEGER);
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  TRACE((__FILE__, __LINE__, "Statement::Init(): SQLSetStmtAttr() failed.\n"));
	  return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_hstmt);
	}
    }

  if (props->HasUniqueRows())
    {
      rc = SQLSetStmtAttr(m_hstmt, SQL_UNIQUE_ROWS, (SQLPOINTER) 1, SQL_IS_INTEGER);
      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
	{
	  TRACE((__FILE__, __LINE__, "Statement::Init(): SQLSetStmtAttr() failed.\n"));
	  return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_hstmt);
	}
    }

  SQLUINTEGER cursor_type = props->GetCursorType();
  rc = SQLSetStmtAttr(m_hstmt, SQL_ATTR_CURSOR_TYPE, (SQLPOINTER) cursor_type, SQL_IS_INTEGER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "Statement::Init(): SQLSetStmtAttr() failed.\n"));
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_hstmt);
    }

  SQLUINTEGER concurrency = props->GetConcurrency();
  rc = SQLSetStmtAttr(m_hstmt, SQL_ATTR_CONCURRENCY, (SQLPOINTER) concurrency, SQL_IS_INTEGER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "Statement::Init(): SQLSetStmtAttr() failed.\n"));
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_hstmt);
    }

  m_state = S_Initialized;
  return S_OK;
}

HRESULT
StatementImpl::SetQueryTimeout(int tosecs)
{
  assert(m_state & S_Initialized);

  SQLRETURN rc = SQLSetStmtAttr(m_hstmt, SQL_ATTR_QUERY_TIMEOUT, (SQLPOINTER) tosecs, SQL_IS_UINTEGER);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "Statement::Init(): SQLSetStmtAttr() failed.\n"));
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_hstmt);
    }

  return S_OK;
}

void
StatementImpl::Fini()
{
  if (m_state == S_Uninitialized)
    return;

  SQLRETURN rv = SQLFreeHandle(SQL_HANDLE_STMT, m_hstmt);
  if (rv != SQL_SUCCESS && rv != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "StatementImpl::Fini(): SQLFreeHandle() failed.\n"));
    }
}

HRESULT
StatementImpl::Execute(const ostring& query)
{
  LOGCALL(("StatementImpl::Execute('%ls')\n", query.c_str()));

  assert(m_state & S_Initialized);
  assert(!(m_state & S_Creates_Rowset) || !(m_state & S_Executed));

  SQLRETURN rc;
  rc = SQLExecDirectW (m_hstmt, (SQLWCHAR *) query.c_str(), SQL_NTS);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO && rc != SQL_NEED_DATA)
    {
      TRACE((__FILE__, __LINE__, "StatementImpl::Execute(): SQLExecDirect('%s') failed.\n", query.c_str()));
      DoDiagnostics();

      char sqlstate[6];
      if (GetSQLSTATE(SQL_HANDLE_STMT, m_hstmt, sqlstate))
	{
	  if (strcmp(sqlstate, "07001") == 0)
	    return ErrorInfo::Set(DB_E_PARAMNOTOPTIONAL, SQL_HANDLE_STMT, m_hstmt);
	  if (strcmp(sqlstate, "23000") == 0)
	    return ErrorInfo::Set(DB_E_INTEGRITYVIOLATION, SQL_HANDLE_STMT, m_hstmt);
	  if (strcmp(sqlstate, "37000") == 0 || strcmp(sqlstate, "42000") == 0)
	    return ErrorInfo::Set(DB_E_ERRORSINCOMMAND, SQL_HANDLE_STMT, m_hstmt);
	  if (strcmp(sqlstate, "S0002") == 0 || strcmp(sqlstate, "42S02") == 0)
	    return ErrorInfo::Set(DB_E_NOTABLE, SQL_HANDLE_STMT, m_hstmt);
	  if (strcmp(sqlstate, "HY008") == 0)
	    return ErrorInfo::Set(DB_E_CANCELED, SQL_HANDLE_STMT, m_hstmt);
	}
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_hstmt);
    }

  m_query = query;

  if (rc == SQL_NEED_DATA)
    {
      m_state = (StatementState) (m_state | S_Executing);
      return S_FALSE;
    }

  m_state = (StatementState) (m_state | S_Executed);
  return CheckResult();
}

HRESULT
StatementImpl::Prepare(const ostring& query)
{
  LOGCALL(("StatementImpl::Prepare('%ls')\n", query.c_str()));

  assert(m_state & S_Initialized);
  assert(!(m_state & S_Creates_Rowset) || !(m_state & S_Executed));

  SQLRETURN rv = SQLPrepareW (m_hstmt, (SQLWCHAR *) query.c_str(), SQL_NTS);
  if (rv != SQL_SUCCESS && rv != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "StatementImpl::Prepare(): SQLPrepare() failed.\n"));
      DoDiagnostics();

      char sqlstate[6];
      if (GetSQLSTATE(SQL_HANDLE_STMT, m_hstmt, sqlstate))
	{
	  if (strcmp(sqlstate, "37000") == 0 || strcmp(sqlstate, "42000") == 0)
	    return ErrorInfo::Set(DB_E_ERRORSINCOMMAND, SQL_HANDLE_STMT, m_hstmt);
	  if (strcmp(sqlstate, "S0002") == 0 || strcmp(sqlstate, "42S02") == 0)
	    return ErrorInfo::Set(DB_E_NOTABLE, SQL_HANDLE_STMT, m_hstmt);
	}
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_hstmt);
    }

  m_query = query;
  m_state = (StatementState) (m_state | S_Prepared);
  return CheckResult();
}

HRESULT
StatementImpl::Execute()
{
  LOGCALL(("StatementImpl::Execute()\n"));

  assert(m_state & S_Initialized);
  assert(m_state & S_Prepared);
  assert(!(m_state & S_Creates_Rowset) || !(m_state & S_Executed));

  SQLRETURN rc;
  rc = SQLExecute(m_hstmt);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO && rc != SQL_NEED_DATA)
    {
      TRACE((__FILE__, __LINE__, "StatementImpl::Execute(): SQLExecute() failed.\n"));
      DoDiagnostics();

      char sqlstate[6];
      if (GetSQLSTATE(SQL_HANDLE_STMT, m_hstmt, sqlstate))
	{
	  if (strcmp(sqlstate, "07001") == 0)
	    return ErrorInfo::Set(DB_E_PARAMNOTOPTIONAL, SQL_HANDLE_STMT, m_hstmt);
	  if (strcmp(sqlstate, "23000") == 0)
	    return ErrorInfo::Set(DB_E_INTEGRITYVIOLATION, SQL_HANDLE_STMT, m_hstmt);
	  if (strcmp(sqlstate, "HY008") == 0)
	    return ErrorInfo::Set(DB_E_CANCELED, SQL_HANDLE_STMT, m_hstmt);
	}
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_hstmt);
    }

  if (rc == SQL_NEED_DATA)
    {
      m_state = (StatementState) (m_state | S_Executing);
      return S_FALSE;
    }

  m_state = (StatementState) (m_state | S_Executed);
  return CheckResult();
}

HRESULT
StatementImpl::CheckDataAtExec(SQLPOINTER* pNextData)
{
  LOGCALL(("StatementImpl::SendDataAtExec()\n"));

  assert(m_state & S_Initialized);
  assert(m_state & S_Prepared);
  assert(m_state & S_Executing);

  SQLRETURN rc = SQLParamData(m_hstmt, pNextData);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO && rc != SQL_NEED_DATA)
    {
      TRACE((__FILE__, __LINE__, "StatementImpl::SendDataAtExec(): SQLParamData() failed.\n"));
      DoDiagnostics();

      char sqlstate[6];
      if (GetSQLSTATE(SQL_HANDLE_STMT, m_hstmt, sqlstate))
	{
	  if (strcmp(sqlstate, "07001") == 0)
	    return ErrorInfo::Set(DB_E_PARAMNOTOPTIONAL, SQL_HANDLE_STMT, m_hstmt);
	  if (strcmp(sqlstate, "23000") == 0)
	    return ErrorInfo::Set(DB_E_INTEGRITYVIOLATION, SQL_HANDLE_STMT, m_hstmt);
	  if (strcmp(sqlstate, "37000") == 0 || strcmp(sqlstate, "42000") == 0)
	    return ErrorInfo::Set(DB_E_ERRORSINCOMMAND, SQL_HANDLE_STMT, m_hstmt);
	  if (strcmp(sqlstate, "S0002") == 0 || strcmp(sqlstate, "42S02") == 0)
	    return ErrorInfo::Set(DB_E_NOTABLE, SQL_HANDLE_STMT, m_hstmt);
	  if (strcmp(sqlstate, "HY008") == 0)
	    return ErrorInfo::Set(DB_E_CANCELED, SQL_HANDLE_STMT, m_hstmt);
	}
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_hstmt);
    }

  if (rc == SQL_NEED_DATA)
    return S_FALSE;

  m_state = (StatementState) (m_state & ~S_Executing);
  m_state = (StatementState) (m_state | S_Executed);
  return CheckResult();
}

HRESULT
StatementImpl::CloseCursor()
{
  LOGCALL(("StatementImpl::CloseCursor()\n"));

  if (!(m_state & S_Executed))
    {
      LOG(("Statement is not executed: close cursor skipped.\n"));
      return S_OK;
    }

  SQLRETURN rc = SQLFreeStmt(m_hstmt, SQL_CLOSE);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "StatementImpl::CloseCursor(): SQLFreeStmt() failed.\n"));
      DoDiagnostics();
      return ErrorInfo::Set(E_FAIL);
    }

  m_state = (StatementState) (m_state & ~S_Executed);
  return S_OK;
}

HRESULT
StatementImpl::MoreResults()
{
  LOGCALL(("StatementImpl::MoreResults()\n"));

  assert(m_state & S_Executed);

  m_state = (StatementState) (m_state & ~S_Creates_Rowset);

  SQLRETURN rc = SQLMoreResults(m_hstmt);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      if (rc == SQL_NO_DATA)
	return DB_S_NORESULT;

      TRACE((__FILE__, __LINE__, "StatementImpl::MoreResults(): SQLMoreResults() failed.\n"));
      DoDiagnostics();
      return ErrorInfo::Set(E_FAIL);
    }

  return CheckResult();
}

HRESULT
StatementImpl::Cancel()
{
  SQLRETURN rc = SQLCancel(m_hstmt);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "StatementImpl::CloseCursor(): SQLCloseCursor() failed.\n"));
      DoDiagnostics();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_hstmt);
    }

  return S_OK;
}

HRESULT
StatementImpl::Reexecute()
{
  LOGCALL(("StatementImpl::Reexecute()\n"));

  assert(m_state & S_Executed);

  if ((m_state & S_Creates_Rowset) && (m_state & S_Executed))
    {
      HRESULT hr = CloseCursor();
      if (FAILED(hr))
	return hr;
    }
  return (m_state & S_Prepared) ? Execute() : Execute(m_query);
}

HRESULT
StatementImpl::GetRowsAffected(DBROWCOUNT* rows_affected)
{
  LOGCALL(("StatementImpl::GetRowsAffected()\n"));
  SQLLEN local_rows_affected;

  assert(m_state & S_Executed);

  SQLRETURN rc = SQLRowCount(m_hstmt, &local_rows_affected);

  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "StatementImpl::GetRowsAffected): SQLRowCount() failed.\n"));
      DoDiagnostics();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_hstmt);
    }
  if (rows_affected)
    *rows_affected = local_rows_affected;

  return S_OK;
}

HRESULT
StatementImpl::CheckResult()
{
  LOGCALL(("StatementImpl::CheckResult()\n"));

  SQLRETURN rc = SQLNumResultCols(m_hstmt, &m_column_count);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "StatementImpl::CheckResult(): SQLNumResultCols() failed.\n"));
      DoDiagnostics();
      return ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_hstmt);
    }

  if (m_column_count != 0)
    m_state = (StatementState) (m_state | S_Creates_Rowset);

  return S_OK;
}

SQLUINTEGER
StatementImpl::GetCursorType() const
{
  SQLUINTEGER cursor_type;
  SQLRETURN rc = SQLGetStmtAttr(m_hstmt, SQL_ATTR_CURSOR_TYPE, &cursor_type, SQL_IS_UINTEGER, NULL);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "StatementImpl::GetCursorType(): SQLGetStmtAttr() failed.\n"));
      DoDiagnostics();
      ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_hstmt);
      return VDB_BAD_CURSOR_TYPE;
    }
  return cursor_type;
}

SQLUINTEGER
StatementImpl::GetConcurrency() const
{
  SQLUINTEGER concurrency;
  SQLRETURN rc = SQLGetStmtAttr(m_hstmt, SQL_ATTR_CONCURRENCY, &concurrency, SQL_IS_UINTEGER, NULL);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "StatementImpl::GetConcurrency(): SQLGetStmtAttr() failed.\n"));
      DoDiagnostics();
      ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_hstmt);
      return VDB_BAD_CONCURRENCY;
    }
  return concurrency;
}

bool
StatementImpl::GetUniqueRows() const
{
  SQLUINTEGER unique_rows;
  SQLRETURN rc = SQLGetStmtAttr(m_hstmt, SQL_UNIQUE_ROWS, &unique_rows, SQL_IS_UINTEGER, NULL);
  if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
    {
      TRACE((__FILE__, __LINE__, "StatementImpl::GetUniqueRows(): SQLGetStmtAttr() failed.\n"));
      DoDiagnostics();
      ErrorInfo::Set(E_FAIL, SQL_HANDLE_STMT, m_hstmt);
      return false;
    }
  return (unique_rows != 0);
}

/**********************************************************************/
/* Statement                                                          */

Statement::Statement()
{
}

Statement::~Statement()
{
}

Statement::Statement(const Statement& stmt)
{
  CopyCtor(stmt);
}

Statement&
Statement::operator=(const Statement& stmt)
{
  if (this != &stmt)
    CopyOp(stmt);
  return *this;
}

HRESULT
Statement::Init(const Connection& conn)
{
  Release();
  impl = new StatementImpl();
  if (impl == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  impl->AddRef();
  return impl->Init(conn);
}

HRESULT
Statement::Init(const Connection& conn, const RowsetPropertySet* props)
{
  Release();
  impl = new StatementImpl();
  if (impl == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);
  impl->AddRef();
  return impl->Init(conn, props);
}

HRESULT
Statement::SetQueryTimeout(int tosecs)
{
  assert(impl != NULL);
  return impl->SetQueryTimeout(tosecs);
}

SQLHSTMT
Statement::GetHSTMT() const
{
  assert(impl != NULL);
  return impl->GetHSTMT();
}

HRESULT
Statement::Execute(const ostring& query)
{
  assert(impl != NULL);
  return impl->Execute(query);
}

HRESULT
Statement::Prepare(const ostring& query)
{
  assert(impl != NULL);
  return impl->Prepare(query);
}

HRESULT
Statement::Execute()
{
  assert(impl != NULL);
  return impl->Execute();
}

HRESULT
Statement::CheckDataAtExec(SQLPOINTER* pNextData)
{
  assert(impl != NULL);
  return impl->CheckDataAtExec(pNextData);
}

HRESULT
Statement::CloseCursor()
{
  assert(impl != NULL);
  return impl->CloseCursor();
}

HRESULT
Statement::MoreResults()
{
  assert(impl != NULL);
  return impl->MoreResults();
}

HRESULT
Statement::Cancel()
{
  assert(impl != NULL);
  return impl->Cancel();
}

HRESULT
Statement::Reexecute()
{
  assert(impl != NULL);
  return impl->Reexecute();
}

HRESULT
Statement::GetRowsAffected(DBROWCOUNT* rows_affected)
{
  assert(impl != NULL);
  return impl->GetRowsAffected(rows_affected);
}

bool
Statement::IsPrepared() const
{
  if (impl == NULL)
    return false;
  return impl->IsPrepared();
}

bool
Statement::IsExecuted() const
{
  if (impl == NULL)
    return false;
  return impl->IsExecuted();
}

bool
Statement::CreatesRowset() const
{
  if (impl == NULL)
    return false;
  return impl->CreatesRowset();
}

bool
Statement::HasBookmark() const
{
  assert(impl != NULL);
  return impl->HasBookmark();
}

DBORDINAL
Statement::GetColumnCount() const
{
  assert(impl != NULL);
  return impl->GetColumnCount();
}

SQLUINTEGER
Statement::GetCursorType() const
{
  assert(impl != NULL);
  return impl->GetCursorType();
}

SQLUINTEGER
Statement::GetConcurrency() const
{
  assert(impl != NULL);
  return impl->GetConcurrency();
}

bool
Statement::GetUniqueRows() const
{
  assert(impl != NULL);
  return impl->GetUniqueRows();
}

void
Statement::DoDiagnostics() const
{
  assert(impl != NULL);
  impl->DoDiagnostics();
}

bool
Statement::GetSqlState(char state[6]) const
{
  assert(impl != NULL);
  return impl->GetSqlState(state);
}
