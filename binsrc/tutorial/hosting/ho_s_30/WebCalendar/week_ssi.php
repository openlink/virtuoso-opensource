<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2016 OpenLink Software
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

// This page is intended to be used as a server-side include
// for another page.
// (Such as an intranet home page or something.)
// As such, no login is required.  Instead, the login id is either
// passed in the URL "week_ssi.php?login=cknudsen".  Unless, of course,
// we are in single-user mode, where no login info is needed.
// If no login info is passed, we check for the last login used.

$user = "__none__"; // don't let user specify in URL

if ( strlen ( $login ) == 0 ) {
  if ( $single_user == "Y" ) {
    $login = $user = $single_user_login;
  } else if ( strlen ( $webcalendar_login ) > 0 ) {
    $login = $user = $webcalendar_login;
  } else {
    echo "<FONT COLOR=\"#FF0000\"><B>Error:</B> No calendar user specified.</FONT>";
    exit;
  }
}

include "includes/config.php";
include "includes/php-dbi.php";
include "includes/functions.php";
include "includes/$user_inc";
include "includes/connect.php";

load_global_settings ();
load_user_preferences ();
load_user_layers ();

$view = "week";

include "includes/translate.php";


if ( strlen ( $date ) > 0 ) {
  $thisyear = $year = substr ( $date, 0, 4 );
  $thismonth = $month = substr ( $date, 4, 2 );
  $thisday = $day = substr ( $date, 6, 2 );
} else {
  if ( $month == 0 )
    $thismonth = date("m");
  else
    $thismonth = $month;
  if ( $year == 0 )
    $thisyear = date("Y");
  else
    $thisyear = $year;
  if ( $day == 0 )
    $thisday = date("d");
  else
    $thisday = $day;
}

$next = mktime ( 3, 0, 0, $thismonth, $thisday + 7, $thisyear );
$prev = mktime ( 3, 0, 0, $thismonth, $thisday - 7, $thisyear );

$today = mktime ( 3, 0, 0, date ( "m" ), date ( "d" ), date ( "Y" ) );

// We add 2 hours on to the time so that the switch to DST doesn't
// throw us off.  So, all our dates are 2AM for that day.
if ( $WEEK_START == 1 )
  $wkstart = get_monday_before ( $thisyear, $thismonth, $thisday );
else
  $wkstart = get_sunday_before ( $thisyear, $thismonth, $thisday );
$wkend = $wkstart + ( 3600 * 24 * 6 );
$startdate = date ( "Ymd", $wkstart );
$enddate = date ( "Ymd", $wkend );

/* Pre-Load the repeated events for quckier access */
$repeated_events = read_repeated_events ( $login );

/* Pre-load the non-repeating events for quicker access */
$events = read_events ( $login, $startdate, $enddate );

for ( $i = 0; $i < 7; $i++ ) {
  $days[$i] = $wkstart + ( 24 * 3600 ) * $i;
  $weekdays[$i] = weekday_short_name ( ( $i + $WEEK_START ) % 7 );
  $header[$i] = $weekdays[$i] . "<BR>" .
     month_short_name ( date ( "m", $days[$i] ) - 1 ) .
     " " . date ( "d", $days[$i] );
}

?>


<TABLE BORDER="0" WIDTH="100%" CELLSPACING="0" CELLPADDING="0">
<TR><TD BGCOLOR="<?php echo $TABLEBG?>">
<TABLE BORDER="0" WIDTH="100%" CELLSPACING="1" CELLPADDING="2" BORDER="0">

<TR>
<?php
for ( $d = 0; $d < 7; $d++ ) {
  if ( date ( "Ymd", $days[$d] ) == date ( "Ymd", $today ) )
    $color = $TODAYCELLBG;
  else
    $color = $THBG;
  echo "<TH WIDTH=\"13%\" BGCOLOR=\"$color\">$header[$d]</TH>";
}
?>
</TR>

<TR>

<?php

$first_hour = $WORK_DAY_START_HOUR - $TZ_OFFSET;
$last_hour = $WORK_DAY_END_HOUR + $TZ_OFFSET;
$untimed_found = false;
for ( $d = 0; $d < 7; $d++ ) {
  $date = date ( "Ymd", $days[$d] );

  print "<TD VALIGN=\"top\" WIDTH=75 HEIGHT=75 ";
  if ( $date == date ( "Ymd" ) )
    echo "BGCOLOR=\"$TODAYCELLBG\">";
  else
    echo "BGCOLOR=\"$CELLBG\">";

  print_date_entries ( $date, $login, true, true );
  echo "&nbsp;";
  echo "</TD>\n";
}
?>
</TR>
</TABLE>
</TD></TR></TABLE>

