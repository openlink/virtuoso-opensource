/*
 *  $Id$
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
 */

package virtuoso.jdbc2;

import java.sql.Connection;
import java.sql.Statement;
import java.sql.PreparedStatement;
import java.sql.CallableStatement;
import java.sql.DatabaseMetaData;
import java.sql.SQLWarning;
import java.sql.SQLException;
import java.util.Map;
import java.util.HashMap;
import java.util.Iterator;
import java.util.ListIterator;
import java.util.LinkedList;
import java.util.Properties;
#if JDK_VER >= 14
import java.sql.Savepoint;
#if JDK_VER >= 16
/*DROP_FOR_JDBC3*/
import java.sql.RowId;
import java.sql.SQLXML;
import java.sql.NClob;
import java.sql.Clob;
import java.sql.Blob;
import java.sql.SQLClientInfoException;
import java.sql.Array;
import java.sql.Struct;
#endif
#endif
import javax.transaction.xa.Xid;


public class ConnectionWrapper implements java.sql.Connection {


  private VirtuosoXAResource r_XAResource;
  private Boolean r_AutoCommit;
  private Boolean r_ReadOnly;
  private String  r_Catalog;
  private Integer r_TxnIsolation;
  private Integer r_Holdability;

#if JDK_VER >= 16
  private HashMap<Object,Object> objsToClose;
#else
  private HashMap objsToClose;
#endif
  protected StmtCache pStmtPool;

  private int maxStatements;

  private volatile Connection rconn;       // physical connection
  private VirtuosoPooledConnection pconn; // pooled connection

#if JDK_VER >= 16
  public ConnectionWrapper(Connection rConn,
                           VirtuosoPooledConnection pConn,
                           LinkedList<Object> pStmtsPool,
                           int _maxStatements)
#else
  public ConnectionWrapper(Connection rConn,
                           VirtuosoPooledConnection pConn,
                           LinkedList pStmtsPool,
                           int _maxStatements)
#endif
  {
    rconn = rConn;
    pconn = pConn;
    maxStatements = _maxStatements;
#if JDK_VER >= 16
    objsToClose  = new HashMap<Object,Object>(100);
#else
    objsToClose  = new HashMap(100);
#endif
    pStmtPool = new StmtCache(this, pStmtsPool);
  }

  public void finalize () throws Throwable {
    close();
  }

  // reuse the physical connection
  public void close() throws java.sql.SQLException {
    if (rconn == null)
      return;
    synchronized(this) {
      if (pconn != null)
        pconn.sendCloseEvent();
      rconn = null;
      pconn = null;
    }
  }

  // close the physical connection & clear the statement's cache
  protected synchronized void closeAll() throws SQLException{
    pStmtPool.closeAll();
    close_objs();
    pconn = null;
    reset_XA();
    if (rconn != null)
      rconn.close();
    rconn = null;
  }


  public Statement createStatement() throws SQLException {
    try {
      check_conn();
      return new StatementWrapper(this, rconn.createStatement());
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public PreparedStatement prepareStatement(String sql) throws SQLException {
    try {
      PreparedStatementWrapper pStmt;
      check_conn();
      String stmtKey = sql;
      if ((pStmt = pStmtPool.lookup(stmtKey)) != null)
         return pStmt;
      else
         return new PreparedStatementWrapper(this, rconn.prepareStatement(sql), stmtKey);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public CallableStatement prepareCall(String sql) throws SQLException {
    try {
      check_conn();
      return new CallableStatementWrapper(this, rconn.prepareCall(sql));
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String nativeSQL(String sql) throws SQLException {
    try {
      check_conn();
      return rconn.nativeSQL(sql);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


  public void setAutoCommit(boolean autoCommit) throws SQLException {
    try {
      check_conn();

      if (r_AutoCommit == null)  // save the initial autoCommit state
         r_AutoCommit = new Boolean(getAutoCommit());

      rconn.setAutoCommit(autoCommit);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean getAutoCommit() throws SQLException {
    try {
      check_conn();
      return rconn.getAutoCommit();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void commit() throws SQLException {
    try {
      check_conn();
      rconn.commit();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void rollback() throws SQLException {
    try {
      check_conn();
      rconn.rollback();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isClosed() throws SQLException {
    return (rconn == null);
  }

  public DatabaseMetaData getMetaData() throws SQLException {
    try {
      check_conn();
      return rconn.getMetaData();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setReadOnly(boolean readOnly) throws SQLException {
    try {
      check_conn();

      if (r_ReadOnly == null)  // save the initial readOnly state
         r_ReadOnly = new Boolean(isReadOnly());

      rconn.setReadOnly(readOnly);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isReadOnly() throws SQLException {
    try {
      check_conn();
      return rconn.isReadOnly();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setCatalog(String catalog) throws SQLException {
    try {
      check_conn();

      if (r_Catalog == null)  // save the initial Catalog name
         r_Catalog = getCatalog();

      rconn.setCatalog(catalog);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getCatalog() throws SQLException {
    try {
      check_conn();
      return rconn.getCatalog();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setTransactionIsolation(int level) throws SQLException {
    try {
      check_conn();

      if (r_TxnIsolation == null)  // save the initial TxnIsolation state
         r_TxnIsolation = new Integer(getTransactionIsolation());

      rconn.setTransactionIsolation(level);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getTransactionIsolation() throws SQLException {
    try {
      check_conn();
      return rconn.getTransactionIsolation();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public SQLWarning getWarnings() throws SQLException {
    try {
      check_conn();
      return rconn.getWarnings();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void clearWarnings() throws SQLException {
    try {
      check_conn();
      rconn.clearWarnings();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Statement createStatement(int resultSetType,
                                   int resultSetConcurrency) throws SQLException {
    try {
      check_conn();
      return new StatementWrapper(this, rconn.createStatement(resultSetType,
          resultSetConcurrency));
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public PreparedStatement prepareStatement(String sql,
                                            int resultSetType,
                                            int resultSetConcurrency) throws SQLException {
    try {
      PreparedStatementWrapper pStmt;
      check_conn();
      StringBuffer tmpBuf = new StringBuffer(sql.length()+16);
      tmpBuf.append(resultSetType);           tmpBuf.append('#');
      tmpBuf.append(resultSetConcurrency);    tmpBuf.append('#');
      tmpBuf.append(sql);
      String stmtKey = tmpBuf.toString();
      if ((pStmt = pStmtPool.lookup(stmtKey)) != null)
         return pStmt;
      else
         return new PreparedStatementWrapper(this, rconn.prepareStatement(sql,
            resultSetType, resultSetConcurrency), stmtKey);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public CallableStatement prepareCall(String sql,
                                       int resultSetType,
                                      int resultSetConcurrency) throws SQLException {
    try {
      check_conn();
      return new CallableStatementWrapper(this, rconn.prepareCall(sql,
          resultSetType, resultSetConcurrency));
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

#if JDK_VER >= 16
  public Map<String,Class<?>> getTypeMap() throws SQLException {
#else
  public Map getTypeMap() throws SQLException {
#endif
    try {
      check_conn();
      return rconn.getTypeMap();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

#if JDK_VER >= 16
  public void setTypeMap(Map<String,Class<?>> map) throws SQLException {
#else
  public void setTypeMap(Map map) throws SQLException {
#endif
    check_conn();
    rconn.setTypeMap(map);
  }

#if JDK_VER >= 14
   //-------------------------- JDBC 3.0 ----------------------------------------
  public int getHoldability()
    throws SQLException
  {
    try {
      check_conn();
      return rconn.getHoldability();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setHoldability(int holdability)
    throws SQLException
  {
    try {
      check_conn();

      if (r_Holdability == null)  // save the initial holdability state
         r_Holdability = new Integer(getHoldability());

      rconn.setHoldability(holdability);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Savepoint setSavepoint()
    throws SQLException
  {
    try {
      check_conn();
      return rconn.setSavepoint();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Savepoint setSavepoint(String name)
    throws SQLException
  {
    try {
      check_conn();
      return rconn.setSavepoint(name);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void rollback(Savepoint savepoint)
    throws SQLException
  {
    try {
      check_conn();
      rconn.rollback(savepoint);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void releaseSavepoint(Savepoint savepoint)
    throws SQLException
  {
    try {
      check_conn();
      rconn.releaseSavepoint(savepoint);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


  public Statement createStatement(int resultSetType,
                                   int resultSetConcurrency,
                                   int resultSetHoldability)
                            throws SQLException
  {
    try {
      check_conn();
      return new StatementWrapper(this, rconn.createStatement(resultSetType,
          resultSetConcurrency, resultSetHoldability));
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public PreparedStatement prepareStatement(String sql,
                                          int resultSetType,
                                          int resultSetConcurrency,
                                          int resultSetHoldability)
                                   throws SQLException
  {
    try {
      PreparedStatementWrapper pStmt;
      check_conn();
      StringBuffer tmpBuf = new StringBuffer(sql.length()+16);
      tmpBuf.append(resultSetType);           tmpBuf.append('#');
      tmpBuf.append(resultSetConcurrency);    tmpBuf.append('#');
      tmpBuf.append(resultSetHoldability);    tmpBuf.append('#');
      tmpBuf.append(sql);
      String stmtKey = tmpBuf.toString();
      if ((pStmt = pStmtPool.lookup(stmtKey)) != null)
         return pStmt;
      else
         return new PreparedStatementWrapper(this, rconn.prepareStatement(sql,
            resultSetType, resultSetConcurrency, resultSetHoldability), stmtKey);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public CallableStatement prepareCall(String sql,
                                     int resultSetType,
                                     int resultSetConcurrency,
                                     int resultSetHoldability)
                              throws SQLException
  {
    try {
      check_conn();
      return new CallableStatementWrapper(this, rconn.prepareCall(sql, resultSetType,
              resultSetConcurrency, resultSetHoldability));
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public PreparedStatement prepareStatement(String sql,
                                          int flag)
                                   throws SQLException
  {
    try {
      PreparedStatementWrapper pStmt;
      check_conn();
      StringBuffer tmpBuf = new StringBuffer(sql.length()+16);
      tmpBuf.append(flag);           tmpBuf.append('#');
      tmpBuf.append(sql);
      String stmtKey = tmpBuf.toString();
      if ((pStmt = pStmtPool.lookup(stmtKey)) != null)
         return pStmt;
      else
         return new PreparedStatementWrapper(this, rconn.prepareStatement(sql,
            flag), stmtKey);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public PreparedStatement prepareStatement(String sql,
                                          int[] columnIndexes)
                                   throws SQLException
  {
    try {
      PreparedStatementWrapper pStmt;
      check_conn();
      StringBuffer tmpBuf = new StringBuffer(sql.length()+16);
      tmpBuf.append('$');
      if (columnIndexes != null) {
        for(int i = 0; i < columnIndexes.length; i++)
          tmpBuf.append(columnIndexes[i]);
      }
      tmpBuf.append('$');    tmpBuf.append('#');
      tmpBuf.append(sql);
      String stmtKey = tmpBuf.toString();
      if ((pStmt = pStmtPool.lookup(stmtKey)) != null)
         return pStmt;
      else
         return new PreparedStatementWrapper(this, rconn.prepareStatement(sql,
            columnIndexes), stmtKey);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public PreparedStatement prepareStatement(String sql,
                                            String[] columnNames)
                                   throws SQLException
  {
    try {
      PreparedStatementWrapper pStmt;
      check_conn();
      StringBuffer tmpBuf = new StringBuffer(sql.length()+16);
      tmpBuf.append('@');
      if (columnNames != null) {
        for(int i = 0; i < columnNames.length; i++)
          tmpBuf.append(columnNames[i]);
      }
      tmpBuf.append('@');    tmpBuf.append('#');
      tmpBuf.append(sql);
      String stmtKey = tmpBuf.toString();
      if ((pStmt = pStmtPool.lookup(stmtKey)) != null)
         return pStmt;
      else
         return new PreparedStatementWrapper(this, rconn.prepareStatement(sql,
            columnNames), stmtKey);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

#if JDK_VER >= 16
    //------------------------- JDBC 4.0 -----------------------------------
  public Clob createClob() throws SQLException
  {
    try {
      check_conn();
      return rconn.createClob();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Blob createBlob() throws SQLException
  {
    try {
      check_conn();
      return rconn.createBlob();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public NClob createNClob() throws SQLException
  {
    try {
      check_conn();
      return rconn.createNClob();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public SQLXML createSQLXML() throws SQLException
  {
    try {
      check_conn();
      return rconn.createSQLXML();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isValid(int timeout) throws SQLException
  {
    try {
      check_conn();
      return rconn.isValid(timeout);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setClientInfo(String name, String value) throws SQLClientInfoException
  {
    try {
      check_conn();
      rconn.setClientInfo(name, value);
    } catch (SQLClientInfoException ex) {
      exceptionOccurred(ex);
      throw ex;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw new SQLClientInfoException(ex.getMessage(), ex.getSQLState(), null);
    }
  }

  public void setClientInfo(Properties properties) throws SQLClientInfoException
  {
    try {
      check_conn();
      rconn.setClientInfo(properties);
    } catch (SQLClientInfoException ex) {
      exceptionOccurred(ex);
      throw ex;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw new SQLClientInfoException(ex.getMessage(), ex.getSQLState(), null);
    }
  }

  public String getClientInfo(String name) throws SQLException
  {
    try {
      check_conn();
      return rconn.getClientInfo(name);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Properties getClientInfo() throws SQLException
  {
    try {
      check_conn();
      return rconn.getClientInfo();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Array createArrayOf(String typeName, Object[] elements) throws SQLException
  {
    try {
      check_conn();
      return rconn.createArrayOf(typeName, elements);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Struct createStruct(String typeName, Object[] attributes) throws SQLException
  {
    try {
      check_conn();
      return rconn.createStruct(typeName, attributes);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public <T> T unwrap(java.lang.Class<T> iface) throws java.sql.SQLException
  {
    try {
      check_conn();
      return rconn.unwrap(iface);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isWrapperFor(java.lang.Class<?> iface) throws java.sql.SQLException
  {
    try {
      check_conn();
      // This works for classes that aren't actually wrapping anything
      return rconn.isWrapperFor(iface);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


#if JDK_VER >= 17
   //--------------------------JDBC 4.1 -----------------------------
  public void setSchema(String schema) throws java.sql.SQLException 
  {
    try {
      check_conn();
      rconn.setSchema(schema);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getSchema() throws java.sql.SQLException
  {
    try {
      check_conn();
      return rconn.getSchema();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void abort(java.util.concurrent.Executor executor) throws java.sql.SQLException
  {
    try {
      check_conn();
      rconn.abort(executor);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setNetworkTimeout(java.util.concurrent.Executor executor, 
  			 final int milliseconds) throws java.sql.SQLException
  {
    try {
      check_conn();
      rconn.setNetworkTimeout(executor, milliseconds);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getNetworkTimeout() throws java.sql.SQLException
  {
    try {
      check_conn();
      return rconn.getNetworkTimeout();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }
#endif

#endif
#endif


  protected void setXAResource(VirtuosoXAResource val)
  {
    r_XAResource = val;
  }

  protected void addObjToClose(Object obj)
  {
     synchronized (objsToClose) {
       objsToClose.put(obj, obj);
     }
  }


  protected void removeObjFromClose(Object obj)
  {
     synchronized (objsToClose) {
       objsToClose.remove(obj);
     }
  }


  protected synchronized void reset_XA()
  {
    if (rconn == null)
      return;

    if (r_XAResource != null)
      r_XAResource.reset_XA();
  }


#if JDK_VER >= 16
  protected synchronized LinkedList<Object> reset()
#else
  protected synchronized LinkedList reset()
#endif
  {
    if (rconn == null)
      return null;

    reset_XA();

    try {
      rconn.rollback();
    } catch (SQLException e) {}
    close_objs();
    if (r_AutoCommit != null)
      try {
        rconn.setAutoCommit(r_AutoCommit.booleanValue());
      } catch (SQLException e) {}
    if (r_ReadOnly != null)
      try {
        rconn.setReadOnly(r_ReadOnly.booleanValue());
      } catch (SQLException e) {}
    if (r_Catalog != null)
      try {
        rconn.setCatalog(r_Catalog);
      } catch (SQLException e) {}
    if (r_TxnIsolation != null)
      try {
        rconn.setTransactionIsolation(r_TxnIsolation.intValue());
      } catch (SQLException e) {}
    try {
      rconn.setTypeMap(null);
    } catch (SQLException e) {}
    return pStmtPool.reset();
  }


  protected void clearStmtsCache() {
    pStmtPool.closeAll();
    close_objs();
  }


  protected void exceptionOccurred(SQLException ex) {
      if (pconn != null && VirtuosoConnection.isCriticalError(ex)) {
        pconn.sendErrorEvent(ex);
      }
  }


  private void close_objs() {
#if JDK_VER >= 16
    HashMap<Object,Object> copy = (HashMap<Object,Object>) objsToClose.clone();
#else
    HashMap copy = (HashMap) objsToClose.clone();
#endif
    synchronized(objsToClose) {
      for (Iterator i = copy.keySet().iterator(); i.hasNext(); )
        try {
          ((Closeable)(i.next())).close();
        } catch(Exception e) { }
      objsToClose.clear();
    }
    copy.clear();
  }


  private void check_conn() throws SQLException
  {
    if (rconn == null)
        throw new VirtuosoException("The connection is already closed.",VirtuosoException.DISCONNECTED);
  }


  ///////////////// Inner classes /////////////////////
  protected class StmtCache {

#if JDK_VER >= 16
    private LinkedList<Object>  unUsed = null;
    private HashMap<Object,Object> in_Use = new HashMap<Object,Object>(32);
#else
    private LinkedList  unUsed = null;
    private HashMap in_Use = new HashMap(32);
#endif
    private int cacheSize = 0;
    private ConnectionWrapper connWrapper;

#if JDK_VER >= 16
    protected StmtCache(ConnectionWrapper _connWrapper, LinkedList<Object> pooledStmts) {
#else
    protected StmtCache(ConnectionWrapper _connWrapper, LinkedList pooledStmts) {
#endif
      connWrapper = _connWrapper;
      if (pooledStmts != null) {
        unUsed = pooledStmts;
        attach_stmts(unUsed);
      } else {
#if JDK_VER >= 16
        unUsed = new LinkedList<Object>();
#else
        unUsed = new LinkedList();
#endif
      }

    }

    private PreparedStatementWrapper lookup(String stmtKey) {
      PreparedStatementWrapper pStmt;
      int hashKey = stmtKey.hashCode();
      synchronized(this) {
        for(Iterator iterator = unUsed.iterator(); iterator.hasNext(); ) {
          pStmt = (PreparedStatementWrapper)iterator.next();
          if (pStmt.hashStmtKey == hashKey && pStmt.stmtKey.equals(stmtKey)) {
              iterator.remove();
              return pStmt;
          }
        }
      }
      return null;
    }

    protected synchronized void addToUsed(PreparedStatementWrapper pStmt) {
      in_Use.put(pStmt, pStmt);
      cacheSize++;
    }


    protected void reuse(PreparedStatementWrapper pStmt) throws SQLException {
      boolean reUsed = true;
      PreparedStatementWrapper pooledStmt;
      synchronized(this) {
        in_Use.remove(pStmt);
        cacheSize--;
        if (maxStatements > 0) {
           unUsed.addFirst(pStmt.reuse());
           cacheSize++;
           if (unUsed.size() > maxStatements) {
              unUsed.removeLast();
              cacheSize--;
           }
        } else {
          reUsed = false;
        }
      }
      if ( !reUsed)
        pStmt.closeAll();
    }

#if JDK_VER >= 16
   @SuppressWarnings("unchecked")
   private synchronized LinkedList<Object> reset() {
#else
   private synchronized LinkedList reset() {
#endif
      PreparedStatementWrapper pStmt;
      if (maxStatements > 0) {
        for(ListIterator i = unUsed.listIterator(); i.hasPrevious() && unUsed.size() > maxStatements; ) {
          pStmt = (PreparedStatementWrapper)i.previous();
          i.remove();
          pStmt.closeAll();
        }
      }
      for (Iterator i = in_Use.keySet().iterator(); i.hasNext(); )
        ((PreparedStatementWrapper)(i.next())).closeAll();
      in_Use.clear();
#if JDK_VER >= 16
      LinkedList<Object> retVal = (LinkedList<Object>)(unUsed.clone());
#else
      LinkedList retVal = (LinkedList)unUsed.clone();
#endif
      unUsed.clear();
      detach_stmts(retVal);
      return retVal;
    }

    private synchronized void closeAll() {
      for(Iterator i = unUsed.iterator(); i.hasNext(); )
        ((PreparedStatementWrapper)(i.next())).closeAll();
      unUsed.clear();

      for (Iterator i = in_Use.keySet().iterator(); i.hasNext(); )
        ((PreparedStatementWrapper)(i.next())).closeAll();
      in_Use.clear();
    }

    private void detach_stmts(LinkedList pooledStmts) {
      for (Iterator i = pooledStmts.iterator(); i.hasNext(); )
        try {
          ((PreparedStatementWrapper)(i.next())).wconn = null;
        } catch(Exception e) { }
    }

    private void attach_stmts(LinkedList pooledStmts) {
      for (Iterator i = pooledStmts.iterator(); i.hasNext(); )
        try {
          ((PreparedStatementWrapper)(i.next())).wconn = connWrapper;
        } catch(Exception e) { }
    }

  }
}
