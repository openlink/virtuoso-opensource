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

import java.io.*;
import java.sql.*;
import java.util.*;
import java.math.*;
import java.io.*;
import openlink.util.*;
import java.lang.reflect.Method;

/**
 * The VirtuosoRow class is designed to store and retrieve a row from the
 * result set.
 *
 * @version 1.0 (JDBC API 2.0 implementation)
 */
class VirtuosoRow
{
   // Content of each column in this row
   private openlink.util.Vector content;

   // Max number of columns in this row
   protected int maxCol;

   // The result set which contains this row
   private VirtuosoResultSet resultSet;

   /**
    * Construct a new VirtuosoRow class which stores the row's content.
    *
    * @param Vector  Content of the row.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    */
   VirtuosoRow(VirtuosoResultSet resultSet, openlink.util.Vector args) throws VirtuosoException
   {
      // Set the row and the column count
      //System.out.println ("new VirtuosoRow : ");
      //System.out.println (args);
      this.resultSet = resultSet;
      content = args;
      maxCol = resultSet.metaData.getColumnCount();
   }

   /**
    * Copy the content of the line into an array.
    */
   protected void getContent(Object anArray[])
   {
      for(int i = 0;i < anArray.length && i < maxCol;i++)
         anArray[i] = content.elementAt(i);
   }

   /**
    * Gets the value of a column in the row as a stream of
    * ASCII characters. The value can then be read in chunks from the
    * stream. This method is particularly
    * suitable for retrieving large LONGVARCHAR values.  The JDBC driver will
    * do any necessary conversion from the database format into ASCII.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return VirtuosoAsciiInputStream   A Java input stream that delivers the database column value.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getAsciiStream
    */
   protected InputStream getAsciiStream(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > maxCol)
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
      // Get the object in the corresponding column
      Object obj = content.elementAt(column - 1);
      // Return the buffer
      resultSet.wasNull((obj != null)?false:true);
      if(obj != null && obj instanceof VirtuosoBlob)
         return ((VirtuosoBlob)obj).getAsciiStream();
      try
        {
          if(obj != null && obj instanceof String)
            return new ByteArrayInputStream (((String)obj).getBytes ("8859_1"));
	}
      catch (java.io.UnsupportedEncodingException e)
        {
	  throw new VirtuosoException (e, VirtuosoException.CASTERROR);
	}
      if(obj != null && obj instanceof byte[])
         return new ByteArrayInputStream((byte[])obj);
      return null;
   }

   /**
    * Gets the value of a column in the current row as a stream of
    * uninterpreted bytes.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return ByteArrayInputStream   A Java input stream that delivers the database column value.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getBinaryStream
    */
   protected InputStream getBinaryStream(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > maxCol)
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
      // Get the object in the corresponding column
      Object obj = content.elementAt(column - 1);
      // Return the buffer
      resultSet.wasNull((obj != null)?false:true);
      if(obj != null && obj instanceof VirtuosoBlob)
         return ((VirtuosoBlob)obj).getBinaryStream();
      try
        {
          if(obj != null && obj instanceof String)
            return new ByteArrayInputStream (((String)obj).getBytes ("8859_1"));
	}
      catch (java.io.UnsupportedEncodingException e)
        {
	  throw new VirtuosoException (e, VirtuosoException.CASTERROR);
	}

      if(obj != null && obj instanceof byte[])
         return new ByteArrayInputStream((byte[])obj);
      return null;
   }

   /**
    * Gets the value of a column in the current row as a stream of
    * uninterpreted characters.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return CharArrayReader   A Java input stream that delivers the database column value.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getCharacterStream
    */
   protected Reader getCharacterStream(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > maxCol)
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
      // Get the object in the corresponding column
      Object obj = content.elementAt(column - 1);
      // Return the buffer
      resultSet.wasNull((obj != null)?false:true);
      if(obj != null && obj instanceof VirtuosoBlob)
         return ((VirtuosoBlob)obj).getCharacterStream();
      //if (obj != null)
//	System.out.println ("getString obj = " + obj.getClass().getName());
 //     else
//	System.out.println ("getString obj = null");
      if(obj != null && obj instanceof String)
	{
	  String str = (String)obj;
	  VirtuosoStatement stmt = (VirtuosoStatement)resultSet.getStatement();
	  if (stmt.connection.charset != null && obj instanceof String)
	    {
	      int dtp = resultSet.metaData.getColumnDtp (column);
	      switch (dtp)
		{
		  case VirtuosoTypes.DV_SHORT_STRING_SERIAL:
		  case VirtuosoTypes.DV_STRING:
		  case VirtuosoTypes.DV_STRICT_STRING:
		      try
			{
			  str = stmt.connection.uncharsetBytes ((String)obj);
			}
		      catch (Exception e)
			{
			  str = (String)obj;
			}
		}
	    }
	  return new StringReader(str);
	}
      if(obj != null && obj instanceof char[])
         return new CharArrayReader((char[])obj);
      return null;
   }

   /**
    * Gets the value of a column in the row as a java.math.BigDecimal
    * object with full precision.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return BigDecimal   The column value (full precision).
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getBigDecimal
    */
   protected BigDecimal getBigDecimal(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > maxCol)
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
      // Get the object in the corresponding column
      Object obj = content.elementAt(column - 1);
      // Return the object
      if(obj != null)
      {
         resultSet.wasNull(false);
         if(obj instanceof BigDecimal)
            return (BigDecimal)obj;
         else
            if(obj instanceof Number)
               try
               {
                  return new BigDecimal(((Number)obj).doubleValue());
               }
               catch(ClassCastException e)
               {
                  throw new VirtuosoException("Column does not contain a number.",VirtuosoException.CASTERROR);
               }
            else
               try
               {
                  return new BigDecimal(obj.toString());
               }
               catch(NumberFormatException e)
               {
                  throw new VirtuosoException(obj.toString() + " is not a number.",VirtuosoException.BADFORMAT);
               }
      }
      resultSet.wasNull(true);
      return null;
   }

   /**
    * Gets the value of a column in the row as a boolean.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return boolean   The column boolean value.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getBoolean
    */
   protected boolean getBoolean(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > maxCol)
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
      // Get the object in the corresponding column
      Object obj = content.elementAt(column - 1);
      // JDBC api spec
      if(obj != null)
      {
         resultSet.wasNull(false);
         if (obj instanceof Number)
           return (((Number)obj).intValue() == 0)?false:true;
         if (obj instanceof String)
           return (java.lang.Integer.parseInt((String)obj) == 0)?false:true;
         if (obj instanceof byte[])
           return (java.lang.Integer.parseInt(new String((byte[])obj)) == 0)?false:true;
         return Boolean.parseBoolean(obj.toString());
      }
      resultSet.wasNull(true);
      return false;
   }

   /**
    * Gets the value of a column in the row as a byte.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return byte   The column byte value.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getByte
    */
   protected byte getByte(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > maxCol)
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
      // Get the object in the corresponding column
      Object obj = content.elementAt(column - 1);
      // JDBC api spec
      if(obj != null)
      {
         resultSet.wasNull(false);
         if(obj instanceof Number)
            try
            {
               return ((Number)obj).byteValue();
            }
            catch(ClassCastException e)
            {
               throw new VirtuosoException("Column does not contain a byte.",VirtuosoException.CASTERROR);
            }
         else
            try
            {
               return Byte.parseByte(obj.toString());
            }
            catch(NumberFormatException e)
            {
               throw new VirtuosoException(obj.toString() + " is not a byte.",VirtuosoException.BADFORMAT);
            }
      }
      resultSet.wasNull(true);
      return 0;
   }

   /**
    * Gets the value of a column in the row as a byte array.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return byte   The column byte array value.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getBytes
    */
   protected byte[] getBytes(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > maxCol)
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
      // Get the object in the corresponding column
      Object obj = content.elementAt(column - 1);
      // JDBC api spec
      if(obj != null)
      {
         resultSet.wasNull(false);
         if (obj instanceof VirtuosoBlob)
           {
             VirtuosoBlob blob = (VirtuosoBlob) obj;
             if (blob.length() > Integer.MAX_VALUE)
               throw new VirtuosoException (
                    "Will not return more than " +
                     Integer.MAX_VALUE +
                     " for a BLOB column. Use getBinaryStream() instead",
               VirtuosoException.ERRORONTYPE);
	     return blob.getBytes(1, (int) blob.length());
	   }
         else if (obj instanceof byte[])
           return (byte[])obj;
         else if (obj instanceof java.lang.String)
           {
              try {
                return ((String)obj).getBytes ("8859_1");
              } catch (UnsupportedEncodingException e) { return null; }
           }
         else
           throw new VirtuosoException ("getBytes() return undefined on a value of type " + obj.getClass(),
             VirtuosoException.ERRORONTYPE);
      }
      resultSet.wasNull(true);
      return null;
   }

   /**
    * Gets the value of a column in the row as a double.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return byte   The column double value.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getDouble
    */
   protected double getDouble(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > maxCol)
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
      // Get the object in the corresponding column
      Object obj = content.elementAt(column - 1);
      // JDBC api spec
      if(obj != null)
      {
         resultSet.wasNull(false);
         if(obj instanceof Number)
            try
            {
               return ((Number)obj).doubleValue();
            }
            catch(ClassCastException e)
            {
               throw new VirtuosoException("Column does not contain a double.",VirtuosoException.CASTERROR);
            }
         else
            try
            {
               return Double.parseDouble(obj.toString().trim());
            }
            catch(NumberFormatException e)
            {
               throw new VirtuosoException(obj.toString() + " is not a double.",VirtuosoException.BADFORMAT);
            }
      }
      resultSet.wasNull(true);
      return 0.0d;
   }

   /**
    * Gets the value of a column in the row as a Date.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return Date   The column date value.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getDate
    */
   protected java.sql.Date getDate(int column) throws VirtuosoException
     {
       // Get and check parameter
       if(column < 1 || column > maxCol)
	 throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
       // Get the object in the corresponding column
       Object obj = content.elementAt(column - 1);
       // JDBC api spec
       if(obj != null)
	 {
	   resultSet.wasNull(false);

           if(obj instanceof VirtuosoDate)
             return ((VirtuosoDate)obj).clone();
           else if(obj instanceof VirtuosoTimestamp)
           {
             VirtuosoTimestamp _t = (VirtuosoTimestamp)obj;
             return new VirtuosoDate(_t.getTime(), _t.getTimezone(), _t.withTimezone());
           }
           else if (obj instanceof VirtuosoTime)
           {
             VirtuosoTime _t = (VirtuosoTime)obj;
             return new VirtuosoDate(_t.getTime(), _t.getTimezone(), _t.withTimezone());
           }
	   else if(obj instanceof java.sql.Date)
	     return new java.sql.Date(((java.sql.Date)obj).getTime());
	   else if (obj instanceof String)
	     return VirtuosoTypes.strToDate((String)obj);
	   else if (obj instanceof java.util.Date) 
	     return new java.sql.Date(((java.util.Date)obj).getTime());
	   else
             throw new VirtuosoException("Column does not contain a Date.",VirtuosoException.CASTERROR);
	 }
       resultSet.wasNull(true);
       return null;
     }

   /**
    * Gets the value of a column in the row as a Time.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return Time   The column time value.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getTime
    */
   protected java.sql.Time getTime(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > maxCol)
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
      // Get the object in the corresponding column
      Object obj = content.elementAt(column - 1);
      // JDBC api spec
      if(obj != null)
      {
         resultSet.wasNull(false);

         if (obj instanceof VirtuosoTime)
            return ((VirtuosoTime)obj).clone();
         else if(obj instanceof VirtuosoTimestamp)
         {
            VirtuosoTimestamp _t = (VirtuosoTimestamp)obj;
            return new VirtuosoTime(_t.getTime(), _t.getTimezone(), _t.withTimezone());
         }
         else if (obj instanceof VirtuosoDate)
         {
            VirtuosoDate _t = (VirtuosoDate)obj;
            return new VirtuosoTime(_t.getTime(), _t.getTimezone(), _t.withTimezone());
         }
         else if(obj instanceof java.sql.Time)
            return new java.sql.Time(((java.sql.Time)obj).getTime());
         else if (obj instanceof java.util.Date)
	    return new java.sql.Time(((java.util.Date)obj).getTime());
         else if(obj instanceof String)
            return VirtuosoTypes.strToTime((String)obj);
	 else
            throw new VirtuosoException("Column does not contain a Time.",VirtuosoException.CASTERROR);
      }
      resultSet.wasNull(true);
      return null;
   }

   /**
    * Gets the value of a column in the row as a Timestamp.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return Timestamp   The column timestamp value.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getTimestamp
    */
   protected java.sql.Timestamp getTimestamp(int column) throws VirtuosoException
     {
       // Get and check parameter
       if(column < 1 || column > maxCol)
	 throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
       // Get the object in the corresponding column
       Object obj = content.elementAt(column - 1);
       // JDBC api spec
       if(obj != null)
       {
         resultSet.wasNull(false);

         if (obj instanceof VirtuosoTimestamp)
            return ((VirtuosoTimestamp)obj).clone();
         else if(obj instanceof VirtuosoTime)
         {
            VirtuosoTime _t = (VirtuosoTime)obj;
            return new VirtuosoTimestamp(_t.getTime(), _t.getTimezone(), _t.withTimezone());
         }
         else if (obj instanceof VirtuosoDate)
         {
            VirtuosoDate _t = (VirtuosoDate)obj;
            return new VirtuosoTimestamp(_t.getTime(), _t.getTimezone(), _t.withTimezone());
         }
	 else if(obj instanceof java.sql.Timestamp)
         {
            Timestamp val = new java.sql.Timestamp(((java.sql.Timestamp)obj).getTime());
            val.setNanos(((java.sql.Timestamp)obj).getNanos());
            return val;
         }
         else if (obj instanceof java.util.Date)
         {
            return new java.sql.Timestamp(((java.util.Date)obj).getTime());
         }
         else if(obj instanceof String)
         {
            return VirtuosoTypes.strToTimestamp((String)obj);
         }
         else
            throw new VirtuosoException("Column does not contain a Timestamp.",VirtuosoException.CASTERROR);
       }
       resultSet.wasNull(true);
       return null;
     }

   /**
    * Gets the value of a column in the row as a float.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return byte   The column float value.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getFloat
    */
   protected float getFloat(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > maxCol)
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
      // Get the object in the corresponding column
      Object obj = content.elementAt(column - 1);
      // JDBC api spec
      if(obj != null)
      {
         resultSet.wasNull(false);
         if(obj instanceof Number)
            try
            {
               return ((Number)obj).floatValue();
            }
            catch(ClassCastException e)
            {
               throw new VirtuosoException("Column does not contain a float.",VirtuosoException.CASTERROR);
            }
         else
            try
            {
               return Float.parseFloat(obj.toString().trim());
            }
            catch(NumberFormatException e)
            {
               throw new VirtuosoException(obj.toString() + " is not a float.",VirtuosoException.BADFORMAT);
            }
      }
      resultSet.wasNull(true);
      return 0.0f;
   }

   /**
    * Gets the value of a column in the row as a int.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return byte   The column int value.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getInt
    */
   protected int getInt(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > maxCol)
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
      // Get the object in the corresponding column
      Object obj = content.elementAt(column - 1);
      // JDBC api spec
      if(obj != null)
      {
         resultSet.wasNull(false);
         if(obj instanceof Number)
            try
            {
               return ((Number)obj).intValue();
            }
            catch(ClassCastException e)
            {
               throw new VirtuosoException("Column does not contain an int.",VirtuosoException.CASTERROR);
            }
         else
            try
            {
               return Integer.parseInt(obj.toString().trim());
            }
            catch(NumberFormatException e)
            {
               throw new VirtuosoException(obj.toString() + " is not an int.",VirtuosoException.BADFORMAT);
            }
      }
      resultSet.wasNull(true);
      return 0;
   }

   /**
    * Gets the value of a column in the row as a long.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return byte   The column long value.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getLong
    */
   protected long getLong(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > maxCol)
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
      // Get the object in the corresponding column
      Object obj = content.elementAt(column - 1);
      // JDBC api spec
      if(obj != null)
      {
         resultSet.wasNull(false);
         if(obj instanceof Number)
            try
            {
               return ((Number)obj).longValue();
            }
            catch(ClassCastException e)
            {
               throw new VirtuosoException("Column does not contain a long.",VirtuosoException.CASTERROR);
            }
         else
            try
            {
               return Long.parseLong(obj.toString().trim());
            }
            catch(NumberFormatException e)
            {
               throw new VirtuosoException(obj.toString() + " is not a long.",VirtuosoException.BADFORMAT);
            }
      }
      resultSet.wasNull(true);
      return 0l;
   }

   /**
    * Gets the value of a column in the row as a short.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return short  The column short value.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getShort
    */
   protected short getShort(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > maxCol)
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
      // Get the object in the corresponding column
      Object obj = content.elementAt(column - 1);
      // JDBC api spec
      if(obj != null)
      {
         resultSet.wasNull(false);
         if(obj instanceof Number)
            try
            {
               return ((Number)obj).shortValue();
            }
            catch(ClassCastException e)
            {
               throw new VirtuosoException("Column does not contain a short.",VirtuosoException.CASTERROR);
            }
         else
            try
            {
               return Short.parseShort(obj.toString().trim());
            }
            catch(NumberFormatException e)
            {
               throw new VirtuosoException(obj.toString() + " is not a short.",VirtuosoException.BADFORMAT);
            }
      }
      resultSet.wasNull(true);
      return 0;
   }

   /**
    * Gets the value of a column in the row as a String.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return String The column string value.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getString
    */
   protected String getString(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > maxCol)
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
      // Get the object in the corresponding column
      Object obj = content.elementAt(column - 1);
      // JDBC api spec
      if(obj != null)
      {
	 int dtp = resultSet.metaData.getColumnDtp (column);
         resultSet.wasNull(false);
	 VirtuosoStatement stmt = (VirtuosoStatement)resultSet.getStatement();
	 if (stmt.connection.charset != null && obj instanceof String)
	   {
	     //System.out.println ("in getString: dtp=" + dtp);
	     switch (dtp)
	       {
		 case VirtuosoTypes.DV_SHORT_STRING_SERIAL:
		 case VirtuosoTypes.DV_STRING:
		 case VirtuosoTypes.DV_STRICT_STRING:
		     try
		       {
			 return stmt.connection.uncharsetBytes ((String)obj);
		       }
		     catch (Exception e)
		       {
			 return (String)obj;
		       }
	       }
	   }
	 if (obj instanceof java.sql.Timestamp)
	   {
	     java.sql.Timestamp ts = (java.sql.Timestamp) obj;
	     switch (dtp)
	       {
		 case VirtuosoTypes.DV_DATE:
		     return (new java.sql.Date (ts.getTime())).toString();
		 case VirtuosoTypes.DV_TIME:
		     return (new java.sql.Time (ts.getTime())).toString();
	       }
	   }
	 else if (obj instanceof VirtuosoBlob)
	   {
	     try {
	       Reader r = ((VirtuosoBlob)obj).getCharacterStream();
	       char[] data = new char[1024];
	       StringWriter w =  new StringWriter();
	       int l;
	       while((l = r.read(data)) != -1)
	         w.write(data,0,l);
	       return w.toString();
	     } catch (IOException e) {
	       throw new VirtuosoException(e, VirtuosoException.MISCERROR);
	     }
	   }
         return obj.toString();
      }
      resultSet.wasNull(true);
      return null;
   }

   /**
    * Gets the blob of a column in the row.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return Blob The blob.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getString
    */
   protected VirtuosoBlob getBlob(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > maxCol)
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
      // Get the object in the corresponding column
      VirtuosoBlob obj = (content.elementAt(column - 1) instanceof String) ?
         new VirtuosoBlob(((String)content.elementAt(column - 1)).getBytes()) :
	 (VirtuosoBlob)(content.elementAt(column - 1));
      // JDBC api spec
      if(obj != null)
      {
         resultSet.wasNull(false);
         return obj;
      }
      resultSet.wasNull(true);
      return null;
   }

   /**
    * Gets the clob of a column in the row.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return Clob The clob.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getString
    */
   protected
   VirtuosoBlob
   getClob(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > maxCol)
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
      // Get the object in the corresponding column
      VirtuosoBlob obj = (content.elementAt(column - 1) instanceof String) ?
         new VirtuosoBlob(((String)content.elementAt(column - 1)).getBytes()) :
	 (VirtuosoBlob)(content.elementAt(column - 1));
      // JDBC api spec
      if(obj != null)
      {
         resultSet.wasNull(false);
         return obj;
      }
      resultSet.wasNull(true);
      return null;
   }

   protected Object createDOMT (Object data) throws VirtuosoException
     {
       Object db = null;
       Method parse_mtd = null;
       // calls javax.xml.parsers.DocumentBuilderFactory.newInstance ()
       try
         {
	   Class<?> dbfact_cls = Class.forName ("javax.xml.parsers.DocumentBuilderFactory");
	   Object dbfact;
	   Method newInstMtd, newDbMtd;
	   newInstMtd = dbfact_cls.getDeclaredMethod ("newInstance", new Class [0]);
	   newDbMtd = dbfact_cls.getDeclaredMethod ("newDocumentBuilder", new Class [0]);

	   // dbfact = javax.xml.parsers.DocumentBuilderFactory.newInstance ();
	   dbfact = newInstMtd.invoke (null, new Object [0]);
	   // db = dbfact.newDocumentBuilder ();
	   db = newDbMtd.invoke (dbfact, new Object [0]);

	   Class<?> db_cls = Class.forName ("javax.xml.parsers.DocumentBuilder");
	   Class<?> parse_args = Class.forName ("java.io.InputStream");
	   parse_mtd = db_cls.getDeclaredMethod ("parse", parse_args);
         }
       catch (Throwable t)
         {
	   db = null;
         }

       if (db == null || parse_mtd == null)
	   return data;

       try
         {
	   if (data instanceof String)
	     {
	       // db.parse (data)
	       //System.out.println ("xml=[" + ((String)data) + "]");
	       Object [] args = { new ByteArrayInputStream ( ((String)data).getBytes("UTF-8")) };
	       data = parse_mtd.invoke (db, args );
	     }
	   else if (data instanceof VirtuosoBlob)
	     {
		 // db.parse (data)
	       Object [] args = { ((VirtuosoBlob)data).getBinaryStream () };
	       data = parse_mtd.invoke (db, args);
	     }
         }
       catch (Exception e)
         {
	   throw new VirtuosoException (e, VirtuosoException.CASTERROR);
         }
       return data;
   }



   /**
    * Gets the value of a column in the row as an Object.
    *
    * @param column The first column is 1, the second is 2, ...
    * @return Object The column Object value.
    * @exception virtuoso.jdbc2.VirtuosoException   An internal error occurred.
    * @see java.sql.ResultSet#getObject
    */
   protected Object getObject(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > maxCol)
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + maxCol,VirtuosoException.BADPARAM);
      // Get the object in the corresponding column
      Object obj = content.elementAt(column - 1);
      // JDBC api spec
      if(obj != null)
      {
         resultSet.wasNull(false);
	 if (resultSet.metaData.isXml (column))
	   {
	     return createDOMT (obj);
	   }
         else if (obj instanceof VirtuosoTimestamp)
             return ((VirtuosoTimestamp)obj).clone();
         else if(obj instanceof VirtuosoTime)
             return ((VirtuosoTime)obj).clone();
         else if (obj instanceof VirtuosoDate)
             return ((VirtuosoDate)obj).clone();
	 else if(obj instanceof java.sql.Date)
	   {                                          
	     return new java.sql.Date(((java.sql.Date)obj).getTime());
	   }
         else if(obj instanceof java.sql.Time)
           {
	     return new java.sql.Time(((java.sql.Time)obj).getTime());
           }
	 else if(obj instanceof java.sql.Timestamp)
	   {
	     Timestamp val = new java.sql.Timestamp(((java.sql.Timestamp)obj).getTime());
	     val.setNanos(((java.sql.Timestamp)obj).getNanos());
	     return val;
	   }

         return obj;
      }
      resultSet.wasNull(true);
      return null;
   }

   /**
    * Get the line number (used only with scrollable cursor)
    *
    * @return The line number in the rowset
    */
   protected int getRow()
   {
      // Check if a linenumber exist
      return (maxCol != content.size()) ? ((Number)content.elementAt(maxCol)).intValue() : 0;
   }

   /**
    * Get the line number (used only with scrollable cursor)
    *
    * @return The line number in the rowset
    */
   protected String getRef()
   {
      // Check if a linenumber exist
      //System.err.println ("In GetRef maxCol = " + maxCol + " content_size=" + content.size());
      if (maxCol != content.size())
	{
	  openlink.util.Vector v1 = (openlink.util.Vector)content.elementAt(maxCol);
	  openlink.util.Vector v2 = (openlink.util.Vector)v1.elementAt (1);
	  Object ret = v2.elementAt (0);
	  //System.err.println ("GetRef returned (" + ret.getClass().getName() + ")=" + ret.toString());
	  return ret.toString();
	}
      else
	return "";
   }

   /**
    * Get the line number (used only with scrollable cursor)
    *
    * @return The bookmark of the line
    */
   protected openlink.util.Vector getBookmark()
   {
      // Check if a linenumber exist
     if (maxCol != content.size())
       return (openlink.util.Vector)content.elementAt(maxCol);
     else
       return content;
   }

   public String toString ()
     {
       if (content == null)
	 return super.toString();
      StringBuffer buf = new StringBuffer();
      buf.append("{ROW ");
      buf.append (content.toString());
      buf.append("}");
      return buf.toString();
     }

}

