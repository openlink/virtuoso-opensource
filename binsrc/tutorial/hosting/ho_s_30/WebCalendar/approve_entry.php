<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2017 OpenLink Software
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

// Allow administrators to approve public events
if ( $public_access == "Y" && ! empty ( $public ) && $is_admin )
  $app_user = "__public__";
else
  $app_user = $login;

if ( $id > 0 ) {
  if ( ! dbi_query ( "UPDATE webcal_entry_user SET cal_status = 'A' " .
    "WHERE cal_login = '$app_user' AND cal_id = $id" ) ) {
    $error = translate("Error approving event") . ": " . dbi_error ();
  } else {
    activity_log ( $id, $login, $app_user, $LOG_APPROVE, "" );
  }
  // Update any extension events related to this one.
  $res = dbi_query ( "SELECT cal_id FROM webcal_entry " .
    "WHERE cal_ext_for_id = $id" );
  if ( $res ) {
    if ( $row = dbi_fetch_row ( $res ) ) {
      $ext_id = $row[0];
      if ( ! dbi_query ( "UPDATE webcal_entry_user SET cal_status = 'A' " .
        "WHERE cal_login = '$app_user' AND cal_id = $ext_id" ) ) {
        $error = translate("Error approving event") . ": " . dbi_error ();
      }
    }
    dbi_free_result ( $res );
  }
}

if ( $ret == "list" )
  do_redirect ( "list_unapproved.php" );
else
  do_redirect ( "view_entry.php?id=$id" );
?>
