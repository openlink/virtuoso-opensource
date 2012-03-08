/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2009-2012 OpenLink Software
 *
 *  See LICENSE file for details.
 *
 */

if (typeof iSPARQL == 'undefined') iSPARQL = {};

iSPARQL.Exception = function (where, parm, prev) {
    var self = this;
    this._where = where;
    this._parm = parm;
    this._longMsg = "";
    this._shortMsg = "";
    this._fatalFlag = false;
    this._iSPARQL_ex_type = "";
    if (prev) this._previousException = prev;

    this.getType = function () { return self._type; };
    this.getLongMsg = function () { return self._longMsg; };
    this.getShortMsg = function () { return self._shortMsg; };
    this.isFatal = function () { return self._fatalFlag; };
    this.toString = function () {
	return ("Exception: " + self._type + "\n" + self._shortMsg + "\n" + self._longMsg);
    }
};

iSPARQL.Exception.prototype = Error.prototype;

iSPARQL.E_MethodNotImplemented = function () {
    this._iSPARQL_ex_type = "E_MethodNotImplemented";
}

iSPARQL.E_InternalError = function () {
    this._iSPARQL_ex_type = "E_InternalError";
}

iSPARQL.E_MethodNotImplemented.prototype = iSPARQL.Exception.prototype;
iSPARQL.E_InternalError.prototype = iSPARQL.Exception.prototype;
