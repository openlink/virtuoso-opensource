/*
 *  BaseRowSet.java
 *
 *  $Id$
 *
 *
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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

package virtuoso.javax;

import java.util.ArrayList;
import java.util.LinkedList;
import java.util.Map;
import java.util.Calendar;
import java.util.Iterator;
import java.io.InputStream;
import java.io.Reader;
import java.io.Serializable;
import java.math.BigDecimal;
import javax.sql.*;
import java.sql.*;


public abstract class BaseRowSet implements RowSet, Serializable {

    private static final long serialVersionUID = 5374661472998522423L;

    protected static final int ev_CursorMoved = 1;
    protected static final int ev_RowChanged  = 2;
    protected static final int ev_RowSetChanged  = 3;

    private LinkedList listeners;
    private String command;
    private String url;
    private String dataSource;
    private transient String username;
    private transient String password;
    private ArrayList params;

    private int rsType = ResultSet.TYPE_SCROLL_INSENSITIVE;
    private int rsConcurrency = ResultSet.CONCUR_UPDATABLE;
    private int queryTimeout = 0;
    private int maxRows = 0;
    private int maxFieldSize = 0;
    private boolean readOnly = true;
    private boolean escapeProcessing = true;
    private int txn_isolation = Connection.TRANSACTION_READ_COMMITTED;
    private int fetchDir = ResultSet.FETCH_FORWARD;
    private int fetchSize = 0;
    private Map map = null;



  public BaseRowSet() {
    listeners = new LinkedList();
    params = new ArrayList();
  }


  public void close() throws SQLException{
    clearParameters();
    listeners.clear();
  }

  /**
   * RowSet listener registration.  Listeners are notified
   * when an event occurs.
   *
   * @param listener an event listener
   */
  public void addRowSetListener(RowSetListener rowsetlistener) {
    synchronized(listeners) {
        listeners.add(rowsetlistener);
    }
  }

  /**
   * RowSet listener deregistration.
   *
   * @param listener an event listener
   */
  public void removeRowSetListener(RowSetListener rowsetlistener) {
    synchronized(listeners) {
        listeners.remove(rowsetlistener);
    }
  }


  /**
   * <P>In general, parameter values remain in force for repeated use of a
   * RowSet. Setting a parameter value automatically clears its
   * previous value.  However, in some cases it is useful to immediately
   * release the resources used by the current parameter values; this can
   * be done by calling clearParameters.
   *
   * @exception SQLException if a database-access error occurs.
   */
  public void clearParameters() throws SQLException {
    params.clear();
  }

  /**
   * Get the rowset's command property.
   *
   * The command property contains a command string that can be executed to
   * fill the rowset with data.  The default value is null.
   *
   * @return the command string, may be null
   */
  public String getCommand() {
    return command;
  }

  /**
   * Get the rowset concurrency.
   *
   * @exception SQLException if a database-access error occurs.
   */
  public int getConcurrency() throws SQLException {
    return rsConcurrency;
  }

  /**
   * The JNDI name that identifies a JDBC data source.  Users should set
   * either the url or data source name properties.  The most recent
   * property set is used to get a connection.
   *
   * @return a data source name
   */
  public String getDataSourceName() {
    return dataSource;
  }

  /**
   * If escape scanning is on (the default), the driver will do
   * escape substitution before sending the SQL to the database.
   *
   * @return true if enabled; false if disabled
   * @exception SQLException if a database-access error occurs.
   */
  public boolean getEscapeProcessing() throws SQLException {
    return escapeProcessing;
  }

  /**
   * Determine the fetch direction.
   *
   * @return the default fetch direction
   * @exception SQLException if a database-access error occurs
   */
  public int getFetchDirection() throws SQLException {
    return fetchDir;
  }

  /**
   * Determine the default fetch size.
   */
  public int getFetchSize() throws SQLException {
    return fetchSize;
  }

  /**
   * The maxFieldSize limit (in bytes) is the maximum amount of data
   * returned for any column value; it only applies to BINARY,
   * VARBINARY, LONGVARBINARY, CHAR, VARCHAR, and LONGVARCHAR
   * columns.  If the limit is exceeded, the excess data is silently
   * discarded.
   *
   * @return the current max column size limit; zero means unlimited
   * @exception SQLException if a database-access error occurs.
   */
  public int getMaxFieldSize() throws SQLException {
    return maxFieldSize;
  }

  /**
   * The maxRows limit is the maximum number of rows that a
   * RowSet can contain.  If the limit is exceeded, the excess
   * rows are silently dropped.
   *
   * @return the current max row limit; zero means unlimited
   * @exception SQLException if a database-access error occurs.
   */
  public int getMaxRows() throws SQLException {
    return maxRows;
  }

  /**
   * Get the parameters that were set on the rowset.
   *
   * @return an array of parameters
   * @exception SQLException if a database-access error occurs.
   */
  public Object[] getParams() throws SQLException {
    return params.toArray();
  }

  /**
   * The password used to create a database connection.  The password
   * property is set at runtime before calling execute().  It is
   * not usually part of the serialized state of a rowset object.
   *
   * @return a password
   */
  public String getPassword() {
    return password;
  }

  /**
   * The queryTimeout limit is the number of seconds the driver will
   * wait for a Statement to execute. If the limit is exceeded, a
   * SQLException is thrown.
   *
   * @return the current query timeout limit in seconds; zero means
   * unlimited
   * @exception SQLException if a database-access error occurs.
   */
  public int getQueryTimeout() throws SQLException {
    return queryTimeout;
  }

  /**
   * The transaction isolation property contains the JDBC transaction
   * isolation level used.
   *
   * @return the transaction isolation level
   */
  public int getTransactionIsolation() {
    return txn_isolation;
  }

  /**
   * Return the type of this result set.
   *
   * @return TYPE_FORWARD_ONLY, TYPE_SCROLL_INSENSITIVE, or
       * TYPE_SCROLL_SENSITIVE
   * @exception SQLException if a database-access error occurs
   */
  public int getType() throws SQLException {
    return rsType;
  }

  /**
   * Get the type-map object associated with this rowset.
   * By default, the map returned is empty.
   *
   * @return a map object
   * @exception SQLException if a database-access error occurs.
   */
  public Map getTypeMap() throws SQLException{
    return map;
  }

  /**
   * Get the url used to create a JDBC connection. The default value
   * is null.
   *
   * @return a string url
   * @exception SQLException if a database-access error occurs.
   */
  public String getUrl() throws SQLException {
    return url;
  }

  /**
   * The username used to create a database connection.  The username
   * property is set at runtime before calling execute().  It is
   * not usually part of the serialized state of a rowset object.
   *
   * @return a user name
   */
  public String getUsername() {
    return username;
  }

  /**
   * A rowset may be read-only.  Attempts to update a
   * read-only rowset will result in an SQLException being thrown.
   * Rowsets are updateable, by default, if updates are possible.
   *
   * @return true if updatable, false otherwise
   */
  public boolean isReadOnly() {
    return readOnly;
  }



  /**
   * Set an Array parameter.
   *
   * @param i the first parameter is 1, the second is 2, ...
   * @param x an object representing an SQL array
   */
  public synchronized void setArray(int parameterIndex, Array x)
      throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jObject;
  }

  /**
   * When a very large ASCII value is input to a LONGVARCHAR
   * parameter, it may be more practical to send it via a
   * java.io.InputStream. JDBC will read the data from the stream
   * as needed, until it reaches end-of-file.
   *
   * <P><B>Note:</B> This stream object can either be a standard
   * Java stream object or your own subclass that implements the
   * standard interface.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the java input stream which contains the ASCII parameter value
   * @param length the number of bytes in the stream
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setAsciiStream(int parameterIndex, InputStream x, int length)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jAsciiStream;
    param.length = length;
  }

  /**
   * Set a parameter to a java.lang.BigDecimal value.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the parameter value
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setBigDecimal(int parameterIndex, BigDecimal x)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jObject;
  }

  /**
   * When a very large binary value is input to a LONGVARBINARY
   * parameter, it may be more practical to send it via a
   * java.io.InputStream. JDBC will read the data from the stream
   * as needed, until it reaches end-of-file.
   *
   * <P><B>Note:</B> This stream object can either be a standard
   * Java stream object or your own subclass that implements the
   * standard interface.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the java input stream which contains the binary parameter value
   * @param length the number of bytes in the stream
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setBinaryStream(int parameterIndex, InputStream x, int length)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jBinaryStream;
    param.length = length;
  }

  /**
   * Set a BLOB parameter.
   *
   * @param i the first parameter is 1, the second is 2, ...
   * @param x an object representing a BLOB
   */
  public synchronized void setBlob(int parameterIndex, Blob x)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jObject;
  }

  /**
   * Set a parameter to a Java boolean value.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the parameter value
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setBoolean(int parameterIndex, boolean x)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = new Boolean(x);
    param.jType = Parameter.jObject;
  }

  /**
   * Set a parameter to a Java byte value.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the parameter value
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setByte(int parameterIndex, byte x)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = new Byte(x);
    param.jType = Parameter.jObject;
  }

  /**
   * Set a parameter to a Java array of bytes.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the parameter value
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setBytes(int parameterIndex, byte[] x)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jObject;
  }

  /**
   * When a very large UNICODE value is input to a LONGVARCHAR
   * parameter, it may be more practical to send it via a
   * java.io.Reader. JDBC will read the data from the stream
   * as needed, until it reaches end-of-file.
   *
   * <P><B>Note:</B> This stream object can either be a standard
   * Java stream object or your own subclass that implements the
   * standard interface.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the java reader which contains the UNICODE data
   * @param length the number of characters in the stream
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setCharacterStream(int parameterIndex, Reader x, int length)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jCharacterStream;
    param.length = length;
  }

  /**
   * Set a CLOB parameter.
   *
   * @param i the first parameter is 1, the second is 2, ...
   * @param x an object representing a CLOB
   */
  public synchronized void setClob(int parameterIndex, Clob x)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jObject;
  }

  /**
   * Set a parameter to a java.sql.Date value.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the parameter value
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setDate(int parameterIndex, Date x)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jObject;
  }

  /**
   * Set a parameter to a java.sql.Date value.  The driver converts this
   * to a SQL DATE value when it sends it to the database.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the parameter value
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setDate(int parameterIndex, Date x, Calendar cal)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jDateWithCalendar;
    param.cal = cal;
  }

  /**
   * Set a parameter to a Java double value.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the parameter value
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setDouble(int parameterIndex, double x)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = new Double(x);
    param.jType = Parameter.jObject;
  }

  /**
   * Set a parameter to a Java float value.  The driver converts this
   * to a SQL FLOAT value when it sends it to the database.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the parameter value
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setFloat(int parameterIndex, float x)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = new Float(x);
    param.jType = Parameter.jObject;
  }

  /**
   * Set a parameter to a Java int value.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the parameter value
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setInt(int parameterIndex, int x)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = new Integer(x);
    param.jType = Parameter.jObject;
  }

  /**
   * Set a parameter to a Java long value.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the parameter value
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setLong(int parameterIndex, long x)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = new Long(x);
    param.jType = Parameter.jObject;
  }

  /**
   * Set a REF(&lt;structured-type&gt;) parameter.
   *
   * @param i the first parameter is 1, the second is 2, ...
   * @param x an object representing data of an SQL REF Type
   */
  public synchronized void setRef(int parameterIndex, Ref x)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jObject;
  }

  /**
   * Set a parameter to a Java short value.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the parameter value
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setShort(int parameterIndex, short x)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = new Short(x);
    param.jType = Parameter.jObject;
  }

  /**
   * Set a parameter to a Java String value.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the parameter value
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setString(int parameterIndex, String x)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jObject;
  }

  /**
   * Set a parameter to a java.sql.Time value.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the parameter value
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setTime(int parameterIndex, Time x)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jObject;
  }

  /**
   * Set a parameter to a java.sql.Time value.  The driver converts this
   * to a SQL TIME value when it sends it to the database.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the parameter value
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setTime(int parameterIndex, Time x, Calendar cal)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jTimeWithCalendar;
    param.cal = cal;
  }

  /**
   * Set a parameter to a java.sql.Timestamp value.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the parameter value
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setTimestamp(int parameterIndex, Timestamp x)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jObject;
  }

  /**
   * Set a parameter to a java.sql.Timestamp value.  The driver
   * converts this to a SQL TIMESTAMP value when it sends it to the
   * database.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the parameter value
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setTimestamp(int parameterIndex, Timestamp x, Calendar cal)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jObject;
    param.cal = cal;
  }

  /**
   * When a very large UNICODE value is input to a LONGVARCHAR
   * parameter, it may be more practical to send it via a
   * java.io.InputStream. JDBC will read the data from the stream
   * as needed, until it reaches end-of-file.  The JDBC driver will
   * do any necessary conversion from UNICODE to the database char format.
   *
   * <P><B>Note:</B> This stream object can either be a standard
   * Java stream object or your own subclass that implements the
   * standard interface.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the java input stream which contains the
   * UNICODE parameter value
   * @param length the number of bytes in the stream
   * @exception SQLException if a database-access error occurs.
   * @deprecated
   */
  public synchronized void setUnicodeStream(int parameterIndex, InputStream x, int length)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jUnicodeStream;
    param.length = length;
  }

  /**
   * Set a parameter to SQL NULL.
   *
   * <P><B>Note:</B> You must specify the parameter's SQL type.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param sqlType SQL type code defined by java.sql.Types
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setNull(int parameterIndex, int sqlType)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = null;
    param.jType = Parameter.jNull_1;
    param.sqlType = sqlType;
  }

  /**
   * Sets the designated parameter to SQL NULL.  This version of setNull should
   * be used for user-named types and REF type parameters.  Examples
   * of user-named types include: STRUCT, DISTINCT, JAVA_OBJECT, and
   * named array types.
   *
   * <P><B>Note:</B> To be portable, applications must give the
   * SQL type code and the fully-qualified SQL type name when specifying
   * a NULL user-defined or REF parameter.  In the case of a user-named type
   * the name is the type name of the parameter itself.  For a REF
   * parameter the name is the type name of the referenced type.  If
   * a JDBC driver does not need the type code or type name information,
   * it may ignore it.
   *
   * Although it is intended for user-named and Ref parameters,
   * this method may be used to set a null parameter of any JDBC type.
   * If the parameter does not have a user-named or REF type, the given
   * typeName is ignored.
   *
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param sqlType a value from java.sql.Types
   * @param typeName the fully-qualified name of an SQL user-named type,
   *  ignored if the parameter is not a user-named type or REF
   * @exception SQLException if a database access error occurs
   */
  public synchronized void setNull(int parameterIndex, int sqlType, String typeName)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = null;
    param.jType = Parameter.jNull_2;
    param.sqlType = sqlType;
    param.typeName = typeName;
  }

  /**
   * <p>Set the value of a parameter using an object; use the
   * java.lang equivalent objects for integral values.
   *
   * <p>The JDBC specification specifies a standard mapping from
   * Java Object types to SQL types.  The given argument java object
   * will be converted to the corresponding SQL type before being
   * sent to the database.
   *
   * <p>Note that this method may be used to pass datatabase
   * specific abstract data types, by using a Driver specific Java
   * type.
   *
   * If the object is of a class implementing SQLData,
   * the rowset should call its method writeSQL() to write it
   * to the SQL data stream.
   * else
   * If the object is of a class implementing Ref, Blob, Clob, Struct,
   * or Array then pass it to the database as a value of the
   * corresponding SQL type.
   *
   * Raise an exception if there is an ambiguity, for example, if the
   * object is of a class implementing more than one of those interfaces.
   *
   * @param parameterIndex The first parameter is 1, the second is 2, ...
   * @param x The object containing the input parameter value
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setObject(int parameterIndex, Object x)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jObject;
  }

  /**
   * This method is like setObject above, but the scale used is the scale
   * of the second parameter.  Scalar values have a scale of zero.  Literal
   * values have the scale present in the literal.  While it is supported, it
   * is not recommended that this method not be called with floating point
   * input values.
   *
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setObject(int parameterIndex, Object x, int targetSqlType)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jObject;
    param.sqlType = targetSqlType;
  }

  /**
   * <p>Set the value of a parameter using an object; use the
   * java.lang equivalent objects for integral values.
   *
   * <p>The given Java object will be converted to the targetSqlType
   * before being sent to the database.
   *
   * If the object is of a class implementing SQLData,
   * the rowset should call its method writeSQL() to write it
   * to the SQL data stream.
   * else
   * If the object is of a class implementing Ref, Blob, Clob, Struct,
   * or Array then pass it to the database as a value of the
   * corresponding SQL type.
   *
   * <p>Note that this method may be used to pass datatabase-
   * specific abstract data types.
   *
   * @param parameterIndex The first parameter is 1, the second is 2, ...
   * @param x The object containing the input parameter value
   * @param targetSqlType The SQL type (as defined in java.sql.Types) to be
   * sent to the database. The scale argument may further qualify this type.
   * @param scale For java.sql.Types.DECIMAL or java.sql.Types.NUMERIC types
   *          this is the number of digits after the decimal.  For all other
   *          types this value will be ignored,
   * @exception SQLException if a database-access error occurs.
   * @see Types
   */
  public synchronized void setObject(int parameterIndex, Object x, int targetSqlType, int scale)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = x;
    param.jType = Parameter.jObject;
    param.sqlType = targetSqlType;
    param.scale = scale;
  }


  /**
   * Set the rowset's command property.
   *
   * This property is optional.  The command property may not be needed
   * when a rowset is produced by a data source that doesn't support
   * commands, such as a spreadsheet.
   *
   * @param cmd a command string, may be null
   * @exception SQLException if a database-access error occurs.
   */
  public synchronized void setCommand(String s)
        throws SQLException
  {
    command = new String(s);
    params.clear();
  }

  /**
   * Set the rowset concurrency.
   *
   * @param concurrency a value from ResultSet.CONCUR_XXX
   * @exception SQLException if a database-access error occurs.
   */
  public void setConcurrency(int i) throws SQLException {
    rsConcurrency = i;
  }

  /**
   * Set the data source name.
   *
   * @param name a data source name
   * @exception SQLException if a database-access error occurs.
   */
  public void setDataSourceName(String s) throws SQLException {
    if(s != null)
       dataSource = new String(s);
    else
       dataSource = null;
    url = null;
  }


  /**
   * If escape scanning is on (the default), the driver will do
   * escape substitution before sending the SQL to the database.
   *
   * @param enable true to enable; false to disable
   * @exception SQLException if a database-access error occurs.
   */
  public void setEscapeProcessing(boolean flag) throws SQLException {
    escapeProcessing = flag;
  }

  /**
   * Give a hint as to the direction in which the rows in this result set
   * will be processed.  The initial value is determined by the statement
   * that produced the result set.  The fetch direction may be changed
   * at any time.
   *
   * @exception SQLException if a database-access error occurs, or
   * the result set type is TYPE_FORWARD_ONLY and direction is not
   * FETCH_FORWARD.
   */
  public void setFetchDirection(int direction) throws SQLException {
    fetchDir = direction;
  }

  /**
   * Give the JDBC driver a hint as to the number of rows that should
   * be fetched from the database when more rows are needed for this result
   * set.  If the fetch size specified is zero, then the JDBC driver
   * ignores the value, and is free to make its own best guess as to what
   * the fetch size should be.  The default value is set by the statement
   * that creates the result set.  The fetch size may be changed at any
   * time.
   *
   * @param rows the number of rows to fetch
   * @exception SQLException if a database-access error occurs, or the
   * condition 0 <= rows <= this.getMaxRows() is not satisfied.
   */
  public void setFetchSize(int rows) throws SQLException {
    fetchSize = rows;
  }

  /**
   * The maxFieldSize limit (in bytes) is set to limit the size of
   * data that can be returned for any column value; it only applies
   * to BINARY, VARBINARY, LONGVARBINARY, CHAR, VARCHAR, and
   * LONGVARCHAR fields.  If the limit is exceeded, the excess data
   * is silently discarded. For maximum portability use values
   * greater than 256.
   *
   * @param max the new max column size limit; zero means unlimited
   * @exception SQLException if a database-access error occurs.
   */
  public void setMaxFieldSize(int max) throws SQLException {
    maxFieldSize = max;
  }

  /**
   * The maxRows limit is set to limit the number of rows that any
   * RowSet can contain.  If the limit is exceeded, the excess
   * rows are silently dropped.
   *
   * @param max the new max rows limit; zero means unlimited
   * @exception SQLException if a database-access error occurs.
   */
  public void setMaxRows(int max) throws SQLException {
    maxRows = max;
  }

  /**
   * The queryTimeout limit is the number of seconds the driver will
   * wait for a Statement to execute. If the limit is exceeded, a
   * SQLException is thrown.
   *
   * @param seconds the new query timeout limit in seconds; zero means
   * unlimited
   * @exception SQLException if a database-access error occurs.
   */
  public void setQueryTimeout(int seconds) throws SQLException {
    queryTimeout = seconds;
  }

  /**
   * Set the read-onlyness of the rowset
   *
   * @param value true if read-only, false otherwise
   * @exception SQLException if a database-access error occurs.
   */
  public void setReadOnly(boolean value) throws SQLException {
    readOnly = value;
  }

  /**
   * Set the password.
   *
   * @param password the password string
   * @exception SQLException if a database-access error occurs.
   */
  public void setPassword(String s) throws SQLException {
    if (s != null)
      password = new String(s);
    else
      password = null;
  }

  /**
   * Set the transaction isolation.
   *
   * @param level the transaction isolation level
   * @exception SQLException if a database-access error occurs.
   */
  public void setTransactionIsolation(int value) throws SQLException
  {
    txn_isolation = value;
  }

  /**
   * Set the type of this result set.
   *
   * @param value may be TYPE_FORWARD_ONLY, TYPE_SCROLL_INSENSITIVE, or
       * TYPE_SCROLL_SENSITIVE
   * @exception SQLException if a database-access error occurs
   */
  public void setType(int value) throws SQLException
  {
    rsType = value;
  }

  /**
   * Install a type-map object as the default type-map for
   * this rowset.
   *
   * @param map a map object
   * @exception SQLException if a database-access error occurs.
   */
  public void setTypeMap(Map value) throws SQLException
  {
     map = value;
  }

  /**
   * Set the url used to create a connection.
   *
   * Setting this property is optional.  If a url is used, a JDBC driver
   * that accepts the url must be loaded by the application before the
   * rowset is used to connect to a database.  The rowset will use the url
   * internally to create a database connection when reading or writing
   * data.  Either a url or a data source name is used to create a
   * connection, whichever was specified most recently.
   *
   * @param url a string value, may be null
   * @exception SQLException if a database-access error occurs.
   */
  public void setUrl(String s) throws SQLException {
    if(s != null)
      url = new String(s);
    else
      url = null;
    dataSource = null;
  }

  /**
   * Set the user name.
   *
   * @param name a user name
   * @exception SQLException if a database-access error occurs.
   */
  public void setUsername(String s) throws SQLException {
    if ( s!= null)
      username = new String(s);
    else
      username = null;
  }


  protected void notifyListener(int event) {
    if(!listeners.isEmpty()) {
       LinkedList l = (LinkedList)listeners.clone();
       RowSetEvent ev = new RowSetEvent(this);
       for(Iterator i = l.iterator(); i.hasNext(); )
         switch (event) {
           case ev_CursorMoved:
              ((RowSetListener)i.next()).cursorMoved(ev);
              break;
           case ev_RowChanged:
              ((RowSetListener)i.next()).rowChanged(ev);
              break;
           case ev_RowSetChanged:
              ((RowSetListener)i.next()).rowSetChanged(ev);
              break;
         }
       l.clear();
    }
  }

  protected Parameter getParam(int paramIndex)
    throws SQLException
  {
    if(paramIndex < 1)
        throw OPLMessage_x.makeExceptionV(OPLMessage_x.errx_Invalid_parameter_index_XX, String.valueOf(paramIndex)); // "S1093"
    paramIndex--;

    int sz = params.size();

    if( paramIndex < sz ) {
      return (Parameter)params.get(paramIndex);
    } else {
       for(; sz < paramIndex; sz++)
           params.add(new Parameter());

       Parameter param = new Parameter();
       params.add(param);
       return param;
    }
  }


 ///////////Inner class////////////
   protected class Parameter {
    protected Object value;
    protected int sqlType = java.sql.Types.VARCHAR;
    protected String typeName;
    protected int scale;
    protected int length;
    protected Calendar cal;
    protected int jType = jObject;

    protected static final int jObject = 0;
    protected static final int jObject_1 = 1;
    protected static final int jObject_2 = 2;
    protected static final int jAsciiStream = 3;
    protected static final int jBinaryStream = 4;
    protected static final int jUnicodeStream = 5;
    protected static final int jCharacterStream = 6;
    protected static final int jDateWithCalendar = 7;
    protected static final int jTimeWithCalendar = 8;
    protected static final int jTimestampWithCalendar = 9;
    protected static final int jNull_1 = 10;
    protected static final int jNull_2 = 11;
  }
}
