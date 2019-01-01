/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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
import java.sql.RowIdLifetime;

/**
 * The DatabaseMetaData class is an implementation of the DatabaseMetaData interface
 * in the JDBC API which represents the database meta data. You can have one with:
 * <pre>
 *   <code>DatabaseMetaData metaData = connection.getMetaData()</code>
 * </pre>
 *
 * @version 1.0 (JDBC API 2.0 implementation)
 * @see java.sql.DatabaseMetaData
 * @see java.sql.Connection#getDatabaseMetaData
 * @see virtuoso.jdbc4.VirtuosoResultSet
 */
public class VirtuosoDatabaseMetaData implements DatabaseMetaData
{

   // Request queries
  /*
   private static final String r3 = "SELECT DISTINCT name_part(\\KEY_TABLE,0) AS \\TABLE_CAT VARCHAR(128)," +
     "NULL AS \\TABLE_SCHEM VARCHAR(128),NULL AS \\TABLE_NAME VARCHAR(128),NULL AS \\TABLE_TYPE VARCHAR(128)," +
     "NULL AS \\REMARKS VARCHAR(254) FROM DB.DBA.SYS_KEYS";

   private static final String r4 = "SELECT DISTINCT NULL AS \\TABLE_CAT VARCHAR(128)," +
     "name_part(\\KEY_TABLE,1) AS \\TABLE_SCHEM VARCHAR(128),NULL AS \\TABLE_NAME VARCHAR(128),NULL AS \\TABLE_TYPE VARCHAR(128)," +
     "NULL AS \\REMARKS VARCHAR(254) FROM DB.DBA.SYS_KEYS";

   private static final String r5 = "SELECT DISTINCT NULL AS \\TABLE_CAT VARCHAR(128)," +
     "NULL AS \\TABLE_SCHEM VARCHAR(128),NULL AS \\TABLE_NAME VARCHAR(128),table_type(\\KEY_TABLE) AS \\TABLE_TYPE VARCHAR(128)," +
     "NULL AS \\REMARKS VARCHAR(254) FROM DB.DBA.SYS_KEYS";
   */


   // Connection associated with
   private VirtuosoConnection connection;

   /**
    * Constructs a new database meta data.
    *
    * @param connection The connection associated to this meta data.
    */
   VirtuosoDatabaseMetaData(VirtuosoConnection connection)
   {
      this.connection = connection;
   }


   // --------------------------- JDBC 1.0 ------------------------------
   /**
    * Returns the URL which permits to access the database.
    *
    * @return the url or null if it cannot be generated.
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getURL() throws VirtuosoException
   {
      return connection.getURL();
   }

   /**
    * Returns the user name as known to the database.
    *
    * @return the database user name used.
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getUserName() throws VirtuosoException
   {
      return connection.getUserName();
   }

   /**
    * Is the database in read-only mode?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise.
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean isReadOnly() throws VirtuosoException
   {
      return false;
   }

   /**
    * Are NULL values sorted high?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise.
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean nullsAreSortedHigh() throws VirtuosoException
   {
      return true;
   }

   /**
    * Are NULL values sorted low?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise.
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean nullsAreSortedLow() throws VirtuosoException
   {
      return false;
   }

   /**
    * Are NULL values sorted at the start regardless of sort order?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise.
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean nullsAreSortedAtStart() throws VirtuosoException
   {
      return false;
   }

   /**
    * Are NULL values sorted at the end regardless of sort order?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise.
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean nullsAreSortedAtEnd() throws VirtuosoException
   {
      return false;
   }

   /**
    * Returns the name of this database product. In our case it is OpenLink Virtuoso DBMS.
    *
    * @return the database product name.
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getDatabaseProductName() throws VirtuosoException
   {
      return new String("OpenLink Virtuoso VDBMS");
   }

   /**
    * Returns the version of this database product.
    *
    * @return the database version.
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getDatabaseProductVersion() throws VirtuosoException
   {
      return connection.getVersion();
   }

   /**
    * Returns the name of this JDBC driver. In our case it is OpenLink Virtuoso JDBC pure Java.
    *
    * @return the JDBC driver name.
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getDriverName() throws VirtuosoException
   {
      return new String("OpenLink Virtuoso JDBC pure Java");
   }

   /**
    * Returns the version of this JDBC driver.
    *
    * @return the JDBC driver version.
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getDriverVersion() throws VirtuosoException
   {
      return new String(virtuoso.jdbc4.Driver.major + "." + virtuoso.jdbc4.Driver.minor + " (for Java 2 platform)");
   }

   /**
    * Returns the JDBC driver's major version number.
    *
    * @return the JDBC driver major version.
    */
   public int getDriverMajorVersion()
   {
      return virtuoso.jdbc4.Driver.major;
   }

   /**
    * Returns the JDBC driver's minor version number.
    *
    * @return the JDBC driver minor version.
    */
   public int getDriverMinorVersion()
   {
      return virtuoso.jdbc4.Driver.minor;
   }

   /**
    * Does the database store tables in a local file?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean usesLocalFiles() throws VirtuosoException
   {
      return true;
   }

   /**
    * Does the database use a file for each table?
    *
    * @return true if the database uses a local file for each table.
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean usesLocalFilePerTable() throws VirtuosoException
   {
      return false;
   }

   /**
    * Does the database treat mixed case unquoted SQL identifiers as
    * case sensitive and as a result store them in mixed case?
    *
    * A JDBC Compliant<sup><font size=-2>TM</font></sup> driver will always return false.
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsMixedCaseIdentifiers() throws VirtuosoException
   {
      return (connection.getCase() == 0);
   }

   /**
    * Does the database treat mixed case unquoted SQL identifiers as
    * case insensitive and store them in upper case?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean storesUpperCaseIdentifiers() throws VirtuosoException
   {
      return (connection.getCase() == 1);
   }

   /**
    * Does the database treat mixed case unquoted SQL identifiers as
    * case insensitive and store them in lower case?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean storesLowerCaseIdentifiers() throws VirtuosoException
   {
      return false;
   }

   /**
    * Does the database treat mixed case unquoted SQL identifiers as
    * case insensitive and store them in mixed case?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean storesMixedCaseIdentifiers() throws VirtuosoException
   {
      return (connection.getCase() == 2);
   }

   /**
    * Does the database treat mixed case quoted SQL identifiers as
    * case sensitive and as a result store them in mixed case?
    *
    * A JDBC Compliant<sup><font size=-2>TM</font></sup> driver will always return true.
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsMixedCaseQuotedIdentifiers() throws VirtuosoException
   {
      return true;
   }

   /**
    * Does the database treat mixed case quoted SQL identifiers as
    * case insensitive and store them in upper case?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean storesUpperCaseQuotedIdentifiers() throws VirtuosoException
   {
      return false;
   }

   /**
    * Does the database treat mixed case quoted SQL identifiers as
    * case insensitive and store them in lower case?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean storesLowerCaseQuotedIdentifiers() throws VirtuosoException
   {
      return false;
   }

   /**
    * Does the database treat mixed case quoted SQL identifiers as
    * case insensitive and store them in mixed case?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean storesMixedCaseQuotedIdentifiers() throws VirtuosoException
   {
      return true;
   }

   /**
    * What's the string used to quote SQL identifiers?
    * This returns a space " " if identifier quoting is not supported.
    *
    * A JDBC Compliant<sup><font size=-2>TM</font></sup>
    * driver always uses a double quote character.
    *
    * @return the quoting string
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getIdentifierQuoteString() throws VirtuosoException
   {
      return new String("\"");
   }

   /**
    * Gets a comma-separated list of all a database's SQL keywords
    * that are NOT also SQL92 keywords.
    *
    * @return the list
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getSQLKeywords() throws VirtuosoException
   {
      return new String("CHAR,INT,NAME,STRING,INTNUM,APPROXNUM,AMMSC,PARAMETER,AS,OR,AND,NOT,UMINUS,ALL," + "AMMSC,ANY,ATTACH,AS,ASC,AUTHORIZATION,BETWEEN,BY,CHARACTER,CHECK,CLOSE," + "COMMIT,CONTINUE,CREATE,CURRENT,CURSOR,DECIMAL,DECLARE,DEFAULT,DELETE,DESC," + "DISTINCT,DOUBLE,DROP,ESCAPE,EXISTS,FETCH,FLOAT,FOR,FOREIGN,FOUND,FROM,GOTO,GO," + "GRANT,GROUP,HAVING,IN,INDEX,INDICATOR,INSERT,INTEGER,INTO,IS,KEY,LANGUAGE," + "LIKE,NULLX,NUMERIC,OF,ON,OPEN,OPTION,ORDER,PRECISION,PRIMARY,PRIVILEGES,PROCEDURE," + "PUBLIC,REAL,REFERENCES,ROLLBACK,SCHEMA,SELECT,SET,SMALLINT,SOME,SQLCODE,SQLERROR," + "TABLE,TO,UNION,UNIQUE,UPDATE,USER,VALUES,VIEW,WHENEVER,WHERE,WITH,WORK," + "CONTIGUOUS,OBJECT_ID,UNDER,CLUSTERED,VARCHAR,VARBINARY,LONG,REPLACING,SOFT," + "SHUTDOWN,CHECKPOINT,BACKUP,REPLICATION,SYNC,ALTER,ADD,RENAME,DISCONNECT," + "BEFORE,AFTER,INSTEAD,TRIGGER,REFERENCING,OLD,PROCEDURE,FUNCTION,OUT,INOUT," + "HANDLER,IF,THEN,ELSE,ELSEIF,WHILE,BEGINX,ENDX,EQUALS,RETURN,CALL,RETURNS,DO," + "EXCLUSIVE,PREFETCH,SQLSTATE,FOUND,REVOKE,PASSWORD,OFF,LOGX,SQLSTATE,TIMESTAMP," + "DATE,DATETIME,TIME,EXECUTE,OWNER,BEGIN_FN_X,BEGIN_OJ_X,CONVERT,CASE,WHEN,THEN," + "IDENTITY,LEFT,RIGHT,FULL,OUTER,JOIN,USE,");
   }

   /**
    * Gets a comma-separated list of math functions.  These are the
    * X/Open CLI math function names used in the JDBC function escape
    * clause.
    *
    * @return the list
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getNumericFunctions() throws VirtuosoException
   {
      return new String("MOD,ABS,SIGN,ACOS,ASIN,ATAN,COS,SIN,TAN,COT,DEGREES,RADIANS," + "EXP,LOG,LOG10,SQRT,ATAN2,POWER,CEILING,FLOOR,PI,RAND"); //,ROUND,TRUNCATE
   }

   /**
    * Gets a comma-separated list of string functions.  These are the
    * X/Open CLI string function names used in the JDBC function escape
    * clause.
    *
    * @return the list
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getStringFunctions() throws VirtuosoException
   {
      return new String("CONCAT,LEFT,LTRIM,LENGTH,LCASE,REPEAT,RIGHT,RTRIM,SUBSTRING,UCASE,ASCII,CHAR," + "SPACE,LOCATE,LOCATE_2");
   }

   /**
    * Gets a comma-separated list of system functions.  These are the
    * X/Open CLI system function names used in the JDBC function escape
    * clause.
    *
    * @return the list
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getSystemFunctions() throws VirtuosoException
   {
      return new String("USERNAME,DBNAME,IFNULL");
   }

   /**
    * Gets a comma-separated list of time and date functions.
    *
    * @return the list
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getTimeDateFunctions() throws VirtuosoException
   {
      return new String("NOW,CURDATE,DAYOFMONTH,DAYOFWEEK,DAYOFYEAR,MONTH,QUARTER,WEEK,YEAR,CURTIME," + "HOUR,MINUTE,SECOND,DAYNAME,MONTHNAME");
   }

   /**
    * Gets the string that can be used to escape wildcard characters.
    * This is the string that can be used to escape '_' or '%' in
    * the string pattern style catalog search parameters.
    *
    * <P>The '_' character represents any single character.
    * <P>The '%' character represents any sequence of zero or
    * more characters.
    *
    * @return the string used to escape wildcard characters
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getSearchStringEscape() throws VirtuosoException
   {
      return new String("\\");
   }

   /**
    * Gets all the "extra" characters that can be used in unquoted
    * identifier names (those beyond a-z, A-Z, 0-9 and _).
    *
    * @return the string containing the extra characters
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getExtraNameCharacters() throws VirtuosoException
   {
      return new String("");
   }

   /**
    * Is "ALTER TABLE" with add column supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsAlterTableWithAddColumn() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is "ALTER TABLE" with drop column supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsAlterTableWithDropColumn() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is column aliasing supported?
    * If so, the SQL AS clause can be used to provide names for
    * computed columns or to provide alias names for columns as
    * required.
    *
    * A JDBC Compliant<sup><font size=-2>TM</font></sup> driver always returns true.
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsColumnAliasing() throws VirtuosoException
   {
      return true;
   }

   /**
    * Are concatenations between NULL and non-NULL values NULL?
    *
    * A JDBC Compliant<sup><font size=-2>TM</font></sup> driver always returns true.
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean nullPlusNonNullIsNull() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is the CONVERT function between SQL types supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsConvert() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is CONVERT between the given SQL types supported?
    *
    * @param fromType the type to convert from
    * @param toType the type to convert to
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    * @see virtuoso.jdbc4.Types
    */
   public boolean supportsConvert(int fromType, int toType) throws VirtuosoException
   {
      switch(fromType)
      {
         case Types.CHAR:
         case Types.VARCHAR:
         case Types.LONGVARCHAR:
            return true;
         case Types.BIT:
         case Types.TINYINT:
         case Types.SMALLINT:
         case Types.INTEGER:
         case Types.BIGINT:
         case Types.FLOAT:
         case Types.REAL:
         case Types.DOUBLE:
         case Types.NUMERIC:
         case Types.DECIMAL:
            switch(toType)
            {
               case Types.CHAR:
               case Types.VARCHAR:
               case Types.LONGVARCHAR:
               case Types.BIT:
               case Types.TINYINT:
               case Types.SMALLINT:
               case Types.INTEGER:
               case Types.BIGINT:
               case Types.FLOAT:
               case Types.REAL:
               case Types.DOUBLE:
               case Types.NUMERIC:
               case Types.DECIMAL:
                  return true;
            }
            ;
            return false;
         case Types.BLOB:
         case Types.CLOB:
            switch(toType)
            {
               case Types.CHAR:
               case Types.VARCHAR:
               case Types.LONGVARCHAR:
               case Types.BLOB:
               case Types.CLOB:
                  return true;
            }
            ;
            return false;
         default:
            switch(toType)
            {
               case Types.CHAR:
               case Types.VARCHAR:
               case Types.LONGVARCHAR:
                  return true;
            }
            ;
            return false;
      }
   }

   /**
    * Are table correlation names supported?
    *
    * A JDBC Compliant<sup><font size=-2>TM</font></sup> driver always returns true.
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsTableCorrelationNames() throws VirtuosoException
   {
      return true;
   }

   /**
    * If table correlation names are supported, are they restricted
    * to be different from the names of the tables?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsDifferentTableCorrelationNames() throws VirtuosoException
   {
      return false;
   }

   /**
    * Are expressions in "ORDER BY" lists supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsExpressionsInOrderBy() throws VirtuosoException
   {
      return true;
   }

   /**
    * Can an "ORDER BY" clause use columns not in the SELECT statement?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsOrderByUnrelated() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is some form of "GROUP BY" clause supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsGroupBy() throws VirtuosoException
   {
      return true;
   }

   /**
    * Can a "GROUP BY" clause use columns not in the SELECT?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsGroupByUnrelated() throws VirtuosoException
   {
      return true;
   }

   /**
    * Can a "GROUP BY" clause add columns not in the SELECT
    * provided it specifies all the columns in the SELECT?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsGroupByBeyondSelect() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is the escape character in "LIKE" clauses supported?
    *
    * A JDBC Compliant<sup><font size=-2>TM</font></sup> driver always returns true.
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsLikeEscapeClause() throws VirtuosoException
   {
      return true;
   }

   /**
    * Are multiple ResultSets from a single execute supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsMultipleResultSets() throws VirtuosoException
   {
      return true;
   }

   /**
    * Can we have multiple transactions open at once (on different
    * connections)?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsMultipleTransactions() throws VirtuosoException
   {
      return true;
   }

   /**
    * Can columns be defined as non-nullable?
    *
    * A JDBC Compliant<sup><font size=-2>TM</font></sup> driver always returns true.
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsNonNullableColumns() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is the ODBC Minimum SQL grammar supported?
    *
    * All JDBC Compliant<sup><font size=-2>TM</font></sup> drivers must return true.
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsMinimumSQLGrammar() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is the ODBC Core SQL grammar supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsCoreSQLGrammar() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is the ODBC Extended SQL grammar supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsExtendedSQLGrammar() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is the ANSI92 entry level SQL grammar supported?
    *
    * All JDBC Compliant<sup><font size=-2>TM</font></sup> drivers must return true.
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsANSI92EntryLevelSQL() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is the ANSI92 intermediate SQL grammar supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsANSI92IntermediateSQL() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is the ANSI92 full SQL grammar supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsANSI92FullSQL() throws VirtuosoException
   {
      return false;
   }

   /**
    * Is the SQL Integrity Enhancement Facility supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsIntegrityEnhancementFacility() throws SQLException
   {
      return true;
   }

   /**
    * Is some form of outer join supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsOuterJoins() throws VirtuosoException
   {
      return true;
   }

   /**
    * Are full nested outer joins supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsFullOuterJoins() throws VirtuosoException
   {
      return false;
   }

   /**
    * Is there limited support for outer joins?  (This will be true
    * if supportFullOuterJoins is true.)
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsLimitedOuterJoins() throws VirtuosoException
   {
      return true;
   }

   /**
    * What's the database vendor's preferred term for "schema"?
    *
    * @return the vendor term
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getSchemaTerm() throws VirtuosoException
   {
      return new String("OWNER");
   }

   /**
    * What's the database vendor's preferred term for "procedure"?
    *
    * @return the vendor term
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getProcedureTerm() throws VirtuosoException
   {
      return new String("PROCEDURE");
   }

   /**
    * What's the database vendor's preferred term for "catalog"?
    *
    * @return the vendor term
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getCatalogTerm() throws VirtuosoException
   {
      return new String("QUALIFIER");
   }

   /**
    * Does a catalog appear at the start of a qualified table name?
    * (Otherwise it appears at the end)
    *
    * @return true if it appears at the start
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean isCatalogAtStart() throws VirtuosoException
   {
      return true;
   }

   /**
    * What's the separator between catalog and table name?
    *
    * @return the separator string
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public String getCatalogSeparator() throws VirtuosoException
   {
      return new String(".");
   }

   /**
    * Can a schema name be used in a data manipulation statement?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsSchemasInDataManipulation() throws VirtuosoException
   {
      return true;
   }

   /**
    * Can a schema name be used in a procedure call statement?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsSchemasInProcedureCalls() throws VirtuosoException
   {
      return true;
   }

   /**
    * Can a schema name be used in a table definition statement?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsSchemasInTableDefinitions() throws VirtuosoException
   {
      return true;
   }

   /**
    * Can a schema name be used in an index definition statement?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsSchemasInIndexDefinitions() throws VirtuosoException
   {
      return true;
   }

   /**
    * Can a schema name be used in a privilege definition statement?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsSchemasInPrivilegeDefinitions() throws VirtuosoException
   {
      return true;
   }

   /**
    * Can a catalog name be used in a data manipulation statement?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsCatalogsInDataManipulation() throws VirtuosoException
   {
      return true;
   }

   /**
    * Can a catalog name be used in a procedure call statement?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsCatalogsInProcedureCalls() throws VirtuosoException
   {
      return true;
   }

   /**
    * Can a catalog name be used in a table definition statement?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsCatalogsInTableDefinitions() throws VirtuosoException
   {
      return true;
   }

   /**
    * Can a catalog name be used in an index definition statement?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsCatalogsInIndexDefinitions() throws VirtuosoException
   {
      return true;
   }

   /**
    * Can a catalog name be used in a privilege definition statement?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsCatalogsInPrivilegeDefinitions() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is positioned DELETE supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsPositionedDelete() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is positioned UPDATE supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsPositionedUpdate() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is SELECT for UPDATE supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsSelectForUpdate() throws VirtuosoException
   {
      return true;
   }

   /**
    * Are stored procedure calls using the stored procedure escape
    * syntax supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsStoredProcedures() throws VirtuosoException
   {
      return true;
   }

   /**
    * Are subqueries in comparison expressions supported?
    *
    * A JDBC Compliant<sup><font size=-2>TM</font></sup> driver always returns true.
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsSubqueriesInComparisons() throws VirtuosoException
   {
      return true;
   }

   /**
    * Are subqueries in 'exists' expressions supported?
    *
    * A JDBC Compliant<sup><font size=-2>TM</font></sup> driver always returns true.
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsSubqueriesInExists() throws VirtuosoException
   {
      return true;
   }

   /**
    * Are subqueries in 'in' statements supported?
    *
    * A JDBC Compliant<sup><font size=-2>TM</font></sup> driver always returns true.
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsSubqueriesInIns() throws VirtuosoException
   {
      return true;
   }

   /**
    * Are subqueries in quantified expressions supported?
    *
    * A JDBC Compliant<sup><font size=-2>TM</font></sup> driver always returns true.
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsSubqueriesInQuantifieds() throws VirtuosoException
   {
      return true;
   }

   /**
    * Are correlated subqueries supported?
    *
    * A JDBC Compliant<sup><font size=-2>TM</font></sup> driver always returns true.
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsCorrelatedSubqueries() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is SQL UNION supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsUnion() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is SQL UNION ALL supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsUnionAll() throws VirtuosoException
   {
      return true;
   }

   /**
    * Can cursors remain open across commits?
    *
    * @return <code>true</code> if cursors always remain open;
    * <code>false</code> if they might not remain open
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsOpenCursorsAcrossCommit() throws VirtuosoException
   {
      return false;
   }

   /**
    * Can cursors remain open across rollbacks?
    *
    * @return <code>true</code> if cursors always remain open;
    * <code>false</code> if they might not remain open
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsOpenCursorsAcrossRollback() throws VirtuosoException
   {
      return false;
   }

   /**
    * Can statements remain open across commits?
    *
    * @return <code>true</code> if statements always remain open;
    * <code>false</code> if they might not remain open
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsOpenStatementsAcrossCommit() throws VirtuosoException
   {
      return true;
   }

   /**
    * Can statements remain open across rollbacks?
    *
    * @return <code>true</code> if statements always remain open;
    * <code>false</code> if they might not remain open
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsOpenStatementsAcrossRollback() throws VirtuosoException
   {
      return true;
   }

   /**
    * How many hex characters can you have in an inline binary literal?
    *
    * @return max binary literal length in hex characters;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxBinaryLiteralLength() throws VirtuosoException
   {
      return 0;
   }

   /**
    * What's the max length for a character literal?
    *
    * @return max literal length;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxCharLiteralLength() throws VirtuosoException
   {
      return 0;
   }

   /**
    * What's the limit on column name length?
    *
    * @return max column name length;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxColumnNameLength() throws VirtuosoException
   {
      return 100;
   }

   /**
    * What's the maximum number of columns in a "GROUP BY" clause?
    *
    * @return max number of columns;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxColumnsInGroupBy() throws VirtuosoException
   {
      return 0;
   }

   /**
    * What's the maximum number of columns allowed in an index?
    *
    * @return max number of columns;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxColumnsInIndex() throws VirtuosoException
   {
      return 0;
   }

   /**
    * What's the maximum number of columns in an "ORDER BY" clause?
    *
    * @return max number of columns;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxColumnsInOrderBy() throws VirtuosoException
   {
      return 0;
   }

   /**
    * What's the maximum number of columns in a "SELECT" list?
    *
    * @return max number of columns;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxColumnsInSelect() throws VirtuosoException
   {
      return 0;
   }

   /**
    * What's the maximum number of columns in a table?
    *
    * @return max number of columns;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxColumnsInTable() throws VirtuosoException
   {
      return 200;
   }

   /**
    * How many active connections can we have at a time to this database?
    *
    * @return max number of active connections;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxConnections() throws VirtuosoException
   {
      return 0;
   }

   /**
    * What's the maximum cursor name length?
    *
    * @return max cursor name length in bytes;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxCursorNameLength() throws VirtuosoException
   {
      return 100;
   }

   /**
    * What's the maximum length of an index (in bytes)?
    *
    * @return max index length in bytes;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxIndexLength() throws VirtuosoException
   {
      return 1300;
   }

   /**
    * What's the maximum length allowed for a schema name?
    *
    * @return max name length in bytes;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxSchemaNameLength() throws VirtuosoException
   {
      return 100;
   }

   /**
    * What's the maximum length of a procedure name?
    *
    * @return max name length in bytes;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxProcedureNameLength() throws VirtuosoException
   {
      return 100;
   }

   /**
    * What's the maximum length of a catalog name?
    *
    * @return max name length in bytes;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxCatalogNameLength() throws VirtuosoException
   {
      return 100;
   }

   /**
    * What's the maximum length of a single row?
    *
    * @return max row size in bytes;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxRowSize() throws VirtuosoException
   {
      return 2000;
   }

   /**
    * Did getMaxRowSize() include LONGVARCHAR and LONGVARBINARY
    * blobs?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean doesMaxRowSizeIncludeBlobs() throws VirtuosoException
   {
      return false;
   }

   /**
    * What's the maximum length of a SQL statement?
    *
    * @return max length in bytes;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxStatementLength() throws VirtuosoException
   {
      return 0;
   }

   /**
    * How many active statements can we have open at one time to this
    * database?
    *
    * @return the maximum number of statements that can be open at one time;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxStatements() throws VirtuosoException
   {
      return 0;
   }

   /**
    * What's the maximum length of a table name?
    *
    * @return max name length in bytes;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxTableNameLength() throws VirtuosoException
   {
      return 100;
   }

   /**
    * What's the maximum number of tables in a SELECT statement?
    *
    * @return the maximum number of tables allowed in a SELECT statement;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxTablesInSelect() throws VirtuosoException
   {
      return 0;
   }

   /**
    * What's the maximum length of a user name?
    *
    * @return max user name length  in bytes;
    * a result of zero means that there is no limit or the limit is not known
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public int getMaxUserNameLength() throws VirtuosoException
   {
      return 100;
   }

   /**
    * What's the database's default transaction isolation level?  The
    * values are defined in <code>java.sql.Connection</code>.
    *
    * @return the default isolation level
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Connection
    */
   public int getDefaultTransactionIsolation() throws VirtuosoException
   {
      return Connection.TRANSACTION_REPEATABLE_READ;
   }

   /**
    * Are transactions supported? If not, invoking the method
    * <code>commit</code> is a noop and the
    * isolation level is TRANSACTION_NONE.
    *
    * @return <code>true</code> if transactions are supported; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsTransactions() throws VirtuosoException
   {
      return true;
   }

   /**
    * Does this database support the given transaction isolation level?
    *
    * @param level the values are defined in <code>java.sql.Connection</code>
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    * @see java.sql.Connection
    */
   public boolean supportsTransactionIsolationLevel(int level) throws VirtuosoException
   {
      if(level == Connection.TRANSACTION_READ_UNCOMMITTED
	  || level == Connection.TRANSACTION_READ_COMMITTED
	  || level == Connection.TRANSACTION_REPEATABLE_READ
	  || level == Connection.TRANSACTION_SERIALIZABLE)
         return true;
      return false;
   }

   /**
    * Are both data definition and data manipulation statements
    * within a transaction supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsDataDefinitionAndDataManipulationTransactions() throws VirtuosoException
   {
      return false;
   }

   /**
    * Are only data manipulation statements within a transaction
    * supported?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean supportsDataManipulationTransactionsOnly() throws VirtuosoException
   {
      return false;
   }

   /**
    * Does a data definition statement within a transaction force the
    * transaction to commit?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean dataDefinitionCausesTransactionCommit() throws VirtuosoException
   {
      return true;
   }

   /**
    * Is a data definition statement within a transaction ignored?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean dataDefinitionIgnoredInTransactions() throws VirtuosoException
   {
      return false;
   }

   /**
    * Can all the procedures returned by getProcedures be called by the
    * current user?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean allProceduresAreCallable() throws VirtuosoException
   {
      return false;
   }

   /**
    * Can all the tables returned by getTable be SELECTed by the
    * current user?
    *
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException No errors returned (just an implementation question).
    */
   public boolean allTablesAreSelectable() throws VirtuosoException
   {
      return false;
   }

   private static final String getProceduresCaseMode0 =
       "SELECT " +
         "name_part (\\P_NAME, 0) AS PROCEDURE_CAT VARCHAR(128)," +
	 "name_part (\\P_NAME, 1) AS PROCEDURE_SCHEM VARCHAR(128)," +
	 "name_part (\\P_NAME, 2) AS PROCEDURE_NAME VARCHAR(128)," +
	 "\\P_N_IN AS RES1," +
	 "\\P_N_OUT AS RES2," +
	 "\\P_N_R_SETS AS RES3," +
	 "\\P_COMMENT AS REMARKS VARCHAR(254)," +
	 "either(isnull(P_TYPE),0,P_TYPE) AS PROCEDURE_TYPE SMALLINT " +
       "FROM DB.DBA.SYS_PROCEDURES " +
       "WHERE " +
         "name_part (\\P_NAME, 0) like ? AND " +
	 "name_part (\\P_NAME, 1) like ? AND " +
	 "name_part (\\P_NAME, 2) like ? AND " +
	 "__proc_exists (\\P_NAME) is not null " +
       "ORDER BY P_QUAL, P_NAME";

   private static final String getProceduresCaseMode2 =
       "SELECT " +
         "name_part (\\P_NAME, 0) AS PROCEDURE_CAT VARCHAR(128)," +
	 "name_part (\\P_NAME, 1) AS PROCEDURE_SCHEM VARCHAR(128)," +
	 "name_part (\\P_NAME, 2) AS PROCEDURE_NAME VARCHAR(128)," +
	 "\\P_N_IN AS RES1," +
	 "\\P_N_OUT AS RES2," +
	 "\\P_N_R_SETS AS RES3," +
	 "\\P_COMMENT AS REMARKS VARCHAR(254)," +
	 "either(isnull(P_TYPE),0,P_TYPE) AS PROCEDURE_TYPE SMALLINT " +
       "FROM DB.DBA.SYS_PROCEDURES " +
       "WHERE " +
         "upper (name_part (\\P_NAME, 0)) like upper(?) AND " +
	 "upper (name_part (\\P_NAME, 1)) like upper(?) AND " +
	 "upper (name_part (\\P_NAME, 2)) like upper(?) AND " +
	 "__proc_exists (\\P_NAME) is not null " +
       "ORDER BY P_QUAL, P_NAME";
   private static final String getWideProceduresCaseMode0 =
       "SELECT " +
         "charset_recode (name_part (\\P_NAME, 0), 'UTF-8', '_WIDE_') AS PROCEDURE_CAT NVARCHAR(128)," +
	 "charset_recode (name_part (\\P_NAME, 1), 'UTF-8', '_WIDE_') AS PROCEDURE_SCHEM NVARCHAR(128)," +
	 "chatset_recode (name_part (\\P_NAME, 2), 'UTF-8', '_WIDE_') AS PROCEDURE_NAME NVARCHAR(128)," +
	 "\\P_N_IN AS RES1," +
	 "\\P_N_OUT AS RES2," +
	 "\\P_N_R_SETS AS RES3," +
	 "\\P_COMMENT AS REMARKS VARCHAR(254)," +
	 "either(isnull(P_TYPE),0,P_TYPE) AS PROCEDURE_TYPE SMALLINT " +
       "FROM DB.DBA.SYS_PROCEDURES " +
       "WHERE " +
         "name_part (\\P_NAME, 0) like ? AND " +
	 "name_part (\\P_NAME, 1) like ? AND " +
	 "name_part (\\P_NAME, 2) like ? AND " +
	 "__proc_exists (\\P_NAME) is not null " +
       "ORDER BY P_QUAL, P_NAME";

   private static final String getWideProceduresCaseMode2 =
       "SELECT " +
         "charset_recode (name_part (\\P_NAME, 0), 'UTF-8', '_WIDE_') AS PROCEDURE_CAT NVARCHAR(128)," +
	 "charset_recode (name_part (\\P_NAME, 1), 'UTF-8', '_WIDE_') AS PROCEDURE_SCHEM NVARCHAR(128)," +
	 "charset_recode (name_part (\\P_NAME, 2), 'UTF-8', '_WIDE_') AS PROCEDURE_NAME NVARCHAR(128)," +
	 "\\P_N_IN AS RES1," +
	 "\\P_N_OUT AS RES2," +
	 "\\P_N_R_SETS AS RES3," +
	 "\\P_COMMENT AS REMARKS VARCHAR(254)," +
	 "either(isnull(P_TYPE),0,P_TYPE) AS PROCEDURE_TYPE SMALLINT " +
       "FROM DB.DBA.SYS_PROCEDURES " +
       "WHERE " +
         "charset_recode (upper (charset_recode (name_part (\\P_NAME, 0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') AND " +
	 "charset_recode (upper (charset_recode (name_part (\\P_NAME, 1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') AND " +
	 "charset_recode (upper (charset_recode (name_part (\\P_NAME, 2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') AND " +
	 "__proc_exists (\\P_NAME) is not null " +
       "ORDER BY P_QUAL, P_NAME";


   /**
    * Gets a description of the stored procedures available in a
    * catalog.
    *
    * <P>Only procedure descriptions matching the schema and
    * procedure name criteria are returned.  They are ordered by
    * PROCEDURE_SCHEM, and PROCEDURE_NAME.
    *
    * <P>Each procedure description has the following columns:
    *  <OL>
    *	<LI><B>PROCEDURE_CAT</B> String => procedure catalog (may be null)
    *	<LI><B>PROCEDURE_SCHEM</B> String => procedure schema (may be null)
    *	<LI><B>PROCEDURE_NAME</B> String => procedure name
    *  <LI> reserved for future use
    *  <LI> reserved for future use
    *  <LI> reserved for future use
    *	<LI><B>REMARKS</B> String => explanatory comment on the procedure
    *	<LI><B>PROCEDURE_TYPE</B> short => kind of procedure:
    *      <UL>
    *      <LI> procedureResultUnknown - May return a result
    *      <LI> procedureNoResult - Does not return a result
    *      <LI> procedureReturnsResult - Returns a result
    *      </UL>
    *  </OL>
    *
    * @param catalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param schemaPattern a schema name pattern; "" retrieves those
    * without a schema
    * @param procedureNamePattern a procedure name pattern
    * @return ResultSet - each row is a procedure description
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    * @see #getSearchStringEscape
    */
   public ResultSet getProcedures(String catalog, String schemaPattern,
       String procedureNamePattern) throws SQLException
   {
      if(catalog == null)
         catalog = "%";
      if(schemaPattern == null)
         schemaPattern = "%";
      if(procedureNamePattern == null)
         procedureNamePattern = "%";
      VirtuosoPreparedStatement ps;
      if (connection.utf8_execs)
	ps = (VirtuosoPreparedStatement)
	    connection.prepareStatement ((connection.getCase() == 2) ?
		getWideProceduresCaseMode2 :
		getWideProceduresCaseMode0);
      else
	ps = (VirtuosoPreparedStatement)
	    connection.prepareStatement ((connection.getCase() == 2) ?
		getProceduresCaseMode2 :
		getProceduresCaseMode0);
      ps.setString (1, connection.escapeSQLString (catalog).toParamString());
      ps.setString (2, connection.escapeSQLString (schemaPattern).toParamString());
      ps.setString (3, connection.escapeSQLString (procedureNamePattern).toParamString());
      ResultSet rs = ps.executeQuery();
      return rs;
   }

   /**
    * Gets a description of a catalog's stored procedure parameters
    * and result columns.
    *
    * <P>Only descriptions matching the schema, procedure and
    * parameter name criteria are returned.  They are ordered by
    * PROCEDURE_SCHEM and PROCEDURE_NAME. Within this, the return value,
    * if any, is first. Next are the parameter descriptions in call
    * order. The column descriptions follow in column number order.
    *
    * <P>Each row in the ResultSet is a parameter description or
    * column description with the following fields:
    *  <OL>
    *	<LI><B>PROCEDURE_CAT</B> String => procedure catalog (may be null)
    *	<LI><B>PROCEDURE_SCHEM</B> String => procedure schema (may be null)
    *	<LI><B>PROCEDURE_NAME</B> String => procedure name
    *	<LI><B>COLUMN_NAME</B> String => column/parameter name
    *	<LI><B>COLUMN_TYPE</B> Short => kind of column/parameter:
    *      <UL>
    *      <LI> procedureColumnUnknown - nobody knows
    *      <LI> procedureColumnIn - IN parameter
    *      <LI> procedureColumnInOut - INOUT parameter
    *      <LI> procedureColumnOut - OUT parameter
    *      <LI> procedureColumnReturn - procedure return value
    *      <LI> procedureColumnResult - result column in ResultSet
    *      </UL>
    *  <LI><B>DATA_TYPE</B> short => SQL type from java.sql.Types
    *	<LI><B>TYPE_NAME</B> String => SQL type name, for a UDT type the
    *  type name is fully qualified
    *	<LI><B>PRECISION</B> int => precision
    *	<LI><B>LENGTH</B> int => length in bytes of data
    *	<LI><B>SCALE</B> short => scale
    *	<LI><B>RADIX</B> short => radix
    *	<LI><B>NULLABLE</B> short => can it contain NULL?
    *      <UL>
    *      <LI> procedureNoNulls - does not allow NULL values
    *      <LI> procedureNullable - allows NULL values
    *      <LI> procedureNullableUnknown - nullability unknown
    *      </UL>
    *	<LI><B>REMARKS</B> String => comment describing parameter/column
    *  </OL>
    *
    * <P><B>Note:</B> Some databases may not return the column
    * descriptions for a procedure. Additional columns beyond
    * REMARKS can be defined by the database.
    *
    * @param catalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param schemaPattern a schema name pattern; "" retrieves those
    * without a schema
    * @param procedureNamePattern a procedure name pattern
    * @param columnNamePattern a column name pattern
    * @return ResultSet - each row describes a stored procedure parameter or
    *      column
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    * @see #getSearchStringEscape
    */
   public ResultSet getProcedureColumns(String catalog, String schemaPattern,
       String procedureNamePattern, String columnNamePattern) throws SQLException
   {
      if(catalog == null)
         catalog = "%";
      if(schemaPattern == null)
         schemaPattern = "%";
      if(procedureNamePattern == null)
         procedureNamePattern = "%";
      if(columnNamePattern == null)
         columnNamePattern = "%";

      VirtuosoPreparedStatement ps = (VirtuosoPreparedStatement)
	  (connection.utf8_execs ?
	      connection.prepareStatement("DB.DBA.SQL_PROCEDURE_COLUMNSW (?, ?, ?, ?, ?, ?)") :
	      connection.prepareStatement("DB.DBA.SQL_PROCEDURE_COLUMNS (?, ?, ?, ?, ?, ?)"));

      ps.setString (1, connection.escapeSQLString(catalog).toParamString());
      ps.setString (2, connection.escapeSQLString(schemaPattern).toParamString());
      ps.setString (3, connection.escapeSQLString(procedureNamePattern).toParamString());
      ps.setString (4, connection.escapeSQLString(columnNamePattern).toParamString());
      ps.setInt(5, connection.getCase());
      ps.setInt(6, 1);

      VirtuosoResultSet rs = (VirtuosoResultSet)ps.executeQuery();

      rs.metaData.setColumnName(8, "PRECISION");
      rs.metaData.setColumnName(9, "LENGTH");
      rs.metaData.setColumnName(10, "SCALE");
      rs.metaData.setColumnName(11, "RADIX");

      return rs;
   }

   private static final String getWideTablesCaseMode0 =
       "SELECT " +
         "charset_recode (name_part(\\KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_CAT NVARCHAR(128)," +
	 "charset_recode (name_part(\\KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_SCHEM NVARCHAR(128)," +
	 "charset_recode (name_part(\\KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128)," +
         "table_type(\\KEY_TABLE)  AS \\TABLE_TYPE VARCHAR(128)," +
	 "NULL AS \\REMARKS VARCHAR(254) " +
	 ",NULL AS \\TYPE_CAT  VARCHAR(128) " +
	 ",NULL AS \\TYPE_SCHEM VARCHAR(128) " +
	 ",NULL AS \\TYPE_NAME VARCHAR(128) " +
	 ",NULL AS \\SELF_REFERENCING_COL_NAME VARCHAR(128) " +
	 ",NULL AS \\REF_GENERATION VARCHAR(128) " +
       "FROM DB.DBA.SYS_KEYS " +
       "WHERE " +
         "__any_grants(\\KEY_TABLE) AND " +
	 "name_part(\\KEY_TABLE,0) LIKE ? AND " +
	 "name_part(\\KEY_TABLE,1) LIKE ? AND " +
	 "name_part(\\KEY_TABLE,2) LIKE ? AND " +
	 "locate (concat ('G', table_type (\\KEY_TABLE)), ?) > 0 AND " +
	 "\\KEY_IS_MAIN = 1 AND " +
	 "\\KEY_MIGRATE_TO IS NULL " +
       "ORDER BY 4, 2, 3";
   private static final String getWideTablesCaseMode2 =
       "SELECT " +
         "charset_recode (name_part(\\KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_CAT NVARCHAR(128)," +
	 "charset_recode (name_part(\\KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_SCHEM NVARCHAR(128)," +
	 "charset_recode (name_part(\\KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128)," +
         "table_type(\\KEY_TABLE)  AS \\TABLE_TYPE VARCHAR(128)," +
	 "NULL AS \\REMARKS VARCHAR(254) " +
	 ",NULL AS \\TYPE_CAT  VARCHAR(128) " +
	 ",NULL AS \\TYPE_SCHEM VARCHAR(128) " +
	 ",NULL AS \\TYPE_NAME VARCHAR(128) " +
	 ",NULL AS \\SELF_REFERENCING_COL_NAME VARCHAR(128) " +
	 ",NULL AS \\REF_GENERATION VARCHAR(128) " +
       "FROM DB.DBA.SYS_KEYS " +
       "WHERE " +
         "__any_grants(\\KEY_TABLE) AND " +
	 "charset_recode (UPPER(charset_recode (name_part(\\KEY_TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (UPPER(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') AND " +
	 "charset_recode (UPPER(charset_recode (name_part(\\KEY_TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (UPPER(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') AND " +
	 "charset_recode (UPPER(charset_recode (name_part(\\KEY_TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (UPPER(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') AND " +
	 "locate (concat ('G', table_type (\\KEY_TABLE)), ?) > 0 AND " +
	 "\\KEY_IS_MAIN = 1 AND " +
	 "\\KEY_MIGRATE_TO IS NULL " +
       "ORDER BY 4, 2, 3";
   private static final String getTablesCaseMode0 =
       "SELECT " +
         "name_part(\\KEY_TABLE,0) AS \\TABLE_CAT VARCHAR(128)," +
	 "name_part(\\KEY_TABLE,1) AS \\TABLE_SCHEM VARCHAR(128)," +
	 "name_part(\\KEY_TABLE,2) AS \\TABLE_NAME VARCHAR(128)," +
         "table_type(\\KEY_TABLE)  AS \\TABLE_TYPE VARCHAR(128)," +
	 "NULL AS \\REMARKS VARCHAR(254) " +
	 ",NULL AS \\TYPE_CAT  VARCHAR(128) " +
	 ",NULL AS \\TYPE_SCHEM VARCHAR(128) " +
	 ",NULL AS \\TYPE_NAME VARCHAR(128) " +
	 ",NULL AS \\SELF_REFERENCING_COL_NAME VARCHAR(128) " +
	 ",NULL AS \\REF_GENERATION VARCHAR(128) " +
       "FROM DB.DBA.SYS_KEYS " +
       "WHERE " +
         "__any_grants(\\KEY_TABLE) AND " +
	 "name_part(\\KEY_TABLE,0) LIKE ? AND " +
	 "name_part(\\KEY_TABLE,1) LIKE ? AND " +
	 "name_part(\\KEY_TABLE,2) LIKE ? AND " +
	 "locate (concat ('G', table_type (\\KEY_TABLE)), ?) > 0 AND " +
	 "\\KEY_IS_MAIN = 1 AND " +
	 "\\KEY_MIGRATE_TO IS NULL " +
       "ORDER BY 4, 2, 3";
   private static final String getTablesCaseMode2 =
       "SELECT " +
         "name_part(\\KEY_TABLE,0) AS \\TABLE_CAT VARCHAR(128)," +
	 "name_part(\\KEY_TABLE,1) AS \\TABLE_SCHEM VARCHAR(128)," +
	 "name_part(\\KEY_TABLE,2) AS \\TABLE_NAME VARCHAR(128)," +
         "table_type(\\KEY_TABLE)  AS \\TABLE_TYPE VARCHAR(128)," +
	 "NULL AS \\REMARKS VARCHAR(254) " +
	 ",NULL AS \\TYPE_CAT  VARCHAR(128) " +
	 ",NULL AS \\TYPE_SCHEM VARCHAR(128) " +
	 ",NULL AS \\TYPE_NAME VARCHAR(128) " +
	 ",NULL AS \\SELF_REFERENCING_COL_NAME VARCHAR(128) " +
	 ",NULL AS \\REF_GENERATION VARCHAR(128) " +
       "FROM DB.DBA.SYS_KEYS " +
       "WHERE " +
         "__any_grants(\\KEY_TABLE) AND " +
	 "UPPER(name_part(\\KEY_TABLE,0)) LIKE UPPER(?) AND " +
	 "UPPER(name_part(\\KEY_TABLE,1)) LIKE UPPER(?) AND " +
	 "UPPER(name_part(\\KEY_TABLE,2)) LIKE UPPER(?) AND " +
	 "locate (concat ('G', table_type (\\KEY_TABLE)), ?) > 0 AND " +
	 "\\KEY_IS_MAIN = 1 AND " +
	 "\\KEY_MIGRATE_TO IS NULL " +
       "ORDER BY 4, 2, 3";


   /**
    * Gets a description of tables available in a catalog.
    *
    * <P>Only table descriptions matching the catalog, schema, table
    * name and type criteria are returned.  They are ordered by
    * TABLE_TYPE, TABLE_SCHEM and TABLE_NAME.
    *
    * <P>Each table description has the following columns:
    *  <OL>
    *	<LI><B>TABLE_CAT</B> String => table catalog (may be null)
    *	<LI><B>TABLE_SCHEM</B> String => table schema (may be null)
    *	<LI><B>TABLE_NAME</B> String => table name
    *	<LI><B>TABLE_TYPE</B> String => table type.  Typical types are "TABLE",
    *			"VIEW",	"SYSTEM TABLE", "GLOBAL TEMPORARY",
    *			"LOCAL TEMPORARY", "ALIAS", "SYNONYM".
    *	<LI><B>REMARKS</B> String => explanatory comment on the table
    *  </OL>
    *
    * <P><B>Note:</B> Some databases may not return information for
    * all tables.
    *
    * @param catalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param schemaPattern a schema name pattern; "" retrieves those
    * without a schema
    * @param tableNamePattern a table name pattern
    * @param types a list of table types to include; null returns all types
    * @return ResultSet - each row is a table description
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    * @see #getSearchStringEscape
    */
   public ResultSet getTables(String catalog, String schemaPattern,
       String tableNamePattern, String types[]) throws SQLException
   {
      if(catalog != null && catalog.equals("%") && schemaPattern == null && tableNamePattern == null)
	return getCatalogs();
      if(schemaPattern != null && schemaPattern.equals("%") && catalog == null && tableNamePattern == null)
	return getSchemas();
      if(types!=null && types[0].equals("%") && catalog == null &&
	  schemaPattern == null && tableNamePattern == null)
	return getTableTypes();

      StringBuffer typ = new StringBuffer();
      if(types != null)
         for(int i = 0;i < types.length;i++)
	 {
	   if (types[i].equals("TABLE"))
	     typ.append("GTABLE");
	   else if (types[i].equals("VIEW"))
	     typ.append("GVIEW");
	   else if (types[i].equals("SYSTEM TABLE"))
	     typ.append("GSYSTEM TABLE");
	 }
      if (typ.length() == 0)
	typ.append("GTABLEGVIEWGSYSTEM TABLE");

      if (catalog == null)
	catalog = "%";
      if (schemaPattern == null)
	schemaPattern = "%";
      if (tableNamePattern == null)
	tableNamePattern = "%";

      VirtuosoPreparedStatement ps;
      if (connection.utf8_execs)
	ps = (VirtuosoPreparedStatement) connection.prepareStatement(
	    (connection.getCase() == 2) ?
	    getWideTablesCaseMode2 :
	    getWideTablesCaseMode0);
      else
	ps = (VirtuosoPreparedStatement) connection.prepareStatement(
	    (connection.getCase() == 2) ?
	    getTablesCaseMode2 :
	    getTablesCaseMode0);
      ps.setString(1,connection.escapeSQLString(catalog).toParamString());
      ps.setString(2,connection.escapeSQLString(schemaPattern).toParamString());
      ps.setString(3,connection.escapeSQLString (tableNamePattern).toParamString());
      ps.setString(4,connection.escapeSQLString(typ.toString()).toParamString());
      ResultSet rs = ps.executeQuery();
      return rs;
   }

/****** create problem for DbVisualizer, bug in DbVisualizer, it does not support new JDBC specification
   private static final String getSchemasText =
	"select distinct" +
	" name_part(KEY_TABLE, 1) AS \\TABLE_SCHEM VARCHAR(128)" +
#if 1
	", name_part(KEY_TABLE, 0) AS \\TABLE_CAT VARCHAR(128)" +
#endif
	"from DB.DBA.SYS_KEYS";
   private static final String getWideSchemasText =
	"select distinct" +
	" charset_recode (name_part(KEY_TABLE, 1), 'UTF-8', '_WIDE_') AS \\TABLE_SCHEM NVARCHAR(128)" +
#if 1
	", charset_recode (name_part(KEY_TABLE, 0), 'UTF-8', '_WIDE_') AS \\TABLE_CAT NVARCHAR(128)" +
#endif
	"from DB.DBA.SYS_KEYS";
***********/
   private static final String getSchemasText =
	"select distinct" +
	" name_part(KEY_TABLE, 1) AS \\TABLE_SCHEM VARCHAR(128)" +
	", null AS \\TABLE_CAT VARCHAR(128)" +
	"from DB.DBA.SYS_KEYS";
   private static final String getWideSchemasText =
	"select distinct" +
	" charset_recode (name_part(KEY_TABLE, 1), 'UTF-8', '_WIDE_') AS \\TABLE_SCHEM NVARCHAR(128)" +
	", null AS \\TABLE_CAT NVARCHAR(128)" +
	"from DB.DBA.SYS_KEYS";
   /**
    * Gets the schema names available in this database.  The results
    * are ordered by schema name.
    *
    * <P>The schema column is:
    *  <OL>
    *	<LI><B>TABLE_SCHEM</B> String => schema name
    *  </OL>
    *
    * @return ResultSet - each row has a single String column that is a
    * schema name
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public ResultSet getSchemas() throws SQLException
   {
      Statement st = connection.createStatement();
      ResultSet rs = st.executeQuery(connection.utf8_execs ? getWideSchemasText : getSchemasText);
      return rs;
   }

   private static final String getCatalogsText =
	"select" +
	" distinct name_part(KEY_TABLE,0) AS \\TABLE_CAT VARCHAR(128)" +
	"from DB.DBA.SYS_KEYS order by 1";

   private static final String getWideCatalogsText =
	"select" +
	" distinct charset_recode (name_part(KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_CAT NVARCHAR(128)" +
	"from DB.DBA.SYS_KEYS order by 1";

   /**
    * Gets the catalog names available in this database.  The results
    * are ordered by catalog name.
    *
    * <P>The catalog column is:
    *  <OL>
    *	<LI><B>TABLE_CAT</B> String => catalog name
    *  </OL>
    *
    * @return ResultSet - each row has a single String column that is a
    * catalog name
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public ResultSet getCatalogs() throws SQLException
   {
      Statement st = connection.createStatement();
      ResultSet rs = st.executeQuery(connection.utf8_execs ? getWideCatalogsText : getCatalogsText);
      return rs;
   }

   private static final String getTableTypes_text =
    "select distinct" +
    " table_type (KEY_TABLE)" +
    "   AS \\TABLE_TYPE VARCHAR(128)," +
    " NULL AS \\REMARKS VARCHAR(254) " +
    "from DB.DBA.SYS_KEYS";

   /**
    * Gets the table types available in this database.  The results
    * are ordered by table type.
    *
    * <P>The table type is:
    *  <OL>
    *	<LI><B>TABLE_TYPE</B> String => table type.  Typical types are "TABLE",
    *			"VIEW",	"SYSTEM TABLE", "GLOBAL TEMPORARY",
    *			"LOCAL TEMPORARY", "ALIAS", "SYNONYM".
    *  </OL>
    *
    * @return ResultSet - each row has a single String column that is a
    * table type
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public ResultSet getTableTypes() throws SQLException
   {
     return connection.createStatement().executeQuery(getTableTypes_text);
   }

   private static final String getColumsText_case0 =
       "SELECT " +
         "name_part(k.KEY_TABLE,0) AS \\TABLE_CAT VARCHAR(128), " +
	 "name_part(k.KEY_TABLE,1) AS \\TABLE_SCHEM VARCHAR(128), " +
	 "name_part(k.KEY_TABLE,2) AS \\TABLE_NAME VARCHAR(128), " +
	 "c.\"COLUMN\" AS \\COLUMN_NAME VARCHAR(128), " +
	 "dv_to_sql_type(c.COL_DTP) AS \\DATA_TYPE SMALLINT, " +
	 "dv_type_title(c.COL_DTP) AS \\TYPE_NAME VARCHAR(128), " +
	 "c.COL_PREC AS \\COLUMN_SIZE INTEGER, " +
	 "NULL AS \\BUFFER_LENGTH INTEGER, " +
	 "c.COL_SCALE AS \\DECIMAL_DIGITS SMALLINT, " +
	 "2 AS \\NUM_PREC_RADIX SMALLINT, " +
	 "either(isnull(c.COL_NULLABLE),2,c.COL_NULLABLE) AS \\NULLABLE SMALLINT, " +
	 "NULL AS \\REMARKS VARCHAR(254), " +
	 "NULL AS \\COLUMN_DEF VARCHAR(128), " +
	 "NULL AS \\SQL_DATA_TYPE INTEGER, " +
	 "NULL AS \\SQL_DATETIME_SUB INTEGER, " +
	 "NULL AS \\CHAR_OCTET_LENGTH INTEGER, " +
	 "NULL AS \\ORDINAL_POSITION INTEGER, " +
	 "NULL AS \\IS_NULLABLE VARCHAR(10) " +
	 ",NULL AS \\SCOPE_CATLOG VARCHAR(128) " +
	 ",NULL AS \\SCOPE_SCHEMA VARCHAR(128) " +
	 ",NULL AS \\SCOPE_TABLE VARCHAR(128) " +
	 ",NULL AS \\SOURCE_DATA_TYPE SMALLINT " +
       "FROM " +
         "DB.DBA.SYS_KEYS k, " +
	 "DB.DBA.SYS_KEY_PARTS kp, " +
	 "DB.DBA.SYS_COLS c " +
       "WHERE " +
         "name_part(k.KEY_TABLE,0) LIKE ? " +
	 "AND name_part(k.KEY_TABLE,1) LIKE ? " +
	 "AND name_part(k.KEY_TABLE,2) LIKE ? " +
	 "AND c.\"COLUMN\" LIKE ? " +
	 "AND c.\"COLUMN\" <> '_IDN' " +
	 "AND k.KEY_IS_MAIN = 1 " +
	 "AND k.KEY_MIGRATE_TO is null " +
	 "AND kp.KP_KEY_ID = k.KEY_ID " +
	 "AND COL_ID = KP_COL " +
       "ORDER BY k.KEY_TABLE, c.COL_ID";
   private static final String getColumsText_case2 =
       "SELECT " +
         "name_part(k.KEY_TABLE,0) AS \\TABLE_CAT VARCHAR(128), " +
	 "name_part(k.KEY_TABLE,1) AS \\TABLE_SCHEM VARCHAR(128), " +
	 "name_part(k.KEY_TABLE,2) AS \\TABLE_NAME VARCHAR(128)," +
	 "c.\"COLUMN\" AS \\COLUMN_NAME VARCHAR(128), " +
	 "dv_to_sql_type(c.COL_DTP) AS \\DATA_TYPE SMALLINT," +
	 "dv_type_title(c.COL_DTP) AS \\TYPE_NAME VARCHAR(128), " +
	 "c.COL_PREC AS \\COLUMN_SIZE INTEGER, " +
	 "NULL AS \\BUFFER_LENGTH INTEGER, " +
	 "c.COL_SCALE AS \\DECIMAL_DIGITS SMALLINT," +
	 "2 AS \\NUM_PREC_RADIX SMALLINT, " +
	 "either(isnull(c.COL_NULLABLE),2,c.COL_NULLABLE) AS \\NULLABLE SMALLINT," +
	 "NULL AS \\REMARKS VARCHAR(254), " +
	 "NULL AS \\COLUMN_DEF VARCHAR(128), " +
	 "NULL AS \\SQL_DATA_TYPE INTEGER, " +
	 "NULL AS \\SQL_DATETIME_SUB INTEGER," +
	 "NULL AS \\CHAR_OCTET_LENGTH INTEGER, " +
	 "NULL AS \\ORDINAL_POSITION INTEGER, " +
	 "NULL AS \\IS_NULLABLE VARCHAR(10) " +
	 ",NULL AS \\SCOPE_CATLOG VARCHAR(128) " +
	 ",NULL AS \\SCOPE_SCHEMA VARCHAR(128) " +
	 ",NULL AS \\SCOPE_TABLE VARCHAR(128) " +
	 ",NULL AS \\SOURCE_DATA_TYPE SMALLINT " +
       "FROM " +
         "DB.DBA.SYS_KEYS k, " +
	 "DB.DBA.SYS_KEY_PARTS kp, " +
	 "DB.DBA.SYS_COLS c " +
       "WHERE " +
         "upper(name_part(k.KEY_TABLE,0)) LIKE upper(?) " +
	 "AND upper(name_part(k.KEY_TABLE,1)) LIKE upper(?) " +
	 "AND upper(name_part(k.KEY_TABLE,2)) LIKE upper(?) " +
	 "AND upper (c.\"COLUMN\") LIKE upper(?) " +
	 "AND c.\"COLUMN\" <> '_IDN' " +
	 "AND k.KEY_IS_MAIN = 1 " +
	 "AND k.KEY_MIGRATE_TO is null " +
	 "AND kp.KP_KEY_ID = k.KEY_ID " +
	 "AND COL_ID = KP_COL " +
       "ORDER BY k.KEY_TABLE, c.COL_ID";

   private static final String getWideColumsText_case0 =
       "SELECT " +
         "charset_recode (name_part(k.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_CAT NVARCHAR(128), " +
	 "charset_recode (name_part(k.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_SCHEM NVARCHAR(128), " +
	 "charset_recode (name_part(k.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128), " +
	 "charset_recode (c.\"COLUMN\", 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128), " +
	 "dv_to_sql_type(c.COL_DTP) AS \\DATA_TYPE SMALLINT, " +
	 "dv_type_title(c.COL_DTP) AS \\TYPE_NAME VARCHAR(128), " +
	 "c.COL_PREC AS \\COLUMN_SIZE INTEGER, " +
	 "NULL AS \\BUFFER_LENGTH INTEGER, " +
	 "c.COL_SCALE AS \\DECIMAL_DIGITS SMALLINT, " +
	 "2 AS \\NUM_PREC_RADIX SMALLINT, " +
	 "either(isnull(c.COL_NULLABLE),2,c.COL_NULLABLE) AS \\NULLABLE SMALLINT, " +
	 "NULL AS \\REMARKS VARCHAR(254), " +
	 "NULL AS \\COLUMN_DEF VARCHAR(128), " +
	 "NULL AS \\SQL_DATA_TYPE INTEGER, " +
	 "NULL AS \\SQL_DATETIME_SUB INTEGER, " +
	 "NULL AS \\CHAR_OCTET_LENGTH INTEGER, " +
	 "NULL AS \\ORDINAL_POSITION INTEGER, " +
	 "NULL AS \\IS_NULLABLE VARCHAR(10) " +
	 ",NULL AS \\SCOPE_CATLOG VARCHAR(128) " +
	 ",NULL AS \\SCOPE_SCHEMA VARCHAR(128) " +
	 ",NULL AS \\SCOPE_TABLE VARCHAR(128) " +
	 ",NULL AS \\SOURCE_DATA_TYPE SMALLINT " +
       "FROM " +
         "DB.DBA.SYS_KEYS k, " +
	 "DB.DBA.SYS_KEY_PARTS kp, " +
	 "DB.DBA.SYS_COLS c " +
       "WHERE " +
         "name_part(k.KEY_TABLE,0) LIKE ? " +
	 "AND name_part(k.KEY_TABLE,1) LIKE ? " +
	 "AND name_part(k.KEY_TABLE,2) LIKE ? " +
	 "AND c.\"COLUMN\" LIKE ? " +
	 "AND c.\"COLUMN\" <> '_IDN' " +
	 "AND k.KEY_IS_MAIN = 1 " +
	 "AND k.KEY_MIGRATE_TO is null " +
	 "AND kp.KP_KEY_ID = k.KEY_ID " +
	 "AND COL_ID = KP_COL " +
       "ORDER BY k.KEY_TABLE, c.COL_ID";
   private static final String getWideColumsText_case2 =
       "SELECT " +
         "charset_recode (name_part(k.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_CAT NVARCHAR(128), " +
	 "charset_recode (name_part(k.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_SCHEM NVARCHAR(128), " +
	 "charset_recode (name_part(k.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128), " +
	 "charset_recode (c.\"COLUMN\", 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128), " +
	 "dv_to_sql_type(c.COL_DTP) AS \\DATA_TYPE SMALLINT," +
	 "dv_type_title(c.COL_DTP) AS \\TYPE_NAME VARCHAR(128), " +
	 "c.COL_PREC AS \\COLUMN_SIZE INTEGER, " +
	 "NULL AS \\BUFFER_LENGTH INTEGER, " +
	 "c.COL_SCALE AS \\DECIMAL_DIGITS SMALLINT," +
	 "2 AS \\NUM_PREC_RADIX SMALLINT, " +
	 "either(isnull(c.COL_NULLABLE),2,c.COL_NULLABLE) AS \\NULLABLE SMALLINT," +
	 "NULL AS \\REMARKS VARCHAR(254), " +
	 "NULL AS \\COLUMN_DEF VARCHAR(128), " +
	 "NULL AS \\SQL_DATA_TYPE INTEGER, " +
	 "NULL AS \\SQL_DATETIME_SUB INTEGER," +
	 "NULL AS \\CHAR_OCTET_LENGTH INTEGER, " +
	 "NULL AS \\ORDINAL_POSITION INTEGER, " +
	 "NULL AS \\IS_NULLABLE VARCHAR(10) " +
	 ",NULL AS \\SCOPE_CATLOG VARCHAR(128) " +
	 ",NULL AS \\SCOPE_SCHEMA VARCHAR(128) " +
	 ",NULL AS \\SCOPE_TABLE VARCHAR(128) " +
	 ",NULL AS \\SOURCE_DATA_TYPE SMALLINT " +
       "FROM " +
         "DB.DBA.SYS_KEYS k, " +
	 "DB.DBA.SYS_KEY_PARTS kp, " +
	 "DB.DBA.SYS_COLS c " +
       "WHERE " +
         "charset_recode (upper(charset_recode (name_part(k.KEY_TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
	 "AND charset_recode (upper(charset_recode (name_part(k.KEY_TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
	 "AND charset_recode (upper(charset_recode (name_part(k.KEY_TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
	 "AND charset_recode (upper (charset_recode (c.\"COLUMN\", 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
	 "AND c.\"COLUMN\" <> '_IDN' " +
	 "AND k.KEY_IS_MAIN = 1 " +
	 "AND k.KEY_MIGRATE_TO is null " +
	 "AND kp.KP_KEY_ID = k.KEY_ID " +
	 "AND COL_ID = KP_COL " +
       "ORDER BY k.KEY_TABLE, c.COL_ID";

   /**
    * Gets a description of table columns available in
    * the specified catalog.
    *
    * <P>Only column descriptions matching the catalog, schema, table
    * and column name criteria are returned.  They are ordered by
    * TABLE_SCHEM, TABLE_NAME and ORDINAL_POSITION.
    *
    * <P>Each column description has the following columns:
    *  <OL>
    *	<LI><B>TABLE_CAT</B> String => table catalog (may be null)
    *	<LI><B>TABLE_SCHEM</B> String => table schema (may be null)
    *	<LI><B>TABLE_NAME</B> String => table name
    *	<LI><B>COLUMN_NAME</B> String => column name
    *	<LI><B>DATA_TYPE</B> short => SQL type from java.sql.Types
    *	<LI><B>TYPE_NAME</B> String => Data source dependent type name,
    *  for a UDT the type name is fully qualified
    *	<LI><B>COLUMN_SIZE</B> int => column size.  For char or date
    *	    types this is the maximum number of characters, for numeric or
    *	    decimal types this is precision.
    *	<LI><B>BUFFER_LENGTH</B> is not used.
    *	<LI><B>DECIMAL_DIGITS</B> int => the number of fractional digits
    *	<LI><B>NUM_PREC_RADIX</B> int => Radix (typically either 10 or 2)
    *	<LI><B>NULLABLE</B> int => is NULL allowed?
    *      <UL>
    *      <LI> columnNoNulls - might not allow NULL values
    *      <LI> columnNullable - definitely allows NULL values
    *      <LI> columnNullableUnknown - nullability unknown
    *      </UL>
    *	<LI><B>REMARKS</B> String => comment describing column (may be null)
    * <LI><B>COLUMN_DEF</B> String => default value (may be null)
    *	<LI><B>SQL_DATA_TYPE</B> int => unused
    *	<LI><B>SQL_DATETIME_SUB</B> int => unused
    *	<LI><B>CHAR_OCTET_LENGTH</B> int => for char types the
    *       maximum number of bytes in the column
    *	<LI><B>ORDINAL_POSITION</B> int	=> index of column in table
    *      (starting at 1)
    *	<LI><B>IS_NULLABLE</B> String => "NO" means column definitely
    *      does not allow NULL values; "YES" means the column might
    *      allow NULL values.  An empty string means nobody knows.
    *  </OL>
    *
    * @param catalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param schemaPattern a schema name pattern; "" retrieves those
    * without a schema
    * @param tableNamePattern a table name pattern
    * @param columnNamePattern a column name pattern
    * @return ResultSet - each row is a column description
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    * @see #getSearchStringEscape
    */
   public ResultSet getColumns(String catalog, String schemaPattern,
       String tableNamePattern, String columnNamePattern) throws SQLException
   {
      if(catalog == null)
         catalog = "";
      if(schemaPattern == null)
         schemaPattern = "";
      if(tableNamePattern == null)
         tableNamePattern = "";
      if(columnNamePattern == null)
         columnNamePattern = "";
      catalog = (catalog.equals("")) ? "%" : catalog;
      schemaPattern = (schemaPattern.equals("")) ? "%" : schemaPattern;
      tableNamePattern = (tableNamePattern.equals("")) ? "%" : tableNamePattern;
      columnNamePattern = (columnNamePattern.equals("")) ? "%" : columnNamePattern;

      VirtuosoPreparedStatement ps;
      if (connection.utf8_execs)
	ps = (VirtuosoPreparedStatement)connection.prepareStatement(
	    (connection.getCase() == 2) ? getWideColumsText_case2 : getWideColumsText_case0);
      else
	ps = (VirtuosoPreparedStatement)connection.prepareStatement(
	    (connection.getCase() == 2) ? getColumsText_case2 : getColumsText_case0);
      ps.setString(1,connection.escapeSQLString (catalog).toParamString());
      ps.setString(2,connection.escapeSQLString (schemaPattern).toParamString());
      ps.setString(3,connection.escapeSQLString (tableNamePattern).toParamString());
      ps.setString(4,connection.escapeSQLString (columnNamePattern).toParamString());
      ResultSet rs = ps.executeQuery();
      return rs;
   }

   /**
    * Gets a description of the access rights for a table's columns.
    *
    * <P>Only privileges matching the column name criteria are
    * returned.  They are ordered by COLUMN_NAME and PRIVILEGE.
    *
    * <P>Each privilege description has the following columns:
    *  <OL>
    *	<LI><B>TABLE_CAT</B> String => table catalog (may be null)
    *	<LI><B>TABLE_SCHEM</B> String => table schema (may be null)
    *	<LI><B>TABLE_NAME</B> String => table name
    *	<LI><B>COLUMN_NAME</B> String => column name
    *	<LI><B>GRANTOR</B> => grantor of access (may be null)
    *	<LI><B>GRANTEE</B> String => grantee of access
    *	<LI><B>PRIVILEGE</B> String => name of access (SELECT,
    *      INSERT, UPDATE, REFERENCES, ...)
    *	<LI><B>IS_GRANTABLE</B> String => "YES" if grantee is permitted
    *      to grant to others; "NO" if not; null if unknown
    *  </OL>
    *
    * @param catalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param schema a schema name; "" retrieves those without a schema
    * @param table a table name
    * @param columnNamePattern a column name pattern
    * @return ResultSet - each row is a column privilege description
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    * @see #getSearchStringEscape
    */
   public ResultSet getColumnPrivileges(String catalog, String schema, String table, String columnNamePattern) throws SQLException
   {
      if(catalog == null)
         catalog = "%";
      if(schema == null)
         schema = "%";
      if(table == null)
         table = "%";
      if(columnNamePattern == null)
         columnNamePattern = "%";

      VirtuosoPreparedStatement ps = (VirtuosoPreparedStatement)
	  (connection.utf8_execs ?
	      connection.prepareStatement("DB.DBA.column_privileges_utf8(?,?,?,?)") :
	      connection.prepareStatement("DB.DBA.column_privileges(?,?,?,?)"));

      ps.setString (1, connection.escapeSQLString(catalog).toParamString());
      ps.setString (2, connection.escapeSQLString(schema).toParamString());
      ps.setString (3, connection.escapeSQLString(table).toParamString());
      ps.setString (4, connection.escapeSQLString(columnNamePattern).toParamString());

      return ps.executeQuery();
   }

   /**
    * Gets a description of the access rights for each table available
    * in a catalog. Note that a table privilege applies to one or
    * more columns in the table. It would be wrong to assume that
    * this privilege applies to all columns (this may be true for
    * some systems but is not true for all.)
    *
    * <P>Only privileges matching the schema and table name
    * criteria are returned.  They are ordered by TABLE_SCHEM,
    * TABLE_NAME, and PRIVILEGE.
    *
    * <P>Each privilege description has the following columns:
    *  <OL>
    *	<LI><B>TABLE_CAT</B> String => table catalog (may be null)
    *	<LI><B>TABLE_SCHEM</B> String => table schema (may be null)
    *	<LI><B>TABLE_NAME</B> String => table name
    *	<LI><B>GRANTOR</B> => grantor of access (may be null)
    *	<LI><B>GRANTEE</B> String => grantee of access
    *	<LI><B>PRIVILEGE</B> String => name of access (SELECT,
    *      INSERT, UPDATE, REFERENCES, ...)
    *	<LI><B>IS_GRANTABLE</B> String => "YES" if grantee is permitted
    *      to grant to others; "NO" if not; null if unknown
    *  </OL>
    *
    * @param catalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param schemaPattern a schema name pattern; "" retrieves those
    * without a schema
    * @param tableNamePattern a table name pattern
    * @return ResultSet - each row is a table privilege description
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    * @see #getSearchStringEscape
    */
   public ResultSet getTablePrivileges(String catalog, String schemaPattern,
	String tableNamePattern) throws VirtuosoException
   {
      if(catalog == null)
         catalog = "%";
      if(schemaPattern == null)
         schemaPattern = "%";
      if(tableNamePattern == null)
         tableNamePattern = "%";

      VirtuosoPreparedStatement ps = (VirtuosoPreparedStatement)
	  connection.prepareStatement("DB.DBA.table_privileges(?,?,?)");

      ps.setString (1, connection.escapeSQLString(catalog).toParamString());
      ps.setString (2, connection.escapeSQLString(schemaPattern).toParamString());
      ps.setString (3, connection.escapeSQLString(tableNamePattern).toParamString());

      return ps.executeQuery();
   }

   public static final int VARCHAR_UNSPEC_SIZE = 4080;

   public static final String getWideBestRowIdText_case0 =
    "select" +
    " 0 AS \\SCOPE SMALLINT," +
    " charset_recode (SYS_COLS.\\COLUMN, 'UTF-8', '_WIDE_') AS COLUMN_NAME NVARCHAR(128)," +       /* NOT NULL */
    " dv_to_sql_type(SYS_COLS.COL_DTP) AS DATA_TYPE SMALLINT," + /* NOT NULL */
    " dv_type_title(SYS_COLS.COL_DTP) AS TYPE_NAME VARCHAR(128)," + /* NOT NULL */
    " case SYS_COLS.COL_PREC when 0 then " + VARCHAR_UNSPEC_SIZE + " else SYS_COLS.COL_PREC end AS COLUMN_SIZE INTEGER,\n" +
    " SYS_COLS.COL_PREC AS BUFFER_LENGTH INTEGER," +
    " SYS_COLS.COL_SCALE AS DECIMAL_DIGITS SMALLINT," +
    " 1 AS PSEUDO_COLUMN SMALLINT " +       /* = SQL_PC_NOT_PSEUDO */
    "from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS," +
    " DB.DBA.SYS_COLS SYS_COLS " +
    " where name_part(SYS_KEYS.KEY_TABLE,0) like ?" +
    "  and __any_grants (KEY_TABLE) " +
    "  and name_part(SYS_KEYS.KEY_TABLE,1) like ?" +
    "  and name_part(SYS_KEYS.KEY_TABLE,2) like ?" +
    "  and SYS_KEYS.KEY_IS_MAIN = 1" +
    "  and SYS_KEYS.KEY_MIGRATE_TO is NULL" +
    "  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID" +
    "  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS" +
    "  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL " +
    " order by SYS_KEYS.KEY_TABLE, SYS_KEY_PARTS.KP_NTH";

   public static final String getWideBestRowIdText_case2 =
    "select" +
    " 0 AS \\SCOPE SMALLINT," +
    " charset_recode (SYS_COLS.\\COLUMN, 'UTF-8', '_WIDE_') AS COLUMN_NAME NVARCHAR(128)," +       /* NOT NULL */
    " dv_to_sql_type(SYS_COLS.COL_DTP) AS DATA_TYPE SMALLINT," + /* NOT NULL */
    " dv_type_title(SYS_COLS.COL_DTP) AS TYPE_NAME VARCHAR(128)," + /* NOT NULL */
    " case SYS_COLS.COL_PREC when 0 then " + VARCHAR_UNSPEC_SIZE + " else SYS_COLS.COL_PREC end AS COLUMN_SIZE INTEGER,\n" +
    " SYS_COLS.COL_PREC AS BUFFER_LENGTH INTEGER," +
    " SYS_COLS.COL_SCALE AS DECIMAL_DIGITS SMALLINT," +
    " 1 AS PSEUDO_COLUMN SMALLINT " +       /* = SQL_PC_NOT_PSEUDO */
    "from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS," +
    " DB.DBA.SYS_COLS SYS_COLS " +
    " where charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8        ') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and __any_grants (KEY_TABLE) " +
    "  and charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8'        ) like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8'        ) like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and SYS_KEYS.KEY_IS_MAIN = 1" +
    "  and SYS_KEYS.KEY_MIGRATE_TO is NULL" +
    "  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID" +
    "  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS" +
    "  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL " +
    " order by SYS_KEYS.KEY_TABLE, SYS_KEY_PARTS.KP_NTH";


   public static final String getBestRowIdText_case0 =
    "select" +
    " 0 AS \\SCOPE SMALLINT," +
    " SYS_COLS.\\COLUMN AS COLUMN_NAME VARCHAR(128)," +     /* NOT NULL */
    " dv_to_sql_type(SYS_COLS.COL_DTP) AS DATA_TYPE SMALLINT," + /* NOT NULL */
    " dv_type_title(SYS_COLS.COL_DTP) AS TYPE_NAME VARCHAR(128)," +  /* NOT NULL */
    " case SYS_COLS.COL_PREC when 0 then " + VARCHAR_UNSPEC_SIZE + " else SYS_COLS.COL_PREC end AS COLUMN_SIZE INTEGER,\n" +
    " SYS_COLS.COL_PREC AS BUFFER_LENGTH INTEGER," +
    " SYS_COLS.COL_SCALE AS DECIMAL_DIGITS SMALLINT," +
    " 1 AS PSEUDO_COLUMN SMALLINT " +      /* = SQL_PC_NOT_PSEUDO */
    "from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS," +
    " DB.DBA.SYS_COLS SYS_COLS " +
    " where name_part(SYS_KEYS.KEY_TABLE,0) like ?" +
    "  and __any_grants (KEY_TABLE) " +
    "  and name_part(SYS_KEYS.KEY_TABLE,1) like ?" +
    "  and name_part(SYS_KEYS.KEY_TABLE,2) like ?" +
    "  and SYS_KEYS.KEY_IS_MAIN = 1" +
    "  and SYS_KEYS.KEY_MIGRATE_TO is NULL" +
    "  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID" +
    "  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS" +
    "  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL " +
    " order by SYS_KEYS.KEY_TABLE, SYS_KEY_PARTS.KP_NTH";

   public static final String getBestRowIdText_case2 =
    "select" +
    " 0 AS \\SCOPE SMALLINT," +
    " SYS_COLS.\\COLUMN AS COLUMN_NAME VARCHAR(128)," +    /* NOT NULL */
    " dv_to_sql_type(SYS_COLS.COL_DTP) AS DATA_TYPE SMALLINT," + /* NOT NULL */
    " dv_type_title(SYS_COLS.COL_DTP) AS TYPE_NAME VARCHAR(128)," + /* NOT NULL */
    " case SYS_COLS.COL_PREC when 0 then " + VARCHAR_UNSPEC_SIZE + " else SYS_COLS.COL_PREC end AS COLUMN_SIZE INTEGER,\n" +
    " SYS_COLS.COL_PREC AS BUFFER_LENGTH INTEGER," +
    " SYS_COLS.COL_SCALE AS DECIMAL_DIGITS SMALLINT," +
    " 1 AS PSEUDO_COLUMN SMALLINT " +      /* = SQL_PC_NOT_PSEUDO */
    "from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS," +
    " DB.DBA.SYS_COLS SYS_COLS " +
    " where upper(name_part(SYS_KEYS.KEY_TABLE,0)) like upper(?)" +
    "  and __any_grants (KEY_TABLE) " +
    "  and upper(name_part(SYS_KEYS.KEY_TABLE,1)) like upper(?)" +
    "  and upper(name_part(SYS_KEYS.KEY_TABLE,2)) like upper(?)" +
    "  and SYS_KEYS.KEY_IS_MAIN = 1" +
    "  and SYS_KEYS.KEY_MIGRATE_TO is NULL" +
    "  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID" +
    "  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS" +
    "  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL " +
    " order by SYS_KEYS.KEY_TABLE, SYS_KEY_PARTS.KP_NTH";


   /**
    * Gets a description of a table's optimal set of columns that
    * uniquely identifies a row. They are ordered by SCOPE.
    *
    * <P>Each column description has the following columns:
    *  <OL>
    *	<LI><B>SCOPE</B> short => actual scope of result
    *      <UL>
    *      <LI> bestRowTemporary - very temporary, while using row
    *      <LI> bestRowTransaction - valid for remainder of current transaction
    *      <LI> bestRowSession - valid for remainder of current session
    *      </UL>
    *	<LI><B>COLUMN_NAME</B> String => column name
    *	<LI><B>DATA_TYPE</B> short => SQL data type from java.sql.Types
    *	<LI><B>TYPE_NAME</B> String => Data source dependent type name,
    *  for a UDT the type name is fully qualified
    *	<LI><B>COLUMN_SIZE</B> int => precision
    *	<LI><B>BUFFER_LENGTH</B> int => not used
    *	<LI><B>DECIMAL_DIGITS</B> short	 => scale
    *	<LI><B>PSEUDO_COLUMN</B> short => is this a pseudo column
    *      like an Oracle ROWID
    *      <UL>
    *      <LI> bestRowUnknown - may or may not be pseudo column
    *      <LI> bestRowNotPseudo - is NOT a pseudo column
    *      <LI> bestRowPseudo - is a pseudo column
    *      </UL>
    *  </OL>
    *
    * @param catalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param schema a schema name; "" retrieves those without a schema
    * @param table a table name
    * @param scope the scope of interest; use same values as SCOPE
    * @param nullable include columns that are nullable?
    * @return ResultSet - each row is a column description
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public ResultSet getBestRowIdentifier(String catalog, String schema, String table, int scope, boolean nullable) throws VirtuosoException
   {
      if(catalog == null)
         catalog = "";
      if(schema == null)
         schema = "";
      if(table == null)
         table = "";
      catalog = (catalog.equals("")) ? "%" : catalog;
      schema = (schema.equals("")) ? "%" : schema;
      table = (table.equals("")) ? "%" : table;

      VirtuosoPreparedStatement ps;
      if (connection.utf8_execs)
	ps = (VirtuosoPreparedStatement)connection.prepareStatement(
	    (connection.getCase() == 2) ? getWideBestRowIdText_case2 : getWideBestRowIdText_case0);
      else
	ps = (VirtuosoPreparedStatement)connection.prepareStatement(
	    (connection.getCase() == 2) ? getBestRowIdText_case2 : getBestRowIdText_case0);
      ps.setString(1,connection.escapeSQLString (catalog).toParamString());
      ps.setString(2,connection.escapeSQLString (schema).toParamString());
      ps.setString(3,connection.escapeSQLString (table).toParamString());
      ResultSet rs = ps.executeQuery();
      return rs;
   }

   public static final String getWideBestVersionColsText_case0 =
    "select" +
          " null as \\SCOPE smallint," +
          " charset_recode (\\COLUMN, 'UTF-8', '_WIDE_') as COLUMN_NAME nvarchar(128)," +  /* not null */
          " dv_to_sql_type(COL_DTP) as DATA_TYPE smallint," +      /* not null */
          " dv_type_title(COL_DTP) as TYPE_NAME varchar(128)," +   /* not null */
          " case COL_PREC when 0 then " + VARCHAR_UNSPEC_SIZE + " else COL_PREC end AS COLUMN_SIZE INTEGER,\n" +
          " COL_PREC as BUFFER_LENGTH integer," +
          " COL_SCALE as DECIMAL_DIGITS smallint," +
          " 1 as PSEUDO_COLUMN smallint " + /* = sql_pc_not_pseudo */
          "from DB.DBA.SYS_COLS " +
          "where \\COL_DTP = 128" +
          "  and name_part(\\TABLE,0) like ?" +
          "  and name_part(\\TABLE,1) like ?" +
          "  and name_part(\\TABLE,2) like ? " +
          "order by \\TABLE, \\COL_ID";

   public static final String getWideBestVersionColsText_case2 =
    "select" +
          " NULL as \\SCOPE smallint," +
          " charset_recode (\\COLUMN, 'UTF-8', '_WIDE_') as COLUMN_NAME nvarchar(128)," +   /* NOT NULL */
          " dv_to_sql_type(COL_DTP) as DATA_TYPE smallint," +       /* NOT NULL */
          " dv_type_title(COL_DTP) as TYPE_NAME varchar(128)," +   /* NOT NULL */
          " case COL_PREC when 0 then " + VARCHAR_UNSPEC_SIZE + " else COL_PREC end AS COLUMN_SIZE INTEGER,\n" +
          " COL_PREC as BUFFER_LENGTH integer," +
          " COL_SCALE as DECIMAL_DIGITS smallint," +
          " 1 as PSEUDO_COLUMN smallint " +/* = SQL_PC_NOT_PSEUDO */
          "from DB.DBA.SYS_COLS " +
          "where \\COL_DTP = 128" +
          "  and charset_recode (upper(charset_recode (name_part(\\TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') lik        e charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
          "  and charset_recode (upper(charset_recode (name_part(\\TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') lik        e charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
          "  and charset_recode (upper(charset_recode (name_part(\\TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') lik        e charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
          "order by \\TABLE, \\COL_ID";

   public static final String getBestVersionColsText_case0 =
    "select" +
          " null as \\SCOPE smallint," +
          " \\COLUMN as COLUMN_NAME varchar(128)," +       /* not null */
          " dv_to_sql_type(COL_DTP) as DATA_TYPE smallint," +      /* not null */
          " dv_type_title(COL_DTP) as TYPE_NAME varchar(128)," +   /* not null */
          " case COL_PREC when 0 then " + VARCHAR_UNSPEC_SIZE + " else COL_PREC end AS COLUMN_SIZE INTEGER,\n" +
          " COL_PREC as BUFFER_LENGTH integer," +
          " COL_SCALE as DECIMAL_DIGITS smallint," +
          " 1 as PSEUDO_COLUMN smallint " +/* = sql_pc_not_pseudo */
          "from DB.DBA.SYS_COLS " +
          "where \\COL_DTP = 128" +
          "  and name_part(\\TABLE,0) like ?" +
          "  and name_part(\\TABLE,1) like ?" +
          "  and name_part(\\TABLE,2) like ? " +
          "order by \\TABLE, \\COL_ID";

   public static final String getBestVersionColsText_case2 =
    "select" +
          " null as \\SCOPE smallint," +
          " \\COLUMN as COLUMN_NAME varchar(128)," +       /* not null */
          " dv_to_sql_type(COL_DTP) as DATA_TYPE smallint," +      /* not null */
          " dv_type_title(COL_DTP) as TYPE_NAME varchar(128)," +   /* not null */
          " case COL_PREC when 0 then " + VARCHAR_UNSPEC_SIZE + " else COL_PREC end AS COLUMN_SIZE INTEGER,\n" +
          " COL_PREC as BUFFER_LENGTH integer," +
          " COL_SCALE as DECIMAL_DIGITS smallint," +
          " 1 as PSEUDO_COLUMN smallint " +/* = sql_pc_not_pseudo */
          "from DB.DBA.SYS_COLS " +
          "where \\COL_DTP = 128" +
          "  and upper(name_part(\\TABLE,0)) like upper(?)" +
          "  and upper(name_part(\\TABLE,1)) like upper(?)" +
          "  and upper(name_part(\\TABLE,2)) like upper(?) " +
          "order by \\TABLE, \\COL_ID";


   /**
    * Gets a description of a table's columns that are automatically
    * updated when any value in a row is updated.  They are
    * unordered.
    *
    * <P>Each column description has the following columns:
    *  <OL>
    *	<LI><B>SCOPE</B> short => is not used
    *	<LI><B>COLUMN_NAME</B> String => column name
    *	<LI><B>DATA_TYPE</B> short => SQL data type from java.sql.Types
    *	<LI><B>TYPE_NAME</B> String => Data source dependent type name
    *	<LI><B>COLUMN_SIZE</B> int => precision
    *	<LI><B>BUFFER_LENGTH</B> int => length of column value in bytes
    *	<LI><B>DECIMAL_DIGITS</B> short	 => scale
    *	<LI><B>PSEUDO_COLUMN</B> short => is this a pseudo column
    *      like an Oracle ROWID
    *      <UL>
    *      <LI> versionColumnUnknown - may or may not be pseudo column
    *      <LI> versionColumnNotPseudo - is NOT a pseudo column
    *      <LI> versionColumnPseudo - is a pseudo column
    *      </UL>
    *  </OL>
    *
    * @param catalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param schema a schema name; "" retrieves those without a schema
    * @param table a table name
    * @return ResultSet - each row is a column description
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public ResultSet getVersionColumns(String catalog, String schema, String table) throws VirtuosoException
   {
      if(catalog == null)
         catalog = "";
      if(schema == null)
         schema = "";
      if(table == null)
         table = "";
      catalog = (catalog.equals("")) ? "%" : catalog;
      schema = (schema.equals("")) ? "%" : schema;
      table = (table.equals("")) ? "%" : table;

      VirtuosoPreparedStatement ps;
      if (connection.utf8_execs)
	ps = (VirtuosoPreparedStatement)connection.prepareStatement(
	    (connection.getCase() == 2) ? getWideBestVersionColsText_case2 : getWideBestVersionColsText_case0);
      else
	ps = (VirtuosoPreparedStatement)connection.prepareStatement(
	    (connection.getCase() == 2) ? getBestVersionColsText_case2 : getBestVersionColsText_case0);
      ps.setString(1,connection.escapeSQLString (catalog).toParamString());
      ps.setString(2,connection.escapeSQLString (schema).toParamString());
      ps.setString(3,connection.escapeSQLString (table).toParamString());
      ResultSet rs = ps.executeQuery();
      return rs;
   }

   private static final String get_pk_case0 =
       "SELECT " +
         "name_part(v1.KEY_TABLE,0) AS \\TABLE_CAT VARCHAR(128), " +
	 "name_part(v1.KEY_TABLE,1) AS \\TABLE_SCHEM VARCHAR(128), " +
	 "name_part(v1.KEY_TABLE,2) AS \\TABLE_NAME VARCHAR(128), " +
	 "DB.DBA.SYS_COLS.\"COLUMN\" AS \\COLUMN_NAME VARCHAR(128), " +
	 "(kp.KP_NTH+1) AS \\KEY_SEQ SMALLINT, " +
	 "name_part (v1.KEY_NAME, 2) AS \\PK_NAME VARCHAR(128) " +
       "FROM " +
         "DB.DBA.SYS_KEYS v1, " +
	 "DB.DBA.SYS_KEYS v2, " +
	 "DB.DBA.SYS_KEY_PARTS kp, " +
	 "DB.DBA.SYS_COLS " +
       "WHERE " +
         "name_part(v1.KEY_TABLE,0) LIKE ? " +
	 "AND name_part(v1.KEY_TABLE,1) LIKE ? " +
	 "AND name_part(v1.KEY_TABLE,2) LIKE ? " +
	 "AND __any_grants (v1.KEY_TABLE) " +
	 "AND v1.KEY_IS_MAIN = 1 " +
	 "AND v1.KEY_MIGRATE_TO is NULL " +
	 "AND v1.KEY_SUPER_ID = v2.KEY_ID " +
	 "AND kp.KP_KEY_ID = v1.KEY_ID " +
	 "AND kp.KP_NTH < v1.KEY_DECL_PARTS " +
	 "AND DB.DBA.SYS_COLS.COL_ID = kp.KP_COL " +
	 "AND DB.DBA.SYS_COLS.\"COLUMN\" <> '_IDN' " +
       "ORDER BY v1.KEY_TABLE, kp.KP_NTH";

   private static final String get_pk_case2 =
       "SELECT " +
         "name_part(v1.KEY_TABLE,0) AS \\TABLE_CAT VARCHAR(128), " +
	 "name_part(v1.KEY_TABLE,1) AS \\TABLE_SCHEM VARCHAR(128), " +
	 "name_part(v1.KEY_TABLE,2) AS \\TABLE_NAME VARCHAR(128), " +
	 "DB.DBA.SYS_COLS.\"COLUMN\" AS \\COLUMN_NAME VARCHAR(128), " +
	 "(kp.KP_NTH+1) AS \\KEY_SEQ SMALLINT, " +
	 "name_part (v1.KEY_NAME, 2) AS \\PK_NAME VARCHAR(128) " +
       "FROM " +
         "DB.DBA.SYS_KEYS v1, " +
	 "DB.DBA.SYS_KEYS v2, " +
	 "DB.DBA.SYS_KEY_PARTS kp, " +
	 "DB.DBA.SYS_COLS " +
       "WHERE " +
         "upper (name_part(v1.KEY_TABLE,0)) LIKE upper (?) " +
	 "AND upper (name_part(v1.KEY_TABLE,1)) LIKE upper (?) " +
	 "AND upper (name_part(v1.KEY_TABLE,2)) LIKE upper (?) " +
	 "AND __any_grants (v1.KEY_TABLE) " +
	 "AND v1.KEY_IS_MAIN = 1 " +
	 "AND v1.KEY_MIGRATE_TO is NULL " +
	 "AND v1.KEY_SUPER_ID = v2.KEY_ID " +
	 "AND kp.KP_KEY_ID = v1.KEY_ID " +
	 "AND kp.KP_NTH < v1.KEY_DECL_PARTS " +
	 "AND DB.DBA.SYS_COLS.COL_ID = kp.KP_COL " +
	 "AND DB.DBA.SYS_COLS.\"COLUMN\" <> '_IDN' " +
       "ORDER BY v1.KEY_TABLE, kp.KP_NTH";

   private static final String get_wide_pk_case0 =
       "SELECT " +
         "charset_recode (name_part(v1.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_CAT NVARCHAR(128), " +
	 "charset_recode (name_part(v1.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_SCHEM NVARCHAR(128), " +
	 "charset_recode (name_part(v1.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128), " +
	 "charset_recode (DB.DBA.SYS_COLS.\"COLUMN\", 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128), " +
	 "(kp.KP_NTH+1) AS \\KEY_SEQ SMALLINT, " +
	 "charset_recode (name_part (v1.KEY_NAME, 2), 'UTF-8', '_WIDE_') AS \\PK_NAME VARCHAR(128) " +
       "FROM " +
         "DB.DBA.SYS_KEYS v1, " +
	 "DB.DBA.SYS_KEYS v2, " +
	 "DB.DBA.SYS_KEY_PARTS kp, " +
	 "DB.DBA.SYS_COLS " +
       "WHERE " +
         "name_part(v1.KEY_TABLE,0) LIKE ? " +
	 "AND name_part(v1.KEY_TABLE,1) LIKE ? " +
	 "AND name_part(v1.KEY_TABLE,2) LIKE ? " +
	 "AND __any_grants (v1.KEY_TABLE) " +
	 "AND v1.KEY_IS_MAIN = 1 " +
	 "AND v1.KEY_MIGRATE_TO is NULL " +
	 "AND v1.KEY_SUPER_ID = v2.KEY_ID " +
	 "AND kp.KP_KEY_ID = v1.KEY_ID " +
	 "AND kp.KP_NTH < v1.KEY_DECL_PARTS " +
	 "AND DB.DBA.SYS_COLS.COL_ID = kp.KP_COL " +
	 "AND DB.DBA.SYS_COLS.\"COLUMN\" <> '_IDN' " +
       "ORDER BY v1.KEY_TABLE, kp.KP_NTH";

   private static final String get_wide_pk_case2 =
       "SELECT " +
         "charset_recode (name_part(v1.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_CAT NVARCHAR(128), " +
	 "charset_recode (name_part(v1.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_SCHEM NVARCHAR(128), " +
	 "charset_recode (name_part(v1.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128), " +
	 "charset_recode (DB.DBA.SYS_COLS.\"COLUMN\", 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128), " +
	 "(kp.KP_NTH+1) AS \\KEY_SEQ SMALLINT, " +
	 "charset_recode (name_part (v1.KEY_NAME, 2), 'UTF-8', '_WIDE_') AS \\PK_NAME VARCHAR(128) " +
       "FROM " +
         "DB.DBA.SYS_KEYS v1, " +
	 "DB.DBA.SYS_KEYS v2, " +
	 "DB.DBA.SYS_KEY_PARTS kp, " +
	 "DB.DBA.SYS_COLS " +
       "WHERE " +
         "charset_recode (upper (charset_recode (name_part(v1.KEY_TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"+
	 " LIKE charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
	 "AND charset_recode (upper (charset_recode (name_part(v1.KEY_TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
	 "AND charset_recode (upper (charset_recode (name_part(v1.KEY_TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
	 "AND __any_grants (v1.KEY_TABLE) " +
	 "AND v1.KEY_IS_MAIN = 1 " +
	 "AND v1.KEY_MIGRATE_TO is NULL " +
	 "AND v1.KEY_SUPER_ID = v2.KEY_ID " +
	 "AND kp.KP_KEY_ID = v1.KEY_ID " +
	 "AND kp.KP_NTH < v1.KEY_DECL_PARTS " +
	 "AND DB.DBA.SYS_COLS.COL_ID = kp.KP_COL " +
	 "AND DB.DBA.SYS_COLS.\"COLUMN\" <> '_IDN' " +
       "ORDER BY v1.KEY_TABLE, kp.KP_NTH";

   /**
    * Gets a description of a table's primary key columns.  They
    * are ordered by COLUMN_NAME.
    *
    * <P>Each primary key column description has the following columns:
    *  <OL>
    *	<LI><B>TABLE_CAT</B> String => table catalog (may be null)
    *	<LI><B>TABLE_SCHEM</B> String => table schema (may be null)
    *	<LI><B>TABLE_NAME</B> String => table name
    *	<LI><B>COLUMN_NAME</B> String => column name
    *	<LI><B>KEY_SEQ</B> short => sequence number within primary key
    *	<LI><B>PK_NAME</B> String => primary key name (may be null)
    *  </OL>
    *
    * @param catalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param schema a schema name; "" retrieves those
    * without a schema
    * @param table a table name
    * @return ResultSet - each row is a primary key column description
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public ResultSet getPrimaryKeys(String catalog, String schema, String table) throws SQLException
   {
      if(catalog == null)
         catalog = "";
      if(schema == null)
         schema = "";
      if(table == null)
         table = "";
      catalog = catalog.equals("") ? "%" : catalog;
      schema = schema.equals("") ? "%" : schema;
      table = table.equals("") ? "%" : table;
      VirtuosoPreparedStatement ps;
      if (connection.utf8_execs)
	ps = (VirtuosoPreparedStatement)
	    connection.prepareStatement((connection.getCase() == 2) ? get_wide_pk_case2 : get_wide_pk_case0);
      else
	ps = (VirtuosoPreparedStatement)
	    connection.prepareStatement((connection.getCase() == 2) ? get_pk_case2 : get_pk_case0);
      ps.setString(1, connection.escapeSQLString (catalog).toParamString());
      ps.setString(2, connection.escapeSQLString (schema).toParamString());
      ps.setString(3, connection.escapeSQLString (table).toParamString());
      ResultSet rs = ps.executeQuery();
      return rs;
   }

   private static final String imp_keys_case0 =
       "SELECT " +
         "name_part (PK_TABLE, 0) as PKTABLE_CAT varchar (128), " +
	 "name_part (PK_TABLE, 1) as PKTABLE_SCHEM varchar (128), " +
	 "name_part (PK_TABLE, 2) as PKTABLE_NAME varchar (128), " +
	 "PKCOLUMN_NAME, " +
	 "name_part (FK_TABLE, 0) as FKTABLE_CAT varchar (128), " +
	 "name_part (FK_TABLE, 1) as FKTABLE_SCHEM varchar (128), " +
	 "name_part (FK_TABLE, 2) as FKTABLE_NAME varchar (128), " +
	 "FKCOLUMN_NAME, " +
	 "KEY_SEQ+1 AS KEY_SEQ, " +
	 "UPDATE_RULE, " +
	 "DELETE_RULE, " +
	 "FK_NAME, " +
	 "PK_NAME, " +
	 "7 AS DEFERRABILITY " +
       "FROM " +
         "DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS " +
       "WHERE " +
         "name_part (FK_TABLE, 0) LIKE ? " +
	 "AND name_part (FK_TABLE, 1) LIKE ? " +
	 "AND name_part (FK_TABLE, 2) LIKE ? " +
       "ORDER BY 5,6,7,10";
   private static final String imp_keys_case2 =
       "SELECT " +
         "name_part (PK_TABLE, 0) as PKTABLE_CAT varchar (128), " +
	 "name_part (PK_TABLE, 1) as PKTABLE_SCHEM varchar (128), " +
	 "name_part (PK_TABLE, 2) as PKTABLE_NAME varchar (128), " +
	 "PKCOLUMN_NAME, " +
	 "name_part (FK_TABLE, 0) as FKTABLE_CAT varchar (128), " +
	 "name_part (FK_TABLE, 1) as FKTABLE_SCHEM varchar (128), " +
	 "name_part (FK_TABLE, 2) as FKTABLE_NAME varchar (128), " +
	 "FKCOLUMN_NAME, " +
	 "KEY_SEQ+1 AS KEY_SEQ, " +
	 "UPDATE_RULE, " +
	 "DELETE_RULE, " +
	 "FK_NAME, " +
	 "PK_NAME, " +
	 "7 AS DEFERRABILITY " +
       "FROM " +
         "DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS " +
       "WHERE " +
         "upper (name_part (FK_TABLE, 0)) LIKE upper (?) " +
	 "AND upper (name_part (FK_TABLE, 1)) LIKE upper (?) " +
	 "AND upper (name_part (FK_TABLE, 2)) LIKE upper (?) " +
       "ORDER BY 5,6,7,10";

   private static final String imp_wide_keys_case0 =
       "SELECT " +
         "charset_recode (name_part (PK_TABLE, 0), 'UTF-8', '_WIDE_') as PKTABLE_CAT nvarchar (128), " +
	 "charset_recode (name_part (PK_TABLE, 1), 'UTF-8', '_WIDE_') as PKTABLE_SCHEM nvarchar (128), " +
	 "charset_recode (name_part (PK_TABLE, 2), 'UTF-8', '_WIDE_') as PKTABLE_NAME nvarchar (128), " +
	 "charset_recode (PKCOLUMN_NAME, 'UTF-8', '_WIDE_') as PKCOLUMN_NAME nvarchar (128), " +
	 "charset_recode (name_part (FK_TABLE, 0), 'UTF-8', '_WIDE_') as FKTABLE_CAT nvarchar (128), " +
	 "charset_recode (name_part (FK_TABLE, 1), 'UTF-8', '_WIDE_') as FKTABLE_SCHEM nvarchar (128), " +
	 "charset_recode (name_part (FK_TABLE, 2), 'UTF-8', '_WIDE_') as FKTABLE_NAME nvarchar (128), " +
	 "charset_recode (FKCOLUMN_NAME, 'UTF-8', '_WIDE_') as FKCOLUMN_NAME nvarchar (128), " +
	 "KEY_SEQ+1 AS KEY_SEQ, " +
	 "UPDATE_RULE, " +
	 "DELETE_RULE, " +
	 "charset_recode (FK_NAME, 'UTF-8', '_WIDE_') as FK_NAME nvarchar (128), " +
	 "charset_recode (PK_NAME, 'UTF-8', '_WIDE_') as PK_NAME nvarchar (128), " +
	 "7 AS DEFERRABILITY " +
       "FROM " +
         "DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS " +
       "WHERE " +
         "name_part (FK_TABLE, 0) LIKE ? " +
	 "AND name_part (FK_TABLE, 1) LIKE ? " +
	 "AND name_part (FK_TABLE, 2) LIKE ? " +
       "ORDER BY 5,6,7,10";
   private static final String imp_wide_keys_case2 =
       "SELECT " +
         "charset_recode (name_part (PK_TABLE, 0), 'UTF-8', '_WIDE_') as PKTABLE_CAT nvarchar (128), " +
	 "charset_recode (name_part (PK_TABLE, 1), 'UTF-8', '_WIDE_') as PKTABLE_SCHEM nvarchar (128), " +
	 "charset_recode (name_part (PK_TABLE, 2), 'UTF-8', '_WIDE_') as PKTABLE_NAME nvarchar (128), " +
	 "charset_recode (PKCOLUMN_NAME, 'UTF-8', '_WIDE_') as PKCOLUMN_NAME nvarchar (128), " +
	 "charset_recode (name_part (FK_TABLE, 0), 'UTF-8', '_WIDE_') as FKTABLE_CAT nvarchar (128), " +
	 "charset_recode (name_part (FK_TABLE, 1), 'UTF-8', '_WIDE_') as FKTABLE_SCHEM nvarchar (128), " +
	 "charset_recode (name_part (FK_TABLE, 2), 'UTF-8', '_WIDE_') as FKTABLE_NAME nvarchar (128), " +
	 "charset_recode (FKCOLUMN_NAME, 'UTF-8', '_WIDE_') as FKCOLUMN_NAME nvarchar (128), " +
	 "KEY_SEQ+1 AS KEY_SEQ, " +
	 "UPDATE_RULE, " +
	 "DELETE_RULE, " +
	 "charset_recode (FK_NAME, 'UTF-8', '_WIDE_') as FK_NAME nvarchar (128), " +
	 "charset_recode (PK_NAME, 'UTF-8', '_WIDE_') as PK_NAME nvarchar (128), " +
	 "7 AS DEFERRABILITY " +
       "FROM " +
         "DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS " +
       "WHERE " +
         "charset_recode (upper (charset_recode (name_part (FK_TABLE, 0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
         "AND charset_recode (upper (charset_recode (name_part (FK_TABLE, 1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
         "AND charset_recode (upper (charset_recode (name_part (FK_TABLE, 2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
       "ORDER BY 5,6,7,10";
   /**
    * Gets a description of the primary key columns that are
    * referenced by a table's foreign key columns (the primary keys
    * imported by a table).  They are ordered by PKTABLE_CAT,
    * PKTABLE_SCHEM, PKTABLE_NAME, and KEY_SEQ.
    *
    * <P>Each primary key column description has the following columns:
    *  <OL>
    *	<LI><B>PKTABLE_CAT</B> String => primary key table catalog
    *      being imported (may be null)
    *	<LI><B>PKTABLE_SCHEM</B> String => primary key table schema
    *      being imported (may be null)
    *	<LI><B>PKTABLE_NAME</B> String => primary key table name
    *      being imported
    *	<LI><B>PKCOLUMN_NAME</B> String => primary key column name
    *      being imported
    *	<LI><B>FKTABLE_CAT</B> String => foreign key table catalog (may be null)
    *	<LI><B>FKTABLE_SCHEM</B> String => foreign key table schema (may be null)
    *	<LI><B>FKTABLE_NAME</B> String => foreign key table name
    *	<LI><B>FKCOLUMN_NAME</B> String => foreign key column name
    *	<LI><B>KEY_SEQ</B> short => sequence number within foreign key
    *	<LI><B>UPDATE_RULE</B> short => What happens to
    *       foreign key when primary is updated:
    *      <UL>
    *      <LI> importedNoAction - do not allow update of primary
    *               key if it has been imported
    *      <LI> importedKeyCascade - change imported key to agree
    *               with primary key update
    *      <LI> importedKeySetNull - change imported key to NULL if
    *               its primary key has been updated
    *      <LI> importedKeySetDefault - change imported key to default values
    *               if its primary key has been updated
    *      <LI> importedKeyRestrict - same as importedKeyNoAction
    *                                 (for ODBC 2.x compatibility)
    *      </UL>
    *	<LI><B>DELETE_RULE</B> short => What happens to
    *      the foreign key when primary is deleted.
    *      <UL>
    *      <LI> importedKeyNoAction - do not allow delete of primary
    *               key if it has been imported
    *      <LI> importedKeyCascade - delete rows that import a deleted key
    *      <LI> importedKeySetNull - change imported key to NULL if
    *               its primary key has been deleted
    *      <LI> importedKeyRestrict - same as importedKeyNoAction
    *                                 (for ODBC 2.x compatibility)
    *      <LI> importedKeySetDefault - change imported key to default if
    *               its primary key has been deleted
    *      </UL>
    *	<LI><B>FK_NAME</B> String => foreign key name (may be null)
    *	<LI><B>PK_NAME</B> String => primary key name (may be null)
    *	<LI><B>DEFERRABILITY</B> short => can the evaluation of foreign key
    *      constraints be deferred until commit
    *      <UL>
    *      <LI> importedKeyInitiallyDeferred - see SQL92 for definition
    *      <LI> importedKeyInitiallyImmediate - see SQL92 for definition
    *      <LI> importedKeyNotDeferrable - see SQL92 for definition
    *      </UL>
    *  </OL>
    *
    * @param catalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param schema a schema name; "" retrieves those
    * without a schema
    * @param table a table name
    * @return ResultSet - each row is a primary key column description
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    * @see #getExportedKeys
    */
   public ResultSet getImportedKeys(String catalog, String schema, String table) throws SQLException
   {
      if(catalog == null)
         catalog = "";
      if(schema == null)
         schema = "";
      if(table == null)
         table = "";
      catalog = catalog.equals("") ? "%" : catalog;
      schema = schema.equals("") ? "%" : schema;
      table = table.equals("") ? "%" : table;
      VirtuosoPreparedStatement ps;
      if (connection.utf8_execs)
	ps = (VirtuosoPreparedStatement)
	    connection.prepareStatement((connection.getCase() == 2) ? imp_wide_keys_case2 : imp_wide_keys_case0);
      else
	ps = (VirtuosoPreparedStatement)
	    connection.prepareStatement((connection.getCase() == 2) ? imp_keys_case2 : imp_keys_case0);
      ps.setString(1, connection.escapeSQLString (catalog).toParamString());
      ps.setString(2, connection.escapeSQLString (schema).toParamString());
      ps.setString(3, connection.escapeSQLString (table).toParamString());
      ResultSet rs = ps.executeQuery();
      return rs;
   }

   private static final String exp_keys_mode0 =
       "SELECT " +
         "name_part (PK_TABLE, 0) as PKTABLE_CAT varchar (128), " +
	 "name_part (PK_TABLE, 1) as PKTABLE_SCHEM varchar (128), " +
	 "name_part (PK_TABLE, 2) as PKTABLE_NAME varchar (128), " +
	 "PKCOLUMN_NAME, " +
	 "name_part (FK_TABLE, 0) as FKTABLE_CAT varchar (128), " +
	 "name_part (FK_TABLE, 1) as FKTABLE_SCHEM varchar (128), " +
	 "name_part (FK_TABLE, 2) as FKTABLE_NAME varchar (128), " +
	 "FKCOLUMN_NAME, " +
	 "KEY_SEQ+1 AS KEY_SEQ, " +
	 "UPDATE_RULE, " +
	 "DELETE_RULE, " +
	 "FK_NAME, " +
	 "PK_NAME, " +
	 "7 AS DEFERRABILITY " +
       "FROM DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS " +
       "WHERE " +
         "name_part (PK_TABLE, 0) LIKE ? " +
	 "AND name_part (PK_TABLE, 1) LIKE ? " +
	 "AND name_part (PK_TABLE, 2) LIKE ? " +
       "ORDER BY 1,2,3,10";
   private static final String exp_keys_mode2 =
       "SELECT " +
         "name_part (PK_TABLE, 0) as PKTABLE_CAT varchar (128), " +
	 "name_part (PK_TABLE, 1) as PKTABLE_SCHEM varchar (128), " +
	 "name_part (PK_TABLE, 2) as PKTABLE_NAME varchar (128), " +
	 "PKCOLUMN_NAME, " +
	 "name_part (FK_TABLE, 0) as FKTABLE_CAT varchar (128), " +
	 "name_part (FK_TABLE, 1) as FKTABLE_SCHEM varchar (128), " +
	 "name_part (FK_TABLE, 2) as FKTABLE_NAME varchar (128), " +
	 "FKCOLUMN_NAME, " +
	 "KEY_SEQ+1 AS KEY_SEQ, " +
	 "UPDATE_RULE, " +
	 "DELETE_RULE, " +
	 "FK_NAME, " +
	 "PK_NAME, " +
	 "7 AS DEFERRABILITY " +
       "FROM DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS " +
       "WHERE " +
         "upper (name_part (PK_TABLE, 0)) LIKE upper (?) " +
	 "AND upper (name_part (PK_TABLE, 1)) LIKE upper (?) " +
	 "AND upper (name_part (PK_TABLE, 2)) LIKE upper (?) " +
       "ORDER BY 1,2,3,10";
   private static final String exp_wide_keys_mode0 =
       "SELECT " +
         "charset_recode (name_part (PK_TABLE, 0), 'UTF-8', '_WIDE_') as PKTABLE_CAT nvarchar (128), " +
	 "charset_recode (name_part (PK_TABLE, 1), 'UTF-8', '_WIDE_') as PKTABLE_SCHEM nvarchar (128), " +
	 "charset_recode (name_part (PK_TABLE, 2), 'UTF-8', '_WIDE_') as PKTABLE_NAME nvarchar (128), " +
	 "charset_recode (PKCOLUMN_NAME, 'UTF-8', '_WIDE_') as PKCOLUMN_NAME nvarchar (128), " +
	 "charset_recode (name_part (FK_TABLE, 0), 'UTF-8', '_WIDE_') as FKTABLE_CAT nvarchar (128), " +
	 "charset_recode (name_part (FK_TABLE, 1), 'UTF-8', '_WIDE_') as FKTABLE_SCHEM nvarchar (128), " +
	 "charset_recode (name_part (FK_TABLE, 2), 'UTF-8', '_WIDE_') as FKTABLE_NAME nvarchar (128), " +
	 "charset_recode (FKCOLUMN_NAME, 'UTF-8', '_WIDE_') as FKCOLUMN_NAME nvarchar (128), " +
	 "KEY_SEQ+1 AS KEY_SEQ, " +
	 "UPDATE_RULE, " +
	 "DELETE_RULE, " +
	 "charset_recode (FK_NAME, 'UTF-8', '_WIDE_') as FK_NAME nvarchar (128), " +
	 "charset_recode (PK_NAME, 'UTF-8', '_WIDE_') as PK_NAME nvarchar (128), " +
	 "7 AS DEFERRABILITY " +
       "FROM DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS " +
       "WHERE " +
         "name_part (PK_TABLE, 0) LIKE ? " +
	 "AND name_part (PK_TABLE, 1) LIKE ? " +
	 "AND name_part (PK_TABLE, 2) LIKE ? " +
       "ORDER BY 1,2,3,10";
   private static final String exp_wide_keys_mode2 =
       "SELECT " +
         "charset_recode (name_part (PK_TABLE, 0), 'UTF-8', '_WIDE_') as PKTABLE_CAT nvarchar (128), " +
	 "charset_recode (name_part (PK_TABLE, 1), 'UTF-8', '_WIDE_') as PKTABLE_SCHEM nvarchar (128), " +
	 "charset_recode (name_part (PK_TABLE, 2), 'UTF-8', '_WIDE_') as PKTABLE_NAME nvarchar (128), " +
	 "charset_recode (PKCOLUMN_NAME, 'UTF-8', '_WIDE_') as PKCOLUMN_NAME nvarchar (128), " +
	 "charset_recode (name_part (FK_TABLE, 0), 'UTF-8', '_WIDE_') as FKTABLE_CAT nvarchar (128), " +
	 "charset_recode (name_part (FK_TABLE, 1), 'UTF-8', '_WIDE_') as FKTABLE_SCHEM nvarchar (128), " +
	 "charset_recode (name_part (FK_TABLE, 2), 'UTF-8', '_WIDE_') as FKTABLE_NAME nvarchar (128), " +
	 "charset_recode (FKCOLUMN_NAME, 'UTF-8', '_WIDE_') as FKCOLUMN_NAME nvarchar (128), " +
	 "KEY_SEQ+1 AS KEY_SEQ, " +
	 "UPDATE_RULE, " +
	 "DELETE_RULE, " +
	 "charset_recode (FK_NAME, 'UTF-8', '_WIDE_') as FK_NAME nvarchar (128), " +
	 "charset_recode (PK_NAME, 'UTF-8', '_WIDE_') as PK_NAME nvarchar (128), " +
	 "7 AS DEFERRABILITY " +
       "FROM DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS " +
       "WHERE " +
         "charset_recode (upper (charset_recode (name_part (PK_TABLE, 0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
         "AND charset_recode (upper (charset_recode (name_part (PK_TABLE, 1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
         "AND charset_recode (upper (charset_recode (name_part (PK_TABLE, 2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
       "ORDER BY 1,2,3,10";
   /**
    * Gets a description of the foreign key columns that reference a
    * table's primary key columns (the foreign keys exported by a
    * table).  They are ordered by FKTABLE_CAT, FKTABLE_SCHEM,
    * FKTABLE_NAME, and KEY_SEQ.
    *
    * <P>Each foreign key column description has the following columns:
    *  <OL>
    *	<LI><B>PKTABLE_CAT</B> String => primary key table catalog (may be null)
    *	<LI><B>PKTABLE_SCHEM</B> String => primary key table schema (may be null)
    *	<LI><B>PKTABLE_NAME</B> String => primary key table name
    *	<LI><B>PKCOLUMN_NAME</B> String => primary key column name
    *	<LI><B>FKTABLE_CAT</B> String => foreign key table catalog (may be null)
    *      being exported (may be null)
    *	<LI><B>FKTABLE_SCHEM</B> String => foreign key table schema (may be null)
    *      being exported (may be null)
    *	<LI><B>FKTABLE_NAME</B> String => foreign key table name
    *      being exported
    *	<LI><B>FKCOLUMN_NAME</B> String => foreign key column name
    *      being exported
    *	<LI><B>KEY_SEQ</B> short => sequence number within foreign key
    *	<LI><B>UPDATE_RULE</B> short => What happens to
    *       foreign key when primary is updated:
    *      <UL>
    *      <LI> importedNoAction - do not allow update of primary
    *               key if it has been imported
    *      <LI> importedKeyCascade - change imported key to agree
    *               with primary key update
    *      <LI> importedKeySetNull - change imported key to NULL if
    *               its primary key has been updated
    *      <LI> importedKeySetDefault - change imported key to default values
    *               if its primary key has been updated
    *      <LI> importedKeyRestrict - same as importedKeyNoAction
    *                                 (for ODBC 2.x compatibility)
    *      </UL>
    *	<LI><B>DELETE_RULE</B> short => What happens to
    *      the foreign key when primary is deleted.
    *      <UL>
    *      <LI> importedKeyNoAction - do not allow delete of primary
    *               key if it has been imported
    *      <LI> importedKeyCascade - delete rows that import a deleted key
    *      <LI> importedKeySetNull - change imported key to NULL if
    *               its primary key has been deleted     *      <LI> importedKeyRestrict - same as importedKeyNoAction
    *                                 (for ODBC 2.x compatibility)
    *      <LI> importedKeySetDefault - change imported key to default if
    *               its primary key has been deleted
    *      </UL>
    *	<LI><B>FK_NAME</B> String => foreign key name (may be null)
    *	<LI><B>PK_NAME</B> String => primary key name (may be null)
    *	<LI><B>DEFERRABILITY</B> short => can the evaluation of foreign key
    *      constraints be deferred until commit
    *      <UL>
    *      <LI> importedKeyInitiallyDeferred - see SQL92 for definition
    *      <LI> importedKeyInitiallyImmediate - see SQL92 for definition
    *      <LI> importedKeyNotDeferrable - see SQL92 for definition
    *      </UL>
    *  </OL>
    *
    * @param catalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param schema a schema name; "" retrieves those
    * without a schema
    * @param table a table name
    * @return ResultSet - each row is a foreign key column description
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    * @see #getImportedKeys
    */
   public ResultSet getExportedKeys(String catalog, String schema, String table) throws SQLException
   {
      if(catalog == null)
         catalog = "";
      if(schema == null)
         schema = "";
      if(table == null)
         table = "";
      catalog = catalog.equals("") ? "%" : catalog;
      schema =  schema.equals("") ? "%" : schema;
      table = table.equals("") ? "%" : table;

      VirtuosoPreparedStatement ps;
      if (connection.utf8_execs)
	ps = (VirtuosoPreparedStatement)
	    connection.prepareStatement((connection.getCase() == 2) ? exp_wide_keys_mode2 : exp_wide_keys_mode0);
      else
	ps = (VirtuosoPreparedStatement)
	    connection.prepareStatement((connection.getCase() == 2) ? exp_keys_mode2 : exp_keys_mode0);
      ps.setString(1, connection.escapeSQLString (catalog).toParamString());
      ps.setString(2, connection.escapeSQLString (schema).toParamString());
      ps.setString(3, connection.escapeSQLString (table).toParamString());
      ResultSet rs = ps.executeQuery();
      return rs;
   }


    public static final String fk_text_casemode_0 =
    "select" +
    " name_part (PK_TABLE, 0) as PKTABLE_CAT varchar (128)," +
    " name_part (PK_TABLE, 1) as PKTABLE_SCHEM varchar (128)," +
    " name_part (PK_TABLE, 2) as PKTABLE_NAME varchar (128)," +
    " PKCOLUMN_NAME," +
    " name_part (FK_TABLE, 0) as FKTABLE_CAT varchar (128)," +
    " name_part (FK_TABLE, 1) as FKTABLE_SCHEM varchar (128)," +
    " name_part (FK_TABLE, 2) as FKTABLE_NAME varchar (128)," +
    " FKCOLUMN_NAME," +
    " (KEY_SEQ + 1) as KEY_SEQ SMALLINT," +
    " (case UPDATE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as UPDATE_RULE smallint," +
    " (case DELETE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as DELETE_RULE smallint," +
    " FK_NAME," +
    " PK_NAME, " +
    " NULL as DEFERRABILITY " +
    "from DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS " +
    "where name_part (PK_TABLE, 0) like ?" +
    "  and name_part (PK_TABLE, 1) like ?" +
    "  and name_part (PK_TABLE, 2) like ?" +
    "  and name_part (FK_TABLE, 0) like ?" +
    "  and name_part (FK_TABLE, 1) like ?" +
    "  and name_part (FK_TABLE, 2) like ? " +
    "order by 1, 2, 3, 5, 6, 7, 9";

    public static final String fk_text_casemode_2 =
    "select" +
    " name_part (PK_TABLE, 0) as PKTABLE_CAT varchar (128)," +
    " name_part (PK_TABLE, 1) as PKTABLE_SCHEM varchar (128)," +
    " name_part (PK_TABLE, 2) as PKTABLE_NAME varchar (128)," +
    " PKCOLUMN_NAME," +
    " name_part (FK_TABLE, 0) as FKTABLE_CAT varchar (128)," +
    " name_part (FK_TABLE, 1) as FKTABLE_SCHEM varchar (128)," +
    " name_part (FK_TABLE, 2) as FKTABLE_NAME varchar (128)," +
    " FKCOLUMN_NAME," +
    " (KEY_SEQ + 1) as KEY_SEQ SMALLINT," +
    " (case UPDATE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as UPDATE_RULE smallint," +
    " (case DELETE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as DELETE_RULE smallint," +
    " FK_NAME," +
    " PK_NAME, " +
    " NULL as DEFERRABILITY " +
    "from DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS " +
    "where upper (name_part (PK_TABLE, 0)) like upper (?)" +
    "  and upper (name_part (PK_TABLE, 1)) like upper (?)" +
    "  and upper (name_part (PK_TABLE, 2)) like upper (?)" +
    "  and upper (name_part (FK_TABLE, 0)) like upper (?)" +
    "  and upper (name_part (FK_TABLE, 1)) like upper (?)" +
    "  and upper (name_part (FK_TABLE, 2)) like upper (?) " +
    "order by 1, 2, 3, 5, 6, 7, 9";

    public static final String fk_textw_casemode_0 =
    "select" +
    " charset_recode (name_part (PK_TABLE, 0), 'UTF-8', '_WIDE_') as PKTABLE_CAT nvarchar (128)," +
    " charset_recode (name_part (PK_TABLE, 1), 'UTF-8', '_WIDE_') as PKTABLE_SCHEM nvarchar (128)," +
    " charset_recode (name_part (PK_TABLE, 2), 'UTF-8', '_WIDE_') as PKTABLE_NAME nvarchar (128)," +
    " charset_recode (PKCOLUMN_NAME, 'UTF-8', '_WIDE_') as PKCOLUMN_NAME nvarchar (128)," +
    " charset_recode (name_part (FK_TABLE, 0), 'UTF-8', '_WIDE_') as FKTABLE_CAT nvarchar (128)," +
    " charset_recode (name_part (FK_TABLE, 1), 'UTF-8', '_WIDE_') as FKTABLE_SCHEM nvarchar (128)," +
    " charset_recode (name_part (FK_TABLE, 2), 'UTF-8', '_WIDE_') as FKTABLE_NAME nvarchar (128)," +
    " charset_recode (FKCOLUMN_NAME, 'UTF-8', '_WIDE_') as FKCOLUMN_NAME nvarchar (128)," +
    " (KEY_SEQ + 1) as KEY_SEQ SMALLINT," +
    " (case UPDATE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as UPDATE_RULE smallint," +
    " (case DELETE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as DELETE_RULE smallint," +
    " charset_recode (FK_NAME, 'UTF-8', '_WIDE_') as FK_NAME nvarchar (128)," +
    " charset_recode (PK_NAME, 'UTF-8', '_WIDE_') as PK_NAME nvarchar (128), " +
    " NULL as DEFERRABILITY " +
    "from DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS " +
    "where name_part (PK_TABLE, 0) like ?" +
    "  and name_part (PK_TABLE, 1) like ?" +
    "  and name_part (PK_TABLE, 2) like ?" +
    "  and name_part (FK_TABLE, 0) like ?" +
    "  and name_part (FK_TABLE, 1) like ?" +
    "  and name_part (FK_TABLE, 2) like ? " +
    "order by 1, 2, 3, 5, 6, 7, 9";

    public static final String fk_textw_casemode_2 =
    "select" +
    " charset_recode (name_part (PK_TABLE, 0), 'UTF-8', '_WIDE_') as PKTABLE_CAT nvarchar (128)," +
    " charset_recode (name_part (PK_TABLE, 1), 'UTF-8', '_WIDE_') as PKTABLE_SCHEM nvarchar (128)," +
    " charset_recode (name_part (PK_TABLE, 2), 'UTF-8', '_WIDE_') as PKTABLE_NAME nvarchar (128)," +
    " charset_recode (PKCOLUMN_NAME, 'UTF-8', '_WIDE_') as PKCOLUMN_NAME nvarchar (128)," +
    " charset_recode (name_part (FK_TABLE, 0), 'UTF-8', '_WIDE_') as FKTABLE_CAT nvarchar (128)," +
    " charset_recode (name_part (FK_TABLE, 1), 'UTF-8', '_WIDE_') as FKTABLE_SCHEM nvarchar (128)," +
    " charset_recode (name_part (FK_TABLE, 2), 'UTF-8', '_WIDE_') as FKTABLE_NAME nvarchar (128)," +
    " charset_recode (FKCOLUMN_NAME, 'UTF-8', '_WIDE_') as FKCOLUMN_NAME nvarchar (128)," +
    " (KEY_SEQ + 1) as KEY_SEQ SMALLINT," +
    " (case UPDATE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as UPDATE_RULE smallint," +
    " (case DELETE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as DELETE_RULE smallint," +
    " charset_recode (FK_NAME, 'UTF-8', '_WIDE_') as FK_NAME nvarchar (128)," +
    " charset_recode (PK_NAME, 'UTF-8', '_WIDE_') as PK_NAME nvarchar (128), " +
    " NULL as DEFERRABILITY " +
    "from DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS " +
    "where charset_recode (upper (charset_recode (name_part (PK_TABLE, 0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and charset_recode (upper (charset_recode (name_part (PK_TABLE, 1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and charset_recode (upper (charset_recode (name_part (PK_TABLE, 2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and charset_recode (upper (charset_recode (name_part (FK_TABLE, 0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and charset_recode (upper (charset_recode (name_part (FK_TABLE, 1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and charset_recode (upper (charset_recode (name_part (FK_TABLE, 2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
    "order by 1, 2, 3, 5, 6, 7, 9";
   /**
    * Gets a description of the foreign key columns in the foreign key
    * table that reference the primary key columns of the primary key
    * table (describe how one table imports anothere is key.) This
    * should normally return a single foreign key/primary key pair
    * (most tables only import a foreign key from a table once.)  They
    * are ordered by FKTABLE_CAT, FKTABLE_SCHEM, FKTABLE_NAME, and
    * KEY_SEQ.
    *
    * <P>Each foreign key column description has the following columns:
    *  <OL>
    *	<LI><B>PKTABLE_CAT</B> String => primary key table catalog (may be null)
    *	<LI><B>PKTABLE_SCHEM</B> String => primary key table schema (may be null)
    *	<LI><B>PKTABLE_NAME</B> String => primary key table name
    *	<LI><B>PKCOLUMN_NAME</B> String => primary key column name
    *	<LI><B>FKTABLE_CAT</B> String => foreign key table catalog (may be null)
    *      being exported (may be null)
    *	<LI><B>FKTABLE_SCHEM</B> String => foreign key table schema (may be null)
    *      being exported (may be null)
    *	<LI><B>FKTABLE_NAME</B> String => foreign key table name
    *      being exported
    *	<LI><B>FKCOLUMN_NAME</B> String => foreign key column name
    *      being exported
    *	<LI><B>KEY_SEQ</B> short => sequence number within foreign key
    *	<LI><B>UPDATE_RULE</B> short => What happens to
    *       foreign key when primary is updated:
    *      <UL>
    *      <LI> importedNoAction - do not allow update of primary
    *               key if it has been imported
    *      <LI> importedKeyCascade - change imported key to agree
    *               with primary key update
    *      <LI> importedKeySetNull - change imported key to NULL if
    *               its primary key has been updated
    *      <LI> importedKeySetDefault - change imported key to default values
    *               if its primary key has been updated
    *      <LI> importedKeyRestrict - same as importedKeyNoAction
    *                                 (for ODBC 2.x compatibility)
    *      </UL>
    *	<LI><B>DELETE_RULE</B> short => What happens to
    *      the foreign key when primary is deleted.
    *      <UL>
    *      <LI> importedKeyNoAction - do not allow delete of primary
    *               key if it has been imported
    *      <LI> importedKeyCascade - delete rows that import a deleted key
    *      <LI> importedKeySetNull - change imported key to NULL if
    *               its primary key has been deleted
    *      <LI> importedKeyRestrict - same as importedKeyNoAction
    *                                 (for ODBC 2.x compatibility)
    *      <LI> importedKeySetDefault - change imported key to default if
    *               its primary key has been deleted
    *      </UL>
    *	<LI><B>FK_NAME</B> String => foreign key name (may be null)
    *	<LI><B>PK_NAME</B> String => primary key name (may be null)
    *	<LI><B>DEFERRABILITY</B> short => can the evaluation of foreign key
    *      constraints be deferred until commit
    *      <UL>
    *      <LI> importedKeyInitiallyDeferred - see SQL92 for definition
    *      <LI> importedKeyInitiallyImmediate - see SQL92 for definition
    *      <LI> importedKeyNotDeferrable - see SQL92 for definition
    *      </UL>
    *  </OL>
    *
    * @param primaryCatalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param primarySchema a schema name; "" retrieves those
    * without a schema
    * @param primaryTable the table name that exports the key
    * @param foreignCatalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param foreignSchema a schema name; "" retrieves those
    * without a schema
    * @param foreignTable the table name that imports the key
    * @return ResultSet - each row is a foreign key column description
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    * @see #getImportedKeys
    */
   public ResultSet getCrossReference(String primaryCatalog, String primarySchema, String primaryTable, String foreignCatalog, String foreignSchema, String foreignTable) throws VirtuosoException
   {
      if(primaryCatalog == null)
         primaryCatalog = "";
      if(primarySchema == null)
         primarySchema = "";
      if(primaryTable == null)
         primaryTable = "";
      if(foreignCatalog == null)
         foreignCatalog = "";
      if(foreignSchema == null)
         foreignSchema = "";
      if(foreignTable == null)
         foreignTable = "";

      primaryCatalog = primaryCatalog.equals("") ? "%" : primaryCatalog;
      primarySchema =  primarySchema.equals("") ? "%" : primarySchema;
      primaryTable = primaryTable.equals("") ? "%" : primaryTable;
      foreignCatalog = foreignCatalog.equals("") ? "%" : foreignCatalog;
      foreignSchema =  foreignSchema.equals("") ? "%" : foreignSchema;
      foreignTable = foreignTable.equals("") ? "%" : foreignTable;

      VirtuosoPreparedStatement ps;
      if (connection.utf8_execs)
	ps = (VirtuosoPreparedStatement)
	    connection.prepareStatement((connection.getCase() == 2) ? fk_textw_casemode_2 : fk_textw_casemode_0);
      else
	ps = (VirtuosoPreparedStatement)
	    connection.prepareStatement((connection.getCase() == 2) ? fk_text_casemode_2 : fk_text_casemode_0);
      ps.setString(1, connection.escapeSQLString (primaryCatalog).toParamString());
      ps.setString(2, connection.escapeSQLString (primarySchema).toParamString());
      ps.setString(3, connection.escapeSQLString (primaryTable).toParamString());
      ps.setString(4, connection.escapeSQLString (foreignCatalog).toParamString());
      ps.setString(5, connection.escapeSQLString (foreignSchema).toParamString());
      ps.setString(6, connection.escapeSQLString (foreignTable).toParamString());
      ResultSet rs = ps.executeQuery();
      return rs;
   }

   /**
    * Gets a description of all the standard SQL types supported by
    * this database. They are ordered by DATA_TYPE and then by how
    * closely the data type maps to the corresponding JDBC SQL type.
    *
    * <P>Each type description has the following columns:
    *  <OL>
    *	<LI><B>TYPE_NAME</B> String => Type name
    *	<LI><B>DATA_TYPE</B> short => SQL data type from java.sql.Types
    *	<LI><B>PRECISION</B> int => maximum precision
    *	<LI><B>LITERAL_PREFIX</B> String => prefix used to quote a literal
    *      (may be null)
    *	<LI><B>LITERAL_SUFFIX</B> String => suffix used to quote a literal
    *       (may be null)
    *	<LI><B>CREATE_PARAMS</B> String => parameters used in creating
    *      the type (may be null)
    *	<LI><B>NULLABLE</B> short => can you use NULL for this type?
    *      <UL>
    *      <LI> typeNoNulls - does not allow NULL values
    *      <LI> typeNullable - allows NULL values
    *      <LI> typeNullableUnknown - nullability unknown
    *      </UL>
    *	<LI><B>CASE_SENSITIVE</B> boolean=> is it case sensitive?
    *	<LI><B>SEARCHABLE</B> short => can you use "WHERE" based on this type:
    *      <UL>
    *      <LI> typePredNone - No support
    *      <LI> typePredChar - Only supported with WHERE .. LIKE
    *      <LI> typePredBasic - Supported except for WHERE .. LIKE
    *      <LI> typeSearchable - Supported for all WHERE ..
    *      </UL>
    *	<LI><B>UNSIGNED_ATTRIBUTE</B> boolean => is it unsigned?
    *	<LI><B>FIXED_PREC_SCALE</B> boolean => can it be a money value?
    *	<LI><B>AUTO_INCREMENT</B> boolean => can it be used for an
    *      auto-increment value?
    *	<LI><B>LOCAL_TYPE_NAME</B> String => localized version of type name
    *      (may be null)
    *	<LI><B>MINIMUM_SCALE</B> short => minimum scale supported
    *	<LI><B>MAXIMUM_SCALE</B> short => maximum scale supported
    *	<LI><B>SQL_DATA_TYPE</B> int => unused
    *	<LI><B>SQL_DATETIME_SUB</B> int => unused
    *	<LI><B>NUM_PREC_RADIX</B> int => usually 2 or 10
    *  </OL>
    *
    * @return ResultSet - each row is a SQL type description
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public ResultSet getTypeInfo() throws SQLException
   {
      CallableStatement cs = connection.prepareCall("DB.DBA.gettypeinfojdbc(?)");
      cs.setInt(1, 0);
      ResultSet rs = cs.executeQuery();
      return rs;
   }

    private static final int SQL_INDEX_OBJECT_ID_STR = 8;

    public static final String sql_statistics_text_casemode_0 =
    "select" +
    " name_part(SYS_KEYS.KEY_TABLE,0) AS \\TABLE_CAT VARCHAR(128)," +
    " name_part(SYS_KEYS.KEY_TABLE,1) AS \\TABLE_SCHEM VARCHAR(128)," +
    " name_part(SYS_KEYS.KEY_TABLE,2) AS \\TABLE_NAME VARCHAR(128)," + /* NOT NULL */
    " iszero(SYS_KEYS.KEY_IS_UNIQUE) AS \\NON_UNIQUE SMALLINT," +
    " name_part (SYS_KEYS.KEY_TABLE, 0) AS \\INDEX_QUALIFIER VARCHAR(128)," +
    " name_part (SYS_KEYS.KEY_NAME, 2) AS \\INDEX_NAME VARCHAR(128)," +
    " ((SYS_KEYS.KEY_IS_OBJECT_ID*" + SQL_INDEX_OBJECT_ID_STR + ") + " +
    "(3-(2*iszero(SYS_KEYS.KEY_CLUSTER_ON_ID)))) AS \\TYPE SMALLINT," + /* NOT NULL */
    " (SYS_KEY_PARTS.KP_NTH+1) AS \\ORDINAL_POSITION SMALLINT," +
    " SYS_COLS.\\COLUMN AS \\COLUMN_NAME VARCHAR(128)," +
    " NULL AS \\ASC_OR_DESC CHAR(1)," +	/* Value is either NULL, 'A' or 'D' */
    " NULL AS \\CARDINALITY INTEGER," +
    " NULL AS \\PAGES INTEGER," +
    " NULL AS \\FILTER_CONDITION VARCHAR(128) " +
    "from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS," +
    " DB.DBA.SYS_COLS SYS_COLS " +
    "where name_part(SYS_KEYS.KEY_TABLE,0) like ?" +
    "  and __any_grants (SYS_KEYS.KEY_TABLE) " +
    "  and name_part(SYS_KEYS.KEY_TABLE,1) like ?" +
    "  and name_part(SYS_KEYS.KEY_TABLE,2) like ?" +
    "  and SYS_KEYS.KEY_IS_UNIQUE >= ?" +
    "  and SYS_KEYS.KEY_MIGRATE_TO is NULL" +
    "  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID" +
    "  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS" +
    "  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL" +
    "  and SYS_COLS.\\COLUMN <> '_IDN' " +
    "order by SYS_KEYS.KEY_TABLE, SYS_KEYS.KEY_NAME, SYS_KEY_PARTS.KP_NTH";

    public static final String sql_statistics_text_casemode_2 =
    "select" +
    " name_part(SYS_KEYS.KEY_TABLE,0) AS \\TABLE_CAT VARCHAR(128)," +
    " name_part(SYS_KEYS.KEY_TABLE,1) AS \\TABLE_SCHEM VARCHAR(128)," +
    " name_part(SYS_KEYS.KEY_TABLE,2) AS \\TABLE_NAME VARCHAR(128)," +/* NOT NULL */
    " iszero(SYS_KEYS.KEY_IS_UNIQUE) AS \\NON_UNIQUE SMALLINT," +
    " name_part (SYS_KEYS.KEY_TABLE, 0) AS \\INDEX_QUALIFIER VARCHAR(128)," +
    " name_part (SYS_KEYS.KEY_NAME, 2) AS \\INDEX_NAME VARCHAR(128)," +
    " ((SYS_KEYS.KEY_IS_OBJECT_ID*" + SQL_INDEX_OBJECT_ID_STR + ") + " +
    "(3-(2*iszero(SYS_KEYS.KEY_CLUSTER_ON_ID)))) AS \\TYPE SMALLINT," +/* NOT NULL */
    " (SYS_KEY_PARTS.KP_NTH+1) AS \\ORDINAL_POSITION SMALLINT," +
    " SYS_COLS.\\COLUMN AS \\COLUMN_NAME VARCHAR(128)," +
    " NULL AS \\ASC_OR_DESC CHAR(1)," +	/* Value is either NULL, 'A' or 'D' */
    " NULL AS \\CARDINALITY INTEGER," +
    " NULL AS \\PAGES INTEGER," +
    " NULL AS \\FILTER_CONDITION VARCHAR(128) " +
    "from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS," +
    " DB.DBA.SYS_COLS SYS_COLS " +
    "where upper(name_part(SYS_KEYS.KEY_TABLE,0)) like upper(?)" +
    "  and __any_grants (SYS_KEYS.KEY_TABLE) " +
    "  and upper(name_part(SYS_KEYS.KEY_TABLE,1)) like upper(?)" +
    "  and upper(name_part(SYS_KEYS.KEY_TABLE,2)) like upper(?)" +
    "  and SYS_KEYS.KEY_IS_UNIQUE >= ?" +
    "  and SYS_KEYS.KEY_MIGRATE_TO is NULL" +
    "  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID" +
    "  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS" +
    "  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL" +
    "  and SYS_COLS.\\COLUMN <> '_IDN' " +
    "order by SYS_KEYS.KEY_TABLE, SYS_KEYS.KEY_NAME, SYS_KEY_PARTS.KP_NTH";

    public static final String sql_statistics_textw_casemode_0 =
    "select" +
    " charset_recode (name_part(SYS_KEYS.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_CAT NVARCHAR(128)," +
    " charset_recode (name_part(SYS_KEYS.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_SCHEM NVARCHAR(128)," +
    " charset_recode (name_part(SYS_KEYS.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128)," +/* NOT NULL */
    " iszero(SYS_KEYS.KEY_IS_UNIQUE) AS \\NON_UNIQUE SMALLINT," +
    " charset_recode (name_part (SYS_KEYS.KEY_TABLE, 0), 'UTF-8', '_WIDE_') AS \\INDEX_QUALIFIER NVARCHAR(128)," +
    " charset_recode (name_part (SYS_KEYS.KEY_NAME, 2), 'UTF-8', '_WIDE_') AS \\INDEX_NAME NVARCHAR(128)," +
    " ((SYS_KEYS.KEY_IS_OBJECT_ID*" + SQL_INDEX_OBJECT_ID_STR + ") + " +
    "(3-(2*iszero(SYS_KEYS.KEY_CLUSTER_ON_ID)))) AS \\TYPE SMALLINT," + /* NOT NULL */
    " (SYS_KEY_PARTS.KP_NTH+1) AS \\ORDINAL_POSITION SMALLINT," +
    " charset_recode (SYS_COLS.\\COLUMN, 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128)," +
    " NULL AS \\ASC_OR_DESC CHAR(1)," +	/* Value is either NULL, 'A' or 'D' */
    " NULL AS \\CARDINALITY INTEGER," +
    " NULL AS \\PAGES INTEGER," +
    " NULL AS \\FILTER_CONDITION VARCHAR(128) " +
    "from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS," +
    " DB.DBA.SYS_COLS SYS_COLS " +
    "where name_part(SYS_KEYS.KEY_TABLE,0) like ?" +
    "  and __any_grants (SYS_KEYS.KEY_TABLE) " +
    "  and name_part(SYS_KEYS.KEY_TABLE,1) like ?" +
    "  and name_part(SYS_KEYS.KEY_TABLE,2) like ?" +
    "  and SYS_KEYS.KEY_IS_UNIQUE >= ?" +
    "  and SYS_KEYS.KEY_MIGRATE_TO is NULL" +
    "  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID" +
    "  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS" +
    "  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL" +
    "  and SYS_COLS.\\COLUMN <> '_IDN' " +
    "order by SYS_KEYS.KEY_TABLE, SYS_KEYS.KEY_NAME, SYS_KEY_PARTS.KP_NTH";

    public static final String sql_statistics_textw_casemode_2 =
    "select" +
    " charset_recode (name_part(SYS_KEYS.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS TABLE_CAT NVARCHAR(128)," +
    " charset_recode (name_part(SYS_KEYS.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_SCHEM NVARCHAR(128)," +
    " charset_recode (name_part(SYS_KEYS.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128)," + /* NOT NULL */
    " iszero(SYS_KEYS.KEY_IS_UNIQUE) AS \\NON_UNIQUE SMALLINT," +
    " charset_recode (name_part (SYS_KEYS.KEY_TABLE, 0), 'UTF-8', '_WIDE_') AS \\INDEX_QUALIFIER NVARCHAR(128)," +
    " charset_recode (name_part (SYS_KEYS.KEY_NAME, 2), 'UTF-8', '_WIDE_') AS \\INDEX_NAME NVARCHAR(128)," +
    " ((SYS_KEYS.KEY_IS_OBJECT_ID*" + SQL_INDEX_OBJECT_ID_STR + ") + " +
    "(3-(2*iszero(SYS_KEYS.KEY_CLUSTER_ON_ID)))) AS \\TYPE SMALLINT," + /* NOT NULL */
    " (SYS_KEY_PARTS.KP_NTH+1) AS \\ORDINAL_POSITION SMALLINT," +
    " charset_recode (SYS_COLS.\\COLUMN, 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128)," +
    " NULL AS \\ASC_OR_DESC CHAR(1)," +	/* Value is either NULL, 'A' or 'D' */
    " NULL AS \\CARDINALITY INTEGER," +
    " NULL AS \\PAGES INTEGER," +
    " NULL AS \\FILTER_CONDITION VARCHAR(128) " +
    "from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS," +
    " DB.DBA.SYS_COLS SYS_COLS " +
    "where charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and __any_grants (SYS_KEYS.KEY_TABLE) " +
    "  and charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
    "  and SYS_KEYS.KEY_IS_UNIQUE >= ?" +
    "  and SYS_KEYS.KEY_MIGRATE_TO is NULL" +
    "  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID" +
    "  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS" +
    "  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL" +
    "  and SYS_COLS.\\COLUMN <> '_IDN' " +
    "order by SYS_KEYS.KEY_TABLE, SYS_KEYS.KEY_NAME, SYS_KEY_PARTS.KP_NTH";
   /**
    * Gets a description of a table's indices and statistics. They are
    * ordered by NON_UNIQUE, TYPE, INDEX_NAME, and ORDINAL_POSITION.
    *
    * <P>Each index column description has the following columns:
    *  <OL>
    *	<LI><B>TABLE_CAT</B> String => table catalog (may be null)
    *	<LI><B>TABLE_SCHEM</B> String => table schema (may be null)
    *	<LI><B>TABLE_NAME</B> String => table name
    *	<LI><B>NON_UNIQUE</B> boolean => Can index values be non-unique?
    *      false when TYPE is tableIndexStatistic
    *	<LI><B>INDEX_QUALIFIER</B> String => index catalog (may be null);
    *      null when TYPE is tableIndexStatistic
    *	<LI><B>INDEX_NAME</B> String => index name; null when TYPE is
    *      tableIndexStatistic
    *	<LI><B>TYPE</B> short => index type:
    *      <UL>
    *      <LI> tableIndexStatistic - this identifies table statistics that are
    *           returned in conjunction with a table's index descriptions
    *      <LI> tableIndexClustered - this is a clustered index
    *      <LI> tableIndexHashed - this is a hashed index
    *      <LI> tableIndexOther - this is some other style of index
    *      </UL>
    *	<LI><B>ORDINAL_POSITION</B> short => column sequence number
    *      within index; zero when TYPE is tableIndexStatistic
    *	<LI><B>COLUMN_NAME</B> String => column name; null when TYPE is
    *      tableIndexStatistic
    *	<LI><B>ASC_OR_DESC</B> String => column sort sequence, "A" => ascending,
    *      "D" => descending, may be null if sort sequence is not supported;
    *      null when TYPE is tableIndexStatistic
    *	<LI><B>CARDINALITY</B> int => When TYPE is tableIndexStatistic, then
    *      this is the number of rows in the table; otherwise, it is the
    *      number of unique values in the index.
    *	<LI><B>PAGES</B> int => When TYPE is  tableIndexStatistic then
    *      this is the number of pages used for the table, otherwise it
    *      is the number of pages used for the current index.
    *	<LI><B>FILTER_CONDITION</B> String => Filter condition, if any.
    *      (may be null)
    *  </OL>
    *
    * @param catalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param schema a schema name; "" retrieves those without a schema
    * @param table a table name
    * @param unique when true, return only indices for unique values;
    *     when false, return indices regardless of whether unique or not
    * @param approximate when true, result is allowed to reflect approximate
    *     or out of data values; when false, results are requested to be
    *     accurate
    * @return ResultSet - each row is an index column description
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public ResultSet getIndexInfo(String catalog, String schema, String table, boolean unique, boolean approximate) throws VirtuosoException
   {
      if(catalog == null)
         catalog = "";
      if(schema == null)
         schema = "";
      if(table == null)
         table = "";
      catalog = catalog.equals("") ? "%" : catalog;
      schema =  schema.equals("") ? "%" : schema;
      table = table.equals("") ? "%" : table;

      VirtuosoPreparedStatement ps;
      if (connection.utf8_execs)
	ps = (VirtuosoPreparedStatement)
	    connection.prepareStatement((connection.getCase() == 2) ? sql_statistics_textw_casemode_2 : sql_statistics_textw_casemode_0);
      else
	ps = (VirtuosoPreparedStatement)
	    connection.prepareStatement((connection.getCase() == 2) ? sql_statistics_text_casemode_2 : sql_statistics_text_casemode_0);
      ps.setString(1, connection.escapeSQLString (catalog).toParamString());
      ps.setString(2, connection.escapeSQLString (schema).toParamString());
      ps.setString(3, connection.escapeSQLString (table).toParamString());
      ps.setInt(4, unique ? 0 /* SQL_INDEX_UNIQUE */ : 1 /* SQL_INDEX_ALL */);
      ResultSet rs = ps.executeQuery();
      return rs;
   }

   // --------------------------- JDBC 2.0 ------------------------------
   /**
    * Retrieves the connection that produced this metadata object.
    *
    * @return the connection that produced this metadata object
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public Connection getConnection() throws VirtuosoException {
	return connection;
   }

   /**
    * Does the database support the given result set type?
    *
    * @param type defined in <code>java.sql.ResultSet</code>
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public boolean supportsResultSetType(int type) throws VirtuosoException
   {
      switch(type)
      {
         case VirtuosoResultSet.TYPE_FORWARD_ONLY:
            return true;
         case VirtuosoResultSet.TYPE_SCROLL_INSENSITIVE:
            return true;
         case VirtuosoResultSet.TYPE_SCROLL_SENSITIVE:
            return true;
      }
      ;
      return false;
   }

   /**
    * Does the database support the concurrency type in combination
    * with the given result set type?
    *
    * @param type defined in <code>java.sql.ResultSet</code>
    * @param concurrency type defined in <code>java.sql.ResultSet</code>
    * @return <code>true</code> if so; <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    * @see java.sql.Connection
    */
   public boolean supportsResultSetConcurrency(int type, int concurrency) throws VirtuosoException
   {
      return supportsResultSetType(type);
   }

   /**
    * Indicates whether a result set's own updates are visible.
    *
    * @param result set type, i.e. ResultSet.TYPE_XXX
    * @return <code>true</code> if updates are visible for the result set type;
    * <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public boolean ownUpdatesAreVisible(int type) throws VirtuosoException
   {
      return true;
   }

   /**
    * Indicates whether a result set's own deletes are visible.
    *
    * @param result set type, i.e. ResultSet.TYPE_XXX
    * @return <code>true</code> if deletes are visible for the result set type;
    * <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public boolean ownDeletesAreVisible(int type) throws VirtuosoException
   {
      return true;
   }

   /**
    * Indicates whether a result set's own inserts are visible.
    *
    * @param result set type, i.e. ResultSet.TYPE_XXX
    * @return <code>true</code> if inserts are visible for the result set type;
    * <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public boolean ownInsertsAreVisible(int type) throws VirtuosoException
   {
      return true;
   }

   /**
    * Indicates whether updates made by others are visible.
    *
    * @param result set type, i.e. ResultSet.TYPE_XXX
    * @return <code>true</code> if updates made by others
    * are visible for the result set type;
    * <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public boolean othersUpdatesAreVisible(int type) throws VirtuosoException
   {
      return true;
   }

   /**
    * Indicates whether deletes made by others are visible.
    *
    * @param result set type, i.e. ResultSet.TYPE_XXX
    * @return <code>true</code> if deletes made by others
    * are visible for the result set type;
    * <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public boolean othersDeletesAreVisible(int type) throws VirtuosoException
   {
      return true;
   }

   /**
    * Indicates whether inserts made by others are visible.
    *
    * @param result set type, i.e. ResultSet.TYPE_XXX
    * @return true if updates are visible for the result set type
    * @return <code>true</code> if inserts made by others
    * are visible for the result set type;
    * <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public boolean othersInsertsAreVisible(int type) throws VirtuosoException
   {
      return true;
   }

   /**
    * Indicates whether or not a visible row update can be detected by
    * calling the method <code>ResultSet.rowUpdated</code>.
    *
    * @param result set type, i.e. ResultSet.TYPE_XXX
    * @return <code>true</code> if changes are detected by the result set type;
    * <code>false</code> otherwise
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public boolean updatesAreDetected(int type) throws VirtuosoException
   {
      return true;
   }

   /**
    * Indicates whether or not a visible row delete can be detected by
    * calling ResultSet.rowDeleted().  If deletesAreDetected()
    * returns false, then deleted rows are removed from the result set.
    *
    * @param result set type, i.e. ResultSet.TYPE_XXX
    * @return true if changes are detected by the resultset type
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public boolean deletesAreDetected(int type) throws VirtuosoException
   {
      return true;
   }

   /**
    * Indicates whether or not a visible row insert can be detected
    * by calling ResultSet.rowInserted().
    *
    * @param result set type, i.e. ResultSet.TYPE_XXX
    * @return true if changes are detected by the resultset type
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public boolean insertsAreDetected(int type) throws VirtuosoException
   {
      return true;
   }

   /**
    * Indicates whether the driver supports batch updates.
    *
    * @return true if the driver supports batch updates; false otherwise
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public boolean supportsBatchUpdates() throws VirtuosoException
   {
      return true;
   }

   /**
    * Gets a description of the user-defined types defined in a particular
    * schema.  Schema-specific UDTs may have type JAVA_OBJECT, STRUCT,
    * or DISTINCT.
    *
    * <P>Only types matching the catalog, schema, type name and type
    * criteria are returned.  They are ordered by DATA_TYPE, TYPE_SCHEM
    * and TYPE_NAME.  The type name parameter may be a fully-qualified
    * name.  In this case, the catalog and schemaPattern parameters are
    * ignored.
    *
    * <P>Each type description has the following columns:
    *  <OL>
    *	<LI><B>TYPE_CAT</B> String => the type's catalog (may be null)
    *	<LI><B>TYPE_SCHEM</B> String => type's schema (may be null)
    *	<LI><B>TYPE_NAME</B> String => type name
    *  <LI><B>CLASS_NAME</B> String => Java class name
    *	<LI><B>DATA_TYPE</B> String => type value defined in java.sql.Types.
    *  One of JAVA_OBJECT, STRUCT, or DISTINCT
    *	<LI><B>REMARKS</B> String => explanatory comment on the type
    *  </OL>
    *
    * <P><B>Note:</B> If the driver does not support UDTs, an empty
    * result set is returned.
    *
    * @param catalog a catalog name; "" retrieves those without a
    * catalog; null means drop catalog name from the selection criteria
    * @param schemaPattern a schema name pattern; "" retrieves those
    * without a schema
    * @param typeNamePattern a type name pattern; may be a fully-qualified
    * name
    * @param types a list of user-named types to include (JAVA_OBJECT,
    * STRUCT, or DISTINCT); null returns all types
    * @return ResultSet - each row is a type description
    * @exception virtuoso.jdbc4.VirtuosoException if a database access error occurs
    */
   public ResultSet getUDTs(String catalog, String schemaPattern, String typeNamePattern, int[] types) throws VirtuosoException
   {
     String [] col_names = {
      "TYPE_CAT",
      "TYPE_SCHEM",
      "TYPE_NAME",
      "CLASS_NAME",
      "DATA_TYPE",
      "REMARKS",
      "BASE_TYPE" };
     int [] col_dtps = {
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_SHORT_INT };

     return new VirtuosoResultSet (connection, col_names, col_dtps);
   }

   /* JDK 1.4 functions */

    // ------------------- JDBC 3.0 -------------------------

    /**
     * Retrieves whether this database supports savepoints.
     *
     * @return <code>true</code> if savepoints are supported;
     *         <code>false</code> otherwise
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public boolean supportsSavepoints() throws SQLException
     {
       return false;
     }

    /**
     * Retrieves whether this database supports named parameters to callable
     * statements.
     *
     * @return <code>true</code> if named parameters are supported;
     *         <code>false</code> otherwise
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public boolean supportsNamedParameters() throws SQLException
     {
       return false;
     }

    /**
     * Retrieves whether it is possible to have multiple <code>ResultSet</code> objects
     * returned from a <code>CallableStatement</code> object
     * simultaneously.
     *
     * @return <code>true</code> if a <code>CallableStatement</code> object
     *         can return multiple <code>ResultSet</code> objects
     *         simultaneously; <code>false</code> otherwise
     * @exception SQLException if a datanase access error occurs
     * @since 1.4
     */
   public boolean supportsMultipleOpenResults() throws SQLException
     {
       return false;
     }

    /**
     * Retrieves whether auto-generated keys can be retrieved after
     * a statement has been executed.
     *
     * @return <code>true</code> if auto-generated keys can be retrieved
     *         after a statement has executed; <code>false</code> otherwise
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public boolean supportsGetGeneratedKeys() throws SQLException
     {
       return false;
     }

    /**
     * Retrieves a description of the user-defined type (UDT) hierarchies defined in a
     * particular schema in this database. Only the immediate super type/
     * sub type relationship is modeled.
     * <P>
     * Only supertype information for UDTs matching the catalog,
     * schema, and type name is returned. The type name parameter
     * may be a fully-qualified name. When the UDT name supplied is a
     * fully-qualified name, the catalog and schemaPattern parameters are
     * ignored.
     * <P>
     * If a UDT does not have a direct super type, it is not listed here.
     * A row of the <code>ResultSet</code> object returned by this method
     * describes the designated UDT and a direct supertype. A row has the following
     * columns:
     *  <OL>
     *  <LI><B>TYPE_CAT</B> String => the UDT's catalog (may be <code>null</code>)
     *  <LI><B>TYPE_SCHEM</B> String => UDT's schema (may be <code>null</code>)
     *  <LI><B>TYPE_NAME</B> String => type name of the UDT
     *  <LI><B>SUPERTYPE_CAT</B> String => the direct super type's catalog
     *                           (may be <code>null</code>)
     *  <LI><B>SUPERTYPE_SCHEM</B> String => the direct super type's schema
     *                             (may be <code>null</code>)
     *  <LI><B>SUPERTYPE_NAME</B> String => the direct super type's name
     *  </OL>
     *
     * <P><B>Note:</B> If the driver does not support type hierarchies, an
     * empty result set is returned.
     *
     * @param catalog a catalog name; "" retrieves those without a catalog;
     *        <code>null</code> means drop catalog name from the selection criteria
     * @param schemaPattern a schema name pattern; "" retrieves those
     *        without a schema
     * @param typeNamePattern a UDT name pattern; may be a fully-qualified
     *        name
     * @return a <code>ResultSet</code> object in which a row gives information
     *         about the designated UDT
     * @throws SQLException if a database access error occurs
     * @since 1.4
     */
   public ResultSet getSuperTypes(String catalog, String schemaPattern,
       String typeNamePattern) throws SQLException
     {
     String [] col_names = {
      "TYPE_CAT",
      "TYPE_SCHEM",
      "TYPE_NAME",
      "SUPERTYPE_CAT",
      "SUPERTYPE_SCHEM",
      "SUPERTYPE_NAME"
      };
     int [] col_dtps = {
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING
       };

     return new VirtuosoResultSet (connection, col_names, col_dtps);
     }

    /**
     * Retrieves a description of the table hierarchies defined in a particular
     * schema in this database.
     *
     * <P>Only supertable information for tables matching the catalog, schema
     * and table name are returned. The table name parameter may be a fully-
     * qualified name, in which case, the catalog and schemaPattern parameters
     * are ignored. If a table does not have a super table, it is not listed here.
     * Supertables have to be defined in the same catalog and schema as the
     * sub tables. Therefore, the type description does not need to include
     * this information for the supertable.
     *
     * <P>Each type description has the following columns:
     *  <OL>
     *  <LI><B>TABLE_CAT</B> String => the type's catalog (may be <code>null</code>)
     *  <LI><B>TABLE_SCHEM</B> String => type's schema (may be <code>null</code>)
     *  <LI><B>TABLE_NAME</B> String => type name
     *  <LI><B>SUPERTABLE_NAME</B> String => the direct super type's name
     *  </OL>
     *
     * <P><B>Note:</B> If the driver does not support type hierarchies, an
     * empty result set is returned.
     *
     * @param catalog a catalog name; "" retrieves those without a catalog;
     *        <code>null</code> means drop catalog name from the selection criteria
     * @param schemaPattern a schema name pattern; "" retrieves those
     *        without a schema
     * @param tableNamePattern a table name pattern; may be a fully-qualified
     *        name
     * @return a <code>ResultSet</code> object in which each row is a type description
     * @throws SQLException if a database access error occurs
     * @since 1.4
     */
   public ResultSet getSuperTables(String catalog, String schemaPattern,
       String tableNamePattern) throws SQLException
     {
     String [] col_names = {
      "TYPE_CAT",
      "TYPE_SCHEM",
      "TYPE_NAME",
      "SUPERTABLE_NAME"
      };
     int [] col_dtps = {
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING
       };

     return new VirtuosoResultSet (connection, col_names, col_dtps);
     }

    /**
     * Retrieves a description of the given attribute of the given type
     * for a user-defined type (UDT) that is available in the given schema
     * and catalog.
     * <P>
     * Descriptions are returned only for attributes of UDTs matching the
     * catalog, schema, type, and attribute name criteria. They are ordered by
     * TYPE_SCHEM, TYPE_NAME and ORDINAL_POSITION. This description
     * does not contain inherited attributes.
     * <P>
     * The <code>ResultSet</code> object that is returned has the following
     * columns:
     * <OL>
     *  <LI><B>TYPE_CAT</B> String => type catalog (may be <code>null</code>)
     *	<LI><B>TYPE_SCHEM</B> String => type schema (may be <code>null</code>)
     *	<LI><B>TYPE_NAME</B> String => type name
     *	<LI><B>ATTR_NAME</B> String => attribute name
     *	<LI><B>DATA_TYPE</B> short => attribute type SQL type from java.sql.Types
     *	<LI><B>ATTR_TYPE_NAME</B> String => Data source dependent type name.
     *  For a UDT, the type name is fully qualified. For a REF, the type name is
     *  fully qualified and represents the target type of the reference type.
     *	<LI><B>ATTR_SIZE</B> int => column size.  For char or date
     *	    types this is the maximum number of characters; for numeric or
     *	    decimal types this is precision.
     *	<LI><B>DECIMAL_DIGITS</B> int => the number of fractional digits
     *	<LI><B>NUM_PREC_RADIX</B> int => Radix (typically either 10 or 2)
     *	<LI><B>NULLABLE</B> int => whether NULL is allowed
     *      <UL>
     *      <LI> attributeNoNulls - might not allow NULL values
     *      <LI> attributeNullable - definitely allows NULL values
     *      <LI> attributeNullableUnknown - nullability unknown
     *      </UL>
     *	<LI><B>REMARKS</B> String => comment describing column (may be <code>null</code>)
     * 	<LI><B>ATTR_DEF</B> String => default value (may be <code>null</code>)
     *	<LI><B>SQL_DATA_TYPE</B> int => unused
     *	<LI><B>SQL_DATETIME_SUB</B> int => unused
     *	<LI><B>CHAR_OCTET_LENGTH</B> int => for char types the
     *       maximum number of bytes in the column
     *	<LI><B>ORDINAL_POSITION</B> int	=> index of column in table
     *      (starting at 1)
     *	<LI><B>IS_NULLABLE</B> String => "NO" means column definitely
     *      does not allow NULL values; "YES" means the column might
     *      allow NULL values.  An empty string means unknown.
     *  <LI><B>SCOPE_CATALOG</B> String => catalog of table that is the
     *      scope of a reference attribute (<code>null</code> if DATA_TYPE is not REF)
     *  <LI><B>SCOPE_SCHEMA</B> String => schema of table that is the
     *      scope of a reference attribute (<code>null</code> if DATA_TYPE is not REF)
     *  <LI><B>SCOPE_TABLE</B> String => table name that is the scope of a
     *      reference attribute (<code>null</code> if the DATA_TYPE is not REF)
     * <LI><B>SOURCE_DATA_TYPE</B> short => source type of a distinct type or user-generated
     *      Ref type,SQL type from java.sql.Types (<code>null</code> if DATA_TYPE
     *      is not DISTINCT or user-generated REF)
     *  </OL>
     * @param catalog a catalog name; must match the catalog name as it
     *        is stored in the database; "" retrieves those without a catalog;
     *        <code>null</code> means that the catalog name should not be used to narrow
     *        the search
     * @param schemaPattern a schema name pattern; must match the schema name
     *        as it is stored in the database; "" retrieves those without a schema;
     *        <code>null</code> means that the schema name should not be used to narrow
     *        the search
     * @param typeNamePattern a type name pattern; must match the
     *        type name as it is stored in the database
     * @param attributeNamePattern an attribute name pattern; must match the attribute
     *        name as it is declared in the database
     * @return a <code>ResultSet</code> object in which each row is an
     *         attribute description
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public ResultSet getAttributes(String catalog, String schemaPattern,
       String typeNamePattern, String attributeNamePattern) throws SQLException
     {
     String [] col_names = {
      "TYPE_CAT",
      "TYPE_SCHEM",
      "TYPE_NAME",
      "ATTR_NAME",
      "DATA_TYPE",
      "ATTR_TYPE_NAME",
      "ATTR_SIZE",
      "DECIMAL_DIGITS",
      "NUM_PREC_RADIX",
      "NULLABLE",
      "REMARKS",
      "ATTR_DEF",
      "SQL_DATA_TYPE",
      "SQL_DATETIME_SUB",
      "CHAR_OCTET_LENGTH",
      "ORDINAL_POSITION",
      "IS_NULLABLE",
      "SCOPE_CATALOG",
      "SCOPE_SCHEMA",
      "SCOPE_TABLE",
      "SOURCE_DATA_TYPE"
      };
     int [] col_dtps = {
      VirtuosoTypes.DV_STRING,
      VirtuosoTypes.DV_STRING,
      VirtuosoTypes.DV_STRING,
      VirtuosoTypes.DV_STRING,
      VirtuosoTypes.DV_SHORT_INT,
      VirtuosoTypes.DV_STRING,
      VirtuosoTypes.DV_LONG_INT,
      VirtuosoTypes.DV_LONG_INT,
      VirtuosoTypes.DV_LONG_INT,
      VirtuosoTypes.DV_LONG_INT,
      VirtuosoTypes.DV_STRING,
      VirtuosoTypes.DV_STRING,
      VirtuosoTypes.DV_LONG_INT,
      VirtuosoTypes.DV_LONG_INT,
      VirtuosoTypes.DV_LONG_INT,
      VirtuosoTypes.DV_LONG_INT,
      VirtuosoTypes.DV_STRING,
      VirtuosoTypes.DV_STRING,
      VirtuosoTypes.DV_STRING,
      VirtuosoTypes.DV_STRING,
      VirtuosoTypes.DV_SHORT_INT
       };

     return new VirtuosoResultSet (connection, col_names, col_dtps);
     }

    /**
     * Retrieves whether this database supports the given result set holdability.
     *
     * @param holdability one of the following constants:
     *          <code>ResultSet.HOLD_CURSORS_OVER_COMMIT</code> or
     *          <code>ResultSet.CLOSE_CURSORS_AT_COMMIT<code>
     * @return <code>true</code> if so; <code>false</code> otherwise
     * @exception SQLException if a database access error occurs
     * @see Connection
     * @since 1.4
     */
   public boolean supportsResultSetHoldability(int holdability) throws SQLException
     {
       return (holdability == ResultSet.CLOSE_CURSORS_AT_COMMIT);
     }

    /**
     * Retrieves the default holdability of this <code>ResultSet</code>
     * object.
     *
     * @return the default holdability; either
     *         <code>ResultSet.HOLD_CURSORS_OVER_COMMIT</code> or
     *         <code>ResultSet.CLOSE_CURSORS_AT_COMMIT</code>
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public int getResultSetHoldability() throws SQLException
     {
       return ResultSet.CLOSE_CURSORS_AT_COMMIT;
     }

    /**
     * Retrieves the major version number of the underlying database.
     *
     * @return the underlying database's major version
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public int getDatabaseMajorVersion() throws SQLException
     {
       return 3;
     }

    /**
     * Retrieves the minor version number of the underlying database.
     *
     * @return underlying database's minor version
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public int getDatabaseMinorVersion() throws SQLException
     {
       return 0;
     }

    /**
     * Retrieves the major JDBC version number for this
     * driver.
     *
     * @return JDBC version major number
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public int getJDBCMajorVersion() throws SQLException
     {
       return 3;
     }

    /**
     * Retrieves the minor JDBC version number for this
     * driver.
     *
     * @return JDBC version minor number
     * @exception SQLException if a database access error occurs
     * @since 1.4
     */
   public int getJDBCMinorVersion() throws SQLException
     {
       return 0;
     }

    /**
     * Indicates whether the SQLSTATEs returned by <code>SQLException.getSQLState</code>
     * is X/Open (now known as Open Group) SQL CLI or SQL99.
     * @return the type of SQLSTATEs, one of:
     *        sqlStateXOpen or
     *        sqlStateSQL99
     * @throws SQLException if a database access error occurs
     * @since 1.4
     */
   public int getSQLStateType() throws SQLException
     {
       return sqlStateXOpen;
     }

    /**
     * Indicates whether updates made to a LOB are made on a copy or directly
     * to the LOB.
     * @return <code>true</code> if updates are made to a copy of the LOB;
     *         <code>false</code> if updates are made directly to the LOB
     * @throws SQLException if a database access error occurs
     * @since 1.4
     */
   public boolean locatorsUpdateCopy() throws SQLException
     {
       return false;
     }

    /**
     * Retrieves weather this database supports statement pooling.
     *
     * @return <code>true</code> is so;
	       <code>false</code> otherwise
     * @throws SQLExcpetion if a database access error occurs
     * @since 1.4
     */
   public boolean supportsStatementPooling() throws SQLException
     {
       return true;
     }


    //------------------------- JDBC 4.0 -----------------------------------

    /**
     * Indicates whether or not this data source supports the SQL <code>ROWID</code> type,
     * and if so  the lifetime for which a <code>RowId</code> object remains valid.
     * <p>
     * The returned int values have the following relationship:
     * <pre>
     *     ROWID_UNSUPPORTED < ROWID_VALID_OTHER < ROWID_VALID_TRANSACTION
     *         < ROWID_VALID_SESSION < ROWID_VALID_FOREVER
     * </pre>
     * so conditional logic such as
     * <pre>
     *     if (metadata.getRowIdLifetime() > DatabaseMetaData.ROWID_VALID_TRANSACTION)
     * </pre>
     * can be used. Valid Forever means valid across all Sessions, and valid for
     * a Session means valid across all its contained Transactions.
     *
     * @return the status indicating the lifetime of a <code>RowId</code>
     * @throws SQLException if a database access error occurs
     * @since 1.6
     */
  public RowIdLifetime getRowIdLifetime() throws SQLException
  {
    return RowIdLifetime.ROWID_UNSUPPORTED;
  }


   private static final String getWideSchemasCaseMode0 =
       "SELECT DISTINCT " +
         "charset_recode (name_part(\\KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_SCHEM NVARCHAR(128)," +
	 "charset_recode (name_part(\\KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_CAT NVARCHAR(128) " +
       "FROM DB.DBA.SYS_KEYS " +
       "WHERE " +
	 "name_part(\\KEY_TABLE,0) LIKE ? AND " +
	 "name_part(\\KEY_TABLE,1) LIKE ? " +
       "ORDER BY 1, 2";

   private static final String getWideSchemasCaseMode2 =
       "SELECT DISTINCT " +
         "charset_recode (name_part(\\KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_SCHEM NVARCHAR(128)," +
	 "charset_recode (name_part(\\KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_CAT NVARCHAR(128) " +
       "FROM DB.DBA.SYS_KEYS " +
       "WHERE " +
	 "charset_recode (UPPER(charset_recode (name_part(\\KEY_TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (UPPER(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') AND " +
	 "charset_recode (UPPER(charset_recode (name_part(\\KEY_TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')" +
	 " LIKE charset_recode (UPPER(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') " +
       "ORDER BY 1, 2";

   private static final String getSchemasCaseMode0 =
       "SELECT DISTINCT " +
         "name_part(\\KEY_TABLE,1) AS \\TABLE_SCHEM VARCHAR(128)," +
	 "name_part(\\KEY_TABLE,0) AS \\TABLE_CAT VARCHAR(128) " +
       "FROM DB.DBA.SYS_KEYS " +
       "WHERE " +
	 "name_part(\\KEY_TABLE,0) LIKE ? AND " +
	 "name_part(\\KEY_TABLE,1) LIKE ? " +
       "ORDER BY 1, 2";

   private static final String getSchemasCaseMode2 =
       "SELECT DISTINCT " +
         "name_part(\\KEY_TABLE,1) AS \\TABLE_SCHEM VARCHAR(128)," +
	 "name_part(\\KEY_TABLE,0) AS \\TABLE_CAT VARCHAR(128) " +
       "FROM DB.DBA.SYS_KEYS " +
       "WHERE " +
	 "UPPER(name_part(\\KEY_TABLE,0)) LIKE UPPER(?) AND " +
	 "UPPER(name_part(\\KEY_TABLE,1)) LIKE UPPER(?) " +
       "ORDER BY 1, 2";


    /**
     * Retrieves the schema names available in this database.  The results
     * are ordered by <code>TABLE_CATALOG</code> and
     * <code>TABLE_SCHEM</code>.
     *
     * <P>The schema columns are:
     *  <OL>
     *	<LI><B>TABLE_SCHEM</B> String => schema name
     *  <LI><B>TABLE_CATALOG</B> String => catalog name (may be <code>null</code>)
     *  </OL>
     *
     *
     * @param catalog a catalog name; must match the catalog name as it is stored
     * in the database;"" retrieves those without a catalog; null means catalog
     * name should not be used to narrow down the search.
     * @param schemaPattern a schema name; must match the schema name as it is
     * stored in the database; null means
     * schema name should not be used to narrow down the search.
     * @return a <code>ResultSet</code> object in which each row is a
     *         schema description
     * @exception SQLException if a database access error occurs
     * @see #getSearchStringEscape
     * @since 1.6
     */
  public ResultSet getSchemas(String catalog, String schemaPattern) throws SQLException
  {
      if (catalog == null)
	catalog = "%";
      if (schemaPattern == null)
	schemaPattern = "%";

      VirtuosoPreparedStatement ps;
      if (connection.utf8_execs)
	ps = (VirtuosoPreparedStatement) connection.prepareStatement(
	    (connection.getCase() == 2) ?
	    getWideSchemasCaseMode2 :
	    getWideSchemasCaseMode0);
      else
	ps = (VirtuosoPreparedStatement) connection.prepareStatement(
	    (connection.getCase() == 2) ?
	    getSchemasCaseMode2 :
	    getSchemasCaseMode0);
      ps.setString(1,connection.escapeSQLString(catalog).toParamString());
      ps.setString(2,connection.escapeSQLString(schemaPattern).toParamString());
      ResultSet rs = ps.executeQuery();
      return rs;
  }

    /**
     * Retrieves whether this database supports invoking user-defined or vendor functions
     * using the stored procedure escape syntax.
     *
     * @return <code>true</code> if so; <code>false</code> otherwise
     * @exception SQLException if a database access error occurs
     * @since 1.6
     */
  public boolean supportsStoredFunctionsUsingCallSyntax() throws SQLException
  {
    return true;
  }

    /**
     * Retrieves whether a <code>SQLException</code> while autoCommit is <code>true</code> inidcates
     * that all open ResultSets are closed, even ones that are holdable.  When a <code>SQLException</code> occurs while
     * autocommit is <code>true</code>, it is vendor specific whether the JDBC driver responds with a commit operation, a
     * rollback operation, or by doing neither a commit nor a rollback.  A potential result of this difference
     * is in whether or not holdable ResultSets are closed.
     *
     * @return <code>true</code> if so; <code>false</code> otherwise
     * @exception SQLException if a database access error occurs
     * @since 1.6
     */
  public boolean autoCommitFailureClosesAllResultSets() throws SQLException
  {
    return false;
  }
	/**
	 * Retrieves a list of the client info properties
	 * that the driver supports.  The result set contains the following columns
	 * <p>
         * <ol>
	 * <li><b>NAME</b> String=> The name of the client info property<br>
	 * <li><b>MAX_LEN</b> int=> The maximum length of the value for the property<br>
	 * <li><b>DEFAULT_VALUE</b> String=> The default value of the property<br>
	 * <li><b>DESCRIPTION</b> String=> A description of the property.  This will typically
	 * 						contain information as to where this property is
	 * 						stored in the database.
	 * </ol>
         * <p>
	 * The <code>ResultSet</code> is sorted by the NAME column
	 * <p>
	 * @return	A <code>ResultSet</code> object; each row is a supported client info
         * property
	 * <p>
	 *  @exception SQLException if a database access error occurs
	 * <p>
	 * @since 1.6
	 */
  public ResultSet getClientInfoProperties() throws SQLException
  {
     String [] col_names = {
      "NAME",
      "MAX_LEN",
      "DEFAULT_VALUE",
      "DESCRIPTION"
      };
     int [] col_dtps = {
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_LONG_INT,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING
       };

     return new VirtuosoResultSet (connection, col_names, col_dtps);
  }

    /**
     * Retrieves a description of the  system and user functions available
     * in the given catalog.
     * <P>
     * Only system and user function descriptions matching the schema and
     * function name criteria are returned.  They are ordered by
     * <code>FUNCTION_CAT</code>, <code>FUNCTION_SCHEM</code>,
     * <code>FUNCTION_NAME</code> and
     * <code>SPECIFIC_ NAME</code>.
     *
     * <P>Each function description has the the following columns:
     *  <OL>
     *	<LI><B>FUNCTION_CAT</B> String => function catalog (may be <code>null</code>)
     *	<LI><B>FUNCTION_SCHEM</B> String => function schema (may be <code>null</code>)
     *	<LI><B>FUNCTION_NAME</B> String => function name.  This is the name
     * used to invoke the function
     *	<LI><B>REMARKS</B> String => explanatory comment on the function
     * <LI><B>FUNCTION_TYPE</B> short => kind of function:
     *      <UL>
     *      <LI>functionResultUnknown - Cannot determine if a return value
     *       or table will be returned
     *      <LI> functionNoTable- Does not return a table
     *      <LI> functionReturnsTable - Returns a table
     *      </UL>
     *	<LI><B>SPECIFIC_NAME</B> String  => the name which uniquely identifies
     *  this function within its schema.  This is a user specified, or DBMS
     * generated, name that may be different then the <code>FUNCTION_NAME</code>
     * for example with overload functions
     *  </OL>
     * <p>
     * A user may not have permission to execute any of the functions that are
     * returned by <code>getFunctions</code>
     *
     * @param catalog a catalog name; must match the catalog name as it
     *        is stored in the database; "" retrieves those without a catalog;
     *        <code>null</code> means that the catalog name should not be used to narrow
     *        the search
     * @param schemaPattern a schema name pattern; must match the schema name
     *        as it is stored in the database; "" retrieves those without a schema;
     *        <code>null</code> means that the schema name should not be used to narrow
     *        the search
     * @param functionNamePattern a function name pattern; must match the
     *        function name as it is stored in the database
     * @return <code>ResultSet</code> - each row is a function description
     * @exception SQLException if a database access error occurs
     * @see #getSearchStringEscape
     * @since 1.6
     */
  public ResultSet getFunctions(String catalog, String schemaPattern,
			    String functionNamePattern) throws SQLException
  {
     String [] col_names = {
      "FUNCTION_CAT",
      "FUNCTION_SCHEM",
      "FUNCTION_NAME",
      "REMARKS",
      "FUNCTION_TYPE",
      "SPECIFIC_NAME"
      };
     int [] col_dtps = {
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING
       };

     return new VirtuosoResultSet (connection, col_names, col_dtps);
  }

    /**
     * Retrieves a description of the given catalog's system or user
     * function parameters and return type.
     *
     * <P>Only descriptions matching the schema,  function and
     * parameter name criteria are returned. They are ordered by
     * <code>FUNCTION_CAT</code>, <code>FUNCTION_SCHEM</code>,
     * <code>FUNCTION_NAME</code> and
     * <code>SPECIFIC_ NAME</code>. Within this, the return value,
     * if any, is first. Next are the parameter descriptions in call
     * order. The column descriptions follow in column number order.
     *
     * <P>Each row in the <code>ResultSet</code>
     * is a parameter description, column description or
     * return type description with the following fields:
     *  <OL>
     *  <LI><B>FUNCTION_CAT</B> String => function catalog (may be <code>null</code>)
     *	<LI><B>FUNCTION_SCHEM</B> String => function schema (may be <code>null</code>)
     *	<LI><B>FUNCTION_NAME</B> String => function name.  This is the name
     * used to invoke the function
     *	<LI><B>COLUMN_NAME</B> String => column/parameter name
     *	<LI><B>COLUMN_TYPE</B> Short => kind of column/parameter:
     *      <UL>
     *      <LI> functionColumnUnknown - nobody knows
     *      <LI> functionColumnIn - IN parameter
     *      <LI> functionColumnInOut - INOUT parameter
     *      <LI> functionColumnOut - OUT parameter
     *      <LI> functionColumnReturn - function return value
     *      <LI> functionColumnResult - Indicates that the parameter or column
     *  is a column in the <code>ResultSet</code>
     *      </UL>
     *  <LI><B>DATA_TYPE</B> int => SQL type from java.sql.Types
     *	<LI><B>TYPE_NAME</B> String => SQL type name, for a UDT type the
     *  type name is fully qualified
     *	<LI><B>PRECISION</B> int => precision
     *	<LI><B>LENGTH</B> int => length in bytes of data
     *	<LI><B>SCALE</B> short => scale -  null is returned for data types where
     * SCALE is not applicable.
     *	<LI><B>RADIX</B> short => radix
     *	<LI><B>NULLABLE</B> short => can it contain NULL.
     *      <UL>
     *      <LI> functionNoNulls - does not allow NULL values
     *      <LI> functionNullable - allows NULL values
     *      <LI> functionNullableUnknown - nullability unknown
     *      </UL>
     *	<LI><B>REMARKS</B> String => comment describing column/parameter
     *	<LI><B>CHAR_OCTET_LENGTH</B> int  => the maximum length of binary
     * and character based parameters or columns.  For any other datatype the returned value
     * is a NULL
     *	<LI><B>ORDINAL_POSITION</B> int  => the ordinal position, starting
     * from 1, for the input and output parameters. A value of 0
     * is returned if this row describes the function's return value.
     * For result set columns, it is the
     * ordinal position of the column in the result set starting from 1.
     *	<LI><B>IS_NULLABLE</B> String  => ISO rules are used to determine
     * the nullability for a parameter or column.
     *       <UL>
     *       <LI> YES           --- if the parameter or column can include NULLs
     *       <LI> NO            --- if the parameter or column  cannot include NULLs
     *       <LI> empty string  --- if the nullability for the
     * parameter  or column is unknown
     *       </UL>
     *	<LI><B>SPECIFIC_NAME</B> String  => the name which uniquely identifies
     * this function within its schema.  This is a user specified, or DBMS
     * generated, name that may be different then the <code>FUNCTION_NAME</code>
     * for example with overload functions
     *  </OL>
     *
     * <p>The PRECISION column represents the specified column size for the given
     * parameter or column.
     * For numeric data, this is the maximum precision.  For character data, this is the length in characters.
     * For datetime datatypes, this is the length in characters of the String representation (assuming the
     * maximum allowed precision of the fractional seconds component). For binary data, this is the length in bytes.  For the ROWID datatype,
     * this is the length in bytes. Null is returned for data types where the
     * column size is not applicable.
     * @param catalog a catalog name; must match the catalog name as it
     *        is stored in the database; "" retrieves those without a catalog;
     *        <code>null</code> means that the catalog name should not be used to narrow
     *        the search
     * @param schemaPattern a schema name pattern; must match the schema name
     *        as it is stored in the database; "" retrieves those without a schema;
     *        <code>null</code> means that the schema name should not be used to narrow
     *        the search
     * @param functionNamePattern a procedure name pattern; must match the
     *        function name as it is stored in the database
     * @param columnNamePattern a parameter name pattern; must match the
     * parameter or column name as it is stored in the database
     * @return <code>ResultSet</code> - each row describes a
     * user function parameter, column  or return type
     *
     * @exception SQLException if a database access error occurs
     * @see #getSearchStringEscape
     * @since 1.6
     */
  public ResultSet getFunctionColumns(String catalog,
				  String schemaPattern,
				  String functionNamePattern,
				  String columnNamePattern) throws SQLException
  {
     String [] col_names = {
       "FUNCTION_CAT",
       "FUNCTION_SCHEM",
       "FUNCTION_NAME",
       "COLUMN_NAME",
       "COLUMN_TYPE",
       "DATA_TYPE",
       "TYPE_NAME",
       "PRECISION",
       "LENGTH",
       "SCALE",
       "RADIX",
       "NULLABLE",
       "REMARKS",
       "CHAR_OCTET_LENGTH",
       "ORDINAL_POSITION",
       "IS_NULLABLE",
       "SPECIFIC_NAME"
      };
     int [] col_dtps = {
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_SHORT_INT,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_LONG_INT,
       VirtuosoTypes.DV_LONG_INT,
       VirtuosoTypes.DV_SHORT_INT,
       VirtuosoTypes.DV_SHORT_INT,
       VirtuosoTypes.DV_SHORT_INT,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_LONG_INT,
       VirtuosoTypes.DV_LONG_INT,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING
       };

     return new VirtuosoResultSet (connection, col_names, col_dtps);
  }


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
      // This works for classes that are not actually wrapping anything
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
    // This works for classes that are not actually wrapping anything
    return iface.isInstance(this);
  }


#if JDK_VER >= 17

    //--------------------------JDBC 4.1 -----------------------------

    /**
     * Retrieves a description of the pseudo or hidden columns available
     * in a given table within the specified catalog and schema.
     * Pseudo or hidden columns may not always be stored within
     * a table and are not visible in a ResultSet unless they are
     * specified in the query's outermost SELECT list. Pseudo or hidden
     * columns may not necessarily be able to be modified. If there are
     * no pseudo or hidden columns, an empty ResultSet is returned.
     *
     * <P>Only column descriptions matching the catalog, schema, table
     * and column name criteria are returned.  They are ordered by
     * <code>TABLE_CAT</code>,<code>TABLE_SCHEM</code>, <code>TABLE_NAME</code>
     * and <code>COLUMN_NAME</code>.
     *
     * <P>Each column description has the following columns:
     *  <OL>
     *  <LI><B>TABLE_CAT</B> String => table catalog (may be <code>null</code>)
     *  <LI><B>TABLE_SCHEM</B> String => table schema (may be <code>null</code>)
     *  <LI><B>TABLE_NAME</B> String => table name
     *  <LI><B>COLUMN_NAME</B> String => column name
     *  <LI><B>DATA_TYPE</B> int => SQL type from java.sql.Types
     *  <LI><B>COLUMN_SIZE</B> int => column size.
     *  <LI><B>DECIMAL_DIGITS</B> int => the number of fractional digits. Null is returned for data types where
     * DECIMAL_DIGITS is not applicable.
     *  <LI><B>NUM_PREC_RADIX</B> int => Radix (typically either 10 or 2)
     *  <LI><B>COLUMN_USAGE</B> String => The allowed usage for the column.  The
     *  value returned will correspond to the enum name returned by {@link PseudoColumnUsage#name PseudoColumnUsage.name()}
     *  <LI><B>REMARKS</B> String => comment describing column (may be <code>null</code>)
     *  <LI><B>CHAR_OCTET_LENGTH</B> int => for char types the
     *       maximum number of bytes in the column
     *  <LI><B>IS_NULLABLE</B> String  => ISO rules are used to determine the nullability for a column.
     *       <UL>
     *       <LI> YES           --- if the column can include NULLs
     *       <LI> NO            --- if the column cannot include NULLs
     *       <LI> empty string  --- if the nullability for the column is unknown
     *       </UL>
     *  </OL>
     *
     * <p>The COLUMN_SIZE column specifies the column size for the given column.
     * For numeric data, this is the maximum precision.  For character data, this is the length in characters.
     * For datetime datatypes, this is the length in characters of the String representation (assuming the
     * maximum allowed precision of the fractional seconds component). For binary data, this is the length in bytes.  For the ROWID datatype,
     * this is the length in bytes. Null is returned for data types where the
     * column size is not applicable.
     *
     * @param catalog a catalog name; must match the catalog name as it
     *        is stored in the database; "" retrieves those without a catalog;
     *        <code>null</code> means that the catalog name should not be used to narrow
     *        the search
     * @param schemaPattern a schema name pattern; must match the schema name
     *        as it is stored in the database; "" retrieves those without a schema;
     *        <code>null</code> means that the schema name should not be used to narrow
     *        the search
     * @param tableNamePattern a table name pattern; must match the
     *        table name as it is stored in the database
     * @param columnNamePattern a column name pattern; must match the column
     *        name as it is stored in the database
     * @return <code>ResultSet</code> - each row is a column description
     * @exception SQLException if a database access error occurs
     * @see PseudoColumnUsage
     * @since 1.7
     */
  public ResultSet getPseudoColumns(String catalog,
                         String schemaPattern,
                         String tableNamePattern,
                         String columnNamePattern) throws SQLException
  {
     String [] col_names = {
      "TABLE_CAT",
      "TABLE_SCHEM",
      "TABLE_NAME",
      "COLUMN_NAME",
      "DATA_TYPE",
      "COLUMN_SIZE",
      "DECIMAL_DIGITS",
      "NUM_PREC_RADIX",
      "COLUMN_USAGE",
      "REMARKS",
      "CHAR_OCTET_LENGTH",
      "IS_NULLABLE"
      };
     int [] col_dtps = {
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_LONG_INT,
       VirtuosoTypes.DV_LONG_INT,
       VirtuosoTypes.DV_LONG_INT,
       VirtuosoTypes.DV_LONG_INT,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_STRING,
       VirtuosoTypes.DV_LONG_INT,
       VirtuosoTypes.DV_STRING
       };

     return new VirtuosoResultSet (connection, col_names, col_dtps);
  }


    /**
     * Retrieves whether a generated key will always be returned if the column
     * name(s) or index(es) specified for the auto generated key column(s)
     * are valid and the statement succeeds.  The key that is returned may or
     * may not be based on the column(s) for the auto generated key.
     * Consult your JDBC driver documentation for additional details.
     * @return <code>true</code> if so; <code>false</code> otherwise
     * @exception SQLException if a database access error occurs
     * @since 1.7
     */
  public boolean generatedKeyAlwaysReturned() throws SQLException
  {
    return false;
  }


#endif


}
