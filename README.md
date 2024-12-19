# Virtuoso Open Source Edition

![GitHub Release](https://img.shields.io/github/v/release/openlink/virtuoso-opensource?label=latest%20release)
![GitHub commits since latest release (branch)](https://img.shields.io/github/commits-since/openlink/virtuoso-opensource/latest/develop%2F7)
![GitHub contributors](https://img.shields.io/github/contributors-anon/openlink/virtuoso-opensource)
![GitHub Repo stars](https://img.shields.io/github/stars/openlink/virtuoso-opensource?style=flat)
![GitHub forks](https://img.shields.io/github/forks/openlink/virtuoso-opensource?style=flat)
![GitHub commit activity](https://img.shields.io/github/commit-activity/m/openlink/virtuoso-opensource)
![Docker Pulls](https://img.shields.io/docker/pulls/openlink/virtuoso-opensource-7)

## About

OpenLink Virtuoso Open-Source Edition (VOS) is a multi-model RDBMS platform providing high-performance and scalable data management. It integrates relational, graph and document data models within a single database engine.

VOS includes Data-Integration Middleware with support for ODBC and JDBC, facilitating connection and interaction between data sources and provides data-exchange and transformation capabilities.

VOS includes an HTTP(S) Application Server Platform for deploying web applications and services. It provides built-in support for web standards and protocols. Building on this, VOS is a Linked Data deployment platform with support for RDF, SPARQL and semantic web applications.


## Installation

* Virtuoso Server
  * Downloading prebuilt binaries for Linux, macOS or Windows from [Github releases](https://github.com/openlink/virtuoso-opensource/releases)
  * Running Virtuoso via [Docker](README.Docker.md)
  * Building from source on [Linux, macOS](README.Building.md) and [Windows](README.WINDOWS.md)
  * Upgrading from [previous versions](README.UPGRADE.md)

* Optional Components
  * JDBC drivers and providers for Jena, Sesame and RDF4j are available from [Maven Central](https://central.sonatype.com/search?q=com.openlinksw)
  * Integration with [GeoSPARQL](README.GeoSPARQL.md)

* [Recent commits](https://github.com/openlink/virtuoso-opensource/commits/develop/7/), [News](NEWS.md) and [ChangeLog](https://raw.githubusercontent.com/openlink/virtuoso-opensource/refs/heads/develop/7/ChangeLog)

 ## Documentation

* [Database Administration Manual](https://docs.openlinksw.com/virtuoso/)
* [VOS Wiki](https://vos.openlinksw.com/)
* [SPARQL ANYTIME](README.ANYTIME.md) implementation notes

## Reporting Security Vulnerabilities

Security vulnerabilities may be reported by following the [instructions in SECURITY.md](SECURITY.md).

## Support

Issues with Virtuoso may be reported by [opening a Github issue](https://github.com/openlink/virtuoso-opensource/issues/),
providing a summary, description and steps to reproduce.

Assistance is available via our [OpenLink Community forums](https://community.openlinksw.com/), or if covered by a support contract, you can also create a [Support Case through the OpenLink Support Site](https://support.openinksw.com/).

See our [policy](README.GIT.md) for notes on managing this git repository.

## License

VOS is licensed under the [GNU General Public License Version 2, dated June 1991](COPYING.md).

## Credits

The Virtuoso Open-Source Edition (VOS) project acknowledges incorporation of code from several other projects. See [CREDITS](CREDITS.md) for details.


## See Also

  * OpenLink Virtuoso (Commercial Edition) https://virtuoso.openlinksw.com/
  * OpenLink Software corporate home https://www.openlinksw.com/
