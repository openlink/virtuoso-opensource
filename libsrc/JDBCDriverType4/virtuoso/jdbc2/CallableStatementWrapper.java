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

import java.sql.CallableStatement;
import java.math.BigDecimal;
import java.math.BigInteger;
import java.sql.Date;
import java.sql.Time;
import java.sql.Timestamp;
import java.util.Map;
import java.sql.Ref;
import java.sql.Blob;
import java.sql.Clob;
import java.sql.Array;
import java.util.Calendar;
import java.sql.ResultSet;
import java.io.InputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.Reader;
import java.io.UnsupportedEncodingException;
import java.sql.ResultSetMetaData;
import java.sql.SQLWarning;
import java.sql.SQLException;
import java.sql.Connection;

#if JDK_VER >= 16
import java.sql.RowId;
import java.sql.SQLXML;
import java.sql.NClob;
#endif

public class CallableStatementWrapper
          extends PreparedStatementWrapper implements CallableStatement{

  protected CallableStatementWrapper(ConnectionWrapper _wconn, CallableStatement _stmt) {
    super(_wconn, _stmt, "");
  }


  protected void addLink() {
    wconn.addObjToClose(this);
  }

  protected void removeLink() {
    wconn.removeObjFromClose(this);
  }

  protected synchronized void closeAll() {
    try {
      close();
    } catch(Exception e) { }
  }

  protected PreparedStatementWrapper reuse() {
    throw new java.lang.UnsupportedOperationException();
  }


  public void registerOutParameter(int parameterIndex, int sqlType) throws SQLException {
    check_close();
    try {
      ((CallableStatement)stmt).registerOutParameter(parameterIndex, sqlType);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void registerOutParameter(int parameterIndex, int sqlType, int scale) throws SQLException {
    check_close();
    try {
      ((CallableStatement)stmt).registerOutParameter(parameterIndex, sqlType, scale);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean wasNull() throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).wasNull();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getString(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getString(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean getBoolean(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getBoolean(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public byte getByte(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getByte(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public short getShort(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getShort(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getInt(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getInt(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public long getLong(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getLong(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public float getFloat(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getFloat(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public double getDouble(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getDouble(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public BigDecimal getBigDecimal(int parameterIndex, int scale) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getBigDecimal(parameterIndex, scale);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public byte[] getBytes(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getBytes(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Date getDate(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getDate(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Time getTime(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getTime(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Timestamp getTimestamp(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getTimestamp(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  //----------------------------------------------------------------------
  // Advanced features:


  public Object getObject(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getObject(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  //--------------------------JDBC 2.0-----------------------------

  public BigDecimal getBigDecimal(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getBigDecimal(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


#if JDK_VER >= 16
  public Object getObject(int i, Map<String,Class<?>> map) throws SQLException {
#else
  public Object getObject(int i, Map map) throws SQLException {
#endif
    check_close();
    try {
      return ((CallableStatement)stmt).getObject(i, map);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Ref getRef(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getRef(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Blob getBlob(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getBlob(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Clob getClob(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getClob(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Array getArray(int parameterIndex) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getArray(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Date getDate(int parameterIndex, Calendar cal) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getDate(parameterIndex, cal);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Time getTime(int parameterIndex, Calendar cal) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getTime(parameterIndex, cal);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Timestamp getTimestamp(int parameterIndex, Calendar cal) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getTimestamp(parameterIndex, cal);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void registerOutParameter(int paramIndex, int sqlType, String typeName) throws SQLException {
    check_close();
    try {
      ((CallableStatement)stmt).registerOutParameter(paramIndex, sqlType, typeName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

#if JDK_VER >= 14
  //--------------------------JDBC 3.0-----------------------------

  public void registerOutParameter(String parameterName, int sqlType)
	throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).registerOutParameter(parameterName, sqlType);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void registerOutParameter(String parameterName, int sqlType, int scale)
	throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).registerOutParameter(parameterName, sqlType, scale);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void registerOutParameter (String parameterName, int sqlType, String typeName)
	throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).registerOutParameter(parameterName, sqlType, typeName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public java.net.URL getURL(int parameterIndex)
      throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getURL(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setURL(String parameterName, java.net.URL val)
    throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setURL(parameterName, val);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setNull(String parameterName, int sqlType) throws SQLException {
    check_close();
    try {
      ((CallableStatement)stmt).setNull(parameterName, sqlType);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBoolean(String parameterName, boolean x) throws SQLException {
    check_close();
    try {
      ((CallableStatement)stmt).setBoolean(parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setByte(String parameterName, byte x) throws SQLException {
    check_close();
    try {
      ((CallableStatement)stmt).setByte(parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setShort(String parameterName, short x) throws SQLException {
    check_close();
    try {
      ((CallableStatement)stmt).setShort(parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setInt(String parameterName, int x) throws SQLException {
    check_close();
    try {
      ((CallableStatement)stmt).setInt(parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setLong(String parameterName, long x) throws SQLException {
    check_close();
    try {
      ((CallableStatement)stmt).setLong(parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setFloat(String parameterName, float x) throws SQLException {
    check_close();
    try {
      ((CallableStatement)stmt).setFloat(parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setDouble(String parameterName, double x) throws SQLException {
    check_close();
    try {
      ((CallableStatement)stmt).setDouble(parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBigDecimal(String parameterName, BigDecimal x) throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setBigDecimal(parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setString(String parameterName, String x) throws SQLException {
    check_close();
    try {
      ((CallableStatement)stmt).setString(parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBytes(String parameterName, byte x[]) throws SQLException {
    check_close();
    try {
      ((CallableStatement)stmt).setBytes(parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setDate(String parameterName, java.sql.Date x)
	throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setDate(parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setTime(String parameterName, java.sql.Time x)
	throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setTime(parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setTimestamp(String parameterName, java.sql.Timestamp x)
	throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setTimestamp(parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setAsciiStream(String parameterName, java.io.InputStream x, int length)
	throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setAsciiStream(parameterName, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBinaryStream(String parameterName, java.io.InputStream x,
			 int length) throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setBinaryStream(parameterName, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setObject(String parameterName, Object x, int targetSqlType, int scale)
	throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setObject(parameterName, x, targetSqlType, scale);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setObject(String parameterName, Object x, int targetSqlType)
	throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setObject(parameterName, x, targetSqlType);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setObject(String parameterName, Object x) throws SQLException {
    check_close();
    try {
      ((CallableStatement)stmt).setObject(parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


  public void setCharacterStream(String parameterName,
			    java.io.Reader x,
			    int length) throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setCharacterStream(parameterName, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setDate(String parameterName, java.sql.Date x, Calendar cal)
	throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setDate(parameterName, x, cal);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setTime(String parameterName, java.sql.Time x, Calendar cal)
	throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setTime(parameterName, x, cal);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setTimestamp(String parameterName, java.sql.Timestamp x, Calendar cal)
	throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setTimestamp(parameterName, x, cal);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setNull (String paramName, int sqlType, String typeName)
	throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setNull(paramName, sqlType, typeName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getString(String parameterName) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getString(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean getBoolean(String parameterName) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getBoolean(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public byte getByte(String parameterName) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getByte(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public short getShort(String parameterName) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getShort(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int getInt(String parameterName) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getInt(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public long getLong(String parameterName) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getLong(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public float getFloat(String parameterName) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getFloat(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public double getDouble(String parameterName) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getDouble(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public byte[] getBytes(String parameterName) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getBytes(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public java.sql.Date getDate(String parameterName) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getDate(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public java.sql.Time getTime(String parameterName) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getTime(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public java.sql.Timestamp getTimestamp(String parameterName) throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getTimestamp(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Object getObject(String parameterName) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getObject(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public BigDecimal getBigDecimal(String parameterName) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getBigDecimal(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

#if JDK_VER >= 16
  public Object getObject (String parameterName, Map<String,Class<?>> map)
#else
  public Object getObject (String parameterName, Map map)
#endif
     throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getObject(parameterName, map);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Ref getRef (String parameterName) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getRef(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Blob getBlob (String parameterName) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getBlob(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Clob getClob (String parameterName) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getClob(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public Array getArray (String parameterName) throws SQLException {
    check_close();
    try {
      return ((CallableStatement)stmt).getArray(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public java.sql.Date getDate(String parameterName, Calendar cal)
	throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getDate(parameterName, cal);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public java.sql.Time getTime(String parameterName, Calendar cal)
	throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getTime(parameterName, cal);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public java.sql.Timestamp getTimestamp(String parameterName, Calendar cal)
	throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getTimestamp(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public java.net.URL getURL(String parameterName)
    throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getURL(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

#if JDK_VER >= 16
    //------------------------- JDBC 4.0 -----------------------------------

  public RowId getRowId(int parameterIndex) throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getRowId(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public RowId getRowId(String parameterName) throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getRowId(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setRowId(String parameterName, RowId x) throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setRowId(parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setNString(String parameterName, String value)
            throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setNString(parameterName, value);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setNCharacterStream(String parameterName, Reader value, long length)
            throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setNCharacterStream(parameterName, value, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setNClob(String parameterName, NClob value) throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setNClob(parameterName, value);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setClob(String parameterName, Reader reader, long length)
       throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setClob(parameterName, reader, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBlob(String parameterName, InputStream inputStream, long length)
        throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setBlob(parameterName, inputStream, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setNClob(String parameterName, Reader reader, long length)
       throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setNClob(parameterName, reader, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public NClob getNClob (int parameterIndex) throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getNClob (parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public NClob getNClob (String parameterName) throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getNClob (parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setSQLXML(String parameterName, SQLXML xmlObject) throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setSQLXML(parameterName, xmlObject);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public SQLXML getSQLXML(int parameterIndex) throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getSQLXML(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public SQLXML getSQLXML(String parameterName) throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getSQLXML(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getNString(int parameterIndex) throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getNString(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public String getNString(String parameterName) throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getNString(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public java.io.Reader getNCharacterStream(int parameterIndex) throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getNCharacterStream(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public java.io.Reader getNCharacterStream(String parameterName) throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getNCharacterStream(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public java.io.Reader getCharacterStream(int parameterIndex) throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getCharacterStream(parameterIndex);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public java.io.Reader getCharacterStream(String parameterName) throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getCharacterStream(parameterName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBlob (String parameterName, Blob x) throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setBlob (parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setClob (String parameterName, Clob x) throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setClob (parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setAsciiStream(String parameterName, java.io.InputStream x, long length)
	throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setAsciiStream(parameterName, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBinaryStream(String parameterName, java.io.InputStream x,
			 long length) throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setBinaryStream(parameterName, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setCharacterStream(String parameterName, java.io.Reader reader, long length) throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setCharacterStream(parameterName, reader, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setAsciiStream(String parameterName, java.io.InputStream x)
	    throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setAsciiStream(parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBinaryStream(String parameterName, java.io.InputStream x)
    throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setBinaryStream(parameterName, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setCharacterStream(String parameterName, java.io.Reader reader) throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setCharacterStream(parameterName, reader);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setNCharacterStream(String parameterName, Reader value) throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setNCharacterStream(parameterName, value);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setClob(String parameterName, Reader reader)
       throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setClob(parameterName, reader);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBlob(String parameterName, InputStream inputStream)
        throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setBlob(parameterName, inputStream);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setNClob(String parameterName, Reader reader)
       throws SQLException
  {
    check_close();
    try {
      ((CallableStatement)stmt).setNClob(parameterName, reader);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

#if JDK_VER >= 17
    //--------------------------JDBC 4.1 -----------------------------
  public <T> T getObject(int parameterIndex, Class<T> type) throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getObject(parameterIndex, type);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public <T> T getObject(String parameterName, Class<T> type) throws SQLException
  {
    check_close();
    try {
      return ((CallableStatement)stmt).getObject(parameterName, type);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

#endif

#endif
#endif

}
