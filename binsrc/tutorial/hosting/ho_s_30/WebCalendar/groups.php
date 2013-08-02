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

include "includes/translate.php";

if ( ! $is_admin )
  $user = $login;

if ( $groups_enabled == "N" ) {
  do_redirect ( "$STARTVIEW.php" );
  exit;
}

?>
<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>
<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR;?>" CLASS="defaulttext">

<H2><FONT COLOR="<?php echo $H2COLOR;?>"><?php etranslate("Groups")?></FONT></H2>

<UL>
<?php
$res = dbi_query ( "SELECT cal_group_id, cal_name FROM webcal_group " .
  "ORDER BY cal_name" );
if ( $res ) {
  while ( $row = dbi_fetch_row ( $res ) ) {
    echo "<LI><A HREF=\"group_edit.php?id=" . $row[0] .
      "\">" . $row[1] . "</A> ";
  }
  dbi_free_result ( $res );
}
?>
</UL>
<P>
<?php
  echo "<A HREF=\"group_edit.php\">" . translate("Add New Group") .
    "</A><BR>\n";
?>

<?php include "includes/trailer.php"; ?>
</BODY>
</HTML>
