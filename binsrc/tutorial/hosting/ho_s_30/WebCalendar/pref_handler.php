<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2014 OpenLink Software
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

$updating_public = false;;
if ( $is_admin && ! empty ( $public ) && $public_access == "Y" ) {
  $updating_public = true;
  $prefuser = "__public__";
} else {
  $prefuser = "$login";
}

while ( list ( $key, $value ) = each ( $HTTP_POST_VARS ) ) {
  $setting = substr ( $key, 5 );
  $prefix = substr ( $key, 0, 5 );
  //echo "Setting = $setting, key = $key, prefix = $prefix <BR>\n";
  if ( strlen ( $setting ) > 0 && $prefix == "pref_" ) {
    $sql =
      "DELETE FROM webcal_user_pref WHERE cal_login = '$prefuser' " .
      "AND cal_setting = '$setting'";
    dbi_query ( $sql );
    if ( strlen ( $value ) > 0 ) {
      $sql = "INSERT INTO webcal_user_pref " .
        "( cal_login, cal_setting, cal_value ) VALUES " .
        "( '$prefuser', '$setting', '$value' )";
      if ( ! dbi_query ( $sql ) ) {
        $error = "Unable to update preference: " . dbi_error () .
          "<P><B>SQL:</B> $sql";
        break;
      }
    }
  }
}

if ( empty ( $error ) ) {
  if ( $updating_public )
    do_redirect ( "pref.php?public=1" );
  else
    do_redirect ( "pref.php" );
}

?>
<HTML>
<HEAD><TITLE><?php etranslate($application_name)?></TITLE>
<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR; ?>" CLASS="defaulttext">

<H2><FONT COLOR="<?php echo $H2COLOR;?>"><?php etranslate("Error")?></FONT></H2>

<?php etranslate("The following error occurred")?>:
<BLOCKQUOTE>
<?php echo $error; ?>
</BLOCKQUOTE>

<?php include "includes/trailer.php"; ?>

</BODY>
</HTML>
