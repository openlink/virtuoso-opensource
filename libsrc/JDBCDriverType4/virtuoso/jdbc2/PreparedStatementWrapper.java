/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.math.BigDecimal;
import java.sql.Date;
import java.sql.Time;
import java.sql.Timestamp;
import java.io.InputStream;
import java.io.Reader;
import java.io.StringWriter;
import java.io.IOException;
import java.sql.Ref;
import java.sql.Blob;
import java.sql.Clob;
import java.sql.Array;
import java.sql.ResultSetMetaData;
import java.util.*;
import java.sql.SQLWarning;
import java.sql.SQLException;
import java.sql.Connection;
import java.sql.Types;

#if JDK_VER >= 16
import java.sql.RowId;
import java.sql.SQLXML;
import java.sql.NClob;
#endif

public class PreparedStatementWrapper
          extends StatementWrapper implements PreparedStatement {

  protected PreparedStatementWrapper(ConnectionWrapper _wconn, PreparedStatement _stmt) {
    super(_wconn, _stmt);
  }


  public ResultSet executeQuery() throws SQLException {
    check_close();
    try {
      ResultSet rs = ((PreparedStatement)stmt).executeQuery();
      if (rs != null)
        return new ResultSetWrapper(wconn, this, rs);
      else
        return null;
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int executeUpdate() throws SQLException {
    check_close();
    try {
      return ((PreparedStatement)stmt).executeUpdate();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setNull(int parameterIndex, int sqlType) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setNull(parameterIndex, sqlType);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBoolean(int parameterIndex, boolean x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setBoolean(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setByte(int parameterIndex, byte x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setByte(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setShort(int parameterIndex, short x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setShort(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setInt(int parameterIndex, int x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setInt(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setLong(int parameterIndex, long x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setLong(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setFloat(int parameterIndex, float x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setFloat(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setDouble(int parameterIndex, double x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setDouble(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBigDecimal(int parameterIndex, BigDecimal x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setBigDecimal(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setString(int parameterIndex, String x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setString(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBytes(int parameterIndex, byte[] x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setBytes(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setDate(int parameterIndex, Date x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setDate(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setTime(int parameterIndex, Time x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setTime(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setTimestamp(int parameterIndex, Timestamp x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setTimestamp(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setAsciiStream(int parameterIndex, InputStream x, int length) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setAsciiStream(parameterIndex, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setUnicodeStream(int parameterIndex, InputStream x, int length) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setUnicodeStream(parameterIndex, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBinaryStream(int parameterIndex, InputStream x, int length) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setBinaryStream(parameterIndex, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void clearParameters() throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).clearParameters();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  //----------------------------------------------------------------------
  // Advanced features:

  public void setObject(int parameterIndex, Object x, int targetSqlType, int scale) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setObject(parameterIndex, x, targetSqlType, scale);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setObject(int parameterIndex, Object x, int targetSqlType) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setObject(parameterIndex, x, targetSqlType);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setObject(int parameterIndex, Object x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setObject(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public boolean execute() throws SQLException {
    check_close();
    try {
      return ((PreparedStatement)stmt).execute();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  //--------------------------JDBC 2.0-----------------------------

  public void addBatch() throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).addBatch();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public int[] executeBatch() throws SQLException {
    check_close();
    try {
      return ((PreparedStatement)stmt).executeBatch();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setCharacterStream(int parameterIndex, Reader x, int length) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setCharacterStream(parameterIndex, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setRef(int parameterIndex, Ref x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setRef(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBlob(int parameterIndex, Blob x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setBlob(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setClob(int parameterIndex, Clob x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setClob(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setArray(int parameterIndex, Array x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setArray(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public ResultSetMetaData getMetaData() throws SQLException {
    check_close();
    try {
      return ((PreparedStatement)stmt).getMetaData();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setDate(int parameterIndex, Date x, Calendar cal) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setDate(parameterIndex, x, cal);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setTime(int parameterIndex, Time x, Calendar cal) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setTime(parameterIndex, x, cal);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setTimestamp(int parameterIndex, Timestamp x, Calendar cal) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setTimestamp(parameterIndex, x, cal);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setNull(int paramIndex, int sqlType, String typeName) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setNull(paramIndex, sqlType, typeName);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

#if JDK_VER >= 14
    //------------------------- JDBC 3.0 -----------------------------------

  public void setURL(int parameterIndex, java.net.URL x) throws SQLException {
    check_close();
    try {
      ((PreparedStatement)stmt).setURL(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public java.sql.ParameterMetaData getParameterMetaData() throws SQLException {
    check_close();
    try {
      return ((PreparedStatement)stmt).getParameterMetaData();
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }


#if JDK_VER >= 16
    //------------------------- JDBC 4.0 -----------------------------------
  public void setRowId(int parameterIndex, RowId x) throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setRowId(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setNString(int parameterIndex, String value) throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setNString(parameterIndex, value);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setNCharacterStream(int parameterIndex, Reader value, long length) throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setNCharacterStream(parameterIndex, value, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setNClob(int parameterIndex, NClob value) throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setNClob(parameterIndex, value);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setClob(int parameterIndex, Reader reader, long length)
       throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setClob(parameterIndex, reader, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBlob(int parameterIndex, InputStream inputStream, long length)
        throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setBlob(parameterIndex, inputStream, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setNClob(int parameterIndex, Reader reader, long length)
       throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setNClob(parameterIndex, reader, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setSQLXML(int parameterIndex, SQLXML xmlObject) throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setSQLXML(parameterIndex, xmlObject);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setAsciiStream(int parameterIndex, java.io.InputStream x, long length)
	    throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setAsciiStream(parameterIndex, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBinaryStream(int parameterIndex, java.io.InputStream x, long length) throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setBinaryStream(parameterIndex, x, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setCharacterStream(int parameterIndex, java.io.Reader reader, long length) throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setCharacterStream(parameterIndex, reader, length);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setAsciiStream(int parameterIndex, java.io.InputStream x)
	    throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setAsciiStream(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBinaryStream(int parameterIndex, java.io.InputStream x)
    throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setBinaryStream(parameterIndex, x);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setCharacterStream(int parameterIndex, java.io.Reader reader) throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setCharacterStream(parameterIndex, reader);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setNCharacterStream(int parameterIndex, Reader value) throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setNCharacterStream(parameterIndex, value);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setClob(int parameterIndex, Reader reader) throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setClob(parameterIndex, reader);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setBlob(int parameterIndex, InputStream inputStream) throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setBlob(parameterIndex, inputStream);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

  public void setNClob(int parameterIndex, Reader reader) throws SQLException
  {
    check_close();
    try {
      ((PreparedStatement)stmt).setNClob(parameterIndex, reader);
    } catch (SQLException ex) {
      exceptionOccurred(ex);
      throw ex;
    }
  }

#endif
#endif

}
