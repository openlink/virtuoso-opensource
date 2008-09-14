
DB.DBA."RDFData_MAKE_DET_COL" ('/DAV/home/demo/tpch/rdf/',
	'http://' || cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost') || '/tpch', NULL);

DB.DBA.VHOST_REMOVE (lpath=>'/tpch/data/rdf');
DB.DBA.VHOST_DEFINE (lpath=>'/tpch/data/rdf', ppath=>'/DAV/home/demo/tpch/rdf/All/', is_dav=>1, vsp_user=>'dba');

create procedure DB.DBA.TPCH_DET_REF (in par varchar, in fmt varchar, in val varchar)
{
  declare res, iri any;
  declare uriqa_str varchar;
  uriqa_str := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  iri := 'http://' || uriqa_str || val || '#this';
  res := sprintf ('iid (%d).rdf', iri_id_num (iri_to_id (iri)));
  return sprintf (fmt, res);
}
;

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'tpch_rule1',
    1,
    '([^#]*)',
    vector('path'),
    1,
    '/about/html/http://^{URIQADefaultHost}^%s%%23this',
    vector('path'),
    null,
    null,
    2,
    303
    );



DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'tpch_rule2', 1,
    '([^#]*)', vector('path'), 1,
    '/tpch/data/rdf/%U', vector('path'),
    'DB.DBA.TPCH_DET_REF',
    '(application/rdf.xml)|(text/rdf.n3)',
    2,
    303);

DB.DBA.URLREWRITE_CREATE_RULELIST (
    'tpch_rule_list1',
    1,
    vector (
                'tpch_rule1',
                'tpch_rule2'
          ));


DB.DBA.VHOST_REMOVE (lpath=>'/tpch');
DB.DBA.VHOST_DEFINE (lpath=>'/tpch', ppath=>'/DAV/home/demo/tpch/', vsp_user=>'dba', is_dav=>1,
          is_brws=>0, opts=>vector ('url_rewrite', 'tpch_rule_list1'));


