var featureList = ["slidebar", "resize", "ajax", "json"];
var timer = null;
var x = function (data) 
   {
     var o = null;
     var div = $('status');
     try 
       {
	 o = OAT.JSON.parse(data);
       }
     catch (e)
       {
	 o = null;
       }
     if (o && o.result != 0)
       {
	 div.innerHTML = "Status: " + o.cartridge + ", " + o.time + "sec. in queue";
       } 
     if (o && o.result == 0)
       {
	 div.innerHTML = 'Status: done';
	 if (timer) clearTimeout (timer);
       } 
   }
function getStatus ()
   {
     OAT.AJAX.GET ("/about/queue/status?uri=" + uri, false, x);
     timer = setTimeout ("getStatus ()", 10000);
   }

function init() {
  var slb = new OAT.Slidebar ("slb", {imgPrefix: "statics/", autoClose: false, width: 500, handleWidth: 15, handleOpenImg: "whats_this_open_hndl_15w.png", handleCloseImg: "whats_this_close_hndl_15w.png"});
  init_long_list ();
  init_long_literals();
  var restrict = function(x,y) { return (x < 25); }
  if ($('x_content'))
    {
      OAT.Resize.create($('x_content'),$('x_content'),OAT.Resize.TYPE_Y,restrict);
    }
  getStatus ();
}

var long_literal_counter = 0;
var long_literal_spans = {};
var long_literal_texts = {};
function init_long_literals() {
    var spans = document.getElementsByTagName('span');
    for (i = 0; i < spans.length; i++) {
        if (spans[i].className != 'literal') continue;
        var span = spans[i];
        var textNode = span.firstChild;
        var text = textNode.data;
        if (!text || text.length < 300) continue;
        var match = text.match(/([^\0]{150}[^\0]*? )([^\0]*)/);
        if (!match) continue;
        span.insertBefore(document.createTextNode(match[1] + ' ... '), span.firstChild);
        span.removeChild(textNode);
        var link = document.createElement('a');
        link.href = 'javascript:expand(' + long_literal_counter + ');';
        link.appendChild(document.createTextNode('\u00BBmore\u00BB'));
        link.className = 'expander';
        span.insertBefore(link, span.firstChild.nextSibling);
        long_literal_spans[long_literal_counter] = span;
        long_literal_texts[long_literal_counter] = textNode;
        long_literal_counter = long_literal_counter + 1;
    }
}

var long_ul_counter = 0;
var long_uls = {};
var long_uls_nodes = {};
function init_long_list()
{
    var uls = document.getElementsByTagName('ul');
    for (i = 0; i < uls.length; i++)
      {
	if (uls[i].className != 'obj') continue;
	if (uls[i].childNodes.length <= 10) continue;
	var ul = uls[i];
	long_uls_nodes[long_ul_counter] = ul.cloneNode (true);
	//alert (long_ul_counter + ' ' + ul.childNodes.length);
	while (ul.childNodes.length > 10)
	  {
	    ul.removeChild (ul.lastChild);
	  }
	var link = document.createElement('a');
	link.href = 'javascript:expand_ul(' + long_ul_counter + ');';
	link.appendChild(document.createTextNode('\u00BBmore\u00BB'));
	link.className = 'expander';
	ul.insertBefore(link, ul.lastChild.nextSibling);
	long_uls[long_ul_counter] = ul;
	long_ul_counter++;
      }

}

function expand_ul(n) {
    var ul = long_uls[n];
    var copy = long_uls_nodes[n];
    while (ul.childNodes.length > 0)
      ul.removeChild (ul.lastChild);
    //alert (n + ' ' + copy.childNodes.length);
    for (i = 0; i < copy.childNodes.length; i++)
      ul.appendChild (copy.childNodes[i].cloneNode (true));
    var link = document.createElement('a');
    link.href = 'javascript:collapse_ul(' + n + ');';
    link.appendChild(document.createTextNode('\u00ABless\u00AB'));
    link.className = 'expander';
    ul.insertBefore(link, ul.lastChild.nextSibling);
}

function collapse_ul(n) {
    var ul = long_uls[n];
    var copy = long_uls_nodes[n];
    while (ul.childNodes.length > 0)
      ul.removeChild (ul.lastChild);
    for (i = 0; i < 10; i++)
      ul.appendChild (copy.childNodes[i].cloneNode (true));
    var link = document.createElement('a');
    link.href = 'javascript:expand_ul(' + n + ');';
    link.appendChild(document.createTextNode('\u00BBmore\u00BB'));
    link.className = 'expander';
    ul.insertBefore(link, ul.lastChild.nextSibling);
}

function expand(i) {
    var span = long_literal_spans[i];
    span.removeChild(span.firstChild);
    span.removeChild(span.firstChild);
    span.insertBefore(long_literal_texts[i], span.firstChild);
}

/* -- Tabbed interface support -- */

function Show(objid)
{
  var obj = document.getElementById(objid);
  obj.style.display="";
  obj.visible = true;
}

function Hide(objid)
{
  var obj = document.getElementById(objid);
  obj.style.display="none";
  obj.visible = false;
}

function toggle_tab(div_id)
{
  var obj = document.getElementById('tab_'+div_id);
  var ul_obj = document.getElementById('navlist');
  var nodeList = returnListOfNodes(ul_obj.childNodes);
  for(var i=0; i < nodeList.length;i++)
  {
    returnListOfNodes(nodeList[i].childNodes)[0].className = "";
  };
  obj.className = "current";

  var ContentDivs = Array(
    document.getElementById('attributes'),
    document.getElementById('attributeof'));

  for (var i = 0; i < ContentDivs.length; i++)
  {
    if (ContentDivs[i].id == div_id && ContentDivs[i].style.display == 'none')
      Show(ContentDivs[i].id);
    else if (ContentDivs[i].id != div_id && ContentDivs[i].style.display != 'none')
      Hide(ContentDivs[i].id);
  };
}

function returnListOfNodes(nodeList)
{
  var list = new Object();
  var x = 0;
  for (var i = 0; i < nodeList.length; i++)
  {
    if(nodeList[i].nodeType == 1)
    {
      list[x++] = nodeList[i];
    }
  }
  list.length = x--;
  return list;
}

/* -- End: Tabbed interface support -- */
