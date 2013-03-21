<?php 
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2013 OpenLink Software
#  
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#  
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#  
#  
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"> 

<?php require('.sanep.php'); ?>

<html>
<head>
<title>OpenLink Virtuoso test of ODBC access through PHP hosting</title>
</head>

<body>

<h1>Testing ODBC connectivity from PHP hosted within Virtuoso</h1>

<hr />

<?php
# set global variables based on the form thing - see `register global
# variables' and PHP security updates
$query=$_POST['query'];
$uid=$_POST['uid'];
$passwd=$_POST['passwd'];
$listtables=$_POST['listtables'];
$DSN=$_POST['DSN'];
$exec=$_POST['exec'];
?>

<p>Enter the parameters for your query here:</p>

<form action="odbc-sample.php" method="post"> 
<div> 
<span class="caption">DSN</span> 
<input type="text" name="DSN" value="<?php
  print ($DSN<>"")?$DSN:"Local Virtuoso Tutorial HO-S-30"
?>" /> 

<span class="caption">UserID</span>
<input type="text" name="uid" value="<?php print ($uid<>"")?$uid:"demo" ?>" />

<span class="caption">Password</span>
<input type="password" name="passwd" value="demo" />
</div>

<div>
<span class="caption">Query</span> 
<input type="text" name="query" value="<?php
  print ($query<>"")?$query:"select top 100 * from Demo..Customers"
?>" /> 
</div>
<div>
<input type="submit" name="exec" value="Execute query" />
or
<input type="submit" name="listtables" value="List Tables" />
</div>
</form>

<hr />

<?php
if($query<>"" && $DSN<>"" && $exec!=NULL) {
    
  if(sanep($query)) {

    print "<h2>Results:</h2>\n";
    print "<p>Connecting... ";
    $handle=odbc_connect ("$DSN", "$uid", "$passwd");

    if(!$handle) {
      print "<p>Uh-oh! Failure to connect to DSN [$DSN]: <br />";
      odbc_errormsg();
    }
    else {
      print "done</p>\n";
      $resultset=odbc_exec ($handle, "$query");
      odbc_result_all($resultset, "border=2");
      odbc_close($handle);
    }
  } else 
    print "<p>Sorry, that query has been disabled for security reasons</p>\n";
}

if($listtables!=NULL) {
  print "<h2>List of tables</h2>";
  print "<p>Connecting... ";
  $handle=odbc_connect ("$DSN", "$uid", "$passwd");
  print "done</p>\n";

  if(!$handle) {
    print "<p>Uh-oh! Failure to connect to DSN [$DSN]: <br />";
    odbc_errormsg();
  }
  else {
    $resultset=odbc_tables($handle);
    odbc_result_all($resultset, "border=2");
    odbc_close($handle);
  }
}
?>

</body>
</html>
