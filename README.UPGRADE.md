# Virtuoso Open Source Upgrade Notes

*Copyright (C) 1998-2024 OpenLink Software <vos.admin@openlinksw.com>*

 * [Introduction](#introduction)
  * [Upgrading from VOS 7.2.x to VOS 7.2.7](#upgrading-from-vos-72x-to-vos-727)
    + [Caveat](#caveat)
    + [Upgrade method 1](#upgrade-method-1)
    + [Upgrade method 2](#upgrade-method-2)
  * [Upgrading from VOS 6.1.4 to VOS 7.2.6](#upgrading-from-vos-614-to-vos-726)
  * [Legacy upgrades](#legacy-upgrades)
    + [Upgrading from VOS 6.1.x to VOS 6.1.4](#upgrading-from-vos-61x-to-vos-614)
    + [Upgrading from VOS 6.1.x to VOS 6.1.y](#upgrading-from-vos-61x-to-vos-61y)
    + [Upgrading from VOS 6.0.0(-TP1) to VOS 6.1.0](#upgrading-from-vos-600--tp1--to-vos-610)
    + [Upgrading from VOS 5.0.x to VOS 6.1.0](#upgrading-from-vos-50x-to-vos-610)
    + [Upgrading from VOS 5.0.x to VOS 5.0.y](#upgrading-from-vos-50x-to-vos-50y)


## Introduction

Before performing any of the following updates/upgrades, always make
sure that the database has been properly shut down, and that the
transaction log (`virtuoso.trx`) is empty.

Before upgrading any database, it is always a wise precaution to make
a proper backup.

**NOTE**: This document contains historic notes for upgrading deprecated
releases of Virtuoso Open Source versions 5.x up to 6.1.4. It is not
recommended to attempt to upgrade from these versions to the current release
using in-place upgrades.


## Upgrading from VOS 7.2.x to VOS 7.2.7

The Virtuoso engine in 7.2.7 has been enhanced to use 64-bit prefix IDs in `RDF_IRI` which allows for
even larger databases.

This enhancement fixes two important problems in Virtuoso:

1. When Virtuoso was upgraded to use 64-bit `IRI_ID`s around v6.0.x, we forgot to upgrade the
   `RDF_IRI` table to use a 64-bit prefix ID. This meant that Virtuoso could only store around 2
   billion distinct prefixes before returning an error.
2. The algorithm to generate distinct prefixes resulted in too many prefixes being created.

While this is not a problem for storing small or even medium sized data sets, this becomes a
problem when you want to host large databases the size of [Uniprot](https://www.uniprot.org/)
which now contains over 90 billion triples.

To compare sizes, here are some of the databases that OpenLink hosts, all of which were unaffected
by this issue:

| Endpoint                                    |        triples | distinct prefixes |
| ------------------------------------------- | -------------: | ----------------: |
| https://uriburner.com/sparql                |    138,881,702 |         9,197,016 |
| https://dbpedia.org/sparql                  |  1,104,129,087 |        27,528,113 |
| https://wikidata.demo.openlinksw.com/sparql | 12,216,143,296 |           990,992 |
| https://lod.openlinksw.com/sparql           | 35,875,699,899 |       175,697,066 |

When starting an existing 7.x database with the new 7.2.7 binary, the following message will appear in
the virtuoso.log file:
```pre
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

As stated in the message, the engine will use a backward compatibility function to handle existing
databases without causing a performance degradation when running SPARQL queries, inserts and
deletes.

### Caveat
Bulkloading operations on an existing database using 32-bit prefix IDs will be restricted to use
non-vectored functions. This will cause a drop in bulkload performance, so users who rely on this
functionality should upgrade their database as soon as possible.

Calling vectored functions like `TTLP_V()` and `RDF_LOAD_RDFXML_V()` will automatically call their
non-vectored equivalents like `TTLP()` and `RDF_LOAD_RDFXML()`.

Bulkloading using the `rdf_loader_run()` functions also automatically will downgrade to use
non-vectored functions.

Some functions may fail with the following error:
```pre
[42000] Can not use dpipe IRI operations before upgrading the RDF_IRI table to 64-bit prefixes IDs
```


### Upgrade method 1
The preferred way of upgrading to the new 7.2.7 format is to perform an `NQUAD` dump of all your
triples using the `RDF_DUMP_NQUADS()` function and bulkloading them into a new database.

### Upgrade method 2
To upgrade an existing database in-place, make sure you have a proper backup of your existing
database before performing the following commands:
```pre
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

Note however that depending on the number of records in the `DB.DBA.RDF_IRI` table, this can take a
long time and will increase the size of your database.


## Upgrading from VOS 6.1.4 to VOS 7.2.6

The database format has not changed between Virtuoso 6.1.4 and Virtuoso 7.2.6, so from a database
standpoint no particular steps need to be performed before upgrading to the latest version of
Virtuoso 7.2.6.

The only requirement is that you have properly shutdown the database prior to installing the latest
binaries, as the transaction logs can have a different version tag. In this case the virtuoso server
will print the following message and refuses to start the database:

```pre
The transaction log file has been produced by server version '06.01.xxxx'. The version of this
server is '06.01.yyyy'. If the transaction log is empty or you do not want to replay it then
delete it and start the server again. Otherwise replay the log using the server of version
'06.01.xxxx' and make checkpoint and shutdown to ensure that the log is empty, then delete it
and start using new version.
```

## <h1>Legacy upgrades</h1>

The rest of this document contains legacy notes for upgrading deprecated releases of Virtuoso Open Source.

It is not recommended to attempt to upgrade from these versions to the current release using in-line upgrades.

### Upgrading from VOS 6.1.x to VOS 6.1.4

In Virtuoso versions before 6.1.4, some XML data was stored in the
QUAD store in such a way that it could break the sequence of an
index, causing wrong results to be returned.

To fix this, we've added an automated check into 6.1.4 to detect the
presence of this condition, and to fix the index when needed.

When a DBA starts the database with this newer Virtuoso binary, the
following text will appear in the Virtuoso session log:

```pre
21:05:36 PL LOG: This database may contain RDF data that could cause indexing problems on previous versions of the server.
21:05:36 PL LOG: The content of the DB.DBA.RDF_QUAD table will be checked and an update may automatically be performed if
21:05:36 PL LOG: such data is found.
21:05:36 PL LOG: This check will take some time but is made only once.
```

This check may take some time depending on the number of stored
quads, but if the check succeeds the following message is entered
in the log and Virtuoso will flag this check as done within the DB
file, so it will not affect subsequent restarts.

```pre
21:05:36 PL LOG: No need to update DB.DBA.RDF_QUAD
```

The database will then continue to perform the startup routines and
go into an online state.

However, if the condition *is* detected, the following message will
appear in the log, and the Virtuoso server will refuse to start:

```pre
21:05:36 PL LOG: An update is required.
21:05:36 PL LOG:
21:05:36 PL LOG: NOTICE: Before Virtuoso can continue fixing the DB.DBA.RDF_QUAD table and its indexes
21:05:36 PL LOG:         the DB Administrator should check make sure that:
21:05:36 PL LOG:
21:05:36 PL LOG:          * there is a recent backup of the database
21:05:36 PL LOG:          * there is enough free disk space available to complete this conversion
21:05:36 PL LOG:          * the database can be offline for the duration of this conversion
21:05:36 PL LOG:
21:05:36 PL LOG:         Since the update can take a considerable amount of time on large databases
21:05:36 PL LOG:         it is advisable to schedule this at an appropriate time.
21:05:36 PL LOG:
21:05:36 PL LOG: To continue the DBA must change the virtuoso.ini file and add the following flag:
21:05:36 PL LOG:
21:05:36 PL LOG:     [Parameters]
21:05:36 PL LOG:     AnalyzeFixQuadStore = 1
21:05:36 PL LOG:
21:05:36 PL LOG: For additional information please contact OpenLink Support <support@openlinksw.com>
21:05:36 PL LOG: This process will now exit.
```

Since the update may take a substantial amount of time and disk
space, depending on the size of the quad store, OpenLink has
decided not to automatically start the update process but hand
control back to the DBA and let them decide when to perform this
update. If the DBA wants to delay the update until a more
appropriate time, they should restart with the previously active
binary, as this latest binary will not start.

Once the DBA has checked the backups and disk space, and found
an appropriate time-slot to run this update, they should edit
the `virtuoso.ini` file, and add the following line to the
`[Parameters]` stanza:

```pre
AnalyzeFixQuadStore = 1
```

Upon starting the Virtuoso server with the `AnalyzeFixQuadStore=1`
setting active, messages like the following will be written to
the `virtuoso.log` file:

```pre
21:05:57 PL LOG: This database may contain RDF data that could cause indexing problems on previous versions of the server.
21:05:57 PL LOG: The content of the DB.DBA.RDF_QUAD table will be checked and an update may automatically be performed if
21:05:57 PL LOG: such data is found.
21:05:57 PL LOG: This check will take some time but is made only once.
21:05:57 PL LOG:
21:05:57 PL LOG: An update is required.
21:05:57 PL LOG: Please be patient.
21:05:57 PL LOG: The table DB.DBA.RDF_QUAD and two of its additional indexes will now be patched.
21:05:57 PL LOG: In case of an error during the operation, delete the transaction log before restarting the server.
21:05:57 Checkpoint started
21:05:57 Checkpoint finished, log off
21:05:57 PL LOG: Phase 1 of 9: Gathering statistics ...
21:05:58 PL LOG:  * Index sizes before the processing: 002565531 RDF_QUAD, 002565531 POGS, 001171100 OP
21:05:58 PL LOG: Phase 2 of 9: Copying all quads to a temporary table ...
21:07:26 PL LOG: * Index sizes of temporary table: 001171100 OP
21:07:26 PL LOG: Phase 3 of 9: Cleaning the quad storage ...
21:07:51 PL LOG: Phase 4 of 9: Refilling the quad storage from the temporary table...
21:09:17 PL LOG: Phase 5 of 9: Cleaning the temporary table ...
21:09:41 PL LOG: Phase 6 of 9: Gathering statistics again ...
21:09:41 PL LOG: * Index sizes after the processing: 002565531 RDF_QUAD, 002565531 POGS, 001171100 OP
21:09:41 PL LOG: Phase 7 of 9: integrity check (completeness of index RDF_QUAD_POGS of DB.DBA.RDF_QUAD) ...
21:10:00 PL LOG: Phase 8 of 9: integrity check (completeness of primary key of DB.DBA.RDF_QUAD) ...
21:10:17 PL LOG: Phase 9 of 9: final checkpoint...
21:10:20 Checkpoint started
21:10:22 Checkpoint finished, log off
21:10:22 PL LOG: Update complete.
```

If the update process detects any problem, it will put some debug
output into the `virtuoso.log` and exit. At this point, the DBA is
advised to remove the `virtuoso.trx` file and contact
[OpenLink Support](http://wikis.openlinksw.com/SupportWeb/).

After the update process has completed, the database is left in
an online state.


### Upgrading from VOS 6.1.x to VOS 6.1.y

*Also see **[Upgrading from VOS 6.1.x to VOS 6.1.4](#upgrading-from-vos-61x-to-vos-614)***

The database format did not change between various versions of Virtuoso
6.1.x, so from a database standpoint, no particular steps need to be
performed before upgrading to the latest version of Virtuoso 6.1.x.

The only requirement is that you must properly shut down the database
prior to installing the latest binaries, as the transaction logs for
different binary versions typically have different version tags, and
cannot be replayed by mismatched binaries. In such case, the Virtuoso
server will print a message like that below, and refuse to start the
database:

```pre
The transaction log file has been produced by server version
'06.01.xxxx'. The version of this server is '06.01.yyyy'. If the
transaction log is empty or you do not want to replay it then delete
it and start the server again. Otherwise replay the log using the
server of version '06.01.xxxx' and make checkpoint and shutdown
to ensure that the log is empty, then delete it and start using
new version.
```

### Upgrading from VOS 6.0.0(-TP1) to VOS 6.1.0

The database disk format has not changed, but the introduction of a newer
RDF index requires that you run a script to upgrade the `RDF_QUAD` table.
Since this can be a lengthy task and takes extra disk space (up to twice
the space of the original `RDF_QUAD` table during conversion), this is not
done automatically on startup.

After upgrading the binary, you will not be able to perform any SPARQL
queries until the `RDF_QUAD` table is converted, by the following steps:

  1. Shut down the database and verify the `.trx` file is empty.

  2. Check to make sure you have enough disk space.

  3. Check to make sure you have a proper backup of the database.

  4. Edit `virtuoso.ini` to disable `VADInstallDir` and possibly the
     `HTTPServer` section for the duration of the upgrade.

  5. Start the database.

  6. Use `isql` to connect to your database and run the upgrade script,
     `libsrc/Wi/clrdf23.sql`. Depending on the number of quad records,
     this may take several hours. Once the conversion is complete, the
     database will shut itself down.

  7. Edit `virtuoso.ini` to re-enable `VADInstallDir` and `HTTPServer`
     section, as were disabled in step 4 above.

  8. Start the database.


### Upgrading from VOS 5.0.x to VOS 6.1.0

The database format changed substantially between Virtuoso versions 5.x
and 6.x. To upgrade your database, you must dump all data from VOS 5.x
and re-load it into VOS 6.x.

The `dbdump` tool can be used to dump regular VOS 5.x RDBMS (SQL) tables
into scripts that can be replayed using the VOS 6.x `isql` tool.

For VOS 5.x `RDF_QUAD` tables, we have a set of `dump`/`load` stored
procedures to dump graphs into a set of backup files, which can then
be loaded into the VOS 6.x database. For more info, contact
[OpenLink Support](http://wikis.openlinksw.com/SupportWeb/).

If you attempt to open a VOS 5.0 database file with a VOS 6.0 server
binary, the server will print a message like the following, and refuse
to start the database:

```pre
The database you are opening was last closed with a server of
version 3016. The present server is of version 3126. This server
does not read this pre 6.0 format.
```

### Upgrading from VOS 5.0.x to VOS 5.0.y

The database format did not change between various versions of Virtuoso
5.0.x, so from a database standpoint, no particular steps need to be
performed before upgrading to the latest version of Virtuoso 5.

The only requirement is that you must properly shut down the database
prior to installing the latest binaries, as the transaction logs for
different binary versions typically have different version tags, and
cannot be replayed by mismatched binaries. In such case, the Virtuoso
server will print a message like that below and refuse to start the
database:

```pre
The transaction log file has been produced by server version
'05.00.xxxx'. The version of this server is '05.00.yyyy'. If the
transaction log is empty or you do not want to replay it then delete
it and start the server again. Otherwise replay the log using the
server of version '05.00.xxxx' and make checkpoint and shutdown
to ensure that the log is empty, then delete it and start using
new version.
```