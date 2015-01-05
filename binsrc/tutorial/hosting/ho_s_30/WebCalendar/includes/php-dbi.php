<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2015 OpenLink Software
#  
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#  
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#  
#  
?>
<?php
// php-dbi.php
//
// (C) Craig Knudsen, cknudsen@radix.net, http://www.radix.net/~cknudsen/
// License: GNU GPL (see www.gnu.org)
//
// The functions defined in this file are meant to provide a single
// API to the different PHP database APIs.  Unfortunately, this is
// necessary since PHP does not yet have a common db API.
// The value of $GLOBALS["db_type"] should be defined somewhere
// to one of the following:
//	mysql
//	oracle	(This uses the Oracle8 OCI API, so Oracle 8 libs are required)
//	postgresl
//	odbc
//	ibase (Interbase)
// Limitations:
//	This assumes a single connection to a single database
//	for the sake of simplicity.  Do not make a new query until you
//	are completely finished with the previous one.
//	Rather than use the associative arrays returned with
//	xxx_fetch_array(), normal arrays are used with xxx_fetch_row().
//	(Some db APIs don't support xxx_fetch_array().)
//
// History:
//	31-May-2002	Craig Knudsen <cknudsen@radix.net>
//			Added support for Interbase contributed by
//			Marco Forlin
//	11-Jul-2001	Craig Knudsen <cknudsen@radix.net>
//			Removed pass by reference for odbc_fetch_into()
//			Removed ++ in call to pg_fetch_array()
//	22-Apr-2000	Ken Harris <kharris@lhinfo.com>
//			PostgreSQL fixes
//	23-Feb-2000	Craig Knudsen <cknudsen@radix.net>
//			Initial release
//	

// Limitations:
// Fetched rows are returned in non-associative arrays.

// Open up a database connection
// Always do a pooled connection if the db supports it
// For ODBC, $host is ignored, $database = DSN
// For Oracle, $database = tnsnames name
function dbi_connect ( $host, $login, $password, $database ) {
  if ( strcmp ( $GLOBALS["db_type"], "mysql" ) == 0 ) {
    $c = mysql_pconnect ( $host, $login, $password );
    if ( $c ) {
      if ( ! mysql_select_db ( $database ) )
        return false;
      return $c;
    } else {
      return false;
    }
  } else if ( strcmp ( $GLOBALS["db_type"], "oracle" ) == 0 ) {
    if ( strlen ( $host ) && strcmp ( $host, "localhost" ) )
      $c = OCIPLogon ( "$login@$host", $password, $database );
    else
      $c = OCIPLogon ( $login, $password, $database );
    $GLOBALS["oracle_connection"] = $c;
    return $c;
  } else if ( strcmp ( $GLOBALS["db_type"], "postgresql" ) == 0 ) {
    if ( strlen ( $password ) )
      $c = pg_connect ( "host=$host dbname=$database user=$login password=$password" );
    else
      $c = pg_connect ( "host=$host dbname=$database user=$login" );
    $GLOBALS["postgresql_connection"] = $c;
    if ( ! $c ) {
        echo "Error connecting to database\n";
        exit;
    }
    return $c;
  } else if ( strcmp ( $GLOBALS["db_type"], "odbc" ) == 0 ) {
    if ( strlen ( $host ) )
      $c = odbc_pconnect ( "$host:$database", $login, $password );
    else
      $c = odbc_pconnect ( $database, $login, $password );
    $GLOBALS["odbc_connection"] = $c;
    return $c;
  } else if ( strcmp ( $GLOBALS["db_type"], "ibase" ) == 0 ) {
    $c = ibase_connect ( $host, $login, $password );
    return $c;
  } else {
    dbi_fatal_error ( "dbi_connect(): db_type not defined." );
  }
}

// Close a database connection
// Not necessary for any database that uses pooled connections
// such as MySQL
function dbi_close ( $conn ) {
  if ( strcmp ( $GLOBALS["db_type"], "mysql" ) == 0 ) {
    return mysql_close ( $conn );
  } else if ( strcmp ( $GLOBALS["db_type"], "oracle" ) == 0 ) {
    return OCILogOff ( $conn );
  } else if ( strcmp ( $GLOBALS["db_type"], "postgresql" ) == 0 ) {
    return pg_close ( $GLOBALS["postgresql_connection"] );
  } else if ( strcmp ( $GLOBALS["db_type"], "odbc" ) == 0 ) {
    return odbc_close ( $GLOBALS["odbc_connection"] );
  } else if ( strcmp ( $GLOBALS["db_type"], "ibase" ) == 0 ) {
    return ibase_close ( $conn );
  } else {
    dbi_fatal_error ( "dbi_close(): db_type not defined." );
  }
  
}


// Select the database that all queries should use
//function dbi_select_db ( $database ) {
//  if ( strcmp ( $GLOBALS["db_type"], "mysql" ) == 0 ) {
//    return mysql_select_db ( $database );
//  } else if ( strcmp ( $GLOBALS["db_type"], "oracle" ) == 0 ) {
//    // Not supported.  Must sent up a tnsname and user that uses
//    // the correct tablesapce.
//    return true;
//  } else {
//    dbi_fatal_error ( "dbi_select_db(): db_type not defined." );
//  }
//}

// Execute an SQL query
function dbi_query ( $sql ) {
  if ( strcmp ( $GLOBALS["db_type"], "mysql" ) == 0 ) {
    $res = mysql_query ( $sql );
    if ( ! $res )
      dbi_fatal_error ( "Error executing query: " . dbi_error() .
        "\n\n<P>\n" . $sql );
    return $res;
  } else if ( strcmp ( $GLOBALS["db_type"], "oracle" ) == 0 ) {
    $GLOBALS["oracle_statement"] =
      OCIParse ( $GLOBALS["oracle_connection"], $sql );
    return OCIExecute ( $GLOBALS["oracle_statement"],
      OCI_COMMIT_ON_SUCCESS );
  } else if ( strcmp ( $GLOBALS["db_type"], "postgresql" ) == 0 ) {
    $GLOBALS["postgresql_row"] = 0;
    $GLOBALS["postgresql_row"] = 0;
    $res =  pg_exec ( $GLOBALS["postgresql_connection"], $sql );
    if ( ! $res )
      dbi_fatal_error ( "Error executing query: " . dbi_error() .
        "\n\n<P>\n" . $sql );
    $GLOBALS["postgresql_numrows"] = pg_numrows ( $res );
    return $res;
  } else if ( strcmp ( $GLOBALS["db_type"], "odbc" ) == 0 ) {
    return odbc_exec ( $GLOBALS["odbc_connection"], $sql );
  } else if ( strcmp ( $GLOBALS["db_type"], "ibase" ) == 0 ) {
    $res = ibase_query ( $sql );
    if ( ! $res )
      dbi_fatal_error ( "Error executing query: " . dbi_error() .
        "\n\n<P>\n" . $sql );
    return $res;
  } else {
    dbi_fatal_error ( "dbi_query(): db_type not defined." );
  }
}


// Determine the number of rows from a result
//function dbi_num_rows ( $res ) {
//  if ( strcmp ( $GLOBALS["db_type"], "mysql" ) == 0 ) {
//    return mysql_num_rows ( $res );
//  } else {
//    dbi_fatal_error ( "dbi_num_rows(): db_type not defined." );
//  }
//}

// Retrieve a single row from the database and return it
// as an array.
// Note: we don't use the more useful xxx_fetch_array because not all
// databases support this function.
function dbi_fetch_row ( $res ) {
  if ( strcmp ( $GLOBALS["db_type"], "mysql" ) == 0 ) {
    return mysql_fetch_array ( $res );
  } else if ( strcmp ( $GLOBALS["db_type"], "oracle" ) == 0 ) {
    if ( OCIFetchInto ( $GLOBALS["oracle_statement"], $row,
      OCI_NUM + OCI_RETURN_NULLS  ) )
      return $row;
    return 0;
  } else if ( strcmp ( $GLOBALS["db_type"], "postgresql" ) == 0 ) {
    if ( $GLOBALS["postgresql_numrows"]  > $GLOBALS["postgresql_row"] ) {
        $r =  pg_fetch_array ( $res, $GLOBALS["postgresql_row"] );
        $GLOBALS["postgresql_row"]++;
        if ( ! $r ) {
            echo "Unable to fetch row\n"; 
            return '';
        }
    }
    else {
        $r = '';
    }
    return $r;
  } else if ( strcmp ( $GLOBALS["db_type"], "odbc" ) == 0 ) {
    if ( ! odbc_fetch_into ( $res, $ret ) )
      return false;
    return $ret;
  } else if ( strcmp ( $GLOBALS["db_type"], "ibase" ) == 0 ) {
    return ibase_fetch_row ( $res );
  } else {
    dbi_fatal_error ( "dbi_fetch_row(): db_type not defined." );
  }
}


// Free a result set.
// This isn't really necessary for PHP4 since this is done automatically,
// but it's a good habit for PHP3.
function dbi_free_result ( $res ) {
  if ( strcmp ( $GLOBALS["db_type"], "mysql" ) == 0 ) {
    return mysql_free_result ( $res );
  } else if ( strcmp ( $GLOBALS["db_type"], "oracle" ) == 0 ) {
    // Not supported.  Ingore.
    if ( $GLOBALS["oracle_statement"] >= 0 ) {
      OCIFreeStatement ( $GLOBALS["oracle_statement"] );
      $GLOBALS["oracle_statement"] = -1;
    }
  } else if ( strcmp ( $GLOBALS["db_type"], "postgresql" ) == 0 ) {
    return pg_freeresult ( $res );
  } else if ( strcmp ( $GLOBALS["db_type"], "odbc" ) == 0 ) {
    return odbc_free_result ( $res );
  } else if ( strcmp ( $GLOBALS["db_type"], "ibase" ) == 0 ) {
    return ibase_free_result ( $res );
  } else {
    dbi_fatal_error ( "dbi_free_result(): db_type not defined." );
  }
}


// Get the latest db error message.
function dbi_error () {
  if ( strcmp ( $GLOBALS["db_type"], "mysql" ) == 0 ) {
    $ret = mysql_error ();
  } else if ( strcmp ( $GLOBALS["db_type"], "oracle" ) == 0 ) {
    $ret = OCIError ( $GLOBALS["oracle_connection"] );
  } else if ( strcmp ( $GLOBALS["db_type"], "postgresql" ) == 0 ) {
    $ret = pg_errormessage ( $GLOBALS["postgresql_connection"] );
  } else if ( strcmp ( $GLOBALS["db_type"], "odbc" ) == 0 ) {
    // no way to get error from ODBC API
    $ret = "Unknown ODBC error";
  } else if ( strcmp ( $GLOBALS["db_type"], "ibase" ) == 0 ) {
    $ret = ibase_errmsg ();
  } else {
    $ret = "dbi_error(): db_type not defined.";
  }
  if ( strlen ( $ret ) )
    return $ret;
  else
    return "Unknown error";
}


// display an error message and exit
function dbi_fatal_error ( $msg ) {
  echo "<H2>Error</H2>\n";
  echo "<!--begin_error(dbierror)-->\n";
  echo "$msg\n";
  echo "<!--end_error-->\n";
  exit;
}

?>
