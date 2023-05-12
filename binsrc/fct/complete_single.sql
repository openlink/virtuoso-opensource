
create procedure
urilbl_ac_init_db ()
{
  declare n, n_ins, n_strange integer;
  declare o_str varchar;
  set isolation = 'committed';

  urilbl_ac_init_log ('urilbl_ac_init_db: started');
  cl_exec('registry_set (''urilbl_ac_init_status'',''1'')');

  declare exit handler for sqlstate '*' {
    urilbl_ac_init_log (sprintf ('***ERROR %s:%s', __SQL_STATE, __SQL_MESSAGE));
    cl_exec('registry_set(''urilbl_ac_init_status'',''4711'')');
    goto finished;
  };

  for (sparql
        define output:valmode 'LONG'
        define input:inference 'facets'
        select ?s ?o where { ?s virtrdf:label ?o }) do
    {
      declare lng, id int;
      lng := 257;
      if (__tag of rdf_box = __tag(o))
        {
	  o_str := rdf_box_data (o);
	  if (isstring (o_str))
	    o_str := charset_recode (o_str, 'UTF-8', '_WIDE_');
	  else
	    o_str := cast (o_str as varchar);
	  lng := rdf_box_lang (o);
	  id := rdf_box_ro_id (o);
	}
      else
	{
          n_strange := n_strange + 1;
	  goto cont;
        }

      if (not isstring (o_str) and not iswidestring (o_str))
        goto cont;

      n_ins := n_ins + 1;

      o_str := "LEFT"(o_str, 512);

      insert soft rdf_label (rl_o, rl_ro_id, rl_text, rl_lang) values (o, id, urilbl_ac_ruin_label (o_str), lng);

     cont:;
      n := n + 1;
      if (mod (n, 1000000) = 0)
        urilbl_ac_init_log (sprintf ('urilbl_ac_init_db: %d rows, %d ins, %d strange...\n',
                                      n, n_ins, n_strange));
      if (0 = mod (n, 10000))
	{
	  commit work;
	}
    }
  commit work;
  cl_exec('registry_set (''urilbl_ac_init_status'',''2'')');
 finished:;
  urilbl_ac_init_log (sprintf ('urilbl_ac_init_db: Finished. %d rows, %d ins, %d strange.',
              n, n_ins, n_strange));
}
;

create procedure
cmp_label (in lbl_str varchar, in langs varchar)
{
  declare res any;
  declare q,best_q float;
  declare cur_iid any;
  declare cur_lbl varchar;
  declare n integer;
  declare lang_vec any;

  res := vector();

--  dbg_printf ('cmp_label');
  cur_iid := null;
  best_q := 0;

  {
    declare exit handler for sqlstate 'S1TAT' {
      goto done;
    };

    lang_vec := cmp_fill_lang_by_q (langs);
    for (select rl_lang, s as ull_iid, __ro2sq (o) as ull_label from RDF_LABEL table option (index RDF_LABEL_TEXT), RDF_QUAD
	where rl_text like urilbl_ac_ruin_label (lbl_str) || '%' and rl_o = o) do
      {
	declare ull_label_lang varchar;
	ull_label_lang := '';
	if (rl_lang <> 257)
	  {
	    ull_label_lang := rdf_cache_id_to_name('l', rl_lang);
            if (ull_label_lang = 0)
	      ull_label_lang := coalesce ((select rl_id from rdf_language where rl_twobyte = rl_lang), '');
	  }
        if (cur_iid is not null and ull_iid <> cur_iid)
          {
            res := vector_concat (res, vector (cur_lbl, id_to_iri(cur_iid)));
            n := n + 1;
            if (n >= 50) goto done;
            best_q := 0;
  	}

        cur_iid := ull_iid;
        q := get_keyword_ucase (ull_label_lang, lang_vec, 0.001);

        if (q >= best_q)
          {
            best_q := q;
	    if (__tag (ull_label) = 246)
	      cur_lbl := rdf_box_data (ull_label);
	    else
	      cur_lbl := ull_label;
	  }
      }
    res := vector_concat (res, vector (cur_lbl, id_to_iri (cur_iid)));
   done:;
    return res;
  }
}
;
