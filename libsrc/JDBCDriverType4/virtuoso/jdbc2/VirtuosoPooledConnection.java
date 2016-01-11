/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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

import java.sql.Connection;
import java.sql.Statement;
import java.sql.PreparedStatement;
import java.sql.CallableStatement;
import java.sql.DatabaseMetaData;
import java.sql.SQLWarning;
import java.sql.SQLException;
import java.util.*;
import javax.sql.PooledConnection;
import javax.sql.ConnectionEventListener;
import javax.sql.ConnectionEvent;
#if JDK_VER >= 16
import javax.sql.StatementEventListener;
#endif

/**
 * A PooledConnection object is a connection object that provides hooks
 * for connection pool management. A PooledConnection object represents
 * a physical connection to a data source.
**/


public class VirtuosoPooledConnection implements PooledConnection, Cloneable {
  private LinkedList<ConnectionEventListener> listeners = null;
  private ConnectionWrapper connWrapper = null;
  private VirtuosoConnection conn;
  private boolean sendEvent = true;
  protected String connURL;
  protected int hashConnURL;
  protected long tmClosed;

  protected VirtuosoPooledConnection(VirtuosoConnection _conn, String _connURL)
  {
    conn = _conn;
    conn.pooled_connection = this;
    connURL = _connURL;
    hashConnURL = connURL.hashCode();
    tmClosed = System.currentTimeMillis();
  }

  protected VirtuosoPooledConnection(VirtuosoConnection _conn, String _connURL, VirtuosoConnectionPoolDataSource listener) {
    this(_conn, _connURL);
    init(listener);
  }

  protected void init(VirtuosoConnectionPoolDataSource listener) {
    listeners = new LinkedList<ConnectionEventListener>();
    addConnectionEventListener(listener);
    conn.pooled_connection = this;
  }


  public synchronized void finalize () throws Throwable {
    try {
      close();
    } catch(Exception e) { }
    listeners.clear();
  }


  protected synchronized Object clone() {
    try {
      VirtuosoPooledConnection v = (VirtuosoPooledConnection)super.clone();
      v.listeners = null;
      v.connWrapper = null;
      v.conn = conn;
      v.sendEvent = true;
      v.connURL = connURL;
      v.hashConnURL = hashConnURL;
      v.tmClosed = tmClosed;
      return v;
    } catch (CloneNotSupportedException e) {
      // this shouldn't happen, since we are Cloneable
      throw new InternalError();
    }
  }


  protected VirtuosoPooledConnection reuse() {
    connWrapper.reset();
    VirtuosoPooledConnection pconn = (VirtuosoPooledConnection)this.clone();
    listeners.clear();
    this.connWrapper = null;
    this.conn.pooled_connection = null;
    this.conn.xa_connection = null;
    this.conn = null;
    this.connURL = null;
    pconn.tmClosed = System.currentTimeMillis();
    pconn.conn.pooled_connection = pconn;
    pconn.conn.clearFutures();
    return pconn;
  }

/*********************** PooledConnection ***************************************/
  /**
   * Registers the given event listener so that it will be notified
   * when an event occurs on this <code>PooledConnection</code> object.
   *
   * @param parm listener a component, usually the connection pool manager,
   *        that has implemented the
   *        <code>ConnectionEventListener</code> interface and wants to be
   *        notified when the connection is closed or has an error
   * @see #removeConnectionEventListener
   */
  public void addConnectionEventListener(ConnectionEventListener parm) {
    synchronized(listeners) {
      listeners.add(parm);
    }
  }


  /**
   * Removes the given event listener from the list of components that
   * will be notified when an event occurs on this
   * <code>PooledConnection</code> object.
   *
   * @param parm listener a component, usually the connection pool manager,
   *        that has implemented the
   *        <code>ConnectionEventListener</code> interface and
   *        been registered with this <code>PooledConnection</code> object as
   *        a listener
   * @see #addConnectionEventListener
   */
  public void removeConnectionEventListener(ConnectionEventListener parm) {
    synchronized(listeners) {
      listeners.remove(parm);
    }
  }


  /**
   * Closes the physical connection that this <code>PooledConnection</code>
   * object represents.  An application never calls this method directly;
   * it is called by the connection pool module, or manager.
   * <P>
   * See the {@link PooledConnection interface description} for more
   * information.
   *
   * @exception SQLException if a database access error occurs
   */
  public synchronized void close() throws java.sql.SQLException {
    SQLException ex = null;
    if (connWrapper != null) {
      try {
        connWrapper.closeAll();
      } catch(SQLException e) {
        ex = e;
      }
      connWrapper = null;
    }
    if (conn != null) {
      if (!conn.isClosed()) {
        try {
          conn.close();
        } catch(SQLException e) {
          ex = e;
        }
      }
      conn.pooled_connection = null;
      conn.xa_connection = null;
    }
    conn = null;
    sendErrorEvent(new VirtuosoException("Physical Connection is closed", VirtuosoException.OK));
    if (ex != null)
      throw ex;
  }


  /**
   * Close all the Statement objects that have been opened by this
   * PooledConnection object.
   *
   * @exception  java.sql.SQLException
   *             if a database-access error occurs
   *
  **/
  @Deprecated
  public void closeAll() throws java.sql.SQLException {
  }


  /**
   * Create an object handle for this physical connection.
   * The object returned is a temporary handle used by application code
   * to refer to a physical connection that is being pooled.
   *
   * @return  a Connection object
   *
   * @exception  java.sql.SQLException
   *             if a database-access error occurs
   *
  **/
  public Connection getConnection() throws java.sql.SQLException {
    if (conn == null) {
       SQLException ex = (SQLException)(new VirtuosoException("Physical Connection is closed", VirtuosoException.OK));
       sendErrorEvent(ex);
       throw ex;
    }
    if (connWrapper != null) {
      sendEvent = false;
      connWrapper.reset();
      connWrapper.close();
      sendEvent = true;
    }
    connWrapper = new ConnectionWrapper(conn, this);
    return connWrapper;
  }


  public VirtuosoConnection getVirtuosoConnection() throws java.sql.SQLException
  {
    if (conn == null) {
       SQLException ex = (SQLException)(new VirtuosoException("Connection is closed", VirtuosoException.OK));
       sendErrorEvent(ex);
       throw ex;
    }
    return conn;
  }

  public boolean isConnectionLost(int timeout_sec)
  {
    if (conn == null) {
       return true;
    }
    return conn.isClosed() || conn.isConnectionLost(timeout_sec);
  }

#if JDK_VER >= 16
	/**
	 * Registers a <code>StatementEventListener</code> with this <code>PooledConnection</code> object.  Components that
	 * wish to be notified when  <code>PreparedStatement</code>s created by the
         * connection are closed or are detected to be invalid may use this method
         * to register a <code>StatementEventListener</code> with this <code>PooledConnection</code> object.
	 * <p>
	 * @param listener	an component which implements the <code>StatementEventListener</code>
	 *		interface that is to be registered with this <code>PooledConnection</code> object
	 * <p>
	 * @since 1.6
	 */
  public void addStatementEventListener(StatementEventListener listener)
  {
//??TODO    errx_Method_XX_not_yet_implemented, "addStatementEventListener(listener)");
  }

	/**
	 * Removes the specified <code>StatementEventListener</code> from the list of
	 * components that will be notified when the driver detects that a
	 * <code>PreparedStatement</code> has been closed or is invalid.
	 * <p>
	 * @param listener	the component which implements the
	 *	<code>StatementEventListener</code> interface that was previously
	 *	registered with this <code>PooledConnection</code> object
	 * <p>
	 * @since 1.6
	 */
  public void removeStatementEventListener(StatementEventListener listener)
  {
//??TODO    errx_Method_XX_not_yet_implemented, "removeStatementEventListener(listener)");
  }
#endif


  protected boolean isClosed() {
    return conn == null;
  }


  protected void sendCloseEvent() {
     if (!sendEvent)
       return;

     if (listeners == null)
        return;

     ConnectionEvent ev = new ConnectionEvent((PooledConnection)this);
     LinkedList tmpList;

     synchronized(listeners) {
       tmpList = (LinkedList)listeners.clone();
     }
     for (Iterator i = tmpList.iterator(); i.hasNext(); )
         ((ConnectionEventListener)(i.next())).connectionClosed(ev);
     tmpList.clear();
  }


  protected void sendErrorEvent(SQLException ex) {
     if (listeners == null)
        return;

     ConnectionEvent ev = new ConnectionEvent((PooledConnection)this, ex);
     LinkedList tmpList;

     synchronized(listeners) {
       tmpList = (LinkedList)listeners.clone();
     }

     for (Iterator i = tmpList.iterator(); i.hasNext(); )
         ((ConnectionEventListener)(i.next())).connectionErrorOccurred(ev);
     tmpList.clear();
  }

}
