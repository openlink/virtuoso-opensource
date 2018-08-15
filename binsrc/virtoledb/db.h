/*  db.h
 *
 *  $Id$
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

#ifndef DB_H
#define DB_H

#include "refcounted.h"
#include "util.h"

class RowsetPropertySet;

class EnvironmentImpl;
class ConnectionPool;
class ConnectionPoolImpl;
class ConnectionImpl;
class StatementImpl;


#define VDB_BAD_CURSOR_TYPE 0x12345678
#define VDB_BAD_CONCURRENCY 0x12345678

struct ConnectionPoolInfo
{
  int cpi_conn_min;
  int cpi_conn_max_soft;
  int cpi_conn_max_hard;
};


struct ConnectionInfo
{
  ConnectionInfo();
  ConnectionInfo(const ConnectionInfo &info);
  ConnectionInfo& operator=(const ConnectionInfo &info);

  std::string ci_userid;
  std::string ci_password;
  std::string ci_datasource;
  std::string ci_catalog;
  std::string ci_providerstring;
  HWND ci_hwnd;
  int ci_prompt;
  int ci_timeout;
  bool ci_encrypt;
  bool ci_show_systemtables;
  std::string ci_pkcs12_file;
};


class Environment : public RefCounted<EnvironmentImpl>
{
public:

  Environment();
  ~Environment();

  Environment(const Environment&);
  Environment& operator=(const Environment&);

  HRESULT Init();
  SQLHENV GetHENV() const;
  void DoDiagnostics() const;

  friend ConnectionPool;
};


class ConnectionPool : public RefCounted<ConnectionPoolImpl>
{
public:

  ConnectionPool();
  ~ConnectionPool();

  ConnectionPool(const ConnectionPool&);
  ConnectionPool& operator=(const ConnectionPool&);

  HRESULT Init
  (
    Environment &environment,
    const ConnectionPoolInfo &pool_info,
    const ConnectionInfo &conn_info
  );

  const ConnectionInfo& GetConnectionInfo() const;

  HRESULT GetActiveSessions(LONG& value);
  HRESULT GetCurrentCatalog(std::string& catalog) const;
  HRESULT SetCurrentCatalog(const std::string& catalog);
  HRESULT GetDBMSName(std::string& value);
  HRESULT GetDBMSVer(std::string& value);
  HRESULT GetIdentifierCase(LONG& value);
  HRESULT GetServerName(std::string& value);
  HRESULT GetUserName(std::string& value);

  friend ConnectionImpl;
};


class Connection : public RefCounted<ConnectionImpl>
{
public:

  Connection();
  ~Connection();

  Connection(const Connection&);
  Connection& operator=(const Connection&);

  HRESULT Init(ConnectionPool& pool, bool multiple_connections);
  HRESULT SetTransactionAttrs(bool auto_commit, ULONG isolation);
  HRESULT EndTransaction(bool commit);
  HRESULT EnlistInDTC(ITransaction* pTransaction);

  SQLHDBC GetHDBC() const;
};


class Statement : public RefCounted<StatementImpl>
{
public:

  Statement();
  ~Statement();

  Statement(const Statement&);
  Statement& operator=(const Statement&);

  HRESULT Init(const Connection& conn);
  HRESULT Init(const Connection& conn, const RowsetPropertySet* props);
  HRESULT SetQueryTimeout(int tosecs);

  HRESULT Execute(const ostring& query);
  HRESULT Prepare(const ostring& query);
  HRESULT Execute();
  HRESULT CheckDataAtExec(SQLPOINTER* pNextData);
  HRESULT CloseCursor();
  HRESULT MoreResults();
  HRESULT Cancel();
  HRESULT Reexecute();
  HRESULT GetRowsAffected(DBROWCOUNT* rows_affected);

  bool IsPrepared() const;
  bool IsExecuted() const;
  bool CreatesRowset() const;
  bool HasBookmark() const;
  DBORDINAL GetColumnCount() const;
  SQLUINTEGER GetCursorType() const;
  SQLUINTEGER GetConcurrency() const;
  bool GetUniqueRows() const;

  SQLHSTMT GetHSTMT() const;

  void DoDiagnostics() const;
  bool GetSqlState(char state[6]) const;
};


#endif
