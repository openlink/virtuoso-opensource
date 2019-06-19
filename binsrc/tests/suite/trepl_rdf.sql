--
--  $Id: trepl_rdf.sql,v 1.1.2.3.4.3 2013/01/02 16:15:21 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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

-- SET ECHO ON;
connect;
ECHO BOTH "DSNs for subscriber: " $U{ds2} " publisher: " $U{ds1} "\n";

-- PUBLISHER
set DSN=$U{ds1};
reconnect;
ECHO BOTH "----- Reconnected to PUBLISHER " $U{ds1} ", will start replication\n";

select registry_get ('DB.DBA.RDF_REPL');

DB.DBA.RDF_REPL_START();

select registry_get ('DB.DBA.RDF_REPL');

DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/ttlp_0/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/ttlp_1/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/ttlp_mt_0/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/ttlp_mt_1/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/ttlp_mt_0_norepl/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/ttlp_mt_1_norepl/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/trig_0/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/trig_1/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/trig_mt_0/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/trig_mt_1/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/ttlp_mt_0_norepl/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/ttlp_mt_1_norepl/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/ttlp_ff_0/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/ttlp_ff_1/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/rdfxml_0/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/rdfxml_1/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/rdfxml_mt_0/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/rdfxml_mt_1/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/sparul_0/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/sparul_1/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/manip_0/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/manip_1/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/geo_0/');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/geo_1/');
checkpoint;

-- SUBSCRIBER
set DSN=$U{ds2};
reconnect;
ECHO BOTH "----- Reconnected to SUBSCRIBER " $U{ds2} ", will declare the publishing server and subscribe\n";

repl_server ('trepl_rdf_1', '127.0.0.1:$U{ds1}', '127.0.0.1:$U{ds1}');
repl_subscribe ('trepl_rdf_1', '__rdf_repl', 'dav', 'dav', 'dba', 'dba');

-- PUBLISHER
set DSN=$U{ds1};
reconnect;
ECHO BOTH "----- Reconnected to PUBLISHER " $U{ds1} ", will add RDF data by different methods\n";

DB.DBA.TTLP ('<s_ttlp_0> <p_ttlp_0> <o_ttlp_0> , "plain_ttlp_0" , 100 , "qq_ttlp_0"^^<dt_ttlp_0> , "рус_ttlp_0"@ru , [ rdf:type <t_ttlp_0> ] .', 'http://trepl_rdf/ttlp_0/', 'http://trepl_rdf/ttlp_0/');
DB.DBA.TTLP ('<s_ttlp_1> <p_ttlp_1> <o_ttlp_1> , "plain_ttlp_1" , 101 , "qq_ttlp_1"^^<dt_ttlp_1> , "рус_ttlp_1"@ru , [ rdf:type <t_ttlp_1> ] .', 'http://trepl_rdf/ttlp_1/', 'http://trepl_rdf/ttlp_1/');
DB.DBA.TTLP ('<s_ttlp_8> <p_ttlp_8> <o_ttlp_8> , "plain_ttlp_8" , 109 , "qq_ttlp_', 'http://trepl_rdf/ttlp_8/', 'http://trepl_rdf/ttlp_8/'); -- Intentionally wrong, to check the recovery
DB.DBA.TTLP ('<s_ttlp_9> <p_ttlp_9> <o_ttlp_9> , "plain_ttlp_9" , 109 , "qq_ttlp_9"^^<dt_ttlp_9> , "рус_ttlp_9"@ru , [ rdf:type <t_ttlp_9> ] .', 'http://trepl_rdf/ttlp_9/', 'http://trepl_rdf/ttlp_9/');
DB.DBA.TTLP_MT ('<s_ttlp_mt_0> <p_ttlp_mt_0> <o_ttlp_mt_0> , "plain_ttlp_mt_0" , 100 , "qq_ttlp_mt_0"^^<dt_ttlp_mt_0> , "рус_ttlp_mt_0"@ru , [ rdf:type <t_ttlp_mt_0> ] .', 'http://trepl_rdf/ttlp_mt_0_norepl/', 'http://trepl_rdf/ttlp_mt_0_norepl/', log_mode => 0);
DB.DBA.TTLP_MT ('<s_ttlp_mt_1> <p_ttlp_mt_1> <o_ttlp_mt_1> , "plain_ttlp_mt_1" , 101 , "qq_ttlp_mt_1"^^<dt_ttlp_mt_1> , "рус_ttlp_mt_1"@ru , [ rdf:type <t_ttlp_mt_1> ] .', 'http://trepl_rdf/ttlp_mt_1_norepl/', 'http://trepl_rdf/ttlp_mt_1_norepl/', log_mode => 0);
DB.DBA.TTLP_MT ('<s_ttlp_mt_9> <p_ttlp_mt_9> <o_ttlp_mt_9> , "plain_ttlp_mt_9" , 109 , "qq_ttlp_mt_9"^^<dt_ttlp_mt_9> , "рус_ttlp_mt_9"@ru , [ rdf:type <t_ttlp_mt_9> ] .', 'http://trepl_rdf/ttlp_mt_9_norepl/', 'http://trepl_rdf/ttlp_mt_9_norepl/', log_mode => 0);
DB.DBA.TTLP_MT ('<s_ttlp_mt_0> <p_ttlp_mt_0> <o_ttlp_mt_0> , "plain_ttlp_mt_0" , 100 , "qq_ttlp_mt_0"^^<dt_ttlp_mt_0> , "рус_ttlp_mt_0"@ru , [ rdf:type <t_ttlp_mt_0> ] .', 'http://trepl_rdf/ttlp_mt_0/', 'http://trepl_rdf/ttlp_mt_0/', log_mode => 1);
DB.DBA.TTLP_MT ('<s_ttlp_mt_1> <p_ttlp_mt_1> <o_ttlp_mt_1> , "plain_ttlp_mt_1" , 101 , "qq_ttlp_mt_1"^^<dt_ttlp_mt_1> , "рус_ttlp_mt_1"@ru , [ rdf:type <t_ttlp_mt_1> ] .', 'http://trepl_rdf/ttlp_mt_1/', 'http://trepl_rdf/ttlp_mt_1/', log_mode => 1);
DB.DBA.TTLP_MT ('<s_ttlp_mt_9> <p_ttlp_mt_9> <o_ttlp_mt_9> , "plain_ttlp_mt_9" , 109 , "qq_ttlp_mt_9"^^<dt_ttlp_mt_9> , "рус_ttlp_mt_9"@ru , [ rdf:type <t_ttlp_mt_9> ] .', 'http://trepl_rdf/ttlp_mt_9/', 'http://trepl_rdf/ttlp_mt_9/', log_mode => 1);

DB.DBA.TTLP ('
<http://trepl_rdf/trig_0/> { <s_trig_0> <p_trig_0> <o_trig_0> , "plain_trig_0" , 100 , "qq_trig_0"^^<dt_trig_0> , "рус_trig_0"@ru , [ rdf:type <t_trig_0> ] . }
<http://trepl_rdf/trig_1/> { <s_trig_1> <p_trig_1> <o_trig_1> , "plain_trig_1" , 101 , "qq_trig_1"^^<dt_trig_1> , "рус_trig_1"@ru , [ rdf:type <t_trig_1> ] . }
<http://trepl_rdf/trig_9/> { <s_trig_9> <p_trig_9> <o_trig_9> , "plain_trig_9" , 109 , "qq_trig_9"^^<dt_trig_9> , "рус_trig_9"@ru , [ rdf:type <t_trig_9> ] . }
', 'http://trepl_rdf/trig_XXX/', 'http://qq/', 256);
DB.DBA.TTLP_MT ('
<http://trepl_rdf/trig_mt_0_norepl/> { <s_trig_mt_0> <p_trig_mt_0> <o_trig_mt_0> , "plain_trig_mt_0" , 100 , "qq_trig_mt_0"^^<dt_trig_mt_0> , "рус_trig_mt_0"@ru , [ rdf:type <t_trig_mt_0> ] . }
<http://trepl_rdf/trig_mt_1_norepl/> { <s_trig_mt_1> <p_trig_mt_1> <o_trig_mt_1> , "plain_trig_mt_1" , 101 , "qq_trig_mt_1"^^<dt_trig_mt_1> , "рус_trig_mt_1"@ru , [ rdf:type <t_trig_mt_1> ] . }
<http://trepl_rdf/trig_mt_9_norepl/> { <s_trig_mt_9> <p_trig_mt_9> <o_trig_mt_9> , "plain_trig_mt_9" , 109 , "qq_trig_mt_9"^^<dt_trig_mt_9> , "рус_trig_mt_9"@ru , [ rdf:type <t_trig_mt_9> ] . }
', 'http://trepl_rdf/trig_mt_9_norepl/', 'http://qq/', 256, log_mode => 0);
DB.DBA.TTLP_MT ('
<http://trepl_rdf/trig_mt_0/> { <s_trig_mt_0> <p_trig_mt_0> <o_trig_mt_0> , "plain_trig_mt_0" , 100 , "qq_trig_mt_0"^^<dt_trig_mt_0> , "рус_trig_mt_0"@ru , [ rdf:type <t_trig_mt_0> ] . }
<http://trepl_rdf/trig_mt_1/> { <s_trig_mt_1> <p_trig_mt_1> <o_trig_mt_1> , "plain_trig_mt_1" , 101 , "qq_trig_mt_1"^^<dt_trig_mt_1> , "рус_trig_mt_1"@ru , [ rdf:type <t_trig_mt_1> ] . }
<http://trepl_rdf/trig_mt_9/> { <s_trig_mt_9> <p_trig_mt_9> <o_trig_mt_9> , "plain_trig_mt_9" , 109 , "qq_trig_mt_9"^^<dt_trig_mt_9> , "рус_trig_mt_9"@ru , [ rdf:type <t_trig_mt_9> ] . }
', 'http://trepl_rdf/trig_mt_9/', 'http://qq/', 256, log_mode => 1);

string_to_file ('ttlp_ff_0.ttl', '<s_ttlp_ff_0> <p_ttlp_ff_0> <o_ttlp_ff_0> , "plain_ttlp_ff_0" , 100 , "qq_ttlp_ff_0"^^<dt_ttlp_ff_0> , "рус_ttlp_ff_0"@ru , [ rdf:type <t_ttlp_ff_0> ] .', -2);
string_to_file ('ttlp_ff_1.ttl', '<s_ttlp_ff_1> <p_ttlp_ff_1> <o_ttlp_ff_1> , "plain_ttlp_ff_1" , 101 , "qq_ttlp_ff_1"^^<dt_ttlp_ff_1> , "рус_ttlp_ff_1"@ru , [ rdf:type <t_ttlp_ff_1> ] .', -2);
string_to_file ('ttlp_ff_9.ttl', '<s_ttlp_ff_9> <p_ttlp_ff_9> <o_ttlp_ff_9> , "plain_ttlp_ff_9" , 109 , "qq_ttlp_ff_9"^^<dt_ttlp_ff_9> , "рус_ttlp_ff_9"@ru , [ rdf:type <t_ttlp_ff_9> ] .', -2);
DB.DBA.TTLP_MT (file_to_string_output ('ttlp_ff_0.ttl'), 'http://trepl_rdf/ttlp_ff_0/', 'http://trepl_rdf/ttlp_ff_0/');
DB.DBA.TTLP_MT (file_to_string_output ('ttlp_ff_1.ttl'), 'http://trepl_rdf/ttlp_ff_1/', 'http://trepl_rdf/ttlp_ff_1/');
DB.DBA.TTLP_MT (file_to_string_output ('ttlp_ff_9.ttl'), 'http://trepl_rdf/ttlp_ff_9/', 'http://trepl_rdf/ttlp_ff_9/');

DB.DBA.RDF_LOAD_RDFXML ('<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="s_rdfxml_0" p="plain_rdfxml_0" />
  <rdf:Description rdf:nodeID="rdfxml_0" rdf:type="t_rdfxml_0" />
</rdf:RDF>', 'http://trepl_rdf/rdfxml_0/', 'http://trepl_rdf/rdfxml_0/' );

DB.DBA.RDF_LOAD_RDFXML ('<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="s_rdfxml_1" p="plain_rdfxml_1" />
  <rdf:Description rdf:nodeID="rdfxml_1" rdf:type="t_rdfxml_1" />
</rdf:RDF>', 'http://trepl_rdf/rdfxml_1/', 'http://trepl_rdf/rdfxml_1/' );

DB.DBA.RDF_LOAD_RDFXML ('<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="s_rdfxml_9" p="plain_rdfxml_9" />
  <rdf:Description rdf:nodeID="rdfxml_9" rdf:type="t_rdfxml_9" />
</rdf:RDF>', 'http://trepl_rdf/rdfxml_9/', 'http://trepl_rdf/rdfxml_9/' );

DB.DBA.RDF_LOAD_RDFXML_MT ('<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="s_rdfxml_mt_0" p="plain_rdfxml_mt_0" />
  <rdf:Description rdf:nodeID="rdfxml_mt_0" rdf:type="t_rdfxml_mt_0" />
</rdf:RDF>', 'http://trepl_rdf/rdfxml_mt_0/', 'http://trepl_rdf/rdfxml_mt_0/' );

DB.DBA.RDF_LOAD_RDFXML_MT ('<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="s_rdfxml_mt_1" p="plain_rdfxml_mt_1" />
  <rdf:Description rdf:nodeID="rdfxml_mt_1" rdf:type="t_rdfxml_mt_1" />
</rdf:RDF>', 'http://trepl_rdf/rdfxml_mt_1/', 'http://trepl_rdf/rdfxml_mt_1/' );

DB.DBA.RDF_LOAD_RDFXML_MT ('<?xml version="1.0"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="s_rdfxml_mt_9" p="plain_rdfxml_mt_9" />
  <rdf:Description rdf:nodeID="rdfxml_mt_9" rdf:type="t_rdfxml_mt_9" />
</rdf:RDF>', 'http://trepl_rdf/rdfxml_mt_9/', 'http://trepl_rdf/rdfxml_mt_9/' );

sparql base <http://trepl_rdf/sparul_0/> insert in <http://trepl_rdf/sparul_0/> {
  <s_sparul_0> <p_sparul_0> <o_sparul_0> , "plain_sparul_0" , 100 , "qq_sparul_0"^^<dt_sparul_0> , "\u0440\u0443\u0441_sparul_0"@ru , [ rdf:type <t_sparul_0> ] . };

sparql base <http://trepl_rdf/sparul_1/> insert in <http://trepl_rdf/sparul_1/> {
  <s_sparul_1> <p_sparul_1> <o_sparul_1> , "plain_sparul_1" , 101 , "qq_sparul_1"^^<dt_sparul_1> , "\u0440\u0443\u0441_sparul_1"@ru , [ rdf:type <t_sparul_1> ] . };

sparql base <http://trepl_rdf/sparul_9/> insert in <http://trepl_rdf/sparul_9/> {
  <s_sparul_9> <p_sparul_9> <o_sparul_9> , "plain_sparul_9" , 109 , "qq_sparul_9"^^<dt_sparul_9> , "\u0440\u0443\u0441_sparul_9"@ru , [ rdf:type <t_sparul_9> ] . };

DB.DBA.RDF_QUAD_URI ('http://trepl_rdf/manip_0/', 'http://trepl_rdf/manip_0/s_manip_0', 'http://trepl_rdf/manip_0/p_manip_0', 'http://trepl_rdf/manip_0/o_manip_0');
DB.DBA.RDF_QUAD_URI_L ('http://trepl_rdf/manip_0/', 'http://trepl_rdf/manip_0/s_manip_0', 'http://trepl_rdf/manip_0/p_manip_0', 'plain_manip_0');
DB.DBA.RDF_QUAD_URI_L_TYPED ('http://trepl_rdf/manip_0/', 'http://trepl_rdf/manip_0/s_manip_0', 'http://trepl_rdf/manip_0/p_manip_0', 'qq_manip_0', 'http://trepl_rdf/manip_0/t_manip_0', null);
DB.DBA.RDF_QUAD_URI_L_TYPED ('http://trepl_rdf/manip_0/', 'http://trepl_rdf/manip_0/s_manip_0', 'http://trepl_rdf/manip_0/p_manip_0', N'рус_manip_0', null, 'ru');

DB.DBA.RDF_QUAD_URI ('http://trepl_rdf/manip_1/', 'http://trepl_rdf/manip_1/s_manip_1', 'http://trepl_rdf/manip_1/p_manip_1', 'http://trepl_rdf/manip_1/o_manip_1');
DB.DBA.RDF_QUAD_URI_L ('http://trepl_rdf/manip_1/', 'http://trepl_rdf/manip_1/s_manip_1', 'http://trepl_rdf/manip_1/p_manip_1', 'plain_manip_1');
DB.DBA.RDF_QUAD_URI_L_TYPED ('http://trepl_rdf/manip_1/', 'http://trepl_rdf/manip_1/s_manip_1', 'http://trepl_rdf/manip_1/p_manip_1', 'qq_manip_1', 'http://trepl_rdf/manip_1/t_manip_1', null);
DB.DBA.RDF_QUAD_URI_L_TYPED ('http://trepl_rdf/manip_1/', 'http://trepl_rdf/manip_1/s_manip_1', 'http://trepl_rdf/manip_1/p_manip_1', N'рус_manip_1', null, 'ru');

DB.DBA.RDF_QUAD_URI ('http://trepl_rdf/manip_9/', 'http://trepl_rdf/manip_9/s_manip_9', 'http://trepl_rdf/manip_9/p_manip_9', 'http://trepl_rdf/manip_1/o_manip_9');
DB.DBA.RDF_QUAD_URI_L ('http://trepl_rdf/manip_9/', 'http://trepl_rdf/manip_9/s_manip_9', 'http://trepl_rdf/manip_9/p_manip_9', 'plain_manip_9');
DB.DBA.RDF_QUAD_URI_L_TYPED ('http://trepl_rdf/manip_9/', 'http://trepl_rdf/manip_9/s_manip_9', 'http://trepl_rdf/manip_9/p_manip_9', 'qq_manip_9', 'http://trepl_rdf/manip_9/t_manip_9', null);
DB.DBA.RDF_QUAD_URI_L_TYPED ('http://trepl_rdf/manip_9/', 'http://trepl_rdf/manip_9/s_manip_9', 'http://trepl_rdf/manip_9/p_manip_9', N'рус_manip_9', null, 'ru');

DB.DBA.TTLP ('@prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#> . <s_geo_0> geo:lat 45 ; geo:long 135 .', 'http://trepl_rdf/geo_0/', 'http://trepl_rdf/geo_0/');
DB.DBA.TTLP ('@prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#> . <s_geo_1> geo:lat 45 ; geo:long 135 .', 'http://trepl_rdf/geo_1/', 'http://trepl_rdf/geo_1/');
DB.DBA.TTLP ('@prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#> . <s_geo_9> geo:lat 45 ; geo:long 135 .', 'http://trepl_rdf/geo_9/', 'http://trepl_rdf/geo_9/');
DB.DBA.RDF_GEO_FILL_SINGLE ();

sparql select ?g ?s ?p ?o where { graph ?g { ?s ?p ?o } . filter (str(?g) like "http://trepl_rdf/%") } order by asc (bif:replace(bif:concat(str(?g), ' ', str(?p), ' ', str(?o)), 'nodeID://', '_:rr'));

sparql select (count(1)) where { graph ?g { ?s ?p ?o } . filter (str(?g) like "http://trepl_rdf/%") };

ECHO BOTH $IF $EQU $LAST[1] 204 "PASSED" "***FAILED";
ECHO BOTH ": "  $LAST[1] " returned, expected: 204 triples on publisher after all inserts\n";

checkpoint;

-- SUBSCRIBER
set DSN=$U{ds2};
reconnect;
ECHO BOTH "----- Reconnected to SUBSCRIBER " $U{ds2}", will sync and check what has been added\n";

commit work;

DB.DBA.RDF_REPL_SYNC ('trepl_rdf_1', 'dba', 'dba');

status ('r');

sparql select ?g ?s ?p ?o where { graph ?g { ?s ?p ?o } . filter (str(?g) like "http://trepl_rdf/%") } order by asc (bif:replace(bif:concat(str(?g), ' ', str(?p), ' ', str(?o)), 'nodeID://', '_:rr'));

sparql select (count(1)) where { graph ?g { ?s ?p ?o } . filter (str(?g) like "http://trepl_rdf/%") };

ECHO BOTH $IF $EQU $LAST[1] 92 "PASSED" "***FAILED";
ECHO BOTH ": "  $LAST[1] " returned, expected: 92 triples on subscriber after all inserts\n";

-- PUBLISHER
set DSN=$U{ds1};
reconnect;
ECHO BOTH "----- Reconnected to PUBLISHER " $U{ds1}", will delete RDF data  by different methods\n";

sparql clear graph <http://trepl_rdf/ttlp_1/> ;

sparql base <http://trepl_rdf/sparul_1/> delete from <http://trepl_rdf/sparul_1/> {
  <s_sparul_1> <p_sparul_1> <o_sparul_1> , "plain_sparul_1" , 101 , "qq_sparul_1"^^<dt_sparul_1> , "\u0440\u0443\u0441_sparul_1"@ru , ?bn .
  ?bn rdf:type <t_sparul_1> . }
from <http://trepl_rdf/sparul_1/> where { ?bn rdf:type <t_sparul_1> . };

sparql select ?g ?s ?p ?o where { graph ?g { ?s ?p ?o } . filter (str(?g) like "http://trepl_rdf/%") } order by asc (bif:replace(bif:concat(str(?g), ' ', str(?p), ' ', str(?o)), 'nodeID://', '_:rr'));

sparql select (count(1)) where { graph ?g { ?s ?p ?o } . filter (str(?g) like "http://trepl_rdf/%") };

ECHO BOTH $IF $EQU $LAST[1] 190 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " returned, expected: 190 triples on publisher after removals\n";

checkpoint;

-- SUBSCRIBER
set DSN=$U{ds2};
reconnect;
ECHO BOTH "----- Reconnected to SUBSCRIBER " $U{ds2}", will sync and check what has been deleted\n";

commit work;

DB.DBA.RDF_REPL_SYNC ('trepl_rdf_1', 'dba', 'dba');

status('r');

sparql select ?g ?s ?p ?o where { graph ?g { ?s ?p ?o } . filter (str(?g) like "http://trepl_rdf/%") } order by asc (bif:replace(bif:concat(str(?g), ' ', str(?p), ' ', str(?o)), 'nodeID://', '_:rr'));

sparql select (count(1)) where { graph ?g { ?s ?p ?o } . filter (str(?g) like "http://trepl_rdf/%") };

ECHO BOTH $IF $EQU $LAST[1] 78 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " returned, expected: 78 triples on subscriber after removals\n";

-- PUBLISHER
set DSN=$U{ds1};
reconnect;
ECHO BOTH "----- Reconnected to PUBLISHER " $U{ds1}", will declare RDB2RDF and try all procedures and triggers\n";

DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/sys');
DB.DBA.RDF_REPL_GRAPH_INS ('http://trepl_rdf/sys/user?id=5');

create table ZYZ_USERS (
    U_ID 		integer,
    U_NAME 		char (128),
    U_IS_ROLE		integer 	default 0,
    U_FULL_NAME 	char (128),
    U_E_MAIL 		char (128) 	default '',
    U_PASSWORD		char (128),
    U_GROUP 		integer,  	/* the primary group references ZYZ_USERS (U_ID), */
    U_LOGIN_TIME 	datetime,
    U_ACCOUNT_DISABLED integer 	default 1,
    U_DAV_ENABLE	integer		default 0,
    U_SQL_ENABLE	integer 	default 1,
    U_DATA		varchar, 	/* login qual */
    U_METHODS 		integer,
    U_DEF_PERMS 	char (11) 	default '110100000RR',
    U_HOME		varchar (128),
    U_PASSWORD_HOOK 	varchar,
    U_PASSWORD_HOOK_DATA varchar,
    U_GET_PASSWORD	varchar,
    U_DEF_QUAL		varchar default NULL,
    U_OPTS		long varchar,
    primary key (U_NAME)
 )
create unique index ZYZ_USERS_ID on ZYZ_USERS (U_ID)
;

 create table ZYZ_ROLE_GRANTS (
       GI_SUPER 	integer,
     	GI_SUB 		integer,
 	GI_DIRECT	integer default 1,
 	GI_GRANT	integer,
 	GI_ADMIN	integer default 0,
 	primary key 	(GI_SUPER, GI_SUB, GI_DIRECT));

delete from ZYZ_USERS;
delete from ZYZ_ROLE_GRANTS;

insert soft ZYZ_USERS select * from SYS_USERS
where (U_ID <= 6 or U_ID between 100 and 106);

insert soft ZYZ_ROLE_GRANTS select * from SYS_ROLE_GRANTS
where (GI_SUB <= 6 or GI_SUB between 100 and 106)
  and (GI_SUPER <= 6 or GI_SUPER between 100 and 106);

--sparql alter quad storage virtrdf:SyncToQuads { create virtrdf:TPCD using storage virtrdf:DefaultQuadStorage };

create function DB.DBA.RDF_DF_GRANTEE_ID_URI (in id integer)
{
  declare isrole integer;
  isrole := coalesce ((select top 1 U_IS_ROLE from DB.DBA.ZYZ_USERS where U_ID = id));
  if (isrole is null)
    return NULL;
  else if (isrole)
    return sprintf ('http://%s/sys/group?id=%d', registry_get ('URIQADefaultHost'), id);
  else
    return sprintf ('http://%s/sys/user?id=%d', registry_get ('URIQADefaultHost'), id);
}
;

grant execute on DB.DBA.RDF_DF_GRANTEE_ID_URI to SPARQL_SELECT;

create function DB.DBA.RDF_DF_GRANTEE_ID_URI_INVERSE (in id_iri varchar)
{
  declare parts any;
  parts := sprintf_inverse (id_iri, sprintf ('http://%s/sys/user?id=%%d', registry_get ('URIQADefaultHost')), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = parts[0] and not U_IS_ROLE))
        return parts[0];
    }
  parts := sprintf_inverse (id_iri, sprintf ('http://%s/sys/group?id=%%d', registry_get ('URIQADefaultHost')), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = parts[0] and U_IS_ROLE))
        return parts[0];
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_GRANTEE_ID_URI_INVERSE to SPARQL_SELECT;

create function DB.DBA.RDF_DF_MN_URI (in super integer, in sub integer) returns varchar
{
  declare super_is_role integer;
  super_is_role := coalesce ((select top 1 U_IS_ROLE from DB.DBA.ZYZ_USERS where U_ID = super));
  if (super_is_role is null)
    return NULL;
  else if (super_is_role)
    return sprintf ('http://%s/sys/mn?group=%d&role=%d', registry_get ('URIQADefaultHost'), super, sub);
  else
    return sprintf ('http://%s/sys/mn?user=%d&role=%d', registry_get ('URIQADefaultHost'), super, sub);
}
;

grant execute on DB.DBA.RDF_DF_MN_URI to SPARQL_SELECT;

create function DB.DBA.RDF_DF_MN_URI_INV_1 (in mn_iri varchar) returns integer
{
  declare parts any;
  parts := sprintf_inverse (mn_iri, sprintf ('http://%s/sys/mn?user=%%d&role=%%d', registry_get ('URIQADefaultHost')), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = parts[0] and not U_IS_ROLE))
        return parts[0];
    }
  parts := sprintf_inverse (mn_iri, sprintf ('http://%s/sys/mn?group=%%d&role=%%d', registry_get ('URIQADefaultHost')), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = parts[0] and U_IS_ROLE))
        return parts[0];
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_MN_URI_INV_1 to SPARQL_SELECT;

create function DB.DBA.RDF_DF_MN_URI_INV_2 (in mn_iri varchar) returns integer
{
  declare parts any;
  parts := sprintf_inverse (mn_iri, sprintf ('http://%s/sys/mn?user=%%d&role=%%d', registry_get ('URIQADefaultHost')), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = parts[0] and not U_IS_ROLE))
        return parts[1];
    }
  parts := sprintf_inverse (mn_iri, sprintf ('http://%s/sys/mn?group=%%d&role=%%d', registry_get ('URIQADefaultHost')), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = parts[0] and U_IS_ROLE))
        return parts[1];
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_MN_URI_INV_2 to SPARQL_SELECT;

create function DB.DBA.RDF_DF_GRANTEE_ID_LIT (in id integer)
{
  declare isrole integer;
  isrole := coalesce ((select top 1 U_IS_ROLE from DB.DBA.ZYZ_USERS where U_ID = id));
  if (isrole is null)
    return NULL;
  else if (isrole)
    return sprintf ('lit-%s/sys/group?id=%d', registry_get ('URIQADefaultHost'), id);
  else
    return sprintf ('lit-%s/sys/user?id=%d', registry_get ('URIQADefaultHost'), id);
}
;

grant execute on DB.DBA.RDF_DF_GRANTEE_ID_LIT to SPARQL_SELECT;

create function DB.DBA.RDF_DF_GRANTEE_ID_LIT_INVERSE (in id_lit varchar)
{
  declare parts any;
  parts := sprintf_inverse (id_lit, sprintf ('lit-%s/sys/user?id=%%d', registry_get ('URIQADefaultHost')), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = parts[0] and not U_IS_ROLE))
        return parts[0];
    }
  parts := sprintf_inverse (id_lit, sprintf ('lit-%s/sys/group?id=%%d', registry_get ('URIQADefaultHost')), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = parts[0] and U_IS_ROLE))
        return parts[0];
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_GRANTEE_ID_LIT_INVERSE to SPARQL_SELECT;

create function DB.DBA.RDF_DF_MN_LIT (in super integer, in sub integer) returns varchar
{
  declare super_is_role integer;
  super_is_role := coalesce ((select top 1 U_IS_ROLE from DB.DBA.ZYZ_USERS where U_ID = super));
  if (super_is_role is null)
    return NULL;
  if (super_is_role)
    return sprintf ('lit-%s/sys/mn?group=%d&role=%d', registry_get ('URIQADefaultHost'), super, sub);
  else
    return sprintf ('lit-%s/sys/mn?user=%d&role=%d', registry_get ('URIQADefaultHost'), super, sub);
}
;

grant execute on DB.DBA.RDF_DF_MN_LIT to SPARQL_SELECT;

create function DB.DBA.RDF_DF_MN_LIT_INV_1 (in mn_lit varchar) returns integer
{
  declare parts any;
  parts := sprintf_inverse (mn_lit, sprintf ('lit-%s/sys/mn?user=%%d&role=%%d', registry_get ('URIQADefaultHost')), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = parts[0] and not U_IS_ROLE))
        return parts[0];
    }
  parts := sprintf_inverse (mn_lit, sprintf ('lit-%s/sys/mn?group=%%d&role=%%d', registry_get ('URIQADefaultHost')), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = parts[0] and U_IS_ROLE))
        return parts[0];
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_MN_LIT_INV_1 to SPARQL_SELECT;

create function DB.DBA.RDF_DF_MN_LIT_INV_2 (in mn_lit varchar) returns integer
{
  declare parts any;
  parts := sprintf_inverse (mn_lit, sprintf ('lit-%s/sys/mn?user=%%d&role=%%d', registry_get ('URIQADefaultHost')), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = parts[0] and not U_IS_ROLE))
        return parts[1];
    }
  parts := sprintf_inverse (mn_lit, sprintf ('lit-%s/sys/mn?group=%%d&role=%%d', registry_get ('URIQADefaultHost')), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = parts[0] and U_IS_ROLE))
        return parts[1];
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_MN_LIT_INV_2 to SPARQL_SELECT;

create function DB.DBA.RDF_DF_GRANTEE_ID_NUM (in id integer)
{
  declare isrole integer;
  isrole := coalesce ((select top 1 U_IS_ROLE from DB.DBA.ZYZ_USERS where U_ID = id));
  if (isrole is null)
    return NULL;
  else if (isrole)
    return 1000+id;
  else
    return 500+id;
}
;

grant execute on DB.DBA.RDF_DF_GRANTEE_ID_NUM to SPARQL_SELECT;

create function DB.DBA.RDF_DF_GRANTEE_ID_NUM_INVERSE (in id_num integer)
{
  declare parts any;
  if (not isinteger (id_num))
    return NULL;
  if ((500 <= id_num) and (id_num < 1000))
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = id_num-500 and not U_IS_ROLE))
        return id_num-500;
    }
  else if ((1000 <= id_num) and (id_num < 2000))
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = id_num-1000 and U_IS_ROLE))
        return id_num-1000;
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_GRANTEE_ID_NUM_INVERSE to SPARQL_SELECT;

create function DB.DBA.RDF_DF_MN_NUM (in super integer, in sub integer) returns integer
{
  declare super_is_role integer;
  super_is_role := coalesce ((select top 1 U_IS_ROLE from DB.DBA.ZYZ_USERS where U_ID = super));
  if (super_is_role is null)
    return NULL;
  else if (super_is_role)
    return 1000+super + 10000 * (1000+sub);
  else
    return 500+super + 10000 * (1000+sub);
}
;

grant execute on DB.DBA.RDF_DF_MN_NUM to SPARQL_SELECT;

create function DB.DBA.RDF_DF_MN_NUM_INV_1 (in mn_num integer) returns integer
{
  declare super, sub integer;
  if (not isinteger (mn_num))
    return NULL;
  super := mod (mn_num, 10000);
  sub := mn_num / 10000;
  if ((500 <= super) and (super < 1000))
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = super-500 and not U_IS_ROLE))
        return super-500;
    }
  else if ((1000 <= super) and (super < 2000))
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = super-1000 and U_IS_ROLE))
        return super-1000;
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_MN_NUM_INV_1 to SPARQL_SELECT;

create function DB.DBA.RDF_DF_MN_NUM_INV_2 (in mn_num integer) returns integer
{
  declare super, sub integer;
  if (not isinteger (mn_num))
    return NULL;
  super := mod (mn_num, 10000);
  sub := mn_num / 10000;
  if ((500 <= super) and (super < 1000))
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = super-500 and not U_IS_ROLE))
        return sub-1000;
    }
  else if ((1000 <= super) and (super < 2000))
    {
      if (exists (select top 1 1 from DB.DBA.ZYZ_USERS where U_ID = super-1000 and U_IS_ROLE))
        return sub-1000;
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_MN_NUM_INV_2 to SPARQL_SELECT;

sparql drop quad map graph iri("http://trepl_rdf/sys");
sparql drop quad map virtrdf:SysUsers;
sparql create quad storage virtrdf:sys { };

sparql drop quad storage virtrdf:sys;

DB.DBA.RDF_QM_END_ALTER_QUAD_STORAGE ( UNAME'http://www.openlinksw.com/schemas/virtrdf#sys' );

sparql
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
drop quad map graph iri("http://trepl_rdf/sys") .
create iri class oplsioc:user_iri  "http://trepl_rdf/sys/user?id=%d" (in uid integer not null) .
create iri class oplsioc:user_name_iri  "http://trepl_rdf/sys/user?name=%U" (in uname varchar not null) .
create iri class oplsioc:grp_iri "http://trepl_rdf/sys/group?id=%d" (in gid integer not null) .
create iri class oplsioc:grp_name_iri "http://trepl_rdf/sys/group?name=%U" (in gname varchar not null) .
create iri class oplsioc:membership_iri "http://trepl_rdf/sys/membersip?super=%d&sub=%d" (in super integer not null, in sub integer not null) .
create iri class oplsioc:membership_names_iri "http://trepl_rdf/sys/membersip?supername=%U&subname=%U" (in super varchar not null, in sub varchar not null) .
create iri class oplsioc:dav_iri "http://trepl_rdf/sys/%s" (in path varchar) .
create iri class oplsioc:grantee_iri using
  function DB.DBA.RDF_DF_GRANTEE_ID_URI (in id integer) returns varchar ,
  function DB.DBA.RDF_DF_GRANTEE_ID_URI_INVERSE (in id_iri varchar) returns integer
  option ( bijection ,
    returns	"http://trepl_rdf/sys/group?id=%d"
    union	"http://trepl_rdf/sys/user?id=%d" ) .
make oplsioc:user_iri subclass of oplsioc:grantee_iri .
make oplsioc:grp_iri subclass of oplsioc:grantee_iri .
create iri class oplsioc:mn_iri using
  function DB.DBA.RDF_DF_MN_URI (in super integer, in sub integer) returns varchar ,
  function DB.DBA.RDF_DF_MN_URI_INV_1 (in mn_iri varchar) returns integer ,
  function DB.DBA.RDF_DF_MN_URI_INV_2 (in mn_iri varchar) returns integer
  option ( bijection ,
    returns	"http://trepl_rdf/sys/mn?group=%d&role=%d"
    union	"http://trepl_rdf/sys/mn?user=%d&role=%d" ) .

create literal class oplsioc:grantee_lit using
  function DB.DBA.RDF_DF_GRANTEE_ID_LIT (in id integer) returns varchar ,
  function DB.DBA.RDF_DF_GRANTEE_ID_LIT_INVERSE (in id_iri varchar) returns integer
  option (bijection) .
create literal class oplsioc:grantee_num using
  function DB.DBA.RDF_DF_GRANTEE_ID_NUM (in id integer) returns integer ,
  function DB.DBA.RDF_DF_GRANTEE_ID_NUM_INVERSE (in id_num integer) returns integer
  option (bijection, datatype xsd:integer) .
create literal class oplsioc:mn_lit using
  function DB.DBA.RDF_DF_MN_LIT (in super integer, in sub integer) returns varchar ,
  function DB.DBA.RDF_DF_MN_LIT_INV_1 (in mn_lit varchar) returns integer ,
  function DB.DBA.RDF_DF_MN_LIT_INV_2 (in mn_lit varchar) returns integer
  option (bijection) .
create literal class oplsioc:mn_num using
  function DB.DBA.RDF_DF_MN_NUM (in super integer, in sub integer) returns integer ,
  function DB.DBA.RDF_DF_MN_NUM_INV_1 (in mn_lit integer) returns integer ,
  function DB.DBA.RDF_DF_MN_NUM_INV_2 (in mn_lit integer) returns integer
  option (bijection, datatype xsd:integer) .
;

sparql
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
create quad storage virtrdf:sys
from DB.DBA.ZYZ_USERS as user where (^{user.}^.U_IS_ROLE = 0)
from DB.DBA.ZYZ_USERS as grp where (^{grp.}^.U_IS_ROLE = 1)
from DB.DBA.ZYZ_USERS as account
from DB.DBA.ZYZ_USERS as active_user where (^{active_user.}^.U_IS_ROLE = 0) where (^{active_user.}^.U_ACCOUNT_DISABLED = 0)
from DB.DBA.ZYZ_USERS as active_grp where (^{active_grp.}^.U_IS_ROLE = 1) where (^{active_grp.}^.U_ACCOUNT_DISABLED = 0)
from DB.DBA.ZYZ_USERS as active_account where (^{active_account.}^.U_ACCOUNT_DISABLED = 0)
from DB.DBA.ZYZ_ROLE_GRANTS as role_grant
  where (^{role_grant.}^.GI_SUPER = ^{account.}^.U_ID)
  where (^{role_grant.}^.GI_SUB = ^{grp.}^.U_ID)
  where (^{role_grant.}^.GI_SUPER = ^{user.}^.U_ID)
  where (^{role_grant.}^.GI_SUPER = ^{active_user.}^.U_ID)
  where (^{role_grant.}^.GI_SUPER = ^{active_grp.}^.U_ID)
  where (^{role_grant.}^.GI_SUB = ^{active_grp.}^.U_ID)
from DB.DBA.ZYZ_ROLE_GRANTS as super_role_grant
  where (^{super_role_grant.}^.GI_SUB = ^{role_grant.}^.GI_SUPER)
  {
    create virtrdf:SysUsers-p as graph oplsioc:user_iri (user.U_ID) option (soft exclusive)
      {
        oplsioc:graph-owner
            a sioc:user
                    as virtrdf:SysUserType-User-p ;
            sioc:email user.U_E_MAIL
                    as virtrdf:SysUsersEMail-User-p ;
            sioc:login user.U_NAME
                    as virtrdf:SysUsersName-User-p ;
            oplsioc:login user.U_NAME
                    as virtrdf:SysUsersName-User1-p ;
            oplsioc:login user.U_NAME
                    as virtrdf:SysUsersName-User1-p-dupe ;
            oplsioc:home oplsioc:dav_iri (user.U_HOME) where (^{user.}^.U_DAV_ENABLE = 1)
                    as virtrdf:SysUsersHome-p ;
            oplsioc:name user.U_FULL_NAME
                    as virtrdf:SysUsersFullName-p .
      } .
    create virtrdf:SysUsers as graph iri ("http://trepl_rdf/sys") option (exclusive)
      {
        oplsioc:user_iri (active_user.U_ID)
            a oplsioc:active-user
                    as virtrdf:SysUserType-ActiveUser .
        oplsioc:user_iri (user.U_ID)
            a sioc:user
                    as virtrdf:SysUserType-User ;
            sioc:email user.U_E_MAIL
                    as virtrdf:SysUsersEMail-User ;
            sioc:login user.U_NAME
                    as virtrdf:SysUsersName-User ;
            oplsioc:login user.U_NAME
                    as virtrdf:SysUsersName-User1 ;
            oplsioc:login user.U_NAME
                    as virtrdf:SysUsersName-User1-dupe ;
            oplsioc:home oplsioc:dav_iri (user.U_HOME) where (^{user.}^.U_DAV_ENABLE = 1)
                    as virtrdf:SysUsersHome ;
            oplsioc:name user.U_FULL_NAME
                    as virtrdf:SysUsersFullName .
        oplsioc:user_name_iri (user.U_NAME)
            oplsioc:subname-of-supername oplsioc:grp_name_iri (grp.U_NAME) option (using role_grant)
		    as virtrdf:SysUsers-subname-of-supername .
        oplsioc:grp_iri (active_grp.U_ID)
            a oplsioc:active-role
                    as virtrdf:SysUserType-ActiveRole .
        oplsioc:grp_iri (grp.U_ID)
            a sioc:role
                    as virtrdf:SysUserType-Role ;
            oplsioc:login grp.U_NAME
                    as virtrdf:SysUsersName-Role ;
            oplsioc:name grp.U_FULL_NAME
                    as virtrdf:SysUsersFullName-Role .
        oplsioc:grp_iri (role_grant.GI_SUB)
            sioc:has_member oplsioc:grantee_iri (role_grant.GI_SUPER)
                    as virtrdf:SysRoleGrantsHasMember ;
            oplsioc:grp_of_membership
                oplsioc:membership_iri (role_grant.GI_SUPER, role_grant.GI_SUB)
                    as virtrdf:SysRoleGrantsGroupOfMembership .
        oplsioc:grantee_iri (role_grant.GI_SUPER)
            sioc:has_function oplsioc:grp_iri (role_grant.GI_SUB)
                    as virtrdf:SysRoleGrantsHasFunction ;
            oplsioc:member_of
                oplsioc:membership_iri (role_grant.GI_SUPER, role_grant.GI_SUB)
                    as virtrdf:SysRoleGrantsMemberOfMembership .
        oplsioc:membership_iri (role_grant.GI_SUPER, role_grant.GI_SUB)
            a oplsioc:membership as virtrdf:SysRoleGrantType-Membership;
            oplsioc:is_direct role_grant.GI_DIRECT
                    as virtrdf:SysRoleGrantsMembershipIsDirect ;
            rdf:type oplsioc:grant
                    as virtrdf:SysRoleGrantsTypeMembership .
        oplsioc:membership_iri (super_role_grant.GI_SUPER, role_grant.GI_SUB)
            a oplsioc:submembership as virtrdf:SysRoleGrantType-Submembership.
        oplsioc:mn_iri (role_grant.GI_SUPER, role_grant.GI_SUB)
            a oplsioc:mn as virtrdf:SysRoleGrantType-MN.
        oplsioc:grantee_iri (account.U_ID)
            <grantee-lit> oplsioc:grantee_lit (account.U_ID) as virtrdf:SysUsers-grantee_lit ;
            <grantee-num> oplsioc:grantee_num (account.U_ID) as virtrdf:SysUsers-grantee_num .
        oplsioc:mn_iri (role_grant.GI_SUPER, role_grant.GI_SUB)
            <mn-lit> oplsioc:mn_lit (role_grant.GI_SUPER, role_grant.GI_SUB) as virtrdf:SysRoleGrants-mn_lit ;
            <mn-num> oplsioc:mn_num (role_grant.GI_SUPER, role_grant.GI_SUB) as virtrdf:SysRoleGrants-mn_num .
      } }
;

--sparql alter quad storage virtrdf:SyncToQuads { create virtrdf:TPCD using storage virtrdf:DefaultQuadStorage };
sparql alter quad storage virtrdf:SyncToQuads { create virtrdf:SysUsers using storage virtrdf:sys };
sparql alter quad storage virtrdf:SyncToQuads { create virtrdf:SysUsers-p using storage virtrdf:sys };

create procedure codegen_for_table (in tbl varchar)
{
  declare ctr integer;
  declare outs any;
  declare stat, msg varchar;
  outs := vector (null, null, null, null, null);
  for (ctr := 0; ctr <= 4; ctr := ctr+1 )
    {
      outs[ctr] := sparql_rdb2rdf_codegen (tbl, ctr);
      if (__tag of vector = __tag (outs[ctr]))
        {
           string_to_file (sprintf ('Rdb2Rdf.%s.%d.sql', tbl, ctr), string_output_string (outs[ctr][0]) || '\n;\n', -2);
           string_to_file (sprintf ('Rdb2Rdf.%s.%dp.sql', tbl, ctr), string_output_string (outs[ctr][1]) || '\n;\n', -2);
        }
      else
        string_to_file (sprintf ('Rdb2Rdf.%s.%d.sql', tbl, ctr), string_output_string (outs[ctr]) || '\n;\n', -2);
    }
  for (ctr := 1; ctr <= 4; ctr := ctr+1 )
    {
      if (__tag of vector = __tag (outs[ctr]))
        {
          stat := '00000';
          msg := '';
          exec (string_output_string (outs[ctr][0]), stat, msg);
          if ('00000' <> stat)
            signal (stat, sprintf ('codegen_for_table, ctr %d, 1/2', ctr) || msg);
          string_to_file (sprintf ('Rdb2Rdf.%s.%d.sql', tbl, ctr), '\n-----8<----- ' || stat || ' ' || msg, -1);
          stat := '00000';
          msg := '';
          exec (string_output_string (outs[ctr][1]), stat, msg);
          if ('00000' <> stat)
            signal (stat, sprintf ('codegen_for_table, ctr %d, 2/2', ctr) || msg);
          string_to_file (sprintf ('Rdb2Rdf.%s.%dp.sql', tbl, ctr), '\n-----8<----- ' || stat || ' ' || msg, -1);
        }
      else
        {
          stat := '00000';
          msg := '';
          exec (string_output_string (outs[ctr]), stat, msg);
          if ('00000' <> stat)
            signal (stat, sprintf ('codegen_for_table, ctr %d, 1/1', ctr) || msg);
          string_to_file (sprintf ('Rdb2Rdf.%s.%d.sql', tbl, ctr), '\n-----8<----- ' || stat || ' ' || msg, -1);
        }
    }
}
;

codegen_for_table ('DB.DBA.ZYZ_USERS');
codegen_for_table ('DB.DBA.ZYZ_ROLE_GRANTS');

sparql clear graph <http://trepl_rdf/sys>;
DB.DBA.RDF_OBJ_FT_RULE_ADD ('http://trepl_rdf/sys', null, 'Rdb2Rdf.sql');
DB.DBA.RDF_OBJ_FT_RULE_ADD ('http://trepl_rdf/sys/user?id=5', null, 'Rdb2Rdf.sql');
DB.DBA.RDF_OBJ_FT_RULE_ADD ('http://trepl_rdf/sys/user?id=1001', null, 'Rdb2Rdf.sql');
DB.DBA.RDF_OBJ_FT_RULE_ADD ('http://trepl_rdf/sys/user?id=1002', null, 'Rdb2Rdf.sql');
DB.DBA."RDB2RDF_FILL__DB~DBA~ZYZ_USERS" (3);
DB.DBA."RDB2RDF_FILL__DB~DBA~ZYZ_ROLE_GRANTS" (3);


insert into ZYZ_USERS (U_ID, U_NAME) values (1001, 'u1001');
insert into ZYZ_USERS (U_ID, U_NAME) values (1002, 'u1002');
insert into ZYZ_USERS (U_ID, U_NAME) values (1003, 'u1003');
insert into ZYZ_USERS (U_ID, U_NAME) values (1011, 'u1011');
insert into ZYZ_USERS (U_ID, U_NAME) values (1012, 'u1012');
insert into ZYZ_USERS (U_ID, U_NAME) values (1013, 'u1013');
sparql describe <http://trepl_rdf/sys/user?id=1001>;
DB.DBA.VT_INC_INDEX_DB_DBA_RDF_OBJ();
sparql select * from <http://trepl_rdf/sys> where { ?s ?p ?o . ?o bif:contains "Administrator" } ;
sparql describe ?s from <http://trepl_rdf/sys> where { ?s ?p ?o . ?o bif:contains "Administrator" };
sparql select * from <http://trepl_rdf/sys> where { ?s ?p ?o . ?o bif:contains "nobody" } ;
sparql describe ?s from <http://trepl_rdf/sys/user?id=5> where { ?s ?p ?o . ?o bif:contains "nobody" };
update ZYZ_USERS set U_FULL_NAME = replace (U_FULL_NAME, 'Administrator', 'Adm') where U_FULL_NAME like '%Administrator%';
DB.DBA.VT_INC_INDEX_DB_DBA_RDF_OBJ();
sparql select * from <http://trepl_rdf/sys> where { ?s ?p ?o . ?o bif:contains "Administrator" } ;
sparql select * from <http://trepl_rdf/sys> where { ?s ?p ?o . ?o bif:contains "Adm" } ;

update ZYZ_USERS set U_E_MAIL='u1001@qq' where U_ID=1001;
update ZYZ_USERS set U_E_MAIL='u1002@qq' where U_ID=1002;
update ZYZ_USERS set U_E_MAIL='u1011@qq' where U_ID=1011;
update ZYZ_USERS set U_E_MAIL='u1012@qq' where U_ID=1012;
update ZYZ_USERS set U_NAME='u1003_new' where U_ID=1003;
update ZYZ_USERS set U_NAME='u1013_new' where U_ID=1013;
delete from ZYZ_USERS where U_ID=1002;
delete from ZYZ_USERS where U_ID=1012;

select top 5 __ro2sq("mapg"), __ro2sq("maps"), __ro2sq("mapp"), __ro2sq("mapo")
from (sparql define output:valmode "LONG" define input:storage virtrdf:sys select * where { graph ?mapg { ?maps ?mapp ?mapo }}) as map
where not exists (sparql select (1) where { graph ?:mapg { ?:maps ?:mapp ?:mapo }})
;

select top 5 __ro2sq("phys"), __ro2sq("phyp"), __ro2sq("phyo")
from (sparql define output:valmode "LONG" select * from <http://trepl_rdf/sys> where { ?phys ?phyp ?phyo }) as phy
where not exists (sparql define input:storage virtrdf:sys select (1) from <http://trepl_rdf/sys> where { ?:phys ?:phyp ?:phyo })
;

select top 5 __ro2sq("phys"), __ro2sq("phyp"), __ro2sq("phyo")
from (sparql define output:valmode "LONG" select * from <http://trepl_rdf/sys/user?id=5> where { ?phys ?phyp ?phyo }) as phy
where not exists (sparql define input:storage virtrdf:sys select (1) from <http://trepl_rdf/sys/user?id=5> where { ?:phys ?:phyp ?:phyo })
;

select top 5 __ro2sq("phys"), __ro2sq("phyp"), __ro2sq("phyo")
from (sparql define output:valmode "LONG" select * from <http://trepl_rdf/sys> where { ?phys ?phyp ?phyo }) as phy
where not exists (sparql define input:storage virtrdf:sys select (1) from <http://trepl_rdf/sys> where { ?ms ?mp ?mo . filter (str(?ms) = str(?:phys) && str(?mp) = str(?:phyp) && str(?mo) = str(?:phyo)) })
;

select top 5 __ro2sq("phys"), __ro2sq("phyp"), __ro2sq("phyo")
from (sparql define output:valmode "LONG" select * from <http://trepl_rdf/sys/user?id=5> where { ?phys ?phyp ?phyo }) as phy
where not exists (sparql define input:storage virtrdf:sys select (1) from <http://trepl_rdf/sys/user?id=5> where { ?ms ?mp ?mo . filter (str(?ms) = str(?:phys) && str(?mp) = str(?:phyp) && str(?mo) = str(?:phyo)) })
;

sparql clear graph <http://trepl_rdf/sys_copy>;
sparql define input:storage virtrdf:sys insert in <http://trepl_rdf/sys_copy> { ?maps ?mapp ?mapo } where { ?maps ?mapp ?mapo }
;

sparql select ?s ?p ?o where { graph <http://trepl_rdf/sys> { ?s ?p ?o } optional { graph <http://trepl_rdf/sys_copy> { ?s2 ?p ?o . filter (?s2 = ?s0) } } . filter (!bound(?s2)) };
sparql select ?s ?p ?o where { graph <http://trepl_rdf/sys_copy> { ?s ?p ?o } optional { graph <http://trepl_rdf/sys> { ?s2 ?p ?o . filter (?s2 = ?s0) } } . filter (!bound(?s2)) };

sparql select (count(1)) from <http://trepl_rdf/sys> where { ?s ?p ?o };

ECHO BOTH $IF $EQU $LAST[1] 157 "PASSED" "***FAILED";
ECHO BOTH ": "  $LAST[1] " returned, expected: 157 triples in http://trepl_rdf/sys on publisher after all rdb2rdf operations\n";

sparql select (count(1)) from <http://trepl_rdf/sys/user?id=5> where { ?s ?p ?o };

ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": "  $LAST[1] " returned, expected: 4 triples in default http://trepl_rdf/sys/user?id=5 on publisher after all rdb2rdf operations\n";

sparql select (count(1)) where { graph <http://trepl_rdf/sys/user?id=5> { ?s ?p ?o }};

ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": "  $LAST[1] " returned, expected: 4 triples in named http://trepl_rdf/sys/user?id=5 on publisher after all rdb2rdf operations\n";

checkpoint;

-- SUBSCRIBER
set DSN=$U{ds2};
reconnect;
ECHO BOTH "----- Reconnected to SUBSCRIBER " $U{ds2}", will sync and check what has been made by replication inside RDB2RDF triggers\n";

commit work;

DB.DBA.RDF_REPL_SYNC ('trepl_rdf_1', 'dba', 'dba');

status('r');

sparql select (count(1)) from <http://trepl_rdf/sys> where { ?s ?p ?o };

ECHO BOTH $IF $EQU $LAST[1] 175 "PASSED" "***FAILED";
ECHO BOTH ": "  $LAST[1] " returned, expected: 175 triples in http://trepl_rdf/sys on subscriber after all rdb2rdf operations\n";

sparql select (count(1)) from <http://trepl_rdf/sys/user?id=5> where { ?s ?p ?o };

ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": "  $LAST[1] " returned, expected: 4 triples in default http://trepl_rdf/sys/user?id=5 on subscriber after all rdb2rdf operations\n";

sparql select (count(1)) where { graph <http://trepl_rdf/sys/user?id=5> { ?s ?p ?o }};

ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": "  $LAST[1] " returned, expected: 4 triples in named http://trepl_rdf/sys/user?id=5 on subscriber after all rdb2rdf operations\n";
