--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2020 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--


create procedure WS.WS.SPARQL_ENDPOINT_HTML_DOCTYPE()
{
    http('<?xml version="1.0" encoding="UTF-8" ?>\n');
    http('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">\n');
    http('<html version="-//W3C//DTD XHTML 1.1//EN"\n');
    http('    xmlns="http://www.w3.org/1999/xhtml"\n');
    http('    xml:lang="en"\n');
    http('>\n');
}
;


create procedure WS.WS.SPARQL_ENDPOINT_HTML_HEAD(in title varchar)
{
    http('    <title>' || title || '</title>\n');
    http(sprintf('    <meta name="Copyright" content="Copyright &copy; %d OpenLink Software" />\n', year(now())));
    http('    <meta name="Keywords" content="OpenLink Virtuoso Sparql" />\n');
    http('    <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />\n');
}
;


create procedure WS.WS.SPARQL_ENDPOINT_STYLE ()
{
    http('\n');
    http('
    <style type="text/css">
    /*<![CDATA[*/
	html { padding: 0; }
	body {
	    padding: 0;
	    margin: 0;
	    font-family:Arial, Helvetica, sans-serif;
	    font-size: 9pt;
	    color: #333;
	    background-color: #FDFDFD;
	}
	#header {
	    padding: 0;
	    margin: 0;
	    background-color: #86B9D9;
	    color: #FFFFFF;
	    border-bottom: 1px solid #AAA;
	}
	#header h1 {
	    font-size: 16pt;
	    font-weight: normal;
	    text-align: left;
	    vertical-align: middle;
	    padding: 4px 8px 4px 8px;
	    margin: 0px 0px 0px 0px;
	}
	#menu {
	    margin-left: 8px;
	    margin-right: 8px;
 	    margin-top: 0px;
	    clear: right;
	    float: right;
	}
	#intro,#main {
	    margin-left: 8px;
	    margin-right: 8px;
	}
	#help {
	    margin-left: 8px;
	    margin-right: 8px;
	    width: 80%
	}
	#footer {
	    width: 100%;
	    float: left;
	    clear: left;
	    margin: 2em 0 0;
	    padding-top: 0.7ex;
	    border-top: 1px solid #AAA;
	    font-size: 8pt;
	    text-align: center;
	}
	fieldset {
	    border: 0;
	    padding: 0;
	    margin: 0;
	}
	fieldset label {
	    font-weight: normal;
	    white-space: nowrap;
	    font-size: 11pt;
	    color: #000;
	}
	fieldset label.n {
	    display: block;
	    vertical-align: bottom;
	    margin-top:5px;
	    width: 160px;
	    float:left;
	    white-space: nowrap;
	}
	fieldset label.n:after { content: ":"; }
	fieldset label.n1 {
	    display: block;
	    vertical-align: bottom;
	    margin-top:5px;
	    width: 160px;
	    float:left;
	    white-space: nowrap;
	}
	fieldset label.ckb {
	    width: 160px;
	    font-weight: normal;
	    font-size: 10pt;
	}
	fieldset label.ckb:after { content: ""; }
	fieldset textarea {
	    width: 99%;
	    font-family: monospace;
	    font-size: 10pt;
	}
	#cxml {
	    clear: both;
	    display: block;
	}
	#savefs {
	    clear: both;
	    display: block;
	}
	span.info {
	    font-size: 9pt;
	    white-space: nowrap;
	    height: 2em;
	}
	br { clear: both; }
    /*]]>*/
    </style>
    ');
}
;


create procedure WS.WS.SPARQL_ENDPOINT_JAVASCRIPT (in can_cxml integer, in can_qrcode integer)
{
    http('\n');
    http('    <script type="text/javascript">\n');
    http('    /*<![CDATA[*/\n');
    http('	var timer;\n');
    http('	function format_select(query_obg){\n');
    http('	    clearTimeout(timer);\n');
    http('	    timer = setTimeout (function delay_format_select() {do_format_select(query_obg);}, 1000);\n');
    http('	}\n\n');
    http('	var curr_format = 0;\n');
    http('	function do_format_select(query_obg)\n');
    http('	{\n');
    http('		var query = query_obg.value; \n');
    http('		var format = query_obg.form.format;\n');
    http('		var prev_value = format.options[format.selectedIndex].value;\n');
    http('		var prev_format = curr_format;\n');
    http('		var ctr = 0;\n');
    http('		var query_is_construct = (query.match(/\\bconstruct\\b\\s/i) || query.match(/\\bdescribe\\b\\s/i));\n');
    http('\n');
    http('		if (query_is_construct && curr_format != 2) {\n');
    http('			for(ctr = format.options.length - 1; ctr >= 0; ctr--)\n');
    http('				format.remove(ctr);\n');
    http('			ctr = 0;\n');
    http('			format.options[ctr++] = new Option(\'Turtle\',\'text/turtle\');\n');
    http('			format.options[ctr++] = new Option(\'Turtle (beautified)\',\'application/x-nice-turtle\');\n');
    http('			format.options[ctr++] = new Option(\'RDF/JSON\',\'application/rdf+json\');\n');
    http('			format.options[ctr++] = new Option(\'RDF/XML\',\'application/rdf+xml\');\n');
    http('			format.options[ctr++] = new Option(\'N-Triples\',\'text/plain\');\n');
    http('			format.options[ctr++] = new Option(\'XHTML+RDFa\',\'application/xhtml+xml\');\n');
    http('			format.options[ctr++] = new Option(\'ATOM+XML\',\'application/atom+xml\');\n');
    http('			format.options[ctr++] = new Option(\'ODATA/JSON\',\'application/odata+json\');\n');
    http('			format.options[ctr++] = new Option(\'JSON-LD (plain)\',\'application/x-ld+json\');\n');
    http('			format.options[ctr++] = new Option(\'JSON-LD (with context)\',\'application/ld+json\');\n');
    http('			format.options[ctr++] = new Option(\'HTML (list)\',\'text/x-html+ul\');\n');
    http('			format.options[ctr++] = new Option(\'HTML (table)\',\'text/x-html+tr\');\n');
    http('			format.options[ctr++] = new Option(\'HTML+Microdata (basic)\',\'text/html\');\n');
    http('			format.options[ctr++] = new Option(\'HTML+Microdata (table)\',\'application/x-nice-microdata\');\n');
    http('			format.options[ctr++] = new Option(\'HTML+JSON-LD (basic)\',\'text/x-html-script-ld+json\');\n');
    http('			format.options[ctr++] = new Option(\'HTML+Turtle (basic)\',\'text/x-html-script-turtle\');\n');
    http('			format.options[ctr++] = new Option(\'Turtle (beautified - browsing oriented)\',\'text/x-html-nice-turtle\');\n');
    http('			format.options[ctr++] = new Option(\'Microdata/JSON\',\'application/microdata+json\');\n');
    http('			format.options[ctr++] = new Option(\'CSV\',\'text/csv\');\n');
    http('			format.options[ctr++] = new Option(\'TSV\',\'text/tab-separated-values\');\n');
    http('			format.options[ctr++] = new Option(\'TriG\',\'application/x-trig\');\n');
    if (can_cxml)
      {
	http('			format.options[ctr++] = new Option(\'CXML (Pivot Collection)\',\'text/cxml\');\n');
	if (can_qrcode)
	  http('		format.options[ctr++] = new Option(\'CXML (Pivot Collection with QRcodes)\',\'text/cxml+qrcode\');\n');
      }
    http('			curr_format = 2;\n');
    http('		}\n');
    http('\n');
    http('		if (!query_is_construct && curr_format != 1) {\n');
    http('			for(ctr = format.options.length - 1; ctr >= 0; ctr--)\n');
    http('				format.remove(ctr);\n');
    http('			ctr = 0;\n');
    http('			format.options[ctr++] = new Option(\'Auto\',\'auto\');\n');
    http('			format.options[ctr++] = new Option(\'HTML\',\'text/html\');\n');
    if (DB.DBA.VAD_CHECK_VERSION ('fct') is not null)
      http('			format.options[ctr++] = new Option(\'HTML (Faceted Browsing Links)\',\'text/x-html+tr\');\n');
    else
      http('			format.options[ctr++] = new Option(\'HTML (Basic Browsing Links)\',\'text/x-html+tr\');\n');
    http('			format.options[ctr++] = new Option(\'Spreadsheet\',\'application/vnd.ms-excel\');\n');
    http('			format.options[ctr++] = new Option(\'XML\',\'application/sparql-results+xml\');\n');
    http('			format.options[ctr++] = new Option(\'JSON\',\'application/sparql-results+json\');\n');
    http('			format.options[ctr++] = new Option(\'Javascript\',\'application/javascript\');\n');
    http('			format.options[ctr++] = new Option(\'Turtle\',\'text/turtle\');\n');
    http('			format.options[ctr++] = new Option(\'RDF/XML\',\'application/rdf+xml\');\n');
    http('			format.options[ctr++] = new Option(\'N-Triples\',\'text/plain\');\n');
    http('			format.options[ctr++] = new Option(\'CSV\',\'text/csv\');\n');
    http('			format.options[ctr++] = new Option(\'TSV\',\'text/tab-separated-values\');\n');
    if (can_cxml)
      {
	http('			format.options[ctr++] = new Option(\'CXML (Pivot Collection)\',\'text/cxml\');\n');
	if (can_qrcode)
	  http('		format.options[ctr++] = new Option(\'CXML (Pivot Collection with QRcodes)\',\'text/cxml+qrcode\');\n');
      }
    http('			curr_format = 1;\n');
    http('		}\n');
    http('		if (prev_format != curr_format)\n');
    http('			for(ctr = format.options.length - 1, format.selectedIndex=0; ctr >= 0; ctr--)\n');
    http('				if (format.options[ctr].value == prev_value) format.selectedIndex = ctr;\n');
    http('	}\n');
    http('
	function format_change(e)
	{
		var format = e.value;
		var cxml = document.getElementById("cxml");
		if (!cxml) return;
		if ((format.match (/\\bCXML\\b/i)))
		{
			cxml.style.display="block";
		} else {
			cxml.style.display="none";
		}
	}
	function savedav_change(e)
	{
		var savefs = document.getElementById("savefs");
		if (!savefs) return;
		if (e.checked)
		{
			savefs.style.display = "block";
		}
		else
		{
			savefs.style.display = "none";
		}
	}
	function change_run_button(e)
	{
		var button = document.getElementById("run");
		var lbl;

		if (!button) return;

		if (e.checked)
		{
		    lbl = " Explain ";
		}
		else
		{
		    lbl = " Run Query ";
		}

		if (button)
		{
		      if (button.childNodes[0])
		      {
			button.childNodes[0].nodeValue=lbl;
		      }
		      else if (button.value)
		      {
			button.value=lbl;
		      }
		      else //if (button.innerHTML)
		      {
			button.innerHTML=lbl;
		      }
		}
	}
	function sparql_endpoint_init()
	{
		var format = document.getElementById("format");
 		if (format) format_change(format);
		var savefs = document.getElementById("savefs");
		if (savefs)
		{
		  var save = document.getElementById("save");
		  if (save)
		    savedav_change(save);
		}
		var b = document.getElementById("explain");
		if (b) change_run_button(b);
	}
    ');
    http('    /*]]>*/\n');
    http('    </script>\n');
}
;


create procedure WS.WS.SPARQL_ENDPOINT_FOOTER()
{
    http('    <div id="footer">\n');
    http(sprintf('      Copyright &copy; %d <a href="http://www.openlinksw.com/virtuoso">OpenLink Software</a>', year(now())));
    http(sprintf('<br />Virtuoso version %s on %s (%s), ', sys_stat('st_dbms_ver'), sys_stat('st_build_opsys_id'), host_id()));
    if (1 = sys_stat('cl_run_local_only'))
        http('Single Server Edition\n');
    else
        http(sprintf('Cluster Edition (%d server processes)\n', sys_stat('cl_n_hosts')));
    http('    </div>\n');
}
;


create procedure WS.WS.SPARQL_ENDPOINT_FORMAT_OPTS (in can_cxml integer, in can_qrcode integer, in params varchar, in qr varchar)
{
    declare opts any;
    declare format varchar;
    format := get_keyword ('format', params, get_keyword ('output', params, ''));
    qr := lower (qr);
    if (format <> '')
    {
        format := (
            case lower(format)
            when 'csv'              then 'text/csv'
            when 'cxml'             then 'text/cxml'
            when 'cxml+qrcode'      then 'text/cxml+qrcode'
            when 'html'             then 'text/html'
            when 'js'               then 'application/javascript'
            when 'json'             then 'application/sparql-results+json'
            when 'json-ld'          then 'application/ld+json'
            when 'n3'               then 'text/rdf+n3'
            when 'ttl'              then 'text/turtle'
            when 'turtle'           then 'text/turtle'
            when 'rdf'              then 'application/rdf+xml'
            when 'sparql'           then 'application/sparql-results+xml'
            when 'xml'              then 'application/sparql-results+xml'
            else format
        end);
    }
    if (regexp_match ('\\bconstruct\\b', qr) is not null or regexp_match ('\\bdescribe\\b', qr) is not null)
    {
        opts := vector (
            vector ('Turtle'                                                , 'text/turtle'                         ),
            vector ('Turtle (beautified)'                                   , 'application/x-nice-turtle'           ),
            vector ('RDF/JSON'                                              , 'application/rdf+json'                ),
            vector ('RDF/XML'                                               , 'application/rdf+xml'                 ),
            vector ('N-Triples'                                             , 'text/plain'                          ),
            vector ('XHTML+RDFa'                                            , 'application/xhtml+xml'               ),
            vector ('ATOM+XML'                                              , 'application/atom+xml'                ),
            vector ('ODATA/JSON'                                            , 'application/odata+json'              ),
            vector ('JSON-LD (plain)'                                       , 'application/x-ld+json'               ),
            vector ('JSON-LD (with context)'                                , 'application/ld+json'                 ),
            vector ('HTML (list)'                                           , 'text/x-html+ul'                      ),
            vector ('HTML (table)'                                          , 'text/x-html+tr'                      ),
            vector ('HTML+Microdata (basic)'                                , 'text/html'                           ),
            vector ('HTML+Microdata (table)'                                , 'application/x-nice-microdata'        ),
            vector ('HTML+JSON-LD (basic)'                                  , 'text/x-html-script-ld+json'          ),
            vector ('HTML+Turtle (basic)'                                   , 'text/x-html-script-turtle'           ),
            vector ('Turtle (beautified - browsing oriented)'               , 'text/x-html-nice-turtle'             ),
            vector ('Microdata/JSON'                                        , 'application/microdata+json'          ),
            vector ('CSV'                                                   , 'text/csv'                            ),
            vector ('TSV'                                                   , 'text/tab-separated-values'           ),
            vector ('TriG'                                                  , 'application/x-trig'                  )
        );
    }
    else
    {
        declare lbl any;
        if (DB.DBA.VAD_CHECK_VERSION ('fct') is not null)
            lbl := 'HTML (Faceted Browsing Links)';
        else
            lbl := 'HTML (Basic Browsing Links)';

        if (not length (format)) format := 'text/html';

        opts := vector (
            vector ('Auto'                                                  , 'auto'                                ),
            vector ('HTML'                                                  , 'text/html'                           ),
            vector (lbl                                                     , 'text/x-html+tr'                      ),
            vector ('Spreadsheet'                                           , 'application/vnd.ms-excel'            ),
            vector ('XML'                                                   , 'application/sparql-results+xml'      ),
            vector ('JSON'                                                  , 'application/sparql-results+json'     ),
            vector ('Javascript'                                            , 'application/javascript'              ),
            vector ('Turtle'                                                , 'text/turtle'                         ),
            vector ('RDF/XML'                                               , 'application/rdf+xml'                 ),
            vector ('N-Triples'                                             , 'text/plain'                          ),
            vector ('CSV'                                                   , 'text/csv'                            ),
            vector ('TSV'                                                   , 'text/tab-separated-values'           )
        );
    }

    if (can_cxml)
    {
        opts := vector_concat (opts, vector (
            vector ('CXML (Pivot Collection)'                               , 'text/cxml'                           )));
        if (can_qrcode) opts := vector_concat (opts, vector (
            vector ('CXML (Pivot Collection with QRcodes)'                  , 'text/cxml+qrcode'                    )));
    }

    foreach (any x in opts) do
    {
        http( sprintf ('<option value="%V" %s>%V</option>\n', x[1], case when format = x[1] then 'selected' else '' end , x[0]));
    }
}
;


create procedure WS.WS.SPARQL_ENDPOINT_SPONGE_OPTS (in params varchar)
{
    declare s_param varchar;
    declare opts any;

    s_param := get_keyword ('should-sponge', params, '');
    opts := vector (
        vector ('',                 'Use only local data (including data retrieved before), but do not retrieve more'),
        vector ('soft',             'Retrieve remote RDF data for all missing source graphs'),
        vector ('grab-all',         'Retrieve all missing remote RDF data that might be useful'),
        vector ('grab-all-seealso', 'Retrieve all missing remote RDF data that might be useful, including seeAlso references'),
        vector ('grab-everything',  'Try to download all referenced resources (this may be very slow and inefficient)')
    );

    foreach (any x in opts) do
    {
        http(sprintf ('<option value="%V" %s>%V</option>\n', x[0], case when s_param = x[0] then 'selected' else '' end , x[1]));
    }
}
;


create procedure WS.WS.SPARQL_ENDPOINT_CXML_OPTION (in can_pivot integer, in params varchar, in lbl varchar, in decoration integer := 1)
{
    declare val varchar;
    declare opts varchar;

    if ('CXML_redir_for_subjs' = lbl)
    {
        val := get_keyword (lbl, params, '121');
        if (decoration)
        {
            http ('<label for="CXML_redir_for_subjs" class="n">External resource link</label>\n');
            http ('<select name="CXML_redir_for_subjs" id="CXML_redir_for_subjs">\n');
        }
        opts := vector (
            vector ('',                   'No link out'),
            vector ('121',                'External resource link'),
            vector ('DESCRIBE',           'External description link'),
            vector ('ABOUT_RDF',          'External sponged data link (RDF)'),
            vector ('ABOUT_HTML',         'External sponged data link (HTML)'),
            vector ('LOCAL_TTL',          'External description resource (TTL)'),
            vector ('LOCAL_NTRIPLES',     'External description resource (NTRIPLES)'),
            vector ('LOCAL_JSON',         'External description resource (JSON)'),
            vector ('LOCAL_XML',          'External description resource (RDF/XML)')
        );
    } else {
        val := get_keyword (lbl, params, '');
        if (decoration)
        {
            http ('<label for="CXML_redir_for_hrefs" class="n">Facet link behavior</label>\n');
            http ('<select name="CXML_redir_for_hrefs" id="CXML_redir_for_hrefs">\n');
        }
        opts := vector (
            vector ('',                   'Local faceted navigation link'),
            vector ('121',                'External resource link'),
            vector ('LOCAL_PIVOT',        'External faceted navigation link'),
            vector ('DESCRIBE',           'External description link'),
            vector ('ABOUT_RDF',          'External sponged data link (RDF)'),
            vector ('ABOUT_HTML',         'External sponged data link (HTML)'),
            vector ('LOCAL_TTL',          'External description resource (TTL)'),
            vector ('LOCAL_CXML',         'External description resource (CXML)'),
            vector ('LOCAL_NTRIPLES',     'External description resource (NTRIPLES)'),
            vector ('LOCAL_JSON',         'External description resource (JSON)'),
            vector ('LOCAL_XML',          'External description resource (RDFXML)')
        );
    }

    foreach (any x in opts) do
    {
        if ('LOCAL_PIVOT' <> x[0] or can_pivot)
            http(sprintf ('<option value="%V" %s>%V</option>\n', x[0], case when val = x[0] then 'selected' else '' end , x[1]));
    }

    if (decoration) http ('</select><br />\n');
}
;


create procedure WS.WS.SPARQL_ENDPOINT_GENERATE_FORM (
    in params any,
    in ini_dflt_graph varchar,
    in def_qry varchar,
    in timeout integer,
    in signal_void varchar,
    in signal_unconnected varchar,
    in quiet_geo varchar,
    in log_debug_info varchar,
    in save_mode varchar,
    in dav_refresh varchar,
    in overwrite varchar,
    in explain_report varchar)
{
    declare can_cxml, can_pivot, can_qrcode, can_sponge integer;
    can_cxml := case (isnull (DB.DBA.VAD_CHECK_VERSION ('sparql_cxml'))) when 0 then 1 else 0 end;
    can_pivot := case (isnull (DB.DBA.VAD_CHECK_VERSION ('PivotViewer'))) when 0 then 1 else 0 end;
    can_qrcode := isstring (__proc_exists ('QRcode encodeString8bit', 2));
    can_sponge := coalesce ((select top 1 1
      from DB.DBA.SYS_USERS as sup
        join DB.DBA.SYS_ROLE_GRANTS as g on (sup.U_ID = g.GI_SUPER)
        join DB.DBA.SYS_USERS as sub on (g.GI_SUB = sub.U_ID)
      where sup.U_NAME = 'SPARQL' and sub.U_NAME = 'SPARQL_SPONGE' ), 0);

    declare endpoint_xsl any;
    endpoint_xsl := registry_get ('sparql_endpoint_xsl');
    if (0 = endpoint_xsl) endpoint_xsl := '';
    if ('' <> endpoint_xsl) http_xslt(endpoint_xsl);

    declare user_id varchar;
    user_id := connection_get ('SPARQLUserId', 'SPARQL');

    declare path, save_dir varchar;
    declare parts any;
    save_dir := null;
    for (select COL_ID from WS.WS.SYS_DAV_COL where COL_DET = 'DynaRes' and WS.WS.COL_PATH (COL_PARENT) like '/DAV/home/%') do
    {
      path := WS.WS.COL_PATH (COL_ID);
      parts := split_and_decode (path, 0, '\0\0/');
      if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = parts[3] and U_DAV_ENABLE));
	      save_dir := path;
	  }

    http_header ('Content-Type: text/html; charset=UTF-8\r\n');
    if (http_request_get ('REQUEST_METHOD') = 'OPTIONS')
	    http_header (http_header_get () || 'MS-Author-Via: SPARQL\r\n');

    WS.WS.SPARQL_ENDPOINT_HTML_DOCTYPE();

    http('<head>\n');
    WS.WS.SPARQL_ENDPOINT_HTML_HEAD('Virtuoso SPARQL Query Editor');
    WS.WS.SPARQL_ENDPOINT_STYLE ();
    WS.WS.SPARQL_ENDPOINT_JAVASCRIPT(can_cxml, can_qrcode);
    http('</head>\n');

    http('<body onload="sparql_endpoint_init()">\n');

    http('    <div id="header">\n');
    http('	<h1>Virtuoso SPARQL Query Editor</h1>\n');
    http('    </div>\n\n');

    http('    <div id="menu">\n');
    http('	  <a href="?help=intro">About</a>\n');
    http('	| <a href="?help=nsdecl">Namespace Prefixes</a>\n');
    http('	| <a href="?help=rdfinf">Inference Rules</a>\n');
    http('	| <a href="?help=macrolibs">Macros</a>\n');
    http('	| <a href="?help=views">RDF Views</a>\n');
    if (DB.DBA.VAD_CHECK_VERSION('iSPARQL') is not null)
	    http('	| <a href="/isparql">iSPARQL</a>\n');
    http('    </div>\n\n');

    http('    <div id="main">\n');
    http('    <br />\n');
    http('	<form action="" method="get">\n');
    http('	<fieldset>\n');
    http('		<label for="default-graph-uri">Default Data Set Name (Graph IRI)</label><br />\n');
    http('		<input type="text" name="default-graph-uri" id="default-graph-uri"');
    http(sprintf (' value="%V" size="80"/>\n', coalesce (ini_dflt_graph, '') ));
    http('		<br /><br />\n');

    http('		<label for="query">Query Text</label><br />\n');
    http(sprintf('             <textarea rows="18" cols="80" name="query" id="query" onchange="javascript:format_select(this)" onkeyup="javascript:format_select(this)">%V</textarea>\n', charset_recode (def_qry, 'UTF-8', '_WIDE_')));

    http('		<br /><br />\n');
    if (can_sponge)
    {
    	http('		<label for="should-sponge" class="n">Sponging</label>\n');
    	http('		<select name="should-sponge" id="should-sponge">\n');
    	WS.WS.SPARQL_ENDPOINT_SPONGE_OPTS (params);
    	http('		</select>\n');
    }
    else
    {
	    http('		<span class="info"><i>(Security restrictions of this server do not allow you to retrieve remote RDF data, see <a href="?help=enable_sponge">details</a>.)</i></span>\n');
    }

    http('		<br />\n');
    http('		<label for="format" class="n">Results Format</label>\n');
    http('		<select name="format" id="format" onchange="javascript:format_change(this)">\n');
    WS.WS.SPARQL_ENDPOINT_FORMAT_OPTS (can_cxml, can_qrcode, params, def_qry);
    http('		</select>\n');
    if (sys_stat('st_has_vdb'))
    {
	    if (not can_cxml)
	      http('		<span class="info"><i>(The CXML output is disabled, see <a href="?help=enable_cxml">details</a>)</i></span>\n');
	    else if (not can_qrcode)
	      http('		<span class="info"><i>(The QRCODE output is disabled, see <a href="?help=enable_cxml">details</a>)</i></span>\n');
    }
    http('		<br />\n');

    if (can_cxml)
    {
    	http ('		<fieldset id="cxml">\n');
    	WS.WS.SPARQL_ENDPOINT_CXML_OPTION (can_pivot, params, 'CXML_redir_for_subjs');

    	WS.WS.SPARQL_ENDPOINT_CXML_OPTION (can_pivot, params, 'CXML_redir_for_hrefs');
    	http ('		</fieldset>\n');
    }

    http('		<label for="timeout" class="n">Execution timeout</label>\n');
    http(sprintf('             <input name="timeout" id="timeout" type="text" value="%d" /> milliseconds\n', timeout, ''));
    http('		<span class="info"><i>(values less than 1000 are ignored)</i></span>');
    http('		<br />\n');

    --http('		<li>\n');
    --http('		<label for="maxrows">Max Rows</label>\n');
    --http('		<input type="text" name="maxrows" id="maxrows"\n');
    --http( sprintf('		value="%d"/>\n',maxrows));
    --http('		<br />\n');

    http('		<label class="n" for="options">Options</label>\n');
    http('		<fieldset id="options">\n');
    http('		<input name="signal_void" id="signal_void" type="checkbox"' || case (signal_void) when '' then '' else ' checked="checked"' end || '/>\n');
    http('		<label for="signal_void" class="ckb">Strict checking of void variables</label>\n');
    http('		<br />\n');
    http('		<input name="signal_unconnected" id="signal_unconnected" type="checkbox"' || case (signal_unconnected) when '' then '' else ' checked="checked"' end || '/>\n');
    http('		<label for="signal_unconnected" class="ckb">Strict checking of variable names used in multiple clauses but not logically connected to each other</label>\n');
    http('		<br />\n');
    http('		<input name="quiet_geo" id="quiet_geo" type="checkbox"' || case (quiet_geo) when '' then '' else ' checked="checked"' end || '/>\n');
    http('		<label for="quiet_geo" class="ckb">Suppress errors on wrong geometries and errors on geometrical operators (failed operations will return NULL)</label>\n');
    http('		<br />\n');
    http('		<input name="log_debug_info" id="log_debug_info" type="checkbox"' || case (log_debug_info) when '' then '' else ' checked="checked"' end || '/>\n');
    http('		<label for="log_debug_info" class="ckb">Log debug info at the end of output (has no effect on some queries and output formats)</label>\n');
    http('		<br />\n');
    http('		<input name="explain" id="explain" onclick="javascript:change_run_button(this)" type="checkbox"' || case (explain_report) when '' then '' else ' checked="checked"' end || '/>\n');
    http('		<label for="explain" class="ckb">Generate SPARQL compilation report (instead of executing the query)</label>\n');


    if (save_dir is not null)
    {
    	http('		<br />\n');
    	http('		<input name="save" id="save" onclick="savedav_change(this)" type="checkbox"' || case when (save_mode is null) then '' else ' checked="checked"' end || ' />\n');
    	http('		<label for="save" class="ckb">Save resultset to WebDAV folder on the server</label>\n');
    	http('		<span id="savefs" style="display: %s;">\n');
    	http('		  <label for="dname">Dynamic resource collection:</label>\n');
    	http('		  <select id="dname" name="dname" >\n');
      for (select COL_ID from WS.WS.SYS_DAV_COL where COL_DET = 'DynaRes' and WS.WS.COL_PATH (COL_PARENT) like '/DAV/home/%') do
      {
        path := WS.WS.COL_PATH (COL_ID);
        parts := split_and_decode (path, 0, '\0\0/');
        if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = parts[3] and U_DAV_ENABLE));
        	http(sprintf('<option>%s</option>\n', path));
  	  }
    	http('		  </select>\n');
    	http('		  <br />\n');
    	http('		  <label for="fname">File name:</label>\n');
    	http('		  <input type="text" id="fname" name="fname" />\n');
    	http('		  <br />\n');
    	http('		  <input type="checkbox" name="dav_refresh" id="dav_refresh"' || case when (dav_refresh is null) then '' else ' checked="checked"' end || ' />\n');
    	http('		  <label class="ckb" for="dav_refresh">Refresh periodically</label>\n');
    	http('		  <br />\n');
    	http('		  <input type="checkbox" name="dav_overwrite" id="dav_overwrite"' || case when (overwrite is null or overwrite = '0') then '' else ' checked="checked"' end || ' />\n');
    	http('		  <label class="ckb" for="dav_overwrite">Overwrite if exists</label>\n');
    	http('		</span>\n');
    }

    http('		</fieldset>\n');
    http('		<br />\n');

    if (save_dir is null)
    {
    	http('		<span class="info"><i>(The result can only be sent back to browser, not saved on the server, see <a href="?help=enable_det">details</a>)</i></span>\n');
      http('		<br />\n');
    }

    http('		<br />\n');
    http('		<input type="submit" name="run" id="run" value="Go"/>\n');
    http('		<input type="reset" value="Reset"/>\n');
    http('	</fieldset>\n');
    http('	</form>\n');
    http('    </div>\n\n');
    WS.WS.SPARQL_ENDPOINT_FOOTER();
    http (WS.WS.SPARQL_ENDPOINT_SVC_DESC ());
    http('</body>\n');
    http('</html>\n');

    return;
}
;


create procedure WS.WS.SPARQL_ENDPOINT_BRIEF_HELP (inout path varchar, inout params any, inout lines any, in user_id varchar, in help_topic varchar)
{
#pragma prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
#pragma prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
  declare subtitle varchar;
  declare format varchar;
  subtitle := case help_topic
    when 'intro' then 'About'
    when 'enable_sponge' then 'Sponge'
    when 'enable_cxml' then 'CXML'
    when 'enable_det' then 'DAV'
    when 'nsdecl' then 'Namespace Prefixes'
    when 'rdfinf' then 'Build-in Inference Rules'
    when 'views' then 'RDF Views'
    when 'macrolibs' then 'SPIN and SPARQL-BI Macro Libraries'
    else 'Error' end;
  format := '';
  WS.WS.SPARQL_ENDPOINT_HTML_DOCTYPE();
  http('<head>\n');
  WS.WS.SPARQL_ENDPOINT_HTML_HEAD('Virtuoso SPARQL Query Editor | ' || subtitle);
  WS.WS.SPARQL_ENDPOINT_STYLE ();
  http('</head>\n');
  http('<body>\n');
  http ('    <div id="header">\n');
  http('	<h1 id="title">Virtuoso SPARQL Query Editor | ' || subtitle || '</h1>\n');
  http ('    </div>\n\n');
  http ('    <div id="help">\n');
  if (help_topic='intro')
    {
      http('	<h3>Intro</h3>\n');
      http('	<p>This page is designed to help you test the OpenLink Virtuoso SPARQL protocol endpoint.<br/>\n');
      http('	Consult the <a href="http://virtuoso.openlinksw.com/wiki/main/Main/VOSSparqlProtocol">Virtuoso Wiki page</a> describing the service \n');
      http('	or the <a href="http://docs.openlinksw.com/virtuoso/">Online Virtuoso Documentation</a> section <a href="http://docs.openlinksw.com/virtuoso/rdfandsparql.html">RDF Database and SPARQL</a>.</p>\n');
      http('	<p>There is also a rich Web based user interface with sample queries. \n');
      if (DB.DBA.VAD_CHECK_VERSION('iSPARQL') is null)
	  http('	In order to use it, ask the site admin to install the iSPARQL package (isparql_dav.vad).</p>\n');
      else
	  http('	You can access it at: <a href="/isparql">/isparql</a>.</p>\n');
      http('	<p>For your convenience we have a set of <a href="?help=nsdecl">predefined name space prefixes</a> and <a href="?help=rdfinf">inference rules</a></p>\n');

      http('	<h3>What is SPARQL?</h3>\n');
      http('	<p>SPARQL is the W3C''s declaritive query-language for Graph Model Databases and Stores.</p>\n');
      http('    <p>As is the case with regards to SQL for relational databases and XQUERY for XML databases, ');
      http('    SPARQL is database and host operating system independent.<p>\n');
      http('	<p>The development and evolution of this standard is overseen by the\n');
      http('	<a href="http://www.w3.org/2009/sparql/wiki/Main_Page">SPARQL Working Group</a> within W3C and\n');
      http('	while parts of the language are still in active development, it is fully <a href="http://www.w3.org/TR/sparql11-overview/">documented</a> and <a href="http://www.w3.org/2009/05/sparql-phase-II-charter">publicly</a> available.</p>\n');
    }
  else if (help_topic='enable_sponge')
    {
      declare host_ur varchar;
      host_ur := registry_get ('URIQADefaultHost');
      host_ur := http_request_header (lines, 'Host', null, host_ur);
      http('<h3>How To Enable Sponge?</h3>
      <p>When a new Virtuoso server is installed, the default security restrictions do not allow SPARQL endpoint users to retrieve remote RDF data.
      To remove this restriction, the DBA should grant "SPARQL_SPONGE" privilege to "SPARQL" account.
      If you are the Database Administrator and want to enable this feature, you can perform the following steps:</p>\n');
      http('<ol>\n');
      http('<li>Go to the Virtuoso Administration Conductor i.e. \n');
      if (not isstring (host_ur))
          http('http://host:port/conductor .');
      else
          http( sprintf('<a href="http://%s/conductor">http://%s/conductor</a>.', host_ur, host_ur));
      http('</li>\n');
      http('<li>Login as dba user.</li>\n');
      http('<li>Go to System Admin->User Accounts->Roles</li>\n');
      http('<li>Click the link "Edit" for "SPARQL_SPONGE"</li>\n');
      http('<li>Select from the list of available user/groups "SPARQL" and click the ">>" button so to add it to the right-positioned list.\n</li>');
      http('<li>Click the button "Update"</li>\n');
      http('<li>Access again the sparql endpoint in order to be able to retrieve remote data.</li>\n');
      http('</ol>\n');
    }
  else if (help_topic='enable_cxml')
    {
      http('<h3>How To Enable CXML Support</h3>');
      http('<p>CXML is data exchange format for so-called "faceted view". It can be displayed by programs like Microsoft Pivot.</p>');
      http('<p>For best results, the result of the query should contain links to images associated with described data and follow some rules, described in the User&apos;s Guide.</p>');
      http('<p>This feature is supported by combination of four components:</p>\n');
      http('<ol>\n');
      http('<li>The Virtuoso Universal Server (Virtuoso Open Source does not contain some required functions)</li>\n');
      http('<li>The ImageMagick plugin (version 0.6 or newer) and optionally the QRcode plugin</li>\n');
      http('<li>The QRcode plugin (version 0.1 or newer)</li>\n');
      http('<li>The sparql_cxml VAD package (which in turn requires the &quot;RDF mappers&quot; package)</li>\n');
      http('</ol>\n');
      http('<p>As soon as all these components are installed, the SPARQL web service endpoint will add the &quot;CXML&quot; option to the list of available formats.</p>\n');
    }
  else if (help_topic='enable_det')
    {
      http('<h3>How To Let the SPARQL Endpoint Save Results In WebDAV?</h3>');
      http('<p>By default, the SPARQL endpoint can only sent the result back to the client. This can be inconvenient if the result should be accessible for programs like file managers and archivers.</p>');
      http('<p>The solution is to let the endpoint create &quot;dynamic&quot;resources in a WebDAV folder on the Virtuoso server. A WebDAV client, e.g. the built-in client of Windows Explorer, can connect to that storage and access these resources as if they are plain local files.</p>');
      http('<p>If you are the Database Administrator and want to enable this feature, you can perform the following steps:</p>\n');
      http('<ol>\n');
      http( sprintf('<li>This web service endpoint runs under the &quot;%.100s&quot; account. This user should have an access to WebDAV (U_DAV_ENABLE=1 in DB.DBA.SYS_USERS)</li>\n', user_id));
      http( sprintf('<li>A WebDAV home directory (e.g. <a href="/DAV/home/%.100s/">/DAV/home/%.100s/</a>) should be created and the path to it should be remembered in DB.DBA.SYS_USERS (U_HOME) field;<br />(do not forget the leading and the trailing slash chars).</li>\n', user_id, user_id));
      http( sprintf('<li>This home directory should contain a subdirectory named &quot;saved-sparql-results&quot;, and the subdirectory should be of &quot;DynaRes&quot; DAV Extension Type.</li>\n'));
      http('</ol>\n');
      http('<p>As soon as the appropriate directory exists, the SPARQL web service endpoint will show additional controls to choose how to save results.</p>\n');
    }
  else if (help_topic='nsdecl')
    {
      http ('    <table class="tableresult" border="1">\n');
      http (sprintf ('	<tr><th>Prefix</th><th>URI</th></tr>\n'));
      for select NS_PREFIX, NS_URL from SYS_XML_PERSISTENT_NS_DECL order by 1 do
        {
           http (sprintf ('	<tr><td>%V</td><td><a href="%s">%V</a></td></tr>\n', NS_PREFIX, NS_URL, NS_URL));
        }
      http ('    </table>\n');
    }
  else if (help_topic='rdfinf')
    {
      http ('    <table class="tableresult" border="1">\n');
      http (sprintf ('	<tr><th>Name</th><th>URI</th></tr>\n'));
      for select * from SYS_RDF_SCHEMA order by 1 do
        {
          http (sprintf ('	<tr><td>%V</td><td>%V</td></tr>\n', RS_NAME, RS_URI));
        }
      http ('    </table>\n');
    }
  else if (help_topic='views')
    {
      declare storage_is_dflt integer;
      storage_is_dflt := 0;
      if (exists
        (sparql define input:storage "" ask from virtrdf:
          where
            {
              virtrdf:DefaultQuadStorage	a virtrdf:QuadStorage ; virtrdf:qsDefaultMap virtrdf:DefaultQuadMap	; virtrdf:qsMatchingFlags virtrdf:SPART_QS_NO_IMPLICIT_USER_QM .
              virtrdf:TmpQuadStorage		a virtrdf:QuadStorage ; virtrdf:qsDefaultMap virtrdf:TmpQuadMap		; virtrdf:qsMatchingFlags virtrdf:SPART_QS_NO_IMPLICIT_USER_QM .
              virtrdf:DefaultServiceStorage	a virtrdf:QuadStorage ; virtrdf:qsDefaultMap virtrdf:DefaultServiceMap	; virtrdf:qsMatchingFlags virtrdf:SPART_QS_NO_IMPLICIT_USER_QM .
              virtrdf:SyncToQuads		a virtrdf:QuadStorage .
            } )
        and 3 = (sparql define input:storage "" select count (1) from virtrdf: where { [] virtrdf:qsDefaultMap [] } )
        and 3 = (sparql define input:storage "" select count (1) from virtrdf: where { [] a virtrdf:QuadMap } )
        and 0 = (sparql define input:storage "" select count (1) from virtrdf: where { [] virtrdf:qsUserMaps/rdf:_1 [] } ) )
        storage_is_dflt := 1;
      http('<h3>How To Let Virtuoso Render Relational Data As RDF?</h3>');
      http('<p>By default, Virtuoso stores all RDF data in a single "RDF Storage" that consists of one four-column relational table containing all triples of all graphs.</p>');
      if (storage_is_dflt)
        http('<p><b>The Virtuoso instance seems to be in the default configuration now, probably you do not have to inspect the rest of this page.</b></p>');
      http('<p>System Administrator can extend this basic schema with more storages and more groups of triples to represent a variety of SQL tables and views stored in Virtuoso or in attached data sources.</p>');
      for (sparql define output:valmode "LONG" define input:storage "" select ?storage from virtrdf: where { ?storage a virtrdf:QuadStorage } order by asc(str(?storage))) do
        {
          declare default_qm IRI_ID;
          declare qm_count integer;
          http ('<a name="' || md5(id_to_iri ("storage")) || '" id="' || md5(id_to_iri ("storage")) || '">');
          http ('<h3>Storage &lt;'); http_value (id_to_iri ("storage")); http ('&gt;</h3>');
          if ('http://www.openlinksw.com/schemas/virtrdf#DefaultQuadStorage' = id_to_iri ("storage"))
            http ('<p>This pre-defined storage is used by default by all SPARQL queries.</p>');
          if ('http://www.openlinksw.com/schemas/virtrdf#TmpQuadStorage' = id_to_iri ("storage"))
            http ('<p>This pre-defined storage is used internally for temporary quads made during work of EXTRACT {...} FROM CONSTRUCT {...} WHERE {...} operator</p>');
          else if ('http://www.openlinksw.com/schemas/virtrdf#DefaultServiceStorage' = id_to_iri ("storage"))
            http ('<p>This pre-defined storage is used internally for SERVICE {...} clauses of SPARQL queries; not for regular use.</p>');
          else if ('http://www.openlinksw.com/schemas/virtrdf#SyncToQuads' = id_to_iri ("storage"))
            http ('<p>This pre-defined storage is to enumerate quad maps mentioned by triggers based on RDF Views; these triggers track changes in source tables of RDF Views and materialize updated content of views as "physical" triples.</p>');
          else
            http ('<p>This storage is created by some application or by a system administrator.\n');
          qm_count := (sparql define input:storage "" select count (1) from virtrdf: where { `iri(?:storage)` virtrdf:qsUserMaps ?maps . ?maps ?p ?qm . ?qm a virtrdf:QuadMap . });
          if (qm_count > 0)
            {
              http ('It contains ' || qm_count || ' top-level quad maps ("RDF Views"):</p>\n');
              http ('  <ol>\n');
              for (sparql define output:valmode "LONG" define input:storage "" select ?qm from virtrdf:
                where {
                    `iri(?:storage)` virtrdf:qsUserMaps ?maps . ?maps ?p ?qm . ?qm a virtrdf:QuadMap .
                    bind (bif:sprintf_inverse (str (?p), bif:concat (str(rdf:_), "%d"), 0) as ?arr)
                    filter (bound (?arr)) }
                order by asc (bif:aref (?arr, 0)) ) do
                {
                  http ('    <li>Top-level quad map ("RDF View") &lt;'); http_value (id_to_iri ("qm")); http ('&gt;<br/>\n');
                  WS.WS.SPARQL_ENDPOINT_QM_OVERVIEW (qm);
                  http ('    </li>');
                }
              http ('  </ol>\n');
            }
          else
            http ('</p>\n<p>The storage contains no RDF Views.</p>\n');
          default_qm := (sparql define input:storage "" select ?qm from virtrdf: where { `iri(?:storage)` virtrdf:qsDefaultMap ?qm . ?qm a virtrdf:QuadMap . });
          if (default_qm is not null)
            {
              http ('  <p>The storage has a default quad map &lt;'); http_value (id_to_iri ("default_qm")); http ('&gt;<br/>\n');
              WS.WS.SPARQL_ENDPOINT_QM_OVERVIEW (default_qm);
              http ('  </p>');
            }
          else
            http ('  <p>The storage has no default quad map.</p>\n');
          for (sparql define output:valmode "LONG" define input:storage "" select ?sml from virtrdf: where { `iri(?:storage)` virtrdf:qsMacroLibrary ?sml } order by asc(str(?sml))) do
            {
              http ('  <p>The storage is enriched with SPIN/SPARQL-BI macro library &lt;<a href="?help=macrolibs#' || md5(id_to_iri("sml")) || '">');
              http_value (id_to_iri ("default_qm")); http ('</a>&gt;<br/>\n');
--              WS.WS.SPARQL_ENDPOINT_SML_OVERVIEW (default_qm); !!!TBD: write such a function
              http ('  </p>');
            }
        }
    }
  else if (help_topic='macrolibs')
    {
      declare sml_count, macro_ctr, macro_count integer;
      declare make_gp_remark, make_nested_alias_remark, make_alias_remark, make_nested_const_read_remark integer;
      sml_count := 0;
      for (sparql define output:valmode "LONG" define input:storage "" select ?sml from virtrdf: where { ?sml a virtrdf:SparqlMacroLibrary } order by asc(str(?sml))) do
        {
          declare macro_list any;
          sml_count := sml_count + 1;
          http ('<a name="' || md5(id_to_iri ("sml")) || '" id="' || md5(id_to_iri ("sml")) || '">');
          http ('<h3>Macro Library &lt;'); http_value (id_to_iri ("sml")); http ('&gt;</h3>');
          macro_list := null;
            { whenever sqlstate '*' goto macro_compilation_error;
              macro_list := sparql_list_macro_in_lib (id_to_iri ("sml"));
              goto macro_compilation_done;
macro_compilation_error:
              http ('  <p>This macro library is not available due to error<br><pre>' || __SQL_STATE || ': '); http_value (__SQL_MESSAGE); http ('</pre></p>');
            }
macro_compilation_done:
          if (macro_list is not null)
            {
              -- rowvector_obj_sort (macro_list, 0, 1);
              -- rowvector_obj_sort (macro_list, 1, 1);
              http ('  <ul>\n');
              foreach (any macro_data in macro_list) do
                {
                  declare argctr, argcount integer;
                  declare graph_arg any;
                  http (case
                    when (macro_data[3] and (length(macro_data[5][2]) = 2)) then '    <li>Magic predicate &lt;'
                    when (macro_data[3]) then '    <li>Magic triple pattern &lt;'
                    else '    <li>Macro &lt;' end );
                  http_value (macro_data[0]); http ('&gt;');
                  http (case when (macro_data[3]) then ' for triples like {' else ' (' end);
                  argcount := length (macro_data[5]);
                  graph_arg := case when (macro_data[3] and not isinteger (macro_data[5][0])) then macro_data[5][0] else null end;
                  for (argctr := 0; argctr < argcount; argctr := argctr + 1)
                    {
                      declare arg any;
                      http (case when (macro_data[3]) then ' ' when (0 = argctr) then '' else ', ' end);
                      arg := macro_data[5][argctr];
                      if (graph_arg is not null and (argctr = 0)) http ('GRAPH ');
                      if (arg is null)
                        { ; }
                      else if (arg[0] is null)
                        {
                          if (length (arg) = 2)
                            { http ('&lt;'); http_value (arg[1]); http ('&gt;'); }
                          else if (isstring (arg[2]))
                            http_value (arg[2]);
                          else if (isstring (arg[1]))
                            { http ('"'); http_value (arg[1]); http ('"'); }
                          else
                            { http_value (arg[1]); }
                        }
                      else
                        {
                          http ('?'); http (arg[0]);
                          if (bit_and (arg[1], 0hex10))
                            { http ('<SUP><A href="#gp_remark">[GP]</A></SUP>'); make_gp_remark := 1; }
                          if (bit_and (arg[1], 0hex80))
                            { http ('<SUP><A href="#nested_alias_remark">[nested-alias]</A></SUP>'); make_nested_alias_remark := 1; }
                          else if (bit_and (arg[1], 0hex08))
                            { http ('<SUP><A href="#alias_remark">[alias]</A></SUP>'); make_alias_remark := 1; }
                          if (bit_and (arg[1], 0hex40))
                            { http ('<SUP><A href="#nested_const_read_remark">[nested-expr]</A></SUP>'); make_nested_const_read_remark := 1; }
                        }
                      if (graph_arg is not null and (argctr = 0)) http (' {');
                      if (graph_arg is not null and (argctr = 3)) http (' }');
                    }
                  http (case when (macro_data[3]) then ' }' else ')' end);
                  if (macro_data[1] is not null)
                    { http (' of SPIN class &lt;'); http_value (macro_data[1]); http ('&gt;'); }
                  if (macro_data[2] is not null)
                    { http (' &mdash; '); http_value (macro_data[2]); }
                  http ('</li>\n');
                }
              http ('  </ul>\n');
            }
          for (sparql define output:valmode "LONG" define input:storage "" select ?storage from virtrdf: where { ?storage virtrdf:qsMacroLibrary `iri(?:sml)` } order by asc(str(?storage))) do
            {
              http ('  <p>The macro library is attached to RDF storage &lt;<a href="?help=views#' || md5(id_to_iri("storage")) || '">');
              http_value (id_to_iri ("storage")); http ('</a>&gt;<br/>\n');
              http ('  </p>');
            }
        }
      if (sml_count = 0)
        http ('  <p>This Virtuoso instance has no macro libraries in its system metadata.</p>\n');
      if (make_gp_remark)
        http ('<a name="gp_remark" id="gp_remark"><p><B>?name<SUP><A href="#gp_remark">[GP]</A></SUP></B>
indicates that the parameter of the macro should be a group pattern, not a plain variable or other expression.</p>');
      if (make_nested_alias_remark)
        http ('<a name="nested_alias_remark" id="nested_alias_remark"><p><B>?name<SUP><A href="#nested_alias_remark">[nested-alias]</A></SUP></B>
warns that the parameter of the macro should be a plain variable name and not anythig else, because inside the macro it is used as a name of variable to bind with <B>x AS ?name</B> expression.</p>');
      if (make_alias_remark)
        http ('<a name="alias_remark" id="alias_remark"><p><B>?name<SUP><A href="#alias_remark">[alias]</A></SUP></B>
warns that the parameter is used as a name of variable to bind with <B>x AS ?name</B> expression. If the value is not a variable, a proxy variable is created by the compiler. As a result, the semantics of the query may differ from "self-evident" one. When in doubt, write the query in such a way that the variable name is passed to the macro, then add a filter based on the value of the variable.</p>');
      if (make_nested_const_read_remark)
        http ('<a name="nested_const_read_remark" id="nested_const_read_remark"><p><B>?name<SUP><A href="#nested_const_read_remark">[nested-expr]</A></SUP></B>
warns that the parameter is used as an expression in nested group graph pattern inside the macro body. If the parameter is an expression that contains variables then these variables may be not bound inside that group graph pattern, resulting in wrong semantics. This is usually not the case for magic predicates, other macro should be carefully studied before use.
</p>');
    }
  else
    {
      DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
        '500', 'Request Failed',
        '(no query)', '00000', 'Invalid help topic', format);
    }
  http('');
  http('<p>To close this help, press ');
  http ('<button type="button" name="back" value="Back" onclick="javascript:history.go(-1);">Back</button>\n');
  http(' or use the &quot;back&quot; button of the browser.</p>\n');
  http('</div>\n\n');
  WS.WS.SPARQL_ENDPOINT_FOOTER();
  http('</body>\n');
  http('</html>\n');
}
;


create procedure WS.WS.SPARQL_ENDPOINT_EXPLAIN_REPORT (inout full_query any)
{
      declare report any;
      --http_header (http_header_get () || 'Context-Type: text/plain\r\n');
      http ('<html><head><title>Compilation Details</title></head>\n');
      http ('<body>\n');
      http ('<h3>SPARQL query as it is passed by web page to the SPARQL compiler</h3>\n');
      http ('<pre>\n');
      http_value (signed_query_to_exec);
      http ('\n</pre>\n');
      http ('<h3>SPARQL query after parsing, optimization, and converting back into SPARQL</h3>\n');
      whenever sqlstate '*' goto err_on_detalize;
      report := sparql_detalize (concat ('{', full_query, '\n}'));
      http ('<pre>\n');
      http_value (report);
      http ('\n</pre>\n');
      goto detalize_done;
err_on_detalize:
      http ('<pre><b>ERROR ' || __SQL_STATE || ': '); http_value (__SQL_MESSAGE); http ('</b></pre>\n');
detalize_done:
      http ('<h3>SPARQL query translated to SQL</h3>\n');
      whenever sqlstate '*' goto err_on_sql_text;
      report := sparql_to_sql_text (concat ('{ define sql:comments 0 ', full_query, '\n}'));
      http ('<i>For security reasons, code responsible for graph-level security is not generated and some account-specific data are intentionally made wrong.</i>\n');
      http ('<pre>\n');
      http_value (report);
      http ('\n</pre>\n');
      goto sql_text_done;
err_on_sql_text:
      http ('<pre><b>ERROR ' || __SQL_STATE || ': '); http_value (__SQL_MESSAGE); http ('</b></pre>\n');
sql_text_done:
      http ('<h3>SQL execution plan</h3>\n');
      whenever sqlstate '*' goto err_on_sql_explain;
      state := '00000';
      metas := null;
      rset := null;
      commit work;
      exec (concat ('explain (', WS.ws.STR_SQL_APOS ('sparql {' || full_query || '\n}'), ')'), state, msg, vector(), vector ('use_cache', 0), metas, rset);
      if ('00000' <> state)
        {
          http ('<pre><b>ERROR ' || state || ': '); http_value (msg); http ('</b></pre>\n');
        }
      else
        {
          http ('<pre>\n');
          foreach (any res in rset) do { http_value (res[0]); http ('\n'); }
          http ('</pre>\n');
        }
      goto sql_explain_done;
err_on_sql_explain:
      http ('<pre><b>ERROR ' || __SQL_STATE || ': '); http_value (__SQL_MESSAGE); http ('</b></pre>\n');
sql_explain_done:
      http ('<h3>Internal optimizer data</h3>\n');
      whenever sqlstate '*' goto err_on_sparql_explain;
      report := sparql_explain (concat ('{ define sql:comments 1 ', full_query, '\n}'));
      http ('<i>These data are primarily for OpenLink support, to get additional details about the query processing.</i>\n');
      http ('<pre>\n');
      http_value (report);
      http ('\n</pre>\n');
      goto sparql_explain_done;
err_on_sparql_explain:
      http ('<pre><b>ERROR ' || __SQL_STATE || ': '); http_value (__SQL_MESSAGE); http ('</b></pre>\n');
sparql_explain_done:
      http ('</body></html>\n');
}
