/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2009 OpenLink Software
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
    errMsg: function (msg) {
	$("statMsgErr").innerHTML = msg;
    }
};

iSPARQL.ErrorUI = {
    hide: function () {},
    clear: function () {},
    fromGenericXhr: function () {},
    fromSparqlQuery: function () {}
};
