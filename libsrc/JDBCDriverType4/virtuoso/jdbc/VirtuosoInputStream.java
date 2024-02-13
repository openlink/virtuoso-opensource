/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2024 OpenLink Software
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

package virtuoso.jdbc4;

import java.io.*;
import java.net.*;
import java.sql.*;
import java.util.*;
import java.math.*;
import openlink.util.*;

/**
 * The VirtuosoInputStream is used to deserialize data during
 * an answer message between Virtuoso DBMS and the JDBC driver .
 *
 * @version 1.0 (JDBC API 2.0 implementation)
 */
class VirtuosoInputStream extends BufferedInputStream
{
   // The connection attached to this stream
   private VirtuosoConnection connection;


    public int read () throws IOException
      {
	int c = super.read();
	if (c == -1)
	  throw new IOException ("Connection to the server lost");
	return c;
      }

    public int read(byte[] b, int off, int len) throws IOException
      {
	int c = super.read (b, off, len);
	if (c == -1)
	  throw new IOException ("Connection to the server lost");
	return c;
      }


    private static final int DefaultBufferSize = 2048;
   /**
    * Constructs a VirtuosoInputStream using a InputStream from
    * a socket connecting the driver to the database.
    *
    * @param connection The connection attached to this stream.
    * @param input   The InputStream representing data from the database.
    * @exception java.io.IOException   An error occurred creating a
    * BufferedInputStream for the InputStream
    * @see java.io.BufferInputStream
    */
   VirtuosoInputStream(VirtuosoConnection connection, InputStream input) throws IOException
   {
      this (connection,input,DefaultBufferSize);
   }

   /**
    * Constructs a VirtuosoInputStream using a InputStream from
    * a socket connecting the driver to the database with a specific
    * buffer size.
    *
    * @param connection The connection attached to this stream.
    * @param input   The InputStream representing data from the database.
    * @param size The BufferedInputStream buffer size.
    * @exception java.io.IOException   An error occurred creating a
    * BufferedInputStream for the InputStream
    * @see java.io.BufferInputStream
    */
   VirtuosoInputStream(VirtuosoConnection connection, InputStream input, int size) throws IOException
   {
     super (input, size);
      this.connection = connection;
   }

   /**
    * Constructs a VirtuosoInputStream using from the Socket
    * connecting the driver to the database.
    *
    * @param connection The connection attached to this stream.
    * @param input   The Socket representing data from the database.
    * @exception java.io.IOException   An error occurred creating a
    * BufferedInputStream for the InputStream
    * @see java.net.Socket
    */
   VirtuosoInputStream(VirtuosoConnection connection, Socket input) throws IOException
   {
      this (connection,input.getInputStream());
   }

   /**
    * Constructs a VirtuosoInputStream using from the Socket
    * connecting the driver to the database with a specific size
    * buffer.
    *
    * @param connection The connection attached to this stream.
    * @param input   The Socket representing data from the database.
    * @param size The buffer size.
    * @exception java.io.IOException   An error occurred creating a
    * BufferedInputStream for the InputStream
    * @see java.net.Socket
    */
   VirtuosoInputStream(VirtuosoConnection connection, Socket input, int size) throws IOException
   {
      this (connection,input.getInputStream(),size);
   }

   /**
    * Check if the input stream is closed.
    *
    * @return true if the connection is closed, false if it is still open.
    */
   protected boolean isClosed()
   {
      return (in == null);
   }

   /**
    * Method uses to deserialize an object from a DV format.
    *
    * @return Object	The object read from the stream.
    * @exception	java.io.IOException  An IO error occurred on the stream.
    * @exception  java.io.EOFException An end of stream is occurred
    * (read incomplete).
    * @exception  virtuoso.jdbc4.VirtuosoException   An internal error occurred.
    */
   protected Object read_object() throws IOException, EOFException, VirtuosoException
   {
     // Read and treat the tag
     int tag = read();
     Object res;
     try
       {
         switch(tag)
           {
             case VirtuosoTypes.DV_NULL:
                   {
                     //System.out.println("DV_NULL");
                     return Short.valueOf((short)0); //null; because off absence of TAG_BOX in O12
                   }
             case VirtuosoTypes.DV_DB_NULL:
                   {
                     //System.out.println("DV_DB_NULL");
                     return null;
                   }
             case VirtuosoTypes.DV_ARRAY_OF_POINTER:
             case VirtuosoTypes.DV_LIST_OF_POINTER:
                   {
                     //System.out.println("DV_ARRAY_OF_POINTER");
                     int n = readint();
                     Object[] array = new Object[(int)n];
                     for(int i = 0;i < n;i++)
                       array[i] = read_object();
		     res = new openlink.util.Vector(array);
                     //System.out.print("DV_ARRAY_OF_POINTER: ");
		     //System.out.println (res.toString());
                     return res;
                   }
             case VirtuosoTypes.DV_ARRAY_OF_LONG:
                   {
                     //System.out.println("DV_ARRAY_OF_LONG");
                     int n = readint();
                     Object[] array = new Object[(int)n];
                     for(int i = 0;i < n;i++)
                       array[i] = Long.valueOf(readlongint());
                     res = new VectorOfLong(array);
                     //System.out.print("DV_ARRAY_OF_LONG");
		     //System.out.println (res.toString());
                     return res;
                   }
             case VirtuosoTypes.DV_ARRAY_OF_LONG_PACKED:
                   {
                     // ???? Perhaps a VectorOfLongPacked class to design ????
                     //System.out.println("DV_ARRAY_OF_LONG_PACKED");
                     int n = readint();
                     Object[] array = new Object[(int)n];
                     for(int i = 0;i < n;i++)
                       array[i] = Long.valueOf(readlongint());
                     res = new VectorOfLong(array);
                     //System.out.print("DV_ARRAY_OF_LONG_PACKED: ");
		     //System.out.println (res.toString());
                     return res;
                   }
             case VirtuosoTypes.DV_ARRAY_OF_DOUBLE:
                   {
                     //System.out.println("DV_ARRAY_OF_DOUBLE");
                     int n = readint();
                     Object[] array = new Object[(int)n];
                     for(int i = 0;i < n;i++)
                       array[i] = Double.valueOf(readdouble());
                     res = new VectorOfDouble(array);
                     //System.out.print("DV_ARRAY_OF_DOUBLE: ");
		     //System.out.println (res.toString());
                     return res;
                   }
             case VirtuosoTypes.DV_ARRAY_OF_FLOAT:
                   {
                     //System.out.println("DV_ARRAY_OF_FLOAT");
                     int n = readint();
                     Object[] array = new Object[(int)n];
                     for(int i = 0;i < n;i++)
                       array[i] = Float.valueOf(readfloat());
                     res = new VectorOfFloat(array);
                     //System.out.print("DV_ARRAY_OF_FLOAT: ");
		     //System.out.println (res.toString());
                     return res;
                   }
             case VirtuosoTypes.DV_LONG_WIDE:
                   {
                     //System.out.println("DV_LONG_WIDE");
                     int n = readlongint();
                     byte[] array = new byte[(int)n];
                     for(int i = read(array,0,(int)n) ; i != n ; i+=read(array,i,(int)n-i));
                     return convByte2UTF(array);
                     //System.out.print("DV_LONG_WIDE: ");
		     //System.out.println (res.toString());
                     //return res;
                   }

             case VirtuosoTypes.DV_WIDE:
                   {
                     //System.out.println("DV_WIDE");
                     int n = readshortint();
                     byte[] array = new byte[n];
                     for(int i = read(array,0,(int)n) ; i != n ; i+=read(array,i,(int)n-i));
		     //for (int i = 0; i < array.length; i++)
		     //  if (array[i] > 0)
			// System.err.print (array[i] + " ");
		      // else
			// System.err.print ((256 + array[i]) + " ");
		     //System.err.println ();
		     return convByte2UTF(array);
		     //System.err.println ("UTF16 len=" + ((String)res).length());
		     //for (int i = 0; i < ((String)res).length(); i++)
		     //  System.err.print (((int) ((String)res).charAt(i)) + " ");
		     //System.err.println ();
                     //System.out.print("DV_WIDE: ");
		     //System.out.println (res.toString());
                     //return res;
                   }

             case VirtuosoTypes.DV_C_STRING:
             case VirtuosoTypes.DV_STRING:
             case VirtuosoTypes.DV_LONG_CONT_STRING:
                   {
                     //System.out.println("DV_LONG_STRING ");
                     int n = readlongint();
                     byte[] array = new byte[(int)n];
                     for(int i = read(array,0,(int)n) ; i != n ; i+=read(array,i,(int)n-i));
		     if (connection.charset_utf8)
		         return convByte2UTF(array);
		     else
		         return convByte2Ascii(array);
                     //System.out.print("DV_LONG_STRING: ");
		     //System.out.println (res.toString());
                     //return res;
                   }
	     case VirtuosoTypes.DV_BOX_FLAGS:
		   {
                     int flags = readlongint();
		     Object str = read_object ();
                     res = new VirtuosoExtendedString ((String) str, flags);
                     //System.out.print("DV_BOX_FLAGS: ");
		     //System.out.println (res.toString());
                     return res;
		   }
             case VirtuosoTypes.DV_LONG_BIN:
                   {
		     //System.out.println("reading DV_LONG_BIN");
                     int n = readlongint();
                     byte[] array = new byte[(int)n];
                     for(int i = read(array,0,(int)n) ; i != n ; i+=read(array,i,(int)n-i));
		     //System.out.println("reading DV_LONG_BIN done");
                     return array;
                   }
             case VirtuosoTypes.DV_C_SHORT:
             case VirtuosoTypes.DV_SHORT_STRING_SERIAL:
             case VirtuosoTypes.DV_SHORT_CONT_STRING:
                   {
                     //System.out.println("DV_SHORT_STRING_SERIAL");
                     int n = readshortint();
                     byte[] array = new byte[n];
                     for(int i = read(array,0,(int)n) ; i != n ; i+=read(array,i,(int)n-i));
		     if (connection.charset_utf8)
		         return convByte2UTF(array);
		     else
		         return convByte2Ascii(array);
                     //System.out.print("DV_SHORT_STRING_SERIAL: " + res.toString());
		     //System.out.println (res.toString());
                     //return res;
                   }

             case VirtuosoTypes.DV_BIN:
                   {
		     //System.out.println("reading DV_BIN");
                     int n = readshortint();
                     byte[] array = new byte[n];
                     for(int i = read(array,0,(int)n) ; i != n ; i+=read(array,i,(int)n-i));
		     //System.out.println("reading DV_BIN done");
                     return array;
                   }

             case VirtuosoTypes.DV_SINGLE_FLOAT:
                   {
                     //System.out.println("DV_SINGLE_FLOAT");
                     res = Float.valueOf(readfloat());
                     //System.out.print("DV_SINGLE_FLOAT: ");
		     //System.out.println (res.toString());
                     return res;
                   }
             case VirtuosoTypes.DV_DOUBLE_FLOAT:
                   {
                     //System.out.println("DV_DOUBLE_FLOAT");
                     res = Double.valueOf(readdouble());
                     //System.out.print("DV_DOUBLE_FLOAT: ");
		     //System.out.println (res.toString());
                     return res;
                   }
             case VirtuosoTypes.DV_SHORT_INT:
                   {
                     //System.out.println("DV_SHORT_INT");
		     int ret = readshortint();
		     if (ret > 127)
		       ret = ret - 256;
                     res = Short.valueOf((short)ret);
                     //System.out.print("DV_SHORT_INT: ");
		     //System.out.println (res.toString());
                     return res;
                   }
             case VirtuosoTypes.DV_LONG_INT:
                   {
                     //System.out.println("DV_LONG_INT");
                     res = Integer.valueOf(readlongint());
                     //System.out.print("DV_LONG_INT: ");
		     //System.out.println (res.toString());
                     return res;
                   }
             case VirtuosoTypes.DV_DATETIME:
             case VirtuosoTypes.DV_TIMESTAMP_OBJ:
             case VirtuosoTypes.DV_TIMESTAMP:
             case VirtuosoTypes.DV_TIME:
             case VirtuosoTypes.DV_DATE:
                   {
                     //System.out.println("DV_DATE");
                     res = readDate(tag);
                     //System.out.print("DV_DATE: ");
		     //System.out.println (res.toString());
                     return res;
                   }
             case VirtuosoTypes.DV_BLOB_HANDLE:
             case VirtuosoTypes.DV_BLOB_WIDE_HANDLE:
                   {
                     //System.out.println("DV_BLOB_HANDLE dtp=" + tag);
                     res = new VirtuosoBlob(connection,readlongint(),readlongint(),readlongint(),readlongint(),readlongint(),readlongint(), readlongint(), read_object(), tag);
                     //System.out.print("DV_BLOB_HANDLE: ");
		     //System.out.println (res.toString());
                     return res;
                   }
             case VirtuosoTypes.DV_NUMERIC:
                   {
                     //System.out.println("DV_NUMERIC");
                     res = readNumeric();
                     //System.out.print("DV_NUMERIC: ");
		     //System.out.println (res.toString());
                     /*try
                       {
                         java.math.BigDecimal dec = (java.math.BigDecimal) res;
                         java.math.BigInteger bi = dec.setScale (0, java.math.BigDecimal.ROUND_UNNECESSARY).unscaledValue();
                         return bi;
                       }
                     catch (ArithmeticException e) {};*/
                     return res;
                   }
	     case VirtuosoTypes.DV_OBJECT:
		   {
                     //System.out.println("DV_NUMERIC");
		     res = readObject();
                     //System.out.print("DV_NUMERIC: ");
		     //System.out.println (res.toString());
		     return res;
		   }
             case VirtuosoTypes.DV_STRING_SESSION:
                   {
                     //System.out.println("DV_LONG_STRING ");
		     int flags = read();
		     ByteArrayOutputStream os = new ByteArrayOutputStream ();
		     do
		       {
			 int part_tag = read ();
			 if (part_tag != VirtuosoTypes.DV_STRING &&
				 part_tag != VirtuosoTypes.DV_SHORT_STRING_SERIAL)
			   {
			     throw new VirtuosoException (
				     "Invalid data (tag=" + part_tag + ") in deserializing a string session",
				     "42000",
				     VirtuosoException.BADTAG);
			   }
			 int n = (part_tag == VirtuosoTypes.DV_STRING) ? readlongint() : read ();
			 if (n > 0)
			   {
			     byte[] array = new byte[(int)n];
			     for(int i = read(array,0,(int)n) ; i != n ; i+=read(array,i,(int)n-i));
			     os.write (array, 0, n);
			   }
			 else
			   break;
		       }
		     while (true);
                     res = os.toString ((flags & 0x1) != 0 ? "UTF-8" : "8859_1");
                     //System.out.print("DV_STRING_SESSION: ");
		     //System.out.println (res.toString());
                     return res;
                   }
             case VirtuosoTypes.DV_IRI_ID:
                   {
                     res = Integer.valueOf(readlongint());
                     return res;
                   }
             case VirtuosoTypes.DV_IRI_ID_8:
             case VirtuosoTypes.DV_INT64:
                   {
                     res = Long.valueOf(readlong());
                     return res;
                   }
	     case VirtuosoTypes.DV_RDF:
		   {
		     res = readRdfBox ();
                     return res;
                   }
             default:
                 // Problem !
                 //System.out.println("Tag not defined : "+tag);
                 throw new VirtuosoException("Tag " + tag + " not defined.",VirtuosoException.BADTAG);
           }
       }
     catch (ClassCastException e)
       {
         if (VirtuosoFuture.rpc_log != null)
           {
                 VirtuosoFuture.rpc_log.println ("  **(conn " + connection.hashCode() + ") **** runtime " +
                     e.getClass().getName() + " encountered while reading tag " + tag);
                 e.printStackTrace(VirtuosoFuture.rpc_log);
           }
           throw new VirtuosoException(e.getClass().getName() + ":" + e.getMessage(),VirtuosoException.IOERROR);

       }
   }

   private final String convByte2UTF(byte[] data) throws IOException {
        int utflen = data.length;
        char[] c_arr = new char[utflen];
        char bad_char = '?';

        int c, c2, c3;
        int count = 0;
        int ch_count=0;

        while (count < utflen) {
            c = (int) data[count] & 0xff;
            if (c > 127) break;
            count++;
            c_arr[ch_count++]=(char)c;
        }

        while (count < utflen) {
            c = (int) data[count] & 0xff;
            switch (c >> 4) {
                case 0: case 1: case 2: case 3: case 4: case 5: case 6: case 7:
                    /* 0xxxxxxx*/
                    count++;
                    c_arr[ch_count++]=(char)c;
                    break;
                case 12: case 13:
                    /* 110x xxxx   10xx xxxx*/
                    count += 2;
                    if (count > utflen) {
                        c_arr[ch_count++]=(char)c;
                    } else {
                        c2 = (int) data[count-1];

                        if ((c2 & 0xC0) != 0x80)
                          c_arr[ch_count++] = bad_char;
                        else
                          c_arr[ch_count++] = (char)(((c & 0x1F) << 6) | (c2 & 0x3F));
                    }
                    break;
                case 14:
                    /* 1110 xxxx  10xx xxxx  10xx xxxx */
                    count += 3;
                    if (count > utflen) {
                        c_arr[ch_count++]=(char)c;
                    } else {
                        c2 = (int) data[count-2];
                        c3 = (int) data[count-1];

                        if (((c2 & 0xC0) != 0x80) || ((c3 & 0xC0) != 0x80))
                          c_arr[ch_count++] = bad_char;
                        else
                          c_arr[ch_count++] = (char)(((c & 0x0F) << 12) |
                                                    ((c2 & 0x3F) << 6)  |
                                                    ((c3 & 0x3F) << 0));
                    }
                    break;
                default:
                    /* 10xx xxxx,  1111 xxxx */
                    count++;
                    c_arr[ch_count++] = bad_char;
            }
        }
        // The number of chars produced may be less than utflen
        return new String(c_arr, 0, ch_count);
    }


   private final String convByte2Ascii(byte[] data) throws IOException {
        int len = data.length;
        char[] c_arr = new char[len];

        for(int i=0; i < len; i++)
          c_arr[i] = (char)(data[i] & 0xff);

        return new String(c_arr, 0, len);
    }


   /**
    * Method to read an int value depending DV_xxx_INT type.
    *
    * @return int	Value read.
    * @exception	java.io.IOException  An IO error occurred on the stream.
    */
   private int readint() throws IOException
   {
      return (read() == VirtuosoTypes.DV_SHORT_INT) ? readshortint() : readlongint();
   }

   /**
    * Method to read a short int value depending DV_SHORT_INT type.
    *
    * @return int	Value read.
    * @exception	java.io.IOException  An IO error occurred on the stream.
    */
   private int readshortint() throws IOException
   {
      return read();
   }

   private short readshort() throws IOException
   {
      int retVal;

      retVal = ((int) read() & 0xFF) << 8;
      return (short)(retVal | ((int) read() & 0xFF));
   }

   /**
    * Method to read a long int value depending DV_LONG_INT type.
    *
    * @return int	Value read.
    * @exception	java.io.IOException  An IO error occurred on the stream.
    */
   private int readlongint() throws IOException
   {
      int retVal;

      retVal  = ((int) read() & 0xFF) << 24;
      retVal |= ((int) read() & 0xFF) << 16;
      retVal |= ((int) read() & 0xFF) << 8;
      return retVal | ((int) read() & 0xFF);
   }

   private long readlong() throws IOException
   {
      long retVal;

      retVal  = ((long) read() & 0xFF) << 56;
      retVal |= ((long) read() & 0xFF) << 48;
      retVal |= ((long) read() & 0xFF) << 40;
      retVal |= ((long) read() & 0xFF) << 32;
      retVal |= ((long) read() & 0xFF) << 24;
      retVal |= ((long) read() & 0xFF) << 16;
      retVal |= ((long) read() & 0xFF) << 8;
      return retVal | ((long) read() & 0xFF);
   }

   /**
    * Method to read a float value depending DV_SINGLE_FLOAT type.
    *
    * @return float	Value read.
    * @exception	java.io.IOException  An IO error occurred on the stream.
    */
   private float readfloat() throws IOException
   {
      return Float.intBitsToFloat(readlongint());
   }

   /**
    * Method to read a double value depending DV_DOUBLE_FLOAT type.
    *
    * @return double	Value read.
    * @exception	java.io.IOException  An IO error occurred on the stream.
    */
   private double readdouble() throws IOException
   {
     return Double.longBitsToDouble (readlong());
   }

   /**
    * Method to read a numeric value depending DV_NUMERIC type.
    *
    * @return BigDecimal	Numeric value.
    * @exception	java.io.IOException	An IO error occurred on the stream.
    */
   private BigDecimal readNumeric() throws IOException, VirtuosoException
   {
      int n = readshortint(), i = 0;
      int len, scale, rp, ep;
      boolean isneg, isinvalid;
      byte array[] = new byte[n + 2];
      byte dp[] = new byte[n << 1];
      BigDecimal bd;

      if (array!=null && dp!=null)
      {
        array[0] = (byte)VirtuosoTypes.DV_NUMERIC;
	array[1] = (byte)n;
	for(int inx = read(array,2,n) ; inx != n ; inx+=read(array,inx + 2,n-inx));
      }
      else
        return null;

      /* Init the dp array with a zero value */
      dp[0] = (byte) '0';

      /* Get some evident informations */
      len = array[3] << 1;
      scale = (array[1] - array[3] - 2) << 1;
      isneg = ((array[2] & 0x1) == 0x1) ? true : false;
      isinvalid = ((array[2] & 0x18) == 0x18) ? true : false;

      /* Return already here if the value is not good */
      switch(array[2] & 0x18)
      {
        case 0x8:
            {
	      return new BigDecimal(Double.NaN);
            }
	case 0x10:
            {
               if(isneg)
                 return new BigDecimal(Double.NEGATIVE_INFINITY);
               return new BigDecimal(Double.POSITIVE_INFINITY);
            }
      };

      /* Get the real and exponent parts */
      rp = 4;
      ep = 2 + array[1];

      if ((array[2] & 0x04) == 0x04)
      {
        dp[i++] = (byte)((array[rp ++] & 0x0f) + '0');
	len --;
      }

      if ((array[2] & 0x02) == 0x02)
        scale --;

      while(rp < ep)
      {
        if (i == len)
	  dp[i++] = (byte) '.';
        dp[i++] = (byte)(((array[rp] >> 4) & 0x0f) + '0');
        if (i == len)
	  dp[i++] = (byte) '.';
	dp[i++] = (byte)((array[rp++] & 0x0f) + '0');
      }

      bd = new BigDecimal( ((isneg) ? "-" : "") + new String(dp, 0,
          (rp != 4) ? (i - (((array[2] & 0x02) == 0x02) ? 1 : 0)) : 1));
      return bd;
   }


   private VirtuosoRdfBox readRdfBox () throws IOException, VirtuosoException
   {
      int flags = read ();
      Object box = null;
      short type = VirtuosoRdfBox.RDF_BOX_DEFAULT_TYPE;
      short lang = VirtuosoRdfBox.RDF_BOX_DEFAULT_LANG;
      boolean is_complete = false;
      long ro_id = 0L;
      boolean id_only = false;
      VirtuosoRdfBox rb;

      //System.out.println ("flags:" + flags);
      if (0 != (flags & VirtuosoRdfBox.RBS_EXT_TYPE))
      {
        int ID_ONLY = VirtuosoRdfBox.RBS_HAS_LANG | VirtuosoRdfBox.RBS_HAS_TYPE;
        if ((flags & ID_ONLY) == ID_ONLY) {
            id_only = true;
        } else if ((flags & VirtuosoRdfBox.RBS_HAS_LANG)!=0){
            lang = readshort();
        } else {
            type = readshort();
        }

        if (0 != (flags & VirtuosoRdfBox.RBS_64))
            ro_id = readlong();
        else
            ro_id = readlongint();

        if (0 != (flags & VirtuosoRdfBox.RBS_COMPLETE)){
            is_complete = true;
            box = read_object ();
        }

      } else {

        if (0 != (flags & VirtuosoRdfBox.RBS_CHKSUM))
        {
	  throw new VirtuosoException ("Invalid rdf box received", "42000", VirtuosoException.MISCERROR);
        }

        if (0 != (flags & VirtuosoRdfBox.RBS_SKIP_DTP))
        {
	  int n = readshortint();
	  byte[] array = new byte[n];
	  for(int i = read(array,0,(int)n) ; i != n ; i+=read(array,i,(int)n-i));
	  if (connection.charset_utf8)
	      box = convByte2UTF(array);
	  else
	      box = convByte2Ascii(array);

        }
        else
          box = read_object ();

        if (0 != (flags & VirtuosoRdfBox.RBS_OUTLINED))
        {
	  if (0 != (flags & VirtuosoRdfBox.RBS_64))
	    ro_id = readlong();
	  else
	    ro_id = readlongint ();
        }

        if (0 != (flags & VirtuosoRdfBox.RBS_COMPLETE))
	  is_complete = true;

        if (0 != (flags & VirtuosoRdfBox.RBS_HAS_TYPE))
	  type = readshort ();
        else
	  type = VirtuosoRdfBox.RDF_BOX_DEFAULT_TYPE;

        if (0 != (flags & VirtuosoRdfBox.RBS_HAS_LANG))
	  lang = readshort ();
        else
	  lang = VirtuosoRdfBox.RDF_BOX_DEFAULT_LANG;
      }

      rb = new VirtuosoRdfBox(this.connection, box, is_complete, id_only, type, lang, ro_id);
      return rb;
   }

   private Object readObject() throws IOException, VirtuosoException
   {
     int obj_id = readlongint();
     Object obj = read_object ();
     if (obj instanceof String)
       {
	 try
	   {
	     java.io.ByteArrayInputStream bis = new ByteArrayInputStream (((String)obj).getBytes ("8859_1"));
	     ObjectInputStream ois = new ObjectInputStream (bis);
	     obj = ois.readObject();
	   }
	 catch (Exception e)
	   {
	     obj = null;
	   }
       }
     return obj;
   }

   /**
    * Method to read a date value depending of DV_DATE type.
    *
    * @param  tag      The tag to determine if it will be a date or a time.
    * @return Object   The date or a time.
    * @exception  java.io.IOException  An IO error occurred on the stream.
    */
   private Object readDate(int tag) throws IOException
   {
      java.util.Calendar cal_dat = new java.util.GregorianCalendar ();
      int d0 = read();
      int day = d0 << 16 | read() << 8 | read();
      int hour = read();
      int temp = read();
      int minute = temp >> 2;
      int second = (((temp & 0x3) << 4) | ((temp = read()) >> 4));
      int fraction = (((temp & 0xf) << 16) | (read() << 8) | read());
      int tz_bytes[] = new int[2], tz_interm;

      day = day | ((d0 & 0x80)!=0 ? 0xff000000 : 0);

      int tzless = hour >> 7;
      hour &= 0x1F;

      tz_bytes[0] = read();
      tz_bytes[1] = read();
      int tz = (((int)(tz_bytes[0] & 0x07)) << 8) | tz_bytes[1];
      int type = tz_bytes[0] >> 5;

      if ((tz_bytes[0] & 0x4) != 0)
        {
          tz_interm = tz_bytes[0] & 0x07;
	  tz_interm |= 0xF8;
        }
      else
        tz_interm = tz_bytes[0] & 0x03;

      tz = ((int)(tz_interm << 8)) | tz_bytes[1];

      if (tz > 32767)
	tz -= 65536;

      return new DateObject(day, hour, minute, second, fraction, tz, type);
   }

}
