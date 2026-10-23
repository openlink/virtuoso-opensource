# PHP SAPI Module for Virtuoso (removed)

The PHP SAPI module (`hosting_php.so`) has been removed from this tree.

It was a legacy plugin that was never updated for modern PHP releases. The
source and its original build instructions remain available in the git
history, in release v7.2.17 and earlier, for reference only.

## Availability

- **Linux and macOS installers:** have not shipped this plugin since v7.2.5,
  published on 16 August 2018.
- **Windows installers:** up to and including v7.2.17, the installers did
  install this plugin, but did not activate it. Its entries were commented out
  in the plugin section of `virtuoso.ini`, so it was never loaded by default.
- **Docker images:** have never shipped this plugin.
- **Distribution packages** (Ubuntu, Debian, CentOS, Red Hat and SUSE): have
  never shipped this plugin.

None of these deployments load this plugin by default.

## Check your configuration

If you have a `virtuoso.ini` that was carried forward from a very early
installation, it may still try to load this plugin. Open the file and look in
the `[Plugins]` section for either of these entries (the number after `Load`
will vary):

    [Plugins]
    ...
    Load1 = attach, libphp5.so
    Load2 = Hosting, hosting_php.so

On Windows, these plugins use the `.dll` extension instead of `.so`, so look
for the corresponding entries ending in `.dll`.

If either is present and not commented out, remove the line, or at least
comment it out, then restart Virtuoso for the change to take effect. Windows
users who have not edited these entries do not need to do anything, as the
installers left them commented out.

## Security note

On 21 October 2026, PHP disclosed and fixed two critical remote code execution
vulnerabilities, CVE-2026-109618 and CVE-2026-109619 ("PHP2Shell"). They affect
PHP versions from 5.4 through 8, and fixes were released only for the
currently maintained branches (PHP 8.2 to 8.5). A Virtuoso installation that
still loads `libphp5.so` is running a PHP 5 runtime that will not receive a
fix. The Virtuoso PHP module has not been assessed against these
vulnerabilities, and the removal described here is not a response to them, but
we strongly recommend removing or commenting out these plugin entries above and
running PHP only as a separate, fully patched service.

To run PHP applications alongside Virtuoso, run PHP as a separate service and
connect to Virtuoso over a standard interface such as ODBC, JDBC or the
SPARQL/HTTP endpoints.
