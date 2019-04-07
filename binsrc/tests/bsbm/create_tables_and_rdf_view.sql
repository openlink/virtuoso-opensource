create procedure DB.DBA.exec_no_error(in expr varchar)
{
	declare state, message, meta, result any;
	exec(expr, state, message, vector(), 0, meta, result);
}
;

DB.DBA.exec_no_error('alter table DB.DBA.productfeature rename BSBM_tmp')
;
DB.DBA.exec_no_error('alter table BSBM_tmp rename DB.DBA.ProductFeature')
;

DB.DBA.exec_no_error('alter table DB.DBA.producttype rename BSBM_tmp')
;
DB.DBA.exec_no_error('alter table BSBM_tmp rename DB.DBA.ProductType')
;

DB.DBA.exec_no_error('alter table DB.DBA.producttypeproduct rename BSBM_tmp')
;
DB.DBA.exec_no_error('alter table BSBM_tmp rename DB.DBA.ProductTypeProduct')
;

DB.DBA.exec_no_error('alter table DB.DBA.productfeatureproduct rename BSBM_tmp')
;
DB.DBA.exec_no_error('alter table BSBM_tmp rename DB.DBA.ProductFeatureProduct')
;

DB.DBA.exec_no_error('alter table DB.DBA.product rename BSBM_tmp')
;
DB.DBA.exec_no_error('alter table BSBM_tmp rename DB.DBA.Product')
;

DB.DBA.exec_no_error('alter table DB.DBA.producer rename BSBM_tmp')
;
DB.DBA.exec_no_error('alter table BSBM_tmp rename DB.DBA.Producer')
;

DB.DBA.exec_no_error('alter table DB.DBA.offer rename BSBM_tmp')
;
DB.DBA.exec_no_error('alter table BSBM_tmp rename DB.DBA.Offer')
;

DB.DBA.exec_no_error('alter table DB.DBA.vendor rename BSBM_tmp')
;
DB.DBA.exec_no_error('alter table BSBM_tmp rename DB.DBA.Vendor')
;

DB.DBA.exec_no_error('alter table DB.DBA.person rename BSBM_tmp')
;
DB.DBA.exec_no_error('alter table BSBM_tmp rename DB.DBA.Person')
;

DB.DBA.exec_no_error('alter table DB.DBA.review rename BSBM_tmp')
;
DB.DBA.exec_no_error('alter table BSBM_tmp rename DB.DBA.Review')
;


DB.DBA.exec_no_error('CREATE TABLE DB.DBA.ProductFeature (
  nr integer primary key,
  label varchar(100) not null,
  comment varchar(1500) not null,
  publisher integer not null,
  publishDate date not null
)')
;

grant select on DB.DBA.ProductFeature to public
;

DB.DBA.exec_no_error('CREATE TABLE DB.DBA.ProductType (
  nr integer primary key,
  label varchar(100) not null,
  comment varchar(1500) not null,
  parent integer,
  publisher integer not null,
  publishDate date not null
)')
;

grant select on DB.DBA.ProductType to public
;

DB.DBA.exec_no_error('CREATE TABLE DB.DBA.Producer (
  nr integer primary key,
  label varchar(100) not null,
  comment varchar(1500) not null,
  homepage varchar(100) not null,
  country char(2) not null,
  publisher integer not null,
  publishDate date not null
)')
;

grant select on DB.DBA.Producer to public
;
DB.DBA.exec_no_error('create index producer_homepage on DB.DBA.Producer (homepage)')
;
DB.DBA.exec_no_error('create index producer_country on DB.DBA.Producer (country)')
;

DB.DBA.exec_no_error('CREATE TABLE DB.DBA.Product (
  nr integer primary key,
  label varchar(100) not null,
  comment varchar not null,
  producer integer not null,
  propertyNum1 integer,
  propertyNum2 integer,
  propertyNum3 integer,
  propertyNum4 integer,
  propertyNum5 integer,
  propertyNum6 integer,
  propertyTex1 varchar(250),
  propertyTex2 varchar(250),
  propertyTex3 varchar(250),
  propertyTex4 varchar(250),
  propertyTex5 varchar(250),
  propertyTex6 varchar(250),
  publisher integer not null,
  publishDate date not null
)')
;

grant select on DB.DBA.Product to public
;

DB.DBA.exec_no_error('create index product_lbl on DB.DBA.Product (label)')
;
DB.DBA.exec_no_error('create unique index product_producer_nr on DB.DBA.Product (producer, nr)')
;
DB.DBA.exec_no_error('create index product_pn1 on DB.DBA.Product (propertyNum1)')
;
DB.DBA.exec_no_error('create index product_pn2 on DB.DBA.Product (propertyNum2)')
;
DB.DBA.exec_no_error('create index product_pn3 on DB.DBA.Product (propertyNum3)')
;

DB.DBA.exec_no_error('create text index on DB.DBA.Product (label) with key nr')
;

DB.DBA.exec_no_error('CREATE TABLE DB.DBA.ProductTypeProduct (
  product integer not null,
  productType integer not null,
  PRIMARY KEY (product, productType)
)')
;

grant select on DB.DBA.ProductTypeProduct to public
;

DB.DBA.exec_no_error('create index ptype_inv on DB.DBA.ProductTypeProduct (productType, product)')
;

DB.DBA.exec_no_error('CREATE TABLE DB.DBA.ProductFeatureProduct (
  product integer not null,
  productFeature integer not null,
  PRIMARY KEY (product, productFeature)
)')
;

grant select on DB.DBA.ProductFeatureProduct to public
;

DB.DBA.exec_no_error('create index pfeature_inv on DB.DBA.ProductFeatureProduct (productFeature, product)')
;

DB.DBA.exec_no_error('CREATE TABLE DB.DBA.Vendor (
  nr integer primary key,
  label varchar(100) not null,
  comment varchar not null,
  homepage varchar(100) not null,
  country char(2) not null,
  publisher integer not null,
  publishDate date not null
)')
;

grant select on DB.DBA.Vendor to public
;

DB.DBA.exec_no_error('create index vendor_country on DB.DBA.Vendor (country)')
;
DB.DBA.exec_no_error('create index vendor_homepage on DB.DBA.Vendor (homepage)')
;

DB.DBA.exec_no_error('CREATE TABLE DB.DBA.Offer (
  nr integer primary key,
  product integer not null,
  producer integer,
  vendor integer not null,
  price double precision not null,
  validFrom date not null,
  validTo date not null,
  deliveryDays integer not null,
  offerWebpage varchar(100) not null,
  publisher integer not null,
  publishDate date not null
)')
;

grant select on DB.DBA.Offer to public
;

DB.DBA.exec_no_error('create index offer_product on DB.DBA.Offer (product, deliveryDays)')
;
DB.DBA.exec_no_error('create unique index offer_producer_product on DB.DBA.Offer (producer, product, nr)')
;
DB.DBA.exec_no_error('create index offer_validto on DB.DBA.Offer (validTo)')
;
DB.DBA.exec_no_error('create index offer_vendor_product on DB.DBA.Offer (vendor, product)')
;
DB.DBA.exec_no_error('create index offer_webpage on DB.DBA.Offer (offerWebpage)')
;

DB.DBA.exec_no_error('CREATE TABLE DB.DBA.Person (
  nr integer primary key,
  name varchar(30) not null,
  mbox_sha1sum char(40) not null,
  country char(2) not null,
  publisher integer not null,
  publishDate date not null
)')
;

grant select on DB.DBA.Person to public
;

DB.DBA.exec_no_error('CREATE TABLE DB.DBA.Review (
  nr integer primary key,
  product integer not null,
  producer integer,
  person integer not null,
  reviewDate date not null,
  title varchar(250) not null,
  text long varchar not null,
  textlang char(2) not null,
  rating1 integer,
  rating2 integer,
  rating3 integer,
  rating4 integer,
  publisher integer not null,
  publishDate date not null
)')
;

grant select on DB.DBA.Review to public
;

DB.DBA.exec_no_error('create unique index review_product on DB.DBA.Review (product, producer, nr)')
;

DB.DBA.exec_no_error('create index review_person_1 on DB.DBA.Review (person, product, title)
create index review_person on DB.DBA.Review (person)')
;

DB.DBA.exec_no_error('create unique index review_product_person_producer on DB.DBA.Review (product, person, producer, nr)')
;

DB.DBA.exec_no_error('create unique index review_producer_product on DB.DBA.Review (producer, product, nr)')
;

DB.DBA.exec_no_error('create bitmap index review_textlang on DB.DBA.Review (textlang)')
;

DB.DBA.XML_SET_NS_DECL ('foaf', 'http://xmlns.com/foaf/0.1/', 2)
;
DB.DBA.XML_SET_NS_DECL ('dc', 'http://purl.org/dc/elements/1.1/', 2)
;
DB.DBA.XML_SET_NS_DECL ('xsd', 'http://www.w3.org/2001/XMLSchema-datatypes/', 2)
;
DB.DBA.XML_SET_NS_DECL ('rev', 'http://purl.org/stuff/rev#', 2)
;
DB.DBA.XML_SET_NS_DECL ('bsbm', 'http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/vocabulary/', 2)
;
DB.DBA.XML_SET_NS_DECL ('bsbm-inst', 'http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/instances/', 2)
;

sparql drop quad map bsbm:SingleGraphView
;

sparql create iri class bsbm:ProductFeature-iri "http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/instances/ProductFeature%d" (in nr integer not null)
;

sparql create iri class bsbm:ProductType-iri "http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/instances/ProductType%d" (in nr integer not null)
;

sparql create iri class bsbm:Producer-iri "http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/instances/dataFromProducer%d/Producer%d" (in producer integer not null, in nr integer not null)
;

sparql create iri class bsbm:Product-iri "http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/instances/dataFromProducer%d/Product%d" (in producer integer not null, in nr integer not null)
;

sparql create iri class bsbm:Vendor-iri "http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/instances/dataFromVendor%d/Vendor%d" (in vendor integer not null, in nr integer not null)
;

sparql create iri class bsbm:Offer-iri "http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/instances/dataFromVendor%d/Offer%d" (in vendor integer not null, in nr integer not null)
;

sparql create iri class bsbm:StdInst-iri "http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/instances/StandardizationInstitution%d" (in publisher integer not null)
;

sparql create iri class bsbm:Person-iri "http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/instances/dataFromRatingSite%d/Person%d" (in publisher integer not null, in nr integer not null)
;

sparql create iri class bsbm:Review-iri "http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/instances/dataFromRatingSite%d/Review%d" (in site integer, in nr integer not null)
;

sparql create iri class bsbm:ISO3166-country-iri "http://downlode.org/rdf/iso-3166/countries#%s" (in code varchar not null)
;

sparql create iri class bsbm:homepage-iri "%s" (in homepage varchar not null) option (returns "http://%s")
;

sparql create iri class bsbm:RatingSite-iri "http://www4.wiwiss.fu-berlin.de/bizer/bsbm/v01/instances/dataFromRatingSite%d/RatingSite%d" (in rsite integer not null, in nr integer not null)
;

sparql
alter quad storage virtrdf:DefaultQuadStorage
from DB.DBA.ProductFeature as pfeature
from DB.DBA.ProductType as ptype
from DB.DBA.Producer as producer
from DB.DBA.Product as product text literal product.label
from DB.DBA.ProductTypeProduct as ptypeproduct
from DB.DBA.ProductFeatureProduct as pfeatureproduct
from DB.DBA.Vendor as vendor
from DB.DBA.Offer as offer
from DB.DBA.Person as person
from DB.DBA.Review as review
where (^{product.}^.nr = ^{ptypeproduct.}^.product)
where (^{product.}^.nr = ^{pfeatureproduct.}^.product)
  {
    create bsbm:SingleGraphView as graph <BSBM> option (exclusive)
      {
	bsbm:Product-iri (product.producer, product.nr)
          a bsbm:Product ;
	  rdfs:label product.label ;
          rdfs:comment product.comment ;
          bsbm:producer bsbm:Producer-iri (product.producer, product.producer) ;
          bsbm:productPropertyTextual1 product.propertyTex1 ;
          bsbm:productPropertyTextual2 product.propertyTex2 ;
          bsbm:productPropertyTextual3 product.propertyTex3 ;
          bsbm:productPropertyTextual4 product.propertyTex4 ;
          bsbm:productPropertyTextual5 product.propertyTex5 ;
          bsbm:productPropertyTextual6 product.propertyTex6 ;
          bsbm:productPropertyNumeric1 product.propertyNum1 ;
          bsbm:productPropertyNumeric2 product.propertyNum2 ;
          bsbm:productPropertyNumeric3 product.propertyNum3 ;
          bsbm:productPropertyNumeric4 product.propertyNum4 ;
          bsbm:productPropertyNumeric5 product.propertyNum5 ;
          bsbm:productPropertyNumeric6 product.propertyNum6 ;
          rdf:type bsbm:ProductType-iri (ptypeproduct.productType) ;
          bsbm:productFeature bsbm:ProductFeature-iri (pfeatureproduct.productFeature) ;
          dc:publisher bsbm:Producer-iri (product.publisher, product.publisher) ;
          dc:date product.publishDate .

        bsbm:ProductType-iri (ptype.nr)
          a bsbm:ProductType ;
          rdfs:label ptype.label ;
          rdfs:comment ptype.comment ;
          rdfs:subClassOf bsbm:ProductType-iri (ptype.parent) ;
          dc:publisher bsbm:StdInst-iri (ptype.publisher) ;
          dc:date ptype.publishDate .

        bsbm:ProductFeature-iri (pfeature.nr)
          a bsbm:ProductFeature ;
          rdfs:label pfeature.label ;
          rdfs:comment pfeature.comment ;
          dc:publisher bsbm:StdInst-iri (pfeature.publisher) ;
          dc:date pfeature.publishDate .

        bsbm:Producer-iri (producer.nr, producer.nr)
          a bsbm:Producer ;
          rdfs:label producer.label ;
          rdfs:comment producer.comment ;
          foaf:homepage bsbm:homepage-iri (producer.homepage) ;
          bsbm:country bsbm:ISO3166-country-iri (producer.country) ;
          dc:publisher bsbm:Producer-iri (producer.nr, producer.nr) ;
          dc:date producer.publishDate .

        bsbm:Vendor-iri (vendor.nr, vendor.nr)
          a bsbm:Vendor ;
          rdfs:label vendor.label ;
          rdfs:comment vendor.comment ;
          foaf:homepage bsbm:homepage-iri (vendor.homepage) ;
          bsbm:country bsbm:ISO3166-country-iri (vendor.country) ;
          dc:publisher bsbm:Vendor-iri (vendor.publisher, vendor.publisher) ;
          dc:date vendor.publishDate .

        bsbm:Offer-iri (offer.vendor, offer.nr)
          a bsbm:Offer ;
          bsbm:product bsbm:Product-iri (offer.producer, offer.product) ;
          bsbm:vendor bsbm:Vendor-iri (offer.vendor, offer.vendor) ;
          bsbm:price offer.price ;
          bsbm:validFrom offer.validFrom ;
          bsbm:validTo offer.validTo ;
          bsbm:deliveryDays offer.deliveryDays ;
          bsbm:offerWebpage bsbm:homepage-iri (offer.offerWebpage) ;
          dc:publisher bsbm:Vendor-iri (offer.publisher, offer.publisher) ;
          dc:date offer.publishDate .

        bsbm:Person-iri (person.publisher, person.nr)
          a foaf:Person ;
          foaf:name person.name ;
          foaf:mbox_sha1sum person.mbox_sha1sum ;
          bsbm:country bsbm:ISO3166-country-iri (person.country) ;
          dc:publisher bsbm:RatingSite-iri (person.publisher, person.publisher) ;
          dc:date person.publishDate .

        bsbm:Review-iri (review.publisher, review.nr)
          a rev:Review ;
          bsbm:reviewFor bsbm:Product-iri (review.producer, review.product) ;
          bsbm:producer bsbm:Producer-iri (review.producer, review.producer) ;
          rev:reviewer bsbm:Person-iri (review.publisher, review.person) ;
          bsbm:reviewDate review.reviewDate ;
          dc:title review.title ;
          rev:text review.text lang review.textlang ;
          bsbm:rating1 review.rating1 ;
          bsbm:rating2 review.rating2 ;
          bsbm:rating3 review.rating3 ;
          bsbm:rating4 review.rating4 ;
          dc:publisher bsbm:RatingSite-iri (review.publisher, review.publisher) ;
          dc:date review.publishDate .
      }
  }
;
