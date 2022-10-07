--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2022 OpenLink Software
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


create function WS.WS.SPARQL_ENDPOINT_CDN (in url varchar, in file varchar, in checksum varchar, in no_checksum integer := 0) returns varchar
{
    declare path any;
    declare integrity varchar;
    declare line varchar;

    path := registry_get ('sparql-ui-cdn', '');
    if (length(path) = 0)
    {
        path := url;
        if (length(checksum) > 0)
            integrity := sprintf('integrity="%s" crossorigin="anonymous"', checksum);
    }
    if (path = 'disable')
        return;

    if (no_checksum > 0)
      integrity := '';

    path := rtrim (path, ' /') || '/' || file;

    if (file like '%.js')
        line := sprintf ('<script src="%H" %s></script>\n', path, integrity);
    else
        line := sprintf ('<link rel="stylesheet" href="%H" %s />\n', path, integrity);

    return line;
}
;


create procedure WS.WS.SPARQL_ENDPOINT_HTML_DOCTYPE ()
{
    set http_charset='utf-8';
    set http_in_charset='utf-8';

    http('<!DOCTYPE html>\n');
    http('<html lang="en">\n');
}
;


create procedure WS.WS.SPARQL_ENDPOINT_HTML_HEAD (in title varchar)
{ ?>
    <meta charset="utf-8" />
    <meta name="viewport"  content="width=device-width, initial-scale=1, shrink-to-fit=no" />
    <meta name="Copyright" content="Copyright &#169; <?V year(now()) ?> OpenLink Software" />
    <meta name="Keywords"  content="OpenLink Virtuoso Sparql" />
    <title><?V title ?></title>

    <link rel="icon" href="/favicon.ico?v=1" sizes="any" />
    <link rel="icon" href="/favicon/favicon.svg?v=1" type="image/svg+xml" />
    <link rel="apple-touch-icon" href="/favicon/apple-touch-icon-180x180.png?v=1" />
    <link rel="manifest" href="/favicon/manifest.webmanifest?v=1" />
<?vsp
}
;


create procedure WS.WS.SPARQL_ENDPOINT_STYLE (in enable_bootstrap integer := 0)
{
    if (enable_bootstrap) {
        http (WS.WS.SPARQL_ENDPOINT_CDN('https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.6.0/css/', 'bootstrap.min.css',
            'sha512-P5MgMn1jBN01asBgU0z60Qk4QxiXo86+wlFahKrsQf37c9cro517WzVSPPV1tDKzhku2iJ2FVgL67wG03SGnNA=='));
        return;
    }
?>
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
<?vsp
}
;



create procedure WS.WS.SPARQL_ENDPOINT_JAVASCRIPT (in can_cxml integer, in can_qrcode integer)
{ ?>
    <script>
    /*<![CDATA[*/
    var timer = 0;
    var curr_format = 0;
    var can_cxml = <?V can_cxml ?>;
    var can_qrcode = <?V can_qrcode ?>;
    var can_fct = <?V isnotnull (DB.DBA.VAD_CHECK_VERSION ('fct')) ?>;
    var max_url = <?V atoi (registry_get('sparql-ui-max-url', '0')) ?>;

    var using_IE = /edge|msie\s|trident\//i.test(window.navigator.userAgent || '');
    if (using_IE && (max_url == 0 || max_url > 2000)) {
        max_url = 2000;
    }

    function format_select (query_obg) {
        clearTimeout (timer);
        timer = setTimeout (function delay_format_select () { do_format_select (query_obg); }, 1000);
    }

    function do_format_select (query_obg) {
        var query = query_obg.value;
        var format = query_obg.form.format;
        var prev_value = format.options[format.selectedIndex].value;
        var prev_format = curr_format;
        var ctr = 0;
        var query_is_construct = (query.match(/\bconstruct\b\s/i) || query.match(/\bdescribe\b\s/i));

        if (query_is_construct && curr_format != 2) {
            for (ctr = format.options.length - 1; ctr >= 0; ctr = ctr - 1)
                format.remove(ctr);
            ctr = 0;
            format.options[ctr++] = new Option('Turtle', 'text/turtle');
            format.options[ctr++] = new Option('Turtle (beautified)', 'application/x-nice-turtle');
            format.options[ctr++] = new Option('RDF/JSON', 'application/rdf+json');
            format.options[ctr++] = new Option('RDF/XML', 'application/rdf+xml');
            format.options[ctr++] = new Option('N-Triples', 'text/plain');
            format.options[ctr++] = new Option('XHTML+RDFa', 'application/xhtml+xml');
            format.options[ctr++] = new Option('ATOM+XML', 'application/atom+xml');
            format.options[ctr++] = new Option('ODATA/JSON', 'application/odata+json');
            format.options[ctr++] = new Option('JSON-LD (plain)', 'application/x-ld+json');
            format.options[ctr++] = new Option('JSON-LD (with context)', 'application/ld+json');
            format.options[ctr++] = new Option('HTML (list)', 'text/x-html+ul');
            format.options[ctr++] = new Option('HTML (table)', 'text/x-html+tr');
            format.options[ctr++] = new Option('HTML+Microdata (basic)', 'text/html');
            format.options[ctr++] = new Option('HTML+Microdata (table)', 'application/x-nice-microdata');
            format.options[ctr++] = new Option('HTML+JSON-LD (basic)', 'text/x-html-script-ld+json');
            format.options[ctr++] = new Option('HTML+Turtle (basic)', 'text/x-html-script-turtle');
            format.options[ctr++] = new Option('Turtle (beautified - browsing oriented)', 'text/x-html-nice-turtle');
            format.options[ctr++] = new Option('Microdata/JSON', 'application/microdata+json');
            format.options[ctr++] = new Option('CSV', 'text/csv');
            format.options[ctr++] = new Option('TSV', 'text/tab-separated-values');
            format.options[ctr++] = new Option('TriG', 'application/x-trig');
            curr_format = 2;
        }

        if (!query_is_construct && curr_format != 1) {
            for (ctr = format.options.length - 1; ctr >= 0; ctr = ctr - 1)
                format.remove(ctr);
            ctr = 0;
            format.options[ctr++] = new Option('Auto', 'auto');
            format.options[ctr++] = new Option('HTML', 'text/html');
            if (can_fct)
                format.options[ctr++] = new Option('HTML (Faceted Browsing Links)','text/x-html+tr');
            else
                format.options[ctr++] = new Option('HTML (Basic Browsing Links)','text/x-html+tr');
            format.options[ctr++] = new Option('Spreadsheet', 'application/vnd.ms-excel');
            format.options[ctr++] = new Option('XML', 'application/sparql-results+xml');
            format.options[ctr++] = new Option('JSON', 'application/sparql-results+json');
            format.options[ctr++] = new Option('Javascript', 'application/javascript');
            format.options[ctr++] = new Option('Turtle', 'text/turtle');
            format.options[ctr++] = new Option('RDF/XML', 'application/rdf+xml');
            format.options[ctr++] = new Option('N-Triples', 'text/plain');
            format.options[ctr++] = new Option('CSV', 'text/csv');
            format.options[ctr++] = new Option('TSV', 'text/tab-separated-values');
            curr_format = 1;
        }


        if (prev_format != curr_format) {
	    if (can_cxml) {
		format.options[ctr++] = new Option('CXML (Pivot Collection)', 'text/cxml');
		if (can_qrcode)
		    format.options[ctr++] = new Option('CXML (Pivot Collection with QRcodes)', 'text/cxml+qrcode');
	    }
            for (ctr = format.options.length - 1, format.selectedIndex = 0; ctr >= 0; ctr = ctr - 1)
                if (format.options[ctr].value == prev_value) format.selectedIndex = ctr;
        }

    }

    function format_change (e) {
        var format = e.value;
        var cxml = document.getElementById ("cxml");
        var cxml_subj = document.getElementById ("CXML_redir_for_subjs");
        var cxml_href = document.getElementById ("CXML_redir_for_hrefs");
        if (!cxml) return;
        if ((format.match (/\bCXML\b/i))) {
            if (cxml_subj) cxml_subj.removeAttribute ("disabled");
            if (cxml_href) cxml_href.removeAttribute ("disabled");
            cxml.style.display = "block";
        } else {
            if (cxml_subj) cxml_subj.setAttribute ("disabled", "disabled");
            if (cxml_href) cxml_href.setAttribute ("disabled", "disabled");
            cxml.style.display = "none";
        }
    }

    function savedav_change (e) {
        var savefs = document.getElementById ("savefs");
        if (!savefs) return;
        if (e.checked) {
            savefs.style.display = "block";
        } else {
            savefs.style.display = "none";
        }
    }

    function change_run_button (e) {
        var button = document.getElementById ("run");
        var lbl;
        if (!button) return;
        if (e.checked) {
            lbl = " Explain Query ";
        } else {
            lbl = " Execute Query ";
        }

        if (button) {
            if (button.childNodes[0]) {
                button.childNodes[0].nodeValue = lbl;
            } else if (button.value) {
                button.value = lbl;
            } else { //if (button.innerHTML)
                button.innerHTML = lbl;
            }
        }
    }

    function sparqlGenerateLink (edit) {
        var link;
        var first = true;

        if (typeof location.origin === "undefined")
            location.origin = location.protocol + "//" + location.host;
        link = location.origin + location.pathname;

        $("form input[type!=checkbox],input[type=checkbox]:checked,select,textarea").each (function () {
            if (this.name.length > 0 && this.name != "sid" && !this.disabled) {
                var name = this.name;

                if (edit === 1 && name == "query")
                    name = "qtxt";

                if (first)
                    link += "?";
                else
                    link += "&"
                link += (name + "=" + encodeURIComponent (this.value));
                first = false;
            }
        });

        return link;
    }

    function sparqlCopyPermalinkToClipboard () {
        var link = sparqlGenerateLink(1);

        var el = document.createElement ('textarea');
        el.value = link;
        el.setAttribute ('readonly', '');
        el.style = { position: 'absolute', left: '-9999px' };
        document.body.appendChild (el);
        el.select ();
        document.execCommand ('copy');
        document.body.removeChild (el);

        sparqlShowAlert ({ message: 'Copied permalink to clipboard', class: 'success', timeout: 5000 });

        return link;
    }

    function sparqlSubmitForm () {
        var link = sparqlGenerateLink(1);

        if (max_url > 0 && max_url < link.length) {
            $('#sparql_form').attr('method', 'post');
        }
        document.forms['sparql_form'].submit();
    }


    function sparqlSubmitFormWithCtrlEnter () {
        $('form').keydown (function (event) {
            if (event.ctrlKey && event.keyCode === 13) {
                sparqlSubmitForm();
            }
        })
    }

    function sparqlAlertTimeout (wait) {
        setTimeout (function () {
            $('#alert').children ('.alert:first-child').remove ();
        }, wait);
    }

    function sparqlShowAlert (obj) {
        var html = '<div class="alert alert-' + obj.class + ' alert-dismissible" role="alert">' +
            '   <strong>' + obj.message + '</strong>' +
            '       <button class="close" type="button" data-dismiss="alert" aria-label="Close">' +
            '           <span aria-hidden="true">×</span>' +
            '       </button>'
        '   </div>';

        $('#alert').append (html);
        if (obj.timeout > 0) sparqlAlertTimeout (obj.timeout);
    }

    function sparql_endpoint_init () {
        var format = document.getElementById ("format");
        if (format) format_change (format);
        var savefs = document.getElementById ("savefs");
        if (savefs) {
            var save = document.getElementById ("save");
            if (save)
                savedav_change (save);
        }
        var b = document.getElementById ("explain");
        if (b) change_run_button (b);

        sparqlSubmitFormWithCtrlEnter ();
    }
    /*]]>*/
    </script>
<?vsp
}
;


create procedure WS.WS.SPARQL_ENDPOINT_FOOTER ()
{ ?>
    <footer id="footer" class="page-footer small">
    <div class="footer-copyright text-center">
        Copyright &#169; <?V year(now()) ?> <a href="https://virtuoso.openlinksw.com/">OpenLink Software</a>
        <br/>
        Virtuoso version <?V sys_stat('st_dbms_ver') ?> on <?V sys_stat('st_build_opsys_id') ?> (<?V host_id() ?>)
<?vsp
    declare rss any;

    rss := getrusage();

    if (1 = sys_stat('cl_run_local_only'))
    {
        http(sprintf ('Single Server Edition (%s total memory', mem_hum_size (mem_info_cl())));
	if (rss <> 0)
          http (sprintf (', %s memory in use', mem_hum_size (rss[2] * 1024)));
        http (')\n');
    }
    else
        http(sprintf('Cluster Edition (%d server processes, %s total memory)\n', sys_stat('cl_n_hosts'), mem_hum_size (mem_info_cl())));
?>
    </div>
    </footer>
<?vsp
}
;

create procedure WS.WS.SPARQL_ENDPOINT_SVC_DESC ()
{
  declare ses any;
  ses := string_output ();
  http ('    <div style="display:none">\n', ses);
  http ('       <div class="description" about="#service" typeof="sd:Service">\n', ses);
  http (sprintf ('          <div rel="sd:endpoint" resource="%s://%{WSHost}s/sparql"></div>\n',
		case when is_https_ctx () then 'https' else 'http' end, ses), ses);
  http ('          <div rel="sd:feature"\n', ses);
  http ('               resource="http://www.w3.org/ns/sparql-service-description#UnionDefaultGraph"></div>\n', ses);
  http ('          <div rel="sd:feature"\n', ses);
  http ('               resource="http://www.w3.org/ns/sparql-service-description#DereferencesURIs"></div>\n', ses);
  http ('          <div rel="sd:resultFormat" resource="http://www.w3.org/ns/formats/RDF_XML"></div>\n', ses);
  http ('          <div rel="sd:resultFormat" resource="http://www.w3.org/ns/formats/Turtle"></div>\n', ses);
  http ('          <div rel="sd:resultFormat"\n', ses);
  http ('               resource="http://www.w3.org/ns/formats/SPARQL_Results_CSV"></div>\n', ses);
  http ('          <div rel="sd:resultFormat" resource="http://www.w3.org/ns/formats/N-Triples"></div>\n', ses);
  http ('          <div rel="sd:resultFormat" resource="http://www.w3.org/ns/formats/N3"></div>\n', ses);
  http ('          <div rel="sd:resultFormat"\n', ses);
  http ('               resource="http://www.w3.org/ns/formats/SPARQL_Results_JSON"></div>\n', ses);
  http ('          <div rel="sd:resultFormat" resource="http://www.w3.org/ns/formats/RDFa"></div>\n', ses);
  http ('          <div rel="sd:resultFormat"\n', ses);
  http ('               resource="http://www.w3.org/ns/formats/SPARQL_Results_XML"></div>\n', ses);
  http ('          <div rel="sd:supportedLanguage"\n', ses);
  http ('               resource="http://www.w3.org/ns/sparql-service-description#SPARQL10Query"></div>\n', ses);
  http (sprintf ('          <div rel="sd:url" resource="%s://%{WSHost}s/sparql"></div>\n',
		case when is_https_ctx () then 'https' else 'http' end, ses), ses);
  http ('       </div>\n', ses);
  http ('    </div>\n', ses);
  return ses;
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
    if (regexp_match ('\\bconstruct\\b', qr, 0, 'I', 1) is not null or regexp_match ('\\bdescribe\\b', qr, 0, 'I', 1) is not null)
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
        http( sprintf ('<option value="%V" %s>%V</option>\n', x[1], case when format = x[1] then 'selected="selected"' else '' end , x[0]));
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
        http(sprintf ('<option value="%V" %s>%V</option>\n', x[0], case when s_param = x[0] then 'selected="selected"' else '' end , x[1]));
    }
}
;


create procedure WS.WS.SPARQL_ENDPOINT_CXML_OPTION (in can_pivot integer, in params varchar, in lbl varchar, in use_label integer := 1)
{
    declare val varchar;
    declare opts varchar;

    if ('CXML_redir_for_subjs' = lbl)
    {
        val := get_keyword (lbl, params, '121');
        if (use_label)
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
        if (use_label)
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
            http(sprintf ('<option value="%V" %s>%V</option>\n', x[0], case when val = x[0] then 'selected="selected"' else '' end , x[1]));
    }

    if (use_label) http ('</select><br/>\n');
}
;


create procedure WS.WS.SPARQL_ENDPOINT_HTML_MENU( in title varchar, in display_submenu integer := 1)
{ ?>
    <nav class="navbar navbar-expand-md sticky-top navbar-light bg-light">
        <a class="navbar-brand" href="/sparql"><?V title ?></a>
        <button class="navbar-toggler"
            type="button"
            data-toggle="collapse"
            data-target="#navbarSupportedContent"
            aria-controls="navbarSupportedContent"
            aria-expanded="false"
            aria-label="Toggle navigation">
            <span class="navbar-toggler-icon"></span>
        </button>

<?vsp if (display_submenu) { ?>
        <div class="collapse navbar-collapse" id="navbarSupportedContent">
            <ul class="navbar-nav mr-auto">
            <li class="nav-item"><a class="nav-link" href="/sparql/?help=intro">About</a></li>
            <li class="nav-item dropdown">
                <a class="nav-link dropdown-toggle" href="#" id="navbarDropdown" data-toggle="dropdown"
                    aria-haspopup="true" aria-expanded="false">Tables</a>
                <div class="dropdown-menu" aria-labelledby="navbarDropdown">
                    <a class="nav-item nav-link"        href="/sparql/?help=nsdecl">Namespace&#160;Prefixes</a>
                    <a class="nav-item nav-link"        href="/sparql/?help=rdfinf">Inference&#160;Rules</a>
                    <a class="nav-item nav-link"        href="/sparql/?help=macrolibs">Macros</a>
                    <a class="nav-item nav-link"        href="/sparql/?help=views">RDF Views</a>
                </div>
            </li>
            </ul>

            <ul class="navbar-nav">
<?vsp if (DB.DBA.VAD_CHECK_VERSION('conductor') is not null) { ?>
            <li class="nav-item"><a class="nav-item nav-link"        href="/conductor">Conductor</a></li>
<?vsp } ?>
<?vsp if (DB.DBA.VAD_CHECK_VERSION('fct') is not null) { ?>
            <li class="nav-item"><a class="nav-item nav-link"        href="/fct">Facet Browser</a></li>
<?vsp } ?>
            <li class="nav-item">
                <a class="nav-item nav-link" onclick="javascript:sparqlCopyPermalinkToClipboard()" href="#" title="Copy Permalink to Clipboard">Permalink</a>
            </li>
            </ul>
        </div>
<?vsp } ?>
    </nav>
<?vsp
}
;


create procedure WS.WS.SPARQL_ENDPOINT_HTML_OPTION (in lbl varchar, in help varchar, in enabled integer)
{
    declare color varchar;

    color := 'badge-light';
    if (enabled)
        color := 'badge-dark';

    http (sprintf ('<a href="/sparql/?help=%U" class="badge badge-pill %s">%V</a>\n', help, color, lbl));
}
;


create function WS.WS.SPARQL_ENDPOINT_CAN_SPONGE (in user_id varchar) returns integer
{
    if (exists (select top 1 1
        from DB.DBA.SYS_USERS as sup
        join DB.DBA.SYS_ROLE_GRANTS as g on (sup.U_ID = g.GI_SUPER)
        join DB.DBA.SYS_USERS as sub on (g.GI_SUB = sub.U_ID)
        where sup.U_NAME = user_id and sub.U_NAME = 'SPARQL_SPONGE' ))
        return 1;

    return 0;
}
;


create function WS.WS.SPARQL_ENDPOINT_SAVE_PATH (in user_id varchar) returns varchar
{
    declare save_dir any;

    save_dir := (select U_HOME from DB.DBA.SYS_USERS where U_NAME = user_id and U_DAV_ENABLE);
    if (save_dir is not null)
    {
        save_dir := rtrim (save_dir, '/') || '/saved-sparql-results/';
        if (exists (select COL_ID from WS.WS.SYS_DAV_COL where COL_DET = 'DynaRes' and COL_FULL_PATH = save_dir))
          return save_dir;
    }

    return NULL;
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
    --
    --  Get Virtuoso version
    --
    declare virtuoso_major integer;
    virtuoso_major := atoi(sys_stat('st_dbms_ver'));

    --
    --  Get owner of this page
    --
    declare user_id varchar;
    user_id := connection_get ('SPARQLUserId', 'SPARQL');


    --
    --  Check for XSL sheet to overrride UI
    --
    declare endpoint_xsl any;
    endpoint_xsl := registry_get ('sparql_endpoint_xsl', '');

    if (length(endpoint_xsl))
        http_xslt(endpoint_xsl);


    --
    --  Registry settings
    --
    declare enable_bootstrap any;
    enable_bootstrap := atoi (registry_get ('sparql-ui-bootstrap', '1'));


    --
    --  Check arguments
    --
    ini_dflt_graph := coalesce (ini_dflt_graph, '');
    def_qry := charset_recode (def_qry, 'UTF-8', '_WIDE_');


    --
    --  Check availability of optional components
    --
    declare can_cxml, can_pivot, can_qrcode, can_sponge integer;
    can_cxml := case (isnull (DB.DBA.VAD_CHECK_VERSION ('sparql_cxml'))) when 0 then 1 else 0 end;
    can_pivot := case (isnull (DB.DBA.VAD_CHECK_VERSION ('PivotViewer'))) when 0 then 1 else 0 end;
    can_qrcode := isstring (__proc_exists ('QRcode encodeString8bit', 2));
    can_sponge := WS.WS.SPARQL_ENDPOINT_CAN_SPONGE (user_id);


    --
    --  Check if the user has a $DAV_HOME/saved-sparql-results/ DynaRes directory
    --
    declare save_dir varchar;
    save_dir := WS.WS.SPARQL_ENDPOINT_SAVE_PATH (user_id);


    --
    --  Extra headers
    --
    http_header ('Content-Type: text/html; charset=UTF-8\r\n');
    if (http_request_get ('REQUEST_METHOD') = 'OPTIONS')
            http_header (http_header_get () || 'MS-Author-Via: SPARQL\r\n');


    --
    --  Start generating the editor page
    --
    WS.WS.SPARQL_ENDPOINT_HTML_DOCTYPE();
    http('<head>\n');
    WS.WS.SPARQL_ENDPOINT_HTML_HEAD('OpenLink Virtuoso SPARQL Query Editor');
    WS.WS.SPARQL_ENDPOINT_STYLE (enable_bootstrap);
    http('</head>\n');

    http('<body onload="sparql_endpoint_init()">\n');
    http('<div class="container">\n');

    WS.WS.SPARQL_ENDPOINT_HTML_MENU('SPARQL Query Editor');


    --
    --  Popup alerts
    --
    http ('<div id="alert"></div>');


    --
    --  Show which options are enabled/disabled
    --
    http ('<div class="d-flex justify-content-end small">\n');
    http ('<span class="badge">Extensions:</span>\n');
    WS.WS.SPARQL_ENDPOINT_HTML_OPTION('cxml', 'enable_cxml', can_cxml);
    WS.WS.SPARQL_ENDPOINT_HTML_OPTION('save to dav', 'enable_det', isnotnull(save_dir));
    WS.WS.SPARQL_ENDPOINT_HTML_OPTION('sponge', 'enable_sponge', can_sponge);
    http ('<span class="badge"> User: <b>' || user_id || '</b></span>\n');
    http ('</div>\n');


    --
    --  Main
    --
    http ('<main id="main">\n');
    http ('<form id="sparql_form" method="get">\n');
?>

    <fieldset class="">

        <div class="form-group">
            <label for="default-graph-uri">Default Data Set Name (Graph IRI)</label><br/>
            <input class="form-control form-control-sm" type="url" name="default-graph-uri" id="default-graph-uri" value="<?V ini_dflt_graph ?>"/>
        </div>

        <div class="form-group">
            <label for="query">Query Text</label><br/>
            <textarea class="form-control" rows="10" name="query" id="query" onchange="javascript:format_select(this)"
                onkeyup="javascript:format_select(this)"><?V def_qry ?></textarea>
        </div>

        <div class="form-group row">
            <label class="col-lg-2 col-form-label" for="format">Results Format</label>
            <div class="col-lg-10">
                <select class="form-control form-control-sm" name="format" id="format" onchange="javascript:format_change(this)">
<?vsp           WS.WS.SPARQL_ENDPOINT_FORMAT_OPTS (can_cxml, can_qrcode, params, def_qry); ?>
                </select>
            </div>
        </div>

        <div>
            <input class="btn btn-primary" type="submit" id="run" value="Execute Query"/>
            <input class="btn btn-light" type="reset" value="Reset" id="reset"/>
        </div>
    </fieldset>

    <hr />

    <fieldset class="" id="options">

<?vsp if (can_sponge) { ?>
        <div class="form-group row">
            <label class="col-lg-2 col-form-label" for="should-sponge">Sponging</label>
            <div class="col-lg-10">
            <select class="form-control form-control-sm" name="should-sponge" id="should-sponge">
<?vsp       WS.WS.SPARQL_ENDPOINT_SPONGE_OPTS (params); ?>
            </select>
            </div>
        </div>
<?vsp } ?>


<?vsp if (can_cxml) { ?>
        <div id="cxml">
        <div class="form-group row">
            <label class="col-lg-2 col-form-label" for="CXML_redir_for_subjs">External resource link</label>
            <div class="col-lg-10">
                <select class="form-control form-control-sm" name="CXML_redir_for_subjs" id="CXML_redir_for_subjs">
<?vsp           WS.WS.SPARQL_ENDPOINT_CXML_OPTION (can_pivot, params, 'CXML_redir_for_subjs', 0); ?>
                </select>
            </div>

            <label for="CXML_redir_for_hrefs" class="col-lg-2 col-form-label">Facet link behavior</label>
            <div class="col-lg-10">
                <select class="form-control form-control-sm" name="CXML_redir_for_hrefs" id="CXML_redir_for_hrefs">
<?vsp           WS.WS.SPARQL_ENDPOINT_CXML_OPTION (can_pivot, params, 'CXML_redir_for_hrefs', 0); ?>
                </select>
            </div>
        </div>
        </div>
<?vsp } ?>

        <div class="form-group row">
            <label for="timeout" class="col-lg-2 col-form-label">Execution timeout</label>
            <div class="col-lg-10">
                <div class="input-group input-group-sm">
                <input class="form-control" name="timeout" id="timeout" type="number" value="<?V timeout ?>" />
                <div class="input-group-append"><span class="input-group-text">milliseconds</span></div>
            </div>
            </div>
        </div>

        <div class="form-group row">
            <div class="col-form-label col-lg-2 pt-0">Options</div>
            <div class="col-lg-10">

                <div class="form-check">
                    <input class="form-check-input" name="signal_void" id="signal_void" type="checkbox"
                        <?vsp http( case (signal_void) when '' then '' else 'checked="checked"' end); ?> />
                    <label for="signal_void" class="form-check-label">Strict checking of void variables</label>
                </div>

<?vsp if (virtuoso_major > 7) { ?>
                <div class="form-check">
                    <input class="form-check-input" name="signal_unconnected" id="signal_unconnected" type="checkbox"
                        <?vsp http( case (signal_unconnected) when '' then '' else 'checked="checked"' end ); ?> />
                    <label for="signal_unconnected" class="form-check-label">Strict checking of variable names used in multiple clauses but not logically connected to each other</label>
                </div>

                <div class="form-check">
                    <input class="form-check-input" name="quiet_geo" id="quiet_geo" type="checkbox"
                        <?vsp http( case (quiet_geo) when '' then '' else 'checked="checked"' end ); ?> />
                    <label for="quiet_geo" class="form-check-label">Suppress errors on wrong geometries and errors on geometrical operators (failed operations will return NULL)</label>
                </div>
<?vsp } ?>

                <div class="form-check">
                    <input class="form-check-input" name="log_debug_info" id="log_debug_info" type="checkbox"
                        <?vsp http( case (log_debug_info) when '' then '' else 'checked="checked"' end ); ?> />
                    <label for="log_debug_info" class="form-check-label">Log debug info at the end of output (has no effect on some queries and output formats)</label>
                </div>

                <div class="form-check">
                    <input class="form-check-input" name="explain" id="explain" onclick="javascript:change_run_button(this)" type="checkbox"
                        <?vsp http( case (explain_report) when '' then '' else 'checked="checked"' end ); ?> />
                    <label for="explain" class="form-check-label">Generate SPARQL compilation report (instead of executing the query)</label>
                </div>

            </div>
        </div>

<?vsp if (save_dir is not null) { ?>
        <div class="form-group row">
            <div class="col-form-label col-lg-2 pt-0">Save to DAV</div>
            <div class="col-lg-10">
                <div class="form-check">
                    <input class="form-check-input" name="save" id="save" type="checkbox" onclick="savedav_change(this)"/>
                    <label for="save" class="form-check-label">Save resultset to WebDAV folder on the server</label>
                </div>

                <div id="savefs" style="display: none">

                    <div class="form-group row">
                        <input type="hidden" id="dname" name="dname" value="<?V save_dir ?>"/>
                        <label for="fname" class="col-lg-1 col-form-label">Filename</label>
                        <div class="col-lg-9">
                            <div class="input-group input-group-sm">
                                <div class="input-group-prepend"><span class="input-group-text"><?V save_dir ?></span></div>
                                <input class="form-control" type="text" id="fname" name="fname"/>
                            </div>
                        </div>
                    </div>

                    <input type="checkbox" name="dav_refresh" id="dav_refresh" <?vsp http( case when (dav_refresh is null) then '' else 'checked="checked"' end ); ?> />
                    <label class="ckb" for="dav_refresh">Refresh periodically</label>
                    <br/>
                    <input type="checkbox" name="dav_overwrite" id="dav_overwrite" <?vsp http( case when (overwrite is null or overwrite = '0') then '' else 'checked="checked"' end ); ?> />
                    <label class="ckb" for="dav_overwrite">Overwrite if exists</label>
                </div>
            </div>
        </div>
<?vsp } ?>

    </fieldset>

<?vsp
    http('</form>\n');
    http('</main>\n');


    --
    --  Endpoint description (hidden)
    --
    http (WS.WS.SPARQL_ENDPOINT_SVC_DESC ());


    --
    --  Footer
    --
    WS.WS.SPARQL_ENDPOINT_FOOTER ();

    --
    --  Javascript
    --
    http('<div id="sparql-scripts">\n');
    http (WS.WS.SPARQL_ENDPOINT_CDN ('https://cdnjs.cloudflare.com/ajax/libs/jquery/3.5.1/', 'jquery.slim.min.js',
            'sha512-/DXTXr6nQodMUiq+IUJYCt2PPOUjrHJ9wFrqpJ3XkgPNOZVfMok7cRw6CSxyCQxXn6ozlESsSh1/sMCTF1rL/g=='));
    http (WS.WS.SPARQL_ENDPOINT_CDN ('https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.6.0/js/', 'bootstrap.bundle.min.js',
            'sha512-wV7Yj1alIZDqZFCUQJy85VN+qvEIly93fIQAN7iqDFCPEucLCeNFz4r35FCo9s6WrpdDQPi80xbljXB8Bjtvcg=='));

    WS.WS.SPARQL_ENDPOINT_JAVASCRIPT(can_cxml, can_qrcode);

    http('</div>\n');

    http('</div>');
    http('</body>\n');
    http('</html>\n');
}
;


create procedure WS.WS.SPARQL_ENDPOINT_BRIEF_HELP_NSDECL()
{ ?>
    <h3>Namespace Prefixes</h3>
    <table class="table table-striped table-sm">
    <thead>
        <tr>
            <th scope="col">Prefix</th>
            <th scope="col">URI</th>
        </tr>
    </thead>
    <tbody>
<?vsp
    for select NS_PREFIX, NS_URL from SYS_XML_PERSISTENT_NS_DECL order by 1 do
    {
        http (sprintf ('<tr><td>%V</td><td><a href="%s">%V</a></td></tr>\n', NS_PREFIX, NS_URL, NS_URL));
    }
?>
    </tbody>
    </table>
<?vsp
}
;


create procedure WS.WS.SPARQL_ENDPOINT_BRIEF_HELP_RDFINF()
{ ?>
    <h3>Inference Rules</h3>
    <table class="table table-striped table-sm table-compact">
    <thead>
        <tr>
            <th scope="col">Name</th>
            <th scope="col">URI</th>
        </tr>
    </thead>
    <tbody>
<?vsp
    for select * from SYS_RDF_SCHEMA order by 1 do
    {
        http (sprintf ('<tr><td>%V</td><td>%V</td></tr>\n', RS_NAME, RS_URI));
    }
?>
    </tbody>
    </table>
<?vsp
}
;


create procedure WS.WS.SPARQL_ENDPOINT_BRIEF_HELP_INTRO()
{ ?>
    <h3>Introduction</h3>
    <p>This page is designed to help you test the OpenLink Virtuoso SPARQL protocol endpoint.</p>
    <p>Consult the
    <a href="http://vos.openlinksw.com/owiki/wiki/VOS/VOSSparqlProtocol">Virtuoso Wiki page</a>
    describing the service or the
    <a href="http://docs.openlinksw.com/virtuoso/ch-rdfandsparql/">RDF Data Access and Data Management</a>
    chapter of the
    <a href="http://docs.openlinksw.com/virtuoso/">Online Virtuoso Documentation</a>.</p>
    <p>There is also a rich Web based user interface with sample queries</p>
<?vsp
    if (DB.DBA.VAD_CHECK_VERSION('iSPARQL') is null)
        http('In order to use it, ask the site admin to install the iSPARQL package (isparql_dav.vad).</p>\n');
    else
        http('You can access it at: <a href="/isparql">/isparql</a>.</p>\n');
?>

    <h3>Endpoint Information</h3>
    <p>Consult the following links for available information defined on this endpoint:
    <ul>
    <li><a href="/sparql/?help=nsdecl">Namespace Prefixes</a>
    <li><a href="/sparql/?help=rdfinf">Build-in Inference Rules</a>
    <li><a href="/sparql/?help=views">RDF Views</a>
    <li><a href="/sparql/?help=macrolibs">SPIN and SPARQL-BI Macro Libraries</a>
    </ul>
    </p>

    <h3>What is SPARQL?</h3>
    <p>SPARQL is the W3C&quot;s declaritive query-language for Graph Model Databases and Stores.</p>
    <p>As is the case with SQL for relational databases and XQUERY for XML databases,
    SPARQL is database and host operating system independent.<p>
    <p>The development and evolution of this standard is overseen by the
    <a href="https://www.w3.org/2009/sparql/wiki/Main_Page">SPARQL Working Group</a> within W3C and
    while parts of the language are still in active development, it is fully
    <a href="https://www.w3.org/TR/sparql11-overview/">documented</a> and
    <a href="https://www.w3.org/2009/05/sparql-phase-II-charter">publicly</a> available.</p>
<?vsp
}
;


create procedure WS.WS.SPARQL_ENDPOINT_BRIEF_HELP_SPONGE(inout lines any)
{
    declare host_ur, _http varchar;
    host_ur := registry_get ('URIQADefaultHost');
    host_ur := http_request_header (lines, 'Host', null, host_ur);
    _http := case when is_https_ctx() then 'https' else 'http' end;
?>
    <h3>How To Enable Sponge?</h3>
    <p>When a new Virtuoso server is installed, the default security restrictions do not
    allow SPARQL endpoint users to retrieve remote RDF data.  To remove this restriction, the
    DBA should grant "SPARQL_SPONGE" privilege to "SPARQL" account.  If you are the Database
    Administrator and want to enable this feature, you can perform the following steps:</p>
    <ol>
    <li>Go to the Virtuoso Administration Conductor i.e.
<?vsp
    if (not isstring (host_ur))
      http('http://host:port/conductor .');
    else
      http( sprintf('<a href="%s://%s/conductor">%s://%s/conductor</a>.', _http, host_ur, _http, host_ur));
?>
    </li>
    <li>Login as dba user.</li>
    <li>Go to System Admin->User Accounts->Roles</li>
    <li>Click the link "Edit" for "SPARQL_SPONGE"</li>
    <li>Select from the list of available user/groups "SPARQL" and click the ">>" button so to add it to the right-positioned list.</li>
    <li>Click the button "Update"</li>
    <li>Access again the sparql endpoint in order to be able to retrieve remote data.</li>
    </ol>
<?vsp
}
;


create procedure WS.WS.SPARQL_ENDPOINT_BRIEF_HELP_CXML()
{
?>
    <h3>How To Enable CXML Support</h3>
    <p>CXML is a data exchange format for so-called <code>faceted views</code> which
    can be displayed by programs like the <a href="https://github.com/openlink/html5pivotviewer">HTML5 PivotViewer</a>.</p>
    <p>For best results, the result of the query should contain links to images associated
    with described data and follow some rules, described in the User&apos;s Guide.</p>
    <p>This feature is supported by combination of the following components:</p>
    <ol>
    <li>The sparql_cxml VAD package for generating CXML output (required)</li>
    <li>The ImageMagick plugin (version 0.6 or newer) for manipulating images (required)</li>
    <li>The QRcode plugin (version 0.1 or newer) for generating qrcodes (optional)</li>
    <li>The html5pivotviewer VAD package for viewing CXML queries (optional)</li>
    </ol>
    <p>As soon as the required components are installed, the SPARQL web service endpoint will
    add the &quot;CXML&quot; option to the list of available formats.</p>
<?vsp
}
;


create procedure WS.WS.SPARQL_ENDPOINT_BRIEF_HELP_DET()
{
    declare user_id varchar;
    user_id := connection_get ('SPARQLUserId', 'SPARQL');
?>
    <h3>How To Let the SPARQL Endpoint Save Results In WebDAV?</h3>
    <p>By default, the SPARQL endpoint can only sent the result back to the client. This
    can be inconvenient if the result should be accessible for programs like file managers
    and archivers.</p>
    <p>The solution is to let the endpoint create &quot;dynamic&quot;resources in a WebDAV
    folder on the Virtuoso server. A WebDAV client, e.g. the built-in client of Windows Explorer,
    can connect to that storage and access these resources as if they are plain local files.</p>
    <p>If you are the Database Administrator and want to enable this feature, you can perform
    the following steps:</p>
    <ol>
        <li>This web service endpoint runs under the &quot;<?V user_id ?>&quot; account.
        This user should have access to WebDAV (U_DAV_ENABLE=1 in DB.DBA.SYS_USERS)</li>
        <li>A WebDAV home directory (e.g. <a href="/DAV/home/<?V user_id ?>/">/DAV/home/<?V user_id ?>/</a>)
        should be created and the path to it should be remembered in DB.DBA.SYS_USERS (U_HOME) field;<br />
        (do not forget the leading and the trailing slash chars).</li>
        <li>This home directory should contain a subdirectory named &quot;saved-sparql-results&quot;,
        and the subdirectory should be of &quot;DynaRes&quot; DAV Extension Type.</li>
    </ol>
    <p>As soon as the appropriate directory exists, the SPARQL web service endpoint will show
    additional controls to choose how to save results.</p>
<?vsp
}
;


create procedure WS.WS.SPARQL_ENDPOINT_BRIEF_HELP_VIEWS()
{
    declare storage_is_dflt integer;
    storage_is_dflt := 0;
    if ((sparql define input:storage "" ask from virtrdf:
        where {
            virtrdf:DefaultQuadStorage a virtrdf:QuadStorage    ;
                virtrdf:qsDefaultMap virtrdf:DefaultQuadMap     ;
                virtrdf:qsMatchingFlags virtrdf:SPART_QS_NO_IMPLICIT_USER_QM .
            virtrdf:TmpQuadStorage a virtrdf:QuadStorage        ;
                virtrdf:qsDefaultMap virtrdf:TmpQuadMap         ;
                virtrdf:qsMatchingFlags virtrdf:SPART_QS_NO_IMPLICIT_USER_QM .
            virtrdf:DefaultServiceStorage a virtrdf:QuadStorage ;
                virtrdf:qsDefaultMap virtrdf:DefaultServiceMap  ;
                virtrdf:qsMatchingFlags virtrdf:SPART_QS_NO_IMPLICIT_USER_QM .
            virtrdf:SyncToQuads         a virtrdf:QuadStorage .
        } )
        and 3 = (sparql define input:storage "" select count (1) from virtrdf: where { [] virtrdf:qsDefaultMap [] } )
        and 3 = (sparql define input:storage "" select count (1) from virtrdf: where { [] a virtrdf:QuadMap } )
        and 0 = (sparql define input:storage "" select count (1) from virtrdf: where { [] virtrdf:qsUserMaps/rdf:_1 [] } ) ) {
            storage_is_dflt := 1;
    }

    http('<h3>How To Let Virtuoso Render Relational Data As RDF?</h3>');
    http('<p>By default, Virtuoso stores all RDF data in a single "RDF Storage" that consists of one four-column relational table containing all triples of all graphs.</p>');
    if (storage_is_dflt)
        http('<p><b>The Virtuoso instance seems to be in the default configuration now, probably you do not have to inspect the rest of this page.</b></p>');
    http('<p>The System Administrator can extend this basic schema with more storages and more groups of triples to represent a variety of SQL tables and views stored in Virtuoso or in attached data sources.</p>');
    for (sparql define output:valmode "LONG" define input:storage "" select ?storage from virtrdf: where { ?storage a virtrdf:QuadStorage } order by asc(str(?storage))) do
    {
        declare default_qm IRI_ID;
        declare qm_count integer;
        http ('<a name="' || md5(id_to_iri ("storage")) || '" id="' || md5(id_to_iri ("storage")) || '">');
        http ('<h4>Storage &lt;'); http_value (id_to_iri ("storage")); http ('&gt;</h4>');
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
        if (qm_count > 0) {
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
        } else
            http ('</p>\n<p>The storage contains no RDF Views.</p>\n');

        default_qm := (sparql define input:storage "" select ?qm from virtrdf: where { `iri(?:storage)` virtrdf:qsDefaultMap ?qm . ?qm a virtrdf:QuadMap . });
        if (default_qm is not null) {
            http ('  <p>The storage has a default quad map &lt;'); http_value (id_to_iri ("default_qm")); http ('&gt;<br/>\n');
            WS.WS.SPARQL_ENDPOINT_QM_OVERVIEW (default_qm);
            http ('  </p>');
        } else
            http ('  <p>The storage has no default quad map.</p>\n');

        for (sparql define output:valmode "LONG" define input:storage "" select ?sml from virtrdf: where { `iri(?:storage)` virtrdf:qsMacroLibrary ?sml } order by asc(str(?sml))) do {
            http ('  <p>The storage is enriched with SPIN/SPARQL-BI macro library &lt;<a href="/sparql/?help=macrolibs#' || md5(id_to_iri("sml")) || '">');
            http_value (id_to_iri ("default_qm")); http ('</a>&gt;<br/>\n');
            --              WS.WS.SPARQL_ENDPOINT_SML_OVERVIEW (default_qm); !!!TBD: write such a function
            http ('  </p>');
        }
    }
}
;


create procedure WS.WS.SPARQL_ENDPOINT_BRIEF_HELP_MACROS()
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
        {
            whenever sqlstate '*' goto macro_compilation_error;
            macro_list := sparql_list_macro_in_lib (id_to_iri ("sml"));
            goto macro_compilation_done;
macro_compilation_error:
            http ('  <p>This macro library is not available due to error<br/><pre>' || __SQL_STATE || ': '); http_value (__SQL_MESSAGE); http ('</pre></p>');
        }
macro_compilation_done:
        if (macro_list is not null) {
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
                        if (length (arg) = 2)       { http ('&lt;'); http_value (arg[1]); http ('&gt;'); }
                        else if (isstring (arg[2])) { http_value (arg[2]); }
                        else if (isstring (arg[1])) { http ('"'); http_value (arg[1]); http ('"'); }
                        else                        { http_value (arg[1]); }
                    } else {
                        http ('?'); http (arg[0]);
                        if (bit_and (arg[1], 0hex10)) { http ('<SUP><A href="#gp_remark">[GP]</A></SUP>'); make_gp_remark := 1; }
                        if (bit_and (arg[1], 0hex80)) { http ('<SUP><A href="#nested_alias_remark">[nested-alias]</A></SUP>'); make_nested_alias_remark := 1; }
                        else if (bit_and (arg[1], 0hex08)) { http ('<SUP><A href="#alias_remark">[alias]</A></SUP>'); make_alias_remark := 1; }
                        if (bit_and (arg[1], 0hex40)) { http ('<SUP><A href="#nested_const_read_remark">[nested-expr]</A></SUP>'); make_nested_const_read_remark := 1; }
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
            http ('  <p>The macro library is attached to RDF storage &lt;<a href="/sparql/?help=views#' || md5(id_to_iri("storage")) || '">');
            http_value (id_to_iri ("storage")); http ('</a>&gt;<br/>\n');
            http ('  </p>');
        }
    }
    if (sml_count = 0)
        http ('  <p>This Virtuoso instance has no macro libraries in its system metadata.</p>\n');
    if (make_gp_remark)
        http ('<a name="gp_remark" id="gp_remark"><p><B>?name<SUP><A
        href="#gp_remark">[GP]</A></SUP></B> indicates that the parameter of the macro should
        be a group pattern, not a plain variable or other expression.</p>');
    if (make_nested_alias_remark)
        http ('<a name="nested_alias_remark" id="nested_alias_remark"><p><B>?name<SUP><A
        href="#nested_alias_remark">[nested-alias]</A></SUP></B> warns that the parameter of
        the macro should be a plain variable name and not anythig else, because inside the
        macro it is used as a name of variable to bind with <B>x AS ?name</B> expression.</p>');
    if (make_alias_remark)
        http ('<a name="alias_remark" id="alias_remark"><p><B>?name<SUP><A
        href="#alias_remark">[alias]</A></SUP></B> warns that the parameter is used as a name
        of variable to bind with <B>x AS ?name</B> expression. If the value is not a variable,
        a proxy variable is created by the compiler. As a result, the semantics of the query
        may differ from "self-evident" one. When in doubt, write the query in such a way that
        the variable name is passed to the macro, then add a filter based on the value of the
        variable.</p>');
    if (make_nested_const_read_remark)
        http ('<a name="nested_const_read_remark" id="nested_const_read_remark"><p><B>?name<SUP><A
        href="#nested_const_read_remark">[nested-expr]</A></SUP></B> warns that the parameter
        is used as an expression in nested group graph pattern inside the macro body. If the
        parameter is an expression that contains variables then these variables may be not
        bound inside that group graph pattern, resulting in wrong semantics. This is usually
        not the case for magic predicates, other macro should be carefully studied before use.</p>');
}
;


create procedure WS.WS.SPARQL_ENDPOINT_BRIEF_HELP (inout path varchar, inout params any, inout lines any, in user_id varchar, in help_topic varchar)
{
#pragma prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
#pragma prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#>
    declare subtitle varchar;
    declare format varchar;
    subtitle := case help_topic
        when 'intro'                then 'About'
        when 'enable_sponge'        then 'Sponge'
        when 'enable_cxml'          then 'CXML'
        when 'enable_det'           then 'DAV'
        when 'nsdecl'               then 'Namespace Prefixes'
        when 'rdfinf'               then 'Build-in Inference Rules'
        when 'views'                then 'RDF Views'
        when 'macrolibs'            then 'SPIN and SPARQL-BI Macro Libraries'
        else 'Error' end;
    format := '';

    WS.WS.SPARQL_ENDPOINT_HTML_DOCTYPE();
    http('<head>\n');
    WS.WS.SPARQL_ENDPOINT_HTML_HEAD('Virtuoso SPARQL Query Editor | ' || subtitle);
    WS.WS.SPARQL_ENDPOINT_STYLE (1);
    http('</head>\n');


    http('<body>\n');
    http('<div class="container">\n');

    WS.WS.SPARQL_ENDPOINT_HTML_MENU('SPARQL Query Editor');

    http ('<div id="help">\n');
    if (help_topic='intro')
    {
        WS.WS.SPARQL_ENDPOINT_BRIEF_HELP_INTRO();
    }
    else if (help_topic='enable_sponge')
    {
        WS.WS.SPARQL_ENDPOINT_BRIEF_HELP_SPONGE(lines);
    }
    else if (help_topic='enable_cxml')
    {
        WS.WS.SPARQL_ENDPOINT_BRIEF_HELP_CXML();
    }
    else if (help_topic='enable_det')
    {
        WS.WS.SPARQL_ENDPOINT_BRIEF_HELP_DET();
    }
    else if (help_topic='nsdecl')
    {
        WS.WS.SPARQL_ENDPOINT_BRIEF_HELP_NSDECL();
    }
    else if (help_topic='rdfinf')
    {
        WS.WS.SPARQL_ENDPOINT_BRIEF_HELP_RDFINF();
    }
    else if (help_topic='views')
    {
        WS.WS.SPARQL_ENDPOINT_BRIEF_HELP_VIEWS();
    }
    else if (help_topic='macrolibs')
    {
        WS.WS.SPARQL_ENDPOINT_BRIEF_HELP_MACROS();
    }
    else
    {
        DB.DBA.SPARQL_PROTOCOL_ERROR_REPORT (path, params, lines,
            '500', 'Request Failed',
            '(no query)', '00000', 'Invalid help topic', format);
    }

    http('');
    http('<p>To close this help, press ');
    http ('<button class="button btn btn-secondary" type="button" name="back" value="Back" onclick="javascript:history.go(-1);">Back</button>\n');
    http(' or use the &quot;back&quot; button of the browser.</p>\n');
    http('</div>\n\n');
    WS.WS.SPARQL_ENDPOINT_FOOTER ();
    http('</div>\n');

    http('<div id="sparql-scripts">\n');
    http (WS.WS.SPARQL_ENDPOINT_CDN ('https://cdnjs.cloudflare.com/ajax/libs/jquery/3.5.1/', 'jquery.slim.min.js',
            'sha512-/DXTXr6nQodMUiq+IUJYCt2PPOUjrHJ9wFrqpJ3XkgPNOZVfMok7cRw6CSxyCQxXn6ozlESsSh1/sMCTF1rL/g=='));
    http (WS.WS.SPARQL_ENDPOINT_CDN ('https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.6.0/js/', 'bootstrap.bundle.min.js',
            'sha512-wV7Yj1alIZDqZFCUQJy85VN+qvEIly93fIQAN7iqDFCPEucLCeNFz4r35FCo9s6WrpdDQPi80xbljXB8Bjtvcg=='));
    http('</div>');

    http('</body>\n');
    http('</html>\n');
}
;



create procedure WS.WS.SPARQL_ENDPOINT_EXPLAIN_REPORT (inout full_query any)
{
    declare report any;
    declare signed_query_to_exec varchar;
    declare state, msg, metas, rset any;

    WS.WS.SPARQL_ENDPOINT_HTML_DOCTYPE();
    http('<head>\n');
    WS.WS.SPARQL_ENDPOINT_HTML_HEAD('Virtuoso SPARQL Compilation report');
    WS.WS.SPARQL_ENDPOINT_STYLE (1);
    http('<style>.example { background-color: #ddd; padding: 1em; } </style>\n');
    http('</head>\n');

    signed_query_to_exec := concat ('/*', md5(full_query), '*/\nsparql {\n', full_query, '\n}');

    http ('<body>\n');
    http ('<div class="container-fluid">\n');
?>

    <h3>Virtuoso SPARQL Compilation Report</h3>
    <p>


    <h5>Original SPARQL query</h5>
    <p>The SPARQL query as it is passed by web page to the SPARQL compiler:</p>
    <pre class="text-monospace example"><code><?V signed_query_to_exec ?></code></pre>


    <h5>Optimized SPARQL query</h5>
    <p>The SPARQL query after parsing, optimization and converting back into SPARQL</p>
<?vsp
    whenever sqlstate '*' goto detalize_error;
    report := sparql_detalize (concat ('{\n', full_query, '\n}'));

    http('<pre class="text-monospace example"><code>');
    http_value(report);
    http('</code></pre>\n');

    goto detalize_done;
detalize_error:
    http ('<pre><b>ERROR ' || __SQL_STATE || ': '); http_value (__SQL_MESSAGE); http ('</b></pre>\n');
detalize_done:
?>


    <h5>SPARQL query translated to SQL</h5>
    <p>
    <i>For security reasons, code responsible for graph-level security is not generated and some account-specific data is deliberately obfuscated.</i>
<?vsp
    whenever sqlstate '*' goto sql_text_error;
    report := sparql_to_sql_text (concat ('{ define sql:comments 0 ', full_query, '\n}'));

    http('<pre class="text-monospace example"><code>');
    http_value(report);
    http('</code></pre>\n');

    goto sql_text_done;
sql_text_error:
    http ('<pre><b>ERROR ' || __SQL_STATE || ': '); http_value (__SQL_MESSAGE); http ('</b></pre>\n');
sql_text_done:
?>


    <h5>SQL execution plan</h5>
    <p>
<?vsp
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
      http ('<pre class="text-monospace example"><code>');
      foreach (any res in rset) do { http_value (res[0]); http ('\n'); }
      http ('</code></pre>\n');
    }
    goto sql_explain_done;
err_on_sql_explain:
    http ('<pre><b>ERROR ' || __SQL_STATE || ': '); http_value (__SQL_MESSAGE); http ('</b></pre>\n');
sql_explain_done:
?>


    <h5>Internal optimizer data</h5>
    <p>
    <i>These data are primarily for OpenLink support, to get additional details about the query processing.</i>
<?vsp
    whenever sqlstate '*' goto sparql_explain_error;
    report := sparql_explain (concat ('{ define sql:comments 1 ', full_query, '\n}'));

    http('<pre class="text-monospace example"><code>');
    http_value(report);
    http('</code></pre>\n');

    goto sparql_explain_done;
sparql_explain_error:
    http ('<pre><b>ERROR ' || __SQL_STATE || ': '); http_value (__SQL_MESSAGE); http ('</b></pre>\n');
sparql_explain_done:

    http ('</div>\n</body>\n</html>\n');
}
;



--
--  Functions for generating bootstrap 4 enabled output
--
create procedure WS.WS.SPARQL_RESULT_HTML5_OUTPUT_BEGIN (in title varchar, inout ses any, in nslist any := null)
{
    set http_charset='utf-8';
    set http_in_charset='utf-8';

    http ('<!DOCTYPE html>\n', ses);
    if (nslist is not null)
    {
      declare len, ctr any;
      http ('<html prefix="', ses);
      len := length (nslist);
      for (ctr := len-2; ctr >= 0; ctr := ctr-2)
      {
        http (sprintf ('\n  %s: ', nslist[ctr+1]), ses);
        http_escape (nslist[ctr], 7, ses, 1, 1);
      }
      http ('\n" >\n', ses);
    }
    else
    {
      http ('<html>\n', ses);
    }
    http ('<head>\n', ses);
    http ('<meta charset="utf-8" />\n', ses);
    http ('<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no" />\n', ses);
    http ('<title>', ses);
    http_value(title, 0, ses);
    http ('</title>\n', ses);

    http (WS.WS.SPARQL_ENDPOINT_CDN('https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.6.0/css/', 'bootstrap.min.css',
            'sha512-P5MgMn1jBN01asBgU0z60Qk4QxiXo86+wlFahKrsQf37c9cro517WzVSPPV1tDKzhku2iJ2FVgL67wG03SGnNA=='), ses);
    http (WS.WS.SPARQL_ENDPOINT_CDN('https://cdnjs.cloudflare.com/ajax/libs/bootstrap-icons/1.4.0/font/', 'bootstrap-icons.min.css',
            'sha512-jNfYp+q76zAGok++m0PjqlsP7xwJSnadvhhsL7gzzfjbXTqqOq+FmEtplSXGVI5uzKq7FrNimWaoc8ubP7PT5w=='), ses);

    http ('</head>\n', ses);
    http ('<body>\n', ses);
    http ('<div class="container-fluid">\n', ses);
    http ('<nav class="navbar navbar-expand-md sticky-top navbar-light bg-light">', ses);
    http ('<a class="navbar-brand" href="#" onclick="javascript:history.go(-1); return false;">SPARQL | ', ses);
    http_value (title);
    http ('</a></nav>\n', ses);
}
;


create procedure WS.WS.SPARQL_RESULT_HTML5_OUTPUT_END(inout ses any)
{
    http('</div>\n</body>\n</html>\n', ses);
}
;


create procedure WS.WS.SPARQL_RESULT_XHTML_OUTPUT_BEGIN (in title varchar, inout ses any, in nslist any := null)
{
    set http_charset='utf-8';
    set http_in_charset='utf-8';

    http ('<?xml version="1.0" encoding="UTF-8"?>\n', ses);
    http ('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">\n', ses);
    if (nslist is not null)
    {
      declare len, ctr any;
      http ('<html xmlns="http://www.w3.org/1999/xhtml"', ses);
      len := length (nslist);
      for (ctr := len-2; ctr >= 0; ctr := ctr-2)
      {
        http (sprintf ('\n  xmlns:%s="', nslist[ctr+1]), ses);
        http_escape (nslist[ctr], 7, ses, 1, 1);
        http ('"', ses);
      }
      http ('\n>\n', ses);
    }
    else
    {
      http ('<html xmlns="http://www.w3.org/1999/xhtml">\n', ses);
    }
    http ('<head>\n', ses);
    http ('<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no" />\n', ses);
    http ('<title>', ses);
    http_value(title, 0, ses);
    http ('</title>\n', ses);

    http (WS.WS.SPARQL_ENDPOINT_CDN('https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.6.0/css/', 'bootstrap.min.css',
            'sha512-P5MgMn1jBN01asBgU0z60Qk4QxiXo86+wlFahKrsQf37c9cro517WzVSPPV1tDKzhku2iJ2FVgL67wG03SGnNA==', 1), ses);
    http (WS.WS.SPARQL_ENDPOINT_CDN('https://cdnjs.cloudflare.com/ajax/libs/bootstrap-icons/1.4.0/font/', 'bootstrap-icons.min.css',
            'sha512-jNfYp+q76zAGok++m0PjqlsP7xwJSnadvhhsL7gzzfjbXTqqOq+FmEtplSXGVI5uzKq7FrNimWaoc8ubP7PT5w==', 1), ses);

    http ('</head>\n', ses);
    http ('<body>\n', ses);
    http ('<div class="container-fluid">\n', ses);
    http ('<div class="navbar navbar-expand-md sticky-top navbar-light bg-light">', ses);
    http ('<a class="navbar-brand" href="#" onclick="javascript:history.go(-1); return false;">SPARQL | ', ses);
    http_value (title);
    http ('</a></div>\n', ses);
}
;


create procedure WS.WS.SPARQL_RESULT_XHTML_OUTPUT_END(inout ses any)
{
    http('</div>\n</body>\n</html>\n', ses);
}
;


--
-- vim: tabstop=4 shiftwidth=4 expandtab autoindent
--
