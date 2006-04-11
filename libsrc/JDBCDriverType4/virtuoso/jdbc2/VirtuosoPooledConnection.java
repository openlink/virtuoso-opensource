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

import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;
import javax.sql.ConnectionEvent;
import javax.sql.ConnectionEventListener;
import javax.sql.PooledConnection;

public class VirtuosoPooledConnection implements PooledConnection {

    private VirtuosoDataSource ds;
    private VirtuosoConnection connection;
    private VirtuosoConnectionHandle connectionHandle;
    private ArrayList listeners;

    VirtuosoPooledConnection(VirtuosoDataSource ds, VirtuosoConnection connection) {
        this.ds = ds;
        this.connection = connection;
        this.connection.pooled_connection = this;
        this.listeners = new ArrayList();
    }

    public Connection getConnection() throws SQLException {
        synchronized (this) {
            if (connectionHandle != null) {
                connectionHandle.close();
            }
            connectionHandle = new VirtuosoConnectionHandle(this);
            return connectionHandle;
        }
    }

    public void close() throws SQLException {
        synchronized (this) {
            if(connectionHandle != null) {
                connectionHandle.close();
                connectionHandle = null;
            }
            if (connection != null) {
                connection.close();
                connection = null;
            }
        }
    }

    public void addConnectionEventListener(ConnectionEventListener listener) {
        synchronized (listeners) {
            listeners.add(listener);
        }
    }

    public void removeConnectionEventListener(ConnectionEventListener listener) {
        synchronized(listeners) {
            listeners.remove(listener);
        }
    }

    void notify_closed() {
        ConnectionEvent evt = new ConnectionEvent(this);
        Object[] listeners2;
        synchronized (listeners) {
            listeners2 = listeners.toArray();
        }
        for (int i = 0; i < listeners2.length; i++) {
            ((ConnectionEventListener) listeners2[i]).connectionClosed(evt);
        }
    }

    void notify_error(VirtuosoException e) {
        ConnectionEvent evt = new ConnectionEvent(this, e);
        Object[] listeners2;
        synchronized (listeners) {
            listeners2 = listeners.toArray();
        }
        for (int i = 0; i < listeners2.length; i++) {
            ((ConnectionEventListener) listeners2[i]).connectionErrorOccurred(evt);
        }
    }

    VirtuosoDataSource getVirtuosoDataSource() {
        return ds;
    }

    VirtuosoConnection getVirtuosoConnection() {
        return connection;
    }
}
