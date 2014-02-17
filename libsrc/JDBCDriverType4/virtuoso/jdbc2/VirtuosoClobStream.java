/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

/**
 * The VirtuosoClobStream is used to get a clob into an input
 * stream.
 *
 * @version 1.0 (JDBC API 2.0 implementation)
 */
class VirtuosoClobStream extends InputStream
{
   // The clob attached to this stream
   private VirtuosoBlob clob;

   // The actual position into the clob
   protected long pos = 1;

   /**
    * Constructs a VirtuosoClobStream using a clob.
    *
    * @param blob The clob to get.
    */
   VirtuosoClobStream(VirtuosoBlob clob)
   {
      this.clob = clob;
      //try
      //   {
      //System.out.println ("init , len=" + clob.length());
      //    }
      //catch (Exception e) { };
   }

   // ------------------------ InputStream -----------------------------
   /**
    * Reads the next byte of data from this input stream. The value
    * byte is returned as an <code>int</code> in the range
    * <code>0</code> to <code>255</code>. If no byte is available
    * because the end of the stream has been reached, the value
    * <code>-1</code> is returned. This method blocks until input data
    * is available, the end of the stream is detected, or an exception
    * is thrown.
    *
    * @return     the next byte of data, or <code>-1</code> if the end of the
    *             stream is reached.
    * @exception  IOException  if an I/O error occurs.
    */
   public int read() throws IOException
   {
     //if (VirtuosoFuture.rpc_log != null)
     //  VirtuosoFuture.rpc_log.println ("read1, pos=" + pos);
     //  System.err.println ("read1, pos=" + pos);
      try
      {
	 //System.err.print ("(conn " + hashCode() + ") IN ");
         // Check if it's the end of the stream
         return (pos > clob.length()) ? -1 : ((clob.getSubString(pos++,1)).getBytes("ASCII"))[0];
      }
      catch(Exception e)
      {
         throw new IOException(e.getMessage());
      }
   }

   /**
    * Reads up to <code>len</code> bytes of data from this input stream
    * into an array of bytes. This method blocks until some input is
    * available. If the argument <code>b</code> is <code>null</code>, a
    * <code>NullPointerException</code> is thrown.
    *
    * @param      b     the buffer into which the data is read.
    * @param      off   the start offset of the data.
    * @param      len   the maximum number of bytes read.
    * @return     the total number of bytes read into the buffer, or
    *             <code>-1</code> if there is no more data because the end of
    *             the stream has been reached.
    * @exception  IOException  if an I/O error occurs.
    * @see        java.io.InputStream#read()
    */
   public int read(byte b[], int off, int len) throws IOException
   {
      //   System.err.println ("read2, pos=" + pos + " len = " + len);
      try
      {
	byte[] bytes = null;
	//if (VirtuosoFuture.rpc_log != null)
	  //VirtuosoFuture.rpc_log.println ("read2, pos=" + pos + " len = " + len);
         // Check parameters
         if(len <= 0)
            return 0;
         // Check if it's the end of the stream
         if((pos + len) > clob.length())
         {
	    int to_read = (int)(clob.length() - pos + 1);
	    if (to_read > 0)
	      bytes = clob.getSubString (pos, to_read).getBytes("ASCII");
	    if (bytes != null)
	      {
		System.arraycopy(bytes,0,b,off,to_read);
		pos = clob.length() + 1;
		return bytes.length;
	      }
	    else
	      return -1;
         }
         // Read the byte
	 bytes = clob.getSubString(pos,len).getBytes("ASCII");
	 if (bytes != null)
	   {
	     System.arraycopy(bytes,0,b,off,len);
	     pos += bytes.length;
	     return bytes.length;
	   }
	 else return -1;
      }
      catch(Exception e)
      {
         throw new IOException(e.getMessage());
      }
   }

   /**
    * Skips over and discards <code>n</code> bytes of data from this
    * input stream. The <code>skip</code> method may, for a variety of
    * reasons, end up skipping over some smaller number of bytes,
    * possibly <code>0</code>. The actual number of bytes skipped is
    * returned.
    *
    * @param      n   the number of bytes to be skipped.
    * @return     the actual number of bytes skipped.
    * @exception  IOException  if an I/O error occurs.
    * @since      JDK1.0
    */
   public long skip(long n) throws IOException
   {
      try
      {
         // Check parameters
         if(n <= 0)
            return 0;
         // Skip n bytes
         if((pos + n) > clob.length())
         {
            long _prov = clob.length() - pos;
            pos = clob.length();
            return _prov;
         }
         pos += n;
         return n;
      }
      catch(Exception e)
      {
         throw new IOException(e.getMessage());
      }
   }

   /**
    * Returns the number of bytes that can be read from this input
    * stream without blocking. The available method of
    *
    * @return     the number of bytes that can be read from this input stream
    *             without blocking.
    * @exception  IOException  if an I/O error occurs.
    */
   public int available() throws IOException
   {
      try
      {
         return (int)(clob.length() - pos + 1);
      }
      catch(Exception e)
      {
         throw new IOException(e.getMessage());
      }
   }

}

