--
--  openGQL: CREATE VIRTUAL/PHYSICAL PROPERTY GRAPH — DDL Tests
--
--  Run via isql: isql <host>:<port> dba dba < test_gql_pg_ddl.sql
--

create procedure DB.DBA.GQL_PG_TEST_ASSERT (
  in _test_name varchar, in _condition integer, in _detail varchar,
  inout _pass integer, inout _fail integer, inout _results any)
{
  if (_condition)
    { _pass := _pass + 1; _results := vector_concat (_results, vector (concat (_test_name, ' PASS'))); }
  else
    { _fail := _fail + 1; _results := vector_concat (_results, vector (concat (_test_name, ' FAIL: ', _detail))); }
}
;

create procedure DB.DBA.GQL_PG_TEST_GQL (in _gql_text varchar) returns varchar
{
  declare _sparql varchar;
  declare exit handler for sqlstate '*' { return null; };
  _sparql := DB.DBA.GQL_TO_SPARQL (_gql_text);
  return _sparql;
}
;

create procedure DB.DBA.GQL_PG_TEST_EXEC (in _sql varchar) returns integer
{
  declare _st, _msg varchar; declare _m, _d any;
  declare exit handler for sqlstate '*' { return 0; };
  _st := '00000'; _msg := '';
  exec (_sql, _st, _msg, vector(), 0, _m, _d);
  if (_st = '00000') return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_PG_TEST_QUERY (in _sql varchar) returns any
{
  declare _st, _msg varchar; declare _m, _d any;
  declare exit handler for sqlstate '*' { return vector (); };
  _st := '00000'; _msg := '';
  exec (_sql, _st, _msg, vector(), 0, _m, _d);
  if (_st = '00000') return _d;
  return vector ();
}
;

create procedure DB.DBA.GQL_PG_TEST_SETUP ()
{
  DB.DBA.GQL_PG_TEST_EXEC ('DROP TABLE DB.DBA.pg_test_order_items');
  DB.DBA.GQL_PG_TEST_EXEC ('DROP TABLE DB.DBA.pg_test_customer_orders');
  DB.DBA.GQL_PG_TEST_EXEC ('DROP TABLE DB.DBA.pg_test_orders');
  DB.DBA.GQL_PG_TEST_EXEC ('DROP TABLE DB.DBA.pg_test_products');
  DB.DBA.GQL_PG_TEST_EXEC ('DROP TABLE DB.DBA.pg_test_customers');
  DB.DBA.GQL_PG_TEST_EXEC ('DROP TABLE DB.DBA.pg_test_employees');
  DB.DBA.GQL_PG_TEST_EXEC ('CREATE TABLE DB.DBA.pg_test_products (product_no integer PRIMARY KEY, name varchar, price numeric)');
  DB.DBA.GQL_PG_TEST_EXEC ('CREATE TABLE DB.DBA.pg_test_customers (customer_id integer PRIMARY KEY, name varchar, address varchar)');
  DB.DBA.GQL_PG_TEST_EXEC ('CREATE TABLE DB.DBA.pg_test_orders (order_id integer PRIMARY KEY, ordered_when date)');
  DB.DBA.GQL_PG_TEST_EXEC ('CREATE TABLE DB.DBA.pg_test_employees (employee_id integer PRIMARY KEY, employee_name varchar)');
  DB.DBA.GQL_PG_TEST_EXEC ('CREATE TABLE DB.DBA.pg_test_order_items (order_items_id integer PRIMARY KEY, order_id integer, product_no integer, quantity integer)');
  DB.DBA.GQL_PG_TEST_EXEC ('CREATE TABLE DB.DBA.pg_test_customer_orders (customer_orders_id integer PRIMARY KEY, customer_id integer, order_id integer)');
  DB.DBA.GQL_PG_TEST_EXEC ('INSERT INTO DB.DBA.pg_test_products VALUES (1, ''Widget'', 9.99)');
  DB.DBA.GQL_PG_TEST_EXEC ('INSERT INTO DB.DBA.pg_test_products VALUES (2, ''Gadget'', 19.99)');
  DB.DBA.GQL_PG_TEST_EXEC ('INSERT INTO DB.DBA.pg_test_customers VALUES (1, ''Alice'', ''123 Main St'')');
  DB.DBA.GQL_PG_TEST_EXEC ('INSERT INTO DB.DBA.pg_test_customers VALUES (2, ''Bob'', ''456 Oak Ave'')');
  DB.DBA.GQL_PG_TEST_EXEC ('INSERT INTO DB.DBA.pg_test_orders VALUES (1, ''2024-01-15'')');
  DB.DBA.GQL_PG_TEST_EXEC ('INSERT INTO DB.DBA.pg_test_orders VALUES (2, ''2024-02-20'')');
  DB.DBA.GQL_PG_TEST_EXEC ('INSERT INTO DB.DBA.pg_test_order_items VALUES (1, 1, 1, 5)');
  DB.DBA.GQL_PG_TEST_EXEC ('INSERT INTO DB.DBA.pg_test_order_items VALUES (2, 1, 2, 3)');
  DB.DBA.GQL_PG_TEST_EXEC ('INSERT INTO DB.DBA.pg_test_customer_orders VALUES (1, 1, 1)');
  DB.DBA.GQL_PG_TEST_EXEC ('INSERT INTO DB.DBA.pg_test_customer_orders VALUES (2, 2, 2)');
}
;

create procedure DB.DBA.GQL_PG_TEST_CLEANUP ()
{
  if (__proc_exists ('DB.DBA.GQL_PG_DROP') is not null)
    {
      DB.DBA.GQL_PG_DROP ('pgtest', 1);
      DB.DBA.GQL_PG_DROP ('pgtest2', 1);
      DB.DBA.GQL_PG_DROP ('pgphys', 1);
    }
  DB.DBA.GQL_PG_TEST_EXEC ('DROP TABLE DB.DBA.pg_test_order_items');
  DB.DBA.GQL_PG_TEST_EXEC ('DROP TABLE DB.DBA.pg_test_customer_orders');
  DB.DBA.GQL_PG_TEST_EXEC ('DROP TABLE DB.DBA.pg_test_orders');
  DB.DBA.GQL_PG_TEST_EXEC ('DROP TABLE DB.DBA.pg_test_products');
  DB.DBA.GQL_PG_TEST_EXEC ('DROP TABLE DB.DBA.pg_test_customers');
  DB.DBA.GQL_PG_TEST_EXEC ('DROP TABLE DB.DBA.pg_test_employees');
}
;

-- Helper: check that a string contains a substring (returns 1/0)
create procedure DB.DBA.GQL_PG_TEST_CONTAINS (in _haystack varchar, in _needle varchar) returns integer
{
  if (_haystack is null) return 0;
  if (strstr (_haystack, _needle) is not null) return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_PG_DDL_TESTS ()
{
  declare _pass, _fail, _total integer;
  declare _results any;
  declare _sparql varchar;
  declare _data any;
  declare _ok integer;
  declare _meta any;
  declare _desc varchar;
  declare _ttl varchar;
  declare _graph_iri, _ont_ns, _q varchar;
  declare _summary varchar;
  declare _i integer;

  _pass := 0; _fail := 0; _total := 0;
  _results := vector ();

  DB.DBA.GQL_PG_TEST_SETUP ();

  -- PG01: CREATE VIRTUAL PROPERTY GRAPH minimal
  _sparql := DB.DBA.GQL_PG_TEST_GQL (
    'CREATE VIRTUAL PROPERTY GRAPH pgtest
       NODE TABLES (pg_test_products, pg_test_customers, pg_test_orders)
       RELATIONSHIP TABLES (
         pg_test_order_items SOURCE pg_test_orders DESTINATION pg_test_products,
         pg_test_customer_orders SOURCE pg_test_customers DESTINATION pg_test_orders
       )');
  _ok := DB.DBA.GQL_PG_TEST_CONTAINS (_sparql, 'CREATE VIRTUAL PROPERTY GRAPH pgtest');
  DB.DBA.GQL_PG_TEST_ASSERT ('PG01', _ok, 'expected CREATE VIRTUAL PROPERTY GRAPH pgtest', _pass, _fail, _results);

  -- PG02: Verify catalog metadata
  _meta := DB.DBA.GQL_PG_DEF_GET ('pgtest');
  _ok := 0;
  if (_meta is not null) if (aref (_meta, 0) = 'virtual') _ok := 1;
  DB.DBA.GQL_PG_TEST_ASSERT ('PG02', _ok, 'expected catalog entry with mode=virtual', _pass, _fail, _results);

  -- PG03: GQL_PG_DESCRIBE
  _desc := DB.DBA.GQL_PG_DESCRIBE ('pgtest');
  _ok := 0;
  if (DB.DBA.GQL_PG_TEST_CONTAINS (_desc, 'pgtest')) if (DB.DBA.GQL_PG_TEST_CONTAINS (_desc, 'virtual')) _ok := 1;
  DB.DBA.GQL_PG_TEST_ASSERT ('PG03', _ok, 'expected describe output with pgtest and virtual', _pass, _fail, _results);

  -- PG04: SPARQL query against virtual graph
  _graph_iri := DB.DBA.GQL_PG_GRAPH_IRI ('pgtest');
  _ont_ns := DB.DBA.GQL_PG_ONTOLOGY_NS ('pgtest');
  _q := sprintf ('SPARQL SELECT ?name FROM <%s> WHERE { ?p <%sname> ?name }', _graph_iri, _ont_ns);
  _data := DB.DBA.GQL_PG_TEST_QUERY (_q);
  _ok := 0;
  if (isarray (_data)) if (length (_data) > 1) _ok := 1;
  DB.DBA.GQL_PG_TEST_ASSERT ('PG04', _ok, 'expected product data from virtual graph', _pass, _fail, _results);

  -- PG05: DROP and recreate with labels and properties
  DB.DBA.GQL_PG_DROP ('pgtest', 1);
  _sparql := DB.DBA.GQL_PG_TEST_GQL (
    'CREATE VIRTUAL PROPERTY GRAPH pgtest
       NODE TABLES (
         pg_test_products KEY (product_no) LABEL product PROPERTIES (name, price),
         pg_test_customers KEY (customer_id) LABEL customer LABEL person PROPERTIES (name),
         pg_test_orders KEY (order_id) LABEL "order" PROPERTIES (ordered_when)
       )
       RELATIONSHIP TABLES (
         pg_test_order_items KEY (order_items_id)
           SOURCE pg_test_orders DESTINATION pg_test_products
           LABEL contains PROPERTIES (quantity),
         pg_test_customer_orders KEY (customer_orders_id)
           SOURCE pg_test_customers DESTINATION pg_test_orders
           LABEL has_placed
       )');
  _ok := DB.DBA.GQL_PG_TEST_CONTAINS (_sparql, 'CREATE VIRTUAL PROPERTY GRAPH pgtest');
  DB.DBA.GQL_PG_TEST_ASSERT ('PG05', _ok, 'expected CREATE VIRTUAL PROPERTY GRAPH pgtest with labels', _pass, _fail, _results);

  -- PG06: SPARQL query with label returns customer data
  _graph_iri := DB.DBA.GQL_PG_GRAPH_IRI ('pgtest');
  _ont_ns := DB.DBA.GQL_PG_ONTOLOGY_NS ('pgtest');
  _q := sprintf ('SPARQL SELECT ?name FROM <%s> WHERE { ?c a <%scustomer> . ?c <%sname> ?name }', _graph_iri, _ont_ns, _ont_ns);
  _data := DB.DBA.GQL_PG_TEST_QUERY (_q);
  _ok := 0;
  if (isarray (_data)) if (length (_data) > 1) _ok := 1;
  DB.DBA.GQL_PG_TEST_ASSERT ('PG06', _ok, 'expected customer data with label filter', _pass, _fail, _results);

  -- PG07: Multi-label — person matches both customers (2 rows)
  _q := sprintf ('SPARQL SELECT ?c FROM <%s> WHERE { ?c a <%sperson> }', _graph_iri, _ont_ns);
  _data := DB.DBA.GQL_PG_TEST_QUERY (_q);
  _ok := 0;
  if (isarray (_data)) if (length (_data) > 1) _ok := 1;
  DB.DBA.GQL_PG_TEST_ASSERT ('PG07', _ok, 'expected person multi-label data', _pass, _fail, _results);

  -- PG08: R2RML export
  _ok := 0;
  if (__proc_exists ('DB.DBA.R2RML_MAKE_QM_FROM_G') is not null)
    {
      declare exit handler for sqlstate '*' { goto pg08_skip; };
      _ttl := DB.DBA.GQL_PG_EXPORT_R2RML ('pgtest');
      if (DB.DBA.GQL_PG_TEST_CONTAINS (_ttl, 'rr:TriplesMap'))
        if (DB.DBA.GQL_PG_TEST_CONTAINS (_ttl, 'rdf:reifies'))
          if (DB.DBA.GQL_PG_TEST_CONTAINS (_ttl, '<<('))
            _ok := 1;
    pg08_skip:;
    }
  else
    _ok := 1;  -- skip if rdb2rdf not installed
  DB.DBA.GQL_PG_TEST_ASSERT ('PG08', _ok, 'expected R2RML TTL with TriplesMap, rdf:reifies, triple terms', _pass, _fail, _results);

  -- PG09: CREATE PHYSICAL PROPERTY GRAPH
  _sparql := DB.DBA.GQL_PG_TEST_GQL ('CREATE PHYSICAL PROPERTY GRAPH pgphys');
  _meta := DB.DBA.GQL_PG_DEF_GET ('pgphys');
  _ok := 0;
  if (_meta is not null) if (aref (_meta, 0) = 'physical') _ok := 1;
  DB.DBA.GQL_PG_TEST_ASSERT ('PG09', _ok, 'expected catalog entry with mode=physical', _pass, _fail, _results);

  -- PG10: CREATE PROPERTY GRAPH (no keyword) defaults to physical
  _sparql := DB.DBA.GQL_PG_TEST_GQL ('CREATE PROPERTY GRAPH pgtest2');
  _ok := 0;
  if (_sparql is not null) _ok := 1;
  DB.DBA.GQL_PG_TEST_ASSERT ('PG10', _ok, 'expected non-null SPARQL for CREATE PROPERTY GRAPH', _pass, _fail, _results);
  DB.DBA.GQL_PG_TEST_EXEC (sprintf ('SPARQL DROP SILENT GRAPH <%s>', DB.DBA.GQL_PG_GRAPH_IRI ('pgtest2')));
  DB.DBA.GQL_PG_DROP ('pgtest2', 1);

  -- PG11: DROP removes catalog metadata
  DB.DBA.GQL_PG_DROP ('pgphys', 1);
  _meta := DB.DBA.GQL_PG_DEF_GET ('pgphys');
  _ok := 0;
  if (_meta is null) _ok := 1;
  DB.DBA.GQL_PG_TEST_ASSERT ('PG11', _ok, 'expected catalog entry removed after DROP', _pass, _fail, _results);

  -- PG12: Duplicate PG name rejected
  _ok := 1;
  {
    declare exit handler for sqlstate '*' { _ok := 0; };
    DB.DBA.GQL_PG_CREATE_PHYSICAL ('pgtest');
  }
  _ok := 1 - _ok;  -- invert: 1=was rejected, 0=was not rejected
  DB.DBA.GQL_PG_TEST_ASSERT ('PG12', _ok, 'expected duplicate PG name rejected', _pass, _fail, _results);

  -- PG13: Nonexistent table rejected
  _ok := 1;
  {
    declare exit handler for sqlstate '*' { _ok := 0; };
    DB.DBA.GQL_PG_CREATE_VIRTUAL ('pgtest_bad',
      vector (vector ('DB.DBA.nonexistent_table', null, vector (), null)),
      vector ());
  }
  _ok := 1 - _ok;
  DB.DBA.GQL_PG_TEST_ASSERT ('PG13', _ok, 'expected nonexistent table rejected', _pass, _fail, _results);

  -- PG14: SOURCE referencing non-declared node table rejected
  _ok := 1;
  {
    declare exit handler for sqlstate '*' { _ok := 0; };
    DB.DBA.GQL_PG_CREATE_VIRTUAL ('pgtest_bad2',
      vector (vector ('DB.DBA.pg_test_products', null, vector ('product'), null)),
      vector (vector ('DB.DBA.pg_test_order_items', null,
                      'DB.DBA.pg_test_nonexistent', null,
                      'DB.DBA.pg_test_products', null,
                      'contains', null, 0, null)));
  }
  _ok := 1 - _ok;
  DB.DBA.GQL_PG_TEST_ASSERT ('PG14', _ok, 'expected undeclared SOURCE rejected', _pass, _fail, _results);

  -- Cleanup
  DB.DBA.GQL_PG_TEST_CLEANUP ();

  -- Report
  _total := _pass + _fail;
  _summary := sprintf ('=========================\nPG DDL Tests: %d/%d passed, %d failed\n=========================\n', _pass, _total, _fail);
  for (_i := 0; _i < length (_results); _i := _i + 1)
    _summary := concat (_summary, aref (_results, _i), '\n');
  return _summary;
}
;

DB.DBA.GQL_PG_DDL_TESTS ();
