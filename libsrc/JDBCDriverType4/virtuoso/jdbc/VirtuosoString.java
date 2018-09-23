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

package virtuoso.jdbc4;

import java.lang.*;
import java.io.*;

/**
 * The VString class is an implementation DV_WIDE strings.
 *
 * @author Boris Muratshin
 */
public final class VirtuosoString
{
   // The string itself
   private byte[] bytes = null;
   // the dv code as it will be serialized in future request
   private int dv = VirtuosoTypes.DV_SHORT_STRING;

    /**
     * Initializes a newly created <code>VirtuosoString</code> object.
     *
     * @param   s a<code>Object</code>.
     * @param   iswide a<code>boolean</code>.
     */
   public VirtuosoString (Object obj, String enc, int dv, int length)
   {
     bytesFromObject(obj, enc, dv, length);
   }
    /**
     * Returns a length of wrapped string
     *
     */
   public int length ()
   {
     return bytes.length;
   }
    /**
     * Returns a dv code of the wrapped string
     *
     */
   public int getDV ()
   {
     return dv;
   }

    /**
     * Calculates a dv code of the  wrapped string
     *
     * @param   iswide a<code>boolean</code>.
     */
   protected int setDV (boolean iswide)
   {
     if (iswide)
       dv = (bytes.length>255)?
        VirtuosoTypes.DV_LONG_WIDE:VirtuosoTypes.DV_WIDE;
     else
       dv = (bytes.length>255)?
        VirtuosoTypes.DV_LONG_STRING:VirtuosoTypes.DV_SHORT_STRING;
     return dv;
   }
    /**
     * Returns the wrapped string itself
     *
     * @param   s a<code>String</code>.
     */
   public byte[] getValue ()
   {
     return bytes;
   }

    /**
     * Initializes a newly created <code>VirtuosoString</code> object.
     *
     * @param   s a<code>Object</code>.
     * @param   iswide a<code>boolean</code>.
     */
   protected byte[]  bytesFromObject (Object obj, String enc, int _dv, int length)
   {
     boolean iswide = isWide(_dv);
     StringBuffer sb = new StringBuffer ();
     String s = "";
     int c;
     if (obj instanceof Reader)
     {
       Reader r = (Reader)obj;
       try {for (;-1!=(c=r.read());)sb.append((char)c);} catch (IOException e){}
       s = sb.toString();
       try {
         bytes = s.getBytes(iswide?"UTF8":enc);
       } catch (UnsupportedEncodingException e)
       {
         try { bytes = s.getBytes("8859_1");} catch (UnsupportedEncodingException ee){};
       };
       setDV (iswide);
     }
     else if (obj instanceof InputStream)
     {
       InputStream r = (InputStream)obj;
       bytes = new byte[length];
       try {for (c=0;c<length;c++) bytes[c]=(byte)r.read();} catch (IOException e){}
       if (iswide)
         {
           s = new String(bytes);
           try { bytes = s.getBytes("UTF8");} catch (UnsupportedEncodingException ee){};
         }
       setDV (iswide);
     }
     else if (obj instanceof String)
     {
       s = (String)obj;
       try {
         bytes = s.getBytes(iswide?"UTF8":enc);
       } catch (UnsupportedEncodingException e)
       {
         try { bytes = s.getBytes("8859_1");} catch (UnsupportedEncodingException ee){};
       };
       setDV (iswide);
     }
     else if (obj instanceof byte[])
     {
       if (VirtuosoTypes.DV_LONG_BIN == _dv || VirtuosoTypes.DV_BIN == _dv)
         {
           int l = ((byte[])obj).length;
           bytes = new byte[l];
           System.arraycopy((byte[])obj, 0, bytes, 0, l);
           dv = (l>255)? VirtuosoTypes.DV_LONG_BIN:VirtuosoTypes.DV_BIN;
         }
       else
         {
           try {
             s = new String((byte[])obj, enc);
             bytes = s.getBytes(iswide?"UTF8":enc);
           } catch (UnsupportedEncodingException e)
           {
             try { bytes = s.getBytes("8859_1");} catch (UnsupportedEncodingException ee){};
           };
           setDV (iswide);
         }
     }
     return bytes;
   }

   /**
    * Returns boolean which means if the parameter corresponding to the parameterIndex
    * was pre-compiled and found as wide
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    */
   public static boolean isWide(int dv)
   {
     boolean iswide;
     iswide = (VirtuosoTypes.DV_WIDE == dv ||
                            VirtuosoTypes.DV_BLOB_WIDE == dv ||
                            VirtuosoTypes.DV_LONG_WIDE == dv ||
                            VirtuosoTypes.DV_BLOB_WIDE_HANDLE == dv)?true:false;
     return iswide;
   }
   /**
    * Returns boolean which means if the parameter corresponding to the parameterIndex
    * was pre-compiled and found as blob(clob)
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    */
   public static boolean isBlob(int dv)
   {
     boolean isblob;
     isblob = (        VirtuosoTypes.DV_BLOB_HANDLE == dv ||
                            VirtuosoTypes.DV_BLOB == dv ||
                            VirtuosoTypes.DV_BLOB_BIN == dv ||
                            VirtuosoTypes.DV_BLOB_WIDE == dv ||
                            VirtuosoTypes.DV_BLOB_XPER == dv ||
                            VirtuosoTypes.DV_BLOB_XPER_HANDLE == dv ||
                            VirtuosoTypes.DV_BLOB_WIDE_HANDLE == dv)?true:false;
     return isblob;
   }
   /**
    * Returns boolean which means if the parameter corresponding to the parameterIndex
    * was pre-compiled and found as varchar
    *
    * @param parameterIndex the first parameter is 1, the second is 2, ...
    */
   public static boolean isString(int dv)
   {
     boolean isstr;
     isstr = (        VirtuosoTypes.DV_C_STRING == dv ||
                            VirtuosoTypes.DV_BIN == dv ||
                            VirtuosoTypes.DV_LONG_BIN == dv ||
                            VirtuosoTypes.DV_LONG_STRING == dv ||
                            VirtuosoTypes.DV_SHORT_STRING == dv ||
                            VirtuosoTypes.DV_WIDE == dv)?true:false;
     return isstr;
   }
}

