# Virtuoso Open Source Upgrade Notes

*Copyright (C) 1998-2026 OpenLink Software <vos.admin@openlinksw.com>*

 * [Introduction](#introduction)
  * [Upgrading from VOS 7.2.X to VOS 7.2.7](#upgrading-from-vos-72x-to-vos-727)
    + [Caveat](#caveat)
    + [Upgrade method 1](#upgrade-method-1)
    + [Upgrade method 2](#upgrade-method-2)
  * [Upgrading from VOS 6.1.4 to VOS 7.2.x](#upgrading-from-vos-614-to-vos-72x)


## Introduction

Please ensure a clean database shutdown and an empty transaction log (`virtuoso.trx`) before any update or upgrade below.

The database should be backed up before upgrading.

**NOTE**: Historic material here covers deprecated Virtuoso Open Source 5.x through 6.1.4. In-place upgrades from those lines to the current release are not recommended.


## Upgrading from VOS 7.2.X to VOS 7.2.7

The Virtuoso engine in 7.2.7 has been enhanced to use 64-bit prefix IDs in `RDF_IRI` which allows for even larger databases.

This enhancement fixes two important problems in Virtuoso:

1. When Virtuoso was upgraded to use 64-bit `IRI_ID`s around v6.0.x, the `RDF_IRI` table was not upgraded to use a 64-bit prefix ID. This meant that Virtuoso could only store around 2 billion distinct prefixes before returning an error.
2. The algorithm to generate distinct prefixes resulted in too many prefixes being created.

While this is not a problem for storing small or even medium sized data sets, this becomes a problem when hosting large databases the size of [Uniprot](https://www.uniprot.org/), which now contains over 90 billion triples.

To compare sizes, here are some of the databases OpenLink hosts, all unaffected by this issue:

| Endpoint                                    |        triples | distinct prefixes |
| ------------------------------------------- | -------------: | ----------------: |
| https://uriburner.com/sparql                |    138,881,702 |         9,197,016 |
| https://dbpedia.org/sparql                  |  1,104,129,087 |        27,528,113 |
| https://wikidata.demo.openlinksw.com/sparql | 12,216,143,296 |           990,992 |
| https://lod.openlinksw.com/sparql           | 35,875,699,899 |       175,697,066 |

When starting an existing 7.x database with the new 7.2.7 binary, the following message appears in the virtuoso.log file:
```
NOTE: Your database is using 32-bit prefix IDs in RDF_IRI

    This Virtuoso engine has been upgraded to use 64-bit prefix IDs
    in RDF_IRI to allow for even larger databases.

    To take advantage of this new feature, your database needs to
    be upgraded.

    The performance of your existing database should not be affected,
    except when performing certain bulkload operations.

    Please contact OpenLink Support <support@openlinksw.com> for
    more information.
```

As stated in the message, the engine uses a backward compatibility function to handle existing databases without causing a performance degradation when running SPARQL queries, inserts and deletes.

### Caveat

Bulkloading operations on an existing database using 32-bit prefix IDs are restricted to use non-vectored functions. This causes a drop in bulkload performance, so users relying on this functionality should plan a database upgrade as soon as possible.

Calling vectored functions like `TTLP_V()` and `RDF_LOAD_RDFXML_V()` automatically calls the non-vectored equivalents like `TTLP()` and `RDF_LOAD_RDFXML()`.

Bulkloading using the `rdf_loader_run()` functions also automatically downgrade to use non-vectored functions.

Some functions may fail with this error:
```
[42000] Can not use dpipe IRI operations before upgrading the RDF_IRI table to 64-bit prefixes IDs
```


### Upgrade Method 1

The preferred way of upgrading to the new 7.2.7 format is to perform an `NQUAD` dump of all your triples using the `RDF_DUMP_NQUADS()` function and bulkloading them into a new database.

### Upgrade Method 2

To upgrade an existing database in-place, make sure you have a proper backup of your existing database before performing these commands:
```
set echo on;
scheduler_interval(0);
backup '/dev/null'; -- make sure db is consistent
log_enable (2,0);

-- copy
create table DB.DBA.RDF_IRI_64 (RI_NAME varchar not null primary key, RI_ID IRI_ID_8 not null);
insert into DB.DBA.RDF_IRI_64 (RI_ID, RI_NAME) select RI_ID, __iri_name_id_64(RI_NAME) from DB.DBA.RDF_IRI;
checkpoint;

-- rename
drop table DB.DBA.RDF_IRI;
alter table DB.DBA.RDF_IRI_64 rename DB.DBA.RDF_IRI;
create unique index DB_DBA_RDF_IRI_UNQC_RI_ID on DB.DBA.RDF_IRI (RI_ID);

-- set db is upgraded
__dbf_set('rdf_rpid64_mode',1);
shutdown;
```

Note that depending on the number of records in the `DB.DBA.RDF_IRI` table, this can take a long time and increases the size of your database.


## Upgrading from VOS 6.1.4 to VOS 7.2.x

The database format has not changed between Virtuoso 6.1.4 and Virtuoso 7.2.6, so from a database standpoint no particular steps need to be performed before upgrading to the latest version of Virtuoso 7.2.6.

Please complete a clean database shutdown before installing new binaries.
Transaction logs may carry a different version tag; otherwise the Virtuoso server prints this message and refuses database startup:

```
The transaction log file has been produced by server version '06.01.XXXX'. The version of this
server is '06.01.YYYY'. If the transaction log is empty or you do not want to replay it then
delete it and start the server again. Otherwise replay the log using the server of version
'06.01.XXXX' and make checkpoint and shutdown to ensure the log is empty, then delete it
and start using new version.
```
