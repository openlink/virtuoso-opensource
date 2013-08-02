// 
// $Id$
//

using System.Reflection;
using System.Runtime.CompilerServices;

//
// General Information about an assembly is controlled through the following 
// set of attributes. Change these attribute values to modify the information
// associated with an assembly.
//
#if ODBC_CLIENT
[assembly: AssemblyTitle("OpenLink.Data.VirtuosoOdbcClient.Design")]
[assembly: AssemblyDescription("OpenLink.Data.VirtuosoOdbcClient.Design")]
[assembly: AssemblyProduct("OpenLink.Data.VirtuosoOdbcClient.Design")]
#elif CLIENT
[assembly: AssemblyTitle("OpenLink.Data.VirtuosoClient.Design")]
[assembly: AssemblyDescription("OpenLink.Data.VirtuosoClient.Design")]
[assembly: AssemblyProduct("OpenLink.Data.VirtuosoClient.Design")]
#else
[assembly: AssemblyTitle("OpenLink.Data.Virtuoso.Design")]
[assembly: AssemblyDescription("OpenLink.Data.Virtuoso.Design")]
[assembly: AssemblyProduct("OpenLink.Data.Virtuoso.Design")]
#endif
[assembly: AssemblyConfiguration("")]
[assembly: AssemblyCompany("OpenLink Software")]
[assembly: AssemblyCopyright("Copyright (C) 1998-2013 OpenLink Software. All rights reserved.")]
[assembly: AssemblyTrademark("")]
[assembly: AssemblyCulture("")]		

[assembly: AssemblyVersion(
OpenLink.Data.Virtuoso.VirtuosoConstants.AssemblyVersion
)]

[assembly: AssemblyDelaySign(false)]
#if !ADONET2
#if FROMIDE
[assembly: AssemblyKeyFile(@"..\..\VirtuosoClient.snk")]
#else
[assembly: AssemblyKeyFile(@"VirtuosoClient.snk")]
#endif
#endif
[assembly: AssemblyKeyName("")]
