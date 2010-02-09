if (typeof iSPARQL == 'undefined')
    iSPARQL = {};

iSPARQL.defaults = {
    endpoints: [ "/sparql",
		 "http://uriburner.com/sparql",
		 "http://dbpedia.org/sparql",
		 "http://lod.openlinksw.com/sparql",
		 "http://bbc.openlinksw.com/sparql",
		 "http://demo.openlinksw.com/sparql",
		 "http://myopenlink.net:8890/sparql/",
//		 "http://www.govtrack.us/sparql",
		 "http://services.data.gov.uk/education/sparql",
		 "http://services.data.gov.uk/crime/sparql",
		 "http://services.data.gov.uk/environment/sparql",
		 "http://services.data.gov.uk/finance/sparql",
		 "http://services.data.gov.uk/statistics/sparql",
		 "http://api.talis.com/stores/ordnance-survey/services/sparql",
		 "http://api.talis.com/stores/uberblic/services/sparql",
		 "http://linkedlifedata.com/sparql",
		 "http://ldsr.ontotext.com/sparql",
		 "http://www.sparql.org/sparql",
		 "http://abdera.watson.ibm.com:8080/sparql",
//		 "http://km.aifb.uni-karlsruhe.de/services/sparql/SPARQL",
//		 "http://jena.hpl.hp.com:3040/backstage",
//		 "http://my.opera.com/community/sparql/sparql",
		 "http://www.wasab.dk/morten/2005/04/sparqlette/",
//		 "http://biogw-db.hpc.ntnu.no:8892/sparql"
		 ],

    query:        'SELECT * WHERE {?s ?p ?o}',
    sponge:       'none',
    grabLimit:    100,
    grabDepth:    2,
    grabAll:      false,
    graph:        '',
    queryTimeout: 2000, // ms
    auth:         {user:'dav',pass:'dav',endpoint:'./auth.vsp'},
    tab:          0,
    maxrows:      50
};

// curie, prefix, selected by default

iSPARQL.defaults.followPropertiesList = [ ['foaf:knows',      'http://xmlns.com/foaf/0.1/',           true],
					  ['sioc:links_to',   'http://rdfs.org/sioc/ns#',             true],
					  ['rdfs:isDefinedBy','http://www.w3.org/2000/01/rdf-schema#',true],
					  ['rdfs:seeAlso',    'http://www.w3.org/2000/01/rdf-schema#',true],
					  ['owl:sameAs',      'http://www.w3.org/2002/07/owl#'       ,true] ];

iSPARQL.Preferences = {
    xslt:'/isparql/xslt/',
    debug:true
};

// Should be taken care by init.

/* var iSPARQL = {
    dataObj:{
	data:false,
	query:"",
	endpoint:"",
 	defaultGraph:"",
	graphs:[],
	namedGraphs:[],
	prefixes:[],			// FIXME: prefixes?
	pragmas:[],
	canvas:false,
	metaData:false
        maxrows: 0;
    }
};*/