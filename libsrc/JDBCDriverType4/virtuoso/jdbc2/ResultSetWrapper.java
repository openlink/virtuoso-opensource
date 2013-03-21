/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

import java.io.InputStream;
import java.io.Reader;
import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.Date;
import java.sql.Time;
import java.sql.Timestamp;
import java.sql.SQLWarning;
import java.sql.SQLException;
import java.sql.ResultSetMetaData;
import java.sql.Statement;
import java.sql.Ref;
import java.sql.Blob;
import java.sql.Clob;
import java.sql.Array;
import java.util.Map;
import java.util.Calendar;
import java.net.URL;

#if JDK_VER >= 16
import java.sql.RowId;
import java.sql.SQLXML;
import java.sql.NClob;
#endif

public class ResultSetWrapper implements ResultSet, Closeable {
  private ConnectionWrapper wconn;
  private StatementWrapper wstmt;
  private ResultSet rs;

  protected ResultSetWrapper(ConnectionWrapper _wconn, StatementWrapper _wstmt, ResultSet _rs) {
    wconn = _wconn;
    wstmt = _wstmt;
    rs = _rs;
    wstmt.addObjToClose(this);
  }

  protected ResultSetWrapper(ConnectionWrapper _wconn, ResultSet _rs) {
    wconn = _wconn;
    wstmt = null;
    rs = _rs;
    wconn.addObjToClose(this);
  }

  private void exceptionOccurred(SQLException sqlEx) {
    if (wconn != null)
      wconn.exceptionOccurred(sqlEx);
  }

  public synchronized void finalize () throws Throwable {
    close();
  }

  public void close() throws SQLException {
    if (rs == null)
      return;
    check_close();
    try {
      rs.close();
      if (wstmt == null) //DBMetaDataResultSet
        wconn.removeObjFromClose(this);
      else
        {
          wstmt.removeObjFromClose(this);
          wstmt.close();
        }
      rs = null;
      wstmt = null;
      wconn = null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean next() throws SQLException {
    check_close();
    try {
      return rs.next();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean wasNull() throws SQLException {
    check_close();
    try {
      return rs.wasNull();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getString(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getString(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean getBoolean(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getBoolean(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public byte getByte(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getByte(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public short getShort(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getShort(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getInt(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getInt(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public long getLong(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getLong(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public float getFloat(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getFloat(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public double getDouble(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getDouble(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public BigDecimal getBigDecimal(int columnIndex, int scale) throws SQLException {
    check_close();
    try {
      return rs.getBigDecimal(columnIndex, scale);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public byte[] getBytes(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getBytes(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Date getDate(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getDate(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Time getTime(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getTime(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Timestamp getTimestamp(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getTimestamp(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public InputStream getAsciiStream(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getAsciiStream(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public InputStream getUnicodeStream(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getUnicodeStream(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public InputStream getBinaryStream(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getBinaryStream(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getString(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getString(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean getBoolean(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getBoolean(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public byte getByte(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getByte(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public short getShort(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getShort(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getInt(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getInt(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public long getLong(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getLong(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public float getFloat(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getFloat(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public double getDouble(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getDouble(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public BigDecimal getBigDecimal(String columnName, int scale) throws SQLException {
    check_close();
    try {
      return rs.getBigDecimal(columnName, scale);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public byte[] getBytes(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getBytes(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Date getDate(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getDate(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Time getTime(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getTime(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Timestamp getTimestamp(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getTimestamp(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public InputStream getAsciiStream(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getAsciiStream(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public InputStream getUnicodeStream(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getUnicodeStream(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public InputStream getBinaryStream(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getBinaryStream(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public SQLWarning getWarnings() throws SQLException {
    check_close();
    try {
      return rs.getWarnings();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void clearWarnings() throws SQLException {
    check_close();
    try {
      rs.clearWarnings();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getCursorName() throws SQLException {
    check_close();
    try {
      return rs.getCursorName();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSetMetaData getMetaData() throws SQLException {
    check_close();
    try {
      return rs.getMetaData();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Object getObject(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getObject(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Object getObject(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getObject(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int findColumn(String columnName) throws SQLException {
    check_close();
    try {
      return rs.findColumn(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Reader getCharacterStream(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getCharacterStream(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Reader getCharacterStream(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getCharacterStream(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public BigDecimal getBigDecimal(int columnIndex) throws SQLException {
    check_close();
    try {
      return rs.getBigDecimal(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public BigDecimal getBigDecimal(String columnName) throws SQLException {
    check_close();
    try {
      return rs.getBigDecimal(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isBeforeFirst() throws SQLException {
    check_close();
    try {
      return rs.isBeforeFirst();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isAfterLast() throws SQLException {
    check_close();
    try {
      return rs.isAfterLast();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isFirst() throws SQLException {
    check_close();
    try {
      return rs.isFirst();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isLast() throws SQLException {
    check_close();
    try {
      return rs.isLast();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void beforeFirst() throws SQLException {
    check_close();
    try {
      rs.beforeFirst();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void afterLast() throws SQLException {
    check_close();
    try {
      rs.afterLast();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean first() throws SQLException {
    check_close();
    try {
      return rs.first();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean last() throws SQLException {
    check_close();
    try {
      return rs.last();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getRow() throws SQLException {
    check_close();
    try {
      return rs.getRow();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean absolute(int row) throws SQLException {
    check_close();
    try {
      return rs.absolute(row);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean relative(int row) throws SQLException {
    check_close();
    try {
      return rs.relative(row);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean previous() throws SQLException {
    check_close();
    try {
      return rs.previous();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setFetchDirection(int direction) throws SQLException {
    check_close();
    try {
      rs.setFetchDirection(direction);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getFetchDirection() throws SQLException {
    check_close();
    try {
      return rs.getFetchDirection();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setFetchSize(int rows) throws SQLException {
    check_close();
    try {
      rs.setFetchSize(rows);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getFetchSize() throws SQLException {
    check_close();
    try {
      return rs.getFetchSize();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getType() throws SQLException {
    check_close();
    try {
      return rs.getType();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getConcurrency() throws SQLException {
    check_close();
    try {
      return rs.getConcurrency();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean rowUpdated() throws SQLException {
    check_close();
    try {
      return rs.rowUpdated();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean rowInserted() throws SQLException {
    check_close();
    try {
      return rs.rowInserted();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean rowDeleted() throws SQLException {
    check_close();
    try {
      return rs.rowDeleted();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateNull(int columnIndex) throws SQLException {
    check_close();
    try {
      rs.updateNull(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBoolean(int columnIndex, boolean x) throws SQLException {
    check_close();
    try {
      rs.updateBoolean(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateByte(int columnIndex, byte x) throws SQLException {
    check_close();
    try {
      rs.updateByte(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateShort(int columnIndex, short x) throws SQLException {
    check_close();
    try {
      rs.updateShort(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateInt(int columnIndex, int x) throws SQLException {
    check_close();
    try {
      rs.updateInt(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateLong(int columnIndex, long x) throws SQLException {
    check_close();
    try {
      rs.updateLong(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateFloat(int columnIndex, float x) throws SQLException {
    check_close();
    try {
      rs.updateFloat(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateDouble(int columnIndex, double x) throws SQLException {
    check_close();
    try {
      rs.updateDouble(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBigDecimal(int columnIndex, BigDecimal x) throws SQLException {
    check_close();
    try {
      rs.updateBigDecimal(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateString(int columnIndex, String x) throws SQLException {
    check_close();
    try {
      rs.updateString(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBytes(int columnIndex, byte[] x) throws SQLException {
    check_close();
    try {
      rs.updateBytes(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateDate(int columnIndex, Date x) throws SQLException {
    check_close();
    try {
      rs.updateDate(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateTime(int columnIndex, Time x) throws SQLException {
    check_close();
    try {
      rs.updateTime(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateTimestamp(int columnIndex, Timestamp x) throws SQLException {
    check_close();
    try {
      rs.updateTimestamp(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateAsciiStream(int columnIndex, InputStream x, int length) throws SQLException {
    check_close();
    try {
      rs.updateAsciiStream(columnIndex, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBinaryStream(int columnIndex, InputStream x, int length) throws SQLException {
    check_close();
    try {
      rs.updateBinaryStream(columnIndex, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateCharacterStream(int columnIndex, Reader x, int length) throws SQLException {
    check_close();
    try {
      rs.updateCharacterStream(columnIndex, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateObject(int columnIndex, Object x, int scale) throws SQLException {
    check_close();
    try {
      rs.updateObject(columnIndex, x, scale);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateObject(int columnIndex, Object x) throws SQLException {
    check_close();
    try {
      rs.updateObject(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateNull(String columnName) throws SQLException {
    check_close();
    try {
      rs.updateNull(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBoolean(String columnName, boolean x) throws SQLException {
    check_close();
    try {
      rs.updateBoolean(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateByte(String columnName, byte x) throws SQLException {
    check_close();
    try {
      rs.updateByte(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateShort(String columnName, short x) throws SQLException {
    check_close();
    try {
      rs.updateShort(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateInt(String columnName, int x) throws SQLException {
    check_close();
    try {
      rs.updateInt(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateLong(String columnName, long x) throws SQLException {
    check_close();
    try {
      rs.updateLong(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateFloat(String columnName, float x) throws SQLException {
    check_close();
    try {
      rs.updateFloat(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateDouble(String columnName, double x) throws SQLException {
    check_close();
    try {
      rs.updateDouble(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBigDecimal(String columnName, BigDecimal x) throws SQLException {
    check_close();
    try {
      rs.updateBigDecimal(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateString(String columnName, String x) throws SQLException {
    check_close();
    try {
      rs.updateString(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBytes(String columnName, byte[] x) throws SQLException {
    check_close();
    try {
      rs.updateBytes(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateDate(String columnName, Date x) throws SQLException {
    check_close();
    try {
      rs.updateDate(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateTime(String columnName, Time x) throws SQLException {
    check_close();
    try {
      rs.updateTime(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateTimestamp(String columnName, Timestamp x) throws SQLException {
    check_close();
    try {
      rs.updateTimestamp(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateAsciiStream(String columnName, InputStream x, int length) throws SQLException {
    check_close();
    try {
      rs.updateAsciiStream(columnName, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBinaryStream(String columnName, InputStream x, int length) throws SQLException {
    check_close();
    try {
      rs.updateBinaryStream(columnName, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateCharacterStream(String columnName, Reader x, int length) throws SQLException {
    check_close();
    try {
      rs.updateCharacterStream(columnName, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateObject(String columnName, Object x, int scale) throws SQLException {
    check_close();
    try {
      rs.updateObject(columnName, x, scale);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateObject(String columnName, Object x) throws SQLException {
    check_close();
    try {
      rs.updateObject(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void insertRow() throws SQLException {
    check_close();
    try {
      rs.insertRow();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateRow() throws SQLException {
    check_close();
    try {
      rs.updateRow();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void deleteRow() throws SQLException {
    check_close();
    try {
      rs.deleteRow();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void refreshRow() throws SQLException {
    check_close();
    try {
      rs.refreshRow();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void cancelRowUpdates() throws SQLException {
    check_close();
    try {
      rs.cancelRowUpdates();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void moveToInsertRow() throws SQLException {
    check_close();
    try {
      rs.moveToInsertRow();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void moveToCurrentRow() throws SQLException {
    check_close();
    try {
      rs.moveToCurrentRow();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Statement getStatement() throws SQLException {
    check_close();
    return wstmt;
  }

#if JDK_VER >= 16
  public Object getObject(int i, Map<String,Class<?>> map)
#else
  public Object getObject(int i, Map map)
#endif
     throws SQLException
  {
    check_close();
    try {
      return rs.getObject(i, map);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Ref getRef(int i) throws SQLException {
    check_close();
    try {
      return rs.getRef(i);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Blob getBlob(int i) throws SQLException {
    check_close();
    try {
      return rs.getBlob(i);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Clob getClob(int i) throws SQLException {
    check_close();
    try {
      return rs.getClob(i);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Array getArray(int i) throws SQLException {
    check_close();
    try {
      return rs.getArray(i);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

#if JDK_VER >= 16
  public Object getObject(String colName, Map<String,Class<?>> map)
#else
  public Object getObject(String colName, Map map)
#endif
    throws SQLException
  {
    check_close();
    try {
      return rs.getObject(colName, map);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Ref getRef(String colName) throws SQLException {
    check_close();
    try {
      return rs.getRef(colName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Blob getBlob(String colName) throws SQLException {
    check_close();
    try {
      return rs.getBlob(colName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Clob getClob(String colName) throws SQLException {
    check_close();
    try {
      return rs.getClob(colName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Array getArray(String colName) throws SQLException {
    check_close();
    try {
      return rs.getArray(colName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Date getDate(int columnIndex, Calendar cal) throws SQLException {
    check_close();
    try {
      return rs.getDate(columnIndex, cal);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Date getDate(String columnName, Calendar cal) throws SQLException {
    check_close();
    try {
      return rs.getDate(columnName, cal);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Time getTime(int columnIndex, Calendar cal) throws SQLException {
    check_close();
    try {
      return rs.getTime(columnIndex, cal);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Time getTime(String columnName, Calendar cal) throws SQLException {
    check_close();
    try {
      return rs.getTime(columnName, cal);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Timestamp getTimestamp(int columnIndex, Calendar cal) throws SQLException {
    check_close();
    try {
      return rs.getTimestamp(columnIndex, cal);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Timestamp getTimestamp(String columnName, Calendar cal) throws SQLException {
    check_close();
    try {
      return rs.getTimestamp(columnName, cal);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

#if JDK_VER >= 14
    //-------------------------- JDBC 3.0 ----------------------------------------
  public java.net.URL getURL(int columnIndex) throws SQLException
  {
    check_close();
    try {
      return rs.getURL(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public java.net.URL getURL(String columnName) throws SQLException
  {
    check_close();
    try {
      return rs.getURL(columnName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateRef(int columnIndex, java.sql.Ref x) throws SQLException {
    check_close();
    try {
      rs.updateRef(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateRef(String columnName, java.sql.Ref x) throws SQLException {
    check_close();
    try {
      rs.updateRef(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBlob(int columnIndex, java.sql.Blob x) throws SQLException {
    check_close();
    try {
      rs.updateBlob(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBlob(String columnName, java.sql.Blob x) throws SQLException {
    check_close();
    try {
      rs.updateBlob(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateClob(int columnIndex, java.sql.Clob x) throws SQLException {
    check_close();
    try {
      rs.updateClob(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateClob(String columnName, java.sql.Clob x) throws SQLException {
    check_close();
    try {
      rs.updateClob(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateArray(int columnIndex, java.sql.Array x) throws SQLException {
    check_close();
    try {
      rs.updateArray(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateArray(String columnName, java.sql.Array x) throws SQLException {
    check_close();
    try {
      rs.updateArray(columnName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


#if JDK_VER >= 16

    //------------------------- JDBC 4.0 -----------------------------------

  public RowId getRowId(int columnIndex) throws SQLException
  {
    check_close();
    try {
      return rs.getRowId(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public RowId getRowId(String columnLabel) throws SQLException
  {
    check_close();
    try {
      return rs.getRowId(columnLabel);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateRowId(int columnIndex, RowId x) throws SQLException
  {
    check_close();
    try {
      rs.updateRowId(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateRowId(String columnLabel, RowId x) throws SQLException
  {
    check_close();
    try {
      rs.updateRowId(columnLabel, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getHoldability() throws SQLException
  {
    check_close();
    try {
      return rs.getHoldability();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isClosed() throws SQLException
  {
    check_close();
    try {
      return rs.isClosed();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateNString(int columnIndex, String nString) throws SQLException
  {
    check_close();
    try {
      rs.updateNString(columnIndex, nString);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateNString(String columnLabel, String nString) throws SQLException
  {
    check_close();
    try {
      rs.updateNString(columnLabel, nString);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateNClob(int columnIndex, NClob nClob) throws SQLException
  {
    check_close();
    try {
      rs.updateNClob(columnIndex, nClob);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateNClob(String columnLabel, NClob nClob) throws SQLException
  {
    check_close();
    try {
      rs.updateNClob(columnLabel, nClob);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public NClob getNClob(int columnIndex) throws SQLException
  {
    check_close();
    try {
      return rs.getNClob(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public NClob getNClob(String columnLabel) throws SQLException
  {
    check_close();
    try {
      return rs.getNClob(columnLabel);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public SQLXML getSQLXML(int columnIndex) throws SQLException
  {
    check_close();
    try {
      return rs.getSQLXML(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public SQLXML getSQLXML(String columnLabel) throws SQLException
  {
    check_close();
    try {
      return rs.getSQLXML(columnLabel);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateSQLXML(int columnIndex, SQLXML xmlObject) throws SQLException
  {
    check_close();
    try {
      rs.updateSQLXML(columnIndex, xmlObject);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateSQLXML(String columnLabel, SQLXML xmlObject) throws SQLException
  {
    check_close();
    try {
      rs.updateSQLXML(columnLabel, xmlObject);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getNString(int columnIndex) throws SQLException
  {
    check_close();
    try {
      return rs.getNString(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getNString(String columnLabel) throws SQLException
  {
    check_close();
    try {
      return rs.getNString(columnLabel);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public java.io.Reader getNCharacterStream(int columnIndex) throws SQLException
  {
    check_close();
    try {
      return rs.getNCharacterStream(columnIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public java.io.Reader getNCharacterStream(String columnLabel) throws SQLException
  {
    check_close();
    try {
      return rs.getNCharacterStream(columnLabel);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateNCharacterStream(int columnIndex, java.io.Reader x, long length) throws SQLException
  {
    check_close();
    try {
      rs.updateNCharacterStream(columnIndex, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateNCharacterStream(String columnLabel, java.io.Reader reader, long length) throws SQLException
  {
    check_close();
    try {
      rs.updateNCharacterStream(columnLabel, reader, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateAsciiStream(int columnIndex, java.io.InputStream x, long length) throws SQLException
  {
    check_close();
    try {
      rs.updateAsciiStream(columnIndex, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBinaryStream(int columnIndex, java.io.InputStream x, long length) throws SQLException
  {
    check_close();
    try {
      rs.updateBinaryStream(columnIndex, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateCharacterStream(int columnIndex, java.io.Reader x, long length) throws SQLException
  {
    check_close();
    try {
      rs.updateCharacterStream(columnIndex, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateAsciiStream(String columnLabel, java.io.InputStream x, long length) throws SQLException
  {
    check_close();
    try {
      rs.updateAsciiStream(columnLabel, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBinaryStream(String columnLabel, java.io.InputStream x, long length) throws SQLException
  {
    check_close();
    try {
      rs.updateBinaryStream(columnLabel, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateCharacterStream(String columnLabel, java.io.Reader reader, long length) throws SQLException
  {
    check_close();
    try {
      rs.updateCharacterStream(columnLabel, reader, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBlob(int columnIndex, InputStream inputStream, long length) throws SQLException
  {
    check_close();
    try {
      rs.updateBlob(columnIndex, inputStream, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBlob(String columnLabel, InputStream inputStream, long length) throws SQLException
  {
    check_close();
    try {
      rs.updateBlob(columnLabel, inputStream, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateClob(int columnIndex,  Reader reader, long length) throws SQLException
  {
    check_close();
    try {
      rs.updateClob(columnIndex, reader, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateClob(String columnLabel,  Reader reader, long length) throws SQLException
  {
    check_close();
    try {
      rs.updateClob(columnLabel, reader, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateNClob(int columnIndex,  Reader reader, long length) throws SQLException
  {
    check_close();
    try {
      rs.updateNClob(columnIndex, reader, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateNClob(String columnLabel,  Reader reader, long length) throws SQLException
  {
    check_close();
    try {
      rs.updateNClob(columnLabel, reader, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateNCharacterStream(int columnIndex, java.io.Reader x) throws SQLException
  {
    check_close();
    try {
      rs.updateNCharacterStream(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateNCharacterStream(String columnLabel, java.io.Reader reader) throws SQLException
  {
    check_close();
    try {
      rs.updateNCharacterStream(columnLabel, reader);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateAsciiStream(int columnIndex, java.io.InputStream x) throws SQLException
  {
    check_close();
    try {
      rs.updateAsciiStream(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBinaryStream(int columnIndex, java.io.InputStream x) throws SQLException
  {
    check_close();
    try {
      rs.updateBinaryStream(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateCharacterStream(int columnIndex, java.io.Reader x) throws SQLException
  {
    check_close();
    try {
      rs.updateCharacterStream(columnIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateAsciiStream(String columnLabel, java.io.InputStream x) throws SQLException
  {
    check_close();
    try {
      rs.updateAsciiStream(columnLabel, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBinaryStream(String columnLabel, java.io.InputStream x) throws SQLException
  {
    check_close();
    try {
      rs.updateBinaryStream(columnLabel, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateCharacterStream(String columnLabel, java.io.Reader reader) throws SQLException
  {
    check_close();
    try {
      rs.updateCharacterStream(columnLabel, reader);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBlob(int columnIndex, InputStream inputStream) throws SQLException
  {
    check_close();
    try {
      rs.updateBlob(columnIndex, inputStream);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateBlob(String columnLabel, InputStream inputStream) throws SQLException
  {
    check_close();
    try {
      rs.updateBlob(columnLabel, inputStream);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateClob(int columnIndex,  Reader reader) throws SQLException
  {
    check_close();
    try {
      rs.updateClob(columnIndex, reader);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateClob(String columnLabel,  Reader reader) throws SQLException
  {
    check_close();
    try {
      rs.updateClob(columnLabel, reader);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateNClob(int columnIndex,  Reader reader) throws SQLException
  {
    check_close();
    try {
      rs.updateNClob(columnIndex, reader);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void updateNClob(String columnLabel,  Reader reader) throws SQLException
  {
    check_close();
    try {
      rs.updateNClob(columnLabel, reader);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public <T> T unwrap(java.lang.Class<T> iface) throws java.sql.SQLException
  {
    check_close();
    try {
      return rs.unwrap(iface);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean isWrapperFor(java.lang.Class<?> iface) throws java.sql.SQLException
  {
    check_close();
    try {
      return rs.isWrapperFor(iface);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

#if JDK_VER >= 17

    //------------------------- JDBC 4.1 -----------------------------------
  public <T> T getObject(int columnIndex, Class<T> type) throws SQLException
  {
    check_close();
    try {
      return rs.getObject(columnIndex, type);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


  public <T> T getObject(String columnLabel, Class<T> type) throws SQLException
  {
    check_close();
    try {
      return rs.getObject(columnLabel, type);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }
#endif



#endif
#endif

  private void check_close()  throws SQLException
  {
    if (rs == null)
      throw new VirtuosoException("The ResultSet is closed.",VirtuosoException.OK);
  }
}
