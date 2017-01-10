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

/**
 * This class is an SQLException that has special constructors for
 * messages directly from Virtuoso.<p>
 * All classes can thrown a such exception.
 *
 * @version 1.0 (JDBC API 2.0 implementation)
 * @see java.sql.SQLException
 */
public class VirtuosoFNSException extends SQLFeatureNotSupportedException
{
   /**
    * Constructs a VirtuosoException based on an error occurred from Virtuoso.
    *
    * @param data 	The error message.
    * @param vendor	The error code vendor.
    */
   public VirtuosoFNSException(String data, int vendor)
   {
      super(data,"42000",vendor);
   }

   /**
    * Constructs a VirtuosoException based on an error occurred from Virtuoso
    * and an SQL state.
    *
    * @param data 	The error message.
    * @param sqlstate The SQL state of the error.
    * @param vendor	The error code vendor.
    */
   public VirtuosoFNSException(String data, String sqlstate, int vendor)
   {
      super(data,sqlstate,vendor);
   }

   /**
    * Constructs a VirtuosoException based on some odd exception.
    *
    * @param e 		The exception that caused this to be thrown.
    * @param vendor	The error code vendor.
    */
   public VirtuosoFNSException(Exception e, int vendor)
   {
#if JDK_VER >= 14
      super("General error","42000",vendor);
      initCause (e);
#else
      super(e.getMessage(),"42000",vendor);
#endif
   }

}

