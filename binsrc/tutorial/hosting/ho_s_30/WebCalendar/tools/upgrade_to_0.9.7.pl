#!/usr/local/bin/perl
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2015 OpenLink Software
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
#
# This script will update a pre-0.9.7 WebCalendar database to have the
# correct tables for 0.9.7.
# (FYI, these changes were necessary to add support for other databases
# like Oracle.)
#


$mysql_path = "/usr/local/mysql/bin:/opt/mysql/bin";
$dbname = "intranet";
$tables = "cal_entry cal_entry_user cal_user cal_user_pref";
$out = "commands.sql";

# look for the mysql executable and mysqldump programs
sub find_executable {
  my ( $app ) = @_;
  my ( $path, $dir, $file, @dirs );

  my ( $path ) = $ENV{"PATH"} . ":" . $mysql_path;
  @dirs = split ( /:/, $path );
  foreach $dir ( @dirs ) {
    $file = "$dir/$app";
    return $file if ( -x $file );
  }

  die "Could not find $app executable in:\n$path\n";
}


sub string_or_null {
  my ( $in ) = @_;
  my ( $ret );

  if ( $in eq "\\N" || length ( $in ) == 0 ) {
    $ret = "NULL";
  } else {
    $in =~ s/'/\\'/g;
    $ret = "\'$in\'";
  }
  return $ret;
}

sub num_or_zero {
  my ( $in ) = @_;
  return "NULL" if ( $in eq "\\N" );
  return "0" if ( $in eq "" );
  return $in;
}

sub date_to_int {
  my ( $in ) = @_;
  my ( $ret );
  if ( $in =~ /(\d\d\d\d)-(\d\d)-(\d\d)/ ) {
    $ret = sprintf "%04d%02d%02d", $1, $2, $3;
  } else {
    $ret = "NULL";
  }
  #print STDERR "Date \"$in\" -> $ret\n";
  return $ret;
}


sub time_to_int {
  my ( $in ) = @_;
  my ( $ret );
  if ( $in =~ /(\d\d):(\d\d):(\d\d)/ ) {
    $ret = sprintf "%02d%02d%02d", $1, $2, $3;
  } else {
    $ret = "NULL";
  }
  #print STDERR "Time \"$in\" -> $ret\n";
  return $ret;
}


$mysql = &find_executable ( "mysql" );
$mysqldump = &find_executable ( "mysqldump" );

print "mysql found: $mysql\n";
print "mysqldump found: $mysqldump\n";

# Get a current dump of the db
$dir = "./data";
mkdir ( $dir, 0755 ) if ( ! -d $dir );
$cmd = "$mysqldump --no-create-info -T $dir $dbname $tables";
print "Command: $cmd\n";
system ( $cmd );

# use datafiles to create a series of SQL Insert commands

open ( OUT, ">$out" ) ||
  die "Error writing output file: $!\n";
print OUT<<EOF;
#DROP TABLE webcal_user;
CREATE TABLE webcal_user (
  cal_login VARCHAR(25) NOT NULL,
  cal_passwd VARCHAR(25),
  cal_lastname VARCHAR(25),
  cal_firstname VARCHAR(25),
  cal_is_admin CHAR(1) DEFAULT 'N',
  cal_email VARCHAR(75) NULL,
  PRIMARY KEY ( cal_login )
);
#DROP TABLE webcal_entry;
CREATE TABLE webcal_entry (
  cal_id INT NOT NULL,
  cal_group_id INT NULL,
  cal_create_by VARCHAR(25) NOT NULL,
  cal_date INT NOT NULL,
  cal_time INT NULL,
  cal_mod_date INT,
  cal_mod_time INT,
  cal_duration INT NOT NULL,
  cal_priority INT DEFAULT 2,
  cal_type CHAR(1) DEFAULT 'E',
  cal_access CHAR(1) DEFAULT 'P',
  cal_name VARCHAR(80) NOT NULL,
  cal_description TEXT,
  PRIMARY KEY ( cal_id )
);
#DROP TABLE webcal_entry_user;
CREATE TABLE webcal_entry_user (
  cal_id int(11) DEFAULT '0' NOT NULL,
  cal_login varchar(25) DEFAULT '' NOT NULL,
  cal_status char(1) DEFAULT 'A',
  PRIMARY KEY (cal_id,cal_login)
);
#DROP TABLE webcal_user_pref;
CREATE TABLE webcal_user_pref (
  cal_login varchar(25) NOT NULL,
  cal_setting varchar(25) NOT NULL,
  cal_value varchar(50) NULL,
  PRIMARY KEY ( cal_login, cal_setting )
);
EOF

open ( IN, "$dir/cal_user.txt" );
print OUT "\n\n\n";
while ( <IN> ) {
  chop;
  @fields = split /\t/;
  print OUT "INSERT INTO webcal_user ( cal_login, cal_passwd, cal_lastname,\n" .
   "cal_firstname, cal_is_admin )\n  VALUES ( ";
  print OUT &string_or_null ( $fields[0] ) . ", ";
  print OUT &string_or_null ( $fields[1] ) . ", ";
  print OUT &string_or_null ( $fields[2] ) . ", ";
  print OUT &string_or_null ( $fields[3] ) . ", ";
  print OUT &string_or_null ( $fields[4] ) . " );\n";
}
close ( IN );

open ( IN, "$dir/cal_entry.txt" );
print OUT "\n\n\n";
while ( <IN> ) {
  chop;
  while ( /\\$/ ) {
    s/[\\\r\n]+$//g;
    chop ( $nextline = <IN> );
    $nextline =~ s/[\\\r\n]+$//g;
    $_ .= "\\n" . $nextline;
  }
  @fields = split /\t/;
  $i = 0;
  print OUT "\nINSERT INTO webcal_entry\n" .
   "  ( cal_id, cal_group_id, cal_create_by,\n" .
   "  cal_date, cal_time, cal_mod_date, cal_mod_time, cal_duration,\n" .
   "  cal_priority, cal_type, cal_access, cal_name,\n" .
   "  cal_description )\n  VALUES (\n  ";
  print OUT &num_or_zero ( $fields[$i++] ) . ", ";	#cal_id
  print OUT "NULL, ";					#cal_group_id
  print OUT &string_or_null ( $fields[$i++] ) . ", ";	#cal_create_by
  print OUT &date_to_int ( $fields[$i++] ) . ", ";	#cal_date
  print OUT &time_to_int ( $fields[$i++] ) . ", ";	#cal_time
  print OUT &date_to_int ( $fields[$i] ) . ", ";	#cal_mod_date
  print OUT &time_to_int ( $fields[$i++] ) . ", ";	#cal_mod_time
  print OUT &num_or_zero ( $fields[$i++] ) . ", ";	#cal_duration
  print OUT &string_or_null ( $fields[$i++] ) . ", ";	#cal_priority
  print OUT &string_or_null ( $fields[$i++] ) . ", ";	#cal_type
  print OUT &string_or_null ( $fields[$i++] ) . ", ";	#cal_access
  $i++; # skip over status since it was never used
  print OUT &string_or_null ( $fields[$i++] ) . ", ";	#cal_name
  print OUT &string_or_null ( $fields[$i++] ) . ");\n";	#cal_description
}
close ( IN );

open ( IN, "$dir/cal_entry_user.txt" );
print OUT "\n\n\n";
while ( <IN> ) {
  chop;
  @fields = split /\t/;
  print OUT "INSERT INTO webcal_entry_user\n" .
   "( cal_id, cal_login, cal_status )\n" .
   "VALUES ( ";
  $i = 0;
  print OUT &num_or_zero ( $fields[$i++] ) . ", ";
  print OUT &string_or_null ( $fields[$i++] ) . ", ";
  print OUT &string_or_null ( $fields[$i++] ) . " );\n";
}
close ( IN );


open ( IN, "$dir/cal_user_pref.txt" );
print OUT "\n\n\n";
while ( <IN> ) {
  chop;
  @fields = split /\t/;
  print OUT "INSERT INTO webcal_user_pref\n" .
   "( cal_login, cal_setting, cal_value )\n" .
   "VALUES ( ";
  $i = 0;
  print OUT &string_or_null ( $fields[$i++] ) . ", ";
  print OUT &string_or_null ( $fields[$i++] ) . ", ";
  print OUT &string_or_null ( $fields[$i++] ) . " );\n";
}
close ( IN );

close ( OUT );

exit 0;
