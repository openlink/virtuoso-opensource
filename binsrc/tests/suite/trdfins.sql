

create procedure rdi_quad (in s1 any array, in p1 any array, in o1 any array, in g1 any array) returns varchar 
{
  vectored;
  declare o, o2, s,p, g any array;
 s := __ro2sq (s1);
 p := __ro2sq (p1);
    o2 := __ro2sq (o1);
 o := o1;
 g := __ro2sq (g1);
  if (isiri_id (o) or 1 = __box_flags (o))
  o := sprintf ('%s\n-\n0\n', o2);
  else if (is_rdf_box (o))
    {
      declare tp, lng int;
    lng := rdf_box_lang (o2);
    tp := rdf_box_type (o2);
      if (lng <> 257)
      o := sprintf ('%.99s\n%s\n2', rdf_box_data (o2), (select rl_id from rdf_language where rl_twobyte = lng));
      else if (tp <> 257)
      o := sprintf ('%.99s\n%s\n3\n', rdf_box_data (o2), (select rdt_qname from rdf_datatype where rdt_twobyte = rdf_box_type (o2)));
      else 
      o := sprintf ('%.99s\n-\n1\n', cast (rdf_box_data (o2) as varchar));
    }
  else if (isnumeric (o2))
  o := sprintf ('%s\n-\n%d\n', cast (o2 as varchar),
    case when isinteger (o2) then 5 when isfloat (o) then 6 when isdouble (o2) then 7 else 8 end);
  else if (211 = __tag (o2))
  o := sprintf ('%s\n%s\n3\n', cast (o2 as varchar), __xsd_type (o2));
  return sprintf ('%s\n%s\n%s%s', s, p, o, g);
}


	  



