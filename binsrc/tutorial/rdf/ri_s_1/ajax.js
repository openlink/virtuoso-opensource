/*
  init ajax for IE & Mozilla
*/
function initRequest ()
{
  try {
    xmlhttp = new ActiveXObject("Msxml2.XMLHTTP");
  } catch (e) { }

  if (xmlhttp == null) {
    try {
      xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
    } catch (e) { }
  }
  // Gecko / Mozilla / Firefox
  if (xmlhttp == null)
    xmlhttp = new XMLHttpRequest();
  return xmlhttp;
}

var xmlhttp = initRequest ();
var timer = null;
var processID = null;


function showObject(id)
{
  var obj = document.getElementById(id);
  if (obj != null) {
    obj.style.display="";
    obj.visible = true;
  }
}

function hideObject(id)
{
  var obj = document.getElementById(id);
  if (obj != null) {
    obj.style.display="none";
    obj.visible = false;
  }
}


function initState ()
{
  var URL = 'ajax.vsp?sa=init';
  var rdf_url;
  var mt;
  processID = document.getElementById ("PID").value;
  rdf_url = document.getElementById ("url").value;
  mt = document.getElementById ("mt1").checked;

  showProgress ();
  xmlhttp.open("GET", URL+"&id=" + processID + "&url=" + escape (rdf_url) + "&mt=" + mt, true);
  xmlhttp.onreadystatechange = function() {
    if (xmlhttp.readyState == 4) {
      timer = setTimeout("checkState()", 500);
    }
  }
  xmlhttp.setRequestHeader("Pragma", "no-cache");
  xmlhttp.send("");
}

function checkState()
{
  var URL = 'ajax.vsp?sa=state';
  xmlhttp.open("GET", URL+"&id="+processID, true);
  xmlhttp.onreadystatechange = function() {
    if (xmlhttp.readyState == 4) {
      var rc;

      // progressIndex
      try {
        rc = xmlhttp.responseText;
      } catch (e) { }

      if (rc != null)
      {
        rc = rc.replace(/\r/g, "");
        rc = rc.replace(/\n/g, "");
        rc = rc.replace(/\r\n/g, "");
      };

      if (rc == 'importing' && timer != null) {
        setTimeout("checkState()", 500);
      } else {
        timer = null;
      }
      if (timer != null)
        showProgress ();
      else
        showMsg (rc);
    }
  }
  xmlhttp.setRequestHeader("Pragma", "no-cache");
  xmlhttp.send("");
}

function showProgress ()
{
  var obj = document.getElementById ("msg");
  obj.innerHTML = '<img src="wait_16.gif" border="0"/> Please wait...';
}

function showMsg (msg)
{
  var obj = document.getElementById ("msg");
  obj.innerHTML = msg;
}
