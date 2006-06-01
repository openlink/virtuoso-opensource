/*==============================================================================

                             HTML2XHTML Converter 1.5
                             ========================
                       Copyright (c) 2004-2006 Vyacheslav Smolin


Author:
-------
Vyacheslav Smolin (http://www.richarea.com, http://html2xhtml.richarea.com,
re@richarea.com)

About the script:
-----------------
HTML2XHTML Converter (H2X) generates a well formed XHTML string from a HTML DOM
object.

Requirements:
-------------
H2X works in  MS IE 5.0 for Windows or above,  in Netscape 7.1,  Mozilla 1.3 or
above. It should work in all Mozilla based browsers.

Usage:
------
Please see description of function get_xhtml below.

Demo:
-----
http://html2xhtml.richarea.com/, http://www.richarea.com/demo/

License:
--------
Free for non-commercial using. Please contact author for commercial licenses.


==============================================================================*/


//add \n before opening tag
var need_nl_before = '|div|p|table|tbody|tr|td|th|title|head|body|script|comment|li|meta|h1|h2|h3|h4|h5|h6|hr|ul|ol|option|link|';
//add \n after opening tag
var need_nl_after = '|html|head|body|p|th|style|';

var re_comment = new RegExp();
re_comment.compile("^<!--(([a]|[^a])*)-->$");

var re_hyphen = new RegExp();
re_hyphen.compile("-$");


// Convert inner text of node to xhtml
// Call: get_xhtml(node);
//       get_xhtml(node, lang, encoding) -- to convert whole page
// other parameters are for inner usage and should be omitted
// Parameters:
// node - dom node to convert
// lang - document lang (need it if whole page converted)
// encoding - document charset (need it if whole page converted)
// need_nl - if true, add \n before a tag if it is in list need_nl_before
// inside_pre - if true, do not change content, as it is inside a <pre>
function get_xhtml(node, lang, encoding, need_nl, inside_pre) {

var i;
var text = '';
var children = node.childNodes;
var child_length = children.length;
var tag_name;
var do_nl = need_nl?true:false;
var page_mode = true;

	for (i=0;i<child_length;i++) {
		var child = children[i];

		//to prevent adding parts of html code twice in IE (thanks to Jorn Sjostrom)
		if (child.parentNode && String(node.tagName).toLowerCase() != String(child.parentNode.tagName).toLowerCase()) continue;

		switch (child.nodeType) {

			case 1: { //ELEMENT_NODE
				var tag_name = String(child.tagName).toLowerCase();

				if (tag_name == '') break;

				if (tag_name == 'meta') {
					var meta_name = String(child.name).toLowerCase();
					if (meta_name == 'generator') break;
				}

				//children nodes of <object> tags parsed incorrectly by ie-dom
				//so take their code and lowercase names of tags and attributes
				if (document.all && tag_name == 'object') {
					text += fix_object_code(child.outerHTML);
					continue;
				}

				if (!need_nl && tag_name == 'body') { //html fragment mode
					page_mode = false;
				}

				if (tag_name == '!') { //COMMENT_NODE in IE 5.0/5.5
					//get comment inner text
					var parts = re_comment.exec(child.text);

					if (parts) {
						//the last char of the comment text must not be a hyphen
						var inner_text = parts[1];
						text += fix_comment(inner_text);
					}
				} else {
					if (tag_name == 'html'){
						text = '<?xml version="1.0" encoding="'+encoding+'"?>\n<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">\n';
					}

					//inset \n to make code more neat
					if (need_nl_before.indexOf('|'+tag_name+'|') != -1) {
						if ((do_nl || text != '') && !inside_pre) text += '\n';
							else do_nl = true;
					}

					text += '<'+tag_name;

					//add attributes
					var attr = child.attributes;
					var attr_length = attr.length;
					var attr_value;

					var attr_lang = false;
					var attr_xml_lang = false;
					var attr_xmlns = false;

					var is_alt_attr = false;

					for (j=0;j<attr_length;j++) {
						var attr_name = attr[j].nodeName.toLowerCase();

						if (!attr[j].specified &&
							attr_name != 'selected' &&
							attr_name != 'style' &&
							attr_name != 'value') continue; //IE 5.0

						if (attr_name == 'selected' &&
							!child.selected ||
							attr_name == 'style' && //IE 5.0
							child.style.cssText == '') continue;

						if (attr_name == '_moz_dirty' ||
							attr_name == '_moz_resizing' ||
							tag_name == 'br' && attr_name == 'type' &&
							child.getAttribute('type') == '_moz') continue;

						var valid_attr = true;

						switch (attr_name) {
							case "style" :
								attr_value = child.style.cssText;
								break;
							case "class" :
								attr_value = child.className;
								break;
							case "http-equiv":
								attr_value = child.httpEquiv;
								break;
							case "noshade": //this set of choices will extend
							case "checked":
							case "selected":
							case "multiple":
							case "nowrap":
							case "disabled":
								attr_value = attr_name;
								break;
							default:
								try {
									attr_value = child.getAttribute(attr_name, 2);
								} catch (e) {
									valid_attr = false;
								}
						}

						//html tag attribs
						if (attr_name == 'lang') {
							attr_lang = true;
							attr_value = lang;
						}
						if (attr_name == 'xml:lang') {
							attr_xml_lang = true;
							attr_value = lang;
						}
						if (attr_name == 'xmlns') attr_xmlns = true;

						if (valid_attr) {
							//value attribute set to "0" is not handled correctly in Mozilla
							if (!(tag_name == 'li' && attr_name == 'value')) {
								text += ' '+attr_name+'="'+fix_attribute(attr_value)+'"';
							}
						}

						if (attr_name == 'alt') is_alt_attr = true;
					}

					if (tag_name == 'img' && !is_alt_attr) {
						text += ' alt=""';
					}

					if (tag_name == 'html') {
						if (!attr_lang) text += ' lang="'+lang+'"';
						if (!attr_xml_lang) text += ' xml:lang="'+lang+'"';
						if (!attr_xmlns) text += ' xmlns="http://www.w3.org/1999/xhtml"';
					}

					if (child.canHaveChildren || child.hasChildNodes()){
						text += '>';
						if (need_nl_after.indexOf('|'+tag_name+'|') != -1) {
//							text += '\n';
						}
						text += get_xhtml(child, lang, encoding, true,
					inside_pre||tag_name=='pre'?true:false);
						text += '</'+tag_name+'>';
					} else {

						//these tags must have closing tags
						//'a' included as otherwise Mozilla extends <a /> links
						//on content coming after the link, that is wrong
						if (tag_name == 'style' || tag_name == 'title' ||
							tag_name == 'script' || tag_name == 'textarea' ||
							tag_name == 'a') {

							text += '>';
							var inner_text;
							if (tag_name == 'script') {
								inner_text = child.text;
							}else inner_text = child.innerHTML;

							if (tag_name == 'style') {
								inner_text = String(inner_text).replace(/[\n]+/g,'\n');
							}

							text += inner_text+'</'+tag_name+'>';

						} else {
							text += ' />';
						}
					}

				}
				break;
			}
			case 3: { //TEXT_NODE
				if (!inside_pre) { //do not change text inside <pre> tag
					if (child.nodeValue != '\n') {
						text += fix_entities(fix_text(child.nodeValue));
					}
				} else text += child.nodeValue;
				break;
			}
			case 8: { //COMMENT_NODE
				text += fix_comment(child.nodeValue);
				break;
			}
			default:
				break;
		}
	}

	if (!need_nl && !page_mode) { //delete head and body tags from html fragment
			text = text.replace(/<\/?head>[\n]*/gi, "");
			text = text.replace(/<head \/>[\n]*/gi, "");
			text = text.replace(/<\/?body>[\n]*/gi, "");
	}

	return text;
}

//fix inner text of a comment
function fix_comment(text){

	//delete double hyphens from the comment text
	text = text.replace(/--/g, "__");

	if(re_hyphen.exec(text)){ //last char must not be a hyphen
		text += " ";
	}

	return "<!--"+text+"-->";
}

//fix content of a text node
function fix_text(text) {
	//convert <,> and & to the corresponding entities

	//change &lt; and &gt; or the next string convert their & chars
	var temp_text = String(text).replace(/\&lt;/g, "#h2x_lt").replace(/\&gt;/g, "#h2x_gt");
	temp_text = temp_text.replace(/\n{2,}/g, "\n").replace(/\&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\u00A0/g, "&nbsp;");
	return temp_text.replace(/#h2x_lt/g, "&lt;").replace(/#h2x_gt/g, "&gt;");
}

//fix content of attributes href, src or background
function fix_attribute(text) {
	//convert <,>, & and " to the corresponding entities

	//change &lt; and &gt; or the next string convert their & chars
	var temp_text = String(text).replace(/\&lt;/g, "#h2x_lt").replace(/\&gt;/g, "#h2x_gt");
	temp_text = temp_text.replace(/\&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\"/g, "&quot;");
	return temp_text.replace(/#h2x_lt/g, "&lt;").replace(/#h2x_gt/g, "&gt;");
}

//lowercase names of tags and its attributes - the best we can do for
//flash objects in IE
function fix_object_code(text) {
var temp = String(text);

	temp = temp.replace(/ style=/gi, ' style=');
	temp = temp.replace(/ codeBase=/gi, ' codebase=');
	temp = temp.replace(/ height=/gi, ' height=');
	temp = temp.replace(/ width=/gi, ' width=');
	temp = temp.replace(/ align=/gi, ' align=');
	temp = temp.replace(/ classid=/gi, ' classid=');
	temp = temp.replace(/ src=/gi, ' src=');
	temp = temp.replace(/ NAME=/gi, ' name=');
	temp = temp.replace(/ VALUE=/gi, ' value=');
	temp = temp.replace(/ quality=/gi, ' quality=');
	temp = temp.replace(/ TYPE=/gi, ' type=');
	temp = temp.replace(/ PLUGINSPAGE=/gi, ' pluginspage=');
	temp = temp.replace(/<OBJECT /gi, '<object ');
	temp = temp.replace(/<\/OBJECT>/gi, '</object>');
	temp = temp.replace(/<PARAM /gi, '<param ');
	temp = temp.replace(/<\/PARAM>/gi, '</param>');
	temp = temp.replace(/<EMBED /gi, '<embed ');
	temp = temp.replace(/<\/EMBED>/gi, '</embed>');

	return temp;
}

//fix entities, eg &euro;
function fix_entities(text) {
var i;
var ents = {
	8364 : "euro",
	402  : "fnof",
	8240 : "permil",
	352  : "Scaron",
	338  : "OElig",
	381  : "#381",
	8482 : "trade",
	353  : "scaron",
	339  : "oelig",
	382  : "#382",
	376  : "Yuml",
	162  : "cent",
	163  : "pound",
	164  : "curren",
	165  : "yen",
	166  : "brvbar",
	167  : "sect",
	168  : "uml",
	169  : "copy",

	170  : "ordf",
	171  : "laquo",
	172  : "not",
	173  : "shy",
	174  : "reg",
	175  : "macr",
	176  : "deg",
	177  : "plusmn",
	178  : "sup2",
	179  : "sup3",
	180  : "acute",
	181  : "micro",
	182  : "para",
	183  : "middot",
	184  : "cedil",
	185  : "sup1",
	186  : "ordm",
	187  : "raquo",
	188  : "frac14",
	189  : "frac12",

	190  : "frac34",
	191  : "iquest",
	192  : "Agrave",
	193  : "Aacute",
	194  : "Acirc",
	195  : "Atilde",
	196  : "Auml",
	197  : "Aring",
	198  : "AElig",
	199  : "Ccedil",
	200  : "Egrave",
	201  : "Eacute",
	202  : "Ecirc",
	203  : "Euml",
	204  : "Igrave",
	205  : "Iacute",
	206  : "Icirc",
	207  : "Iuml",
	208  : "ETH",
	209  : "Ntilde",

	210  : "Ograve",
	211  : "Oacute",
	212  : "Ocirc",
	213  : "Otilde",
	214  : "Ouml",
	215  : "times",
	216  : "Oslash",
	217  : "Ugrave",
	218  : "Uacute",
	219  : "Ucirc",
	220  : "Uuml",
	221  : "Yacute",
	222  : "THORN",
	223  : "szlig",
	224  : "agrave",
	225  : "aacute",
	226  : "acirc",
	227  : "atilde",
	228  : "auml",
	229  : "aring",

	230  : "aelig",
	231  : "ccedil",
	232  : "egrave",
	233  : "eacute",
	234  : "ecirc",
	235  : "euml",
	236  : "igrave",
	237  : "iacute",
	238  : "icirc",
	239  : "iuml",
	240  : "eth",
	241  : "ntilde",
	242  : "ograve",
	243  : "oacute",
	244  : "ocirc",
	245  : "otilde",
	246  : "ouml",
	247  : "divide",
	248  : "oslash",
	249  : "ugrave",
	250  : "uacute",
	251  : "ucirc",
	252  : "uuml",
	253  : "yacute",
	254  : "thorn",
	255  : "yuml",


	913  : "Alpha",
	914  : "Beta",
	915  : "Gamma",
	916  : "Delta",
	917  : "Epsilon",
	918  : "Zeta",
	919  : "Eta",
	920  : "Theta",
	921  : "Iota",
	922  : "Kappa",
	923  : "Lambda",
	924  : "Mu",
	925  : "Nu",
	926  : "Xi",
	927  : "Omicron",
	928  : "Pi",
	929  : "Rho",

	931  : "Sigma",
	932  : "Tau",
	933  : "Upsilon",
	934  : "Phi",
	935  : "Chi",
	936  : "Psi",
	937  : "Omega",

	8756 : "there4",
	8869 : "perp",

	945  : "alpha",
	946  : "beta",
	947  : "gamma",
	948  : "delta",
	949  : "epsilon",
	950  : "zeta",
	951  : "eta",
	952  : "theta",
	953  : "iota",
	954  : "kappa",
	955  : "lambda",
	956  : "mu",
	957  : "nu",
	968  : "xi",
	969  : "omicron",
	960  : "pi",
	961  : "rho",
	962  : "sigmaf",
	963  : "sigma",
	964  : "tau",
	965  : "upsilon",
	966  : "phi",
	967  : "chi",
	968  : "psi",
	969  : "omega",

	8254 : "oline",
	8804 : "le",
	8260 : "frasl",
	8734 : "infin",
	8747 : "int",
	9827 : "clubs",
	9830 : "diams",
	9829 : "hearts",
	9824 : "spades",
	8596 : "harr",
	8592 : "larr",
	8594 : "rarr",
	8593 : "uarr",
	8595 : "darr",
	8220 : "ldquo",
	8221 : "rdquo",
	8222 : "bdquo",
	8805 : "ge",
	8733 : "prop",
	8706 : "part",
	8226 : "bull",
	8800 : "ne",
	8801 : "equiv",
	8776 : "asymp",
	8230 : "hellip",
	8212 : "mdash",
	8745 : "cap",
	8746 : "cup",
	8835 : "sup",
	8839 : "supe",
	8834 : "sub",
	8838 : "sube",
	8712 : "isin",
	8715 : "ni",
	8736 : "ang",
	8711 : "nabla",
	8719 : "prod",
	8730 : "radic",
	8743 : "and",
	8744 : "or",
	8660 : "hArr",
	8658 : "rArr",
	9674 : "loz",
	8721 : "sum",

	8704 : "forall",
	8707 : "exist",
	8216 : "lsquo",
	8217 : "rsquo",
	161  : "iexcl",

// other entities
	977  : "thetasym",
	978  : "upsih",
	982  : "piv",
	8242 : "prime",
	8243 : "Prime",
	8472 : "weierp",
	8465 : "image",
	8476 : "real",
	8501 : "alefsym",
	8629 : "crarr",
	8656 : "lArr",
	8657 : "uArr",
	8659 : "dArr",
	8709 : "empty",
	8713 : "notin",
	8727 : "lowast",
	8764 : "sim",
	8773 : "cong",
	8836 : "nsub",
	8853 : "oplus",
	8855 : "otimes",
	8901 : "sdot",
	8968 : "lceil",
	8969 : "rceil",
	8970 : "lfloor",
	8971 : "rfloor",
	9001 : "lang",
	9002 : "rang",
	710  : "circ",
	732  : "tilde",
	8194 : "ensp",
	8195 : "emsp",
	8201 : "thinsp",
	8204 : "zwnj",
	8205 : "zwj",
	8206 : "lrm",
	8207 : "rlm",
	8211 : "ndash",
	8218 : "sbquo",
	8224 : "dagger",
	8225 : "Dagger",
	8249 : "lsaquo",
	8250 : "rsaquo"
};

	var new_text = '';

var temp = new RegExp();
	temp.compile("[a]|[^a]", "g");

	var parts = text.match(temp);

	if (!parts) return text;
	for (i=0; i<parts.length; i++) {
		var c_code = parseInt(parts[i].charCodeAt());
		if (ents[c_code]) {
			new_text += "&"+ents[c_code]+";";
		} else new_text += parts[i];
	}

	return new_text;
}
