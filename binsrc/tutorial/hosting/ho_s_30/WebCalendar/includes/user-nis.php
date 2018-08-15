<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2018 OpenLink Software
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

// This file contains all the functions for getting information
// about users.  So, if you want to use an authentication scheme
// other than the webcal_user table, you can just create a new
// version of each function found below.
//
// Note: this application assumes that usernames (logins) are unique.
//
// Note #2: If you are using HTTP-based authentication, then you still
// need these functions and you will still need to add users to
// webcal_user.


// Set some global config variables about your system.
// For NIS (which is maintained external to WebCalendar), don't let them
// add/delete users or change passwords.
$user_can_update_password = false;
$admin_can_add_user = false;
$admin_can_delete_user = false;


// $user_external_group = 100;
$user_external_email = "infotechfl.com";


// Check to see if a given login/password is valid.  If invalid,
// the error message will be placed in $login_error.
// params:
//   $login - user login
//   $password - user password
// returns: true or false
function user_valid_login ( $login, $password ) {
  global $error,$user_external_group,$user_external_email;
  $ret = false;

  $login_error = "";

  $data = yp_match (yp_get_default_domain(), "passwd.byname", $login);
  if ( strlen ( $data ) ) {
    $data = explode ( ":", $data );
    if ( $user_external_group && $user_external_group != $data[3] ) {
      $error = translate ("Invalid login");
      return $ret;
    }
    if ( $data[1] == crypt ( $password, substr ( $data[1], 0, 2 ) ) ) {
      if ( count ( $data ) >= 4 ) {
        $ret = true;

	// Check for user in webcal_user.  If in NIS and not in DB then insert...
	$sql = "SELECT cal_login FROM webcal_user WHERE cal_login = '" . $login . "'";
        $res = dbi_query ( $sql );
        if ( ! $res || ! dbi_fetch_row ( $res ) ) {
          // insert user
          $uname = explode ( " ", $data[4] );
          $ufirstname = $uname[0];
          $ulastname = $uname[count ( $uname ) - 1];
          $sql = "INSERT INTO webcal_user " .
            "( cal_login, cal_lastname, cal_firstname, " .
            "cal_is_admin, cal_email ) " .
            "VALUES ( '$login', '$ulastname', '$ufirstname', " .
            "'N', '$login" . "@" . "$user_external_email')";
          if ( ! dbi_query ( $sql ) ) {
            $error = translate("Database error") . ": " . dbi_error();
	    $ret = false;
          }
        }
      } else {
       $error = translate ("Invalid login");
       $ret = false;
      }
    }
  }
  return $ret;
}


// Check to see if a given login/crypted password is valid.  If invalid,
// the error message will be placed in $login_error.
// params:
//   $login - user login
//   $crypt_password - crypted user password
// returns: true or false
function user_valid_crypt ( $login, $crypt_password ) {
  return true;
  // NOT YET IMPLEMENTED FOR NIS.
}


// Load info about a user (first name, last name, admin) and set
// globally.
// params:
//   $user - user login
//   $prefix - variable prefix to use
function user_load_variables ( $login, $prefix ) {
  global $PUBLIC_ACCESS_FULLNAME;
  if ( $login == "__public__" ) {
    $GLOBALS[$prefix . "login"] = $login;
    $GLOBALS[$prefix . "firstname"] = "";
    $GLOBALS[$prefix . "lastname"] = "";
    $GLOBALS[$prefix . "is_admin"] = "N";
    $GLOBALS[$prefix . "email"] = "";
    $GLOBALS[$prefix . "fullname"] = $PUBLIC_ACCESS_FULLNAME;
    $GLOBALS[$prefix . "password"] = "";
    return true;
  }
  $sql =
    "SELECT cal_firstname, cal_lastname, cal_is_admin, cal_email, cal_passwd " .
    "FROM webcal_user WHERE cal_login = '" . $login . "'";
  $res = dbi_query ( $sql );
  if ( $res ) {
    if ( $row = dbi_fetch_row ( $res ) ) {
      $GLOBALS[$prefix . "login"] = $login;
      $GLOBALS[$prefix . "firstname"] = $row[0];
      $GLOBALS[$prefix . "lastname"] = $row[1];
      $GLOBALS[$prefix . "is_admin"] = $row[2];
      $GLOBALS[$prefix . "email"] = empty ( $row[3] ) ? "" : $row[3];
      if ( strlen ( $row[0] ) && strlen ( $row[1] ) )
        $GLOBALS[$prefix . "fullname"] = "$row[0] $row[1]";
      elseif ( strlen ( $row[1] ) && ! strlen ( $row[0] ) )
        $GLOBALS[$prefix . "fullname"] = "$row[1]";
      else
        $GLOBALS[$prefix . "fullname"] = $login;
      $GLOBALS[$prefix . "password"] = $row[4];
    }
    dbi_free_result ( $res );
  } else {
    $error = translate ("Database error") . ": " . dbi_error ();
    return false;
  }
  return true;
}



// Add a new user.
// params:
//   $user - user login
//   $password - user password
//   $firstname - first name
//   $lastname - last name
//   $email - email address
//   $admin - is admin? ("Y" or "N")
function user_add_user ( $user, $password, $firstname, $lastname, $email,
  $admin ) {
  global $error;

  if ( $user == "__public__" ) {
    $error = translate ("Invalid user login");
    return false;
  }

  if ( strlen ( $email ) )
    $uemail = "'" . $email . "'";
  else
    $uemail = "NULL";
  if ( strlen ( $firstname ) )
    $ufirstname = "'" . $firstname . "'";
  else
    $ufirstname = "NULL";
  if ( strlen ( $lastname ) )
    $ulastname = "'" . $lastname . "'";
  else
    $ulastname = "NULL";
  if ( strlen ( $password ) )
    $upassword = "'" . $password . "'";
  else
    $upassword = "NULL";
  if ( $admin != "Y" )
    $admin = "N";
  $sql = "INSERT INTO webcal_user " .
    "( cal_login, cal_lastname, cal_firstname, " .
    "cal_is_admin, cal_passwd, cal_email ) " .
    "VALUES ( '$user', $ulastname, $ufirstname, " .
    "'$admin', $upassword, $uemail )";
  if ( ! dbi_query ( $sql ) ) {
    $error = translate ("Database error") . ": " . dbi_error ();
    return false;
  }
  return true;
}


// Update a user
// params:
//   $user - user login
//   $firstname - first name
//   $lastname - last name
//   $email - email address
//   $admin - is admin?
function user_update_user ( $user, $firstname, $lastname, $email, $admin ) {
  global $error;

  if ( $user == "__public__" ) {
    $error = translate ("Invalid user login");
    return false;
  }
  if ( strlen ( $email ) )
    $uemail = "'" . $email . "'";
  else
    $uemail = "NULL";
  if ( strlen ( $firstname ) )
    $ufirstname = "'" . $firstname . "'";
  else
    $ufirstname = "NULL";
  if ( strlen ( $lastname ) )
    $ulastname = "'" . $lastname . "'";
  else
    $ulastname = "NULL";
  if ( $admin != "Y" )
    $admin = "N";

  $sql = "UPDATE webcal_user SET cal_lastname = $ulastname, " .
    "cal_firstname = $ufirstname, cal_email = $uemail," .
    "cal_is_admin = '$admin' WHERE cal_login = '$user'";
  if ( ! dbi_query ( $sql ) ) {
    $error = translate ("Database error") . ": " . dbi_error ();
    return false;
  }
  return true;
}


// Update user password
// params:
//   $user - user login
//   $password - last name
function user_update_user_password ( $user, $password ) {
  global $error;

  $sql = "UPDATE webcal_user SET cal_passwd = '$password' " .
    "WHERE cal_login = '$user'";
  if ( ! dbi_query ( $sql ) ) {
    $error = translate ("Database error") . ": " . dbi_error ();
    return false;
  }
  return true;
}



// Delete a user from the system.
// We assume that we've already checked to make sure this user doesn't
// have events still in the database.
// params:
//   $user - user to delete
function user_delete_user ( $user ) {

  // Get event ids for all events this user is a participant
  $events = array ();
  $res = dbi_query ( "SELECT webcal_entry.cal_id " .
    "FROM webcal_entry, webcal_entry_user " .
    "WHERE webcal_entry.cal_id = webcal_entry_user.cal_id " .
    "AND webcal_entry_user.cal_login = '$user'" );
  if ( $res ) {
    while ( $row = dbi_fetch_row ( $res ) ) {
      $events[] = $row[0];
    }
  }

  // Now count number of participants in each event...
  // If just 1, then save id to be deleted
  $delete_em = array ();
  for ( $i = 0; $i < count ( $events ); $i++ ) {
    $res = dbi_query ( "SELECT COUNT(*) FROM webcal_entry_user " .
      "WHERE cal_id = " . $events[$i] );
    if ( $res ) {
      if ( $row = dbi_fetch_row ( $res ) ) {
        if ( $row[0] == 1 )
	  $delete_em[] = $events[$i];
      }
      dbi_free_result ( $res );
    }
  }
  // Now delete events that were just for this user
  for ( $i = 0; $i < count ( $delete_em ); $i++ ) {
    dbi_query ( "DELETE FROM webcal_entry WHERE cal_id = " . $delete_em[$i] );
  }

  // Delete user participation from events
  dbi_query ( "DELETE FROM webcal_entry_user WHERE cal_login = '$user'" );


  // Delete preferences
  dbi_query ( "DELETE FROM webcal_user_pref WHERE cal_login = '$user'" );

  // Delete from groups
  dbi_query ( "DELETE FROM webcal_group_user WHERE cal_login = '$user'" );

  // Delete user's views
  $delete_em = array ();
  $res = dbi_query ( "SELECT cal_view_id FROM webcal_view " .
    "WHERE cal_owner = '$user'" );
  if ( $res ) {
    while ( $row = dbi_fetch_row ( $res ) ) {
      $delete_em[] = $row[0];
    }
    dbi_free_result ( $res );
  }
  for ( $i = 0; $i < count ( $delete_em ); $i++ ) {
    dbi_query ( "DELETE FROM webcal_view_user WHERE cal_view_id = " .
      $delete_em[$i] );
  }
  dbi_query ( "DELETE FROM webcal_view WHERE cal_owner = '$user'" );

  // Delete layers
  dbi_query ( "DELETE FROM webcal_user_layers WHERE cal_login = '$user'" );

  // Delete any layers other users may have that point to this user.
  dbi_query ( "DELETE FROM webcal_user_layers WHERE cal_layeruser = '$user'" );

  // Delete user
  dbi_query ( "DELETE FROM webcal_user WHERE cal_login = '$user'" );
}


// Get a list of users and return info in an array.
function user_get_users () {
  global $public_access, $PUBLIC_ACCESS_FULLNAME;

  $count = 0;
  $ret = array ();
  if ( $public_access == "Y" )
    $ret[$count++] = array (
       "cal_login" => "__public__",
       "cal_lastname" => "",
       "cal_firstname" => "",
       "cal_is_admin" => "N",
       "cal_email" => "",
       "cal_password" => "",
       "cal_fullname" => $PUBLIC_ACCESS_FULLNAME );
  $res = dbi_query ( "SELECT cal_login, cal_lastname, cal_firstname, " .
    "cal_is_admin, cal_email, cal_passwd FROM webcal_user " .
    "ORDER BY cal_lastname, cal_firstname, cal_login" );
  if ( $res ) {
    while ( $row = dbi_fetch_row ( $res ) ) {
      if ( strlen ( $row[1] ) && strlen ( $row[2] ) )
        $fullname = "$row[2] $row[1]";
      elseif ( strlen ( $row[1] ) && ! strlen ( $row[2] ) )
        $fullname = "$row[1]";
      else
        $fullname = $row[0];
      $ret[$count++] = array (
        "cal_login" => $row[0],
        "cal_lastname" => $row[1],
        "cal_firstname" => $row[2],
        "cal_is_admin" => $row[3],
        "cal_email" => empty ( $row[4] ) ? "" : $row[4],
        "cal_password" => $row[5],
        "cal_fullname" => $fullname
      );
    }
    dbi_free_result ( $res );
  }
  return $ret;
}



?>
