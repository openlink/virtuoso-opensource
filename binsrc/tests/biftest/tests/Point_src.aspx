<%@ Page Language="C#" Debug="true" %>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2013 OpenLink Software
 -
 -  This project is free software; you can redistribute it and/or modify it
 -  under the terms of the GNU General Public License as published by the
 -  Free Software Foundation; only version 2 of the License, dated June 1991.
 -
 -  This program is distributed in the hope that it will be useful, but
 -  WITHOUT ANY WARRANTY; without even the implied warranty of
 -  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 -  General Public License for more details.
 -
 -  You should have received a copy of the GNU General Public License along
 -  with this program; if not, write to the Free Software Foundation, Inc.,
 -  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 -
-->
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="OpenLink.Data.Virtuoso" %>

<html>
<script language="C#" runat="server">

    protected void Page_Load(Object sender, EventArgs e)
    {
        VirtuosoConnection myConnection = new VirtuosoConnection("HOST=localhost:PORT;UID=dba;PWD=dba;Database=DB");
        VirtuosoDataAdapter myCommand = new VirtuosoDataAdapter("select s.name from Supplier s where s.location.\"distance\" (\"Point\" (4, 4)) < 3", myConnection);

        DataSet ds = new DataSet();
        myCommand.Fill(ds, "Supplier");

        MyDataGrid.DataSource=ds.Tables["Supplier"].DefaultView;
        MyDataGrid.DataBind();
    }

</script>

<body>

  <h3><font face="Verdana">select s.name from CLR..Supplier s where s.location."distance" (CLR.."Point" (4, 4)) &lt; 3</font></h3>

  <ASP:DataGrid id="MyDataGrid" runat="server"
    BackColor="#ccccff"
    BorderColor="black"
    ShowFooter="false"
    CellPadding=3
    CellSpacing="0"
    Font-Name="Verdana"
    Font-Size="8pt"
    HeaderStyle-BackColor="#aaaadd"
    EnableViewState="false"
  />

</body>
</html>

