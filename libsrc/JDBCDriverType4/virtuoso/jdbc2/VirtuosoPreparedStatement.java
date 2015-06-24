/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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
import java.math.*;
import openlink.util.*;

#if JDK_VER >= 16
import java.sql.RowId;
import java.sql.SQLXML;
import java.sql.NClob;
#endif

/**
 * The VirtuosoPreparedStatement class is an implementation of the PreparedStatement interface
 * in the JDBC API which represents a prepared statement.
 * You can obtain a Statement like below :
 * <pre>
 *   <code>PreparedStatement s = connection.prepareStatement(...)</code>
 * </pre>
 *
 * @version 1.0 (JDBC API 2.0 implementation)
 * @see virtuoso.jdbc2.VirtuosoConnection#prepareStatement
 */
public class VirtuosoPreparedStatement extends VirtuosoStatement implements PreparedStatement
{
   // The sql string with ?
   protected String sql;
#if JDK_VER <= 14
   private static final int _EXECUTE_FAILED = -3;
#else
   private static final int _EXECUTE_FAILED = Statement.EXECUTE_FAILED;
#endif

   /**
    * Constructs a new VirtuosoPreparedStatement that is forward-only and read-only.
    *
    * @param connection The VirtuosoConnection which owns it.
    * @param sql        The sql string with ?.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   VirtuosoPreparedStatement(VirtuosoConnection connection, String sql) throws VirtuosoException
   {
      this (connection,sql,VirtuosoResultSet.TYPE_FORWARD_ONLY,VirtuosoResultSet.CONCUR_READ_ONLY);
   }

   /**
    * Constructs a new VirtuosoPreparedStatement with specific options.
    *
    * @param connection The VirtuosoConnection which owns it.
    * @param sql        The sql string with ?.
    * @param type       The result set type.
    * @param concurrency   The result set concurrency.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    * @see java.sql.ResultSet
    */
   VirtuosoPreparedStatement(VirtuosoConnection connection, String sql, int type, int concurrency) throws VirtuosoException
   {
      super(connection,type,concurrency);
      sparql_executed =  sql.trim().regionMatches(true, 0, "sparql", 0, 6);
      synchronized (connection)
	{
	  try
	    {
	      // Parse the sql query
	      this.sql = sql;
	      parse_sql();
	      // Send RPC call
	      Object[] args = new Object[4];
	      args[0] = (statid == null) ? statid = new String("s" + connection.hashCode() + (req_no++)) : statid;
	      //args[0] = statid = new String("s" + connection.hashCode() + (req_no++));
	      args[1] = connection.escapeSQL(sql);
	      args[2] = new Long(0);
	      args[3] = getStmtOpts();
	      // Create a future
	      future = connection.getFuture(VirtuosoFuture.prepare,args, this.rpc_timeout);
	      // Process result to get information about results meta data
	      vresultSet = new VirtuosoResultSet(this,metaData, true);
	      result_opened = true;
              clearParameters();
	    }
	  catch(IOException e)
	    {
	      throw new VirtuosoException("Problem during serialization : " + e.getMessage(),VirtuosoException.IOERROR);
	    }
	}
   }

   /**
    * Method parses the sql string with ?
    */
   private void parse_sql()
   {
      String sql = this.sql;
      int count = 0;
      do
      {
         int index = sql.indexOf("?");
         if(index >= 0)
         {
            count++;
            sql = sql.substring(index + 1,sql.length());
            if(sql == null)
               sql = "";
         }
         else
            sql = "";
      }
      while(sql.length() != 0);
      parameters = new openlink.util.Vector(count);
      objparams = new openlink.util.Vector(count);
   }

   /**
    * Executes a SQL statement that returns a single ResultSet.
    *
    * @param sql  the SQL request.
    * @return ResultSet  A ResultSet that contains the data produced by
    * the query; never null.
    * @exception virtuoso.jdbc2.VirtuosoException  If a database access error occurs.
    */
   private void sendQuery() throws VirtuosoException
   {
     synchronized (connection)
       {
	 Object[] args = new Object[6];
	 openlink.util.Vector vect = new openlink.util.Vector(1);
         if (future != null) 
           {
             connection.removeFuture(future);
             future = null;
           }
	 // Set arguments to the RPC function
	 args[0] = statid;
	 args[2] = (cursorName == null) ? args[0] : cursorName;
	 args[1] = null;
	 args[3] = vect;
	 args[4] = null;
	 try
	   {
	     // Add parameters
	     vect.addElement(objparams);
	     // Put the options array in the args array
	     args[5] = getStmtOpts();
	     future = connection.getFuture(VirtuosoFuture.exec,args, this.rpc_timeout);
             vresultSet.isLastResult = false;
	     vresultSet.getMoreResults(false);
             vresultSet.stmt_n_rows_to_get = this.prefetch;
	     result_opened = true;
	   }
	 catch(IOException e)
	   {
	     throw new VirtuosoException("Problem during serialization : " + e.getMessage(),VirtuosoException.IOERROR);
	   }
       }
   }

   /**
    * Sets the designated parameter to a Java Vector value.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the parameter value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   protected void setVector(int parameterIndex, openlink.util.Vector x) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      if(x == null) this.setNull(parameterIndex, Types.ARRAY);
		else objparams.setElementAt(x,parameterIndex - 1);
   }

   // --------------------------- JDBC 1.0 ------------------------------
   /**
    * Clears the current parameter values immediately.
    *
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#clearParameters
    */
   public void clearParameters() throws VirtuosoException
   {
      // Clear parameters
      objparams.removeAllElements();
      /*for(int i=0 ; i<parameters.capacity() ; i++)
         objparams.setElementAt(null, i);*/
   }

   /**
    * Executes any kind of SQL statement.
    * Some prepared statements return multiple results; the execute
    * method handles these complex statements as well as the simpler
    * form of statements handled by executeQuery and executeUpdate.
    *
    * @exception virtuoso.jdbc2.VirtuosoException  If a database access error occurs.
    * @see virtuoso.jdbc2.VirtuosoStatement#getResultSet
    * @see virtuoso.jdbc2.VirtuosoStatement#getUpdateCount
    * @see virtuoso.jdbc2.VirtuosoStatement#getMoreResults
    * @see java.sql.PreparedStatement#execute
    */
   public boolean execute() throws VirtuosoException
   {
      exec_type = VirtuosoTypes.QT_UNKNOWN;
      sendQuery();
      // Test the kind of operation
      return (vresultSet.kindop() != VirtuosoTypes.QT_UPDATE);
   }

   /**
    * Executes the SQL INSERT, UPDATE or DELETE statement
    * in this PreparedStatement object.
    * In addition,
    * SQL statements that return nothing, such as SQL DDL statements,
    * can be executed.
    *
    * @return either the row count for INSERT, UPDATE or DELETE statements;
    * or 0 for SQL statements that return nothing
    * @exception virtuoso.jdbc2.VirtuosoException  If a database access error occurs.
    * @see java.sql.PreparedStatement#executeUpdate
    */
   public int executeUpdate() throws VirtuosoException
   {
      exec_type = VirtuosoTypes.QT_UPDATE;
      sendQuery();
      return vresultSet.getUpdateCount();
   }

   public int[] executeBatchUpdate() throws BatchUpdateException
   {
     int size = batch.size();
     int[] res = new int[size];
     int inx = 0;
     synchronized (connection)
       {
	 Object[] args = new Object[6];
	 // Set arguments to the RPC function
	 args[0] = statid;
	 args[2] = (cursorName == null) ? args[0] : cursorName;
	 args[1] = null;
	 args[3] = batch;
	 args[4] = null;
	 try
	   {
             if (future != null) 
               {
	         connection.removeFuture(future);
	         future = null;
               }

	     // Put the options array in the args array
	     args[5] = getStmtOpts();
	     future = connection.getFuture(VirtuosoFuture.exec,args, this.rpc_timeout);
             vresultSet.isLastResult = false;
	     for (inx = 0; inx < size; inx++)
	     {
		 vresultSet.setUpdateCount (0);
		 vresultSet.getMoreResults (false);
		 res[inx] = SUCCESS_NO_INFO; //vresultSet.getUpdateCount();
	     }
	   }
	 catch(IOException e)
	   {
	     throwBatchUpdateException(res, "Problem during serialization : " + e.getMessage(), inx);
	   }
	 catch(VirtuosoException e)
	  {
	     throwBatchUpdateException (res, e, inx);
	  }
       }
     return res;
   }

   /**
    * Executes a SQL prepare statement that returns a single ResultSet.
    *
    * @return ResultSet  A ResultSet that contains the data produced by
    * the query; never null.
    * @exception virtuoso.jdbc2.VirtuosoException  If a database access error occurs.
    * @see java.sql.PreparedStatement#executeQuery
    */
   public ResultSet executeQuery() throws VirtuosoException
   {
      exec_type = VirtuosoTypes.QT_SELECT;
      sendQuery();
      return vresultSet;
   }

   /**
    * Gets the number, types and properties of a ResultSet's columns.
    *
    * @return the description of a ResultSet's columns
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#getMetaData
    */
   public ResultSetMetaData getMetaData() throws VirtuosoException
   {
      if(vresultSet != null)
         return vresultSet.getMetaData();
      throw new VirtuosoException("Prepared statement closed",VirtuosoException.CLOSED);
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
#if JDK_VER >= 16
    if (isCached) {
      close_flag = true;
      try {
        connection.recacheStmt(this);
      } catch (SQLException ex) {
        throw new VirtuosoException(ex.getMessage(), ex.getSQLState(), ex.getErrorCode());
      }
      return;
    }
#endif

     if(close_flag)
       return;

     synchronized (connection)
       {
	 try
	   {
	     close_flag = true;
	     // Check if a statement is treat
	     if(statid == null)
	       return;
	     // Cancel current result set
	     cancel();
	     // Build the args array
	     Object[] args = new Object[2];
	     args[0] = statid;
//	     args[1] = new Long(VirtuosoTypes.STAT_CLOSE);
	     args[1] = new Long(VirtuosoTypes.STAT_DROP);
	     // Create and get a future for this
	     future = connection.getFuture(VirtuosoFuture.close,args, this.rpc_timeout);
	     // Read the answer
	     future.nextResult(false);
	     // Remove the future reference
	     connection.removeFuture(future);
	     future = null;
	     result_opened = false;
	   }
	 catch(IOException e)
	   {
	     throw new VirtuosoException("Problem during closing : " + e.getMessage(),VirtuosoException.IOERROR);
	   }
       }
   }

   /**
    * Sets the designated parameter to the given input stream, which will have
    * the specified number of bytes.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the Java input stream that contains the ASCII parameter value
    * @param length the number of bytes in the stream
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setAsciiStream
    */
   public void setAsciiStream(int parameterIndex, InputStream x, int length) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // After check, check if a Blob object is already associated or not
      Object _obj = objparams.elementAt(parameterIndex - 1);
      if (parameters != null && parameters.elementAt(parameterIndex - 1) instanceof openlink.util.Vector)
	{
	  openlink.util.Vector pd = (openlink.util.Vector)parameters.elementAt(parameterIndex - 1);
	  int dtp = ((Number)pd.elementAt (0)).intValue();
	  if (dtp != VirtuosoTypes.DV_BLOB &&
	      dtp != VirtuosoTypes.DV_BLOB_BIN &&
	      dtp != VirtuosoTypes.DV_BLOB_WIDE)
	    throw new VirtuosoException ("Passing streams to non-blob columns not supported",
		"IM001", VirtuosoException.NOTIMPLEMENTED);
	  if (dtp == VirtuosoTypes.DV_BLOB_BIN)
	    throw new VirtuosoException ("Passing ASCII stream to LONG VARBINARY columns not supported",
		"IM001", VirtuosoException.NOTIMPLEMENTED);
	}

      // Check now if it's a Blob
      if(_obj instanceof VirtuosoBlob)
	{
	  ((VirtuosoBlob)_obj).setInputStream(x,length);
	  try
	    {
	      ((VirtuosoBlob)_obj).setReader(new InputStreamReader (x, "ASCII"),length);
	    }
	  catch (UnsupportedEncodingException e)
	    {
	      ((VirtuosoBlob)_obj).setReader(new InputStreamReader (x),length);
	    }
	}
      else
	{
	  // Else create a Clob
	  if(x == null)
	    this.setNull(parameterIndex, Types.CLOB);
	  else
	    {
	      InputStreamReader rd;
	      try
		{
		  rd = new InputStreamReader (x, "ASCII");
		}
	      catch (UnsupportedEncodingException e)
		{
		  rd = new InputStreamReader (x);
		}
	      VirtuosoBlob bl = new VirtuosoBlob(rd, length, parameterIndex - 1);
	      bl.setInputStream (x, length);
	      objparams.setElementAt(bl, parameterIndex - 1);
	    }
	}
   }

   /**
    * Sets the designated parameter to a java.lang.BigDecimal value.
    * The driver converts this to an SQL NUMERIC value when
    * it sends it to the database.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the parameter value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setBigDecimal
    */
   public void setBigDecimal(int parameterIndex, BigDecimal x) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      if(x == null) this.setNull(parameterIndex, Types.NUMERIC);
		else objparams.setElementAt(x,parameterIndex - 1);
   }

   /**
    * Sets the designated parameter to the given input stream, which will have
    * the specified number of bytes.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the java input stream which contains the binary parameter value
    * @param length the number of bytes in the stream
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setBinaryStream
    */
   public void setBinaryStream(int parameterIndex, InputStream x, int length) throws VirtuosoException
   {
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // After check, check if a Blob object is already associated or not
      Object _obj = objparams.elementAt(parameterIndex - 1);

      if (parameters != null && parameters.elementAt(parameterIndex - 1) instanceof openlink.util.Vector)
	{
	  openlink.util.Vector pd = (openlink.util.Vector)parameters.elementAt(parameterIndex - 1);
	  int dtp = ((Number)pd.elementAt (0)).intValue();
	  if (dtp != VirtuosoTypes.DV_BLOB &&
	      dtp != VirtuosoTypes.DV_BLOB_BIN &&
	      dtp != VirtuosoTypes.DV_BLOB_WIDE)
	    throw new VirtuosoException ("Passing streams to non-blob columns not supported",
		"IM001", VirtuosoException.NOTIMPLEMENTED);
	  if (dtp == VirtuosoTypes.DV_BLOB_WIDE)
	    throw new VirtuosoException ("Passing binary stream to LONG NVARCHAR columns not supported",
		"IM001", VirtuosoException.NOTIMPLEMENTED);
	}

      // Check now if it's a Blob
      if(_obj instanceof VirtuosoBlob)
	{
	  ((VirtuosoBlob)_obj).setInputStream(x,length);
	  try
	    {
	      ((VirtuosoBlob)_obj).setReader(new InputStreamReader (x, "8859_1"),length);
	    }
	  catch (UnsupportedEncodingException e)
	    {
	      ((VirtuosoBlob)_obj).setReader(new InputStreamReader (x),length);
	    }
	}
      else
	{
	  // Else create a Blob
	  if(x == null)
	    this.setNull(parameterIndex, Types.BLOB);
	  else
	    {
	      InputStreamReader rd;
	      try
		{
		  rd = new InputStreamReader (x, "8859_1");
		}
	      catch (UnsupportedEncodingException e)
		{
		  rd = new InputStreamReader (x);
		}
	      VirtuosoBlob bl = new VirtuosoBlob(rd, length, parameterIndex - 1);
	      bl.setInputStream (x, length);
	      objparams.setElementAt(bl, parameterIndex - 1);
	    }
	}
   }

   /**
    * Sets the designated parameter to the given input stream, which will have
    * the specified number of unicode chars.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the java input stream which contains the binary parameter value
    * @param length the number of bytes in the stream
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setBinaryStream
    */
   public void setUnicodeStream(int parameterIndex, InputStream x, int length) throws VirtuosoException
   {
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // After check, check if a Blob object is already associated or not
      Object _obj = objparams.elementAt(parameterIndex - 1);
      if (parameters != null && parameters.elementAt(parameterIndex - 1) instanceof openlink.util.Vector)
	{
	  openlink.util.Vector pd = (openlink.util.Vector)parameters.elementAt(parameterIndex - 1);
	  int dtp = ((Number)pd.elementAt (0)).intValue();
	  if (dtp != VirtuosoTypes.DV_BLOB &&
	      dtp != VirtuosoTypes.DV_BLOB_BIN &&
	      dtp != VirtuosoTypes.DV_BLOB_WIDE)
	    throw new VirtuosoException ("Passing streams to non-blob columns not supported",
		"IM001", VirtuosoException.NOTIMPLEMENTED);
	  if (dtp == VirtuosoTypes.DV_BLOB_BIN)
	    throw new VirtuosoException ("Passing unicode stream to LONG VARBINARY columns not supported",
		"IM001", VirtuosoException.NOTIMPLEMENTED);
	}

      // Check now if it's a Blob
      if(_obj instanceof VirtuosoBlob)
	{
	  ((VirtuosoBlob)_obj).setInputStream(x,length);
	  try
	    {
	      ((VirtuosoBlob)_obj).setReader(new InputStreamReader (x, "UTF8"),length);
	    }
	  catch (UnsupportedEncodingException e)
	    {
	      ((VirtuosoBlob)_obj).setReader(new InputStreamReader (x),length);
	    }
	}
      else
	{
	  // Else create a Blob
	  if(x == null)
	    this.setNull(parameterIndex, Types.CLOB);
	  else
	    {
	      InputStreamReader rd;
	      try
		{
		  rd = new InputStreamReader (x, "UTF8");
		}
	      catch (UnsupportedEncodingException e)
		{
		  rd = new InputStreamReader (x);
		}
	      VirtuosoBlob bl = new VirtuosoBlob(rd, length, parameterIndex - 1);
	      bl.setInputStream (x, length);
	      objparams.setElementAt(bl, parameterIndex - 1);
	    }
	}
   }

   /**
    * Sets the designated parameter to a Java boolean value.  The driver converts this
    * to an SQL BIT value when it sends it to the database.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the parameter value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setBoolean
    */
   public void setBoolean(int parameterIndex, boolean x) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      objparams.setElementAt(new Boolean(x),parameterIndex - 1);
   }

   /**
    * Sets the designated parameter to a Java byte value.  The driver converts this
    * to an SQL TINYINT value when it sends it to the database.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the parameter value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setByte
    */
   public void setByte(int parameterIndex, byte x) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      objparams.setElementAt(new Byte(x),parameterIndex - 1);
   }

   /**
    * Sets the designated parameter to a Java array of bytes.  The driver converts
    * this to an SQL VARBINARY or LONGVARBINARY (depending on the
    * argument's size relative to the driver's limits on VARBINARYs)
    * when it sends it to the database.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the parameter value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setBytes
    */
   public void setBytes(int parameterIndex, byte x[]) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex +
	     " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);

      if(x == null)
	this.setNull(parameterIndex, Types.VARBINARY);
      else
	{
	  objparams.setElementAt(x, parameterIndex - 1);
	}
   }

   /**
    * Sets the designated parameter to a java.sql.Date value.  The driver converts this
    * to an SQL DATE value when it sends it to the database.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the parameter value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setDate
    */
   public void setDate(int parameterIndex, java.sql.Date x) throws VirtuosoException
   {
      setDate(parameterIndex,x,null);
   }

   /**
    * Sets the designated parameter to a Java double value.  The driver converts this
    * to an SQL DOUBLE value when it sends it to the database.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the parameter value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setDouble
    */
   public void setDouble(int parameterIndex, double x) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      objparams.setElementAt(new Double(x),parameterIndex - 1);
   }

   /**
    * Sets the designated parameter to a Java float value.  The driver converts this
    * to an SQL FLOAT value when it sends it to the database.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the parameter value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setFloat
    */
   public void setFloat(int parameterIndex, float x) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      objparams.setElementAt(new Float(x),parameterIndex - 1);
   }

   /**
    * Sets the designated parameter to a Java int value.  The driver converts this
    * to an SQL INTEGER value when it sends it to the database.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the parameter value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setInt
    */
   public void setInt(int parameterIndex, int x) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      objparams.setElementAt(new Integer(x),parameterIndex - 1);
   }

   /**
    * Sets the designated parameter to a Java long value.  The driver converts this
    * to an SQL BIGINT value when it sends it to the database.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the parameter value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setLong
    */
   public void setLong(int parameterIndex, long x) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      objparams.setElementAt(new Long(x),parameterIndex - 1);
   }

   /**
    * Sets the designated parameter to SQL NULL.
    *
    * Note: You must specify the parameter's SQL type.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param sqlType the SQL type code defined in java.sql.Types
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setNull
    */
   public void setNull(int parameterIndex, int sqlType) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      objparams.setElementAt(new VirtuosoNullParameter(sqlType, true),parameterIndex - 1);
   }

   /**
    * Sets the value of a parameter using an object; use the
    * java.lang equivalent objects for integral values.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the object containing the input parameter value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setObject
    */
   public void setObject(int parameterIndex, Object x) throws VirtuosoException
   {
      setObject(parameterIndex,x,Types.OTHER);
   }

   /**
    * Sets the value of the designated parameter with the given object.
    * This method is like setObject above, except that it assumes a scale of zero.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the object containing the input parameter value
    * @param targetSqlType the SQL type (as defined in java.sql.Types) to be
    * sent to the database
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setObject
    */
   public void setObject(int parameterIndex, Object x, int targetSqlType) throws VirtuosoException
   {
      setObject(parameterIndex,x,targetSqlType, 0);
   }


   /**
    * Sets the value of a parameter using an object. The second
    * argument must be an object type; for integral values, the
    * java.lang equivalent objects should be used.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the object containing the input parameter value
    * @param targetSqlType the SQL type (as defined in java.sql.Types) to be
    * sent to the database. The scale argument may further qualify this type.
    * @param scale for java.sql.Types.DECIMAL or java.sql.Types.NUMERIC types,
    * this is the number of digits after the decimal point.  For all other
    * types, this value will be ignored.
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setObject
    * @see java.sql.Types
    */
   public void setObject(int parameterIndex, Object x, int targetSqlType, int scale) throws VirtuosoException
   {
      //System.err.println ("setObject (" + parameterIndex + ", " + x + ", " + targetSqlType + ", " + scale);
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      if (x instanceof VirtuosoExplicitString)
	{
	  objparams.setElementAt(x, parameterIndex - 1);
	  return;
	}
      // After check, check if a Blob object is already associated or not
      Object _obj = objparams.elementAt(parameterIndex - 1);
      // Check now if it's a Blob
      if(_obj instanceof VirtuosoBlob)
      {
         ((VirtuosoBlob)_obj).setObject(x);
         return;
      }
      // Else create a Blob
      if(x == null) this.setNull(parameterIndex, Types.OTHER);
      x = VirtuosoTypes.mapJavaTypeToSqlType (x, targetSqlType, scale);
      if (x instanceof java.io.Serializable)
	{
	  //System.err.println ("setObject2 (" + parameterIndex + ", " + x + ", " + targetSqlType + ", " + scale);
	  objparams.setElementAt (x, parameterIndex - 1);
	}
      else
	throw new VirtuosoException ("Object " + x.getClass().getName() + " not serializable", "22023",
	    VirtuosoException.BADFORMAT);
   }

   /**
    * Sets the designated parameter to a Java short value.  The driver converts this
    * to an SQL SMALLINT value when it sends it to the database.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the parameter value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setShort
    */
   public void setShort(int parameterIndex, short x) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      objparams.setElementAt(new Short(x),parameterIndex - 1);
   }

   /**
    * Sets the designated parameter to a Java String value.  The driver converts this
    * to an SQL VARCHAR or LONGVARCHAR value (depending on the argument's
    * size relative to the driver's limits on VARCHARs) when it sends
    * it to the database.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the parameter value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setString
    */
   public void setString(int parameterIndex, String x) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " +
	     parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      if(x == null)
	this.setNull(parameterIndex, Types.VARCHAR);
      else
	{
	  if (parameters != null && parameters.elementAt(parameterIndex - 1) instanceof openlink.util.Vector)
	    {
	      openlink.util.Vector pd = (openlink.util.Vector)parameters.elementAt(parameterIndex - 1);
	      int dtp = ((Number)pd.elementAt (0)).intValue();
	      VirtuosoExplicitString ret;
	      ret = new VirtuosoExplicitString (x, dtp, connection);
	      objparams.setElementAt (ret, parameterIndex - 1);
	    }
	  else
	    {
	    objparams.setElementAt(x,parameterIndex - 1);
	}
   }
   }

   protected void setString(int parameterIndex, VirtuosoExplicitString x) throws VirtuosoException
   {
     if(parameterIndex < 1 || parameterIndex > parameters.capacity())
       throw new VirtuosoException("Index " +
	   parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
     if(x == null)
       this.setNull(parameterIndex, Types.VARCHAR);
     else
        objparams.setElementAt(x, parameterIndex - 1);
   }
   /**
    * Sets the designated parameter to a java.sql.Time value.  The driver converts this
    * to an SQL TIME value when it sends it to the database.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the parameter value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setTime
    */
   public void setTime(int parameterIndex, java.sql.Time x) throws VirtuosoException
   {
      setTime(parameterIndex,x,null);
   }

   /**
    * Sets the designated parameter to a java.sql.Timestamp value.  The driver
    * converts this to an SQL TIMESTAMP value when it sends it to the
    * database.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the parameter value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setTimeStamp
    */
   public void setTimestamp(int parameterIndex, java.sql.Timestamp x) throws VirtuosoException
   {
      setTimestamp(parameterIndex,x,null);
   }

   // --------------------------- JDBC 2.0 ------------------------------
   /**
    * Adds a set of parameters to the batch.
    *
    * @exception virtuoso.jdbc2.VirtuosoException  If a database access error occurs.
    * @see java.sql.PreparedStatement#addBatch
    */
   public void addBatch() throws VirtuosoException
   {
      // Check parameters and batch vector
      if(parameters == null)
         return;
      if(batch == null)
#if JDK_VER >= 16
         batch = new LinkedList<Object>();
#elif JDK_VER >= 12
         batch = new LinkedList();
#else
         batch = new openlink.util.Vector(10,10);
#endif
      // Add the sql request at the end
#if JDK_VER >= 12
      batch.add(objparams.clone());
#else
      batch.addElement(objparams.clone());
#endif
   }

   /**
    * Submits a batch of commands to the database for execution.
    *
    * @return an array of update counts containing one element for each
    * command in the batch.  The array is ordered according
    * to the order in which commands were inserted into the batch.
    * @exception BatchUpdateException if a database access error occurs or the
    * driver does not support batch statements
    */

   private void throwBatchUpdateException (int [] result, SQLException ex, int inx) throws BatchUpdateException
   {
     int [] _result = new int[inx + 1];
     System.arraycopy (result, 0, _result, 0, inx);
     _result[inx] = _EXECUTE_FAILED;
     throw new BatchUpdateException(ex.getMessage(), ex.getSQLState(), ex.getErrorCode(), _result);
   }

   private void throwBatchUpdateException (int [] result, String mess, int inx) throws BatchUpdateException
   {
     int [] _result = new int[inx + 1];
     System.arraycopy (result, 0, _result, 0, inx);
     _result[inx] = _EXECUTE_FAILED;
     throw new BatchUpdateException(mess, "HY000", 0, _result);
   }

   public int[] executeBatch() throws BatchUpdateException
   {
      // Check if the batch vector exists
      if(batch == null)
         return new int[0];
      // Else execute one by one SQL request
      int[] result = new int[batch.size()];
      // Flag to say if there's a problem
      boolean error = false;

      if (this instanceof VirtuosoCallableStatement && ((VirtuosoCallableStatement)this).hasOut())
	throwBatchUpdateException (result, "Batch can't execute calls with out params", 0);

      try
	{
      	  if (vresultSet.kindop()==VirtuosoTypes.QT_SELECT)
	    throwBatchUpdateException (result, "Batch executes only update statements", 0);

	  result = executeBatchUpdate ();
	}
      catch(VirtuosoException ex)
        {
	    throwBatchUpdateException (result, ex, 0);
	}
      finally
        {
#if JDK_VER >= 12
	  batch.clear();
#else
	  batch.removeAllElements();
#endif
	}


      return result;
   }

#if JDK_VER >= 12
   /**
    * Sets an Array parameter.
    *
    * @param i the first parameter is 1, the second is 2, ...
    * @param x an object representing an SQL array
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setArray
    */
   public void setArray(int i, Array x) throws VirtuosoException
   {
      // Check parameters
      if(i < 1 || i > parameters.capacity())
         throw new VirtuosoException("Index " + i + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      if(x == null){
          this.setNull(i, Types.ARRAY);
      } else if (x instanceof VirtuosoArray) {
          objparams.setElementAt(((VirtuosoArray)x).data, i - 1);
      } else {
          objparams.setElementAt(x,i - 1);
      }
   }
#endif

   /**
    * Sets a BLOB parameter.
    *
    * @param i the first parameter is 1, the second is 2, ...
    * @param x an object representing a BLOB
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setBlob
    */
#if JDK_VER >= 12
   public void setBlob(int i, Blob x) throws VirtuosoException
#else
   public void setBlob(int i, VirtuosoBlob x) throws VirtuosoException
#endif
   {
      // Check parameters
      if(i < 1 || i > parameters.capacity())
         throw new VirtuosoException("Index " + i + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      if(x == null) this.setNull(i, Types.BLOB);
      else objparams.setElementAt(x,i - 1);
   }

   /**
    * Sets the designated parameter to the given <code>Reader</code>
    * object, which is the given number of characters long.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the java reader which contains the UNICODE data
    * @param length the number of characters in the stream
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setCharacterStream
    */
   public void setCharacterStream(int parameterIndex, Reader x, int length) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);

      if (parameters != null && parameters.elementAt(parameterIndex - 1) instanceof openlink.util.Vector)
	{
	  openlink.util.Vector pd = (openlink.util.Vector)parameters.elementAt(parameterIndex - 1);
	  int dtp = ((Number)pd.elementAt (0)).intValue();
	  if (dtp != VirtuosoTypes.DV_BLOB &&
	      dtp != VirtuosoTypes.DV_BLOB_BIN &&
	      dtp != VirtuosoTypes.DV_BLOB_WIDE)
	    {
	      try
		{
		  StringBuffer buf = new StringBuffer();
		  char chars[] = new char [4096];
		  int read;
		  int total_read = 0;
		  int to_read;
		  String ret;

		  do
		    {
		      to_read = (length - total_read) > chars.length ? chars.length : (length - total_read);
		      read = x.read (chars, 0, to_read);
		      if (read > 0)
			{
			  buf.append (chars, 0, read);
			  total_read += read;
			}
		    }
		  while (read > 0 && total_read < length);
		  ret = buf.toString();
		  //System.err.println ("setCharStream : len=" + ret.length() + " [" + ret + "]");
		  if (connection.charset != null)
		    {
		      objparams.setElementAt (
			  new VirtuosoExplicitString (connection.charsetBytes (ret),
			    VirtuosoTypes.DV_STRING),
			  parameterIndex - 1);
		      //System.err.println ("setting DV_LONG_STRING");
		    }
		  else
		    objparams.setElementAt (ret, parameterIndex - 1);
		  return;
		}
	      catch (java.io.IOException e)
		{
		  throw new VirtuosoException ("Error reading from a character stream " + e.getMessage(),
		      VirtuosoException.IOERROR);
		}
	    }

	  if (dtp == VirtuosoTypes.DV_BLOB_BIN)
	    throw new VirtuosoException ("Passing character stream to LONG VARBINARY columns not supported",
		"IM001", VirtuosoException.NOTIMPLEMENTED);
	}

      // After check, check if a Blob object is already associated or not
      //System.err.println ("after check");
      Object _obj = objparams.elementAt(parameterIndex - 1);
      // Check now if it's a Blob
      if(_obj instanceof VirtuosoBlob)
      {
         ((VirtuosoBlob)_obj).setReader(x,length);
         return;
      }
      // Else create a Clob
      if(x == null) this.setNull(parameterIndex, Types.BLOB);
      else objparams.setElementAt(new VirtuosoBlob(x,length,parameterIndex - 1),parameterIndex - 1);
   }

   /**
    * Sets a CLOB parameter.
    *
    * @param i the first parameter is 1, the second is 2, ...
    * @param x an object representing a CLOB
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setClob
    */
#if JDK_VER >= 12
   public void setClob(int i, Clob x) throws VirtuosoException
#else
   public void setClob(int i, VirtuosoClob x) throws VirtuosoException
#endif
   {
      // Check parameters
      if(i < 1 || i > parameters.capacity())
         throw new VirtuosoException("Index " + i + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      if(x == null) this.setNull(i, Types.CLOB);
      else objparams.setElementAt(x,i - 1);
   }

   /**
    * Sets the designated parameter to SQL NULL.  This version of setNull should
    * be used for user-named types and REF type parameters.  Examples
    * of user-named types include: STRUCT, DISTINCT, JAVA_OBJECT, and
    * named array types.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param sqlType a value from java.sql.Types
    * @param typeName the fully-qualified name of an SQL user-named type,
    *  ignored if the parameter is not a user-named type or REF
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setNull
    */
   public void setNull(int paramIndex, int sqlType, String typeName) throws VirtuosoException
   {
      setNull(paramIndex,sqlType);
   }

#if JDK_VER >= 12
   /**
    * Sets a REF(&lt;structured-type&gt;) parameter.
    *
    * @param i the first parameter is 1, the second is 2, ...
    * @param x an object representing data of an SQL REF Type
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setRef
    */
   public void setRef(int i, Ref x) throws VirtuosoException
   {
      // Check parameters
      if(i < 1 || i > parameters.capacity())
         throw new VirtuosoException("Index " + i + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      if(x == null) this.setNull(i, Types.REF);
      else objparams.setElementAt(x,i - 1);
   }
#endif

   /**
    * Sets the designated parameter to a java.sql.Date value,
    * using the given Calendar object.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the parameter value
    * @param cal the Calendar object the driver will use
    * to construct the date
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setDate
    */
   public void setDate(int parameterIndex, java.sql.Date x, Calendar cal) throws VirtuosoException
     {
       // Check parameters
       if(parameterIndex < 1 || parameterIndex > parameters.capacity())
	 throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
       if(x == null)
	 this.setNull(parameterIndex, Types.DATE);
       else
	 {
	   if(cal != null)
	     {
	       x = new java.sql.Date (VirtuosoTypes.timeFromCal(x, cal));
	     }
	   objparams.setElementAt(x,parameterIndex - 1);
	 }
     }

   /**
    * Sets the designated parameter to a java.sql.Time value,
    * using the given Calendar object.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the parameter value
    * @param cal the <code>Calendar</code> object the driver will use
    * to construct the time
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setTime
    */
   public void setTime(int parameterIndex, java.sql.Time x, Calendar cal) throws VirtuosoException
     {
       // Check parameters
       if(parameterIndex < 1 || parameterIndex > parameters.capacity())
	 throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
       if(x == null)
	 this.setNull(parameterIndex, Types.TIME);
       else
	 {
	   if(cal != null)
	     {
	       x = new java.sql.Time (VirtuosoTypes.timeFromCal(x, cal));
	     }
	   objparams.setElementAt(x,parameterIndex - 1);
	 }
     }

   /**
    * Sets the designated parameter to a java.sql.Timestamp value,
    * using the given Calendar object.
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    * @param x the parameter value
    * @param cal the <code>Calendar</code> object the driver will use
    * to construct the timestamp
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see java.sql.PreparedStatement#setTimestamp
    */
   public void setTimestamp(int parameterIndex, java.sql.Timestamp x, Calendar cal) throws VirtuosoException
     {
       // Check parameters
       if(parameterIndex < 1 || parameterIndex > parameters.capacity())
	 throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
       if(x == null)
	 this.setNull(parameterIndex, Types.TIMESTAMP);
       else
	 {
	   if(cal != null)
	     {
	       int nanos = x.getNanos();
	       x = new java.sql.Timestamp(VirtuosoTypes.timeFromCal(x, cal));
               x.setNanos (nanos);
	     }
	   objparams.setElementAt(x,parameterIndex - 1);
	 }
     }
#if JDK_VER >= 14
   /* JDK 1.4 functions */

    /**
     * Sets the designated parameter to the given <code>java.net.URL</code> value.
     * The driver converts this to an SQL <code>DATALINK</code> value
     * when it sends it to the database.
     *
     * @param parameterIndex the first parameter is 1, the second is 2, ...
     * @param x the <code>java.net.URL</code> object to be set
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public void setURL(int parameterIndex, java.net.URL x) throws SQLException
     {
       throw new VirtuosoException ("DATALINK not supported", VirtuosoException.NOTIMPLEMENTED);
     }

    /**
     * Retrieves the number, types and properties of this
     * <code>PreparedStatement</code> object's parameters.
     *
     * @return a <code>ParameterMetaData</code> object that contains information
     *         about the number, types and properties of this
     *         <code>PreparedStatement</code> object's parameters
     * @exception SQLException if a database access error occurs
     * @see ParameterMetaData
     * @since 1.4
     */
   public ParameterMetaData getParameterMetaData() throws SQLException
     {
       return paramsMetaData == null ? new VirtuosoParameterMetaData(null, connection) : paramsMetaData;
     }

#if JDK_VER >= 16
    //------------------------- JDBC 4.0 -----------------------------------

    /**
     * Sets the designated parameter to the given <code>java.sql.RowId</code> object. The
     * driver converts this to a SQL <code>ROWID</code> value when it sends it
     * to the database
     *
     * @param parameterIndex the first parameter is 1, the second is 2, ...
     * @param x the parameter value
     * @throws SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if a database access error occurs or
     * this method is called on a closed <code>PreparedStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     *
     * @since 1.6
     */
  public void setRowId(int parameterIndex, RowId x) throws SQLException
  {
    throw new VirtuosoFNSException ("Method  setRowId(parameterIndex, x)  isn't supported", VirtuosoException.NOTIMPLEMENTED);
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
     * @throws SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; if a database access error occurs; or
     * this method is called on a closed <code>PreparedStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public synchronized void setNString(int parameterIndex, String value) throws SQLException
  {
    setString(parameterIndex, value);
  }

    /**
     * Sets the designated parameter to a <code>Reader</code> object. The
     * <code>Reader</code> reads the data till end-of-file is reached. The
     * driver does the necessary conversion from Java character format to
     * the national character set in the database.
     * @param parameterIndex of the first parameter is 1, the second is 2, ...
     * @param value the parameter value
     * @param length the number of characters in the parameter data.
     * @throws SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; if a database access error occurs; or
     * this method is called on a closed <code>PreparedStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public synchronized void setNCharacterStream(int parameterIndex, Reader value, long length) throws SQLException
  {
    setCharacterStream(parameterIndex, value, length);
  }

    /**
     * Sets the designated parameter to a <code>java.sql.NClob</code> object. The driver converts this to a
     * SQL <code>NCLOB</code> value when it sends it to the database.
     * @param parameterIndex of the first parameter is 1, the second is 2, ...
     * @param value the parameter value
     * @throws SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; if a database access error occurs; or
     * this method is called on a closed <code>PreparedStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public synchronized void setNClob(int parameterIndex, NClob value) throws SQLException
  {
    if (value == null) {
      setNull(parameterIndex, java.sql.Types.NCLOB);
    } else {
      setNCharacterStream(parameterIndex, value.getCharacterStream(), value.length());
    }
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
     * @throws SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if a database access error occurs; this method is called on
     * a closed <code>PreparedStatement</code> or if the length specified is less than zero.
     *
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public void setClob(int parameterIndex, Reader reader, long length)
       throws SQLException
  {
    setCharacterStream(parameterIndex, reader, length);
  }

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
     * @throws SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if a database access error occurs;
     * this method is called on a closed <code>PreparedStatement</code>;
     *  if the length specified
     * is less than zero or if the number of bytes in the inputstream does not match
     * the specfied length.
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     *
     * @since 1.6
     */
  public void setBlob(int parameterIndex, InputStream inputStream, long length)
        throws SQLException
  {
    setBinaryStream(parameterIndex, inputStream, (int)length);
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
  public synchronized void setNClob(int parameterIndex, Reader reader, long length)
       throws SQLException
  {
    if (reader == null) {
      setNull(parameterIndex, java.sql.Types.LONGVARCHAR);
    } else {
      setNCharacterStream(parameterIndex, reader, length);
    }
  }

     /**
      * Sets the designated parameter to the given <code>java.sql.SQLXML</code> object.
      * The driver converts this to an
      * SQL <code>XML</code> value when it sends it to the database.
      * <p>
      *
      * @param parameterIndex index of the first parameter is 1, the second is 2, ...
      * @param xmlObject a <code>SQLXML</code> object that maps an SQL <code>XML</code> value
      * @throws SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if a database access error occurs;
      *  this method is called on a closed <code>PreparedStatement</code>
      * or the <code>java.xml.transform.Result</code>,
      *  <code>Writer</code> or <code>OutputStream</code> has not been closed for
      * the <code>SQLXML</code> object
      * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
      *
      * @since 1.6
      */
  public synchronized void setSQLXML(int parameterIndex, SQLXML xmlObject) throws SQLException
  {
    throw new VirtuosoFNSException ("Method  setSQLXML(parameterIndex, xmlObject)  isn't supported", VirtuosoException.NOTIMPLEMENTED);
/*********
//??TODO
*******/
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
     * @param parameterIndex the first parameter is 1, the second is 2, ...
     * @param x the Java input stream that contains the ASCII parameter value
     * @param length the number of bytes in the stream
     * @exception SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if a database access error occurs or
     * this method is called on a closed <code>PreparedStatement</code>
     * @since 1.6
    */
  public void setAsciiStream(int parameterIndex, java.io.InputStream x, long length)
	    throws SQLException
  {
    setAsciiStream(parameterIndex, x, (int)length);
  }

    /**
     * Sets the designated parameter to the given input stream, which will have
     * the specified number of bytes.
     * When a very large binary value is input to a <code>LONGVARBINARY</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.InputStream</code> object. The data will be read from the
     * stream as needed until end-of-file is reached.
     *
     * <P><B>Note:</B> This stream object can either be a standard
     * Java stream object or your own subclass that implements the
     * standard interface.
     *
     * @param parameterIndex the first parameter is 1, the second is 2, ...
     * @param x the java input stream which contains the binary parameter value
     * @param length the number of bytes in the stream
     * @exception SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if a database access error occurs or
     * this method is called on a closed <code>PreparedStatement</code>
     * @since 1.6
     */
  public void setBinaryStream(int parameterIndex, java.io.InputStream x,
			 long length) throws SQLException
  {
    setBinaryStream(parameterIndex, x, (int)length);
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
     * @param parameterIndex the first parameter is 1, the second is 2, ...
     * @param reader the <code>java.io.Reader</code> object that contains the
     *        Unicode data
     * @param length the number of characters in the stream
     * @exception SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if a database access error occurs or
     * this method is called on a closed <code>PreparedStatement</code>
     * @since 1.6
     */
  public void setCharacterStream(int parameterIndex, java.io.Reader reader,
			  long length) throws SQLException
  {
    setCharacterStream(parameterIndex, reader, (int)length);
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
     * @param parameterIndex the first parameter is 1, the second is 2, ...
     * @param x the Java input stream that contains the ASCII parameter value
     * @exception SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if a database access error occurs or
     * this method is called on a closed <code>PreparedStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
       * @since 1.6
    */
  public void setAsciiStream(int parameterIndex, java.io.InputStream x)
	    throws SQLException
  {
    throw new VirtuosoFNSException ("Method  setAsciiStream(parameterIndex, x)  isn't supported", VirtuosoException.NOTIMPLEMENTED);
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
     * @param parameterIndex the first parameter is 1, the second is 2, ...
     * @param x the java input stream which contains the binary parameter value
     * @exception SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if a database access error occurs or
     * this method is called on a closed <code>PreparedStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public void setBinaryStream(int parameterIndex, java.io.InputStream x)
    throws SQLException
  {
    throw new VirtuosoFNSException ("Method  setAsciiStream(parameterIndex, x)  isn't supported", VirtuosoException.NOTIMPLEMENTED);
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
     * @param parameterIndex the first parameter is 1, the second is 2, ...
     * @param reader the <code>java.io.Reader</code> object that contains the
     *        Unicode data
     * @exception SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if a database access error occurs or
     * this method is called on a closed <code>PreparedStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public void setCharacterStream(int parameterIndex,
       			  java.io.Reader reader) throws SQLException
  {
    throw new VirtuosoFNSException ("Method  setCharacterStream(parameterIndex, reader)  isn't supported", VirtuosoException.NOTIMPLEMENTED);
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
     * @param parameterIndex of the first parameter is 1, the second is 2, ...
     * @param value the parameter value
     * @throws SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; if a database access error occurs; or
     * this method is called on a closed <code>PreparedStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public void setNCharacterStream(int parameterIndex, Reader value) throws SQLException
  {
    throw new VirtuosoFNSException ("Method  setNCharacterStream(parameterIndex, value)  isn't supported", VirtuosoException.NOTIMPLEMENTED);
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
     * @throws SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if a database access error occurs; this method is called on
     * a closed <code>PreparedStatement</code>or if parameterIndex does not correspond to a parameter
     * marker in the SQL statement
     *
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public void setClob(int parameterIndex, Reader reader)
       throws SQLException
  {
    throw new VirtuosoFNSException ("Method  setClob(parameterIndex, reader)  isn't supported", VirtuosoException.NOTIMPLEMENTED);
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
     * @throws SQLException if parameterIndex does not correspond to a parameter
     * marker in the SQL statement; if a database access error occurs;
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
    throw new VirtuosoFNSException ("Method  setBlob(parameterIndex, inputStream)  isn't supported", VirtuosoException.NOTIMPLEMENTED);
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
  public void setNClob(int parameterIndex, Reader reader)
       throws SQLException
  {
    throw new VirtuosoFNSException ("Method  setNClob(parameterIndex, reader)  isn't supported", VirtuosoException.NOTIMPLEMENTED);
  }
#endif
#endif

  protected synchronized void setClosed(boolean flag)
  {
    close_flag = flag;
  }

}
