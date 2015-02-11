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
[assembly: AssemblyTitle("OpenLink.Data.VirtuosoOdbcClient")]
[assembly: AssemblyDescription("OpenLink.Data.VirtuosoOdbcClient")]
[assembly: AssemblyProduct("OpenLink.Data.VirtuosoOdbcClient")]
#elif CLIENT
[assembly: AssemblyTitle("OpenLink.Data.VirtuosoClient")]
[assembly: AssemblyDescription("OpenLink.Data.VirtuosoClient")]
[assembly: AssemblyProduct("OpenLink.Data.VirtuosoClient")]
#else
[assembly: AssemblyTitle("OpenLink.Data.Virtuoso")]
[assembly: AssemblyDescription("OpenLink.Data.Virtuoso")]
[assembly: AssemblyProduct("OpenLink.Data.Virtuoso")]
#endif
[assembly: AssemblyConfiguration("")]
[assembly: AssemblyCompany("OpenLink Software")]
[assembly: AssemblyCopyright("Copyright (C) 1998-2015 OpenLink Software. All rights reserved.")]
[assembly: AssemblyTrademark("")]
[assembly: AssemblyCulture("")]		

//
// Version information for an assembly consists of the following four values:
//
//      Major Version
//      Minor Version 
//      Build Number
//      Revision
//
// You can specify all the values or you can default the Revision and Build Numbers 
// by using the '*' as shown below:

[assembly: AssemblyVersion(
#if ODBC_CLIENT
OpenLink.Data.VirtuosoOdbcClient.VirtuosoConstants.AssemblyVersion
#elif CLIENT
OpenLink.Data.VirtuosoClient.VirtuosoConstants.AssemblyVersion
#else
OpenLink.Data.Virtuoso.VirtuosoConstants.AssemblyVersion
#endif
)]
// 3.5.2720.1 : GK 
//       - Added support for Icons. 
//       - Added a designer to VirtuosoDataAdapter, 
//         that will generate a DataSet as in http://developer.mimer.se/mpm/index.htm
// 3.5.2721.1 : GK
//       - added access to the connection string parts
//       - added a customer editor for the connection string as in bugzilla #7524
// 3.5.2721.2 : GK
//       - clear dependency for the installer

[assembly: AssemblyDelaySign(false)]
#if FROMIDE
[assembly: AssemblyKeyFile(@"..\..\VirtuosoClient.snk")]
#else
[assembly: AssemblyKeyFile(@"VirtuosoClient.snk")]
#endif
[assembly: AssemblyKeyName("")]
