/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

/**
 * The VirtuosoNullParameter class is designed for Prepared and Callable
 * statements for which some parameters are NULL, to keep track of the SQL
 * type when executing the query.
 *
 * @version 1.0 (JDBC API 1.2 implementation)
 * @see virtuoso.jdbc.VirtuosoConnection#prepareStatement
 */
public class VirtuosoNullParameter
{
   // The Virtuoso types of the parameter
	private int type;

   /**
    * Constructs a new VirtuosoNullParameter.
    *
    * @param type   The Virtuoso types of the parameter.
    */
   VirtuosoNullParameter(int type) throws VirtuosoException
   {
	   this(type, false);
   }

   /**
    * Constructs a new VirtuosoNullParameter from a Generic Type.
    *
    * @param type   The Type of the parameter.
	 * @param isSql  True if the Type is a SQL Type.
    */
   VirtuosoNullParameter(int type, boolean isSql) throws VirtuosoException
   {
	   if(isSql == false) this.type = type;
      else this.type = this.fromSQLType(type);
   }

   private int fromSQLType(int type) throws VirtuosoException
	{
	   switch (type)
		{
		   case Types.NULL:
			   return VirtuosoTypes.DV_DB_NULL;
			case Types.VARCHAR:
			   return VirtuosoTypes.DV_STRING;
			case Types.LONGVARCHAR:
			   return VirtuosoTypes.DV_STRING;
         case Types.BIT:
         case Types.TINYINT:
			case Types.SMALLINT:
			   return VirtuosoTypes.DV_SHORT_INT;
			case Types.INTEGER:
			   return VirtuosoTypes.DV_LONG_INT;
			case Types.REAL:
			   return VirtuosoTypes.DV_SINGLE_FLOAT;
			case Types.DOUBLE:
			   return VirtuosoTypes.DV_DOUBLE_FLOAT;
			case Types.CHAR:
			   return VirtuosoTypes.DV_CHARACTER;
			case Types.ARRAY:
			   return VirtuosoTypes.DV_LIST_OF_POINTER;
			case Types.OTHER:
			   return VirtuosoTypes.DV_OBJECT_REFERENCE;
			case Types.BLOB:
			case Types.CLOB:
			   return VirtuosoTypes.DV_BLOB;
			case Types.BINARY:
			case Types.VARBINARY:
			   return VirtuosoTypes.DV_BIN;
			case Types.LONGVARBINARY:
			   return VirtuosoTypes.DV_LONG_BIN;
         case Types.BIGINT:
			case Types.NUMERIC:
         case Types.DECIMAL:
			   return VirtuosoTypes.DV_NUMERIC;
			case Types.TIMESTAMP:
			   return VirtuosoTypes.DV_TIMESTAMP;
			case Types.DATE:
			   return VirtuosoTypes.DV_DATETIME;
			case Types.TIME:
			   return VirtuosoTypes.DV_TIME;
			default:
			   //System.out.println("SQL Types not defined.");
				throw new VirtuosoException("SQL Type " + type + " not defined.", VirtuosoException.BADTAG);
		}
	}

}
