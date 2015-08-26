/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

import java.sql.*;
import java.util.*;
import java.io.*;
import openlink.util.*;

/**
 * The VirtuosoStatement class is an implementation of the Statement interface
 * in the JDBC API which represents a statement.
 * You can obtain a Statement like below :
 * <pre>
 *   <code>Statement s = connection.createStatement()</code>
 * </pre>
 *
 * @version 1.0 (JDBC API 2.0 implementation)
 * @see java.sql.connection#createStatement
 */
public class VirtuosoStatement implements Statement
{
   // Parameters for a prepared statement
   protected openlink.util.Vector parameters, objparams;

#if JDK_VER >= 16
   protected LinkedList<Object> batch;
#elif JDK_VER >= 12
   protected LinkedList batch;
#else
   protected openlink.util.Vector batch;
#endif

   // The concurrency to use for this Statement
   private int concurrency;

   // The result set type
   protected int type;

   // The exec type
   protected int exec_type = VirtuosoTypes.QT_UNKNOWN;

   // The direction in which results may be fetched
   private int fetchDirection = VirtuosoResultSet.FETCH_FORWARD;

   // The Connection that owns this Statement
   protected VirtuosoConnection connection;

   // The maximum field size for data of certain SQL types
   private int maxFieldSize;

   // The number of rows to be fetched for each query
   private int prefetch = VirtuosoTypes.DEFAULTPREFETCH;

   // The maximum of rows which can be returned by a query
   private int maxRows;

   // The time out for an transaction
   protected int txn_timeout;

   // The time out for an transaction
   protected int rpc_timeout;

   // The statement id
   protected String statid, cursorName;

   // The true when the statement is closed
   protected volatile boolean close_flag = false;

   // The request number
   protected static int req_no;

   // The current ResultSet
   protected VirtuosoResultSet vresultSet;

   // The future where result in DV format are stored
   protected VirtuosoFuture future;

   // Its meta data
   protected VirtuosoResultSetMetaData metaData;

   protected boolean isCached = false;

   protected boolean closeOnCompletion = false;

#if JDK_VER >= 14
   // Its params data
   protected VirtuosoParameterMetaData paramsMetaData = null;
#endif

   /**
    * Constructs a new VirtuosoStatement that is forward-only and read-only.
    *
    * @param connection The VirtuosoConnection which owns it.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   VirtuosoStatement(VirtuosoConnection connection) throws VirtuosoException
   {
      // Get and check parameters
      this.connection = connection;
      this.type = VirtuosoResultSet.TYPE_FORWARD_ONLY;
      this.concurrency = VirtuosoResultSet.CONCUR_READ_ONLY;
      this.rpc_timeout = connection.timeout;
      this.txn_timeout = connection.txn_timeout;
      this.prefetch = connection.fbs;
   }

   /**
    * Constructs a new VirtuosoStatement with specific options.
    *
    * @param connection The VirtuosoConnection which owns it.
    * @param type       The result set type.
    * @param concurrency   The result set concurrency.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    * @see java.sql.ResultSet
    */
   VirtuosoStatement(VirtuosoConnection connection, int type, int concurrency) throws VirtuosoException
   {
      // Get and check parameters
      this.connection = connection;
      if(type == VirtuosoResultSet.TYPE_FORWARD_ONLY || type == VirtuosoResultSet.TYPE_SCROLL_SENSITIVE || type == VirtuosoResultSet.TYPE_SCROLL_INSENSITIVE)
         this.type = type;
      else
         throw new VirtuosoException("Bad parameters.",VirtuosoException.BADPARAM);
      if(concurrency == VirtuosoResultSet.CONCUR_READ_ONLY || concurrency == VirtuosoResultSet.CONCUR_UPDATABLE)
         this.concurrency = concurrency;
      else
         throw new VirtuosoException("Bad parameters.",VirtuosoException.BADPARAM);
      this.rpc_timeout = connection.timeout;
      this.txn_timeout = connection.txn_timeout;
      this.prefetch = connection.fbs;
   }


   protected VectorOfLong getStmtOpts () throws VirtuosoException
     {
       // Set the concurrency type
       Long[] arrLong = new Long[11];
       if (connection.isReadOnly ())
         arrLong[0] = new Long (VirtuosoTypes.SQL_CONCUR_ROWVER);
       else
	 arrLong[0] = new Long(concurrency == VirtuosoResultSet.CONCUR_READ_ONLY ?
		VirtuosoTypes.SQL_CONCUR_READ_ONLY : VirtuosoTypes.SQL_CONCUR_LOCK);
       arrLong[1] = new Long(0);
       arrLong[2] = new Long(maxRows);
#if JDK_VER >= 14
       if (connection.getGlobalTransaction()) {
           VirtuosoXAConnection xac = (VirtuosoXAConnection) connection.xa_connection;
	   if (VirtuosoFuture.rpc_log != null)
	   {
	       synchronized (VirtuosoFuture.rpc_log)
	       {
		   VirtuosoFuture.rpc_log.println ("VirtuosoStatement.getStmtOpts () xa_res=" + xac.getVirtuosoXAResource().hashCode() + " :" + hashCode());
		   VirtuosoFuture.rpc_log.flush();
	       }
	   }
           arrLong[3] = new Long(xac.getVirtuosoXAResource().txn_timeout * 1000);
       } else {
           arrLong[3] = new Long(txn_timeout * 1000);
       }
#else
       arrLong[3] = new Long(txn_timeout * 1000);
#endif
     if (VirtuosoFuture.rpc_log != null)
       {
	 synchronized (VirtuosoFuture.rpc_log)
	   {
	     VirtuosoFuture.rpc_log.println ("VirtuosoStatement.getStmtOpts (txn_timeout=" + arrLong[3] + ") (con=" + connection.hashCode() + ") :" + hashCode());
	     VirtuosoFuture.rpc_log.flush();
	   }
       }
       arrLong[4] = new Long(prefetch);
       // Set the autocommit
       arrLong[5] = new Long((connection.getAutoCommit()) ? 1 : 0);
       arrLong[6] = new Long (rpc_timeout);
       // Set the cursor type
       switch(type)
	 {
	   case VirtuosoResultSet.TYPE_FORWARD_ONLY:
	       arrLong[7] = new Long(VirtuosoTypes.SQL_CURSOR_FORWARD_ONLY);
	       break;
	   case VirtuosoResultSet.TYPE_SCROLL_SENSITIVE:
	       arrLong[7] = new Long(VirtuosoTypes.SQL_CURSOR_DYNAMIC);
	       break;
	   case VirtuosoResultSet.TYPE_SCROLL_INSENSITIVE:
	       arrLong[7] = new Long(VirtuosoTypes.SQL_CURSOR_STATIC);
	       break;
	 }
       ;
       // Set keyset size and bookmark
       arrLong[8] = new Long(0);
       arrLong[9] = new Long(1);
       // Set the isolation mode
       arrLong[10] = new Long(connection.getTransactionIsolation());
       // Put the options array in the args array
       return new VectorOfLong(arrLong);
     }

   /**
    * Executes a SQL statement that returns a single ResultSet.
    *
    * @param sql  the SQL request.
    * @return ResultSet  A ResultSet that contains the data produced by
    * the query; never null.
    * @exception virtuoso.jdbc2.VirtuosoException  If a database access error occurs.
    */
   protected VirtuosoResultSet sendQuery(String sql) throws VirtuosoException
   {
       try
       {
	   synchronized (connection)
	   {
	       if (close_flag)
		   throw new VirtuosoException("Statement is already closed",VirtuosoException.CLOSED);
	       Object[] args = new Object[6];
	       openlink.util.Vector vect = new openlink.util.Vector(1);
	       // Drop the current statement
	       if (future != null)
	       {
		   close();
		   close_flag = false;
	       }
	       else
		   cancel();
	       //System.out.println(this+" "+connection+" [@"+sql+"@]");
	       // Set arguments to the RPC function
	       args[0] = (statid == null) ? statid = new String("s" + connection.hashCode() + (req_no++)) : statid;
	       args[2] = (cursorName == null) ? args[0] : cursorName;
	       args[1] = connection.escapeSQL (sql);
	       args[3] = vect;
	       args[4] = null;
	       try
	       {
		   vect.addElement(new openlink.util.Vector(0));
		   // Put the options array in the args array
		   args[5] = getStmtOpts();
		   future = connection.getFuture(VirtuosoFuture.exec,args, this.rpc_timeout);
		   return new VirtuosoResultSet(this,metaData,false);
	       }
	       catch(IOException e)
	       {
		   throw new VirtuosoException("Problem during serialization : " + e.getMessage(),VirtuosoException.IOERROR);
	       }
	   }
       }
       catch (Throwable e)
       {
	   notify_error (e);
	   return null;
       }
   }

   /**
    * Method runs when the garbage collector want to erase the object
    */
   public void finalize() throws Throwable
   {
      close();
      // Remove the metaData
      if(metaData != null)
         metaData.close();
   }

   // --------------------------- JDBC 1.0 ------------------------------
   /**
    * Cancels this Statement object if both the DBMS and
    * driver support aborting an SQL statement.
    * This method can be used by one thread to cancel a statement that
    * is being executed by another thread.
    *
    * @exception virtuoso.jdbc2.VirtuosoException If a database access error occurs
    */
   public void cancel() throws VirtuosoException
   {
     synchronized (connection)
       {
	 // Close the result set
	 if(vresultSet != null)
	   {
	     //vresultSet.close();
	     vresultSet = null;
	   }
	 // Remove the future

	 if(future != null)
	   {
	     connection.removeFuture(future);
	     future = null;
	   }
       }
   }

   /**
    * Clears all the warnings reported on this Statement object.
    * Virtuoso doesn't generate warnings, so this function does nothing.
    *
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Statement#clearWarnings
    */
   public void clearWarnings() throws VirtuosoException
   {
   }

   /**
    * Releases this Statement object's database
    * and JDBC resources immediately instead of new wait for
    * this to happen when it is automatically closed.
    *
    * @exception virtuoso.jdbc2.VirtuosoException If a database access error occurs.
    * @see java.sql.Statement#close
    */
   public void close() throws VirtuosoException
   {
     if(close_flag)
       return;
      
     synchronized (connection)
       {
	 // System.out.println("Close statement : "+this);
	 try
	   {
	     // Check if a statement is treat
	     if(close_flag)
	       return;
             close_flag = true;
	     if(statid == null)
	       return;
	     // Cancel current result set
	     cancel();
	     // Build the args array
	     Object[] args = new Object[2];
	     args[0] = statid;
	     args[1] = new Long(VirtuosoTypes.STAT_DROP);
	     // Create and get a future for this
	     future = connection.getFuture(VirtuosoFuture.close,args, this.rpc_timeout);
	     // Read the answer
	     future.nextResult();
	     // Remove the future reference
	     connection.removeFuture(future);
	     future = null;
	   }
	 catch(IOException e)
	   {
	     throw new VirtuosoException("Problem during closing : " + e.getMessage(),VirtuosoException.IOERROR);
	   }
       }
   }

   /**
    * Executes a SQL statement that may return multiple results.
    * This method executes a SQL statement and indicates the
    * form of the first result.  You can then use getResultSet or
    * getUpdateCount to retrieve the result, and getMoreResults to
    * move to any subsequent result(s).
    *
    * @param sql  Any SQL statement.
    * @return boolean   True if the next result is a ResultSet; false if it is
    * an update count or there are no more results.
    * @exception VirtuosoException  If a database access error occurs.
    * @see virtuoso.jdbc2.VirtuosoStatement#getResultSet
    * @see virtuoso.jdbc2.VirtuosoStatement#getUpdateCount
    * @see virtuoso.jdbc2.VirtuosoStatement#getMoreResults
    * @see java.sql.Statement#execute
    */
   public boolean execute(String sql) throws VirtuosoException
   {
      exec_type = VirtuosoTypes.QT_UNKNOWN;
      vresultSet = sendQuery(sql);
      // Test the kind of operation
      return (vresultSet.kindop() != VirtuosoTypes.QT_UPDATE);
   }

   /**
    * Executes a SQL statement that returns a single ResultSet.
    *
    * @param sql  Typically this is a static SQL SELECT statement. (null is possible)
    * @return ResultSet  A ResultSet that contains the data produced by
    * the query; never null.
    * @exception virtuoso.jdbc2.VirtuosoException  If a database access error occurs.
    * @see java.sql.Statement#executeQuery
    */
   public ResultSet executeQuery(String sql) throws VirtuosoException
   {
      exec_type = VirtuosoTypes.QT_SELECT;
      vresultSet = sendQuery(sql);
      return vresultSet;
   }

   /**
    * Executes an SQL INSERT, UPDATE or DELETE statement. In addition,
    * SQL statements that return nothing, such as SQL DDL statements,
    * can be executed.
    *
    * @param sql a SQL INSERT, UPDATE or DELETE statement or a SQL
    * statement that returns nothing
    * @return either the row count for INSERT, UPDATE or DELETE or 0
    * for SQL statements that return nothing
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.Statement#executeUpdate
    */
   public int executeUpdate(String sql) throws VirtuosoException
   {
      exec_type = VirtuosoTypes.QT_UPDATE;
      vresultSet = sendQuery(sql);
      return vresultSet.getUpdateCount();
   }

   /**
    * Returns the maximum number of bytes allowed for any column value.
    * This limit is the maximum number of bytes that can be returned for
    * any column value. The limit applies only to BINARY,
    * VARBINARY, LONGVARBINARY, CHAR, VARCHAR, and LONGVARCHAR
    * columns.  If the limit is exceeded, the excess data is silently
    * discarded.
    *
    * @return int The current max column size limit; zero means unlimited
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Statement#getMaxFieldSize
    */
   public int getMaxFieldSize() throws VirtuosoException
   {
      return maxFieldSize;
   }

   /**
    * Retrieves the maximum number of rows that a
    * VirtuosoResultSet can contain.  If the limit is exceeded, the excess
    * rows are silently dropped.
    *
    * @return int The current max row limit; zero means unlimited.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Statement#getMaxRows
    */
   public int getMaxRows() throws VirtuosoException
   {
      return maxRows;
   }

   /**
    * Moves to a Statement's next result.  It returns true if
    * this result is a ResultSet.  This method also implicitly
    * closes any current ResultSet obtained with getResultSet.
    *
    * There are no more results when (!getMoreResults() &&
    * (getUpdateCount() == -1)
    *
    * @return true if the next result is a ResultSet; false if it is
    * an update count or there are no more results
    * @exception VirtuosoException if a database access error occurs
    * @see virtuoso.jdbc2.VirtuosoStatement#getResultSet
    * @see virtuoso.jdbc2.VirtuosoStatement#execute
    * @see java.sql.Statement#getMoreResults
    */
   public boolean getMoreResults() throws VirtuosoException
   {
       try
       {
	   synchronized (connection)
	   {
	       try
	       {
		   // First of all, check if there's at least the first result set
		   if(vresultSet == null || vresultSet.isLastResult)
		       return false;
		   // Send the fetch query
		   Object[] args = new Object[2];
		   args[0] = statid;
		   args[1] = new Long(future.hashCode());
		   future.send_message(VirtuosoFuture.fetch,args);
		   // ReArm the process
		   vresultSet.getMoreResults(false);
		   return true;
	       }
	       catch(IOException e)
	       {
		   throw new VirtuosoException("Problem during serialization : " + e.getMessage(),VirtuosoException.IOERROR);
	       }
	   }
       } catch (Throwable e) {
	   notify_error (e);
	   return false;
       }

   }

   /**
    * Retrieves the number of seconds the driver will
    * new wait for a Statement to execute. If the limit is exceeded, a
    * VirtuosoException is thrown.
    *
    * @return int The current query timeout limit in seconds; zero means unlimited.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Statement#getQueryTimeOut
    */
   public int getQueryTimeout() throws VirtuosoException
   {
      return rpc_timeout/1000;
   }

   /**
    * Returns the current result as a VirtuosoResultSet object.
    * This method should be called only once per result.
    *
    * @return the current result as a ResultSet; null if the result
    * is an update count or there are no more results
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see virtuoso.jdbc2.VirtuosoStatement#getResultSet
    * @see virtuoso.jdbc2.VirtuosoStatement#execute
    * @see java.sql.Statement#getResultSet
    */
   public ResultSet getResultSet() throws VirtuosoException
   {
      return (vresultSet.kindop() != VirtuosoTypes.QT_UPDATE)?vresultSet:null;
   }

   /**
    * Returns the current result as an update count;
    * if the result is a ResultSet or there are no more results, -1
    * is returned.
    * This method should be called only once per result.
    *
    * @return the current result as an update count; -1 if it is a
    * ResultSet or there are no more results
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see #execute
    */
   public int getUpdateCount() throws VirtuosoException
   {
      if(vresultSet != null)
         switch(vresultSet.kindop())
         {
            case VirtuosoTypes.QT_UPDATE:
	    case VirtuosoTypes.QT_PROC_CALL: // since we can set row count from a stored procedure
               return vresultSet.getUpdateCount();
            default:
               return -1;
         }
      ;
      return -1;
   }

   /**
    * Retrieves the first warning reported by calls on this Statement.
    * Subsequent Statement warnings will be chained to this
    * SQLWarning. Virtuoso doesn't generate warnings, so this function
    * will return always null.
    *
    * @return SQLWarning   The first SQLWarning or null (must be null for the moment)
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Statement#getWarnings
    */
   public SQLWarning getWarnings() throws VirtuosoException
   {
      return null;
   }

   /**
    * Sets the limit for the maximum number of bytes in a column to
    * the given number of bytes.  This is the maximum number of bytes
    * that can be returned for any column value.  This limit applies
    * only to BINARY, VARBINARY, LONGVARBINARY, CHAR, VARCHAR, and
    * LONGVARCHAR fields.  If the limit is exceeded, the excess data
    * is silently discarded. For maximum portability, use values
    * greater than 256.
    *
    * @param max  The new max column size limit; zero means unlimited
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Statement#setMaxFieldSize
    */
   public void setMaxFieldSize(int max) throws VirtuosoException
   {
      // Check and get parameters
      if(max < 0)
         throw new VirtuosoException("Bad parameters.",VirtuosoException.BADPARAM);
      maxFieldSize = max;
   }

   /**
    * Sets the limit for the maximum number of rows that any
    * VirtuosoResultSet can contain to the given number.
    * If the limit is exceeded, the excess rows are silently dropped.
    *
    * @param max  The new max rows limit; zero means unlimited
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    * @see java.sql.Statement#setMaxRows
    */
   public void setMaxRows(int max) throws VirtuosoException
   {
      if(max < 0)
         throw new VirtuosoException("Bad parameters.",VirtuosoException.BADPARAM);
      maxRows = max;
   }

   /**
    * Sets the number of seconds the driver will
    * new wait for a Statement to execute to the given number of seconds.
    * If the limit is exceeded, a VirtuosoException is thrown.
    *
    * @param int  Seconds the new query timeout limit in seconds; zero means.
    * unlimited
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.Statement#setQueryTimeOut
    */
   public void setQueryTimeout(int seconds) throws VirtuosoException
   {
      // Check and get parameters
      if(seconds < 0)
         throw new VirtuosoException("Bad parameters.",VirtuosoException.BADPARAM);
      rpc_timeout = seconds*1000;
   }

   // --------------------------- JDBC 2.0 ------------------------------
   /**
    * Returns the VirtuosoConnection object that produced this
    * VirtuosoStatement object.
    *
    * @return Connection The connection that produced this statement
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Statement#getConnection
    */
    public Connection getConnection() throws VirtuosoException {
	return connection;
    }

   /**
    * Retrieves the direction for fetching rows from
    * database tables that is the default for result sets
    * generated from this VirtuosoStatement object.
    *
    * @return int The default fetch direction for result sets generated
    * from this VirtuosoStatement object.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Statement#getFetchDirection
    */
   public int getFetchDirection() throws VirtuosoException
   {
      return fetchDirection;
   }

   /**
    * Retrieves the number of result set rows that is the default
    * fetch size for result sets generated from this Statement object.
    *
    * @return int The default fetch size for result sets generated
    * from this Statement object.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Statement#getFetchSize
    */
   public int getFetchSize() throws VirtuosoException
   {
      return prefetch;
   }

   /**
    * Returns the result set concurrency.
    *
    * @return int The result set concurrency.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.ResultSet
    * @see java.sql.Statement#getResultSetConcurrency
    */
   public int getResultSetConcurrency() throws VirtuosoException
   {
      return concurrency;
   }

   /**
    * Returns the result set type.
    *
    * @return int The result set type.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.ResultSet
    * @see java.sql.Statement#getResultSetType
    */
   public int getResultSetType() throws VirtuosoException
   {
      return type;
   }

   /**
    * Sets the default fetch direction for result sets generated by
    * this VirtuosoStatement object.
    * Each result set has its own methods for getting and setting
    * its own fetch direction.
    *
    * @param direction the initial direction for processing rows
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    * @see java.sql.Statement#setFetchDirection
    */
   public void setFetchDirection(int direction) throws VirtuosoException
   {
      // Check and set parameters
      if(direction == VirtuosoResultSet.FETCH_FORWARD || direction == VirtuosoResultSet.FETCH_REVERSE || direction == VirtuosoResultSet.FETCH_UNKNOWN)
         fetchDirection = direction;
      else
         throw new VirtuosoException("Bad parameters.",VirtuosoException.BADPARAM);
   }

   /**
    * Gives the JDBC driver a hint as to the number of rows that should
    * be fetched from the database when more rows are needed.
    *
    * @param rows the number of rows to fetch
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    * @see java.sql.Statement#setFetchSize
    */
   public void setFetchSize(int rows) throws VirtuosoException
   {
      if(rows < 0 || (maxRows > 0 && rows > maxRows))
         throw new VirtuosoException("Bad parameters.",VirtuosoException.BADPARAM);
	
      prefetch = (rows == 0 ? VirtuosoTypes.DEFAULTPREFETCH : rows);
   }

   /**
    * Defines the SQL cursor name that will be used by
    * subsequent Statement <code>execute</code> methods. This name can then be
    * used in SQL positioned update/delete statements to identify the
    * current row in the ResultSet generated by this statement.  If
    * the database doesn't support positioned update/delete, this
    * method is a noop.  To insure that a cursor has the proper isolation
    * level to support updates, the cursor's SELECT statement should be
    * of the form 'select for update ...'. If the 'for update' phrase is
    * omitted, positioned updates may fail.
    *
    * <P><B>Note:</B> By definition, positioned update/delete
    * execution must be done by a different Statement than the one
    * which generated the ResultSet being used for positioning. Also,
    * cursor names must be unique within a connection.
    *
    * @param name the new cursor name, which must be unique within
    * a connection
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void setCursorName(String name) throws VirtuosoException
   {
      cursorName = name;
   }

   /**
    * Adds a SQL command to the current batch of commands for the statement.
    *
    * @param sql typically this is a static SQL INSERT or UPDATE statement
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void addBatch(String sql) throws VirtuosoException
   {
      // Check parameters and batch vector
      if(sql == null)
         return;
      if(batch == null)
#if JDK_VER >= 16
         batch = new LinkedList<Object>();
      // Add the sql request at the end
      batch.add(sql);
#elif JDK_VER >= 12
         batch = new LinkedList();
      // Add the sql request at the end
      batch.add(sql);
#else
         batch = new openlink.util.Vector(10,10);
      // Add the sql request at the end
      batch.addElement(sql);
#endif
   }

   /**
    * Makes the set of commands in the current batch empty.
    *
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void clearBatch() throws VirtuosoException
   {
      // Check if the batch vector exists
      if(batch != null)
#if JDK_VER >= 12
         batch.clear();
#else
         batch.removeAllElements();
#endif
   }

   /**
    * Submits a batch of commands to the database for execution.
    *
    * @return an array of update counts containing one element for each
    * command in the batch.  The array is ordered according
    * to the order in which commands were inserted into the batch.
    * @exception BatchUpdateException if a database access error occurs
    */
   public int[] executeBatch() throws BatchUpdateException
   {
      // Check if the batch vector exists
      if(batch == null)
         return new int[0];
      // Else execute one by one SQL request
      int[] result = new int[batch.size()];
      int[] outres = null;
      int outcount = 0;
      int i;
      // Flag to say if there's a problem
      boolean error = false;
      VirtuosoException ex = null;
#if JDK_VER >= 12
      i = 0;
      for(ListIterator it = batch.listIterator(); it.hasNext(); )
#else
      for(i = 0; i < batch.size(); i++)
#endif
      {
         try
         {
#if JDK_VER >= 12
            String stmt =  (String)it.next();
#else
            String stmt = (String)batch.elementAt(i);
#endif
            VirtuosoResultSet rset = sendQuery(stmt);
            result[i] = rset.getUpdateCount();
            if(rset.kindop()==VirtuosoTypes.QT_SELECT)
            {
              error = true;
              break;
            }
         }
         catch(VirtuosoException e)
         {
            error = true;
            result[i] = -3;
            ex = e;
         }
         outcount++;
#if JDK_VER >= 12
         i++;
#endif
      }
#if JDK_VER >= 12
      batch.clear();
#else
      batch.removeAllElements();
#endif
      if(error)
      {
         outres = new int[outcount];
         for (i=0; i<outcount; i++)
           outres[i]=result[i];
         if (ex != null)
           throw new BatchUpdateException(ex.getMessage(), ex.getSQLState(), ex.getErrorCode(), outres);
         else
           throw new BatchUpdateException(outres);
      }
      return result;
   }

   /**
    * Toggles on and off escape substitution before sending SQL to the
    * database.
    *
    * @param enable  Indicate whether to enable or disable escape processing.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Statement#setEscapeProcessing
    */
   public void setEscapeProcessing(boolean enable) throws VirtuosoException
   {
   }

   /**
    * Returns the type of executing query.
    */
   public int getExecType()
   {
     return exec_type;
   }

    /**
     * Retrieves whether this <code>Statement</code> object has been closed. A <code>Statement</code> is closed if the
     * method close has been called on it, or if it is automatically closed.
     * @return true if this <code>Statement</code> object is closed; false if it is still open
     * @throws SQLException if a database access error occurs
     * @since 1.6
     */
   public boolean isClosed ( )
   {
     return close_flag;
   }

#if JDK_VER >= 14
   /* JDK 1.4 functions */

   public boolean getMoreResults(int current) throws SQLException
     {
       if (current == KEEP_CURRENT_RESULT)
         throw new VirtuosoException ("Keeping the current result open not supported", "IM001",
           VirtuosoException.NOTIMPLEMENTED);
       return getMoreResults();
     }

   public ResultSet getGeneratedKeys() throws SQLException
     {
       return new VirtuosoResultSet (connection);
     }

   public int executeUpdate(String sql,
       int autoGeneratedKeys) throws SQLException
     {
       /* TODO: autoGeneratedKeys ignored */
       return executeUpdate (sql);
     }

   public int executeUpdate(String sql,
       int[] columnIndexes) throws SQLException
     {
       /* TODO: columnIndexes ignored */
       return executeUpdate (sql);
     }

   public int executeUpdate(String sql,
       String[] columnNames) throws SQLException
     {
       /* TODO: columnNames ignored */
       return executeUpdate (sql);
     }

   public boolean execute(String sql,
       int autoGeneratedKeys) throws SQLException
     {
       /* TODO: autoGeneratedKeys ignored */
       return execute (sql);
     }

   public boolean execute(String sql,
       int[] columnIndexes) throws SQLException
     {
       /* TODO: columnIndexes ignored */
       return execute (sql);
     }

   public boolean execute(String sql,
       String[] columnNames) throws SQLException
     {
       /* TODO: columnNames ignored */
       return execute (sql);
     }

   public int getResultSetHoldability() throws SQLException
     {
       return ResultSet.CLOSE_CURSORS_AT_COMMIT;
     }
#endif

   protected void notify_error (Throwable e) throws VirtuosoException
   {
       VirtuosoConnection c = connection;

       if (c != null)
	   throw c.notify_error (e);
       else
       {
	   VirtuosoException ve = new VirtuosoException(e.getMessage(), VirtuosoException.IOERROR);
#if JDK_VER >= 14
           ve.initCause (e);
#endif
	   throw ve;
       }
   }

#if JDK_VER >= 16
    //------------------------- JDBC 4.0 -----------------------------------
  private boolean isPoolable = true;
    /**
     * Requests that a <code>Statement</code> be pooled or not pooled.  The value
     * specified is a hint to the statement pool implementation indicating
     * whether the applicaiton wants the statement to be pooled.  It is up to
     * the statement pool manager as to whether the hint is used.
     * <p>
     * The poolable value of a statement is applicable to both internal
     * statement caches implemented by the driver and external statement caches
     * implemented by application servers and other applications.
     * <p>
     * By default, a <code>Statement</code> is not poolable when created, and
     * a <code>PreparedStatement</code> and <code>CallableStatement</code>
     * are poolable when created.
     * <p>
     * @param poolable	requests that the statement be pooled if true and
     * 			that the statement not be pooled if false
     * <p>
     * @throws SQLException if this method is called on a closed
     * <code>Statement</code>
     * <p>
     * @since 1.6
     */
  public void setPoolable(boolean poolable) throws SQLException
  {
    isPoolable = poolable;
  }

    /**
     * Returns a  value indicating whether the <code>Statement</code>
     * is poolable or not.
     * <p>
     * @return	<code>true</code> if the <code>Statement</code>
     * is poolable; <code>false</code> otherwise
     * <p>
     * @throws SQLException if this method is called on a closed
     * <code>Statement</code>
     * <p>
     * @since 1.6
     * <p>
     * @see java.sql.Statement#setPoolable(boolean) setPoolable(boolean)
     */
  public boolean isPoolable() throws SQLException
  {
    return isPoolable;
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
    try {
      // This works for classes that aren't actually wrapping anything
      return iface.cast(this);
    } catch (ClassCastException cce) {
      throw new VirtuosoException ("Unable to unwrap to "+iface.toString(), "22023", VirtuosoException.BADPARAM);
    }
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
    // This works for classes that aren't actually wrapping anything
    return iface.isInstance(this);
  }


#if JDK_VER >= 17
    //--------------------------JDBC 4.1 -----------------------------

    /**
     * Specifies that this {@code Statement} will be closed when all its
     * dependent result sets are closed. If execution of the {@code Statement}
     * does not produce any result sets, this method has no effect.
     * <p>
     * <strong>Note:</strong> Multiple calls to {@code closeOnCompletion} do
     * not toggle the effect on this {@code Statement}. However, a call to
     * {@code closeOnCompletion} does effect both the subsequent execution of
     * statements, and statements that currently have open, dependent,
     * result sets.
     *
     * @throws SQLException if this method is called on a closed
     * {@code Statement}
     * @since 1.7
     */
  public void closeOnCompletion() throws SQLException
  {
    synchronized (this) {
      closeOnCompletion = true;
    }
  }

    /**
     * Returns a value indicating whether this {@code Statement} will be
     * closed when all its dependent result sets are closed.
     * @return {@code true} if the {@code Statement} will be closed when all
     * of its dependent result sets are closed; {@code false} otherwise
     * @throws SQLException if this method is called on a closed
     * {@code Statement}
     * @since 1.7
     */
  public boolean isCloseOnCompletion() throws SQLException
  {
    synchronized (this) {
      return closeOnCompletion;
    }
  }

#endif
#endif
}
