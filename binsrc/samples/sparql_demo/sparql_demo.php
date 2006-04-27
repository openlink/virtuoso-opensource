<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
	<head>
		<title>Virtuoso RDF Store - Demo</title>
		<meta name="Robots" content="index,nofollow" />
<style type="text/css">
<![CDATA[
body { font-size:0.9em; }
#pageAreaOuter { width:90%; margin:10px auto 10px auto; text-align:center; }
p { text-align:left; }
#formArea { text-align:left; }
#formArea textarea{ width:95%; height:175px; border:1px solid #999; border:none; }
.formButtons { text-align:left; }
.formButtons input { border:1px solid #666; padding:10px; margin:5px 5px 5px 2px; background-color:#f6f6f6; }
fieldset { border: 1px solid #aaa; padding:10px; margin-top:20px; }
fieldset legend{ font-weight:bold; }
.serverWinIframe { visibility:hidden; width:1px; height:1px; padding:1px; }
.formItem { text-align:left; padding:0px; margin:0px; }
.formItemLeftCol { clear:both; float:left; width:240px; text-align:right; margin-right:20px; margin-bottom:20px; }
.formItemRightCol { float:left; }
.formItemRightCol input, .formItemRightCol select { width:200px; border:1px solid #999; font-size:14px; }
div.indent{ margin-left:10px; }
pre{ padding:10px 5px 10px 5px; border:1px dotted #ccc; line-height:1.2em; background-color:#f3f3f3; }
blockquote{ margin:15px 5px 5px 5px; padding:5px 5px 5px 5px; border:1px dotted #ccc; line-height:1.2em; background-color:#f3f3f3; font-style:italic; }
.small{ font-size:0.9em; }
img { border: 0; opacity:1; -moz-opacity:1; -khtml-opacity:1; filter:alpha(opacity=100); }
.center{ text-align:center; }
.clb{/* clear both */ clear:both; height:1px; margin:0px; padding:1px; font-size:0px; line-height:0.1em; }
.abbr{ cursor:help; }
.op100{ opacity:1; -moz-opacity:1; -khtml-opacity:1; filter:alpha(opacity=100); }
.op90{ opacity:0.9; -moz-opacity:0.9; -khtml-opacity:0.9; filter:alpha(opacity=90); }
.op50{ opacity:0.5; -moz-opacity:0.5; -khtml-opacity:0.5; filter:alpha(opacity=50); }
.op25{ opacity:0.25; -moz-opacity:0.25; -khtml-opacity:0.25; filter:alpha(opacity=25); }
h1, h2, h3, h4, h5, h6 { font-weight: bold; letter-spacing:0.05em; margin-top:0px; margin-bottom:0.2em; }
h1{ margin-top:0px; margin-bottom:0.5em; font-size:1.25em; }
h2{ font-size:1.1em; }
h3{ font-size:1em; }
h4{ font-size:1em; letter-spacing:0em; margin-top:0.2em; }
body { font-family: Verdana, Helvetica, sans-serif; color:#666; }
p{ color:#666; line-height:1.3em; margin-top:5px; margin-bottom:5px; margin-left:5px; }
a { color: #999; }
a:hover { color: #666; }
div.paragraph, div.justifiedParagraph, div.rightAlignedParagraph, div.centeredParagraph{ width:99%; color:#666; line-height:1.3em; margin-top:5px; margin-bottom:5px; margin-left:5px; }
div.centeredParagraph{ text-align:center; }
div.justifiedParagraph{	text-align:justify; }
div.rightAlignedParagraph{ text-align:right; }
.abbr{ border-bottom:1px dotted #999; }
input{ font-size:11px; }
.serverWinIframe{ width:1px; height:1px; visibility:hidden; margin:0px; padding:0px; border:none; }
]]>
</style>
	</head>
<?php
    if(isset($_POST['q']) && $_POST['q']<>"")
      $query=$_POST['q'];
    else
      $query="sparql select distinct ?p where { graph ?g { ?s ?p ?o } }";

    if(isset($_POST['dsn']) && $_POST['dsn']<>"")
      $_dsn=$_POST['dsn'];
    else
      $_dsn="Local Virtuoso Demo";

    if(isset($_POST['user']) && $_POST['user']<>"")
      $_user=$_POST['user'];
    else
      $_user="dba";

    if(isset($_POST['pass']) && $_POST['pass']<>"")
      $_pass=$_POST['pass'];
    else
      $_pass="";
?>
	<body>
		<BODY TEXT="#000000" LINK="#0000CC" VISITED="#3300CC" BGCOLOR="#EEEEEE" TOPMARGIN=0>
		<div id="pageAreaOuter">
			<h1>Virtuoso RDF Store - Demo</h1>
			<div id="formArea">
				<form id="queryForm" name="queryForm" method="post" action="sparql_demo.php" enctype="application/x-www-form-urlencoded">

					<input type="hidden" name="run" value="1" />

					<fieldset>
						<legend>SPARQL Query</legend>
						<div>
							<span>
								<textarea  COLS="80" ROWS="15" id="q" name="q"><?php print ($query); ?>
								</textarea>
							</span>
						</div>
					</fieldset>
					<fieldset>
						<legend>DSN info</legend>
						<div>
							<span>
						    DSN: <input type="text" size="25" name="dsn" value="<?php print ($_dsn); ?>">
							</span>
						</div>
						<div>
							<span>
						    User: <input type="text" size="25" name="user" value="<?php print ($_user); ?>">
							</span>
						</div>
						<div>
							<span>
						    Pass: <input type="password" size="25" name="pass" value="<?php print ($_pass); ?>">
							</span>
						</div>
					</fieldset>

					<div class="formButtons">
						<input type="submit" value="Run query" />
					</div>

					<fieldset>
						<legend>Result</legend>
						<pre>
<?php
    if(isset($_POST['q']) && $_POST['q']<>"")
     $query=$_POST['q'];
    print "Results:\n";
    print "<p>Connecting... ";
    $handle=odbc_connect ($dsn, $_user, $_pass);

    if(!$handle)
    {
	print "<p>Failure to connect to DSN [$DSN]: <br />";
	odbc_errormsg();
    }
    else
    {
	print "done</p>\n";
	$resultset=odbc_exec ($handle, "$query");
	odbc_result_all($resultset, "border=2");
	odbc_close($handle);
    }
 ?>
						</pre>
					</fieldset>
				</form>

			</div>
		</div>
	</body>
</html>
