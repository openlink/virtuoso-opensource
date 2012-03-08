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

// Site-specific settings.
// Configure these for your site.
// You shouldn't have to modify any files outside of this one.
// When you're done here, try accessing WebCalendar as an admin
// user and go to the System Settings page (admin.php) to change system
// settings.
//
// Note: if you enable LDAP support, you will also need to modify
// user-ldap.php.
//
/////////////////////////////////////////////////////////////////

$PROGRAM_NAME = "WebCalendar v0.9.40 (30 Nov 2002)";
$PROGRAM_URL = "http://webcalendar.sourceforge.net/";

// MySQL example
// $db_type = "mysql";
// $db_host = "localhost";
// $db_login = "webcalendar";
// $db_password = "webcal01";
// $db_database = "intranet";

// Oracle example
//$db_type = "oracle";
//$db_host = ""; // use localhost
//$db_login = "webcalendar";
//$db_password = "webcal01";
// for oracle, db_database should be the name in tnsnames.ora
//$db_database = "orcl";

// Postgres example
//$db_type = "postgresql";
//$db_host = "localhost";
//$db_login = "webcalendar";
//$db_password = "webcalendar";
//$db_database = "webcalendar";

// ODBC example
$db_type = "odbc";
$db_host = ""; // not used for odbc
$db_login = "WebCal";
$db_password = "WebCal";
// for oracle, db_database should be the name in tnsnames.ora
$db_database = "Local Virtuoso Tutorial HO-S-30"; // this is the ODBC DSN

// Interbase example
//$db_type = "ibase";
//$db_host = "localhost:/opt/webcal/WEBCAL.gdb";
//$db_login = "sysdba";
//$db_password = "masterkey";
//$db_database = "WEBCAL.gdb";


// Read-only mode: You can set this to true to create a read-only calendar.
// If you enable $single_user_login (below), no login will be required,
// making this a publicly viewable calendar.  In order to add events to
// a setup like this, you will need to setup another installation of this
// application that is not read-only.
// If $readonly is enabled in multi-user mode, only admin users will able
// to add/edit/delete events.
// NOTE: Approvals are not disabled in read-only.  You must also disable
// approvals if you don't want to use them.
// NOTE #2: Using $readonly has mostly been superceded by the new public
// access calendar (added in version 0.9.35).  The new system allows
// a public access calendar with no login or a regular calendar with
// a valid login.  This is configured in the admin web interface.
// If you want to use the new system (recommended), leave this $readonly
// setting set to "N".
$readonly = "N";

// Are you setting this up as a multi-user system?
// You can always start as a single-user system and change to multi-user
// later.  To enable single-user mode, uncomment out the following line
// and set it to a login name (that you would use if you ever switched to
// multi-user).  In single-user mode, you will not be prompted for a login,
// nor will you be asked to select participants for events.
// NOTE: If you select single-user and then upgrade to multi-user later,
// you'll have to add in the login name you've set below to the cal_user
// table.  Set $single_user to either true or false.  If true, make sure
// $single_user_login is defined.
$single_user = "N";
//$single_user_login = "cknudsen";

// Do you want to use web-based login or use HTTP authorization?
// NOTE: You can only use HTTP authorization if PHP is built as
// an Apache module.
// NOTE #2: There's no need to use this if you're running single
// user mode.
// Set the following to true to use http-based authorization.
// web-based login.)
// If you want to setup a public calendar with HTTP-based authentication,
// see FAQ for instructions.
$use_http_auth = false;


// Which user schema to use.  Currently, you can use the default webcal_user
// table, LDAP or NIS.  These files are found in the includes directory.
// Pick just one of the following:

// webcal_user table: default
$user_inc = "user.php";
// LDAP: if you select this, you must also configure some variables
// in includes/user-ldap.php such as your LDAP server...
//$user_inc = "user-ldap.php";
// NIS: if you select this, you must also configure some variables
// in includes/user-nis.php
//$user_inc = "user-nis.php";


// Language options  The first is the name presented to users while
// the second is the filename (without the ".txt") that must exist
// in the translations subdirectory.
$languages = array (
  "Browser-defined" =>"none",
  "English" =>"English-US",
  "Chinese (Traditonal/Big5)" => "Chinese-Big5",
  "Chinese (Simplified/GB2312)" => "Chinese-GB2312",
  "Czech" => "Czech",
  "Danish" => "Danish",
  "Dutch" =>"Dutch",
  "French" =>"French",
  "Galician" => "Galician",
  "German" =>"German",
  "Hungarian" =>"Hungarian",
  "Icelandic" => "Icelandic",
  "Italian" => "Italian",
  "Japanese" => "Japanese",
  "Korean" =>"Korean",
  "Norwegian" => "Norwegian",
  "Polish" => "Polish",
  "Portuguese" =>"Portuguese",
  "Portuguese/Brazil" => "Portuguese_BR",
  "Russian" => "Russian",
  "Spanish" =>"Spanish",
  "Swedish" =>"Swedish",
  "Turkish" =>"Turkish"
  // add new languages here!  (don't forget to add a comma at the end of
  // last line above.)
);

// If the user sets "Browser-defined" as their language setting, then
// use the $HTTP_ACCEPT_LANGUAGE settings to determine the language.
// The array below translates browser language abbreviations into
// our available language files.
// NOTE: These should all be lowercase on the left side even though
// the proper listing is like "en-US"!
// Not sure what the abbreviation is?  Check out the following URL:
// http://www.geocities.com/click2speak/languages.html
$browser_languages = array (
  "zh" => "Chinese-GB2312",    // Simplified Chinese
  "zh-cn" => "Chinese-GB2312",
  "zh-tw" => "Chinese-Big5",   // Traditional Chinese
  "cs" => "Czech",
  "en" => "English-US",
  "en-us" => "English-US",
  "en-gb" => "English-US",
  "da" => "Danish",
  "nl" =>"Dutch",
  "fr" =>"French",
  "fr-ch" =>"French", // French/Swiss
  "fr-ca" =>"French", // French/Canada
  "gl" => "Galician",
  "de" =>"German",
  "de-at" =>"German", // German/Austria
  "de-ch" =>"German", // German/Switzerland
  "de-de" =>"German", // German/German
  "hu" => "Hungarian",
  "is" => "Icelandic",
  "it" => "Italian",
  "it-ch" => "Italian", // Italian/Switzerland
  "ja" => "Japanese",
  "ko" =>"Korean",
  "no" => "Norwegian",
  "pl" => "Polish",
  "pt" =>"Portuguese",
  "pt-br" => "Portuguese_BR", // Portuguese/Brazil
  "ru" =>"Russian",
  "es" =>"Spanish",
  "sv" =>"Swedish",
  "tr" =>"Turkish",
  "cy" => "Welsh"
);

if ( $single_user != "Y" )
  $single_user_login = "";

?>
