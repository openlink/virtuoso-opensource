# NEWS

## February 13, 2024, v7.2.12:

  * Virtuoso Engine
    - Added JSON-LD parser mode for handling blank nodes
    - Added serialization support for missing datatypes in obj2json
    - Added statistics and setting to limit mem pool for chash
    - Added support for dumping `XML` and `varbinary` data in JSON
    - Added support for fetching `attributes` and `attributes_info` on user defined types
    - Added `create user .. with password` and `identified by` syntax
    - Added uptime, virtual memory size, and page faults to status() output
    - Updated CSV functionality
    - Fixed NaN behaviour in cmp_double same as ordering (fixes #1213)
    - Fixed check constraint cannot use CONTAINS text predicate (fixes #1177)
    - Fixed check for date/time/datetime/timestamp datatypes (fixes #1206)
    - Fixed check for table def (fixes #1212)
    - Fixed check if prev has a key (fixes #1216)
    - Fixed check number of arguments to geo contains (fixes #1209)
    - Fixed check values before copying invalid data (fixes #1208)
    - Fixed get argument before place gets mangled when serializing ANY (fixes #1174)
    - Fixed issue getting lock information for status()
    - Fixed issue mixing numeric and int boxes in expression (fixes #1194, #1198)
    - Fixed issue mixing vectored and non vectored ops (fixes #1184)
    - Fixed issue on cube/rollup with constant in select list (fixes #1195, #1197)
    - Fixed issue right outer join with constant false (fixes #1214)
    - Fixed issue skipping sort node on outer as hash join may put right side at top
    - Fixed issue when hash source is not available (fixes #1193)
    - Fixed issue with TOP 1 on a cursor
    - Fixed issue with TOP not working when DISTINCT is used (fixes #1158)
    - Fixed issue with all const in group (fixes #1204)
    - Fixed issue with bad index op ref in table dft (fixes #1190, #1191)
    - Fixed issue with freetext index; missing check if term is mergable
    - Fixed issue with function inside control expression
    - Fixed issue with missing cast on return type (fixes #1172)
    - Fixed issue with outer hash build (fixes #1185)
    - Fixed issue with outer hash join with GROUP BY via hash source
    - Fixed issue with printf style functions not using explicit format string (fixes #1199)
    - Fixed issue with scalar subq (fixes #1183)
    - Fixed issue with select (select ... union ...) or similar expressions
    - Fixed issue with setting type before col assign function (fixes #1178)
    - Fixed issue with sql fragment that has div operation
    - Fixed issue with status for non dba user
    - Fixed issue with user aggregates
    - Fixed issue with with dfe true/false shortcuts (fixes #1196)
    - Fixed issues in orderby/groupby (fixes #1210)
    - Fixed issues with unix timestamp
    - Fixed missing argument check to ORDER BY and GROUP BY (fixed #1182)
    - Fixed missing check for freetext field (fixes #1220)
    - Fixed obj2json and obj2xml should be public functions
    - Fixed remove duplicate keys in oby/gby (fixes #1205)
    - Fixed sprintf format for windows (fixes #1203)

  * SPARQL
    - Added support for GRAPH decorations in TriG (fixes #1169)
    - Fixed issue in ontology generation
    - Fixed issue with drop quad map graph
    - Fixed issue with restriction on number of deleted triples (fixes #1164)
    - Fixed issue with turtle/n-triples media type legacy and recent spec. compatibility (fixes #1187)
    - Fixed issue with very long sparql queries
    - Fixed issues with `Default Graph IRI` from table `SYS_SPARQL_HOSTS` (fixes #1086)
    - Fixed `virtrdf:Geometry` should be replaced with wktLiteral (fixes #806)

  * Web Server and DAV
    - Added HTTP CORs pattern support
    - Added support to avoid redundant check for 401 handlers
    - Added support for Azure Storage Account as a DET mounting option
    - Added support for Access-Control-Allow-Methods different than Allow, for AJAX CORs
    - Added `security_realm` to access realm from VD
    - Added support for ping/pong for websock
    - Added support for binary frames in websocket
    - Fixed FS directory browsing does not need SQL/VSP user account
    - Fixed HTTP 101/204/304 responses MUST not return content
    - Fixed LDP sparql queries delete/insert should search physical graph only
    - Fixed check DET HTTP status code
    - Fixed check for missing graph
    - Fixed clear http method at session cleanup
    - Fixed do not use gzip if no content is allowed
    - Fixed http log records partial request over 4k
    - Fixed issue checking `is_https` on websocket
    - Fixed issue getting dtp in rdf box case
    - Fixed issue when ODS is not installed
    - Fixed issue when response is chunked/gzip by app
    - Fixed issue with `DAV_LINK` double escape UTF-8
    - Fixed issue with bad Accept header
    - Fixed issue with double free
    - Fixed issue with updating permissions on wiki
    - Fixed issues with encoding of DAV URLs
    - Fixed websocket error message indicating what frame type is
    - Fixed websocket framing on text messages
    - Fixed missing entry for .md text/markdown

  * Faceted Browser
    - Fixed grants must be added to `SPARQL_SELECT` role
    - Removed `rdf_resolve_labels_s` case

  * Conductor
    - Added support for password show/hide in login dialog
    - Added backup before rdf view creation
    - Added auto-commit mode flag
    - Fixed CSV import accessing outside of header array
    - Fixed error message on page
    - Fixed import w/o columns detected should not be syntax error
    - Fixed issue refreshing status variables
    - Fixed mismatch of a URL parameter and control

  * R2RML
    - Added quap map iri parameter
    - Fixed rr:template by default is IRI unless column, dt or lang are given
    - Fixed complete table name before quoting
    - Fixed case to ucase for case insensitive lookup
    - Fixed issue with column CaSeMoDe

  * GraphQL
    - Fixed issue when field type cannot be detected


## September 26, 2023, v7.2.11:

  * Virtuoso Engine
    - Added log info on manual enable/disable scheduler and checkpoint intervals
    - Added sprintf format %[xx]s for registry settings
    - Added CPU% and RSS usage to status() output
    - Added BIF jsonld_ctx_to_dict
    - Added input state in explain output where missing
    - Fixed issue with SPARQL UUID() function (fixes #515)
    - Fixed missing grant from SPARQL_UPDATE role (fixes #1152)
    - Fixed issue with DROP TABLE/VIEW not checking target
    - Fixed issue when copying constants in union
    - Fixed several issues in json parser
    - Fixed issue with get_keyword with soap options vector
    - Fixed issue with chash on many threads
    - Fixed issue with lang matches
    - Fixed issue loading graphql plugin with musl C library
    - Fixed do not replace trx log prefix with CHECKPOINT command
    - Fixed small typos in documentation and error messages

  * SPARQL
    - Fixed SPARQL property path query returning incorrect results
    - Fixed issue with conflict on join predicate of pview leading to AREF error
    - Fixed issue with heterogeneous data column leading to range assert
    - Fixed issue reusing boxes
    - Fixed RDF quad sanity check for 'O' column
    - Fixed entities in /sparql UI for maximum X(HT)ML compatibility

  * Web Server and DAV
    - Added option http_options_no_exec for http virtual path
    - Added support for Content-Security-Policy header
    - Added optional base url to http_xslt function as 3rd parameter
    - Fixed issues mixing valid and invalid MIME types in Accept header
    - Fixed issue writing log on delete/put/patch etc
    - Fixed missing entry for JSON-LD in RDF DET
    - Fixed issue with missing href in PROPPATCH response
    - Fixed issue with base64 decode and trailing zeroes
    - Fixed issue with dead http session

  * Conductor
    - Added simple webservices UI
    - Fixed DAV browser to allow editing for json files
    - Fixed import of all keys in a PEM certificate bundle


## June 7, 2023, v7.2.10:

  * Virtuoso Engine
    - Added checkpoint to end of online backup
    - Added support for IF EXISTS and IF NOT EXISTS in ALTER TABLE
    - Added support for DROP TYPE .... IF EXISTS
    - Added support for bulkloading .jsonld and .jsonld.gz files
    - Added new testsuite entries for recent fixes
    - Fixed missing escape of identifiers in log replay
    - Fixed issue if original dfe not there; see error in optimizer
    - Fixed issue with transaction mutex inside checkpoint
    - Fixed obj2json output should be canonical
    - Fixed issue in short-circuit evaluation (fixes #777)
    - Fixed compare only up to cha key parts (fixes #1117)
    - Fixed missing arguments in table def (fixes #1118)
    - Fixed expand column list during parsing (fixes #1119)
    - Fixed missing check for max number of key parts (fixes #1120)
    - Fixed missing reuse check for dv bin (fixes #1121)
    - Fixed 64bit arith exception (fixes #1122)
    - Fixed 64bit arith overflow (fixes #1123)
    - Fixed do not change col_dtp if already set before (fixes #1124)
    - Fixed save/restore temp refs (fixes #1127)
    - Fixed issue using case/when inside arg simple functions like min/max/count fixes #1128)
    - Fixed handling of aliases in output (fixes #1129)
    - Fixed cannot add non-null column to existing data (fixes #1130)
    - Fixed check number of values vs cols when inserting into view (fixes #1134)
    - Fixed missing check for table in positioned delete (fixes #1135)
    - Fixed non-terminal in union branch is not supported (fixes #1136)
    - Fixed missing check if column exists (fixes #1137)
    - Fixed missing check for non-terminals in WITH DATA (fixes #1138)
    - Fixed wrap unions etc. if non-select for EXISTS ( subq ) (fixes #1139)
    - Fixed first argument of CONTAINS() cannot be star (fixes #1140)
    - Fixed missing variable declaration (fixes #1148)
    - Fixed small memory leaks

  * SPARQL
    - Backported duration and interval fixes to v7 engine (fixes #1147)
    - Added N-QUADS support for SPARQL CRUD using REST (fixes #1142)
    - Added option to limit number of triples in a SPARQL CONSTRUCT query
    - Fixed issue deleting strings with language tag (Fixes #1055)
    - Fixed IRI patterns for SPARQL LOAD SERVICE (fixes #879)
    - Fixed issues with Turtle 1.1 parser (fixes #1059)
    - Fixed rdf_regex is set to work with UTF-8 by default (fixes #705)
    - Fixed suppress errors on loading even for wktLiterals, just like dates/integer types etc.
    - Fixed small SPARQL UI issues

  * Web Server and DAV
    - Added function to return the current HTTP status code 20x/30x/40x etc. or NULL if not set
    - Fixed HTTPS accept timeout
    - Fixed issue with client_protocol mode
    - Fixed issue with TCN
    - Fixed issues with SOAP endpoint

  * Faceted Browser
    - Added support for showing custom datatypes (fixes #963)
    - Fixed issues truncating lists using '>>more>>'
    - Fixed show language when available
    - Fixed issue generating labels in urilbl_ac_init_db
    - Fixed file permissions in VAD packages

  * Conductor
    - Added support for uploading N-QUADS and JSON_LD data via Conductor
    - Fixed file permissions in VAD package

  * JDBC
    - Added small optimization to VirtuosoInputStream (fixes #1150)

## February 27, 2023, v7.2.9:

This update introduces additional GraphQL enhancements for mutations and subscriptions, as documented in the recently published
[GraphQL Introduction](https://community.openlinksw.com/t/introducing-native-graphql-support-in-virtuoso/3378)
and [GraphQL Usage Guide](https://community.openlinksw.com/t/usage-guide-virtuoso-graphql-views-creation-management/3381)
posts, plus enhancements to the existing 
[AnyTime Query](https://community.openlinksw.com/t/technology-update-virtuoso-anytime-query-functionality-for-query-scalability/3388)functionality.

  * Virtuoso Engine
    - Added new JSON-LD parser
    - Added IRI validation bif: functions
    - Added `GIT SHA1` signature to status and log output
    - Added current value of backup prefix to status report
    - Added option for soft `CHECKPOINT`, i.e., only perform a `CHECKPOINT` when the server is in idle state
    - Backported PL debugger enhancements
    - Fixed overflow in msec-based timestamps such as those used for AnyTime queries
    - Fixed PL debugger to produce better debug output for DateTime types
    - Fixed issue with `NULL` in Aggregate groups
    - Fixed issue comparing `NUMERIC` and `DOUBLE`
    - Fixed issue comparing timezoneless and timezoned dates in columnstore index
    - Fixed issue with `GROUP BY` on `FLOAT` values
    - Fixed issue with `revoke all privileges from xx`
    - Fixed issues running testsuite
    - Fixed issues packaging source for distribution

  * SPARQL
    - Added default SPARQL namespace prefixes for ActivityStreams, GoodRelations, OA, and PROV vocabularies
    - Added validation to default-graph parameter
    - Added error logging for bad IRIs
    - Added multi-threaded NQuads dump variant for RDF Quad Store via `RDF_DUMP_NQUADS_MT()`
    - Fixed issue trying to make IRI from incompatible types
    - Fixed issue with `SPARQL LOAD` into an existing graph
    - Fixed issue with casting RDF `datetime` to a string
    - Fixed issue with explicit datatype of literal class; must cast value to a string
    - Fixed issue with label insert when using `with_delete`
    - Fixed issue with literals that have both `LANG` & `TYPE`
    - Fixed issue with load get:accept pragma
    - Fixed issue with permissions; users with `SPARQL_SELECT` role can now use REST interface
    - Fixed issue with serialization when `datatype` is missing, or `lang` is an empty string
    - Fixed issue with unnamed result from view
    - Fixed `DISTINCT` query compilation failure in certain cases where `SELECT` lists contain a reference to a parameter
    - Fixed `--MM-DD` is a valid `gMonthYear`
    - Updated Bootstrap to v5.2.3
    - Updated Bootstrap Icons to v1.10.3

  * Web Server and DAV
    - Added support for Websockets protocol
    - Added JSON-LD support to LDP protocol implementation
    - Added correct HTTP(S) protocol to `%{WSBaseUrl}` variable
    - Added support for https connection timeout
    - Added support for internal CA list in https client
    - Fixed `http_keep_session` and related functions require NN 64-bit id
    - Fixed issue with `.well-known/host-meta` & co for `application/jrd+json` output
    - Fixed issue with `Accept/profile`; should follow RFC media type field rules
    - Fixed issue with `SOCKS4` and `SOCKS5` proxy handler
    - Fixed issue when socket is closed prematurely
    - Fixed issue with LDP sparql queries and rdf views
    - Fixed missing JSON-LD in RDF-related DETs

  * Faceted Browser
    - Fixed format of `INTEGER` and `FLOAT` fields
    - Fixed issue calculating Unicode labels
    - Fixed issue calculating labels for blank nodes
    - Fixed issue with Unicode text in `<span>`
    - Fixed use `schema:description` as alt for `rdfs:comment`
    - Updated JQuery to v3.6.3
    - Updated JQuery UI to v1.13.2

  * Conductor
    - Added Automatic Certificate Management Environment (ACME) client protocol
    - Fixed issue in `VAD` installer when composing the `VAD` package file path
    - Fixed confirmation prompt behavior prior to removing user encryption keys from Virtuoso’s native key store

  * R2RML
    - Fixed issue with rr:template: default is IRI unless column, datatype, or lang are given

  * GraphQL
    - Added graphql-ws protocol
    - Added GraphQL subscriptions support
    - Added implementation-specific directives for SQL/SPARQL optimization hints
    - Added transitivity for smarter and more concise GraphQL-to-RDF-Ontology mapping definitions
    - Added debug options to endpoint
    - Improved mutations support
    - Improved SDL-type schema import
    - Improved error reporting on conflicting schema & mapping/annotation definitions
    - Cleaned up introspection schema



## October 19, 2022, v7.2.8:

This update introduces native GraphQL support, as documented in the recently published
[GraphQL Introduction](https://community.openlinksw.com/t/introducing-native-graphql-support-in-virtuoso/3378) and
[GraphQL Usage Guide](https://community.openlinksw.com/t/usage-guide-virtuoso-graphql-views-creation-management/3381) posts,
plus enhancements to existing [AnyTime Query](https://community.openlinksw.com/t/technology-update-virtuoso-anytime-query-functionality-for-query-scalability/3388) functionality.

  * Virtuoso Engine
    - Added support for `IF EXISTS` and `IF NOT EXISTS` in SQL DDL
    - Added more `EXPORTS` for plugins
    - Added current value of backup prefix to status report
    - Added support for changing the request timeout on `http_client` connections
    - Added support for internal x509 CA list
    - Added support for storing DH param in database
    - Added handle validation to ODBC calls
    - Updated CORS header handling
    - Fixed issue with 64-bit indicators in `sys_stat`
    - Fixed `http_keep_session` and related functions that require 64-bit ID
    - Fixed use separate table to keep HTTP(S) listeners settings
    - Fixed issue with OpenSSL 3.0.x
    - Fixed issue with bad stats pending RPC counter
    - Fixed issues with HTTP renegotiate
    - Fixed compiler warnings and other small cleanups
    - Updated Windows build

  * SPARQL
    - Added GraphQL to SPARQL bridge
    - Added support for HTTP status code `206` to signal partial result
    - Optimized selecting distinct graphs
    - Upgraded SPARQL endpoint to latest version of bootstrap
    - Fixed system crash on 'Generate SPARQL compilation report" (fixes #1068)
    - Fixed crash on vec temp res w/ nulls (fixes #1065)
    - Fixes issue printing datetime boxes
    - Fixed issue with unnamed result col from RDF view
    - Fixed check for non-existing IRI ID
    - Fixed grants for RDF views
    - Fixed issue returning the reserved 0x2000 IRI ID
    - Fixed anonymous sponging is not allowed
    - Fixed timeout validation
    - Fixed error report on unknown help topic
    - Removed cast to string which limited output to 10Mb

  * JDBC, Jena and RDF4j
    - Optimized finalizers
    - Fixed IRI escape
    - Fixed issue with inserting Literal with Language
    - Fixed issue with query param binding
    - Fixed parameter binding issues in RDF4J provider
    - Fixed issues with query param binding

  * Faceted Browser
    - Added support to try loading external images w/ referer policy
    - Added support to show users location on map
    - Fixed rounding lat/long to 4 digits to get true distinction on map
    - Fixed JSON result from FCT service
    - Fixed handling of inline images
    - Fixed IRI search requires 64-bit prefix
    - Fixed issue when an empty IRI is requested
    - Fixed URL rewrite rules
    - Fixed pages should not call batch FT procedures
    - Fixed small PL warnings

  * Conductor
    - Added support for CORS allow headers in Conductor UI
    - Added support for local CA renewal
    - Added support for multi-domain certificates in HTTPS listener UI
    - Fixed HTTPS endpoints
    - Fixed disable VAD re-install if no such file exists
    - Fixed https setup was missing CA x509 verify list option
    - Fixed missing delete from listeners table
    - Fixed update of existing listener did not write changes to table
    - Fixed use common API for adding new listener

  * DAV
    - Fixed issue with delete on LDP resource 
    - Fixed CORS header handling

## May 17, 2022, v7.2.7:

The Virtuoso engine has been enhanced to use 64-bit prefix IDs in `RDF_IRI` which allows for
very large databases such as [Uniprot](https://www.uniprot.org/), which currently contains over
90 billion triples, to be hosted using the Virtuoso Open Source engine.

While new databases automatically make use of this important enhancement, existing databases
will need to be upgraded. 

Please read our [instructions to upgrade from 7.2.x to 7.2.7](README.UPGRADE.md#upgrading-from-vos-72x-to-vos-727)

  * Virtuoso Engine
    - Added optimizations for clearing graph
    - Added optimizations for deleting triples
    - Added support for CONNECT to allow http proxy like squid to tunnel https:// requests
    - Added support for OpenSSL 3.0.x
    - Added support for cast epoch time back to date/datetime
    - Added support for handling X-Forwarded-Proto header from proxy
    - Added support to fine tune size of memory pool used by SPARQL constructs
    - Added support to populate labels in insert for FCT
    - Added optional digest name to aes key
    - Added short name date BIF functions
    - Added xenc_digest and xenc_hmac_digest BIF functions
    - Added unix_timestamp() BIF function
    - Added support for handling HTTP status 307 and 308 in client
    - Fixed Host header should include non-standard port.
    - Fixed SQLConnect handling of empty strings in szDSN and szUID
    - Fixed SSL_renegotiate for OpenSSL 1.1.x
    - Fixed backup_online syntax
    - Fixed calculations from TZ in minutes to +HHMM format
    - Fixed check for https behind proxy for dynamic local
    - Fixed crypto functions error codes
    - Fixed issue calling external proxy with https address
    - Fixed issue executing vec exec expression in WHERE clause
    - Fixed issue generating triples from rdf view to physical store with rdfs:label property
    - Fixed issue sorting NaN values in colstore
    - Fixed issue with X509 CSR generation
    - Fixed issue with backup restore and DDL from plugins
    - Fixed issue with dsa and rsa keys when no cert is attached
    - Fixed issue with registering tables in plugin
    - Fixed issues with x509 extensions
    - Fixed memory leak in colsearch
    - Fixed missing index upgrading older databases
    - Fixed possible box corruption printing a very long literals box
    - Fixed return HTTP 503 even if MaintenancePage cannot be found
    - Fixed serialize of AES IV
    - Fixed subject should be written in UTF8 format
    - Fixed trace to log warnings as WARN_0 instead of ERRS_0
    - Fixed when running as windows service, stderr is an invalid handle
    - Removed redundant checkpoints when creating new database
    - Small cleanups

  * SPARQL
    - Added optimizations for clearing graph
    - Added optimizations for deleting triples
    - Added initial list of languages to decrease risk of deadlocks
    - Added SPARQL_SELECT_FED role
    - Added RDF_DUMP_GRAPH and RDF_DUMP_NQUADS as built-in stored procedures
    - Added missing JSON support function to format output of ASK query
    - Added support to fine tune size of memory pool used by SPARQL constructs
    - Fixed /sparql-auth requests should not be redirect to /sparql
    - Fixed RDF loading re. transaction modes.
    - Fixed SPARQL endpoint description document
    - Fixed functions for making rdf literals must return dc of boxes
    - Fixed incorrect handling of UTF8 characters on SPARQL HTTP endpoint
    - Fixed issue converting RDF metadata from older databases
    - Fixed issue with ANYTIME query timeout values
    - Fixed issue with JSON-LD and JSON-LD (with context) mime types
    - Fixed issue with SPARQL ASK in embedded PL
    - Fixed issue with SPARQL variables containing unicode characters
    - Fixed issue with incomplete RDF box
    - Fixed old proxy and redirect handling in RDF_HTTP_URL_GET
    - Fixed reporting when new graph is created
    - Fixed use a standard namespace URI for special bif: and sql: SPARQL Built-in functions
    - Removed redundant checkpoints when creating new database
    - Small cleanups

  * JDBC, Jena and RDF4j
    - Added optimizations for bulk deleting triples
    - Added support for all JDBC Transaction Isolation levels
    - Added new class VirtStreamRDF for support stream uploading to Virtuoso
    - Fixed issue with closing/leaking JDBC statements
    - Fixed issue with exceptions
    - Fixed issue using batchSize
    - Fixed SQLException handler for better conversion to JenaException

    - Small cleanups

  * Faceted Browser
    - Added check if automated label fill is enabled
    - Added some nofollow and noindex hints for bots
    - Added support to use built-in rdf_label and don't cache the object value twice
    - Fixed UTF-8 encoding issues
    - Fixed XSS issue
    - Fixed bad url encoding
    - Fixed caching query via plink
    - Fixed decoding of percent-encoded URLs when used as labels
    - Fixed detection of label language
    - Fixed do not make default http links
    - Fixed do not remove user defined graphs
    - Fixed efficiency of label language lookup
    - Fixed endpoint creation
    - Fixed issue with bnodes
    - Fixed issue with sid
    - Fixed issue with sponge link in header
    - Fixed make ifps secure
    - Fixed missing graph group
    - Fixed only make link when protocol scheme is safe (http, https, ftp)
    - Fixed order labels by accept-language
    - Fixed return 404 if usage.vsp is called with bad url
    - Fixed several issues in About: block
    - Fixed usage.vsp for safe links
    - Fixed whitespace in Link: header
    - Updated S ranking algorithm

  * Conductor
    - Added faster check for version of installed VAD package
    - Added drop statement and better reporting (ala-isql)
    - Added fingerprint info for system root key
    - Added git hash to the build info
    - Added warning to modifying registry by hand
    - Fixed dependency check on ODS
    - Fixed ensure DB qualifier for conductor
    - Fixed fully qualified view name and use DB qual for all conductor sql
    - Fixed import of user's key
    - Fixed installation of VADs can only be performed by dba account
    - Fixed issue with encoding
    - Fixed issue with non-dba user login causing inf redirects
    - Fixed missing check for ODS Briefcase
    - Fixed LDP metadata
    - Fixed the the rr:graph was not taken from RML doc - UI changes
    - Fixed UI form related to importing RDF files
    - Fixed UI form related to RDF push subscriptions
    - Fixed url encoding

  * DAV
    - Added helper function for fixing DAV COL_FULL_PATH
    - Fixed encoding-type for text/* files
    - Fixed handling of content type
    - Fixed issue removing properties
    - Fixed LDP metadata
    - Fixed unhandled error when COL_FULL_PATH is NULL
    - Removed redundand join with all graphs

  * GEO
    - Added GEOS-isValid BIF

  * R2RML
    - Fixed handling tableName attribute as per spec
    - Fixed rr:graph was not taken from RML doc

## June 22, 2021, v7.2.6:

  * Virtuoso Engine
    - Added support for macOS Big Sur (11.x) on Intel (x86_64) and Apple Silicon (arm64 or M1)
    - Added support for Linux on arm64 such as Raspberry Pi
    - Added support for OpenSSL 1.1.1
    - Added support for Strict-Transport-Security header
    - Added check to make sure RPNG is properly seeded
    - Added support for Forward Secrecy using DH and ECDH
    - Added support for rwlock in dict
    - Added support for latest iODBC DM Unicode fixes
    - Added support for unfoldable internal functions in execution plan
    - Fixed default cipher list
    - Fixed set default protocol to TLSv1.2 or newer when possible
    - Fixed issue setting cipher list on https ctx
    - Fixed issues ordering NaN values
    - Fixed issue with atomic transactions
    - Fixed issue reading large blobs
    - Fixed small memory leaks
    - Fixed small portability issues
    - Fixed dependency on netstat during building and testing

  * SPARQL
    - Added initial support for GeoSPARQL functions
    - Added new bootstrap 4 based /sparql (X)HTML endpoint
    - Added support for Content-Disposition header hint for browsers
    - Added flag to control inference optimizations by G
    - Added support for property paths in federated SPARQL queries
    - Fixed namespace check for bif: and sql: and issues with system functions
    - Fixed issue with JSON-LD and JSON-LD (with context) mime types
    - Fixed output formats to use UTF-8 and HTML5 or XHTML5
    - Fixed splitting on '/#:' produces better results for unnamed prefixes

  * JDBC Driver
    - Added support for JDBC 4.3
    - Moved SSL connectivity into regular jdbc drivers
    - Fixed issue with closing stmt handle in PreparedStatement
    - Fixed JDBC RPC login options
    - Fixed issue with POINTZ
    - Fixed constructions using new Long/Byte/Short/Character
    - Fixed issue with finalizers
    - Fixed issue running jdbc testsuite
    - Removed support for deprecated versions of JDKs 1.1, 1.2, 1.3, 1.4 and 1.5

  * Faceted Browser
    - Added FCT Configuration page in Conductor
    - Added specific Map view options using dedicated graph
    - Added configuration option to control browser cache
    - Added small inference rule for link-out icons
    - Added support for schema.org latitude/longitude in factet inference
    - Added new setting to treat narrow string boxes as UTF-8 encoded
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
    - Fixed reporting proper datatype of object rather than box type

  * Conductor
    - Added UI optimizations
    - Added option to view CalDAV and CardDAV resources
    - Disabled triggers generation for RDF view referencing SQL views
    - Fixed issue creating LDP collection data
    - Fixed issue creating user's IRIs
    - Fixed issue in RDF console
    - Fixed issues editing soap services
    - Fixed login when conductor is behind a proxy
    - Fixed small build issues
    - Moved binsrc/yacutia binsrc/conductor

  * DAV
    - Added new optimizations for WebDAV
    - Added support to move lost collections to '/DAV/.lost+found/' collection
    - Added triggers to check the collection hierarchy before updates
    - Added performance improvements for some often used functions
    - Added additional checks for some API calls
    - Updated triggers and procedures to use the new column COL_FULL_PATH
    - Fixed issue in conductor showing folder content after rename.
    - Fixed issue with ID of DET collections and optimize DAV_SEARCH_ID
    - Fixed issues reported by the Litmus DAV testsuite for COPY and MOVE
    - Fixed issues with LDP, PROPFIND, PATCH
    - Fixed issues with HostFs DET actions
    - Fixed issue with SSL HTTP authentication
    - Fixed issue with LDP POST command
    - Fixed LDP folder content return (by GET)

  * GEO
    - Added new plugins proj4, geos and shapefileio for GeoSPARQL
    - Added check if proj data has been loaded
    - Fixed issue in error handling
    - Fixed handling of GEO_NULL_SHAPE
    - Fixed bif:st_intersects
    - Fixed issue with empty shape
    - Fixed handling empty and invalid geometries
    - Fixed portability issues

  * ODS
    - Fixed issue login into ODS
    - Fixed OAUTH token

  * R2RML
    - Fixed support for rr:datatype and rr:language


## August 15, 2018, v7.2.5

  * Virtuoso Engine
    - Added support for `application/n-triples` mime type
    - Added support for modifying size of SQL compiler cache
    - Added better version checking for OpenSSL to configure
    - Added support for timeout on socket connect
    - Added new debug code to audit SPARQL/SQL errors
    - Added new code for `MALLOC_DEBUG`
    - Added support for LDAPS
    - Added support for TLSext Server Name Indication to `http_client`
    - Remove TLSv1 protocol from default protocol list
    - Fixed initial `DB.DBA.RDF_DEFAULT_USER_PERMS_SET` for user `nobody` so
      `/sparql` endpoint can query all graphs without any performance penalty
    - Fixed scheduler so errors will be emailed every time the event fails
    - Fixed issue replaying table rename due to dereference of `NULL` result
    - Fixed issue returning correct user after TLS login
    - Fixed issues with HTTP `PATCH` command changing resource permissions
    - Fixed check for infinite loop in SQL compiler
    - Fixed XMLA service to select `TIMESTAMP`, `XML_ENTITY`, `IRI_ID` columns
    - Fixed issue with shcompo cache size
    - Fixed memory leaks
    - Fixed portability issues and compiler warnings
    - Fixed issues building Windows binaries using VS2017

  * SPARQL
    - Added new option `Explain` to `/sparql` endpoint
    - Added new help page for RDF views to `/sparql` endpoint
    - Fixed initial fill of language and datatype caches after server restart
    - Fixed SPARQL `DELETE` for quads which failed on booleans and other 
      inlined RDF boxes
    - Fixed SPARQL 1.1 `SUBSTR()`
    - Fixed issues with `PATCH` not returning an error after a SPARQL error
    - Fixed `SPARQL_CONSTRUCT_ACC` could get fixed-value variables referred 
      to in `stats` argument
    - Fixed Turtle 1.1 permits multiple semicolons without predicate-object 
      pairs between them
    - Fixed handling for timezone date values from SPARQL queries
    - Fixed readability and indentation of `EXPLAIN` output
    - Fixed issue encoding urls in SPARQL-FED
    - Fixed `st_contains` and other geo predicates
    - Fixed issue with `CAST NUMERIC TO BOOL`
    - Fixed issues with Turtle and JSON;LD_CTX

  * Jena & Sesame
    - Added method to Sesame provider to query across all RDF graphs in 
      Quad Store
    - Added `set/getIsolationLevel` to `VirtDataset`
    - Update using of DB proc `rdf_insert_triple_c()`
    - Fixed `baseURI` parameter not handled properly by RDF4J provider
    - Fixed issue with Jena object values that are URLs
    - Fixed providers Jena/RDF4J `set/getNamespaces` in global cache instead 
      of connection cache
    - Fixed `xsd:boolean` literals returned as `xsd:string` literals
    - Fixed `VirtDataset` class to properly handle transaction

  * JDBC Driver
    - Added support for concurency mode `CONCUR_VALUES`
    - Added support for SSL truststore
    - Fixed binding/conversion of Unicode characters
    - Fixed handling of SPARQL negative dates
    - Fixed Sql Workbench/J csv file import to Virtuoso failure on empty 
      numeric fields
    - Fixed exception handling

  * ADO.NET
    - Fixed support for SPARQL Negative Dates, Concurrency modes, Connection 
      option `Log_enable`
    - Fixed compilation warnings and errors on Mono and .NET versions on Windows
    - Fixed error in `CompareTo()` methods
    - Fixed issue ADO.NET for `DateTime` types and TZ

  * Faceted Browser
    - Fixed incorrect UTF-8 character IRI handling in Namespaces

  * Conductor
    - Added option to delete locked files by admin users
    - Added support for JSON and JSON-LD in rewrite rules for SPARQL query output
    - Added support for importing PEM and DER formats
    - Updated Conductor UI to support new redirection options
    - Moved *OAuth Service Binding* to *Web Services*
    - Optimized handling of vspx session expiration
    - Fixed issue creating new user accounts with Conductor using user with dba 
      and administrator roles
    - Fixed a missing CA chain does not mean `.p12` file is bad
    - Fixed issue with *Next* time in Scheduler
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
    - Fixed issues with macOS WebDAV mapping
    - Fixed issues with WebDAV browser and folder selection
    - Fixed issue deleting Smart folders
    - Fixed issue with permissions for `PUT` command
    - Fixed bug with `PROPFIND` and bad XML (without correct namespace) as body
    - Fixed issue with DAV authentication
    - Fixed issues with set/update LDP related data
    - Fixed response code to `204` for `PATCH` command
    - Fixed return `406` if no matching `Accept` header found
    - Fixed issue retrieving user's profile data with RDFData DET

  * DBpedia
    - Added LODmilla browser


## April 25, 2016, v7.2.4

  * Virtuoso Engine
    - Added "obvious" index choice
    - Added new bif `http_redirect_from` for getting initial path from 
      internal redirect
    - Fixed ODBC issue with `SQL_C_LONG` bound to an `int32` instead of 
      an `int64/long`
    - Fixed hang as page was not left if `geo_pred` signal an error
    - Fixed check if geo pred gets right arguments to prevent crash
    - Fixed portability issue on Windows
    - Fixed issue with cost based optimizer for `isiri_id`
    - Fixed no change from chash to pageable if `enable_chash_gb = 2`
    - Disable AIO for this release of virtuoso

  * SPARQL
    - Added missing grants to `SPARQL_UPDATE`
    - Added optimizations of paths with complementary and/or repeating 
      paths
    - Added min/max for iri id
    - Added support for `<script>...</script>` inlining of RDF data in 
      HTML output
    - Added support for CSV in RFC4180 format
    - Added support for skipping UTF-8 BOM marks on Turtle and JSON lexers
    - Added support for service invocation of bigdata running in triples 
      and introducing language exceptions
    - Added new debug option to `/sparql` page
    - Fixed issue with `:` in blank node labels
    - Fixed N-Quads do not permit `%NN` in blank node labels
    - Fixed issues with property paths like `<p>|!<p>`
    - Fixed issue when `SERVICE` clause does not return real vars, only 
      `?stubvarXX`
    - Fixed issue with unused default graph
    - Fixed issue with `SPARQL SELECT COUNT(DISTINCT *) { ... }`
    - Fixed SPARQL-BI syntax for `HAVING`
    - Fixed issue with duplicate triples in microdata
    - Fixed handling of strings containing serialized XML
    - Fixed issue with BOOLEAN in SPARQL/XML results

  * Jena & Sesame
    - Added Sesame 4 provider
    - Added Jena 3 provider
    - Added support for Sesame 2.8.x
    - Added Jena example for use Inference and Ontology Model with Jena 
      provider
    - Fixed `Node2Str` for Literals to more properly handle Literals 
      with Lang
    - Fixed issue with `openrdf-workbench` application
    - Fixed Testsuites
    - Fixed Sesame 2 test connection string
    - Fixed `PreparedStatement` with params binding for SPARQL queries 
      with parameters instead of substitution parameter values to query
    - Updated testsuites

  * JDBC Driver
    - Added support for building JDK 1.8 / JDBC 4.2
    - Added support for `Connection.setCatalog()`
    - Fixed conversion of broken unicode strings
    - Fixed variable initialization
    - Fixed `VirtuosoDataSource` methods `setLog_Enable()`/`getLog_Enable()` 
      to properly work with Spring framework
    - Fixed JDBC driver to remove finalizers

  * Faceted Browser
    - Added link-out icons
    - Added more link-out relations
    - Fixed content negotiation
    - Fixed default output is XML
    - Fixed facet search service
    - Fixed issue with CSS
    - Fixed labels
    - Fixed missing alias in fct svc
    - Fixed missing grant
    - Fixed `og:image` added to list
    - Fixed possible change of displayed resources post-sponge
    - Fixed prefixes
    - Fixed space encoding in IRI
    - Fixed splitting UTF-8 strings can produce bad encoded strings
    - Fixed support for images
    - Fixed svc search to keep address

  * Conductor
    - Added validation for sequence number value
    - Added start/expiry date of CA
    - Added new option to disable scheduled job
    - Synced Conductor WebDAV implementation with Briefcase
    - Fixed set specific Sponger pragmas on `text/html`
    - Fixed checkpoint after RDF View generation
    - Fixed use of transactional mode
    - Fixed issue with LDAP server
    - Fixed labels

  * DAV
    - Small optimization for update triggers of `WS.WS.SYS_DAV_RES`
    - Fixed set specific sponger pragmas on `text/html`
    - Fixed issue uploading Turtle files containing special symbols

  * DBpedia
    - Implemented new fluid skin design for DBpedia `/page` based on 
      the Bootstrap Framework
    - Updated DBpedia VAD for UTF-8 based URIs for International Chapters
    - Updated prefixes
    - Added references to license
    - Fixed show language with label, abstract, comment
    - Fixed the `http://mementoarchive.lanl.gov` link


## December 09, 2015, v7.2.2

  * Virtuoso Engine
    - Added support for reading bzip2 compressed files
    - Added support for reading xz/lzma compressed files
    - Added optimization for `date`/`datetime`/`time` escapes
    - Fixed use vfork if working properly to reduce memory footprint 
      on exec
    - Fixed issue with `SQL_TIMEZONELESS_DATETIMES`
    - Fixed issue with uninitialized data in `TIME` string
    - Fixed issue with checkpoint recovery
    - Fixed issue with freeing checkpoint remap col pages
    - Fixed issue with row locks
    - Fixed issue with sampling
    - Fixed issue with outer-join plan
    - Fixed `xmlliteral` should be serialized as UTF-8
    - Fixed `enable_joins_only=1` hint to cost based optimizer
    - Fixed merge transaction log
    - Fixed issues with extent map
    - Fixed `itc_ranges` can be uninitialized when scanning 
      updated/deleted pages
    - Fixed issue with cascaded delete
    - Fixed allow identity to start with `0`
    - Fixed memory leaks
    - Updated debian packaging
    - Updated testsuite
    - Updated documentation

  * SPARQL
    - Added batch validation of JSO instances and new mode 3 for 
      `RDF_AUDIT_METADATA()`
    - Added new JSO loader with `bif_jso_validate_and_pin_batch`
    - Added new pretty-printed HTML tabular output for SPARQL `SELECT` 
      in `/sparql` page
    - Added support for bulkloading `.gz`, `.xz`, and `.bz2` files
    - Fixed recovery of `DefaultQuadStorage`, etc., in 
      `DB.DBA.RDF_AUDIT_METADATA()`
    - Fixed `EWKT` reader to be case-insensitive according to 
      paragraph 7.2.1. of OGC 06-103r4
    - Fixed issue when `nil <p> <o>` triple pattern is used
    - Fixed handling of bad `IRI_IDs` in `DB.DBA.RDF_GAPH_SECURITY_AUDIT()`
    - Fixed output of `@type` in JSON-LD
    - Fixed nice microdata
    - Fixed issues with `gYear`, `gMonth`, etc. in `json`/`csv`/`sparql` 
      output formats
    - Fixed issues with const in `DISTINCT`
    - Fixed issue with recovery for property paths with `*` on `SERVICES`
    - Fixed check to prevent wide insert into `O` column
    - Fixed issue in `RDF_LONG_TO_TTL` with typed RDF literals
    - Fixed for vectorization-related error on SPARQL queries with `RDF_GRAB`
    - Fixed handling of weird blank node labels like `_:2`
    - Fixed issue with unique keys
    - Fixed size of rdf lang cache
    - Fixed codegen for `IN` operator when left hand is column and right 
      hand contains constants
    - Fixed crash when blank nodes are used in data rows of `VALUES`

  * Jena & Sesame
    - Update Jena provider to configure conversion of Jena BNodes to 
      Virtuoso BNodes
    - Fixed `log_enable` support
    - Fixed issue with literals that have both Language and Datatype tags

  * JDBC Driver
    - Added missing server-side setting
    - Added initial testsuite for handling date values in JDBC provider
    - Fixed issues decoding RdfBox with Date object and timezoneless modes
    - Fixed return SPARQL `Time GMT0` with `Z` suffix (`13:24:00.000Z` 
      instead of `13:24:00.000-00:00`)
    - Fixed return SPARQL `DateTime GMT0` with `Z` suffix 
      (`1999-05-31T13:24:00Z` instead of `1999-05-31T13:24:00-00:00`)
    - Fixed `log_enable` support
    - Fixed Datasources to support both JNDI attribute names `charset` 
      and `charSet`
    - Fixed `UTF8` to `String` conversion to return `?` for bad character 
      instead of throwing Exception.
    - Fixed JDBC testsuite

  * .NET Adapter
    - Fixed build rules for Virtuoso .NET Adapter
    - Fixed ADO.NET prefetch size from `20` to `100`
    - Fixed `Int32` overflow in `VirtuosoDataReader.GetValues`
    - Fixed issue with implementation of `Cancel`
    - Fixed `NullPointer` exception in `ManagedCommand`, when Connection 
      is closed after exceptions

  * Faceted Browser
    - Added small query optimization
    - Added support for auto sponge
    - Added support for emitting Microdata instead of RDFa
    - Added missing grants
    - Added iframe opt
    - Fixed handling of `nodeID`, null graphs, `foaf:depiction`, and iframe
    - Fixed describe mode from LOD to CBD
    - Fixed serialization issue
    - Fixed namespace prefixes
    - Fixed error on bad IRIs
    - Fixed error on subseq when uri is wide string
    - Fixed issue passing literal as reference parameter in `/fct`
    - Fixed show distinct count on list-count view
    - Fixed issue with xtree over null
    - Fixed labels

  * Conductor
    - Added export function for key storage
    - Added filters to IMAP DET folders
    - Added support for FTP DET
    - Added support for move and copy commands on some DETs
    - Added support for new RDF params in WebDAV browser
    - Added support for pattern search and edit options to 
      namespace prefixes
    - Added support for setting file expiration for WebDAV/Briefcase
    - Fixed IMAP DET filter page
    - Fixed Turtle editor text revision
    - Fixes for site-copy robot

  * DAV
    - Added DETs move/copy commands
    - Added IMAP DET filters to WebDAV browser
    - Added `last-modified` for dav res
    - Added optimizations using RDF params for DET folders
    - Added scheduler procedure for expired items
    - Added support for FTP DET
    - Fixed issues creating/updating LDP containers
    - Fixed bug updating existing file with only read permission on 
      parent dir
    - Fixed calculation of MD5 value for resource content
    - Fixed issue with `POST` of SPARQL query with 
      `"Content-Type: application/sparql-query"`
    - Fixed issues with DAV permissions
    - Fixed resource size value for some DAV operations
    - Fixed resource update API call and sync with HTTP `PUT`
    - Fixed setting DET RDF params
    - Fixed timezone bug with S3 DET


## June 24, 2015, v7.2.1

  * Virtuoso Engine
    - Added support for `datetime without timezone`
    - Added new implementation of `xsd:boolean` logic
    - Added new text index functions and aggregates
    - Added better handling of HTTP status codes on SPARQL graph 
      protocol endpoint
    - Added new cache for compiled regular expressions
    - Added support for expression in `TOP`/`SKIP`
    - Fixed cost based optimizer
    - Fixed codegen for `((A is NULL) or (A=B))` and similar in 
      `LEFT OUTER JOIN`
    - Fixed issue with conditional expression
    - Fixed issue with SSL handshake in non-blocking mode
    - Fixed issue with `anytime` and `group by`
    - Fixed issue with multistate `order by`
    - Fixed issues with stability
    - Fixed CORS headers
    - Fixed memory leaks
    - Updated documentation

  * SPARQL
    - Added support for SPARQL `GROUPING SETS`
    - Added support for SPARQL 1.1 `EBV` (Efficient Boolean Value)
    - Added support for `define input:with-fallback-graph_uri`
    - Added support for `define input:target-fallback-graph-uri`
    - Fixed SPARQL queries with sub-selects
    - Fixed SPARQL `abs()` should not convert result to `integer`
    - Fixed `UNDEF` is now a valid generic subexpression in SPARQL
    - Fixed SQL codegen for `SPARQL SELECT ... count(*) ...`
    - Fixed SPARQL issue with `UNION` with multiple `BINDS`
    - Fixed handling of `*` in `COUNT(*)` and `COUNT(DISTINCT *)`
    - Fixed handling of "plain box" constants
    - Fixed handling of optional minus sign on SPARQL values
    - Fixed SPARQL/Update target to ignore default graph from context 
      but set from `USING`
    - Fixed issue inserting triple with XML type
    - Fixed issue with bad filter reduced to `NULL`
    - Fixed return `\uNNNN\uNNNN` instead of `\UNNNNNNNN` in JSON strings
    - Fixed issue with `xsd:dayTimeDuration` in codegen
    - Fixed issue multiple `OPTIONALs` for a variable or nullable 
      subq + `optional`

  * Jena & Sesame
    - Added support for using `rdf_insert_triple_c()` to insert BNode data
    - Added support for returning `xsd:boolean` as `true`/`false` rather 
      than `1`/`0`
    - Added support for `maxQueryTimeout` in Sesame2 provider
    - Fixed storing blank nodes as URIs
    - Fixed issue with insert data via Jena provider in XA transaction
    - Fixed issue closing XA connection
    - Fixed issue with `DELETE` query
    - Fixed issue with blank nodes in `DELETE` constructor
    - Fixed issues with `Date`/`Time`/`DateTime` literals
    - Fixed corrupted literals with datatypes using Jena provider
    - Removed deprecated class reference

  * JDBC Driver
    - Added new methods `setLogFileName` and `getLogFileName`
    - Added new attribute `logFileName` to `VirtuosoDataSources` for 
      logging support
    - Fixed issues logging JDBC XA operations and JDBC RPC calls
    - Fixed JDBC driver did not use `SQL_TXN_ISOLATION` setting from 
      init handshake
    - Fixed throw exception when reading polygon geometry by JDBC
    - Fixed issues with `Date`, `Time`, and `DateTime`
    - Fixed hang on `PreparedStatement` when using `setFetchSize()` method

  * Faceted Browser
    - Added support for emitting Microdata instead of RDFa
    - Added query optimizations
    - Added footer icons to `/describe` page
    - Fixed support for graph permission checks
    - Fixed user switch
    - Fixed serialization issue
    - Fixed HTML content detection
    - Fixed labels
    - Fixed bad font on Chrome

  * Conductor and DAV
    - Added support for VAD dependency tree
    - Added support for default vdirs when creating new listeners
    - Added support for private RDF graphs
    - Added support for LDP in DAV API
    - Added option to create shared folder if does not exist
    - Added option to enable/disable DET graphs binding
    - Added option to set content length threshold for async spongeing
    - Added folder option related to `.TTL` redirection
    - Added functions to edit turtle files
    - Added popup dialog to search for unknown prefixes
    - Added registry option to add missing prefixes for `.TTL` files
    - Fixed DETs to work with new private graphs
    - Fixed conflict using graph for share and LDP in WAC delete queries
    - Fixed hrefs for resource paths in DAV browser
    - Fixed issue deleting files from DAV
    - Fixed issues with subfolders of DETs type `ResFilter` and `CatFilter`
    - Fixed labels

## February 17, 2015, v7.2.0

  * Virtuoso Engine
    - Added new threadsafe / reentrant SQL parser
    - Added support for using TLSF library for page-maps
    - Added support for setting SSL Protocols and Ciphers
    - Added support for new Unicode-3 based collations
    - Added support for custom `HTTPLogFormat`
    - Added support for quality factor in `Accept` headers
    - Added rate limiter for bad connections
    - Added ODBC 3.x alias for `current_date`, `current_time`, and 
      `current_timestamp`
    - Improved cost based optimizer
    - Improved LDP support
    - Improved XPER support
    - Improved CSV support
    - Fixed handling of regexp cache size and `pcre_match` depth limit
    - Fixed handling of multibyte strings
    - Fixed handling of `nvarchar` data with zeroes in the middle
    - Fixed handling of values in 10 day gap between Julian and Gregorian dates
    - Fixed if expr in rdf `o` range condition, set super so they get placed once
    - Fixed issue possibly reading freed block
    - Fixed issue with TZ field without separator
    - Fixed issue with duplicate hashes
    - Fixed issue with invariant preds
    - Fixed issue with non chash distinct gby with nulls
    - Fixed issue with user aggregates and chash flush
    - Fixed issues with `outer join`, `order by`, and `group by`
    - Fixed sending IRI IDs to remotes when using `WHERE 0`
    - Fixed use SHA256 as default for certificate signing
    - Fixed memory leaks and memory fragmentation
    - Fixed SSL read/write error condition
    - Fixed windows build

  * GEO functions
    - Added support for SPARQL `INSERT` with GEO literals
    - Added support for upcoming proj4 plugin
    - Fixed issue with rdf box with a geometry rdf type and 
      non-geometry content
    - Fixed calculation of serialization lengths for geo boxes
    - Fixed compilation of a query with `bif:st_intersects` inside 
      `SERVICE {}`
    - Fixed serialization of geo boxes
    - Fixed `intersect` to work with other geo shapes

  * SPARQL
    - Added new SPARQL pragma: `define sql:comment 0/1`
    - Added indicator when max rows is returned on `/sparql` endpoint
    - Added new role `SPARQL_LOAD_SERVICE_DATA`
    - Added new client callable graph ins/del/replace functions
    - Added support for `__tag` of `UNAME`
    - Added support for multiple SPARQL UPDATE commands
    - Added support for `xsd:gYear` and the like
    - Added support for `CASE x WHEN ...` and `CASE when` in SPARQL
    - Added support for *HTML with nice turtle* output format
    - Added `TransStepMode` option to `virtuoso.ini`
    - Improved handling of `FLOAT` and `DOUBLE` in SPARQL compiler
    - Improved Turtle parser
    - Fixed `SPARQL DELETE DATA` when a complete RDF box w/o `RO_ID` 
      is passed as obj
    - Fixed `URI()` is synonym for `IRI()`
    - Fixed equality of unames and strings, iri strings
    - Fixed issue eliminating empty `{}` in `VALUE` join
    - Fixed issue with R2RML
    - Fixed issue with XMLA
    - Fixed issue with base graph when using `with_delete` in bulkloader
    - Fixed issue with multiple `OPTIONAL`
    - Fixed issue with `sparql ... with delete` on certain datatypes
    - Fixed issue with `varbinary` in rdf views
    - Fixed printing optimized-away data rows of `VALUES` in 
      `sparql_explain()` dump
    - Fixed propagation of limits if `SPART_VARR_EXTERNAL`/`GLOBAL` 
      variables present
    - Fixed regression for SPARQL 1.1 `VALUES` bindings
    - Fixed sort accented letters from `ORDER BY` in alphabetical order
    - Fixed startup speed with many graph group members

  * Jena & Sesame
    - Upgraded to Jena 2.12.0
    - Added support for Bulk Loading
    - Added support for Dataset method using `defaultInsertGraph` 
      and `defaultRemoveGraph`
    - Fixed handling of blank nodes
    - Fixed transaction handling
    - Fixed `NullPointerException` for sparql with `OPTIONAL`
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
    - Fixed issue with rewind on Virtuoso `blob`
    - Fixed issue with batch procedure execution
    - Fixed issue with dates
    - Fixed issue with `SQL_UTF8_EXECS=1`
    - Fixed issue with JDBC testsuite

  * Faceted Browser
    - Added support for graph selection and persist in fct state
    - Added support for link out icons on certain doc and image links
    - Added new description and sponger options as entity link types
    - Added option for JSON output to fct service
    - Added `group by` to speed up `distinct`
    - Added precompiled queries to speed up `usage.vsp`
    - Fixed base uri for crawlers
    - Fixed color scheme
    - Fixed graph perm check
    - Fixed handling of `foaf:depiction`
    - Fixed handling of iframe
    - Fixed issue when lang is missing to fct service
    - Fixed issue with `dateTime`
    - Fixed issue with double-quotes in literals
    - Fixed issue with nodeID
    - Fixed issue with null graphs
    - Fixed labels
    - Fixed links

## February 17, 2014, v7.1.0

  * Engine
    - Enhancements to cost based optimizer
    - Added optimization when splitting on scattered `inserts`
    - Added optimization on fetching col seg
    - Added support for multithreaded sync/flush
    - Added support for ordered `count distinct` and `exact p` stat
    - Added new settings `EnableMonitor`
    - Added BIFs `key_delete_replay()`, `set_by_graph_keywords()`,
      `tweak_by_graph_keywords`, `vec_length()`, `vec_ref()`,
      `x509_verify_array()`, `xenc_x509_cert_verify_array()`
    - Added new functions `bif_list_names()` and `bif_metadata()`
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

  * GEO functions
    - Added initial support for `geoc_epsilon()`, `geometrytype()`,
      `st_affine()` (2D trans only), `st_geometryn()`, `st_get_bounding_box_n()`,
      `st_intersects()`, `st_linestring()`, `st_numgeometries()`,
      `st_transform_by_custom_projection()`, `st_translate()`,
      `st_transscale()`, `st_contains()`, `st_may_contain()`,
      `st_may_intersect()`
    - Added new BIFs for getting `Z` and `M` coords
    - Added support for `<(type,type,...)type::sql:function>` trick
      in order to eliminate conversion of types on function call
    - Optimization in calculation of gcb steps to make number of
      chained blocks close to square root of length of the shape
    - Fixed geo box support for large polygons
    - Fixed `mp_box_copy()` of long shapes
    - Fixed range checks for coordinates
    - Fixed calculation of lat/long ratio for proximity checks
    - Fixed boxes in `geo_deserialize`
    - Fixed check for `NAN` and `INF` in `float` valued geo inx
    - Fixed check for `NULL` arguments
    - Minor fixes to other geo BIFs

  * SPARQL
    - Added initial support for list of quad maps in SPARQL BI
    - Added initial support for vectored iri to id
    - Added initial support for sparql `valid()`
    - Added new codegen for initial fill of RDB2RDF
    - Added new settings `CreateGraphKeywords`, `QueryGraphKeywords`
    - Added new SPARQL triple/group/subquery options
    - Added missing function `rdf_vec_ins_triples`
    - Added support for `application/x-nice-microdata` SPARQL format
    - Added support for buildin inverse functions
    - Added support for geosparql `wkt` type literal as synonym
    - Added support for the `-` operator for datetime data types
    - Fixed issues in handling geo predicates in SPARQL
    - Fixed RDF view to use multiple quad maps
    - Fixed issues with `UNION` and `BREAKUP`
    - Fixed dynamic local for vectored
    - Fixed support for combination of `T_DIRECTION 3` and `T_STEP (var)`
    - Fixed handle `30x` redirects when calling remote endpoint
    - Fixed support for `MALLOC_DEBUG` inside SPARQL compiler
    - Fixed TriG parser

  * Jena & Sesame
    - Improved speed of batch delete
    - Removed unnecessary check that graph exists after remove
    - Removed unnecessary commits
    - Replaced `n.getLiteralValue().toString()` with `n.getLiteralLexicalForm()`

  * JDBC Driver
    - Added statistics for Connection Pool
    - Fixed speed of finalize

  * Conductor and DAV
    - Added trigger for delete temporary graphs used for WebID verification
    - Added new `CONFIGURE` methods to DETs to unify folder creation
    - Added new page for managing CA root certificates
    - Added new pages for graph level security
    - Added verify for WebDAV DET folders
    - Added creation of shared DET folders
    - Fixed creation of ETAGs for DET resources
    - Fixed DAV rewrite issue
    - Fixed dav to use proper escape for graphs when uploading
    - Fixed issue deleting graphs
    - Fixed issue uploading bad `.TTL` files
    - Fixed issue with DAV QoS re-write rule for `text/html`
    - Fixed issue with user `dba` when creating DET folders
    - Fixed normalize paths procedure in WebDAV
    - Fixed reset connection variable before no file error

  * Faceted Browser
    - Added missing grants
    - Added graph param in FCT permalink
    - Changed labels in LD views
    - Changed default sort order to `date (desc)`
    - Copied `virt_rdf_label.sql` locally
    - Fixed escape double quote in literals
    - Fixed FCT datatype links
    - Fixed the curie may contain UTF-8, so mark string accordingly
    - Changed describe mode for PivotViewer link


## August 02, 2013, v7.0.0

  * First official release of Virtuoso Open Source Edition v7.0

  NOTE: At this point in time, the engine is only buildable in 64bit mode


## July 12, 2011, v7.0.0-alpha

  * First release of the experimental v7 branch.

  NOTE: This version is unstable and should not be used for any production
        data. The database format may still change during the next couple
        of cycles and we do not guarantee any upgrading at this point.
