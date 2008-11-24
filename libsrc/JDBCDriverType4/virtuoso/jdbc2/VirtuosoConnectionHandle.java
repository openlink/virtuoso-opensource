/*
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
//
// $Id$
//

package virtuoso.jdbc2;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.SQLWarning;
import java.sql.Savepoint;
import java.sql.Statement;
import java.util.Map;
import java.sql.*;
import java.util.Properties;

/**
 * Connection wrapper which is created by PooledConnection.getConnection()
 * and XAConnection.getConnection().
 *
 * @author avd
 */
public class VirtuosoConnectionHandle implements Connection {

    private VirtuosoPooledConnection pooledConnection;

    VirtuosoConnectionHandle(VirtuosoPooledConnection pooledConnection) {
        this.pooledConnection = pooledConnection;
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#close()
     */
    public void close() throws SQLException {
        if(isClosed()) {
            return;
        }
        try {
            VirtuosoConnection connection = pooledConnection.getVirtuosoConnection();
            if(!connection.getAutoCommit() && !connection.getGlobalTransaction()) {
                connection.rollback();
            }
        } finally {
            pooledConnection.notify_closed();
            pooledConnection = null;
        }
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#isClosed()
     */
    public boolean isClosed() throws SQLException {
        return pooledConnection == null;
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#getWarnings()
     */
    public SQLWarning getWarnings() throws SQLException {
        return getVirtuosoConnection().getWarnings();
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#clearWarnings()
     */
    public void clearWarnings() throws SQLException {
        getVirtuosoConnection().clearWarnings();
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#getAutoCommit()
     */
    public boolean getAutoCommit() throws SQLException {
        return getVirtuosoConnection().getAutoCommit();
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#setAutoCommit(boolean)
     */
    public void setAutoCommit(boolean autoCommit) throws SQLException {
        getVirtuosoConnection().setAutoCommit(autoCommit);
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#getCatalog()
     */
    public String getCatalog() throws SQLException {
        return getVirtuosoConnection().getCatalog();
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#setCatalog(java.lang.String)
     */
    public void setCatalog(String catalog) throws SQLException {
        getVirtuosoConnection().setCatalog(catalog);
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#getHoldability()
     */
    public int getHoldability() throws SQLException {
        return getVirtuosoConnection().getHoldability();
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#setHoldability(int)
     */
    public void setHoldability(int holdability) throws SQLException {
        getVirtuosoConnection().setHoldability(holdability);
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#isReadOnly()
     */
    public boolean isReadOnly() throws SQLException {
        return getVirtuosoConnection().isReadOnly();
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#setReadOnly(boolean)
     */
    public void setReadOnly(boolean readOnly) throws SQLException {
        getVirtuosoConnection().setReadOnly(readOnly);
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#getTransactionIsolation()
     */
    public int getTransactionIsolation() throws SQLException {
        return getVirtuosoConnection().getTransactionIsolation();
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#setTransactionIsolation(int)
     */
    public void setTransactionIsolation(int arg0) throws SQLException {
        getVirtuosoConnection().getTransactionIsolation();
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#getTypeMap()
     */
    public Map getTypeMap() throws SQLException {
        return getVirtuosoConnection().getTypeMap();
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#setTypeMap(java.util.Map)
     */
    public void setTypeMap(Map map) throws SQLException {
        getVirtuosoConnection().setTypeMap(map);
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#getMetaData()
     */
    public DatabaseMetaData getMetaData() throws SQLException {
        VirtuosoDatabaseMetaData metadata =
            (VirtuosoDatabaseMetaData) getVirtuosoConnection().getMetaData();
        metadata.setConnectionHandle(this);
        return metadata;
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#nativeSQL(java.lang.String)
     */
    public String nativeSQL(String sql) throws SQLException {
        return getVirtuosoConnection().nativeSQL(sql);
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#commit()
     */
    public void commit() throws SQLException {
        getVirtuosoConnection().commit();
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#rollback()
     */
    public void rollback() throws SQLException {
        getVirtuosoConnection().rollback();
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#setSavepoint()
     */
    public Savepoint setSavepoint() throws SQLException {
        return getVirtuosoConnection().setSavepoint();
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#setSavepoint(java.lang.String)
     */
    public Savepoint setSavepoint(String name) throws SQLException {
        return getVirtuosoConnection().setSavepoint(name);
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#releaseSavepoint(java.sql.Savepoint)
     */
    public void releaseSavepoint(Savepoint savepoint) throws SQLException {
        getVirtuosoConnection().releaseSavepoint(savepoint);
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#rollback(java.sql.Savepoint)
     */
    public void rollback(Savepoint savepoint) throws SQLException {
        getVirtuosoConnection().rollback(savepoint);
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#createStatement()
     */
    public Statement createStatement() throws SQLException {
        VirtuosoStatement stmt =
            (VirtuosoStatement) getVirtuosoConnection().createStatement();
        stmt.setConnectionHandle(this);
        return stmt;
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#createStatement(int, int)
     */
    public Statement createStatement(int resultSetType, int resultSetConcurrency)
        throws SQLException {
        VirtuosoStatement stmt =
            (VirtuosoStatement) getVirtuosoConnection().createStatement(
                resultSetType,
                resultSetConcurrency);
        stmt.setConnectionHandle(this);
        return stmt;
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#createStatement(int, int, int)
     */
    public Statement createStatement(
        int resultSetType,
        int resultSetConcurrency,
        int resultSetHoldability)
        throws SQLException {
        VirtuosoStatement stmt =
            (VirtuosoStatement) getVirtuosoConnection().createStatement(
                resultSetType,
                resultSetConcurrency,
                resultSetHoldability);
        stmt.setConnectionHandle(this);
        return stmt;
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#prepareCall(java.lang.String)
     */
    public CallableStatement prepareCall(String sql) throws SQLException {
        VirtuosoCallableStatement stmt =
            (VirtuosoCallableStatement) getVirtuosoConnection().prepareCall(sql);
        stmt.setConnectionHandle(this);
        return stmt;
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#prepareCall(java.lang.String, int, int)
     */
    public CallableStatement prepareCall(
        String sql,
        int resultSetType,
        int resultSetConcurrency)
        throws SQLException {
        VirtuosoCallableStatement stmt =
            (VirtuosoCallableStatement) getVirtuosoConnection().prepareCall(
                sql,
                resultSetType,
                resultSetConcurrency);
        stmt.setConnectionHandle(this);
        return stmt;
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#prepareCall(java.lang.String, int, int, int)
     */
    public CallableStatement prepareCall(
        String sql,
        int resultSetType,
        int resultSetConcurrency,
        int resultSetHoldability)
        throws SQLException {
        VirtuosoCallableStatement stmt =
            (VirtuosoCallableStatement) getVirtuosoConnection().prepareCall(
                sql,
                resultSetType,
                resultSetConcurrency,
                resultSetHoldability);
        stmt.setConnectionHandle(this);
        return stmt;
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#prepareStatement(java.lang.String)
     */
    public PreparedStatement prepareStatement(String sql) throws SQLException {
        VirtuosoPreparedStatement stmt =
            (VirtuosoPreparedStatement) getVirtuosoConnection().prepareStatement(sql);
        stmt.setConnectionHandle(this);
        return stmt;
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#prepareStatement(java.lang.String, int)
     */
    public PreparedStatement prepareStatement(String sql, int autoGeneratedKeys)
        throws SQLException {
        VirtuosoPreparedStatement stmt =
            (VirtuosoPreparedStatement) getVirtuosoConnection().prepareStatement(
                sql,
                autoGeneratedKeys);
        stmt.setConnectionHandle(this);
        return stmt;
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#prepareStatement(java.lang.String, int, int)
     */
    public PreparedStatement prepareStatement(
        String sql,
        int resultSetType,
        int resultSetConcurrency)
        throws SQLException {
        VirtuosoPreparedStatement stmt =
            (VirtuosoPreparedStatement) getVirtuosoConnection().prepareStatement(
                sql,
                resultSetType,
                resultSetConcurrency);
        stmt.setConnectionHandle(this);
        return stmt;
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#prepareStatement(java.lang.String, int, int, int)
     */
    public PreparedStatement prepareStatement(
        String sql,
        int resultSetType,
        int resultSetConcurrency,
        int resultSetHoldability)
        throws SQLException {
        VirtuosoPreparedStatement stmt =
            (VirtuosoPreparedStatement) getVirtuosoConnection().prepareStatement(
                sql,
                resultSetType,
                resultSetConcurrency,
                resultSetHoldability);
        stmt.setConnectionHandle(this);
        return stmt;
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#prepareStatement(java.lang.String, int[])
     */
    public PreparedStatement prepareStatement(String sql, int[] columnIndexes)
        throws SQLException {
        VirtuosoPreparedStatement stmt =
            (VirtuosoPreparedStatement) getVirtuosoConnection().prepareStatement(
                sql,
                columnIndexes);
        stmt.setConnectionHandle(this);
        return stmt;
    }

    /* (non-Javadoc)
     * @see java.sql.Connection#prepareStatement(java.lang.String, java.lang.String[])
     */
    public PreparedStatement prepareStatement(String sql, String[] columnNames)
        throws SQLException {
        VirtuosoPreparedStatement stmt =
            (VirtuosoPreparedStatement) getVirtuosoConnection().prepareStatement(
                sql,
                columnNames);
        stmt.setConnectionHandle(this);
        return stmt;
    }

    protected VirtuosoConnection getVirtuosoConnection() throws SQLException {
        if (pooledConnection == null) {
            throw new VirtuosoException(
                "The connection has already been closed.",
                VirtuosoException.CLOSED);
        }
        VirtuosoConnection connection = pooledConnection.getVirtuosoConnection();
        if (connection == null) {
            throw new VirtuosoException(
                "The phisical connection has already been closed.",
                VirtuosoException.CLOSED);
        }
        return connection;
    }

#if JDK_VER >= 16
    //------------------------- JDBC 4.0 -----------------------------------
    /**
     * Constructs an object that implements the <code>Clob</code> interface. The object
     * returned initially contains no data.  The <code>setAsciiStream</code>,
     * <code>setCharacterStream</code> and <code>setString</code> methods of 
     * the <code>Clob</code> interface may be used to add data to the <code>Clob</code>.
     * @return An object that implements the <code>Clob</code> interface
     * @throws SQLException if an object that implements the
     * <code>Clob</code> interface can not be constructed, this method is 
     * called on a closed connection or a database access error occurs.
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this data type
     *
     * @since 1.6
     */
  public Clob createClob() throws SQLException
  {
    return getVirtuosoConnection().createClob();
  }

    /**
     * Constructs an object that implements the <code>Blob</code> interface. The object
     * returned initially contains no data.  The <code>setBinaryStream</code> and
     * <code>setBytes</code> methods of the <code>Blob</code> interface may be used to add data to
     * the <code>Blob</code>.
     * @return  An object that implements the <code>Blob</code> interface
     * @throws SQLException if an object that implements the
     * <code>Blob</code> interface can not be constructed, this method is 
     * called on a closed connection or a database access error occurs.
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this data type
     *
     * @since 1.6
     */
  public Blob createBlob() throws SQLException
  {
    return getVirtuosoConnection().createBlob();
  }
    
    /**
     * Constructs an object that implements the <code>NClob</code> interface. The object
     * returned initially contains no data.  The <code>setAsciiStream</code>,
     * <code>setCharacterStream</code> and <code>setString</code> methods of the <code>NClob</code> interface may
     * be used to add data to the <code>NClob</code>.
     * @return An object that implements the <code>NClob</code> interface
     * @throws SQLException if an object that implements the
     * <code>NClob</code> interface can not be constructed, this method is 
     * called on a closed connection or a database access error occurs.
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this data type
     *
     * @since 1.6
     */
  public NClob createNClob() throws SQLException
  {
    return getVirtuosoConnection().createNClob();
  }

    /**
     * Constructs an object that implements the <code>SQLXML</code> interface. The object
     * returned initially contains no data. The <code>createXmlStreamWriter</code> object and
     * <code>setString</code> method of the <code>SQLXML</code> interface may be used to add data to the <code>SQLXML</code>
     * object.
     * @return An object that implements the <code>SQLXML</code> interface
     * @throws SQLException if an object that implements the <code>SQLXML</code> interface can not
     * be constructed, this method is 
     * called on a closed connection or a database access error occurs.
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this data type
     * @since 1.6
     */
  public SQLXML createSQLXML() throws SQLException
  {
    return getVirtuosoConnection().createSQLXML();
  }

        /**
	 * Returns true if the connection has not been closed and is still valid.  
	 * The driver shall submit a query on the connection or use some other 
	 * mechanism that positively verifies the connection is still valid when 
	 * this method is called.
	 * <p>
	 * The query submitted by the driver to validate the connection shall be 
	 * executed in the context of the current transaction.
	 * 
	 * @param timeout -		The time in seconds to wait for the database operation 
	 * 						used to validate the connection to complete.  If 
	 * 						the timeout period expires before the operation 
	 * 						completes, this method returns false.  A value of 
	 * 						0 indicates a timeout is not applied to the 
	 * 						database operation.
	 * <p>
	 * @return true if the connection is valid, false otherwise
         * @exception SQLException if the value supplied for <code>timeout</code> 
         * is less then 0
         * @since 1.6
	 * <p>
	 * @see java.sql.DatabaseMetaData#getClientInfoProperties
	 */
  public boolean isValid(int timeout) throws SQLException
  {
    return getVirtuosoConnection().isValid(timeout);
  }

	/**
	 * Sets the value of the client info property specified by name to the 
	 * value specified by value.  
	 * <p>
	 * Applications may use the <code>DatabaseMetaData.getClientInfoProperties</code> 
	 * method to determine the client info properties supported by the driver 
	 * and the maximum length that may be specified for each property.
	 * <p>
	 * The driver stores the value specified in a suitable location in the 
	 * database.  For example in a special register, session parameter, or 
	 * system table column.  For efficiency the driver may defer setting the 
	 * value in the database until the next time a statement is executed or 
	 * prepared.  Other than storing the client information in the appropriate 
	 * place in the database, these methods shall not alter the behavior of 
	 * the connection in anyway.  The values supplied to these methods are 
	 * used for accounting, diagnostics and debugging purposes only.
	 * <p>
	 * The driver shall generate a warning if the client info name specified 
	 * is not recognized by the driver.
	 * <p>
	 * If the value specified to this method is greater than the maximum 
	 * length for the property the driver may either truncate the value and 
	 * generate a warning or generate a <code>SQLClientInfoException</code>.  If the driver 
	 * generates a <code>SQLClientInfoException</code>, the value specified was not set on the 
	 * connection.
	 * <p>
	 * The following are standard client info properties.  Drivers are not 
	 * required to support these properties however if the driver supports a 
	 * client info property that can be described by one of the standard 
	 * properties, the standard property name should be used.
	 * <p>
	 * <ul>
	 * <li>ApplicationName	-	The name of the application currently utilizing 
	 * 				the connection</li>
	 * <li>ClientUser	-	The name of the user that the application using 
	 * 				the connection is performing work for.  This may 
	 * 				not be the same as the user name that was used 
	 * 				in establishing the connection.</li>
	 * <li>ClientHostname	-	The hostname of the computer the application 
	 * 				using the connection is running on.</li>
	 * </ul>
	 * <p>
	 * @param name		The name of the client info property to set 
	 * @param value		The value to set the client info property to.  If the 
	 * 			value is null, the current value of the specified
	 * 			property is cleared.
	 * <p>
	 * @throws	SQLClientInfoException if the database server returns an error while 
	 * 		setting the client info value on the database server or this method 
         * is called on a closed connection
	 * <p>
	 * @since 1.6	
	 */
  public void setClientInfo(String name, String value) throws SQLClientInfoException
  {
    try {
      getVirtuosoConnection().setClientInfo(name, value);
    } catch(SQLException ex) {
	throw new SQLClientInfoException( ex.getMessage(), ex.getSQLState(), 
			ex.getErrorCode(), null);
    }
  }
	
   /**
     * Sets the value of the connection's client info properties.  The 
     * <code>Properties</code> object contains the names and values of the client info 
     * properties to be set.  The set of client info properties contained in 
     * the properties list replaces the current set of client info properties 
     * on the connection.  If a property that is currently set on the 
     * connection is not present in the properties list, that property is 
     * cleared.  Specifying an empty properties list will clear all of the 
     * properties on the connection.  See <code>setClientInfo (String, String)</code> for 
     * more information.
     * <p>  
     * If an error occurs in setting any of the client info properties, a 
     * <code>SQLClientInfoException</code> is thrown. The <code>SQLClientInfoException</code>
     * contains information indicating which client info properties were not set. 
     * The state of the client information is unknown because 
     * some databases do not allow multiple client info properties to be set 
     * atomically.  For those databases, one or more properties may have been 
     * set before the error occurred.
     * <p>
     * 
     * @param properties the list of client info properties to set
     * <p>
     * @see java.sql.Connection#setClientInfo(String, String) setClientInfo(String, String)
     * @since 1.6
     * <p>
     * @throws SQLClientInfoException if the database server returns an error while 
     * 		setting the clientInfo values on the database server or this method 
     * is called on a closed connection 
     * <p>
     */
  public void setClientInfo(Properties properties) throws SQLClientInfoException
  {
    try {
      getVirtuosoConnection().setClientInfo(properties);
    } catch(SQLException ex) {
	throw new SQLClientInfoException( ex.getMessage(), ex.getSQLState(), 
			ex.getErrorCode(), null);
    }
  }
	
	/**
	 * Returns the value of the client info property specified by name.  This 
	 * method may return null if the specified client info property has not 
	 * been set and does not have a default value.  This method will also 
	 * return null if the specified client info property name is not supported 
	 * by the driver.
	 * <p>
	 * Applications may use the <code>DatabaseMetaData.getClientInfoProperties</code>
	 * method to determine the client info properties supported by the driver.
	 * <p>
	 * @param name		The name of the client info property to retrieve
	 * <p>
	 * @return 			The value of the client info property specified
	 * <p>
	 * @throws SQLException		if the database server returns an error when 
	 * 							fetching the client info value from the database 
         *or this method is called on a closed connection
	 * <p>
	 * @since 1.6
	 * <p>
	 * @see java.sql.DatabaseMetaData#getClientInfoProperties
	 */
  public String getClientInfo(String name) throws SQLException
  {
    return getVirtuosoConnection().getClientInfo(name);
  }
	
	/**
	 * Returns a list containing the name and current value of each client info 
	 * property supported by the driver.  The value of a client info property 
	 * may be null if the property has not been set and does not have a 
	 * default value.
	 * <p>
	 * @return	A <code>Properties</code> object that contains the name and current value of 
	 * 			each of the client info properties supported by the driver.  
	 * <p>
	 * @throws 	SQLException if the database server returns an error when 
	 * 			fetching the client info values from the database
         * or this method is called on a closed connection
	 * <p>
	 * @since 1.6
	 */
  public Properties getClientInfo() throws SQLException
  {
    return getVirtuosoConnection().getClientInfo();
  }

/**
  * Factory method for creating Array objects.
  *<p>
  * <b>Note: </b>When <code>createArrayOf</code> is used to create an array object 
  * that maps to a primitive data type, then it is implementation-defined 
  * whether the <code>Array</code> object is an array of that primitive 
  * data type or an array of <code>Object</code>.
  * <p>
  * <b>Note: </b>The JDBC driver is responsible for mapping the elements 
  * <code>Object</code> array to the default JDBC SQL type defined in 
  * java.sql.Types for the given class of <code>Object</code>. The default 
  * mapping is specified in Appendix B of the JDBC specification.  If the
  * resulting JDBC type is not the appropriate type for the given typeName then 
  * it is implementation defined whether an <code>SQLException</code> is 
  * thrown or the driver supports the resulting conversion.
  *
  * @param typeName the SQL name of the type the elements of the array map to. The typeName is a
  * database-specific name which may be the name of a built-in type, a user-defined type or a standard  SQL type supported by this database. This
  *  is the value returned by <code>Array.getBaseTypeName</code>
  * @param elements the elements that populate the returned object
  * @return an Array object whose elements map to the specified SQL type
  * @throws SQLException if a database error occurs, the JDBC type is not
  *  appropriate for the typeName and the conversion is not supported, the typeName is null or this method is called on a closed connection
  * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this data type
  * @since 1.6
  */
  public Array createArrayOf(String typeName, Object[] elements) throws SQLException
  {
    return getVirtuosoConnection().createArrayOf(typeName, elements);
  }

/**
  * Factory method for creating Struct objects.
  *
  * @param typeName the SQL type name of the SQL structured type that this <code>Struct</code> 
  * object maps to. The typeName is the name of  a user-defined type that
  * has been defined for this database. It is the value returned by
  * <code>Struct.getSQLTypeName</code>.
 
  * @param attributes the attributes that populate the returned object
  *  @return a Struct object that maps to the given SQL type and is populated with the given attributes
  * @throws SQLException if a database error occurs, the typeName is null or this method is called on a closed connection
  * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this data type
  * @since 1.6
  */
  public Struct createStruct(String typeName, Object[] attributes) throws SQLException
  {
    return getVirtuosoConnection().createStruct(typeName, attributes);
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
  public <T> T unwrap(java.lang.Class<T> iface) throws java.sql.SQLException
  {
    return getVirtuosoConnection().unwrap(iface);
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
  public boolean isWrapperFor(java.lang.Class<?> iface) throws java.sql.SQLException
  {
    return getVirtuosoConnection().isWrapperFor(iface);
  }

  
#endif

}
