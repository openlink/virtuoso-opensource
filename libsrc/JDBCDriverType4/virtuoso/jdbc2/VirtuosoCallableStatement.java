/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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
 *  
*/
/* VirtuosoCallableStatement.java */
package virtuoso.jdbc2;

import java.sql.*;
import java.util.*;
import java.io.*;
import java.math.*;
import openlink.util.*;

/**
 * The VirtuosoCallableStatement class is an implementation of the CallableStatement interface
 * in the JDBC API which represents a callable statement.
 * You can obtain a CallableStatement like below :
 * <pre>
 *   <code>CallableStatement s = connection.prepareCall(...)</code>
 * </pre>
 *
 * @version 1.0 (JDBC API 2.0 implementation)
 * @see virtuoso.jdbc2.VirtuosoConnection#prepareCall
 */
public class VirtuosoCallableStatement extends VirtuosoPreparedStatement implements CallableStatement
{
   // The flag of the nullability of the last operation
   private boolean _wasNull = false;
   // The flag of the existance of out parameters
   private boolean _hasOut = false;

   protected int [] param_type;
   protected int [] param_scale;
   /**
    * Constructs a new VirtuosoCallableStatement that is forward-only and read-only.
    *
    * @param connection The VirtuosoConnection which owns it.
    * @param sql        The sql string with ?.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   VirtuosoCallableStatement(VirtuosoConnection connection, String sql) throws VirtuosoException
   {
      this (connection,sql,VirtuosoResultSet.TYPE_FORWARD_ONLY,VirtuosoResultSet.CONCUR_READ_ONLY);
   }

   /**
    * Constructs a new VirtuosoCallableStatement with specific options.
    *
    * @param connection The VirtuosoConnection which owns it.
    * @param sql        The sql string with ?.
    * @param type       The result set type.
    * @param concurrency   The result set concurrency.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    * @see java.sql.ResultSet
    */
   VirtuosoCallableStatement(VirtuosoConnection connection, String sql, int type, int concurrency) throws VirtuosoException
   {
      super(connection,sql/*.replace('{',' ').replace('}',' ')*/,type,concurrency);
      param_type = new int[parameters.capacity()];
      param_scale = new int[parameters.capacity()];
      for (int i = 0; i < param_type.length; i++)
        {
          param_type[i] = Types.OTHER;
          param_scale[i] = 0;
        }
   }

   // --------------------------- JDBC 2.0 ------------------------------
   /**
    * Registers the OUT parameter in ordinal position
    * parameterIndex to the JDBC type sqlType.
    * All OUT parameters must be registered
    * before a stored procedure is executed.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @param sqlType the JDBC type code defined by java.sql.Types.
    * If the parameter is of type Numeric or Decimal, the version of
    * registerOutParameter that accepts a scale value should be used.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#registerOutParameter
    * @see java.sql.Types
    */
   public void registerOutParameter(int parameterIndex, int sqlType) throws VirtuosoException
   {
      registerOutParameter(parameterIndex,sqlType,0);
   }

   /**
    * Registers the parameter in ordinal position
    * parameterIndex to be of JDBC type sqlType.
    * This method must be called before a stored procedure
    * is executed.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @param sqlType SQL type code defined by <code>java.sql.Types</code>.
    * @param scale the desired number of digits to the right of the
    * decimal point.  It must be greater than or equal to zero.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#registerOutParameter
    * @see java.sql.Types
    */
   public void registerOutParameter(int parameterIndex, int sqlType, int scale) throws VirtuosoException
   {
      _hasOut = true;
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Put the output parameter
      param_type[parameterIndex - 1] = sqlType;
      param_scale[parameterIndex - 1] = scale;
      switch(sqlType)
      {
         case Types.ARRAY:
            /*objparams.setElementAt(new VirtuosoArray(),parameterIndex-1);*/
            return;
         case Types.STRUCT:
            /*objparams.setElementAt(new VirtuosoStruct(),parameterIndex-1);*/
            return;
         case Types.BIGINT:
            objparams.setElementAt(new Long(Long.MAX_VALUE),parameterIndex - 1);
            return;
         case Types.LONGVARBINARY:
         case Types.VARBINARY:
         case Types.BINARY:
            /*objparams.setElementAt(new VirtuosoBinary(),parameterIndex-1);*/
            return;
         case Types.BIT:
            objparams.setElementAt(new Boolean(false),parameterIndex - 1);
            return;
         case Types.BLOB:
            /*objparams.setElementAt(new VirtuosoBlob(),parameterIndex-1);*/
            return;
         case Types.CLOB:
            /*objparams.setElementAt(new VirtuosoClob(),parameterIndex-1);*/
            return;
         case Types.LONGVARCHAR:
         case Types.VARCHAR:
         case Types.CHAR:
            objparams.setElementAt(new String(),parameterIndex - 1);
            return;
         case Types.DATE:
            objparams.setElementAt(new java.sql.Date(0),parameterIndex - 1);
            return;
         case Types.TIME:
            objparams.setElementAt(new java.sql.Time(0),parameterIndex - 1);
            return;
         case Types.TIMESTAMP:
            objparams.setElementAt(new java.sql.Timestamp(0),parameterIndex - 1);
            return;
         case Types.NUMERIC:
         case Types.DECIMAL:
            objparams.setElementAt(new BigDecimal(0.0d).setScale(scale),parameterIndex - 1);
            return;
         case Types.FLOAT:
         case Types.DOUBLE:
            objparams.setElementAt(new Double(Double.MAX_VALUE),parameterIndex - 1);
            return;
         case Types.OTHER:
         case Types.JAVA_OBJECT:
            objparams.setElementAt(new Object(),parameterIndex - 1);
            return;
         case Types.NULL:
            objparams.setElementAt(new VirtuosoNullParameter(sqlType, true),parameterIndex - 1);
            return;
         case Types.REAL:
            objparams.setElementAt(new Float(Float.MAX_VALUE),parameterIndex - 1);
            return;
         case Types.SMALLINT:
            objparams.setElementAt(new Short(Short.MAX_VALUE),parameterIndex - 1);
            return;
         case Types.INTEGER:
         case Types.TINYINT:
            objparams.setElementAt(new Integer(Integer.MAX_VALUE),parameterIndex - 1);
            return;
      }
      ;
   }

   /**
    * Indicates whether or not the last OUT parameter read had the value of
    * SQL NULL.  Note that this method should be called only after
    * calling the get method; otherwise, there is no value to use in
    * determining whether it is null or not.
    *
    * @return true if the last parameter read was SQL NULL;
    * false otherwise.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#wasNull
    */
   public boolean wasNull() throws VirtuosoException
   {
      return _wasNull;
   }

   /**
    * Indicates whether the OUT parameters exist.
    *
    * @return true if there are OUT parameters
    * false otherwise.
    */
   public boolean hasOut()
   {
      return _hasOut;
   }

   /**
    * Retrieves the value of a JDBC CHAR, VARCHAR,
    * or LONGVARCHAR parameter as a String in
    * the Java programming language.
    * For the fixed-length type JDBC CHAR, the String object
    * returned has exactly the same value the JDBC CHAR value had in the
    * database, including any padding added by the database.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @return the parameter value. If the value is SQL NULL, the result
    * is null.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getString
    */
   public String getString(int parameterIndex) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Return object
      Object obj = mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     param_type[parameterIndex - 1],
                     param_scale[parameterIndex - 1]);
      if (_wasNull = (obj == null))
	return null;
      else
	return obj.toString();
   }

   /**
    * Gets the value of a JDBC BIT parameter as a boolean
    * in the Java programming language.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @return the parameter value.  If the value is SQL NULL, the result
    * is false.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getBoolean
    */
   public boolean getBoolean(int parameterIndex) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Return object
      Object obj = mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     param_type[parameterIndex - 1],
                     param_scale[parameterIndex - 1]);
      _wasNull = (obj == null);
      if (_wasNull)
        return false;
      else
        {
          java.lang.Number nret = (java.lang.Number) obj;
          return (nret.intValue() != 0);
        }
   }

   /**
    * Gets the value of a JDBC TINYINT parameter as a byte
    * in the Java programming language.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @return the parameter value.  If the value is SQL NULL, the result
    * is 0.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getByte
    */
   public byte getByte(int parameterIndex) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Return object
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Return object
      Object obj = mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     param_type[parameterIndex - 1],
                     param_scale[parameterIndex - 1]);
      if (_wasNull = (obj == null))
	return 0;
      else
	return ((Number) obj).byteValue();
   }

   /**
    * Gets the value of a JDBC SMALLINT parameter as a <code>short</code>
    * in the Java programming language.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @return the parameter value.  If the value is SQL NULL, the result
    * is 0.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getShort
    */
   public short getShort(int parameterIndex) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Return object
      Object obj = mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     param_type[parameterIndex - 1],
                     param_scale[parameterIndex - 1]);
      if (_wasNull = (obj == null))
	return 0;
      else
	return ((Number) obj).shortValue();
   }

   /**
    * Gets the value of a JDBC INTEGER parameter as an <code>int</code>
    * in the Java programming language.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @return the parameter value.  If the value is SQL NULL, the result
    * is 0.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getInt
    */
   public int getInt(int parameterIndex) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Return object
      Object obj = mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     param_type[parameterIndex - 1],
                     param_scale[parameterIndex - 1]);
      if (_wasNull = (obj == null))
	return 0;
      else
	return ((Number) obj).intValue();
   }

   /**
    * Gets the value of a JDBC BIGINT parameter as a <code>long</code>
    * in the Java programming language.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @return the parameter value.  If the value is SQL NULL, the result
    * is 0.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getLong
    */
   public long getLong(int parameterIndex) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Return object
      Object obj = mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     param_type[parameterIndex - 1],
                     param_scale[parameterIndex - 1]);
      if (_wasNull = (obj == null))
	return 0;
      else
	return ((Number) obj).longValue();
   }

   /**
    * Gets the value of a JDBC FLOAT parameter as a <code>float</code>
    * in the Java programming language.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @return the parameter value.  If the value is SQL NULL, the result
    * is 0.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getFloat
    */
   public float getFloat(int parameterIndex) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Return object
      Object obj = mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     param_type[parameterIndex - 1],
                     param_scale[parameterIndex - 1]);
      if (_wasNull = (obj == null))
	return 0;
      else
	return ((Number) obj).floatValue();
   }

   /**
    * Gets the value of a JDBC DOUBLE parameter as a <code>double</code>
    * in the Java programming language.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @return the parameter value.  If the value is SQL NULL, the result
    * is 0.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getDouble
    */
   public double getDouble(int parameterIndex) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Return object
      Object obj = mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     param_type[parameterIndex - 1],
                     param_scale[parameterIndex - 1]);
      if (_wasNull = (obj == null))
	return 0;
      else
	return ((Number) obj).doubleValue();
   }

   /**
    * Gets the value of a JDBC NUMERIC parameter as a
    * java.math.BigDecimal object with scale digits to
    * the right of the decimal point.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @param scale the number of digits to the right of the decimal point
    * @return the parameter value.  If the value is SQL NULL, the result is
    * null.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getBigDecimal
    * @deprecated
    */
   public BigDecimal getBigDecimal(int parameterIndex, int scale) throws VirtuosoException
   {
     BigDecimal ret = getBigDecimal (parameterIndex);
     if (ret != null)
       ret = ret.setScale(scale);
     return ret;
   }

   /**
    * Gets the value of a JDBC BINARY or VARBINARY
    * parameter as an array of byte values in the Java
    * programming language.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @return the parameter value.  If the value is SQL NULL, the result is
    * null.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getBytes
    */
   public byte[] getBytes(int parameterIndex) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Return object
      Object obj = mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     param_type[parameterIndex - 1],
                     param_scale[parameterIndex - 1]);
      if (_wasNull = (obj == null))
	return null;
      else
	return (byte []) obj;
   }

   /**
    * Gets the value of a JDBC DATE parameter as a
    * java.sql.Date object.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @return the parameter value.  If the value is SQL NULL, the result
    * is null.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getDate
    */
   public java.sql.Date getDate(int parameterIndex) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Return object
      Object obj = mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     param_type[parameterIndex - 1],
                     param_scale[parameterIndex - 1]);
      if (_wasNull = (obj == null))
	return null;
      else
	return java.sql.Date.valueOf (((java.sql.Date) obj).toString());
   }

   /**
    * Get the value of a JDBC TIME parameter as a
    * java.sql.Time object.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @return the parameter value.  If the value is SQL NULL, the result
    * is null.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getTime
    */
   public java.sql.Time getTime(int parameterIndex) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Return object
      Object obj = mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     param_type[parameterIndex - 1],
                     param_scale[parameterIndex - 1]);
      if (_wasNull = (obj == null))
	return null;
      else if(obj instanceof java.sql.Time)
	return java.sql.Time.valueOf (((java.sql.Time)obj).toString());
      else if (obj instanceof java.util.Date)
	{
	  java.sql.Time tm = new java.sql.Time (((java.util.Date)obj).getTime());
	  return java.sql.Time.valueOf(tm.toString());
	}
      else if(obj instanceof String)
	{
	  return java.sql.Time.valueOf((String)obj);
	}
      else return null;
   }

   /**
    * Gets the value of a JDBC TIMESTAMP parameter as a
    * java.sql.Timestamp object.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @return the parameter value.  If the value is SQL NULL, the result
    * is null.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getTimestamp
    */
   public java.sql.Timestamp getTimestamp(int parameterIndex) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Return object
      Object obj = mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     param_type[parameterIndex - 1],
                     param_scale[parameterIndex - 1]);
      if (_wasNull = (obj == null))
	return null;
      else
	return java.sql.Timestamp.valueOf (((java.sql.Timestamp) obj).toString());
   }

   /**
    * Gets the value of a parameter as an object in the Java
    * programming language.
    *
    * @param parameterIndex The first parameter is 1, the second is 2,
    * and so on
    * @return A java.lang.Object holding the OUT parameter value.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getObject
    */
   public Object getObject(int parameterIndex) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Return object
      Object obj = mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     param_type[parameterIndex - 1],
                     param_scale[parameterIndex - 1]);

      if (_wasNull = (obj == null))
	return null;
      else
	{
          switch (param_type[parameterIndex - 1])
            {
              case Types.BIGINT:
                obj = new Long(((Number)obj).longValue()); break;

              case Types.DATE:
                if (! (obj instanceof java.sql.Date))
                  {
		    if (obj instanceof java.util.Date)
		      obj = java.sql.Date.valueOf (new java.sql.Date(((java.util.Date)obj).getTime()).toString());
		    else
		      obj = java.sql.Date.valueOf ((String) obj);
		  }
                break;

              case Types.TIME:
                if (! (obj instanceof java.sql.Time))
                  {
		    if (obj instanceof java.util.Date)
		      obj = java.sql.Time.valueOf (new java.sql.Time(((java.util.Date)obj).getTime()).toString());
		    else
		      obj = java.sql.Time.valueOf ((String) obj);
		  }
                break;

              case Types.TIMESTAMP:
                if (! (obj instanceof java.sql.Timestamp))
                  {
		    if (obj instanceof java.util.Date)
		      obj = java.sql.Timestamp.valueOf (new java.sql.Timestamp(((java.util.Date)obj).getTime()).toString());
		    else
		      obj = java.sql.Timestamp.valueOf ((String) obj);
		  }
                break;

             }
          return obj;
        }
   }

   /**
    * Gets the value of a JDBC NUMERIC parameter as a
    * java.math.BigDecimal object with as many digits to the
    * right of the decimal point as the value contains.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @return the parameter value in full precision.  If the value is
    * SQL NULL, the result is null.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getBigDecimal
    */
   public BigDecimal getBigDecimal(int parameterIndex) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Return object
      Object obj = mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     param_type[parameterIndex - 1],
                     param_scale[parameterIndex - 1]);
      if (_wasNull = (obj == null))
	return null;
      else
	return ((BigDecimal) obj);
   }

#if JDK_VER >= 12
   /**
    * Returns an object representing the value of OUT parameter
    * i and uses map for the custom mapping of the parameter value.
    *
    * @param i the first parameter is 1, the second is 2, and so on
    * @param map the mapping from SQL type names to Java classes
    * @return a java.lang.Object holding the OUT parameter value.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getObject
    */
   public Object getObject(int parameterIndex, java.util.Map map) throws VirtuosoException
   {
     return this.getObject (parameterIndex);
   }

   /**
    * Gets the value of a JDBC REF(&lt;structured-type&gt;)
    * parameter as a {@link Ref} object in the Java programming language.
    *
    * @param i the first parameter is 1, the second is 2,
    * and so on
    * @return the parameter value as a Ref object in the
    * Java programming language.  If the value was SQL NULL, the value
    * null is returned.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getRef
    */
   public Ref getRef(int parameterIndex) throws VirtuosoException
   {
     throw new VirtuosoException ("REF not supported", VirtuosoException.NOTIMPLEMENTED);
   }
#endif

   /**
    * Gets the value of a JDBC BLOB parameter as a
    * {@link Blob} object in the Java programming language.
    *
    * @param i the first parameter is 1, the second is 2, and so on
    * @return the parameter value as a Blob object in the
    * Java programming language.  If the value was SQL NULL, the value
    * null is returned.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getBlob
    */
   public
#if JDK_VER >= 12
   Blob
#else
   VirtuosoBlob
#endif
   getBlob(int parameterIndex) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Return object
      if (_wasNull = (objparams.elementAt(parameterIndex - 1) == null))
        return null;
      else
        return
#if JDK_VER >= 12
           (Blob)
#else
	   (VirtuosoBlob)
#endif
           objparams.elementAt(parameterIndex - 1);
   }

   /**
    * Gets the value of a JDBC CLOB parameter as a
    * Clob object in the Java programming language.
    *
    * @param i the first parameter is 1, the second is 2, and
    * so on
    * @return the parameter value as a <code>Clob</code> object in the
    * Java programming language.  If the value was SQL NULL, the
    * value null is returned.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getClob
    */
   public
#if JDK_VER >= 12
   Clob
#else
   VirtuosoClob
#endif
   getClob(int parameterIndex) throws VirtuosoException
   {
      // Check parameters
      if(parameterIndex < 1 || parameterIndex > parameters.capacity())
         throw new VirtuosoException("Index " + parameterIndex + " is not 1<n<" + parameters.capacity(),VirtuosoException.BADPARAM);
      // Return object
      if (_wasNull = (objparams.elementAt(parameterIndex - 1) == null))
        return null;
      else
        return
#if JDK_VER >= 12
         (Clob)
#else
	 (VirtuosoClob)
#endif
         objparams.elementAt(parameterIndex - 1);
   }

#if JDK_VER >= 12
   /**
    * Gets the value of a JDBC <code>ARRAY</code> parameter as an
    * {@link Array} object in the Java programming language.
    * @param i the first parameter is 1, the second is 2, and
    * so on
    * @return the parameter value as an <code>Array</code> object in
    * the Java programming language.  If the value was SQL NULL, the
    * value <code>null</code> is returned.
    * @exception SQLException if a database access error occurs
    */
   public Array getArray(int parameterIndex) throws VirtuosoException
   {
     throw new VirtuosoException ("ARRAY not supported", VirtuosoException.NOTIMPLEMENTED);
   }
#endif

   /**
    * Gets the value of a JDBC DATE parameter as a java.sql.Date object, using
    * the given Calendar object to construct the date.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @param cal the Calendar object the driver will use
    * to construct the date
    * @return the parameter value.  If the value is SQL NULL, the result is
    * null.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getDate
    */
   public java.sql.Date getDate(int parameterIndex, Calendar cal) throws VirtuosoException
   {
     java.sql.Date ret = this.getDate(parameterIndex);
     if (ret == null)
       return ret;
     cal.setTime (ret);
     return java.sql.Date.valueOf (new java.sql.Date (cal.getTime().getTime()).toString());
   }

   /**
    * Gets the value of a JDBC TIME parameter as a java.sql.Time object, using
    * the given Calendar object to construct the time.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @param cal the Calendar object the driver will use
    * to construct the time
    * @return the parameter value; if the value is SQL NULL, the result is null.
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#getTime
    */
   public java.sql.Time getTime(int parameterIndex, Calendar cal) throws VirtuosoException
   {
     java.sql.Time ret = this.getTime(parameterIndex);
     if (ret == null)
       return ret;
     cal.setTime (ret);
     return java.sql.Time.valueOf (new java.sql.Time (cal.getTime().getTime()).toString());
   }

   /**
    * Gets the value of a JDBC TIMESTAMP parameter as a
    * java.sql.Timestamp object, using the given Calendar object to construct
    * the Timestamp object.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,
    * and so on
    * @param cal the Calendar object the driver will use
    * to construct the timestamp
    * @return the parameter value.  If the value is SQL NULL, the result is null.
    * @exception SQLException if a database access error occurs
    */
   public java.sql.Timestamp getTimestamp(int parameterIndex, Calendar cal) throws SQLException
   {
     java.sql.Timestamp ret = this.getTimestamp(parameterIndex);
     if (ret == null)
       return ret;
     cal.setTime (ret);
     return java.sql.Timestamp.valueOf (new java.sql.Timestamp (cal.getTime().getTime()).toString());
   }

   /**
    * Registers the designated output parameter.  This version of
    * the method <code>registerOutParameter</code>
    * should be used for a user-named or REF output parameter.  Examples
    * of user-named types include: STRUCT, DISTINCT, JAVA_OBJECT, and
    * named array types.
    *
    * @param parameterIndex the first parameter is 1, the second is 2,...
    * @param sqlType a value from {@link java.sql.Types}
    * @param typeName the fully-qualified name of an SQL structured type
    * @exception VirtuosoException if a database access error occurs
    * @see java.sql.CallableStatement#registerOutParameter
    */
   public void registerOutParameter(int parameterIndex, int sqlType, String typeName) throws VirtuosoException
   {
     throw new VirtuosoException ("UDTs not supported", VirtuosoException.NOTIMPLEMENTED);
   }


#if JDK_VER >= 14
   /* JDK 1.4 functions */

   public void registerOutParameter(String parameterName,
       int sqlType) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void registerOutParameter(String parameterName,
       int sqlType,
       int scale) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void registerOutParameter(String parameterName,
       int sqlType,
       String typeName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public java.net.URL getURL(int parameterIndex) throws SQLException
     {
       throw new VirtuosoException ("DATALINK type not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setURL(String parameterName, java.net.URL val) throws SQLException
     {
       throw new VirtuosoException ("DATALINK type not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setNull(String parameterName, int sqlType) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setBoolean(String parameterName, boolean x) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setByte(String parameterName, byte x) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setShort(String parameterName, short x) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setInt(String parameterName, int x) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setLong(String parameterName, long x) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setFloat(String parameterName, float x) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setDouble(String parameterName, double x) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setBigDecimal(String parameterName, BigDecimal x) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setString(String parameterName, String x) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setBytes(String parameterName, byte[] x) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setDate(String parameterName, java.sql.Date x) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setTime(String parameterName, Time x) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setTimestamp(String parameterName, Timestamp x) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setAsciiStream(String parameterName, InputStream x, int length) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setBinaryStream(String parameterName, InputStream x, int length) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setObject(String parameterName, Object x, int targetSqlType,
       int scale) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setObject(String parameterName, Object x,
       int targetSqlType) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setObject(String parameterName, Object x) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setCharacterStream(String parameterName, Reader reader, int length) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setDate(String parameterName, java.sql.Date x, Calendar cal) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setTime(String parameterName, Time x, Calendar cal) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setTimestamp(String parameterName, Timestamp x, Calendar cal) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public void setNull(String parameterName, int sqlType, String typeName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public String getString(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public boolean getBoolean(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public byte getByte(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public short getShort(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public int getInt(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public long getLong(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public float getFloat(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public double getDouble(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public byte[] getBytes(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public java.sql.Date getDate(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public Time getTime(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public Timestamp getTimestamp(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public Object getObject(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public BigDecimal getBigDecimal(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public Object getObject(String parameterName, Map map) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public Ref getRef(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public Blob getBlob(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public Clob getClob(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public Array getArray(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public java.sql.Date getDate(String parameterName, Calendar cal) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public Time getTime(String parameterName, Calendar cal) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public Timestamp getTimestamp(String parameterName, Calendar cal) throws SQLException
     {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
     }

   public java.net.URL getURL(String parameterName) throws SQLException
     {
       throw new VirtuosoException ("DATALINK type not supported", VirtuosoException.NOTIMPLEMENTED);
     }
#endif
}
