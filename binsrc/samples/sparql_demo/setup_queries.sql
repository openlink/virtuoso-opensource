--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
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

"RQ"."RQ"."sparql_exec_no_error"('drop table RQ.RQ.SAMPLE_QUERIES');

create table RQ.RQ.SAMPLE_QUERIES (
  SQ_GROUP	  varchar not null,
  SQ_NAME     varchar not null,
  SQ_ORDER    integer,
  SQ_DESCRIPTION	varchar,
  SQ_DEFAULT_GRAPH	varchar,
  SQ_QUERY	varchar,
  primary key (SQ_GROUP, SQ_NAME)
);

INSERT INTO RQ.RQ.SAMPLE_QUERIES VALUES ('librdf.org','example 1',1,'A FOAF query that finds all people with a name and an IRC nick',
'http://www.dajobe.org/foaf.rdf',
'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT ?nick, ?name
WHERE { ?x rdf:type foaf:Person . ?x foaf:nick ?nick . ?x foaf:name ?name }');

INSERT INTO RQ.RQ.SAMPLE_QUERIES VALUES ('librdf.org','example 2',2,'An RSS 1.0 query that finds all the items in the feed',
'http://www.w3.org/2000/08/w3c-synd/home.rss',
'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX rss: <http://purl.org/rss/1.0/>
SELECT ?title ?description
WHERE { ?item rdf:type rss:item .
       ?item rss:title ?title .
       ?item rss:description ?description }');

INSERT INTO RQ.RQ.SAMPLE_QUERIES VALUES ('librdf.org','example 3',3,'Find all LOM root elements in the LOM encoded for the <a href="http://www.ukoln.ac.uk/projects/iemsr/">JISC IE Schema Registry</a>',
'http://www.ukoln.ac.uk/projects/iemsr/terms/LOM/',
'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX iemsr: <http://www.ukoln.ac.uk/projects/iemsr/terms/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

SELECT ?number ?name ?description
WHERE {
  ?r rdf:type iemsr:RootDataElement .
  ?n iemsr:isChildOf ?r .
  ?n iemsr:refNumber ?number .
  ?n rdfs:label ?name .
  ?n rdfs:comment ?description
}');

INSERT INTO RQ.RQ.SAMPLE_QUERIES VALUES ('librdf.org','example 4',4,'Print the description of a project and maintainer(s) using <a href="http://usefulinc.com/doap">DOAP</a>',
'http://svn.usefulinc.com/svn/repos/trunk/doap/examples/gnome-bluetooth-doap.rdf',
'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX doap: <http://usefulinc.com/ns/doap#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>

SELECT ?description ?maintainerName
WHERE {
  ?project rdf:type doap:Project .
  ?project doap:description ?description .
  ?project doap:maintainer ?m .
  ?m foaf:name ?maintainerName
}');

--INSERT INTO RQ.RQ.SAMPLE_QUERIES VALUES ('librdf.org','example 5',5,'Print the name and archive URIs of W3C mailing lists about P3P as described by <a href="http://www.doaml.net/">DOAML</a>',
--'http://www.doaml.net/doaml/w3ml/Lists.rdf',
--'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
--PREFIX doaml: <http://ns.balbinus.net/doaml#>
--
--SELECT ?name ?archives
--WHERE {
--  ?list rdf:type doaml:MailingList .
--  ?list doaml:name ?name .
--  ?list doaml:archives ?archives .
--  FILTER REGEX(?name, "p3p")
--}');

INSERT INTO RQ.RQ.SAMPLE_QUERIES VALUES ('librdf.org','example 6',6,'Print the names and optional nicks of people in my FOAF file where available',
'http://www.dajobe.org/foaf.rdf',
'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT ?name ?nick
WHERE {
  ?x rdf:type foaf:Person .
  ?x foaf:name ?name .
  OPTIONAL { ?x foaf:nick ?nick }
}');

--INSERT INTO RQ.RQ.SAMPLE_QUERIES VALUES ('librdf.org','example 7',7,'What podcasts have you got in your RSS feed? (you will need an RSS feed using the enclosures vocab) ',
--'http://B4mad.Net/datenbrei/feed/rdf',
--'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
--PREFIX dc: <http://purl.org/dc/elements/1.1/>
--PREFIX rss: <http://purl.org/rss/1.0/>
--PREFIX enc: <http://purl.oclc.org/net/rss_2.0/enc#>
--SELECT ?title ?enc ?len
--WHERE {
--      ?item rdf:type rss:item .
--      ?item rss:title ?title .
--      ?enclosure rdf:type enc:Enclosure .
--      ?item enc:enclosure ?enclosure .
--      ?enclosure enc:url ?enc .
--      ?enclosure enc:type ?type .
--      ?enclosure enc:length ?len .
--      FILTER regex(?type, "audio/mpeg")
--     }');

--INSERT INTO RQ.RQ.SAMPLE_QUERIES VALUES ('librdf.org','example 8',8,'What are the Noble Gases?',
--'http://www.daml.org/2003/01/periodictable/PeriodicTable.owl',
--'PREFIX table: <http://www.daml.org/2003/01/periodictable/PeriodicTable#>
--PREFIX xsd:   <http://www.w3.org/2001/XMLSchema#>
--SELECT ?name ?symbol ?weight ?number
--WHERE {
-- ?element table:group ?group .
-- ?group table:name "Noble gas"^^xsd:string .
-- ?element table:name ?name .
-- ?element table:symbol ?symbol .
-- ?element table:atomicWeight ?weight .
-- ?element table:atomicNumber ?number
--}
--ORDER BY ASC(?name)');

--INSERT INTO RQ.RQ.SAMPLE_QUERIES VALUES ('librdf.org','example 9',9,'What are the RDF DAWG issues?',
--'http://www.w3.org/2000/06/webdata/xslt?xslfile=http%3A%2F%2Fwww.w3.org%2F2003%2F11%2Frdf-in-xhtml-processor&xmlfile=http%3A%2F%2Fwww.w3.org%2F2001%2Fsw%2FDataAccess%2Fissues',
--'PREFIX collab: <http://www.w3.org/2000/10/swap/pim/collab@@#>
--SELECT ?desc ?R
--WHERE {
--  ?issue collab:shortDesc ?desc;
--  collab:resolveRecord ?R
--}');

--INSERT INTO RQ.RQ.SAMPLE_QUERIES VALUES ('librdf.org','example 10',10,'What are the last 10 updated items in an atom feed?',
--'http://www.tbray.org/ongoing/ongoing.atom',
--'PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
--PREFIX dc: <http://purl.org/dc/elements/1.1/>
--PREFIX rss: <http://purl.org/rss/1.0/>
--PREFIX atom: <http://www.w3.org/2005/Atom>
--SELECT ?item ?title ?date
--WHERE { ?item rdf:type rss:item .
--        ?item rss:title ?title .
--        ?item atom:updated ?date }
--ORDER BY DESC(?date)
--LIMIT 10');

--INSERT INTO RQ.RQ.SAMPLE_QUERIES VALUES ('librdf.org','example 11',11,'Who made a bridge in Bristol and what birth/death dates did they have?',
--'http://www.w3.org/2003/01/geo/rdfgml/tests/mixing-eg1.xml',
--'PREFIX : <http://www.commonobjects.example.org/gmlrss>
--PREFIX bio: <http://purl.org/vocab/bio/0.1/>
--PREFIX foaf: <http://xmlns.com/foaf/0.1/>
--
--SELECT ?name ?birthDate ?deathDate
--WHERE {
--  ?bridge a :Bridge;
--    foaf:maker ?person [
--      foaf:name ?name;
--      bio:event [
--	a bio:Birth;
--	bio:date ?birthDate
--      ];
--      bio:event [
--	a bio:Death;
--	bio:date ?deathDate
--      ]
--    ]
--}');

INSERT INTO RQ.RQ.SAMPLE_QUERIES VALUES ('librdf.org','example 12',12,'http://librdf.org/NEWS.rdf http://librdf.org/raptor/NEWS.rdf http://librdf.org/rasqal/NEWS.rdf http://librdf.org/bindings/NEWS.rdf',
'http://librdf.org/NEWS.rdf',
'PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX rss: <http://purl.org/rss/1.0/>
SELECT ?item ?title ?date
WHERE {
  ?item a rss:item ;
        rss:title ?title ;
        dc:date ?date
}
ORDER BY DESC(?date)
LIMIT 10');

