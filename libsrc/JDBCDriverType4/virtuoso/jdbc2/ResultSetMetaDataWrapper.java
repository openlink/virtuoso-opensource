/*
 *  ResultSetMetaDataWrapper.java
 *
 *  $Id$
 *
 *  Wrapper for the JDBC ResultSetMetaData class
 *
 *  (C)Copyright 2004 OpenLink Software.
 *  All Rights Reserved.
 *
 *  The copyright above and this notice must be preserved in all
 *  copies of this source code.  The copyright above does not
 *  evidence any actual or intended publication of this source code.
 *
 *  This is unpublished proprietary trade secret of OpenLink Software.
 *  This source code may not be copied, disclosed, distributed, demonstrated
 *  or licensed except as authorized by OpenLink Software.
 */
package virtuoso.jdbc2;

import java.sql.*;


public class ResultSetMetaDataWrapper implements ResultSetMetaData {

  private ResultSetMetaData wmd;
  private ConnectionWrapper wconn;

  protected ResultSetMetaDataWrapper(ResultSetMetaData _rmd,
  	ConnectionWrapper _wconn)
  {
    wmd = _rmd;
    wconn = _wconn;
  }


  private void exceptionOccurred(SQLException sqlEx) {
    if (wconn != null)
      wconn.exceptionOccurred(sqlEx);
  }


  public synchronized void finalize () throws Throwable {
    close();
  }

  protected void close() throws SQLException {
    if (wmd == null)
      return;
    wmd = null;
    wconn = null;
  }


  public int getColumnCount() throws SQLException {
    try {
      return wmd.getColumnCount();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


  public boolean isAutoIncrement(int column) throws SQLException {
    try {
      return wmd.isAutoIncrement(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isCaseSensitive(int column) throws SQLException {
    try {
      return wmd.isCaseSensitive(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isSearchable(int column) throws SQLException {
    try {
      return wmd.isSearchable(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isCurrency(int column) throws SQLException {
    try {
      return wmd.isCurrency(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int isNullable(int column) throws SQLException {
    try {
      return wmd.isNullable(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isSigned(int column) throws SQLException {
    try {
      return wmd.isSigned(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getColumnDisplaySize(int column) throws SQLException {
    try {
      return wmd.getColumnDisplaySize(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getColumnLabel(int column) throws SQLException {
    try {
      return wmd.getColumnLabel(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getColumnName(int column) throws SQLException {
    try {
      return wmd.getColumnName(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getSchemaName(int column) throws SQLException {
    try {
      return wmd.getSchemaName(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getPrecision(int column) throws SQLException {
    try {
      return wmd.getPrecision(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getScale(int column) throws SQLException {
    try {
      return wmd.getScale(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getTableName(int column) throws SQLException {
    try {
      return wmd.getTableName(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getCatalogName(int column) throws SQLException {
    try {
      return wmd.getCatalogName(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getColumnType(int column) throws SQLException {
    try {
      return wmd.getColumnType(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getColumnTypeName(int column) throws SQLException {
    try {
      return wmd.getColumnTypeName(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isReadOnly(int column) throws SQLException {
    try {
      return wmd.isReadOnly(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isWritable(int column) throws SQLException {
    try {
      return wmd.isWritable(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isDefinitelyWritable(int column) throws SQLException {
    try {
      return wmd.isDefinitelyWritable(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

    //--------------------------JDBC 2.0-----------------------------------
  public String getColumnClassName(int column) throws SQLException {
    try {
      return wmd.getColumnClassName(column);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


#if JDK_VER >= 16
  public <T> T unwrap(java.lang.Class<T> iface) throws java.sql.SQLException
  {
    try {
      return wmd.unwrap(iface);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isWrapperFor(java.lang.Class<?> iface) throws java.sql.SQLException
  {
    try {
      return wmd.isWrapperFor(iface);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }
#endif

}
