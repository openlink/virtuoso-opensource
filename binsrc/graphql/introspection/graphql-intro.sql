ttlp ('<http://www.openlinksw.com/schemas/graphql/intro#name> <http://www.w3.org/2000/01/rdf-schema#subPropertyOf> virtrdf:label .',
        '', 'urn:graphql:label');
rdfs_rule_set ('facets', 'urn:graphql:label');
ttlp (file_open ('introspection/graphql-schema.ttl'), '', 'urn:graphql:sparql-bridge');
echo "The init is moved in plugin, use GQL_INIT_TYPE_SCHEMA() instead.\n";
