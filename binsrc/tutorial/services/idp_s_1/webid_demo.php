<?php
  function apiURL()
  {
    $pageURL = $_SERVER['HTTPS'] == 'on' ? 'https://' : 'http://';
    $pageURL .= $_SERVER['SERVER_PORT'] <> '80' ? $_SERVER['SERVER_NAME'] . ':' . $_SERVER['SERVER_PORT'] : $_SERVER['SERVER_NAME'];
    return $pageURL . '/tutorial/webid/webid_demo.php';
  }

	$_webid = isset ($_REQUEST['webid']) ? $_REQUEST['webid'] : '';
	$_error = isset ($_REQUEST['error']) ? $_REQUEST['error'] : '';
	$_action = isset ($_REQUEST['go']) ? $_REQUEST['go'] : '';
  if (($_webid == '') && ($_error == ''))
  {
    if ($_action <> '')
    {
      if ($_SERVER['HTTPS'] <> 'on')
      {
        $_error = 'No certificate';
      }
      else
      {
        $_callback = apiURL();
        $_url = sprintf ('https://id.myopenlink.net/ods/webid_verify.vsp?callback=%s', urlencode($_callback));
        header (sprintf ('Location: %s', $_url));
        return;
      }
    }
  }
?>
<html>
  <head>
    <title>WebID Verification Demo - PHP</title>
    <style type="text/css">
      body {
      	background-color: white;
      	color: black;
      	font-size: 10pt;
      	font-family: Verdana, Helvetica, sans-serif;
      }
      ul {
        font-family: Verdana, Helvetica, sans-serif;
        list-style-type: none;
      }
    </style>
  </head>
  <body>
    <h1>WebID Verification Demo - PHP</h1>
    <div>
      This will check the WebID watermark in your X.509 Certificate.<br/><br/>
      This service supports WebIDs based on the following URI schemes (more to come):
      <ul>
      	<li>* <b>acct</b>, e.g: <span style="font-size: 80%; color: #1DA237;">acct:ExampleUser@id.example.com</span></li>
      	<li>* <b>http</b>, e.g: <span style="font-size: 80%; color: #1DA237;">http://id.example.com/person/ExampleUser#this</span></li>
      	<li>* <b>ldap</b>, e.g: <span style="font-size: 80%; color: #1DA237;">ldap://ldap.example.com/o=An%20Example%5C2C%20Inc.,c=US</span></li>
      	<li>* <b>mailto</b>, e.g: <span style="font-size: 80%; color: #1DA237;">mailto:ExampleUser@id.example.com</span></li>
      </ul>
    </div>
    <br/>
    <br/>
    <div>
      <form method="get">
        <input type="submit" name="go" value="Check"/>
      </form>
    </div>
    <?php
      if (($_webid <> '') || ($_error <> ''))
      {
    ?>
      <div>
      	The return values are:
  	    <ul>
          <?php
            if ($_webid <> '')
            {
          ?>
  	      <li>WebID -  <?php print ($_webid); ?></li>
  	      <li>Timestamp in ISO 8601 format - <?php print ($_REQUEST['ts']); ?></li>
          <?php
            }
            if ($_error <> '')
            {
          ?>
  	      <li>Error - <?php print ($_error); ?></li>
          <?php
            }
          ?>
  	    </ul>
      </div>
    <?php
      }
    ?>
  </body>
</html>
