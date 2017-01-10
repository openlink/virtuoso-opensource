#!/usr/local/bin/perl
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
#
# h2html.pl
#
# Image library
#
# Description:
#	Create HTML documentation from a C include file.
#
# History:
#	29-Nov-99	Craig Knudsen	cknudsen@radix.net
#			Updated to show prototype
#	20-Aug-99	Craig Knudsen	cknudsen@radix.net
#			Misc. bug fix
#	19-Jul-99	Craig Knudsen	cknudsen@radix.net
#			Modified for nicer looking output.
#	29-May-96	Craig Knudsen	cknudsen@radix.net
#			Created
#
#######################################################################


sub print_function {
  $out{$name} = "<H3><A NAME=\"$name\">$name</A></H3>\n";
  $out{$name} .= "<TT>$ret_type $name ( $args )</TT><P>\n";
  $out{$name} .= "$description<P>\n"
    if ( defined ( $description ) );
  $out{$name} .= "Returns: <TT>$ret_type</TT><P>\n" .
    "Input Parameters:<BR>\n<UL>\n";
  for ( $i = 0; $i < $num_ivars; $i++ ) {
    $out{$name} .= "<LI><TT>$vars[$i]</TT>";
    $out{$name} .= " - $comments[$i]" if ( defined ( $comments[$i] ) );
    $out{$name} .= "\n";
  }
  $out{$name} .= "</UL><P>\n";
  if ( $i < $num_vars ) {
    $out{$name} .= "Output Parameters:<BR>\n<UL><P>\n";
    for ( ; $i < $num_vars; $i++ ) {
      $out{$name} .= "<LI><TT>$vars[$i]</TT>";
      $out{$name} .= " - $comments[$i]" if ( defined ( $comments[$i] ) );
      $out{$name} .= "\n";
    }
    $out{$name} .= "</UL>\n";
  }
}

$line = 1;
$functions_found;
while ( <> ) {
  chop;
  $line++;
  if ( /Description:/ ) {
    $in_info = 1;
  } elsif ( /History:/ ) {
    $in_info = 0;
  } elsif ( $in_info ) {
    if ( /\*\s+/ ) {
      $info .= " " if length ( $info );
      $info .= $';
    }
  } elsif ( ! $functions_found ) {
    if ( /^\*\* Functions/ ) {
      $functions_found = 1;
    } else {
      next;
    }
  }
  elsif ( /^([^\*]\S+)\s+(\S+)\s+\(/ ) {
    # start of a function.
    $name = $2;
    $ret_type = $1;
    if ( $name =~ /^\*/ ) {
      $name = $';
      $ret_type .= " *";
    }
    $name =~ s/^_//;
    $num_vars = 0;
    $num_ivars = 0;
  } elsif ( defined ( $name ) ) {
    if ( /^\s+(\S.*)\s+\/\*\s*(\S.*)\s*\*\// ) {
      $vars[$num_vars] = $1;
      $comments[$num_vars] = $2;
      if ( $comments[$num_vars] =~ /^out: / ) {
        $comments[$num_vars] =~ s/^out:\s*//;;
      } else {
        $num_ivars++;
      }
      $vars[$num_vars] =~ s/[\s,]+$//;
      $args .= ", " if ( $args ne "" );
      $args .= $vars[$num_vars];
      $num_vars++;
    } elsif ( /^\);/ ) {
      &print_function;
      undef ( $name );
      undef ( @vars );
      undef ( @comments );
      undef ( $description );
      undef ( $args );
    } elsif ( /\s+\/\*\s*(\S.*)\s*\*\// ) {
if ( $num_vars <= 0 ) { print "ERROR ($line): $_\n"; exit ( 1 ); }
      $comments[$num_vars-1] .= " " . $1;
    }
  } elsif ( /^\*+\// ) {
    # end comment
  } elsif ( /^\*+\s*(\S.*)$/ ) {
    $description .= " " if ( length ( $description ) );
    $description .= $1;
  } elsif ( /^\/*/ ) {
    undef ( $description );
  }
}

@months = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul",
  "Aug", "Sep", "Oct", "Nov", "Dec" );
( $mday, $mon, $year ) = ( localtime ( time ) )[3,4,5];
$now = sprintf "%02d-%s-%04d",
  $mday, $months[$mon], $year + 1900;

print<<EOF;
<HTML>
<HEAD>
<TITLE>ILib API Documentation</TITLE>
</HEAD>
<BODY BGCOLOR="#FFFFFF">
<H2>Ilib Image Library</H2>
<BLOCKQUOTE>
$info
</BLOCKQUOTE>
<TABLE BORDER=0>
<TR><TD>Home Page:</TD>
  <TD><A HREF="http://www.radix.net/~cknudsen/Ilib/">http://www.radix.net/~cknudsen/Ilib/</A></TD></TR>
<TR><TD>Author:</TD>
  <TD><A HREF="http://www.radix.net/~cknudsen/">Craig Knudsen</A>, <A HREF="mailto:cknudsen\@radix.net">cknudsen\@radix.net</A></TD></TR>
<TR><TD>Last updated:</TD><TD>$now</TD></TR>
</TABLE>
<H2>API Documentation</H2>
<UL>
EOF

foreach $name ( sort keys ( %out ) ) {
  print "<LI><A HREF=\"#$name\">$name</A>\n";
}

print "</UL>\n<HR>\n";

foreach $name ( sort keys ( %out ) ) {
  print "<P>\n" . $out{$name};
}

print "</BODY>\n</HTML>\n";

exit 0;
