

create table tcomp (tc_id int primary key, tc_comp long varchar, tc_source long varchar);

create procedure tc_fill ()
{
  declare strses any;
  declare len , last_id int;
  log_enable (2, 1);
 len := 0;
 strses := string_output ();
  for select ro_id, coalesce (blob_to_string (ro_long), ro_val) as val  from rdf_obj do
      {
	http (val, strses);
	if (length (strses) > 4096)
	  {
	    declare s varchar;
	  s := string_output_string (strses);
	    http_rewrite (strses);
	    insert into tcomp values (ro_id, snappy_compress (s), s);
	  }
      }
}




create table ticomp (tc_id int primary key, tc_comp long varchar, tc_source long varchar);

create procedure tci_fill ()
{
  declare strses any;
  declare len , last_id int;
  log_enable (2, 1);
 len := 0;
 strses := string_output ();
  for select iri_id_num (ri_id) as ro_id, ri_name as val  from rdf_iri order by ri_id do
      {
	http (val, strses);
	if (length (strses) > 4096)
	  {
	    declare s varchar;
	  s := string_output_string (strses);
	    http_rewrite (strses);
	    insert into ticomp values (ro_id, snappy_compress (s), s);
	  }
      }
}







-- select count (*), sum (length (gzip_uncompress (blob_to_string (tc_comp)))), sum (length (blob_to_string (tc_source))) from tcomp
