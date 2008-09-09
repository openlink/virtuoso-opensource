
CREATE TABLE ProductFeature (
  nr integer primary key,
  "LABEL" varchar2(100) not null,
  "COMMENT" varchar2(1500) not null,
  publisher integer not null,
  publishDate date not null
)
;

grant select on ProductFeature to public
;

CREATE TABLE ProductType (
  nr integer primary key,
  label varchar2(100) not null,
  "COMMENT" varchar2(1500) not null,
  parent integer,
  publisher integer not null,
  publishDate date not null
)
;

grant select on ProductType to public
;

CREATE TABLE Producer (
  nr integer primary key,
  label varchar2(100) not null,
  "COMMENT" varchar2(1500) not null,
  homepage varchar2(100) not null,
  country char(2) not null,
  publisher integer not null,
  publishDate date not null
)
;

grant select on Producer to public
;
create index producer_homepage on Producer (homepage)
;

CREATE TABLE Product (
  nr integer primary key,
  label varchar2(100) not null,
  "COMMENT" varchar2 (1800) not null,
  producer integer not null,
  propertyNum1 integer,
  propertyNum2 integer,
  propertyNum3 integer,
  propertyNum4 integer,
  propertyNum5 integer,
  propertyNum6 integer,
  propertyTex1 varchar2(200),
  propertyTex2 varchar2(200),
  propertyTex3 varchar2(200),
  propertyTex4 varchar2(200),
  propertyTex5 varchar2(200),
  propertyTex6 varchar2(200),
  publisher integer not null,
  publishDate date not null
)
;

grant select on Product to public
;

create index product_lbl on Product (label)
;
create unique index product_producer_nr on Product (producer, nr)
;
create index product_pn1 on Product (propertyNum1)
;
create index product_pn2 on Product (propertyNum2)
;
create index product_pn3 on Product (propertyNum3)
;

create text index on Product (label) with key nr
;

create  index P_LABEL on Product (label) indextype is ctxsys.context;


CREATE TABLE ProductTypeProduct (
  product integer not null,
  productType integer not null,
  PRIMARY KEY (product, productType)
)
;

grant select on ProductTypeProduct to public
;

create index ptype_inv on ProductTypeProduct (productType, product)
;

CREATE TABLE ProductFeatureProduct (
  product integer not null,
  productFeature integer not null,
  PRIMARY KEY (product, productFeature)
)
;

grant select on ProductFeatureProduct to public
;

create index pfeature_inv on ProductFeatureProduct (productFeature, product)
;

CREATE TABLE Vendor (
  nr integer primary key,
  label varchar2(100) not null,
  "COMMENT" varchar2 (600) not null,
  homepage varchar2(100) not null,
  country char(2) not null,
  publisher integer not null,
  publishDate date not null
)
;

grant select on Vendor to public
;

create index vendor_country on Vendor (country)
;
create index vendor_homepage on Vendor (homepage)
;

CREATE TABLE Offer (
  nr integer primary key,
  product integer not null,
  producer integer,
  vendor integer not null,
  price double precision not null,
  validFrom date not null,
  validTo date not null,
  deliveryDays integer not null,
  offerWebpage varchar2(100) not null,
  publisher integer not null,
  publishDate date not null
)
;

grant select on Offer to public
;

create index offer_product on Offer (product, deliveryDays)
;
create unique index offer_producer_product on Offer (producer, product, nr)
;
create index offer_validto on Offer (validTo)
;
create index offer_vendor_product on Offer (vendor, product)
;
create index offer_webpage on Offer (offerWebpage)
;

CREATE TABLE Person (
  nr integer primary key,
  name varchar2(30) not null,
  mbox_sha1sum char(40) not null,
  country char(2) not null,
  publisher integer not null,
  publishDate date not null
)
;

grant select on Person to public
;

CREATE TABLE Review (
  nr integer primary key,
  product integer not null,
  producer integer,
  person integer not null,
  reviewDate date not null,
  title varchar2(200) not null,
  text long varchar not null,
  textlang char(2) not null,
  rating1 integer,
  rating2 integer,
  rating3 integer,
  rating4 integer,
  publisher integer not null,
  publishDate date not null
)
;

grant select on Review to public
;

create unique index review_product on Review (product, producer, nr)
;

create unique index review_producer_product on Review (producer, product, nr)
;

create  index review_textlang on Review (textlang)
;

-- execute ctx_ddl.sync_index ('P_LABEL', '20M');
-- alter system set sga_max_size = 4 G scope = spfile;



