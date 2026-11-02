--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
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
--
--  GQL for Virtuoso - large statement tests
--
--  A statement much larger than the others: a literal INSERT of 2,000 nodes
--  (8,000 triples), through GQL_RUN and GQL_EXECUTE.  This script runs last
--  so the data it adds does not change the plans of the other scripts'
--  queries.  With it in place, the batch test B1 was planned through
--  RDF_QUAD's primary key and got no row: a quad-store defect reported
--  separately ("RDF_QUAD's primary key misses rows when scanned for an
--  object constant").
--
--  Run via isql: isql <host>:<port> dba dba test_gql_large.sql
--

ECHO "STARTED: GQL large statement tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

create procedure DB.DBA.GQL_LARGE_T_INSERT_TEXT (in _n integer) returns varchar
{
  declare _ses any;
  declare _i integer;
  _ses := string_output ();
  http ('INSERT ', _ses);
  for (_i := 0; _i < _n; _i := _i + 1)
    {
      if (_i > 0)
        http (', ', _ses);
      http (sprintf ('(:Review { id: ''r%d'', stars: %d, text: ''review %d'' })',
        _i, mod (_i, 5) + 1, _i), _ses);
    }
  return string_output_string (_ses);
}
;

-- SPARQL parses the triples of one GRAPH block by right recursion, and a
-- block of about 5,000 exhausts its parser stack.  Returns the number of
-- nodes written, or the error.
create procedure DB.DBA.GQL_LARGE_T_INSERT (in _via varchar) returns varchar
{
  declare _st, _msg, _g varchar;
  declare _meta, _data any;
  _g := concat ('urn:gql:large:', _via);
  exec (sprintf ('sparql clear graph <%s>', _g));
  _st := '00000'; _msg := '';
  if (_via = 'run')
    exec ('DB.DBA.GQL_RUN (?, ?)', _st, _msg, vector (DB.DBA.GQL_LARGE_T_INSERT_TEXT (2000), _g));
  else
    exec ('DB.DBA.GQL_EXECUTE (?, ?)', _st, _msg, vector (DB.DBA.GQL_LARGE_T_INSERT_TEXT (2000), _g), 10, _meta, _data);
  commit work;
  if (_st <> '00000')
    return concat (_st, ' ', subseq (_msg, 0, 100));
  return cast (length (DB.DBA.GQL_RUN ('MATCH (r:Review) RETURN r.id', _g)) as varchar);
}
;

select 0;
select DB.DBA.GQL_LARGE_T_INSERT ('run');
ECHO $IF $EQU $LAST[1] "2000" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": a 2,000-node literal INSERT runs through GQL_RUN (" $LAST[1] ")\n";

select 0;
select DB.DBA.GQL_LARGE_T_INSERT ('exec');
ECHO $IF $EQU $LAST[1] "2000" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": a 2,000-node literal INSERT runs through GQL_EXECUTE (" $LAST[1] ")\n";

ECHO "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GQL large statement tests\n";
