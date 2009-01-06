/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2009 OpenLink Software
 *
 *  See LICENSE file for details.
 */
var YAHOO=window.YAHOO||{};
var __yload_count = 0;

YAHOO.namespace=function(_1){
        if(!_1||!_1.length){
                return null;
        }
        var _2=_1.split(".");
        var _3=YAHOO;
        for(var i=(_2[0]=="YAHOO")?1:0;i<_2.length;++i){
                _3[_2[i]]=_3[_2[i]]||{};
                _3=_3[_2[i]];
        }
return _3;
};
YAHOO.namespace("util");
YAHOO.namespace("widget");
YAHOO.namespace("example");

// var YMAPPID = "";
function _ywjs(inc) { 
	var h = document.getElementsByTagName("head")[0];
	var s = document.createElement("script");
	s.src = inc;
	h.appendChild(s);

}
_ywjs('http://us.js2.yimg.com/us.js.yimg.com/lib/common/utils/2/dom_2.0.1-b2.js');
_ywjs('http://us.js2.yimg.com/us.js.yimg.com/lib/common/utils/2/event_2.0.0-b2.js');
_ywjs('http://us.js2.yimg.com/us.js.yimg.com/lib/common/utils/2/dragdrop_2.0.1-b4.js');
_ywjs('http://us.js2.yimg.com/us.js.yimg.com/lib/common/utils/2/animation_2.0.1-b2.js');
//		_ywjs('http://us.js2.yimg.com/us.js.yimg.com/lib/map/js/api/ymapapi_3_0_3_17.js');
function ymap_last_include() {
	if (window.YAHOO.util.Event && window.YAHOO.util.Anim && window.YAHOO.util.Dom && window.YAHOO.util.DragDrop) {
		/* include main library only after event is loaded */
		OAT.Loader.include("ymapapi.js");
	} else if (__yload_count < 5) {
		__yload_count = __yload_count + 1;
		setTimeout(ymap_last_include,1000);
	} else {
		OAT.Loader.featureLoaded("ymaps"); 
	}
}

setTimeout(ymap_last_include,1000);
/* no pending count here - decrease after ymapapi.js was included */
