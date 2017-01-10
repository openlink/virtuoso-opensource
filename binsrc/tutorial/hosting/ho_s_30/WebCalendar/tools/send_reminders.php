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
#!/usr/local/bin/php -q
<?php
// This script should be setup to run periodically on your system.
// You could run it once every minute, but every 5-15 minutes should be
// sufficient.
//
// To set this up in cron, add a line like the following in your crontab
// to run it every 10 minutes:
//   1,11,21,31,41,51 * * * * /some/patch/here/send_reminders.ph
// (of course change the path to where this script lives!)
// On Linux, just type crontab -e to edit your crontab.
//
// If you're a Windows user, you'll either need to find a cron clone
// for Windows (they're out there) or come up with another creative
// solution.
// 
// You will need PHP build as a CGI (rather than an Apache module) for
// this script to work.  I install PHP as an Apache module and then
// build the CGI version later (without Apache).  The module version
// of PHP is preferred for use in a web server.

// How many days in advance can a reminder be sent (max)
// this will affect performance, but keep in mind that someone may enter
// a reminder to be sent 60 days in advance or they may enter a specific
// date for a reminder to be sent that is more than 30 days before the
// event's date.  If you're only running this once an hour or less often,
// then you could certainly change this to look a whole 365 days ahead.
$DAYS_IN_ADVANCE = 30;
//$DAYS_IN_ADVANCE = 365;


// Load include files.
// If you have moved this script out of the WebCalendar directory,
// which you probably should do since it would be better for security
// reasons, you would need to change $includedir to point to the
// webcalendar include directory.
$basedir = ".."; // points to the base WebCalendar directory relative to
                 // current working directory
$includedir = "../includes";

include "$includedir/config.php";
include "$includedir/php-dbi.php";
include "$includedir/functions.php";
include "$includedir/$user_inc";
include "$includedir/site_extras.php";

$debug = false; // set to true to print debug info...
$only_testing = false; // act like we're sending, but don't send -- for debugging

// Establish a database connection.
$c = dbi_connect ( $db_host, $db_login, $db_password, $db_database );
if ( ! $c ) {
  echo "Error connecting to database: " . dbi_error ();
  exit;
}

load_global_settings ();

include "$includedir/translate.php";

if ( $debug )
  echo "<br>\n";

// Get a list of people who have asked not to receive email
$res = dbi_query ( "SELECT cal_login FROM webcal_user_pref " .
  "WHERE cal_setting = 'EMAIL_REMINDER' " .
  "AND cal_value = 'N'" );
$noemail = array ();
if ( $res ) {
  while ( $row = dbi_fetch_row ( $res ) ) {
    $user = $row[0];
    $noemail[$user] = 1;
    if ( $debug )
      echo "User $user does not want email. <br>\n";
  }
  dbi_free_result ( $res );
}

// Get a list of the email users in the system.
// They must also have an email address.  Otherwise, we can't
// send them mail, so what's the point?
$allusers = user_get_users ();
for ( $i = 0; $i < count ( $allusers ); $i++ ) {
  $names[$allusers[$i]['cal_login']] = $allusers[$i]['cal_fullname'];
  $emails[$allusers[$i]['cal_login']] = $allusers[$i]['cal_email'];
}


// Get all users language settings.
$res = dbi_query ( "SELECT cal_login, cal_value FROM webcal_user_pref " .
  "WHERE cal_setting = 'LANGUAGE'" );
$languages = array ();
if ( $res ) {
  while ( $row = dbi_fetch_row ( $res ) ) {
    $user = $row[0];
    $user_lang = $row[1];
    $languages[$user] = $user_lang;
    if ( $debug )
      echo "Language for $user is \"$user_lang\" <br>\n";
  }
  dbi_free_result ( $res );
}

// Get all users timezone settings.
$res = dbi_query ( "SELECT cal_login, cal_value FROM webcal_user_pref " .
  "WHERE cal_setting = 'TZ_OFFSET'" );
$tzoffset = array ();
if ( $res ) {
  while ( $row = dbi_fetch_row ( $res ) ) {
    $user = $row[0];
    $user_tzoffset = $row[1];
    $tzoffset[$user] = $user_tzoffset;
    if ( $debug )
      echo "TZ OFFSET for $user is \"$user_tzoffset\" <br>\n";
  }
  dbi_free_result ( $res );
}

// Now read events all the repeating events (for all users)
$repeated_events = read_repeated_events ( "" );

// Read non-repeating events (for all users)
$startdate = date ( "Ymd" );
$enddate = date ( "Ymd", time() + ( $DAYS_IN_ADVANCE * 24 * 3600 ) );
if ( $debug )
  echo "Checking for events from date $startdate to date $enddate <br>\n";
$events = read_events ( "", $startdate, $enddate );
if ( $debug )
  echo "Found " . count ( $events ) . " events in time range. <br>\n";


function indent ( $str ) {
  return "  " . str_replace ( "\n", "\n  ", $str );
}


// Send a reminder for a single event for a single day to all
// participants in the event.
// Send to participants who have accepted as well as those who have not yet
// approved.  But, don't send to users how rejected (cal_status='R').
function send_reminder ( $id, $event_date ) {
  global $names, $emails, $site_extras, $debug, $only_testing,
    $server_url, $languages, $tzoffset, $application_name;
  global $EXTRA_TEXT, $EXTRA_MULTILINETEXT, $EXTRA_URL, $EXTRA_DATE,
    $EXTRA_EMAIL, $EXTRA_USER, $EXTRA_REMINDER, $LANGUAGE, $LOG_REMINDER;

  $pri[1] = translate("Low");
  $pri[2] = translate("Medium");
  $pri[3] = translate("High");

  // get participants first...
 
  $sql = "SELECT cal_login FROM webcal_entry_user " .
    "WHERE cal_id = $id AND cal_status IN ('A','W') " .
    "ORDER BY cal_login";
  $res = dbi_query ( $sql );
  $participants = array ();
  $num_participants = 0;
  if ( $res ) {
    while ( $row = dbi_fetch_row ( $res ) ) {
      $participants[$num_participants++] = $row[0];
    }
  }

  // get external participants
  $ext_participants = array ();
  $num_ext_participants = 0;
  if ( ! empty ( $allow_external_users ) && $allow_external_users == "Y" &&
    ! empty ( $external_reminders ) && $external_reminders == "Y" ) {
    $sql = "SELECT cal_fullname, cal_email FROM webcal_entry_ext_user " .
      "WHERE cal_id = $id AND cal_email NOT NULL " .
      "ORDER BY cal_fullname";
    $res = dbi_query ( $sql );
    if ( $res ) {
      while ( $row = dbi_fetch_row ( $res ) ) {
        $ext_participants[$num_ext_participants] = $row[0];
        $ext_participants_email[$num_ext_participants++] = $row[1];
      }
    }
  }

  if ( ! $num_participants && ! $num_ext_participants ) {
    if ( $debug )
      echo "No participants found for event id: $id <br>\n";
    return;
  }


  // get event details
  $res = dbi_query (
    "SELECT cal_create_by, cal_date, cal_time, cal_mod_date, " .
    "cal_mod_time, cal_duration, cal_priority, cal_type, cal_access, " .
    "cal_name, cal_description FROM webcal_entry WHERE cal_id = $id" );
  if ( ! $res ) {
    echo "Db error: could not find event id $id.\n";
    return;
  }


  if ( ! ( $row = dbi_fetch_row ( $res ) ) ) {
    echo "Error: could not find event id $id in database.\n";
    return;
  }

  // send mail.  we send one user at a time so that we can switch
  // languages between users if needed.
  $mailusers = array ();
  $recipients = array ();
  if ( $single_user == "Y" ) {
    $mailusers[] = $emails[$single_user_login];
    $recipients[] = $single_user_login;
  } else {
    for ( $i = 0; $i < count ( $participants ); $i++ ) {
      if ( strlen ( $emails[$participants[$i]] ) ) {
        $mailusers[] = $emails[$participants[$i]];
        $recipients[] = $participants[$i];
      } else {
        if ( $debug )
	  echo "No email for user $participants[$i] <br>\n";
      }
    }
    for ( $i = 0; $i < count ( $ext_participants ); $i++ ) {
      $mailusers[] = $ext_participants_email[$i];
      $recipients[] = $ext_participants[$i];
    }
  }
  if ( $debug )
    echo "Found " . count ( $mailusers ) . " with email addresses <br>\n";
  for ( $j = 0; $j < count ( $mailusers ); $j++ ) {
    $recip = $mailusers[$j];
    $user = $participants[$j];
    if ( ! empty ( $languages[$user] ) )
      $userlang = $languages[$user];
    else
      $userlang = $LANGUAGE; // system default
    if ( $userlang == "none" )
      $userlang = "English-US"; // gotta pick something
    if ( $debug )
      echo "Setting language to \"$userlang\" <br>\n";
    reset_language ( $userlang );
    // reset timezone setting for current user
    if ( empty ( $tzoffset[$user] ) )
      $GLOBALS["TZ_OFFSET"] = 0;
    else
      $GLOBALS["TZ_OFFSET"] = $tzoffset[$user];

    $body = translate("This is a reminder for the event detailed below.") .
      "\n\n";

    $create_by = $row[0];
    $name = $row[9];
    $description = $row[10];

    if ( ! empty ( $server_url ) )
      $body .= $server_url . "view_entry.php?id=" . $id . "\n\n";

    $body .= strtoupper ( $name ) . "\n\n";
    $body .= translate("Description") . ":\n";
    $body .= indent ( $description ) . "\n";
    $body .= translate("Date") . ": " . date_to_str ( $row[1] ) . "\n";
    if ( $row[2] >= 0 )
      $body .= translate ("Time") . ": " . display_time ( $row[2] ) . "\n";
    if ( $row[5] > 0 )
      $body .= translate ("Duration") . ": " . $row[5] .
        " " . translate("minutes") . "\n";
    if ( ! $disable_priority_field )
      $body .= translate("Priority") . ": " . $pri[$row[6]] . "\n";
    if ( ! $disable_access_field )
      $body .= translate("Access") . ": " .
        ( $row[8] == "P" ? translate("Public") : translate("Confidential") ) .
        "\n";
    if ( ! strlen ( $single_user_login ) )
      $body .= translate("Created by") . ": " . $row[0] . "\n";
    $body .= translate("Updated") . ": " . date_to_str ( $row[3] ) . " " .
      display_time ( $row[4] ) . "\n";

    // site extra fields
    $extras = get_site_extra_fields ( $id );
    for ( $i = 0; $i < count ( $site_extras ); $i++ ) {
      $extra_name = $site_extras[$i][0];
      $extra_descr = $site_extras[$i][1];
      $extra_type = $site_extras[$i][2];
      if ( $extras[$extra_name]['cal_name'] != "" ) {
        $body .= translate ( $extra_descr ) . ": ";
        if ( $extra_type == $EXTRA_DATE ) {
          $body .= date_to_str ( $extras[$extra_name]['cal_date'] ) . "\n";
        } else if ( $extra_type == $EXTRA_MULTILINETEXT ) {
          $body .= "\n" . indent ( $extras[$extra_name]['cal_data'] ) . "\n";
        } else if ( $extra_type == $EXTRA_REMINDER ) {
          $body .= ( $extras[$extra_name]['cal_remind'] > 0 ?
            translate("Yes") : translate("No") ) . "\n";
        } else {
          // default method for $EXTRA_URL, $EXTRA_TEXT, etc...
          $body .= $extras[$extra_name]['cal_data'] . "\n";
        }
      }
    }
    if ( $single_user != "Y" && ! $disable_participants_field ) {
      $body .= translate("Participants") . ":\n";
      for ( $i = 0; $i < count ( $participants ); $i++ ) {
        $body .= "  " . $names[$participants[$i]] . "\n";
      }
      for ( $i = 0; $i < count ( $ext_participants ); $i++ ) {
        $body .= "  " . $ext_participants[$i] . " (" .
          translate("External User") . ")\n";
      }
    }
  
    $subject = translate("Reminder") . ": " . $name;

    if ( strlen ( $GLOBALS["email_fallback_from"] ) )
      $extra_hdrs = "From: " . $GLOBALS["email_fallback_from"] . "\n" .
        "X-Mailer: " . translate($application_name);
    else
      $extra_hdrs = "X-Mailer: " . translate($application_name);
  
    if ( $debug )
      echo "Sending mail to $recip (in $userlang)\n";
    if ( $only_testing ) {
      if ( $debug )
        echo "<HR><PRE>To: $recip\nSubject: $subject\n$extra_hdrs\n\n$body\n\n</PRE>\n";
    } else {
      mail ( $recip, $subject, $body, $extra_hdrs );
      activity_log ( $id, "system", $user, $LOG_REMINDER, "" );
    }
  }
}


// keep track of the fact that we send the reminder, so we don't
// do it again.
function log_reminder ( $id, $name, $event_date ) {
  global $only_testing;

  if ( ! $only_testing ) {
    dbi_query ( "DELETE FROM webcal_reminder_log " .
      "WHERE cal_id = $id AND cal_name = '$name' " .
      "AND cal_event_date = $event_date" );
    dbi_query ( "INSERT INTO webcal_reminder_log " .
      "( cal_id, cal_name, cal_event_date, cal_last_sent ) VALUES ( " .
      "$id, '" . $name . "', $event_date, " . time() . ")" );
  }
}


// Process an event for a single day.  Check to see if it has
// a reminder, when it needs to be sent and when the last time it
// was sent.
function process_event ( $id, $name, $event_date, $event_time ) {
  global $site_extras, $debug, $only_testing;
  global $EXTRA_REMINDER_WITH_OFFSET, $EXTRA_REMINDER_WITH_DATE;

  if ( $debug )
    printf ( "Event %d: \"%s\" at %s on %s <br>\n",
      $id, $name, $event_time, $event_date );

  // Check to see if this event has any reminders
  $extras = get_site_extra_fields ( $id );
  for ( $j = 0; $j < count ( $site_extras ); $j++ ) {
    $extra_name = $site_extras[$j][0];
    $extra_type = $site_extras[$j][2];
    $extra_arg1 = $site_extras[$j][3];
    $extra_arg2 = $site_extras[$j][4];
    //if ( $debug )
    //  printf ( "  name: %s\n  type: %d\n  arg1: %s\n  arg2: %s\n",
    //  $extra_name, $extra_type, $extra_arg1, $extra_arg2 );
    if ( ! empty ( $extras[$extra_name]['cal_remind'] ) ) {
      if ( $debug )
        echo "  Reminder set for event. <br>\n";
      // how many minutes before event should we send the reminder?
      $ev_h = (int) ( $event_time / 10000 );
      $ev_m = ( $event_time / 100 ) % 100;
      $ev_year = substr ( $event_date, 0, 4 );
      $ev_month = substr ( $event_date, 4, 2 );
      $ev_day = substr ( $event_date, 6, 2 );
      $event_time = mktime ( $ev_h, $ev_m, 0, $ev_month, $ev_day, $ev_year );
      if ( ( $extra_arg2 & $EXTRA_REMINDER_WITH_OFFSET ) > 0 ) {
        $minsbefore = $extras[$extra_name]['cal_data'];
        $remind_time = $event_time - ( $minsbefore * 60 );
      } else if ( ( $extra_arg2 & $EXTRA_REMINDER_WITH_DATE ) > 0 ) {
        $rd = $extras[$extra_name]['cal_date'];
        $r_year = substr ( $rd, 0, 4 );
        $r_month = substr ( $rd, 4, 2 );
        $r_day = substr ( $rd, 6, 2 );
        $remind_time = mktime ( 0, 0, 0, $r_month, $r_day, $r_year );
      } else {
        $minsbefore = $extra_arg1;
        $remind_time = $event_time - ( $minsbefore * 60 );
      }
      if ( $debug )
        echo "  Mins Before: $minsbefore <br>\n";
      if ( $debug ) {
        echo "  Event time is: " . date ( "m/d/Y H:i", $event_time ) . "<br>\n";
        echo "  Remind time is: " . date ( "m/d/Y H:i", $remind_time ) . "<br>\n";
      }
      if ( time() > $remind_time ) {
        // It's later than the remind time.  See if one has already been sent
        $last_sent = 0;
        $res = dbi_query ( "SELECT MAX(cal_last_sent) FROM " .
          "webcal_reminder_log WHERE cal_id = " . $id .
          " AND cal_event_date = $event_date" .
          " AND cal_name = '" . $extra_name . "'" );
        if ( $res ) {
          if ( $row = dbi_fetch_row ( $res ) ) {
            $last_sent = $row[0];
          }
          dbi_free_result ( $res );
        }
        if ( $debug )
          echo "  Last sent on: " . date ( "m/d/Y H:i", $last_sent ) . "<br>\n";
        if ( $last_sent < $remind_time ) {
          // Send a reminder
          if ( $debug )
            echo "  SENDING REMINDER! <br>\n";
          send_reminder ( $id, $event_date );
          // now update the db...
          log_reminder ( $id, $extra_name, $event_date );
        }
      }
    }
  }
}


$startdate = time(); // today
for ( $d = 0; $d < $DAYS_IN_ADVANCE; $d++ ) {
  $date = date ( "Ymd", time() + ( $d * 24 * 3600 ) );
  //echo "Date: $date\n";
  // Get non-repeating events for this date.
  // An event will be included one time for each participant.
  $ev = get_entries ( "", $date );
  // Keep track of duplicates
  $completed_ids = array ( );
  for ( $i = 0; $i < count ( $ev ); $i++ ) {
    $id = $ev[$i]['cal_id'];
    if ( ! empty ( $completed_ids[$id] ) )
      continue;
    $completed_ids[$id] = 1;
    process_event ( $id, $ev[$i]['cal_name'], $date, $ev[$i]['cal_time'] );
  }
  $rep = get_repeating_entries ( "", $date );
  for ( $i = 0; $i < count ( $rep ); $i++ ) {
    $id = $rep[$i]['cal_id'];
    if ( ! empty ( $completed_ids[$id] ) )
      continue;
    $completed_ids[$id] = 1;
    process_event ( $id, $rep[$i]['cal_name'], $date, $rep[$i]['cal_time'] );
  }
}

if ( $debug )
  echo "Done.<br>\n";

?>
