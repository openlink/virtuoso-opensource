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
import openlink.util.*;

/**
 * The VirtuosoParameterMetaData class is an implementation of the ParameterMetaData
 * interface in the JDBC API that represents information about a PreparedStatement.
 * You can obtain one like below :
 * <pre>
 *   <code>ParameterMetaData metadata = statement.getParameterMetaData()</code>
 * </pre>
 *
 * @author George Kodinov (<a href="mailto:gkodinov@openlinksw.co.uk">gkodinov@openlinksw.co.uk</a>)
 * @version 1.0 (JDBC API 3.0 implementation)
 * @see java.sql.PreparedStatement
 * @see virtuoso.jdbc2.VirtuosoPreparedStatement#getParameterMetaData
 */
public class VirtuosoParameterMetaData implements ParameterMetaData
{
   protected openlink.util.Vector parameters;
   /**
    * Constructs a new VirtuosoParameterMetaData.
    *
    * @param args      The column description in the DV format.
    * @exception virtuoso.jdbc2.VirtuosoException An internal error occurred.
    */
   VirtuosoParameterMetaData(openlink.util.Vector args, VirtuosoConnection conn) throws VirtuosoException
   {
     if (args == null)
       {
         parameters = new openlink.util.Vector(0);
       }
     else
       {
         parameters = (openlink.util.Vector) args.clone();
       }
   }


   public int getParameterCount() throws VirtuosoException
   {
     return parameters.size();
   }


   private openlink.util.Vector getPd (int param) throws VirtuosoException
   {
     Object pd;
     openlink.util.Vector pdd;
     if (param < 1 || param > getParameterCount())
       throw new VirtuosoException ("No such parameter", "22023", VirtuosoException.BADPARAM);

     param--;

     pd = parameters.elementAt (param);
     if (pd == null || !(pd instanceof openlink.util.Vector))
       throw new VirtuosoException ("Invalid param info type", "22023", VirtuosoException.BADPARAM);
     pdd = (openlink.util.Vector) pd;
     if (pdd.size () < 5)
       throw new VirtuosoException ("Invalid param info size", "22023", VirtuosoException.BADPARAM);
     return pdd;
   }

   public int isNullable(int param) throws VirtuosoException
   {
     int nullable = ((Number) getPd (param).elementAt (3)).intValue();
     return (nullable != 0) ?
       ParameterMetaData.parameterNullable : ParameterMetaData.parameterNoNulls;
   }


   public boolean isSigned(int param) throws VirtuosoException
   {
     int dtp = ((Number) getPd (param).elementAt (3)).intValue();
     return (
        dtp == VirtuosoTypes.DV_SHORT_CONT_STRING ||
	dtp == VirtuosoTypes.DV_SHORT_STRING_SERIAL ||
	dtp == VirtuosoTypes.DV_STRICT_STRING ||
	dtp == VirtuosoTypes.DV_LONG_CONT_STRING ||
	dtp == VirtuosoTypes.DV_STRING ||
	dtp == VirtuosoTypes.DV_C_STRING ||
	dtp == VirtuosoTypes.DV_WIDE ||
	dtp == VirtuosoTypes.DV_LONG_WIDE ||
	dtp == VirtuosoTypes.DV_C_SHORT ||
	dtp == VirtuosoTypes.DV_SHORT_INT ||
	dtp == VirtuosoTypes.DV_LONG_INT ||
	dtp == VirtuosoTypes.DV_C_INT ||
	dtp == VirtuosoTypes.DV_SINGLE_FLOAT ||
	dtp == VirtuosoTypes.DV_DOUBLE_FLOAT ||
	dtp == VirtuosoTypes.DV_CHARACTER ||
	dtp == VirtuosoTypes.DV_NUMERIC);
   }


   public int getPrecision(int param) throws VirtuosoException
   {
     return ((Number) getPd (param).elementAt (1)).intValue();
   }

   public int getScale(int param) throws VirtuosoException
   {
     return ((Number) getPd (param).elementAt (2)).intValue();
   }


   public int getParameterType(int param) throws VirtuosoException
   {
     return VirtuosoColumn.getColumnType (((Number) getPd (param).elementAt (0)).intValue());
   }


   public String getParameterTypeName(int param) throws VirtuosoException
   {
     return VirtuosoResultSetMetaData._getColumnTypeName (getParameterType(param));
   }


   public String getParameterClassName(int param) throws VirtuosoException
   {
     return VirtuosoColumn.getColumnClassName (getParameterType(param));
   }


   public int getParameterMode(int param) throws VirtuosoException
   {
     switch (((Number) getPd (param).elementAt (0)).intValue())
     {
        case VirtuosoTypes.SQL_PARAM_INPUT: return  parameterModeIn;
        case VirtuosoTypes.SQL_PARAM_INPUT_OUTPUT: return  parameterModeInOut;
        case VirtuosoTypes.SQL_PARAM_OUTPUT: return  parameterModeOut;
        default: return  parameterModeUnknown;
     }
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
