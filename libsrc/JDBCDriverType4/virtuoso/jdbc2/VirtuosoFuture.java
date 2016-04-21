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

import java.io.*;
import openlink.util.*;

/**
 * The VirtuosoFuture class is an implementation of the RPC mechanism.
 *
 * @version 1.0 (JDBC API 2.0 implementation)
 */
class VirtuosoFuture
{
   // RPC name :
   protected static final String callerid = "caller_identification";

   protected static final String scon = "SCON";

   protected static final String exec = "EXEC";

   protected static final String close = "FRST";

   protected static final String fetch = "FTCH";

   protected static final String prepare = "PREP";

   protected static final String transaction = "TRXC";

   protected static final String getdata = "GETDA";

   protected static final String extendedfetch = "EXTF";

   protected static final String cancel = "CANCEL";

   protected static final String tp_transaction = "TPTRX";

   // The future request id
   private int req_no;

   // Its corresponding VirtuosoConnection
   private VirtuosoConnection connection;

   // Queue of results
   //private openlink.util.Vector results=new openlink.util.Vector(5,10);
   private openlink.util.Vector results = new openlink.util.Vector(5);

   // Set if there has been a DA_FUTURE_ANSWER message to this future
   private boolean is_complete = false;

   protected static PrintWriter rpc_log = null;
   // Mutex used to access to the queue of results
   //private Semaphore mutex;
   /**
    * Constructs a new VirtuosoFuture request corresponding to a
    * VirtuosoConnection, a RPC name and an array of arguments (8 max.).
    *
    * @param connection	Its corresponding connection.
    * @param rpcname		The name of the RPC function.
    * @param args			The array of arguments.
    * @param req_no     The request serial number.
    * @exception java.io.IOException	An error occurred.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred;
    */
   VirtuosoFuture(VirtuosoConnection connection, String rpcname, Object[] args, int req_no, int timeout)
       throws IOException, VirtuosoException
   {
      // Reference the corresponding connection
      this.connection = connection;
      this.req_no = req_no;
      // Create the mutex
      /*try { mutex = new Semaphore(Semaphore.MUTEX); }
         catch(SemaphoreException e) {}*/
      connection.setSocketTimeout(timeout);
      send_message(rpcname,args);
   }

   /**
    * Send an RPC call to a function with its name and parameters.
    *
    * @param rpcname		The name of the RPC function.
    * @param args			The array of arguments.
    * @exception java.io.IOException	An error occurred.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred;
    */
   protected void send_message(String rpcname, Object[] args) throws IOException, VirtuosoException
   {
      Object[] vector = new Object[5];
      if(args != null)
      {
         openlink.util.Vector v = new openlink.util.Vector(args);
         vector[4] = v;
      }
      else
         vector[4] = null;
      vector[3] = rpcname;
      vector[2] = null;
      vector[1] = new Integer(req_no);
      vector[0] = new Integer(VirtuosoTypes.DA_FUTURE_REQUEST);
      // Serialize data and flush the stream
      connection.write_object(new openlink.util.Vector(vector));
   }

   /**
    * Put a result in the queue.
    *
    * @param obj  The result to put in the queue.
    */
   protected void putResult(Object res)
   {
      results.addElement(res);
   /*try { mutex.getSem(); results.addElement(res); }
      catch(InterruptedException e) { }
      finally { mutex.freeSem(); }*/
   }

   /**
    * Returns the next result of the answer queue messages.
    *
    * @return Object	A Vector object or a base class.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   protected openlink.util.Vector nextResult() throws VirtuosoException
   {
      try
      {
         // Try to read an answer
        while(results.isEmpty())
          connection.read_request();

         // Get the next result of the queue
         //mutex.getSem();
         // Get the next result of the queue
         openlink.util.Vector vect = (openlink.util.Vector)results.firstElement();
         results.removeElementAt(0);
         return vect;
      }
      catch(IOException e)
      {
	sendCancelFuture();
         throw new VirtuosoException("Virtuoso Communications Link Failure (timeout) : " + e.getMessage(),
	     VirtuosoException.IOERROR);
      }
   /*catch(InterruptedException e) { }
      finally { mutex.freeSem(); }
      return null;*/
   }

   protected void sendCancelFuture () throws VirtuosoException
     {
       int ver = connection.getVersionNum();
       //System.err.println ("sendCancelFuture: Version is " + ver);
       try
	 {
	   //System.err.println ("sendCancelFuture: sending cancel");
	   Object[] args = new Object[0];
	   connection.removeFuture (connection.getFuture (VirtuosoFuture.cancel, args, 0));
	 }
       catch (IOException e)
	 {
	   //System.err.println ("sendCancelFuture: IOException ocurred : " + e.getMessage());
	 }
       catch (VirtuosoException e2)
	 {
	   //System.err.println ("sendCancelFuture: VirtuosoException ocurred : " + e2.getMessage());
	   throw e2;
	 }
     }


   /**
    * Function uses to set the is_complete flag.
    *
    * @param isComplete The boolean status to set.
    */
   protected void complete(boolean isComplete)
   {
      is_complete = isComplete;
   }

   // --------------------------- Object ------------------------------
   /**
    * Returns a hash code value for the object.
    *
    * @return int	The hash code value.
    */
   public int hashCode()
   {
      return req_no;
   }

   /**
    * Compares two Objects for equality.
    *
    * @return boolean	True if two objects are equal, else false.
    */
   public boolean equals(Object obj)
   {
      // First check if the object is not null or the same object type
      if(obj != null && (obj instanceof VirtuosoFuture))
         return ((VirtuosoFuture)obj).req_no == req_no;
      return false;
   }

}

