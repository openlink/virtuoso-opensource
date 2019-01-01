/*
 *  $Id:$
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

package virtuoso.jena.driver;


import java.sql.*;
import javax.transaction.xa.*;

import org.apache.jena.graph.impl.*;
import org.apache.jena.query.ReadWrite;
import org.apache.jena.shared.*;

import static virtuoso.jena.driver.VirtIsolationLevel.*;

public class VirtTransactionHandler extends TransactionHandlerBase implements XAResource {

    private VirtGraph graph = null;
    private Boolean m_transactionsSupported = null;
    private ReadWrite readWrite;

    protected ReadWrite getReadWrite() {
        return this.readWrite;
    }

    public VirtTransactionHandler(VirtGraph _graph) {
        super();
        this.graph = _graph;
    }

    public VirtIsolationLevel getIsolationLevel() {
        try {
            Connection c = graph.getConnection();
            int i = c.getTransactionIsolation();
            switch (i){
                case Connection.TRANSACTION_READ_UNCOMMITTED:  return READ_UNCOMMITTED;
                case Connection.TRANSACTION_READ_COMMITTED:    return READ_COMMITTED;
                case Connection.TRANSACTION_REPEATABLE_READ:   return REPEATABLE_READ;
                case Connection.TRANSACTION_SERIALIZABLE:      return SERIALIZABLE;
                default:
                    return NONE;
            }
        } catch (SQLException e) {
            throw new JenaException("getIsolationLevel failed: ", e);
        }
    }

    public void setIsolationLevel(VirtIsolationLevel level) {
        try {
            Connection c = graph.getConnection();
            if (level == NONE)
                c.setTransactionIsolation(Connection.TRANSACTION_NONE);
            else if (level == READ_UNCOMMITTED)
                c.setTransactionIsolation(Connection.TRANSACTION_READ_UNCOMMITTED);
            else if (level == READ_COMMITTED)
                c.setTransactionIsolation(Connection.TRANSACTION_READ_COMMITTED);
            else if (level == REPEATABLE_READ)
                c.setTransactionIsolation(Connection.TRANSACTION_REPEATABLE_READ);
            else if (level == SERIALIZABLE)
                c.setTransactionIsolation(Connection.TRANSACTION_SERIALIZABLE);

        } catch (SQLException e) {
            throw new JenaException("setIsolationLevel failed: ", e);
        }
    }


    public boolean transactionsSupported() {
        if (m_transactionsSupported != null) {
            return (m_transactionsSupported.booleanValue());
        }

        try {
            Connection c = graph.getConnection();
            if (c != null) {
                m_transactionsSupported = new Boolean(c.getMetaData().supportsMultipleTransactions());
                return (m_transactionsSupported.booleanValue());
            }
        } catch (Exception e) {
            throw new JenaException(e);
        }
        return (false);
    }

    private XAResource checkXA() {
        if (!graph.isXA)
            throw new JenaException("XA Transaction is supported only for XAConnections");
        return graph.getXAResource();
    }

    private void checkNotXA(String cmd) {
        if (graph.isXA)
            throw new JenaException("Method '" + cmd + "' doesn't work with XAConnection");
    }

    public boolean transactionsXASupported() {
        return graph.isXA;
    }

    public void start(Xid xid, int i) throws XAException {
        XAResource xa = checkXA();
        xa.start(xid, i);
    }

    public void commit(Xid xid, boolean flag) throws XAException {
        XAResource xa = checkXA();
        xa.commit(xid, flag);
        if (graph.resetBNodesDictAfterCommit)
            graph.dropBNodesDict();
    }

    public void end(Xid xid, int i) throws XAException {
        XAResource xa = checkXA();
        xa.end(xid, i);
        if (graph.resetBNodesDictAfterCommit)
            graph.dropBNodesDict();
    }

    public void forget(Xid xid) throws XAException {
        XAResource xa = checkXA();
        xa.forget(xid);
        if (graph.resetBNodesDictAfterCommit)
            graph.dropBNodesDict();
    }

    public int prepare(Xid xid) throws XAException {
        XAResource xa = checkXA();
        return xa.prepare(xid);
    }

    public Xid[] recover(int i) throws XAException {
        XAResource xa = checkXA();
        return xa.recover(i);
    }

    public void rollback(Xid xid) throws XAException {
        XAResource xa = checkXA();
        xa.rollback(xid);
        if (graph.resetBNodesDictAfterCommit)
            graph.dropBNodesDict();
    }

    public boolean setTransactionTimeout(int i) throws XAException {
        XAResource xa = checkXA();
        return xa.setTransactionTimeout(i);
    }

    public int getTransactionTimeout() throws XAException {
        XAResource xa = checkXA();
        return xa.getTransactionTimeout();
    }

    public boolean isSameRM(XAResource tr) throws XAException {
        XAResource xa = checkXA();
        if (tr instanceof VirtTransactionHandler) {
            return xa.isSameRM(((VirtTransactionHandler) tr).checkXA());
        } else {
            return xa.isSameRM(tr);
        }
    }


    public void begin() {
        checkNotXA("begin");
        if (transactionsSupported()) {
            try {
                Connection c = graph.getConnection();
                if (c.getAutoCommit()) {
                    c.setAutoCommit(false);
                }
                this.readWrite = ReadWrite.READ;
            } catch (SQLException e) {
                throw new JenaException("Transaction begin failed: ", e);
            }
        } else {
            notSupported("begin transaction");
        }
    }

    public void begin(ReadWrite _readWrite) {
        checkNotXA("begin");
        if (transactionsSupported()) {
            try {
                Connection c = graph.getConnection();
                if (c.getAutoCommit()) {
                    c.setAutoCommit(false);
                }
                this.readWrite = _readWrite;
            } catch (SQLException e) {
                throw new JenaException("Transaction begin failed: ", e);
            }
        } else {
            notSupported("begin transaction");
        }
    }

    public void abort() {
        checkNotXA("abort");
        if (transactionsSupported()) {
            try {
                Connection c = graph.getConnection();
                c.rollback();
                c.setAutoCommit(true);
                if (graph.resetBNodesDictAfterCommit)
                    graph.dropBNodesDict();
            } catch (SQLException e) {
                throw new JenaException("Transaction rollback failed: ", e);
            }
        } else {
            notSupported("abort transaction");
        }
    }

    public void commit() {
        checkNotXA("commit");
        if (transactionsSupported()) {
            try {
                Connection c = graph.getConnection();
                c.commit();
                c.setAutoCommit(true);
                if (graph.resetBNodesDictAfterCommit)
                    graph.dropBNodesDict();
            } catch (SQLException e) {
                throw new JenaException("Transaction commit failed: ", e);
            }
        } else {
            notSupported("commit transaction");
        }
    }

    private void notSupported(String opName) {
        throw new UnsupportedOperationException(opName);
    }

}
