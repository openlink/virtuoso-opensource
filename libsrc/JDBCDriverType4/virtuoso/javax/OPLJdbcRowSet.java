/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

package virtuoso.javax;

import javax.sql.RowSet;
import javax.sql.RowSetListener;
import javax.sql.DataSource;
import javax.naming.*;
import java.util.Map;
import java.sql.*;
import java.io.InputStream;
import java.io.Reader;
import java.math.BigDecimal;
import java.util.Calendar;
import java.net.URL;

/**

<P>A OPLJdbcRowSet is a connected rowset.  The purpose of the
OPLJdbcRowSet class is to act like a JavaBean at design time and provide
a thin layer that wraps around a JDBC ResultSet at runtime.

<P>When execute() is called a OPLJdbcRowSet object opens a JDBC connection
internally which remains open until close() is called, unless a Connection
is passed to execute() explicitly, in which case that Connection is used
instead.  ResultSet operations such as cursor movement, updating, etc. are
simply delegated to an underlying JDBC ResultSet object which is maintained
internally.

*/

public class OPLJdbcRowSet extends BaseRowSet {

    private Connection conn;
    private PreparedStatement pstmt;
    private ResultSet rs;
    private boolean doDisconnect = false;

  public synchronized void finalize () throws Throwable
  {
    close();
  }

  private Connection connect() throws SQLException {
      String connName;
      if ((connName = getDataSourceName()) != null)
        try {
          InitialContext initialcontext = new InitialContext();
          DataSource ds = (DataSource)initialcontext.lookup(connName);
          return ds.getConnection(getUsername(), getPassword());
        } catch(NamingException e) {
          throw OPLMessage_x.makeException(e);
        }
      else if ((connName = getUrl()) != null)
        return DriverManager.getConnection(connName, getUsername(), getPassword());
      else
        return null;
  }


  private void setParams(PreparedStatement pstmt, Object[] params) throws SQLException {
    if (params == null)
      return;

    for(int i = 0; i < params.length; i++) {
      Parameter par = (Parameter)params[i];
      switch(par.jType) {
        case Parameter.jObject:
            pstmt.setObject(i + 1, par.value);
            break;
        case Parameter.jObject_1:
            pstmt.setObject(i + 1, par.value, par.sqlType);
            break;
        case Parameter.jObject_2:
            pstmt.setObject(i + 1, par.value, par.sqlType, par.scale);
            break;
        case Parameter.jAsciiStream:
            pstmt.setAsciiStream(i + 1, (InputStream)par.value, par.length);
            break;
        case Parameter.jBinaryStream:
            pstmt.setBinaryStream(i + 1, (InputStream)par.value, par.length);
            break;
        case Parameter.jUnicodeStream:
            pstmt.setUnicodeStream(i + 1, (InputStream)par.value, par.length);
            break;
        case Parameter.jCharacterStream:
            pstmt.setCharacterStream(i + 1, (Reader)par.value, par.length);
            break;
        case Parameter.jDateWithCalendar:
            pstmt.setDate(i + 1, (Date)par.value, par.cal);
            break;
        case Parameter.jTimeWithCalendar:
            pstmt.setTime(i + 1, (Time)par.value, par.cal);
            break;
        case Parameter.jTimestampWithCalendar:
            pstmt.setTimestamp(i + 1, (Timestamp)par.value, par.cal);
            break;
        case Parameter.jNull_1:
            pstmt.setNull(i + 1, par.sqlType);
            break;
        case Parameter.jNull_2:
            pstmt.setNull(i + 1, par.sqlType, par.typeName);
            break;
        default:
          throw OPLMessage_x.makeException(OPLMessage_x.errx_Unknown_type_of_parameter);
      }
    }
  }

  /**
   * Populates the rowset with data.
   *
   * Execute() may use the following properties: url, data source name,
   * user name, password, transaction isolation, and type map to create a
   * connection for reading data.
   *
   * Execute may use the following properties to create a statement
   * to execute a command: command, read only, maximum field size,
   * maximum rows, escape processing, and query timeout.
   *
   * If the required properties have not been set, an exception is
   * thrown.  If successful, the current contents of the rowset are
   * discarded and the rowset's metadata is also (re)set.  If there are
   * outstanding updates, they are ignored.
   *
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void execute() throws java.sql.SQLException {
    if (conn == null) {
      conn = connect();
      doDisconnect = true;
    }
    if (conn == null || getCommand() == null)
      throw OPLMessage_x.makeException(OPLMessage_x.errx_SQL_query_is_undefined);

    try {
      conn.setTransactionIsolation(getTransactionIsolation());
    } catch(Exception e) { }

    PreparedStatement pstmt = conn.prepareStatement(getCommand(), getType(),
        getConcurrency());
    setParams(pstmt, getParams());

    try {
      pstmt.setMaxRows(getMaxRows());
      pstmt.setMaxFieldSize(getMaxFieldSize());
      pstmt.setEscapeProcessing(getEscapeProcessing());
      pstmt.setQueryTimeout(getQueryTimeout());
    } catch(Exception e) { }

    rs = pstmt.executeQuery();
    notifyListener(ev_RowSetChanged);
  }

  /**
   * Populates the rowset with data.  Uses an existing JDBC connection object.
   * The values of the url/data source name, user, and password
   * properties are ignored.   The command specified by the command property
   * is executed to retrieve
   * the data.  The current contents of the rowset are discarded and the
   * rowset's metadata is also (re)set.  If there are outstanding updates,
   * they are also ignored.
   *
   * @param _conn a Connection to use
   * @exception SQLException if a database-access error occurs.
   */
  public void execute(Connection _conn) throws SQLException {
    conn = _conn;
    execute();
  }


///////////// ResultSet interface /////////////
  /**
   * In some cases, it is desirable to immediately release a
   * ResultSet's database and JDBC resources instead of waiting for
   * this to happen when it is automatically closed; the close
   * method provides this immediate release.
   *
   * <P><B>Note:</B> A ResultSet is automatically closed by the
   * Statement that generated it when that Statement is closed,
   * re-executed, or is used to retrieve the next result from a
   * sequence of multiple results. A ResultSet is also automatically
   * closed when it is garbage collected.
   *
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void close() throws SQLException {
    if (rs != null)
        rs.close();
    if (pstmt != null)
        pstmt.close();
    if (conn != null && doDisconnect)
        conn.close();
  }

  /**
   * The cancelRowUpdates() method may be called after calling an
   * updateXXX() method(s) and before calling updateRow() to rollback
   * the updates made to a row.  If no updates have been made or
   * updateRow() has already been called, then this method has no
   * effect.
   *
   * @exception SQLException if an error occurs.
   */
  public synchronized void cancelRowUpdates() throws SQLException {
    check_close();
    rs.cancelRowUpdates();
    notifyListener(ev_RowChanged);
  }

  /**
   * A ResultSet is initially positioned before its first row; the
   * first call to next makes the first row the current row; the
   * second call makes the second row the current row, etc.
   *
   * <P>If an input stream from the previous row is open, it is
   * implicitly closed. The ResultSet's warning chain is cleared
   * when a new row is read.
   *
   * @return true if the new current row is valid; false if there
   *   are no more rows
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized boolean next() throws SQLException {
    check_close();
    boolean ret = rs.next();
    notifyListener(ev_CursorMoved);
    return ret;
  }

  /**
   * <p>Moves to the previous row in the result set.
   *
   * <p>Note: previous() is not the same as relative(-1) since it
   * makes sense to call previous() when there is no current row.
   *
   * @return true if on a valid row, false if off the result set.
   * @exception SQLException if a database-access error occurs, or
   * result set type is TYPE_FORWAR_DONLY.
   */
  public synchronized boolean previous() throws SQLException {
    check_close();
    boolean ret = rs.previous();
    notifyListener(ev_CursorMoved);
    return ret;
  }

  /**
   * <p>Moves to the first row in the result set.
   *
   * @return true if on a valid row, false if no rows in the result set.
   * @exception SQLException if a database-access error occurs, or
   * result set type is TYPE_FORWARD_ONLY.
   */
  public synchronized boolean first() throws SQLException {
    check_close();
    boolean ret = rs.first();
    notifyListener(ev_CursorMoved);
    return ret;
  }

  /**
   * <p>Moves to the last row in the result set.
   *
   * @return true if on a valid row, false if no rows in the result set.
   * @exception SQLException if a database-access error occurs, or
   * result set type is TYPE_FORWARD_ONLY.
   */
  public synchronized boolean last() throws SQLException {
    check_close();
    boolean ret = rs.last();
    notifyListener(ev_CursorMoved);
    return ret;
  }

  /**
   * <p>Move to an absolute row number in the result set.
   *
   * <p>If row is positive, moves to an absolute row with respect to the
   * beginning of the result set.  The first row is row 1, the second
   * is row 2, etc.
   *
   * <p>If row is negative, moves to an absolute row position with respect to
   * the end of result set.  For example, calling absolute(-1) positions the
   * cursor on the last row, absolute(-2) indicates the next-to-last
   * row, etc.
   *
   * <p>An attempt to position the cursor beyond the first/last row in
   * the result set, leaves the cursor before/after the first/last
   * row, respectively.
   *
   * <p>Note: Calling absolute(1) is the same as calling first().
   * Calling absolute(-1) is the same as calling last().
   *
   * @return true if on the result set, false if off.
   * @exception SQLException if a database-access error occurs, or
   * row is 0, or result set type is TYPE_FORWARD_ONLY.
   */
  public synchronized boolean absolute(int row) throws SQLException {
    check_close();
    boolean ret = rs.absolute(row);
    notifyListener(ev_CursorMoved);
    return ret;
  }

  /**
   * <p>Moves a relative number of rows, either positive or negative.
   * Attempting to move beyond the first/last row in the
   * result set positions the cursor before/after the
   * the first/last row. Calling relative(0) is valid, but does
   * not change the cursor position.
   *
   * <p>Note: Calling relative(1) is different than calling next()
   * since is makes sense to call next() when there is no current row,
   * for example, when the cursor is positioned before the first row
   * or after the last row of the result set.
   *
   * @return true if on a row, false otherwise.
   * @exception SQLException if a database-access error occurs, or there
   * is no current row, or result set type is TYPE_FORWARD_ONLY.
   */
  public synchronized boolean relative(int rows) throws SQLException {
    check_close();
    boolean ret = rs.relative(rows);
    notifyListener(ev_CursorMoved);
    return ret;
  }

  /**
   * <p>Moves to the front of the result set, just before the
   * first row. Has no effect if the result set contains no rows.
   *
   * @exception SQLException if a database-access error occurs, or
   * result set type is TYPE_FORWARD_ONLY
   */
  public synchronized void beforeFirst() throws SQLException {
    check_close();
    rs.beforeFirst();
    notifyListener(this.ev_CursorMoved);
  }

  /**
   * <p>Moves to the end of the result set, just after the last
   * row.  Has no effect if the result set contains no rows.
   *
   * @exception SQLException if a database-access error occurs, or
   * result set type is TYPE_FORWARD_ONLY.
   */
  public synchronized void afterLast() throws SQLException {
    check_close();
    rs.afterLast();
    notifyListener(this.ev_CursorMoved);
  }

  /**
   * <p>Determine if the cursor is before the first row in the result
   * set.
   *
   * @return true if before the first row, false otherwise. Returns
   * false when the result set contains no rows.
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized boolean isBeforeFirst() throws SQLException {
    check_close();
    return rs.isBeforeFirst();
  }

  /**
   * <p>Determine if the cursor is after the last row in the result
   * set.
   *
   * @return true if after the last row, false otherwise.  Returns
   * false when the result set contains no rows.
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized boolean isAfterLast() throws SQLException {
    check_close();
    return rs.isAfterLast();
  }

  /**
   * <p>Determine if the cursor is on the first row of the result set.
   *
   * @return true if on the first row, false otherwise.
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized boolean isFirst() throws SQLException {
    check_close();
    return rs.isFirst();
  }

  /**
   * <p>Determine if the cursor is on the last row of the result set.
   * Note: Calling isLast() may be expensive since the JDBC driver
   * might need to fetch ahead one row in order to determine
   * whether the current row is the last row in the result set.
   *
   * @return true if on the last row, false otherwise.
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized boolean isLast() throws SQLException {
    check_close();
    return rs.isLast();
  }

  /**
   * <p>Determine the current row number.  The first row is number 1, the
   * second number 2, etc.
   *
   * @return the current row number, else return 0 if there is no
   * current row
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized int getRow() throws SQLException {
    check_close();
    return rs.getRow();
  }

  /**
   * Determine if the current row has been updated.  The value returned
   * depends on whether or not the result set can detect updates.
   *
   * @return true if the row has been visibly updated by the owner or
   * another, and updates are detected
   * @exception SQLException if a database-access error occurs
   *
   * @see DatabaseMetaData#updatesAreDetected
   */
  public synchronized boolean rowUpdated() throws SQLException {
    check_close();
    return rs.rowUpdated();
  }

  /**
   * Determine if the current row has been inserted.  The value returned
   * depends on whether or not the result set can detect visible inserts.
   *
   * @return true if inserted and inserts are detected
   * @exception SQLException if a database-access error occurs
   *
   * @see DatabaseMetaData#insertsAreDetected
   */
  public synchronized boolean rowInserted() throws SQLException {
    check_close();
    return rs.rowInserted();
  }

  /**
   * Determine if this row has been deleted.  A deleted row may leave
   * a visible "hole" in a result set.  This method can be used to
   * detect holes in a result set.  The value returned depends on whether
   * or not the result set can detect deletions.
   *
   * @return true if deleted and deletes are detected
   * @exception SQLException if a database-access error occurs
   *
   * @see DatabaseMetaData#deletesAreDetected
   */
  public synchronized boolean rowDeleted() throws SQLException {
    check_close();
    return rs.rowDeleted();
  }

  /**
   * Refresh the value of the current row with its current value in
   * the database.  Cannot be called when on the insert row.
   *
   * The refreshRow() method provides a way for an application to
   * explicitly tell the JDBC driver to refetch a row(s) from the
   * database.  An application may want to call refreshRow() when
   * caching or prefetching is being done by the JDBC driver to
   * fetch the latest value of a row from the database.  The JDBC driver
   * may actually refresh multiple rows at once if the fetch size is
   * greater than one.
   *
   * All values are refetched subject to the transaction isolation
   * level and cursor sensitivity.  If refreshRow() is called after
   * calling updateXXX(), but before calling updateRow() then the
   * updates made to the row are lost.  Calling refreshRow() frequently
   * will likely slow performance.
   *
   * @exception SQLException if a database-access error occurs, or if
   * called when on the insert row.
   */
  public synchronized void refreshRow() throws SQLException {
    check_close();
    rs.refreshRow();
  }


  /**
   * Inserts the contents of the insert row into this
   * <code>ResultSet</code> objaect and into the database.
   * The cursor must be on the insert row when this method is called.
   *
   * @exception SQLException if a database access error occurs,
   * if this method is called when the cursor is not on the insert row,
   * or if not all of non-nullable columns in
   * the insert row have been given a value
   */
  public synchronized void insertRow() throws SQLException {
    check_close();
    rs.insertRow();
    notifyListener(ev_RowChanged);
  }

  /**
   * Update the underlying database with the new contents of the
   * current row.  Cannot be called when on the insert row.
   *
   * @exception SQLException if a database-access error occurs, or
   * if called when on the insert row
   */
  public synchronized void updateRow() throws SQLException {
    check_close();
    rs.updateRow();
    notifyListener(ev_RowChanged);
  }

  /**
   * Delete the current row from the result set and the underlying
   * database.  Cannot be called when on the insert row.
   *
   * @exception SQLException if a database-access error occurs, or if
   * called when on the insert row.
   */
  public synchronized void deleteRow() throws SQLException {
    check_close();
    rs.deleteRow();
    notifyListener(ev_RowChanged);
  }

  /**
   * Move to the insert row.  The current cursor position is
   * remembered while the cursor is positioned on the insert row.
   *
   * The insert row is a special row associated with an updatable
   * result set.  It is essentially a buffer where a new row may
   * be constructed by calling the updateXXX() methods prior to
   * inserting the row into the result set.
   *
   * Only the updateXXX(), getXXX(), and insertRow() methods may be
   * called when the cursor is on the insert row.  All of the columns in
   * a result set must be given a value each time this method is
   * called before calling insertRow().  UpdateXXX()must be called before
   * getXXX() on a column.
   *
   * @exception SQLException if a database-access error occurs,
   * or the result set is not updatable
   */
  public synchronized void moveToInsertRow() throws SQLException {
    check_close();
    rs.moveToInsertRow();
  }

  /**
   * Move the cursor to the remembered cursor position, usually the
   * current row.  Has no effect unless the cursor is on the insert
   * row.
   *
   * @exception SQLException if a database-access error occurs,
   * or the result set is not updatable
   */
  public synchronized void moveToCurrentRow() throws SQLException {
    check_close();
    rs.moveToCurrentRow();
  }


  /**
   * A column may have the value of SQL NULL; wasNull reports whether
   * the last column read had this special value.
   * Note that you must first call getXXX on a column to try to read
   * its value and then call wasNull() to find if the value was
   * the SQL NULL.
   *
   * @return true if last column read was SQL NULL
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized boolean wasNull() throws SQLException {
    check_close();
    return rs.wasNull();
  }

  /**
   * <p>The first warning reported by calls on this ResultSet is
   * returned. Subsequent ResultSet warnings will be chained to this
   * SQLWarning.
   *
   * <P>The warning chain is automatically cleared each time a new
   * row is read.
   *
   * <P><B>Note:</B> This warning chain only covers warnings caused
   * by ResultSet methods.  Any warning caused by statement methods
   * (such as reading OUT parameters) will be chained on the
   * Statement object.
   *
   * @return the first SQLWarning or null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized SQLWarning getWarnings() throws SQLException {
    check_close();
    return rs.getWarnings();
  }

  /**
   * After this call getWarnings returns null until a new warning is
   * reported for this ResultSet.
   *
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void clearWarnings() throws SQLException {
    check_close();
    rs.clearWarnings();
  }

  /**
   * Get the name of the SQL cursor used by this ResultSet.
   *
   * @return the null
   * @exception SQLException if an error occurs.
   */
  public synchronized String getCursorName() throws SQLException {
    check_close();
    return rs.getCursorName();
  }

  /**
   * The number, types and properties of a ResultSet's columns
   * are provided by the getMetaData method.
   *
   * @return the description of a ResultSet's columns
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized ResultSetMetaData getMetaData() throws SQLException {
    check_close();
    return rs.getMetaData();
  }

  /**
   * Map a Resultset column name to a ResultSet column index.
   *
   * @param columnName the name of the column
   * @return the column index
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized int findColumn(String columnName) throws SQLException {
    check_close();
    return rs.findColumn(columnName);
  }

  /**
   * Get the value of a column in the current row as a Java String.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized String getString(int columnIndex) throws SQLException {
    check_close();
    return rs.getString(columnIndex);
  }

  /**
   * Get the value of a column in the current row as a Java boolean.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is false
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized boolean getBoolean(int columnIndex) throws SQLException {
    check_close();
    return rs.getBoolean(columnIndex);
  }

  /**
   * Get the value of a column in the current row as a Java byte.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized byte getByte(int columnIndex) throws SQLException {
    check_close();
    return rs.getByte(columnIndex);
  }

  /**
   * Get the value of a column in the current row as a Java short.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized short getShort(int columnIndex) throws SQLException {
    check_close();
    return rs.getShort(columnIndex);
  }

  /**
   * Get the value of a column in the current row as a Java int.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized int getInt(int columnIndex) throws SQLException {
    check_close();
    return rs.getInt(columnIndex);
  }

  /**
   * Get the value of a column in the current row as a Java long.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized long getLong(int columnIndex) throws SQLException {
    check_close();
    return rs.getLong(columnIndex);
  }

  /**
   * Get the value of a column in the current row as a Java float.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized float getFloat(int columnIndex) throws SQLException {
    check_close();
    return rs.getFloat(columnIndex);
  }

  /**
   * Get the value of a column in the current row as a Java double.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized double getDouble(int columnIndex) throws SQLException {
    check_close();
    return rs.getDouble(columnIndex);
  }

  /**
   * Get the value of a column in the current row as a java.math.BigDecimal
   * object.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value (full precision); if the value is SQL NULL,
   * the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized BigDecimal getBigDecimal(int columnIndex) throws SQLException {
    check_close();
    return rs.getBigDecimal(columnIndex);
  }

  /**
   * Get the value of a column in the current row as a java.math.BigDecimal object.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param scale the number of digits to the right of the decimal
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   * @deprecated
   */
  public synchronized BigDecimal getBigDecimal(int columnIndex, int scale) throws SQLException {
    check_close();
    return rs.getBigDecimal(columnIndex, scale);
  }

  /**
   * Get the value of a column in the current row as a Java byte array.
   * The bytes represent the raw values returned by the driver.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized byte[] getBytes(int columnIndex) throws SQLException {
    check_close();
    return rs.getBytes(columnIndex);
  }

  /**
   * Get the value of a column in the current row as a java.sql.Date object.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Date getDate(int columnIndex) throws SQLException {
    check_close();
    return rs.getDate(columnIndex);
  }

  /**
   * Get the value of a column in the current row as a java.sql.Time object.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Time getTime(int columnIndex) throws SQLException {
    check_close();
    return rs.getTime(columnIndex);
  }

  /**
   * Get the value of a column in the current row as a java.sql.Timestamp object.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Timestamp getTimestamp(int columnIndex) throws SQLException {
    check_close();
    return rs.getTimestamp(columnIndex);
  }

  /**
   * A column value can be retrieved as a stream of ASCII characters
   * and then read in chunks from the stream.  This method is particularly
   * suitable for retrieving large LONGVARCHAR values.  The JDBC driver will
   * do any necessary conversion from the database format into ASCII.
   *
   * <P><B>Note:</B> All the data in the returned stream must be
   * read prior to getting the value of any other column. The next
   * call to a get method implicitly closes the stream. . Also, a
   * stream may return 0 for available() whether there is data
   * available or not.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return a Java input stream that delivers the database column value
   * as a stream of one byte ASCII characters.  If the value is SQL NULL
   * then the result is null.
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized InputStream getAsciiStream(int columnIndex) throws SQLException {
    check_close();
    return rs.getAsciiStream(columnIndex);
  }

  /**
   * A column value can be retrieved as a stream of Unicode characters
   * and then read in chunks from the stream.  This method is particularly
   * suitable for retrieving large LONGVARCHAR values.  The JDBC driver will
   * do any necessary conversion from the database format into Unicode.
   *
   * <P><B>Note:</B> All the data in the returned stream must be
   * read prior to getting the value of any other column. The next
   * call to a get method implicitly closes the stream. . Also, a
   * stream may return 0 for available() whether there is data
   * available or not.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return a Java input stream that delivers the database column value
   * as a stream of two byte Unicode characters.  If the value is SQL NULL
   * then the result is null.
   * @exception SQLException if a database-access error occurs.
   * @deprecated
   */
  public synchronized InputStream getUnicodeStream(int columnIndex) throws SQLException {
    check_close();
    return rs.getUnicodeStream(columnIndex);
  }

  /**
   * A column value can be retrieved as a stream of uninterpreted bytes
   * and then read in chunks from the stream.  This method is particularly
   * suitable for retrieving large LONGVARBINARY values.
   *
   * <P><B>Note:</B> All the data in the returned stream must be
   * read prior to getting the value of any other column. The next
   * call to a get method implicitly closes the stream. Also, a
   * stream may return 0 for available() whether there is data
   * available or not.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return a Java input stream that delivers the database column value
   * as a stream of uninterpreted bytes.  If the value is SQL NULL
   * then the result is null.
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized InputStream getBinaryStream(int columnIndex) throws SQLException {
    check_close();
    return rs.getBinaryStream(columnIndex);
  }

  /**
   * <p>Get the value of a column in the current row as a Java object.
   *
   * <p>This method will return the value of the given column as a
   * Java object.  The type of the Java object will be the default
   * Java object type corresponding to the column SQL type,
   * following the mapping for built-in types specified in the JDBC
   * spec.
   *
   * <p>This method may also be used to read database specific
   * abstract data types.
   *
   * JDBC 2.0
   *
   * New behavior for getObject().
   * The behavior of method getObject() is extended to materialize
   * data of SQL user-defined types.  When the column @column is
   * a structured or distinct value, the behavior of this method is as
   * if it were a call to: getObject(column,
   * this.getStatement().getConnection().getTypeMap()).
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @return a java.lang.Object holding the column value.
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Object getObject(int columnIndex) throws SQLException {
    check_close();
    return rs.getObject(columnIndex);
  }

  /**
   * Get the value of a column in the current row as a Java String.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized String getString(String columnName) throws SQLException {
    check_close();
    return rs.getString(columnName);
  }

  /**
   * Get the value of a column in the current row as a Java boolean.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is false
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized boolean getBoolean(String columnName) throws SQLException {
    check_close();
    return rs.getBoolean(columnName);
  }

  /**
   * Get the value of a column in the current row as a Java byte.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized byte getByte(String columnName) throws SQLException {
    check_close();
    return rs.getByte(columnName);
  }

  /**
   * Get the value of a column in the current row as a Java short.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized short getShort(String columnName) throws SQLException {
    check_close();
    return rs.getShort(columnName);
  }

  /**
   * Get the value of a column in the current row as a Java int.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized int getInt(String columnName) throws SQLException {
    check_close();
    return rs.getInt(columnName);
  }

  /**
   * Get the value of a column in the current row as a Java long.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized long getLong(String columnName) throws SQLException {
    check_close();
    return rs.getLong(columnName);
  }

  /**
   * Get the value of a column in the current row as a Java float.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized float getFloat(String columnName) throws SQLException {
    check_close();
    return rs.getFloat(columnName);
  }

  /**
   * Get the value of a column in the current row as a Java double.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is 0
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized double getDouble(String columnName) throws SQLException {
    check_close();
    return rs.getDouble(columnName);
  }

  /**
   * Get the value of a column in the current row as a java.math.BigDecimal
   * object.
   *
   * @param columnName is the SQL name of the column
   * @param scale the number of digits to the right of the decimal
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   * @deprecated
   */
  public synchronized BigDecimal getBigDecimal(String columnName, int scale) throws SQLException {
    check_close();
    return rs.getBigDecimal(columnName, scale);
  }

  /**
   * Get the value of a column in the current row as a Java byte array.
   * The bytes represent the raw values returned by the driver.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized byte[] getBytes(String columnName) throws SQLException {
    check_close();
    return rs.getBytes(columnName);
  }

  /**
   * Get the value of a column in the current row as a java.sql.Date object.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Date getDate(String columnName) throws SQLException {
    check_close();
    return rs.getDate(columnName);
  }

  /**
   * Get the value of a column in the current row as a java.sql.Time object.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Time getTime(String columnName) throws SQLException {
    check_close();
    return rs.getTime(columnName);
  }

  /**
   * Get the value of a column in the current row as a java.sql.Timestamp object.
   *
   * @param columnName is the SQL name of the column
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Timestamp getTimestamp(String columnName) throws SQLException {
    check_close();
    return rs.getTimestamp(columnName);
  }

  /**
   * A column value can be retrieved as a stream of ASCII characters
   * and then read in chunks from the stream.  This method is particularly
   * suitable for retrieving large LONGVARCHAR values.  The JDBC driver will
   * do any necessary conversion from the database format into ASCII.
   *
   * <P><B>Note:</B> All the data in the returned stream must
   * be read prior to getting the value of any other column. The
   * next call to a get method implicitly closes the stream.
   *
   * @param columnName is the SQL name of the column
   * @return a Java input stream that delivers the database column value
   * as a stream of one byte ASCII characters.  If the value is SQL NULL
   * then the result is null.
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized InputStream getAsciiStream(String columnName) throws SQLException {
    check_close();
    return rs.getAsciiStream(columnName);
  }

  /**
   * A column value can be retrieved as a stream of Unicode characters
   * and then read in chunks from the stream.  This method is particularly
   * suitable for retrieving large LONGVARCHAR values.  The JDBC driver will
   * do any necessary conversion from the database format into Unicode.
   *
   * <P><B>Note:</B> All the data in the returned stream must
   * be read prior to getting the value of any other column. The
   * next call to a get method implicitly closes the stream.
   *
   * @param columnName is the SQL name of the column
   * @return a Java input stream that delivers the database column value
   * as a stream of two byte Unicode characters.  If the value is SQL NULL
   * then the result is null.
   * @exception SQLException if a database-access error occurs.
   * @deprecated
   */
  public synchronized InputStream getUnicodeStream(String columnName) throws SQLException {
    check_close();
    return rs.getUnicodeStream(columnName);
  }

  /**
   * A column value can be retrieved as a stream of uninterpreted bytes
   * and then read in chunks from the stream.  This method is particularly
   * suitable for retrieving large LONGVARBINARY values.
   *
   * <P><B>Note:</B> All the data in the returned stream must
   * be read prior to getting the value of any other column. The
   * next call to a get method implicitly closes the stream.
   *
   * @param columnName is the SQL name of the column
   * @return a Java input stream that delivers the database column value
   * as a stream of uninterpreted bytes.  If the value is SQL NULL
   * then the result is null.
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized InputStream getBinaryStream(String columnName) throws SQLException {
    check_close();
    return rs.getBinaryStream(columnName);
  }

  /**
   * <p>Get the value of a column in the current row as a Java object.
   *
   * <p>This method will return the value of the given column as a
   * Java object.  The type of the Java object will be the default
   * Java object type corresponding to the column SQL type,
   * following the mapping for built-in types specified in the JDBC
   * spec.
   *
   * <p>This method may also be used to read database specific
   * abstract data types.
   *
   * JDBC 2.0
   *
   * New behavior for getObject().
   * The behavior of method getObject() is extended to materialize
   * data of SQL user-defined types.  When the column @columnName is
   * a structured or distinct value, the behavior of this method is as
   * if it were a call to: getObject(columnName,
   * this.getStatement().getConnection().getTypeMap()).
   *
   * @param columnName is the SQL name of the column
   * @return a java.lang.Object holding the column value.
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Object getObject(String columnName) throws SQLException {
    check_close();
    return rs.getObject(columnName);
  }

  /**
   * <p>Get the value of a column in the current row as a java.io.Reader.
   */
  public synchronized Reader getCharacterStream(int columnIndex) throws SQLException {
    check_close();
    return rs.getCharacterStream(columnIndex);
  }

  /**
   * <p>Get the value of a column in the current row as a java.io.Reader.
   */
  public synchronized Reader getCharacterStream(String columnName) throws SQLException {
    check_close();
    return rs.getCharacterStream(columnName);
  }

  /**
   * Get the value of a column in the current row as a java.math.BigDecimal
   * object.
   *
   */
  public synchronized BigDecimal getBigDecimal(String columnName) throws SQLException {
    check_close();
    return rs.getBigDecimal(columnName);
  }

  /**
   * Give a nullable column a null value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateNull(int columnIndex) throws SQLException {
    check_close();
    rs.updateNull(columnIndex);
  }

  /**
   * Update a column with a boolean value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateBoolean(int columnIndex, boolean x) throws SQLException {
    check_close();
    rs.updateBoolean(columnIndex, x);
  }

  /**
   * Update a column with a byte value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateByte(int columnIndex, byte x) throws SQLException {
    check_close();
    rs.updateByte(columnIndex, x);
  }

  /**
   * Update a column with a short value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateShort(int columnIndex, short x) throws SQLException {
    check_close();
    rs.updateShort(columnIndex, x);
  }

  /**
   * Update a column with an integer value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateInt(int columnIndex, int x) throws SQLException {
    check_close();
    rs.updateInt(columnIndex, x);
  }

  /**
   * Update a column with a long value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateLong(int columnIndex, long x) throws SQLException {
    check_close();
    rs.updateLong(columnIndex, x);
  }

  /**
   * Update a column with a float value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateFloat(int columnIndex, float x) throws SQLException {
    check_close();
    rs.updateFloat(columnIndex, x);
  }

  /**
   * Update a column with a Double value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateDouble(int columnIndex, double x) throws SQLException {
    check_close();
    rs.updateDouble(columnIndex, x);
  }

  /**
   * Update a column with a BigDecimal value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateBigDecimal(int columnIndex, BigDecimal x) throws SQLException {
    check_close();
    rs.updateBigDecimal(columnIndex, x);
  }

  /**
   * Update a column with a String value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateString(int columnIndex, String x) throws SQLException {
    check_close();
    rs.updateString(columnIndex, x);
  }

  /**
   * Update a column with a byte array value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateBytes(int columnIndex, byte[] x) throws SQLException {
    check_close();
    rs.updateBytes(columnIndex, x);
  }

  /**
   * Update a column with a Date value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateDate(int columnIndex, Date x) throws SQLException {
    check_close();
    rs.updateDate(columnIndex, x);
  }

  /**
   * Update a column with a Time value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateTime(int columnIndex, Time x) throws SQLException {
    check_close();
    rs.updateTime(columnIndex, x);
  }

  /**
   * Update a column with a Timestamp value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateTimestamp(int columnIndex, Timestamp x) throws SQLException {
    check_close();
    rs.updateTimestamp(columnIndex, x);
  }

  /**
   * Update a column with an ascii stream value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @param length the length of the stream
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateAsciiStream(int columnIndex, InputStream x, int length) throws SQLException {
    check_close();
    rs.updateAsciiStream(columnIndex, x, length);
  }

  /**
   * Update a column with a binary stream value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @param length the length of the stream
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateBinaryStream(int columnIndex, InputStream x, int length) throws SQLException {
    check_close();
    rs.updateBinaryStream(columnIndex, x, length);
  }

  /**
   * Update a column with a character stream value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @param length the length of the stream
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateCharacterStream(int columnIndex, Reader x, int length) throws SQLException {
    check_close();
    rs.updateCharacterStream(columnIndex, x, length);
  }

  /**
   * Update a column with an Object value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @param scale For java.sql.Types.DECIMAL or java.sql.Types.NUMERIC types
   *  this is the number of digits after the decimal.  For all other
   *  types this value will be ignored.
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateObject(int columnIndex, Object x, int scale) throws SQLException {
    check_close();
    rs.updateObject(columnIndex, x, scale);
  }

  /**
   * Update a column with an Object value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateObject(int columnIndex, Object x) throws SQLException {
    check_close();
    rs.updateObject(columnIndex, x);
  }


  /**
   * Update a column with a null value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateNull(String columnName) throws SQLException {
    check_close();
    rs.updateNull(columnName);
  }

  /**
   * Update a column with a boolean value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateBoolean(String columnName, boolean x) throws SQLException {
    check_close();
    rs.updateBoolean(columnName, x);
  }

  /**
   * Update a column with a byte value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateByte(String columnName, byte x) throws SQLException {
    check_close();
    rs.updateByte(columnName, x);
  }

  /**
   * Update a column with a short value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateShort(String columnName, short x) throws SQLException {
    check_close();
    rs.updateShort(columnName, x);
  }

  /**
   * Update a column with an integer value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateInt(String columnName, int x) throws SQLException {
    check_close();
    rs.updateInt(columnName, x);
  }

  /**
   * Update a column with a long value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateLong(String columnName, long x) throws SQLException {
    check_close();
    rs.updateLong(columnName, x);
  }

  /**
   * Update a column with a float value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateFloat(String columnName, float x) throws SQLException {
    check_close();
    rs.updateFloat(columnName, x);
  }

  /**
   * Update a column with a double value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateDouble(String columnName, double x) throws SQLException {
    check_close();
    rs.updateDouble(columnName, x);
  }

  /**
   * Update a column with a BigDecimal value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateBigDecimal(String columnName, BigDecimal x) throws SQLException {
    check_close();
    rs.updateBigDecimal(columnName, x);
  }

  /**
   * Update a column with a String value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateString(String columnName, String x) throws SQLException {
    check_close();
    rs.updateString(columnName, x);
  }

  /**
   * Update a column with a byte array value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateBytes(String columnName, byte[] x) throws SQLException {
    check_close();
    rs.updateBytes(columnName, x);
  }

  /**
   * Update a column with a Date value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateDate(String columnName, Date x) throws SQLException {
    check_close();
    rs.updateDate(columnName, x);
  }

  /**
   * Update a column with a Time value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateTime(String columnName, Time x) throws SQLException {
    check_close();
    rs.updateTime(columnName, x);
  }

  /**
   * Update a column with a Timestamp value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateTimestamp(String columnName, Timestamp x) throws SQLException {
    check_close();
    rs.updateTimestamp(columnName, x);
  }

  /**
   * Update a column with an ascii stream value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @param length of the stream
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateAsciiStream(String columnName, InputStream x, int length) throws SQLException {
    check_close();
    rs.updateAsciiStream(columnName, x, length);
  }

  /**
   * Update a column with a binary stream value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @param length of the stream
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateBinaryStream(String columnName, InputStream x, int length) throws SQLException {
    check_close();
    rs.updateBinaryStream(columnName, x, length);
  }

  /**
   * Update a column with a character stream value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @param length of the stream
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateCharacterStream(String columnName, Reader x, int length) throws SQLException {
    check_close();
    rs.updateCharacterStream(columnName, x, length);
  }

  /**
   * Update a column with an Object value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @param scale For java.sql.Types.DECIMAL or java.sql.Types.NUMERIC types
   *  this is the number of digits after the decimal.  For all other
   *  types this value will be ignored.
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateObject(String columnName, Object x, int scale) throws SQLException {
    check_close();
    rs.updateObject(columnName, x, scale);
  }

  /**
   * Update a column with an Object value.
   *
   * The updateXXX() methods are used to update column values in the
   * current row, or the insert row.  The updateXXX() methods do not
   * update the underlying database, instead the updateRow() or insertRow()
   * methods are called to update the database.
   *
   * @param columnName the name of the column
   * @param x the new column value
   * @exception SQLException if a database-access error occurs
   */
  public synchronized void updateObject(String columnName, Object x) throws SQLException {
    check_close();
    rs.updateObject(columnName, x);
  }

  /**
   * Return the Statement that produced the ResultSet.
   *
   * @return the Statement that produced the result set
   *
   * @exception SQLException if a database-access error occurs
   */
  public synchronized Statement getStatement() throws SQLException {
    check_close();
    return rs.getStatement();
  }

  /**
   * Returns the value of column @i as a Java object.  Use the
   * map to determine the class from which to construct data of
   * SQL structured and distinct types.
   *
   * @param colIndex the first column is 1, the second is 2, ...
   * @param map the mapping from SQL type names to Java classes
   * @return an object representing the SQL value
   */
  public synchronized Object getObject(int colIndex, Map<String,Class<?>> map)
   throws SQLException
  {
    check_close();
    return rs.getObject(colIndex, map);
  }

  /**
   * Get a REF(&lt;structured-type&gt;) column.
   *
   * @param colIndex the first column is 1, the second is 2, ...
   * @return an object representing data of an SQL REF type
   */
  public synchronized Ref getRef(int colIndex) throws SQLException {
    check_close();
    return rs.getRef(colIndex);
  }

  /**
   * Get a BLOB column.
   *
   * @param colIndex the first column is 1, the second is 2, ...
   * @return an object representing a BLOB
   */
  public synchronized Blob getBlob(int colIndex) throws SQLException {
    check_close();
    return rs.getBlob(colIndex);
  }

  /**
   * Get a CLOB column.
   *
   * @param colIndex the first column is 1, the second is 2, ...
   * @return an object representing a CLOB
   */
  public synchronized Clob getClob(int colIndex) throws SQLException {
    check_close();
    return rs.getClob(colIndex);
  }

  /**
   * Get an array column.
   *
   * @param colIndex the first column is 1, the second is 2, ...
   * @return an object representing an SQL array
   */
  public synchronized Array getArray(int colIndex) throws SQLException {
    check_close();
    return rs.getArray(colIndex);
  }

  /**
   * Returns the value of column @i as a Java object.  Use the
   * map to determine the class from which to construct data of
   * SQL structured and distinct types.
   *
   * @param colName the column name
   * @param map the mapping from SQL type names to Java classes
   * @return an object representing the SQL value
   */
  public synchronized Object getObject(String colName, Map<String,Class<?>> map)
     throws SQLException
  {
    check_close();
    return rs.getObject(colName, map);
  }

  /**
   * Get a REF(&lt;structured-type&gt;) column.
   *
   * @param colName the column name
   * @return an object representing data of an SQL REF type
   */
  public synchronized Ref getRef(String colName) throws SQLException {
    check_close();
    return rs.getRef(colName);
  }

  /**
   * Get a BLOB column.
   *
   * @param colName the column name
   * @return an object representing a BLOB
   */
  public synchronized Blob getBlob(String colName) throws SQLException {
    check_close();
    return rs.getBlob(colName);
  }

  /**
   * Get a CLOB column.
   *
   * @param colName the column name
   * @return an object representing a CLOB
   */
  public synchronized Clob getClob(String colName) throws SQLException {
    check_close();
    return rs.getClob(colName);
  }

  /**
   * Get an array column.
   *
   * @param colName the column name
   * @return an object representing an SQL array
   */
  public synchronized Array getArray(String colName) throws SQLException {
    check_close();
    return rs.getArray(colName);
  }

  /**
   * Get the value of a column in the current row as a java.sql.Date
   * object.  Use the calendar to construct an appropriate millisecond
   * value for the Date, if the underlying database does not store
   * timezone information.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param cal the calendar to use in constructing the date
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Date getDate(int columnIndex, Calendar cal) throws SQLException {
    check_close();
    return rs.getDate(columnIndex, cal);
  }

  /**
   * Get the value of a column in the current row as a java.sql.Date
   * object. Use the calendar to construct an appropriate millisecond
   * value for the Date, if the underlying database does not store
   * timezone information.
   *
   * @param columnName is the SQL name of the column
   * @param cal the calendar to use in constructing the date
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Date getDate(String columnName, Calendar cal) throws SQLException {
    check_close();
    return rs.getDate(columnName, cal);
  }

  /**
   * Get the value of a column in the current row as a java.sql.Time
   * object. Use the calendar to construct an appropriate millisecond
   * value for the Time, if the underlying database does not store
   * timezone information.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param cal the calendar to use in constructing the time
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Time getTime(int columnIndex, Calendar cal) throws SQLException {
    check_close();
    return rs.getTime(columnIndex, cal);
  }

  /**
   * Get the value of a column in the current row as a java.sql.Time
   * object. Use the calendar to construct an appropriate millisecond
   * value for the Time, if the underlying database does not store
   * timezone information.
   *
   * @param columnName is the SQL name of the column
   * @param cal the calendar to use in constructing the time
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Time getTime(String columnName, Calendar cal) throws SQLException {
    check_close();
    return rs.getTime(columnName, cal);
  }

  /**
   * Get the value of a column in the current row as a java.sql.Timestamp
   * object. Use the calendar to construct an appropriate millisecond
   * value for the Timestamp, if the underlying database does not store
   * timezone information.
   *
   * @param columnIndex the first column is 1, the second is 2, ...
   * @param cal the calendar to use in constructing the timestamp
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Timestamp getTimestamp(int columnIndex, Calendar cal) throws SQLException {
    check_close();
    return rs.getTimestamp(columnIndex, cal);
  }

  /**
   * Get the value of a column in the current row as a java.sql.Timestamp
   * object. Use the calendar to construct an appropriate millisecond
   * value for the Timestamp, if the underlying database does not store
   * timezone information.
   *
   * @param columnName is the SQL name of the column
   * @param cal the calendar to use in constructing the timestamp
   * @return the column value; if the value is SQL NULL, the result is null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized Timestamp getTimestamp(String columnName, Calendar cal) throws SQLException {
    check_close();
    return rs.getTimestamp(columnName, cal);
  }

    //-------------------------- JDBC 3.0 ----------------------------------------
    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a <code>java.net.URL</code>
     * object in the Java programming language.
     *
     * @param columnIndex the index of the column 1 is the first, 2 is the second,...
     * @return the column value as a <code>java.net.URL</code> object;
     * if the value is SQL <code>NULL</code>,
     * the value returned is <code>null</code> in the Java programming language
     * @exception SQLException if a database access error occurs,
     *            or if a URL is malformed
     * @since 1.4
     */
  public synchronized java.net.URL getURL(int columnIndex)
          throws SQLException
  {
    check_close();
    return rs.getURL(columnIndex);
  }

    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a <code>java.net.URL</code>
     * object in the Java programming language.
     *
     * @param columnName the SQL name of the column
     * @return the column value as a <code>java.net.URL</code> object;
     * if the value is SQL <code>NULL</code>,
     * the value returned is <code>null</code> in the Java programming language
     * @exception SQLException if a database access error occurs
     *            or if a URL is malformed
     * @since 1.4
     */
  public synchronized java.net.URL getURL(String columnName)
          throws SQLException
  {
    check_close();
    return rs.getURL(columnName);
  }

    /**
     * Updates the designated column with a <code>java.sql.Ref</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
  public synchronized void updateRef(int columnIndex, java.sql.Ref x) throws SQLException {
    check_close();
    rs.updateRef(columnIndex, x);
  }

    /**
     * Updates the designated column with a <code>java.sql.Ref</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnName the name of the column
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
  public synchronized void updateRef(String columnName, java.sql.Ref x) throws SQLException {
    check_close();
    rs.updateRef(columnName, x);
  }

    /**
     * Updates the designated column with a <code>java.sql.Blob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
  public synchronized void updateBlob(int columnIndex, java.sql.Blob x) throws SQLException {
    check_close();
    rs.updateBlob(columnIndex, x);
  }

    /**
     * Updates the designated column with a <code>java.sql.Blob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnName the name of the column
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
  public synchronized void updateBlob(String columnName, java.sql.Blob x) throws SQLException {
    check_close();
    rs.updateBlob(columnName, x);
  }

    /**
     * Updates the designated column with a <code>java.sql.Clob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
  public synchronized void updateClob(int columnIndex, java.sql.Clob x) throws SQLException {
    check_close();
    rs.updateClob(columnIndex, x);
  }

    /**
     * Updates the designated column with a <code>java.sql.Clob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnName the name of the column
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
  public synchronized void updateClob(String columnName, java.sql.Clob x) throws SQLException {
    check_close();
    rs.updateClob(columnName, x);
  }

    /**
     * Updates the designated column with a <code>java.sql.Array</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
  public synchronized void updateArray(int columnIndex, java.sql.Array x) throws SQLException {
    check_close();
    rs.updateArray(columnIndex, x);
  }

    /**
     * Updates the designated column with a <code>java.sql.Array</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnName the name of the column
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
  public synchronized void updateArray(String columnName, java.sql.Array x) throws SQLException {
    check_close();
    rs.updateArray(columnName, x);
  }

    //------------------------- JDBC 4.0 -----------------------------------

    /**
     * Retrieves the value of the designated column in the current row of this
     * <code>ResultSet</code> object as a <code>java.sql.RowId</code> object in the Java
     * programming language.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @return the column value; if the value is a SQL <code>NULL</code> the
     *     value returned is <code>null</code>
     * @throws SQLException if the columnIndex is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized RowId getRowId(int columnIndex) throws SQLException
  {
    check_close();
    return rs.getRowId(columnIndex);
  }

    /**
     * Retrieves the value of the designated column in the current row of this
     * <code>ResultSet</code> object as a <code>java.sql.RowId</code> object in the Java
     * programming language.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @return the column value ; if the value is a SQL <code>NULL</code> the
     *     value returned is <code>null</code>
     * @throws SQLException if the columnLabel is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized RowId getRowId(String columnLabel) throws SQLException
  {
    check_close();
    return rs.getRowId(columnLabel);
  }

    /**
     * Updates the designated column with a <code>RowId</code> value. The updater
     * methods are used to update column values in the current row or the insert
     * row. The updater methods do not update the underlying database; instead
     * the <code>updateRow</code> or <code>insertRow</code> methods are called
     * to update the database.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param x the column value
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateRowId(int columnIndex, RowId x) throws SQLException
  {
    check_close();
    rs.updateRowId(columnIndex, x);
  }

    /**
     * Updates the designated column with a <code>RowId</code> value. The updater
     * methods are used to update column values in the current row or the insert
     * row. The updater methods do not update the underlying database; instead
     * the <code>updateRow</code> or <code>insertRow</code> methods are called
     * to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param x the column value
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateRowId(String columnLabel, RowId x) throws SQLException
  {
    check_close();
    rs.updateRowId(columnLabel, x);
  }

    /**
     * Retrieves the holdability of this <code>ResultSet</code> object
     * @return  either <code>ResultSet.HOLD_CURSORS_OVER_COMMIT</code> or <code>ResultSet.CLOSE_CURSORS_AT_COMMIT</code>
     * @throws SQLException if a database access error occurs
     * or this method is called on a closed result set
     * @since 1.6
     */
  public synchronized int getHoldability() throws SQLException
  {
    check_close();
    return rs.getHoldability();
  }

    /**
     * Retrieves whether this <code>ResultSet</code> object has been closed. A <code>ResultSet</code> is closed if the
     * method close has been called on it, or if it is automatically closed.
     *
     * @return true if this <code>ResultSet</code> object is closed; false if it is still open
     * @throws SQLException if a database access error occurs
     * @since 1.6
     */
  public synchronized boolean isClosed() throws SQLException
  {
    if (rs != null)
      return rs.isClosed();
    else
      return true;
  }

    /**
     * Updates the designated column with a <code>String</code> value.
     * It is intended for use when updating <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param nString the value for the column to be updated
     * @throws SQLException if the columnIndex is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or if a database access error occurs
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNString(int columnIndex, String nString) throws SQLException
  {
    check_close();
    rs.updateNString(columnIndex, nString);
  }

    /**
     * Updates the designated column with a <code>String</code> value.
     * It is intended for use when updating <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param nString the value for the column to be updated
     * @throws SQLException if the columnLabel is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     * the result set concurrency is <CODE>CONCUR_READ_ONLY</code>
     *  or if a database access error occurs
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNString(String columnLabel, String nString) throws SQLException
  {
    check_close();
    rs.updateNString(columnLabel, nString);
  }

    /**
     * Updates the designated column with a <code>java.sql.NClob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param nClob the value for the column to be updated
     * @throws SQLException if the columnIndex is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     * if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNClob(int columnIndex, NClob nClob) throws SQLException
  {
    check_close();
    rs.updateNClob(columnIndex, nClob);
  }

    /**
     * Updates the designated column with a <code>java.sql.NClob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param nClob the value for the column to be updated
     * @throws SQLException if the columnLabel is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     *  if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNClob(String columnLabel, NClob nClob) throws SQLException
  {
    check_close();
    rs.updateNClob(columnLabel, nClob);
  }

    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a <code>NClob</code> object
     * in the Java programming language.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @return a <code>NClob</code> object representing the SQL
     *         <code>NCLOB</code> value in the specified column
     * @exception SQLException if the columnIndex is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set
     * or if a database access error occurs
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized NClob getNClob(int columnIndex) throws SQLException
  {
    check_close();
    return rs.getNClob(columnIndex);
  }

  /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a <code>NClob</code> object
     * in the Java programming language.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @return a <code>NClob</code> object representing the SQL <code>NCLOB</code>
     * value in the specified column
     * @exception SQLException if the columnLabel is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set
     * or if a database access error occurs
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized NClob getNClob(String columnLabel) throws SQLException
  {
    check_close();
    return rs.getNClob(columnLabel);
  }

    /**
     * Retrieves the value of the designated column in  the current row of
     *  this <code>ResultSet</code> as a
     * <code>java.sql.SQLXML</code> object in the Java programming language.
     * @param columnIndex the first column is 1, the second is 2, ...
     * @return a <code>SQLXML</code> object that maps an <code>SQL XML</code> value
     * @throws SQLException if the columnIndex is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized SQLXML getSQLXML(int columnIndex) throws SQLException
  {
    check_close();
    return rs.getSQLXML(columnIndex);
  }

    /**
     * Retrieves the value of the designated column in  the current row of
     *  this <code>ResultSet</code> as a
     * <code>java.sql.SQLXML</code> object in the Java programming language.
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @return a <code>SQLXML</code> object that maps an <code>SQL XML</code> value
     * @throws SQLException if the columnLabel is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized SQLXML getSQLXML(String columnLabel) throws SQLException
  {
    check_close();
    return rs.getSQLXML(columnLabel);
  }

    /**
     * Updates the designated column with a <code>java.sql.SQLXML</code> value.
     * The updater
     * methods are used to update column values in the current row or the insert
     * row. The updater methods do not update the underlying database; instead
     * the <code>updateRow</code> or <code>insertRow</code> methods are called
     * to update the database.
     * <p>
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param xmlObject the value for the column to be updated
     * @throws SQLException if the columnIndex is not valid;
     * if a database access error occurs; this method
     *  is called on a closed result set;
     * the <code>java.xml.transform.Result</code>,
     *  <code>Writer</code> or <code>OutputStream</code> has not been closed
     * for the <code>SQLXML</code> object;
     *  if there is an error processing the XML value or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>.  The <code>getCause</code> method
     *  of the exception may provide a more detailed exception, for example, if the
     *  stream does not contain valid XML.
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateSQLXML(int columnIndex, SQLXML xmlObject) throws SQLException
  {
    check_close();
    rs.updateSQLXML(columnIndex, xmlObject);
  }

    /**
     * Updates the designated column with a <code>java.sql.SQLXML</code> value.
     * The updater
     * methods are used to update column values in the current row or the insert
     * row. The updater methods do not update the underlying database; instead
     * the <code>updateRow</code> or <code>insertRow</code> methods are called
     * to update the database.
     * <p>
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param xmlObject the column value
     * @throws SQLException if the columnLabel is not valid;
     * if a database access error occurs; this method
     *  is called on a closed result set;
     * the <code>java.xml.transform.Result</code>,
     *  <code>Writer</code> or <code>OutputStream</code> has not been closed
     * for the <code>SQLXML</code> object;
     *  if there is an error processing the XML value or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>.  The <code>getCause</code> method
     *  of the exception may provide a more detailed exception, for example, if the
     *  stream does not contain valid XML.
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateSQLXML(String columnLabel, SQLXML xmlObject) throws SQLException
  {
    check_close();
    rs.updateSQLXML(columnLabel, xmlObject);
  }

    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as
     * a <code>String</code> in the Java programming language.
     * It is intended for use when
     * accessing  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @return the column value; if the value is SQL <code>NULL</code>, the
     * value returned is <code>null</code>
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized String getNString(int columnIndex) throws SQLException
  {
    check_close();
    return rs.getNString(columnIndex);
  }


    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as
     * a <code>String</code> in the Java programming language.
     * It is intended for use when
     * accessing  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @return the column value; if the value is SQL <code>NULL</code>, the
     * value returned is <code>null</code>
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized String getNString(String columnLabel) throws SQLException
  {
    check_close();
    return rs.getNString(columnLabel);
  }


    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a
     * <code>java.io.Reader</code> object.
     * It is intended for use when
     * accessing  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     *
     * @return a <code>java.io.Reader</code> object that contains the column
     * value; if the value is SQL <code>NULL</code>, the value returned is
     * <code>null</code> in the Java programming language.
     * @param columnIndex the first column is 1, the second is 2, ...
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized java.io.Reader getNCharacterStream(int columnIndex) throws SQLException
  {
    check_close();
    return rs.getNCharacterStream(columnIndex);
  }

    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a
     * <code>java.io.Reader</code> object.
     * It is intended for use when
     * accessing  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @return a <code>java.io.Reader</code> object that contains the column
     * value; if the value is SQL <code>NULL</code>, the value returned is
     * <code>null</code> in the Java programming language
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized java.io.Reader getNCharacterStream(String columnLabel) throws SQLException
  {
    check_close();
    return rs.getNCharacterStream(columnLabel);
  }

    /**
     * Updates the designated column with a character stream value, which will have
     * the specified number of bytes.   The
     * driver does the necessary conversion from Java character format to
     * the national character set in the database.
     * It is intended for use when
     * updating  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code> or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNCharacterStream(int columnIndex,
			java.io.Reader x, long length) throws SQLException
  {
    check_close();
    rs.updateNCharacterStream(columnIndex, x, length);
  }

    /**
     * Updates the designated column with a character stream value, which will have
     * the specified number of bytes.  The
     * driver does the necessary conversion from Java character format to
     * the national character set in the database.
     * It is intended for use when
     * updating  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader the <code>java.io.Reader</code> object containing
     *        the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code> or this method is called on a closed result set
      * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNCharacterStream(String columnLabel,
			     java.io.Reader reader,
			     long length) throws SQLException
  {
    check_close();
    rs.updateNCharacterStream(columnLabel, reader, length);
  }

    /**
     * Updates the designated column with an ascii stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateAsciiStream(int columnIndex, java.io.InputStream x,
  			long length) throws SQLException
  {
    check_close();
    rs.updateAsciiStream(columnIndex, x, length);
  }

    /**
     * Updates the designated column with a binary stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateBinaryStream(int columnIndex, java.io.InputStream x,
			    long length) throws SQLException
  {
    check_close();
    rs.updateBinaryStream(columnIndex, x, length);
  }

    /**
     * Updates the designated column with a character stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateCharacterStream(int columnIndex, java.io.Reader x,
			     long length) throws SQLException
  {
    check_close();
    rs.updateCharacterStream(columnIndex, x, length);
  }

    /**
     * Updates the designated column with an ascii stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateAsciiStream(String columnLabel, java.io.InputStream x,
			   long length) throws SQLException
  {
    check_close();
    rs.updateAsciiStream(columnLabel, x, length);
  }

    /**
     * Updates the designated column with a binary stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateBinaryStream(String columnLabel, java.io.InputStream x,
			    long length) throws SQLException
  {
    check_close();
    rs.updateBinaryStream(columnLabel, x, length);
  }

    /**
     * Updates the designated column with a character stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader the <code>java.io.Reader</code> object containing
     *        the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateCharacterStream(String columnLabel, java.io.Reader reader,
			     long length) throws SQLException
  {
    check_close();
    rs.updateCharacterStream(columnLabel, reader, length);
  }

    /**
     * Updates the designated column using the given input stream, which
     * will have the specified number of bytes.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @param length the number of bytes in the parameter data.
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateBlob(int columnIndex, InputStream inputStream, long length) throws SQLException
  {
    check_close();
    rs.updateBlob(columnIndex, inputStream, length);
  }

    /**
     * Updates the designated column using the given input stream, which
     * will have the specified number of bytes.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @param length the number of bytes in the parameter data.
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateBlob(String columnLabel, InputStream inputStream, long length) throws SQLException
  {
    check_close();
    rs.updateBlob(columnLabel, inputStream, length);
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object, which is the given number of characters long.
     * When a very large UNICODE value is input to a <code>LONGVARCHAR</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.Reader</code> object. The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateClob(int columnIndex,  Reader reader, long length) throws SQLException
  {
    check_close();
    rs.updateClob(columnIndex, reader, length);
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object, which is the given number of characters long.
     * When a very large UNICODE value is input to a <code>LONGVARCHAR</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.Reader</code> object.  The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateClob(String columnLabel,  Reader reader, long length) throws SQLException
  {
    check_close();
    rs.updateClob(columnLabel, reader, length);
  }

   /**
     * Updates the designated column using the given <code>Reader</code>
     * object, which is the given number of characters long.
     * When a very large UNICODE value is input to a <code>LONGVARCHAR</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.Reader</code> object. The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @throws SQLException if the columnIndex is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set,
     * if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNClob(int columnIndex,  Reader reader, long length) throws SQLException
  {
    check_close();
    rs.updateNClob(columnIndex, reader, length);
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object, which is the given number of characters long.
     * When a very large UNICODE value is input to a <code>LONGVARCHAR</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.Reader</code> object. The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @throws SQLException if the columnLabel is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     *  if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNClob(String columnLabel,  Reader reader, long length) throws SQLException
  {
    check_close();
    rs.updateNClob(columnLabel, reader, length);
  }

    /**
     * Updates the designated column with a character stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.  The
     * driver does the necessary conversion from Java character format to
     * the national character set in the database.
     * It is intended for use when
     * updating  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateNCharacterStream</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code> or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNCharacterStream(int columnIndex, java.io.Reader x) throws SQLException
  {
    check_close();
    rs.updateNCharacterStream(columnIndex, x);
  }

    /**
     * Updates the designated column with a character stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.  The
     * driver does the necessary conversion from Java character format to
     * the national character set in the database.
     * It is intended for use when
     * updating  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateNCharacterStream</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader the <code>java.io.Reader</code> object containing
     *        the new column value
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code> or this method is called on a closed result set
      * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNCharacterStream(String columnLabel, java.io.Reader reader) throws SQLException
  {
    check_close();
    rs.updateNCharacterStream(columnLabel, reader);
  }

    /**
     * Updates the designated column with an ascii stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateAsciiStream</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateAsciiStream(int columnIndex, java.io.InputStream x) throws SQLException
  {
    check_close();
    rs.updateAsciiStream(columnIndex, x);
  }

    /**
     * Updates the designated column with a binary stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateBinaryStream</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateBinaryStream(int columnIndex, java.io.InputStream x) throws SQLException
  {
    check_close();
    rs.updateBinaryStream(columnIndex, x);
  }

    /**
     * Updates the designated column with a character stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateCharacterStream</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateCharacterStream(int columnIndex, java.io.Reader x) throws SQLException
  {
    check_close();
    rs.updateCharacterStream(columnIndex, x);
  }

    /**
     * Updates the designated column with an ascii stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateAsciiStream</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param x the new column value
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateAsciiStream(String columnLabel, java.io.InputStream x) throws SQLException
  {
    check_close();
    rs.updateAsciiStream(columnLabel, x);
  }

    /**
     * Updates the designated column with a binary stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateBinaryStream</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param x the new column value
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateBinaryStream(String columnLabel, java.io.InputStream x) throws SQLException
  {
    check_close();
    rs.updateBinaryStream(columnLabel, x);
  }

    /**
     * Updates the designated column with a character stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateCharacterStream</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader the <code>java.io.Reader</code> object containing
     *        the new column value
     * @exception SQLException if the columnLabel is not valid; if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateCharacterStream(String columnLabel, java.io.Reader reader) throws SQLException
  {
    check_close();
    rs.updateCharacterStream(columnLabel, reader);
  }

    /**
     * Updates the designated column using the given input stream. The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateBlob</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @exception SQLException if the columnIndex is not valid; if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateBlob(int columnIndex, InputStream inputStream) throws SQLException
  {
    check_close();
    rs.updateBlob(columnIndex, inputStream);
  }

    /**
     * Updates the designated column using the given input stream. The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     *   <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateBlob</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @exception SQLException if the columnLabel is not valid; if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateBlob(String columnLabel, InputStream inputStream) throws SQLException
  {
    check_close();
    rs.updateBlob(columnLabel, inputStream);
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object.
     *  The data will be read from the stream
     * as needed until end-of-stream is reached.  The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     *   <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateClob</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param reader An object that contains the data to set the parameter value to.
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateClob(int columnIndex,  Reader reader) throws SQLException
  {
    check_close();
    rs.updateClob(columnIndex, reader);
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object.
     *  The data will be read from the stream
     * as needed until end-of-stream is reached.  The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateClob</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader An object that contains the data to set the parameter value to.
     * @exception SQLException if the columnLabel is not valid; if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateClob(String columnLabel,  Reader reader) throws SQLException
  {
    check_close();
    rs.updateClob(columnLabel, reader);
  }

   /**
     * Updates the designated column using the given <code>Reader</code>
     *
     * The data will be read from the stream
     * as needed until end-of-stream is reached.  The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateNClob</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param reader An object that contains the data to set the parameter value to.
     * @throws SQLException if the columnIndex is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set,
     * if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNClob(int columnIndex,  Reader reader) throws SQLException
  {
    check_close();
    rs.updateNClob(columnIndex, reader);
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.  The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateNClob</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader An object that contains the data to set the parameter value to.
     * @throws SQLException if the columnLabel is not valid; if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     *  if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNClob(String columnLabel,  Reader reader) throws SQLException
  {
    check_close();
    rs.updateNClob(columnLabel, reader);
  }


    /**
     * Returns an object that implements the given interface to allow access to
     * non-standard methods, or standard methods not exposed by the proxy.
     *
     * If the receiver implements the interface then the result is the receiver
     * or a proxy for the receiver. If the receiver is a wrapper
     * and the wrapped object implements the interface then the result is the
     * wrapped object or a proxy for the wrapped object. Otherwise return the
     * the result of calling <code>unwrap</code> recursively on the wrapped object
     * or a proxy for that result. If the receiver is not a
     * wrapper and does not implement the interface, then an <code>SQLException</code> is thrown.
     *
     * @param iface A Class defining an interface that the result must implement.
     * @return an object that implements the interface. May be a proxy for the actual implementing object.
     * @throws java.sql.SQLException If no object found that implements the interface
     * @since 1.6
     */
  public synchronized <T> T unwrap(java.lang.Class<T> iface) throws java.sql.SQLException
  {
    check_close();
    return rs.unwrap(iface);
  }

    /**
     * Returns true if this either implements the interface argument or is directly or indirectly a wrapper
     * for an object that does. Returns false otherwise. If this implements the interface then return true,
     * else if this is a wrapper then return the result of recursively calling <code>isWrapperFor</code> on the wrapped
     * object. If this does not implement the interface and is not a wrapper, return false.
     * This method should be implemented as a low-cost operation compared to <code>unwrap</code> so that
     * callers can use this method to avoid expensive <code>unwrap</code> calls that may fail. If this method
     * returns true then calling <code>unwrap</code> with the same argument should succeed.
     *
     * @param iface a Class defining an interface.
     * @return true if this implements the interface or directly or indirectly wraps an object that does.
     * @throws java.sql.SQLException  if an error occurs while determining whether this is a wrapper
     * for an object with the given interface.
     * @since 1.6
     */
  public synchronized boolean isWrapperFor(java.lang.Class<?> iface) throws java.sql.SQLException
  {
    check_close();
    return rs.isWrapperFor(iface);
  }

#if JDK_VER >= 17

    //------------------------- JDBC 4.1 -----------------------------------


    /**
     *<p>Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object and will convert from the
     * SQL type of the column to the requested Java data type, if the
     * conversion is supported. If the conversion is not
     * supported  or null is specified for the type, a
     * <code>SQLException</code> is thrown.
     *<p>
     * At a minimum, an implementation must support the conversions defined in
     * Appendix B, Table B-3 and conversion of appropriate user defined SQL
     * types to a Java type which implements {@code SQLData}, or {@code Struct}.
     * Additional conversions may be supported and are vendor defined.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param type Class representing the Java data type to convert the designated
     * column to.
     * @return an instance of {@code type} holding the column value
     * @throws SQLException if conversion is not supported, type is null or
     *         another error occurs. The getCause() method of the
     * exception may provide a more detailed exception, for example, if
     * a conversion error occurs
     * @throws SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.7
     */
  public <T> T getObject(int columnIndex, Class<T> type) throws SQLException
  {
    if (type == null) {
      throw new SQLException("Type parameter cannot be null", "S1009");
    }

    if (type.equals(String.class)) {
      return (T) getString(columnIndex);
    } else if (type.equals(BigDecimal.class)) {
      return (T) getBigDecimal(columnIndex);
    } else if (type.equals(Boolean.class) || type.equals(Boolean.TYPE)) {
      return (T) Boolean.valueOf(getBoolean(columnIndex));
    } else if (type.equals(Integer.class) || type.equals(Integer.TYPE)) {
      return (T) Integer.valueOf(getInt(columnIndex));
    } else if (type.equals(Long.class) || type.equals(Long.TYPE)) {
      return (T) Long.valueOf(getLong(columnIndex));
    } else if (type.equals(Float.class) || type.equals(Float.TYPE)) {
      return (T) Float.valueOf(getFloat(columnIndex));
    } else if (type.equals(Double.class) || type.equals(Double.TYPE)) {
      return (T) Double.valueOf(getDouble(columnIndex));
    } else if (type.equals(byte[].class)) {
      return (T) getBytes(columnIndex);
    } else if (type.equals(java.sql.Date.class)) {
      return (T) getDate(columnIndex);
    } else if (type.equals(Time.class)) {
      return (T) getTime(columnIndex);
    } else if (type.equals(Timestamp.class)) {
      return (T) getTimestamp(columnIndex);
    } else if (type.equals(Clob.class)) {
      return (T) getClob(columnIndex);
    } else if (type.equals(Blob.class)) {
      return (T) getBlob(columnIndex);
    } else if (type.equals(Array.class)) {
      return (T) getArray(columnIndex);
    } else if (type.equals(Ref.class)) {
      return (T) getRef(columnIndex);
    } else if (type.equals(java.net.URL.class)) {
      return (T) getURL(columnIndex);
//		} else if (type.equals(Struct.class)) {
//
//			}
//		} else if (type.equals(RowId.class)) {
//
//		} else if (type.equals(NClob.class)) {
//
//		} else if (type.equals(SQLXML.class)) {

    } else {
      try {
        return (T) getObject(columnIndex);
      } catch (ClassCastException cce) {
         throw new SQLException ("Conversion not supported for type " + type.getName(),
                    "S1009");
      }
    }
  }


    /**
     *<p>Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object and will convert from the
     * SQL type of the column to the requested Java data type, if the
     * conversion is supported. If the conversion is not
     * supported  or null is specified for the type, a
     * <code>SQLException</code> is thrown.
     *<p>
     * At a minimum, an implementation must support the conversions defined in
     * Appendix B, Table B-3 and conversion of appropriate user defined SQL
     * types to a Java type which implements {@code SQLData}, or {@code Struct}.
     * Additional conversions may be supported and are vendor defined.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.
     * If the SQL AS clause was not specified, then the label is the name
     * of the column
     * @param type Class representing the Java data type to convert the designated
     * column to.
     * @return an instance of {@code type} holding the column value
     * @throws SQLException if conversion is not supported, type is null or
     *         another error occurs. The getCause() method of the
     * exception may provide a more detailed exception, for example, if
     * a conversion error occurs
     * @throws SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.7
     */
  public <T> T getObject(String columnLabel, Class<T> type) throws SQLException
  {
    return getObject(findColumn(columnLabel), type);
  }
#endif



  private void check_close()  throws SQLException
  {
    if (rs == null)
      throw OPLMessage_x.makeException (OPLMessage_x.errx_ResultSet_is_closed);
  }
}
