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

    private String command;
    private String url;
    private String dataSource;
    private transient String username;
    private transient String password;

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

#if JDK_VER >= 16
    protected java.util.Map<String,Class<?>> map = null;
    private LinkedList<RowSetListener> listeners;
    private ArrayList<Parameter> params;
#else
    private Map map = null;
    private LinkedList listeners;
    private ArrayList params;
#endif


  public BaseRowSet() {
#if JDK_VER >= 16
    listeners = new LinkedList<RowSetListener>();
    params = new ArrayList<Parameter>();
#else
    listeners = new LinkedList();
    params = new ArrayList();
#endif
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
#if JDK_VER >= 16
  public Map<String,Class<?>> getTypeMap() throws SQLException{
#else
  public Map getTypeMap() throws SQLException{
#endif
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

#if JDK_VER >= 16
  /**
     * Sets the designated parameter to a <code>InputStream</code> object.  The inputstream must contain  the number
     * of characters specified by length otherwise a <code>SQLException</code> will be
     * generated when the <code>PreparedStatement</code> is executed.
     * This method differs from the <code>setBinaryStream (int, InputStream, int)</code>
     * method because it informs the driver that the parameter value should be
     * sent to the server as a <code>BLOB</code>.  When the <code>setBinaryStream</code> method is used,
     * the driver may have to do extra work to determine whether the parameter
     * data should be sent to the server as a <code>LONGVARBINARY</code> or a <code>BLOB</code>
     * @param parameterIndex index of the first parameter is 1,
     * the second is 2, ...
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @param length the number of bytes in the parameter data.
     * @throws SQLException if a database access error occurs,
     * this method is called on a closed <code>PreparedStatement</code>,
     * if parameterIndex does not correspond
     * to a parameter marker in the SQL statement,  if the length specified
     * is less than zero or if the number of bytes in the inputstream does not match
     * the specfied length.
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     *
     * @since 1.6
     */
  public synchronized void setBlob(int parameterIndex, InputStream inputStream, long length)
        throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = inputStream;
    param.jType = Parameter.jBinaryStream;
    param.length = (int)length;
  }

  /**
     * Sets the designated parameter to a <code>InputStream</code> object.
     * This method differs from the <code>setBinaryStream (int, InputStream)</code>
     * method because it informs the driver that the parameter value should be
     * sent to the server as a <code>BLOB</code>.  When the <code>setBinaryStream</code> method is used,
     * the driver may have to do extra work to determine whether the parameter
     * data should be sent to the server as a <code>LONGVARBINARY</code> or a <code>BLOB</code>
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>setBlob</code> which takes a length parameter.
     *
     * @param parameterIndex index of the first parameter is 1,
     * the second is 2, ...
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @throws SQLException if a database access error occurs,
     * this method is called on a closed <code>PreparedStatement</code> or
     * if parameterIndex does not correspond
     * to a parameter marker in the SQL statement,
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     *
     * @since 1.6
     */
  public void setBlob(int parameterIndex, InputStream inputStream)
        throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setBlob(parameterIndex, inputStream)");
  }


  /**
     * Sets the designated parameter to a <code>InputStream</code> object.  The <code>inputstream</code> must contain  the number
     * of characters specified by length, otherwise a <code>SQLException</code> will be
     * generated when the <code>CallableStatement</code> is executed.
     * This method differs from the <code>setBinaryStream (int, InputStream, int)</code>
     * method because it informs the driver that the parameter value should be
     * sent to the server as a <code>BLOB</code>.  When the <code>setBinaryStream</code> method is used,
     * the driver may have to do extra work to determine whether the parameter
     * data should be sent to the server as a <code>LONGVARBINARY</code> or a <code>BLOB</code>
     *
     * @param parameterName the name of the parameter to be set
     * the second is 2, ...
     *
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @param length the number of bytes in the parameter data.
     * @throws SQLException  if parameterIndex does not correspond
     * to a parameter marker in the SQL statement,  or if the length specified
     * is less than zero; if the number of bytes in the inputstream does not match
     * the specfied length; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     *
     * @since 1.6
     */
  public void setBlob(String parameterName, InputStream inputStream, long length)
        throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setBlob(parameterName, inputStream, length)");
  }

  /**
     * Sets the designated parameter to the given <code>java.sql.Blob</code> object.
     * The driver converts this to an SQL <code>BLOB</code> value when it
     * sends it to the database.
     *
     * @param parameterName the name of the parameter
     * @param x a <code>Blob</code> object that maps an SQL <code>BLOB</code> value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void setBlob (String parameterName, Blob x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setBlob (parameterName, x)");
  }

  /**
     * Sets the designated parameter to a <code>InputStream</code> object.
     * This method differs from the <code>setBinaryStream (int, InputStream)</code>
     * method because it informs the driver that the parameter value should be
     * sent to the server as a <code>BLOB</code>.  When the <code>setBinaryStream</code> method is used,
     * the driver may have to do extra work to determine whether the parameter
     * data should be send to the server as a <code>LONGVARBINARY</code> or a <code>BLOB</code>
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>setBlob</code> which takes a length parameter.
     *
     * @param parameterName the name of the parameter
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @throws SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     *
     * @since 1.6
     */
  public void setBlob(String parameterName, InputStream inputStream)
        throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setBlob(parameterName, inputStream)");
  }

  /**
     * Sets the designated parameter to a <code>Reader</code> object.  The reader must contain  the number
     * of characters specified by length otherwise a <code>SQLException</code> will be
     * generated when the <code>PreparedStatement</code> is executed.
     *This method differs from the <code>setCharacterStream (int, Reader, int)</code> method
     * because it informs the driver that the parameter value should be sent to
     * the server as a <code>CLOB</code>.  When the <code>setCharacterStream</code> method is used, the
     * driver may have to do extra work to determine whether the parameter
     * data should be sent to the server as a <code>LONGVARCHAR</code> or a <code>CLOB</code>
     * @param parameterIndex index of the first parameter is 1, the second is 2, ...
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @throws SQLException if a database access error occurs, this method is called on
     * a closed <code>PreparedStatement</code>, if parameterIndex does not correspond to a parameter
     * marker in the SQL statement, or if the length specified is less than zero.
     *
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public synchronized void setClob(int parameterIndex, Reader reader, long length)
       throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = reader;
    param.jType = Parameter.jCharacterStream;
    param.length = (int)length;
  }

  /**
     * Sets the designated parameter to a <code>Reader</code> object.
     * This method differs from the <code>setCharacterStream (int, Reader)</code> method
     * because it informs the driver that the parameter value should be sent to
     * the server as a <code>CLOB</code>.  When the <code>setCharacterStream</code> method is used, the
     * driver may have to do extra work to determine whether the parameter
     * data should be sent to the server as a <code>LONGVARCHAR</code> or a <code>CLOB</code>
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>setClob</code> which takes a length parameter.
     *
     * @param parameterIndex index of the first parameter is 1, the second is 2, ...
     * @param reader An object that contains the data to set the parameter value to.
     * @throws SQLException if a database access error occurs, this method is called on
     * a closed <code>PreparedStatement</code>or if parameterIndex does not correspond to a parameter
     * marker in the SQL statement
     *
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public void setClob(int parameterIndex, Reader reader) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setClob(parameterIndex, reader)");
  }

  /**
     * Sets the designated parameter to a <code>Reader</code> object.  The <code>reader</code> must contain  the number
     * of characters specified by length otherwise a <code>SQLException</code> will be
     * generated when the <code>CallableStatement</code> is executed.
     * This method differs from the <code>setCharacterStream (int, Reader, int)</code> method
     * because it informs the driver that the parameter value should be sent to
     * the server as a <code>CLOB</code>.  When the <code>setCharacterStream</code> method is used, the
     * driver may have to do extra work to determine whether the parameter
     * data should be send to the server as a <code>LONGVARCHAR</code> or a <code>CLOB</code>
     * @param parameterName the name of the parameter to be set
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @throws SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if the length specified is less than zero;
     * a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     *
     * @since 1.6
     */
  public void setClob(String parameterName, Reader reader, long length)
       throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setClob(parameterName, reader, length)");
  }

   /**
     * Sets the designated parameter to the given <code>java.sql.Clob</code> object.
     * The driver converts this to an SQL <code>CLOB</code> value when it
     * sends it to the database.
     *
     * @param parameterName the name of the parameter
     * @param x a <code>Clob</code> object that maps an SQL <code>CLOB</code> value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void setClob (String parameterName, Clob x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setClob (String parameterName, Clob x)");
  }

  /**
     * Sets the designated parameter to a <code>Reader</code> object.
     * This method differs from the <code>setCharacterStream (int, Reader)</code> method
     * because it informs the driver that the parameter value should be sent to
     * the server as a <code>CLOB</code>.  When the <code>setCharacterStream</code> method is used, the
     * driver may have to do extra work to determine whether the parameter
     * data should be send to the server as a <code>LONGVARCHAR</code> or a <code>CLOB</code>
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>setClob</code> which takes a length parameter.
     *
     * @param parameterName the name of the parameter
     * @param reader An object that contains the data to set the parameter value to.
     * @throws SQLException if a database access error occurs or this method is called on
     * a closed <code>CallableStatement</code>
     *
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public void setClob(String parameterName, Reader reader) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setClob(parameterName, reader)");
  }

    /**
      * Sets the designated parameter to the given <code>java.sql.SQLXML</code> object. The driver converts this to an
      * SQL <code>XML</code> value when it sends it to the database.
      * @param parameterIndex index of the first parameter is 1, the second is 2, ...
      * @param xmlObject a <code>SQLXML</code> object that maps an SQL <code>XML</code> value
      * @throws SQLException if a database access error occurs, this method
      *  is called on a closed result set,
      * the <code>java.xml.transform.Result</code>,
      *  <code>Writer</code> or <code>OutputStream</code> has not been closed
      * for the <code>SQLXML</code> object  or
      *  if there is an error processing the XML value.  The <code>getCause</code> method
      *  of the exception may provide a more detailed exception, for example, if the
      *  stream does not contain valid XML.
      * @since 1.6
      */
  public void setSQLXML(int parameterIndex, SQLXML xmlObject) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setSQLXML(parameterIndex, xmlObject)");
  }

    /**
     * Sets the designated parameter to the given <code>java.sql.SQLXML</code> object. The driver converts this to an
     * <code>SQL XML</code> value when it sends it to the database.
     * @param parameterName the name of the parameter
     * @param xmlObject a <code>SQLXML</code> object that maps an <code>SQL XML</code> value
     * @throws SQLException if a database access error occurs, this method
     *  is called on a closed result set,
     * the <code>java.xml.transform.Result</code>,
     *  <code>Writer</code> or <code>OutputStream</code> has not been closed
     * for the <code>SQLXML</code> object  or
     *  if there is an error processing the XML value.  The <code>getCause</code> method
     *  of the exception may provide a more detailed exception, for example, if the
     *  stream does not contain valid XML.
     * @since 1.6
     */
  public void setSQLXML(String parameterName, SQLXML xmlObject) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setSQLXML(parameterName, xmlObject)");
  }

    /**
     * Sets the designated parameter to the given <code>java.sql.RowId</code> object. The
     * driver converts this to a SQL <code>ROWID</code> value when it sends it
     * to the database
     *
     * @param parameterIndex the first parameter is 1, the second is 2, ...
     * @param x the parameter value
     * @throws SQLException if a database access error occurs
     *
     * @since 1.6
     */
  public void setRowId(int parameterIndex, RowId x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setRowId(parameterIndex, x)");
  }

    /**
    * Sets the designated parameter to the given <code>java.sql.RowId</code> object. The
    * driver converts this to a SQL <code>ROWID</code> when it sends it to the
    * database.
    *
    * @param parameterName the name of the parameter
    * @param x the parameter value
    * @throws SQLException if a database access error occurs
    * @since 1.6
    */
  public void setRowId(String parameterName, RowId x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setRowId(parameterName, x)");
  }

    /**
     * Sets the designated paramter to the given <code>String</code> object.
     * The driver converts this to a SQL <code>NCHAR</code> or
     * <code>NVARCHAR</code> or <code>LONGNVARCHAR</code> value
     * (depending on the argument's
     * size relative to the driver's limits on <code>NVARCHAR</code> values)
     * when it sends it to the database.
     *
     * @param parameterIndex of the first parameter is 1, the second is 2, ...
     * @param value the parameter value
     * @throws SQLException if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur ; or if a database access error occurs
     * @since 1.6
     */
  public void setNString(int parameterIndex, String value) throws SQLException
  {
    setString(parameterIndex, value);
  }

    /**
     * Sets the designated paramter to the given <code>String</code> object.
     * The driver converts this to a SQL <code>NCHAR</code> or
     * <code>NVARCHAR</code> or <code>LONGNVARCHAR</code>
     * @param parameterName the name of the column to be set
     * @param value the parameter value
     * @throws SQLException if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; or if a database access error occurs
     * @since 1.6
     */
  public void setNString(String parameterName, String value)
            throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setNString(parameterName, value)");
  }

    /**
     * Sets the designated parameter to a <code>Reader</code> object. The
     * <code>Reader</code> reads the data till end-of-file is reached. The
     * driver does the necessary conversion from Java character format to
     * the national character set in the database.
     * @param parameterIndex of the first parameter is 1, the second is 2, ...
     * @param value the parameter value
     * @param length the number of characters in the parameter data.
     * @throws SQLException if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur ; or if a database access error occurs
     * @since 1.6
     */
  public void setNCharacterStream(int parameterIndex, Reader value, long length) throws SQLException
  {
    setCharacterStream(parameterIndex, value, (int)length);
  }

    /**
     * Sets the designated parameter to a <code>Reader</code> object. The
     * <code>Reader</code> reads the data till end-of-file is reached. The
     * driver does the necessary conversion from Java character format to
     * the national character set in the database.
     * @param parameterName the name of the column to be set
     * @param value the parameter value
     * @param length the number of characters in the parameter data.
     * @throws SQLException if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; or if a database access error occurs
     * @since 1.6
     */
  public void setNCharacterStream(String parameterName, Reader value, long length)
            throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setNCharacterStream(parameterName, value, length)");
  }

    /**
     * Sets the designated parameter to a <code>Reader</code> object. The
     * <code>Reader</code> reads the data till end-of-file is reached. The
     * driver does the necessary conversion from Java character format to
     * the national character set in the database.

     * <P><B>Note:</B> This stream object can either be a standard
     * Java stream object or your own subclass that implements the
     * standard interface.
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>setNCharacterStream</code> which takes a length parameter.
     *
     * @param parameterName the name of the parameter
     * @param value the parameter value
     * @throws SQLException if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur ; if a database access error occurs; or
     * this method is called on a closed <code>CallableStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public void setNCharacterStream(String parameterName, Reader value) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setNCharacterStream(parameterName, value)");
  }

    /**
    * Sets the designated parameter to a <code>java.sql.NClob</code> object. The object
    * implements the <code>java.sql.NClob</code> interface. This <code>NClob</code>
    * object maps to a SQL <code>NCLOB</code>.
    * @param parameterName the name of the column to be set
    * @param value the parameter value
    * @throws SQLException if the driver does not support national
    *         character sets;  if the driver can detect that a data conversion
    *  error could occur; or if a database access error occurs
    * @since 1.6
    */
  public void setNClob(String parameterName, NClob value) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setNClob(parameterName, value)");
  }

    /**
     * Sets the designated parameter to a <code>Reader</code> object.  The <code>reader</code> must contain  the number
     * of characters specified by length otherwise a <code>SQLException</code> will be
     * generated when the <code>CallableStatement</code> is executed.
     * This method differs from the <code>setCharacterStream (int, Reader, int)</code> method
     * because it informs the driver that the parameter value should be sent to
     * the server as a <code>NCLOB</code>.  When the <code>setCharacterStream</code> method is used, the
     * driver may have to do extra work to determine whether the parameter
     * data should be send to the server as a <code>LONGNVARCHAR</code> or a <code>NCLOB</code>
     *
     * @param parameterName the name of the parameter to be set
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @throws SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if the length specified is less than zero;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void setNClob(String parameterName, Reader reader, long length)
       throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setNClob(parameterName, value)");
  }

    /**
     * Sets the designated parameter to a <code>Reader</code> object.
     * This method differs from the <code>setCharacterStream (int, Reader)</code> method
     * because it informs the driver that the parameter value should be sent to
     * the server as a <code>NCLOB</code>.  When the <code>setCharacterStream</code> method is used, the
     * driver may have to do extra work to determine whether the parameter
     * data should be send to the server as a <code>LONGNVARCHAR</code> or a <code>NCLOB</code>
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>setNClob</code> which takes a length parameter.
     *
     * @param parameterName the name of the parameter
     * @param reader An object that contains the data to set the parameter value to.
     * @throws SQLException if the driver does not support national character sets;
     * if the driver can detect that a data conversion
     *  error could occur;  if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     *
     * @since 1.6
     */
  public void setNClob(String parameterName, Reader reader) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setNClob(parameterName, reader)");
  }

    /**
     * Sets the designated parameter to a <code>Reader</code> object.  The reader must contain  the number
     * of characters specified by length otherwise a <code>SQLException</code> will be
     * generated when the <code>PreparedStatement</code> is executed.
     * This method differs from the <code>setCharacterStream (int, Reader, int)</code> method
     * because it informs the driver that the parameter value should be sent to
     * the server as a <code>NCLOB</code>.  When the <code>setCharacterStream</code> method is used, the
     * driver may have to do extra work to determine whether the parameter
     * data should be sent to the server as a <code>LONGNVARCHAR</code> or a <code>NCLOB</code>
     * @param parameterIndex index of the first parameter is 1, the second is 2, ...
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @throws SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if the length specified is less than zero;
     * if the driver does not support national character sets;
     * if the driver can detect that a data conversion
     *  error could occur;  if a database access error occurs or
     * this method is called on a closed <code>PreparedStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     *
     * @since 1.6
     */
  public void setNClob(int parameterIndex, Reader reader, long length) throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = reader;
    param.jType = Parameter.jCharacterStream;
    param.length = (int)length;
  }

    /**
     * Sets the designated parameter to a <code>java.sql.NClob</code> object. The driver converts this to a
     * SQL <code>NCLOB</code> value when it sends it to the database.
     * @param parameterIndex of the first parameter is 1, the second is 2, ...
     * @param value the parameter value
     * @throws SQLException if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur ; or if a database access error occurs
     * @since 1.6
     */
  public synchronized void setNClob(int parameterIndex, NClob value) throws SQLException
  {
    Parameter param = getParam(parameterIndex);

    param.value = value;
    param.jType = Parameter.jObject;
  }

    /**
     * Sets the designated parameter to a <code>Reader</code> object.
     * This method differs from the <code>setCharacterStream (int, Reader)</code> method
     * because it informs the driver that the parameter value should be sent to
     * the server as a <code>NCLOB</code>.  When the <code>setCharacterStream</code> method is used, the
     * driver may have to do extra work to determine whether the parameter
     * data should be sent to the server as a <code>LONGNVARCHAR</code> or a <code>NCLOB</code>
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>setNClob</code> which takes a length parameter.
     *
     * @param parameterIndex index of the first parameter is 1, the second is 2, ...
     * @param reader An object that contains the data to set the parameter value to.
     * @throws SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement;
     * if the driver does not support national character sets;
     * if the driver can detect that a data conversion
     *  error could occur;  if a database access error occurs or
     * this method is called on a closed <code>PreparedStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     *
     * @since 1.6
     */
  public void setNClob(int parameterIndex, Reader reader) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setNClob(parameterIndex, reader)");
  }

#endif

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

#if JDK_VER >= 16

  /**
   * Sets the designated parameter in this <code>RowSet</code> object's command
   * to the given input stream.
   * When a very large ASCII value is input to a <code>LONGVARCHAR</code>
   * parameter, it may be more practical to send it via a
   * <code>java.io.InputStream</code>. Data will be read from the stream
   * as needed until end-of-file is reached.  The JDBC driver will
   * do any necessary conversion from ASCII to the database char format.
   *
   * <P><B>Note:</B> This stream object can either be a standard
   * Java stream object or your own subclass that implements the
   * standard interface.
   * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
   * it might be more efficient to use a version of
   * <code>setAsciiStream</code> which takes a length parameter.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the Java input stream that contains the ASCII parameter value
   * @exception SQLException if a database access error occurs or
   * this method is called on a closed <code>PreparedStatement</code>
   * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
   * @since 1.6
   */
 public void setAsciiStream(int parameterIndex, java.io.InputStream x)
                      throws SQLException
 {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setAsciiStream(parameterIndex, x)");
 }

   /**
     * Sets the designated parameter to the given input stream.
     * When a very large ASCII value is input to a <code>LONGVARCHAR</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.InputStream</code>. Data will be read from the stream
     * as needed until end-of-file is reached.  The JDBC driver will
     * do any necessary conversion from ASCII to the database char format.
     *
     * <P><B>Note:</B> This stream object can either be a standard
     * Java stream object or your own subclass that implements the
     * standard interface.
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>setAsciiStream</code> which takes a length parameter.
     *
     * @param parameterName the name of the parameter
     * @param x the Java input stream that contains the ASCII parameter value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
       * @since 1.6
    */
  public void setAsciiStream(String parameterName, java.io.InputStream x)
            throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setAsciiStream(parameterName, x)");
  }

  /**
   * Sets the designated parameter in this <code>RowSet</code> object's command
   * to the given input stream.
   * When a very large binary value is input to a <code>LONGVARBINARY</code>
   * parameter, it may be more practical to send it via a
   * <code>java.io.InputStream</code> object. The data will be read from the
   * stream as needed until end-of-file is reached.
   *
   * <P><B>Note:</B> This stream object can either be a standard
   * Java stream object or your own subclass that implements the
   * standard interface.
   * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
   * it might be more efficient to use a version of
   * <code>setBinaryStream</code> which takes a length parameter.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param x the java input stream which contains the binary parameter value
   * @exception SQLException if a database access error occurs or
   * this method is called on a closed <code>PreparedStatement</code>
   * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
   * @since 1.6
   */
  public void setBinaryStream(int parameterIndex, java.io.InputStream x)
                       throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setBinaryStream(parameterIndex, x)");
  }

  /**
     * Sets the designated parameter to the given input stream.
     * When a very large binary value is input to a <code>LONGVARBINARY</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.InputStream</code> object. The data will be read from the
     * stream as needed until end-of-file is reached.
     *
     * <P><B>Note:</B> This stream object can either be a standard
     * Java stream object or your own subclass that implements the
     * standard interface.
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>setBinaryStream</code> which takes a length parameter.
     *
     * @param parameterName the name of the parameter
     * @param x the java input stream which contains the binary parameter value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public void setBinaryStream(String parameterName, java.io.InputStream x)
    throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setBinaryStream(parameterName, x)");
  }

  /**
   * Sets the designated parameter in this <code>RowSet</code> object's command
   * to the given <code>Reader</code>
   * object.
   * When a very large UNICODE value is input to a <code>LONGVARCHAR</code>
   * parameter, it may be more practical to send it via a
   * <code>java.io.Reader</code> object. The data will be read from the stream
   * as needed until end-of-file is reached.  The JDBC driver will
   * do any necessary conversion from UNICODE to the database char format.
   *
   * <P><B>Note:</B> This stream object can either be a standard
   * Java stream object or your own subclass that implements the
   * standard interface.
   * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
   * it might be more efficient to use a version of
   * <code>setCharacterStream</code> which takes a length parameter.
   *
   * @param parameterIndex the first parameter is 1, the second is 2, ...
   * @param reader the <code>java.io.Reader</code> object that contains the
   *        Unicode data
   * @exception SQLException if a database access error occurs or
   * this method is called on a closed <code>PreparedStatement</code>
   * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
   * @since 1.6
   */
  public void setCharacterStream(int parameterIndex,
                          java.io.Reader reader) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setCharacterStream(parameterIndex, reader)");
  }

  /**
     * Sets the designated parameter to the given <code>Reader</code>
     * object.
     * When a very large UNICODE value is input to a <code>LONGVARCHAR</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.Reader</code> object. The data will be read from the stream
     * as needed until end-of-file is reached.  The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <P><B>Note:</B> This stream object can either be a standard
     * Java stream object or your own subclass that implements the
     * standard interface.
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>setCharacterStream</code> which takes a length parameter.
     *
     * @param parameterName the name of the parameter
     * @param reader the <code>java.io.Reader</code> object that contains the
     *        Unicode data
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public void setCharacterStream(String parameterName,
                          java.io.Reader reader) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setCharacterStream(parameterName, reader)");
  }

  /**
   * Sets the designated parameter in this <code>RowSet</code> object's command
   * to a <code>Reader</code> object. The
   * <code>Reader</code> reads the data till end-of-file is reached. The
   * driver does the necessary conversion from Java character format to
   * the national character set in the database.

   * <P><B>Note:</B> This stream object can either be a standard
   * Java stream object or your own subclass that implements the
   * standard interface.
   * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
   * it might be more efficient to use a version of
   * <code>setNCharacterStream</code> which takes a length parameter.
   *
   * @param parameterIndex of the first parameter is 1, the second is 2, ...
   * @param value the parameter value
   * @throws SQLException if the driver does not support national
   *         character sets;  if the driver can detect that a data conversion
   *  error could occur ; if a database access error occurs; or
   * this method is called on a closed <code>PreparedStatement</code>
   * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
   * @since 1.6
   */
  public void setNCharacterStream(int parameterIndex, Reader value) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setNCharacterStream(parameterIndex, value)");
  }

#endif

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
     * Sets the designated parameter to the given <code>java.net.URL</code> value.
     * The driver converts this to an SQL <code>DATALINK</code> value
     * when it sends it to the database.
     *
     * @param parameterIndex the first parameter is 1, the second is 2, ...
     * @param x the <code>java.net.URL</code> object to be set
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>PreparedStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.4
     */
  public synchronized void setURL(int parameterIndex, java.net.URL x) throws SQLException
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


#if JDK_VER >= 16
  /**
     * Sets the designated parameter to SQL <code>NULL</code>.
     *
     * <P><B>Note:</B> You must specify the parameter's SQL type.
     *
     * @param parameterName the name of the parameter
     * @param sqlType the SQL type code defined in <code>java.sql.Types</code>
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.4
     */
  public void setNull(String parameterName, int sqlType) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setNull(parameterName, sqlType)");
  }

  /**
     * Sets the designated parameter to SQL <code>NULL</code>.
     * This version of the method <code>setNull</code> should
     * be used for user-defined types and REF type parameters.  Examples
     * of user-defined types include: STRUCT, DISTINCT, JAVA_OBJECT, and
     * named array types.
     *
     * <P><B>Note:</B> To be portable, applications must give the
     * SQL type code and the fully-qualified SQL type name when specifying
     * a NULL user-defined or REF parameter.  In the case of a user-defined type
     * the name is the type name of the parameter itself.  For a REF
     * parameter, the name is the type name of the referenced type.  If
     * a JDBC driver does not need the type code or type name information,
     * it may ignore it.
     *
     * Although it is intended for user-defined and Ref parameters,
     * this method may be used to set a null parameter of any JDBC type.
     * If the parameter does not have a user-defined or REF type, the given
     * typeName is ignored.
     *
     *
     * @param parameterName the name of the parameter
     * @param sqlType a value from <code>java.sql.Types</code>
     * @param typeName the fully-qualified name of an SQL user-defined type;
     *        ignored if the parameter is not a user-defined type or
     *        SQL <code>REF</code> value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.4
     */
  public void setNull (String parameterName, int sqlType, String typeName)
        throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setNull (parameterName, sqlType, typeName)");
  }

  /**
     * Sets the designated parameter to the given Java <code>boolean</code> value.
     * The driver converts this
     * to an SQL <code>BIT</code> or <code>BOOLEAN</code> value when it sends it to the database.
     *
     * @param parameterName the name of the parameter
     * @param x the parameter value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @see #getBoolean
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.4
     */
  public void setBoolean(String parameterName, boolean x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setBoolean(parameterName, x)");
  }

  /**
     * Sets the designated parameter to the given Java <code>byte</code> value.
     * The driver converts this
     * to an SQL <code>TINYINT</code> value when it sends it to the database.
     *
     * @param parameterName the name of the parameter
     * @param x the parameter value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see #getByte
     * @since 1.4
     */
  public void setByte(String parameterName, byte x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setByte(parameterName, x)");
  }

  /**
     * Sets the designated parameter to the given Java <code>short</code> value.
     * The driver converts this
     * to an SQL <code>SMALLINT</code> value when it sends it to the database.
     *
     * @param parameterName the name of the parameter
     * @param x the parameter value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see #getShort
     * @since 1.4
     */
  public void setShort(String parameterName, short x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setShort(parameterName, x)");
  }

  /**
     * Sets the designated parameter to the given Java <code>int</code> value.
     * The driver converts this
     * to an SQL <code>INTEGER</code> value when it sends it to the database.
     *
     * @param parameterName the name of the parameter
     * @param x the parameter value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see #getInt
     * @since 1.4
     */
  public void setInt(String parameterName, int x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setInt(parameterName, x)");
  }

  /**
     * Sets the designated parameter to the given Java <code>long</code> value.
     * The driver converts this
     * to an SQL <code>BIGINT</code> value when it sends it to the database.
     *
     * @param parameterName the name of the parameter
     * @param x the parameter value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see #getLong
     * @since 1.4
     */
  public void setLong(String parameterName, long x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setLong(parameterName, x)");
  }

  /**
     * Sets the designated parameter to the given Java <code>float</code> value.
     * The driver converts this
     * to an SQL <code>FLOAT</code> value when it sends it to the database.
     *
     * @param parameterName the name of the parameter
     * @param x the parameter value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see #getFloat
     * @since 1.4
     */
  public void setFloat(String parameterName, float x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setFloat(parameterName, x)");
  }

  /**
     * Sets the designated parameter to the given Java <code>double</code> value.
     * The driver converts this
     * to an SQL <code>DOUBLE</code> value when it sends it to the database.
     *
     * @param parameterName the name of the parameter
     * @param x the parameter value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see #getDouble
     * @since 1.4
     */
  public void setDouble(String parameterName, double x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setDouble(parameterName, x)");
  }

  /**
     * Sets the designated parameter to the given
     * <code>java.math.BigDecimal</code> value.
     * The driver converts this to an SQL <code>NUMERIC</code> value when
     * it sends it to the database.
     *
     * @param parameterName the name of the parameter
     * @param x the parameter value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see #getBigDecimal
     * @since 1.4
     */
  public void setBigDecimal(String parameterName, BigDecimal x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setBigDecimal(parameterName, x)");
  }

  /**
     * Sets the designated parameter to the given Java <code>String</code> value.
     * The driver converts this
     * to an SQL <code>VARCHAR</code> or <code>LONGVARCHAR</code> value
     * (depending on the argument's
     * size relative to the driver's limits on <code>VARCHAR</code> values)
     * when it sends it to the database.
     *
     * @param parameterName the name of the parameter
     * @param x the parameter value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see #getString
     * @since 1.4
     */
  public void setString(String parameterName, String x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setString(parameterName, x)");
  }

  /**
     * Sets the designated parameter to the given Java array of bytes.
     * The driver converts this to an SQL <code>VARBINARY</code> or
     * <code>LONGVARBINARY</code> (depending on the argument's size relative
     * to the driver's limits on <code>VARBINARY</code> values) when it sends
     * it to the database.
     *
     * @param parameterName the name of the parameter
     * @param x the parameter value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see #getBytes
     * @since 1.4
     */
  public void setBytes(String parameterName, byte x[]) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setBytes(parameterName, x[])");
  }

  /**
     * Sets the designated parameter to the given <code>java.sql.Timestamp</code> value.
     * The driver
     * converts this to an SQL <code>TIMESTAMP</code> value when it sends it to the
     * database.
     *
     * @param parameterName the name of the parameter
     * @param x the parameter value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see #getTimestamp
     * @since 1.4
     */
  public void setTimestamp(String parameterName, java.sql.Timestamp x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setTimestamp(parameterName, x)");
  }

  /**
     * Sets the designated parameter to the given input stream, which will have
     * the specified number of bytes.
     * When a very large ASCII value is input to a <code>LONGVARCHAR</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.InputStream</code>. Data will be read from the stream
     * as needed until end-of-file is reached.  The JDBC driver will
     * do any necessary conversion from ASCII to the database char format.
     *
     * <P><B>Note:</B> This stream object can either be a standard
     * Java stream object or your own subclass that implements the
     * standard interface.
     *
     * @param parameterName the name of the parameter
     * @param x the Java input stream that contains the ASCII parameter value
     * @param length the number of bytes in the stream
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.4
     */
  public void setAsciiStream(String parameterName, java.io.InputStream x, int length) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setAsciiStream(parameterName, x, length)");
  }

  /**
     * Sets the designated parameter to the given input stream, which will have
     * the specified number of bytes.
     * When a very large binary value is input to a <code>LONGVARBINARY</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.InputStream</code> object. The data will be read from the stream
     * as needed until end-of-file is reached.
     *
     * <P><B>Note:</B> This stream object can either be a standard
     * Java stream object or your own subclass that implements the
     * standard interface.
     *
     * @param parameterName the name of the parameter
     * @param x the java input stream which contains the binary parameter value
     * @param length the number of bytes in the stream
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.4
     */
  public void setBinaryStream(String parameterName, java.io.InputStream x, int length) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setBinaryStream(parameterName, x, length)");
  }

  /**
     * Sets the designated parameter to the given <code>Reader</code>
     * object, which is the given number of characters long.
     * When a very large UNICODE value is input to a <code>LONGVARCHAR</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.Reader</code> object. The data will be read from the stream
     * as needed until end-of-file is reached.  The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <P><B>Note:</B> This stream object can either be a standard
     * Java stream object or your own subclass that implements the
     * standard interface.
     *
     * @param parameterName the name of the parameter
     * @param reader the <code>java.io.Reader</code> object that
     *        contains the UNICODE data used as the designated parameter
     * @param length the number of characters in the stream
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.4
     */
  public void setCharacterStream(String parameterName, java.io.Reader reader, int length) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setCharacterStream(parameterName, reader, length)");
  }

  /**
     * Sets the value of the designated parameter with the given object. The second
     * argument must be an object type; for integral values, the
     * <code>java.lang</code> equivalent objects should be used.
     *
     * <p>The given Java object will be converted to the given targetSqlType
     * before being sent to the database.
     *
     * If the object has a custom mapping (is of a class implementing the
     * interface <code>SQLData</code>),
     * the JDBC driver should call the method <code>SQLData.writeSQL</code> to write it
     * to the SQL data stream.
     * If, on the other hand, the object is of a class implementing
     * <code>Ref</code>, <code>Blob</code>, <code>Clob</code>,  <code>NClob</code>,
     *  <code>Struct</code>, <code>java.net.URL</code>,
     * or <code>Array</code>, the driver should pass it to the database as a
     * value of the corresponding SQL type.
     * <P>
     * Note that this method may be used to pass datatabase-
     * specific abstract data types.
     *
     * @param parameterName the name of the parameter
     * @param x the object containing the input parameter value
     * @param targetSqlType the SQL type (as defined in java.sql.Types) to be
     * sent to the database. The scale argument may further qualify this type.
     * @param scale for java.sql.Types.DECIMAL or java.sql.Types.NUMERIC types,
     *          this is the number of digits after the decimal point.  For all other
     *          types, this value will be ignored.
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if <code>targetSqlType</code> is
     * a <code>ARRAY</code>, <code>BLOB</code>, <code>CLOB</code>,
     * <code>DATALINK</code>, <code>JAVA_OBJECT</code>, <code>NCHAR</code>,
     * <code>NCLOB</code>, <code>NVARCHAR</code>, <code>LONGNVARCHAR</code>,
     *  <code>REF</code>, <code>ROWID</code>, <code>SQLXML</code>
     * or  <code>STRUCT</code> data type and the JDBC driver does not support
     * this data type
     * @see Types
     * @see #getObject
     * @since 1.4
     */
  public void setObject(String parameterName, Object x, int targetSqlType, int scale) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setObject(parameterName, x, targetSqlType, scale)");
  }

  /**
     * Sets the value of the designated parameter with the given object.
     * This method is like the method <code>setObject</code>
     * above, except that it assumes a scale of zero.
     *
     * @param parameterName the name of the parameter
     * @param x the object containing the input parameter value
     * @param targetSqlType the SQL type (as defined in java.sql.Types) to be
     *                      sent to the database
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if <code>targetSqlType</code> is
     * a <code>ARRAY</code>, <code>BLOB</code>, <code>CLOB</code>,
     * <code>DATALINK</code>, <code>JAVA_OBJECT</code>, <code>NCHAR</code>,
     * <code>NCLOB</code>, <code>NVARCHAR</code>, <code>LONGNVARCHAR</code>,
     *  <code>REF</code>, <code>ROWID</code>, <code>SQLXML</code>
     * or  <code>STRUCT</code> data type and the JDBC driver does not support
     * this data type
     * @see #getObject
     * @since 1.4
     */
  public void setObject(String parameterName, Object x, int targetSqlType) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setObject(parameterName, x, targetSqlType)");
  }

   /**
     * Sets the value of the designated parameter with the given object.
     * The second parameter must be of type <code>Object</code>; therefore, the
     * <code>java.lang</code> equivalent objects should be used for built-in types.
     *
     * <p>The JDBC specification specifies a standard mapping from
     * Java <code>Object</code> types to SQL types.  The given argument
     * will be converted to the corresponding SQL type before being
     * sent to the database.
     *
     * <p>Note that this method may be used to pass datatabase-
     * specific abstract data types, by using a driver-specific Java
     * type.
     *
     * If the object is of a class implementing the interface <code>SQLData</code>,
     * the JDBC driver should call the method <code>SQLData.writeSQL</code>
     * to write it to the SQL data stream.
     * If, on the other hand, the object is of a class implementing
     * <code>Ref</code>, <code>Blob</code>, <code>Clob</code>,  <code>NClob</code>,
     *  <code>Struct</code>, <code>java.net.URL</code>,
     * or <code>Array</code>, the driver should pass it to the database as a
     * value of the corresponding SQL type.
     * <P>
     * This method throws an exception if there is an ambiguity, for example, if the
     * object is of a class implementing more than one of the interfaces named above.
     *
     * @param parameterName the name of the parameter
     * @param x the object containing the input parameter value
     * @exception SQLException if a database access error occurs,
     * this method is called on a closed <code>CallableStatement</code> or if the given
     *            <code>Object</code> parameter is ambiguous
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see #getObject
     * @since 1.4
     */
  public void setObject(String parameterName, Object x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setObject(parameterName, x)");
  }

  /**
     * Sets the designated parameter to the given <code>java.sql.Date</code> value
     * using the default time zone of the virtual machine that is running
     * the application.
     * The driver converts this
     * to an SQL <code>DATE</code> value when it sends it to the database.
     *
     * @param parameterName the name of the parameter
     * @param x the parameter value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see #getDate
     * @since 1.4
     */
  public void setDate(String parameterName, java.sql.Date x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setDate(parameterName, x)");
  }

  /**
     * Sets the designated parameter to the given <code>java.sql.Date</code> value,
     * using the given <code>Calendar</code> object.  The driver uses
     * the <code>Calendar</code> object to construct an SQL <code>DATE</code> value,
     * which the driver then sends to the database.  With a
     * a <code>Calendar</code> object, the driver can calculate the date
     * taking into account a custom timezone.  If no
     * <code>Calendar</code> object is specified, the driver uses the default
     * timezone, which is that of the virtual machine running the application.
     *
     * @param parameterName the name of the parameter
     * @param x the parameter value
     * @param cal the <code>Calendar</code> object the driver will use
     *            to construct the date
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see #getDate
     * @since 1.4
     */
  public void setDate(String parameterName, java.sql.Date x, Calendar cal) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setDate(parameterName, x, cal)");
  }

  /**
     * Sets the designated parameter to the given <code>java.sql.Time</code> value.
     * The driver converts this
     * to an SQL <code>TIME</code> value when it sends it to the database.
     *
     * @param parameterName the name of the parameter
     * @param x the parameter value
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see #getTime
     * @since 1.4
     */
  public void setTime(String parameterName, java.sql.Time x) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setTime(parameterName, x)");
  }

  /**
     * Sets the designated parameter to the given <code>java.sql.Time</code> value,
     * using the given <code>Calendar</code> object.  The driver uses
     * the <code>Calendar</code> object to construct an SQL <code>TIME</code> value,
     * which the driver then sends to the database.  With a
     * a <code>Calendar</code> object, the driver can calculate the time
     * taking into account a custom timezone.  If no
     * <code>Calendar</code> object is specified, the driver uses the default
     * timezone, which is that of the virtual machine running the application.
     *
     * @param parameterName the name of the parameter
     * @param x the parameter value
     * @param cal the <code>Calendar</code> object the driver will use
     *            to construct the time
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see #getTime
     * @since 1.4
     */
  public void setTime(String parameterName, java.sql.Time x, Calendar cal) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setTime(parameterName, x, cal)");
  }

  /**
     * Sets the designated parameter to the given <code>java.sql.Timestamp</code> value,
     * using the given <code>Calendar</code> object.  The driver uses
     * the <code>Calendar</code> object to construct an SQL <code>TIMESTAMP</code> value,
     * which the driver then sends to the database.  With a
     * a <code>Calendar</code> object, the driver can calculate the timestamp
     * taking into account a custom timezone.  If no
     * <code>Calendar</code> object is specified, the driver uses the default
     * timezone, which is that of the virtual machine running the application.
     *
     * @param parameterName the name of the parameter
     * @param x the parameter value
     * @param cal the <code>Calendar</code> object the driver will use
     *            to construct the timestamp
     * @exception SQLException if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @see #getTimestamp
     * @since 1.4
     */
  public void setTimestamp(String parameterName, java.sql.Timestamp x, Calendar cal) throws SQLException
  {
    throw OPLMessage_x.makeFExceptionV(OPLMessage_x.errx_Method_XX_not_yet_implemented, "setTimestamp(parameterName, x, cal)");
  }

#endif

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
#if JDK_VER >= 16
  public void setTypeMap(Map<String,Class<?>> value) throws SQLException
#else
  public void setTypeMap(Map value) throws SQLException
#endif
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
