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
  </head>
  <body>
    <h1>WebID Verification Demo - PHP</h1>
    <div>
      This will check your X.509 Certificate's WebID  watermark. <br/>Also note this service supports ldap, http, mailto, acct scheme based WebIDs.
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
