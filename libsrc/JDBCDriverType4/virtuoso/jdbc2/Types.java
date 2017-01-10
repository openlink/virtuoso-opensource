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


/**
 * This is the SQL Types defined in the JDBC API 1.2 and others from the JDBC
 * 2.0 API counted as an extension.
 *
 * @version 1.0 (JDBC API 1.2 implementation)
 */
public class Types
{
   public final static int BIT = -7;

   public final static int TINYINT = -6;

   public final static int SMALLINT = 5;

   public final static int INTEGER = 4;

   public final static int BIGINT = -5;

   public final static int FLOAT = 6;

   public final static int REAL = 7;

   public final static int DOUBLE = 8;

   public final static int NUMERIC = 2;

   public final static int DECIMAL = 3;

   public final static int CHAR = 1;

   public final static int VARCHAR = 12;

   public final static int LONGVARCHAR = -1;

   public final static int DATE = 91;

   public final static int TIME = 92;

   public final static int TIMESTAMP = 93;

   public final static int BINARY = -2;

   public final static int VARBINARY = -3;

   public final static int LONGVARBINARY = -4;

   public final static int NULL = 0;

   public final static int OTHER = 1111;

   public final static int JAVA_OBJECT = 2000;

   public final static int DISTINCT = 2001;

   public final static int STRUCT = 2002;

   public final static int ARRAY = 2003;

   public final static int BLOB = 2004;

   public final static int CLOB = 2005;

   public final static int REF = 2006;

   private Types()
   {
   }

}

