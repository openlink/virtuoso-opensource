/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

import java.lang.reflect.*;
import java.io.PrintWriter;
import java.sql.SQLException;
import java.sql.Connection;
import java.io.Serializable;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.NoSuchElementException;
import java.util.Properties;
import java.util.Iterator;
import java.util.ListIterator;
import java.util.List;
import java.util.TreeSet;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import javax.sql.*;
import javax.naming.*;

public class VirtuosoConnectionPoolDataSource
    extends VirtuosoDataSource
    implements ConnectionPoolDataSource, ConnectionEventListener {

    protected final static String n_initialPoolSize = "initialPoolSize";
    protected final static String n_minPoolSize = "minPoolSize";
    protected final static String n_maxPoolSize = "maxPoolSize";
    protected final static String n_maxIdleTime = "maxIdleTime";
    protected final static String n_propertyCycle = "propertyCycle";
    protected final static String n_maxStatements = "maxStatements";

    public int initialPoolSize = 0;
    public volatile int minPoolSize = 0;
    public volatile int maxPoolSize = 0;
    public volatile int maxIdleTime = 0;
    public volatile int propertyCycle = 0;
    public volatile int maxStatements = 0;

    private ConnCache connPool;
    private volatile boolean isInitialized = false;
    private volatile boolean isClosed = false;
    private VirtuosoPoolStatistic stat;
    private Object  initLock ;
    private TreeSet<Object> propQueue;
    private long  propEnforceTime = 0;



  public VirtuosoConnectionPoolDataSource() {
    dataSourceName = "VirtuosoConnectionPoolDataSourceName";
    initLock = new Object();
    stat = new VirtuosoPoolStatistic();
    connPool = new ConnCache(this);
    propQueue = new TreeSet<Object>( new Comparator<Object>() {
          public int compare(Object a, Object b) {
            long a_time = ((NewProperty)a).enforceTime;
            long b_time = ((NewProperty)b).enforceTime;
            if (a_time == b_time)
              return 0;
            else if (a_time > b_time)
              return +1;
            else
              return -1;
          }
        });
  }


  protected void checkPool() {
    if (isClosed)
       return;

    connPool.checkPool();
  }


  protected void checkPropQueue() {
    if (isClosed || propEnforceTime == 0)
       return;

    long curTime = System.currentTimeMillis();
    NewProperty prop;
    synchronized(propQueue) {
      while(propEnforceTime != 0 && propEnforceTime < curTime) {
        try {
          prop = (NewProperty)(propQueue.first());
        } catch (NoSuchElementException e) {
          propEnforceTime = 0;
          break;
        }
        propQueue.remove(prop);
        try {
          prop.fld.setInt(this, prop.arg);
        } catch (Exception e) {
          //?? System.out.println(e);
        }
        try {
          prop = (NewProperty)(propQueue.first());
          propEnforceTime = prop.enforceTime;
        } catch (NoSuchElementException e) {
          propEnforceTime = 0;
          break;
        }
      }
    }
  }


  /**
   * Return the cache statistics for the VirtuosoConnectionPoolDataSource
   *
   * @return  the cache statistics
   *
  **/
  public synchronized VirtuosoPoolStatistic get_statistics() {
    VirtuosoPoolStatistic v = (VirtuosoPoolStatistic)stat.clone();
    v.setCacheParam(dataSourceName, connPool.cacheSize.get(),
        connPool.unUsed.size(), connPool.in_Use.size());
    return v;
  }

  /**
   * Return an array of the cache statistics for the all created VirtuosoConnectionPoolDataSources
   *
   * @return  the array of cache statistics
   *
  **/
  public synchronized VirtuosoPoolStatistic[] getAll_statistics() {
    return VirtuosoPoolManager.getInstance().getAll_statistics();
  }

  /**
   * Physically close all the pooled connections in the cache and free all
   * the resources
   *
   * @exception  java.sql.SQLException
   *             if a database-access error occurs
   *
  **/
  public void close() throws SQLException {
    if (isClosed)
      return;

    isClosed = true;
    connPool.clear();
    initLock = null;
    propQueue.clear();
  }


//==================== interface ConnectionEventListener
  /**
   * Invoked when the application calls close() on its representation of
   * the connection.
   *
   * @param event an event object describing the source of the event
  **/
  public void connectionClosed(ConnectionEvent event) {
    try {
      Object source = event.getSource();
      if (source instanceof VirtuosoPooledConnection)
        connPool.reusePooledConnection((VirtuosoPooledConnection)event.getSource());
    } catch(SQLException e) { }
  }


  /**
   * Invoked when a fatal connection error occurs, just before an SQLException
   * is thrown to the application.
   *
   * @param event an event object describing the source of the event
  **/
  public void connectionErrorOccurred(ConnectionEvent event) {
    try {
      Object source = event.getSource();
      if (source instanceof VirtuosoPooledConnection)
        connPool.closePooledConnection((VirtuosoPooledConnection)event.getSource());
    } catch(SQLException e) { }
  }


//==================== interface Referenceable
  protected void  addProperties(Reference ref) {
    super.addProperties(ref);

    //Pool Specific
    ref.add(new StringRefAddr(VirtuosoConnectionPoolDataSource.n_minPoolSize, String.valueOf(minPoolSize)));
    ref.add(new StringRefAddr(VirtuosoConnectionPoolDataSource.n_maxPoolSize, String.valueOf(maxPoolSize)));
    ref.add(new StringRefAddr(VirtuosoConnectionPoolDataSource.n_initialPoolSize, String.valueOf(initialPoolSize)));
    ref.add(new StringRefAddr(VirtuosoConnectionPoolDataSource.n_maxIdleTime, String.valueOf(maxIdleTime)));
    ref.add(new StringRefAddr(VirtuosoConnectionPoolDataSource.n_propertyCycle, String.valueOf(propertyCycle)));
    ref.add(new StringRefAddr(VirtuosoConnectionPoolDataSource.n_maxStatements, String.valueOf(maxStatements)));
  }


  public Reference getReference() throws NamingException {
     Reference ref = new Reference(getClass().getName(), "virtuoso.jdbc4.VirtuosoDataSourceFactory", null);
     addProperties(ref);
     return ref;
  }


  /**
   * Fills the cache with PooledConnections for later use.
   * Ignored if the MinPoolSize is 0.
   * It is usually called when the OPLConnectionPoolDataSource is created
   * via JNDI calls.
   *
   * @exception  java.sql.SQLException
   *             if a error occurs
  **/
  public void fill() throws java.sql.SQLException {
    check_close();
    Properties info = createConnProperties();
    String connKey = create_url_key(create_url(), info);

    synchronized(initLock) {
      if (!isInitialized) {
        isInitialized = true;
        if (initialPoolSize == 0)
          initialPoolSize = minPoolSize;
        if (initialPoolSize != 0) {
          OpenHelper initThread = new OpenHelper(initialPoolSize, info);
          initThread.start();
          try {
            initThread.join();
          }
          catch (InterruptedException e) {}
        }
        VirtuosoPoolManager.getInstance().addPool(this);
      }

    }
  }

  /**
   * Attempt to get a database connection from the pool or
   * to establish a database connection .
   *
   * @return   a Connection to the database
   *
   * @exception  java.sql.SQLException
   *             if a database-access error occurs
  **/
  public Connection getConnection() throws java.sql.SQLException {
    return getPooledConnection().getConnection();
  }


  /**
   * Attempt to get a database connection from the pool or
   * to establish a database connection .
   *
   * @param   user       the database user on whose behalf the Connection is being made
   * @param   password   the user's password
   *
   * @return   a Connection to the database
   *
   * @exception  java.sql.SQLException
   *             if a database-access error occurs
  **/
  public Connection getConnection(String user, String password) throws java.sql.SQLException {
    return getPooledConnection(user, password).getConnection();
  }

  /**
   * Attempt to establish a database connection.
   *
   * @return   a PooledConnection to the database
   *
   * @exception  java.sql.SQLException
   *             if a database-access error occurs
  **/
  public PooledConnection getPooledConnection() throws java.sql.SQLException {
    return getPooledConnection(null, null);
  }


  /**
   * Attempts to establish a physical database connection that can
   * be used as a pooled connection.
   *
   * @param   user       the database user on whose behalf the Connection is being made
   * @param   password   the user's password
   *
   * @return   a PooledConnection to the database
   *
   * @exception  java.sql.SQLException
   *             if a database-access error occurs
  **/
  public PooledConnection getPooledConnection(String _user, String _password)
      throws java.sql.SQLException
  {
    check_close();
    String conn_url = create_url();
    Properties info = createConnProperties();

    if (_user != null)
        info.setProperty("user", _user);
    if (_password != null)
        info.setProperty("password", _password);

    String connKey = create_url_key(conn_url, info);
    Connection conn;

    synchronized(initLock) {
      if (!isInitialized) {
        isInitialized = true;
        if (initialPoolSize == 0)
          initialPoolSize = minPoolSize;
        if (initialPoolSize != 0) {
          OpenHelper initThread = new OpenHelper(initialPoolSize, info);
          initThread.start();
          try {
             initThread.join();
          } catch(InterruptedException e) {}
        }
        VirtuosoPoolManager.getInstance().addPool(this);
      }
    }

    return connPool.getPooledConnection(info, connKey, conn_url);

  }


  // get & set methods
  // PooledSpecific
  /**
   * Get the minimum number of physical connections
   * the pool will keep available at all times. Zero ( 0 ) indicates that
   * connections will be created as needed.
   *
   * @return   the minimum number of physical connections
   *
  **/
  public int getMinPoolSize() {
    return minPoolSize;
  }

  /**
   * Set the number of physical connections the pool should keep available
   * at all times. Zero ( 0 ) indicates that connections should be created
   * as needed
   * The default value is 0 .
   *
   * @param   parm a minimum number of physical connections
   *
   * @exception  java.sql.SQLException if an error occurs
   *
  **/
  public void setMinPoolSize(int parm) throws SQLException
  {
    try {
      Field fld = getClass().getField(this.n_minPoolSize);
      setField(fld, parm);
    } catch (Exception e) {
      throw new VirtuosoException("Error: "+e.toString(), VirtuosoException.OK);
    }
  }



  /**
   * Get the maximum number of physical connections
   * the pool will be able contain. Zero ( 0 ) indicates no maximum size.
   *
   * @return   the maximum number of physical connections
   *
  **/
  public int getMaxPoolSize() {
    return maxPoolSize;
  }

  /**
   * Set the maximum number of physical conections that the pool should contain.
   * Zero ( 0 ) indicates no maximum size.
   * The default value is 0 .
   *
   * @param   parm a maximum number of physical connections
   *
   * @exception  java.sql.SQLException if an error occurs
   *
  **/
  public void setMaxPoolSize(int parm) throws SQLException
  {
    try {
      Field fld = getClass().getField(this.n_maxPoolSize);
      setField(fld, parm);
    } catch (Exception e) {
      throw new VirtuosoException("Error: "+e.toString(), VirtuosoException.OK);
    }
  }


  /**
   * Get the number of physical connections the pool
   * will contain when it is created
   *
   * @return   the number of physical connections
   *
  **/
  public int getInitialPoolSize() {
    return initialPoolSize;
  }

  /**
   * Set the number of physical connections the pool
   * should contain when it is created
   *
   * @param   parm a number of physical connections
   *
   * @exception  java.sql.SQLException if an error occurs
   *
  **/
  public void setInitialPoolSize(int parm) throws SQLException
  {
    try {
      Field fld = getClass().getField(this.n_initialPoolSize);
      setField(fld, parm);
    } catch (Exception e) {
      throw new VirtuosoException("Error: "+e.toString(), VirtuosoException.OK);
    }
  }


  /**
   * Get the number of seconds that a physical connection
   * will remain unused in the pool before the
   * connection is closed. Zero ( 0 ) indicates no limit.
   *
   * @return   the number of seconds
  **/
  public int getMaxIdleTime() {
    return maxIdleTime;
  }

  /**
   * Set the number of seconds that a physical connection
   * should remain unused in the pool before the
   * connection is closed. Zero ( 0 ) indicates no limit.
   *
   * @param  parm a number of seconds
   *
   * @exception  java.sql.SQLException if an error occurs
   *
  **/
  public void setMaxIdleTime(int parm) throws SQLException
  {
    try {
      Field fld = getClass().getField(this.n_maxIdleTime);
      setField(fld, parm);
    } catch (Exception e) {
      throw new VirtuosoException("Error: "+e.toString(), VirtuosoException.OK);
    }
  }

  /**
   * Get the interval, in seconds, that the pool will wait
   * before enforcing the current policy defined by the
   * values of the above connection pool properties
   *
   * @return  the interval (in seconds)
  **/
  public int getPropertyCycle() {
    return propertyCycle;
  }

  /**
   * Set the interval, in seconds, that the pool should wait
   * before enforcing the current policy defined by the
   * values of the above connection pool properties
   *
   * @param  parm an interval (in seconds)
  **/
  public void setPropertyCycle(int parm) {
    propertyCycle = parm;
  }


  /**
   * Get the total number of statements that the pool will
   * keep open. Zero ( 0 ) indicates that caching of
   * statements is disabled.
   *
   * @return  the total number of statements
  **/
  public int getMaxStatements() {
    return maxStatements;
  }

  /**
   * Set the total number of statements that the pool should
   * keep open. Zero ( 0 ) indicates that caching of
   * statements is disabled.
   *
   * @param  parm a total number of statements
   *
   * @exception  java.sql.SQLException if an error occurs
   *
  **/
  public void setMaxStatements(int parm) throws SQLException
  {
    try {
      Field fld = getClass().getField(this.n_maxStatements);
      setField(fld, parm);
    } catch (Exception e) {
      throw new VirtuosoException("Error: "+e.toString(), VirtuosoException.OK);
    }
  }


  private void setField(Field fld, int parm) throws Exception {
    if (propertyCycle == 0)
      fld.setInt(this, parm);
    else
      synchronized(propQueue) {
        propQueue.add(new NewProperty(fld, parm));
        propEnforceTime = ((NewProperty)propQueue.first()).enforceTime;
      }
  }

  private void check_close()  throws SQLException
  {
    if (isClosed)
      throw new VirtuosoException("ConnectionPoolDataSource is closed", VirtuosoException.OK);
  }


  ///////////////// Inner classes //////////////////////
  private class NewProperty {
    protected long enforceTime;
    protected Field fld;
    protected int arg;

    protected NewProperty(Field _fld, int _arg) {
      fld = _fld;
      arg = _arg;
      enforceTime = System.currentTimeMillis() + propertyCycle * 1000L;
    }
  }


  private class OpenHelper extends Thread {

    private String conn_url;
    private Properties info;
    private String connKey;
    private int count;

    protected OpenHelper(int _count, Properties _info) {
      count = _count;
      info = _info;

      conn_url = create_url();
      connKey = create_url_key(conn_url, info);
      setName("Virtuoso OpenHelper");
    }

    public void run() {
      int cacheSize = connPool.cacheSize.get();
      if (cacheSize >= count ||
          (maxPoolSize != 0 && cacheSize >= maxPoolSize))
        return;

      for(int i = 0; i < count; i++)
        try {
          connPool.tryAddConnection(conn_url, connKey, info);
          cacheSize = connPool.cacheSize.get();
          if ((minPoolSize != 0 && cacheSize >= minPoolSize)
              || (maxPoolSize != 0 && cacheSize >= maxPoolSize))
            return;
        } catch (Exception e) { }
    }

  }


  private class CloseHelper extends Thread {

    private List connList;
    private PooledConnection pconn;

    private CloseHelper() {
      setName("Virtuoso CloseHelper");
    }

    protected CloseHelper(List _connList) {
      this();
      connList = _connList;
    }

    protected CloseHelper(PooledConnection _pconn) {
      this();
      pconn = _pconn;
    }

    public void run() {
      if (connList != null) {
        for(ListIterator i = connList.listIterator(); i.hasNext(); ) {
          try {
            ((VirtuosoPooledConnection)i.next()).close();
          } catch (Exception e) { 
          } finally {
            connPool.cacheSize.decrementAndGet();
          }
        }
        connList.clear();
      } else {
        try {
          pconn.close();
        } catch (Exception e) {
        } finally {
          connPool.cacheSize.decrementAndGet();
        }
      }
    }

  }


  private class ConnCache {
    AtomicInteger cacheSize;
    LinkedList<VirtuosoPooledConnection> unUsed;
    ConcurrentHashMap<VirtuosoPooledConnection,VirtuosoPooledConnection> in_Use;
    Object lck_new = new Object();

    private VirtuosoConnectionPoolDataSource cpds;

    private ConnCache(VirtuosoConnectionPoolDataSource _cpds) {
      unUsed = new LinkedList<VirtuosoPooledConnection>();
      in_Use = new ConcurrentHashMap<VirtuosoPooledConnection,VirtuosoPooledConnection>(32);
      cacheSize = new AtomicInteger(0);
      cpds = _cpds;
    }


    public void finalize () throws Throwable {
      clear ();
    }


    private void tryAddConnection(String conn_url, String connKey, Properties info) {
      VirtuosoConnection conn = null;
      VirtuosoPooledConnection pconn;

      if (checkForNewConn()) {
        // establish a new Connection
        try {
          conn = new VirtuosoConnection (conn_url, "localhost", 1111, info);
          pconn = new VirtuosoPooledConnection(conn, connKey, cpds);
          connPool.addPooledConnection(pconn, true);
        } catch(SQLException e) {
          cacheSize.decrementAndGet();
          if (conn!=null) {
            try {
              conn.close();
            } catch(Exception e1) { }
          }
        }
      }
    }

    //add a new connection to pool
    private void addPooledConnection(VirtuosoPooledConnection pconn, boolean reuse)
        throws java.sql.SQLException
    {
      if (isClosed)
          throw new VirtuosoException("Cache was closed", VirtuosoException.OK);

      synchronized(unUsed) {
        unUsed.addLast(pconn);
      }

      if (!reuse)
        cacheSize.incrementAndGet();

      synchronized(this) {
        notifyAll();
      }
    }

    //close all connections & clear the pool
    private void clear() throws SQLException {
      VirtuosoPooledConnection pconn;

      for(Iterator iterator = in_Use.keySet().iterator(); iterator.hasNext(); ) {
        pconn = (VirtuosoPooledConnection)iterator.next();
        pconn.removeConnectionEventListener(cpds);
        try {
          pconn.close();
        } catch (Exception e) {}
      }
      in_Use.clear();

      synchronized(unUsed) {
        Iterator<VirtuosoPooledConnection> iterator;
        for(iterator = unUsed.iterator(); iterator.hasNext(); ) {
          pconn = iterator.next();
          try {
            pconn.close();
          } catch (Exception e) {}
        }
        unUsed.clear();
      }

      cacheSize.set(0);
    }


    private void reusePooledConnection(VirtuosoPooledConnection pconn)
    	throws SQLException
    {
      if (isClosed)
          throw new VirtuosoException("Cache was closed", VirtuosoException.OK);

      if (pconn == null)
        return;

      pconn.removeConnectionEventListener(cpds);

      VirtuosoPooledConnection pooledConn = null;
      if ((pooledConn = (VirtuosoPooledConnection)in_Use.remove(pconn)) == null)
          throw new VirtuosoException("Unexpected state of cache", VirtuosoException.OK);

      if (maxPoolSize != 0  &&  cacheSize.get() > maxPoolSize) {
        // System.out.println("close pconn....");
        CloseHelper helpThread = new CloseHelper(pconn);
        helpThread.start();

      } else {

        // reUse connection & put connection to the unUsed pool
        pooledConn = pconn.reuse();
        addPooledConnection(pooledConn, true);
      }
    }


    private void closePooledConnection(VirtuosoPooledConnection pconn)
    	throws SQLException
    {
      if (isClosed)
          throw new VirtuosoException("Cache was closed", VirtuosoException.OK);
//    System.out.println("Calling closePooledConnection");
      pconn.removeConnectionEventListener(cpds);

      VirtuosoPooledConnection pooledConn;

      if ((pooledConn = (VirtuosoPooledConnection)in_Use.remove(pconn)) == null)
          throw new VirtuosoException("Unexpected state of cache", VirtuosoException.OK);

      try {
        pconn.close();
      } finally {
        cacheSize.decrementAndGet();
      } 
    }


    private VirtuosoPooledConnection lookup(String _Key)
        throws java.sql.SQLException
    {
      if (isClosed)
          throw new VirtuosoException("Cache was closed", VirtuosoException.OK);

      ArrayList<VirtuosoPooledConnection> closeTmp = new ArrayList<VirtuosoPooledConnection>();
      VirtuosoPooledConnection pooledConn;
      int _hashKey = _Key.hashCode();

      try {
        synchronized(unUsed) {
          for(ListIterator iterator = unUsed.listIterator(); iterator.hasNext(); ) {
            pooledConn = (VirtuosoPooledConnection)iterator.next();
            if (pooledConn.hashConnURL == _hashKey && pooledConn.connURL.equals(_Key)) {
              iterator.remove();
	      if (pooledConn.isConnectionLost(1)) {
                closeTmp.add(pooledConn);
	      } else {
                return pooledConn;
	      }
            }
          }
        }

        return null;

      } finally {
        if (closeTmp.size() > 0) {
          // close connections
          CloseHelper helpThread = new CloseHelper(closeTmp);
          helpThread.start();
        }
      }
    }


    private boolean checkForNewConn() {
      synchronized(lck_new) 
      {
        if (maxPoolSize == 0 || cacheSize.get() < maxPoolSize) {
          cacheSize.incrementAndGet();
          return true;
        } else
          return false;
      }
    }

    // get connection from cache or create a new connection
    private PooledConnection getPooledConnection(Properties info,
                                                 String connKey,
                                                 String conn_url)
        throws java.sql.SQLException
    {
      if (isClosed)
          throw new VirtuosoException("Cache was closed", VirtuosoException.OK);

      VirtuosoPooledConnection pconn = null;
      VirtuosoConnection conn = null;

    //try to find an unused Connection
      if ((pconn = lookup(connKey)) != null) {
        pconn.init(cpds);
        in_Use.put(pconn, pconn);
        stat._hits++;
        return pconn;
      }

    // if couldn't found an unused Connection
      if (checkForNewConn()) {
        // establish a new Connection
        try {
          conn = new VirtuosoConnection (conn_url, "localhost", 1111, info);
          pconn = new VirtuosoPooledConnection(conn, connKey, cpds);
        } catch(SQLException e) {
          cacheSize.decrementAndGet();
          if (conn!=null) {
            try {
              conn.close();
            } catch(Exception e1) {
            }
          }
          throw e;
        }
        in_Use.put(pconn, pconn);
        return pconn;
      }

      // wait a free Connection
      long start = System.currentTimeMillis();
      long _timeout = loginTimeout * 1000L;
      Thread thr = Thread.currentThread();
      stat._misses++;
      while (pconn == null) {

        if ((pconn = lookup(connKey)) != null) {
//        System.out.println("Thread "+thr+" has found a free connection");
          stat.setWaitingTime(System.currentTimeMillis() - start);
          pconn.init(cpds);
          in_Use.put(pconn, pconn);
          return pconn;
        }

//    System.out.println("Thread "+thr+" begin a waiting...");
        synchronized(this) {
          try {
            if (loginTimeout > 0) {
              wait(_timeout);
              _timeout -= (System.currentTimeMillis() - start);
              if (_timeout < 0) {
//              System.out.println("Thread "+thr+" : loginTimeout has expired");
                throw new VirtuosoException("Connection failed loginTimeout has expired", VirtuosoException.TIMEOUT);
              }
            } else {
              wait();
            }
//          System.out.println("Thread "+thr+" has woken ");
          } catch (InterruptedException e) { }
        }
      }

      return null;
    }


    private void checkPool() {
      VirtuosoPooledConnection pooledConn;
      ArrayList<Object> closeTmp = new ArrayList<Object>();
      ListIterator l_iter;

      if (maxIdleTime != 0) {
       // remove a long time unused connections
        long minTime = System.currentTimeMillis() - maxIdleTime * 1000L;

        synchronized(unUsed) {
          for(l_iter = unUsed.listIterator(); l_iter.hasNext(); ) {
            pooledConn = (VirtuosoPooledConnection)l_iter.next();
            if (pooledConn.tmClosed < minTime) {
               closeTmp.add(pooledConn);
               l_iter.remove();
            }
          }
        }
      }

      if (maxPoolSize != 0 && cacheSize.get() > maxPoolSize) {
         //remove connections
         synchronized(unUsed) {
           int count = cacheSize.get() - maxPoolSize;
           for(l_iter = unUsed.listIterator(); l_iter.hasNext() && count > 0; count--) {
             closeTmp.add(l_iter.next());
             l_iter.remove();
           }
         }
      }

      if (closeTmp != null && closeTmp.size() > 0) {
       // close connections
        CloseHelper helpThread = new CloseHelper(closeTmp);
        helpThread.start();
      }

      if (minPoolSize != 0 && cacheSize.get() < minPoolSize) {
        //add connections
        Properties info = createConnProperties();
        int count = minPoolSize - cacheSize.get();
        OpenHelper helpThread = new OpenHelper(count, info);
        helpThread.start();
      }
    }

  }

}
