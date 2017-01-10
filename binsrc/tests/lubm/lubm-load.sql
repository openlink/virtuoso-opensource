--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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

set timeout 120;

create procedure load_lubm (in dir any)
{
  declare arr, src, stat any;
  result_names (src, stat);
  arr := sys_dirlist (dir, 1);
--  arr := vector ('u0000_00.rdf');
  foreach (any f in arr) do
    {
      declare str any;
      if (f[0] <> '.'[0])
	{
	  str := file_to_string (dir||f);
	  DB.DBA.RDF_LOAD_RDFXML (str, 'file:///'||dir, 'lubm');
	  result (f, 'Loaded');
	}
    }
};

cl_text_index (1);
rdf_obj_ft_rule_add (null, null, 'lubm');


sparql clear graph <lubm>;
sparql clear graph <inf>;

load_lubm (server_root()||'/lubm_8000/');

vt_inc_index_db_dba_rdf_obj ();

sparql select count(*) from <lubm> where { ?x ?y ?z } ;
ECHO BOTH $IF $EQU $LAST[1] 100545 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Data loaded: " $LAST[1] " rows\n";

-- To materialize suborg in a large database:
--  log_enable (2);
--  insert soft rdf_quad (g,s,p,o)
--  select iri_to_id ('lubm', 0), "x", iri_to_id ('http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#subOrganizationOf', 0), "z" from (
--  sparql define output:valmode "LONG" prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
--  select   ?x   ?z   from <lubm> where { ?x ub:subOrganizationOf ?y . ?y ub:subOrganizationOf ?z . }) c;
--

sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
insert into graph <lubm> { ?x ub:subOrganizationOf ?z  } from <lubm> where { ?x ub:subOrganizationOf ?y . ?y ub:subOrganizationOf ?z . };

DB.DBA.TTLP (file_to_string ('inf.nt'), 'http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl', 'inf');
sparql select count(*) from <inf> where { ?x ?y ?z } ;
ECHO BOTH $IF $EQU $LAST[1] 45 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Inference loaded: " $LAST[1] " rows\n";

rdfs_rule_set ('inft', 'inf');

checkpoint;
