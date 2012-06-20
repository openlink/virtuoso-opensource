<?php
  function parseUrl($url)
  {
    // parse the given URL
    $url = parse_url($url);
    if (!isset($url['port'])) {
      if ($url['scheme'] == 'http') {
        $url['port'] = 80;
      }
      elseif ($url['scheme'] == 'https') {
        $url['port'] = 443;
      }
    }
    if ($url['scheme'] == 'https')
      $url['scheme'] = 'ssl';

    elseif ($url['scheme'] == 'http')
      $url['scheme'] = 'tcp';

    $url['query'] = isset($url['query'])? $url['query']: '';
    $url['protocol'] = $url['scheme'] . '://';

    return $url;
  }
  function makeRequest($url, $headers) {
    // parse the given URL
    $content = "";
    $fp = fsockopen($url['protocol'] . $url['host'], $url['port'], $errno, $errstr, 30);
    if ($fp) {
      if (fwrite($fp, $headers)) {
        while (!feof($fp)) {
          $result .= fgets($fp, 128);
        }
        fclose($fp);

        // split the result header from the content
        $result = explode("\r\n\r\n", $result, 2);

        $header = isset($result[0]) ? $result[0] : '';
        $content = isset($result[1]) ? $result[1] : '';
      } else {
        fclose($fp);
      }
    }
    return $content;
  }
  function getRequest($url)
  {
    $url = parseUrl($url);
    $eol = "\r\n";
    $headers = "GET " . $url['path'] . "?" . $url['query'] . " HTTP/1.1" . $eol .
               "Host: " . $url['host'].":".$url['port'] . $eol .
               "Connection: close"  . $eol . $eol;
    return makeRequest ($url, $headers);
  }
  function apiURL()
  {
    $pageURL = $_SERVER['HTTPS'] == 'on' ? 'https://' : 'http://';
    $pageURL .= $_SERVER['SERVER_PORT'] <> '80' ? $_SERVER["SERVER_NAME"].":".$_SERVER["SERVER_PORT"] : $_SERVER['SERVER_NAME'];
    return $pageURL.'/ods/api';
  }
  function httpURL()
  {
    $pageURL = $_SERVER['HTTPS'] == 'on' ? 'https://' : 'http://';
    $pageURL .= $_SERVER['SERVER_PORT'] <> '80' ? $_SERVER['SERVER_NAME'] . ':' . $_SERVER['SERVER_PORT'] : $_SERVER['SERVER_NAME'];
    return $pageURL . '/ods/webid/webid_demo.php';
  }
	$_webid = isset ($_REQUEST['webid']) ? $_REQUEST['webid'] : '';
	$_error = isset ($_REQUEST['error']) ? $_REQUEST['error'] : '';
	$_action = isset ($_REQUEST['go']) ? $_REQUEST['go'] : '';
  if (($_webid == '') && ($_error == ''))
  {
    if ($_action <> '')
    {
      $_url = getRequest (sprintf ("%s/getDefaultHttps", apiURL()));
      $_url = sprintf ('https://%s/ods/webid_verify.vsp?callback=%s', $_url, urlencode(httpURL()));
      $_expiration = isset ($_REQUEST['expiration']) ? $_REQUEST['expiration'] : '';
      if ($_expiration == 'true')
        $_url .= '&expiration=true';

      header (sprintf ('Location: %s', $_url));
      return;
    }
  }
?>
<html>
  <head>
    <title>WebID Verification Demo</title>
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
      #qrcode {
        float: right;
        clear: right;
        margin-right: 20px;
      }
    </style>
  </head>
  <body>
    <h1>WebID Verification Demo</h1>
    <?php
      $_QR = getRequest (sprintf ("%s/qrcode?data=%s", apiURL(), urlencode(httpURL())));
      if ($_QR <> '')
      {
    ?>
    <div id="qrcode"><img alt="QRcode image" src="data:image/jpg;base64,<?php print ($_QR); ?>" /></div>
    <?php
      }
    ?>
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
    <div>
    	<a href="http://ods.openlinksw.com/wiki/ODS/ODSWebIDIdP">Help</a>
    </div>
    <br/>
    <br/>
    <div>
      <form method="get">
	      <input type="checkbox" value="true" name="expiration" id="expiration" />  <label for="expiration">Check Certificate Expiration</label><br />
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
	            $_proxyIri = getRequest (sprintf ("%s/iri2proxy?iri=%s", apiURL(), urlencode($_webid)));
          ?>
  	      <li>WebID -  <?php print (sprintf('<a href="%s">%s</a>', $_proxyIri, $_proxyIri)); ?></li>
  	      <li>Timestamp in ISO 8601 format - <?php print ($_REQUEST['ts']); ?></li>
          <?php
            }
            else if ($_error <> '')
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
