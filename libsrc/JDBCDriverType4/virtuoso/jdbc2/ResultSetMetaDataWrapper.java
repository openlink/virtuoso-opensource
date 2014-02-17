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
