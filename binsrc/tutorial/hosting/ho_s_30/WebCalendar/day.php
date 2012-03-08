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

send_no_cache_header ();
load_global_settings ();
load_user_preferences ();
load_user_layers ();
load_user_categories ();
if ( empty ( $friendly ) && empty ( $user ) )
  remember_this_view ();

include "includes/translate.php";

if ( $allow_view_other != "Y" && ! $is_admin )
  $user = "";

$view = "day";

$can_add = ( $readonly == "N" || $is_admin == "Y" );
if ( $public_access == "Y" && $login == "__public__" ) {
  if ( $public_access_can_add != "Y" )
    $can_add = false;
  if ( $public_access_others != "Y" )
    $user = ""; // security precaution
}

if ( ! empty ( $user ) ) {
  $u_url = "user=$user&";
  user_load_variables ( $user, "user_" );
} else {
  $u_url = "";
  $user_fullname = $fullname;
}

if ( ! empty ( $date ) ) {
  $thisyear = substr ( $date, 0, 4 );
  $thismonth = substr ( $date, 4, 2 );
  $thisday = substr ( $date, 6, 2 );
} else {
  if ( empty ( $month ) || $month == 0 )
    $thismonth = date("m");
  else
    $thismonth = $month;
  if ( empty ( $year ) || $year == 0 )
    $thisyear = date("Y");
  else
    $thisyear = $year;
  if ( empty ( $day ) || $day == 0 )
    $thisday = date("d");
  else
    $thisday = $day;
}
$wday = strftime ( "%w", mktime ( 3, 0, 0, $thismonth, $thisday, $thisyear ) );

$now = mktime ( 3, 0, 0, $thismonth, $thisday, $thisyear );
$nowYmd = date ( "Ymd", $now );

$next = mktime ( 3, 0, 0, $thismonth, $thisday + 1, $thisyear );
$nextYmd = date ( "Ymd", $next );
$nextyear = date ( "Y", $next );
$nextmonth = date ( "m", $next );
$nextday = date ( "d", $next );
$month_ago = date ( "Ymd", mktime ( 3, 0, 0, $thismonth - 1, $thisday, $thisyear ) );

$prev = mktime ( 3, 0, 0, $thismonth, $thisday - 1, $thisyear );
$prevYmd = date ( "Ymd", $prev );
$prevyear = date ( "Y", $prev );
$prevmonth = date ( "m", $prev );
$prevday = date ( "d", $prev );
$month_ahead = date ( "Ymd", mktime ( 3, 0, 0, $thismonth + 1, $thisday, $thisyear ) );

if ( $categories_enabled == "Y" && ( !$user || $user == $login ) ) {
  if ( isset ( $cat_id ) ) {
    $cat_id = $cat_id;
  } elseif ( isset ( $CATEGORY_VIEW ) ) {
    $cat_id = $CATEGORY_VIEW;
  } else {
    $cat_id = '';
  }
} else {
  $cat_id = '';
}
if ( empty ( $cat_id ) )
  $caturl = "";
else
  $caturl = "&cat_id=$cat_id";

?>
<HTML>
<HEAD>
<TITLE><?php etranslate($application_name)?></TITLE>
<?php include "includes/styles.php"; ?>
<?php include "includes/js.php"; ?>
<?php
if ( $auto_refresh == "Y" && ! empty ( $auto_refresh_time ) ) {
  $refresh = $auto_refresh_time * 60; // convert to seconds
  echo "<META HTTP-EQUIV=\"refresh\" content=\"$refresh; URL=day.php?$u_url" .
    "date=$nowYmd$caturl\" TARGET=\"_self\">\n";
}

?>
</HEAD>
<BODY BGCOLOR=<?php echo "\"$BGCOLOR\"";?> CLASS="defaulttext">

<?php

/* Pre-Load the repeated events for quckier access */
$repeated_events = read_repeated_events ( empty ( $user ) ? $login : $user,
  $cat_id  );

/* Pre-load the non-repeating events for quicker access */
$events = read_events ( empty ( $user ) ? $login : $user, $nowYmd, $nowYmd,
  $cat_id  );

?>

<TABLE BORDER="0" WIDTH="100%">
<TR><TD VALIGN="top" WIDTH="70%"><TR><TD>
<TABLE BORDER="0" WIDTH="100%">
<TR>
<?php if ( empty ( $friendly ) ) { ?>
<TD VALIGN="left"><A HREF="day.php?<?php echo $u_url;?>date=<?php echo $prevYmd . $caturl;?>"><img align="left" src="leftarrow.gif" width="36" height="32" border="0" alt="<?php etranslate("Previous"); ?>"></A></TD>
<?php } ?>
<TD ALIGN="middle"><FONT SIZE="+2" COLOR="<?php echo $H2COLOR;?>"><B>
<?php
  echo date_to_str ( $nowYmd );
?>
</B></FONT>
<FONT SIZE="+1" COLOR="<?php echo $H2COLOR;?>">
<?php
  // display current calendar's user (if not in single user)
  if ( $single_user == "N" ) {
    echo "<BR>";
    echo $user_fullname;
  }
  if ( $is_assistant )
    echo "<B><BR>-- " . translate("Assistant mode") . " --</B>";
  if ( $categories_enabled == "Y" ) {
    echo "<BR>\n<BR>\n";
    print_category_menu('day', sprintf ( "%04d%02d%02d",$thisyear, $thismonth, $thisday ), $cat_id, $friendly);
  }
?>
</FONT>
</TD>
<?php if ( empty ( $friendly ) ) { ?>
<TD VALIGN="right"><A HREF="day.php?<?php echo $u_url;?>date=<?php echo $nextYmd . $caturl;?>"><img align="right" src="rightarrow.gif" width="36" height="32" border="0" alt="<?php etranslate("Next"); ?>"></A></TD>
<?php } ?>
</TR>
</TABLE>

<?php if ( empty ( $friendly ) || ! $friendly ) { ?>
<TABLE BORDER="0" WIDTH="100%" CELLSPACING="0" CELLPADDING="0">
<TR><TD BGCOLOR="<?php echo $TABLEBG?>">
<TABLE BORDER="0" WIDTH="100%" CELLSPACING="1" CELLPADDING="2">
<?php } else { ?>
<TABLE BORDER="1" WIDTH="100%" CELLSPACING="0" CELLPADDING="0">
<?php } ?>


<?php

if ( empty ( $TIME_SLOTS ) )
  $TIME_SLOTS = 24;

print_day_at_a_glance ( date ( "Ymd", $now ),
  empty ( $user ) ? $login : $user, ! empty ( $friendly ), $can_add );

?>

<?php if ( empty ( $friendly ) || ! $friendly ) { ?>
</TABLE>
</TD></TR></TABLE>
<?php } else { ?>
</TABLE>
<?php } ?>

</TD>
<TD VALIGN="top">
<?php if ( empty ( $friendly ) ) { ?>
<DIV ALIGN="right">
<TABLE BORDER="0" CELLSPACING="0" CELLPADDING="0">
<TR><TD BGCOLOR="<?php echo $TABLEBG?>">
<TABLE BORDER="0" WIDTH="100%" CELLSPACING="1" CELLPADDING="2">
<TR><TH COLSPAN="7" BGCOLOR="<?php echo $THBG?>"><FONT SIZE="+4" COLOR="<?php echo $THFG?>"><?php echo $thisday?></FONT></TH></TR>
<TR>
<TD ALIGN="left" BGCOLOR="<?php echo $THBG?>"><A HREF="day.php?<?php echo $u_url; ?>date=<?php echo $month_ago . $caturl?>" CLASS="monthlink"><img src="leftarrowsmall.gif" width="18" height="18" border="0" ALT="<? etranslate("Previous")?>"></A></TD>
<TH COLSPAN="5" BGCOLOR="<?php echo $THBG?>"><FONT COLOR="<?php echo $THFG?>"><?php echo date_to_str ( sprintf ( "%04d%02d01", $thisyear, $thismonth ), $DATE_FORMAT_MY, false ) ?></FONT></TH>
<TD ALIGN="right" BGCOLOR="<?php echo $THBG?>"><A HREF="day.php?<?php echo $u_url; ?>date=<?php echo $month_ahead . $caturl?>" CLASS="monthlink"><img src="rightarrowsmall.gif" width="18" height="18" border="0" alt="<?php etranslate("Next") ?>"></A></TD>
</TR>
<?php
echo "<TR>";
if ( $WEEK_START == 0 ) echo "<TD BGCOLOR=\"$CELLBG\"><FONT SIZE=\"-3\">" .
  weekday_short_name ( 0 ) . "</TD>";
for ( $i = 1; $i < 7; $i++ ) {
  echo "<TD BGCOLOR=\"$CELLBG\"><FONT SIZE=\"-3\">" .
    weekday_short_name ( $i ) . "</TD>";
}
if ( $WEEK_START == 1 ) echo "<TD BGCOLOR=\"$CELLBG\"><FONT SIZE=\"-3\">" .
  weekday_short_name ( 0 ) . "</TD>";
echo "</TR>\n";
// generate values for first day and last day of month
$monthstart = mktime ( 3, 0, 0, $thismonth, 1, $thisyear );
$monthend = mktime ( 3, 0, 0, $thismonth + 1, 0, $thisyear );
if ( $WEEK_START == "1" )
  $wkstart = get_monday_before ( $thisyear, $thismonth, 1 );
else
  $wkstart = get_sunday_before ( $thisyear, $thismonth, 1 );
$wkend = $wkstart + ( 3600 * 24 * 7 );

for ( $i = $wkstart; date ( "Ymd", $i ) <= date ( "Ymd", $monthend );
  $i += ( 24 * 3600 * 7 ) ) {
  for ( $i = $wkstart; date ( "Ymd", $i ) <= date ( "Ymd", $monthend );
    $i += ( 24 * 3600 * 7 ) ) {
    echo "<TR ALIGN=\"center\">\n";
    for ( $j = 0; $j < 7; $j++ ) {
      $date = $i + ( $j * 24 * 3600 );
      if ( date ( "Ymd", $date ) >= date ( "Ymd", $monthstart ) &&
        date ( "Ymd", $date ) <= date ( "Ymd", $monthend ) ) {
        if ( date ( "Ymd", $date ) == date ( "Ymd", $now ) )
          echo "<TD BGCOLOR=\"$TODAYCELLBG\">";
        else
          echo "<TD BGCOLOR=\"$CELLBG\">";
        echo "<FONT SIZE=\"-2\">";
        echo "<A HREF=\"day.php?";
        echo $u_url;
        echo "date=" . date ( "Ymd", $date ) . "$caturl\" CLASS=\"monthlink\">" .
         date ( "d", $date ) .
         "</A></FONT></TD>\n";
      } else {
        print "<TD BGCOLOR=\"$CELLBG\">&nbsp;</TD>\n";
      }
    }
    echo "</TR>\n";
  }
}
?>
</TABLE>
</TD></TR></TABLE>
</DIV>
<?php } ?>
</TD></TR></TABLE>

<P>

<?php if ( isset ( $eventinfo ) && empty ( $friendly ) ) echo $eventinfo; ?>

<?php if ( empty ( $friendly ) ) {

  display_unapproved_events ( $login );

?>

<P>
<A HREF="day.php?<?php
  echo $u_url;
  if ( $thisyear ) {
    echo "year=$thisyear&month=$thismonth&day=$thisday&";
  }
  if ( ! empty ( $cat_id ) ) echo "cat_id=$cat_id&";
?>friendly=1" TARGET="cal_printer_friendly"
onMouseOver="window.status = '<?php etranslate("Generate printer-friendly version")?>'">[<?php etranslate("Printer Friendly")?>]</A>

<?php include "includes/trailer.php"; ?>

<?php } else {
        dbi_close ( $c );
      }
?>

</BODY>
</HTML>
