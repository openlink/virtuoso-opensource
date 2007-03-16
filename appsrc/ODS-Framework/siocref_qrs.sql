select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
SELECT distinct ?attribute

WHERE {
        ?forum a sioct:Weblog .
        ?forum sioc:container_of ?post .
        ?post ?attribute ?o
      }
ORDER BY ?attribute
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX dct: <http://purl.org/dc/elements/1.1/>
PREFIX dcc: <http://purl.org/dc/terms/>
SELECT DISTINCT ?forum_name, ?post, ?title ?cr ?url

WHERE    {
           ?forum a sioct:Weblog .
           ?forum sioc:id ?forum_name.
           ?forum sioc:scope_of ?role.
           ?role sioc:function_of ?member.
           ?member sioc:id "demo".
           ?forum sioc:container_of ?post.
           optional{ ?post dct:title ?title }.
           optional{ ?post dcc:created ?cr }.
           optional{ ?post sioc:link ?url }.
         }
ORDER BY DESC (?cr)
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
SELECT ?endp , ?proto

WHERE {
        ?forum a sioct:Weblog .
        ?forum sioc:has_service ?svc .
        ?svc sioc:service_endpoint ?endp .
        ?svc sioc:service_protocol ?proto .
      }
ORDER BY ?proto
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX dct: <http://purl.org/dc/elements/1.1/>
PREFIX dcc: <http://purl.org/dc/terms/>
PREFIX sioct: <http://rdfs.org/sioc/types#>
SELECT ?forum_name, ?post, ?title, ?cr, ?content, ?url

WHERE    {
           ?forum a sioct:Weblog .
           ?forum sioc:id ?forum_name.
           ?forum sioc:scope_of ?role.
           ?role sioc:function_of ?member.
           ?member sioc:id "demo".
           ?forum sioc:container_of ?post.
           optional{?post dct:title ?title }.
           optional{?post dcc:created ?cr }.
           optional{?post sioc:link ?url }.
           optional{?post sioc:links_to ?links_to }.
           optional{?post sioc:content ?content}
         }
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX dct: <http://purl.org/dc/elements/1.1/>
PREFIX dcc: <http://purl.org/dc/terms/>
SELECT ?forum_name, ?post, ?title, ?cr, ?content, ?url, ?links_to

WHERE    {
           ?forum a sioct:Weblog .
           ?forum sioc:id ?forum_name.
           ?forum sioc:scope_of ?role.
           ?role sioc:function_of ?member.
           ?member sioc:id "demo".
           ?forum sioc:container_of ?post.
           optional{ ?post dct:title ?title }.
           optional{ ?post dcc:created ?cr }.
           optional{ ?post sioc:link ?url }.
           optional{ ?post sioc:links_to ?links_to }.
           optional{?post sioc:content ?content}
         }
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
SELECT distinct ?attribute

WHERE {
        ?forum rdf:type sioct:Wiki  .
        ?forum sioc:container_of ?post .
        ?post ?attribute ?o
      }
ORDER BY ?attribute
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc: <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX dct: <http://purl.org/dc/elements/1.1/>
PREFIX dcc: <http://purl.org/dc/terms/>
SELECT distinct ?forum_name, ?post, ?title, ?link, ?links_to, ?cr

WHERE {
        ?forum rdf:type sioct:Wiki .
        ?forum sioc:id ?forum_name.
        ?forum sioc:container_of ?post .
        ?post  dct:title ?title.
        OPTIONAL {?post dcc:created ?cr}.
        OPTIONAL {?post sioc:link ?link} .
        OPTIONAL {?post sioc:links_to ?links_to} .
      }
ORDER BY ?title

');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX dct: <http://purl.org/dc/elements/1.1/>
PREFIX dcc: <http://purl.org/dc/terms/>
SELECT ?forum_name, ?post, ?title, ?link, ?cr, ?content

WHERE {
        ?forum rdf:type sioct:Wiki .
        ?forum sioc:id ?forum_name.
        ?forum sioc:container_of ?post .
        ?post  dct:title ?title.
        OPTIONAL {?post dcc:created ?cr}.
        OPTIONAL {?post sioc:link ?link} .
        OPTIONAL {?post sioc:content ?content}.
      }
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX dct: <http://purl.org/dc/elements/1.1/>
PREFIX dcc: <http://purl.org/dc/terms/>
SELECT ?forum_name, ?post, ?title, ?link, ?links_to, ?cr, ?content

WHERE {
        ?forum rdf:type sioct:Wiki .
        ?forum sioc:id ?forum_name.
        ?forum sioc:container_of ?post .
        ?post  dct:title ?title.
        OPTIONAL {?post dcc:created ?cr}.
        OPTIONAL {?post sioc:link ?link} .
        OPTIONAL {?post sioc:links_to ?links_to} .
        OPTIONAL {?post sioc:content ?content}.
      }
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
SELECT distinct ?attribute

WHERE {
        ?forum rdf:type sioct:Feed .
        ?forum sioc:parent_of ?parentf .
        ?parentf sioc:container_of ?post .
        ?post ?attribute ?o
      }
ORDER BY ?attribute
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX dct: <http://purl.org/dc/elements/1.1/>
PREFIX dcc: <http://purl.org/dc/terms/>
SELECT distinct ?forum_name, ?creator, ?member,  ?channel, ?item_title, ?url, ?created

WHERE {
        ?forum a sioct:Feed;
               sioc:id ?forum_name.
        ?forum sioc:scope_of ?role.
        ?role sioc:function_of ?member.
        ?member sioc:id "demo".
        ?forum sioc:parent_of ?channel .
        ?channel sioc:container_of ?post .
        optional{?post dct:title ?item_title }.
        optional{ ?post sioc:links_to ?url }.
        optional{ ?post sioc:has_creator ?creator }.
        optional{ ?post dcc:created ?created }
      }
ORDER BY DESC (?created)
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX dct: <http://purl.org/dc/elements/1.1/>
PREFIX dcc: <http://purl.org/dc/terms/>
SELECT  ?forum_name, ?creator, ?member, ?channel, ?item_title, ?url, ?created, ?content

WHERE {
        ?forum a sioct:Feed;
               sioc:id ?forum_name.
        ?forum sioc:scope_of ?role.
        ?role sioc:function_of ?member.
        ?member sioc:id "demo".
        ?forum sioc:parent_of ?channel .
        ?channel sioc:container_of ?post .
        optional{ ?post dct:title ?item_title }.
        optional{ ?post sioc:links_to ?url }.
        optional{ ?post sioc:has_creator ?creator }.
        optional{ ?post dcc:created ?created }.
        optional{ ?post sioc:content ?content}.
      }
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
SELECT distinct ?attribute

WHERE {
        ?forum a sioct:Bookmark .
        ?forum sioc:container_of ?post .
        ?post ?attribute ?o
      }
ORDER BY ?attribute
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX dct: <http://purl.org/dc/elements/1.1/>
SELECT distinct ?forum_name, ?member, ?post, ?title, ?link, ?url

WHERE {
        ?forum a sioct:Bookmark .
        ?forum sioc:id ?forum_name.
        ?forum sioc:scope_of ?role.
        ?role sioc:function_of ?member.
        ?member sioc:id "demo".
        ?forum sioc:container_of ?post .
        optional{ ?post  dct:title ?title }.
        optional{ ?post sioc:link ?link  } .
        optional{ ?post sioc:links_to ?url }
      }
ORDER BY ?title
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
SELECT distinct ?attribute

WHERE {
        ?forum rdf:type sioct:Photo .
        ?forum sioc:container_of ?post .
        ?post ?attribute ?o
      }
ORDER BY ?attribute
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX dct: <http://purl.org/dc/elements/1.1/>
PREFIX dcc: <http://purl.org/dc/terms/>
SELECT ?forum_name, ?post, ?title, ?link, ?cr, ?content

WHERE {
        ?forum rdf:type sioct:Photo .
        ?forum sioc:id ?forum_name.
        ?forum sioc:container_of ?post .
        OPTIONAL {?post  dct:title ?title }.
        OPTIONAL {?post dcc:created ?cr}.
        OPTIONAL {?post sioc:link ?link} .
        OPTIONAL {?post sioc:content ?content}
      }
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX dct: <http://purl.org/dc/elements/1.1/>
PREFIX dcc: <http://purl.org/dc/terms/>
SELECT ?forum_name, ?post, ?title, ?link, ?links_to, ?cr, ?content

WHERE {
        ?forum rdf:type sioct:Photo .
        ?forum sioc:id ?forum_name.
        ?forum sioc:container_of ?post .
        OPTIONAL {?post  dct:title ?title}.
        OPTIONAL {?post dcc:created ?cr}.
        OPTIONAL {?post sioc:link ?link} .
        OPTIONAL {?post sioc:links_to ?links_to} .
        OPTIONAL {?post sioc:content ?content}
      }
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
SELECT distinct ?attribute

WHERE {
        ?forum rdf:type sioct:Community .
        ?forum sioc:parent_of ?parentf .
        ?parentf sioc:container_of ?post .
        ?post ?attribute ?o
      }
ORDER BY ?attribute
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
SELECT distinct ?attribute

WHERE
  {
    ?forum rdf:type sioct:Briefcase .
    ?forum sioc:container_of ?post .
    ?post ?attribute ?o
  }
ORDER BY ?attribute
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX dct: <http://purl.org/dc/elements/1.1/>
PREFIX dcc: <http://purl.org/dc/terms/>
SELECT DISTINCT ?forum_name, ?post, ?title, ?cr, ?url, ?links_to

WHERE    {
           ?forum a sioct:Briefcase .
           ?forum sioc:id ?forum_name.
           ?forum sioc:container_of ?post.
           optional { ?post dct:title ?title }.
           optional { ?post dcc:created ?cr }.
           optional { ?post sioc:link ?url }.
           optional { ?post sioc:links_to ?links_to }.
         }
ORDER BY DESC (?cr)
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
SELECT distinct ?attribute
from <http://demo.openlinksw.com/dataspace_v>
WHERE {
        ?forum rdf:type sioct:Discussion .
        ?forum sioc:container_of ?post .
        ?post ?attribute ?o
      }
order by ?attribute
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc: <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX dct: <http://purl.org/dc/elements/1.1/>
PREFIX dcc: <http://purl.org/dc/terms/>
SELECT distinct ?forum_name, ?post, ?title, ?mod_time, ?create_time, ?url

WHERE {
        ?forum a sioct:Discussion ;
               sioc:id ?forum_name.
        optional{ ?forum sioc:container_of ?post  } .
        optional{ ?post dct:title ?title } .
        optional{ ?post dcc:modified ?mod_time } .
        optional{ ?post dcc:created ?create_time } .
        optional{ ?post sioc:link ?url } .
      }
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc: <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX dct: <http://purl.org/dc/elements/1.1/>
PREFIX dcc: <http://purl.org/dc/terms/>
SELECT ?forum_name, ?post, ?title, ?mod_time, ?create_time, ?url, ?content

WHERE {
        ?forum a sioct:Discussion ;
                    sioc:id ?forum_name FILTER REGEX(?forum_name,".*king*.").
        OPTIONAL{ ?forum sioc:container_of ?post  } .
        OPTIONAL{ ?post dct:title ?title } .
        OPTIONAL{ ?post dcc:modified ?mod_time } .
        OPTIONAL{ ?post dcc:created ?create_time } .
        OPTIONAL{ ?post sioc:link ?url } .
        OPTIONAL{ ?post sioc:content ?content}.
      }
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc: <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX dct: <http://purl.org/dc/elements/1.1/>
PREFIX dcc: <http://purl.org/dc/terms/>
SELECT distinct ?forum_name, ?post, ?title, ?mod_time, ?create_time, ?url

WHERE {
        ?forum rdf:type sioct:Discussion .
        OPTIONAL{ ?forum sioc:id ?forum_name. FILTER REGEX(?forum_name,".*king*.") }.
        OPTIONAL{ ?forum sioc:container_of ?post  } .
        OPTIONAL{ ?post dct:title ?title } .
        OPTIONAL{ ?post dcc:modified ?mod_time } .
        OPTIONAL{ ?post dcc:created ?create_time } .
        OPTIONAL{ ?post sioc:link ?url } .
      }
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc: <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX dct: <http://purl.org/dc/elements/1.1/>
PREFIX dcc: <http://purl.org/dc/terms/>
SELECT distinct ?forum_name, ?post, ?title, ?mod_time, ?create_time, ?url

WHERE {
        ?forum rdf:type sioct:Discussion ;
               sioc:id ?forum_name FILTER REGEX(?forum_name,".*DemoWiki*.").
        OPTIONAL{ ?forum sioc:container_of ?post  } .
        OPTIONAL{ ?post dct:title ?title } .
        OPTIONAL{ ?post dcc:modified ?mod_time } .
        OPTIONAL{ ?post dcc:created ?create_time } .
        OPTIONAL{ ?post sioc:link ?url } .
      }
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX sioc: <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
SELECT ?title, ?tag, ?topic

WHERE  {
                 ?s a sioc:Post .
                 optional { ?s dc:title ?title }.
                 ?s sioc:id ?id .
                 optional { ?s sioc:topic ?topic .
                            ?topic rdf:type skos:Concept .
                            ?topic skos:prefLabel ?tag }
             }
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX dct: <http://purl.org/dc/elements/1.1/>
PREFIX dcc: <http://purl.org/dc/terms/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
SELECT DISTINCT ?forum_name, ?post, ?title, ?cr, ?content, ?url, ?links_to, ?tag, ?nick, ?gender, ?org, ?geodata
WHERE    {
           ?forum a sioct:Weblog .
           ?forum sioc:id ?forum_name.
           optional {?forum sioc:scope_of ?role } .
          optional { ?role sioc:function_of ?member } .
           ?member sioc:id "demo".
           ?forum sioc:container_of ?post.
           ?post   dct:title ?title;
                   dcc:created ?cr;
                   sioc:link ?url;
                   sioc:links_to ?links_to;
                   foaf:maker ?maker.
           OPTIONAL { ?maker foaf:nick ?nick  } .
           OPTIONAL { ?maker foaf:name ?fname } .
           OPTIONAL { ?maker foaf:gender ?gender } .
           OPTIONAL { ?maker foaf:based_near ?geodata } .
           OPTIONAL { ?maker foaf:organization ?org } .
           OPTIONAL {?post sioc:content ?content}.
           OPTIONAL {?post sioc:topic ?topic .
                             ?topic rdf:type skos:Concept .
                             ?topic skos:prefLabel ?tag }
         }
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX xsd:   <http://www.w3.org/2001/XMLSchema#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX dcterms: <http://purl.org/dc/terms/>
SELECT DISTINCT ?post, ?post_sioc, ?post_author, ?post_title, ?post_date, ?reply

WHERE {
    ?post sioc:has_creator ?_x .
    ?_x sioc:id ?post_author .
    optional { ?post rdfs:seeAlso ?post_sioc } .
    optional { ?post sioc:has_reply ?reply } .
    optional { ?post dcterms:created ?post_date } .
    optional { ?post dc:title ?post_title }
}
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX sioc:   <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX xsd:   <http://www.w3.org/2001/XMLSchema#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX dcterms: <http://purl.org/dc/terms/>

CONSTRUCT
{
 ?post sioc:has_creator ?_x .
 ?_x sioc:id ?post_author .
 ?post rdfs:seeAlso ?post_sioc .
 ?post sioc:has_reply ?reply .
 ?post dcterms:created ?post_date .
 ?post dc:title ?post_title .
}


WHERE {
    ?post sioc:has_creator ?_x .
    ?_x sioc:id ?post_author .
    OPTIONAL { ?post rdfs:seeAlso ?post_sioc } .
    OPTIONAL { ?post sioc:has_reply ?reply } .
    OPTIONAL { ?post dcterms:created ?post_date } .
    OPTIONAL { ?post dc:title ?post_title }
}
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX sioc: <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX dcterms: <http://purl.org/dc/terms/>
CONSTRUCT
{
?post dcterms:created ?created .
?post sioc:link ?link .
?post sioc:title ?title .
}

WHERE
  {
    ?forum a sioct:Discussion  .
    ?post sioc:has_container ?forum .
    optional { ?post dcterms:created ?created } .
    optional { ?post sioc:link ?link } .
    optional { ?post sioc:title ?title }
  }
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc: <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
CONSTRUCT
{
 ?x rdf:type sioc:User .
}

WHERE
{
  ?x rdf:type sioc:User .
}
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc: <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX dcterms: <http://purl.org/dc/terms/>
CONSTRUCT
{
  ?post dc:title ?title .
  ?post sioc:link ?link .
  ?post sioc:links_to ?links_to .
  ?post sioc:topic ?topic .
  ?post dcterms:created ?cr
}

WHERE
{
  ?post rdf:type sioc:Post  .
  OPTIONAL { ?post dc:title ?title } .
  OPTIONAL { ?post sioc:link ?link } .
  OPTIONAL { ?post sioc:links_to ?links_to } .
  OPTIONAL { ?post dcterms:created ?cr } .
  OPTIONAL { ?post sioc:topic ?topic }.
  OPTIONAL { ?topic skos:prefLabel ?tag }.
  ?post sioc:has_container ?forum .
  ?forum a sioct:Photo  .
  ?forum sioc:scope_of ?role.
  ?role sioc:function_of ?member.
  ?member sioc:id "demo"
}
');


select exec_score ('sparql define input:default-graph-uri "http://intel.gmz:8890/dataspace_v"
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX sioc: <http://rdfs.org/sioc/ns#>
PREFIX sioct: <http://rdfs.org/sioc/types#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX dc: <http://purl.org/dc/elements/1.1/>
PREFIX dcterms: <http://purl.org/dc/terms/>
CONSTRUCT
{
  ?post dc:title ?title .
  ?post dcterms:created ?date
}

WHERE
{
  ?forum rdf:type sioct:Community .
  ?forum sioc:parent_of ?parentf .
  ?parentf sioc:container_of ?post .
  OPTIONAL { ?post dc:title ?title } .
  OPTIONAL { ?post dcterms:created ?date } .
}
');


