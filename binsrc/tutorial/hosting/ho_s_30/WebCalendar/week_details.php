<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2014 OpenLink Software
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

$view = "week_details";

include "includes/translate.php";

if ( ( $allow_view_other != "Y" && ! $is_admin ) || empty ( $user ) ) $user = "";

if ( ! empty ( $friendly ) )
  $hide_icons = true;
else
  $hide_icons = false;

if ( strlen ( $user ) ) {
  $u_url = "user=$user&";
  user_load_variables ( $user, "user_" );
} else {
  $u_url = "";
  $user_fullname = $fullname;
}

$can_add = ( $readonly == "N" || $is_admin == "Y" );
if ( $public_access == "Y" && $public_access_can_add != "Y" &&
  $login == "__public__" )
  $can_add = false;

if ( $categories_enabled == "Y" && (!$user || $user == $login)) {
  if (isset ($cat_id)) {
    $cat_id = $cat_id;
  } elseif (isset ($CATEGORY_VIEW)) {
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

$next = mktime ( 2, 0, 0, $thismonth, $thisday + 7, $thisyear );
$prev = mktime ( 2, 0, 0, $thismonth, $thisday - 7, $thisyear );

$today = mktime ( 2, 0, 0, date ( "m" ), date ( "d" ), date ( "Y" ) );

// We add 2 hours on to the time so that the switch to DST doesn't
// throw us off.  So, all our dates are 2AM for that day.
if ( $WEEK_START == 1 )
  $wkstart = get_monday_before ( $thisyear, $thismonth, $thisday );
else
  $wkstart = get_sunday_before ( $thisyear, $thismonth, $thisday );
$wkend = $wkstart + ( 3600 * 24 * 6 );
$startdate = date ( "Ymd", $wkstart );
$enddate = date ( "Ymd", $wkend );

?>
<html>
<head>
<title><?php etranslate("Title")?></title>
<?php include "includes/styles.php"; ?>
<?php include "includes/js.php"; ?>
<?php
if ( $auto_refresh == "Y" && ! empty ( $auto_refresh_time ) ) {
  $refresh = $auto_refresh_time * 60; // convert to seconds
  echo "<META HTTP-EQUIV=\"refresh\" content=\"$refresh; URL=week_details.php?$u_url" .
    "date=$startdate$caturl\" TARGET=\"_self\">\n";
}
?>
</head>
<body bgcolor=<?php echo "\"$BGCOLOR\"";?> class="defaulttext">
<center>

<table border="0" width="100%">
<TR>
<?php if ( empty ( $friendly ) || ! $friendly ) { ?>
<td align="left"><a href="week_details.php?<?php echo $u_url; ?>date=<?php echo date("Ymd", $prev ) . $caturl;?>"><img src="leftarrow.gif" width="36" height="32" border=\"0\"></a></td>
<?php } ?>
<td align="middle"><font size="+2" color="<?php echo $H2COLOR;?>"><B>
<?php
  echo date_to_str ( date ( "Ymd", $wkstart ), false ) .
    "&nbsp;&nbsp;&nbsp; - &nbsp;&nbsp;&nbsp;" .
    date_to_str ( date ( "Ymd", $wkend ), false );
  /*
  if ( date ( "m", $wkstart ) == date ( "m", $wkend ) ) {
    printf ( "%s %d - %d, %d", month_name ( $thismonth - 1 ),
      date ( "d", $wkstart ), date ( "d", $wkend ), $thisyear );
  } else {
    if ( date ( "Y", $wkstart ) == date ( "Y", $wkend ) ) {
      printf ( "%s %d - %s %d, %d",
        month_name ( date ( "m", $wkstart ) - 1 ), date ( "d", $wkstart ),
        month_name ( date ( "m", $wkend ) - 1 ), date ( "d", $wkend ),
        $thisyear );
    } else {
      printf ( "%s %d, %d - %s %d, %d",
        month_name ( date ( "m", $wkstart ) - 1 ), date ( "d", $wkstart ),
        date ( "Y", $wkstart ),
        month_name ( date ( "m", $wkend ) - 1 ), date ( "d", $wkend ),
        date ( "Y", $wkend ) );
    }
  }
  */
?>
</b></font>
<?php
if ( $GLOBALS["DISPLAY_WEEKNUMBER"] == "Y" ) {
  echo "<br>\n<font size=\"-2\" color=\"$H2COLOR\">(" .
    translate("Week") . " " . week_number ( $wkstart ) . ")</font>";
}
?>
<font size="+1" color="<?php echo $H2COLOR;?>">
<?php
  if ( $single_user == "N" ) {
    echo "<br>$user_fullname\n";
  }
  if ( $categories_enabled == "Y" ) {
    echo "<br>\n<br>\n";
    print_category_menu('week', sprintf ( "%04d%02d%02d",$thisyear, $thismonth, $thisday ), $cat_id, $friendly );
  }
?>
</font>
</td>
<?php if ( empty ( $friendly ) || ! $friendly ) { ?>
<td align="right"><a href="week_details.php?<?php echo $u_url;?>date=<?php echo date ("Ymd", $next ) . $caturl;?>"><img src="rightarrow.gif" width="36" height="32" border="0"></a></td>
<?php } ?>
</tr>
</table>


<?php 

/* Pre-Load the repeated events for quckier access */
$repeated_events = read_repeated_events ( strlen ( $user ) ? $user : $login, $cat_id  );

/* Pre-load the non-repeating events for quicker access */
$events = read_events ( strlen ( $user ) ? $user : $login, $startdate, $enddate, $cat_id  );

for ( $i = 0; $i < 7; $i++ ) {
  $days[$i] = $wkstart + ( 24 * 3600 ) * $i;
  $weekdays[$i] = weekday_short_name ( ( $i + $WEEK_START ) % 7 );
  $header[$i] = date_to_str ( date ( "Ymd", $days[$i] ) );
}

?>

<table border="0" width="90%" cellspacing="0" cellpadding="0">
<tr><td bgcolor="<?php echo $TABLEBG?>">
<table border="0" width="100%" cellspacing="1" cellpadding="2" border="0">

<?php

$untimed_found = false;
for ( $d = 0; $d < 7; $d++ ) {
  $date = date ( "Ymd", $days[$d] );
  $thiswday = date ( "w", $days[$d] );
  $is_weekend = ( $thiswday == 0 || $thiswday == 6 );
  if ( $date == date ( "Ymd", $today ) ) {
    $hcolor = $THBG;
    $hclass = "tableheadertoday";
    $color = $TODAYCELLBG;
  } else if ( $is_weekend ) {
    $hcolor = $THBG;
    $hclass = "tableheader";
    $color = $WEEKENDBG;
  } else {
    $hcolor = $THBG;
    $hclass = "tableheader";
    $color = $CELLBG;
  }

  echo "<tr><th width=\"100%\" bgcolor=\"$hcolor\" class=\"$hclass\">";
  if ( empty ( $friendly ) && $can_add ) {
    echo "<a href=\"edit_entry.php?" . $u_url .
      "date=" . date ( "Ymd", $days[$d] ) . "\">" .
      "<img src=\"new.gif\" width=\"10\" height=\"10\" alt=\"" .
      translate("New Entry") . "\" border=\"0\" align=\"right\">" .  "</a>";
  }
  echo "<a href=\"day.php?" . $u_url .
    "date=" . date("Ymd", $days[$d] ) . "$caturl\" class=\"$hclass\">" .
    $header[$d] . "</a></th></tr>";

  print "<tr><td valign=\"top\" height=\"75\" ";
  if ( $date == date ( "Ymd" ) )
    echo "bgcolor=\"$color\">";
  else
    echo "bgcolor=\"$color\">";

  print_det_date_entries ( $date, $user, $hide_icons, true );
  echo "&nbsp;";
  echo "</td></tr>\n";
}
?>

</tr>
</table>
</td></tr></table></center>

<?php if ( empty ( $friendly ) ) { ?>
<?php echo $eventinfo; ?>
<P>
<A CLASS="navlinks" HREF="week_details.php?<?php
  echo $u_url;
  if ( $thisyear ) {
    echo "year=$thisyear&month=$thismonth&day=$thisday";
  }
  echo $caturl . "&";
?>friendly=1" TARGET="cal_printer_friendly"
onMouseOver="window.status = '<?php etranslate("Generate printer-friendly version")?>'">[<?php etranslate("Printer Friendly")?>]</A>


<?php include "includes/trailer.php"; ?>

<?php } else {
        dbi_close ( $c );
      }
?>

</body>
</html>

<?php


// Print the HTML for one day's events in detailed view.
// params:
//   $id - event id
//   $date - date (not used)
//   $time - time (in HHMMSS format)
//   $name - event name
//   $description - long description of event
//   $status - event status
//   $pri - event priority
//   $access - event access
//   $event_owner - user associated with this event
//   $hide_icons - hide icons to make printer-friendly
function print_detailed_entry ( $id, $date, $time, $duration,
  $name, $description, $status,
  $pri, $access, $event_owner, $hide_icons ) {
  global $eventinfo, $login, $user, $TZ_OFFSET;
  static $key = 0;

  global $layers;


  #echo "<font size=\"-1\">";

  if ( $login != $event_owner && strlen ( $event_owner ) ) {
    $class = "layerentry";
  } else {
    $class = "entry";
    if ( $status == "W" ) $class = "unapprovedentry";
  }

  if ( $pri == 3 ) echo "<b>";
  if ( ! $hide_icons ) {
    $divname = "eventinfo-$id-$key";
    $key++;
    echo "<a class=\"$class\" href=\"view_entry.php?id=$id&date=$date";
    if ( strlen ( $user ) > 0 )
      echo "&user=" . $user;
    echo "\" onMouseOver=\"window.status='" . translate("View this entry") .
      "'; return true;\" onMouseOut=\"window.status=''; return true;\">";
    echo "<img src=\"circle.gif\" width=\"5\" height=\"7\" alt=\"view icon\" border=\"0\"> ";
  }


  if ( $login != $event_owner && strlen ( $event_owner ) ) {
    for($index = 0; $index < sizeof($layers); $index++) {
      if($layers[$index]['cal_layeruser'] == $event_owner) {
        echo("<font color=\"" . $layers[$index]['cal_color'] . "\">");
      }
    }
  }


  $timestr = "";
  $my_time = $time + ( $TZ_OFFSET * 10000 );
  if ( $time >= 0 ) {
    if ( $GLOBALS["TIME_FORMAT"] == "24" ) {
      printf ( "%02d:%02d", $my_time / 10000, ( $my_time / 100 ) % 100 );
    } else {
      $h = ( (int) ( $my_time / 10000 ) ) % 12;
      if ( $h == 0 ) $h = 12;
      echo $h;
      $m = ( $my_time / 100 ) % 100;
      if ( $m > 0 )
        printf ( ":%02d", $m );
      else
        print (":00");
      echo ( (int) ( $my_time / 10000 ) ) < 12 ? translate("am") : translate("pm");
    }
    //echo "&gt;";
    $timestr = display_time ( $time );
    if ( $duration > 0 ) {
      // calc end time
      $h = (int) ( $time / 10000 );
      $m = ( $time / 100 ) % 100;
      $m += $duration;
      $d = $duration;
      while ( $m >= 60 ) {
        $h++;
        $m -= 60;
      }
      $end_time = sprintf ( "%02d%02d00", $h, $m );
      $timestr .= " - " . display_time ( $end_time );
      echo " - " .display_time ( $end_time ). " ";
    }
  }
  if ( $login != $user && $access == 'R' && strlen ( $user ) ) {
    $PN = "(" . translate("Private") . ")"; $PD = "(" . translate("Private") . ")";
  } elseif ( $login != $event_owner && $access == 'R' && strlen ( $event_owner ) ) {
    $PN = "(" . translate("Private") . ")";$PD ="(" . translate("Private") . ")";
  } elseif ( $login != $event_owner && strlen ( $event_owner ) ) {
    $PN = htmlspecialchars ( $name ) ."</font>";
    $PD = activate_urls ( htmlspecialchars ( $description ) );
  } else {
    $PN = htmlspecialchars ( $name );
    $PD = activate_urls ( htmlspecialchars ( $description ) );
  }
  echo $PN;
  echo "</a>";
  if ( $pri == 3 ) echo "</b>";
  # Only display description if it is different than the event name.
  if ( $PN != $PD )
    echo " - " . $PD;
  echo "</font><br><br>";

}

//
// Print all the calendar entries for the specified user for the
// specified date.  If we are displaying data from someone other than
// the logged in user, then check the access permission of the entry.
// params:
//   $date - date in YYYYMMDD format
//   $user - username
//   $hide_icons - hide icons to make printer-friendly
//   $is_ssi - is this being called from week_ssi.php?
function print_det_date_entries ( $date, $user, $hide_icons, $ssi ) {
  global $events, $readonly, $is_admin;

  $year = substr ( $date, 0, 4 );
  $month = substr ( $date, 4, 2 );
  $day = substr ( $date, 6, 2 );

  $dateu = mktime ( 2, 0, 0, $month, $day, $year );


  // get all the repeating events for this date and store in array $rep
  $rep = get_repeating_entries ( $user, $date );
  $cur_rep = 0;

  // get all the non-repeating events for this date and store in $ev
  $ev = get_entries ( $user, $date );

  for ( $i = 0; $i < count ( $ev ); $i++ ) {
    // print out any repeating events that are before this one...
    while ( $cur_rep < count ( $rep ) &&
      $rep[$cur_rep]['cal_time'] < $ev[$i]['cal_time'] ) {
      if ( $GLOBALS["DISPLAY_UNAPPROVED"] != "N" ||
        $rep[$cur_rep]['cal_status'] == 'A' )
        print_detailed_entry ( $rep[$cur_rep]['cal_id'],
          $date, $rep[$cur_rep]['cal_time'], $rep[$cur_rep]['cal_duration'],
          $rep[$cur_rep]['cal_name'], $rep[$cur_rep]['cal_description'],
          $rep[$cur_rep]['cal_status'], $rep[$cur_rep]['cal_priority'],
          $rep[$cur_rep]['cal_access'], $rep[$cur_rep]['cal_login'],
          $hide_icons );
      $cur_rep++;
    }
    if ( $GLOBALS["DISPLAY_UNAPPROVED"] != "N" ||
      $ev[$i]['cal_status'] == 'A' )
      print_detailed_entry ( $ev[$i]['cal_id'],
        $date, $ev[$i]['cal_time'], $ev[$i]['cal_duration'],
        $ev[$i]['cal_name'], $ev[$i]['cal_description'],
        $ev[$i]['cal_status'], $ev[$i]['cal_priority'],
        $ev[$i]['cal_access'], $ev[$i]['cal_login'], $hide_icons );
  }
  // print out any remaining repeating events
  while ( $cur_rep < count ( $rep ) ) {
    if ( $GLOBALS["DISPLAY_UNAPPROVED"] != "N" ||
      $rep[$cur_rep]['cal_status'] == 'A' )
      print_detailed_entry ( $rep[$cur_rep]['cal_id'],
        $date, $rep[$cur_rep]['cal_time'], $rep[$cur_rep]['cal_duration'],
        $rep[$cur_rep]['cal_name'], $rep[$cur_rep]['cal_description'],
        $rep[$cur_rep]['cal_status'], $rep[$cur_rep]['cal_priority'],
        $rep[$cur_rep]['cal_access'], $rep[$cur_rep]['cal_login'],
        $hide_icons );
    $cur_rep++;
  }
}
?>
