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

include "includes/translate.php";

?>
<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>
<?php include "includes/styles.php"; ?>
<SCRIPT LANGUAGE="JavaScript">
<?php if ( $groups_enabled == "Y" ) { ?>
function selectUsers () {
  // find id of user selection object
  var listid = 0;
  for ( i = 0; i < document.forms[0].elements.length; i++ ) {
    if ( document.forms[0].elements[i].name == "users[]" )
      listid = i;
  }
  url = "usersel.php?form=searchformentry&listid=" + listid + "&users=";
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
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR;?>" CLASS="defaulttext">

<H2><FONT COLOR="<?php echo $H2COLOR;?>"><?php if ( empty ( $advanced ) ) { etranslate("Search"); } else { etranslate ( "Advanced Search" ); } ?></FONT></H2>

<FORM ACTION="search_handler.php" METHOD="POST" NAME="searchformentry">

<?php if ( empty ( $advanced ) ) { ?>

<B><?php etranslate("Keywords")?>:</B>
<INPUT NAME="keywords" SIZE=30>
<INPUT TYPE="submit" VALUE="<?php etranslate("Search")?>">

<P>
<A CLASS="navlinks" HREF="search.php?advanced=1"><?php etranslate("Advanced Search") ?></A>

<?php } else {
$show_participants = ( $disable_participants_field != "Y" );
if ( $is_admin )
  $show_participants = true;
if ( $login == "__public__" && $public_access_others != "Y" )
  $show_participants = false;

?>

<TABLE BORDER="0">

<INPUT TYPE="hidden" NAME="advanced" VALUE="1">

<TR><TD><B><?php etranslate("Keywords")?>:</B></TD>
<TD><INPUT NAME="keywords" SIZE=30></TD>
<TD><INPUT TYPE="submit" VALUE="<?php etranslate("Search")?>"></TD></TR>

<?php if ( $show_participants ) { ?>
<TR><TD VALIGN="top"><B><?php etranslate("Users"); ?></B></TD>
<?php
  $users = get_my_users ();
  $size = 0;
  $out = "";
  for ( $i = 0; $i < count ( $users ); $i++ ) {
    $out .= "<OPTION VALUE=\"" . $users[$i]['cal_login'] . "\"";
    if ( $users[$i]['cal_login'] == $login )
      $out .= " SELECTED";
    $out .= "> " . $users[$i]['cal_fullname'];
  }
  if ( count ( $users ) > 50 )
    $size = 15;
  else if ( count ( $users ) > 10 )
    $size = 10;
  else
    $size = count ( $users );
?>
<TD><SELECT NAME="users[]" SIZE="<?php echo $size;?>" MULTIPLE><?php echo $out; ?></SELECT>
<?php 
  if ( $groups_enabled == "Y" ) {
    echo "<INPUT TYPE=\"button\" ONCLICK=\"selectUsers()\" VALUE=\"" .
      translate("Select") . "...\">";
  }
?>
</TD></TR>

<?php } /* if show_participants */ ?>

</TABLE>

<?php } ?>

</FORM>

<?php include "includes/trailer.php"; ?>
</BODY>
</HTML>
