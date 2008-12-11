function init() {
	init_long_literals();
	init_long_list ();
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
    //alert (ul.childNodes.length);
}

function expand(i) {
    var span = long_literal_spans[i];
    span.removeChild(span.firstChild);
    span.removeChild(span.firstChild);
    span.insertBefore(long_literal_texts[i], span.firstChild);
}