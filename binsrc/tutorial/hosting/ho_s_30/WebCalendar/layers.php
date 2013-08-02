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

send_no_cache_header ();
load_global_settings ();
load_user_preferences ();

include "includes/translate.php";

$updating_public = false;
if ( $is_admin && ! empty ( $public ) && $public_access == "Y" ) {
  $updating_public = true;
  $layer_user = "__public__";
  $u_url = "&public=1";
  $ret = "ret=layers.php%3Fpublic=1";
} else {
  $layer_user = $login;
  $u_url = "";
  $ret = "ret=layers.php";
}

load_user_layers ( $layer_user, 1 );

$layers_enabled = 0;
$sql = "SELECT cal_value FROM webcal_user_pref " .
  "WHERE cal_setting = 'LAYERS_STATUS' AND cal_login = '$layer_user'";
$res = dbi_query ( $sql );
if ( $res ) {
  $row = dbi_fetch_row ( $res );
  $layers_enabled = ( $row[0] == "Y" ? 1 : 0 );
  dbi_free_result ( $res );
}


?>
<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>


<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR;?>" CLASS="defaulttext">

<H2><FONT COLOR="<?php echo $H2COLOR;?>">
<?php
if ( $updating_public )
  echo translate($PUBLIC_ACCESS_FULLNAME) . " ";
etranslate("Layers")?></FONT></H2>

<?php

if ( $is_admin ) {
  if ( empty ( $public ) ) {
    echo "<blockquote><a href=\"layers.php?public=1\">" .
      translate("Click here") . "</a> " . 
      translate("to modify the layers settings for the") . " " .
      translate($PUBLIC_ACCESS_FULLNAME);
      "</blockquote>\n";
  }
}

etranslate("Layers are currently");

echo " <B>";
if ( $layers_enabled ) {
  etranslate ( "Enabled" );
} else {
  etranslate ( "Disabled" );
}
echo "</B>.<P>";

if ( $layers_enabled )
  echo "<A CLASS=\"navlinks\" HREF=\"layers_toggle.php?status=off$u_url&$ret\">" .
    translate ("Disable Layers") . "</A>\n";
else
  echo "<A CLASS=\"navlinks\" HREF=\"layers_toggle.php?status=on$u_url&$ret\">" .
    translate ("Enable Layers") . "</A>\n";


?>
<P>


<TABLE BORDER=0>

<?php

   for($index = 0; $index < sizeof($layers); $index++) {
      $layeruser = $layers[$index]['cal_layeruser'];
      user_load_variables ( $layeruser, "layer" );
?>
       <TR><TD VALIGN="top"><B><?php etranslate("Layer")?> <?php echo ($index+1) ?></B></TD></TR>
       <TR><TD VALIGN="top"><B><?php etranslate("Source")?>:</B></TD>
           <TD> <?php echo $layerfullname; ?> </TD></TR>

       <TR><TD><B><?php etranslate("Color")?>:</B></TD>
          <TD BGCOLOR="<?php echo $CELLBG;?>"><FONT COLOR="<?php echo ( $layers[$index]['cal_color'] ); ?>"><?php echo ( $layers[$index]['cal_color'] ); ?></FONT></TD></TR>

       <TR><TD><B><?php etranslate("Duplicates")?>:</B></TD>
          <TD>
              <?php
              if( $layers[$index]['cal_dups'] == 'N')
                etranslate("No");
              else
                etranslate("Yes");
              ?>
          </TD></TR>



       <TR><TD><A HREF="edit_layer.php?id=<?php echo $index . $u_url; ?>"><?php echo (translate("Edit layer")) ?></A></TD></TR>
       <TR><TD><A HREF="del_layer.php?id=<?php echo $index . $u_url; ?>" onClick="return confirm('<?php etranslate("Are you sure you want to delete this layer?")?>');"><?php etranslate("Delete layer")?></A><BR></TD></TR>


       <TR><TD><BR></TD></TR>

<?php
   }
?>

       <TR><TD><A HREF="edit_layer.php<?php if ( $updating_public ) echo "?public=1";?>"><?php echo (translate("Add layer")); ?></A></TD></TR>

</TABLE>

<FORM>
<INPUT TYPE="button" VALUE="<?php etranslate("Help")?>..."
  ONCLICK="window.open ( 'help_layers.php', 'cal_help', 'dependent,menubar,scrollbars,height=400,width=400,innerHeight=420,outerWidth=420' );">
</FORM>

<?php include "includes/trailer.php"; ?>
</BODY>
</HTML>
