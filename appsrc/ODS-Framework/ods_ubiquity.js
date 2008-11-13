/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2008 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
*/

var noun_type_id = {
  _name: "id",
  suggest: function(text, html) {
    if (text.indexOf(".") >= 0) {return [];}
    var number = parseInt(text);
    if (isNaN(number)) {return [];}
    if (number < 1) {return [];}
    text = number;
    return [ CmdUtils.makeSugg(text, null, number)];
  }
};

var noun_type_integer = {
  _name: "integer",
  suggest: function(text, html) {
    if (text.indexOf(".") >= 0) {return [];}
    var number = parseInt(text);
    if (isNaN(number)) {return [];}
    text = number;
    return [ CmdUtils.makeSugg(text, null, number)];
  }
};

ODS = {
        getValue: function(prefName, defaultValue)
        {
          if (!Application.prefs.has(prefName))
          {
            return defaultValue;
          }
          else
          {
            return Application.prefs.get(prefName).value;
          }
        },

        setValue: function(prefName, prefValue)
        {
          if (!Application.prefs.has(prefName))
          {
            Application.prefs.setValue(prefName, prefValue);
            return prefValue;
          }
          else
          {
            var new_pref = Application.prefs.get(prefName);
            new_pref.value = prefValue;
          }
        },

        setLog: function(logMode)
        {
          ODS.setValue('ods_log', logMode);
        },

        getLog: function()
        {
          return ODS.getValue('ods_log', false);
        },

        setServer: function(serverUrl)
        {
          ODS.setValue('ods_server', serverUrl);
        },

        getServer: function()
        {
          return ODS.getValue('ods_server', 'http://myopenlink.net/ods');
        },

        setOAuthServer: function(serverUrl)
        {
          ODS.setValue('ods_oauth_server', serverUrl);
        },

        getOAuthServer: function()
        {
          return ODS.getValue('ods_oauth_server', 'http://myopenlink.net/OAuth');
        },

        setMode: function(mode)
        {
          ODS.setValue('ods_mode', mode);
        },

        getMode: function()
          {
          return ODS.getValue('ods_mode', 'sid');
        },

        setSid: function(sid)
          {
          ODS.setValue(ODS.getSidName(), sid);
        },

        getSid: function()
        {
          return ODS.getValue(ODS.getSidName());
        },

        getSidName: function(app)
        {
          return "ODS_api_sid";
        },

        setOAuth: function(app, oauth)
        {
          ODS.setValue(ODS.getOAuthName(app), oauth);
        },

        getOAuth: function(app)
        {
          return ODS.getValue(ODS.getOAuthName(app));
        },

        getOAuthName: function(app)
        {
          return "ODS_"+app+"_api_oauth";
        },
      };

function odsPreview(previewBlock, cmdName, cmdParams, cmdApplication)
{
  var res = odsExecute(cmdName, cmdParams, cmdApplication, "preview");
  previewBlock.innerHTML = "<pre>" + xml_encode(res) + "</pre>";
}

function odsExecuteError (XMLHttpRequest, textStatus, errorThrown, cmdName, showMode, logMode)
{
  if (!showMode)
    displayMessage("ODS Controller Error - command not executed");
  if (logMode)
    CmdUtils.log(cmdName + ": " + XMLHttpRequest.status + " - " + XMLHttpRequest.statusText);
}

function odsExecute (cmdName, cmdParams, cmdApplication, showMode, authMode)
{
  var res = '';
  var logMode = ODS.getLog();

  if (logMode)
  {
    CmdUtils.log(cmdName + " - start");
    var S = "";
    for(var param in cmdParams)
    {
      S += param + " value :" + cmdParams[param] + "\n";
    }
    CmdUtils.log(S);
  }
  if (authMode)
  {
    var res = jQuery.ajax({
      type: "GET",
      url: ODS.getServer() + "/api/" + cmdName,
      data: cmdParams,
      error: function(XMLHttpRequest, textStatus, errorThrown) {
          odsExecuteError (XMLHttpRequest, textStatus, errorThrown, ODS.getServer() + "/api/" + cmdName, showMode, logMode);
        },
      async: false
      }).responseText;
  }
  else if (ODS.getMode() == 'oauth')
  {
    var oauth = ODS.getOAuth(cmdApplication);

    var consumer_key = jQuery.ajax({
      type: "GET",
      url: ODS.getOAuthServer() + "/get_consumer_key",
      data: {"sid": oauth},
      error: function(XMLHttpRequest, textStatus, errorThrown) {
          odsExecuteError (XMLHttpRequest, textStatus, errorThrown, ODS.getOAuthServer() + "/get_consumer_key", showMode, logMode);
        },
      async: false
      }).responseText;

    var params = '';
    for (var param in cmdParams)
    {
      params += "&" + param + "=" + encodeURIComponent(cmdParams[param]);
    }
    var params = {
      meth: "GET",
      url: ODS.getServer() + "/api/" + cmdName,
      params: params,
      consumer_key: consumer_key,
      sid: oauth};

    var apiURL = jQuery.ajax({
      type: "GET",
      url: ODS.getOAuthServer() + "/sign_request",
      data: params,
      error: function(XMLHttpRequest, textStatus, errorThrown) {
          odsExecuteError (XMLHttpRequest, textStatus, errorThrown, ODS.getOAuthServer() + "/sign_request", showMode, logMode);
        },
      async: false
      }).responseText;

    res = jQuery.ajax({
      type: "GET",
      url: apiURL,
      error: function(XMLHttpRequest, textStatus, errorThrown) {
          odsExecuteError (XMLHttpRequest, textStatus, errorThrown, apiURL, showMode, logMode);
        },
      async: false
      }).responseText;
  }
  else if (ODS.getMode() == 'sid')
  {
    cmdParams.sid = ODS.getSid();
    cmdParams.realm = "wa";

    var res = jQuery.ajax({
      type: "GET",
      url: ODS.getServer() + "/api/" + cmdName,
      data: cmdParams,
      error: function(XMLHttpRequest, textStatus, errorThrown) {
          odsExecuteError (XMLHttpRequest, textStatus, errorThrown, ODS.getServer() + "/api/" + cmdName, showMode, logMode);
        },
      async: false
      }).responseText;
  }
  if (showMode)
  {
    if (res && (res.indexOf("<failed>") == 0)) {res = '';}
    if (!res) {res = '';}
  }
  if (!showMode)
    displayMessage(res);
  if (logMode)
  {
    CmdUtils.log(res);
    CmdUtils.log(cmdName + " - end");
  }
  return res;
}

function checkParameter(parameter, parameterName)
{
  if (!parameter || parameter.length < 1)
  {
    if (parameterName) {throw "Please, enter " + parameterName;}
    throw "Bad parameter";
  }
}

function addParameter(modifiers, modifierName, parameters, parameterName, modifierCheck)
{
  if (modifierCheck)
  {
    if (!modifiers[modifierName]) {throw "Please, enter " + modifierName;}
      checkParameter(modifiers[modifierName].text, modifierName);
  }
  if (modifiers[modifierName] && modifiers[modifierName].text)
  {
    var S = modifiers[modifierName].text.toString();
    if (S.length > 0)
    parameters[parameterName] = modifiers[modifierName].text;
}
}

function xml_encode(xml)
{
  if (!xml) {return '';}

  xml = xml.replace(/&/g, '&amp;');
  xml = xml.replace(/</g, '&lt;');
  xml = xml.replace(/>/g, '&gt;');
  xml = xml.replace(/'/g, '&apos;');
  xml = xml.replace(/"/g, '&quot;');

  return xml;
}

function sha (input)
{
	var hexcase = 0;  /* hex output format. 0 - lowercase; 1 - uppercase        */
	var b64pad  = ""; /* base-64 pad character. "=" for strict RFC compliance   */
	var chrsz   = 8;  /* bits per input character. 8 - ASCII; 16 - Unicode      */

	/*
	 * Calculate the SHA-1 of an array of big-endian words, and a bit length
	 */
	function core_sha1(x, len) {
		/* append padding */
		x[len >> 5] |= 0x80 << (24 - len % 32);
		x[((len + 64 >> 9) << 4) + 15] = len;

		var w = Array(80);
		var a =  1732584193;
		var b = -271733879;
		var c = -1732584194;
		var d =  271733878;
		var e = -1009589776;

		for(var i = 0; i < x.length; i += 16) {
			var olda = a;
			var oldb = b;
			var oldc = c;
			var oldd = d;
			var olde = e;

			for(var j = 0; j < 80; j++) {
				if(j < 16) w[j] = x[i + j];
				else w[j] = rol(w[j-3] ^ w[j-8] ^ w[j-14] ^ w[j-16], 1);
				var t = safe_add(safe_add(rol(a, 5), sha1_ft(j, b, c, d)),
				safe_add(safe_add(e, w[j]), sha1_kt(j)));
				e = d;
				d = c;
				c = rol(b, 30);
				b = a;
				a = t;
			}

			a = safe_add(a, olda);
			b = safe_add(b, oldb);
			c = safe_add(c, oldc);
			d = safe_add(d, oldd);
			e = safe_add(e, olde);
		}
		return Array(a, b, c, d, e);
	}

	/*
	* Perform the appropriate triplet combination function for the current
	* iteration
	*/
	function sha1_ft(t, b, c, d) {
		if(t < 20) return (b & c) | ((~b) & d);
		if(t < 40) return b ^ c ^ d;
		if(t < 60) return (b & c) | (b & d) | (c & d);
		return b ^ c ^ d;
	}

	/*
	* Determine the appropriate additive constant for the current iteration
	*/
	function sha1_kt(t) {
		return (t < 20) ?  1518500249 : (t < 40) ?  1859775393 :
		(t < 60) ? -1894007588 : -899497514;
	}

	/*
	* Add integers, wrapping at 2^32. This uses 16-bit operations internally
	* to work around bugs in some JS interpreters.
	*/
	function safe_add(x, y) {
		var lsw = (x & 0xFFFF) + (y & 0xFFFF);
		var msw = (x >> 16) + (y >> 16) + (lsw >> 16);
		return (msw << 16) | (lsw & 0xFFFF);
	}

	/*
	* Bitwise rotate a 32-bit number to the left.
	*/
	function rol(num, cnt) {
		return (num << cnt) | (num >>> (32 - cnt));
	}

	/*
	* Convert an 8-bit or 16-bit string to an array of big-endian words
	* In 8-bit function, characters >255 have their hi-byte silently ignored.
	*/
	function str2binb(str) {
		var bin = Array();
		var mask = (1 << chrsz) - 1;
		for (var i = 0; i < str.length * chrsz; i += chrsz)
			bin[i>>5] |= (str.charCodeAt(i / chrsz) & mask) << (32 - chrsz - i%32);
		return bin;
	}

	/*
	* Convert an array of big-endian words to a hex string.
	*/
	function binb2hex(binarray)	{
		var hex_tab = hexcase ? "0123456789ABCDEF" : "0123456789abcdef";
		var str = "";
		for(var i = 0; i < binarray.length * 4; i++) {
			str += hex_tab.charAt((binarray[i>>2] >> ((3 - i%4)*8+4)) & 0xF) +
			hex_tab.charAt((binarray[i>>2] >> ((3 - i%4)*8  )) & 0xF);
		}
		return str;
	}

	return binb2hex(core_sha1(str2binb(input),input.length * chrsz));
}

////////////////////////////////////
///// ODS common commands //////////
////////////////////////////////////

CmdUtils.CreateCommand({
  name: "ods-log-enable",
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Enable log messages",
  help: "Type ods-log-enable",
  execute: function() {
    ODS.setLog(true);
  }
});

CmdUtils.CreateCommand({
  name: "ods-log-disable",
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Disable log messages",
  help: "Type ods-log-disable",
  execute: function() {
    ODS.setLog(false);
  }
});

CmdUtils.CreateCommand({
  name: "ods-host",
  takes: {"host-url": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS server url - host and port",
  help: "Type ods-host http://myopenlink.net/ods",
  execute: function(hostUrl) {
    try {
      checkParameter(hostUrl.text, "host-url");
    ODS.setServer(hostUrl.text);
    displayMessage("Your ODS host URL has been set to " + ODS.getServer());
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-oauth-host",
  takes: {"host-url": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS OAuth server url",
  help: "Type ods-api-host http://myopenlink.net/OAuth",
  execute: function(hostUrl) {
    try {
      checkParameter(hostUrl.text, "host-url");
    ODS.setOAuthServer(hostUrl.text);
    displayMessage("Your ODS OAuth host has been set to " + ODS.getOAuthServer());
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-set-mode",
  takes: {"mode": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS API mode - sid or oauth",
  help: "Type ods-set-mode <sid|oauth&gt;",
  execute: function(mode) {
    try {
      checkParameter(mode.text, "mode type - sid or oauth");
    ODS.setMode(mode.text);
    displayMessage("Your ODS API mode has been set to " + ODS.getMode());
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-set-sid",
  takes: {"mode": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS session ID",
  help: "Type ods-set-sid <sid value&gt;",
  execute: function(sid) {
    try {
      checkParameter(sid.text, "session ID");
    ODS.setSid(sid.text);
    displayMessage("Your ODS session ID has been set to " + ODS.getSid());
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-authenticate-user",
  takes: {"username": noun_arb_text},
  modifiers: {"password": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-authenticate-user &lt;username&gt; password &lt;password&gt;",
  execute: function(user, modifiers) {
    try {
      checkParameter(user.text, "user");
    var params = {user_name: user.text};
    addParameter(modifiers, "password", params, "password_hash", true);
    params["password_hash"] = sha (params["user_name"] + params["password_hash"]);
      var sid = odsExecute("user.authenticate", params, "", false, true);
    ODS.setSid(sid);
    ODS.setMode('sid');
      displayMessage("You were authenticated. Your ODS session ID has been set to " + ODS.getSid());
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-params",
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Get ODS Ubiquity params",
  help: "Type ods-get-params",
  preview: function(previewBlock) {
    var previewTemplate = "<br />ODS Server: <b>${ods_server}</b><br />ODS OAuth server: <b>${oauth_server}</b><br />ODS authenticate mode: <b>${ods_mode}</b><br />ODS sid: <b>${ods_sid}</b><br />ODS log enable: <b>${ods_log}</b><br />";
    var previewData = {
      ods_server: ODS.getServer(),
      oauth_server: ODS.getOAuthServer(),
      ods_mode: ODS.getMode(),
      ods_sid: ODS.getSid(),
      ods_log: ODS.getLog()
    };
    previewBlock.innerHTML = CmdUtils.renderTemplate(previewTemplate, previewData);     ;
  }
});

////////////////////////////////////
///// ODS commands /////////////////
////////////////////////////////////

CmdUtils.CreateCommand({
  name: "ods-set-oauth",
  takes: {"oauth": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS OAuth. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  help: "Type ods-set-oauth &lt;oauth&gt;. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  execute: function(oauth) {
    try {
      checkParameter(oauth.text, "ODS OAuth");
    ODS.setOAuth("", oauth.text);
    displayMessage("Your ODS OAuth has been set.");
    } catch (ex) {
      displayMessage(ex);
    }
    }
});

CmdUtils.CreateCommand({
  name: "ods-get-uri-info",
  takes: {"uri": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-uri-info &lt;uri&gt;",
  execute: function (uri) {
    try {
      checkParameter(uri.text, "uri");
    var windowManager = Components.classes["@mozilla.org/appshell/window-mediator;1"].getService(Components.interfaces.nsIWindowMediator);
    var browserWindow = windowManager.getMostRecentWindow("navigator:browser");
    var browser = browserWindow.getBrowser();
    var new_tab = browser.addTab(uri.text);
    new_tab.control.selectedIndex = new_tab.control.childNodes.length-1;
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-user",
  takes: {"username": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-user &lt;username&gt;",
  preview: function (previewBlock, user) {
    try {
      checkParameter(user.text, "username");
    var params = {name: user.text};
      odsPreview (previewBlock, "user.get", params);
    } catch (ex) {
    }
  },
});

CmdUtils.CreateCommand({
  name: "ods-create-user",
  takes: {"user": noun_arb_text},
  modifiers: {"password": noun_arb_text, "email": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-user &lt;username&gt; password &lt;password&gt; email &lt;email&gt;",
  execute: function (user, modifiers) {
    try {
      checkParameter(user.text, "user");
      var params = {name: user.text};
      addParameter(modifiers, "password", params, "password", true);
      addParameter(modifiers, "email", params, "email", true);
      odsExecute("user.register", params, "", false, true);
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-user",
  takes: {"user": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-user &lt;username&gt;",
  execute: function (user) {
    try {
      checkParameter(user.text, "user");
    var params = {name: user.text};
    odsExecute ("user.delete", params)
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-enable-user",
  takes: {"user": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-enable-user &lt;username&gt;",
  execute: function (user) {
    try {
      checkParameter(user.text, "user");
    var params = {name: user.text};
      odsExecute("user.enable", params);
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-disable-user",
  takes: {"user": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-disable-user &lt;username&gt;",
  execute: function (user) {
    try {
      checkParameter(user.text, "user");
    var params = {name: user.text};
      odsExecute("user.disable", params);
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-user-annotation",
  takes: {"iri": noun_arb_text},
  modifiers: {"has": noun_arb_text, "with": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-user-annotation &lt;iri&gt; has &lt;relation&gt; with &lt;value&gt;",
  execute: function (iri, modifiers) {
    try {
      checkParameter(iri.text, "iri");
    var params = {claimIri: iri.text};
    addParameter(modifiers, "has", params, "claimRelation", true);
    addParameter(modifiers, "with", params, "claimValue", true);
      odsExecute("user.annotation.new", params);
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-user-annotation",
  takes: {"iri": noun_arb_text},
  modifiers: {"has": noun_arb_text, "with": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-user-annotation &lt;iri&gt; has &lt;relation&gt; with &lt;value&gt;",
  execute: function (iri, modifiers) {
    try {
      checkParameter(iri.text, "iri");
    var params = {claimIri: iri.text};
    addParameter(modifiers, "has", params, "claimRelation", true);
    addParameter(modifiers, "with", params, "claimValue", true);
      odsExecute("user.annotation.delete", params);
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-instance-id",
  takes: {"instanceName": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-instance-id &lt;instanceName&gt;",
  execute: function (instanceName) {
    try {
      checkParameter(instanceName.text, "instanceName");
      var params = {instanceName: instanceName.text};
      odsExecute("instance.get.id", params);
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-freeze-instance",
  takes: {"instance_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-freeze-instance &lt;instance_id&gt;",
  execute: function (instance_id) {
    try {
      checkParameter(instance_id.text, "instance_id");
      var params = {inst_id: instance_id.text};
      odsExecute("instance.freeze", params);
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-unfreeze-instance",
  takes: {"instance_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-unfreeze-instance &lt;instance_id&gt;",
  execute: function (instance_id) {
    try {
      checkParameter(instance_id.text, "instance_id");
      var params = {inst_id: instance_id.text};
      odsExecute("instance.unfreeze", params);
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

////////////////////////////////////
///// ods briefcase ////////////////
////////////////////////////////////

CmdUtils.CreateCommand({
  name: "ods-set-briefcase-oauth",
  takes: {"oauth": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS briefcase OAuth. Get your oauth at " + ODS.getOAuthServer() + "/oauth_sid.vsp",
  help: "Type ods-set-briefcase-oauth &lt;oauth&gt;. Get your oauth at " + ODS.getOAuthServer(),
  execute: function(oauth) {
    try {
      checkParameter(oauth.text, "briefcase instance OAuth");
    ODS.setOAuth("briefcase", oauth.text);
    displayMessage("Your ODS briefcase instance OAuth has been set.");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-briefcase-resource-info-by-path",
  takes: {"path": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Get your ODS briefcase resource content",
  help: "Type ods-get-briefcase-resource-info-by-path &lt;path&gt;",
  preview: function (previewBlock, path) {
    try {
      checkParameter(path.text);
    var params = {path: path.text};
      odsPreview (previewBlock, "briefcase.resource.get", params, "briefcase");
    } catch (ex) {
    }
  },
});

CmdUtils.CreateCommand({
  name: "ods-store-briefcase-resource",
  takes: {"path": noun_arb_text},
  modifiers: {"content": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Store content on resource path",
  help: "Type ods-store-briefcase-resource &lt;path&gt; content &lt;content&gt;",
  execute: function(path, modifiers) {
    try {
      checkParameter(path.text, "path");
    var params = {path: path.text};
    addParameter(modifiers, "content", params, "content", true);
      odsExecute("briefcase.resource.store", params, "briefcase");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-briefcase-resource",
  takes: {"path": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Get your ODS briefcase resource content",
  help: "Type ods-delete-briefcase-resource &lt;path&gt;",
  execute: function(path) {
    try {
      checkParameter(path.text, "path");
    var params = {path: path.text};
      odsExecute("briefcase.resource.delete", params, "briefcase");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-briefcase-collection",
  takes: {"path": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Create ODS briefcase collection (folder)",
  help: "Type ods-create-briefcase-collection &lt;path&gt;",
  execute: function(path) {
    try {
      checkParameter(path.text, "path");
    var params = {path: path.text};
      odsExecute("briefcase.collection.create", params, "briefcase");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-briefcase-collection",
  takes: {"path": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Delete existing ODS Briefcase collection (folder)",
  help: "Type ods-delete-briefcase-collection &lt;path&gt;",
  execute: function(path) {
    try {
      checkParameter(path.text, "path");
    var params = {path: path.text};
      odsExecute("briefcase.collection.delete", params, "briefcase");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-copy-briefcase-collection",
  takes: {"path": noun_arb_text},
  modifiers: {"to": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Copy existing ODS Briefcase collection (folder)",
  help: "Type ods-copy-briefcase-collection &lt;fromPath&gt; to &lt;toPath&gt;",
  execute: function(path, modifiers) {
    try {
      checkParameter(path.text, "path");
    var params = {from_path: path.text};
    addParameter(modifiers, "to", params, "to_path", true);
      odsExecute("briefcase.copy", params, "briefcase");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-move-briefcase-collection",
  takes: {"path": noun_arb_text},
  modifiers: {"to": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Copy existing ODS Briefcase collection (folder)",
  help: "Type ods-copy-briefcase-collection &lt;fromPath&gt; to &lt;toPath&gt;",
  execute: function(path, modifiers) {
    try {
      checkParameter(path.text, "path");
    var params = {from_path: path.text};
    addParameter(modifiers, "to", params, "to_path", true);
      odsExecute("briefcase.move", params, "briefcase");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-set-briefcase-property",
  takes: {"path": noun_arb_text},
  modifiers: {"property": noun_arb_text, "with": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set property to existing ODS Briefcase collection/resource",
  help: "Type ods-set-briefcase-property &lt;path&gt; property &lt;property_name&gt; with &lt;value&gt;",
  execute: function(path, modifiers) {
    try {
      checkParameter(path.text, "path");
    var params = {path: path.text};
    addParameter(modifiers, "property", params, "property", true);
    addParameter(modifiers, "with", params, "value", true);
      odsExecute("briefcase.property.set", params, "briefcase");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-briefcase-property",
  takes: {"path": noun_arb_text},
  modifiers: {"property": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Get property from existing ODS Briefcase collection/resource",
  help: "Type ods-get-briefcase-property &lt;path&gt; property &lt;property_name&gt;",
  execute: function(path, modifiers) {
    try {
      checkParameter(path.text, "path");
    var params = {path: path.text};
    addParameter(modifiers, "property", params, "property", true);
      odsExecute("briefcase.property.get", params, "briefcase");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-briefcase-property",
  takes: {"path": noun_arb_text},
  modifiers: {"property": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Delete property from existing ODS Briefcase collection/resource",
  help: "Type ods-delete-briefcase-property &lt;path&gt; property &lt;property_name&gt;",
  execute: function(path, modifiers) {
    try {
      checkParameter(path.text, "path");
    var params = {path: path.text};
    addParameter(modifiers, "property", params, "property", true);
      odsExecute("briefcase.property.delete", params, "briefcase");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

////////////////////////////////////
///// ods bookmark /////////////////
////////////////////////////////////

CmdUtils.CreateCommand({
  name: "ods-set-bookmark-oauth",
  takes: {"oauth": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS bookmark OAuth. Get your oauth at " + ODS.getOAuthServer() + "/oauth_sid.vsp",
  help: "Type ods-set-bookmark-oauth &lt;oauth&gt;. Get your oauth at " + ODS.getOAuthServer(),
  execute: function(oauth) {
    try {
      checkParameter(oauth.text, "bookmark instance OAuth");
    ODS.setOAuth("bookmark", oauth.text);
    displayMessage("Your ODS bookmark instance OAuth has been set.");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-bookmark-by-id",
  takes: {"bookmark_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-bookmark-by-id &lt;bookmark_id&gt;",
  preview: function (previewBlock, bookmark_id) {
    try {
      checkParameter(bookmark_id.text);
    var params = {bookmark_id: bookmark_id.text};
      odsPreview (previewBlock, "bookmark.get", params, "bookmark");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-bookmark",
  takes: {"instance_id": noun_type_id},
  modifiers: {"title": noun_arb_text, "url": noun_arb_text, "description": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmark &lt;instance_id&gt; title &lt;title&gt; url &lt;url&gt; [description &lt;description&gt;] [tags &lt;tags&gt;]",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "title", params, "name", true);
    addParameter(modifiers, "url", params, "uri", true);
    addParameter(modifiers, "description", params, "description");
    addParameter(modifiers, "tags", params, "tags");
      odsExecute("bookmark.new", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-update-bookmark",
  takes: {"bookmark_id": noun_type_id},
  modifiers: {"title": noun_arb_text, "url": noun_arb_text, "description": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-bookmark &lt;bookmark_id&gt; title &lt;title&gt; url &lt;url&gt; [description &lt;description&gt;] [tags &lt;tags&gt;]",
  execute: function (bookmark_id, modifiers) {
    try {
      checkParameter(bookmark_id.text, "bookmark_id");
    var params = {bookmark_id: bookmark_id.text};
    addParameter(modifiers, "title", params, "name", true);
    addParameter(modifiers, "url", params, "uri", true);
    addParameter(modifiers, "description", params, "description");
    addParameter(modifiers, "tags", params, "tags");
      odsExecute("bookmark.edit", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
    }
});

CmdUtils.CreateCommand({
  name: "ods-delete-bookmark-by-id",
  takes: {"bookmark_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmark-by-id &lt;bookmark_id&gt;",
  execute: function (bookmark_id) {
    try {
      checkParameter(bookmark_id.text, "bookmark_id");
    var params = {bookmark_id: bookmark_id.text};
      odsExecute("bookmark.delete", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-bookmarks-folder",
  takes: {"instance_id": noun_type_id},
  modifiers: {"path": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmarks-folder &lt;instance_id&gt; path &lt;path&gt;",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "path", params, "path", true);
      odsExecute("bookmark.folder.new", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-bookmarks-folder",
  takes: {"instance_id": noun_type_id},
  modifiers: {"path": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmarks-folder &lt;instance_id&gt; path &lt;path&gt;",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "path", params, "path", true);
      odsExecute("bookmark.folder.delete", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-export-bookmarks",
  takes: {"instance_id": noun_type_id},
  modifiers: {"exportType": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-export-bookmarks &lt;instance_id&gt; [exportType &lt;Netscape|XBEL&gt;]",
  preview: function (previewBlock, instance_id, modifiers) {
    try {
      checkParameter(instance_id.text);
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "exportType", params, "contentType");
      odsPreview (previewBlock, "bookmark.export", params, "bookmark");
    } catch (ex) {
    }
        },
});

CmdUtils.CreateCommand({
  name: "ods-import-bookmarks",
  takes: {"instance_id": noun_type_id},
  modifiers: {"source": noun_arb_text, "sourceType": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-import-bookmarks &lt;instance_id&gt; source &lt;source&gt; sourceType &lt;WebDAV|URL&gt;",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "source", params, "source", true);
    addParameter(modifiers, "sourceType", params, "sourceType", true);
      odsExecute("bookmark.import", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-bookmark-annotation-by-id",
  takes: {"annotation_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-bookmark-annotation-by-id &lt;annotation_id&gt;",
  preview: function (annotation_id, modifiers) {
    try {
      checkParameter(annotation_id.text);
    var params = {annotation_id: annotation_id.text};
      odsPreview (previewBlock, "bookmark.annotation.get", params, "bookmark");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-bookmark-annotation",
  takes: {"bookmark_id": noun_type_id},
  modifiers: {"author": noun_arb_text, "body": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmark-annotation &lt;bookmark_id&gt; author &lt;author&gt; body &lt;body&gt;",
  execute: function (bookmark_id, modifiers) {
    try {
      checkParameter(bookmark_id.text, "bookmark_id");
    var params = {bookmark_id: bookmark_id.text};
    addParameter(modifiers, "author", params, "author", true);
    addParameter(modifiers, "body", params, "body", true);
      odsExecute("bookmark.annotation.new", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-bookmark-annotation-claim",
  takes: {"annotation_id": noun_type_id},
  modifiers: {"iri": noun_arb_text, "relation": noun_arb_text, "value": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmark-annotation-claim &lt;annotation_id&gt; iri &lt;iri&gt; relation &lt;relation&gt; value &lt;value&gt;",
  execute: function (annotation_id, modifiers) {
    try {
      checkParameter(annotation_id.text, "annotation_id");
    var params = {annotation_id: annotation_id.text};
    addParameter(modifiers, "iri", params, "claimIri", true);
    addParameter(modifiers, "relation", params, "claimRelation", true);
    addParameter(modifiers, "value", params, "claimValue", true);
      odsExecute("bookmark.annotation.claim", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-bookmark-annotation",
  takes: {"annotation_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmark-annotation &lt;annotation_id&gt;",
  execute: function (annotation_id) {
    try {
      checkParameter(annotation_id.text, "annotation_id");
    var params = {annotation_id: annotation_id.text};
      odsExecute("bookmark.annotation.delete", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-bookmark-comment-by-id",
  takes: {"comment_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-bookmark-comment-by-id &lt;comment_id&gt;",
  preview: function (previewBlock, comment_id) {
    try {
      checkParameter(comment_id.text);
    var params = {comment_id: comment_id.text};
      odsPreview (previewBlock, "bookmark.comment.get", params, "bookmark");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-bookmark-comment",
  takes: {"bookmark_id": noun_type_id},
  modifiers: {"title": noun_arb_text, "body": noun_arb_text, "author": noun_arb_text, "authorMail": noun_arb_text, "authorUrl": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmark-comment &lt;bookmark_id&gt; title &lt;title&gt; body &lt;body&gt; author &lt;author&gt; authorMail &lt;authorMail&gt; authorUrl &lt;authorUrl&gt;",
  execute: function (bookmark_id, modifiers) {
    try {
      checkParameter(bookmark_id.text, "bookmark_id");
    var params = {bookmark_id: bookmark_id.text};
    addParameter(modifiers, "title", params, "title", true);
    addParameter(modifiers, "body", params, "text", true);
    addParameter(modifiers, "author", params, "name", true);
    addParameter(modifiers, "authorMail", params, "email", true);
    addParameter(modifiers, "authorUrl", params, "url", true);
      odsExecute("bookmark.comment.new", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-bookmark-comment",
  takes: {"comment_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmark-comment &lt;comment_id&gt;",
  execute: function (comment_id) {
    try {
      checkParameter(comment_id.text, "comment_id");
    var params = {comment_id: comment_id.text};
      odsExecute("bookmark.comment.delete", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-bookmarks-publication",
  takes: {"instance_id": noun_type_id},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "destinationType": noun_arb_text, "destination": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "folderPath": noun_arb_text, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmarks-publication &lt;instance_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [destinationType &lt;destinationType&gt;] destination &lt;destination&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [folderPath &lt;folderPath&gt;] [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
      var params = {inst_id: instance_id.text};
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers, "updateType", params, "updateType");
    addParameter(modifiers, "updatePeriod", params, "updatePeriod");
    addParameter(modifiers, "updateFreq", params, "updateFreq");
    addParameter(modifiers, "destinationType", params, "destinationType");
    addParameter(modifiers, "destination", params, "destination", true);
    addParameter(modifiers, "userName", params, "userName");
    addParameter(modifiers, "userPassword", params, "userPassword");
    addParameter(modifiers, "folderPath", params, "folderPath");
    addParameter(modifiers, "tagsInclude", params, "tagsInclude");
    addParameter(modifiers, "tagsExclude", params, "tagsExclude");
      odsExecute("bookmark.publication.new", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-update-bookmarks-publication",
  takes: {"publication_id": noun_type_id},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "destinationType": noun_arb_text, "destination": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "folderPath": noun_arb_text, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-bookmarks-publication &lt;publication_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [destinationType &lt;destinationType&gt;] destination &lt;destination&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [folderPath &lt;folderPath&gt;] [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",
  execute: function (publication_id, modifiers) {
    try {
      checkParameter(publication_id.text, "publication_id");
    var params = {publication_id: publication_id.text};
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers, "updateType", params, "updateType");
    addParameter(modifiers, "updatePeriod", params, "updatePeriod");
    addParameter(modifiers, "updateFreq", params, "updateFreq");
    addParameter(modifiers, "destinationType", params, "destinationType");
    addParameter(modifiers, "destination", params, "destination", true);
    addParameter(modifiers, "userName", params, "userName");
    addParameter(modifiers, "userPassword", params, "userPassword");
    addParameter(modifiers, "folderPath", params, "folderPath");
    addParameter(modifiers, "tagsInclude", params, "tagsInclude");
    addParameter(modifiers, "tagsExclude", params, "tagsExclude");
      odsExecute("bookmark.publication.edit", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-bookmarks-publication",
  takes: {"publication_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmarks-publication &lt;publication_id&gt;",
  execute: function (publication_id) {
    try {
      checkParameter(publication_id.text, "publication_id");
    var params = {publication_id: publication_id.text};
      odsExecute("bookmark.publication.delete", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-bookmarks-subscription",
  takes: {"instance_id": noun_type_id},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "sourceType": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "folderPath": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmarks-subscription &lt;instance_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [sourceType &lt;sourceType&gt;] source &lt;source&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [folderPath &lt;folderPath&gt;] [tags &lt;tags&gt;]",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
      var params = {inst_id: instance_id.text};
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers, "updateType", params, "updateType");
    addParameter(modifiers, "updatePeriod", params, "updatePeriod");
    addParameter(modifiers, "updateFreq", params, "updateFreq");
    addParameter(modifiers, "sourceType", params, "sourceType");
    addParameter(modifiers, "source", params, "source", true);
    addParameter(modifiers, "userName", params, "userName");
    addParameter(modifiers, "userPassword", params, "userPassword");
    addParameter(modifiers, "folderPath", params, "folderPath");
    addParameter(modifiers, "tags", params, "tags");
      odsExecute("bookmark.subscription.new", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-update-bookmarks-subscription",
  takes: {"subscription_id": noun_type_id},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "sourceType": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "folderPath": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-bookmarks-subscription &lt;subscription_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [sourceType &lt;sourceType&gt;] source &lt;source&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [folderPath &lt;folderPath&gt;] [tags &lt;tags&gt;]",
  execute: function (subscription_id, modifiers) {
    try {
      checkParameter(subscription_id.text, "subscription_id");
    var params = {subscription_id: subscription_id.text};
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers, "updateType", params, "updateType");
    addParameter(modifiers, "updatePeriod", params, "updatePeriod");
    addParameter(modifiers, "updateFreq", params, "updateFreq");
    addParameter(modifiers, "sourceType", params, "sourceType");
    addParameter(modifiers, "source", params, "source", true);
    addParameter(modifiers, "userName", params, "userName");
    addParameter(modifiers, "userPassword", params, "userPassword");
    addParameter(modifiers, "folderPath", params, "folderPath");
    addParameter(modifiers, "tags", params, "tags");
      odsExecute("bookmark.subscription.edit", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-bookmarks-subscription",
  takes: {"subscription_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmarks-subscription &lt;subscription_id&gt;",
  execute: function (subscription_id) {
    try {
      checkParameter(subscription_id.text, "subscription_id");
    var params = {subscription_id: subscription_id.text};
      odsExecute("bookmark.subscription.delete", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-set-bookmarks-options",
  takes: {"instance_id": noun_type_id},
  modifiers: {"options": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-set-bookmarks-options &lt;instance_id&gt; options &lt;options&gt;",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
      var params = {inst_id: instance_id.text};
    addParameter(modifiers, "options", params, "options");
      odsExecute("bookmark.options.set", params, "bookmark");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-bookmarks-options",
  takes: {"instance_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-bookmarks-options &lt;instance_id&gt;",

  preview: function (previewBlock, instance_id) {
    try {
      checkParameter(instance_id.text);
      var params = {inst_id: instance_id.text};
      odsPreview (previewBlock, "bookmark.options.get", params, "bookmark");
    } catch (ex) {
    }
  }
});

////////////////////////////////////
///// ODS Calendar /////////////////
////////////////////////////////////

CmdUtils.CreateCommand({
  name: "ods-set-calendar-oauth",
  takes: {"oauth": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS Calendar OAuth. Get your oauth at " + ODS.getOAuthServer() + "/oauth_sid.vsp",
  help: "Type ods-set-calendar-oauth &lt;oauth&gt;. Get your oauth at " + ODS.getOAuthServer(),
  execute: function(oauth) {
    try {
      checkParameter(oauth.text, "calendar instance OAuth");
    ODS.setOAuth("calendar", oauth.text);
    displayMessage("Your ODS Calendar instance OAuth has been set.");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-calendar-item-by-id",
  takes: {"event_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-calendar-item-by-id &lt;event_id&gt;",

  preview: function (previewBlock, event_id) {
    try {
      checkParameter(event_id.text);
    var params = {event_id: event_id.text};
      odsPreview (previewBlock, "calendar.get", params, "calendar");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-calendar-event",
  takes: {"instance_id": noun_type_id},
  modifiers: {"subject": noun_arb_text, "description": noun_arb_text, "location": noun_arb_text, "attendees": noun_arb_text, "privacy": noun_arb_text, "tags": noun_arb_text, "event": noun_arb_text, "eventStart": noun_arb_text, "eventEnd": noun_arb_text, "eRepeat": noun_arb_text, "eRepeatParam1": noun_arb_text, "eRepeatParam2": noun_arb_text, "eRepeatParam3": noun_arb_text, "eRepeatUntil": noun_type_date, "eReminder": noun_arb_text, "notes": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-event &lt;instance_id&gt; subject &lt;subject&gt; [description &lt;description&gt;] [location &lt;location&gt;] [attendees &lt;attendees&gt;] [privacy &lt;privacy&gt;] [tags &lt;tags&gt;] [event &lt;event&gt;] eventStart &lt;eventStart&gt; eventEnd &lt;eventEnd&gt; [eRepeat &lt;eRepeat&gt;] [eRepeatParam1 &lt;eRepeatParam1&gt;] [eRepeatParam2 &lt;eRepeatParam2&gt;] [eRepeatParam3 &lt;eRepeatParam3&gt;] [eRepeatUntil &lt;eRepeatUntil&gt;] [eReminder &lt;eReminder&gt;] [notes &lt;notes&gt;]",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "subject", params, "subject", true);
    addParameter(modifiers, "description", params, "description");
    addParameter(modifiers, "location", params, "location");
    addParameter(modifiers, "attendees", params, "attendees");
    addParameter(modifiers, "privacy", params, "privacy");
    addParameter(modifiers, "tags", params, "tags");
    addParameter(modifiers, "event", params, "event");
    addParameter(modifiers, "eventStart", params, "eventStart", true);
    addParameter(modifiers, "eventEnd", params, "eventEnd", true);
    addParameter(modifiers, "eRepeat", params, "eRepeat");
    addParameter(modifiers, "eRepeatParam1", params, "eRepeatParam1");
    addParameter(modifiers, "eRepeatParam2", params, "eRepeatParam2");
    addParameter(modifiers, "eRepeatParam3", params, "eRepeatParam3");
    addParameter(modifiers, "eRepeatUntil ", params, "eRepeatUntil ");
    addParameter(modifiers, "eReminder", params, "eReminder");
    addParameter(modifiers, "notes", params, "notes");
      odsExecute("calendar.event.new", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-update-calendar-event",
  takes: {"event_id": noun_type_id},
  modifiers: {"subject": noun_arb_text, "description": noun_arb_text, "location": noun_arb_text, "attendees": noun_arb_text, "privacy": noun_arb_text, "tags": noun_arb_text, "event": noun_arb_text, "eventStart": noun_arb_text, "eventEnd": noun_arb_text, "eRepeat": noun_arb_text, "eRepeatParam1": noun_arb_text, "eRepeatParam2": noun_arb_text, "eRepeatParam3": noun_arb_text, "eRepeatUntil": noun_type_date, "eReminder": noun_arb_text, "notes": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-calendar-event &lt;event_id&gt; subject &lt;subject&gt; [description &lt;description&gt;] [location &lt;location&gt;] [attendees &lt;attendees&gt;] [privacy &lt;privacy&gt;] [tags &lt;tags&gt;] [event &lt;event&gt;] eventStart &lt;eventStart&gt; eventEnd &lt;eventEnd&gt; [eRepeat &lt;eRepeat&gt;] [eRepeatParam1 &lt;eRepeatParam1&gt;] [eRepeatParam2 &lt;eRepeatParam2&gt;] [eRepeatParam3 &lt;eRepeatParam3&gt;] [eRepeatUntil &lt;eRepeatUntil&gt;] [eReminder &lt;eReminder&gt;] [notes &lt;notes&gt;]",
  execute: function (event_id, modifiers) {
    try {
      checkParameter(event_id.text, "event_id");
    var params = {event_id: event_id.text};
      CmdUtils.log(modifiers["eventStart"].data);
    addParameter(modifiers, "subject", params, "subject", true);
    addParameter(modifiers, "description", params, "description");
    addParameter(modifiers, "location", params, "location");
    addParameter(modifiers, "attendees", params, "attendees");
    addParameter(modifiers, "privacy", params, "privacy");
    addParameter(modifiers, "tags", params, "tags");
    addParameter(modifiers, "event", params, "event");
    addParameter(modifiers, "eventStart", params, "eventStart", true);
    addParameter(modifiers, "eventEnd", params, "eventEnd", true);
    addParameter(modifiers, "eRepeat", params, "eRepeat");
    addParameter(modifiers, "eRepeatParam1", params, "eRepeatParam1");
    addParameter(modifiers, "eRepeatParam2", params, "eRepeatParam2");
    addParameter(modifiers, "eRepeatParam3", params, "eRepeatParam3");
    addParameter(modifiers, "eRepeatUntil ", params, "eRepeatUntil ");
    addParameter(modifiers, "eReminder", params, "eReminder");
    addParameter(modifiers, "notes", params, "notes");
      odsExecute("calendar.event.edit", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-calendar-task",
  takes: {"instance_id": noun_type_id},
  modifiers: {"subject": noun_arb_text, "description": noun_arb_text, "attendees": noun_arb_text, "privacy": noun_arb_text, "tags": noun_arb_text, "eventStart": noun_type_date, "eventEnd": noun_type_date, "priority": noun_arb_text, "status": noun_arb_text, "complete": noun_arb_text, "completed": noun_type_date, "note": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-task &lt;instance_id&gt; subject &lt;subject&gt; [description &lt;description&gt;] [attendees &lt;attendees&gt;] [privacy &lt;privacy&gt;] [tags &lt;tags&gt;] eventStart &lt;eventStart&gt; eventEnd &lt;eventEnd&gt; [priority &lt;priority&gt;] [status &lt;status&gt;] [complete &lt;complete&gt;] [completed &lt;completed&gt;] [notes &lt;notes&gt;]",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "subject", params, "subject", true);
    addParameter(modifiers, "description", params, "description");
    addParameter(modifiers, "attendees", params, "attendees");
    addParameter(modifiers, "privacy", params, "privacy");
    addParameter(modifiers, "tags", params, "tags");
    addParameter(modifiers, "eventStart", params, "eventStart", true);
    addParameter(modifiers, "eventEnd", params, "eventEnd", true);
    addParameter(modifiers, "priority", params, "priority");
    addParameter(modifiers, "status", params, "status");
    addParameter(modifiers, "complete", params, "complete");
    addParameter(modifiers, "completed", params, "completed");
    addParameter(modifiers, "notes", params, "notes");
      odsExecute("calendar.task.new", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-update-calendar-task",
  takes: {"event_id": noun_type_id},
  modifiers: {"subject": noun_arb_text, "description": noun_arb_text, "attendees": noun_arb_text, "privacy": noun_arb_text, "tags": noun_arb_text, "eventStart": noun_type_date, "eventEnd": noun_type_date, "priority": noun_arb_text, "status": noun_arb_text, "complete": noun_arb_text, "completed": noun_type_date, "note": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-calendar-task &lt;event_id&gt; subject &lt;subject&gt; [description &lt;description&gt;] [attendees &lt;attendees&gt;] [privacy &lt;privacy&gt;] [tags &lt;tags&gt;] eventStart &lt;eventStart&gt; eventEnd &lt;eventEnd&gt; [priority &lt;priority&gt;] [status &lt;status&gt;] [complete &lt;complete&gt;] [completed &lt;completed&gt;] [notes &lt;notes&gt;]",
  execute: function (event_id, modifiers) {
    try {
      checkParameter(event_id.text, "event_id");
    var params = {event_id: event_id.text};
    addParameter(modifiers, "subject", params, "subject", true);
    addParameter(modifiers, "description", params, "description");
    addParameter(modifiers, "attendees", params, "attendees");
    addParameter(modifiers, "privacy", params, "privacy");
    addParameter(modifiers, "tags", params, "tags");
    addParameter(modifiers, "eventStart", params, "eventStart", true);
    addParameter(modifiers, "eventEnd", params, "eventEnd", true);
    addParameter(modifiers, "priority", params, "priority");
    addParameter(modifiers, "status", params, "status");
    addParameter(modifiers, "complete", params, "complete");
    addParameter(modifiers, "completed", params, "completed");
    addParameter(modifiers, "notes", params, "notes");
      odsExecute("calendar.task.edit", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-calendar-item-by-id",
  takes: {"event_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-calendar-item-by-id &lt;event_id&gt;",
  execute: function (event_id) {
    try {
      checkParameter(event_id.text, "event_id");
    var params = {event_id: event_id.text};
      odsExecute("calendar.delete", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-export-calendar",
  takes: {"instance_id": noun_type_id},
  modifiers: {"events": noun_arb_text, "tasks": noun_arb_text, "periodFrom": noun_type_date, "periodTo": noun_type_date, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-export-calendar &lt;instance_id&gt; [events &lt;events&gt;] [tasks &lt;tasks&gt;] [periodFrom &lt;periodFrom&gt;] [periodTo &lt;periodTo&gt;] [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",
  preview: function (previewBlock, instance_id, modifiers) {
    try {
      checkParameter(instance_id.text);
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "events", params, "events");
    addParameter(modifiers, "tasks", params, "tasks");
    addParameter(modifiers, "periodFrom", params, "periodFrom");
    addParameter(modifiers, "periodTo", params, "periodTo");
    addParameter(modifiers, "tagsInclude", params, "tagsInclude");
    addParameter(modifiers, "tagsExclude", params, "tagsExclude");
      odsPreview (previewBlock, "calendar.export", params, "calendar");
    } catch (ex) {
    }
        },
});

CmdUtils.CreateCommand({
  name: "ods-import-calendar",
  takes: {"instance_id": noun_type_id},
  modifiers: {"source": noun_arb_text, "sourceType": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "events": noun_arb_text, "tasks": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-import-calendar &lt;instance_id&gt; source &lt;source&gt; sourceType &lt;WebDAV|URL&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [events &lt;events&gt;] [tasks &lt;tasks&gt;] [tags &lt;tags&gt;]",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "source", params, "source", true);
    addParameter(modifiers, "sourceType", params, "sourceType", true);
    addParameter(modifiers, "userName", params, "userName");
    addParameter(modifiers, "userPassword", params, "userPassword");
    addParameter(modifiers, "events", params, "events");
    addParameter(modifiers, "tasks", params, "tasks");
    addParameter(modifiers, "tags", params, "tags");
      odsExecute("calendar.import", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-calendar-annotation-by-id",
  takes: {"annotation_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-calendar-annotation-by-id &lt;annotation_id&gt;",

  preview: function (annotation_id, modifiers) {
    try {
      checkParameter(annotation_id.text);
    var params = {annotation_id: annotation_id.text};
      odsPreview (previewBlock, "calendar.annotation.get", params, "calendar");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-calendar-annotation",
  takes: {"event_id": noun_type_id},
  modifiers: {"author": noun_arb_text, "body": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-annotation &lt;event_id&gt; author &lt;author&gt; body &lt;body&gt;",
  execute: function (event_id, modifiers) {
    try {
      checkParameter(event_id.text, "event_id");
    var params = {event_id: event_id.text};
    addParameter(modifiers, "author", params, "author", true);
    addParameter(modifiers, "body", params, "body", true);
      odsExecute("calendar.annotation.new", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-calendar-annotation-claim",
  takes: {"annotation_id": noun_type_id},
  modifiers: {"iri": noun_arb_text, "relation": noun_arb_text, "value": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-annotation-claim &lt;annotation_id&gt; iri &lt;iri&gt; relation &lt;relation&gt; value &lt;value&gt;",
  execute: function (annotation_id, modifiers) {
    try {
      checkParameter(annotation_id.text, "annotation_id");
    var params = {annotation_id: annotation_id.text};
    addParameter(modifiers, "iri", params, "claimIri", true);
    addParameter(modifiers, "relation", params, "claimRelation", true);
    addParameter(modifiers, "value", params, "claimValue", true);
      odsExecute("calendar.annotation.claim", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-calendar-annotation",
  takes: {"annotation_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-calendar-annotation &lt;annotation_id&gt;",
  execute: function (annotation_id) {
    try {
      checkParameter(annotation_id.text, "annotation_id");
    var params = {annotation_id: annotation_id.text};
      odsExecute("calendar.annotation.delete", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-calendar-comment-by-id",
  takes: {"comment_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-calendar-comment-by-id &lt;comment_id&gt;",

  preview: function (previewBlock, comment_id) {
    try {
      checkParameter(comment_id.text);
    var params = {comment_id: comment_id.text};
      odsPreview (previewBlock, "calendar.comment.get", params, "calendar");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-calendar-comment",
  takes: {"event_id": noun_type_id},
  modifiers: {"title": noun_arb_text, "body": noun_arb_text, "author": noun_arb_text, "authorMail": noun_arb_text, "authorUrl": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-comment &lt;event_id&gt; title &lt;title&gt; body &lt;body&gt; author &lt;author&gt; authorMail &lt;authorMail&gt; authorUrl &lt;authorUrl&gt;",
  execute: function (event_id, modifiers) {
    try {
      checkParameter(event_id.text, "event_id");
    var params = {event_id: event_id.text};
    addParameter(modifiers, "title", params, "title", true);
    addParameter(modifiers, "body", params, "text", true);
    addParameter(modifiers, "author", params, "name", true);
    addParameter(modifiers, "authorMail", params, "email", true);
    addParameter(modifiers, "authorUrl", params, "url", true);
      odsExecute("calendar.comment.new", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-calendar-comment",
  takes: {"comment_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-calendar-comment &lt;comment_id&gt;",
  execute: function (comment_id) {
    try {
      checkParameter(comment_id.text, "comment_id");
    var params = {comment_id: comment_id.text};
      odsExecute("calendar.comment.delete", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-calendar-publication",
  takes: {"instance_id": noun_type_id},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "destinationType": noun_arb_text, "destination": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "events": noun_arb_text, "tasks": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-publication &lt;instance_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [destinationType &lt;destinationType&gt;] destination &lt;destination&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [events &lt;events&gt;] [tasks &lt;tasks&gt;]",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
      var params = {inst_id: instance_id.text};
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers, "updateType", params, "updateType");
    addParameter(modifiers, "updatePeriod", params, "updatePeriod");
    addParameter(modifiers, "updateFreq", params, "updateFreq");
    addParameter(modifiers, "destinationType", params, "destinationType");
    addParameter(modifiers, "destination", params, "destination", true);
    addParameter(modifiers, "userName", params, "userName");
    addParameter(modifiers, "userPassword", params, "userPassword");
    addParameter(modifiers, "events", params, "events");
    addParameter(modifiers, "tasks", params, "tasks");
      odsExecute("calendar.publication.new", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});


CmdUtils.CreateCommand({
  name: "ods-update-calendar-publication",
  takes: {"publication_id": noun_type_id},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "destinationType": noun_arb_text, "destination": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "events": noun_arb_text, "tasks": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-calendar-publication &lt;publication_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [destinationType &lt;destinationType&gt;] destination &lt;destination&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [events &lt;events&gt;] [tasks &lt;tasks&gt;]",
  execute: function (publication_id, modifiers) {
    try {
      checkParameter(publication_id.text, "publication_id");
    var params = {publication_id: publication_id.text};
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers, "updateType", params, "updateType");
    addParameter(modifiers, "updatePeriod", params, "updatePeriod");
    addParameter(modifiers, "updateFreq", params, "updateFreq");
    addParameter(modifiers, "destinationType", params, "destinationType");
    addParameter(modifiers, "destination", params, "destination", true);
    addParameter(modifiers, "userName", params, "userName");
    addParameter(modifiers, "userPassword", params, "userPassword");
    addParameter(modifiers, "events", params, "events");
    addParameter(modifiers, "tasks", params, "tasks");
      odsExecute("calendar.publication.edit", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-calendar-publication",
  takes: {"publication_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-calendar-publication &lt;publication_id&gt;",
  execute: function (publication_id) {
    try {
      checkParameter(publication_id.text, "publication_id");
    var params = {publication_id: publication_id.text};
      odsExecute("calendar.publication.delete", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-calendar-subscription",
  takes: {"instance_id": noun_type_id},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "sourceType": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "events": noun_arb_text, "tasks": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-subscription &lt;instance_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [sourceType &lt;sourceType&gt;] source &lt;source&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [events &lt;events&gt;] [tasks &lt;tasks&gt;]",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
      var params = {inst_id: instance_id.text};
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers, "updateType", params, "updateType");
    addParameter(modifiers, "updatePeriod", params, "updatePeriod");
    addParameter(modifiers, "updateFreq", params, "updateFreq");
    addParameter(modifiers, "sourceType", params, "sourceType");
    addParameter(modifiers, "source", params, "source", true);
    addParameter(modifiers, "userName", params, "userName");
    addParameter(modifiers, "userPassword", params, "userPassword");
    addParameter(modifiers, "events", params, "events");
    addParameter(modifiers, "tasks", params, "tasks");
      odsExecute("calendar.subscription.new", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-update-calendar-subscription",
  takes: {"subscription_id": noun_type_id},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "sourceType": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "events": noun_arb_text, "tasks": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-calendar-subscription &lt;subscription_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [sourceType &lt;sourceType&gt;] source &lt;source&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [events &lt;events&gt;] [tasks &lt;tasks&gt;]",
  execute: function (subscription_id, modifiers) {
    try {
      checkParameter(subscription_id.text, "subscription_id");
    var params = {subscription_id: subscription_id.text};
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers, "updateType", params, "updateType");
    addParameter(modifiers, "updatePeriod", params, "updatePeriod");
    addParameter(modifiers, "updateFreq", params, "updateFreq");
    addParameter(modifiers, "sourceType", params, "sourceType");
    addParameter(modifiers, "source", params, "source", true);
    addParameter(modifiers, "userName", params, "userName");
    addParameter(modifiers, "userPassword", params, "userPassword");
    addParameter(modifiers, "events", params, "events");
    addParameter(modifiers, "tasks", params, "tasks");
      odsExecute("calendar.subscription.edit", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-calendar-subscription",
  takes: {"subscription_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-calendar-subscription &lt;subscription_id&gt;",
  execute: function (subscription_id) {
    try {
      checkParameter(subscription_id.text, "subscription_id");
    var params = {subscription_id: subscription_id.text};
      odsExecute("calendar.subscription.delete", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-set-calendar-options",
  takes: {"instance_id": noun_type_id},
  modifiers: {"options": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-set-calendar-options &lt;instance_id&gt; options &lt;options&gt;",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
      var params = {inst_id: instance_id.text};
    addParameter(modifiers, "options", params, "options");
      odsExecute("calendar.options.set", params, "calendar");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-calendar-options",
  takes: {"instance_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-calendar-options &lt;instance_id&gt;",

  preview: function (previewBlock, instance_id) {
    try {
      checkParameter(instance_id.text);
      var params = {inst_id: instance_id.text};
      odsPreview (previewBlock, "calendar.options.get", params, "calendar");
    } catch (ex) {
    }
  }
});

////////////////////////////////////
///// ODS AddressBook /////////////////
////////////////////////////////////

CmdUtils.CreateCommand({
  name: "ods-set-addressbook-oauth",
  takes: {"oauth": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS AddressBook OAuth. Get your oauth at " + ODS.getOAuthServer() + "/oauth_sid.vsp",
  help: "Type ods-set-addressbook-oauth &lt;oauth&gt;. Get your oauth at " + ODS.getOAuthServer(),
  execute: function(oauth) {
    try {
      checkParameter(oauth.text, "addressbook instance OAuth");
    ODS.setOAuth("addressbook", oauth.text);
    displayMessage("Your ODS AddressBook instance OAuth has been set.");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-addressbook-contact-by-id",
  takes: {"contact_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-addressbook-contact-by-id &lt;contact_id&gt;",

  preview: function (previewBlock, contact_id) {
    try {
      checkParameter(contact_id.text);
    var params = {contact_id: contact_id.text};
      odsPreview (previewBlock, "addressbook.get", params, "addressbook");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-addressbook-contact",
  takes: {"instance_id": noun_type_id},
  modifiers: {"name": noun_arb_text, "title": noun_arb_text, "fName": noun_arb_text, "mName": noun_arb_text, "lName": noun_arb_text, "fullName": noun_arb_text, "gender": noun_arb_text, "birthday": noun_arb_text, "iri": noun_arb_text, "foaf": noun_arb_text, "mail": noun_arb_text, "web": noun_arb_text, "icq": noun_arb_text, "skype": noun_arb_text, "aim": noun_arb_text, "yahoo": noun_arb_text, "msn": noun_arb_text, "hCountry": noun_arb_text, "hState": noun_arb_text, "hCity": noun_arb_text, "hCode": noun_arb_text, "hAddress1": noun_arb_text, "hAddress2": noun_arb_text, "hTzone": noun_arb_text, "hLat": noun_arb_text, "hLng": noun_arb_text, "hPhone": noun_arb_text, "hMobile": noun_arb_text, "hFax": noun_arb_text, "hMail": noun_arb_text, "hWeb": noun_arb_text, "bCountry": noun_arb_text, "bState": noun_arb_text, "bCity": noun_arb_text, "bCode": noun_arb_text, "bAddress1": noun_arb_text, "bAddress2": noun_arb_text, "bTzone": noun_arb_text, "bLat": noun_arb_text, "bLng": noun_arb_text, "bPhone": noun_arb_text, "bMobile": noun_arb_text, "bFax": noun_arb_text, "bIndustry": noun_arb_text, "bOrganization": noun_arb_text, "bDepartment": noun_arb_text, "bJob": noun_arb_text, "bMail": noun_arb_text, "bWeb": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-addressbook-contact &lt;instance_id&gt; name &lt;name&gt; [title &lt;title&gt;] [fName &lt;fName&gt;] [mName &lt;mName&gt;] [lName &lt;lName&gt;] [fullName &lt;fullName&gt;] [gender &lt;gender&gt;] [birthday &lt;birthday&gt;] [iri &lt;iri&gt;] [foaf &lt;foaf&gt;] [mail &lt;mail&gt;] [web &lt;web&gt;] [icq &lt;icq&gt;] [skype &lt;skype&gt;] [aim &lt;aim&gt;] [yahoo &lt;yahoo&gt;] [msn &lt;msn&gt;] [hCountry &lt;hCountry&gt;] [hState &lt;hState&gt;] [hCity &lt;hCity&gt;] [hCode &lt;hCode&gt;] [hAddress1 &lt;hAddress1&gt;] [hAddress2 &lt;hAddress2&gt;] [hTzone &lt;hTzone&gt;] [hLat &lt;hLat&gt;] [hLng &lt;hLng&gt;] [hPhone &lt;hPhone&gt;] [hMobile &lt;hMobile&gt;] [hFax &lt;hFax&gt;] [hMail &lt;hMail&gt;] [hWeb &lt;hWeb&gt;] [bCountry &lt;bCountry&gt;] [bState &lt;bState&gt;] [bCity &lt;bCity&gt;] [bCode &lt;bCode&gt;] [bAddress1 &lt;bAddress1&gt;] [bAddress2 &lt;bAddress2&gt;] [bTzone &lt;bTzone&gt;] [bLat &lt;bLat&gt;] [bLng &lt;bLng&gt;] [bPhone &lt;bPhone&gt;] [bMobile &lt;bMobile&gt;] [bFax &lt;bFax&gt;] [bIndustry &lt;bIndustry&gt;] [bOrganization &lt;bOrganization&gt;] [bDepartment &lt;bDepartment&gt;] [bJob &lt;bJob&gt;] [bMail &lt;bMail&gt;] [bWeb &lt;bWeb&gt;] [tags &lt;tags&gt;]",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers,"title", params,"title");
    addParameter(modifiers,"fName", params,"fName");
    addParameter(modifiers,"mName", params,"mName");
    addParameter(modifiers,"lName", params,"lName");
    addParameter(modifiers,"fullName", params,"fullName");
    addParameter(modifiers,"gender", params,"gender");
    addParameter(modifiers,"birthday", params,"birthday");
    addParameter(modifiers,"iri", params,"iri");
    addParameter(modifiers,"foaf", params,"foaf");
    addParameter(modifiers,"mail", params,"mail");
    addParameter(modifiers,"web", params,"web");
    addParameter(modifiers,"icq", params,"icq");
    addParameter(modifiers,"skype", params,"skype");
    addParameter(modifiers,"aim", params,"aim");
    addParameter(modifiers,"yahoo", params,"yahoo");
    addParameter(modifiers,"msn", params,"msn");
    addParameter(modifiers,"hCountry", params,"hCountry");
    addParameter(modifiers,"hState", params,"hState");
    addParameter(modifiers,"hCity", params,"hCity");
    addParameter(modifiers,"hCode", params,"hCode");
    addParameter(modifiers,"hAddress1", params,"hAddress1");
    addParameter(modifiers,"hAddress2", params,"hAddress2");
    addParameter(modifiers,"hTzone", params,"hTzone");
    addParameter(modifiers,"hLat", params,"hLat");
    addParameter(modifiers,"hLng", params,"hLng");
    addParameter(modifiers,"hPhone", params,"hPhone");
    addParameter(modifiers,"hMobile", params,"hMobile");
    addParameter(modifiers,"hFax", params,"hFax");
    addParameter(modifiers,"hMail", params,"hMail");
    addParameter(modifiers,"hWeb", params,"hWeb");
    addParameter(modifiers,"bCountry", params,"bCountry");
    addParameter(modifiers,"bState", params,"bState");
    addParameter(modifiers,"bCity", params,"bCity");
    addParameter(modifiers,"bCode", params,"bCode");
    addParameter(modifiers,"bAddress1", params,"bAddress1");
    addParameter(modifiers,"bAddress2", params,"bAddress2");
    addParameter(modifiers,"bTzone", params,"bTzone");
    addParameter(modifiers,"bLat", params,"bLat");
    addParameter(modifiers,"bLng", params,"bLng");
    addParameter(modifiers,"bPhone", params,"bPhone");
    addParameter(modifiers,"bMobile", params,"bMobile");
    addParameter(modifiers,"bFax", params,"bFax");
    addParameter(modifiers,"bIndustry", params,"bIndustry");
    addParameter(modifiers,"bOrganization", params,"bOrganization");
    addParameter(modifiers,"bDepartment", params,"bDepartment");
    addParameter(modifiers,"bJob", params,"bJob");
    addParameter(modifiers,"bMail", params,"bMail");
    addParameter(modifiers,"bWeb", params,"bWeb");
    addParameter(modifiers,"tags", params,"tags");
      odsExecute("addressbook.new", params, "addressbook");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-update-addressbook-contact",
  takes: {"contact_id": noun_type_id},
  modifiers: {"name": noun_arb_text, "title": noun_arb_text, "fName": noun_arb_text, "mName": noun_arb_text, "lName": noun_arb_text, "fullName": noun_arb_text, "gender": noun_arb_text, "birthday": noun_arb_text, "iri": noun_arb_text, "foaf": noun_arb_text, "mail": noun_arb_text, "web": noun_arb_text, "icq": noun_arb_text, "skype": noun_arb_text, "aim": noun_arb_text, "yahoo": noun_arb_text, "msn": noun_arb_text, "hCountry": noun_arb_text, "hState": noun_arb_text, "hCity": noun_arb_text, "hCode": noun_arb_text, "hAddress1": noun_arb_text, "hAddress2": noun_arb_text, "hTzone": noun_arb_text, "hLat": noun_arb_text, "hLng": noun_arb_text, "hPhone": noun_arb_text, "hMobile": noun_arb_text, "hFax": noun_arb_text, "hMail": noun_arb_text, "hWeb": noun_arb_text, "bCountry": noun_arb_text, "bState": noun_arb_text, "bCity": noun_arb_text, "bCode": noun_arb_text, "bAddress1": noun_arb_text, "bAddress2": noun_arb_text, "bTzone": noun_arb_text, "bLat": noun_arb_text, "bLng": noun_arb_text, "bPhone": noun_arb_text, "bMobile": noun_arb_text, "bFax": noun_arb_text, "bIndustry": noun_arb_text, "bOrganization": noun_arb_text, "bDepartment": noun_arb_text, "bJob": noun_arb_text, "bMail": noun_arb_text, "bWeb": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-addressbook-contact &lt;contact_id&gt; name &lt;name&gt; [title &lt;title&gt;] [fName &lt;fName&gt;] [mName &lt;mName&gt;] [lName &lt;lName&gt;] [fullName &lt;fullName&gt;] [gender &lt;gender&gt;] [birthday &lt;birthday&gt;] [iri &lt;iri&gt;] [foaf &lt;foaf&gt;] [mail &lt;mail&gt;] [web &lt;web&gt;] [icq &lt;icq&gt;] [skype &lt;skype&gt;] [aim &lt;aim&gt;] [yahoo &lt;yahoo&gt;] [msn &lt;msn&gt;] [hCountry &lt;hCountry&gt;] [hState &lt;hState&gt;] [hCity &lt;hCity&gt;] [hCode &lt;hCode&gt;] [hAddress1 &lt;hAddress1&gt;] [hAddress2 &lt;hAddress2&gt;] [hTzone &lt;hTzone&gt;] [hLat &lt;hLat&gt;] [hLng &lt;hLng&gt;] [hPhone &lt;hPhone&gt;] [hMobile &lt;hMobile&gt;] [hFax &lt;hFax&gt;] [hMail &lt;hMail&gt;] [hWeb &lt;hWeb&gt;] [bCountry &lt;bCountry&gt;] [bState &lt;bState&gt;] [bCity &lt;bCity&gt;] [bCode &lt;bCode&gt;] [bAddress1 &lt;bAddress1&gt;] [bAddress2 &lt;bAddress2&gt;] [bTzone &lt;bTzone&gt;] [bLat &lt;bLat&gt;] [bLng &lt;bLng&gt;] [bPhone &lt;bPhone&gt;] [bMobile &lt;bMobile&gt;] [bFax &lt;bFax&gt;] [bIndustry &lt;bIndustry&gt;] [bOrganization &lt;bOrganization&gt;] [bDepartment &lt;bDepartment&gt;] [bJob &lt;bJob&gt;] [bMail &lt;bMail&gt;] [bWeb &lt;bWeb&gt;] [tags &lt;tags&gt;]",
  execute: function (contact_id, modifiers) {
    try {
      checkParameter(contact_id.text, "contact_id");
    var params = {contact_id: contact_id.text};
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers,"title", params,"title");
    addParameter(modifiers,"fName", params,"fName");
    addParameter(modifiers,"mName", params,"mName");
    addParameter(modifiers,"lName", params,"lName");
    addParameter(modifiers,"fullName", params,"fullName");
    addParameter(modifiers,"gender", params,"gender");
    addParameter(modifiers,"birthday", params,"birthday");
    addParameter(modifiers,"iri", params,"iri");
    addParameter(modifiers,"foaf", params,"foaf");
    addParameter(modifiers,"mail", params,"mail");
    addParameter(modifiers,"web", params,"web");
    addParameter(modifiers,"icq", params,"icq");
    addParameter(modifiers,"skype", params,"skype");
    addParameter(modifiers,"aim", params,"aim");
    addParameter(modifiers,"yahoo", params,"yahoo");
    addParameter(modifiers,"msn", params,"msn");
    addParameter(modifiers,"hCountry", params,"hCountry");
    addParameter(modifiers,"hState", params,"hState");
    addParameter(modifiers,"hCity", params,"hCity");
    addParameter(modifiers,"hCode", params,"hCode");
    addParameter(modifiers,"hAddress1", params,"hAddress1");
    addParameter(modifiers,"hAddress2", params,"hAddress2");
    addParameter(modifiers,"hTzone", params,"hTzone");
    addParameter(modifiers,"hLat", params,"hLat");
    addParameter(modifiers,"hLng", params,"hLng");
    addParameter(modifiers,"hPhone", params,"hPhone");
    addParameter(modifiers,"hMobile", params,"hMobile");
    addParameter(modifiers,"hFax", params,"hFax");
    addParameter(modifiers,"hMail", params,"hMail");
    addParameter(modifiers,"hWeb", params,"hWeb");
    addParameter(modifiers,"bCountry", params,"bCountry");
    addParameter(modifiers,"bState", params,"bState");
    addParameter(modifiers,"bCity", params,"bCity");
    addParameter(modifiers,"bCode", params,"bCode");
    addParameter(modifiers,"bAddress1", params,"bAddress1");
    addParameter(modifiers,"bAddress2", params,"bAddress2");
    addParameter(modifiers,"bTzone", params,"bTzone");
    addParameter(modifiers,"bLat", params,"bLat");
    addParameter(modifiers,"bLng", params,"bLng");
    addParameter(modifiers,"bPhone", params,"bPhone");
    addParameter(modifiers,"bMobile", params,"bMobile");
    addParameter(modifiers,"bFax", params,"bFax");
    addParameter(modifiers,"bIndustry", params,"bIndustry");
    addParameter(modifiers,"bOrganization", params,"bOrganization");
    addParameter(modifiers,"bDepartment", params,"bDepartment");
    addParameter(modifiers,"bJob", params,"bJob");
    addParameter(modifiers,"bMail", params,"bMail");
    addParameter(modifiers,"bWeb", params,"bWeb");
    addParameter(modifiers,"tags", params,"tags");
      odsExecute("addressbook.edit", params, "addressbook");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-addressbook-contact-by-id",
  takes: {"contact_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-addressbook-contact-by-id &lt;contact_id&gt;",
  execute: function (contact_id) {
    try {
      checkParameter(contact_id.text, "contact_id");
    var params = {contact_id: contact_id.text};
      odsExecute("addressbook.delete", params, "addressbook");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-export-addressbook",
  takes: {"instance_id": noun_type_id},
  modifiers: {"contentType": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-export-addressbook &lt;instance_id&gt; [contentType &lt;contentType&gt;]",

  preview: function (previewBlock, instance_id, modifiers) {
    try {
      checkParameter(instance_id.text);
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "contentType", params, "contentType");
      odsPreview (previewBlock, "addressbook.export", params, "addressbook");
    } catch (ex) {
    }
  },
});

CmdUtils.CreateCommand({
  name: "ods-import-addressbook",
  takes: {"instance_id": noun_type_id},
  modifiers: {"source": noun_arb_text, "sourceType": noun_arb_text, "contentType": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-import-addressbook &lt;instance_id&gt; source &lt;source&gt; [sourceType &lt;WebDAV|URL&gt;] [tasks &lt;tasks&gt;] [contentType &lt;contentType&gt;] [tags &lt;tags&gt;]",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "source", params, "source", true);
    addParameter(modifiers, "sourceType", params, "sourceType");
    addParameter(modifiers, "contentType", params, "contentType");
    addParameter(modifiers, "tags", params, "tags");
      odsExecute("addressbook.import", params, "addressbook");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-addressbook-annotation-by-id",
  takes: {"annotation_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-addressbook-annotation-by-id &lt;annotation_id&gt;",

  preview: function (annotation_id, modifiers) {
    try {
      checkParameter(annotation_id.text);
    var params = {annotation_id: annotation_id.text};
      odsPreview (previewBlock, "addressbook.annotation.get", params, "addressbook");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-addressbook-annotation",
  takes: {"contact_id": noun_type_id},
  modifiers: {"author": noun_arb_text, "body": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-addressbook-annotation &lt;contact_id&gt; author &lt;author&gt; body &lt;body&gt;",
  execute: function (contact_id, modifiers) {
    try {
      checkParameter(contact_id.text, "contact_id");
    var params = {contact_id: contact_id.text};
    addParameter(modifiers, "author", params, "author", true);
    addParameter(modifiers, "body", params, "body", true);
      odsExecute("addressbook.annotation.new", params, "addressbook");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-addressbook-annotation-claim",
  takes: {"annotation_id": noun_type_id},
  modifiers: {"iri": noun_arb_text, "relation": noun_arb_text, "value": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-addressbook-annotation-claim &lt;annotation_id&gt; iri &lt;iri&gt; relation &lt;relation&gt; value &lt;value&gt;",
  execute: function (annotation_id, modifiers) {
    try {
      checkParameter(annotation_id.text, "annotation_id");
    var params = {annotation_id: annotation_id.text};
    addParameter(modifiers, "iri", params, "claimIri", true);
    addParameter(modifiers, "relation", params, "claimRelation", true);
    addParameter(modifiers, "value", params, "claimValue", true);
      odsExecute("addressbook.annotation.claim", params, "addressbook");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-addressbook-annotation",
  takes: {"annotation_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-addressbook-annotation &lt;annotation_id&gt;",
  execute: function (annotation_id) {
    try {
      checkParameter(annotation_id.text, "annotation_id");
    var params = {annotation_id: annotation_id.text};
      odsExecute("addressbook.annotation.delete", params, "addressbook");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-addressbook-comment-by-id",
  takes: {"comment_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-addressbook-comment-by-id &lt;comment_id&gt;",

  preview: function (previewBlock, comment_id) {
    try {
      checkParameter(comment_id.text);
    var params = {comment_id: comment_id.text};
      odsPreview (previewBlock, "addressbook.comment.get", params, "addressbook");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-addressbook-comment",
  takes: {"contact_id": noun_type_id},
  modifiers: {"title": noun_arb_text, "body": noun_arb_text, "author": noun_arb_text, "authorMail": noun_arb_text, "authorUrl": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-addressbook-comment &lt;contact_id&gt; title &lt;title&gt; body &lt;body&gt; author &lt;author&gt; authorMail &lt;authorMail&gt; authorUrl &lt;authorUrl&gt;",
  execute: function (contact_id, modifiers) {
    try {
      checkParameter(contact_id.text, "contact_id");
    var params = {contact_id: contact_id.text};
      addParameter(modifiers, "title", params, "title", true);
      addParameter(modifiers, "body", params, "text", true);
      addParameter(modifiers, "author", params, "name", true);
      addParameter(modifiers, "authorMail", params, "email", true);
      addParameter(modifiers, "authorUrl", params, "url", true);
      odsExecute("addressbook.comment.new", params, "addressbook");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-addressbook-comment",
  takes: {"comment_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-addressbook-comment &lt;comment_id&gt;",
  execute: function (comment_id) {
    try {
      checkParameter(comment_id.text, "comment_id");
    var params = {comment_id: comment_id.text};
      odsExecute("addressbook.comment.delete", params, "addressbook");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-addressbook-publication",
  takes: {"instance_id": noun_type_id},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "destinationType": noun_arb_text, "destination": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-addressbook-publication &lt;instance_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [destinationType &lt;destinationType&gt;] destination &lt;destination&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
      var params = {inst_id: instance_id.text};
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers, "updateType", params, "updateType");
    addParameter(modifiers, "updatePeriod", params, "updatePeriod");
    addParameter(modifiers, "updateFreq", params, "updateFreq");
    addParameter(modifiers, "destinationType", params, "destinationType");
    addParameter(modifiers, "destination", params, "destination", true);
    addParameter(modifiers, "userName", params, "userName");
    addParameter(modifiers, "userPassword", params, "userPassword");
    addParameter(modifiers, "tagsInclude", params, "tagsInclude");
    addParameter(modifiers, "tagsExclude", params, "tagsExclude");
      odsExecute("addressbook.publication.new", params, "addressbook");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});


CmdUtils.CreateCommand({
  name: "ods-update-addressbook-publication",
  takes: {"publication_id": noun_type_id},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "destinationType": noun_arb_text, "destination": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-addressbook-publication &lt;publication_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [destinationType &lt;destinationType&gt;] destination &lt;destination&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",
  execute: function (publication_id, modifiers) {
    try {
      checkParameter(publication_id.text, "publication_id");
    var params = {publication_id: publication_id.text};
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers, "updateType", params, "updateType");
    addParameter(modifiers, "updatePeriod", params, "updatePeriod");
    addParameter(modifiers, "updateFreq", params, "updateFreq");
    addParameter(modifiers, "destinationType", params, "destinationType");
    addParameter(modifiers, "destination", params, "destination", true);
    addParameter(modifiers, "userName", params, "userName");
    addParameter(modifiers, "userPassword", params, "userPassword");
    addParameter(modifiers, "tagsInclude", params, "tagsInclude");
    addParameter(modifiers, "tagsExclude", params, "tagsExclude");
      odsExecute("addressbook.publication.edit", params, "addressbook");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-addressbook-publication",
  takes: {"publication_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-addressbook-publication &lt;publication_id&gt;",
  execute: function (publication_id) {
    try {
      checkParameter(publication_id.text, "publication_id");
    var params = {publication_id: publication_id.text};
      odsExecute("addressbook.publication.delete", params, "addressbook");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-addressbook-subscription",
  takes: {"instance_id": noun_type_id},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "sourceType": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-addressbook-subscription &lt;instance_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [sourceType &lt;sourceType&gt;] source &lt;source&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
      var params = {inst_id: instance_id.text};
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers, "updateType", params, "updateType");
    addParameter(modifiers, "updatePeriod", params, "updatePeriod");
    addParameter(modifiers, "updateFreq", params, "updateFreq");
    addParameter(modifiers, "sourceType", params, "sourceType");
    addParameter(modifiers, "source", params, "source", true);
    addParameter(modifiers, "userName", params, "userName");
    addParameter(modifiers, "userPassword", params, "userPassword");
    addParameter(modifiers, "tagsInclude", params, "tagsInclude");
    addParameter(modifiers, "tagsExclude", params, "tagsExclude");
      odsExecute("addressbook.subscription.new", params, "addressbook");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-update-addressbook-subscription",
  takes: {"subscription_id": noun_type_id},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "sourceType": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-addressbook-subscription &lt;subscription_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [sourceType &lt;sourceType&gt;] source &lt;source&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",
  execute: function (subscription_id, modifiers) {
    try {
      checkParameter(subscription_id.text, "subscription_id");
    var params = {subscription_id: subscription_id.text};
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers, "updateType", params, "updateType");
    addParameter(modifiers, "updatePeriod", params, "updatePeriod");
    addParameter(modifiers, "updateFreq", params, "updateFreq");
    addParameter(modifiers, "sourceType", params, "sourceType");
    addParameter(modifiers, "source", params, "source", true);
    addParameter(modifiers, "userName", params, "userName");
    addParameter(modifiers, "userPassword", params, "userPassword");
    addParameter(modifiers, "tagsInclude", params, "tagsInclude");
    addParameter(modifiers, "tagsExclude", params, "tagsExclude");
      odsExecute("addressbook.subscription.edit", params, "addressbook");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-addressbook-subscription",
  takes: {"subscription_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software",
  email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-addressbook-subscription &lt;subscription_id&gt;",
  execute: function (subscription_id) {
    try {
      checkParameter(subscription_id.text, "subscription_id");
    var params = {subscription_id: subscription_id.text};
      odsExecute("addressbook.subscription.delete", params, "addressbook");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-set-addressbook-options",
  takes: {"instance_id": noun_type_id},
  modifiers: {"options": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-set-addressbook-options &lt;instance_id&gt; options &lt;options&gt;",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
      var params = {inst_id: instance_id.text};
    addParameter(modifiers, "options", params, "options");
      odsExecute("addressbook.options.set", params, "addressbook");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-addressbook-options",
  takes: {"instance_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-addressbook-options &lt;instance_id&gt;",

  preview: function (previewBlock, instance_id) {
    try {
      checkParameter(instance_id.text);
      var params = {inst_id: instance_id.text};
      odsPreview (previewBlock, "addressbook.options.get", params, "addressbook");
    } catch (ex) {
    }
  }
});

////////////////////////////////////
///// ods polls /////////////////
////////////////////////////////////

CmdUtils.CreateCommand({
  name: "ods-set-poll-oauth",
  takes: {"oauth": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS poll OAuth. Get your oauth at " + ODS.getOAuthServer() + "/oauth_sid.vsp",
  help: "Type ods-set-poll-oauth &lt;oauth&gt;. Get your oauth at " + ODS.getOAuthServer(),
  execute: function(oauth) {
    try {
      checkParameter(oauth.text, "poll instance OAuth");
    ODS.setOAuth("poll", oauth.text);
    displayMessage("Your ODS poll instance OAuth has been set.");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-poll-by-id",
  takes: {"poll_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-poll-by-id &lt;poll_id&gt;",

  preview: function (previewBlock, poll_id) {
    try {
      checkParameter(poll_id.text);
    var params = {poll_id: poll_id.text};
      odsPreview (previewBlock, "poll.get", params, "poll");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-poll",
  takes: {"instance_id": noun_type_id},
  modifiers: {"name": noun_arb_text, "description": noun_arb_text, "tags": noun_arb_text, "multi_vote": noun_arb_text, "vote_result": noun_arb_text, "vote_result_before": noun_arb_text, "vote_result_opened": noun_arb_text, "date_start": noun_type_date, "date_end": noun_type_date, "mode": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-poll &lt;instance_id&gt; name &lt;name&gt; [description &lt;description&gt;] [tags &lt;tags&gt;] [multi_vote &lt;multi_vote&gt;] [vote_result &lt;vote_result&gt;] [vote_result_before &lt;vote_result_before&gt;] [vote_result_opened &lt;vote_result_opened&gt;] [date_start &lt;date_start&gt;] [date_end &lt;date_end&gt;] [mode &lt;mode&gt;]",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers, "description", params, "description");
    addParameter(modifiers, "tags", params, "tags");
    addParameter(modifiers, "multi_vote", params, "multi_vote");
    addParameter(modifiers, "vote_result", params, "vote_result");
    addParameter(modifiers, "vote_result_before", params, "vote_result_before");
    addParameter(modifiers, "vote_result_opened", params, "vote_result_opened");
    addParameter(modifiers, "date_start", params, "date_start");
    addParameter(modifiers, "date_end", params, "date_end");
    addParameter(modifiers, "mode", params, "mode");
      odsExecute("poll.new", params, "poll");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-update-poll",
  takes: {"poll_id": noun_type_id},
  modifiers: {"name": noun_arb_text, "description": noun_arb_text, "tags": noun_arb_text, "multi_vote": noun_arb_text, "vote_result": noun_arb_text, "vote_result_before": noun_arb_text, "vote_result_opened": noun_arb_text, "date_start": noun_type_date, "date_end": noun_type_date, "mode": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-poll &lt;poll_id&gt; name &lt;name&gt; [description &lt;description&gt;] [tags &lt;tags&gt;] [multi_vote &lt;multi_vote&gt;] [vote_result &lt;vote_result&gt;] [vote_result_before &lt;vote_result_before&gt;] [vote_result_opened &lt;vote_result_opened&gt;] [date_start &lt;date_start&gt;] [date_end &lt;date_end&gt;] [mode &lt;mode&gt;]",
  execute: function (poll_id, modifiers) {
    try {
      checkParameter(poll_id.text, "poll_id");
    var params = {poll_id: poll_id.text};
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers, "description", params, "description");
    addParameter(modifiers, "tags", params, "tags");
    addParameter(modifiers, "multi_vote", params, "multi_vote");
    addParameter(modifiers, "vote_result", params, "vote_result");
    addParameter(modifiers, "vote_result_before", params, "vote_result_before");
    addParameter(modifiers, "vote_result_opened", params, "vote_result_opened");
    addParameter(modifiers, "date_start", params, "date_start");
    addParameter(modifiers, "date_end", params, "date_end");
    addParameter(modifiers, "mode", params, "mode");
      odsExecute("poll.edit", params, "poll");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-poll-by-id",
  takes: {"poll_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-poll-by-id &lt;poll_id&gt;",
  execute: function (poll_id) {
    try {
      checkParameter(poll_id.text, "poll_id");
    var params = {poll_id: poll_id.text};
      odsExecute("poll.delete", params, "poll");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-poll-question",
  takes: {"poll_id": noun_type_id},
  modifiers: {"questionNo": noun_type_integer, "text": noun_arb_text, "description": noun_arb_text, "required": noun_arb_text, "type": noun_arb_text, "answer": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-poll-question &lt;poll_id&gt; questionNo &lt;questionNo&gt; text &lt;text&gt; [description &lt;description&gt;] [required &lt;required&gt;] [type &lt;type&gt;] [answer &lt;answer&gt;]",
  execute: function (poll_id, modifiers) {
    try {
      checkParameter(poll_id.text, "poll_id");
    var params = {poll_id: poll_id.text};
    addParameter(modifiers, "questionNo", params, "questionNo", true);
    addParameter(modifiers, "text", params, "text", true);
    addParameter(modifiers, "description", params, "description");
    addParameter(modifiers, "required", params, "required");
    addParameter(modifiers, "type", params, "type");
      addParameter(modifiers, "answer", params, "answer", true);
      odsExecute("poll.question.new", params, "poll");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-poll-question",
  takes: {"poll_id": noun_type_id},
  modifiers: {"questionNo": noun_type_integer},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-poll-question &lt;poll_id&gt; questionNo &lt;questionNo&gt;",
  execute: function (poll_id, modifiers) {
    try {
      checkParameter(poll_id.text, "poll_id");
    var params = {poll_id: poll_id.text};
    addParameter(modifiers, "questionNo", params, "questionNo", true);
      odsExecute("poll.question.delete", params, "poll");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-activate-poll",
  takes: {"poll_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-activate-poll &lt;poll_id&gt;",
  execute: function (poll_id) {
    try {
      checkParameter(poll_id.text, "poll_id");
    var params = {poll_id: poll_id.text};
      odsExecute("poll.activate", params, "poll");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-close-poll",
  takes: {"poll_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-close-poll &lt;poll_id&gt;",
  execute: function (poll_id) {
    try {
      checkParameter(poll_id.text, "poll_id");
    var params = {poll_id: poll_id.text};
      odsExecute("poll.close", params, "poll");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-clear-poll",
  takes: {"poll_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-clear-poll &lt;poll_id&gt;",
  execute: function (poll_id) {
    try {
      checkParameter(poll_id.text, "poll_id");
    var params = {poll_id: poll_id.text};
      odsExecute("poll.clear", params, "poll");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-vote-poll",
  takes: {"poll_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-vote-poll &lt;poll_id&gt;",
  execute: function (poll_id) {
    try {
      checkParameter(poll_id.text, "poll_id");
    var params = {poll_id: poll_id.text};
      odsExecute("poll.vote", params, "poll");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-poll-vote-answer",
  takes: {"vote_id": noun_type_id},
  modifiers: {"questionNo": noun_type_integer, "answerNo": noun_type_integer, "value": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-poll-vote-answer &lt;vote_id&gt; questionNo &lt;questionNo&gt; answerNo &lt;answerNo&gt; value &lt;value&gt;",
  execute: function (vote_id, modifiers) {
    try {
      checkParameter(vote_id.text, "vote_id");
    var params = {vote_id: vote_id.text};
    addParameter(modifiers, "questionNo", params, "questionNo", true);
    addParameter(modifiers, "answerNo", params, "answerNo", true);
    addParameter(modifiers, "value", params, "value", true);
      odsExecute("poll.vote.answer", params, "poll");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-result-poll",
  takes: {"poll_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-result-poll &lt;poll_id&gt;",

  preview: function (previewBlock, poll_id) {
    try {
      checkParameter(poll_id.text, "poll_id");
    var params = {poll_id: poll_id.text};
      odsPreview (previewBlock, "poll.result", params, "poll");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-poll-comment-by-id",
  takes: {"comment_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-poll-comment-by-id &lt;comment_id&gt;",

  preview: function (previewBlock, comment_id) {
    try {
      checkParameter(comment_id.text);
    var params = {comment_id: comment_id.text};
      odsPreview (previewBlock, "poll.comment.get", params, "poll");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-poll-comment",
  takes: {"poll_id": noun_type_id},
  modifiers: {"title": noun_arb_text, "body": noun_arb_text, "author": noun_arb_text, "authorMail": noun_arb_text, "authorUrl": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-poll-comment &lt;poll_id&gt; title &lt;title&gt; body &lt;body&gt; author &lt;author&gt; authorMail &lt;authorMail&gt; authorUrl &lt;authorUrl&gt;",
  execute: function (poll_id, modifiers) {
    try {
      checkParameter(poll_id.text, "poll_id");
    var params = {poll_id: poll_id.text};
    addParameter(modifiers, "title", params, "title", true);
    addParameter(modifiers, "body", params, "text", true);
    addParameter(modifiers, "author", params, "name", true);
    addParameter(modifiers, "authorMail", params, "email", true);
    addParameter(modifiers, "authorUrl", params, "url", true);
      odsExecute("poll.comment.new", params, "poll");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-poll-comment",
  takes: {"comment_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-poll-comment &lt;comment_id&gt;",
  execute: function (comment_id) {
    try {
      checkParameter(comment_id.text, "comment_id");
    var params = {comment_id: comment_id.text};
      odsExecute("poll.comment.delete", params, "poll");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-set-polls-options",
  takes: {"instance_id": noun_type_id},
  modifiers: {"options": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-set-polls-options &lt;instance_id&gt; options &lt;options&gt;",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
      var params = {inst_id: instance_id.text};
    addParameter(modifiers, "options", params, "options");
      odsExecute("poll.options.set", params, "poll");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-polls-options",
  takes: {"instance_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-polls-options &lt;instance_id&gt;",

  preview: function (previewBlock, instance_id) {
    try {
      checkParameter(instance_id.text);
      var params = {inst_id: instance_id.text};
      odsPreview (previewBlock, "poll.options.get", params, "poll");
    } catch (ex) {
    }
  }
});

////////////////////////////////////
///// ods weblog /////////////////
////////////////////////////////////

CmdUtils.CreateCommand({
  name: "ods-set-weblog-oauth",
  takes: {"oauth": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS weblog OAuth. Get your oauth at " + ODS.getOAuthServer() + "/oauth_sid.vsp",
  help: "Type ods-set-weblog-oauth &lt;oauth&gt;. Get your oauth at " + ODS.getOAuthServer(),
  execute: function(oauth) {
    try {
      checkParameter(oauth.text, "weblog instance OAuth");
    ODS.setOAuth("weblog", oauth.text);
    displayMessage("Your ODS Weblog instance OAuth has been set.");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-weblog-by-id",
  takes: {"instance_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-weblog-by-id &lt;instance_id&gt;",
  preview: function (previewBlock, instance_id) {
    try {
      checkParameter(instance_id.text);
    var params = {inst_id: instance_id.text};
      odsPreview (previewBlock, "weblog.get", params, "weblog");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-weblog-post-by-id",
  takes: {"post_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-weblog-post-by-id &lt;post_id&gt;",
  preview: function (previewBlock, post_id) {
    try {
      checkParameter(post_id.text);
    var params = {post_id: post_id.text};
      odsPreview (previewBlock, "weblog.post.get", params, "weblog");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-weblog-post",
  takes: {"instance_id": noun_type_id},
  modifiers: {"title": noun_arb_text, "description": noun_arb_text, "categories": noun_arb_text, "dateCreated": noun_type_date, "enclosure": noun_arb_text, "source": noun_arb_text, "link": noun_arb_text, "author": noun_arb_text, "comments": noun_arb_text, "allowComments": noun_arb_text, "allowPings": noun_arb_text, "convertBreaks": noun_arb_text, "excerpt": noun_arb_text, "pingUrls": noun_arb_text, "textMore": noun_arb_text, "keywords": noun_arb_text, "publish": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-weblog-post &lt;instance_id&gt; title &lt;title&gt; description &lt;description&gt; [categories &lt;categories&gt;] [dateCreated &lt;dateCreated&gt;] [enclosure &lt;enclosure&gt;] [source &lt;source&gt;] [link &lt;link&gt;] [author &lt;author&gt;] [comments &lt;comments&gt;] [allowComments &lt;allowComments&gt;] [allowPings &lt;allowPings&gt;] [convertBreaks &lt;convertBreaks&gt;] [excerpt &lt;excerpt&gt;] [pingUrls &lt;pingUrls&gt;] [textMore &lt;textMore&gt;] [keywords &lt;keywords&gt;] [publish &lt;publish&gt;]",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "title", params, "title", true);
    addParameter(modifiers, "description", params, "description", true);
    addParameter(modifiers, "categories", params, "categories");
    addParameter(modifiers, "dateCreated", params, "date_created");
    addParameter(modifiers, "enclosure", params, "enclosure");
    addParameter(modifiers, "source", params, "source");
    addParameter(modifiers, "link", params, "link");
    addParameter(modifiers, "comments", params, "comments");
    addParameter(modifiers, "allowComments", params, "allow_comments");
    addParameter(modifiers, "allowPings", params, "allow_pings");
    addParameter(modifiers, "convertBreaks", params, "convert_breaks");
    addParameter(modifiers, "excerpt", params, "excerpt");
    addParameter(modifiers, "pingUrls", params, "tb_ping_urls");
    addParameter(modifiers, "textMore", params, "text_more");
    addParameter(modifiers, "keywords", params, "keywords");
    addParameter(modifiers, "publish", params, "publish");
      odsExecute("weblog.post.new", params, "weblog");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-update-weblog-post",
  takes: {"post_id": noun_type_id},
  modifiers: {"title": noun_arb_text, "description": noun_arb_text, "categories": noun_arb_text, "dateCreated": noun_type_date, "enclosure": noun_arb_text, "source": noun_arb_text, "link": noun_arb_text, "author": noun_arb_text, "comments": noun_arb_text, "allowComments": noun_arb_text, "allowPings": noun_arb_text, "convertBreaks": noun_arb_text, "excerpt": noun_arb_text, "pingUrls": noun_arb_text, "textMore": noun_arb_text, "keywords": noun_arb_text, "publish": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-weblog-post &lt;post_id&gt; title &lt;title&gt; description &lt;description&gt; [categories &lt;categories&gt;] [dateCreated &lt;dateCreated&gt;] [enclosure &lt;enclosure&gt;] [source &lt;source&gt;] [link &lt;link&gt;] [author &lt;author&gt;] [comments &lt;comments&gt;] [allowComments &lt;allowComments&gt;] [allowPings &lt;allowPings&gt;] [convertBreaks &lt;convertBreaks&gt;] [excerpt &lt;excerpt&gt;] [pingUrls &lt;pingUrls&gt;] [textMore &lt;textMore&gt;] [keywords &lt;keywords&gt;] [publish &lt;publish&gt;]",
  execute: function (post_id, modifiers) {
    try {
      checkParameter(post_id.text, "post_id");
    var params = {post_id: post_id.text};
    addParameter(modifiers, "title", params, "title", true);
    addParameter(modifiers, "description", params, "description", true);
    addParameter(modifiers, "categories", params, "categories");
    addParameter(modifiers, "dateCreated", params, "date_created");
    addParameter(modifiers, "enclosure", params, "enclosure");
    addParameter(modifiers, "source", params, "source");
    addParameter(modifiers, "link", params, "link");
    addParameter(modifiers, "comments", params, "comments");
    addParameter(modifiers, "allowComments", params, "allow_comments");
    addParameter(modifiers, "allowPings", params, "allow_pings");
    addParameter(modifiers, "convertBreaks", params, "convert_breaks");
    addParameter(modifiers, "excerpt", params, "excerpt");
    addParameter(modifiers, "pingUrls", params, "tb_ping_urls");
    addParameter(modifiers, "textMore", params, "text_more");
    addParameter(modifiers, "keywords", params, "keywords");
    addParameter(modifiers, "publish", params, "publish");
      odsExecute("weblog.post.edit", params, "weblog");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-weblog-post-by-id",
  takes: {"post_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-weblog-post-by-id &lt;post_id&gt;",
  execute: function (post_id) {
    try {
      checkParameter(post_id.text, "post_id");
    var params = {post_id: post_id.text};
      odsExecute("weblog.post.delete", params, "weblog");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-weblog-comment-by-id",
  takes: {"post_id": noun_type_id},
  modifiers: {"comment_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-weblog-comment-by-id &lt;post_id&gt; comment_id &lt;comment_id&gt;",

  preview: function (previewBlock, post_id, modifiers) {
    try {
      checkParameter(post_id.text);
    var params = {post_id: post_id.text};
    addParameter(modifiers, "comment_id", params, "comment_id", true);
      odsPreview (previewBlock, "weblog.comment.get", params, "weblog");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-weblog-comment",
  takes: {"post_id": noun_type_id},
  modifiers: {"name": noun_arb_text, "title": noun_arb_text, "authorMail": noun_arb_text, "authorUrl": noun_arb_text, "text": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-weblog-comment &lt;post_id&gt; name &lt;name&gt; title &lt;title&gt; authorMail &lt;authorMail&gt; authorUrl &lt;authorUrl&gt; text &lt;text&gt;",
  execute: function (post_id, modifiers) {
    try {
      checkParameter(post_id.text, "post_id");
    var params = {post_id: post_id.text};
    addParameter(modifiers, "name", params, "name", true);
    addParameter(modifiers, "title", params, "title", true);
    addParameter(modifiers, "authorMail", params, "email", true);
    addParameter(modifiers, "authorUrl", params, "url", true);
    addParameter(modifiers, "text", params, "text", true);
      odsExecute("weblog.comment.new", params, "weblog");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-approve-weblog-comment",
  takes: {"post_id": noun_type_id},
  modifiers: {"comment_id": noun_type_id, "flag": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-approve-weblog-comment &lt;post_id&gt; comment_id &lt;comment_id&gt; flag &lt;flag&gt;",
  execute: function (post_id, modifiers) {
    try {
      checkParameter(post_id.text);
    var params = {post_id: post_id.text};
    addParameter(modifiers, "comment_id", params, "comment_id", true);
    addParameter(modifiers, "flag", params, "flag", true);
      odsExecute("weblog.comment.approve", params, "weblog");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-weblog-comment",
  takes: {"post_id": noun_type_id},
  modifiers: {"comment_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-weblog-comment post_id comment_id &lt;comment_id&gt;",
  execute: function (post_id, modifiers) {
    try {
      checkParameter(post_id.text);
    var params = {post_id: post_id.text};
    addParameter(modifiers, "comment_id", params, "comment_id", true);
      odsExecute("weblog.comment.delete", params, "weblog");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-set-weblog-options",
  takes: {"instance_id": noun_type_id},
  modifiers: {"options": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-set-weblog-options &lt;instance_id&gt; options &lt;options&gt;",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "options", params, "options");
      odsExecute("weblog.options.set", params, "weblog");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-weblog-options",
  takes: {"instance_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-weblog-options &lt;instance_id&gt;",
  preview: function (previewBlock, instance_id) {
    try {
      checkParameter(instance_id.text);
    var params = {inst_id: instance_id.text};
      odsPreview (previewBlock, "weblog.options.get", params, "weblog");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-set-weblog-upstreaming",
  takes: {"instance_id": noun_type_id},
  modifiers: {"targetRpcUrl": noun_arb_text, "targetBlogId": noun_arb_text, "targetProtocolId": noun_arb_text, "targetUserName": noun_arb_text, "targetPassword": noun_arb_text, "aclAllow": noun_arb_text, "aclDeny": noun_arb_text, "syncInterval": noun_arb_text, "keepRemote": noun_arb_text, "maxRetries": noun_arb_text, "maxRetransmits": noun_arb_text, "initializeLog": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-set-weblog-upstreaming &lt;instance_id&gt; targetRpcUrl &lt;targetRpcUrl&gt; targetBlogId &lt;targetBlogId&gt; targetProtocolId &lt;targetProtocolId&gt; targetUserName &lt;targetUserName&gt; targetPassword &lt;targetPassword&gt; aclAllow &lt;aclAllow&gt; aclDeny &lt;aclDeny&gt; syncInterval &lt;syncInterval&gt; keepRemote &lt;keepRemote&gt; maxRetries &lt;maxRetries&gt; [maxRetransmits &lt;maxRetransmits&gt;] [initializeLog &lt;initializeLog&gt;]",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "targetRpcUrl", params, "target_rpc_url", true);
    addParameter(modifiers, "targetBlogId", params, "target_blog_id", true);
    addParameter(modifiers, "targetProtocolId", params, "target_protocol_id", true);
    addParameter(modifiers, "targetUserName", params, "target_uname", true);
    addParameter(modifiers, "targetPassword", params, "target_password", true);
    addParameter(modifiers, "aclAllow", params, "acl_allow", true);
    addParameter(modifiers, "aclDeny", params, "acl_deny", true);
    addParameter(modifiers, "syncInterval", params, "sync_interval", true);
    addParameter(modifiers, "keepRemote", params, "keep_remote", true);
    addParameter(modifiers, "maxRetries", params, "max_retries", true);
    addParameter(modifiers, "maxRetransmits", params, "max_retransmits");
    addParameter(modifiers, "initializeLog", params, "initialize_log");
      odsExecute("weblog.upstreaming.set", params, "weblog");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-weblog-upstreaming",
  takes: {"job_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-weblog-upstreaming &lt;job_id&gt;",
  execute: function (job_id) {
    try {
      checkParameter(job_id.text, "job_id");
    var params = {job_id: job_id.text};
      odsExecute("weblog.upstreaming.get", params, "weblog");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-weblog-upstreaming",
  takes: {"job_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-weblog-upstreaming &lt;job_id&gt;",
  execute: function (job_id) {
    try {
      checkParameter(job_id.text, "job_id");
    var params = {job_id: job_id.text};
      odsExecute("weblog.upstreaming.remove", params, "weblog");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-set-weblog-tagging",
  takes: {"instance_id": noun_type_id},
  modifiers: {"flag": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-set-weblog-tagging &lt;instance_id&gt; flag &lt;flag&gt;",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "flag", params, "flag", true);
      odsExecute("weblog.tagging.set", params, "weblog");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-retag-weblog-tagging",
  takes: {"instance_id": noun_type_id},
  modifiers: {"keepExistingTags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-retag-weblog-tagging &lt;instance_id&gt; keepExistingTags &lt;keepExistingTags&gt;",
  execute: function (instance_id, modifiers) {
    try {
      checkParameter(instance_id.text, "instance_id");
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "keepExistingTags", params, "keep_existing_tags", true);
      odsExecute("weblog.tagging.retag", params, "weblog");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

////////////////////////////////////
///// ods discussion /////////////////
////////////////////////////////////
CmdUtils.CreateCommand({
  name: "ods-set-discussion-oauth",
  takes: {"oauth": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS Discussion OAuth. Get your oauth at " + ODS.getOAuthServer() + "/oauth_sid.vsp",
  help: "Type ods-set-discussion-oauth &lt;oauth&gt;. Get your oauth at " + ODS.getOAuthServer(),
  execute: function(oauth) {
    try {
      checkParameter(oauth.text, "discussion instance OAuth");
    ODS.setOAuth("discussion", oauth.text);
    displayMessage("Your ODS Discussion instance OAuth has been set.");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-discussion-groups",
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-discussion-groups",
  preview: function (previewBlock) {
    var params = {};
    odsPreview (previewBlock, "discussion.groups.get", params, "discussion");
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-discussion-group-by-id",
  takes: {"group_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-discussion-group-by-id &lt;group_id&gt;",
  preview: function (previewBlock, group_id) {
    try {
      checkParameter(group_id.text, "group_id");
    var params = {group_id: group_id.text};
      odsPreview (previewBlock, "discussion.group.get", params, "discussion");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-discussion-group",
  takes: {"name": noun_arb_text},
  modifiers: {"description": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-discussion-group &lt;name&gt; description &lt;description&gt;",
  execute: function (name, modifiers) {
    try {
      checkParameter(name.text, "name");
    var params = {name: name.text};
    addParameter(modifiers, "description", params, "description", true);
      odsExecute("discussion.group.new", params, "discussion");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-discussion-group-by-id",
  takes: {"group_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-discussion-group-by-id &lt;group_id&gt;",
  execute: function (group_id) {
    try {
      checkParameter(group_id.text, "group_id");
    var params = {group_id: group_id.text};
      odsExecute("discussion.group.remove", params, "discussion");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-discussion-feed",
  takes: {"group_id": noun_type_id},
  modifiers: {"name": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-discussion-feed &lt;group_id&gt; name &lt;name&gt;",
  execute: function (group_id, modifiers) {
    try {
      checkParameter(group_id.text, "group_id");
    var params = {group_id: group_id.text};
    addParameter(modifiers, "name", params, "name", true);
      odsExecute("discussion.feed.new", params, "discussion");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-discussion-feed-by-id",
  takes: {"feed_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-discussion-feed-by-id &lt;feed_id&gt;",
  execute: function (feed_id) {
    try {
      checkParameter(feed_id.text, "feed_id");
    var params = {feed_id: feed_id.text};
      odsExecute("discussion.feed.remove", params, "discussion");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-discussion-message-by-id",
  takes: {"message_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-discussion-message-by-id &lt;message_id&gt;",
  preview: function (previewBlock, message_id) {
    try {
      checkParameter(message_id.text, "message_id");
    var params = {message_id: message_id.text};
      odsPreview (previewBlock, "discussion.message.get", params, "discussion");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-discussion-message",
  takes: {"group_id": noun_type_id},
  modifiers: {"subject": noun_arb_text, "body": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-discussion-message &lt;group_id&gt; subject &lt;subject&gt; body &lt;body&gt;",
  execute: function (group_id, modifiers) {
    try {
      checkParameter(group_id.text, "group_id");
    var params = {group_id: group_id.text};
    addParameter(modifiers, "subject", params, "subject", true);
    addParameter(modifiers, "body", params, "body", true);
      odsExecute("discussion.message.new", params, "discussion");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-discussion-comment-by-id",
  takes: {"comment_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-discussion-comment-by-id &lt;comment_id&gt;",
  preview: function (previewBlock, comment_id) {
    try {
      checkParameter(comment_id.text, "comment_id");
    var params = {comment_id: comment_id.text};
      odsPreview (previewBlock, "discussion.comment.get", params, "discussion");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-discussion-comment",
  takes: {"parent_id": noun_arb_text},
  modifiers: {"subject": noun_arb_text, "body": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-discussion-comment &lt;parent_id&gt; subject &lt;subject&gt; body &lt;body&gt;",
  execute: function (parent_id, modifiers) {
    try {
      checkParameter(parent_id.text, "parent_id");
    var params = {parent_id: parent_id.text};
    addParameter(modifiers, "subject", params, "subject", true);
    addParameter(modifiers, "body", params, "body", true);
      odsExecute("discussion.comment.new", params, "discussion");
    } catch (ex) {
      displayMessage(ex);
    }
  }
});
