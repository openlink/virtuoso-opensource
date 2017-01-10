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

include "includes/translate.php";

// input args in URL
// users: list of comma-separated users
// form: name of form on parent page
// listid: element id of user selection object in form
//   ... to be used like form.elements[$listid]
if ( !isset ( $form ) ) {
  echo "Program Error: No form specified!"; exit;
}
if ( !isset ( $listid ) ) {
  echo "Program Error: No listid specified!"; exit;
}

// parse $users
$exp = split ( ",", $users );
$selected = array ();
for ( $i = 0; $i < count ( $exp ); $i++ ) {
  $selected[$exp[$i]] = 1;
}

// load list of groups
if ( $user_sees_only_his_groups == "Y" ) {
  $sql =
    "SELECT webcal_group.cal_group_id, webcal_group.cal_name " .
    "FROM webcal_group, webcal_group_user " .
    "WHERE webcal_group.cal_group_id = webcal_group_user.cal_group_id " .
    "AND webcal_group_user.cal_login = '$login' " .
    "ORDER BY webcal_group.cal_name";
} else {
  // show all groups
  $sql = "SELECT cal_group_id, cal_name FROM webcal_group " .
    "ORDER BY cal_name";
}

$res = dbi_query ( $sql );
$groups = array ();
if ( $res ) {
  while ( $row = dbi_fetch_row ( $res ) ) {
    $groups[] = array (
      "cal_group_id" => $row[0],
      "cal_name" => $row[1]
      );
  }
  dbi_free_result ( $res );
}

?>
<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>
<SCRIPT LANGUAGE="JavaScript">
function OkButton () {
  var parentlist = window.opener.document.<?php echo $form?>.elements[<?php echo $listid?>];
  var thislist = document.forms[0].elements[0];

  var found = "";

  // select/deselect all elements
  for ( i = 0; i < parentlist.length; i++ ) {
    var state = false;
    for ( j = 0; j < thislist.length; j++ ) {
      if ( thislist.options[j].value == parentlist.options[i].value ) {
        state = thislist.options[i].selected;
        found += " " + thislist.options[j].value;
      }
    }
    parentlist.options[i].selected = state;
  }
  //alert ( "Found: " + found );
  window.close ();
}

function selectAll() {
  var list = document.forms[0].elements[0];
  var i;
  for ( i = 0; i < list.options.length; i++ ) {
    list.options[i].selected = true;
  }
}

function selectNone() {
  var list = document.forms[0].elements[0];
  var i;
  for ( i = 0; i < list.options.length; i++ ) {
    list.options[i].selected = false;
  }
}

// set the state (selected or unselected) if a single
// user in the list of users
function selectByLogin ( login, state ) {
  //alert ( "selectByLogin ( " + login + ", " + state + " )" );
  var list = document.forms[0].elements[0];
  var i;
  for ( i = 0; i < list.options.length; i++ ) {
    //alert ( "text: " + list.options[i].text );
    if ( list.options[i].value == login ) {
      list.options[i].selected = state;
      return;
    }
  }
}


function toggleGroup ( state ) {
  var list = document.forms[0].elements[4];
  var selNum = list.selectedIndex;
  <?php
  for ( $i = 0; $i < count ( $groups ); $i++ ) {
    print "\n  if ( selNum == $i ) {\n";
    $res = dbi_query ( "SELECT cal_login from webcal_group_user " .
      "WHERE cal_group_id = " . $groups[$i]["cal_group_id"] );
    if ( $res ) {
      while ( $row = dbi_fetch_row ( $res ) ) {
        print "    selectByLogin ( \"$row[0]\", state );\n";
      }
      dbi_free_result ( $res );
      print "  }\n";
    }
  }
  ?>
}

// Select users from a group
function selectGroupMembers () {
  toggleGroup ( true );
}

// De-select users from a group
function deselectGroupMembers () {
  toggleGroup ( false );
}

</SCRIPT>
<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR;?>" CLASS="defaulttext">
<CENTER>

<FORM ACTION="#">


<TABLE BORDER="0" WIDTH="100%">
<TR><TD VALIGN="top">
<B><?php etranslate("Users"); ?>:</B><BR>
<SELECT NAME="users" SIZE="15" MULTIPLE>
<?php

$users = get_my_users ();
for ( $i = 0; $i < count ( $users ); $i++ ) {
  $u = $users[$i]['cal_login'];
  echo "<OPTION VALUE=\"$u\" ";
  if ( ! empty ( $selected[$u] ) )
    echo "SELECTED";
  echo "> " . $users[$i]['cal_fullname'];
}
?>
</SELECT><BR>
<INPUT TYPE="button" VALUE="<?php etranslate("All");?>"
  ONCLICK="selectAll()">
<INPUT TYPE="button" VALUE="<?php etranslate("None");?>"
  ONCLICK="selectNone()">
<INPUT TYPE="reset" VALUE="<?php etranslate("Reset");?>">
</TD>

<TD VALIGN="top">
<B><?php etranslate("Groups"); ?>:<B><BR>
<SELECT NAME="groups" SIZE="15">
<?php
for ( $i = 0; $i < count ( $groups ); $i++ ) {
  echo "<OPTION VALUE=\"" . $groups[$i]['cal_group_id'] .
      "\">" . $groups[$i]['cal_name'] . "</OPTION>\n";
}
?>
</SELECT><BR>
<INPUT TYPE="button" VALUE="<?php etranslate("Add");?>"
  ONCLICK="selectGroupMembers();">
<INPUT TYPE="button" VALUE="<?php etranslate("Remove");?>"
  ONCLICK="deselectGroupMembers();">
</TD></TR>

<TR><TD COLSPAN="2"><CENTER>
<BR><BR>
<INPUT TYPE="button" VALUE="<?php etranslate("Ok");?>"
  ONCLICK="OkButton()">
<INPUT TYPE="button" VALUE="<?php etranslate("Cancel");?>"
  ONCLICK="window.close()">
</CENTER></TD></TR>

</TABLE>

</BODY>
</HTML>
