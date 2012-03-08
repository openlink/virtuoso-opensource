<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<!--
 -  
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2012 OpenLink Software
 -  
 -  This project is free software; you can redistribute it and/or modify it
 -  under the terms of the GNU General Public License as published by the
 -  Free Software Foundation; only version 2 of the License, dated June 1991.
 -  
 -  This program is distributed in the hope that it will be useful, but
 -  WITHOUT ANY WARRANTY; without even the implied warranty of
 -  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 -  General Public License for more details.
 -  
 -  You should have received a copy of the GNU General Public License along
 -  with this program; if not, write to the Free Software Foundation, Inc.,
 -  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 -  
 -  
-->
<?php
  $predef_queries = array (
    'dawg-bound-query-001' => 'sparql \nPREFIX  : <http://example.org/ns#>\nSELECT  ?a ?c\nFROM <http://local.virt/DAV/sparql_demo/data/data-xml/bound/data.rdf>\nWHERE\n    { ?a :b ?c . \n      OPTIONAL\n        { ?c :d ?e } . \n      FILTER (! bound(?e)) \n    }',
    'sparql-query-example-a' => 'sparql \nSELECT  ?title\nFROM <http://local.virt/DAV/sparql_demo/data/data-xml/examples/ex2-1a.rdf>\nWHERE\n    { <http://example.org/book/book1> <http://purl.org/dc/elements/1.1/title> ?title }',
    'sparql-query-example-b' => 'sparql \nSELECT  *\nFROM <http://local.virt/DAV/sparql_demo/data/data-xml/examples/ex2-2a.rdf>\nWHERE\n    { ?x ?x ?v }',
    'sparql-query-example-c' => 'sparql \nPREFIX  foaf: <http://xmlns.com/foaf/0.1/>\nSELECT  ?mbox\nFROM <http://local.virt/DAV/sparql_demo/data/data-xml/examples/ex2-3a.rdf>\nWHERE\n    { ?x foaf:name "Johnny Lee Outlaw" .\n      ?x foaf:mbox ?mbox .\n    }',
    'sparql-query-example-d' => 'sparql \nPREFIX  foaf: <http://xmlns.com/foaf/0.1/>\nSELECT  ?name ?mbox\nFROM <http://local.virt/DAV/sparql_demo/data/data-xml/examples/ex2-4a.rdf>\nWHERE\n    { ?x foaf:name ?name .\n      ?x foaf:mbox ?mbox .\n    }',
    'sparql-query-example-e' => 'sparql \nPREFIX  dc: <http://purl.org/dc/elements/1.1/>\nPREFIX  ns: <http://example.org/ns#>\nSELECT  ?title ?price\nFROM <http://local.virt/DAV/sparql_demo/data/data-xml/examples/ex3.rdf>\nWHERE\n    { ?x ns:price ?price . \n      FILTER ( ?price < 30 ) .\n      ?x dc:title ?title .\n    }',
    'OPTIONAL-FILTER' => 'sparql \nPREFIX  dc: <http://purl.org/dc/elements/1.1/>\nPREFIX  x: <http://example.org/ns#>\nSELECT  ?title ?price\nFROM <http://local.virt/DAV/sparql_demo/data/data-xml/Expr1/data-1.ttl>\nWHERE\n    { ?book dc:title ?title . \n      OPTIONAL\n        { ?book x:price ?price . \n          FILTER (?price < 15) .\n        } .\n    }',
    'OPTIONAL - Outer FILTER with BOUND' => 'sparql \nPREFIX  dc: <http://purl.org/dc/elements/1.1/>\nPREFIX  x: <http://example.org/ns#>\nSELECT  ?title ?price\nFROM <http://local.virt/DAV/sparql_demo/data/data-xml/Expr1/data-1.ttl>\nWHERE\n    { ?book dc:title ?title . \n      OPTIONAL\n        { ?book x:price ?price } . \n      FILTER ( ( ! bound(?price) ) || ( ?price < 15 ) ) .\n    }',
    'Equality 1-1' => 'sparql \nPREFIX  xsd: <http://www.w3.org/2001/XMLSchema#>\nPREFIX  : <http://example.org/things#>\nSELECT  ?x\nFROM <http://local.virt/DAV/sparql_demo/data/data-xml/ExprEquals/data-eq.ttl>\nWHERE\n    { ?x :p ?v . \n      FILTER ( ?v = 1 ) .\n    }',
    'OPTIONAL-AND' => 'sparql \nPREFIX  x: <http://example.org/ns#>\nPREFIX dc:  <http://purl.org/dc/elements/1.1/>\n\nSELECT ?title ?price\nFROM <http://local.virt/DAV/sparql_demo/data/data-xml/local-constr/data-1.ttl>\nWHERE {\n   ?book dc:title ?title .\n   OPTIONAL { ?book x:price ?price . FILTER(?price < 15) }\n}',
    'OPTIONAL - Outer AND with BOUND' => 'sparql \nPREFIX  x: <http://example.org/ns#>\nPREFIX dc:  <http://purl.org/dc/elements/1.1/>\n\nSELECT ?title ?price\nFROM <http://local.virt/DAV/sparql_demo/data/data-xml/local-constr/data-1.ttl>\nWHERE {\n   ?book dc:title ?title .\n   OPTIONAL { ?book x:price ?price . } .\n   FILTER(!bound(?price) || (?price < 15))\n}',
    'dawg-opt-query-001' => 'sparql \nPREFIX foaf: <http://xmlns.com/foaf/0.1/>\n\nSELECT ?name ?mbox\nFROM <http://local.virt/DAV/sparql_demo/data/data-xml/part1/dawg-data-01.rdf>\nWHERE\n  { ?person foaf:name ?name .\n    OPTIONAL { ?person foaf:mbox ?mbox}\n  }',
    'dawg-opt-query-002' => 'sparql \n\nPREFIX foaf: <http://xmlns.com/foaf/0.1/>\n\nSELECT ?name ?name2\nFROM <http://local.virt/DAV/sparql_demo/data/data-xml/part1/dawg-data-01.rdf>\nWHERE\n  { ?person foaf:name ?name .\n    OPTIONAL {\n      ?person foaf:knows ?p2 .\n      ?p2     foaf:name   ?name2 .\n    }\n  }',
    'regex-query-001' => 'sparql \nPREFIX  rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>\nPREFIX  ex: <http://example.com/#>\n\nSELECT ?val\nFROM <http://local.virt/DAV/sparql_demo/data/data-xml/regex/regex-data-01.rdf>\nWHERE {\n        ex:foo rdf:value ?val .\n        FILTER regex(?val, "GHI")\n}',
    'regex-query-004' => 'sparql \nPREFIX  rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>\nPREFIX  ex: <http://example.com/#>\nSELECT ?val\nFROM <http://local.virt/DAV/sparql_demo/data/data-xml/regex/regex-data-01.rdf>\nWHERE {\n        ex:foo rdf:value ?val .\n        FILTER regex(str(?val), "example\\\\.com")\n}',
    'dawg-triple-pattern-001' => 'sparql \nPREFIX : <http://example.org/data/>\n\nSELECT *\nFROM <http://local.virt/DAV/sparql_demo/data/data-xml/simple/data-01.rdf>\nWHERE { :x ?p ?q . }',
    'dawg-triple-pattern-003' => 'sparql \nSELECT *\nFROM <http://local.virt/DAV/sparql_demo/data/data-xml/simple/data-02.rdf>\nWHERE { ?a ?a ?b . }',
    'construct v-ctor sprintf' => 'sparql \nPREFIX  dc: <http://purl.org/dc/elements/1.1/>\nPREFIX  x: <http://example.org/ns#>\nCONSTRUCT { \n  ?book x:label \n  `bif:sprintf (\'%015s:%03d\', ?title, ?price)` . }\n FROM <http://local.virt/DAV/sparql_demo/data/extensions/construct/data-1.ttl>\nWHERE\n    { ?book dc:title ?title ; x:price ?price . }',
    'construct v-ctor blank node' => 'sparql \nPREFIX  dc: <http://purl.org/dc/elements/1.1/>\nPREFIX  x: <http://example.org/ns#>\nCONSTRUCT { ?book x:label [ x:title ?title ; x:price ?price ] . }\n FROM <http://local.virt/DAV/sparql_demo/data/extensions/construct/data-1.ttl>\nWHERE\n    { ?book dc:title ?title . \n      OPTIONAL\n        { ?book x:price ?price } . \n    }',
    'construct v-ctor conditional' => 'sparql \nPREFIX  dc: <http://purl.org/dc/elements/1.1/>\nPREFIX  x: <http://example.org/ns#>\nCONSTRUCT {\n  [ x:title ?title ;\n    x:price-status\n      `bif:either (bif:isnull(?price), \'unknown\', \'assigned\')` ] }\n FROM <http://local.virt/DAV/sparql_demo/data/extensions/construct/data-1.ttl>\nWHERE\n    { ?book dc:title ?title . \n      OPTIONAL\n        { ?book x:price ?price } . \n    }',
    'patterns v-pat Calculated String' => 'sparql \nPREFIX  dc: <http://purl.org/dc/elements/1.1/>\nPREFIX  x: <http://example.org/ns#>\nSELECT  ?title ?price\nFROM <http://local.virt/DAV/sparql_demo/data/extensions/patterns/data-1.ttl>\nWHERE\n    { ?book dc:title ?title ;\n        x:price ?price . \n      ?book2 dc:title `bif:concat (?title, \', College Edition\')` .\n    }',
    'patterns v-pat Calculated Field' => 'sparql \nPREFIX  dc: <http://purl.org/dc/elements/1.1/>\nPREFIX  x: <http://example.org/ns#>\nSELECT  ?title ?vatprice \nFROM <http://local.virt/DAV/sparql_demo/data/extensions/patterns/data-1.ttl>\nWHERE\n    { ?book dc:title ?title ;\n        x:price ?price ;\n        x:vat-price ?vatprice .\n      FILTER (?vatprice < bif:ceiling (?price * 1.05))\n    }',
    'patterns v-pat Calculated Number' => 'sparql \nPREFIX  dc: <http://purl.org/dc/elements/1.1/>\nPREFIX  x: <http://example.org/ns#>\nSELECT  ?title ?price\nFROM <http://local.virt/DAV/sparql_demo/data/extensions/patterns/data-1.ttl>\nWHERE\n    { ?book dc:title ?title ;\n        x:price ?price ;\n        x:vat-price ` ?price * 1.1 ` .\n    }',
    );
?>

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
	<head>
		<title>Virtuoso RDF Store - Demo</title>
		<meta name="Robots" content="index,nofollow" />
	</head>
<?php
    if(isset($_POST['q']) && $_POST['q']<>"")
      $query=stripslashes($_POST['q']);
    else
      $query="sparql select distinct ?p where { graph ?g { ?s ?p ?o } }";

      $_dsn="Local Virtuoso Tutorial RQ-S-2";
      $_user="demo";
      $_pass="demo";
?>
	<body>
		<h3>Virtuoso RDF Store - Demo</h3>
		<form id="queryForm" name="queryForm" method="post" enctype="application/x-www-form-urlencoded">
			<input type="hidden" name="run" value="1" />
			<fieldset>
				<legend>SPARQL Query</legend>
				Predefined queries:
				<select name="pre_def" onchange="this.form.q.value = this[this.selectedIndex].value">
				  <option value=""></option>
				  <?php
  				  while (list($key, $value) = each($predef_queries)) 
  				  {
  				    $value = str_replace('\n',"\n",$value);
  				    print('<option value="');
  				    print(htmlspecialchars($value));
  				    if (str_replace("\r",'',$query) == str_replace("\r",'',$value)) print('" selected="selected');
  				    print('">');
  				    print($key);
  				    print('</option>');
  				  }
				  ?>
				</select>
  			<input type="reset" value="Reset" />
				<br />
				<textarea COLS="60" ROWS="10" id="q" name="q"><?php print ($query); ?></textarea>
				<br/>
				<input type="submit" value="Run query" />
			</fieldset>
		</form>

		<pre>
<?php
    print "Connecting... ";
    $handle=odbc_connect ($_dsn, $_user, $_pass);

    if(!$handle)
    {
	    print "<p>Failure to connect to DSN [$DSN]: <br />";
	    odbc_errormsg();
    }
    else
    {
	    print "done\n";
	    $resultset=odbc_exec ($handle, "$query");
      print "Results:\n";
	    odbc_result_all($resultset, "border=1");
	    odbc_close($handle);
    }
 ?>
		</pre>
  </body>
</html>
