<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2016 OpenLink Software
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

?>
<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>
<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR;?>" CLASS="defaulttext">
<?php

if ( ! $is_admin ) {
  echo "<H2><FONT COLOR=\"$H2COLOR\">" . translate("Error") .
    "</FONT></H2>" . translate("You are not authorized") . ".\n";
  include "includes/trailer.php";
  echo "</BODY></HTML>\n";
  exit;
}
?>


<H2><FONT COLOR="<?php echo $H2COLOR;?>"><?php etranslate("Users")?></FONT></H2>

<UL>
<?php
$userlist = user_get_users ();
for ( $i = 0; $i < count ( $userlist ); $i++ ) {
  echo "<LI><A HREF=\"edit_user.php?user=" . $userlist[$i]["cal_login"] .
    "\">";
  echo $userlist[$i]['cal_fullname'];
  echo "</A>";
  if (  $userlist[$i]["cal_is_admin"] == 'Y' )
    echo "<SUP>*</SUP>";
}
?>
</UL>
<SUP>*</SUP> <?php etranslate("denotes administrative user")?>
<P>
<?php
  if ( $admin_can_add_user )
    echo "<A HREF=\"edit_user.php\">" . translate("Add New User") .
      "</A><BR>\n";
?>

<?php include "includes/trailer.php"; ?>
</BODY>
</HTML>
