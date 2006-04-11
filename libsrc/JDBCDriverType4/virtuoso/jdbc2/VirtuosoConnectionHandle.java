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
}
