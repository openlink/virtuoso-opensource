Readme for Curtype
==================

Setting up the test environment
===============================

This test requires a PC box with any of MS Windows 98, Windows ME,
Windows NT 4.0 SP3 or later, or Windows 2000 operating systems.

The box has to run a Virtuoso server with the Demo database loaded.
Alternatively, a Virtuoso server may run on a different box. In that
case, Virtuoso client tools, in particular its ODBC driver,
still have to be installed on the test box.

VIRTOLEDB is contained within the "virtoledb.dll" file. This
file is installed into the bin directory and is automatically
registered during installation by the command:
 regsvr32.exe virtoledb.dll

Its is not necessary to register again.

Using CurTypes
==============

The CurTypes test is located in the directory:
<install directory>/samples/oledb/curtypes

This is a Visual Basic application. It's sources are in the files
"curtypes.frm", "curtypes.frx", and "curtypes.vbp". The
executable is in the file "curtypes.exe".

This program does a test of all combinations of cursor and lock
type properties of ADO rowset objects. It retrieves all rows from
the Demo.demo.Orders table. It also allows comparison of results
obtained from using VIRTOLEDB and MS OLE DB provider for ODBC 
(MSDASQL) working through the Virtuoso ODBC driver.

The Provider combo-box allows a choice between VIRTOLEDB and MSDASQL.
The Data Source text box allows entry of host name and the port
number of the Virtuoso server in the form "host:port". The Cursor
Type and Lock Type combo-boxes permit selection of the
corresponding ADO properties. The Run button starts the test and the
Stop button allows the test to be interrupted.

The test displays the time spent on the row retrieving.
