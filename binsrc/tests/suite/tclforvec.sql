
-- cluster for vectored test 


echo both "For vectored test\n";


ttlp ('<g1s> <qq> 1234 .' , '', 'fvg1');
ttlp ('<g2s> <qq> 1234 .' , '', 'fvg2');
ttlp ('<g3s> <qq> 1234 .' , '', 'fvg3');

create procedure ff (in gs any)
{
  declare ret any;
  for vectored (in i any := gs, out ret := r) {
      declare r any;
    r := __ro2sq ((select s from rdf_quad where g = iri_to_id (i)));
    }
  return ret;
}

select ff (vector ('fvg1', 'fvg2', 'fvg3', 'fvg4'))[1];
echo both $if $equ $last[1] g2s "PASSED" "***FAILED";
echo both ": Found g2\n";


select ff (vector ('fvg1', 'fvg2', 'fvg3', 'fvg4'))[3];
echo both $if $equ $last[1] NULL "PASSED" "***FAILED";
echo both ": Missing g4\n";

rdf_clear_graphs_c (vector ('fvg1', 'fvg2', 'fvg3', 'fvg4'));

select ff (vector ('fvg1', 'fvg2', 'fvg3', 'fvg4'))[1];
echo both $if $equ $last[1] NULL "PASSED" "***FAILED";
echo both ": Deleted g2\n";


