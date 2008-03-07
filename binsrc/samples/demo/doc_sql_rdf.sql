use DB;

create procedure DB.DBA.SPARQL_DOC_RUN (in txt varchar)
{
  declare REPORT, stat, msg, sqltext varchar;
  declare metas, rowset any;
  result_names (REPORT);
  sqltext := string_output_string (sparql_to_sql_text (txt));
  stat := '00000';
  msg := '';
  rowset := null;
  exec (sqltext, stat, msg, vector (), 1000, metas, rowset);
  result ('STATE=' || stat || ': ' || msg);
  if (__tag(rowset) = 193)
  {
    foreach (any r in rowset) do
      result (r[0] || ': ' || r[1]);
  }
}
;

DB.DBA.exec_no_error('GRANT \"SPARQL_UPDATE\" TO \"SPARQL\"')
;

GRANT SELECT ON "WS"."WS"."SYS_DAV_RES" TO "SPARQL";
GRANT SELECT ON "WS"."WS"."SYS_DAV_COL" TO "SPARQL";
GRANT SELECT ON "WS"."WS"."SYS_DAV_PROP" TO "SPARQL";
GRANT SELECT ON "DB"."DBA"."SYS_USERS" TO "SPARQL";
GRANT SELECT ON "DB"."DBA"."document_search" TO "SPARQL";

DB.DBA.SPARQL_DOC_RUN ('
drop quad map graph iri("http://^{URIQADefaultHost}^/Doc") .
')
;

DB.DBA.SPARQL_DOC_RUN ('
drop quad map virtrdf:Doc .
')
;

create function DB.DBA.DOC_ID_TO_IRI(in _prefix varchar,in _id varchar)
{
  declare iri, uriqa_host any;
  uriqa_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  iri := 'http://' || uriqa_host || '/Doc/' || _prefix || '/' || _id || '#this';
  return sprintf ('http://%s/DAV/home/doc/RDFData/All/iid%%20(%d).rdf', uriqa_host, iri_id_num (iri_to_id (iri)));
}
;

create function DB.DBA.DOC_IRI_TO_ID(in _iri varchar)
{
    declare parts any;
    parts := sprintf_inverse (_iri, 'http://%s/DAV/home/doc/RDFData/All/iid (%d).rdf', 1 );
    if (parts is not null)
    {
        declare uriqa_host, iri any;
        uriqa_host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
        if (parts[0] = uriqa_host)
        {
            iri := id_to_iri(iri_id_from_num(parts[1]));
            parts := sprintf_inverse (iri, 'http://%s/Doc/%s/%s#this', 1 );
            if (parts[0] = uriqa_host)
            {
                return parts[2];
            }
        }
    }
    return NULL;
}
;

create function DB.DBA.FILE_IRI (in _id integer) returns varchar
{
    return DOC_ID_TO_IRI('File', cast(_id as varchar));
}
;

create function DB.DBA.FILE_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.DOC_IRI_TO_ID(_iri));
};

create function DB.DBA.COL_IRI (in _id integer) returns varchar
{
    return DOC_ID_TO_IRI('Collection', cast(_id as varchar));
}
;

create function DB.DBA.PROP_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.DOC_IRI_TO_ID(_iri));
};

create function DB.DBA.PROP_IRI (in _id integer) returns varchar
{
    return DOC_ID_TO_IRI('Property', cast(_id as varchar));
}
;

create function DB.DBA.SUPPLIER_IRI_INVERSE (in _iri varchar) returns integer
{
    return atoi(DB.DBA.DOC_IRI_TO_ID(_iri));
};

grant execute on DB.DBA.FILE_IRI to "SPARQL";
grant execute on DB.DBA.FILE_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.COL_IRI to "SPARQL";
grant execute on DB.DBA.COL_IRI_INVERSE to "SPARQL";
grant execute on DB.DBA.PROP_IRI to "SPARQL";
grant execute on DB.DBA.PROP_IRI_INVERSE to "SPARQL";

DB.DBA.SPARQL_DOC_RUN ('
prefix doc: <http://demo.openlinksw.com/schemas/doc#>
prefix bibo: <http://purl.org/ontology/bibo/>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class doc:File "http://^{URIQADefaultHost}^/Doc/File/%d/%U#this" (in file_id integer not null, in file_name varchar not null) .
create iri class doc:Collection "http://^{URIQADefaultHost}^/Doc/Collection/%d/%U#this" (in col_id integer not null, in col_name varchar not null) .
create iri class doc:Property "http://^{URIQADefaultHost}^/Doc/Property/%U/%d#this" (in prop_name varchar not null, in prop_id integer not null) .
create iri class doc:Search "http://^{URIQADefaultHost}^/Doc/Search/%U/%d#this" (in prop_name varchar not null, in prop_id integer not null) .
create iri class doc:DocPath "http://^{URIQADefaultHost}^%U#this" (in prop_name varchar not null) .
');

DB.DBA.SPARQL_DOC_RUN ('
prefix doc: <http://demo.openlinksw.com/schemas/doc#>
prefix bibo: <http://purl.org/ontology/bibo/>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class doc:file_iri using
    function DB.DBA.FILE_IRI (in customer_id integer) returns varchar,
    function DB.DBA.FILE_IRI_INVERSE (in customer_iri varchar) returns integer.
');

DB.DBA.SPARQL_DOC_RUN ('
prefix doc: <http://demo.openlinksw.com/schemas/doc#>
prefix bibo: <http://purl.org/ontology/bibo/>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class doc:collection_iri using
    function DB.DBA.COL_IRI (in customer_id integer) returns varchar,
    function DB.DBA.COL_IRI_INVERSE (in customer_iri varchar) returns integer.
');

DB.DBA.SPARQL_DOC_RUN ('
prefix doc: <http://demo.openlinksw.com/schemas/doc#>
prefix bibo: <http://purl.org/ontology/bibo/>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix owl: <http://www.w3.org/2002/07/owl#>
create iri class doc:property_iri using
    function DB.DBA.PROP_IRI (in customer_id varchar) returns varchar,
    function DB.DBA.PROP_IRI_INVERSE (in customer_iri varchar) returns varchar.
');


DB.DBA.SPARQL_DOC_RUN ('
prefix doc: <http://demo.openlinksw.com/schemas/doc#>
prefix bibo: <http://purl.org/ontology/bibo/>
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sioc: <http://rdfs.org/sioc/ns#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix wgs: <http://www.w3.org/2003/01/geo/wgs84_pos#>
prefix owl: <http://www.w3.org/2002/07/owl#>
alter quad storage virtrdf:DefaultQuadStorage
from WS.WS.SYS_DAV_RES as resources text literal RES_CONTENT
from WS.WS.SYS_DAV_COL as collections
from WS.WS.SYS_DAV_PROP as properties
from DB.DBA.SYS_USERS as users
from DB.DBA.document_search as docs
where (^{collections.}^.COL_ID = ^{resources.}^.RES_COL)
where (^{resources.}^.RES_FULL_PATH LIKE  \'/DAV/VAD/doc/html/\x25\')
where ((^{properties.}^.PROP_PARENT_ID = ^{resources.}^.RES_ID) or (^{properties.}^.PROP_PARENT_ID = ^{collections.}^.COL_ID))
{
        create virtrdf:Doc as graph iri ("http://^{URIQADefaultHost}^/Doc") option (exclusive)
        {
                doc:File (resources.RES_ID, resources.RES_NAME)
                        a doc:File
                                as virtrdf:File-RES_ID ;
                        a bibo:Article
                                as virtrdf:BiboFile-RES_ID ;
                        bibo:identifier resources.RES_NAME
                                as virtrdf:File-RES_NAME ;
                        bibo:author users.U_NAME
                                where (^{resources.}^.RES_OWNER = ^{users.}^.U_ID)
                                as virtrdf:File-RES_OWNER ;
                        doc:collection doc:Collection(resources.RES_COL, collections.COL_NAME)
                                where (^{resources.}^.RES_COL = ^{collections.}^.COL_ID)
                                as virtrdf:File-RES_COL ;
                        #doc:content resources.RES_CONTENT
                        #        as virtrdf:File-RES_CONTENT ;
                        doc:type resources.RES_TYPE
                                as virtrdf:File-RES_TYPE ;
                        bibo:presentedAt resources.RES_CR_TIME
                                as virtrdf:File-RES_CR_TIME ;
                        bibo:url doc:DocPath(resources.RES_FULL_PATH)
                                as virtrdf:File-RES_FULL_PATH ;
                        rdfs:isDefinedBy doc:file_iri (resources.RES_ID) ;
                        rdfs:isDefinedBy doc:File (resources.RES_ID, resources.RES_NAME) .


                doc:DocPath(resources.RES_FULL_PATH)
                        a doc:DocPath
                                as virtrdf:DocPath-RES_FULL_PATH .

                doc:Collection (collections.COL_ID, collections.COL_NAME)
                        a doc:Collection
                                as virtrdf:Collection-COL_ID ;
                        a bibo:Collection
                                as virtrdf:BiboCollection-COL_ID ;
                        bibo:identifier collections.COL_NAME
                                as virtrdf:Collection-COL_NAME ;
                        bibo:author users.U_NAME
                                where (^{collections.}^.COL_OWNER = ^{users.}^.U_ID)
                                as virtrdf:Collection-COL_OWNER ;
                        rdfs:isDefinedBy doc:collection_iri (collections.COL_ID) ;
                        rdfs:isDefinedBy doc:Collection (collections.COL_ID, collections.COL_NAME) .

                doc:Property (properties.PROP_NAME, properties.PROP_ID)
                        a doc:Property
                                as virtrdf:Property-PROP_ID ;
                        doc:name properties.PROP_NAME
                                as virtrdf:Property-PROP_NAME ;
                        doc:type properties.PROP_TYPE
                                as virtrdf:Property-PROP_TYPE ;
                        doc:value properties.PROP_VALUE
                                as virtrdf:Property-PROP_VALUE ;
                        doc:belongs_to_collection doc:Collection(properties.PROP_PARENT_ID, collections.COL_NAME)
                                where (^{properties.}^.PROP_PARENT_ID = ^{collections.}^.COL_ID)
                                as virtrdf:Property-PROP_PARENT_ID ;
                        doc:belongs_to_file doc:File(properties.PROP_PARENT_ID, resources.RES_NAME)
                                where (^{properties.}^.PROP_PARENT_ID = ^{resources.}^.RES_ID)
                                as virtrdf:Property-PROP_PARENT_ID2 ;
                        rdfs:isDefinedBy doc:property_iri (properties.PROP_ID) ;
                        rdfs:isDefinedBy doc:Property (properties.PROP_NAME, properties.PROP_ID) .

                doc:Search (docs.d_anch, docs.d_id)
                        a doc:Search
                                as virtrdf:Search-d_id ;
                        doc:anch docs.d_anch
                                as virtrdf:Search-d_anch ;
                        doc:text docs.d_txt
                                as virtrdf:Search-d_txt ;
                        doc:belongs_to_file doc:File(docs.d_res_id, resources.RES_NAME)
                                where (^{docs.}^.d_res_id = ^{resources.}^.RES_ID)
                                as virtrdf:Search-d_res_id .
        }
}
')
;

create procedure doc_rdf_doc (in path varchar)
{
  declare r any;
  r := regexp_match ('[^/]*\x24', path);
  return r||'#this';
};

create procedure doc_html_doc (in path varchar)
{
  declare r any;
  r := regexp_match ('[^/]*#', path);
  return subseq (r, 0, length (r)-1);
};

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'doc_rule2',
    1,
    '(/[^#]*)',
    vector('path'),
    1,
    '/sparql?query=CONSTRUCT+{+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Fp+%%3Fo+}+FROM+%%3Chttp%%3A//^{URIQADefaultHost}^/Doc%%3E+WHERE+{+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Fp+%%3Fo+}&format=%U',
    vector('path', 'path', '*accept*'),
    null,
    '(text/rdf.n3)|(application/rdf.xml)',
    0,
    null
    );

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'doc_rule1',
    1,
    '(/[^#]*)',
    vector('path'),
    1,
    '/rdfbrowser/index.html?uri=http%%3A//^{URIQADefaultHost}^%U%%23this',
    vector('path'),
    null,
    '(text/html)|(\\*/\\*)',
    0,
    303
    );

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'doc_rule3',
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

create procedure DB.DBA.REMOVE_DOC_RDF_DET()
{
  declare colid int;
  colid := DAV_SEARCH_ID('/DAV/home/doc/', 'C');
  if (colid < 0)
    return;
  update WS.WS.SYS_DAV_COL set COL_DET=null where COL_ID = colid;
}
;

DB.DBA.REMOVE_DOC_RDF_DET();

drop procedure DB.DBA.REMOVE_DOC_RDF_DET;

create procedure DB.DBA.DOC_MAKE_RDF_DET()
{
    declare uriqa_str varchar;
    uriqa_str := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
    uriqa_str := 'http://' || uriqa_str || '/Doc';
    DB.DBA."RDFData_MAKE_DET_COL" ('/DAV/home/doc/RDFData/', uriqa_str, NULL);
    VHOST_REMOVE (lpath=>'/Doc/data/rdf');
    DB.DBA.VHOST_DEFINE (lpath=>'/Doc/data/rdf', ppath=>'/DAV/home/doc/RDFData/All/', is_dav=>1, vsp_user=>'dba');
}
;

DB.DBA.DOC_MAKE_RDF_DET();

drop procedure DB.DBA.DOC_MAKE_RDF_DET;

-- procedure to convert path to DET resource name
create procedure DB.DBA.DOC_DET_REF (in par varchar, in fmt varchar, in val varchar)
{
  declare res, iri any;
  declare uriqa_str varchar;
  uriqa_str := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  uriqa_str := 'http://' || uriqa_str || '/Doc';
  iri := uriqa_str || val;
  res := sprintf ('iid (%d).rdf', iri_id_num (iri_to_id (iri)));
  return sprintf (fmt, res);
}
;

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('doc_rdf', 1,
    '/Doc/(.*)', vector('path'), 1, 
    '/Doc/data/rdf/%U', vector('path'),
    'DB.DBA.DOC_DET_REF',
    'application/rdf.xml',
    2,  
    303);
    
DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'doc_rule4',
    1,
    '/schemas/doc#(.*)',
    vector('path'),
    1,
    '/sparql?query=DESCRIBE%20%3Chttp%3A//demo.openlinksw.com/schemas/doc%23%U%3E%20FROM%20%3Chttp%3A//demo.openlinksw.com/schemas/DocOntology/1.0/%3E',
    vector('path'),
    null,
    '(text/rdf.n3)|(application/rdf.xml)',
    0,
    null
    );

DB.DBA.URLREWRITE_CREATE_RULELIST (
    'doc_rule_list1',
    1,
    vector (
                'doc_rule1',
                'doc_rule2',
                'doc_rule3',
                'doc_rule4',
                'doc_rdf'
          ));


VHOST_REMOVE (lpath=>'/Doc');
DB.DBA.VHOST_DEFINE (lpath=>'/Doc', ppath=>'/DAV/home/doc/', vsp_user=>'dba', is_dav=>1, def_page=>'sfront.vspx',
          is_brws=>0, opts=>vector ('url_rewrite', 'doc_rule_list1'));

create procedure DB.DBA.LOAD_DOC_ONTOLOGY_FROM_DAV()
{
  declare content1, urihost varchar;
  select cast (RES_CONTENT as varchar) into content1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/VAD/doc/sql/doc.owl';
  DB.DBA.RDF_LOAD_RDFXML (content1, 'http://demo.openlinksw.com/schemas/doc#', 'http://demo.openlinksw.com/schemas/DocOntology/1.0/');
  urihost := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  if (urihost = 'demo.openlinksw.com')
  {
    DB.DBA.VHOST_REMOVE (lpath=>'/schemas/doc');
    DB.DBA.VHOST_DEFINE (lpath=>'/schemas/doc', ppath=>'/DAV/VAD/demo/sql/doc.owl', vsp_user=>'dba', is_dav=>1, is_brws=>0);
    DB.DBA.VHOST_REMOVE (lpath=>'/schemas/doc#');
    DB.DBA.VHOST_DEFINE (lpath=>'/schemas/doc#', ppath=>'/DAV/VAD/demo/sql/doc.owl', vsp_user=>'dba', is_dav=>1, is_brws=>0);
  }
};

--DB.DBA.LOAD_DOC_ONTOLOGY_FROM_DAV();

drop procedure DB.DBA.LOAD_DOC_ONTOLOGY_FROM_DAV;
