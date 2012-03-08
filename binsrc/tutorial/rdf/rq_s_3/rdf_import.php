<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<!--
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2012 OpenLink Software
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
<html>
<head>
  <link href="../../web/demo.css" type="text/css" rel="stylesheet"/>
  <script type="text/javascript" src="ajax.js"><![CDATA[ ]]></script>
</head>
<pre>
<?php
    $_dsn="LocalVirtuosoTutorialRQS3";
    $_user="demo";
    $_pass="demo";

    print "Connecting... ";
    $handle=odbc_connect ($_dsn, $_user, $_pass);

    if(!$handle)
    {
      print "<p>Failure to connect to DSN [$DSN]: <br />";
      odbc_errormsg();
    }
    else
    {
     print "done\n";

     $resultset=odbc_exec ($handle, "select DB.DBA.rq_s_3_workeruuid()");
     $_pid=odbc_result ($resultset, 1);
     odbc_close($handle);
    }

    if(isset($_POST['url']) && $_POST['url']<>"")
      $_url=$_POST['url'];
    else
      $_url="http://www.w3.org/People/Berners-Lee/card";
 ?>
</pre>
<body>
  <h1> RDF Import using PHP hosting</h1>
  <div id="msg"><![CDATA[&nbsp;]]></div>
  <div class="tableentry">
    <form name="form1" method="post" type="simple">
      <input type="hidden" id="PID" name="PID"  value="<?php print($_pid); ?>"/>
      <fieldset>
        <field>
          <label for="url">RDF source URL</label>
          <br />
          <input type="text"  size="80" name="url" id="url" value="<?php print($_url); ?>" />
          <br />
          <input type="checkbox" name="mt1" value="1" id="mt1"/>
	  <label for="mt1">Use multi-threaded functions to import RDF</label>
          <br />
          <input type="button" name="submit2" value="Import" onclick="javascript: initState ();" />
	    </fieldset>
	</form>
    </div>
</body>
</html>
