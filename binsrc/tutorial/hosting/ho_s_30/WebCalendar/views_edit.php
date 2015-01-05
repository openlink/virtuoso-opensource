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
<SCRIPT LANGUAGE="JavaScript">
function selectUsers () {
  url = "usersel.php?form=editviewform&listid=3&users=";
  // add currently selected users
  for ( i = 0, j = 0; i < document.forms[0].elements[3].length; i++ ) {
    if ( document.forms[0].elements[3].options[i].selected ) {
      if ( j != 0 )
	url += ",";
      j++;
      url += document.forms[0].elements[3].options[i].value;
    }
  }
  //alert ( "URL: " + url );
  // open window
  window.open ( url, "UserSelection",
    "width=500,height=500,resizable=yes,scrollbars=yes" );
}
</SCRIPT>
<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR;?>" CLASS="defaulttext">

<FORM ACTION="views_edit_handler.php" METHOD="POST" NAME="editviewform">

<?php

$newview = true;
$viewname = "";
$viewtype = "";


if ( empty ( $id ) ) {
  $viewname = translate("Unnamed View");
} else {
  // search for view by id
  for ( $i = 0; $i < count ( $views ); $i++ ) {
    if ( $views[$i]['cal_view_id'] == $id ) {
      $newview = false;
      $viewname = $views[$i]["cal_name"];
      $viewtype = $views[$i]["cal_view_type"];
    }
  }
}


if ( $newview ) {
  $v = array ();
  echo "<H2><FONT COLOR=\"$H2COLOR\">" . translate("Add View") . "</FONT></H2>\n";
  echo "<INPUT TYPE=\"hidden\" NAME=\"add\" VALUE=\"1\">\n";
} else {
  echo "<H2><FONT COLOR=\"$H2COLOR\">" . translate("Edit View") . "</FONT></H2>\n";
  echo "<INPUT NAME=\"id\" TYPE=\"hidden\" VALUE=\"$id\">";
}
?>

<TABLE BORDER="0">
<TR><TD><B><?php etranslate("View Name")?>:</B></TD>
  <TD><INPUT NAME="viewname" SIZE=20 VALUE="<?php echo htmlspecialchars ( $viewname );?>"></TD></TR>
<TR><TD><B><?php etranslate("View Type")?>:</B></TD>
  <TD><SELECT NAME="viewtype">
      <OPTION VALUE="W" <?php if ( $viewtype == "W" ) echo "SELECTED";?> >
        <?php etranslate("Week"); ?>
      <OPTION VALUE="M" <?php if ( $viewtype == "M" ) echo "SELECTED";?> >
        <?php etranslate("Month"); ?>
      </SELECT>
      </TD></TR>
<TR><TD VALIGN="top">
<B><?php etranslate("Users"); ?>:</B></TD>
<TD>
<SELECT NAME="users[]" SIZE="10" MULTIPLE>
<?php
  // get list of all users
  $users = get_my_users ();
  // get list of users for this view
  if ( ! $newview ) {
    $sql = "SELECT cal_login FROM webcal_view_user WHERE cal_view_id = $id";
    $res = dbi_query ( $sql );
    if ( $res ) {
      while ( $row = dbi_fetch_row ( $res ) ) {
        $viewuser[$row[0]] = 1;
      }
      dbi_free_result ( $res );
    }
  }
  for ( $i = 0; $i < count ( $users ); $i++ ) {
    $u = $users[$i]['cal_login'];
    echo "<OPTION VALUE=\"$u\" ";
    if ( ! empty ( $viewuser[$u] ) ) {
      echo "SELECTED";
    }
    echo "> " . $users[$i]['cal_fullname'];
  }
?>
</SELECT>
<?php if ( $groups_enabled == "Y" ) { ?>
  <INPUT TYPE="button" ONCLICK="selectUsers()" VALUE="<?php etranslate("Select");?>...">
<?php } ?>
</TD></TR>
<TR><TD COLSPAN="2">
<BR><BR>
<CENTER>
<INPUT TYPE="submit" NAME="action" VALUE="<?php if ( $newview ) etranslate("Add"); else etranslate("Save"); ?>" >
<?php if ( ! $newview ) { ?>
<INPUT TYPE="submit" NAME="action" VALUE="<?php etranslate("Delete")?>" ONCLICK="return confirm('<?php etranslate("Are you sure you want to delete this entry?"); ?>')">
<?php } ?>
</CENTER>
</TD></TR>
</TABLE>

</FORM>

<?php include "includes/trailer.php"; ?>
</BODY>
</HTML>
