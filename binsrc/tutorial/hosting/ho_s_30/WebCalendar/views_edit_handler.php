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

include "includes/translate.php";

$error = "";

if ( $action == "Delete" || $action == translate ("Delete") ) {
  // delete this view
  dbi_query ( "DELETE FROM webcal_view WHERE cal_view_id = $id " .
    "AND cal_owner = '$login'" );
} else {
  if ( empty ( $viewname ) ) {
    $error = translate("You must specify a view name");
  }
  else if ( ! empty ( $id ) ) {
    # update
    if ( ! dbi_query ( "UPDATE webcal_view SET cal_name = " .
      "'$viewname', cal_view_type = '$viewtype' " .
      "WHERE cal_view_id = $id AND cal_owner = '$login'" ) ) {
      $error = translate ("Database error") . ": " . dbi_error();
    }
  } else {
    # new... get new id first
    $res = dbi_query ( "SELECT MAX(cal_view_id) FROM webcal_view" );
    if ( $res ) {
      $row = dbi_fetch_row ( $res );
      $id = $row[0];
      $id++;
      dbi_free_result ( $res );
      $sql = "INSERT INTO webcal_view " .
        "( cal_view_id, cal_owner, cal_name, cal_view_type ) VALUES ( " .
        "$id, '$login', '$viewname', '$viewtype' )";
      if ( ! dbi_query ( $sql ) ) {
        $error = translate ("Database error") . ": " . dbi_error();
      }
    } else {
      $error = translate ("Database error") . ": " . dbi_error();
    }
  }

  # update user list
  if ( $error == "" ) {
    dbi_query ( "DELETE FROM webcal_view_user WHERE cal_view_id = $id" );
    for ( $i = 0; $i < count ( $users ); $i++ ) {
      dbi_query ( "INSERT INTO webcal_view_user ( cal_view_id, cal_login ) " .
        "VALUES ( $id, '$users[$i]' )" );
    }
  }
}



if ( $error == "" ) {
  do_redirect ( "views.php" );
}
?>
<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>
<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR;?>" CLASS="defaulttext">

<H2><FONT COLOR="<?php echo $H2COLOR;?>"><?php etranslate("Error")?></FONT></H2>

<BLOCKQUOTE>
<?php

echo $error;
//if ( $sql != "" )
//  echo "<P><B>SQL:</B> $sql";
//?>
</BLOCKQUOTE>

<?php include "includes/trailer.php"; ?>
</BODY>
</HTML>
