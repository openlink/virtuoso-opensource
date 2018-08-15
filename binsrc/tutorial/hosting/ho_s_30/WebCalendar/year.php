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

function display_small_month ( $thismonth, $thisyear, $showyear ) {
  global $WEEK_START, $user, $login;

  if ( $user != $login && ! empty ( $user ) )
    $u_url = "&user=$user";
  else
    $u_url = "";

  echo "<TABLE BORDER=\"0\" CELLPADDING=\"1\" CELLSPACING=\"2\">";
  if ( $WEEK_START == "1" )
    $wkstart = get_monday_before ( $thisyear, $thismonth, 1 );
  else
    $wkstart = get_sunday_before ( $thisyear, $thismonth, 1 );

  $monthstart = mktime(2,0,0,$thismonth,1,$thisyear);
  $monthend = mktime(2,0,0,$thismonth + 1,0,$thisyear);
  echo "<TR><TD COLSPAN=\"7\" ALIGN=\"center\">"
     . "<A HREF=\"month.php?year=$thisyear&month=$thismonth"
     . $u_url . "\" CLASS=\"monthlink\">";
  echo month_name ( $thismonth - 1 ) .
    "</A></TD></TR>";
  echo "<TR>";
  if ( $WEEK_START == 0 ) echo "<TD><FONT SIZE=\"-3\">" .
    weekday_short_name ( 0 ) . "</TD>";
  for ( $i = 1; $i < 7; $i++ ) {
    echo "<TD><FONT SIZE=\"-3\">" .
      weekday_short_name ( $i ) . "</TD>";
  }
  if ( $WEEK_START == 1 ) echo "<TD><FONT SIZE=\"-3\">" .
    weekday_short_name ( 0 ) . "</TD>";
  for ($i = $wkstart; date("Ymd",$i) <= date ("Ymd",$monthend);
    $i += (24 * 3600 * 7) ) {
    echo "<TR>";
    for ($j = 0; $j < 7; $j++) {
      $date = $i + ($j * 24 * 3600);
      if ( date("Ymd",$date) >= date ("Ymd",$monthstart) &&
        date("Ymd",$date) <= date ("Ymd",$monthend) ) {
        echo "<TD ALIGN=\"right\"><A HREF=\"day.php?date=" .
          date ( "Ymd", $date ) . $u_url .
          "\" CLASS=\"dayofmonthyearview\">";
        echo "<FONT SIZE=\"-1\">" . date ( "j", $date ) .
          "</A></FONT></TD>";
      } else
        echo "<TD></TD>";
    }                 // end for $j
    echo "</TR>";
  }                         // end for $i
  echo "</TABLE>";
}

if ( empty ( $year ) )
  $year = date("Y");

$thisyear = $year;
if ( $year != date ( "Y") )
  $thismonth = 1;

if ( $year > "1903" )
  $prevYear = $year - 1;
else
  $prevYear=$year;

$nextYear= $year + 1;

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

if ( $allow_view_other != "Y" && ! $is_admin )
  $user = "";

?>

<HTML>

<HEAD>

<TITLE><?php etranslate ( $application_name) ?></TITLE>
<?php include "includes/styles.php"; ?>
</HEAD>
<BODY BGCOLOR=<?php echo "\"$BGCOLOR\"";?> CLASS="defaulttext">
<TABLE WIDTH="100%">
<TR>
<?php if ( empty ( $friendly ) ) { ?>
<TD ALIGN="left"><FONT SIZE="-1">
<A HREF="year.php?year=<?php echo $prevYear; if ( ! empty ( $user ) ) echo "&user=$user";?>" CLASS="monthlink"><IMG SRC="leftarrow.gif" WIDTH="36" HEIGHT="32" BORDER="0" ALT="<?php etranslate("Previous")?>"></A>
</FONT></TD>
<?php } ?>
<TD ALIGN="center">
<FONT SIZE="+2" COLOR="<?php echo $H2COLOR?>"><B>
<?php echo $thisyear ?>
</B></FONT>
<FONT COLOR="<?php echo $H2COLOR?>" SIZE="+1">
<?php
  if ( $single_user == "N" ) {
    echo "<BR>\n";
    if ( ! empty ( $user ) ) {
      user_load_variables ( $user, "user_" );
      echo $user_fullname;
    } else
      echo $fullname;
    if ( $is_assistant )
      echo "<B><BR>-- " . translate("Assistant mode") . " --</B>";
  }
?>
</FONT></TD>
<?php if ( empty ( $friendly ) ) { ?>
<TD ALIGN="right">
<A HREF="year.php?year=<?php echo $nextYear; if ( ! empty ( $user ) ) echo "&user=$user";?>" CLASS="monthlink"><IMG SRC="rightarrow.gif" WIDTH="36" HEIGHT="32" BORDER="0" ALT="<?php etranslate("Next")?>"></A>
</FONT></TD>
<?php } ?>
</TR>
</TABLE>

<CENTER>
<TABLE BORDER="0" CELLSPACING="4" CELLPADDING="4">
<TR>
<TD VALIGN="top"><? display_small_month(1,$year,False); ?></TD>
<TD VALIGN="top"><? display_small_month(2,$year,False); ?></TD>
<TD VALIGN="top"><? display_small_month(3,$year,False); ?></TD>
<TD VALIGN="top"><? display_small_month(4,$year,False); ?></TD>
</TR>
<TR>
<TD VALIGN="top"><? display_small_month(5,$year,False); ?></TD>
<TD VALIGN="top"><? display_small_month(6,$year,False); ?></TD>
<TD VALIGN="top"><? display_small_month(7,$year,False); ?></TD>
<TD VALIGN="top"><? display_small_month(8,$year,False); ?></TD>
</TR>
<TR>
<TD VALIGN="top"><? display_small_month(9,$year,False); ?></TD>
<TD VALIGN="top"><? display_small_month(10,$year,False); ?></TD>
<TD VALIGN="top"><? display_small_month(11,$year,False); ?></TD>
<TD VALIGN="top"><? display_small_month(12,$year,False); ?></TD>
</TR>
</TABLE>
</CENTER>

<P>

<?php if ( empty ( $friendly ) ) {

display_unapproved_events ( $login );

?>
<P>
<A CLASS="navlinks" HREF="year.php?<?php
  if ( $thisyear )
    echo "year=$thisyear&";
  if ( $user != $login && ! empty ( $user ) )
    echo "user=$user&";
?>friendly=1" TARGET="cal_printer_friendly"
onMouseOver="window.status = '<?php etranslate("Generate printer-friendly version")?>'">[<?php etranslate("Printer Friendly")?>]</A>

<?php include "includes/trailer.php"; ?>

<?php } else {
        dbi_close ( $c );
      }
?>

</BODY>
</HTML>


