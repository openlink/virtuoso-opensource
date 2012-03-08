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

include "includes/config.php";
include "includes/php-dbi.php";
include "includes/functions.php";
include "includes/$user_inc";
include "includes/validate.php";
include "includes/connect.php";

load_global_settings ();
load_user_preferences ();

// load user and global cats
load_user_categories ();

include "includes/translate.php";

$error = "";

if ( $categories_enabled == "N" ) {
  do_redirect ( "$STARTVIEW.php" );
  exit;
}

// If editing, make sure they are editing their own
// (or they are an admin user).
if ( isset ( $id ) ) {
  $res = dbi_query ( "SELECT cat_id, cat_owner FROM webcal_categories WHERE " .
    "cat_id = $id" );
  if ( $res ) {
    if ( $row = dbi_fetch_row ( $res ) ) {
      if ( $row[0] != $id )
        $error = translate ( "Invalid entry id" ) . ": " . $id;
      else if ( $row[1] != $login && ! $is_admin )
        $error = translate ( "You are not authorized" ) . ".";
    }
    dbi_free_result ( $res );
  } else {
    $error = translate("Database error") . ": " . dbi_error ();
  }
}

?>
<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>
<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR;?>" CLASS="defaulttext">

<H2><FONT COLOR="<?php echo $H2COLOR;?>"><?php etranslate("Categories")?></FONT></H2>

<?php

// Adding/Editing category
if ( ( ( $add == '1' ) || ( isset ( $id ) ) ) && empty ( $error ) ) {
  $button = translate("Add");
  ?>
  <FORM ACTION="category_handler.php" METHOD="POST">
  <?php
  if ( isset ( $id ) ) {
    echo "<INPUT NAME=\"id\" TYPE=\"hidden\" VALUE=\"$id\">";
    $button = translate("Save");
    $catname = $categories[$id];
    $catowner = $category_owners[$id];
  }
  ?>
  <?php etranslate("Category Name")?>: <INPUT NAME="catname" SIZE="20" VALUE="<?php echo htmlspecialchars ( $catname ); ?>">
  <BR>
  <?php if ( $is_admin && empty ( $id ) ) { ?>
    <?php etranslate("Global")?>:
      <INPUT TYPE="radio" NAME="isglobal" VALUE="N" <?php if ( ! empty ( $catowner ) || empty ( $id ) ) echo "CHECKED";?>> <?php etranslate("No")?>
      <INPUT TYPE="radio" NAME="isglobal" VALUE="Y" <?php if ( empty ( $catowner ) && ! empty ( $id ) ) echo "CHECKED";?>> <?php etranslate("Yes")?>
  <?php } ?>
  <BR><BR>
  <INPUT TYPE="submit" NAME="action" VALUE="<?php echo $button;?>">
  <?php if ( isset ( $id ) ) {  ?>
    <INPUT TYPE="submit" NAME="action" VALUE="<?php etranslate("Delete");?>" ONCLICK="return confirm('<?php etranslate("Are you sure you want to delete this entry?"); ?>')">
  <?php }  ?>
  </FORM>
  <?php
} else if ( empty ( $error ) ) {
  // Displaying Categories
  $global_found = false;
  if ( ! empty ( $categories ) ) {
    echo "<UL>";
    foreach ( $categories as $K => $V ) {
      echo "<LI>";
      if ( $category_owners[$K] == $login || $is_admin )
        echo "<A HREF=\"category.php?id=$K\">$V</A>";
      else
        echo $V;
      if ( empty ( $category_owners[$K] ) ) {
        echo "<SUP>*</SUP>";
	$global_found = true;
      }
      echo "</LI>\n";
    }
    echo "</UL>";
  }
  if ( $global_found )
    echo "<P><SUP>*</SUP> " . translate ( "Global" );
  echo "<P><A HREF=\"category.php?add=1\">" . translate("Add New Category") . "</A></P><BR>\n";
}

if ( ! empty ( $error ) ) {
  echo "<B>" . translate ( "Error" ) . ":</B>" . $error;
}

?>


<?php include "includes/trailer.php"; ?>
</BODY>
</HTML>
