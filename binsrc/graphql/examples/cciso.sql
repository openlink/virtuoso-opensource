sparql clear graph <urn:cciso:schema>;
ttlp (file_open ('examples/cciso-schema.ttl'), '', 'urn:cciso:schema');
rdfs_rule_set ('cciso', 'urn:cciso:schema', 1);
rdfs_rule_set ('cciso', 'urn:cciso:schema');

sparql clear graph <urn:cciso:data>;
ttlp (file_open ('examples/cciso.ttl'), '', 'urn:cciso:data');
sparql with <urn:cciso:data> insert { ?region <http://example.org/region/countries> ?country }  { ?country <http://example.org/country/region> ?region };

-- CCISO intospection data
GQL_INTRO_DEL ('urn:graphql:intro:cciso');
sparql clear graph <urn:graphql:intro:cciso>;
ttlp (file_open ('examples/cciso-intro.ttl'), '', 'urn:graphql:intro:cciso');
GQL_INTRO_ADD ('urn:graphql:intro:cciso');

