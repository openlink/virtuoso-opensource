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

import java.sql.*;
import java.io.*;

/**
 * The VirtuosoBlob class is an implementation of the Blob
 * interface in the JDBC API that represents a Blob object in SQL.
 *
 * @version 1.0 (JDBC API 2.0 implementation)
 * @see java.sql.Blob
 */
public class VirtuosoBlob
#if JDK_VER >= 12
  implements Blob, Clob
#if JDK_VER >= 16
   ,NClob
#endif
#endif
{
   // A flag to say if it may do some requests
   private boolean request = true;

   // The length of the blob
   private long length, bh_page, ask, bh_current_page, bh_start_offset, bh_position;

   // a cache for the current page
   //private byte bh_buffer[VirtuosoTypes.PAGESIZ];

   // The buffer where data are stored
   private byte[] buffer;

   private Reader rd;

   // The input stream issued from
   private InputStream is;

   // The connection used to get this blob
   private VirtuosoConnection connection;

   protected int dtp;
   // serialization parts
   protected long key_id = 0;
   protected long frag_no = 0;
   protected long dir_page = 0;
   protected long bh_timestamp = 0;
   protected Object pages = null;
   /**
    * Constructs a new VirtuosoBlob object from an InputStream.
    *
    * @param is		The input stream.
    * @param length	The length of the blob to construct from.
    * @param index	The unique Blob number
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   VirtuosoBlob(InputStream is, long length, long index) throws VirtuosoException
   {
      this.is = is;
      this.bh_page = index;
      this.length = length;
      rewind();
   }

   private void rewind ()
     {
       this.bh_current_page = this.bh_page;
       this.bh_start_offset = 0;
       this.bh_position = 0;
     }

   private long bh_offset()
     {
       return this.bh_start_offset;
     }

   /**
    * Constructs a new VirtuosoBlob object from a array.
    *
    * @param array		The byte array.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   VirtuosoBlob(byte[] array) throws VirtuosoException
   {
      this.buffer = array;
      this.request = false;
      this.length = array.length;
   }

   VirtuosoBlob() throws VirtuosoException
   {
   }

   /**
    * Constructs a new VirtuosoBlob object from an Object.
    *
    * @param obj		The object.
    * @param index	The unique Blob number
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   VirtuosoBlob(Object obj, long index) throws VirtuosoException
   {
   //this.obj=obj; this.index=index;
   }

   /**
    * Constructs a new VirtuosoClob object from a Reader.
    *
    * @param rd		The Reader class.
    * @param length	The length of the clob to construct from.
    * @param index	The unique Clob number
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   VirtuosoBlob(Reader rd, long length, long index) throws VirtuosoException
   {
      this.rd = rd;
      this.length = length;
      this.bh_page = index;
      rewind();
   }

   /**
    * Constructs a new VirtuosoBlob handle.
    *
    * @param connection The connection attached to this blob.
    * @param ask		The ask from client flag.
    * @param index	The unique Blob number
    * @param length	The length of the blob to construct from.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   VirtuosoBlob(VirtuosoConnection connection, long ask, long index, long length) throws VirtuosoException
   {
      this.connection = connection;
      this.ask = ask;
      this.bh_page = index;
      this.length = length;
      this.dtp = VirtuosoTypes.DV_BLOB_HANDLE;
      rewind();
   }

   VirtuosoBlob(VirtuosoConnection connection, long ask, long index, long length, long __key_id, long __frag_no, long __dir_page, long __timestamp, Object __pages, int dtp) throws VirtuosoException
   {
      this.connection = connection;
      this.ask = ask;
      this.bh_page = index;
      this.length = length;
      this.dtp = dtp;
      this.key_id = __key_id;
      this.frag_no = __frag_no;
      this.dir_page = __dir_page;
      this.bh_timestamp = __timestamp;
      this.pages = __pages;
      rewind();
      //System.out.println ("Creating a virtuoso blob :");
      //System.out.println ("\tthis.ask=" + this.ask);
      //System.out.println ("\tthis.bh_page=" + this.bh_page);
      //System.out.println ("\tthis.length=" + this.length);
      //System.out.println ("\tthis.dtp=" + this.dtp);
      //System.out.println ("\tthis.key_id=" + this.key_id);
      //System.out.println ("\tthis.frag_no=" + this.frag_no);
      //System.out.println ("\tthis.dir_page=" + this.dir_page);
      //System.out.println ("\tthis.bh_timestamp=" + this.bh_timestamp);


   }

   /**
    * Set the input stream.
    *
    * @param is		The new InputStream to consider.
    * @param length	And its new length.
    */
   protected void setInputStream(InputStream is, long length)
   {
      this.is = is;
      this.length = length;
   }

   /**
    * Set the reader.
    *
    * @param rd		The new Reader to consider.
    * @param length	And its new length.
    */
   protected void setReader(Reader rd, long length)
   {
      this.rd = rd;
      this.length = length;
   }

   /**
    * Set the object.
    *
    * @param obj		The new Object to consider.
    */
   protected void setObject(Object obj)
   {
   //this.obj=obj;
   }

   // --------------------------- JDBC 2.0 ------------------------------
   /**
    * Returns as an array of bytes part or all of the <code>BLOB</code>
    * value that this <code>Blob</code> object designates.  The byte
    * array contains up to <code>length</code> consecutive bytes
    * starting at position <code>pos</code>.
    *
    * @param pos the ordinal position of the first byte in the
    * <code>BLOB</code> value to be extracted; the first byte is at
    * position 1
    * @param length is the number of consecutive bytes to be copied
    * @return a byte array containing up to <code>length</code>
    * consecutive bytes from the <code>BLOB</code> value designated
    * by this <code>Blob</code> object, starting with the
    * byte at position <code>pos</code>.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   private void checkBlobError (openlink.util.Vector curr) throws VirtuosoException
     {
       if (curr.firstElement() instanceof Long &&
	   ((Number) curr.firstElement()).longValue() == VirtuosoTypes.QA_ERROR)
	 {
	   // Throw an exception
	   throw new VirtuosoException(curr.elementAt(2).toString(),
	       curr.elementAt(1).toString(),
	       VirtuosoException.SQLERROR);
	 }
     }
   public byte[] getBytes(long pos, int length) throws VirtuosoException
     {
       //System.out.println ("vb: VirtuosoBlob.getBytes(" + pos + ", " + length + ") dtp=" + dtp);
       if (pos <= 0)
	 throw new VirtuosoException ("Invalid param to the getBytes", "22023", VirtuosoException.BADPARAM);
       //System.out.println ("vb: VirtuosoBlob.getBytes1");
       if(!request)
	 {
           pos--;

	   if(pos>buffer.length || pos+length>buffer.length)
	     {
	       //System.out.println ("vb: return null");
	       return null;
	     }
	   byte[] array = new byte[length];
	   System.arraycopy(buffer, (int)pos, array, 0, length);
	   //System.out.println ("vb: return " + length + "bytes direct");
	   return array;
	 }

       try
	 {
	   // Check input parameters
	   if(pos < 0 || length <= 0 || pos + length - 1 > this.length)
	     {
	       //System.out.println ("vb: return null2 this len =" + this.length);
	       return null;
	     }

	   Long init_read_len = null;
/***
	   if (pos - 1 < bh_offset ())
	     {
	       // we should go from start
	       //System.out.println ("vb: rewind pos:" + pos + " ofs:" + bh_offset());
	       rewind();
//	       init_read_len = new Long ((pos - 1) *
//		   (dtp == VirtuosoTypes.DV_BLOB_WIDE_HANDLE ? -1 : 1));
	       init_read_len = new Long (pos - 1);
	     }
	   else if (pos - 1 > bh_offset ())
	     init_read_len = new Long (pos - bh_offset() - 1);
//	     init_read_len = new Long ((pos - bh_offset() - 1) *
//		 (dtp == VirtuosoTypes.DV_BLOB_WIDE_HANDLE ? -1 : 1));
***/
	   if (pos - 1 < bh_offset ())
	     {
	       // we should go from start
	       //System.out.println ("vb: rewind pos:" + pos + " ofs:" + bh_offset());
	       rewind();
	     }
	   
	   if (pos - 1 > bh_offset ())
	     init_read_len = new Long (pos - bh_offset() - 1);


	   if (init_read_len != null)
	     {
	       //System.out.println ("vb: init read :" + init_read_len);
	       openlink.util.Vector curr = null;
	       synchronized (connection)
		 {
		   // skip the desired number of bytes
		   Object[] args = new Object[9];
		   args[0] = new Long(this.bh_current_page);
		   args[1] = init_read_len;
		   args[2] = new Long(this.bh_position);
		   args[3] = new Long(this.key_id);
		   args[4] = new Long(this.frag_no);
		   args[5] = new Long(this.dir_page);
		   args[6] = this.pages;
		   args[7] = this.dtp == VirtuosoTypes.DV_BLOB_WIDE_HANDLE ? new Long (1) : new Long(0);
		   args[8] = new Long (this.bh_timestamp);
		   //System.out.println ("vb: init read FUTURE: " + this.bh_current_page + " " + init_read_len + " " + this.bh_position);
		   VirtuosoFuture future = connection.getFuture(VirtuosoFuture.getdata,args, -1);
		   curr = future.nextResult();
		   curr = (openlink.util.Vector) curr.firstElement();
		   connection.removeFuture (future);
		 }
	       if(!(curr instanceof openlink.util.Vector))
		 {
		   //System.out.println ("vb: init read returned null future");
		   return null;
		 }
	       checkBlobError(curr);
	       for (int inx = 0; inx < curr.size(); inx++)
		 {
		   Object val = curr.elementAt (inx);
		   //System.out.println ("vb: init read data[" + inx + "]=" + val.getClass().getName());
		   if (val instanceof openlink.util.Vector)
		     {
		       openlink.util.Vector vval = (openlink.util.Vector)val;
		       this.bh_current_page = ((Number) vval.elementAt (1)).longValue();
		       this.bh_position = ((Number) vval.elementAt (2)).longValue();
		       //System.out.println ("vb: init read : bh_position=" + this.bh_position + " bh_cur_page=" + this.bh_current_page);
		       break;
		     }
		   else if (val instanceof String)
		     {
		       String sval = (String)val;
		       if (dtp == VirtuosoTypes.DV_BLOB_WIDE_HANDLE)
			 {
			   this.bh_start_offset += sval.length();
			   //System.out.println ("vb wide: init read : strlen= " + sval.length() +
			   //    " bh_start_offset=" + this.bh_start_offset);
			 }
		       else
			 {
			   this.bh_start_offset += sval.getBytes("8859_1").length;
			   //System.out.println ("vb: init read : strlen= " + sval.getBytes("8859_1").length +
			   //    " bh_start_offset=" + this.bh_start_offset);
			 }
		     }
		 }
	     }

	   //System.out.println ("vb: after init read : bh_start_offset=" + this.bh_start_offset +
	   //    " bh_position=" + this.bh_position + " bh_cur_page=" + this.bh_current_page);
	   ByteArrayOutputStream bo = new ByteArrayOutputStream();

	   openlink.util.Vector curr = null;
	   synchronized (connection)
	     {
	       Object[] args = new Object[9];
	       args[0] = new Long(this.bh_current_page);
//	       args[1] = new Long(length *
//		       (dtp == VirtuosoTypes.DV_BLOB_WIDE_HANDLE ? -1 : 1));
	       args[1] = new Long(length);
	       args[2] = new Long(this.bh_position);
               args[3] = new Long(this.key_id);
               args[4] = new Long(this.frag_no);
               args[5] = new Long(this.dir_page);
               args[6] = this.pages;
	       args[7] = this.dtp == VirtuosoTypes.DV_BLOB_WIDE_HANDLE ? new Long (1) : new Long(0);
	       args[8] = new Long (this.bh_timestamp);
	       //System.out.println ("vb: FUTURE: " + this.bh_current_page + " " + length + " " + this.bh_position);
	       VirtuosoFuture future = connection.getFuture(VirtuosoFuture.getdata,args, -1);
	       curr = future.nextResult();
	       curr = (openlink.util.Vector) curr.firstElement();
	       connection.removeFuture (future);
	     }
	   if(!(curr instanceof openlink.util.Vector))
	     {
	       //System.out.println ("vb: the RPC returned null");
	       return null;
	     }
	   checkBlobError(curr);
	   for (int inx = 0; inx < curr.size(); inx++)
	     {
	       Object val = curr.elementAt (inx);
	       //System.out.println ("vb: data[" + inx + "]=" + val.getClass().getName());
	       if (val instanceof openlink.util.Vector)
		 {
		   openlink.util.Vector vval = (openlink.util.Vector)val;
		   //System.out.println ("vb: vec[1]=" + vval.elementAt (1));
		   //System.out.println ("vb: vec[2]=" + vval.elementAt (2));
		   this.bh_current_page = ((Number) vval.elementAt (1)).longValue();
		   this.bh_position = ((Number) vval.elementAt (2)).longValue();
		   //System.out.println ("vb: bh_position=" + this.bh_position + " bh_cur_page=" + this.bh_current_page);
		 }
	       else if (val instanceof String)
		 {
		   String sval = (String)val;
		   /*
		   if (dtp == VirtuosoTypes.DV_BLOB_WIDE_HANDLE)
		     {
		       bo.write (sval.getBytes("UTF8"));
		       this.bh_start_offset += sval.length();
		       //System.out.println ("vb wide: read : strlen= " + sval.length() +
			//   " bh_start_offset=" + this.bh_start_offset);
		     }
		   else
		   */
		     {
		       bo.write (sval.getBytes("8859_1"));
		       this.bh_start_offset += sval.getBytes("8859_1").length;
		       //System.out.println ("vb: read : strlen= " + sval.getBytes("8859_1").length +
		//	   " bh_start_offset=" + this.bh_start_offset);
		     }
		 }
	     }
	   byte [] ret = bo.toByteArray();
	   //System.out.println ("vb: after read : bh_start_offset=" + this.bh_start_offset +
	    //   " bh_position=" + this.bh_position + " bh_cur_page=" + this.bh_current_page);
	   return ret;
	 }
       catch(IOException e)
	 {
	   throw new VirtuosoException("I/O error occurred : " + e.getMessage(),VirtuosoException.IOERROR);
	 }
     }

   /**
    * Returns a copy of the specified substring
    * in the <code>CLOB</code> value
    * designated by this <code>Clob</code> object.
    * The substring begins at position
    * <code>pos</code> and has up to <code>length</code> consecutive
    * characters.
    *
    * @param pos the first character of the substring to be extracted.
    * The first character is at position 1.
    * @param length the number of consecutive characters to be copied
    * @return a <code>String</code> that is the specified substring in
    * the <code>CLOB</code> value designated by this <code>Clob</code> object
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   public String getSubString(long pos, int length) throws VirtuosoException
   {
     //System.out.println ("getSubString called len=" + length + " dtp=" + dtp);
     byte[] bytes = getBytes(pos,length);
     //try {
     //  FileOutputStream fo = new FileOutputStream ("substring.gb");
     //  fo.write (bytes);
     //  fo.flush();
     //  fo = null;
     //} catch (Exception e) {};

     if (dtp == VirtuosoTypes.DV_BLOB_WIDE_HANDLE)
       {
	 try
	   {
	     return new String(bytes, "UTF8");
	   }
	 catch (java.io.UnsupportedEncodingException e)
	   {
	     throw new VirtuosoException ("UTF8 not supported in getSubString", VirtuosoException.MISCERROR);
	   }
       }
 /*
     else if (connection.charset != null)
       {
	 try
	   {
	     return connection.uncharsetBytes(new String (bytes, "8859_1"));
	   }
	 catch (java.io.UnsupportedEncodingException e)
	   {
	     throw new VirtuosoException ("charset not supported in getSubString : " + e.getMessage(), VirtuosoException.MISCERROR);
	   }
       }
*/
     else
       {
	 try
	   {
	     return new String(bytes, "8859_1");
	   }
	 catch (Exception e)
	   {
	     throw new VirtuosoException ("8859-1 not supported in getSubString", VirtuosoException.MISCERROR);
	   }
       }
   }

   /**
    * Returns the number of bytes in the BLOB value
    * designated by this Blob object.
    *
    * @return long The length of the BLOB in bytes.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   public long length() throws VirtuosoException
   {
      return length;
   }

   /**
    * Retrieves the <code>BLOB</code> designated by this
    * <code>Blob</code> instance as a stream.
    *
    * @return a stream containing the <code>BLOB</code> data
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   public InputStream getBinaryStream() throws VirtuosoException
   {
      if(is != null)
         return is;
      if(buffer != null)
         return new ByteArrayInputStream(buffer);
      return new VirtuosoBlobStream(this);
   }

   /**
    * Gets the <code>Clob</code> contents as a Unicode stream.
    *
    * @return a Unicode stream containing the <code>CLOB</code> data
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   public Reader getCharacterStream() throws VirtuosoException
   {
      if(rd != null)
         return rd;
      if(buffer != null)
         return new StringReader(new String(buffer));
      try
	{
	  switch (dtp)
	    {
	      case VirtuosoTypes.DV_BLOB_WIDE:
		  return new InputStreamReader (new VirtuosoBlobStream (this), "UTF8");
	      case VirtuosoTypes.DV_BLOB_BIN:
		  return new InputStreamReader (new VirtuosoBlobStream (this), "8859_1");
	      default:
		  return new InputStreamReader (new VirtuosoBlobStream (this),
		      connection.charset != null ? connection.charset : "8859_1");
	    }
	}
      catch (java.io.UnsupportedEncodingException e)
	{
	  throw new VirtuosoException ("Unsupported charset encoding : " + e.getMessage(),
	      VirtuosoException.CASTERROR);
	}
   }

   /**
    * Gets the <code>CLOB</code> value designated by this <code>Clob</code>
    * object as a stream of Ascii bytes.
    *
    * @return an ascii stream containing the <code>CLOB</code> data
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   public InputStream getAsciiStream() throws VirtuosoException
   {
      if(is != null)
         return is;
      if(buffer != null)
         return new ByteArrayInputStream(buffer);
      return new VirtuosoClobStream(this);
   }

   /**
    * Determines the byte position at which the specified byte
    * <code>pattern</code> begins within the <code>BLOB</code>
    * value that this <code>Blob</code> object represents.  The
    * search for <code>pattern</code. begins at position
    * <code>start</code>.
    *
    * @param pattern the byte array for which to search
    * @param start the position at which to begin searching; the
    * first position is 1
    * @return the position at which the pattern appears, else -1.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   public long position(byte pattern[], long start) throws VirtuosoException
   {
      if(!request)
      {
         if(start>=buffer.length || start+pattern.length>=buffer.length)
	   return -1;
         boolean found = true; int i;
         for(i = (int)start-1;i < buffer.length && found;i++)
           found &= (buffer[i] == pattern[i]);
         if(found)
           return i;
	 return -1;
      }

      try
      {
         // First get an InputStream
         VirtuosoBlobStream is = (VirtuosoBlobStream)this.getBinaryStream();
         is.skip(start - 1);
         byte[] _array = new byte[pattern.length];
         while(is.available() > _array.length)
         {
            if(is.read(_array,0,_array.length) == -1)
               throw new VirtuosoException("End of stream reached.",VirtuosoException.EOF);
            boolean found = true;
            for(int i = 0;i < _array.length && found;i++)
               found &= (_array[i] == pattern[i]);
            if(found)
               return is.pos;
         }
         return -1L;
      }
      catch(IOException e)
      {
         throw new VirtuosoException("I/O error occurred : " + e.getMessage(),VirtuosoException.IOERROR);
      }
   }

#if JDK_VER >= 12
   /**
    * Determines the byte position in the <code>BLOB</code> value
    * designated by this <code>Blob</code> object at which
    * <code>pattern</code> begins.  The search begins at position
    * <code>start</code>.
    *
    * @param pattern the <code>Blob</code> object designating
    * the <code>BLOB</code> value for which to search
    * @param start the position in the <code>BLOB</code> value
    * at which to begin searching; the first position is 1
    * @return the position at which the pattern begins, else -1
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   public long position(Blob pattern, long start) throws VirtuosoException
   {
      try
      {
         // First get an InputStream
         VirtuosoBlobStream is = (VirtuosoBlobStream)pattern.getBinaryStream();
         is.skip(start - 1);
         byte[] _array = new byte[VirtuosoTypes.PAGELEN];
         while(is.available() > VirtuosoTypes.PAGELEN)
         {
            if(is.read(_array,0,VirtuosoTypes.PAGELEN) == -1)
               throw new VirtuosoException("End of stream reached.",VirtuosoException.EOF);
            long posi = position(_array,start += VirtuosoTypes.PAGELEN);
            if(posi != -1)
               return posi;
         }
         return -1L;
      }
      catch(IOException e)
      {
         throw new VirtuosoException("I/O error occurred : " + e.getMessage(),VirtuosoException.IOERROR);
      }
      catch(SQLException e)
      {
         throw new VirtuosoException("SQL error occurred : " + e.getMessage(),VirtuosoException.SQLERROR);
      }
   }
#endif

   /**
    * Determines the character position at which the specified substring
    * <code>searchstr</code> appears in the <code>CLOB</code>.  The search
    * begins at position <code>start</code>.
    *
    * @param searchstr the substring for which to search
    * @param start the position at which to begin searching; the first position
    * is 1
    * @return the position at which the substring appears, else -1; the first
    * position is 1
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   public long position(String searchstr, long start) throws VirtuosoException
   {
      try
      {
         // First get an InputStream
         VirtuosoClobStream is = (VirtuosoClobStream)this.getAsciiStream();
         is.skip(start - 1);
         byte[] _array = new byte[searchstr.length()];
         while(is.available() > _array.length)
         {
            if(is.read(_array,0,_array.length) == -1)
               throw new VirtuosoException("End of stream reached.",VirtuosoException.EOF);
            if(searchstr.equals(new String(_array)))
               return is.pos;
         }
         return -1L;
      }
      catch(IOException e)
      {
         throw new VirtuosoException("I/O error occurred : " + e.getMessage(),VirtuosoException.IOERROR);
      }
   }

#if JDK_VER >= 12
   /**
    * Determines the character position at which the specified
    * <code>Clob</code> object <code>searchstr</code> appears in this
    * <code>Clob</code> object.  The search begins at position
    * <code>start</code>.
    *
    * @param searchstr the <code>Clob</code> object for which to search
    * @param start the position at which to begin searching; the first
    * position is 1
    * @return the position at which the <code>Clob</code> object appears,
    * else -1; the first position is 1
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   public long position(Clob searchstr, long start) throws VirtuosoException
   {
      try
      {
         // First get an InputStream
         VirtuosoClobStream is = (VirtuosoClobStream)searchstr.getAsciiStream();
         is.skip(start - 1);
         byte[] _array = new byte[VirtuosoTypes.PAGELEN];
         while(is.available() > VirtuosoTypes.PAGELEN)
         {
            if(is.read(_array,0,VirtuosoTypes.PAGELEN) == -1)
               throw new VirtuosoException("End of stream reached.",VirtuosoException.EOF);
            long posi = position(new String(_array),start += VirtuosoTypes.PAGELEN);
            if(posi != -1)
               return posi;
         }
         return -1L;
      }
      catch(IOException e)
      {
         throw new VirtuosoException("I/O error occurred : " + e.getMessage(),VirtuosoException.IOERROR);
      }
      catch(SQLException e)
      {
         throw new VirtuosoException("SQL error occurred : " + e.getMessage(),VirtuosoException.SQLERROR);
      }
   }
#endif

   // --------------------------- Object ------------------------------
   /**
    * Returns a hash code value for the object.
    *
    * @return int	The hash code value.
    */
   public int hashCode()
   {
      return (int)bh_page;
   }

   /**
    * Returns th String of the object.
    *
    * @return String The string value.
    */
   public String toString()
   {
      return "Blob " + length + "b";
/*
      try
      {
	//System.err.println ("Blob toString() called len=" + length + " dtp =" + dtp);
         String ret = getSubString(1,(int)length);
	 if (dtp != VirtuosoTypes.DV_BLOB_WIDE_HANDLE && connection.charset != null)
	   ret = connection.uncharsetBytes (ret);
	//System.err.println ("Blob toString() called ret len=" + ret.length() + " ret(0) =" + ((int)ret.charAt(1)));
	return ret;
      }
      catch(Exception e)
      {
         return null;
      }
*/
   }

#if JDK_VER >= 14
   /* JDK 1.4 functions */

   public int setString(long pos, String str, int offset, int len) throws SQLException
     {
       throw new VirtuosoException ("Not implemented function", VirtuosoException.NOTIMPLEMENTED);
     }

   public int setString(long pos, String str) throws SQLException
     {
       return setString (pos, str, 0, str.length());
     }

   public OutputStream setAsciiStream(long pos) throws SQLException
     {
       throw new VirtuosoException ("Not implemented function", VirtuosoException.NOTIMPLEMENTED);
     }

   public Writer setCharacterStream(long pos) throws SQLException
     {
       throw new VirtuosoException ("Not implemented function", VirtuosoException.NOTIMPLEMENTED);
     }

   public void truncate(long len) throws SQLException
     {
       throw new VirtuosoException ("Not implemented function", VirtuosoException.NOTIMPLEMENTED);
     }

   public int setBytes(long pos, byte[] bytes) throws SQLException
     {
       return setBytes (pos, bytes, 0, bytes.length);
     }

   public int setBytes(long pos, byte[] bytes, int offset, int len) throws SQLException
     {
       throw new VirtuosoException ("Not implemented function", VirtuosoException.NOTIMPLEMENTED);
     }

   public OutputStream setBinaryStream(long pos) throws SQLException
     {
       throw new VirtuosoException ("Not implemented function", VirtuosoException.NOTIMPLEMENTED);
     }

#endif


    /**
     * Returns an <code>InputStream</code> object that contains a partial <code>Blob</code> value,
     * starting  with the byte specified by pos, which is length bytes in length.
     *
     * @param pos the offset to the first byte of the partial value to be retrieved.
     *  The first byte in the <code>Blob</code> is at position 1
     * @param length the length in bytes of the partial value to be retrieved
     * @return <code>InputStream</code> through which the partial <code>Blob</code> value can be read.
     * @throws SQLException if pos is less than 1 or if pos is greater than the number of bytes
     * in the <code>Blob</code> or if pos + length is greater than the number of bytes
     * in the <code>Blob</code>
     *
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
   public InputStream getBinaryStream(long pos, long len) throws SQLException
   {
       throw new VirtuosoException ("Not implemented function", VirtuosoException.NOTIMPLEMENTED);
   }

    /**
     * This method frees the <code>Blob</code> object and releases the resources that
     * it holds. The object is invalid once the <code>free</code>
     * method is called.
     *<p>
     * After <code>free</code> has been called, any attempt to invoke a
     * method other than <code>free</code> will result in a <code>SQLException</code>
     * being thrown.  If <code>free</code> is called multiple times, the subsequent
     * calls to <code>free</code> are treated as a no-op.
     *<p>
     *
     * @throws SQLException if an error occurs releasing
     * the Blob's resources
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
   public void free() throws SQLException
   {
       throw new VirtuosoException ("Not implemented function", VirtuosoException.NOTIMPLEMENTED);
   }

   public Reader getCharacterStream(long pos, long len) throws SQLException {
       throw new VirtuosoException ("Not implemented function", VirtuosoException.NOTIMPLEMENTED);
   }


}
