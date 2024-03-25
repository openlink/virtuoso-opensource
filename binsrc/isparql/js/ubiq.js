
function gen_ubiq_meta() {
  var hd = document.getElementsByTagName('head')[0];
  var ln = document.createElement ('link');

  ln.rel = 'commands';
  ln.href='cmds.vsp?cmd_uri=' + document.location;
  hd.appendChild (ln);
}

function gen_isparql_bookmarklet() {
  var loc = document.location.href;
  loc = loc.substr(0, loc.length - document.location.search.length-1);
  var qry_parm = '?default-graph-uri= &should_sponge=soft&query='+ escape ('select * from <');
  var w = escape('> where { ?s ?p ?o }');
  var l = loc + qry_parm;
  $('isparql_bookmarklet_a').href = 'javascript: (function () { location="'+ l + '" + encodeURIComponent(document.location) + "' + w + '";})()';
 }

function gen_sparql_bookmarklet () {
  loc = document.location.protocol + '//' + document.location.host + '/sparql';
  var qry_parm = '?query='+ escape ('select * from <');
  var w = escape('> where { ?s ?p ?o }');
  var l = loc + qry_parm;
  $('sparql_bookmarklet_a').href = 'javascript: (function () { location="'+ l + '" + encodeURIComponent(document.location) + "' + w + '";})()';
}

function enable_if_ubiq (elm_id) {
    var ua = navigator.userAgent;
    if (ua.indexOf ('Firefox') != -1) {
	OAT.Dom.show(elm_id)
    }
}
