
create procedure
urilbl_ac_init_db () 
{
  declare n, n_ins, n_strange integer;
  declare o_str varchar;
  declare daq any;
  set isolation = 'committed';

  urilbl_ac_init_log ('urilbl_ac_init_db: started');
  cl_exec('registry_set (''urilbl_ac_init_status'',''1'')');

  declare exit handler for sqlstate '*' {
    urilbl_ac_init_log (sprintf ('***ERROR %s:%s', __SQL_STATE, __SQL_MESSAGE));
    cl_exec('registry_set(''urilbl_ac_init_status'',''4711'')');
    goto finished;
  };

-- XXX test that this inference graph exists a priori
-- XXX check if the unresolved literal problem still needs a workaround

  daq := daq (1);
  for (sparql 
        define output:valmode 'LONG' 
        define input:inference 'facets' 
        select ?s ?o (lang(?o)) as ?lng where { ?s virtrdf:label ?o }) do 
    {
      if (__tag of rdf_box = __tag(o)) 
	o_str := cast (o as varchar);
      else if (isstring(o) and o not like 'Unresolved literal for ID%')
	{ 
	  o_str := o;
        }
      else
	{
          n_strange := n_strange + 1;
	  goto cont;
        } 

      n_ins := n_ins + 1;

      o_str := "LEFT"(o_str, 512);

      insert soft urilbl_complete_lookup_2 option (into daq)
           (ull_label_lang, ull_label_ruined, ull_iid, ull_label) 
          values (lng, urilbl_ac_ruin_label (o_str), s, o_str);

     cont:;
      n := n + 1;
      if (mod (n, 1000000) = 0) 
        urilbl_ac_init_log (sprintf ('urilbl_ac_init_db: %d rows, %d ins, %d strange...\n', 
                                      n, n_ins, n_strange));
      if (0 = mod (n, 10000))
	{
	  daq_results (daq);
	daq := daq (1);
	  commit work;
	}
    }
  daq_results (daq);
  commit work;
  cl_exec('registry_set (''urilbl_ac_init_status'',''2'')');
 finished:;
  urilbl_ac_init_log (sprintf ('urilbl_ac_init_db: Finished. %d rows, %d ins, %d strange./n',
              n, n_ins, n_strange));
}
;
