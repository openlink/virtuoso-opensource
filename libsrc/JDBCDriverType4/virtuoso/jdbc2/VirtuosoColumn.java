/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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
 * The VirtuosoColumn class is designed to store and retrieve meta data
 * about a column in a table.
 *
 * @version 1.0 (JDBC API 2.0 implementation)
 */
class VirtuosoColumn
{
   // The type of object stored by this column
   private int typeObject;

   // The column's name
   private String name;

   // The SQL type corresponding to this column
   private int typeSQL;

   // The column's normal max width in chars
   private int length;

   // The column's scale
   private int scale;

   // The column's precision
   private int precision;

   // The column's auto increment flag
   private boolean isAutoIncrement = false;

   // The column's case sensitive flag
   private boolean isCaseSensitive = false;

   // The column's currency flag
   private boolean isCurrency = false;

   // The column's nullable flag
   private int isNullable = ResultSetMetaData.columnNullable;

   // The column's searchable flag
   private boolean isSearchable = false;

   // The column's updateable flag
   private boolean isUpdateable = false;

   // The column's signed flag
   private boolean isSigned = false;

   // The case mode
   private int _case;

   // XML wrapped into DV_.*WIDE
   private boolean _isXml = false;

   /**
    * Construct a new VirtuosoColumn class which stores only the column's name.
    * (Useful to use equals and hashCode without others parameters).
    *
    * @param String  The column's name.
    */
   VirtuosoColumn(String name, int dtp, VirtuosoConnection connection)
   {
      // Set column's name
      this.name = name;
      this._case = connection.getCase();
      this.typeObject = dtp;
   }

   /**
    * Construct a new VirtuosoColumn class which stores meta data about
    * a column in a ResultSet.
    *
    * @param Vector  Description about the column.
    * @exception VirtuosoException   An internal error occurred.
    */
   VirtuosoColumn(openlink.util.Vector args, VirtuosoConnection connection)
   {
      try
      {
         // Set variables
	 if (connection.charset != null)
	   name = connection.uncharsetBytes((String)args.firstElement());
	 else if (connection.utf8_execs)
	   name = new String (((String)args.firstElement()).getBytes("8859_1"), "UTF8");
	 else
	   name = (String)args.firstElement();
         if (null != args.elementAt(1))
	   typeObject = ((Number)args.elementAt(1)).intValue();
         else
           typeObject = VirtuosoTypes.DV_STRING;
         if( args.elementAt(2)!=null)
         length = scale = ((Number)args.elementAt(2)).intValue();
         if( args.elementAt(3)!=null)
         precision = ((Number)args.elementAt(3)).intValue();
         if( args.elementAt(4)!=null && ((Number)args.elementAt(4)).intValue() == 1)
            isNullable = ResultSetMetaData.columnNullable;
         if( args.elementAt(5)!=null && ((Number)args.elementAt(5)).intValue() == 1)
            isUpdateable = true;
         if( args.elementAt(6)!=null && ((Number)args.elementAt(6)).intValue() == 1)
            isSearchable = true;
         this._case = connection.getCase();

	 if (args.size () >= 12)
	   {
	       /* that has the members up to cd_flags */
	       int cd_flags = ((Number)args.elementAt(11)).intValue();

	       if ((cd_flags & VirtuosoTypes.CDF_XMLTYPE) != 0)
		 _isXml = true;
	       if ((cd_flags & VirtuosoTypes.CDF_AUTOINCREMENT) != 0)
		 isAutoIncrement = true;
	   }

      }
      catch(Exception e)
      {
      }
   }

   /**
    * Returns the name of the object which can represent this column.
    *
    * @return String The name of the class.
    * @see java.sql.ResultSetMetaData#getColumnClassName
    */
  protected String getColumnClassName () throws VirtuosoException
    {
      if (_isXml)
        return "org.w3c.dom.Document";

      return getColumnClassName (typeObject);
    }
  protected static String getColumnClassName (int _typeObject) throws VirtuosoException
  {
    switch (_typeObject)
      {
      case VirtuosoTypes.DV_NULL:
	return "java.lang.Void";
	case VirtuosoTypes.DV_SHORT_CONT_STRING:
	case VirtuosoTypes.DV_SHORT_STRING_SERIAL:
	case VirtuosoTypes.DV_STRICT_STRING:
	case VirtuosoTypes.DV_LONG_CONT_STRING:
	case VirtuosoTypes.DV_STRING:
	case VirtuosoTypes.DV_C_STRING:
	case VirtuosoTypes.DV_WIDE:
	case VirtuosoTypes.DV_LONG_WIDE:
	return "java.lang.String";
	case VirtuosoTypes.DV_STRING_SESSION:
	return "java.lang.StringBuffer";
	case VirtuosoTypes.DV_C_SHORT:
	case VirtuosoTypes.DV_SHORT_INT:
	return "java.lang.Short";
	case VirtuosoTypes.DV_LONG_INT:
	return "java.lang.Integer";
	case VirtuosoTypes.DV_C_INT:
	return "java.lang.Integer";
	case VirtuosoTypes.DV_SINGLE_FLOAT:
	return "java.lang.Float";
	case VirtuosoTypes.DV_DOUBLE_FLOAT:
	return "java.lang.Double";
	case VirtuosoTypes.DV_CHARACTER:
	return "java.lang.Character";
	case VirtuosoTypes.DV_ARRAY_OF_LONG_PACKED:
	/*typeObject=new VectorOfLongPacked().getClass().getName(); typeSQL=Types.ARRAY; */
	case VirtuosoTypes.DV_ARRAY_OF_FLOAT:
	case VirtuosoTypes.DV_ARRAY_OF_DOUBLE:
	case VirtuosoTypes.DV_ARRAY_OF_LONG:
	case VirtuosoTypes.DV_ARRAY_OF_POINTER:
	case VirtuosoTypes.DV_LIST_OF_POINTER:
	return "java.util.Vector";
	case VirtuosoTypes.DV_OBJECT_AND_CLASS:
	case VirtuosoTypes.DV_OBJECT_REFERENCE:
	return "java.lang.Object";
	case VirtuosoTypes.DV_BLOB_BIN:
	case VirtuosoTypes.DV_BLOB:
	case VirtuosoTypes.DV_BLOB_HANDLE:
	case VirtuosoTypes.DV_BIN:
	case VirtuosoTypes.DV_LONG_BIN:
	return "java.sql.Blob";
	case VirtuosoTypes.DV_NUMERIC:
	return "java.lang.BigDecimal";
	case VirtuosoTypes.DV_DATE:
	case VirtuosoTypes.DV_DATETIME:
	case VirtuosoTypes.DV_TIMESTAMP:
	case VirtuosoTypes.DV_TIMESTAMP_OBJ:
	case VirtuosoTypes.DV_TIME:
	return "java.lang.Date";
	default:
	// Problem
	//System.out.println("Tag not defined.");
	return "java.lang.Object";
      }
  }

   /**
    * Returns the name of this column.
    *
    * @return String The name of the column.
    * @see java.sql.ResultSetMetaData#getColumnName
    * @see java.sql.ResultSetMetaData#getColumnLabel
    */
   protected String getColumnName()
   {
      return name;
   }

   protected void setColumnName(String s)
   {
      name = s;
   }

   /**
    * Indicates the column's normal max width in chars.
    *
    * @return int The max length of the column.
    * @see java.sql.ResultSetMetaData#getColumnDisplaySize
    */
   protected int getColumnDisplaySize()
   {
      return length;
   }

   /**
    * Returns the SQL type which can be contained in this column.
    *
    * @return int The SQL type.
    * @see java.sql.ResultSetMetaData#getColumnType
    * @see java.sql.Types
    */
  protected int getColumnType () throws VirtuosoException
  {
    return getColumnType (typeObject);
  }
  protected static int getColumnType (int _typeObject) throws VirtuosoException
  {
    switch (_typeObject)
      {
      case VirtuosoTypes.DV_C_SHORT:
      case VirtuosoTypes.DV_SHORT_INT:
	return Types.SMALLINT;

      case VirtuosoTypes.DV_LONG_INT:
      case VirtuosoTypes.DV_C_INT:
	return Types.INTEGER;

      case VirtuosoTypes.DV_DOUBLE_FLOAT:
	return Types.DOUBLE;

      case VirtuosoTypes.DV_NUMERIC:
	return Types.NUMERIC;

      case VirtuosoTypes.DV_SINGLE_FLOAT:
	return Types.REAL;

      case VirtuosoTypes.DV_BLOB:
	return Types.LONGVARCHAR;

      case VirtuosoTypes.DV_BLOB_BIN:
	return Types.LONGVARBINARY;

      case VirtuosoTypes.DV_BLOB_WIDE:
	return -10; /* SQL_WLONGVARCHAR */

      case VirtuosoTypes.DV_DATE:
	return Types.DATE;

      case VirtuosoTypes.DV_TIMESTAMP:
      case VirtuosoTypes.DV_TIMESTAMP_OBJ:
      case VirtuosoTypes.DV_DATETIME:
	return Types.TIMESTAMP;

      case VirtuosoTypes.DV_TIME:
	return Types.TIME;

      case VirtuosoTypes.DV_LONG_BIN:
      case VirtuosoTypes.DV_BIN:
	return Types.VARBINARY;

      case VirtuosoTypes.DV_WIDE:
      case VirtuosoTypes.DV_LONG_WIDE:
	return -9; /* SQL_NVARCHAR */

      /* custom cases follow */
      case VirtuosoTypes.DV_DB_NULL:
      case VirtuosoTypes.DV_NULL:
	return Types.NULL;
      case VirtuosoTypes.DV_SHORT_CONT_STRING:
      case VirtuosoTypes.DV_SHORT_STRING_SERIAL:
      case VirtuosoTypes.DV_STRICT_STRING:
      case VirtuosoTypes.DV_LONG_CONT_STRING:
      case VirtuosoTypes.DV_STRING:
      case VirtuosoTypes.DV_C_STRING:
	return Types.VARCHAR;
      case VirtuosoTypes.DV_STRING_SESSION:
	return Types.LONGVARCHAR;

      case VirtuosoTypes.DV_CHARACTER:
	return Types.CHAR;

      case VirtuosoTypes.DV_ARRAY_OF_LONG_PACKED:
	/*typeObject=new VectorOfLongPacked().getClass().getName(); typeSQL=Types.ARRAY; */
      case VirtuosoTypes.DV_ARRAY_OF_FLOAT:
      case VirtuosoTypes.DV_ARRAY_OF_DOUBLE:
      case VirtuosoTypes.DV_ARRAY_OF_LONG:
      case VirtuosoTypes.DV_ARRAY_OF_POINTER:
      case VirtuosoTypes.DV_LIST_OF_POINTER:
	return Types.ARRAY;

      case VirtuosoTypes.DV_OBJECT_AND_CLASS:
      case VirtuosoTypes.DV_OBJECT_REFERENCE:
	return Types.OTHER;

      case VirtuosoTypes.DV_BLOB_HANDLE:
      case VirtuosoTypes.DV_BLOB_WIDE_HANDLE:
	return Types.BLOB;
      default:
	return Types.OTHER;
      }
  }

   /**
    * Returns the column's number of decimal digits.
    *
    * @return int The column's precision.
    * @see java.sql.ResultSetMetaData#getPrecision
    */
   protected int getPrecision()
   {
      return precision;
   }

   /**
    * Returns the column's number of digits to right of the decimal point.
    *
    * @return int The column's scale.
    * @see java.sql.ResultSetMetaData#getScale
    */
   protected int getScale()
   {
      return scale;
   }

   /**
    * Indicates whether the column is automatically numbered, thus read-only.
    *
    * @return boolean   The autoincrement flag.
    * @see java.sql.ResultSetMetaData#isAutoIncrement
    */
   protected boolean isAutoIncrement()
   {
      return isAutoIncrement;
   }

   /**
    * Indicates whether a column's case matters.
    *
    * @return boolean   The case sensitive flag.
    * @see java.sql.ResultSetMetaData#isCaseSensitive
    */
   protected boolean isCaseSensitive()
   {
      return isCaseSensitive;
   }

   /**
    * Indicates whether the column is a cash value.
    *
    * @return boolean   The currency flag.
    * @see java.sql.ResultSetMetaData#isCurrency
    */
   protected boolean isCurrency()
   {
      return isCurrency;
   }

   /**
    * Indicates the nullability of values in the designated column.
    *
    * @return int The nullability flag.
    * @see java.sql.ResultSetMetaData#isNullable
    */
   protected int isNullable()
   {
      return isNullable;
   }

   /**
    * Indicates whether the column can be used in a where clause.
    *
    * @return boolean   The searchable flag.
    * @see java.sql.ResultSetMetaData#isSearchable
    */
   protected boolean isSearchable()
   {
      return isSearchable;
   }

   /**
    * Indicates whether values in the column are signed numbers.
    *
    * @return boolean   The sign flag.
    * @see java.sql.ResultSetMetaData#isSigned
    */
   protected boolean isSigned()
   {
      return isSigned;
   }

   /**
    * Indicates if the column is updateable.
    *
    * @return boolean   The update flag.
    */
   protected boolean isUpdateable()
   {
      return isUpdateable;
   }

   /**
    * Returns a hash code value for the object.
    *
    * @return int	The hash code value.
    */
   public int hashCode()
   {
/*      if(name != null && _case == 2)
         return name.hashCode();
      if(name != null && _case == 1)
         return name.toUpperCase().hashCode();
      if(name != null && _case == 0)
         return name.toLowerCase().hashCode();*/
      if(name != null && _case == 2)
         return name.toUpperCase().hashCode();
      if(name != null)
         return name.hashCode();
      return 0;
   }

   /**
    * Compares two Objects for equality.
    *
    * @return boolean	True if two objects are equal, else false.
    */
   public boolean equals(Object obj)
   {
      // First check if the object is not null or the same object type
      if(obj != null && (obj instanceof VirtuosoColumn))
      {
/*         if(name != null && _case == 2)
            return ((VirtuosoColumn)obj).name.equals(name);
         if(name != null && _case == 1)
            return ((VirtuosoColumn)obj).name.toUpperCase().equals(name);
         if(name != null && _case == 0)
            return ((VirtuosoColumn)obj).name.toLowerCase().equals(name);*/
         if(name != null && _case == 2)
            return ((VirtuosoColumn)obj).name.toUpperCase().equals(name.toUpperCase());
         if(name != null)
            return ((VirtuosoColumn)obj).name.equals(name);
      }
      return false;
   }

   protected int getDtp ()
     {
       return typeObject;
     }

   protected boolean isXml ()
     {
       return _isXml;
     }
}

