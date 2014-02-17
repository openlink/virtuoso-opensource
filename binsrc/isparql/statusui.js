/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2009-2014 OpenLink Software
 *
 *  See LICENSE file for details.
 *
 */

if (typeof iSPARQL == 'undefined') iSPARQL = {};

iSPARQL.StatusUI = {
    hide: function () {
	OAT.Dom.hide("splash");
    },
    show: function () {
	OAT.Dom.show("splash");
    },
    statMsg: function(msg, isMain) {
	if (isMain) 
	    $("statMsgMain").innerHTML = msg;
	else
	    $("statMsgElem").innerHTML = msg;
    },
    init: function () {
	OAT.Dom.show ("splashThrobber");
    },
    errMsg: function (msg) {
	$("statMsgErr").innerHTML = msg;
    },
    addCustomTemplate: function (div) {
	var c = this.newTplCtr ();
	OAT.Dom.append ([c, div]);
    },
    newTplCtr: function () {
	var custCtr = OAT.Dom.create ("div",{className:"statusUICustCtr"});
	OAT.Dom.append(["statMsgMain",custCtr]);
	return custCtr;
    },
    absorb: function (ctr) {
	var c = OAT.Dom.create ("div", {className: "statusUIAbsorbedCtr"})
	OAT.Dom.unlink (ctr);
	OAT.Dom.append ([c, ctr]);
    }
};

iSPARQL.ErrorUI = {
    hide: function () {},
    clear: function () {},
    fromGenericXhr: function () {},
    fromSparqlQuery: function () {}
};
