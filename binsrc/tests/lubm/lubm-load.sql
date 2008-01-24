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

sparql clear graph <lubm>;
sparql clear graph <inf>;

load_lubm (server_root()||'/lubm_8000/');
sparql select count(*) from <lubm> where { ?x ?y ?z } ;
ECHO BOTH $IF $EQU $LAST[1] 100545 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Data loaded: " $LAST[1] " rows\n";

sparql prefix ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
insert into graph <lubm> { ?x ub:subOrganizationOf ?z  } where { ?x ub:subOrganizationOf ?y . ?y ub:subOrganizationOf ?z . };

DB.DBA.TTLP (file_to_string ('inf.nt'), 'http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl', 'inf');
sparql select count(*) from <inf> where { ?x ?y ?z } ;
ECHO BOTH $IF $EQU $LAST[1] 45 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Inference loaded: " $LAST[1] " rows\n";

rdfs_rule_set ('inft', 'inf');

