NEWS
====

October 2, 2018, v7.2.6-dev:
----------------------------

  * Virtuoso Engine
    - Added new plugins proj4, geos and shapefileio for GeoSPARQL
    - Added support for Strict-Transport-Security header
    - Added check to make sure RPNG is properly seeded
    - Added support for Forward Secrecy using DH and ECDH
    - Added missing X509_STRING_DATE
    - Added support for rwlock in dict
    - Fixed default cipher list
    - Fixed issues with SSL_CTX options
    - Fixed set default protocol to TLSv1.2 or newer when possible
    - Fixed issue setting cipherlist on https ctx

  * SPARQL
    - Added initial support for GeoSPARQL functions
    - Fixed namespace check for bif: and sql: and issues with system functions

  * JDBC Driver
    - Fixed issue with closing stmt handle in PreparedStatement
    - Removed support for deprecated versions of JDKs 1.1, 1.2, 1.3, 1.4 and 1.5
    - Moved SSL connectivity into regular jdbc drivers

  * Faceted Browser
    - Added page to show state of Entity Data generation
    - Added preview for embedded content
    - Added statistics about users of IRI as subject or object in graph to Metadata page
    - Added support for IRIs from RDFviews
    - Fixed number of i18n issues with URL encodings in /describe
    - Fixed issues with long values such as geo shapes
    - Fixed issue with pager in /describe
    - Fixed issue with page refresh when Show x rows selector changes
    - Fixed issues with https in /describe content negotiation in Alternates and Location headers
    - Fixed issues with /describe page behind a (ssl) proxy

  * Conductor
    - Moved binsrc/yacutia binsrc/conductor

  * DAV
    - Fixed issue with LDP POST command
    - Fixed LDP folder content return (by GET)


August 15, 2018, v7.2.5
-----------------------
  * Virtuoso Engine
    - Added support for application/n-triples mime type
    - Added support for modifying size of SQL compiler cache
    - Added better version checking for OpenSSL to configure
    - Added support for timeout on socket connect
    - Added new debug code to audit SPARQL/SQL errors
    - Added new code for MALLOC_DEBUG
    - Added support for LDAPS
    - Added support for TLSext Server Name Indication to http_client
    - Remove TLSv1 protocol from default protocol list
    - Fixed initial DB.DBA.RDF_DEFAULT_USER_PERMS_SET for user 'nobody' so /sparql endpoint
      can query all graphs without any performance penalty
    - Fixed scheduler errors should be emailed every time the event fails
    - Fixed issue replaying table rename due to dereference of NULL result
    - Fixed issue returning correct user after TLS login
    - Fixed issues with HTTP PATCH command changing resource permissions
    - Fixed check for infinite loop in SQL compiler
    - Fixed XMLA service to select TIMESTAMP, XML_ENTITY, IRI_ID columns
    - Fixed issue with shcompo cache size
    - Fixed memory leaks
    - Fixed portability issues and compiler warnings
    - Fixed issues building Windows binaries using VS2017

  * SPARQL
    - Added new option 'Explain' to /sparql endpoint
    - Added new help page for RDF views to /sparql endpoint
    - Fixed initial fill of language and datatype caches after server restart
    - Fixed SPARQL DELETE for quads which failed on booleans and other inlined RDF boxes
    - Fixed SPARQL 1.1 SUBSTR()
    - Fixed issues with PATCH not returning an error after a SPARQL error
    - Fixed SPARQL_CONSTRUCT_ACC could get fixed-value variables referred to in 'stats' argument
    - Fixed Turtle 1.1 permits multiple semicolons without predicate-object pairs between them
    - Fixed handling for timezone date values from sparql queries
    - Fixed readability and indentation of EXPLAIN output
    - Fixed issue encoding urls in SPARQL/FED
    - Fixed st_contains and other geo predicates
    - Fixed issue with cast numeric to bool
    - Fixed issues with Turtle and JSON;LD_CTX

  * Jena & Sesame
    - Added method to Sesame provider to query across all RDF graphs in Quad Store
    - Added set/getIsolationLevel to VirtDataset
    - Update using of DB proc rdf_insert_triple_c()
    - Fixed baseURI parameter not handled properly by RDF4J provider
    - Fixed issue with Jena object values that are URLs
    - Fixed providers Jena/RDF4J set/getNamespaces in global cache instead of connection cache
    - Fixed xsd:boolean literals returned as xsd:string literals
    - Fixed VirtDataset class for properly handle transaction

  * JDBC Driver
    - Added support for concurency mode CONCUR_VALUES
    - Added support for SSL truststore
    - Fixed binding/conversion of Unicode characters
    - Fixed handling of SPARQL negative dates
    - Fixed Sql Workbench/J csv file import in Virtuoso fails on empty numeric fields
    - Fixed exception handling

  * ADO.NET
    - Fixed support for SPARQL Negative Dates, Concurrency modes, Connection option "Log_enable"
    - Fixed compilation warnings and errors on Mono and .NET versions on Windows
    - Fixed error in CompareTo() methods
    - Fixed issue ADO.NET for DateTime types and TZ

  * Faceted Browser
    - Fixed incorrect UTF-8 character IRI handling in Namespaces

  * Conductor
    - Added option to delete locked files by admin users
    - Added support for JSON and JSON-LD in rewrite rules for SPARQL query output
    - Added support for importing PEM and DER formats
    - Updated Conductor UI to support new redirection options
    - Moved 'OAuth Service Binding' to 'Web Services'
    - Optimized handling of vspx session expiration
    - Fixed issue creating new user accounts with conductor using user with dba and administrator roles
    - Fixed a missing CA chain does not mean .p12 file is bad
    - Fixed issue with 'Next' time in Scheduler
    - Fixed selection of category in the database browser page
    - Fixed rewrite rule export format
    - Fixed CSV importer
    - Fixed crawler functions to work with HTTPS sources
    - Fixed issues with Rewrite Rule export function
    - Fixed issues in R2RML

  * DAV
    - Added item creator as a field in the properties when not empty
    - Added overwrite flag for DynaRes creation
    - Optimized calls to some APIs using user/password properties
    - Fixed issues related to the LITMUS testsuite for DAV
    - Fixed issues with Mac OS X WebDAV mapping
    - Fixed issues with WEBdav browser and folder selection
    - Fixed issue deleting Smart folders
    - Fixed issue with permissions for PUT command
    - Fixed bug with PROPFIND and bad XML (without correct namespace) as body
    - Fixed issue with DAV authentication
    - Fixed issues with set/update LDP related data
    - Fixed response code to 204 for PATCH command
    - Fixed return 406 if no matching Accept header found
    - Fixed issue retrieving user's profile data with RDFData DET

  * DBpedia
    - Added LODmilla browser


April 25, 2016, v7.2.4
----------------------
  * Virtuoso Engine
    - Added "obvious" index choice
    - Added new bif http_redirect_from for getting initial path from internal redirect
    - Fixed ODBC issue with SQL_C_LONG bound to an int32 instead of an int64/long
    - Fixed hang as page was not left if geo_pred signal an error
    - Fixed check if geo pred gets right arguments to prevent crash
    - Fixed portability issue on windows
    - Fixed issue with cost based optimizer for isiri_id
    - Fixed no change from chash to pageable if enable_chash_gb = 2
    - Disable AIO for this release of virtuoso

  * SPARQL
    - Added missing grants to SPARQL_UPDATE
    - Added optimizations of paths with complementary and/or repeating paths
    - Added min/max for iri id
    - Added support for <script>...</script> inlining of RDF data in HTML output
    - Added support for CVS in RFC4180 format
    - Added support for skipping UTF-8 BOM marks on Turtle and JSON lexers
    - Added support for service invocation of bigdata running in triples and introducing language exceptions
    - Added new debug option to /sparql page
    - Fixed issue with ':' in blank node labels
    - Fixed NQuads do not permit %NN in blank node labels
    - Fixed issues with property paths like <p>|!<p>
    - Fixed issue when SERVICE clause does not return real vars, only ?stubvarXX
    - Fixed issue with unused default graph
    - Fixed issue with SPARQL select count(distinct *) { ... }
    - Fixed SPARQL-BI syntax for HAVING
    - Fixed issue with duplicate triples in microdata
    - Fixed handling of strings containing serialized xml
    - Fixed issue with boolean in sparql/xml results

  * Jena & Sesame
    - Added Sesame 4 provider
    - Added Jena 3 provider
    - Added support for Sesame 2.8.x
    - Added Jena example for use Inference and Ontology Model with Jena provider
    - Fixed Node2Str for Literals for more properly handle Literals with Lang
    - Fixed issue with openrdf-workbench application
    - Fixed Testsuites
    - Fixed Sesame 2 test connection string
    - Fixed PreparedStatement with params binding for SPARQL queries with parameters instead of substitution parameter values to query
    - Updated testsuites

  * JDBC Driver
    - Added support for building JDK 1.8 / JDBC 4.2
    - Added support for Connection.setCatalog()
    - Fixed conversion of broken unicode strings
    - Fixed variable initialization
    - Fixed VirtuosoDataSource methods setLog_Enable()/getLog_Enable() for properly work with Spring framework
    - Fixed JDBC driver to remove finalizers

  * Faceted Browser
    - Added link-out icons
    - Added more link-out relations
    - Fixed content negotiation
    - Fixed default output is xml
    - Fixed facet search service
    - Fixed issue with css
    - Fixed labels
    - Fixed missing alias in fct svc
    - Fixed missing grant
    - Fixed og:image added to list
    - Fixed possible change of displayed resources post-sponge
    - Fixed prefixes
    - Fixed space encoding in iri
    - Fixed splitting UTF-8 strings can produce bad encoded strings
    - Fixed support for images
    - Fixed svc search to keep address

  * Conductor
    - Added validation for sequence number value
    - Added start/expiry date of CA
    - Added new option to disable scheduled job
    - Synced Conductor WebDAV implementation with briefcase
    - Fixed set specific sponger pragmas on text/html
    - Fixed checkpoint after rdf view generation
    - Fixed use of transactional mode
    - Fixed issue with ldap server
    - Fixed labels

  * DAV
    - Small optimization for update triggers of WS.WS.SYS_DAV_RES
    - Fixed set specific sponger pragmas on text/html
    - Fixed issue uploading turtle files containing special symbols

  * DBpedia
    - Implemented new fluid skin design for DBpedia /page based on the Bootstrap Framework
    - Updated DBpedia VAD for UTF-8 based URIs for International Chapters
    - Updated prefixes
    - Added references to license
    - Fixed show language with label, abstract, comment
    - Fixed the http://mementoarchive.lanl.gov link


December 09, 2015, v7.2.2
-------------------------
  * Virtuoso Engine
    - Added support for reading bzip2 compressed files
    - Added support for reading xz/lzma compressed files
    - Added optimization for date/datetime/time escapes
    - Fixed use vfork if working properly to reduce memory footprint on exec
    - Fixed issue with SQL_TIMEZONELESS_DATETIMES
    - Fixed issue with uninitialized data in TIME string
    - Fixed issue with checkpoint recovery
    - Fixed issue with freeing checkpoint remap col pages
    - Fixed issue with row locks
    - Fixed issue with sampling
    - Fixed issue with outer-join plan
    - Fixed xmlliteral should be serialized as UTF-8
    - Fixed enable_joins_only=1 hint to cost based optimizer
    - Fixed merge transaction log
    - Fixed issues with extent map
    - Fixed itc_ranges can be uninitialized when scanning updated/deleted pages
    - Fixed issue with cascaded delete
    - Fixed allow identity to start with 0
    - Fixed memory leaks
    - Updated debian packaging
    - Updated testsuite
    - Updated documentation

  * SPARQL
    - Added batch validation of JSO instances and new mode 3 for RDF_AUDIT_METADATA()
    - Added new JSO loader with bif_jso_validate_and_pin_batch
    - Added new pretty-printed HTML tabular output for SPARQL SELECT in /sparql page
    - Added support for bulkloading .gz, .xz and .bz2 files
    - Fixed recovery of DefaultQuadStorage etc in DB.DBA.RDF_AUDIT_METADATA()
    - Fixed EWKT reader to be case-insensitive according to paragraph 7.2.1. of OGC 06-103r4
    - Fixed issue when nil <p> <o> triple pattern is used
    - Fixed handling of bad IRI_IDs in DB.DBA.RDF_GAPH_SECURITY_AUDIT()
    - Fixed output of @type in JSON-LD
    - Fixed nice microdata
    - Fixed issues with gYear, gMonth etc in json/csv/sparql output formats
    - Fixed issues with const in distinct
    - Fixed issue with recovery for property paths with "*" on SERVICES
    - Fixed check to prevent wide insert into O column
    - Fixed issue in RDF_LONG_TO_TTL with typed RDF literals
    - Fixed for vectorization-related error on SPARQL queries with RDF_GRAB
    - Fixed handling of weird blank node labels like _:2
    - Fixed issue with unique keys
    - Fixed size of rdf lang cache
    - Fixed codegen for IN operator when left hand is column and right hand contains constants
    - Fixed crash when blank nodes are used in data rows of VALUES

  * Jena & Sesame
    - Update Jena provider to configure conversion of Jena BNodes to Virtuoso BNodes
    - Fixed log_enable support
    - Fixed issue with literals that have both Language and Datatype tags

  * JDBC Driver
    - Added missing server-side setting
    - Added initial testsuite for handling date values in JDBC provider
    - Fixed issues decoding RdfBox with Date object and timezoneless modes
    - Fixed return SPARQL Time GMT0 with Z suffix  ("13:24:00.000Z" instead of "13:24:00.000-00:00")
    - Fixed return SPARQL DateTime GMT0 with Z suffix  ("1999-05-31T13:24:00Z" instead of "1999-05-31T13:24:00-00:00")
    - Fixed log_enable support
    - Fixed Datasources to support both JNDI attribute names "charset" and "charSet"
    - Fixed UTF8 to String conversion for return ? for bad character instead of throw Exception.
    - Fixed JDBC testsuite

  * .NET Adapter
    - Fixed build rules for Virtuoso .NET Adapter
    - Fixed ADO.NET prefetch size from 20 to 100
    - Fixed Int32 overflow in VirtuosoDataReader.GetValues
    - Fixed issue with implementation of Cancel
    - Fixed NullPointer exception in ManagedCommand, when Connection is closed after exceptions

  * Faceted Browser
    - Added small query optimization
    - Added support for auto sponge
    - Added support for emitting microdata instead of rdfa
    - Added missing grants
    - Added iframe opt
    - Fixed handling of nodeID, null graphs, foaf:depiction and iframe
    - Fixed describe mode from LOD to CBD
    - Fixed serialization issue
    - Fixed namespace prefixes
    - Fixed error on bad IRIs
    - Fixed error on subseq when uri is wide string
    - Fixed issue passing literal as reference parameter in fct
    - Fixed show distinct count on list-count view
    - Fixed issue with xtree over null
    - Fixed labels

  * Conductor
    - Added export function for key storage
    - Added filters to IMAP DET folders
    - Added support for FTP DET
    - Added support for move and copy commands on some DETs
    - Added support for new RDF params in WebDAV browser
    - Added support for pattern search and edit options to namespace prefixes
    - Added support for setting file expiration for WebDAV/Briefcase
    - Fixed iMAP DET filter page
    - Fixed turtle editor text revision
    - Fixes for site-copy robot

  * DAV
    - Added DETs move/copy commands
    - Added IMAP DET filters to WebDAV browser
    - Added last-modified for dav res
    - Added optimizations using RDF params for DET folders
    - Added scheduler procedure for expired items
    - Added support for FTP DET
    - Fixed issues creating/updating LDP containers
    - Fixed bug updating existing file with only read permission on parent dir
    - Fixed calculation of MD5 value for resource content
    - Fixed issue with POST of SPARQL query with "Content-Type: application/sparql-query"
    - Fixed issues with DAV permissions
    - Fixed resource size value for some DAV operations
    - Fixed resource update API call and sync with HTTP PUT
    - Fixed setting DET RDF params
    - Fixed timezone bug with S3 DET


June 24, 2015, v7.2.1
---------------------
  * Virtuoso Engine
    - Added support for datetime without timezone
    - Added new implementation of xsd:boolean logic
    - Added new text index functions and aggregates
    - Added better handling of HTTP status codes on SPARQL graph protocol endpoint
    - Added new cache for compiled regular expressions
    - Added support for expression in TOP/SKIP
    - Fixed cost based optimizer
    - Fixed codegen for ((A is NULL) or (A=B)) and similar in LEFT OUTER JOIN
    - Fixed issue with conditional expression
    - Fixed issue with SSL handshake in non-blocking mode
    - Fixed issue with anytime and group by
    - Fixed issue with multistate order by
    - Fixed issues with stability
    - Fixed CORS headers
    - Fixed memory leaks
    - Updated documentation

  * SPARQL
    - Added support for SPARQL GROUPING SETS
    - Added support for SPARQL 1.1 EBV (Efficient Boolean Value)
    - Added support for define input:with-fallback-graph_uri
    - Added support for define input:target-fallback-graph-uri
    - Fixed SPARQL queries with sub-selects
    - Fixed SPARQL abs() should not convert result to integer
    - Fixed UNDEF is now a valid generic subexpression in SPARQL
    - Fixed SQL codegen for SPARQL SELECT ... count(*) ...
    - Fixed SPARQL issue with UNION with multiple BINDS
    - Fixed handling of '*' in COUNT(*) and COUNT(DISTINCT *)
    - Fixed handling of "plain box" constants
    - Fixed handling of optional minus sign on SPARQL values
    - Fixed sparul target for ignore default graph from context but set from USING
    - Fixed issue inserting triple with XML type
    - Fixed issue with bad filter reduced to NULL
    - Fixed return \uNNNN\uNNNN instead of \UNNNNNNNN in JSON strings
    - Fixed issue with xsd:dayTimeDuration in codegen
    - Fixed issue multiple OPTIONALs for a variable or nullable subq + optional

  * Jena & Sesame
    - Added support for using rdf_insert_triple_c() to insert BNode data
    - Added support for returning xsd:boolean as true/false rather than 1/0
    - Added support for maxQueryTimeout in Sesame2 provider
    - Fixed storing blank nodes as URIs
    - Fixed issue with insert data via Jena provider in XA transaction
    - Fixed issue closing XA connection
    - Fixed issue with DELETE query
    - Fixed issue with blank nodes in DELETE constructor
    - Fixed issues with Date/Time/DateTime literals
    - Fixed corrupted literals with datatypes using Jena provider
    - Removed deprecated class reference

  * JDBC Driver
    - Added new methods setLogFileName and getLogFileName
    - Added new attribute "logFileName" to VirtuosoDataSources for logging support
    - Fixed issues logging JDBC XA operations and JDBC RPC calls
    - Fixed JDBC driver did not use SQL_TXN_ISOLATION setting from init handshake
    - Fixed throw exception when reading polygon geometry by JDBC
    - Fixed issues with Date, Time and DateTime
    - Fixed hang on PreparedStatement when using setFetchSize() method

  * Faceted Browser
    - Added support for emitting microdata instead of rdfa
    - Added query optimizations
    - Added footer icons to /describe page
    - Fixed support for graph permission checks
    - Fixed user switch
    - Fixed serialization issue
    - Fixed html content detection
    - Fixed labels
    - Fixed bad font on Chrome

  * Conductor and DAV
    - Added support for VAD dependency tree
    - Added support for default vdirs when creating new listeners
    - Added support for private RDF graphs
    - Added support for LDP in DAV API
    - Added option to create shared folder if not exists
    - Added option to enable/disable DET graphs binding
    - Added option to set content length threshold for async spongeing
    - Added folder option related to .TTL redirection
    - Added functions to edit turtle files
    - Added popup dialog to search for unknown prefixes
    - Added registry option to add missing prefixes for .TTL files
    - Fixed DETs to work with new private graphs
    - Fixed conflict using graph for share and LDP in WAC delete queries
    - Fixed hrefs for resource paths in DAV browser
    - Fixed issue deleting files from DAV
    - Fixed issues with subfolders of DETs type ResFilter and CatFilter
    - Fixed labels

February 17, 2015, v7.2.0
-------------------------
  * Virtuoso Engine
    - Added new threadsafe / reentrant SQL parser
    - Added support for using TLSF library for page-maps
    - Added support for setting SSL Protocols and Ciphers
    - Added support for new Unicode-3 based collations
    - Added support for custom HTTPLogFormat
    - Added support for quality factor in accept headers
    - Added rate limiter for bad connections
    - Added ODBC 3.x alias for current_date, current_time and current_timestamp
    - Improved cost based optimizer
    - Improved LDP support
    - Improved XPER support
    - Improved CSV support
    - Fixed handling of regexp cache size and pcre_match depth limit
    - Fixed handling of multibyte strings
    - Fixed handling of nvarchar data with zeroes in the middle
    - Fixed handling of values in 10 day gap between Julian and Gregorian dates
    - Fixed if expr in rdf o range condition, set super so they get placed once
    - Fixed issue possibly reading freed block
    - Fixed issue with TZ field without separator
    - Fixed issue with duplicate hashes
    - Fixed issue with invariant preds
    - Fixed issue with non chash distinct gby with nulls
    - Fixed issue with user aggregates and chash flush
    - Fixed issues with outer join, order by and group by
    - Fixed sending IRI IDs to remotes when using 'where 0'
    - Fixed use SHA256 as default for certificate signing
    - Fixed memory leaks and memory fragmentation
    - Fixed ssl read/write error condition
    - Fixed windows build

  * GEO functions
    - Added support for SPARQL INSERT with GEO literals
    - Added support for upcoming proj4 plugin
    - Fixed issue with rdf box with a geometry rdf type and a non geometry content
    - Fixed calculation of serialization lengths for geo boxes
    - Fixed compilation of a query with bif:st_intersects inside service {}
    - Fixed serialization of geo boxes
    - Fixed intersect to working with other geo shapes

  * SPARQL
    - Added new SPARQL pragma: define sql:comment 0/1
    - Added indicator when max rows is returned on /sparql endpoint
    - Added new role SPARQL_LOAD_SERVICE_DATA
    - Added new client callable graph ins/del/replace functions
    - Added support for __tag of UNAME
    - Added support for multiple sparql update commands
    - Added support for xsd:gYear and the like
    - Added support for CASE x WHEN ... and CASE when in SPARQL
    - Added support for 'HTML with nice turtle' output format
    - Added TransStepMode option to virtuoso.ini
    - Improved handling of floats and doubles in SPARQL compiler
    - Improved Turtle parser
    - Fixed SPARQL DELETE DATA when a complete RDF box w/o RO_ID is passed as obj
    - Fixed URI() is synonym for IRI()
    - Fixed equality of unames and strings, iri strings
    - Fixed issue eliminating empty {} in VALUE join
    - Fixed issue with R2RML
    - Fixed issue with XMLA
    - Fixed issue with base graph when  using 'with_delete' in bulkloader
    - Fixed issue with multiple OPTIONAL
    - Fixed issue with sparql ... with delete on certain datatypes
    - Fixed issue with varbinary in rdf views
    - Fixed printing optimized-away data rows of VALUES in sparql_explain() dump
    - Fixed propagation of limits if SPART_VARR_EXTERNAL/GLOBAL variables present
    - Fixed regression for SPARQL 1.1 VALUES bindings
    - Fixed sort accented letters from "ORDER BY" in alphabetical order
    - Fixed startup speed with many graph group members

  * Jena & Sesame
    - Upgraded to Jena 2.12.0
    - Added support for Bulk Loading
    - Added support for Dataset method using defaultInsertGraph and defaultRemoveGraph
    - Fixed handling of blank nodes
    - Fixed transaction handling
    - Fixed NullPointerException for sparql with OPTIONAL
    - Fixed issue with statement leaks in older Virtuoso JDBC driver
    - Fixed issue with class definitions and classcast exceptions
    - Fixed issue with large datasets like Uniprot

  * JDBC Driver
    - Enhanced Connection Pool implementation
    - Added support for arrays for RDF Bulk loader
    - Added JDBC4 compliant metadata required by JBOSS
    - Fixed issue with statement leaks
    - Fixed issue with RoundRobin if server out of license
    - Fixed issue with stored procedures returning multiple resultsets
    - Fixed issue with rewind on Virtuoso blob
    - Fixed issue with batch procedure execution
    - Fixed issue with dates
    - Fixed issue with SQL_UTF8_EXECS=1
    - Fixed issue with JDBC testsuite

  * Faceted Browser
    - Added support for graph selection and persist in fct state
    - Added support for link out icons on certain doc and image links
    - Added new description and sponger options as entity link types
    - Added option for json output to fct service
    - Added group by to speed up distinct
    - Added precompiled queries to speed up usage.vsp
    - Fixed base uri for crawlers
    - Fixed color scheme
    - Fixed graph perm check
    - Fixed handling of foaf:depiction
    - Fixed handling of iframe
    - Fixed issue when lang is missing to fct service
    - Fixed issue with dateTime
    - Fixed issue with double quotes in literals
    - Fixed issue with nodeID
    - Fixed issue with null graphs
    - Fixed labels
    - Fixed links

February 17, 2014, v7.1.0
-------------------------
  * Engine
    - Enhancements to cost based optimizer
    - Added optimization when splitting on scattered inserts
    - Added optimization on fetching col seg
    - Added support for multithreaded sync/flush
    - Added support for ordered count distinct and exact p stat
    - Added new settings EnableMonitor
    - Added BIFs key_delete_replay(), set_by_graph_keywords(),
      tweak_by_graph_keywords, vec_length(), vec_ref(),
      x509_verify_array(), xenc_x509_cert_verify_array()
    - Added new functions bif_list_names() and bif_metadata()
    - Added new general-purpose HTTP auth procedure
    - Added support for local dpipes
    - Added support for session pool
    - Added option to allow restricting number of id ranges for new IRIs
    - Added support for execution profile in xml format
    - Added support for PL-as-BIFs in SPARQL
    - Improved I/O for geometries in SQL
    - Fixed geo cost of non point geos where no explicit prec
    - Fixed reentrant lexer
    - Fixed rpc argument checks
    - Fixed memory leaks
    - Fixed compiler warnings
    - Treat single db file as a single segment with one stripe
    - Updated testsuite

   *  GEO functions
    - Added initial support for geoc_epsilon(), geometrytype(),
      st_affine() (2D trans nly), st_geometryn(), st_get_bounding_box_n(),
      st_intersects(), st_linestring(), st_numgeometries(),
      st_transform_by_custom_projection(), st_translate() ,
      st_transscale(), st_contains() , st_may_contain(),
      st_may_intersect()
    - Added new BIFs for getting Z and M coords
    - Added support for <(type,type,...)type::sql:function> trick
      in order to eliminate conversion of types on function call
    - Optimization in calculation of gcb steps to make number of
      chained blocks close to square root of length of the shape
    - Fixed geo box support for large polygons
    - Fixed mp_box_copy() of long shapes
    - Fixed range checks for coordinates
    - Fixed calculation of lat/long ratio for proximity checks
    - Fixed boxes in geo_deserialize
    - Fixed check for NAN and INF in float valued geo inx
    - Fixed check for NULL arguments
    - Minor fixes to other geo BIFs

  * SPARQL
    - Added initial support for list of quad maps in SPARQL BI
    - Added initial support for vectored iri to id
    - Added initial support for sparql valid()
    - Added new codegen for initial fill of RDB2RDF
    - Added new settings CreateGraphKeywords, QueryGraphKeywords
    - Added new SPARQL triple/group/subquery options
    - Added missing function rdf_vec_ins_triples
    - Added support for application/x-nice-microdata SPARQL format
    - Added support for buildin inverse functions
    - Added support for geosparql wkt type literal as synonym
    - Added support for the '-' operator for datetime data types
    - Fixed issues in handling geo predicates in SPARQL
    - Fixed RDF view to use multiple quad maps
    - Fixed issues with UNION and BREAKUP
    - Fixed dynamic local for vectored
    - Fixed support for combination of T_DIRECTION 3 and T_STEP (var)
    - Fixed handle 30x redirects when calling remote endpoint
    - Fixed support for MALLOC_DEBUG inside SPARQL compiler
    - Fixed TriG parser

  * Jena & Sesame
    - Improved speed of batch delete
    - Removed unnecessary check that graph exists after remove
    - Removed unnecessary commits
    - Replaced n.getLiteralValue().toString() with n.getLiteralLexicalForm()

  * JDBC Driver
    - Added statistics for Connection Pool
    - Fixed speed of finalize

  * Conductor and DAV
    - Added trigger for delete temporary graphs used for WebID verification
    - Added new CONFIGURE methods to DETs to unify folder creation
    - Added new page for managing CA root certificates
    - Added new pages for graph level security
    - Added verify for WebDAV DET folders
    - Added creation of shared DET folders
    - Fixed creation of ETAGs for DET resources
    - Fixed DAV rewrite issue
    - Fixed dav to use proper escape for graphs when uploading
    - Fixed issue deleting graphs
    - Fixed issue uploading bad .TTL files
    - Fixed issue with DAV QoS re-write rule for text/html
    - Fixed issue with user dba when creating DET folders
    - Fixed normalize paths procedure in WebDAV
    - Fixed reset connection variable before no file error

  * Faceted Browser
    - Added missing grants
    - Added graph param in FCT permalink
    - Changed labels in LD views
    - Changed default sort order to date (desc)
    - Copied virt_rdf_label.sql locally
    - Fixed escape double quote in literals
    - Fixed FCT datatype links
    - Fixed the curie may contain UTF-8, so mark string accordingly
    - Changed describe mode for PivotViewer link


August 02, 2013, v7.0.0
-----------------------
  * First official release of Virtuoso Open Source Edition v7.0

  NOTE: At this point in time the engine is only buildable in 64bit mode


July 12, 2011, v7.0.0-alpha
---------------------------
  * First release of the experimental v7 branch.

  NOTE: This version is unstable and should not be used for any production
        data. The database format may still change during the next couple
        of cycles and we do not guarantee any upgrading at this point.
