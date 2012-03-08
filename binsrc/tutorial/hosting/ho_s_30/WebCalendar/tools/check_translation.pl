#!/usr/local/bin/perl
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
#
# This tool helps with the translation into other languages by verifying that
# all text specified in translate(), etranslate() and etooltip()
# within the application has a corresponding entry in the translation
# data file.  In short, this makes sure all text has a correspoding
# translation.
#
# Usage:
#	check_translation.pl languagefile
#	  ... or to check the most recently modified translation file
#	check_translation.pl
# Example:
#	check_translation.pl ../translations/English-US.txt
#
# Note: this utility should be run from this directory (tools).
#
###########################################################################

$trans_dir = "../translations";

$infile = $ARGV[0];

if ( $infile eq "" ) {
  opendir ( DIR, $trans_dir ) || die "error opening $trans_dir";
  @files = grep ( /\.txt$/, readdir ( DIR ) );
  closedir ( DIR );
  $last_mtime = 0;
  foreach $f ( @files ) {
    ( $mtime ) = ( stat ( "../translations/$f" ) )[9];
    if ( $mtime > $last_mtime ) {
      $last_mtime = $mtime;
      $infile = "../translations/$f";
    }
  }
}

if ( $infile ne "" && ! -f $infile && -f "$trans_dir/$infile" ) {
  $infile = "$trans_dir/$infile";
}

if ( $infile ne "" && ! -f $infile && -f "$trans_dir/$infile.txt" ) {
  $infile = "$trans_dir/$infile.txt";
}


# First get the list of .php and .inc files.
opendir ( DIR, ".." ) || die "Error opening ..";
@files = grep ( /\.php$/, readdir ( DIR ) );
closedir ( DIR );

opendir ( DIR, "../includes" ) || die "Error opening ../includes";
@incfiles = grep ( /\.php$/, readdir ( DIR ) );
closedir ( DIR );
foreach $f ( @incfiles ) {
  push ( @files, "includes/$f" );
}
push ( @files, "tools/send_reminders.php" );


foreach $f ( @files ) {
  $file = "../$f";
  open ( F, $file ) || die "Error reading $file";
  #print "Checking $f for text.\n";
  while ( <F> ) {
    $data = $_;
    while ( $data =~ /(translate|tooltip)\s*\(\s*"/ ) {
      $data = $';
      if ( $data =~ /"\s*\)/ ) {
        $text = $`;
        $text{$text} = 1;
        $data = $';
      }
    }
  }
  close ( F );
}

#print "Found the following entries:\n";
#foreach $text ( sort { uc($a) cmp uc($b) } keys ( %text ) ) {
#  print "$text\n";
#}

# Now load the translation file
if ( ! -f $infile ) {
  die "Usage: $0 translation-file\n";
}
open ( F, $infile ) || die "Error opening $infile";
while ( <F> ) {
  chop;
  next if ( /^#/ );
  if ( /\s*:/ ) {
    $abbrev = $`;
    $trans{$abbrev} = $';
  }
}

$notfound = 0;
foreach $text ( sort { uc($a) cmp uc($b) } keys ( %text ) ) {
  if ( ! defined ( $trans{$text} ) ) {
    if ( ! $notfound ) {
      print "The following text did not have a translation in $infile:\n\n";
    }
    print "$text\n";
    $notfound++;
  }
}

# Check for translations that are not used...
$extra = 0;
foreach $text ( sort { uc($a) cmp uc($b) } keys ( %trans ) ) {
  if ( ! defined ( $text{$text} ) ) {
    if ( ! $extra ) {
      print "\nThe following translation text is not needed in $infile:\n\n";
    }
    print "$text\n";
    $extra++;
  }
}

if ( ! $notfound ) {
  print "All text was found in $infile.  Good job :-)\n";
} else {
  print "\n$notfound translation(s) missing.\n";
}

exit 0;
