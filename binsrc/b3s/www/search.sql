--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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

create procedure label_get(in smode varchar)
{
  declare label varchar;
  if (smode='1') label := 'Text Search';
  else if (smode='2') label := 'Graph associated with a Full Text Pattern';
  else if (smode='3') label := 'Types of Things With Text';
  else if (smode='4') label := 'Interests Around';
  else if (smode='5') label := 'Top 100 Authors by Text';
  else if (smode='6') label := 'Social Connections a la LinkedIn';
  else if (smode='7') label := 'Connection Between';
  else if (smode='8') label := 'People With Shared Interests';
  else if (smode='9') label := 'Cloud around a Text Pattern';
  else if (smode='10') label := 'Cloud Around Person With Filtered Out Blank Nodes';
  else if (smode='11') label := 'Product Count By Manufacturer';
  else if (smode='12') label := 'Vendors with offers';
  else if (smode='13') label := 'Objects around Paris with Cafe''s in close proximity';
  else if (smode='14') label := 'Motorways across England & Scotland';
  else if (smode='15') label := 'Objects around London with Cities in close proximity';
  else if (smode='16') label := 'Places with coordinates';
  else if (smode='17') label := 'Subcategories of History of Wisconsin';
  else if (smode='18') label := 'Things within close proximity of New York City';
  else if (smode='19') label := 'Distance between New York City and London, England';
  else if (smode='20') label := 'All Educational Institutions within 10km of Oxford, UK';
  else if (smode='100') label := 'Concept Cloud';
  else if (smode='101') label := 'Social Net';
  else if (smode='102') label := 'Graphs in Social Net';
  else if (smode='103') label := 'Interest Matches';
  else if (smode='104') label := 'Named Entities Cloud';
  else if (smode='1001') label := 'Named Entities Cloud';
  else if (smode='1002') label := 'Text Search in a Graph';
  else if (smode='1003') label := 'Documents by Author';
  else if (smode='1004') label := 'Authors about NE';
  else if (smode='1005') label := 'Shared Interests';
  else label := 'No such query';
  return label;

  --else if (smode='13') label := 'Products with certain text patterns in Manfacturer''s legal name';
}
;


create procedure input_get (in num varchar)
{
  declare t1, t2 any;
  t1 := vector (
  	'Search for',
	'Search for',
	'Search for',
	'Name',
	'Search for',
	'Person URI',
	'Property',
	'Nickname',
	'Text pattern',
	'Nickname',
	'Number of items',
        'Price value',
--	'Manufacturer',
        'City Longitude',
        'Latitude',
        'Entity URI',
        'Geometry Latitude',
        'Broader',
        'Place URI',
        'First City URI',
        'City URI'
	);
  t2 := vector (
  	'',
	'',
	'',
	''
	);
  num := atoi (num) - 1;
  if (num > -1 and num < 20)
    return t1[num];
  else if (num > 98 and num < 102)
    return t2[num - 99];
  return '';
}
;

create procedure input_getcustom (in num varchar)
{
  if (num = 2)
    return 'City Latitude';
  else if (num = 3)
    return 'Cafe Proximity to Entity URI';
  else if (num = 4)
    return 'Distance';
  if (num = 5)
    return 'isA';
  if (num = 6)
    return 'Distance';
  if (num = 7)
    return 'Geometry Longitude';
  if (num = 8)
    return 'Person URI';
  if (num = 9)
    return 'Person URI';
  if (num = 10)
    return 'First Language';
  if (num = 11)
    return 'Second Language';
  if (num = 12)
    return 'Narrower';
  if (num = 13)
    return 'Thing(s) Proximity (km)';
  if (num = 14)
    return 'Language';
  if (num = 15)
    return 'Second City URI';
  if (num = 16)
    return 'Institution Proximity to the Place';
  if (num = 17)
    return 'Ontology URI';
  if (num = 18)
    return 'Language';
  else return '';
}
;


create procedure desc_get (in num varchar)
{
  declare t1, t2 any;
  t1 := vector (
  	'Show triples containing a text pattern. The bif:search_excerpt is used to format a short excerpt of the matching literal in search-engine style',
	'What sources talk the most about a given subject? Show the top N graphs containing triples with the given text pattern. Sort by descending triple count.',
	'What types of objects contain a text pattern. Find matches, get the type. Group by type, order by count.',
	'What are the interests of a given person based on their foaf:name?',
	'Who writes the most about a topic. Show for each author the number of works mentioning the topic and total number of works. '
||'<br>For all documents and posts we have extracted named entities the entity could shows the entities which occur in the works of each author. '
||'There are statistics about named entities occurring together, these are used for display a list of related entities. '
	,
	'Show the people a person directly or indirectly knows. Sort by distance and count of connections of the known person',
	'Given two people, find what chain of acquaintances links them together. For each step in the chain show the person linked to, the graph linking this person to the previous person, the number of the step and the number of the path. Note that there may be many paths through which the people are linked.',
	'Given a person, find people with the most interests in common with this person. Show the person, number of shared interests and the total number of interests.',
	'Show names of things surrounding a person by given text pattern. These may be interests, classes of things, other people and so forth. For each label show the count of occurrences, largest count first. This uses the b3s:label superproperty which includes rdfs:label, dc:title, and other qualities which have a general meaning of label.',
	'Show names of things surrounding a person with filtered out blank nodes. These things may be interests, classes of things, other people and so forth. For each label show the count of occurrences, largest count first. This uses the b3s:label superproperty which includes rdfs:label, dc:title, and other qualities which have a general meaning of label.',
	'Show product total by manufacturer where total is greater than given value.',
        'Show all vendors with all offers and their prices that are greater than given value.',
--        'Show products count for given manufacturer.',
        'Show places of worship, within certain km of Paris, that have cafes in close proximity.',
        'Show motorways across England & Scotland from DBpedia.',
        'Shows cities within certain proximity of London.',
        'Shows geometries with their coordinates.',
        'Find entities that are subcategories of History of Wisconsin, no deeper than 3 levels within the concept scheme hierarchy filtered by a specific subcategory.',
        'Shows things within certain proximity of a place.',
        'Shows distance between 2 cities.',
        'Find all Educational Institutions within 10km of Oxford, UK ordered by date of establishment.'
	);
  t2 := vector (
  	'',
	'',
	'',
	''
	);
  num := atoi (num) - 1;
  if (num > -1 and num < 20)
    return t1[num];
  else if (num > 98 and num < 102)
    return t2[num - 99];
  return '';
}
;

create procedure head_get (in num varchar)
{
  declare t1, t2, t3 any;
  t1 := vector (
    vector ('Subject', 'Predicate', 'Hit summary'),
    vector ('Graph', 'Number of mentions'),
    vector ('Class', 'Count'),
    vector ('Interest', 'Number of People'),
    vector ('Author', 'Works Containing Pattern', 'Total Number of Works'),
    vector ('Connection', 'Distance', 'Number of Connections'),
    vector ('Person URI', 'Graph', 'Step No.', 'Path'),
    vector ('Person', 'Nick name', 'Shared Interests', 'Total Interests'),
    vector ('Thing', 'Nick name', 'Occurrences'),
    vector ('Thing', 'Text Pattern', 'Occurrences'),
    vector ('Manifacturer URI', 'Total Products'),
    vector ('Vendor', 'Offer', 'Business Function', 'Offer Object', 'Type of Good', 'Price'),
--    vector ('Vendor', 'Offer', 'Business Function', 'Customer Type', 'Offer Object', 'Type of Good', 'Price'),
--    vector ('Total Products'),
    vector ('Cafe URI', 'Latitude', 'Longitude', 'Cafe Name', 'Church Name', 'Count'),
    vector ('Road', 'Latitude', 'Longitude'),
    vector ('City URI', 'Distance (km)'),
    vector ('Geometry URI', 'Latitude', 'Longitude'),
    vector ('SKOS Broader', 'SKOS Narrower', 'SKOS Level', 'Entity URI', 'Entity Name', 'Geo Point'),
    vector ('Resource URI', 'Name', 'Location'),
    vector ('First City Name', 'First City Location', 'Second City Name', 'Second City Location', 'Distance'),
    vector ('Institution URI', 'Name', 'Established' ,'Latitude', 'Longitude')
  );
  t2 := vector (
    vector (),
    vector (),
    vector (),
    vector ()
  );
  t3 := vector ();
  num := atoi (num) - 1;
  if (num > -1 and num < 20)
    return t1[num];
  else if (num > 98 and num < 102)
    return t2[num - 99];
  return vector ();
}
;


create procedure validate_input(inout val varchar)
{
  val := trim(val, ' ');
  val := replace(val, '*', '');
 val := replace(val, '>', '');
  val := replace(val, '<', '');
  --val := replace(val, '&', '');
  --val := replace(val, '"', '');
  val := replace(val, '''', '');
}
;

create procedure get_curie (in val any)
{

 declare delim, delim1, delim2, delim3 integer;
  declare pref, res, suff varchar;

  delim1 := coalesce (strrchr (val, '/'), -1);
  delim2 := coalesce (strrchr (val, '#'), -1);
  delim3 := coalesce (strrchr (val, ':'), -1);
  delim := __max (delim1, delim2, delim3);

  if (delim < 0)
    return val;

  pref := subseq (val, 0, delim+1);
  suff := subseq (val, delim + 1);

  if (pref = val)
    return val;

  res := null;
  if (strstr (val, 'http://dbpedia.org/resource/') = 0 ) res :=  'dbpedia';
  if (strstr (val, 'http://dbpedia.org/property/') = 0 ) res :=  'dbpprop';
  if (strstr (val, 'http://dbpedia.openlinksw.com/wikicompany/') = 0 ) res :=  'wikicompany';
  if (strstr (val, 'http://dbpedia.org/class/yago/') = 0 ) res :=  'yago';
  if (strstr (val, 'http://www.w3.org/2003/01/geo/wgs84_pos#') = 0 ) res :=  'geo';
  if (strstr (val, 'http://www.geonames.org/ontology#') = 0 ) res :=  'geonames';
  if (strstr (val, 'http://xmlns.com/foaf/0.1/') = 0 ) res :=  'foaf';
  if (strstr (val, 'http://www.w3.org/2004/02/skos/core#') = 0 ) res :=  'skos';
  if (strstr (val, 'http://www.w3.org/2002/07/owl#') = 0 ) res :=  'owl';
  if (strstr (val, 'http://www.w3.org/2000/01/rdf-schema#') = 0 ) res :=  'rdfs';
  if (strstr (val, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#') = 0 ) res :=  'rdf';
  if (strstr (val, 'http://www.w3.org/2001/XMLSchema#') = 0 ) res :=  'xsd';
  if (strstr (val, 'http://purl.org/dc/elements/1.1/') = 0 ) res :=  'dc';
  if (strstr (val, 'http://purl.org/dc/terms/') = 0 ) res :=  'dcterms';
  if (strstr (val, 'http://dbpedia.org/units/') = 0 ) res :=  'units';
  if (strstr (val, 'http://www.w3.org/1999/xhtml/vocab#') = 0 ) res :=  'xhv';
  if (strstr (val, 'http://rdfs.org/sioc/ns#') = 0 ) res :=  'sioc';
  if (strstr (val, 'http://purl.org/ontology/bibo/') = 0 ) res :=  'bibo';
  if (strstr (val, 'http://purl.org/goodrelations/v1#') = 0 ) res :=  'gr';
  if (strstr (val, 'http://linkedgeodata.org/vocabulary#') = 0 ) res :=  'lgv';
  if (strstr (val, 'http://dbpedia.org/resource/Category:') = 0 ) res :=  'category';
  if (strstr (val, 'http://www.georss.org/georss/') = 0 ) res :=  'grs';

  if (res is null)
    res := __xml_get_ns_prefix (pref, 2);
  if (res is null)
    return val;
  return res||':'||suff;
}
;


create procedure print_http(inout val varchar)
{
  if (strstr (val, 'http') = 0)
    val := concat('<', val, '>');
}
;

create procedure print_nbsp_1 (inout ses any, in n int)
{
  for (declare i int, i := 0; i < n;  i := i + 1)
    http ('&nbsp;', ses);
}
;

create procedure pretty_sparql_1 (inout arr any, inout inx int, in len int, inout ses any, in lev int := 0)
{
  declare nbsp, was_open, was_close, num_open int;
  nbsp := 0;
  was_open := 0;
  was_close := 0;
  num_open := 0;
  for (;inx < len; inx := inx + 1)
    {
      declare elm varchar;
      elm := arr[inx];
      if (elm = 'sparql')
        goto skipit;

      if (elm = '(')
	num_open := num_open + 1;
      if (elm = ')')
	num_open := num_open - 1;

      if (num_open = 0)
        {
	  if (elm = '{')
	    {
	      nbsp := nbsp + 2;
	      http ('<br>', ses);
	      print_nbsp_1 (ses, nbsp);
	      was_open := 1;
	      was_close := 0;
	    }
	  else if (was_open = 1)
	    {
	      was_open := 0;
	      was_close := 0;
	      http ('<br>', ses);
	      print_nbsp_1 (ses, nbsp + 2);
	    }
	  else if (elm = '}')
	    {
	      if (not was_close)
		{
		  http ('<br>', ses);
		  print_nbsp_1 (ses, nbsp);
		}
	    }
	  else
	    was_close := 0;
	}


      http (elm, ses);

      if (num_open = 0)
        {
	  if (elm = '}')
	    {
	      was_close := 1;
	      nbsp := nbsp - 2;
	      http ('<br>', ses);
	      print_nbsp_1 (ses, nbsp);
	    }
	  else if (elm = '.')
	    {
	      http ('<br>', ses);
	      print_nbsp_1 (ses, nbsp + 1);
	    }
	}

      if (elm = 'sparql')
	http ('<br>');
      http (' ', ses);
      skipit:;
    }
}
;

create procedure pretty_sparql (in q varchar, in lev int := 0)
{
  declare ses, arr any;
  declare inx int;
  ses := string_output ();
  q := sprintf ('%V', q);
  q := replace (q, '\n', ' ');
  q := replace (q, '}', ' } ');
  q := replace (q, '{', ' { ');
  q := replace (q, ')', ' ) ');
  q := replace (q, '(', ' ( ');
  q := regexp_replace (q, '\\s\\s+', ' ', 1, null);
  arr := split_and_decode (q, 0, '\0\0 ');
  inx := 0;
  pretty_sparql_1 (arr, inx, length (arr), ses, lev);
  return string_output_string (ses);
}
;

create procedure element_split(in val any)
{
  declare srch_split, el varchar;
  declare k integer;
  declare sall any;


  --srch_split := '';
  --k := 0;
  --sall := split_and_decode(val, 0, '\0\0 ');
  --for(k:=0;k<length(sall);k:=k+1)
  --{
  -- el := sall[k];
  -- if (el is not null and length(el) > 0) srch_split := concat (srch_split, ', ', '''',el,'''');
  --};
  --srch_split := trim(srch_split,',');
  --srch_split := trim(srch_split,' ');
  --return srch_split;

  declare words any;
  srch_split := '';
  val := trim (val, '"');
  FTI_MAKE_SEARCH_STRING_INNER (val,words);
  k := 0;
  for(k:=0;k<length(words);k:=k+1)
  {
    el := words[k];
    if (el is not null and length(el) > 0)
      srch_split := concat (srch_split, ', ', '''',el,'''');
  };
  srch_split := trim(srch_split,',');
  srch_split := trim(srch_split,' ');
  return srch_split;
}
;

create procedure words_to_string(in val any)
{
  declare srch_split, el varchar;
  declare k integer;
  declare words any;
  srch_split := '';
  val := trim (val, '"');
  val := '"'||val||'"';
  FTI_MAKE_SEARCH_STRING_INNER (val,words);
  k := 0;
  for(k:=0;k<length(words);k:=k+1)
  {
    el := words[k];
    if (el is not null and length(el) > 0)
      srch_split := concat (srch_split, ' ',el);
  };
  srch_split := trim(srch_split,' ');
  return srch_split;
}
;

create procedure pick_query(in smode varchar, inout val any, inout query varchar, inout val2 any := null, inout val3 any := null, inout val4 any := null)
{
  declare s1, s2, s3, s4, s5 varchar;

  s1:='';
  s2:='';
  s3:='';
  s4:='';
  s5:='';

  if (smode='1')
  {
--* Text Search - default is semantic web.
--sparql
--select ?s ?p (bif:search_excerpt (bif:vector ('semantic', 'web'), ?o))
--where
--  {
--    ?s ?p ?o .
--    filter (bif:contains (?o, "'semantic web'"))
--  }
--limit 10
--;

    if (isnull(val) or val = '') val := '"semantic web"';
    s1 := 'sparql SELECT ?s ?p (bif:search_excerpt (bif:vector (';
    s3 := '), ?o)) WHERE  {  ?s ?p ?o .  FILTER (bif:contains (?o, ''';
    s5 := '''))  }  LIMIT 10';

    validate_input(val);
    s2 := element_split(val);
    s4 := trim (fti_make_search_string(val), '()');
    query := concat('',s1, s2, s3, s4, s5, '');
  }
  else if (smode='2')
  {
--* Graphs With Text  -- paris and dakar is the sample
--sparql
--select ?g count (*)
--where {
--  graph ?g
--  {
--    ?s ?p ?o .
--    filter (bif:contains (?o, "paris and dakar"))
--  } } group by ?g order by desc 2 limit 50
--;

-- old variant
--    if (isnull(val) or val = '') val := 'paris and dakar';
--    s1 := 'sparql SELECT ?g COUNT (*) WHERE { graph ?g { ?s ?p ?o . FILTER (bif:contains (?o, \'';
    --validate_input(val);
--    s2 := trim (fti_make_search_string(val), '()');
--    s3 := '\')) } } GROUP BY ?g ORDER BY DESC 2 LIMIT 50';
--    query := concat('',s1, s2, s3,'');


    if (isnull(val) or val = '') val := '"Linked Data"';
    s1 := 'sparql SELECT ?g COUNT (*) WHERE { graph ?g { ?s ?p ?o . ?s a ?c .  ' ||
    ' FILTER (bif:contains (?o, ''';
    validate_input(val);
    s2 := trim (fti_make_search_string(val), '()');
    s3 := ''')) } } GROUP BY ?g ORDER BY DESC 2 LIMIT 50';
    query := concat('',s1, s2, s3,'');
  }
  else if (smode='3')
  {
----* Types of Things With Text -- sample is Paris Hilton
--sparql
--select ?tp count (*)
--where
--  {
--    graph ?g
--      {
--        ?s ?p ?o .
--        ?s a ?tp
--        filter (bif:contains (?o, "'paris hilton'"))
--      }
--  }
--group by ?tp
--order by desc 2;
    if (isnull(val)  or val = '') val := '"Paris Hilton"';
    s1 := 'sparql SELECT ?tp COUNT(*) WHERE { graph ?g  { ?s ?p ?o . ?s a ?tp  . ' ||
    ' FILTER (bif:contains (?o, ''';
    validate_input(val);
    s2 := trim (fti_make_search_string(val), '()');
    s3 := ''') ) } } GROUP BY ?tp ORDER BY DESC 2';
    query := concat('',s1, s2, s3,'');
  }
  else if (smode='4')
  {
--* Interests Around  -- sample is  <http://www.livejournal.com/interests.bml?int=harry+potter>
--sparql
--select ?i2 count (*)
--where
--  {
--    ?p foaf:interest <http://www.livejournal.com/interests.bml?int=harry+potter> .
--    ?p foaf:interest ?i2
--  }
--group by ?i2
--order by desc 2
--limit 20
--;


-- old variant
--  if (isnull(val)  or val = '') val := 'http://www.livejournal.com/interests.bml?int=harry+potter';
--  s1 := 'sparql SELECT ?i2 COUNT (*) WHERE   { ?p foaf:interest <';
--  validate_input(val);
--  s2 := val;
--  s3 := '> . ?p foaf:interest ?i2  } GROUP BY ?i2 ORDER BY DESC 2 LIMIT 20';
--  query := concat('',s1, s2, s3,'');


    if (isnull(val)  or val = '') val := 'Kingsley Idehen';
    s1 := 'sparql SELECT ?i2 COUNT (*) WHERE  { ?p foaf:interest ?i1 . ' ||
    ' ?p foaf:name ?name . ' ||
    ' FILTER ( bif:contains (?name, \'';
    validate_input(val);
    s2 := trim (fti_make_search_string(val), '()');
    s3 := '\')) . ?p foaf:interest ?i2  } GROUP BY ?i2 ORDER BY DESC 2 LIMIT 20';
    query := concat('',s1, s2, s3,'');
  }
  else if (smode='5')
  {

-- this query crashes the server:
----* The Most One-Sidedly Known People
--sparql
--select ?celeb, count (*)
--where
--  {
--    ?claimant foaf:knows ?celeb .
--    filter (!bif:exists ((select (1) where { ?celeb foaf:knows ?claimant })))
--  }
--group by ?celeb
--order by desc 2
--limit 10
--;
--

  --s1 := 'sparql select ?celeb, count (*) where { ?claimant foaf:knows ?celeb . filter ( !bif:exists ( ( select (1) where { ?celeb foaf:knows ?claimant } ) ) ) } group by ?celeb order by desc 2 limit 10 ' ;
  --query := concat('',s1, '');

-- the new query is Top 100 Authors by Text: default is semantic and web

--sparql
--select ?auth ?cnt ((select count (distinct ?xx) where { ?xx dc:creator ?auth})) where
--{{ select ?auth count (distinct ?d) as ?cnt
--where
--  {
--    ?d dc:creator ?auth .
--    ?d ?p ?o
--    filter (bif:contains (?o, "semantic and web"))
--  }
--group by ?auth
--order by desc 2 limit 100 }}
--;

    if (isnull(val) or val = '') val := 'semantic and web';
    s1 := 'sparql SELECT ?auth ?cnt ((SELECT COUNT (DISTINCT ?xx) ' ||
    ' WHERE { ?xx dc:creator ?auth } )) WHERE { { SELECT ?auth COUNT (DISTINCT ?d) as ?cnt ' ||
    ' WHERE { ?d dc:creator ?auth .  ?d ?p ?o  . FILTER (bif:contains (?o, \'' ;
    validate_input(val);
    s2 := trim (fti_make_search_string(val), '()');
    s3 := '\') && isIRI (?auth)) } GROUP BY ?auth ORDER BY DESC 2 LIMIT 100 } } ' ;
    query := concat('',s1, s2, s3, '');


  }
  else if (smode='6')
  {
----* Social Connections a la LinkedIn   sample is http://myopenlink.net/dataspace/person/kidehen#this
--sparql select ?o ?dist ((select count (*) where {?o foaf:knows ?xx}))
--where
--  {
--    {
--      select ?s ?o
--      where
--        {
--          ?s foaf:knows ?o
--        }
--    }
--    option (transitive, t_distinct, t_in(?s), t_out(?o), t_min (1), t_max (4), t_step ('step_no') as ?dist) .
--    filter (?s= <http://myopenlink.net/dataspace/person/kidehen#this>)
--  } order by ?dist desc 3 limit 50;
    if (isnull(val)  or val = '') val := 'http://www.w3.org/People/Berners-Lee/card#i';
    s1 := 'sparql SELECT ?o ?dist ( ( SELECT COUNT (*) WHERE {?o foaf:knows ?xx } ) ) WHERE  { { SELECT ?s ?o  WHERE { ?s foaf:knows ?o } } OPTION (transitive, t_distinct, t_in(?s), t_out(?o), t_min (1), t_max (4), t_step (''step_no'') as ?dist ) . FILTER (?s= <';
    validate_input(val);
    s2 := val;
    s3 := '> ) } ORDER BY ?dist DESC 3 LIMIT 50 ';
    query := concat('',s1, s2, s3,'');
  }
  else if (smode='7')
  {
----* Connection Between  samples are http://myopenlink.net/dataspace/person/kidehen#this and http://www.advogato.org/person/mparaz/foaf.rdf#me
--
--sparql  select ?link ?g ?step ?path
--where
--  {
--    {
--      select ?s ?o ?g
--      where
--        {
--          graph ?g {?s foaf:knows ?o }
--        }
--    }
--    option (transitive, t_distinct, t_in(?s), t_out(?o), t_no_cycles, T_shortest_only,
--       t_step (?s) as ?link, t_step ('path_id') as ?path, t_step ('step_no') as ?step, t_direction 3) .
--    filter (?s= <http://myopenlink.net/dataspace/person/kidehen#this>
--	&& ?o = <http://www.advogato.org/person/mparaz/foaf.rdf#me>)
--  } limit 20;

    if (isnull(val)  or val = '') val := 'foaf:knows';
    if (isnull(val2)  or val2 = '') val2 := 'http://www.w3.org/People/Berners-Lee/card#i';
    if (isnull(val3)  or val3 = '') val3 := 'http://myopenlink.net/dataspace/person/kidehen#this';
-- old variant with foaf:knows
--  s1 := 'sparql SELECT ?link ?g ?step ?path WHERE { { SELECT ?s ?o ?g WHERE { graph ?g {?s foaf:knows ?o } } } OPTION (transitive, t_distinct, t_in(?s), t_out(?o), t_no_cycles, T_shortest_only, t_step (?s) as ?link, t_step (''path_id'') as ?path, t_step (''step_no'') as ?step, t_direction 3) . FILTER (?s= <';
    s1 := 'sparql SELECT ?link ?g ?step ?path WHERE { { SELECT ?s ?o ?g WHERE { graph ?g {?s ';
    validate_input(val);
    print_http(val);
    s2 := val;
    s1 := concat(s1, s2, ' ?o } } } OPTION (transitive, t_distinct, t_in(?s), t_out(?o), t_no_cycles, T_shortest_only, t_step (?s) as ?link, t_step (''path_id'') as ?path, t_step (''step_no'') as ?step, t_direction 3) . FILTER (?s= <');
    validate_input(val2);
    s3 := val2;
    validate_input(val3);
    s4 := val3;
    s5 := concat(s3, '>  && ?o = <', s4, '>)  } LIMIT 20' );
    query := concat('',s1, s5, '');
  }
  else if (smode = '8')
    {

-- old variant
--      if (isnull(val)  or val = '') val := '"aeon_phoenix"@en';
--      s1 := 'sparql
--SELECT ?p ?n ((SELECT COUNT (*) WHERE {?p foaf:interest ?i . ?ps foaf:interest ?i}))
--((SELECT COUNT (*) WHERE { ?p foaf:interest ?i}))
--WHERE {
--?ps foaf:nick ';
--if (val not like '"%"' and strchr (val, '@') is null)
--  val := '"'||val||'"';
--s2 := val;
--s3 := ' .
--{ SELECT DISTINCT ?p ?psi WHERE { ?p foaf:interest ?i . ?psi foaf:interest ?i } } .  FILTER (?ps = ?psi) ?p foaf:nick ?n } ORDER BY DESC 3 LIMIT 50';
--      query := concat(s1, s2, s3);
--    }
--  else if (smode = '9')
--    {
--      if (isnull(val)  or val = '') val := '"SQL"';
--
---- b3s variant:
--
----      if (isnull(val)  or val = '') val := '"aeon_phoenix"';
----      s1 :=
----      'sparql define input:inference \'b3s\' select ?s ?lbl count(*) where { ?s  ?p2 ?o2 .  ?o2 <http://b3s-demo.openlinksw.com/label> ?lbl . ' ||
----      ' ?s  foaf:nick ?o .  filter (bif:contains (?o, ''';
--
--      s1 :=
--      'sparql define input:inference \'virtrdf-label\' SELECT ?s ?lbl COUNT(*) WHERE { ?s  ?p2 ?o2 .  ?o2 <http://www.w3.org/2000/01/rdf-schema#label> ?lbl . ' ||
--      ' ?s  foaf:nick ?o .  FILTER (bif:contains (?o, ''';
--      validate_input(val);
--      s2 := trim (fti_make_search_string(val), '()');
--      s3 := ''')) } GROUP BY ?s ?lbl ORDER BY DESC 3';
--      query := s1 || s2 || s3;


      if (isnull(val)  or val = '') val := '"kidehen"';
      s1 := 'sparql SELECT DISTINCT ?p ?n ((SELECT COUNT (*) WHERE {?p foaf:interest ?i . ?ps foaf:interest ?i})) ' ||
      ' ((SELECT COUNT (*) WHERE { ?p foaf:interest ?i})) ' ||
      ' WHERE { '||
      ' ?ps foaf:nick ?nick . ' ||
      ' FILTER (bif:contains (?nick, \'';
      validate_input(val);
      s2 := trim (fti_make_search_string(val), '()');
s3 := '\')) .
{ SELECT DISTINCT ?p ?psi WHERE { ?p foaf:interest ?i . ?psi foaf:interest ?i } } .  FILTER (?ps = ?psi) ?p foaf:nick ?n } ORDER BY DESC 3 LIMIT 50';
      query := concat(s1, s2, s3);
    }
  else if (smode = '9')
    {
      if (isnull(val)  or val = '') val := '"data"';

-- b3s variant:

--      if (isnull(val)  or val = '') val := '"aeon_phoenix"';
--      s1 :=
--      'sparql define input:inference \'b3s\' select ?s ?lbl count(*) where { ?s  ?p2 ?o2 .  ?o2 <http://b3s-demo.openlinksw.com/label> ?lbl . ' ||
--      ' ?s  foaf:nick ?o .  filter (bif:contains (?o, ''';

      s1 :=
      'sparql define input:inference \'virtrdf-label\' SELECT ?s ?lbl COUNT(*) WHERE { ?s  ?p2 ?o2 .  ?o2 <http://www.w3.org/2000/01/rdf-schema#label> ?lbl . ' ||
      ' ?s  foaf:nick ?o .  FILTER (bif:contains (?o, ''';
      validate_input(val);
      s2 := trim (fti_make_search_string(val), '()');
      s3 := ''')) } GROUP BY ?s ?lbl ORDER BY DESC 3';
      query := s1 || s2 || s3;

    }
  else if (smode = '10')
    {
      if (isnull(val)  or val = '') val := '"Wellington"';

      s1 :=
      'sparql define input:inference \'virtrdf-label\' SELECT ?s ?lbl COUNT(*) WHERE { ?s  ?p2 ?o2 .  ?o2 <http://www.w3.org/2000/01/rdf-schema#label> ?lbl . ' ||
      ' ?s  foaf:nick ?o .  FILTER (bif:contains (?o, ''';
      validate_input(val);
      s2 := trim (fti_make_search_string(val), '()');
      s3 := ''') && !isblank(?s) ) } GROUP BY ?s ?lbl ORDER BY DESC 3';
      query := s1 || s2 || s3;
    }
  else if (smode = '11')
    {
      if (isnull(val)  or val = '') val := '500';

      s1 :=
      'sparql SELECT ?mnf COUNT(?prd) AS ?total WHERE { ?prd gr:hasManufacturer ?mnf }' ||
      ' GROUP BY ?mnf HAVING COUNT(?prd) > ';
      validate_input(val);
      s2 := val;
      s3 := ' ORDER BY DESC 2 LIMIT 50';
      query := s1 || s2 || s3;
    }
  else if (smode = '12')
    {
      if (isnull(val)  or val = '') val := '500';

--' ?ab gr:eligibleCustomerTypes ?el . ' ||

      s1 :=
      'sparql SELECT ?xx ?ab ?bp ?b ?c bif:ceiling(?cv*100)/100.00  WHERE {' ||
      ' ?xx a gr:BusinessEntity . ' ||
      ' ?xx gr:offers ?ab . ' ||
      ' ?ab rdf:type gr:Offering . ' ||
      ' ?ab gr:hasBusinessFunction ?bp . ' ||
      ' ?ab gr:includesObject ?b . ' ||
      ' ?b rdf:type gr:TypeAndQuantityNode . ' ||
      ' ?b gr:typeOfGood ?c . ' ||
      ' ?c rdf:type gr:ProductOrServicesSomeInstancesPlaceholder . ' ||
      ' ?ab gr:hasPriceSpecification ?p . ' ||
      ' ?p gr:hasCurrencyValue ?cv . ' ||
      ' FILTER (?cv > ';
      validate_input(val);
      s2 := val;
      s3 := ') } LIMIT 10';
      query := s1 || s2 || s3;
    }
-- for now is removed from the list
--  else if (smode = '13')
--    {
--      if (isnull(val)  or val = '') val := '"Manufacturer"';
--      s1 := 'sparql SELECT COUNT(?prd) AS ?total WHERE { ?prd gr:hasManufacturer ?mnf . ' ||
--      ' ?mnf gr:legalName ?name . ' ||
--      ' FILTER( bif:contains (?name, ''';
--      validate_input(val);
--      s2 := trim (fti_make_search_string(val), '()');
--      s3 := ''')) } LIMIT 50';
--      query := concat('',s1, s2, s3,'');
--    }
  else if (smode = '13')
  {
    if (isnull(val)  or val = '') val := '2.3498';
    if (isnull(val2)  or val2 = '') val2 := '48.853';

    if (isnull(val3)  or val3 = '') val3 := '5';
    if (isnull(val4)  or val4 = '') val4 := '0.9';


    s1 := 'sparql SELECT DISTINCT ?cafe ?lat ?long ?cafename ?churchname ' ||
    ' ( bif:round(bif:st_distance (?churchgeo, ?cafegeo)) ) ' ||
    ' WHERE ' ||
    ' { ' ||
    '   ?church a lgv:place_of_worship . ' ||
    '   ?church geo:geometry ?churchgeo . ' ||
    '   ?church lgv:name ?churchname . ' ||
    '   ?cafe a lgv:cafe . ' ||
    '   ?cafe lgv:name ?cafename . ' ||
    '   ?cafe geo:geometry ?cafegeo . ' ||
    '   ?cafe geo:lat ?lat . ' ||
    '   ?cafe geo:long ?long . ' ||
    '   FILTER ( bif:st_intersects (?churchgeo, bif:st_point (';
    validate_input(val);
    validate_input(val2);
    validate_input(val3);
    s2 := concat( val, ',', val2,'),', val3);
    s3 := ')  && bif:st_intersects (?cafegeo, ?churchgeo, ';
    validate_input(val4);
    s4 := val4;
    s5 := ') ) } LIMIT 50';
    query := concat('',s1, s2, s3, s4, s5, '');
  }
  else if (smode = '14')
    {
      if (isnull(val)  or val = '') val := '52.000';

      s1 :=
      'sparql SELECT ?road ?lat ?long WHERE ' ||
      '  { ' ||
      '    { ' ||
--      '     ?services dbpprop:road ?road . ' ||
      '      ?road a yago:MotorwaysInEngland . ' ||
      '      ?services dbpprop:lat ?lat . ' ||
      '      ?services dbpprop:long ?long . ' ||
      '    } ' ||
      '    UNION ' ||
      '    { ' ||
--      '      ?services dbpprop:road ?road . ' ||
      '      ?road a yago:MotorwaysInScotland . ' ||
      '      ?services dbpprop:lat ?lat . ' ||
      '      ?services dbpprop:long ?long . ' ||
      '    } ' ||
      '    FILTER (?lat > ';
      validate_input(val);
      s2 := val;
      s3 := ') } LIMIT 50';
      query := s1 || s2 || s3;
    }
  else if (smode='15')
  {
    if (isnull(val)  or val = '') val := 'http://dbpedia.org/resource/London';
    if (isnull(val2)  or val2 = '') val2 := 'http://dbpedia.org/ontology/PopulatedPlace';
    if (isnull(val3)  or val3 = '') val3 := '10';
    s1 := 'sparql SELECT DISTINCT ?m ( bif:round(bif:st_distance (?geo, ?gm)) ) ' ||
    ' WHERE { <';
    validate_input(val);
    s2 := val;
    s3 := '> geo:geometry ?gm . ' ||
    ' ?m geo:geometry ?geo . ' ||
    ' ?m a <';
    validate_input(val2);
    s4 := val2;
    s5 := '> . FILTER (bif:st_intersects (?geo, ?gm,';
    validate_input(val3);
    s5 := concat(s5, val3, ')) } ORDER BY DESC 2 LIMIT 50');
    query := concat('',s1, s2, s3, s4, s5, '');
  }
  else if ( smode='16' )
  {
    if (isnull(val)  or val = '') val := '-80.000';
    if (isnull(val2)  or val2 = '') val2 := '-140.000';
    s1 := 'sparql SELECT DISTINCT ?s (bif:round(?lat)) AS ?lat (bif:round(?long)) AS ?long ' ||
      ' WHERE ' ||
      '   { ' ||
      --'     { ' ||
      --'       SELECT ?g ?s WHERE  ' ||
      --'         {  ' ||
      --'           graph ?g { ' ||
      --'             ?s geo:geometry ?geo }  ' ||
      --'         } ' ||
      --'       LIMIT 100  ' ||
      --'     } ' ||
      '     graph ?g { ' ||
      '       ?s geo:geometry ?geo . ' ||
      '       ?s geo:lat ?lat . ' ||
      '       ?s geo:long ?long . } ' ||
      '     FILTER (datatype (?lat) IN (xsd:integer, xsd:float, xsd:double)) . ' ||
      '     FILTER (datatype (?long) IN (xsd:integer, xsd:float, xsd:double)) . ' ||
      '    FILTER (?lat < ';
    validate_input(val);
    s2 := val;
    validate_input(val2);
    s3 := val2;
    s4 := concat(s2, ' && ?long > ', s3);
    s5 := ' ) }  LIMIT 50';
    query := s1 || s4 || s5;
  }
  else if ( smode='17' )
  {
    if (isnull(val)  or val = '') val := 'category:History_of_Wisconsin';
    if (isnull(val2)  or val2 = '') val2 := 'en';
    if (isnull(val3)  or val3 = '') val3 := 'en';
    if (isnull(val4)  or val4 = '') val4 := 'http://dbpedia.org/resource/Category:Metropolitan_areas_of_Wisconsin';

    validate_input(val);
    validate_input(val2);
    validate_input(val3);
    validate_input(val4);

    s1 := 'sparql define input:inference "skos-trans" SELECT DISTINCT ?c AS ?skos_broader ' ||
       ' ?trans AS ?skos_narrower ' ||
       ' ?dist AS ?skos_level ' ||
       ' ?m ?n ?p AS ?geo_point ' ||
       ' WHERE  ' ||
       '   { ' ||
       '     { ' ||
       '       SELECT ?c ?m ?n ?p ?trans ?dist ' ||
       '       WHERE ' ||
       '         { ' ||
       '           ?m rdfs:label ?n . ' ||
       '           ?m skos:subject ?c . ' ||
       '           ?c skos:broaderTransitive ';
   s2 := concat (val, ' . ');
   s3 := '         ?c skos:broaderTransitive ?trans ' ||
       '           OPTION ( TRANSITIVE, t_distinct, t_in (?c), t_out (?trans), t_max (3),  t_step ( ''step_no'' ) as ?dist ) .  '||
       '           ?m dbpprop:abstract ?d . ' ||
       '           ?m grs:point ?p . ' ||
       '           FILTER ( lang(?n) = "';
   s4 := concat(val2, '" ) . FILTER ( lang(?d) = "', val3, '" ) ');
   s5 := '      } ' ||
       '     } ' ||
       '     FILTER ( ?trans = <';
   s5 := concat(s5, val4, '> )  } ORDER BY ASC (?dist) ');
   query := concat('',s1, s2, s3, s4, s5, '');
  }
  else if ( smode='18' )
  {
    if (isnull(val)  or val = '') val := 'http://dbpedia.org/resource/New_York_City';
    if (isnull(val2)  or val2 = '') val2 := '20';
    if (isnull(val3)  or val3 = '') val3 := 'en';

    validate_input(val);
    validate_input(val2);
    validate_input(val3);

    s1 := 'sparql SELECT DISTINCT ?resource ?label ?location ' ||
       ' WHERE  ' ||
       '   { ' ||
       '     <';
   s2 := val;
   s3 := '> geo:geometry ?sourcegeo . ' ||
       '     ?resource geo:geometry ?location ; ' ||
       '                    rdfs:label ?label . ' ||
       '     FILTER( bif:st_intersects( ?location, ?sourcegeo, ';
   s4 := val2;
   s5 := concat(' ) ) . FILTER( lang( ?label ) = "', val3, '" ) } ');
   query := concat('', s1, s2, s3, s4, s5, '');
  }
  else if ( smode='19' )
  {
    if (isnull(val)  or val = '') val := 'http://dbpedia.org/resource/New_York_City';
    if (isnull(val2)  or val2 = '') val2 := 'http://dbpedia.org/resource/London';

    validate_input(val);
    validate_input(val2);

    s1 := 'sparql SELECT ?nylLabel ?nyl ?lnLabel ?ln (bif:round ( bif:st_distance( ?nyl, ?ln ) ) ) AS ?distanceBetweenNewYorkCityAndLondon ' ||
          ' FROM <http://dbpedia.org> ' ||
          ' WHERE ' ||
          '  { ' ||
          '    <';
    s2 := val;
    s3 := '> geo:geometry ?nyl . ' ||
         '<';
    s4 := val2;
    s5 := concaT('>  geo:geometry ?ln .  <', s2, '> rdfs:label ?nylLabel .  <', s4, '> rdfs:label ?lnLabel } ');
    query := concat('', s1, s2, s3, s4, s5, '');
  }
  else if ( smode='20' )
  {
    if (isnull(val)    or val = '') val := 'http://dbpedia.org/resource/Oxford';
    if (isnull(val2)  or val2 = '') val2 := '5';
    if (isnull(val3)  or val3 = '') val3 := 'http://dbpedia.org/property/established';
    if (isnull(val4)  or val4 = '') val4 := 'en';

    validate_input(val);
    validate_input(val2);
    validate_input(val3);
    validate_input(val4);

    s1 := 'sparql SELECT DISTINCT ?thing AS ?uri ?thingLabel AS ?name ?date AS ?established ?lat ?long  ' ||
          'WHERE ' ||
          ' { ' ||
          '   <';
    s2 := val;
    s3 := '> geo:geometry ?sourcegeo . ' ||
          ' ?resource geo:geometry ?matchgeo . ' ||
          ' ?resource geo:lat ?lat . ' ||
          ' ?resource geo:long ?long . ' ||
          ' FILTER( bif:st_intersects( ?matchgeo, ?sourcegeo, ';
    s4 := concat (val2, ' ) ) . ?thing ?somelink ?resource . ?thing <', val3);
    s5 := concat('> ?date . ?thing rdfs:label ?thingLabel . FILTER( lang( ?thingLabel ) = "', val4, '" ) } ');
    query := concat('', s1, s2, s3, s4, s5, '');
  }
  --smode > 99 is reserved for drill-down queries
  else if (smode = '1001' or smode = '104')
    {
      validate_input(val);
      query := sprintf ('sparql SELECT ?ne COUNT (*) WHERE { graph <umbel-sc> { ?s rdfs:seeAlso ?ne . }  ?s dc:creator <%s> } GROUP BY ?ne ORDER BY DESC 2', val);
    }
  else if (smode = '1002')
    {
      validate_input(val);
      s2 := element_split(val);
      s4 := trim (fti_make_search_string(val), '()');
      query := sprintf ('sparql SELECT ?s ?p ( bif:search_excerpt ( bif:vector (%s) , ?o ) ) WHERE {  graph ?g  {  ?s ?p ?o . FILTER ( bif:contains ( ?o, \'%s\' ) )  } . FILTER (?g = <%s>)   } LIMIT 10', s2, s4, val2);
    }
  else if (smode = '1003')
    {
      validate_input(val);
      s2 := element_split(val);
      s4 := trim (fti_make_search_string(val), '()');
      query := sprintf ('sparql SELECT ?title ?ne  ( bif:search_excerpt ( bif:vector (%s) , ?o ) )  WHERE {  { ?s dc:creator <%s> ; dc:title ?title ; ?p ?o . FILTER bif:contains (?o, \'%s\') } graph <umbel-sc> { ?s rdfs:seeAlso ?ne } } LIMIT 50', s2, val2, s4);
    }
  else if (smode = '1004')
    {
      validate_input(val);
      query := sprintf ('sparql SELECT ?author COUNT(*) WHERE { graph <umbel-sc> { ?s rdfs:seeAlso <%s> } { ?s dc:creator ?author . FILTER isIRI (?author) }} GROUP BY ?author ORDER BY DESC 2 LIMIT 50', val);
    }
  else if (smode = '1005')
    {
      if (val not like '"%"' and strchr (val, '@') is null)
	val := '"'||val||'"';
      query := sprintf ('sparql SELECT DISTINCT ?i WHERE {  ?ps foaf:nick %s . ?ps foaf:interest ?i . ?psi foaf:interest ?i . FILTER (?ps != ?psi)  . ?ps foaf:nick ?n } LIMIT 200', val);
    }
  else if (smode='100')
  {
-- 1  Cloud Around foaf Person, placeholder for http://myopenlink.net/dataspace/person/kidehen#this
--sparql define input:inference 'b3s'
--select count(*)
--where
--  {
--    <http://myopenlink.net/dataspace/person/kidehen#this>  ?p2 ?o2 .
--    ?o2 <http://b3s-demo.openlinksw.com/label> ?lbl .
--  }
--;
    if (isnull(val)  or val = '') val := 'http://www.w3.org/People/Berners-Lee/card#i';
    s1 := 'sparql define input:inference ''virtrdf-label'' SELECT ?lbl COUNT(*) WHERE { <';
    validate_input(val);
    s2 := val;
    s3 := '>  ?p2 ?o2 . ?o2 <http://www.w3.org/2000/01/rdf-schema#label> ?lbl .  } GROUP BY ?lbl ORDER BY DESC 2 LIMIT 50';
    query := concat('',s1, s2, s3, '');
  }
  else if (smode='101')
  {
-- -- 2 Social Connections a la LinkedIn, placeholder is sample is http://myopenlink.net/dataspace/person/kidehen#this
--sparql
--select ?o ?dist ((select count (*) where {?o foaf:knows ?xx}))
--where
--  {
--    {
--      select ?s ?o
--      where
--        {
--          ?s foaf:knows ?o
--        }
--    }
--    option (transitive, t_distinct, t_in(?s), t_out(?o), t_min (1), t_max (4), t_step ('step_no') as ?dist) .
--    filter (?s= <http://myopenlink.net/dataspace/person/kidehen#this>)
--  } order by ?dist desc 3 limit 50
--;
    if (isnull(val)  or val = '') val := 'http://www.w3.org/People/Berners-Lee/card#i';
    s1 := 'sparql SELECT ?o ?name ?dist ((SELECT COUNT (*) WHERE {?o foaf:knows ?xx})) WHERE { { SELECT ?s ?o ?name WHERE { ?s foaf:knows ?o . ?o foaf:name ?name } } OPTION (transitive, t_distinct, t_in(?s), t_out(?o), t_min (2), t_max (4), t_step (''step_no'') as ?dist) . FILTER (?s= <';
    validate_input(val);
    s2 := val;
    s3 := '> ) } ORDER BY ?dist DESC 4 LIMIT 50';
    query := concat('',s1, s2, s3, '');
  }
  else if (smode='102')
  {
---- 3 Connection Between, placeholder is http://myopenlink.net/dataspace/person/kidehen#this and text entry for the other IRI: http://www.advogato.org/person/mparaz/foaf.rdf#me
--sparql
--select ?link ?g ?step ?path
--where
--  {
--    {
--      select ?s ?o ?g
--      where
--        {
--          graph ?g {?s foaf:knows ?o }
--        }
--    }
--    option (transitive, t_distinct, t_in(?s), t_out(?o), t_no_cycles, T_shortest_only,
--       t_step (?s) as ?link, t_step ('path_id') as ?path, t_step ('step_no') as ?step, t_direction 3) .
--    filter (?s= <http://myopenlink.net/dataspace/person/kidehen#this>
--	&& ?o = <http://www.advogato.org/person/mparaz/foaf.rdf#me>)
--  } limit 20
--;

    if (isnull(val)  or val = '') val := 'http://www.w3.org/People/Berners-Lee/card#i';
    --if (isnull(val2)  or val2 = '') val2 := 'http://www.advogato.org/person/mparaz/foaf.rdf#me';
    --s1 := 'sparql select ?link ?g ?step ?path where  { { select ?s ?o ?g where { graph ?g {?s foaf:knows ?o } } } option (transitive, t_distinct, t_in(?s), t_out(?o), t_no_cycles, T_shortest_only, t_step (?s) as ?link, t_step (''path_id'') as ?path, t_step (''step_no'') as ?step, t_direction 3) . filter (?s= <';
    s1 := 'sparql define input:same-as "YES" SELECT ?g COUNT (*) WHERE { { SELECT ?s ?o ?g WHERE { graph ?g {?s foaf:knows ?o } } } OPTION (transitive, t_distinct, t_in(?s), t_out(?o), t_min (1)) .  FILTER (?s= <';
    validate_input(val);
    s2 := val;
    s3 := '>) } GROUP BY ?g ORDER BY DESC 2 LIMIT 100';
    --s3 := '> && ?o = <';
    --validate_input(val2);
    --s4 := val2;
    --s5 := '> )  } limit 20';
    query := concat(s1, s2, s3);
  }
  else if (smode='103')
  {
---- 4 placeholder is : http://myopenlink.net/dataspace/person/kidehen#this
--sparql
--select distinct ?n ((select count (*) where {?p foaf:interest ?i . ?ps foaf:interest ?i}))
--   ((select count (*) where { ?p foaf:interest ?i}))
--where {
--{select distinct ?p ?psi where {?p foaf:interest ?i . ?psi foaf:interest ?i }} .
--  filter (?psi = <http://myopenlink.net/dataspace/person/kidehen#this> && ?ps = <http://myopenlink.net/dataspace/person/kidehen#this> )
--  ?p foaf:nick ?n
--} order by desc 2 limit 50
--;
    if (isnull(val)  or val = '') val := 'http://www.w3.org/People/Berners-Lee/card#i';
    s1 := 'sparql SELECT ?n ((SELECT COUNT (*) WHERE { ?p foaf:interest ?i . ?ps foaf:interest ?i})) ((SELECT COUNT (*) WHERE { ?p foaf:interest ?i})) WHERE { { SELECT DISTINCT ?p ?psi WHERE { ?p foaf:interest ?i . ?psi foaf:interest ?i  } } . FILTER (?psi = <';
    validate_input(val);
    s2 := val;
    s3 := '> && ?ps = <';
    s4 := val;
    s5 := '> ) ?p foaf:nick ?n } ORDER BY DESC 3 LIMIT 50';
    query := concat('',s1, s2, s3, s4, s5, '');
  }
  else
  {
    query := '';
  };
}
;
