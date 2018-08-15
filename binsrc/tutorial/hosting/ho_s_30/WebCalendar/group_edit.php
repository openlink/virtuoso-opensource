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
include "includes/config.php";
include "includes/php-dbi.php";
include "includes/functions.php";
include "includes/$user_inc";

include "includes/validate.php";
include "includes/connect.php";

load_global_settings ();
load_user_preferences ();

include "includes/translate.php";

?>
<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>
<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR;?>" CLASS="defaulttext">

<FORM ACTION="group_edit_handler.php" METHOD="POST">

<?php

$newgroup = true;
$groupname = "";
$groupowner = "";
$groupupdated = "";


if ( empty ( $id ) ) {
  $groupname = translate("Unnamed Group");
} else {
  $newgroup = false;
  // get group by id
  $res = dbi_query ( "SELECT cal_owner, cal_name, cal_last_update, cal_owner " .
    "FROM webcal_group WHERE cal_group_id = $id" );
  if ( $res ) {
    if ( $row = dbi_fetch_row ( $res ) ) {
      $groupname = $row[1];
      $groupupdated = $row[2];
      user_load_variables ( $row[3], "temp" );
      $groupowner = $tempfullname;
    }
    dbi_fetch_row ( $res );
  }
}


if ( $newgroup ) {
  $v = array ();
  echo "<H2><FONT COLOR=\"$H2COLOR\">" . translate("Add Group") . "</FONT></H2>\n";
  echo "<INPUT TYPE=\"hidden\" NAME=\"add\" VALUE=\"1\">\n";
} else {
  echo "<H2><FONT COLOR=\"$H2COLOR\">" . translate("Edit Group") . "</FONT></H2>\n";
  echo "<INPUT NAME=\"id\" TYPE=\"hidden\" VALUE=\"$id\">";
}
?>

<TABLE BORDER="0">
<TR><TD><B><?php etranslate("Group name")?>:</B></TD>
  <TD><INPUT NAME="groupname" SIZE=20 VALUE="<?php echo htmlspecialchars ( $groupname );?>"></TD></TR>
<?php if ( ! $newgroup ) { ?>
<TR><TD VALIGN="top">
<B><?php etranslate("Updated"); ?>:</B></TD>
<TD> <?php echo date_to_str ( $groupupdated ); ?></TD></TR>
<TR><TD VALIGN="top">
<B><?php etranslate("Created by"); ?>:</B></TD>
<TD> <?php echo $groupowner; ?></TD></TR>
<?php } ?>
<TR><TD VALIGN="top">
<B><?php etranslate("Users"); ?>:</B></TD>
<TD>
<SELECT NAME="users[]" SIZE="10" MULTIPLE>
<?php
  // get list of all users
  $users = user_get_users ();
  // get list of users for this group
  if ( ! $newgroup ) {
    $sql = "SELECT cal_login FROM webcal_group_user WHERE cal_group_id = $id";
    $res = dbi_query ( $sql );
    if ( $res ) {
      while ( $row = dbi_fetch_row ( $res ) ) {
        $groupuser[$row[0]] = 1;
      }
      dbi_free_result ( $res );
    }
  }
  for ( $i = 0; $i < count ( $users ); $i++ ) {
    $u = $users[$i]['cal_login'];
    echo "<OPTION VALUE=\"$u\" ";
    if ( ! empty ( $groupuser[$u] ) ) {
      echo "SELECTED";
    }
    echo "> " . $users[$i]['cal_fullname'];
  }
?>
</SELECT>
</TD></TR>
<TR><TD COLSPAN="2">
<BR><BR>
<CENTER>
<INPUT TYPE="submit" NAME="action" VALUE="<?php if ( $newgroup ) etranslate("Add"); else etranslate("Save"); ?>" >
<?php if ( ! $newgroup ) { ?>
<INPUT TYPE="submit" NAME="action" VALUE="<?php etranslate("Delete")?>" ONCLICK="return confirm('<?php etranslate("Are you sure you want to delete this entry?"); ?>')">
<?php } ?>
</CENTER>
</TD></TR>
</TABLE>

</FORM>

<?php include "includes/trailer.php"; ?>
</BODY>
</HTML>
