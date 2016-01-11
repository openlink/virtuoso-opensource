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
import java.util.*;
import openlink.util.*;

/**
 * The VirtuosoResultSetMetaData class is an implementation of the ResultSetMetaData
 * interface in the JDBC API that represents information about a ResultSet.
 * You can obtain one like below :
 * <pre>
 *   <code>ResultSetMetaData metadata = resultset.getMetaData()</code>
 * </pre>
 *
 * @version 1.0 (JDBC API 2.0 implementation)
 * @see java.sql.ResultSetMetaData
 * @see virtuoso.jdbc2.VirtuosoResultSet#getMetaData
 */
public class VirtuosoResultSetMetaData implements ResultSetMetaData
{
   // Hash table to sort columns by their names
#if JDK_VER >= 16
   protected Hashtable<VirtuosoColumn,Integer> hcolumns;
#else
   protected Hashtable hcolumns;
#endif

   // Description of columns
   private openlink.util.Vector columnsMetaData = new openlink.util.Vector(10,20);

   /**
    * Constructs a new VirtuosoResultSetMetaData.
    *
    * @param args      The column description in the DV format.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   protected VirtuosoResultSetMetaData (VirtuosoConnection conn, String [] columns, int [] dtps)
   {
      // Create the hash table
#if JDK_VER >= 16
      hcolumns = new Hashtable<VirtuosoColumn,Integer>();
#else
      hcolumns = new Hashtable();
#endif
      // Process args in DV format
      for(int i = 0;i < columns.length;i++)
      {
         // Create the new column
         VirtuosoColumn col = new VirtuosoColumn(columns[i], dtps[i], conn);
         hcolumns.put(col,new Integer(i));
         columnsMetaData.insertElementAt(col,i);
      }
   }

   VirtuosoResultSetMetaData(openlink.util.Vector args, VirtuosoConnection conn) throws VirtuosoException
   {
      if(args == null)
         return;
      // Get columns metadata from args
      Object v = ((openlink.util.Vector)args).firstElement();
      openlink.util.Vector vect = null;
      if (v instanceof openlink.util.Vector)
         vect = (openlink.util.Vector)v;
      else
         return;
      // Create the hash table
#if JDK_VER >= 16
      hcolumns = new Hashtable<VirtuosoColumn,Integer>();
#else
      hcolumns = new Hashtable();
#endif
      // Process args in DV format
      for(int i = 0;i < vect.size();i++)
      {
         // Create the new column
         VirtuosoColumn col =
	     new VirtuosoColumn((openlink.util.Vector)((openlink.util.Vector)vect).elementAt(i),
		 conn);
         hcolumns.put(col,new Integer(i));
         columnsMetaData.insertElementAt(col,i);
      }
   }

   /**
    * Method runs when the garbage collector want to erase the object
    */
   public void finalize() throws Throwable
   {
      close();
   }

   // --------------------------- JDBC 1.0 ------------------------------
   /**
    * Returns the number of columns in the ResultSet.
    *
    * @return int   The number of columns.
    * @exception virtuoso.jdbc2.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.ResultSetMetaData#getColumnCount
    */
   public int getColumnCount() throws VirtuosoException
   {
      return columnsMetaData.size();
   }

   /**
    * Indicates whether the column is automatically numbered, thus read-only.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return boolean   True if so.
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSetMetaData#isAutoIncrement
    */
   public boolean isAutoIncrement(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > columnsMetaData.size())
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + columnsMetaData.size(),VirtuosoException.BADPARAM);
      // Treat the method
      return ((VirtuosoColumn)(columnsMetaData.elementAt(column - 1))).isAutoIncrement();
   }

   /**
    * Indicates whether a column's case matters.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return boolean   True if so.
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSetMetaData#isCaseSensitive
    */
   public boolean isCaseSensitive(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > columnsMetaData.size())
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + columnsMetaData.size(),VirtuosoException.BADPARAM);
      // Treat the method
      return ((VirtuosoColumn)(columnsMetaData.elementAt(column - 1))).isCaseSensitive();
   }

   /**
    * Indicates whether the column can be used in a where clause.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return boolean   True if so.
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSetMetaData#isSearchable
    */
   public boolean isSearchable(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > columnsMetaData.size())
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + columnsMetaData.size(),VirtuosoException.BADPARAM);
      // Treat the method
      return ((VirtuosoColumn)(columnsMetaData.elementAt(column - 1))).isSearchable();
   }

   /**
    * Indicates whether the column is a cash value.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return boolean   True if so.
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSetMetaData#isCurrency
    */
   public boolean isCurrency(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > columnsMetaData.size())
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + columnsMetaData.size(),VirtuosoException.BADPARAM);
      // Treat the method
      return ((VirtuosoColumn)(columnsMetaData.elementAt(column - 1))).isCurrency();
   }

   /**
    * Indicates the nullability of values in the designated column.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return the nullability status of the given column; one of columnNoNulls,
    *          columnNullable or columnNullableUnknown
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSetMetaData#isNullable
    */
   public int isNullable(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > columnsMetaData.size())
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + columnsMetaData.size(),VirtuosoException.BADPARAM);
      // Treat the method
      return ((VirtuosoColumn)(columnsMetaData.elementAt(column - 1))).isNullable();
   }

   /**
    * Indicates whether values in the column are signed numbers.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return boolean   True if so.
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSetMetaData#isSigned
    */
   public boolean isSigned(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > columnsMetaData.size())
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + columnsMetaData.size(),VirtuosoException.BADPARAM);
      // Treat the method
      return ((VirtuosoColumn)(columnsMetaData.elementAt(column - 1))).isSigned();
   }

   /**
    * Indicates the column's normal max width in chars.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return the normal maximum number of characters allowed as the width
    *          of the designated column
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSetMetaData#getColumnDisplaySize
    */
   public int getColumnDisplaySize(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > columnsMetaData.size())
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + columnsMetaData.size(),VirtuosoException.BADPARAM);
      // Treat the method
      return ((VirtuosoColumn)(columnsMetaData.elementAt(column - 1))).getColumnDisplaySize();
   }

   /**
    * Gets the suggested column title for use in printouts and
    * displays.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return String The suggested column title.
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSetMetaData#getColumnLabel
    */
   public String getColumnLabel(int column) throws VirtuosoException
   {
      return getColumnName(column);
   }

   /**
    * Gets a column's name.
    *
    * @param column the first column is 1, the second is 2, ...
    * @returnString  The column name.
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSetMetaData#getColumnName
    */
   public String getColumnName(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > columnsMetaData.size())
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + columnsMetaData.size(),VirtuosoException.BADPARAM);
      // Treat the method
      return ((VirtuosoColumn)(columnsMetaData.elementAt(column - 1))).getColumnName();
   }

   public void setColumnName(int column, String name) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > columnsMetaData.size())
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + columnsMetaData.size(),VirtuosoException.BADPARAM);
      // Treat the method
      ((VirtuosoColumn)(columnsMetaData.elementAt(column - 1))).setColumnName(name);
   }

   /**
    * Gets a column's number of decimal digits.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return int The column's precision.
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSetMetaData#getPrecision
    */
   public int getPrecision(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > columnsMetaData.size())
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + columnsMetaData.size(),VirtuosoException.BADPARAM);
      // Treat the method
      return ((VirtuosoColumn)(columnsMetaData.elementAt(column - 1))).getPrecision();
   }

   /**
    * Gets a column's number of digits to right of the decimal point.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return int The column's scale.
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSetMetaData#getScale
    */
   public int getScale(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > columnsMetaData.size())
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + columnsMetaData.size(),VirtuosoException.BADPARAM);
      // Treat the method
      return ((VirtuosoColumn)(columnsMetaData.elementAt(column - 1))).getScale();
   }

   /**
    * Retrieves a column's SQL type.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return int SQL type.
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSetMetaData#getColumnType
    * @see java.sql.Types
    */
   public int getColumnType(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > columnsMetaData.size())
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + columnsMetaData.size(),VirtuosoException.BADPARAM);
      // Treat the method
      return ((VirtuosoColumn)(columnsMetaData.elementAt(column - 1))).getColumnType();
   }

   /**
    * Retrieves a column's database-specific type name.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return type name used by the database. If the column type is
    * a user-defined type, then a fully-qualified type name is returned.
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSetMetaData#getColumnTypeName
    */
   public String getColumnTypeName(int column) throws VirtuosoException
   {
      if(column < 1 || column > columnsMetaData.size())
         throw new VirtuosoException(
		 "Bad column number : " + column + " not in 1<n<" + columnsMetaData.size(),
		 VirtuosoException.BADPARAM);

     VirtuosoColumn c = (VirtuosoColumn)columnsMetaData.elementAt(column - 1);
     if (c.isXml ())
        return "XMLType";

     return _getColumnTypeName (getColumnType(column));
   }

   protected static String _getColumnTypeName(int columnType) throws VirtuosoException
   {
      switch(columnType)
      {
         case Types.ARRAY:
            return "ARRAY";
         case Types.BIGINT:
            return "BIGINT";
         case Types.BINARY:
            return "BINARY";
         case Types.BIT:
            return "BIT";
         case Types.BLOB:
            return "BLOB";
         case Types.CHAR:
            return "CHAR";
         case Types.CLOB:
            return "CLOB";
         case Types.DATE:
            return "DATE";
         case Types.DECIMAL:
            return "DECIMAL";
         case Types.DISTINCT:
            return "DISTINCT";
         case Types.DOUBLE:
            return "DOUBLE PRECISION";
         case Types.FLOAT:
            return "FLOAT";
         case Types.INTEGER:
            return "INTEGER";
         case Types.JAVA_OBJECT:
            return "JAVA_OBJECT";
         case Types.LONGVARBINARY:
            return "LONG VARBINARY";
         case Types.LONGVARCHAR:
            return "LONG VARCHAR";
         case Types.NULL:
            return "NULL";
         case Types.NUMERIC:
            return "NUMERIC";
         case Types.OTHER:
            return "OTHER";
         case Types.REAL:
            return "REAL";
         case Types.SMALLINT:
            return "SMALLINT";
         case Types.STRUCT:
            return "STRUCT";
         case Types.TIME:
            return "TIME";
         case Types.TIMESTAMP:
            return "TIMESTAMP";
         case Types.TINYINT:
            return "TINYINT";
         case Types.VARBINARY:
            return "VARBINARY";
         case Types.VARCHAR:
            return "VARCHAR";
	 case -9:
	    return "NVARCHAR";
	 case -10:
	    return "LONG NVARCHAR";
      }
      ;
      return "";
   }

   /**
    * Indicates whether a column is definitely not writable.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return boolean   True if so.
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSetMetaData#isReadOnly
    */
   public boolean isReadOnly(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > columnsMetaData.size())
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + columnsMetaData.size(),VirtuosoException.BADPARAM);
      // Treat the method
      return !((VirtuosoColumn)(columnsMetaData.elementAt(column - 1))).isUpdateable();
   }

   /**
    * Indicates whether it is possible for a write on the column to succeed.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return boolean   True if so.
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSetMetaData#isWritable
    */
   public boolean isWritable(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > columnsMetaData.size())
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + columnsMetaData.size(),VirtuosoException.BADPARAM);
      // Treat the method
      return ((VirtuosoColumn)(columnsMetaData.elementAt(column - 1))).isUpdateable();
   }

   /**
    * Indicates whether a write on the column will definitely succeed.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return boolean   True if so.
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSetMetaData#isDefinitelyWritable
    */
   public boolean isDefinitelyWritable(int column) throws VirtuosoException
   {
      return isWritable(column);
   }

   /**
    * Returns the fully-qualified name of the Java class.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return the fully-qualified name of the class in the Java programming
    *         language that would be used by the method
    * @exception virtuoso.jdbc2.VirtuosoException If an internal error occurred.
    * @see java.sql.ResultSetMetaData#getColumnClassName
    */
   public String getColumnClassName(int column) throws VirtuosoException
   {
      // Get and check parameter
      if(column < 1 || column > columnsMetaData.size())
         throw new VirtuosoException("Bad column number : " + column + " not in 1<n<" + columnsMetaData.size(),VirtuosoException.BADPARAM);
      // Treat the method
      return ((VirtuosoColumn)(columnsMetaData.elementAt(column - 1))).getColumnClassName();
   }

   /**
    * Gets a column's table's schema.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return schema name or "" if not applicable
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public String getSchemaName(int column) throws VirtuosoException
   {
      return "";
   }

   /**
    * Gets a column's table name.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return table name or "" if not applicable
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public String getTableName(int column) throws VirtuosoException
   {
      return "";
   }

   /**
    * Gets a column's table's catalog name.
    *
    * @param column the first column is 1, the second is 2, ...
    * @return column name or "" if not applicable.
    * @exception virtuoso.jdbc2.VirtuosoException if a database access error occurs
    */
   public String getCatalogName(int column) throws VirtuosoException
   {
      return "";
   }

   /**
    * Releases this ResultSetMetaData object's database and
    * JDBC resources immediately instead of new wait for
    * this to happen when it is automatically closed.
    *
    * Note: A ResultSetMetaData is automatically closed by the
    * ResultSet that generated it when that ResultSet is closed.
    *
    * @exception virtuoso.jdbc.VirtuosoException  An internal error occurred.
    */
   public void close() throws VirtuosoException
   {
      if(hcolumns != null)
      {
         hcolumns.clear();
         hcolumns = null;
      }
      if(columnsMetaData != null)
      {
         columnsMetaData.removeAllElements();
         columnsMetaData = null;
      }
   }

   protected int getColumnDtp (int column)
     {
       if(column < 1 || column > columnsMetaData.size())
	 return 0;
       else
	 return ((VirtuosoColumn)(columnsMetaData.elementAt(column - 1))).getDtp();
     }

   protected boolean isXml (int column)
     {
       if(column < 1 || column > columnsMetaData.size())
	 return false;
       else
	 return ((VirtuosoColumn)(columnsMetaData.elementAt(column - 1))).isXml();
     }


#if JDK_VER >= 16
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
#endif

}

