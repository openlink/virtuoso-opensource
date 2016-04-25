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

if ( ! $is_admin )
  $user = $login;

?>
<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>
<?php include "includes/styles.php"; ?>
</HEAD>
<SCRIPT LANGUAGE="JavaScript">
<?php if ( $groups_enabled == "Y" ) { ?>
function selectUsers () {
  // find id of user selection object
  var listid = 0;
  for ( i = 0; i < document.forms[0].elements.length; i++ ) {
    if ( document.forms[0].elements[i].name == "users[]" )
      listid = i;
  }
  url = "usersel.php?form=editentryform&listid=" + listid + "&users=";
  // add currently selected users
  for ( i = 0, j = 0; i < document.forms[0].elements[listid].length; i++ ) {
    if ( document.forms[0].elements[listid].options[i].selected ) {
      if ( j != 0 )
        url += ",";
      j++;
      url += document.forms[0].elements[listid].options[i].value;
    }
  }
  //alert ( "URL: " + url );
  // open window
  window.open ( url, "UserSelection",
    "width=500,height=500,resizable=yes,scrollbars=yes" );
}
<?php } ?>
</SCRIPT>

<BODY BGCOLOR="<?php echo $BGCOLOR;?>" CLASS="defaulttext">

<FORM ACTION="assistant_edit_handler.php" METHOD="POST" NAME="editentryform">

<?php
  echo "<H2><FONT COLOR=\"$H2COLOR\">" . translate("Yours assistants") . "</FONT></H2>\n";
?>

<TABLE BORDER="0">
<TR><TD VALIGN="top">
<B><?php etranslate("Assistants"); ?>:</B></TD>
<TD>
<SELECT NAME="users[]" SIZE="10" MULTIPLE>
<?php
  // get list of all users
  $users = get_my_users ();
  // get list of users for this view
  $sql = "SELECT cal_boss, cal_assistant FROM webcal_asst WHERE cal_boss = '$login'";
  $res = dbi_query ( $sql );
  if ( $res ) {
    while ( $row = dbi_fetch_row ( $res ) ) {
      $assistantuser[$row[1]] = 1;
    }
    dbi_free_result ( $res );
  }
  for ( $i = 0; $i < count ( $users ); $i++ ) {
    $u = $users[$i]['cal_login'];
    echo "<OPTION VALUE=\"$u\" ";
    if ( ! empty ( $assistantuser[$u] ) ) {
      echo "SELECTED";
    }
    echo "> " . $users[$i]['cal_fullname'];
  }
?>
</SELECT>
<?php
if ( $groups_enabled == "Y" ) {
  echo "<INPUT TYPE=\"button\" ONCLICK=\"selectUsers()\" VALUE=\"" .
    translate("Select") . "...\">";
}
echo "</TD></TR>\n";
?>
</TD></TR>
<TR><TD COLSPAN="2">
<BR><BR>
<CENTER>
<INPUT TYPE="submit" NAME="action" VALUE="<?php etranslate("Save"); ?>" >

</CENTER>
</TD></TR>
</TABLE>

</FORM>

<?php include "includes/trailer.php"; ?>
</BODY>
</HTML>
