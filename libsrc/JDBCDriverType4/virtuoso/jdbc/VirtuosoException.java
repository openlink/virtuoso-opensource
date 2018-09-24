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

import java.sql.*;

/**
 * This class is an SQLException that has special constructors for
 * messages directly from Virtuoso.<p>
 * All classes can thrown a such exception.
 *
 * @version 1.0 (JDBC API 2.0 implementation)
 * @see java.sql.SQLException
 */
public class VirtuosoException extends SQLException
{
   /**
    * The operation ran with success. Normally, this error code (which is not one) is
    * never used. It's just in case of we need a such return code.
    */
   public static final int OK = 0;

   /**
    * The client is not connected to the database or the DBMS disconnected it.
    */
   public static final int DISCONNECTED = -1;

   /**
    * The JDBC url given is not valid.
    * A URL under the Virtuoso DBMS JDBC driver should be :
    * <pre>
    *   <code>jdbc:virtuoso://<i>host</i>:<i>port</i></code> , or
    *   <code>jdbc:virtuoso://<i>host</i>:<i>port</i>/UID=<i>username</i>/PWD=<i>userpassword</i></code>
    * </pre>
    */
   public static final int ILLJDBCURL = -2;

   /**
    * An I/O error occurred due to a communication problem on the socket layer.
    */
   public static final int IOERROR = -3;

   /**
    * Bad parameters given to the function.
    */
   public static final int BADPARAM = -4;

   /**
    * Bad login. Error code returned if the user name or/and password given are not valid.
    */
   public static final int BADLOGIN = -5;

   /**
    * Time out detected during a query.
    */
   public static final int TIMEOUT = -6;

   /**
    * Method launched is not implemented yet. Some function in the JDBC API are optional, so
    * if one of these is not implemented, a such error is returned.
    */
   public static final int NOTIMPLEMENTED = -7;

   /**
    * Error code which represents a SQL error done by the Virtuoso DBMS.
    */
   public static final int SQLERROR = -8;

   /**
    * Error occurred on a DV tag. A such error does not occur. It's only returned if the Virtuoso
    * DBMS used with the currently driver is too recent. It's reserved for futures cases.
    */
   public static final int BADTAG = -9;

   /**
    * Cast error occurred on an object. A such error does not occur. It's only returned if the Virtuoso
    * DBMS used with the currently driver is too recent. It's reserved for futures cases.
    */
   public static final int CASTERROR = -10;

   /**
    * This error code is returned if a user input should be a numeric, but he not entered one.
    * Especially if the port number is not a number.
    */
   public static final int BADFORMAT = -11;

   /**
    * Error occurred when a method is not compatible with the type.
    */
   public static final int ERRORONTYPE = -12;

   /**
    * Error occurred when a function is called in a class which is previously closed.
    * E.g. you want to access to Connection.getMetaData function but you did a Connection.close
    * before.
    */
   public static final int CLOSED = -13;

   /**
    * Error returned when a end of stream is reached.
    */
   public static final int EOF = -14;

   /**
    * Error returned when your license is not valid.
    */
   public static final int NOLICENCE = -15;

   /**
    * Returned when an unknown error is occurred. It should not occur, but just in case of...
    */
   public static final int UNKNOWN = -16;

   /**
    * Returned when a trivial error occurred.
    */
   public static final int MISCERROR = -17;

   /**
    * Constructs a VirtuosoException based on an error occurred from Virtuoso.
    *
    * @param data 	The error message.
    * @param vendor	The error code vendor.
    */
   public VirtuosoException(String data, int vendor)
   {
      super(data,"42000",vendor);
   }

   public VirtuosoException(Exception e, String data, int vendor)
   {
      super(data,"42000",vendor);
      initCause (e);

   }

   /**
    * Constructs a VirtuosoException based on an error occurred from Virtuoso
    * and an SQL state.
    *
    * @param data 	The error message.
    * @param sqlstate The SQL state of the error.
    * @param vendor	The error code vendor.
    */
   public VirtuosoException(String data, String sqlstate, int vendor)
   {
      super(data,sqlstate,vendor);
   }

   /**
    * Constructs a VirtuosoException based on some odd exception.
    *
    * @param e 		The exception that caused this to be thrown.
    * @param vendor	The error code vendor.
    */
   public VirtuosoException(Exception e, int vendor)
   {
      super("General error","42000",vendor);
      initCause (e);
   }

}

