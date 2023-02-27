# Virtuoso Anytime Query Functionality
<small>Copyright &copy; 2022-2023 OpenLink Software</small>

- [Introduction](#introduction)
- [Virtuoso Anytime Query extension for SPARQL](#virtuoso-anytime-query-extension-for-sparql)
    - [Server-side settings](#server-side-settings)
    - [Client-side parameter](#client-side-parameter)
    - [Virtuoso HTTP status codes and response headers](#virtuoso-http-status-codes-and-response-headers)
        - [HTTP status code 200 OK](#http-status-code-200-ok)
        - [HTTP status code 206 Partial](#http-status-code-206-partial)
        - [HTTP status code 400 Bad Request](#http-status-code-400-bad-request)
        - [HTTP status 500 Server Error](#http-status-500-server-error)
        - [HTTP status code 504 Gateway Timeout](#http-status-code-504-gateway-timeout)
- [Virtuoso Anytime Query Functionality & GraphQL Queries](#virtuoso-anytime-query-functionality--graphql-queries)
- [Virtuoso Anytime Query Functionality for ODBC, JDBC, iSQL or Virtuoso PL Clients](#virtuoso-anytime-query-functionality-for-odbc-jdbc-isql-or-virtuoso-pl-clients)
    - [Example using Virtuoso iSQL/PL](#example-using-virtuoso-isqlpl)
    - [Example using SPARQL inside SQL (SPASQL) via iODBC](#example-using-sparql-inside-sql-spasql-via-iodbc)
- [See Also](#see-also)

# Introduction
“`Anytime Query`” is a core feature of Virtuoso that enables it handle challenges inherent in providing a high-performance and accessible interface (public e.g., Web or private e.g., internal intranet) for ad-hoc querying at scale. This extension allows an SPARQL- and HTTP-protocol based application or service to issue queries irrespective of query complexity and/or solution size. Fundamentally, it handles query solution production pipelines that would typically result in no solutions due to exceeding configured DBMS query timeouts and/or solution size limits; in addition, this feature enables the use of LIMIT and OFFSET (typically combined with ORDER BY and/or GROUP BY) to create windows (also known as sliding windows or cursors) to iterate through a complete query solution without being adversely affected by insert or delete operations.

# Virtuoso Anytime Query extension for SPARQL

## Server-side settings
An instance administrator (e.g., a DBA) can impose limits on a Virtuoso SPARQL endpoint, by via the following `virtuoso.ini` file entries:

```ini
[SPARQL]
ResultSetMaxRows      = 60000  ; Limit query results (or solution sizes) to 60000 rows (default is no limit)
MaxQueryExecutionTime = 120    ; Set server-side timeout to 120 seconds (default=0)
ExecutionTimeout      = 30     ; Set client-side timeout to 30 seconds (default=0)
HTTPAnytimeStatus     = 206    ; Preferred HTTP Status code, with the default being 206
```

The `ExecutionTimeout` setting is used by the SPARQL endpoint in the `Execution Timeout` field (converted to milliseconds), which the user can override either via the form or a SPARQL URL parameter (i.e., &timeout).

**NOTE**: If none of these settings are added to the `virtuoso.ini`, there are no constraints set by Virtuoso. However the amount of memory, proxy timeout settings, etc., can still cause SPARQL queries to fail with various HTTP status codes.

## Client-side parameter
HTTP-based client applications such as [cURL](https://en.wikipedia.org/wiki/CURL), [Python](https://en.wikipedia.org/wiki/Python_(programming_language)), [Node.js](https://en.wikipedia.org/wiki/Node.js), [Javascript libraries](https://en.wikipedia.org/wiki/JavaScript), or the Virtuoso SPARQL endpoint itself, can use the `&timeout=30000` parameter of a SPARQL URL to control how long it wants to wait for a result (or query solution) to be produced. Virtuoso's query engine will sanitize the `timeout` parameter ensuring that its between 0 and `MaxQueryExecutionTime` (converted to milliseconds).
 
If a query executes to completion within the configured timeout (which can be unlimited) the HTTP status is set to 200 (OK) and the results will be returned in the requested format.

The following table shows what HTTP status code Virtuoso will return, If either `&timeout` and/or `MaxQueryExecutionTime` are set:
| Timeout | MaxQueryExecutionTime | Description                               | HTTP status on exceeding limit |
| ------: | --------------------: | ----------------------------------------- | --: |
| 0       | 0 seconds             | No limits imposed by the Virtuoso engine  | n/a             |
| 0       | > 0 seconds           | Treat `Anytime Query` timeout as an error | 500 (Server Error)   |
| > 999   | 0 seconds             | Client requests optional timeout          | 206 (Partial Result) |
| > 999   | > 0 seconds           | Mandatory `Anytime Query` timeout         | 206 (Partial Result) |


## Virtuoso HTTP status codes and response headers

The following HTTP status codes and response headers can be returned by the Virtuoso SPARQL endpoint.

**Note**: Headers that start with an `X-` are custom headers that Virtuoso returns.

### HTTP status code 200 (OK)
This HTTP status code is returned if a valid query was executed within the allotted time.

Virtuoso returns the following response headers:
<pre>
Connection: keep-alive
Content-disposition: filename=sparql_2022-10-06_12-00-00Z.html
Content-Encoding: gzip
Content-Type: text/html; charset=UTF-8
Date: Thu, 06 Oct 2022 12:00:00 GMT
Server: Virtuoso/08.03.3326 (Linux) x86_64-generic-linux-glibc212  VDB
Strict-Transport-Security: max-age=15768000
Transfer-Encoding: chunked
Vary: Accept-Encoding
<b>X-SPARQL-default-graph</b>: http://dbpedia.org
</pre>

The response payload is the full result-set (or query solution) returned in the requested format.


### HTTP status code 206 (Partial)
This HTTP status code is returned when the query solution production pipeline exceeded either the current `Anytime Query` timeout setting, or the current `ResultSetMaxRows` limit.

Some internet specifications such as [RFC 2616: Hypertext Transfer Protocol](https://www.rfc-editor.org/rfc/rfc2616) and blogs like [HTTP Status: 206 Partial Content and range requests](https://benramsey.com/blog/2008/05/206-partial-content-and-range-requests) indicate that this status code can only be initiated on the client (request) side.

However [RFC 9110: HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110#section-15.3.7) from June 2022 which supersedes the previous RFC states:

> ... a server might want to send only a subset of the data requested for reasons of its own, 
> such as temporary unavailability, cache efficiency, load balancing, etc. Since a 206 response is 
> self-descriptive, the client can still understand a response that only partially satisfies its range request.

Our testing confirms that all common browsers, javascript frameworks, NodeJS etc. all work fine with HTTP status code 206 in combination with the response headers as well as payload that Virtuoso returns. 

However since we anticipate users might wish to use HTTP status codes 200 or 500 inline with their preferred application's behavior, we've added an INI configuration option, configurable by an instance DBA, along the following lines:

```
[SPARQL]
HTTPAnytimeStatus = 500     ; Default is 206
```

Virtuoso returns the following response headers for a partial result:
<pre>
<b>Accept-Ranges</b>: none
Connection: keep-alive
Content-disposition: filename=sparql_2022-10-06_12-00-00Z.html
Content-Length: 1095
Content-Type: text/html; charset=UTF-8
Date: Thu, 06 Oct 2022 12:00:00 GMT
Server: Virtuoso/08.03.3326 (Linux) x86_64-generic-linux-glibc212  VDB
Strict-Transport-Security: max-age=15768000
<b>X-Exec-DB-Activity</b>: 55.41K rnd  1.383M seq      0 same seg   9.066K same pg  4.708K same par      0 disk      0 spec disk      0B /      0 messages      0 fork
<b>X-Exec-Milliseconds</b>: 2826
<b>X-SPARQL-Anytime</b>: timeout=1000; max_timeout=30000
<b>X-SPARQL-default-graph</b>: http://dbpedia.org
<b>X-SQL-Message</b>: RC...: Returning incomplete results, query interrupted by result timeout.  Activity:  55.41K rnd  1.383M seq      0 same seg   9.066K same pg  4.708K same par      0 disk      0 spec disk      0B /      0 m
<b>X-SQL-State</b>: S1TAT
</pre>

The  `Accept-Ranges` header returns a value of `none` to make sure a client-side application does not attempt to automatically start requesting byte ranges based on the `Content-Length`. 

The `X-SPARQL-Anytime` header returns both the current `timeout` value as well as the `MaxQueryExecutionTime` value both in milliseconds. It can be used by a client-side application to generate a form where the user can change the timeout and resend the request to the SPARQL endpoint using a new value for the `&timeout` parameter.

The `X-SPARQL-default-graph` header returns the SPARQL default graph. 

The `X-Exec-DB-Activity`, `X-Exec-Milliseconds`, `X-SQL-Message` and `X-SQL-State` headers can be used by the DBA or by the OpenLink Support staff to examine some query statistics.

The response payload is the partial result-set returned in the requested format, even if the `HTTPAnytimeStatus` has been changed from `206` to another http status code.


### HTTP status code 400 (Bad Request)
This status code can be returned when the query contains a syntax error.

Virtuoso returns the following response headers:
<pre>
Accept-Ranges: bytes
Connection: keep-alive
Content-Length: 351
Content-Type: text/plain
Date: Thu, 06 Oct 2022 14:06:08 GMT
Server: Virtuoso/08.03.3326 (Linux) x86_64-generic-linux-glibc212  VDB
</pre>

The result payload contains a description of the error which the client side application can log or put in a dialog box for the user, e.g.:

```
Virtuoso 37000 Error SP030: SPARQL compiler, line 5: syntax error at 'string' before '('

SPARQL query:
#output-format:text/html
define sql:signal-unconnected-variables 1
define sql:signal-void-variables 1
define input:default-graph-uri <http://dbpedia.org>
select distinct ?Concept where {[] a ?Concept. filter (string(?Concept) like '%dbpedia%') } LIMIT 100
```


### HTTP status 500 (Server Error)
This status code is be returned when the query hits the `AnyTime Query` timeout, but the client-side specified it did not want to a partial result by setting the `&timeout=0`

Virtuoso returns the following response headers:
<pre>
Accept-Ranges: bytes
Connection: keep-alive
Content-Length: 69
Content-Type: text/plain
Date: Thu, 06 Oct 2022 12:00:00 GMT
Server: Virtuoso/08.03.3326 (Linux) x86_64-generic-linux-glibc212  VDB
</pre>

The result payload contains a description of the error which the client side application can log or put in a dialog box for the user:

```
Virtuoso S1TAT Error Query did not complete due to ANYTIME timeout.
```

### HTTP status code 504 (Gateway Timeout)
This status can be returned by [reverse proxies](https://en.wikipedia.org/wiki/Reverse_proxy) such as [Nginx](https://en.wikipedia.org/wiki/Nginx), [HAProxy](https://en.wikipedia.org/wiki/HAProxy) or [Traefik](https://en.wikipedia.org/wiki/User:Kcmastrpc/Traefik) when the query takes too long to produce results. This can happen when the timeout set by the proxy is smaller than the `AnyTime Query` timeout.

# Virtuoso Anytime Query Functionality & GraphQL Queries

The Virtuoso GraphQL endpoint uses the same `MaxQueryExecutionTime`, `HTTPAnytimeStatus` and `ResultSetMaxRows` settings as the SPARQL endpoint. 

It also uses similar HTTP response headers as the ones described for the SPARQL endpoint.


# Virtuoso Anytime Query Functionality for ODBC, JDBC, iSQL or Virtuoso PL Clients
Virtuoso also allows applications written in ODBC, JDBC, iSQL, Virtuoso stored procedures (PL) etc., to use the `Anytime Timeout` extension for both SQL and SPARQL queries.

Since these types of connections are not anonymous like the SPARQL or GraphQL endpoint, there currently is no maximum timeout. 

## Example using Virtuoso iSQL/PL
Running the following example on dbpedia.org using the Virtuoso isql tool:

```SQL
$ isql 1111
OpenLink Virtuoso Interactive SQL (Virtuoso)
Version 08.03.3318 as of Aug 13 2020
Type HELP; for help and EXIT; to exit.

SQL> set RESULT_TIMEOUT = 1000;     -- timeout in milliseconds

SQL> SPARQL SELECT SAMPLE(?s) AS ?sample COUNT(*) AS ?count ?o 
FROM <http://dbpedia.org>
WHERE { ?s a ?o. }
ORDER BY DESC 2 LIMIT 10;

sample                                                          count  o
LONG VARCHAR                                                    LONG   LONG VARCHAR
_______________________________________________________________________________

http://dbpedia.org/resource/1979_Gulf_Cup_of_Nations            62342  http://dbpedia.org/ontology/CareerStation
http://dbpedia.org/resource/Category:Ancyloceratoidea           48506  http://www.w3.org/2004/02/skos/core#Concept
http://dbpedia.org/resource/1969_in_baseball                    26261  http://www.w3.org/2002/07/owl#Thing
http://dbpedia.org/resource/501(c)(3)                           10959  http://dbpedia.org/ontology/PersonFunction
http://dbpedia.org/resource/2021_in_spaceflight                 9527   http://dbpedia.org/ontology/TimePeriod
http://dbpedia.org/resource/1969_uprising_in_East_Pakistan      8940   http://dbpedia.org/ontology/Organisation
http://dbpedia.org/resource/2020–21_Glasgow_Warriors_season     8727   http://dbpedia.org/ontology/Agent
http://dbpedia.org/resource/2020–21_Glasgow_Warriors_season     8706   http://www.ontologydesignpatterns.org/ont/dul/DUL.owl#Agent
http://dbpedia.org/resource/2020–21_Glasgow_Warriors_season     8706   http://www.wikidata.org/entity/Q24229398
http://dbpedia.org/resource/2020–21_Glasgow_Warriors_season     8700   http://schema.org/Organization

*** Error S1TAT: VD [Virtuoso Server]RC...: Returning incomplete results, query interrupted by result timeout.  Activity:    561K rnd  561.3K seq      0 same seg   172.5K same pg   1.29K same par      0 disk      0 spec disk      0B /      0 m
in lines 3-6 of Top-Level:
#line 3 "(console)"
SPARQL SELECT SAMPLE(?s) AS ?sample COUNT(*) AS ?count ?o  FROM <http://dbpedia.org> WHERE { ?s a ?o. } ORDER BY DESC 2 LIMIT 10

SQL> set RESULT_TIMEOUT = 0;
```

This will fetch a number and display a number of rows, until the timeout exceeds and the next fetch results in a SQL state `S1TAT`.

```
*** Error S1TAT: VD [Virtuoso Server]RC...: Returning incomplete results, query interrupted by result timeout.  Activity:  616.6K rnd  584.1K seq      0 same seg   184.6K same pg  9.519K same par      0 disk      0 spec disk      0B /      0 m
at line 6 of Top-Level:
SPARQL SELECT SAMPLE(?s) AS ?sample COUNT(*) AS ?count ?o  FROM <http://dbpedia.org> WHERE { ?s a ?o. } ORDER BY DESC 2
```

This SQL state can be checked by simple application logic using a [WHENEVER statement](https://docs.openlinksw.com/virtuoso/wheneverstmt/) in Virtuoso PL.

## Example using SPARQL inside SQL (SPASQL) via iODBC
Using the iODBC iodbctest tool to run the same test:

```SQL
$ iodbctest DSN=dbpedia
iODBC Demonstration program
This program shows an interactive SQL processor
Driver Manager: 03.52.1216.0712
Driver: 08.03.3314 OpenLink Virtuoso ODBC Driver (virtodbc.so)

SQL> set RESULT_TIMEOUT = 1000
Statement executed. 0 rows affected.

SQL> SPARQL SELECT SAMPLE(?s) AS ?sample COUNT(*) AS ?count ?o FROM <http://dbpedia.org> WHERE { ?s a ?o. } ORDER BY DESC 2 limit 10

sample                        |count                         |o
------------------------------+------------------------------+------------------------------
http://dbpedia.org/resource/19|63307                         |http://dbpedia.org/ontology/Ca
http://dbpedia.org/resource/Ca|48506                         |http://www.w3.org/2004/02/skos
http://dbpedia.org/resource/19|26261                         |http://www.w3.org/2002/07/owl#
http://dbpedia.org/resource/50|11087                         |http://dbpedia.org/ontology/Pe
http://dbpedia.org/resource/20|9686                          |http://dbpedia.org/ontology/Ti
http://dbpedia.org/resource/19|8940                          |http://dbpedia.org/ontology/Or
http://dbpedia.org/resource/20|8727                          |http://dbpedia.org/ontology/Ag
http://dbpedia.org/resource/20|8706                          |http://www.ontologydesignpatte
http://dbpedia.org/resource/20|8706                          |http://www.wikidata.org/entity
http://dbpedia.org/resource/20|8700                          |http://schema.org/Organization
1: Fetch = [OpenLink][Virtuoso ODBC Driver][Virtuoso Server]RC...: Returning incomplete results, query interrupted by result timeout.  Activity:    562K rnd  562.3K seq      0 same seg   173.5K same pg  1.293K same par      0 disk      0 spec disk      0B /      0 m (-1) SQLSTATE=S1TAT

 result set 1 returned 10 rows.

SQL> set RESULT_TIMEOUT = 0
Statement executed. 0 rows affected.
```


 If iODBC tracing is enabled, we can see the following in the iODBC trace log:

```text
[000024.502533]
iodbctest       7FA9E8E3A700 ENTER SQLFetchScroll
                SQLHSTMT          0x1b2e280
                SQLUSMALLINT      1 (SQL_FETCH_NEXT)
                SQLLEN            1

[000024.502558]
iodbctest       7FA9E8E3A700 EXIT  SQLFetchScroll with return code -1 (SQL_ERROR)
                SQLHSTMT          0x1b2e280
                SQLUSMALLINT      1 (SQL_FETCH_NEXT)
                SQLLEN            1

[000024.502584]
iodbctest       7FA9E8E3A700 ENTER SQLGetDiagRec
                SQLSMALLINT       3 (SQL_HANDLE_STMT)
                SQLHSTMT          0x1b2e280
                SQLSMALLINT       1
                SQLCHAR         * 0x7ffd7aaf6a80
                SQLINTEGER      * 0x7ffd7aaf6a9c
                SQLCHAR         * 0x7ffd7aaf6880
                SQLSMALLINT       512
                SQLSMALLINT     * 0x0

[000024.502636]
iodbctest       7FA9E8E3A700 EXIT  SQLGetDiagRec with return code 0 (SQL_SUCCESS)
                SQLSMALLINT       3 (SQL_HANDLE_STMT)
                SQLHSTMT          0x1b2e280
                SQLSMALLINT       1
                SQLCHAR         * 0x7ffd7aaf6a80
                                  | S1TAT                                    |
                SQLINTEGER      * 0x7ffd7aaf6a9c (-1)
                SQLCHAR         * 0x7ffd7aaf6880
                                  | [OpenLink][Virtuoso ODBC Driver][Virtuos |
                                  | o Server]RC...: Returning incomplete res |
                                  | ults, query interrupted by result timeou |
                                  | t.  Activity:  1.047M rnd  971.5K seq    |
                                  |    0 same seg   229.9K same pg     23K s |
                                  | ame par      0 disk      0 spec disk     |
                                  |   0B /      0 m                          |
                SQLSMALLINT       512
                SQLSMALLINT     * 0x0
```

This SQL state can be checked by simple application logic.

# See Also
  * [Virtuoso documentation on Anytime Queries](https://docs.openlinksw.com/virtuoso/anytimequeries/)
  * [List of HTTP status codes](https://en.wikipedia.org/wiki/List_of_HTTP_status_codes)
  * [Blog: HTTP Status: 206 Partial Content and range requests](https://benramsey.com/blog/2008/05/206-partial-content-and-range-requests/)
  * [RFC 2616: Hypertext Transfer Protocol](https://www.rfc-editor.org/rfc/rfc2616)
  * [RFC 9110: HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110)
