<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2019 OpenLink Software
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

$updating_public = false;
if ( $is_admin && ! empty ( $public ) && $public_access == "Y" ) {
  $updating_public = true;
  $layer_user = "__public__";
} else {
  $layer_user = $login;
}

load_user_layers ( $layer_user, 1 );

?>


<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>

<SCRIPT LANGUAGE="JavaScript">

function valid_color ( str ) {
  var ch, j;
  var valid = "0123456789abcdefABCDEF";

  if ( str.length == 0 )
    return true;

  if ( str.charAt ( 0 ) != '#' || str.length != 7 )
    return false;

  for ( j = 1; j < str.length; j++ ) {
   ch = str.charAt ( j );
   if ( valid.indexOf ( ch ) < 0 )
     return false;
  }
  return true;
}

function valid_form ( form ) {
  var err = "";
  if ( ! valid_color ( form.layercolor.value ) )
    err += "<?php etranslate("Invalid color")?>.\n";

  if ( err.length > 0 ) {
    alert ( "Error:\n\n" + err + "\n\n<?php etranslate("Color format should be '#RRGGBB'")?>" );
    return false;
  }
  return true;
}

function selectColor ( color ) {
  url = "colors.php?color=" + color;
  var colorWindow = window.open(url,"ColorSelection","width=390,height=350,resizable=yes,scrollbars=yes");
}

</SCRIPT>

<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR; ?>" CLASS="defaulttext">

<H2><FONT COLOR="<?php echo $H2COLOR;?>">
<?php
if ( $updating_public )
  echo translate($PUBLIC_ACCESS_FULLNAME) . " ";
if ( ! empty ( $layers[$id]['cal_layeruser'] ) )
  etranslate("Edit Layer");
else
  etranslate("Add Layer");

?></FONT></H2>



<FORM ACTION="edit_layer_handler.php" METHOD="POST" ONSUBMIT="return valid_form(this);" NAME="prefform">

<?php if ( $updating_public ) { ?>
  <INPUT TYPE="hidden" NAME="public" VALUE="1">
<?php } ?>

<TABLE BORDER=0>


<?php
if ( $single_user == "N" ) {
  $userlist = get_my_users ();
  $num_users = 0;
  $size = 0;
  $users = "";
  for ( $i = 0; $i < count ( $userlist ); $i++ ) {
    if ( $userlist[$i]['cal_login'] != $layer_user ) {
      $size++;
      $users .= "<OPTION VALUE=\"" . $userlist[$i]['cal_login'] . "\"";
      if ( ! empty ( $layers[$id]['cal_layeruser'] ) ) {
        if ( $layers[$id]['cal_layeruser'] == $userlist[$i]['cal_login'] )
          $users .= " SELECTED";
      } 
      $users .= "> " . $userlist[$i]['cal_fullname'];
    }
  }
  if ( $size > 50 )
    $size = 15;
  else if ( $size > 5 )
    $size = 5;
  if ( $size >= 1 ) {
    print "<TR><TD VALIGN=\"top\"><B>" .
      translate("Source") . ":</B></TD>";
    print "<TD><SELECT NAME=\"layeruser\" SIZE=1>$users\n";
    print "</SELECT>\n";
    print "</TD></TR>\n";
  }
}
?>

<TR><TD><B><?php etranslate("Color")?>:</B></TD>
  <TD><INPUT NAME="layercolor" SIZE=7 MAXLENGTH=7 VALUE="<?php echo empty ( $layers[$id]['cal_color'] ) ? "" :  $layers[$id]['cal_color']; ?>"> 

<INPUT TYPE="button" ONCLICK="selectColor('layercolor')" VALUE="<?php etranslate("Select")?>...">
</TD></TR>


<TR><TD><B><?php etranslate("Duplicates")?>:</B></TD>
    <TD><INPUT TYPE="checkbox" NAME="dups" VALUE="Y" <?php if ( ! empty ( $layers[$id]['cal_dups'] ) && $layers[$id]['cal_dups'] == 'Y') echo "checked"; ?> >&nbsp;&nbsp;<?php etranslate("Show layer events that are the same as your own")?></TD></TR> 


<TR><TD COLSPAN="2"><INPUT TYPE="submit" VALUE="<?php etranslate("Save")?>">
<INPUT TYPE="button" VALUE="<?php etranslate("Help")?>..."
  ONCLICK="window.open ( 'help_layers.php', 'cal_help', 'dependent,menubar,scrollbars,height=400,width=400,innerHeight=420,outerWidth=420' );">
</TD></TR>


<?php

// If this is 'Edit Layer' (a layer already exists) put a 'Delete Layer' link
if ( ! empty ( $layers[$id]['cal_layeruser'] ) )
{

?>

<TR><TD><BR><A HREF="del_layer.php?id=<?php echo $id; if ( $updating_public ) echo "&public=1"; ?>" onClick="return confirm('<?php etranslate("Are you sure you want to delete this layer?")?>');"><?php etranslate("Delete layer")?></A><BR></TD></TR>

<?php

}  // end of 'Delete Layer' link if

?>


</TABLE>

<?php if ( ! empty ( $layers[$id]['cal_layeruser'] ) ) echo "<INPUT TYPE=\"hidden\" NAME=\"id\" VALUE=\"$id\">\n"; ?>

</FORM>

<?php include "includes/trailer.php"; ?>
</BODY>
</HTML>
