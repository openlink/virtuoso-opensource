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
# Examine all translation files to create a report that shows how
# many translations are missing from each translation file.
#
#######################################################################

$inc_dir = "../includes";

$transdir = "../translations";

opendir ( DIR, $transdir ) || die "Error opening $transdir: $!";
@files = readdir ( DIR );
closedir ( DIR );

# ignore everything except .txt files
@files = grep ( /.txt$/, @files );

# header
printf "%-20s %s\n", "Language file", "No. missing translations";

foreach $f ( @files ) {
  $out = `perl check_translation.pl ../translations/$f`;
  if ( $out =~ / missing./ ) {
    # missing some translations
    @lines = split ( /\n/, $out );
    ( $l ) = grep ( / translation.s. missing/, @lines );
    if ( $l =~ /^(\d+) / ) {
      printf "%-20s %d\n", $f . ":", $1;
    }
  } else {
    # all translations found :-)
    printf "%-20s %s\n", $f . ":", "Complete";
  }
}

