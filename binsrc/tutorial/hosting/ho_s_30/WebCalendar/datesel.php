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
load_user_layers ();

include "includes/translate.php";

?>
<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>
<SCRIPT LANGUAGE="JavaScript">
function sendDate ( date ) {
  year = date.substring ( 0, 4 );
  month = date.substring ( 4, 6 );
  day = date.substring ( 6, 8 );
  window.opener.document.<?php echo $form?>.<?php echo $day?>.selectedIndex = day - 1;
  window.opener.document.<?php echo $form?>.<?php echo $month?>.selectedIndex = month - 1;
  for ( i = 0; i < window.opener.document.<?php echo $form?>.<?php echo $year?>.length; i++ ) {
    if ( window.opener.document.<?php echo $form?>.<?php echo $year?>.options[i].value == year ) {
      window.opener.document.<?php echo $form?>.<?php echo $year?>.selectedIndex = i;
    }
  }
  window.close ();
}
</SCRIPT>
<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR="<?php echo $BGCOLOR;?>" CLASS="defaulttext">
<CENTER>

<?php
if ( strlen ( $date ) > 0 ) {
  $thisyear = substr ( $date, 0, 4 );
  $thismonth = substr ( $date, 4, 2 );
} else {
  $thismonth = date("m");
  $thisyear = date("Y");
}

$next = mktime ( 3, 0, 0, $thismonth + 1, 1, $thisyear );
$nextyear = date ( "Y", $next );
$nextmonth = date ( "m", $next );
$nextdate = date ( "Ym", $next ) . "01";

$prev = mktime ( 3, 0, 0, $thismonth - 1, 1, $thisyear );
$prevyear = date ( "Y", $prev );
$prevmonth = date ( "m", $prev );
$prevdate = date ( "Ym", $prev ) . "01";

?>

<TABLE BORDER=0>
<TR>
<TD><A HREF="datesel.php?form=<?php echo $form?>&day=<?php echo $day?>&month=<?php echo $month?>&year=<?php echo $year?>&date=<?php echo $prevdate?>"><IMG SRC="leftarrowsmall.gif" WIDTH="18" HRIGHT="18" BORDER="0" ALT="<?php etranslate("Previous")?>"></A></TD>
<TH COLSPAN="5"><?php echo month_name ( $thismonth - 1 ) . " " . $thisyear;?></TH>
<TD><A HREF="datesel.php?form=<?php echo $form?>&day=<?php echo $day?>&month=<?php echo $month?>&year=<?php echo $year?>&date=<?php echo $nextdate?>"><IMG SRC="rightarrowsmall.gif" WIDTH="18" HEIGHT="18" BORDER="0" ALT="<?php etranslate("Next")?>"></A></TD>
</TR>
<?php
echo "<TR>";
if ( $WEEK_START == 0 ) echo "<TD><FONT SIZE=\"-1\">" .
  weekday_short_name ( 0 ) . "</TD>";
for ( $i = 1; $i < 7; $i++ ) {
  echo "<TD><FONT SIZE=\"-1\">" .
    weekday_short_name ( $i ) . "</TD>";
}
if ( $WEEK_START == 1 ) echo "<TD><FONT SIZE=\"-1\">" .
  weekday_short_name ( 0 ) . "</TD>";
echo "</TR>\n";
if ( $WEEK_START == "1" )
  $wkstart = get_monday_before ( $thisyear, $thismonth, 1 );
else
  $wkstart = get_sunday_before ( $thisyear, $thismonth, 1 );
$monthstart = mktime ( 3, 0, 0, $thismonth, 1, $thisyear );
$monthend = mktime ( 3, 0, 0, $thismonth + 1, 0, $thisyear );
for ( $i = $wkstart; date ( "Ymd", $i ) <= date ( "Ymd", $monthend );
  $i += ( 24 * 3600 * 7 ) ) {
  echo "<TR>\n";
  for ( $j = 0; $j < 7; $j++ ) {
    $date = $i + ( $j * 24 * 3600 );
    if ( date ( "Ymd", $date ) >= date ( "Ymd", $monthstart ) &&
      date ( "Ymd", $date ) <= date ( "Ymd", $monthend ) ) {
      echo "<TD><A HREF=\"javascript:sendDate('" .
        date ( "Ymd", $date ) . "')\">" .
        date ( "d", $date ) . "</A></TD>";
    } else {
      echo "<TD></TD>\n";
    }
  }
  echo "</TR>\n";
}
?>
</TABLE>

</CENTER>

</BODY>
</HTML>
