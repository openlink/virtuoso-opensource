SPARQL
PREFIX  acl:  <http://www.w3.org/ns/auth/acl#>
PREFIX  oplacl:  <http://www.openlinksw.com/ontology/acl#>
WITH <urn:virtuoso:val:acl:schema>
DELETE { <urn:virtuoso:val:scopes:graphql-sparql> ?p ?o }
WHERE { <urn:virtuoso:val:scopes:graphql-sparql> ?p ?o };

SPARQL
PREFIX  acl:  <http://www.w3.org/ns/auth/acl#>
PREFIX  oplacl:  <http://www.openlinksw.com/ontology/acl#>
WITH <urn:virtuoso:val:config>
DELETE { oplacl:DefaultRealm oplacl:hasEnabledAclScope <urn:virtuoso:val:scopes:graphql-sparql> . };

SPARQL
PREFIX  acl:  <http://www.w3.org/ns/auth/acl#>
PREFIX  oplacl:  <http://www.openlinksw.com/ontology/acl#>
INSERT
INTO <urn:virtuoso:val:acl:schema>
{
  <urn:virtuoso:val:scopes:graphql-sparql> a  oplacl:Scope ;
    rdfs:label  "GraphQL/SPARQL Bridge" ;
    oplacl:hasApplicableAccess  oplacl:Read, oplacl:Write  ;
    oplacl:hasDefaultAccess  oplacl:Read .
};

SPARQL
PREFIX  acl:  <http://www.w3.org/ns/auth/acl#>
PREFIX  oplacl:  <http://www.openlinksw.com/ontology/acl#>
INSERT
INTO <urn:virtuoso:val:config>
{
  oplacl:DefaultRealm oplacl:hasDisabledAclScope <urn:virtuoso:val:scopes:graphql-sparql> .
};
