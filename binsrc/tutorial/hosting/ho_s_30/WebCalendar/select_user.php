<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2012 OpenLink Software
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

include "./includes/config.php";
include "./includes/php-dbi.php";
include "./includes/functions.php";
include "./includes/$user_inc";
include "./includes/validate.php";
include "./includes/connect.php";

load_global_settings ();
load_user_preferences ();
load_user_layers ();

include "./includes/translate.php";

?>
<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>
<?php include "./includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR;?>" CLASS="defaulttext">


<H2><FONT COLOR="<?php echo $H2COLOR; ?>"><?php etranslate("View Another User's Calendar"); ?></H2></FONT>

<?php
if ( $allow_view_other != "Y" && ! $is_admin ) {
  $error = translate ( "You are not authorized" );
}

if ( ! empty ( $error ) ) {
  echo "<BLOCKQUOTE>$error</BLOCKQUOTE>\n";
} else {
  $userlist = get_my_users ();
  ?>
  <FORM ACTION="<?php echo $STARTVIEW;?>.php" METHOD="GET" NAME="SelectUser">
  <SELECT NAME="user" ONCHANGE="document.SelectUser.submit()">
  <?php
  for ( $i = 0; $i < count ( $userlist ); $i++ ) {
    echo "<OPTION VALUE=\"".$userlist[$i]['cal_login']."\">".$userlist[$i]['cal_fullname']."\n";
  }
  ?>
  </SELECT>
  <INPUT TYPE="submit" VALUE="<?php etranslate("Go")?>"></FORM>
  <?php
}

?>
<P>

<?php include "./includes/trailer.php"; ?>
</BODY>
</HTML>
