if (typeof iSPARQL == 'undefined')
    iSPARQL = {};

iSPARQL.addthis_loaded = false;

iSPARQL.Defaults = {
    endpoints: [ "/sparql",
		 "http://uriburner.com/sparql",
		 "http://dbpedia.org/sparql",
                 "http://loc.openlinksw.com/sparql",
		 "http://lod.openlinksw.com/sparql",
                 "http://sparql.sindice.com/sparql",
		 "http://bbc.openlinksw.com/sparql",
		 "http://demo.openlinksw.com/sparql",
		 "http://myopenlink.net:8890/sparql",
		 "http://linkedgeodata.org/sparql",
		 "http://sparql.reegle.info/",
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

    query:        "SELECT * WHERE {?s ?p ?o}",
    sponge:       "none",
    grabLimit:    100,
    grabDepth:    2,
    grabAll:      false,
    graph:        "",
    timeout:      false, // ms
    auth:         {user:'dav',password:'dav'},
    tab:          0,
    anchorMode:   0, /* 0:Exec SPARQL describe, 1:get data items,2:Open in new window,3:Open "describe" page */
    maxrows:      50,
    view:         1,
    endpoint:     '/sparql',
    pivotInstalled: false,
    addthis_key: false,
    locOpts: {             /* XXX all except minAcc not implemented yet */
	cacheLocTO:  2000, /* Milliseconds timeout to improve non-expired cached location accuracy */
	coarseLocTO: 2000, /* Milliseconds to wait for coarse loc in last cached location validation attempt */
	minAcc:      500,  /* default min. accuracy requested for location queries, in metres, after which the query fires */
	autoApply:   true, /* Automatically execute location query when min. accuracy is achieved. */
	cacheExpiry: 10    /* minutes a cached location is deemed accurate */
    },

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
	
	if (p['default-graph-uri']) { iSPARQL.Settings.graph  = p['default-graph-uri']; qp = true; }
	if (p['defaultGraph'])      { iSPARQL.Settings.graph  = p['defaultGraph']; qp = true; }
	if (p['query']) { 
	    iSPARQL.Settings.query  = p['query']; 
	    qp = true; 
	}
	if (p['qtxt']) { 
	    iSPARQL.Settings.query  = p['qtxt']; 
	    qp = true; 
	}
	if (p['sponge'])            { iSPARQL.Settings.sponge = p['sponge']; qp = true; }
	if (p['should_sponge'])     { iSPARQL.Settings.sponge = p['should_sponge']; qp = true; }
	if (p['view']) {
	    var tabInx = parseInt(p['view']);
	    if (!isNaN(tabInx) && tabInx >= 0 && tabInx < 3)
		iSPARQL.Settings.tab = tabInx;
	    else 
		iSPARQL.Settings.tab = 1;
	    qp = true;
	}
	if (p['endpoint']) { iSPARQL.Settings.endpoint = p['endpoint']; qp = true;}
	if (p['resultview']) { iSPARQL.Settings.resultView = p['resultview']; qp = true;}
	if (qp) iSPARQL.Settings.qp_override = qp;
	if (p['__DEBUG']) iSPARQL.Settings.debug = true;
	if (p['maxrows']) iSPARQL.Settings.maxrows = parseInt(p['maxrows']);
	if (p['timeout']) iSPARQL.Settings.timeout = parseInt(p['timeout']);
	if (p['amode']) iSPARQL.Settings.anchorMode = parseInt(p['amode']);
	if (p['raw_iris']) iSPARQL.Settings.raw_iris = ((p['raw_iris'] == 'true')?true:false);
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
	    } else if (defName == 'namespaces') {
		OAT.IRIDB.insertIRIArr (iSPARQL.serverDefaults[defName]);
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
	this.handlePageParams();
    }
};

// curie, prefix, selected by default


iSPARQL.Settings = {
    xslt:'/isparql/xslt/',
    debug:true
}



