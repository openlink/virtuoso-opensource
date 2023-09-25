# Security Policy

# Reporting a Vulnerability
In the first instance, send a detailed email to
[vos.security@openlinksw.com](mailto:vos.security@openlinksw.com)
to report a possible vulnerability in Virtuoso, even if you are
uncertain whether the issue in question is an exploitable vulnerability.

Please add as much detail as possible in your report, including:

 * version information from the binary using `virtuoso-t -?`
 * where you compiled/downloaded this binary from
 * short description (or script) to demonstrate the issue

You should receive an acknowledgement within a few business days,
which may include requests for additional details.

Followups, including notification of a relevant patch, will be sent
as appropriate.


## Supported Versions
Currently there is no official "Long-Term Support" version in Virtuoso.

New features as well as bug-fixes are regularly committed to the
[develop/7](https://github.com/openlink/virtuoso-opensource/tree/develop/7)
branch on GitHub.

At regular intervals we perform our due diligence and we close off this
development cycle by merging the work to the
[stable/7](https://github.com/openlink/virtuoso-opensource/tree/stable/7)
branch.

We then publish a
[new release](https://github.com/openlink/virtuoso-opensource/releases)
with ports for several key platforms.
