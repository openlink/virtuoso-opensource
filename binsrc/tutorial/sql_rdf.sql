use DB;

create procedure DB.DBA.exec_no_error (in expr varchar)
{                                              
  declare state, message, meta, result any;                                                            
  exec(expr, state, message, vector(), 0, meta, result);                                               
}
;

--GRANT SPARQL_UPDATE TO "SPARQL";
GRANT SELECT ON "WS"."WS"."SYS_DAV_RES" TO "SPARQL";
GRANT SELECT ON "WS"."WS"."SYS_DAV_COL" TO "SPARQL";
GRANT SELECT ON "WS"."WS"."SYS_DAV_PROP" TO "SPARQL";
GRANT SELECT ON "DB"."DBA"."SYS_USERS" TO "SPARQL";
GRANT SELECT ON "DB"."DBA"."TUT_SEARCH" TO "SPARQL";

create function DB.DBA.TUT_ID_TO_IRI(in _prefix varchar,in _id varchar)
{
  declare iri, uriqa_host any;
  uriqa_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  iri := 'http://' || uriqa_host || '/tutorial_view/' || _prefix || '/' || _id || '#this';
  return sprintf ('http://%s/DAV/home/tutorial_view/RDFData/All/iid%%20(%d).rdf', uriqa_host, iri_id_num (iri_to_id (iri)));
}
;

create function DB.DBA.TUT_IRI_TO_ID(in _iri varchar)
{
    declare parts any;
    parts := sprintf_inverse (_iri, 'http://%s/DAV/home/tutorial_view/RDFData/All/iid (%d).rdf', 1 );
    if (parts is not null)
    {
        declare uriqa_host, iri any;
        uriqa_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
        if (parts[0] = uriqa_host)
        {
            iri := id_to_iri(iri_id_from_num(parts[1]));
            parts := sprintf_inverse (iri, 'http://%s/tutorial_view/%s/%s#this', 1 );
            if (parts[0] = uriqa_host)
            {
                return parts[2];
            }
        }
    }
    return NULL;
}
;

create function DB.DBA.POST_IRI (in _id integer) returns varchar
{
    return TUT_ID_TO_IRI('Post', cast(_id as varchar));
}
;

create function DB.DBA.POST_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.TUT_IRI_TO_ID(_iri));
};

create function DB.DBA.SECTION_IRI (in _id integer) returns varchar
{
    return TUT_ID_TO_IRI('Section', cast(_id as varchar));
}
;

create function DB.DBA.SECTION_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.TUT_IRI_TO_ID(_iri));
};

grant execute on DB.DBA.POST_IRI to "SPARQL";
grant execute on DB.DBA.POST_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.COL_IRI to "SPARQL";
grant execute on DB.DBA.COL_IRI_INVERSE to "SPARQL";

SPARQL
prefix tutorial: <http://demo.openlinksw.com/schemas/tutorial#>
prefix bibo: <http://purl.org/ontology/bibo/>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
drop quad map graph iri("http://^{URIQADefaultHost}^/tutorial_view") .
;

SPARQL
prefix tutorial: <http://demo.openlinksw.com/schemas/tutorial#>
prefix bibo: <http://purl.org/ontology/bibo/>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
drop quad map virtrdf:tutorial .
;

SPARQL
prefix tutorial: <http://demo.openlinksw.com/schemas/tutorial#>
prefix bibo: <http://purl.org/ontology/bibo/>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class tutorial:Post "http://^{URIQADefaultHost}^/tutorial_view/Post/%d/%U#this" (in post_id integer not null, in post_name varchar not null) .
create iri class tutorial:Section "http://^{URIQADefaultHost}^/tutorial_view/Section/%d/%U#this" (in col_id integer not null, in col_name varchar not null) .
create iri class tutorial:DocPath "http://^{URIQADefaultHost}^%U#this" (in prop_name varchar not null) .
;

SPARQL
prefix tutorial: <http://demo.openlinksw.com/schemas/tutorial#>
prefix bibo: <http://purl.org/ontology/bibo/>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class tutorial:post_iri using
    function DB.DBA.POST_IRI (in customer_id integer) returns varchar,
    function DB.DBA.POST_IRI_INVERSE (in customer_iri varchar) returns integer.
create iri class tutorial:section_iri using
    function DB.DBA.SECTION_IRI (in customer_id integer) returns varchar,
    function DB.DBA.SECTION_IRI_INVERSE (in customer_iri varchar) returns integer.
;

SPARQL
prefix tutorial: <http://demo.openlinksw.com/schemas/tutorial#>
prefix bibo: <http://purl.org/ontology/bibo/>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
alter quad storage virtrdf:DefaultQuadStorage
from WS.WS.SYS_DAV_RES as resources text literal RES_CONTENT
from WS.WS.SYS_DAV_COL as collections
from DB.DBA.SYS_USERS as users
where (^{collections.}^.COL_ID = ^{resources.}^.RES_COL)
where (^{resources.}^.RES_FULL_PATH LIKE  '/DAV/VAD/tutorial/%')
where (DB.DBA.DAV_SEARCH_PATH(^{collections.}^.COL_ID, 'c') LIKE '/DAV/VAD/tutorial/%')
{
        create virtrdf:tutorial as graph iri ("http://^{URIQADefaultHost}^/tutorial_view") option (exclusive)
        {
                tutorial:Post (resources.RES_ID, resources.RES_NAME)
                        a tutorial:Post
                                as virtrdf:tutPost-RES_ID ;
                        a foaf:Document
                                as virtrdf:tutsiocPost-RES_ID;
                        a bibo:Article
                                as virtrdf:tutBiboPost-RES_ID ;
                        foaf:primaryTopic tutorial:Post (resources.RES_ID, resources.RES_NAME) ;
                        bibo:identifier resources.RES_NAME
                                as virtrdf:tutPost-RES_NAME ;
                        bibo:author users.U_NAME
                                where (^{resources.}^.RES_OWNER = ^{users.}^.U_ID)
                                as virtrdf:tutPost-RES_OWNER ;
                        tutorial:belongs_to_section tutorial:Section(resources.RES_COL, collections.COL_NAME)
                                where (^{resources.}^.RES_COL = ^{collections.}^.COL_ID)
                                as virtrdf:tutPost-RES_COL ;
                        sioc:content resources.RES_CONTENT
                                as virtrdf:tutPost-RES_CONTENT ;
                        sioc:description resources.RES_NAME
                                as virtrdf:tutsiocPost-RES_NAME ;
                        tutorial:type resources.RES_TYPE
                                as virtrdf:tutPost-RES_TYPE ;
                        bibo:presentedAt resources.RES_CR_TIME
                                as virtrdf:tutPost-RES_CR_TIME ;
                        bibo:url tutorial:DocPath(resources.RES_FULL_PATH)
                                as virtrdf:tutPost-RES_FULL_PATH ;
                        rdfs:isDefinedBy tutorial:post_iri (resources.RES_ID) ;
                        rdfs:isDefinedBy tutorial:Post (resources.RES_ID, resources.RES_NAME) ;
                        rdfs:seeAlso tutorial:Section(resources.RES_COL, collections.COL_NAME)
                                where (^{resources.}^.RES_COL = ^{collections.}^.COL_ID)
                                as virtrdf:tutPost-RES_COL2.

                tutorial:DocPath(resources.RES_FULL_PATH)
                        a tutorial:DocPath
                                as virtrdf:tutDocPath-RES_FULL_PATH .

                tutorial:Section (collections.COL_ID, collections.COL_NAME)
                        a tutorial:Section
                                as virtrdf:tutSection-COL_ID ;
                        a sioc:Container
                                as virtrdf:tutsiocSection-COL_ID ;
                        a bibo:Collection
                                as virtrdf:tutBiboSection-COL_ID ;
                        bibo:identifier collections.COL_NAME
                                as virtrdf:tutSection-COL_NAME ;
                        bibo:author users.U_NAME
                                where (^{collections.}^.COL_OWNER = ^{users.}^.U_ID)
                                as virtrdf:tutSection-COL_OWNER ;
                        rdfs:isDefinedBy tutorial:section_iri (collections.COL_ID) ;
                        rdfs:isDefinedBy tutorial:Section (collections.COL_ID, collections.COL_NAME) .
                        
                tutorial:Section (collections.COL_ID, collections.COL_NAME)
                        sioc:is_container_of
                        tutorial:Post(resources.RES_ID, resources.RES_NAME)
                        where (^{resources.}^.RES_COL = ^{collections.}^.COL_ID)
                        as virtrdf:tutsiocSection-COL_ID2 .

        } .
} .
;

delete from db.dba.url_rewrite_rule_list where urrl_list like 'tutorial_%';
delete from db.dba.url_rewrite_rule where urr_rule like 'tutorial_%';

create procedure tutorial_rdf_doc (in path varchar)
{
  declare r any;
  r := regexp_match ('[^/]*\x24', path);
  return r||'#this';
};

create procedure tutorial_html_doc (in path varchar)
{
  declare r any;
  r := regexp_match ('[^/]*#', path);
  return subseq (r, 0, length (r)-1);
};

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'tutorial_rule2',
    1,
    '(/[^#]*)',
    vector('path'),
    1,
    '/sparql?query=CONSTRUCT+{+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Fp+%%3Fo+}+FROM+%%3Chttp%%3A//^{URIQADefaultHost}^/tutorial_view%%3E+WHERE+{+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Fp+%%3Fo+}&format=%U',
    vector('path', 'path', '*accept*'),
    null,
    '(text/rdf.n3)|(application/rdf.xml)',
    0,
    null
    );

--DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
--    'tutorial_rule1',
--    1,
--    '(/[^#]*)',
--    vector('path'),
--    1,
--    '/rdfbrowser/index.html?uri=http%%3A//^{URIQADefaultHost}^%U%%23this',
--    vector('path'),
--    null,
--    '(text/html)|(\\*/\\*)',
--    0,
--    303
--    );

DB.DBA.exec_no_error('
DB.DBA.URLREWRITE_DROP_RULELIST (\'tutorial_rule_list1\')
');

DB.DBA.exec_no_error('
DB.DBA.URLREWRITE_DROP_RULE (\'tutorial_rule1\')
');


DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'tutorial_rule3',
    1,
    '(/[^#]*)/\x24',
    vector('path'),
    1,
    '%s',
    vector('path'),
    null,
    null,
    0,
    null
    );

create procedure DB.DBA.REMOVE_TUT_RDF_DET()
{
  declare colid int;
  colid := DAV_SEARCH_ID('/DAV/home/tutorial_view/', 'C');
  if (colid < 0)
    return;
  update WS.WS.SYS_DAV_COL set COL_DET=null where COL_ID = colid;
}
;

DB.DBA.REMOVE_TUT_RDF_DET();

drop procedure DB.DBA.REMOVE_TUT_RDF_DET;

create procedure DB.DBA.TUT_MAKE_RDF_DET()
{
    declare uriqa_str varchar;
    uriqa_str := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
    uriqa_str := 'http://' || uriqa_str || '/tutorial_view';
    DB.DBA."RDFData_MAKE_DET_COL" ('/DAV/home/tutorial_view/RDFData/', uriqa_str, NULL);
    VHOST_REMOVE (lpath=>'/tutorial_view/data/rdf');
    DB.DBA.VHOST_DEFINE (lpath=>'/tutorial_view/data/rdf', ppath=>'/DAV/home/tutorial_view/RDFData/All/', is_dav=>1, vsp_user=>'dba');
}
;

DB.DBA.TUT_MAKE_RDF_DET();

drop procedure DB.DBA.TUT_MAKE_RDF_DET;

-- procedure to convert path to DET resource name
create procedure DB.DBA.TUT_DET_REF (in par varchar, in fmt varchar, in val varchar)
{
  declare res, iri any;
  declare uriqa_str varchar;
  uriqa_str := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  uriqa_str := 'http://' || uriqa_str || '/tutorial_view';
  iri := uriqa_str || val;
  res := sprintf ('iid (%d).rdf', iri_id_num (iri_to_id (iri)));
  return sprintf (fmt, res);
}
;

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('tutorial_rdf', 1,
    '/tutorial_view/(.*)', vector('path'), 1, 
    '/tutorial_view/data/rdf/%U', vector('path'),
    'DB.DBA.TUT_DET_REF',
    'application/rdf.xml',
    2,  
    303);
    
DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'tutorial_rule4',
    1,
    '/schemas/tutorial#(.*)',
    vector('path'),
    1,
    '/sparql?query=DESCRIBE%20%3Chttp%3A//demo.openlinksw.com/schemas/tutorial%23%U%3E%20FROM%20%3Chttp%3A//demo.openlinksw.com/schemas/TutOntology/1.0/%3E',
    vector('path'),
    null,
    '(text/rdf.n3)|(application/rdf.xml)',
    0,
    null
    );

DB.DBA.URLREWRITE_CREATE_RULELIST (
    'tutorial_rule_list1',
    1,
    vector (
                'tutorial_rule2',
                'tutorial_rule3',
                'tutorial_rule4',
                'tutorial_rdf'
          ));


VHOST_REMOVE (lpath=>'/tutorial_view');
DB.DBA.VHOST_DEFINE (lpath=>'/tutorial_view', ppath=>'/DAV/home/tutorial_view/', vsp_user=>'dba', is_dav=>1, def_page=>'sfront.vspx',
          is_brws=>0, opts=>vector ('url_rewrite', 'tutorial_rule_list1'));

create procedure DB.DBA.LOAD_TUT_ONTOLOGY_FROM_DAV()
{
  declare content1, urihost varchar;
  whenever not found goto none;
  select cast (RES_CONTENT as varchar) into content1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/VAD/tutorial/sql/tutorial.owl';
  DB.DBA.RDF_LOAD_RDFXML (content1, 'http://demo.openlinksw.com/schemas/tutorial#', 'http://demo.openlinksw.com/schemas/TutOntology/1.0/');
  urihost := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  if (urihost = 'demo.openlinksw.com')
  {
    DB.DBA.VHOST_REMOVE (lpath=>'/schemas/tutorial');
    DB.DBA.VHOST_DEFINE (lpath=>'/schemas/tutorial', ppath=>'/DAV/VAD/tutorial/sql/tutorial.owl', vsp_user=>'dba', is_dav=>1, is_brws=>0);
    DB.DBA.VHOST_REMOVE (lpath=>'/schemas/tutorial#');
    DB.DBA.VHOST_DEFINE (lpath=>'/schemas/tutorial#', ppath=>'/DAV/VAD/tutorial/sql/tutorial.owl', vsp_user=>'dba', is_dav=>1, is_brws=>0);
  }
  none:
  ;
};

--DB.DBA.LOAD_TUT_ONTOLOGY_FROM_DAV();

drop procedure DB.DBA.LOAD_TUT_ONTOLOGY_FROM_DAV;

create procedure DB.DBA.LOAD_TUT_ONTOLOGY_FROM_DAV2()
{
  declare urihost varchar;
 whenever not found goto none;
  sparql base <http://demo.openlinksw.com/schemas/tutorial#> load bif:concat ("http://", bif:registry_get("URIQADefaultHost"), "/DAV/VAD/tutorial/sql/tutorial.owl")
   into graph <http://demo.openlinksw.com/schemas/TutOntology/1.0/>;
  urihost := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  if (urihost = 'demo.openlinksw.com')
  {
    DB.DBA.VHOST_REMOVE (lpath=>'/schemas/tutorial');
    DB.DBA.VHOST_DEFINE (lpath=>'/schemas/tutorial', ppath=>'/DAV/VAD/tutorial/sql/tutorial.owl', vsp_user=>'dba', is_dav=>1, is_brws=>0);
    DB.DBA.VHOST_REMOVE (lpath=>'/schemas/tutorial#');
    DB.DBA.VHOST_DEFINE (lpath=>'/schemas/tutorial#', ppath=>'/DAV/VAD/tutorial/sql/tutorial.owl', vsp_user=>'dba', is_dav=>1, is_brws=>0);
  }
  none:
  ;
};

--DB.DBA.LOAD_TUT_ONTOLOGY_FROM_DAV2();

drop procedure DB.DBA.LOAD_TUT_ONTOLOGY_FROM_DAV2;
