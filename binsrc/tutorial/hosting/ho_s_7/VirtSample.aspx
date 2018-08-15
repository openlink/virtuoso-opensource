<%@ Page Language="C#" Debug="true" %>
<!--
 -  
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -  
 -  Copyright (C) 1998-2018 OpenLink Software
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
 -  
-->
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="OpenLink.Data.Virtuoso" %>

<html>
<script language="C#" runat="server">

    protected void Page_Load(Object sender, EventArgs e)
    {
        VirtuosoConnection myConnection = new VirtuosoConnection(ConfigurationSettings.AppSettings["connectionStringDg"]);
        VirtuosoDataAdapter myCommand = new VirtuosoDataAdapter("select * from Customers", myConnection);

        DataSet ds = new DataSet();
        myCommand.Fill(ds, "Customers");

        MyDataGrid.DataSource=ds.Tables["Customers"].DefaultView;
        MyDataGrid.DataBind();
    }

</script>

<body>

  <h3><font face="Verdana">Simple Select to a DataGrid Control</font></h3>

  <ASP:DataGrid id="MyDataGrid" runat="server"
    Width="700"
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

