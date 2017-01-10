/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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
         case Types.STRUCT:
            return;
         case Types.BIGINT:
            if (objparams.elementAt(parameterIndex - 1) == null)
              objparams.setElementAt(new Long(Long.MAX_VALUE),parameterIndex - 1);
            return;
         case Types.LONGVARBINARY:
         case Types.VARBINARY:
         case Types.BINARY:
            return;
         case Types.BIT:
            if (objparams.elementAt(parameterIndex - 1) == null)
              objparams.setElementAt(new Boolean(false),parameterIndex - 1);
            return;
         case Types.BLOB:
         case Types.CLOB:
            return;
         case Types.LONGVARCHAR:
         case Types.VARCHAR:
         case Types.CHAR:
            if (objparams.elementAt(parameterIndex - 1) == null)
              objparams.setElementAt(new String(),parameterIndex - 1);
            return;
         case Types.DATE:
            if (objparams.elementAt(parameterIndex - 1) == null)
              objparams.setElementAt(new java.sql.Date(0),parameterIndex - 1);
            return;
         case Types.TIME:
            if (objparams.elementAt(parameterIndex - 1) == null)
              objparams.setElementAt(new java.sql.Time(0),parameterIndex - 1);
            return;
         case Types.TIMESTAMP:
            if (objparams.elementAt(parameterIndex - 1) == null)
              objparams.setElementAt(new java.sql.Timestamp(0),parameterIndex - 1);
            return;
         case Types.NUMERIC:
         case Types.DECIMAL:
            if (objparams.elementAt(parameterIndex - 1) == null)
              objparams.setElementAt(new BigDecimal(0.0d).setScale(scale),parameterIndex - 1);
            return;
         case Types.FLOAT:
         case Types.DOUBLE:
            if (objparams.elementAt(parameterIndex - 1) == null)
              objparams.setElementAt(new Double(Double.MAX_VALUE),parameterIndex - 1);
            return;
         case Types.OTHER:
         case Types.JAVA_OBJECT:
            if (objparams.elementAt(parameterIndex - 1) == null)
              objparams.setElementAt(new Object(),parameterIndex - 1);
            return;
         case Types.NULL:
            if (objparams.elementAt(parameterIndex - 1) == null)
              objparams.setElementAt(new VirtuosoNullParameter(sqlType, true),parameterIndex - 1);
            return;
         case Types.REAL:
            if (objparams.elementAt(parameterIndex - 1) == null)
              objparams.setElementAt(new Float(Float.MAX_VALUE),parameterIndex - 1);
            return;
         case Types.SMALLINT:
            if (objparams.elementAt(parameterIndex - 1) == null)
              objparams.setElementAt(new Short(Short.MAX_VALUE),parameterIndex - 1);
            return;
         case Types.INTEGER:
         case Types.TINYINT:
            if (objparams.elementAt(parameterIndex - 1) == null)
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
      Object obj = VirtuosoTypes.mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
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
      Object obj = VirtuosoTypes.mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
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
      Object obj = VirtuosoTypes.mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
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
      Object obj = VirtuosoTypes.mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
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
      Object obj = VirtuosoTypes.mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
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
      Object obj = VirtuosoTypes.mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
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
      Object obj = VirtuosoTypes.mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
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
      Object obj = VirtuosoTypes.mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
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
      Object obj = VirtuosoTypes.mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
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
      Object obj = VirtuosoTypes.mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     Types.DATE,
                     param_scale[parameterIndex - 1]);
      if (_wasNull = (obj == null))
	return null;
      else
	return (java.sql.Date)obj;
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
      Object obj = VirtuosoTypes.mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     Types.TIME,
                     param_scale[parameterIndex - 1]);
      if (_wasNull = (obj == null))
	return null;
      else	
        return (java.sql.Time)obj;
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
      Object obj = VirtuosoTypes.mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     Types.TIMESTAMP,
                     param_scale[parameterIndex - 1]);
      if (_wasNull = (obj == null))
	return null;
      else
	return (java.sql.Timestamp)obj;
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
      Object obj = VirtuosoTypes.mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     param_type[parameterIndex - 1],
                     param_scale[parameterIndex - 1]);

      _wasNull = (obj == null);
      return obj;
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
      Object obj = VirtuosoTypes.mapJavaTypeToSqlType (objparams.elementAt(parameterIndex - 1),
                     Types.DECIMAL,
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
     java.sql.Date date = this.getDate(parameterIndex);

      if(cal != null && date != null)
        date = new java.sql.Date(VirtuosoTypes.timeToCal(date, cal));

      return date;
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
     java.sql.Time _time = this.getTime(parameterIndex);

      if(cal != null && _time != null)
        _time = new java.sql.Time(VirtuosoTypes.timeToCal(_time, cal));

      return _time;
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
     java.sql.Timestamp _ts, val;
     
     _ts = val = this.getTimestamp(parameterIndex);

      if(cal != null && _ts != null)
        _ts = new java.sql.Timestamp(VirtuosoTypes.timeToCal(_ts, cal));

      if (_ts!=null)
        _ts.setNanos(val.getNanos());
      return _ts;
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

#if JDK_VER >= 16
  private int findParam (String paramName) throws SQLException {
       throw new VirtuosoException ("Named parameters not supported", VirtuosoException.NOTIMPLEMENTED);
  }


    //------------------------- JDBC 4.0 -----------------------------------
    /**
     * Retrieves the value of the designated JDBC <code>ROWID</code> parameter as a
     * <code>java.sql.RowId</code> object.
     *
     * @param parameterIndex the first parameter is 1, the second is 2,...
     * @return a <code>RowId</code> object that represents the JDBC <code>ROWID</code>
     *     value is used as the designated parameter. If the parameter contains
     * a SQL <code>NULL</code>, then a <code>null</code> value is returned.
     * @throws SQLException if the parameterIndex is not valid;
     * if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public RowId getRowId(int parameterIndex) throws SQLException
  {
    throw new VirtuosoException ("Method 'getRowId(parameterIndex)' not yet implemented", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Retrieves the value of the designated JDBC <code>ROWID</code> parameter as a
     * <code>java.sql.RowId</code> object.
     *
     * @param parameterName the name of the parameter
     * @return a <code>RowId</code> object that represents the JDBC <code>ROWID</code>
     *     value is used as the designated parameter. If the parameter contains
     * a SQL <code>NULL</code>, then a <code>null</code> value is returned.
     * @throws SQLException if parameterName does not correspond to a named
     * parameter; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public RowId getRowId(String parameterName) throws SQLException
  {
    throw new VirtuosoException ("Method 'getRowId(parameterName)' not yet implemented", VirtuosoException.NOTIMPLEMENTED);
  }

     /**
     * Sets the designated parameter to the given <code>java.sql.RowId</code> object. The
     * driver converts this to a SQL <code>ROWID</code> when it sends it to the
     * database.
     *
     * @param parameterName the name of the parameter
     * @param x the parameter value
     * @throws SQLException if parameterName does not correspond to a named
     * parameter; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void setRowId(String parameterName, RowId x) throws SQLException
  {
    throw new VirtuosoException ("Method 'setRowId(parameterName, x)' not yet implemented", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Sets the designated parameter to the given <code>String</code> object.
     * The driver converts this to a SQL <code>NCHAR</code> or
     * <code>NVARCHAR</code> or <code>LONGNVARCHAR</code>
     * @param parameterName the name of the parameter to be set
     * @param value the parameter value
     * @throws SQLException if parameterName does not correspond to a named
     * parameter; if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void setNString(String parameterName, String value)
            throws SQLException
  {
    setNString(findParam(parameterName), value);
  }

    /**
     * Sets the designated parameter to a <code>Reader</code> object. The
     * <code>Reader</code> reads the data till end-of-file is reached. The
     * driver does the necessary conversion from Java character format to
     * the national character set in the database.
     * @param parameterName the name of the parameter to be set
     * @param value the parameter value
     * @param length the number of characters in the parameter data.
     * @throws SQLException if parameterName does not correspond to a named
     * parameter; if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void setNCharacterStream(String parameterName, Reader value, long length)
            throws SQLException
  {
    setNCharacterStream(findParam(parameterName), value, length);
  }

     /**
     * Sets the designated parameter to a <code>java.sql.NClob</code> object. The object
     * implements the <code>java.sql.NClob</code> interface. This <code>NClob</code>
     * object maps to a SQL <code>NCLOB</code>.
     * @param parameterName the name of the parameter to be set
     * @param value the parameter value
     * @throws SQLException if parameterName does not correspond to a named
     * parameter; if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void setNClob(String parameterName, NClob value) throws SQLException
  {
    setNClob(findParam(parameterName), value);
  }

    /**
     * Sets the designated parameter to a <code>Reader</code> object.  The <code>reader</code> must contain  the number
     * of characters specified by length otherwise a <code>SQLException</code> will be
     * generated when the <code>CallableStatement</code> is executed.
     * This method differs from the <code>setCharacterStream (int, Reader, int)</code> method
     * because it informs the driver that the parameter value should be sent to
     * the server as a <code>CLOB</code>.  When the <code>setCharacterStream</code> method is used, the
     * driver may have to do extra work to determine whether the parameter
     * data should be send to the server as a <code>LONGVARCHAR</code> or a <code>CLOB</code>
     * @param parameterName the name of the parameter to be set
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @throws SQLException if parameterName does not correspond to a named
     * parameter; if the length specified is less than zero;
     * a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     *
     * @since 1.6
     */
  public void setClob(String parameterName, Reader reader, long length)
       throws SQLException
  {
    setClob(findParam(parameterName), reader, length);
  }

    /**
     * Sets the designated parameter to a <code>InputStream</code> object.  The <code>inputstream</code> must contain  the number
     * of characters specified by length, otherwise a <code>SQLException</code> will be
     * generated when the <code>CallableStatement</code> is executed.
     * This method differs from the <code>setBinaryStream (int, InputStream, int)</code>
     * method because it informs the driver that the parameter value should be
     * sent to the server as a <code>BLOB</code>.  When the <code>setBinaryStream</code> method is used,
     * the driver may have to do extra work to determine whether the parameter
     * data should be sent to the server as a <code>LONGVARBINARY</code> or a <code>BLOB</code>
     *
     * @param parameterName the name of the parameter to be set
     * the second is 2, ...
     *
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @param length the number of bytes in the parameter data.
     * @throws SQLException  if parameterName does not correspond to a named
     * parameter; if the length specified
     * is less than zero; if the number of bytes in the inputstream does not match
     * the specfied length; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     *
     * @since 1.6
     */
  public void setBlob(String parameterName, InputStream inputStream, long length)
        throws SQLException
  {
    setBlob(findParam(parameterName), inputStream, length);
  }
    /**
     * Sets the designated parameter to a <code>Reader</code> object.  The <code>reader</code> must contain  the number
     * of characters specified by length otherwise a <code>SQLException</code> will be
     * generated when the <code>CallableStatement</code> is executed.
     * This method differs from the <code>setCharacterStream (int, Reader, int)</code> method
     * because it informs the driver that the parameter value should be sent to
     * the server as a <code>NCLOB</code>.  When the <code>setCharacterStream</code> method is used, the
     * driver may have to do extra work to determine whether the parameter
     * data should be send to the server as a <code>LONGNVARCHAR</code> or a <code>NCLOB</code>
     *
     * @param parameterName the name of the parameter to be set
     * @param reader An object that contains the data to set the parameter value to.
     * @param length the number of characters in the parameter data.
     * @throws SQLException if parameterName does not correspond to a named
     * parameter; if the length specified is less than zero;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void setNClob(String parameterName, Reader reader, long length)
       throws SQLException
  {
    setNClob(findParam(parameterName), reader, length);
  }

    /**
     * Retrieves the value of the designated JDBC <code>NCLOB</code> parameter as a
     * <code>java.sql.NClob</code> object in the Java programming language.
     *
     * @param parameterIndex the first parameter is 1, the second is 2, and
     * so on
     * @return the parameter value as a <code>NClob</code> object in the
     * Java programming language.  If the value was SQL <code>NULL</code>, the
     * value <code>null</code> is returned.
     * @exception SQLException if the parameterIndex is not valid;
     * if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public NClob getNClob (int parameterIndex) throws SQLException
  {
    return new OPLHeapNClob(getString(parameterIndex));
  }


    /**
     * Retrieves the value of a JDBC <code>NCLOB</code> parameter as a
     * <code>java.sql.NClob</code> object in the Java programming language.
     * @param parameterName the name of the parameter
     * @return the parameter value as a <code>NClob</code> object in the
     *         Java programming language.  If the value was SQL <code>NULL</code>,
     *         the value <code>null</code> is returned.
     * @exception SQLException if parameterName does not correspond to a named
     * parameter; if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public NClob getNClob (String parameterName) throws SQLException
  {
    return getNClob(findParam(parameterName));
  }

    /**
     * Sets the designated parameter to the given <code>java.sql.SQLXML</code> object. The driver converts this to an
     * <code>SQL XML</code> value when it sends it to the database.
     *
     * @param parameterName the name of the parameter
     * @param xmlObject a <code>SQLXML</code> object that maps an <code>SQL XML</code> value
     * @throws SQLException if parameterName does not correspond to a named
     * parameter; if a database access error occurs;
     * this method is called on a closed <code>CallableStatement</code> or
     * the <code>java.xml.transform.Result</code>,
     *  <code>Writer</code> or <code>OutputStream</code> has not been closed for the <code>SQLXML</code> object
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     *
     * @since 1.6
     */
  public void setSQLXML(String parameterName, SQLXML xmlObject) throws SQLException
  {
    throw new VirtuosoException ("Method 'setSQLXML(parameterName, xmlObject)' not yet implemented", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Retrieves the value of the designated <code>SQL XML</code> parameter as a
     * <code>java.sql.SQLXML</code> object in the Java programming language.
     * @param parameterIndex index of the first parameter is 1, the second is 2, ...
     * @return a <code>SQLXML</code> object that maps an <code>SQL XML</code> value
     * @throws SQLException if the parameterIndex is not valid;
     * if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public SQLXML getSQLXML(int parameterIndex) throws SQLException
  {
    throw new VirtuosoException ("Method 'getSQLXML(int parameterIndex)' not yet implemented", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Retrieves the value of the designated <code>SQL XML</code> parameter as a
     * <code>java.sql.SQLXML</code> object in the Java programming language.
     * @param parameterName the name of the parameter
     * @return a <code>SQLXML</code> object that maps an <code>SQL XML</code> value
     * @throws SQLException if parameterName does not correspond to a named
     * parameter; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public SQLXML getSQLXML(String parameterName) throws SQLException
  {
    throw new VirtuosoException ("Method 'getSQLXML(String parameterName)' not yet implemented", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Retrieves the value of the designated <code>NCHAR</code>,
     * <code>NVARCHAR</code>
     * or <code>LONGNVARCHAR</code> parameter as
     * a <code>String</code> in the Java programming language.
     *  <p>
     * For the fixed-length type JDBC <code>NCHAR</code>,
     * the <code>String</code> object
     * returned has exactly the same value the SQL
     * <code>NCHAR</code> value had in the
     * database, including any padding added by the database.
     *
     * @param parameterIndex index of the first parameter is 1, the second is 2, ...
     * @return a <code>String</code> object that maps an
     * <code>NCHAR</code>, <code>NVARCHAR</code> or <code>LONGNVARCHAR</code> value
     * @exception SQLException if the parameterIndex is not valid;
     * if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     * @see #setNString
     */
  public String getNString(int parameterIndex) throws SQLException
  {
    return getString(parameterIndex);
  }


    /**
     *  Retrieves the value of the designated <code>NCHAR</code>,
     * <code>NVARCHAR</code>
     * or <code>LONGNVARCHAR</code> parameter as
     * a <code>String</code> in the Java programming language.
     * <p>
     * For the fixed-length type JDBC <code>NCHAR</code>,
     * the <code>String</code> object
     * returned has exactly the same value the SQL
     * <code>NCHAR</code> value had in the
     * database, including any padding added by the database.
     *
     * @param parameterName the name of the parameter
     * @return a <code>String</code> object that maps an
     * <code>NCHAR</code>, <code>NVARCHAR</code> or <code>LONGNVARCHAR</code> value
     * @exception SQLException if parameterName does not correspond to a named
     * parameter;
     * if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     * @see #setNString
     */
  public String getNString(String parameterName) throws SQLException
  {
    return getNString(findParam(parameterName));
  }

    /**
     * Retrieves the value of the designated parameter as a
     * <code>java.io.Reader</code> object in the Java programming language.
     * It is intended for use when
     * accessing  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> parameters.
     *
     * @return a <code>java.io.Reader</code> object that contains the parameter
     * value; if the value is SQL <code>NULL</code>, the value returned is
     * <code>null</code> in the Java programming language.
     * @param parameterIndex the first parameter is 1, the second is 2, ...
     * @exception SQLException if the parameterIndex is not valid;
     * if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public java.io.Reader getNCharacterStream(int parameterIndex) throws SQLException
  {
    return (new OPLHeapNClob(getNString(parameterIndex))).getCharacterStream();
  }

    /**
     * Retrieves the value of the designated parameter as a
     * <code>java.io.Reader</code> object in the Java programming language.
     * It is intended for use when
     * accessing  <code>NCHAR</code>,<code>NVARCHAR</code>
     * and <code>LONGNVARCHAR</code> parameters.
     *
     * @param parameterName the name of the parameter
     * @return a <code>java.io.Reader</code> object that contains the parameter
     * value; if the value is SQL <code>NULL</code>, the value returned is
     * <code>null</code> in the Java programming language
     * @exception SQLException if parameterName does not correspond to a named
     * parameter; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public java.io.Reader getNCharacterStream(String parameterName) throws SQLException
  {
    return getNCharacterStream(findParam(parameterName));
  }

    /**
     * Retrieves the value of the designated parameter as a
     * <code>java.io.Reader</code> object in the Java programming language.
     *
     * @return a <code>java.io.Reader</code> object that contains the parameter
     * value; if the value is SQL <code>NULL</code>, the value returned is
     * <code>null</code> in the Java programming language.
     * @param parameterIndex the first parameter is 1, the second is 2, ...
     * @exception SQLException if the parameterIndex is not valid; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @since 1.6
     */
  public java.io.Reader getCharacterStream(int parameterIndex) throws SQLException
  {
    return (new OPLHeapClob(getString(parameterIndex))).getCharacterStream();
  }

    /**
     * Retrieves the value of the designated parameter as a
     * <code>java.io.Reader</code> object in the Java programming language.
     *
     * @param parameterName the name of the parameter
     * @return a <code>java.io.Reader</code> object that contains the parameter
     * value; if the value is SQL <code>NULL</code>, the value returned is
     * <code>null</code> in the Java programming language
     * @exception SQLException if parameterName does not correspond to a named
     * parameter; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public java.io.Reader getCharacterStream(String parameterName) throws SQLException
  {
    return getCharacterStream(findParam(parameterName));
  }

    /**
     * Sets the designated parameter to the given <code>java.sql.Blob</code> object.
     * The driver converts this to an SQL <code>BLOB</code> value when it
     * sends it to the database.
     *
     * @param parameterName the name of the parameter
     * @param x a <code>Blob</code> object that maps an SQL <code>BLOB</code> value
     * @exception SQLException if parameterName does not correspond to a named
     * parameter; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void setBlob (String parameterName, Blob x) throws SQLException
  {
    setBlob(findParam(parameterName), x);
  }

    /**
     * Sets the designated parameter to the given <code>java.sql.Clob</code> object.
     * The driver converts this to an SQL <code>CLOB</code> value when it
     * sends it to the database.
     *
     * @param parameterName the name of the parameter
     * @param x a <code>Clob</code> object that maps an SQL <code>CLOB</code> value
     * @exception SQLException if parameterName does not correspond to a named
     * parameter; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void setClob (String parameterName, Clob x) throws SQLException
  {
    setClob(findParam(parameterName), x);
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
     * @param parameterName the name of the parameter
     * @param x the Java input stream that contains the ASCII parameter value
     * @param length the number of bytes in the stream
     * @exception SQLException if parameterName does not correspond to a named
     * parameter; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void setAsciiStream(String parameterName, java.io.InputStream x, long length)
	throws SQLException
  {
    setAsciiStream(findParam(parameterName), x, (int)length);
  }

    /**
     * Sets the designated parameter to the given input stream, which will have
     * the specified number of bytes.
     * When a very large binary value is input to a <code>LONGVARBINARY</code>
     * parameter, it may be more practical to send it via a
     * <code>java.io.InputStream</code> object. The data will be read from the stream
     * as needed until end-of-file is reached.
     *
     * <P><B>Note:</B> This stream object can either be a standard
     * Java stream object or your own subclass that implements the
     * standard interface.
     *
     * @param parameterName the name of the parameter
     * @param x the java input stream which contains the binary parameter value
     * @param length the number of bytes in the stream
     * @exception SQLException if parameterName does not correspond to a named
     * parameter; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void setBinaryStream(String parameterName, java.io.InputStream x,
			 long length) throws SQLException
  {
    setBinaryStream(findParam(parameterName), x, (int)length);
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
     * @param parameterName the name of the parameter
     * @param reader the <code>java.io.Reader</code> object that
     *        contains the UNICODE data used as the designated parameter
     * @param length the number of characters in the stream
     * @exception SQLException if parameterName does not correspond to a named
     * parameter; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void setCharacterStream(String parameterName,
			    java.io.Reader reader,
			    long length) throws SQLException
  {
    setCharacterStream(findParam(parameterName), reader, (int)length);
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
     * @param parameterName the name of the parameter
     * @param x the Java input stream that contains the ASCII parameter value
     * @exception SQLException if parameterName does not correspond to a named
     * parameter; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
       * @since 1.6
    */
  public void setAsciiStream(String parameterName, java.io.InputStream x)
	    throws SQLException
  {
    throw new VirtuosoException ("Method 'setAsciiStream(parameterName, x)' not yet implemented", VirtuosoException.NOTIMPLEMENTED);
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
     * @param parameterName the name of the parameter
     * @param x the java input stream which contains the binary parameter value
     * @exception SQLException if parameterName does not correspond to a named
     * parameter; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public void setBinaryStream(String parameterName, java.io.InputStream x)
    throws SQLException
  {
    throw new VirtuosoException ("Method 'setBinaryStream(parameterName, x)' not yet implemented", VirtuosoException.NOTIMPLEMENTED);
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
     * @param parameterName the name of the parameter
     * @param reader the <code>java.io.Reader</code> object that contains the
     *        Unicode data
     * @exception SQLException if parameterName does not correspond to a named
     * parameter; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public void setCharacterStream(String parameterName,
       			  java.io.Reader reader) throws SQLException
  {
    throw new VirtuosoException ("Method 'setCharacterStream(parameterName, reader)' not yet implemented", VirtuosoException.NOTIMPLEMENTED);
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
     * @param parameterName the name of the parameter
     * @param value the parameter value
     * @throws SQLException if parameterName does not correspond to a named
     * parameter; if the driver does not support national
     *         character sets;  if the driver can detect that a data conversion
     *  error could occur; if a database access error occurs; or
     * this method is called on a closed <code>CallableStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public void setNCharacterStream(String parameterName, Reader value) throws SQLException
  {
    throw new VirtuosoException ("Method 'setNCharacterStream(parameterName, value)' not yet implemented", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Sets the designated parameter to a <code>Reader</code> object.
     * This method differs from the <code>setCharacterStream (int, Reader)</code> method
     * because it informs the driver that the parameter value should be sent to
     * the server as a <code>CLOB</code>.  When the <code>setCharacterStream</code> method is used, the
     * driver may have to do extra work to determine whether the parameter
     * data should be send to the server as a <code>LONGVARCHAR</code> or a <code>CLOB</code>
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>setClob</code> which takes a length parameter.
     *
     * @param parameterName the name of the parameter
     * @param reader An object that contains the data to set the parameter value to.
     * @throws SQLException if parameterName does not correspond to a named
     * parameter; if a database access error occurs or this method is called on
     * a closed <code>CallableStatement</code>
     *
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     * @since 1.6
     */
  public void setClob(String parameterName, Reader reader)
       throws SQLException
  {
    throw new VirtuosoException ("Method 'setClob(parameterName, reader)' not yet implemented", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Sets the designated parameter to a <code>InputStream</code> object.
     * This method differs from the <code>setBinaryStream (int, InputStream)</code>
     * method because it informs the driver that the parameter value should be
     * sent to the server as a <code>BLOB</code>.  When the <code>setBinaryStream</code> method is used,
     * the driver may have to do extra work to determine whether the parameter
     * data should be send to the server as a <code>LONGVARBINARY</code> or a <code>BLOB</code>
     *
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>setBlob</code> which takes a length parameter.
     *
     * @param parameterName the name of the parameter
     * @param inputStream An object that contains the data to set the parameter
     * value to.
     * @throws SQLException if parameterName does not correspond to a named
     * parameter; if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     *
     * @since 1.6
     */
  public void setBlob(String parameterName, InputStream inputStream)
        throws SQLException
  {
    throw new VirtuosoException ("Method 'setBlob(parameterName, inputStream)' not yet implemented", VirtuosoException.NOTIMPLEMENTED);
  }

    /**
     * Sets the designated parameter to a <code>Reader</code> object.
     * This method differs from the <code>setCharacterStream (int, Reader)</code> method
     * because it informs the driver that the parameter value should be sent to
     * the server as a <code>NCLOB</code>.  When the <code>setCharacterStream</code> method is used, the
     * driver may have to do extra work to determine whether the parameter
     * data should be send to the server as a <code>LONGNVARCHAR</code> or a <code>NCLOB</code>
     * <P><B>Note:</B> Consult your JDBC driver documentation to determine if
     * it might be more efficient to use a version of
     * <code>setNClob</code> which takes a length parameter.
     *
     * @param parameterName the name of the parameter
     * @param reader An object that contains the data to set the parameter value to.
     * @throws SQLException if parameterName does not correspond to a named
     * parameter; if the driver does not support national character sets;
     * if the driver can detect that a data conversion
     *  error could occur;  if a database access error occurs or
     * this method is called on a closed <code>CallableStatement</code>
     * @throws SQLFeatureNotSupportedException  if the JDBC driver does not support this method
     *
     * @since 1.6
     */
  public void setNClob(String parameterName, Reader reader)
       throws SQLException
  {
    throw new VirtuosoException ("Method 'setNClob(parameterName, reader)' not yet implemented", VirtuosoException.NOTIMPLEMENTED);
  }


#if JDK_VER >= 17
    //------------------------- JDBC 4.1 -----------------------------------
    /**
     *<p>Returns an object representing the value of OUT parameter
     * {@code parameterIndex} and will convert from the
     * SQL type of the parameter to the requested Java data type, if the
     * conversion is supported. If the conversion is not
     * supported or null is specified for the type, a
     * <code>SQLException</code> is thrown.
     *<p>
     * At a minimum, an implementation must support the conversions defined in
     * Appendix B, Table B-3 and conversion of appropriate user defined SQL
     * types to a Java type which implements {@code SQLData}, or {@code Struct}.
     * Additional conversions may be supported and are vendor defined.
     *
     * @param parameterIndex the first parameter is 1, the second is 2, and so on
     * @param type Class representing the Java data type to convert the
     * designated parameter to.
     * @return an instance of {@code type} holding the OUT parameter value
     * @throws SQLException if conversion is not supported, type is null or
     *         another error occurs. The getCause() method of the
     * exception may provide a more detailed exception, for example, if
     * a conversion error occurs
     * @throws SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.7
     */
  public <T> T getObject(int parameterIndex, Class<T> type) throws SQLException
  {
    if (type == null) {
      throw new VirtuosoException ("Type parameter can not be null", 
                    "S1009", VirtuosoException.BADPARAM);
    }
		
    if (type.equals(String.class)) {
      return (T) getString(parameterIndex);
    } else if (type.equals(BigDecimal.class)) {
      return (T) getBigDecimal(parameterIndex);
    } else if (type.equals(Boolean.class) || type.equals(Boolean.TYPE)) {
      return (T) Boolean.valueOf(getBoolean(parameterIndex));
    } else if (type.equals(Integer.class) || type.equals(Integer.TYPE)) {
      return (T) Integer.valueOf(getInt(parameterIndex));
    } else if (type.equals(Long.class) || type.equals(Long.TYPE)) {
      return (T) Long.valueOf(getLong(parameterIndex));
    } else if (type.equals(Float.class) || type.equals(Float.TYPE)) {
      return (T) Float.valueOf(getFloat(parameterIndex));
    } else if (type.equals(Double.class) || type.equals(Double.TYPE)) {
      return (T) Double.valueOf(getDouble(parameterIndex));
    } else if (type.equals(byte[].class)) {
      return (T) getBytes(parameterIndex);
    } else if (type.equals(java.sql.Date.class)) {
      return (T) getDate(parameterIndex);
    } else if (type.equals(Time.class)) {
      return (T) getTime(parameterIndex);
    } else if (type.equals(Timestamp.class)) {
      return (T) getTimestamp(parameterIndex);
    } else if (type.equals(Clob.class)) {
      return (T) getClob(parameterIndex);
    } else if (type.equals(Blob.class)) {
      return (T) getBlob(parameterIndex);
    } else if (type.equals(Array.class)) {
      return (T) getArray(parameterIndex);
    } else if (type.equals(Ref.class)) {
      return (T) getRef(parameterIndex);
    } else if (type.equals(java.net.URL.class)) {
      return (T) getURL(parameterIndex);
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
        return (T) getObject(parameterIndex);
      } catch (ClassCastException cce) {
         throw new VirtuosoException ("Conversion not supported for type " + type.getName(), 
                    "S1009", VirtuosoException.BADPARAM);
      }
    }
  }


    /**
     *<p>Returns an object representing the value of OUT parameter
     * {@code parameterName} and will convert from the
     * SQL type of the parameter to the requested Java data type, if the
     * conversion is supported. If the conversion is not
     * supported  or null is specified for the type, a
     * <code>SQLException</code> is thrown.
     *<p>
     * At a minimum, an implementation must support the conversions defined in
     * Appendix B, Table B-3 and conversion of appropriate user defined SQL
     * types to a Java type which implements {@code SQLData}, or {@code Struct}.
     * Additional conversions may be supported and are vendor defined.
     *
     * @param parameterName the name of the parameter
     * @param type Class representing the Java data type to convert
     * the designated parameter to.
     * @return an instance of {@code type} holding the OUT parameter
     * value
     * @throws SQLException if conversion is not supported, type is null or
     *         another error occurs. The getCause() method of the
     * exception may provide a more detailed exception, for example, if
     * a conversion error occurs
     * @throws SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.7
     */
  public <T> T getObject(String parameterName, Class<T> type) throws SQLException
  {
    return getObject(findParam(parameterName), type);
  }


#endif

#endif
#endif
}
