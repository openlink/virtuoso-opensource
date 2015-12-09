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

import java.util.*;
import java.sql.*;
import java.math.*;
import java.io.*;
import openlink.util.*;

/**
 * The VirtuosoResultSet class is an implementation of the ResultSet interface
 * in the JDBC API which represents result of a query.
 * You can obtain a ResultSet like below :
 * <pre>
 *   <code>ResultSet rs = statement.executeQuery("SELECT * FROM TABLE ...")</code>
 * </pre>
 *
 * @version 1.0 (JDBC API 2.0 implementation)
 * @see java.sql.ResultSet
 * @see virtuoso.jdbc2.VirtuosoStatement
 * @see virtuoso.jdbc2.VirtuosoPreparedStatement
 * @see virtuoso.jdbc2.VirtuosoCallableStatement
 */
public class VirtuosoResultSet implements ResultSet
{
   // Messages error
   private static final String er1 = "I/O error on output stream.";

   // The array of rows of this result set
   protected openlink.util.Vector rows = new openlink.util.Vector(20);

   // The row to update or insert
   private Object[] row;

   // The result set concurrency
   private int concurrency;

   // The direction in which fetches occur
   private int fetchDirection;

   // The number of rows to be fetched for each query
   private int prefetch;

   // The result set type
   private int type;

   // The statement which owns this result set
   private VirtuosoStatement statement;

   private boolean is_prepared;

   // Its meta data
   protected VirtuosoResultSetMetaData metaData;

   // Max number of rows
   private int maxRows;

   protected int totalRows;

   // Flag to let know if results processed
   private boolean is_complete;

   // The update count
   private int updateCount;

   // The name cursor of this result set
   private String cursorName;

   // The current row visible
   protected int currentRow;

   // the current row in the current fetch window
   protected int stmt_current_of;

   // the number of rows to get in the current fetch window
   protected int stmt_n_rows_to_get;

   // the number of rows to get in the current fetch window
   protected boolean stmt_co_last_in_batch;

   private int oldRow;

   // The nullability of the las column read
   private boolean wasNull = false, rowIsDeleted = false, rowIsUpdated = false, rowIsInserted = false;

   // A flag to know if this result set group all results
   private boolean more_result;

   protected boolean isLastResult = false;
   protected boolean isLastRow = false;

   // A flag to know which kind of op was retrieved
   private int kindop;

   // The prepare statement for the set_pos function
   private VirtuosoPreparedStatement pstmt;

   private int rowNum = 0;

   /**
    * JDBC 2.0 extension.
    * The type for a <code>ResultSet</code> object whose cursor may
    * move only forward.
    */
   public static final int TYPE_FORWARD_ONLY = 1003;

   /**
    * JDBC 2.0 extension.
    * The type for a <code>ResultSet</code> object that is scrollable
    * but generally not sensitive to changes made by others.
    *
    */
   public static final int TYPE_SCROLL_INSENSITIVE = 1004;

   /**
    * JDBC 2.0 extension.
    * The type for a <code>ResultSet</code> object that is scrollable
    * and generally sensitive to changes made by others.
    */
   public static final int TYPE_SCROLL_SENSITIVE = 1005;

   /**
    * JDBC 2.0 extension.
    * The rows in a result set will be processed in a forward direction;
    * first-to-last.
    */
   public static final int FETCH_FORWARD = 1000;

   /**
    * JDBC 2.0 extension.
    * The rows in a result set will be processed in a reverse direction;
    * last-to-first.
    */
   public static final int FETCH_REVERSE = 1001;

   /**
    * JDBC 2.0 extension.
    * The order in which rows in a result set will be processed is unknown.
    */
   public static final int FETCH_UNKNOWN = 1002;

   /**
    * JDBC 2.0 extension.
    * The concurrency mode for a <code>ResultSet</code> object
    * that may NOT be updated.
    *
    */
   public static final int CONCUR_READ_ONLY = 1007;

   /**
    * JDBC 2.0 extension.
    * The concurrency mode for a <code>ResultSet</code> object
    * that may be updated.
    *
    */
   public static final int CONCUR_UPDATABLE = 1008;

   /**
    * Constructs a new VirtuosoResultSet.
    *
    * @param connection The VirtuosoConnection which owns it.
    * @param metaData   The metadata of the result. (It can be null)
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   VirtuosoResultSet(VirtuosoStatement statement, VirtuosoResultSetMetaData metaData, boolean isPrepare) throws VirtuosoException
   {
      this.statement = statement;
      this.metaData = metaData;
      // Set some variables from the statement
      fetchDirection = statement.getFetchDirection();
      concurrency = statement.getResultSetConcurrency();
      type = statement.getResultSetType();
      prefetch = statement.getFetchSize();
      maxRows = statement.getMaxRows();
      cursorName = (statement.cursorName == null) ? statement.statid : statement.cursorName;
      // Create the result
      stmt_current_of = -1;
      stmt_n_rows_to_get = prefetch;
      stmt_co_last_in_batch = false;
      is_prepared = isPrepare;
      //System.err.print ("init: rows :");
      //System.err.println (rows.toString());
      process_result(isPrepare);
      //System.err.print ("init: after process : rows :");
      //System.err.println (rows.toString());
   }

   /**
    * Constructs a new empty VirtuosoResultSet.
    *
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   VirtuosoResultSet(VirtuosoConnection vc) throws VirtuosoException
   {
      this.statement = new VirtuosoStatement (vc);
      this.metaData = new VirtuosoResultSetMetaData (null, vc);
      type = VirtuosoResultSet.TYPE_FORWARD_ONLY;
      is_complete = true;
   }

   protected VirtuosoResultSet(VirtuosoConnection vc, String [] col_names, int [] col_dtps) throws VirtuosoException
   {
      this.statement = new VirtuosoStatement (vc);
      this.metaData = new VirtuosoResultSetMetaData (vc, col_names, col_dtps);
      type = VirtuosoResultSet.TYPE_FORWARD_ONLY;
      is_complete = true;
   }

   /**
    * Method uses to get next rows of this result set.
    *
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred
    */
   protected void getMoreResults(boolean isPrepare) throws VirtuosoException
   {
     synchronized (statement.connection)
       {
	 //System.err.println ("getMoreResults");
	 // Reset some flags
	 rowIsDeleted = rowIsUpdated = rowIsInserted = is_complete = false;
	 currentRow = 0;
	 // Delete older rows
	 if(rows == null)
	   rows = new openlink.util.Vector(20);
	 else
	   rows.removeAllElements();
	 // One more time
	 process_result(isPrepare);
	 more_result = true;
	 //System.err.print ("more_results: after process : rows :");
	 //System.err.println (rows.toString());
       }
   }

   /**
    * Method uses to retrieve the Update count.
    *
    * @return nb	The Update count.
    */
   protected int getUpdateCount()
   {
      return updateCount;
   }

   protected void setUpdateCount(int n)
   {
      updateCount = n;
   }

   /**
    * Method uses with cursor scrollable (implementation of the ExtFetch RPC)
    *
    * @param op	The kind of operation (SQL_FETCH_xxx)
    * @param firstline	The beginning line
    * @param nbline	Number og lines to get
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred;
    */
   private void fetch_rpc() throws VirtuosoException
   {
      try
      {
	synchronized (statement.connection)
	  {
	    // Ask more results
	    Object[] args = new Object[2];
	    // Fill the statement id,the operation, and the beginning line
	    args[0] = statement.statid;
	    // the future number
	    args[1] = new Long(statement.future.hashCode());
	    // Send the RPC message
	    statement.connection.removeFuture(statement.connection.getFuture(
		  VirtuosoFuture.fetch,args, statement.rpc_timeout));
	  }
      }
      catch(IOException e)
      {
         throw new VirtuosoException("Problem during serialization : " + e.getMessage(),VirtuosoException.IOERROR);
      }
   }

   /**
    * Method used with forward-only cursor (implementation of the Fetch RPC)
    *
    * @param op	The kind of operation (SQL_FETCH_xxx)
    * @param firstline	The beginning line
    * @param nbline	Number og lines to get
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred;
    */
   private void extended_fetch(int op, long firstline, long nbline) throws VirtuosoException
   {
      try
      {
	synchronized (statement.connection)
	  {
	    // Ask more results
	    Object[] args = new Object[6];
	    // Fill the statement id,the operation, and the beginning line
	    args[0] = statement.statid;
	    args[1] = new Long(op);
	    args[2] = new Long(firstline);
	    args[3] = new Long(nbline);
	    // Fill the autocommit mode
	    args[4] = new Long((statement.connection.getAutoCommit()) ? 1 : 0);
	    // Fill the bookmark (never used for the moment in JDBC)
	    args[5] = null;
	    // Send the RPC message
	    statement.future = statement.connection.getFuture(
		VirtuosoFuture.extendedfetch,args, statement.rpc_timeout);

	    getMoreResults(false);
	    // Remove future
	    //statement.connection.removeFuture(statement.future);
	    if (statement.connection.getAutoCommit())
	      process_result(false);
	  }
      }
      catch(IOException e)
      {
         throw new VirtuosoException("Problem during serialization : " + e.getMessage(),VirtuosoException.IOERROR);
      }
   }

   /**
    * Method uses with cursor scrollable / updatable (implementation of the SetPos function)
    *
    * @param op	Operation of the SetPos (SQL_xxx ...)
    * @param args Vector of vectors
    * @param num	Line number to affect
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred;
    */
   private void set_pos(int op, openlink.util.Vector args, long num) throws VirtuosoException
   {
      if(pstmt == null)
         pstmt = (VirtuosoPreparedStatement)(statement.connection.prepareStatement("__set_pos(?,?,?,?)"));
      pstmt.setString(1,statement.statid);
      pstmt.setLong(2,op);
      pstmt.setLong(3,num);
      pstmt.setVector(4,args);
      pstmt.execute();
      // Treat depending the operation
      synchronized (statement.connection)
	{
	  switch(op)
	    {
	      case VirtuosoTypes.SQL_DELETE:
		  do
		    {
		      pstmt.vresultSet.getMoreResults(false);
		    }
		  while(!pstmt.vresultSet.isLastRow && isLastResult);
		  rowIsDeleted = (pstmt.vresultSet.getUpdateCount() > 0);
		  break;
	      case VirtuosoTypes.SQL_UPDATE:
		  pstmt.vresultSet.metaData = metaData;
		  pstmt.vresultSet.rows = rows;
		  pstmt.vresultSet.totalRows = totalRows;
		  pstmt.vresultSet.currentRow = currentRow;
		  do
		    {
		      // Reset some flags
		      pstmt.vresultSet.is_complete = pstmt.vresultSet.more_result = false;
		      pstmt.vresultSet.process_result(false);
		    }
		  while(!pstmt.vresultSet.isLastRow && isLastResult);
		  rowIsUpdated = (pstmt.vresultSet.getUpdateCount() > 0);
		  break;
	      case VirtuosoTypes.SQL_ADD:
		  do
		    {
		      pstmt.vresultSet.getMoreResults(false);
		    }
		  while(!pstmt.vresultSet.isLastRow && isLastResult);
		  rowIsInserted = (pstmt.vresultSet.getUpdateCount() > 0);
		  break;
	      case VirtuosoTypes.SQL_REFRESH:
		  pstmt.vresultSet.metaData = metaData;
		  pstmt.vresultSet.rows = rows;
		  pstmt.vresultSet.totalRows = totalRows;
		  pstmt.vresultSet.currentRow = currentRow;
		  do
		    {
		      // Reset some flags
		      pstmt.vresultSet.is_complete = pstmt.vresultSet.more_result = false;
		      pstmt.vresultSet.process_result(false);
		    }
		  while(pstmt.vresultSet.more_result());
		  totalRows = pstmt.vresultSet.totalRows;
		  break;
	    }
	  ;
	  // Clear fields in the pstmt for future uses
	  pstmt.vresultSet.rows = null;
	}
   }

   /**
    * Method processes the result queue to format rows and metadata.
    *
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred;
    */
   private void process_result(boolean isPrepare) throws VirtuosoException
   {
      Object curr;
      openlink.util.Vector result;
      // While the result set is not deserialized
      more_result = false;
      for(int i = 0;!is_complete;)
      {
         // Check if others result set can be set
         if(rows.size() == statement.getMaxRows() && rows.size() > 0)
         {
	   //System.err.println ("process_result1: rows.size() == statement.getMaxRows()");
	   //System.err.println ("process_result2: rows.size()=" + rows.size());
	   //System.err.println ("process_result3: statement.getMaxRows()= " + statement.getMaxRows());
            is_complete = true;
	    continue;
         }
	 if (statement == null || statement.future == null)
	   throw new VirtuosoException ("Statement closed. Operation not applicable",
	       VirtuosoException.MISCERROR);
         // Get the next row (if one exist else null)
	 synchronized (statement) { statement.wait_result = true; }
	 curr = statement.future.nextResult();
	 synchronized (statement) { statement.wait_result = false; }
	 curr = (curr==null)?null:((openlink.util.Vector)curr).firstElement();
	 //String xx;
	 //if (curr != null)
	 //  xx = ("process_result4 :" + curr.toString());
	 //else
	 //  xx = ("process_result5 :<null>");
	 //System.out.println (xx);
         // Get the result vector
         if(curr instanceof openlink.util.Vector)
         {
	     //System.out.println ("process_result7 :is a vector");
            result = (openlink.util.Vector)curr;
            switch(((Short)result.firstElement()).intValue())
            {
               case VirtuosoTypes.QA_LOGIN:
		  //System.out.println("--> QA_LOGIN");
		  statement.connection.qualifier = (String)result.elementAt(1);
		  break;
               case VirtuosoTypes.QA_ROW_LAST_IN_BATCH:
		  //System.out.println("--> QA_ROW_LAST_IN_BATCH");
		  if (statement.type != TYPE_FORWARD_ONLY)
		    is_complete = true;
		  else
		    stmt_co_last_in_batch = true;
               case VirtuosoTypes.QA_ROW:
                  //System.out.println("---> QA_ROW");
                  isLastRow = false;
                  result.removeElementAt(0);
                  fixReturnedData(result);
                  // Get each row
                  if(currentRow == 0)
                     rows.insertElementAt(new VirtuosoRow(this,result),i++);
                  else
                     rows.setElementAt(new VirtuosoRow(this,result),currentRow - 1);
		  if (statement.type == TYPE_FORWARD_ONLY)
		    return;
		  else if (i >= ((prefetch == 0) ? VirtuosoTypes.DEFAULTPREFETCH : prefetch))
		    return;
                  break;
               case VirtuosoTypes.QA_COMPILED:
                  //System.out.println("---> QA_COMPILED");
                  openlink.util.Vector v = (openlink.util.Vector)result.elementAt(1);
                  // First of all, set the kind of operation
                  Number kop = (Number)v.elementAt(1);
                  if(kop == null)
                  {
		     kindop = VirtuosoTypes.QT_UPDATE;
                     if (statement != null)
                     {
                        if (statement.getExecType() == VirtuosoTypes.QT_SELECT)
                          throw new VirtuosoException("executeUpdate can't execute update/insert/delete queries",VirtuosoException.BADPARAM);
                     }
                     if(!(statement instanceof VirtuosoPreparedStatement))
                     {
		       //System.err.println ("process_result6: QA_COMPILED on PreparedStatement");
                        statement.metaData = metaData =
			    new VirtuosoResultSetMetaData(null,statement.connection);
                        break;
                     }
                  // An error will occur or it's a null query
                  }
                  else
                  {
                     kindop = kop.intValue();
                     if (statement != null)
                     {
                        if (statement.getExecType() == VirtuosoTypes.QT_UPDATE && kindop == VirtuosoTypes.QT_SELECT)
                          throw new VirtuosoException("executeUpdate can execute only update/insert/delete queries",VirtuosoException.BADPARAM);
                        if (statement.getExecType() == VirtuosoTypes.QT_SELECT && kindop == VirtuosoTypes.QT_UPDATE)
                          throw new VirtuosoException("executeUpdate can't execute update/insert/delete queries",VirtuosoException.BADPARAM);
                     }
                  }
                  //mutexKindOp.freeSem();
                  // Get meta data of this result set
                  if(metaData != null)
                     metaData.close();
                  statement.metaData = metaData =
		      new VirtuosoResultSetMetaData(v,statement.connection);
		  //more_result = true;
                  //mutexMetaData.freeSem();
                  // Check if it's a prepared statement
                  if(statement instanceof PreparedStatement && isPrepare)
                  {
                     Object obj = v.elementAt(3);
                     statement.objparams = null;
#if JDK_VER >= 14
		     statement.paramsMetaData = null;
#endif
                     if(obj!=null && obj instanceof openlink.util.Vector)
		       {
		         fixReturnedData((openlink.util.Vector)obj);
                         statement.objparams = (openlink.util.Vector)obj;
			 statement.parameters = (openlink.util.Vector)statement.objparams.clone();

                         if (statement instanceof CallableStatement)
                           {
                             VirtuosoCallableStatement _statement = (VirtuosoCallableStatement)statement;
			     _statement.param_type = new int[statement.parameters.capacity()];
			     _statement.param_scale = new int[statement.parameters.capacity()];
			     for (int _i = 0; _i < _statement.param_type.length; _i++)
			       {
				 _statement.param_type[_i] = Types.OTHER;
				 _statement.param_scale[_i] = 0;
			       }
			   }

			 is_complete = true;
#if JDK_VER >= 14
			 statement.paramsMetaData =
                          new VirtuosoParameterMetaData ((openlink.util.Vector)obj, statement.connection);
#endif
		       }
		     else
		       {
		         statement.parameters = null;
		       }
                  }
                  break;
               case VirtuosoTypes.QA_ROWS_AFFECTED:
                  //System.out.println("---> QA_ROWS_AFFECTED");
                  //Set the number of rows affected
                  if(type != VirtuosoResultSet.TYPE_FORWARD_ONLY)
                  {
                     totalRows = ((Number)result.elementAt(1)).intValue();
                     updateCount = 0;
                     is_complete = true;
                  }
                  else
                  {
                     updateCount = ((Number)result.elementAt(1)).intValue();
                     is_complete = true;
                  }
                  isLastRow = true;
                  if (kindop != VirtuosoTypes.QT_PROC_CALL)
                    isLastResult = true;
                  break;
               case VirtuosoTypes.QA_ROW_DELETED:
                  //System.out.println("---> QA_ROWS_DELETED");
                  result.removeElementAt(0);
                  //rows.removeElementAt(((Number)((openlink.util.Vector)((openlink.util.Vector)result.elementAt(0)).elementAt(1)).elementAt(0)).intValue());
                  rows.removeElementAt(currentRow - 1);
                  totalRows--;
                  break;
               case VirtuosoTypes.QA_ROW_UPDATED:
                  //System.out.println("---> QA_ROWS_UPDATED");
                  result.removeElementAt(0);
                  result.removeElementAt(result.size() - 1);
                  /*openlink.util.Vector bm = (openlink.util.Vector)result.lastElement(); result.removeElementAt(result.size()-1);
                     rows.setElementAt(new VirtuosoRow(this,result),((Number)((openlink.util.Vector)bm.elementAt(1)).elementAt(0)).intValue());*/
                  fixReturnedData(result);
                  rows.setElementAt(new VirtuosoRow(this,result),currentRow - 1);
                  break;
               case VirtuosoTypes.QA_ERROR:
		  if (VirtuosoFuture.rpc_log != null)
		  {
			  VirtuosoFuture.rpc_log.println ("---> QA_ERROR err=[" + (String)result.elementAt(2) + "] stat=[" + (String)result.elementAt(1) + "]");
		  }
                  isLastResult = true;
                  isLastRow = true;
                  //System.out.println("---> QA_ERROR err=[" + (String)result.elementAt(2) + "] stat=[" + (String)result.elementAt(1) + "]");
                  // Throw an exception corresponding the error
                  throw new VirtuosoException((String)result.elementAt(2),(String)result.elementAt(1),VirtuosoException.SQLERROR);
               case VirtuosoTypes.QA_WARNING:
                  //System.out.println("---> QA_WARNING");
                  // Set an SQLWaring corresponding the server one
                  statement.connection.setWarning (
			  new SQLWarning(
			      (String)result.elementAt(2),
			      (String)result.elementAt(1),
			      VirtuosoException.SQLERROR));
		  break;
               case VirtuosoTypes.QA_PROC_RETURN:
                  //System.out.println("---> QA_PROC_RETURN " + result + " " + statement.objparams);
                  // Copy out parameters in the parameter vector
                  if (statement.objparams == null)
		      statement.objparams = new openlink.util.Vector(result.size() - 2);

		  for(int j = 0; j < statement.objparams.size() && (j+2) < result.size(); j++)
		  {
		     Object val = result.elementAt(j+2);
		     if (val instanceof DateObject)
		       statement.objparams.setElementAt(((DateObject)val).getValue(statement.sparql_executed),j);
		     else
		       statement.objparams.setElementAt(val,j);
		  }

                  is_complete = true;
                  isLastResult = true;
                  isLastRow = true;
		  break;
               case VirtuosoTypes.QA_NEED_DATA:
		  sendBlobData(result);
		  break;
               default:
                  // Throw an exception
                  throw new VirtuosoException(curr.toString(),VirtuosoException.UNKNOWN);
            }
            ;
         }
         else
         {
            isLastRow = true;
            if (kindop != VirtuosoTypes.QT_PROC_CALL)
               isLastResult = true;
            // Catch a null which means that there are others rows
            if(curr == null)
            {
	       //System.out.println("process_result9 :---> NULL");
               more_result = true;
               is_complete = true;
               continue;
            }
	     //System.out.println ("process_result8 :is a " + curr.getClass().getName());
	    //System.out.println("---> " + curr.toString());
            // It was the last row of the set, but ...
            if(((Short)curr).shortValue() == VirtuosoTypes.QC_STATUS ||
		((Short)curr).shortValue() == 100) /* NO_DATA_FOUND */
            {
	      //System.out.println("process_result10 :---> NO_DATA_FOUND =" + ((Short)curr).toString());
               is_complete = true;
	    }
         }
      }
   }

   /**
    * Method runs when the garbage collector want to erase the object
    */
   public void finalize() throws Throwable
   {
      close();
   }

   void fixReturnedData(openlink.util.Vector data)
   {
     if (data == null)
       return;

     for(int i=0; i < data.size(); i++)
     {
       Object val = data.elementAt(i);
       if (val instanceof DateObject)
         data.setElementAt(((DateObject)val).getValue(statement.sparql_executed), i);
     }
   }

   // --------------------------- JDBC 1.0 ------------------------------
   /**
    * Retrieves the first warning reported by calls on this ResultSet.
    * Subsequent ResultSet warnings will be chained to this
    * SQLWarning. Virtuoso doesn't generate warnings, so this function
    * will return always null.
    *
    * @return SQLWarning   The first SQLWarning or null (must be null for the moment)
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.ResultSet#getWarnings
    */
   public SQLWarning getWarnings() throws VirtuosoException
   {
      return null;
   }

   /**
    * Clears all the warnings reported on this ResultSet object.
    * Virtuoso doesn't generate warnings, so this function does nothing.
    *
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.ResultSet#clearWarnings
    */
   public void clearWarnings() throws VirtuosoException
   {
   }

   /**
    * Returns the type of this result set.
    *
    * <p>This is a JDBC 2.0 function. So to use it with the current Virtuoso DBMS,
    * you have to cast the <code>ResultSet</code> class to a <code>VirtuosoResultSet</code>
    * class like :
    * <pre>
    *   <code>int type = (VirtuosoResultSet)currentrs.getType();</code>
    * </pre>
    *
    * @return int The result set type.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.ResultSet#getType
    */
   public int getType() throws VirtuosoException
   {
      return type;
   }

   /**
    * Returns the concurrency mode of this result set.
    *
    * <p>This is a JDBC 2.0 function. So to use it with the current Virtuoso DBMS,
    * you have to cast the <code>ResultSet</code> class to a <code>VirtuosoResultSet</code>
    * class like :
    * <pre>
    *   <code>int concurrency = (VirtuosoResultSet)currentrs.getConcurrency();</code>
    * </pre>
    *
    * @return int The concurrency type.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.ResultSet#getConcurrency
    */
   public int getConcurrency() throws VirtuosoException
   {
      return concurrency;
   }

   /**
    * Sets the default fetch direction of this result set.
    *
    * <p>This is a JDBC 2.0 function. So to use it with the current Virtuoso DBMS,
    * you have to cast the <code>ResultSet</code> class to a <code>VirtuosoResultSet</code>
    * class like :
    * <pre>
    *   <code>(VirtuosoResultSet)currentrs.setFetchDirection(...);</code>
    * </pre>
    *
    * @param direction The initial direction for processing rows
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    * @see java.sql.ResultSet#setFetchDirection
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
    * Retrieves the fetch direction of this result set.
    *
    * <p>This is a JDBC 2.0 function. So to use it with the current Virtuoso DBMS,
    * you have to cast the <code>ResultSet</code> class to a <code>VirtuosoResultSet</code>
    * class like :
    * <pre>
    *   <code>int fetchdir = (VirtuosoResultSet)currentrs.getFetchDirection();</code>
    * </pre>
    *
    * @return int The default fetch direction for this result set.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.ResultSet#getFetchDirection
    */
   public int getFetchDirection() throws VirtuosoException
   {
      return fetchDirection;
   }

   /**
    * Gives the JDBC driver a hint as to the number of rows that should
    * be fetched from the database when more rows are needed.
    *
    * <p>This is a JDBC 2.0 function. So to use it with the current Virtuoso DBMS,
    * you have to cast the <code>ResultSet</code> class to a <code>VirtuosoResultSet</code>
    * class like :
    * <pre>
    *   <code>(VirtuosoResultSet)currentrs.setFetchSize(...);</code>
    * </pre>
    *
    * @param rows the number of rows to fetch
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    * @see java.sql.ResultSet#setFetchSize
    */
   public void setFetchSize(int rows) throws VirtuosoException
   {
      if(rows < 0 || rows > statement.getMaxRows())
         throw new VirtuosoException("Bad parameters.",VirtuosoException.BADPARAM);
      prefetch = (rows == 0 ? VirtuosoTypes.DEFAULTPREFETCH : rows);
   }

   /**
    * Retrieves the number of result set rows that is the default
    * fetch size for result sets generated from this ResultSet object.
    *
    * <p>This is a JDBC 2.0 function. So to use it with the current Virtuoso DBMS,
    * you have to cast the <code>ResultSet</code> class to a <code>VirtuosoResultSet</code>
    * class like :
    * <pre>
    *   <code>int fetchsize = (VirtuosoResultSet)currentrs.getFetchSize();</code>
    * </pre>
    *
    * @return int The default fetch size for result sets generated.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.ResultSet#getFetchSize
    */
   public int getFetchSize() throws VirtuosoException
   {
      return prefetch;
   }

   /**
    * Returns the VirtuosoStatement object that produced this
    * VirtuosoResultSet object.
    *
    * <p>This is a JDBC 2.0 function. So to use it with the current Virtuoso DBMS,
    * you have to cast the <code>ResultSet</code> class to a <code>VirtuosoResultSet</code>
    * class like :
    * <pre>
    *   <code>Statement statement = (VirtuosoResultSet)currentrs.getStatement();</code>
    * </pre>
    *
    * @return VirtuosoStatement The connection that produced this statement
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.ResultSet#getStatement
    */
   public Statement getStatement() throws VirtuosoException
   {
      return statement;
   }

   /**
    * Retrieves the number, types and properties of a ResultSet's columns.
    *
    * @return VirtuosoResultSetMetaData   The description of a ResultSet's columns.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.ResultSet#getMetaData
    */
   public ResultSetMetaData getMetaData() throws VirtuosoException
   {
      return metaData;
   }

   /**
    * Retrieves the kind of operation of this Result set.
    *
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    */
   protected int kindop() throws VirtuosoException
   {
      return kindop;
   }

   /**
    * Retrieves if it exist more result after this set.
    *
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    */
   protected boolean more_result() throws VirtuosoException
   {
      return more_result;
   }

   /**
    * Returns the column number corresponding to the name.
    *
    * @param name   The column's name.
    * @return int   The column's number corresponding to the name.
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSet#findColumn
    */
   public int findColumn(String name) throws VirtuosoException
   {
      // Check parameters
      if(name == null)
         throw new VirtuosoException("Bad parameters.",VirtuosoException.BADPARAM);
      // Search in the hash table of meta data
      Integer i = (Integer)(metaData.hcolumns.get(
	    new VirtuosoColumn(name, VirtuosoTypes.DV_STRING, statement.connection)));

      if (i == null)
         throw new VirtuosoException("findColumn() can't found column with name '"+name+"' in resultSet", "S0022", VirtuosoException.MISCERROR);
      
      // Return column's number
      return i.intValue() + 1;
   }

   /**
    * Reports whether the last column read had a value of SQL NULL.
    * Note that you must first call getXXX on a column to try to read
    * its value and then call wasNull() to see if the value read was
    * SQL NULL.
    *
    * @return boolean True if last column read was SQL NULL and false otherwise.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.ResultSet#wasNull
    */
   public boolean wasNull() throws VirtuosoException
   {
      return wasNull;
   }

   /**
    * Gets the value of a column in the current row as a Java String.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getString
    */
   public String getString(int columnIndex) throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getString(columnIndex);
   }

   /**
    * Gets the value of a column in the current row as a Java boolean.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return the column value; if the value is SQL NULL, the result is false
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getBoolean
    */
   public boolean getBoolean(int columnIndex) throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getBoolean(columnIndex);
   }

   /**
    * Gets the value of a column in the current row as a Java byte.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return the column value; if the value is SQL NULL, the result is 0
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getByte
    */
   public byte getByte(int columnIndex) throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getByte(columnIndex);
   }

   /**
    * Gets the value of a column in the current row as a Java short.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return the column value; if the value is SQL NULL, the result is 0
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getShort
    */
   public short getShort(int columnIndex) throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getShort(columnIndex);
   }

   /**
    * Gets the value of a column in the current row as a Java int.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return the column value; if the value is SQL NULL, the result is 0
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getInt
    */
   public int getInt(int columnIndex) throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getInt(columnIndex);
   }

   /**
    * Gets the value of a column in the current row as a Java long.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return the column value; if the value is SQL NULL, the result is 0
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getLong
    */
   public long getLong(int columnIndex) throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getLong(columnIndex);
   }

   /**
    * Gets the value of a column in the current row as a Java float.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return the column value; if the value is SQL NULL, the result is 0
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getFloat
    */
   public float getFloat(int columnIndex) throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getFloat(columnIndex);
   }

   /**
    * Gets the value of a column in the current row as a Java double.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return the column value; if the value is SQL NULL, the result is 0
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getDouble
    */
   public double getDouble(int columnIndex) throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getDouble(columnIndex);
   }

   /**
    * Gets the value of a column in the current row as a java.math.BigDecimal object.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param scale the number of digits to the right of the decimal
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getBigDecimal
    * @deprecated
    */
   public BigDecimal getBigDecimal(int columnIndex, int scale) throws VirtuosoException
   {
      // Run the method
      return getBigDecimal(columnIndex).setScale(scale,BigDecimal.ROUND_UNNECESSARY);
   }

   /**
    * Gets the value of a column in the current row as a Java byte array.
    * The bytes represent the raw values returned by the driver.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getBytes
    */
   public byte[] getBytes(int columnIndex) throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getBytes(columnIndex);
   }

   /**
    * Gets the value of a column in the current row as a java.math.BigDecimal
    * object with full precision.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return the column value (full precision); if the value is SQL NULL,
    * the result is null
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getBigDecimal
    */
   public BigDecimal getBigDecimal(int columnIndex) throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getBigDecimal(columnIndex);
   }

   /**
    * Gets the value of a column in the current row as a stream of
    * ASCII characters. The value can then be read in chunks from the
    * stream. This method is particularly
    * suitable for retrieving large LONGVARCHAR values.  The JDBC driver will
    * do any necessary conversion from the database format into ASCII.
    *
    * Note : the object returned by this method is in fact a VirtuosoAsciiInputStream
    * object, so you have to cast the InputStream received.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return a Java input stream that delivers the database column value
    * as a stream of one byte ASCII characters.  If the value is SQL NULL
    * then the result is null.
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getAsciiStream
    */
   public InputStream getAsciiStream(int columnIndex) throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getAsciiStream(columnIndex);
   }

   /**
    * Gets the value of a column in the current row as a stream of
    * Unicode characters. The value can then be read in chunks from the
    * stream. This method is particularly
    * suitable for retrieving large LONGVARCHAR values.  The JDBC driver will
    * do any necessary conversion from the database format into Unicode.
    * The byte format of the Unicode stream must Java UTF-8,
    * as specified in the Java Virtual Machine Specification.
    *
    * Note : the object returned by this method is in fact a VirtuosoAsciiInputStream
    * object, so you have to cast the InputStream received.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return a Java input stream that delivers the database column value
    * as a stream of two-byte Unicode characters.  If the value is SQL NULL
    * then the result is null.
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getUnicodeStream
    * @deprecated
    */
   public InputStream getUnicodeStream(int columnIndex) throws VirtuosoException
   {
      return getAsciiStream(columnIndex);
   }

   /**
    * Gets the value of a column in the current row as a stream of
    * uninterpreted bytes. The value can then be read in chunks from the
    * stream. This method is particularly
    * suitable for retrieving large LONGVARBINARY values.
    *
    * Note : the object returned by this method is in fact a ByteArrayInputStream
    * object, so you have to cast the InputStream received.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return a Java input stream that delivers the database column value
    * as a stream of uninterpreted bytes.  If the value is SQL NULL
    * then the result is null.
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getBinaryStream
    */
   public InputStream getBinaryStream(int columnIndex) throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getBinaryStream(columnIndex);
   }

   /**
    * Gets the value of a column in the current row as a java.io.Reader.
    *
    * Note : the object returned by this method is in fact a CharArrayReader
    * object, so you have to cast the Reader received.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return the Reader
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getCharacterStream
    */
   public Reader getCharacterStream(int columnIndex) throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getCharacterStream(columnIndex);
   }

   /**
    * Gets the value of a column in the current row as a Java String.
    *
    * @param columnName the SQL name of the column
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getString
    */
   public String getString(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getString(findColumn(columnName));
   }

   /**
    * Gets the value of a column in the current row as a Java boolean.
    *
    * @param columnName the SQL name of the column
    * @return the column value; if the value is SQL NULL, the result is false
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getBoolean
    */
   public boolean getBoolean(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getBoolean(findColumn(columnName));
   }

   /**
    * Gets the value of a column in the current row as a Java byte.
    *
    * @param columnName the SQL name of the column
    * @return the column value; if the value is SQL NULL, the result is 0
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getByte
    */
   public byte getByte(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getByte(findColumn(columnName));
   }

   /**
    * Gets the value of a column in the current row as a Java short.
    *
    * @param columnName the SQL name of the column
    * @return the column value; if the value is SQL NULL, the result is 0
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getShort
    */
   public short getShort(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getShort(findColumn(columnName));
   }

   /**
    * Gets the value of a column in the current row as a Java int.
    *
    * @param columnName the SQL name of the column
    * @return the column value; if the value is SQL NULL, the result is 0
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getInt
    */
   public int getInt(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getInt(findColumn(columnName));
   }

   /**
    * Gets the value of a column in the current row as a Java long.
    *
    * @param columnName the SQL name of the column
    * @return the column value; if the value is SQL NULL, the result is 0
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getLong
    */
   public long getLong(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getLong(findColumn(columnName));
   }

   /**
    * Gets the value of a column in the current row as a Java float.
    *
    * @param columnName the SQL name of the column
    * @return the column value; if the value is SQL NULL, the result is 0
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getFloat
    */
   public float getFloat(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getFloat(findColumn(columnName));
   }

   /**
    * Gets the value of a column in the current row as a Java double.
    *
    * @param columnName the SQL name of the column
    * @return the column value; if the value is SQL NULL, the result is 0
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getDouble
    */
   public double getDouble(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getDouble(findColumn(columnName));
   }

   /**
    * Gets the value of a column in the current row as a java.math.BigDecimal
    * object.
    *
    * @param columnName the SQL name of the column
    * @param scale the number of digits to the right of the decimal
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getBigDecimal
    * @deprecated
    */
   public BigDecimal getBigDecimal(String columnName, int scale) throws VirtuosoException
   {
      // First get the column number
      return getBigDecimal(findColumn(columnName));
   }

   /**
    * Gets the value of a column in the current row as a Java byte array.
    * The bytes represent the raw values returned by the driver.
    *
    * @param columnName the SQL name of the column
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getBytes
    */
   public byte[] getBytes(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getBytes(findColumn(columnName));
   }

   /**
    * Gets the value of a column in the current row as a java.io.Reader.
    *
    * Note : the object returned by this method is in fact a CharArrayReader
    * object, so you have to cast the Reader received.
    *
    * @param columnName the name of the column
    * @return the Reader
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getCharacterStream
    */
   public Reader getCharacterStream(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getCharacterStream(findColumn(columnName));
   }

   /**
    * Gets the value of a column in the current row as a java.math.BigDecimal
    * object.
    *
    * @param columnName the SQL name of the column
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getBigDecimal
    */
   public BigDecimal getBigDecimal(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getBigDecimal(findColumn(columnName));
   }

   /**
    * Gets the value of a column in the current row as a stream of
    * ASCII characters. The value can then be read in chunks from the
    * stream. This method is particularly
    * suitable for retrieving large LONGVARCHAR values.  The JDBC driver will
    * do any necessary conversion from the database format into ASCII.
    *
    * Note : the object returned by this method is in fact a VirtuosoAsciiInputStream
    * object, so you have to cast the InputStream received.
    *
    * @param columnName the SQL name of the column
    * @return a Java input stream that delivers the database column value
    * as a stream of one byte ASCII characters.  If the value is SQL NULL
    * then the result is null.
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getAsciiStream
    */
   public InputStream getAsciiStream(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getAsciiStream(findColumn(columnName));
   }

   /**
    * Gets the value of a column in the current row as a stream of
    * Unicode characters. The value can then be read in chunks from the
    * stream. This method is particularly
    * suitable for retrieving large LONGVARCHAR values.  The JDBC driver will
    * do any necessary conversion from the database format into Unicode.
    * The byte format of the Unicode stream must Java UTF-8,
    * as specified in the Java Virtual Machine Specification.
    *
    * Note : the object returned by this method is in fact a VirtuosoAsciiInputStream
    * object, so you have to cast the InputStream received.
    *
    * @param columnName the SQL name of the column
    * @return a Java input stream that delivers the database column value
    * as a stream of two-byte Unicode characters.  If the value is SQL NULL
    * then the result is null.
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getUnicodeStream
    * @deprecated
    */
   public InputStream getUnicodeStream(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getUnicodeStream(findColumn(columnName));
   }

   /**
    * Gets the value of a column in the current row as a stream of
    * uninterpreted bytes. The value can then be read in chunks from the
    * stream. This method is particularly
    * suitable for retrieving large LONGVARBINARY values.
    *
    * Note : the object returned by this method is in fact a ByteArrayInputStream
    * object, so you have to cast the InputStream received.
    *
    * @param columnName the SQL name of the column
    * @return a Java input stream that delivers the database column value
    * as a stream of uninterpreted bytes.  If the value is SQL NULL
    * then the result is null.
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getBinaryStream
    */
   public InputStream getBinaryStream(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getBinaryStream(findColumn(columnName));
   }

   /**
    * Gets the value of a column in the current row as a Java object.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return a java.lang.Object holding the column value
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getObject
    */
   public Object getObject(int columnIndex) throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getObject(columnIndex);
   }

   /**
    * Gets the value of a column in the current row as a Java object.
    *
    * @param columnName the SQL name of the column
    * @return a java.lang.Object holding the column value
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#getObject
    */
   public Object getObject(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getObject(findColumn(columnName));
   }

   /**
    * Gets the value of a column in the current row as a java.sql.Date object.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public java.sql.Date getDate(int columnIndex) throws VirtuosoException
   {
      return getDate(columnIndex, null);
   }

   /**
    * Gets the value of a column in the current row as a java.sql.Time object.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public java.sql.Time getTime(int columnIndex) throws VirtuosoException
   {
      return getTime(columnIndex, null);
   }

   /**
    * Gets the value of a column in the current row as a java.sql.Timestamp object.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public java.sql.Timestamp getTimestamp(int columnIndex) throws VirtuosoException
   {
      return getTimestamp(columnIndex, null);
   }

   /**
    * Gets the value of a column in the current row as a java.sql.Date
    * object. This method uses the given calendar to construct an appropriate millisecond
    * value for the Date if the underlying database does not store
    * timezone information.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param cal the calendar to use in constructing the date
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public java.sql.Date getDate(int columnIndex, Calendar cal) throws VirtuosoException
   {
      java.sql.Date date;
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      date = ((VirtuosoRow)rows.elementAt(currentRow - 1)).getDate(columnIndex);
      // Specify a calendar
      if(cal != null && date != null)
        date = new java.sql.Date(VirtuosoTypes.timeToCal(date, cal));

      return date;
   }

   /**
    * Gets the value of a column in the current row as a java.sql.Time
    * object. This method uses the given calendar to construct an appropriate millisecond
    * value for the Time if the underlying database does not store
    * timezone information.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param cal the calendar to use in constructing the time
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public java.sql.Time getTime(int columnIndex, Calendar cal) throws VirtuosoException
   {
      java.sql.Time _time;
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      _time = ((VirtuosoRow)rows.elementAt(currentRow - 1)).getTime(columnIndex);
      // Specify a calendar
      if(cal != null && _time != null)
        _time = new java.sql.Time(VirtuosoTypes.timeToCal(_time, cal));

      return _time;
   }

   /**
    * Gets the value of a column in the current row as a java.sql.Timestamp
    * object. This method uses the given calendar to construct an appropriate millisecond
    * value for the Timestamp if the underlying database does not store
    * timezone information.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param cal the calendar to use in constructing the timestamp
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public java.sql.Timestamp getTimestamp(int columnIndex, Calendar cal) throws VirtuosoException
   {
      java.sql.Timestamp _ts, val;
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      _ts = val = ((VirtuosoRow)rows.elementAt(currentRow - 1)).getTimestamp(columnIndex);
      // Specify a calendar
      if(cal != null && _ts != null)
        _ts = new java.sql.Timestamp(VirtuosoTypes.timeToCal(_ts, cal));

      if (_ts!=null)
      	_ts.setNanos(val.getNanos());

      return _ts;
   }

   /**
    * Gets the value of a column in the current row as a java.sql.Date object.
    *
    * @param columnName the SQL name of the column
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public java.sql.Date getDate(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getDate(findColumn(columnName), null);
   }

   /**
    * Gets the value of a column in the current row as a java.sql.Time object.
    *
    * @param columnName the SQL name of the column
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public java.sql.Time getTime(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getTime(findColumn(columnName), null);
   }

   /**
    * Gets the value of a column in the current row as a java.sql.Timestamp object.
    *
    * @param columnName the SQL name of the column
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public java.sql.Timestamp getTimestamp(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getTimestamp(findColumn(columnName), null);
   }

   /**
    * Updates a column with a null value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateNull(String columnName) throws VirtuosoException
   {
      // First get the column number
      updateNull(findColumn(columnName));
   }

   /**
    * Updates a column with a boolean value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateBoolean(String columnName, boolean x) throws VirtuosoException
   {
      // First get the column number
      updateBoolean(findColumn(columnName),x);
   }

   /**
    * Updates a column with a byte value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateByte(String columnName, byte x) throws VirtuosoException
   {
      // First get the column number
      updateByte(findColumn(columnName),x);
   }

   /**
    * Updates a column with a short value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateShort(String columnName, short x) throws VirtuosoException
   {
      // First get the column number
      updateShort(findColumn(columnName),x);
   }

   /**
    * Updates a column with an integer value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateInt(String columnName, int x) throws VirtuosoException
   {
      // First get the column number
      updateInt(findColumn(columnName),x);
   }

   /**
    * Updates a column with a long value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateLong(String columnName, long x) throws VirtuosoException
   {
      // First get the column number
      updateLong(findColumn(columnName),x);
   }

   /**
    * Updates a column with a float value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateFloat(String columnName, float x) throws VirtuosoException
   {
      // First get the column number
      updateFloat(findColumn(columnName),x);
   }

   /**
    * Updates a column with a double value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateDouble(String columnName, double x) throws VirtuosoException
   {
      // First get the column number
      updateDouble(findColumn(columnName),x);
   }

   /**
    * Updates a column with a BigDecimal value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateBigDecimal(String columnName, BigDecimal x) throws VirtuosoException
   {
      // First get the column number
      updateBigDecimal(findColumn(columnName),x);
   }

   /**
    * Updates a column with a String value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateString(String columnName, String x) throws VirtuosoException
   {
      // First get the column number
      updateString(findColumn(columnName),x);
   }

   /**
    * Updates a column with a byte array value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateBytes(String columnName, byte x[]) throws VirtuosoException
   {
      // First get the column number
      updateBytes(findColumn(columnName),x);
   }

   /**
    * Updates a column with a Date value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateDate(String columnName, java.sql.Date x) throws VirtuosoException
   {
      // First get the column number
      updateDate(findColumn(columnName),x);
   }

   /**
    * Updates a column with a Time value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateTime(String columnName, java.sql.Time x) throws VirtuosoException
   {
      // First get the column number
      updateTime(findColumn(columnName),x);
   }

   /**
    * Updates a column with a Timestamp value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateTimestamp(String columnName, java.sql.Timestamp x) throws VirtuosoException
   {
      // First get the column number
      updateTimestamp(findColumn(columnName),x);
   }

   /**
    * Updates a column with an ascii stream value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @param length of the stream
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateAsciiStream(String columnName, InputStream x, int length) throws VirtuosoException
   {
      // First get the column number
      updateAsciiStream(findColumn(columnName),x,length);
   }

   /**
    * Updates a column with a binary stream value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @param length of the stream
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateBinaryStream(String columnName, InputStream x, int length) throws VirtuosoException
   {
      // First get the column number
      updateBinaryStream(findColumn(columnName),x,length);
   }

   /**
    * Updates a column with a character stream value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @param length of the stream
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateCharacterStream(String columnName, Reader reader, int length) throws VirtuosoException
   {
      // First get the column number
      updateCharacterStream(findColumn(columnName),reader,length);
   }

   /**
    * Updates a column with an Object value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @param scale For java.sql.Types.DECIMAL or java.sql.Types.NUMERIC types
    * this is the number of digits after the decimal.  For all other
    * types this value will be ignored.
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateObject(String columnName, Object x, int scale) throws VirtuosoException
   {
      // First get the column number
      updateObject(findColumn(columnName),x,scale);
   }

   /**
    * Updates a column with an Object value.
    *
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnName the name of the column
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateObject(String columnName, Object x) throws VirtuosoException
   {
      // First get the column number
      updateObject(findColumn(columnName),x);
   }

#if JDK_VER >= 12
   /**
    * Returns the value in the specified column as a Java object.
    * This method uses the specified <code>Map</code> object for
    * custom mapping if appropriate.
    *
    * @param colName the name of the column from which to retrieve the value
    * @param map the mapping from SQL type names to Java classes
    * @return an object representing the SQL value in the specified column
    */
   public Object getObject(String columnName, Map map) throws VirtuosoException
   {
      // First get the column number
      return getObject(findColumn(columnName),map);
   }

   /**
    * Gets a REF(&lt;structured-type&gt;) column value from the current row.
    *
    * @param colName the column name
    * @return a <code>Ref</code> object representing the SQL REF value in
    * the specified column
    */
   public Ref getRef(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getRef(findColumn(columnName));
   }
#endif

   /**
    * Gets a BLOB value in the current row of this <code>ResultSet</code> object.
    *
    * @param colName the name of the column from which to retrieve the value
    * @return a <code>Blob</code> object representing the SQL BLOB value in
    * the specified column
    * @see virtuoso.jdbc2.VirtuosoBlob
    */
   public
#if JDK_VER >= 12
   Blob
#else
   VirtuosoBlob
#endif
   getBlob(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getBlob(findColumn(columnName));
   }

   /**
    * Gets a CLOB value in the current row of this <code>ResultSet</code> object.
    *
    * @param colName the name of the column from which to retrieve the value
    * @return a <code>Clob</code> object representing the SQL CLOB value in
    * the specified column
    * @see virtuoso.jdbc2.VirtuosoClob
    */
   public
#if JDK_VER >= 12
   Clob
#else
   VirtuosoClob
#endif
   getClob(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getClob(findColumn(columnName));
   }

#if JDK_VER >= 12
   /**
    * Gets an SQL ARRAY value in the current row of this <code>ResultSet</code> object.
    *
    * @param colName the name of the column from which to retrieve the value
    * @return an <code>Array</code> object representing the SQL ARRAY value in
    * the specified column
    */
   public Array getArray(String columnName) throws VirtuosoException
   {
      // First get the column number
      return getArray(findColumn(columnName));
   }
#endif

   /**
    * Gets the value of a column in the current row as a java.sql.Date
    * object. This method uses the given calendar to construct an appropriate millisecond
    * value for the Date, if the underlying database does not store
    * timezone information.
    *
    * @param columnName the SQL name of the column from which to retrieve the value
    * @param cal the calendar to use in constructing the date
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public java.sql.Date getDate(String columnName, Calendar cal) throws VirtuosoException
   {
      // First get the column number
      return getDate(findColumn(columnName),cal);
   }

   /**
    * Gets the value of a column in the current row as a java.sql.Time
    * object. This method uses the given calendar to construct an appropriate millisecond
    * value for the Time if the underlying database does not store
    * timezone information.
    *
    * @param columnName the SQL name of the column
    * @param cal the calendar to use in constructing the time
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public java.sql.Time getTime(String columnName, Calendar cal) throws VirtuosoException
   {
      // First get the column number
      return getTime(findColumn(columnName),cal);
   }

   /**
    * Gets the value of a column in the current row as a java.sql.Timestamp
    * object. This method uses the given calendar to construct an appropriate millisecond
    * value for the Timestamp if the underlying database does not store
    * timezone information.
    *
    * @param columnName the SQL name of the column
    * @param cal the calendar to use in constructing the timestamp
    * @return the column value; if the value is SQL NULL, the result is null
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public java.sql.Timestamp getTimestamp(String columnName, Calendar cal) throws VirtuosoException
   {
      // First get the column number
      return getTimestamp(findColumn(columnName),cal);
   }

   /**
    * Method used to change the wasNull flag;
    *
    * @param flag The new value of the flag.
    */
   protected void wasNull(boolean flag)
   {
      this.wasNull = flag;
   }

   /**
    * Releases this ResultSet object's database and
    * JDBC resources immediately instead of new wait for
    * this to happen when it is automatically closed.
    *
    * Note: A ResultSet is automatically closed by the
    * Statement that generated it when that Statement is closed,
    * re-executed, or is used to retrieve the next result from a
    * sequence of multiple results. A ResultSet is also automatically
    * closed when it is garbage collected.
    *
    * @exception virtuoso.jdbc2.VirtuosoException  An internal error occurred.
    * @see java.sql.ResultSet#close
    */
   public void close() throws VirtuosoException
   {
     //System.err.println ("close");
      if(pstmt != null)
      {
         pstmt.close();
         pstmt = null;
      }
      if(rows != null)
      {
         rows.removeAllElements();
         //rows = null;
      }
#if JDK_VER >= 17
      if (statement != null && isLastResult && statement.closeOnCompletion)
      {
         statement.close();
         statement = null;
      }
#endif
      if (statement != null && !is_prepared) 
      {
         statement.close_rs(false);
         statement = null;
      }

      row = null;
      cursorName = null;
   }

   /**
    * Moves the cursor down one row from its current position.
    * A ResultSet cursor is initially positioned before the first row; the
    * first call to next makes the first row the current row; the
    * second call makes the second row the current row, and so on.
    *
    * @return boolean   True if the new current row is valid; false if there
    * are no more rows.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just implementation).
    * @see java.sql.ResultSet#next
    */
   public boolean next() throws VirtuosoException
   {
       try
       {
	   // Try to go to the next row
	   int nextRow = currentRow + 1;
	   if (statement == null)
	       throw new VirtuosoException ("Activity on a closed statement 1", "IM001", VirtuosoException.SQLERROR);
	   if (statement.isClosed()/*future == null*/)
	       throw new VirtuosoException ("Activity on a closed statement 2", "IM001", VirtuosoException.SQLERROR);
	   if(type == VirtuosoResultSet.TYPE_FORWARD_ONLY)
	   {
	       if (rowNum >= maxRows && maxRows > 0)
	           return false;

	       while (true)
	       {
		   synchronized (statement.connection)
		   {
		       if (is_complete)
		       {
			   //System.err.println ("fetch :complete - return false");
			   return false;
		       }
		       Object elt = rows.firstElement();
		       //System.err.println ("stmt_co_last_in_batch=" + stmt_co_last_in_batch + " currentRow=" + currentRow);
/**		       if (!stmt_co_last_in_batch && currentRow == 0 && elt != null) **/
		       if (currentRow == 0 && elt != null)
		       { /* we have a prefetched row */
			   //System.err.println ("fetch :Prefetched row used " + rows.elementAt (0).toString());
			   stmt_current_of++;
			   currentRow ++;
			   rowNum++;
			   return true;
		       }
		       if ((stmt_co_last_in_batch || stmt_current_of == stmt_n_rows_to_get - 1)
			       && metaData != null && kindop == 1)
		       { /* we should order another batch */
			   //System.out.println ("fetch :" + stmt_n_rows_to_get + " retrieved.Ordering another batch");
			   rows.removeElementAt (1);
			   fetch_rpc();
			   stmt_current_of = -1;
			   stmt_co_last_in_batch = false;
		       }
		       process_result (false);
		       //System.err.print ("fetch: after process : rows :");
		       //System.err.println (rows.toString());
		   }
		   currentRow = 0;
	       }
	   }

	   if(nextRow > 0 && nextRow <= rows.size())
	   {
	       currentRow = nextRow;
	       return true;
	   }
	   else
	       if(type == VirtuosoResultSet.TYPE_FORWARD_ONLY)
	       {
		   currentRow = rows.size() + 1;
		   return false;
	       }
	   if(type == VirtuosoResultSet.TYPE_SCROLL_INSENSITIVE && getRow() == totalRows)
	   {
	       currentRow = rows.size() + 1;
	       return false;
	   }
	   // Call the extended fetch RPC
	   extended_fetch(VirtuosoTypes.SQL_FETCH_NEXT,0,(prefetch == 0) ? VirtuosoTypes.DEFAULTPREFETCH : prefetch);
	   // Here, it's a statid or dynamic cursor, and there are no more results in the row set
	   if(rows.size() == 0)
	   {
	       currentRow = 1;
	       return false;
	   }
	   // Update the current row
	   currentRow = 1;
	   return true;
       }
       catch (Throwable e)
       {
	   statement.notify_error (e);
	   return false;
       }
   }

   /**
    * Retrieves the current row number.  The first row is number 1, the
    * second number 2, and so on.
    *
    * @return int The current row number; 0 if there is no current row.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just implementation).
    * @see java.sql.ResultSet#getRow
    */
   public int getRow() throws VirtuosoException
   {
      if(currentRow > 0 && currentRow <= rows.size())
      {
         int r;

         if (type == VirtuosoResultSet.TYPE_SCROLL_INSENSITIVE)
           r = ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getRow();
         else if (type == VirtuosoResultSet.TYPE_SCROLL_SENSITIVE)
           r = ((Number)((openlink.util.Vector)(((VirtuosoRow)(rows.elementAt(currentRow - 1))).getBookmark()).elementAt(1)).elementAt(0)).intValue();
         else if (type == VirtuosoResultSet.TYPE_FORWARD_ONLY)
           r = rowNum;
         else
           r = 0;

         if(r == 0)
            return currentRow;
         return r;
      }
      return currentRow;
   }

   /**
    * Moves the cursor to the previous row in the result set.
    *
    * Note: previous() is not the same as relative(-1) because it
    * makes sense to call previous() when there is no current row.
    *
    * @return true if the cursor is on a valid row; false if it is off the result set
    * @exception virtuoso.jdbc2.VirtuosoException If the result set type is TYPE_FORWARD_ONLY.
    * @see java.sql.ResultSet#previous
    */
   public boolean previous() throws VirtuosoException
   {
      // The JDBC spec
      if(type == VirtuosoResultSet.TYPE_FORWARD_ONLY)
         throw new VirtuosoException("Can't access to the previous row, the type is forward only.",VirtuosoException.ERRORONTYPE);
      if (currentRow == 0)
	return false;
      // Try to go to the previous row
      int previousRow = currentRow - 1;
      if(previousRow > 0 && previousRow <= rows.size())
      {
         currentRow = previousRow;
         return true;
      }
      if(type == VirtuosoResultSet.TYPE_SCROLL_INSENSITIVE && getRow() == 1)
      {
         currentRow = 0;
         return false;
      }
      if(type == VirtuosoResultSet.TYPE_SCROLL_INSENSITIVE)
      {
         // Get the row bookmark of the line
         int book = getRow();
         // Call the extended fetch RPC
         extended_fetch(VirtuosoTypes.SQL_FETCH_PRIOR,0,(prefetch == 0) ? VirtuosoTypes.DEFAULTPREFETCH : prefetch);
         // Here, it's a statid or dynamic cursor, and there are no more results in the row set
         if(rows.size() == 0)
         {
            currentRow = 0;
            return false;
         }
         // Where are you in the row set
         for(int i = (rows.size() - 1);i >= 0;i--)
         {
            if(rows.elementAt(i) != null && ((VirtuosoRow)rows.elementAt(i)).getRow() == book)
            {
               currentRow = i;
               return true;
            }
         }
      }
      if(type == VirtuosoResultSet.TYPE_SCROLL_SENSITIVE)
      {
	//try {
	 //System.err.println ("refetching: currentRow=" + currentRow);
         // Get the row bookmark of the line
	 VirtuosoRow row = (VirtuosoRow)(rows.elementAt(currentRow - 1));
	 openlink.util.Vector book = null;
	 if (row != null)
	   book = row.getBookmark();
         // Call the extended fetch RPC
         extended_fetch(VirtuosoTypes.SQL_FETCH_PRIOR,0,(prefetch == 0) ? VirtuosoTypes.DEFAULTPREFETCH : prefetch);
         // Here, it's a statid or dynamic cursor, and there are no more results in the row set
         if(rows.size() == 0)
         {
            currentRow = 0;
            return false;
         }
	 //System.err.println ("refetcing : row_size = " + rows.size());
         // Where are you in the row set
	 if (book != null)
	   {
	     for(int i = (rows.size() - 1);i >= 0;i--)
	       {
		 if(rows.elementAt(i) != null && ((VirtuosoRow)rows.elementAt(i)).getBookmark().equals(book))
		   {
		     //System.err.println ("refetcing : row found i=" + (i));
		     currentRow = i;
		     return true;
		   }
	       }
	   }
	//}
	//catch (Exception e)
	//  {
	//    e.printStackTrace (System.err);
	//  }
      }
      currentRow = rows.size();
      //System.err.println ("refetching: after refetch: currentRow=" + currentRow);
      return true;
   }

   /**
    * Moves the cursor to the front of the result set, just before the
    * first row. Has no effect if the result set contains no rows.
    *
    * @exception virtuoso.jdbc2.VirtuosoException If the result set type is TYPE_FORWARD_ONLY.
    * @see java.sql.ResultSet#beforeFirst
    */
   public void beforeFirst() throws VirtuosoException
   {
      absolute(1);
      previous();
   }

   /**
    * Moves the cursor to the end of the result set, just after the last
    * row.  Has no effect if the result set contains no rows.
    *
    * @exception virtuoso.jdbc2.VirtuosoException If the result set type is TYPE_FORWARD_ONLY.
    * @see java.sql.ResultSet#afterLast
    */
   public void afterLast() throws VirtuosoException
   {
      absolute(-1);
      next();
   }

   /**
    * Moves the cursor to the first row in the result set.
    *
    * @return true if the cursor is on a valid row; false if
    * there are no rows in the result set
    * @exception virtuoso.jdbc2.VirtuosoException If the result set type is TYPE_FORWARD_ONLY.
    * @see java.sql.ResultSet#first
    */
   public boolean first() throws VirtuosoException
   {
      return absolute(1);
   }

   /**
    * Indicates whether the cursor is before the first row in the result
    * set.
    *
    * @return true if the cursor is before the first row, false otherwise. Returns
    * false when the result set contains no rows.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just implementation).
    * @see java.sql.ResultSet#isBeforeFirst
    */
   public boolean isBeforeFirst() throws VirtuosoException
   {
      return getRow() == 0;
   }

   /**
    * Indicates whether the cursor is after the last row in the result
    * set.
    *
    * @return true if the cursor is  after the last row, false otherwise.  Returns
    * false when the result set contains no rows.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just implementation).
    * @see java.sql.ResultSet#isAfterLast
    */
   public boolean isAfterLast() throws VirtuosoException
   {
      return getRow() == (rows.size() + 1);
   }

   /**
    * Indicates whether the cursor is on the first row of the result set.
    *
    * @return true if the cursor is on the first row, false otherwise.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just implementation).
    * @see java.sql.ResultSet#isFirst
    */
   public boolean isFirst() throws VirtuosoException
   {
      return getRow() == 1;
   }

   /**
    * Indicates whether the cursor is on the last row of the result set.
    *
    * @return true if the cursor is on the last row, false otherwise.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just implementation).
    * @see java.sql.ResultSet#isLast
    */
   public boolean isLast() throws VirtuosoException
   {
      return getRow() == totalRows;
   }

   /**
    * Moves the cursor to the last row in the result set.
    *
    * @return true if the cursor is on a valid row;
    * false if there are no rows in the result set
    * @exception virtuoso.jdbc2.VirtuosoException If the result set type is TYPE_FORWARD_ONLY.
    * @see java.sql.ResultSet#last
    */
   public boolean last() throws VirtuosoException
   {
      return absolute(-1);
   }

   /**
    * Moves the cursor to the given row number in the result set.
    *
    * @return true if the cursor is on the result set; false otherwise
    * @exception virtuoso.jdbc2.VirtuosoException If the result set type is TYPE_FORWARD_ONLY.
    * @see java.sql.ResultSet#absolute
    */
   public boolean absolute(int row) throws VirtuosoException
   {
      // The JDBC spec
      if(type == VirtuosoResultSet.TYPE_FORWARD_ONLY)
         throw new VirtuosoException("Can't go before the first row, the type is forward only.",VirtuosoException.ERRORONTYPE);
      // Call the extended fetch RPC
      extended_fetch(VirtuosoTypes.SQL_FETCH_ABSOLUTE,row,(prefetch == 0) ? VirtuosoTypes.DEFAULTPREFETCH : prefetch);
      // Here, it's a statid or dynamic cursor, and there are no more results in the row set
      if(rows.size() == 0)
      {
         currentRow = (row > 0) ? 0 : 1;
         return false;
      }
      // Update the current row
      currentRow = 1;
      return true;
   }

   /**
    * Moves the cursor a relative number of rows, either positive or negative.
    *
    * @return true if the cursor is on a row; false otherwise
    * @exception virtuoso.jdbc2.VirtuosoException If the result set type is TYPE_FORWARD_ONLY.
    * @see java.sql.ResultSet#relative
    */
   public boolean relative(int row) throws VirtuosoException
   {
      // The JDBC spec
      if(type == VirtuosoResultSet.TYPE_FORWARD_ONLY)
         throw new VirtuosoException("Can't go before the first row, the type is forward only.",VirtuosoException.ERRORONTYPE);
      // Call the extended fetch RPC
      extended_fetch(VirtuosoTypes.SQL_FETCH_RELATIVE,row,(prefetch == 0) ? VirtuosoTypes.DEFAULTPREFETCH : prefetch);
      // Here, it's a statid or dynamic cursor, and there are no more results in the row set
      if(rows.size() == 0)
      {
         currentRow = (row > 0) ? 0 : 1;
         return false;
      }
      // Update the current row
      currentRow = 1;
      return true;
   }

   /**
    * Gets the name of the SQL cursor used by this ResultSet.
    *
    * @return the ResultSet's SQL cursor name
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public String getCursorName() throws VirtuosoException
   {
      return cursorName;
   }

   /**
    * Gets a BLOB value in the current row of this <code>ResultSet</code> object.
    *
    * @param i the first column is 1, the second is 2, ...
    * @return a <code>Blob</code> object representing the SQL BLOB value in
    * the specified column
    */
   public
#if JDK_VER >= 12
   Blob
#else
   VirtuosoBlob
#endif
   getBlob(int i) throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getBlob(i);
   }

   /**
    * Gets a CLOB value in the current row of this <code>ResultSet</code> object.
    *
    * @param i the first column is 1, the second is 2, ...
    * @return a <code>Clob</code> object representing the SQL CLOB value in
    * the specified column
    */
   public
#if JDK_VER >= 12
   Clob
#else
   VirtuosoClob
#endif
   getClob(int i) throws VirtuosoException
   {
      // Get and check the current row number
      //System.err.println ("getClob (" + i + "), currentRow=" + currentRow + " rows=" + rows.toString());
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getClob(i);
   }

   /**
    * Indicates whether the current row has been updated.  The value returned
    * depends on whether or not the result set can detect updates.
    *
    * @return true if the row has been visibly updated by the owner or
    * another, and updates are detected
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see DatabaseMetaData#updatesAreDetected
    */
   public boolean rowUpdated() throws VirtuosoException
   {
      return rowIsUpdated;
   }

   /**
    * Indicates whether the current row has had an insertion.  The value returned
    * depends on whether or not the result set can detect visible inserts.
    *
    * @return true if a row has had an insertion and insertions are detected
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see DatabaseMetaData#insertsAreDetected
    */
   public boolean rowInserted() throws VirtuosoException
   {
      return rowIsInserted;
   }

   /**
    * Indicates whether a row has been deleted.  A deleted row may leave
    * a visible "hole" in a result set.  This method can be used to
    * detect holes in a result set.  The value returned depends on whether
    * or not the result set can detect deletions.
    *
    * @return true if a row was deleted and deletions are detected
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * @see DatabaseMetaData#deletesAreDetected
    */
   public boolean rowDeleted() throws VirtuosoException
   {
      return rowIsDeleted;
   }

   /**
    * Give a nullable column a null value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateNull(int columnIndex) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      row[columnIndex - 1] = null;
   }

   /**
    * Updates a column with a boolean value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateBoolean(int columnIndex, boolean x) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      row[columnIndex - 1] = new Boolean(x);
   }

   /**
    * Updates a column with a byte value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateByte(int columnIndex, byte x) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      row[columnIndex - 1] = new Byte(x);
   }

   /**
    * Updates a column with a short value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateShort(int columnIndex, short x) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      row[columnIndex - 1] = new Short(x);
   }

   /**
    * Updates a column with an integer value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateInt(int columnIndex, int x) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      row[columnIndex - 1] = new Integer(x);
   }

   /**
    * Updates a column with a long value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateLong(int columnIndex, long x) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      row[columnIndex - 1] = new Long(x);
   }

   /**
    * Updates a column with a float value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateFloat(int columnIndex, float x) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      row[columnIndex - 1] = new Float(x);
   }

   /**
    * Updates a column with a Double value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateDouble(int columnIndex, double x) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      row[columnIndex - 1] = new Double(x);
   }

   /**
    * Updates a column with a BigDecimal value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateBigDecimal(int columnIndex, BigDecimal x) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      row[columnIndex - 1] = x;
   }

   /**
    * Updates a column with a String value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateString(int columnIndex, String x) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      row[columnIndex - 1] = x;
   }

   /**
    * Updates a column with a byte array value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateBytes(int columnIndex, byte x[]) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      try
	{
	  row[columnIndex - 1] = new String(x, "8859_1");
	}
      catch (java.io.UnsupportedEncodingException e)
	{
	  if (x == null)
	    row[columnIndex - 1] = new String (x);
	  char [] chars = new char[x.length];
	  for (int i = 0; i < x.length; i++)
	    chars[i] = (char) x[i];
	  row[columnIndex - 1] = new String (chars);
	}
   }

   /**
    * Updates a column with a Date value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateDate(int columnIndex, java.sql.Date x) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      row[columnIndex - 1] = x;
   }

   /**
    * Updates a column with a Time value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateTime(int columnIndex, java.sql.Time x) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      row[columnIndex - 1] = x;
   }

   /**
    * Updates a column with a Timestamp value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateTimestamp(int columnIndex, java.sql.Timestamp x) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      row[columnIndex - 1] = x;
   }

   /**
    * Updates a column with an ascii stream value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @param length the length of the stream
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateAsciiStream(int columnIndex, InputStream x, int length) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      if(x == null || length < 0)
         throw new VirtuosoException("Bad parameters.",VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      // After check, check if a Blob object is already associated or not
      Object _obj = row[columnIndex - 1];
      // Check now if it's a Blob
      if(_obj instanceof VirtuosoBlob)
      {
         ((VirtuosoBlob)_obj).setInputStream(x,length);
         return;
      }
      // Else create a Clob
      row[columnIndex - 1] = new VirtuosoBlob(x,length,columnIndex - 1);
      pstmt.objparams.setElementAt(row[columnIndex - 1],columnIndex - 1);
   }

   /**
    * Updates a column with a binary stream value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @param length the length of the stream
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateBinaryStream(int columnIndex, InputStream x, int length) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      if(x == null || length < 0)
         throw new VirtuosoException("Bad parameters.",VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      // After check, check if a Blob object is already associated or not
      Object _obj = row[columnIndex - 1];
      // Check now if it's a Blob
      if(_obj instanceof VirtuosoBlob)
      {
         ((VirtuosoBlob)_obj).setInputStream(x,length);
         return;
      }
      // Else create a Clob
      row[columnIndex - 1] = new VirtuosoBlob(x,length,columnIndex - 1);
      pstmt.objparams.setElementAt(row[columnIndex - 1],columnIndex - 1);
   }

   /**
    * Updates a column with a character stream value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @param length the length of the stream
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateCharacterStream(int columnIndex, Reader x, int length) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      if(x == null || length < 0)
         throw new VirtuosoException("Bad parameters.",VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      // After check, check if a Blob object is already associated or not
      Object _obj = row[columnIndex - 1];
      // Check now if it's a Blob
      if(_obj instanceof VirtuosoBlob)
      {
         ((VirtuosoBlob)_obj).setReader(x,length);
         return;
      }
      // Else create a Clob
      row[columnIndex - 1] = new VirtuosoBlob(x,length,columnIndex - 1);
      pstmt.objparams.setElementAt(row[columnIndex - 1],columnIndex - 1);
   }

   /**
    * Updates a column with an Object value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateObject(int columnIndex, Object x) throws VirtuosoException
   {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      if(x == null)
         throw new VirtuosoException("Bad parameters.",VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      // After check, check if a Blob object is already associated or not
      Object _obj = row[columnIndex - 1];
      // Check now if it's a Blob
      if(_obj instanceof VirtuosoBlob)
      {
         ((VirtuosoBlob)_obj).setObject(x);
         return;
      }
      // Else create a Clob
      row[columnIndex - 1] = new VirtuosoBlob(x,columnIndex - 1);
   }

   /**
    * Updates a column with an Object value.
    * The <code>updateXXX</code> methods are used to update column values in the
    * current row, or the insert row.  The <code>updateXXX</code> methods do not
    * update the underlying database; instead the <code>updateRow</code> or <code>insertRow</code>
    * methods are called to update the database.
    *
    * @param columnIndex the first column is 1, the second is 2, ...
    * @param x the new column value
    * @param scale For java.sql.Types.DECIMAL or java.sql.Types.NUMERIC types
    * this is the number of digits after the decimal.  For all other
    * types this value will be ignored.
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public void updateObject(int columnIndex, Object x, int scale) throws VirtuosoException
   {
      updateObject(columnIndex,x);
   }

   /**
    * Cancels the updates made to a row.
    * This method may be called after calling an
    * <code>updateXXX</code> method(s) and before calling <code>updateRow</code> to rollback
    * the updates made to a row.  If no updates have been made or
    * <code>updateRow</code> has already been called, then this method has no
    * effect.
    *
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs or if
    * called when on the insert row
    */
   public void cancelRowUpdates() throws VirtuosoException
   {
      // Check if there's a row to update
      if(row != null)
         row = null;
   }

   /**
    * Inserts the contents of the insert row into the result set and
    * the database.  Must be on the insert row when this method is called.
    *
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs,
    * if called when not on the insert row, or if not all of non-nullable columns in
    * the insert row have been given a value
    */
   public void insertRow() throws VirtuosoException
   {
      Object[] obj = new Object[1];
      obj[0] = new openlink.util.Vector(row);
      set_pos(VirtuosoTypes.SQL_ADD,new openlink.util.Vector(obj),0);
      row = null;
   }

   /**
    * Updates the underlying database with the new contents of the
    * current row.  Cannot be called when on the insert row.
    *
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs or
    * if called when on the insert row
    */
   public void updateRow() throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 0 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      if(currentRow != 0)
      {
         set_pos(VirtuosoTypes.SQL_UPDATE,new openlink.util.Vector(row),currentRow);
         row = null;
      }
      else
         if(oldRow != 0)
            insertRow();
   }

   /**
    * Deletes the current row from the result set and the underlying
    * database.  Cannot be called when on the insert row.
    *
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs or if
    * called when on the insert row.
    */
   public void deleteRow() throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      set_pos(VirtuosoTypes.SQL_DELETE,null,currentRow);
   }

   /**
    * Refreshes the current row with its most recent value in
    * the database.  Cannot be called when on the insert row.
    *
    * The <code>refreshRow</code> method provides a way for an application to
    * explicitly tell the JDBC driver to refetch a row(s) from the
    * database.  An application may want to call <code>refreshRow</code> when
    * caching or prefetching is being done by the JDBC driver to
    * fetch the latest value of a row from the database.  The JDBC driver
    * may actually refresh multiple rows at once if the fetch size is
    * greater than one.
    *
    * All values are refetched subject to the transaction isolation
    * level and cursor sensitivity.  If <code>refreshRow</code> is called after
    * calling <code>updateXXX</code>, but before calling <code>updateRow</code>, then the
    * updates made to the row are lost.  Calling the method <code>refreshRow</code> frequently
    * will likely slow performance.
    *
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs or if
    * called when on the insert row
    */
   public void refreshRow() throws VirtuosoException
   {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      set_pos(VirtuosoTypes.SQL_REFRESH,null,currentRow);
   }

   /**
    * Moves the cursor to the insert row.  The current cursor position is
    * remembered while the cursor is positioned on the insert row.
    *
    * The insert row is a special row associated with an updatable
    * result set.  It is essentially a buffer where a new row may
    * be constructed by calling the <code>updateXXX</code> methods prior to
    * inserting the row into the result set.
    *
    * Only the <code>updateXXX</code>, <code>getXXX</code>,
    * and <code>insertRow</code> methods may be
    * called when the cursor is on the insert row.  All of the columns in
    * a result set must be given a value each time this method is
    * called before calling <code>insertRow</code>.
    * The method <code>updateXXX</code> must be called before a
    * <code>getXXX</code> method can be called on a column value.
    *
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * or the result set is not updatable
    */
   public void moveToInsertRow() throws VirtuosoException
   {
      if(oldRow == 0)
      {
         oldRow = getRow();
         currentRow = 0;
      }
   }

   /**
    * Moves the cursor to the remembered cursor position, usually the
    * current row.  This method has no effect if the cursor is not on the insert
    * row.
    *
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    * or the result set is not updatable
    */
   public void moveToCurrentRow() throws VirtuosoException
   {
      if(oldRow != 0)
      {
         absolute(oldRow);
         oldRow = 0;
      }
   }

   // ==================================================================
#if JDK_VER >= 12
   /**
    * Returns the value of a column in the current row as a Java object.
    * This method uses the given <code>Map</code> object
    * for the custom mapping of the
    * SQL structured or distinct type that is being retrieved.
    *
    * @param i the first column is 1, the second is 2, ...
    * @param map the mapping from SQL type names to Java classes
    * @return an object representing the SQL value
    */
   public Object getObject(int i, Map map) throws VirtuosoException
   {
      return null;
   }

   /**
    * Gets a REF(&lt;structured-type&gt;) column value from the current row.
    *
    * @param i the first column is 1, the second is 2, ...
    * @return a <code>Ref</code> object representing an SQL REF value
    */
   public Ref getRef(int i) throws VirtuosoException
   {
      return null;
   }
   /**
    * Gets an SQL ARRAY value from the current row of this <code>ResultSet</code> object.
    *
    * @param i the first column is 1, the second is 2, ...
    * @return an <code>Array</code> object representing the SQL ARRAY value in
    * the specified column
    */
   public Array getArray(int i) throws VirtuosoException
   {
      return null;
   }
#endif

   protected void sendBlobData (openlink.util.Vector result) throws VirtuosoException
     {
       try
	 {
	   //System.out.println("---> QA_NEED_DATA" + result.toString());
	   int index = ((Number)result.elementAt(1)).intValue();
	   // Now we have to send the blob content as a DV_STRING
	   VirtuosoBlob blob = (VirtuosoBlob)statement.objparams.elementAt(index);
	   Reader rd = blob.getCharacterStream ();
	   long pos = 0;
	   int dtp = VirtuosoTypes.DV_STRING;
	   if (statement.parameters != null &&
	       statement.parameters.elementAt(index) instanceof openlink.util.Vector)
	     {
	       openlink.util.Vector pd = (openlink.util.Vector)statement.parameters.elementAt(index);
	       dtp = ((Number)pd.elementAt (0)).intValue();
	       if (dtp == VirtuosoTypes.DV_BLOB_BIN)
		 dtp = VirtuosoTypes.DV_BIN;
	       else if (dtp == VirtuosoTypes.DV_BLOB_WIDE)
		 dtp = VirtuosoTypes.DV_WIDE;
	       else
		 dtp = VirtuosoTypes.DV_STRING;
	     }
	   //System.err.println ("Dtp=" + dtp);

	   char[] _obj = new char[VirtuosoTypes.PAGELEN];
	   int off;
	   do
	     {
	       off = 0;
	       while (off < VirtuosoTypes.PAGELEN && off < blob.length () - pos)
		 {
		   int read = rd.read(_obj, off,
		       (int) ((blob.length () - pos < VirtuosoTypes.PAGELEN - off) ?
		       (blob.length () - pos) : (VirtuosoTypes.PAGELEN - off)));
		   //System.err.println ("Read=" + read + " off=" + off);
		   if (read == -1)
		     {
		       break;
		     }
		   off += read;
		   pos += read;
		 }
	       if (off > 0)
		 {
		   //System.err.println ("Send off=" + off);
		   Object toSend;
		   if (dtp == VirtuosoTypes.DV_BIN)
		     toSend = new String (_obj, 0, off);
		   else
		     {
		       toSend =
			   new VirtuosoExplicitString(new String (_obj, 0, off), dtp,
			     statement.connection);
		     }
		   statement.connection.write_object (toSend);
		 }
	     }
	   while (off > 0);

	   //System.err.println ("Send END");
	   byte[] end = new byte[1];
	   end[0] = 0;
	   statement.connection.write_bytes(end);
	 }
       catch(IOException e)
	 {
	   throw new VirtuosoException(er1,VirtuosoException.IOERROR);
	 }
     }

   /**
    * Compares two Objects for equality.
    *
    * @return boolean	True if two objects are equal, else false.
    */
   public boolean equals(Object obj)
   {
      // First check if the object is not null or the same object type
      if(obj != null && (obj instanceof VirtuosoResultSet))
      {
        // Strange compasrison due to jdbccts tests :stmt/stmt1/stmtClient1.java:testGetResultSet01()
        return true;
      }
      return false;
   }


#if JDK_VER >= 14
    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a <code>java.net.URL</code>
     * object in the Java programming language.
     *
     * @param columnIndex the index of the column 1 is the first, 2 is the second,...
     * @return the column value as a <code>java.net.URL</code> object;
     * if the value is SQL <code>NULL</code>,
     * the value returned is <code>null</code> in the Java programming language
     * @exception SQLException if a database access error occurs,
     *            or if a URL is malformed
     * @since 1.4
     */
   public java.net.URL getURL(int columnIndex) throws SQLException
     {
       throw new VirtuosoException ("DATALINK not supported", VirtuosoException.NOTIMPLEMENTED);
     }

    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a <code>java.net.URL</code>
     * object in the Java programming language.
     *
     * @param columnName the SQL name of the column
     * @return the column value as a <code>java.net.URL</code> object;
     * if the value is SQL <code>NULL</code>,
     * the value returned is <code>null</code> in the Java programming language
     * @exception SQLException if a database access error occurs
     *            or if a URL is malformed
     * @since 1.4
     */
   public java.net.URL getURL(String columnName) throws SQLException
     {
       throw new VirtuosoException ("DATALINK not supported", VirtuosoException.NOTIMPLEMENTED);
     }

    /**
     * Updates the designated column with a <code>java.sql.Ref</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public void updateRef(int columnIndex, Ref x) throws SQLException
     {
       throw new VirtuosoException ("SQL REF not supported", VirtuosoException.NOTIMPLEMENTED);
     }

    /**
     * Updates the designated column with a <code>java.sql.Ref</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnName the name of the column
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public void updateRef(String columnName, Ref x) throws SQLException
     {
       throw new VirtuosoException ("SQL REF not supported", VirtuosoException.NOTIMPLEMENTED);
     }

    /**
     * Updates the designated column with a <code>java.sql.Blob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public void updateBlob(int columnIndex, Blob x) throws SQLException
     {
       updateBinaryStream (columnIndex, x.getBinaryStream(), (int) x.length());
     }

    /**
     * Updates the designated column with a <code>java.sql.Blob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnName the name of the column
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public void updateBlob(String columnName, Blob x) throws SQLException
     {
       updateBinaryStream (columnName, x.getBinaryStream(), (int) x.length());
     }

    /**
     * Updates the designated column with a <code>java.sql.Clob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public void updateClob(int columnIndex, Clob x) throws SQLException
     {
       updateCharacterStream (columnIndex, x.getCharacterStream(), (int) x.length());
     }

    /**
     * Updates the designated column with a <code>java.sql.Clob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnName the name of the column
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public void updateClob(String columnName, Clob x) throws SQLException
     {
       updateCharacterStream (columnName, x.getCharacterStream(), (int) x.length());
     }

    /**
     * Updates the designated column with a <code>java.sql.Array</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public void updateArray(int columnIndex, Array x) throws SQLException
     {
       throw new VirtuosoException ("Arrays not supported", VirtuosoException.NOTIMPLEMENTED);
     }

    /**
     * Updates the designated column with a <code>java.sql.Array</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnName the name of the column
     * @param x the new column value
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public void updateArray(String columnName, Array x) throws SQLException
     {
       throw new VirtuosoException ("Arrays not supported", VirtuosoException.NOTIMPLEMENTED);
     }


#if JDK_VER >= 16
    //------------------------- JDBC 4.0 -----------------------------------

    /**
     * Retrieves the value of the designated column in the current row of this
     * <code>ResultSet</code> object as a <code>java.sql.RowId</code> object in the Java
     * programming language.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @return the column value; if the value is a SQL <code>NULL</code> the
     *     value returned is <code>null</code>
     * @throws SQLException if the columnIndex is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public RowId getRowId(int columnIndex) throws SQLException
  {
    throw new VirtuosoFNSException ("getRowId(columnIndex)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Retrieves the value of the designated column in the current row of this
     * <code>ResultSet</code> object as a <code>java.sql.RowId</code> object in the Java
     * programming language.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @return the column value ; if the value is a SQL <code>NULL</code> the
     *     value returned is <code>null</code>
     * @throws SQLException if the columnLabel is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public RowId getRowId(String columnLabel) throws SQLException
  {
    throw new VirtuosoFNSException ("getRowId(columnLabel)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Updates the designated column with a <code>RowId</code> value. The updater
     * methods are used to update column values in the current row or the insert
     * row. The updater methods do not update the underlying database; instead
     * the <code>updateRow</code> or <code>insertRow</code> methods are called
     * to update the database.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param x the column value
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateRowId(int columnIndex, RowId x) throws SQLException
  {
    throw new VirtuosoFNSException ("updateRowId(columnIndex, x)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Updates the designated column with a <code>RowId</code> value. The updater
     * methods are used to update column values in the current row or the insert
     * row. The updater methods do not update the underlying database; instead
     * the <code>updateRow</code> or <code>insertRow</code> methods are called
     * to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param x the column value
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateRowId(String columnLabel, RowId x) throws SQLException
  {
    throw new VirtuosoFNSException ("updateRowId(columnLabel, x)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Retrieves the holdability of this <code>ResultSet</code> object
     * @return  either <code>ResultSet.HOLD_CURSORS_OVER_COMMIT</code> or <code>ResultSet.CLOSE_CURSORS_AT_COMMIT</code>
     * @throws SQLException if a database access error occurs
     * or this method is called on a closed result set
     * @since 1.6
     */
  public int getHoldability() throws SQLException
  {
    throw new VirtuosoFNSException ("getHoldability()  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Retrieves whether this <code>ResultSet</code> object has been closed. A <code>ResultSet</code> is closed if the
     * method close has been called on it, or if it is automatically closed.
     *
     * @return true if this <code>ResultSet</code> object is closed; false if it is still open
     * @throws SQLException if a database access error occurs
     * @since 1.6
     */
  public boolean isClosed() throws SQLException
  {
    if (statement == null || statement.future == null)
      return true;
    else
      return false;
  }

    /**
     * Updates the designated column with a <code>String</code> value.
     * It is intended for use when updating <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param nString the value for the column to be updated
     * @throws SQLException if the columnIndex is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or if a database access error occurs
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNString(int columnIndex, String x) throws SQLException
  {
      // Check parameters
      if(columnIndex < 1 || columnIndex > metaData.getColumnCount())
         throw new VirtuosoException("Index " + columnIndex + " is not 1<n<" + metaData.getColumnCount(),VirtuosoException.BADPARAM);
      // Check if the rowupd exist
      if(row == null)
      {
         row = new Object[metaData.getColumnCount()];
         if(!(currentRow < 1 || currentRow > rows.size()))
            ((VirtuosoRow)(rows.elementAt(currentRow - 1))).getContent(row);
      }
      row[columnIndex - 1] = x;
  }

    /**
     * Updates the designated column with a <code>String</code> value.
     * It is intended for use when updating <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param nString the value for the column to be updated
     * @throws SQLException if the columnLabel is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     * the result set concurrency is <CODE>CONCUR_READ_ONLY</code>
     *  or if a database access error occurs
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateNString(String columnLabel, String nString) throws SQLException
  {
    updateNString (findColumn (columnLabel), nString);
  }

    /**
     * Updates the designated column with a <code>java.sql.NClob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param nClob the value for the column to be updated
     * @throws SQLException if the columnIndex is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     * if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNClob(int columnIndex, NClob nClob) throws SQLException
  {
    updateCharacterStream (columnIndex, nClob.getCharacterStream(), (int) nClob.length());
  }

    /**
     * Updates the designated column with a <code>java.sql.NClob</code> value.
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param nClob the value for the column to be updated
     * @throws SQLException if the columnLabel is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     *  if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateNClob(String columnLabel, NClob nClob) throws SQLException
  {
    updateNClob (findColumn (columnLabel), nClob);
  }

    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a <code>NClob</code> object
     * in the Java programming language.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @return a <code>NClob</code> object representing the SQL
     *         <code>NCLOB</code> value in the specified column
     * @exception SQLException if the columnIndex is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set
     * or if a database access error occurs
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized NClob getNClob(int columnIndex) throws SQLException
  {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getClob(columnIndex);
  }

  /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a <code>NClob</code> object
     * in the Java programming language.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @return a <code>NClob</code> object representing the SQL <code>NCLOB</code>
     * value in the specified column
     * @exception SQLException if the columnLabel is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set
     * or if a database access error occurs
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public NClob getNClob(String columnLabel) throws SQLException
  {
    return getNClob(findColumn (columnLabel));
  }

    /**
     * Retrieves the value of the designated column in  the current row of
     *  this <code>ResultSet</code> as a
     * <code>java.sql.SQLXML</code> object in the Java programming language.
     * @param columnIndex the first column is 1, the second is 2, ...
     * @return a <code>SQLXML</code> object that maps an <code>SQL XML</code> value
     * @throws SQLException if the columnIndex is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public SQLXML getSQLXML(int columnIndex) throws SQLException
  {
    throw new VirtuosoFNSException ("getSQLXML(columnIndex)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Retrieves the value of the designated column in  the current row of
     *  this <code>ResultSet</code> as a
     * <code>java.sql.SQLXML</code> object in the Java programming language.
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @return a <code>SQLXML</code> object that maps an <code>SQL XML</code> value
     * @throws SQLException if the columnLabel is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public SQLXML getSQLXML(String columnLabel) throws SQLException
  {
    throw new VirtuosoFNSException ("getSQLXML(String columnLabel)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Updates the designated column with a <code>java.sql.SQLXML</code> value.
     * The updater
     * methods are used to update column values in the current row or the insert
     * row. The updater methods do not update the underlying database; instead
     * the <code>updateRow</code> or <code>insertRow</code> methods are called
     * to update the database.
     * <p>
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param xmlObject the value for the column to be updated
     * @throws SQLException if the columnIndex is not valid;
     * if a database access error occurs; this method
     *  is called on a closed result set;
     * the <code>java.xml.transform.Result</code>,
     *  <code>Writer</code> or <code>OutputStream</code> has not been closed
     * for the <code>SQLXML</code> object;
     *  if there is an error processing the XML value or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>.  The <code>getCause</code> method
     *  of the exception may provide a more detailed exception, for example, if the
     *  stream does not contain valid XML.
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateSQLXML(int columnIndex, SQLXML xmlObject) throws SQLException
  {
    throw new VirtuosoFNSException ("updateSQLXML(columnIndex, xmlObject)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Updates the designated column with a <code>java.sql.SQLXML</code> value.
     * The updater
     * methods are used to update column values in the current row or the insert
     * row. The updater methods do not update the underlying database; instead
     * the <code>updateRow</code> or <code>insertRow</code> methods are called
     * to update the database.
     * <p>
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param xmlObject the column value
     * @throws SQLException if the columnLabel is not valid;
     * if a database access error occurs; this method
     *  is called on a closed result set;
     * the <code>java.xml.transform.Result</code>,
     *  <code>Writer</code> or <code>OutputStream</code> has not been closed
     * for the <code>SQLXML</code> object;
     *  if there is an error processing the XML value or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>.  The <code>getCause</code> method
     *  of the exception may provide a more detailed exception, for example, if the
     *  stream does not contain valid XML.
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateSQLXML(String columnLabel, SQLXML xmlObject) throws SQLException
  {
    throw new VirtuosoFNSException ("updateSQLXML(columnLabel, xmlObject)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as
     * a <code>String</code> in the Java programming language.
     * It is intended for use when
     * accessing  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @return the column value; if the value is SQL <code>NULL</code>, the
     * value returned is <code>null</code>
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized String getNString(int columnIndex) throws SQLException
  {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getString(columnIndex);
  }


    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as
     * a <code>String</code> in the Java programming language.
     * It is intended for use when
     * accessing  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @return the column value; if the value is SQL <code>NULL</code>, the
     * value returned is <code>null</code>
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public String getNString(String columnLabel) throws SQLException
  {
    return getNString(findColumn (columnLabel));
  }


    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a
     * <code>java.io.Reader</code> object.
     * It is intended for use when
     * accessing  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     *
     * @return a <code>java.io.Reader</code> object that contains the column
     * value; if the value is SQL <code>NULL</code>, the value returned is
     * <code>null</code> in the Java programming language.
     * @param columnIndex the first column is 1, the second is 2, ...
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized java.io.Reader getNCharacterStream(int columnIndex) throws SQLException
  {
      // Get and check the current row number
      if(currentRow < 1 || currentRow > rows.size())
         throw new VirtuosoException("Bad current row selected : " + currentRow + " not in 1<n<" + rows.size(),VirtuosoException.BADPARAM);
      // Run the method
      return ((VirtuosoRow)rows.elementAt(currentRow - 1)).getCharacterStream(columnIndex);
  }

    /**
     * Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object as a
     * <code>java.io.Reader</code> object.
     * It is intended for use when
     * accessing  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @return a <code>java.io.Reader</code> object that contains the column
     * value; if the value is SQL <code>NULL</code>, the value returned is
     * <code>null</code> in the Java programming language
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public java.io.Reader getNCharacterStream(String columnLabel) throws SQLException
  {
    return getNCharacterStream (findColumn (columnLabel));
  }

    /**
     * Updates the designated column with a character stream value, which will have
     * the specified number of bytes.   The
     * driver does the necessary conversion from Java character format to
     * the national character set in the database.
     * It is intended for use when
     * updating  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code> or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNCharacterStream(int columnIndex,
			     java.io.Reader x,
		     long length) throws SQLException
  {
      updateCharacterStream(columnIndex, x, length);
  }

    /**
     * Updates the designated column with a character stream value, which will have
     * the specified number of bytes.  The
     * driver does the necessary conversion from Java character format to
     * the national character set in the database.
     * It is intended for use when
     * updating  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader the <code>java.io.Reader</code> object containing
     *        the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code> or this method is called on a closed result set
      * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateNCharacterStream(String columnLabel,
			     java.io.Reader reader,
			     long length) throws SQLException
  {
    updateNCharacterStream (findColumn (columnLabel), reader, length);
  }

    /**
     * Updates the designated column with an ascii stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateAsciiStream(int columnIndex,
			   java.io.InputStream x,
			   long length) throws SQLException
  {
    updateAsciiStream(columnIndex, x, (int)length);
  }

    /**
     * Updates the designated column with a binary stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateBinaryStream(int columnIndex,
			    java.io.InputStream x,
			    long length) throws SQLException
  {
    updateBinaryStream(columnIndex, x, length);
  }

    /**
     * Updates the designated column with a character stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateCharacterStream(int columnIndex,
			     java.io.Reader x,
			     long length) throws SQLException
  {
    updateCharacterStream(columnIndex, x, length);
  }

    /**
     * Updates the designated column with an ascii stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateAsciiStream(String columnLabel,
			   java.io.InputStream x,
			   long length) throws SQLException
  {
    updateAsciiStream (findColumn (columnLabel), x, length);
  }

    /**
     * Updates the designated column with a binary stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param x the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateBinaryStream(String columnLabel,
			    java.io.InputStream x,
			    long length) throws SQLException
  {
    updateBinaryStream (findColumn (columnLabel), x, length);
  }

    /**
     * Updates the designated column with a character stream value, which will have
     * the specified number of bytes.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader the <code>java.io.Reader</code> object containing
     *        the new column value
     * @param length the length of the stream
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateCharacterStream(String columnLabel,
			     java.io.Reader reader,
			     long length) throws SQLException
  {
    updateCharacterStream (findColumn (columnLabel), reader, length);
  }

    /**
     * Updates the designated column using the given input stream, which
     * will have the specified number of bytes.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @param length the number of bytes in the parameter data.
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateBlob(int columnIndex, InputStream inputStream, long length) throws SQLException
  {
    updateBinaryStream (columnIndex, inputStream, (int)length);
  }

    /**
     * Updates the designated column using the given input stream, which
     * will have the specified number of bytes.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @param length the number of bytes in the parameter data.
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateBlob(String columnLabel, InputStream inputStream, long length) throws SQLException
  {
    updateBlob (findColumn (columnLabel), inputStream, length);
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object, which is the given number of characters long.
     * When a very large UNICODE value is input to a <code>LONGVARCHAR</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.Reader</code> object. The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateClob(int columnIndex,  Reader reader, long length) throws SQLException
  {
    updateCharacterStream (columnIndex, reader, (int)length);
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object, which is the given number of characters long.
     * When a very large UNICODE value is input to a <code>LONGVARCHAR</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.Reader</code> object.  The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateClob(String columnLabel,  Reader reader, long length) throws SQLException
  {
    updateClob (findColumn (columnLabel), reader, length);
  }

   /**
     * Updates the designated column using the given <code>Reader</code>
     * object, which is the given number of characters long.
     * When a very large UNICODE value is input to a <code>LONGVARCHAR</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.Reader</code> object. The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @throws SQLException if the columnIndex is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set,
     * if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public synchronized void updateNClob(int columnIndex,  Reader reader, long length) throws SQLException
  {
    updateCharacterStream (columnIndex, reader, (int)length);
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object, which is the given number of characters long.
     * When a very large UNICODE value is input to a <code>LONGVARCHAR</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.Reader</code> object. The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @throws SQLException if the columnLabel is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     *  if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateNClob(String columnLabel,  Reader reader, long length) throws SQLException
  {
    updateNClob (findColumn (columnLabel), reader, length);
  }

    /**
     * Updates the designated column with a character stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.  The
     * driver does the necessary conversion from Java character format to
     * the national character set in the database.
     * It is intended for use when
     * updating  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateNCharacterStream</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code> or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateNCharacterStream(int columnIndex, java.io.Reader x) throws SQLException
  {
    throw new VirtuosoFNSException ("updateNCharacterStream(columnIndex, x)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Updates the designated column with a character stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.  The
     * driver does the necessary conversion from Java character format to
     * the national character set in the database.
     * It is intended for use when
     * updating  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> columns.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateNCharacterStream</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader the <code>java.io.Reader</code> object containing
     *        the new column value
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code> or this method is called on a closed result set
      * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateNCharacterStream(String columnLabel, java.io.Reader reader) throws SQLException
  {
    throw new VirtuosoFNSException ("updateNCharacterStream(columnLabel, reader)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Updates the designated column with an ascii stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateAsciiStream</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateAsciiStream(int columnIndex, java.io.InputStream x) throws SQLException
  {
    throw new VirtuosoFNSException ("updateAsciiStream(columnIndex, x)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Updates the designated column with a binary stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateBinaryStream</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateBinaryStream(int columnIndex, java.io.InputStream x) throws SQLException
  {
    throw new VirtuosoFNSException ("updateBinaryStream(columnIndex, x)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Updates the designated column with a character stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateCharacterStream</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param x the new column value
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateCharacterStream(int columnIndex, java.io.Reader x) throws SQLException
  {
    throw new VirtuosoFNSException ("updateCharacterStream(columnIndex, x)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Updates the designated column with an ascii stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateAsciiStream</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param x the new column value
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateAsciiStream(String columnLabel, java.io.InputStream x) throws SQLException
  {
    throw new VirtuosoFNSException ("updateAsciiStream(columnLabel, x)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Updates the designated column with a binary stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateBinaryStream</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param x the new column value
     * @exception SQLException if the columnLabel is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateBinaryStream(String columnLabel, java.io.InputStream x) throws SQLException
  {
    throw new VirtuosoFNSException ("updateBinaryStream(columnLabel, x)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Updates the designated column with a character stream value.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateCharacterStream</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader the <code>java.io.Reader</code> object containing
     *        the new column value
     * @exception SQLException if the columnLabel is not valid; if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateCharacterStream(String columnLabel, java.io.Reader reader) throws SQLException
  {
    throw new VirtuosoFNSException ("updateCharacterStream(columnLabel, reader)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Updates the designated column using the given input stream. The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateBlob</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @exception SQLException if the columnIndex is not valid; if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateBlob(int columnIndex, InputStream inputStream) throws SQLException
  {
    throw new VirtuosoFNSException ("updateBlob(columnIndex, inputStream)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Updates the designated column using the given input stream. The data will be read from the stream
     * as needed until end-of-stream is reached.
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     *   <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateBlob</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @exception SQLException if the columnLabel is not valid; if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateBlob(String columnLabel, InputStream inputStream) throws SQLException
  {
    throw new VirtuosoFNSException ("updateBlob(columnLabel, inputStream)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object.
     *  The data will be read from the stream
     * as needed until end-of-stream is reached.  The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     *   <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateClob</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param reader An object that contains the data to set the parameter value to.
     * @exception SQLException if the columnIndex is not valid;
     * if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateClob(int columnIndex,  Reader reader) throws SQLException
  {
    throw new VirtuosoFNSException ("updateClob(columnIndex,  reader)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object.
     *  The data will be read from the stream
     * as needed until end-of-stream is reached.  The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateClob</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader An object that contains the data to set the parameter value to.
     * @exception SQLException if the columnLabel is not valid; if a database access error occurs;
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * or this method is called on a closed result set
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateClob(String columnLabel,  Reader reader) throws SQLException
  {
    throw new VirtuosoFNSException ("updateClob(columnLabel,  reader)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

   /**
     * Updates the designated column using the given <code>Reader</code>
     *
     * The data will be read from the stream
     * as needed until end-of-stream is reached.  The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateNClob</code> which takes a length parameter.
     *
     * @param columnIndex the first column is 1, the second 2, ...
     * @param reader An object that contains the data to set the parameter value to.
     * @throws SQLException if the columnIndex is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set,
     * if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateNClob(int columnIndex,  Reader reader) throws SQLException
  {
    throw new VirtuosoFNSException ("updateNClob(columnIndex,  reader)  not supported", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Updates the designated column using the given <code>Reader</code>
     * object.
     * The data will be read from the stream
     * as needed until end-of-stream is reached.  The JDBC driver will
     * do any necessary conversion from UNICODE to the database char format.
     *
     * <p>
     * The updater methods are used to update column values in the
     * current row or the insert row.  The updater methods do not
     * update the underlying database; instead the <code>updateRow</code> or
     * <code>insertRow</code> methods are called to update the database.
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>updateNClob</code> which takes a length parameter.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.  If the SQL AS clause was not specified, then the label is the name of the column
     * @param reader An object that contains the data to set the parameter value to.
     * @throws SQLException if the columnLabel is not valid; if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; this method is called on a closed result set;
     *  if a database access error occurs or
     * the result set concurrency is <code>CONCUR_READ_ONLY</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void updateNClob(String columnLabel,  Reader reader) throws SQLException
  {
    throw new VirtuosoFNSException ("updateNClob(columnLabel,  reader)  not supported", VirtuosoException.NOTIMPLEMENTED);
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
    //------------------------- JDBC 4.1 -----------------------------------


    /**
     *<p>Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object and will convert from the
     * SQL type of the column to the requested Java data type, if the
     * conversion is supported. If the conversion is not
     * supported  or null is specified for the type, a
     * <code>SQLException</code> is thrown.
     *<p>
     * At a minimum, an implementation must support the conversions defined in
     * Appendix B, Table B-3 and conversion of appropriate user defined SQL
     * types to a Java type which implements {@code SQLData}, or {@code Struct}.
     * Additional conversions may be supported and are vendor defined.
     *
     * @param columnIndex the first column is 1, the second is 2, ...
     * @param type Class representing the Java data type to convert the designated
     * column to.
     * @return an instance of {@code type} holding the column value
     * @throws SQLException if conversion is not supported, type is null or
     *         another error occurs. The getCause() method of the
     * exception may provide a more detailed exception, for example, if
     * a conversion error occurs
     * @throws SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.7
     */
  public <T> T getObject(int columnIndex, Class<T> type) throws SQLException
  {
    if (type == null) {
      throw new VirtuosoException ("Type parameter can not be null", 
                    "S1009", VirtuosoException.BADPARAM);
    }
		
    if (type.equals(String.class)) {
      return (T) getString(columnIndex);
    } else if (type.equals(BigDecimal.class)) {
      return (T) getBigDecimal(columnIndex);
    } else if (type.equals(Boolean.class) || type.equals(Boolean.TYPE)) {
      return (T) Boolean.valueOf(getBoolean(columnIndex));
    } else if (type.equals(Integer.class) || type.equals(Integer.TYPE)) {
      return (T) Integer.valueOf(getInt(columnIndex));
    } else if (type.equals(Long.class) || type.equals(Long.TYPE)) {
      return (T) Long.valueOf(getLong(columnIndex));
    } else if (type.equals(Float.class) || type.equals(Float.TYPE)) {
      return (T) Float.valueOf(getFloat(columnIndex));
    } else if (type.equals(Double.class) || type.equals(Double.TYPE)) {
      return (T) Double.valueOf(getDouble(columnIndex));
    } else if (type.equals(byte[].class)) {
      return (T) getBytes(columnIndex);
    } else if (type.equals(java.sql.Date.class)) {
      return (T) getDate(columnIndex);
    } else if (type.equals(Time.class)) {
      return (T) getTime(columnIndex);
    } else if (type.equals(Timestamp.class)) {
      return (T) getTimestamp(columnIndex);
    } else if (type.equals(Clob.class)) {
      return (T) getClob(columnIndex);
    } else if (type.equals(Blob.class)) {
      return (T) getBlob(columnIndex);
    } else if (type.equals(Array.class)) {
      return (T) getArray(columnIndex);
    } else if (type.equals(Ref.class)) {
      return (T) getRef(columnIndex);
    } else if (type.equals(java.net.URL.class)) {
      return (T) getURL(columnIndex);
//		} else if (type.equals(Struct.class)) {
//				
//			} 
//		} else if (type.equals(RowId.class)) {
//			
//		} else if (type.equals(NClob.class)) {
//			
//		} else if (type.equals(SQLXML.class)) {
			
    } else {
      try {
        return (T) getObject(columnIndex);
      } catch (ClassCastException cce) {
         throw new VirtuosoException ("Conversion not supported for type " + type.getName(), 
                    "S1009", VirtuosoException.BADPARAM);
      }
    }
  }


    /**
     *<p>Retrieves the value of the designated column in the current row
     * of this <code>ResultSet</code> object and will convert from the
     * SQL type of the column to the requested Java data type, if the
     * conversion is supported. If the conversion is not
     * supported  or null is specified for the type, a
     * <code>SQLException</code> is thrown.
     *<p>
     * At a minimum, an implementation must support the conversions defined in
     * Appendix B, Table B-3 and conversion of appropriate user defined SQL
     * types to a Java type which implements {@code SQLData}, or {@code Struct}.
     * Additional conversions may be supported and are vendor defined.
     *
     * @param columnLabel the label for the column specified with the SQL AS clause.
     * If the SQL AS clause was not specified, then the label is the name
     * of the column
     * @param type Class representing the Java data type to convert the designated
     * column to.
     * @return an instance of {@code type} holding the column value
     * @throws SQLException if conversion is not supported, type is null or
     *         another error occurs. The getCause() method of the
     * exception may provide a more detailed exception, for example, if
     * a conversion error occurs
     * @throws SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.7
     */
  public <T> T getObject(String columnLabel, Class<T> type) throws SQLException
  {
    return getObject(findColumn(columnLabel), type);
  }

#endif

#endif
#endif
}

