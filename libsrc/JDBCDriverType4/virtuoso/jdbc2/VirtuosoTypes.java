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

import java.util.*;
import java.sql.Types;
import java.sql.Timestamp;


/**
 * The VirtuosoTypes is used to group together all the Virtuoso
 * data types it can manage.
 *
 * @version 1.0 (JDBC API 2.0 implementation)
 */
class VirtuosoTypes
{
   /**
    * The version string.
    */
   public static final String version = "05.12.3039";

   /**
    * NIL, false, the NULL pointer
    */
   public static final int DV_NULL = 180;

   /**
    * Binary string with 1 byte length prefix
    */
   public static final int DV_SHORT_STRING_SERIAL = 181;

   public static final int DV_BIN = 222;

   public static final int DV_STRICT_STRING = 238;

   /**
    * Binary string with 4 byte length prefix
    */
   public static final int DV_STRING = 182;

   public static final int DV_LONG_BIN = 223;

   public static final int DV_WIDE = 225;

   public static final int DV_LONG_WIDE = 226;

   /**
    * C string with trailing 0
    */
   public static final int DV_C_STRING = 183;

   /**
    * NOTE: DV_SHORT_STRING and DV_LONG_STRING are treated like
    * DV_C_STRING in wi - have to clean up this mess (paul)
    *
    * On outgoing data, DV_C_STRING, DV_LONG_STRING  and DV_SHORT_STRING are
    * all converted to either DV_LONG_STRING or DV_SHORT_STRING, depending on
    * their length. (DV_SHORT_STRING is slightly more efficient)
    *
    * Should convert LONG|SHORT -> C_STRING during receive
    */
   /**
    * DV_C_STRING and DV_C_SHORT specifically refer to the C data types
    * char * and short.
    * The char * is treated as a string that has no header and that ends
    * in a NULL character.
    * It is variously transmitted as a DV_SHORT_STRING or DV_LONG_STRING.
    * The short is transmitted as a DV_SHORT_INT or DV_LONG_INT depending on
    * its value.
    */
   public static final int DV_C_SHORT = 184;

   /**
    * Internally used in DB client to send string output sessions
    * as DV_<xx>_CONT_STRING's.
    */
   public static final int DV_STRING_SESSION = 185;

   public static final int DV_SHORT_CONT_STRING = 186;

   public static final int DV_LONG_CONT_STRING = 187;

   /**
    * signed 1 byte integer
    */
   public static final int DV_SHORT_INT = 188;

   /**
    * signed 4 byte integer. Sent low order first
    * NOTE: a box holding a DV_LONG_INT has enough room to store a native
    * long data type, even if that's 8 bytes (Paul)
    * For transport, only 4 bytes are used
    */
   public static final int DV_LONG_INT = 189;
   public static final int DV_INT64    = 247;

   /**
    * 4 byte float
    */
   public static final int DV_SINGLE_FLOAT = 190;

   /**
    * 8 byte float
    */
   public static final int DV_DOUBLE_FLOAT = 191;

   /**
    * 1 byte character
    */
   public static final int DV_CHARACTER = 192;

   /**
    * A numeric type as Bigdecimal
    */
   public static final int DV_NUMERIC = 219;

   /**
    * Record with 4 byte element count. The number
    * of items follow (mostly OBJECT_AND_CLASS records)
    *
    * The size of the object constructed from this is 4 times the length
    * at the head of the message
    */
   public static final int DV_ARRAY_OF_POINTER = 193;

   /**
    * len as DV-<xx>-INT, data as DV_xx_INT.
    */
   public static final int DV_ARRAY_OF_LONG_PACKED = 194;

   public static final int DV_ARRAY_OF_FLOAT = 202;

   public static final int DV_ARRAY_OF_DOUBLE = 195;

   /**
    * len as DV-<xx>-INT, data as 4 byte blocks.
    */
   public static final int DV_ARRAY_OF_LONG = 209;

   /**
    * Interpreted as ARRAY_OF_POINTER by C or C++ client
    */
   public static final int DV_LIST_OF_POINTER = 196;

   /**
    * The message contain an object id and a class id, both 4 byte ints.
    * This is interpreted as a reference to the object with the id in then
    * session. If no object with that id is found in the receiving party a
    * non present object is constructed. The class allows knowing the length
    * of the object so that a memory address can be reserved for eventually
    * bringing in the object.
    */
   public static final int DV_OBJECT_AND_CLASS = 197;

   /**
    * 4 bytes of object id follow. This may appear in slot values inside
    * clusters or in other places where the message sender knows that he receiver
    * has previously been informed of the class of the referenced object.
    * When this is not certain the sender uses DV_OBJECT_AND_CLASS.
    */
   public static final int DV_OBJECT_REFERENCE = 198;

   /**
    * Appears in a cluster delta as predicate value if the predicate has
    * been deleted. Does not really apply to C based Dis Kit
    * Interpreted as a NULL.
    */
   public static final int DV_DELETED = 199;

   public static final int DV_OBJECT = 254;
   public static final int UDT_JAVA_CLIENT_OBJECT_ID = -1;
   /**
    * pointer into a structure. object id, class id, member id, count
    */
   public static final int DV_MEMBER_POINTER = 200;

   /**
    * C integer, whatever length it be. 16/32
    */
   public static final int DV_C_INT = 201;

   /**
    * Identifies a custom serialization member. The reading function
    * will be in the dk_member_t for the member in question.
    * Only for use with DO
    */
   public static final int DV_CUSTOM = 203;

   public static final int DV_DB_NULL = 204;

   public static final int DV_G_REF_CLASS = 205;

   public static final int DV_G_REF = 206;

   /**
    * struct with first dp, current dp, current byte and length
    */
   public static final int DV_BOX_FLAGS = 207;

   public static final int DV_BLOB = 125;

   public static final int DV_BLOB_HANDLE = 126;

   public static final int DV_BLOB_WIDE_HANDLE = 133;

   public static final int DV_BLOB_BIN = 131;

   public static final int DV_BLOB_WIDE = 132;
   /**
    * DV_xxx objects for the time, date and symbols.
    */
   public static final int DV_SYMBOL = 127;

   public static final int DV_TIMESTAMP = 128;

   public static final int DV_DATE = 129;

   public static final int DV_TIMESTAMP_OBJ = 208;

   public static final int DV_TIME = 210;

   public static final int DV_DATETIME = 211;

   public static final int DV_ANY = 242;
   /*
    *  IRI
    */
   public static final int DV_IRI_ID = 243;
   public static final int DV_IRI_ID_8 = 244;

   public static final int DV_RDF = 246;

   /**
    *  Codes for Remote Actions
    */
   public static final int DA_FUTURE_REQUEST = 1;

   public static final int DA_FUTURE_ANSWER = 2;

   public static final int DA_FUTURE_PARTIAL_ANSWER = 3;

   public static final int DA_DIRECT_IO_FUTURE_REQUEST = 4;

   public static final int DA_CALLER_IDENTIFICATION = 5;

   /**
    * Answer Tags
    */
   public static final int QA_ROW = 1;

   public static final int QA_ERROR = 3;

   public static final int QA_COMPILED = 4;

   public static final int QA_NEED_DATA = 5;

   public static final int QA_PROC_RETURN = 6;

   public static final int QA_ROWS_AFFECTED = 7;

   public static final int QA_BLOB_POS = 8;

   public static final int QA_LOGIN = 9;

   public static final int QA_ROW_ADDED = 10;

   public static final int QA_ROW_UPDATED = 11;

   public static final int QA_ROW_DELETED = 12;

   public static final int QA_ROW_LAST_IN_BATCH = 13;

   public static final int QA_WARNING = 14;
   /**
    * Values for sc_is_select
    */
   public static final int QT_UNKNOWN = -1;

   public static final int QT_UPDATE = 0;

   public static final int QT_SELECT = 1;

   public static final int QT_PROC_CALL = 2;

   /**
    * Cursor types definition
    */
   public static final int SQL_CURSOR_FORWARD_ONLY = 0;

   public static final int SQL_CURSOR_KEYSET_DRIVEN = 1;

   public static final int SQL_CURSOR_DYNAMIC = 2;

   public static final int SQL_CURSOR_STATIC = 3;

   /**
    * Operation types definition
    */
   public static final int SQL_FETCH_NEXT = 1;

   public static final int SQL_FETCH_FIRST = 2;

   public static final int SQL_FETCH_LAST = 3;

   public static final int SQL_FETCH_PRIOR = 4;

   public static final int SQL_FETCH_ABSOLUTE = 5;

   public static final int SQL_FETCH_RELATIVE = 6;

   public static final int SQL_FETCH_BOOKMARK = 8;

   public static final int SQL_POSITION = 0;

   public static final int SQL_REFRESH = 1;

   public static final int SQL_UPDATE = 2;

   public static final int SQL_DELETE = 3;

   public static final int SQL_ADD = 4;

   /**
    * so_isolation
    */
   public static final int SQL_TXN_READ_UNCOMMITTED = 0x1;

   public static final int SQL_TXN_READ_COMMITTED = 0x2;

   public static final int SQL_TXN_REPEATABLE_READ = 0x4;

   public static final int SQL_TXN_SERIALIZABLE = 0x8;

   public static final int SQL_TXN_VERSIONING = 0x10;

   /**
    * Options to free a statement
    */
   public static final int STAT_DROP = 1;

   public static final int STAT_CLOSE = 0;

   /**
    * Query Compilation Return
    */
   public static final int QC_STATUS = 0;

   /**
    * Options for the TRXC RPC function
    */
   public static final int SQL_COMMIT = 0;

   public static final int SQL_ROLLBACK = 1;

   public static final int PAGELEN = 8192;

   public static final int PAGESIZ = 8172;

   public static final int DEFAULTPREFETCH = 100;

   /**
    * Array type
    */
   public static final int BYTEARRAY = -1;


   /**
     * Datetime subtype
     *
     */

   public static final int DT_TYPE_DATE	= 2;
   public static final int DT_TYPE_TIME = 3;
   public static final int DT_TYPE_DATETIME = 1;

   /**
     * Parameter Types
     *
     */
   public static final int SQL_PARAM_TYPE_UNKNOWN = 0;
   public static final int SQL_PARAM_INPUT = 1;
   public static final int SQL_PARAM_INPUT_OUTPUT = 2;
   public static final int SQL_PARAM_RESULT_COL = 3;
   public static final int SQL_PARAM_OUTPUT = 4;
   public static final int SQL_PARAM_RETURN_VALUE = 5;


   /**
     * Virtuoso Concurency types
     *
     */
   public static final int SQL_CONCUR_READ_ONLY  = 1;
   public static final int SQL_CONCUR_LOCK  = 2;
   public static final int SQL_CONCUR_ROWVER  = 3;
   public static final int SQL_CONCUR_VALUES  = 4;

   /**
     * Virtuoso numeric consts
     *
     */
   public static final int NUMERIC_MAX_SCALE = 15;
   public static final int NUMERIC_MAX_PRECISION = 40;

   /**
     * Virtuoso columns flags (ext info)
     *
     */
   public static final int CDF_KEY 		= 1;
   public static final int CDF_AUTOINCREMENT 	= 2;
   public static final int CDF_XMLTYPE 		= 4;


   protected static Object mapJavaTypeToSqlType (Object x, int targetSqlType) throws VirtuosoException
   {
     return mapJavaTypeToSqlType(x, targetSqlType, 0, false);
   }

   protected static Object mapJavaTypeToSqlType (Object x, int targetSqlType, int scale) throws VirtuosoException
   {
     return mapJavaTypeToSqlType(x, targetSqlType, scale, true);
   }

   protected static Object mapJavaTypeToSqlType (Object x, int targetSqlType, int scale, boolean useScale) throws VirtuosoException
   {
     if (x == null)
       return x;
     if (x instanceof java.lang.Boolean)
       x = new Integer (((Boolean)x).booleanValue() ? 1 : 0);

     switch (targetSqlType)
       {
	  case Types.CHAR:
	  case Types.VARCHAR:
	      if (x instanceof java.lang.String)
		return x;
	      else
		return x.toString();

	  case Types.LONGVARCHAR:
#if JDK_VER >= 12
              if (x instanceof java.sql.Clob || x instanceof java.sql.Blob || x instanceof java.lang.String)
#else
              if (x instanceof VirtuosoClob || x instanceof VirtuosoBlob || x instanceof java.lang.String)
#endif
                return x;
              else
		return x.toString();

	  case Types.DATE:
              if(x instanceof VirtuosoDate)
                 return ((VirtuosoDate)x).clone();
              else if(x instanceof VirtuosoTimestamp)
              {
                 VirtuosoTimestamp _t = (VirtuosoTimestamp)x;
                 return new VirtuosoDate(_t.getTime(), _t.getTimezone(), _t.withTimezone());
              }
              else if (x instanceof VirtuosoTime)
              {
                 VirtuosoTime _t = (VirtuosoTime)x;
                 return new VirtuosoDate(_t.getTime(), _t.getTimezone(), _t.withTimezone());
              }
	      else if(x instanceof java.sql.Date)
	         return new java.sql.Date(((java.sql.Date)x).getTime());
	      else if (x instanceof String)
	         return VirtuosoTypes.strToDate((String)x);
	      else if (x instanceof java.util.Date) 
	         return new java.sql.Date(((java.util.Date)x).getTime());
	      break;

	  case Types.TIME:
              if (x instanceof VirtuosoTime)
                 return ((VirtuosoTime)x).clone();
              else if(x instanceof VirtuosoTimestamp)
              {
                 VirtuosoTimestamp _t = (VirtuosoTimestamp)x;
                 return new VirtuosoTime(_t.getTime(), _t.getTimezone(), _t.withTimezone());
              }
              else if (x instanceof VirtuosoDate)
              {
                 VirtuosoDate _t = (VirtuosoDate)x;
                 return new VirtuosoTime(_t.getTime(), _t.getTimezone(), _t.withTimezone());
              }
              else if(x instanceof java.sql.Time)
                 return new java.sql.Time(((java.sql.Time)x).getTime());
              else if (x instanceof java.util.Date)
	         return new java.sql.Time(((java.util.Date)x).getTime());
              else if(x instanceof String)
                 return VirtuosoTypes.strToTime((String)x);
              break;

	  case Types.TIMESTAMP:
	      
              if (x instanceof VirtuosoTimestamp)
                 return ((VirtuosoTimestamp)x).clone();
              else if(x instanceof VirtuosoTime)
              {
                 VirtuosoTime _t = (VirtuosoTime)x;
                 return new VirtuosoTimestamp(_t.getTime(), _t.getTimezone(), _t.withTimezone());
              }
              else if (x instanceof VirtuosoDate)
              {
                 VirtuosoDate _t = (VirtuosoDate)x;
                 return new VirtuosoTimestamp(_t.getTime(), _t.getTimezone(), _t.withTimezone());
              }
	      else if(x instanceof java.sql.Timestamp)
	        {
	          Timestamp val = new java.sql.Timestamp(((java.sql.Timestamp)x).getTime());
	          val.setNanos(((java.sql.Timestamp)x).getNanos());
	          return val;
	        }
              else if (x instanceof java.util.Date)
                return new java.sql.Timestamp(((java.util.Date)x).getTime());
	      else if(x instanceof String)
                return VirtuosoTypes.strToTimestamp((String)x);
	      break;

          case Types.NUMERIC:
          case Types.DECIMAL:
              {
                java.math.BigDecimal bd = null;
		if (x instanceof java.math.BigDecimal)
		  bd = (java.math.BigDecimal) x;
                else if (x instanceof java.lang.String)
		  bd = new java.math.BigDecimal ((String) x);
		else if (x instanceof java.lang.Number)
		  bd = new java.math.BigDecimal (x.toString());
                if (bd != null && useScale)
		  return bd.setScale (scale);
              }
	      break;

          case Types.BIGINT:
              if (x instanceof java.math.BigDecimal || x instanceof java.lang.String)
                return new Long(x.toString());
              else if (x instanceof java.lang.Number)
                return new Long(((Number)x).longValue());
	      break;

          case Types.FLOAT:
          case Types.DOUBLE:
              if (x instanceof java.lang.Double)
                return x;
              else if (x instanceof java.lang.Number)
                return new Double (((Number)x).doubleValue());
              else if (x instanceof java.lang.String)
                return new Double ((String) x);
	      break;
          case Types.INTEGER:
              if (x instanceof java.lang.Integer)
                return x;
              else if (x instanceof java.lang.Number)
                return new Integer (((Number)x).intValue());
              else if (x instanceof java.lang.String)
                return new Integer ((String) x);
	      break;

          case Types.REAL:
              if (x instanceof java.lang.Float)
                return x;
              else if (x instanceof java.lang.Number)
                return new Float (((Number)x).floatValue());
              else if (x instanceof java.lang.String)
                return new Float ((String) x);
	      break;

          case Types.SMALLINT:
          case Types.TINYINT:
          case Types.BIT:
#if JDK_VER >= 14
          case Types.BOOLEAN:
#endif
              if (x instanceof java.lang.Short)
                return x;
              else if (x instanceof java.lang.String)
                return new Short ((String) x);
              else if (x instanceof java.lang.Number)
                return new Short (((Number)x).shortValue());
	      break;

	  case Types.ARRAY:
#if JDK_VER >= 14
	  case Types.DATALINK:
#endif
#if JDK_VER >= 16
      case Types.ROWID:
#endif
          case Types.DISTINCT:
	  case Types.REF:
	      throw new VirtuosoException ("Type not supported", VirtuosoException.NOTIMPLEMENTED);

          case Types.VARBINARY:
              if (x instanceof byte[])
                return x;
              break;

          case Types.LONGVARBINARY:
#if JDK_VER >= 12
              if (x instanceof java.sql.Blob || x instanceof byte [])
#else
              if (x instanceof VirtuosoBlob || x instanceof byte [])
#endif
                return x;
              break;

	  default:
	      return x;
       }
     throw new VirtuosoException ("Invalid value specified", VirtuosoException.BADPARAM);
   }


    /**
     * Convert a timestamp to a different Timezone.
     */
    protected static long timeToCal(java.util.Date value, Calendar target) {
        java.util.Date tmp = target.getTime();
        try {
            Calendar cal = Calendar.getInstance();
            cal.setTime(value);
            target.set(Calendar.HOUR_OF_DAY, cal.get(Calendar.HOUR_OF_DAY));
            target.set(Calendar.MINUTE, cal.get(Calendar.MINUTE));
            target.set(Calendar.SECOND, cal.get(Calendar.SECOND));
            target.set(Calendar.MILLISECOND, cal.get(Calendar.MILLISECOND));
            target.set(Calendar.YEAR, cal.get(Calendar.YEAR));
            target.set(Calendar.MONTH, cal.get(Calendar.MONTH));
            target.set(Calendar.DAY_OF_MONTH, cal.get(Calendar.DAY_OF_MONTH));
            return target.getTime().getTime();
        }
        finally {
            target.setTime(tmp);
        }
    }

    /**
     * Convert a timestamp from a different Timezone.
     */
    protected static long timeFromCal(java.util.Date value , Calendar target) {
        java.util.Date tmp = target.getTime();
        try {
            Calendar cal = Calendar.getInstance();
            target.setTime(value);
            cal.set(Calendar.HOUR_OF_DAY, target.get(Calendar.HOUR_OF_DAY));
            cal.set(Calendar.MINUTE, target.get(Calendar.MINUTE));
            cal.set(Calendar.SECOND, target.get(Calendar.SECOND));
            cal.set(Calendar.MILLISECOND, target.get(Calendar.MILLISECOND));
            cal.set(Calendar.YEAR, target.get(Calendar.YEAR));
            cal.set(Calendar.MONTH, target.get(Calendar.MONTH));
            cal.set(Calendar.DAY_OF_MONTH, target.get(Calendar.DAY_OF_MONTH));
            return cal.getTime().getTime();
        }
        finally {
            target.setTime(tmp);
        }
    }


  /**
   * Convert a string in JDBC date escape format to a Date value
   *
   * @param s date in format "yyyy-mm-dd"
   * @return corresponding Date
   */
  protected static java.sql.Date strToDate (String s)
  {
    java.sql.Date dt = null;
    if (s == null)
       return null;
    try {
	dt = java.sql.Date.valueOf (s);
    } catch (Exception e) {
    }
    if (dt == null)
      {
	try {
	    java.text.DateFormat df = java.text.DateFormat.getDateInstance();
	    java.util.Date juD = df.parse (s);
	    dt = new java.sql.Date (juD.getTime());
        } catch (Exception e) {
        }
      }
    return dt;
  }


  /**
   * Convert a string in JDBC timestamp escape format to a Timestamp value
   *
   * @param s timestamp in format "yyyy-mm-dd hh:mm:ss.fffffffff"
   * @return corresponding Timestamp
   */
  protected static java.sql.Timestamp strToTimestamp (String s)
  {
    java.sql.Timestamp ts = null;

    if (s == null)
      return null;
    try {
	ts = java.sql.Timestamp.valueOf (s);
    } catch (Exception e) {
    }
    return ts;
  }


  /**
   * Convert a string in JDBC time escape format to a Time value
   *
   * @param s time in format "hh:mm:ss"
   * @return corresponding Time
   */
  protected static java.sql.Time strToTime (String s)
  {
    java.sql.Time tm = null;

    if (s == null)
       return null;
    try {
	tm = java.sql.Time.valueOf (s);
    } catch (Exception e) {
    }
    return tm;
  }


}
