<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2013 OpenLink Software
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

include "includes/config.php";
include "includes/php-dbi.php";
include "includes/functions.php";
include "includes/$user_inc";
include "includes/validate.php";
include "includes/connect.php";

load_global_settings ();
load_user_preferences ();
load_user_layers ();
load_user_categories();

include "includes/translate.php";

$error = "";

// Only proceed if id was passed
if ( $id > 0 ) {

  // double check to make sure user doesn't already have the event
  $is_my_event = false;
  $sql = "SELECT cal_id FROM webcal_entry_user " .
    "WHERE cal_login = '$login' AND cal_id = $id";
  $res = dbi_query ( $sql );
  if ( $res ) {
    $row = dbi_fetch_row ( $res );
    if ( $row[0] == $id ) {
      $is_my_event = true;
      echo "Event # " . $id . " is already on your calendar.";
      exit;
    }
    dbi_free_result ( $res );
  }

  // Now lets make sure the user is allowed to add the event (not private)

  $sql = "SELECT cal_access FROM webcal_entry WHERE cal_id = " . $id;
  $res = dbi_query ( $sql );
  if ( ! $res ) {
    echo translate("Invalid entry id") . ": $id";
    exit;
  }
  $row = dbi_fetch_row ( $res );

  if ( $row[0] == "R" && ! $is_my_event ) {
    $is_private = true;
    etranslate("This is a private event and may not be added to your calendar.");
    exit;
  } else {
    $is_private = false;
  }

  // add the event
  if ( $readonly == "N" && ! $is_my_event && ! $is_private )  {
    if ( ! dbi_query ( "INSERT INTO webcal_entry_user ( cal_id, cal_login, cal_status ) VALUES ( $id, '$login', 'A' )") ) {
      $error = translate("Error adding event") . ": " . dbi_error ();
    }
  }
}

if ( strlen ( get_last_view() ) ) {
  $url = get_last_view();
} else {
  $url = "$STARTVIEW.php" . ( $thisdate > 0 ? "?date=$thisdate" : "" );
}

do_redirect ( $url );
exit;
?>
