if (typeof iSPARQL == 'undefined')
    iSPARQL = {};

iSPARQL.Defaults = {
    endpoints: [ "/sparql",
		 "http://uriburner.com/sparql",
		 "http://dbpedia.org/sparql",
                 "http://loc.openlinksw.com/sparql",
		 "http://lod.openlinksw.com/sparql",
		 "http://bbc.openlinksw.com/sparql",
		 "http://demo.openlinksw.com/sparql",
		 "http://myopenlink.net:8890/sparql/",
		 "http://linkedgeodata.org/sparql",
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
		 "http://www.wasab.dk/morten/2005/04/sparqlette/",
		 ],
    followPropertiesList: [['foaf:knows',      'http://xmlns.com/foaf/0.1/',           true],
			   ['sioc:links_to',   'http://rdfs.org/sioc/ns#',             true],
			   ['rdfs:isDefinedBy','http://www.w3.org/2000/01/rdf-schema#',true],
			   ['rdfs:seeAlso',    'http://www.w3.org/2000/01/rdf-schema#',true],
			   ['owl:sameAs',      'http://www.w3.org/2002/07/owl#',       true]],

    query:        'SELECT * WHERE {?s ?p ?o}',
    sponge:       'none',
    grabLimit:    100,
    grabDepth:    2,
    grabAll:      false,
    graph:        '',
    queryTimeout: 2000, // ms
    auth:         {user:'dav',pass:'dav',endpoint:'./auth.vsp'},
    tab:          0,
    maxrows:      50,
    endpoint:     '/sparql',
    pivotInstalled: false,

 /* See maps.js indexed by OAT.Map.TYPE_* */
    mapProviderNames: [
	"None", 
	"Google Maps", 
	"Yahoo Maps", 
	"Microsoft Virtual Earth",
	"OpenLayers Map",
	"Google Maps v3"
    ],

    // page params may override defaults
    
    handlePageParams:function () {
	
	var qp = false;
	var p = OAT.Dom.uriParams();
	
	if (p['default-graph-uri']) { iSPARQL.Defaults.graph = p['default-graph-uri']; qp = true; }
	if (p['defaultGraph'])      { iSPARQL.Defaults.graph = p['defaultGraph']; qp = true; }
	if (p['query'])             { iSPARQL.Defaults.query = p['query']; qp = true; }
	if (p['sponge'])            { iSPARQL.Defaults.sponge = p['sponge']; qp = true; }
	if (p['should_sponge'])     { iSPARQL.Defaults.sponge = p['should_sponge']; qp = true; }
	if (p['view']) {
	    var tabInx = parseInt(page_params['view']);
	    if (!isNaN(tabInx) && tabinx >= 0 && tabInx < 3)
		iSPARQL.Defaults.tab = tabInx;
	    qp = true;
	}
	if (p['endpoint']) { iSPARQL.Defaults.endpoint = p['endpoint']; qp = true;}
	if (p['resultview']) { iSPARQL.Defaults.resultView = p['resultview']; qp = true;}
	if (qp) iSPARQL.Defaults.qp_override = qp;
	if (p['__DEBUG']) iSPARQL.Defaults.debug = true;
	if (p['maxrows']) iSPARQL.Defaults.maxrows = parseInt(p['maxrows']);
    },

    //
    // Override app defaults with server settings, etc.
    //

    init: function () { 
	var o = { 
	    async: false,
	    onerror: function() { iSPARQL.StatusUI.statMsg("Warning: Could not get server defaults.") },
	    onstart: function () { return; }
	};

	OAT.AJAX.GET ('/isparql/defaults/',
		      '',
		      function(data, headers) {
			  iSPARQL.serverDefaults = OAT.JSON.parse(data);
		      },
		      o);

	for (var defName in iSPARQL.serverDefaults) {
	    if (defName == 'auth') {
		for (var authParm in iSPARQL.serverDefaults.auth) {
		    if (authParm in ['user', 'pass'] && iSPARQL.serverDefaults.auth[authParm] == '') // Empty user/pass do not override defaults
		    continue;
		    else
			iSPARQL.Defaults.auth[authParm] = iSPARQL.serverDefaults.auth[authParm];
		}
		continue;
	    }
	    iSPARQL.Defaults[defName] = iSPARQL.serverDefaults[defName];
	}
	if (typeof iSPARQL.Defaults.map_type == 'undefined' || iSPARQL.Defaults.map_type == '') 
	    iSPARQL.Defaults.map_type = 'GMAP3';

	if (typeof iSPARQL.Defaults.api_key == 'undefined' || iSPARQL.Defaults.api_key == '')
	    iSPARQL.Defaults.api_key = false;

	switch (iSPARQL.Defaults.map_type) {
	case 'GMAP2':
	    iSPARQL.Defaults.map_type = OAT.Map.TYPE_G;
	    if (iSPARQL.Defaults.api_key) OAT.ApiKeys.addKey ('gmapapi',
							      window.location.href,
							      iSPARQL.Defaults.api_key);
	    break;
	case 'GMAP3':
	    iSPARQL.Defaults.map_type = OAT.Map.TYPE_G3;
	    break;
	case 'YAHOO':
	    iSPARQL.Defaults.map_type = OAT.Map.TYPE_Y;
	    if (iSPARQL.Defaults.api_key) OAT.ApiKeys.addKey ('yahoo',
							      window.location.href,
							      iSPARQL.Defaults.api_key);
	    break;
	case 'MS':
	    iSPARQL.Defaults.map_type = OAT.Map.TYPE_MS;
	    break;
	case 'OL':
	    iSPARQL.Defaults.map_type = OAT.Map.TYPE_OL;
	    break;
	}
	iSPARQL.Defaults.handlePageParams();
    }
    
};

// curie, prefix, selected by default


iSPARQL.Settings = {
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