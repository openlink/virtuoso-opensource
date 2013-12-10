--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--
--
sparql clear graph <http://example.com>;

ttlp (
'
@prefix : <http://example.com/> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix dc: <http://purl.org/dc/elements/1.1/> .
@prefix rss: <http://purl.org/rss/1.0/> .

:p1 a foaf:Person ;
    	foaf:name "Joe Doe (en)" ;
	dc:title "Mr." ;
    	rss:title "<i>The information on this site is provided for discussion purposes only, and are not investing recommendations. Under no circumstances does this information represent a recommendation to buy or sell securities. </i>" ;
    	foaf:knows _:p2 ;
	foaf:knows _:p3 .

_:p2 a foaf:Person ;
	foaf:name "Doe Joe (de)"@de ;
	rdfs:label "This is some long literal more tahne 20 chars" ;
    	rss:title "<i>This string should be long enough............................................................................................ </i>" .

_:p3 a foaf:Person ;
	foaf:name "Doe Joe (fr)"@fr ;
	rdfs:label "This is some long literal more tahne 20 chars" ;
    	rss:title "<i>This string should be long enough too ............................................................................................ </i>" .
'
, '', 'http://example.com' );


sparql select * from <http://example.com> where { ?x ?y ?z };

select hic_set_memcache_size (1);

SPARQL
 PREFIX foaf: <http://xmlns.com/foaf/0.1/>
 PREFIX rss: <http://purl.org/rss/1.0/>

 SELECT DISTINCT ?rss_title
 FROM <http://example.com>
 WHERE {  ?s ?p <http://xmlns.com/foaf/0.1/Person>.
 OPTIONAL { ?s rss:title  ?rss_title }}
;
ECHO BOTH $if $equ $state OK "PASSED" "***FAILED";
ECHO BOTH ": distict with long string\n";

select hic_set_memcache_size (100000);
