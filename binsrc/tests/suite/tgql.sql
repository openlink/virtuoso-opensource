set blobs on;

create procedure gql_test_run (in xp varchar, in qr varchar)
{
  declare js, xt, xe, state, message any;
  result_names (state, message);
  js := GQL_DISPATCH (qr, vector(), 'urn:cciso:schema');
  js := string_output_string (js);
  xe := xtree_doc (json2xml (js));
  xt := xpath_eval (xp, xe);
  if (xt is not null)
    result ('PASSED', concat (qr, ' returned: ', xt));
  else
    result ('FAILED', concat (qr, ' returned ', xt));
}
;

gql_test_run ('/data/region/countries/code3[. = "AUS"]', 'query { region (code:"OC") { name countries { name code3 country_code } }}');
gql_test_run ('/data/country/region/code[ . = "OC"]', 'query{country(code:"AU"){name code3 region{name code}}}');
