use CGI qw/:standard :html3 :all *table/;
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
use DBI;

use strict;
    my $rv;

    print header, start_html('A Simple Example'), "\n";

    eval {
	my $dbh = DBI->connect('dbi:ODBC:Local Virtuoso Demo', 'demo', 'demo', {
		  PrintError => 0,   ### Don't report errors via warn(  )
		  RaiseError => 1    ### Do report errors via die(  )
			  } );
	my $sth = $dbh->prepare("select ShipperID, CompanyName from Shippers");
	$rv = $sth->execute;
	my ($ShipperID, $CompanyName);
#    my $rc = $sth->bind_columns(\($ShipperID, $CompanyName)) or die "Bind ERROR : $DBI::errstr\n";


	print start_table (caption('select ShipperID, CompanyName from Shippers')), "\n";
	print Tr(
	      [
		th(['ShipperID', 'CompanyName'])
	      ])
	, "\n";


	my @data;
	while (@data = $sth->fetchrow_array ())
	{
	    print Tr(
		  [
		    td([ @data ])
		  ])
	    , "\n";
	}

	print  end_table (), "\n";
    };
    print p ("Error in SQL : $@"),"\n" if $@;

    print end_html, "\n";
