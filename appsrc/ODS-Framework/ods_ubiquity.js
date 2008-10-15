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

function odsExecute (cmdName, cmdParams, cmdApplication, cmdMode, authMode)
{
  var res = '';
  var logMode = ODS.getLog();

  if (logMode)
    CmdUtils.log(cmdName + " - start");
  if (authMode)
  {
    var res = jQuery.ajax({
      type: "GET",
      url: ODS.getServer() + "/api/" + cmdName,
      data: cmdParams,
      error: function(XMLHttpRequest, textStatus, errorThrown) {
          if (!cmdMode)
            displayMessage("ODS Controller error - coomand not executed");
          if (logMode)
            CmdUtils.log(cmdName + ": " + textStatus);
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
          if (!cmdMode)
            displayMessage("ODS Controller error - coomand not executed");
          if (logMode)
            CmdUtils.log(ODS.getOAuthServer() + "/get_consumer_key" + " - text status: " + textStatus);
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
          if (!cmdMode)
            displayMessage("ODS Controller error - coomand not executed");
          if (logMode)
            CmdUtils.log(ODS.getOAuthServer() + "/sign_request" + " - text status: " + textStatus);
        },
      async: false
      }).responseText;

    res = jQuery.ajax({
      type: "GET",
      url: apiURL,
      error: function(XMLHttpRequest, textStatus, errorThrown) {
          if (!cmdMode)
            displayMessage("ODS Controller error - coomand not executed");
          if (logMode)
            CmdUtils.log(apiURL + " - text status: " + textStatus);
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
          if (!cmdMode)
            displayMessage("ODS Controller error - coomand not executed");
          if (logMode)
            CmdUtils.log(cmdName + ": " + textStatus);
        },
      async: false
      }).responseText;
  }
  if (!cmdMode)
    displayMessage(res);
  if (logMode)
    CmdUtils.log(cmdName + " - end");
  return res;
}

function checkParameter(parameter, parameterName)
{
  if (!parameter || parameter.length < 1)
  {
    if (parameterName)
      displayMessage("Please, enter " + parameterName);
    return false;
  }
  return true;
}

function addParameter(modifiers, modifierName, parameters, parameterName, modifierCheck)
{
  if (modifierCheck)
  {
    if (!modifiers[modifierName])
    {
      displayMessage("Please, enter " + modifierName);
      return false;
    }
    if (!checkParameter(modifiers[modifierName].text, modifierName))
      return false;
  }
  if (modifiers[modifierName] && modifiers[modifierName].text && (modifiers[modifierName].text.length > 0))
    parameters[parameterName] = modifiers[modifierName].text;
  return true;
}

function xml_encode(xml)
{
  if (!xml) {return;}

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
  takes: {},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Enable log messages",
  help: "Type ods-log-enable",

  execute: function(sid) {
    ODS.setLog(true);
  }
});

CmdUtils.CreateCommand({
  name: "ods-log-disable",
  takes: {},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Disable log messages",
  help: "Type ods-log-disable",

  execute: function(sid) {
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
    if (!checkParameter(hostUrl.text, "host-url")) {return;}
    ODS.setServer(hostUrl.text);
    displayMessage("Your ODS host URL has been set to " + ODS.getServer());
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
    if (!checkParameter(hostUrl.text, "host-url")) {return;}
    ODS.setOAuthServer(hostUrl.text);
    displayMessage("Your ODS OAuth host has been set to " + ODS.getOAuthServer());
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
    if (!checkParameter(mode.text, "mode type - sid or oauth")) {return;}
    ODS.setMode(mode.text);
    displayMessage("Your ODS API mode has been set to " + ODS.getMode());
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
    if (!checkParameter(sid.text, "session ID")) {return;}
    ODS.setSid(sid.text);
    displayMessage("Your ODS session ID has been set to " + ODS.getSid());
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
    if (!checkParameter(user.text, "user")) {return;}
    var params = {user_name: user.text};
    addParameter(modifiers, "password", params, "password_hash", true);
    params["password_hash"] = sha (params["user_name"] + params["password_hash"]);
    var sid = odsExecute ("user.authenticate", params, "", false, true);
    ODS.setSid(sid);
    displayMessage("Your was authenticated. Your ODS session ID has been set to " + ODS.getSid());
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-params",
  takes: {},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Get ODS Ubiquity params",
  help: "Type ods-params",

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
    if (!checkParameter(oauth.text, "ODS OAuth")) {return;}
    ODS.setOAuth("", oauth.text);
    displayMessage("Your ODS OAuth has been set.");
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
    if (!checkParameter(uri.text, "uri")) {return;}
    var windowManager = Components.classes["@mozilla.org/appshell/window-mediator;1"].getService(Components.interfaces.nsIWindowMediator);
    var browserWindow = windowManager.getMostRecentWindow("navigator:browser");
    var browser = browserWindow.getBrowser();
    var new_tab = browser.addTab(uri.text);
    new_tab.control.selectedIndex = new_tab.control.childNodes.length-1;
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
    if (!checkParameter(user.text)) {return;}
    var params = {name: user.text};
    var res = odsExecute ("user.get", params, "", "preview");
    previewBlock.innerHTML = "<pre>" + xml_encode(res) + "</pre>";
  },
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
    if (!checkParameter(user.text, "user")) {return;}
    var params = {name: user.text};
    odsExecute ("user.delete", params, "")
  }
});

CmdUtils.CreateCommand({
  name: "ods-freeze-user",
  takes: {"user": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-freeze-user &lt;username&gt;",

  execute: function (user) {
    if (!checkParameter(user.text, "user")) {return;}
    var params = {name: user.text};
    odsExecute ("user.freeze", params, "")
  }
});

CmdUtils.CreateCommand({
  name: "ods-unfreeze-user",
  takes: {"user": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-unfreeze-user &lt;username&gt;",

  execute: function (user) {
    if (!checkParameter(user.text, "user")) {return;}
    var params = {name: user.text};
    odsExecute ("user.unfreeze", params, "")
  }
});

CmdUtils.CreateCommand({
  name: "ods-new-user-annotation",
  takes: {"iri": noun_arb_text},
  modifiers: {"has": noun_arb_text, "with": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-new-user-annotation &lt;iri&gt; has &lt;relation&gt; with &lt;value&gt;",

  execute: function (iri, modifiers) {
    if (!checkParameter(iri.text, "iri")) {return;}
    var params = {claimIri: iri.text};
    addParameter(modifiers, "has", params, "claimRelation", true);
    addParameter(modifiers, "with", params, "claimValue", true);
    odsExecute ("user.annotation.new", params, "")
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
  help: "Type ods-new-user-annotation &lt;iri&gt; has &lt;relation&gt; with &lt;value&gt;",

  execute: function (iri, modifiers) {
    if (!checkParameter(iri.text, "iri")) {return;}
    var params = {claimIri: iri.text};
    addParameter(modifiers, "has", params, "claimRelation", true);
    addParameter(modifiers, "with", params, "claimValue", true);
    odsExecute ("user.annotation.delete", params, "")
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
    if (!checkParameter(oauth.text, "briefcase instance OAuth")) {return;}
    ODS.setOAuth("briefcase", oauth.text);
    displayMessage("Your ODS briefcase instance OAuth has been set.");
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-briefcase-resource",
  takes: {"path": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Get your ODS briefcase resource content",
  help: "Type ods-get-briefcase-resource &lt;path&gt;",

  preview: function (previewBlock, path) {
    if (!checkParameter(path.text)) {return;}
    var params = {path: path.text};
    var res = odsExecute ("briefcase.resource.get", params, "briefcase", "preview");
    previewBlock.innerHTML = "<pre>" + xml_encode(res) + "</pre>";
  },
});

CmdUtils.CreateCommand({
  name: "ods-store-briefcase-resource",
  takes: {"path": noun_arb_text},
  modifiers: {"with": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Store content on resource path",
  help: "Type ods-store-briefcase-resource &lt;path&gt; with &lt;content&gt;",

  execute: function(path, modifiers) {
    if (!checkParameter(path.text, "path")) {return;}
    var params = {path: path.text};
    addParameter(modifiers, "content", params, "content", true);
    odsExecute ("briefcase.resource.store", params, "briefcase")
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
    if (!checkParameter(path.text, "path")) {return;}
    var params = {path: path.text};
    odsExecute ("briefcase.resource.remove", params, "briefcase")
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
    if (!checkParameter(path.text, "path")) {return;}
    var params = {path: path.text};
    odsExecute ("briefcase.collection.create", params, "briefcase")
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
    if (!checkParameter(path.text, "path")) {return;}
    var params = {path: path.text};
    odsExecute ("briefcase.collection.delete", params, "briefcase")
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
    if (!checkParameter(path.text, "path")) {return;}
    var params = {from_path: path.text};
    addParameter(modifiers, "to", params, "to_path", true);
    odsExecute ("briefcase.copy", params, "briefcase")
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
    if (!checkParameter(path.text, "path")) {return;}
    var params = {from_path: path.text};
    addParameter(modifiers, "to", params, "to_path", true);
    odsExecute ("briefcase.move", params, "briefcase")
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
    if (!checkParameter(path.text, "path")) {return;}
    var params = {path: path.text};
    addParameter(modifiers, "property", params, "property", true);
    addParameter(modifiers, "with", params, "value", true);
    odsExecute ("briefcase.property.set", params, "briefcase")
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
    if (!checkParameter(path.text, "path")) {return;}
    var params = {path: path.text};
    addParameter(modifiers, "property", params, "property", true);
    odsExecute ("briefcase.property.get", params, "briefcase")
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
    if (!checkParameter(path.text, "path")) {return;}
    var params = {path: path.text};
    addParameter(modifiers, "property", params, "property", true);
    odsExecute ("briefcase.property.delete", params, "briefcase")
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
    if (!checkParameter(oauth.text, "bookmark instance OAuth")) {return;}
    ODS.setOAuth("bookmark", oauth.text);
    displayMessage("Your ODS bookmark instance OAuth has been set.");
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-bookmark-by-id",
  takes: {"bookmark_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-bookmark-by-id &lt;bookmark_id&gt;",

  preview: function (previewBlock, bookmark_id) {
    if (!checkParameter(bookmark_id.text)) {return;}
    var params = {bookmark_id: bookmark_id.text};
    var res = odsExecute ("bookmark.get", params, "bookmark", "preview");
    previewBlock.innerHTML = "<pre>" + xml_encode(res) + "</pre>";
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-bookmark",
  takes: {"instance_id": noun_arb_text},
  modifiers: {"title": noun_arb_text, "url": noun_arb_text, "description": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmark &lt;instance_id&gt; title &lt;title&gt; url &lt;url&gt; [description &lt;description&gt;] [tags &lt;tags&gt;]",

  execute: function (instance_id, modifiers) {
    if (!checkParameter(instance_id.text, "instance_id")) {return;}
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "title", params, "name", true);
    addParameter(modifiers, "url", params, "uri", true);
    addParameter(modifiers, "description", params, "description");
    addParameter(modifiers, "tags", params, "tags");
    odsExecute ("bookmark.new", params, "bookmark")
    displayMessage("Bookmark was created.");
  }
});

CmdUtils.CreateCommand({
  name: "ods-update-bookmark",
  takes: {"bookmark_id": noun_arb_text},
  modifiers: {"title": noun_arb_text, "url": noun_arb_text, "description": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-bookmark &lt;bookmark_id&gt; title &lt;title&gt; url &lt;url&gt; [description &lt;description&gt;] [tags &lt;tags&gt;]",

  execute: function (bookmark_id, modifiers) {
    if (!checkParameter(bookmark_id.text, "bookmark_id")) {return;}
    var params = {bookmark_id: bookmark_id.text};
    addParameter(modifiers, "title", params, "name", true);
    addParameter(modifiers, "url", params, "uri", true);
    addParameter(modifiers, "description", params, "description");
    addParameter(modifiers, "tags", params, "tags");
    odsExecute ("bookmark.new", params, "bookmark")
    displayMessage("Bookmark was updated.");
    }
});

CmdUtils.CreateCommand({
  name: "ods-delete-bookmark-by-id",
  takes: {"bookmark_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmark-by-id &lt;bookmark_id&gt;",

  execute: function (bookmark_id) {
    if (!checkParameter(bookmark_id.text, "bookmark_id")) {return;}
    var params = {bookmark_id: bookmark_id.text};
    odsExecute ("bookmark.delete", params, "bookmark")
    displayMessage("Bookmark was deleted.");
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-bookmark-folder",
  takes: {"instance_id": noun_arb_text},
  modifiers: {"path": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmark-folder &lt;instance_id&gt; path &lt;path&gt;",

  execute: function (instance_id, modifiers) {
    if (!checkParameter(instance_id.text, "instance_id")) {return;}
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "path", params, "path", true);
    odsExecute ("bookmark.folder.new", params, "bookmark")
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-bookmark-folder",
  takes: {"instance_id": noun_arb_text},
  modifiers: {"path": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmark-folder &lt;instance_id&gt; path &lt;path&gt;",

  execute: function (instance_id, modifiers) {
    if (!checkParameter(instance_id.text, "instance_id")) {return;}
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "path", params, "path", true);
    odsExecute ("bookmark.folder.delete", params, "bookmark")
  }
});

CmdUtils.CreateCommand({
  name: "ods-export-bookmark",
  takes: {"instance_id": noun_arb_text},
  modifiers: {"exportType": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-export-bookmark &lt;instance_id&gt; [exportType &lt;Netscape|XBEL&gt;]",

  preview: function (previewBlock, instance_id, modifiers) {
    if (!checkParameter(instance_id.text)) {return;}
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "exportType", params, "contentType");
    var res = odsExecute ("bookmark.export", params, "bookmark", "preview")
    previewBlock.innerHTML = "<pre>" + xml_encode(res) + "</pre>";
        },
});

CmdUtils.CreateCommand({
  name: "ods-import-bookmark",
  takes: {"instance_id": noun_arb_text},
  modifiers: {"source": noun_arb_text, "sourceType": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-import-bookmark &lt;instance_id&gt; source &lt;source&gt; sourceType &lt;WebDAV|URL&gt;",

  execute: function (instance_id, modifiers) {
    if (!checkParameter(instance_id.text, "instance_id")) {return;}
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "source", params, "source", true);
    addParameter(modifiers, "sourceType", params, "sourceType", true);
    odsExecute ("bookmark.import", params, "bookmark")
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-bookmark-annotation-by-id",
  takes: {"annotation_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-bookmark-annotation-by-id &lt;annotation_id&gt;",

  preview: function (annotation_id, modifiers) {
    if (!checkParameter(annotation_id.text)) {return;}
    var params = {annotation_id: annotation_id.text};
    var res = odsExecute ("bookmark.annotation.get", params, "bookmark", "preview")
    previewBlock.innerHTML = "<pre>" + xml_encode(res) + "</pre>";
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-bookmark-annotation",
  takes: {"bookmark_id": noun_arb_text},
  modifiers: {"author": noun_arb_text, "body": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmark-annotation &lt;bookmark_id&gt; author &lt;author&gt; body &lt;body&gt;",

  execute: function (bookmark_id, modifiers) {
    if (!checkParameter(bookmark_id.text, "bookmark_id")) {return;}
    var params = {bookmark_id: bookmark_id.text};
    addParameter(modifiers, "author", params, "author", true);
    addParameter(modifiers, "body", params, "body", true);
    odsExecute ("bookmark.annotation.new", params, "bookmark")
  }
});

CmdUtils.CreateCommand({
  name: "ods-update-bookmark-annotation",
  takes: {"annotation_id": noun_arb_text},
  modifiers: {"author": noun_arb_text, "body": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-bookmark-annotation &lt;annotation_id&gt; author &lt;author&gt; body &lt;body&gt;",

  execute: function (annotation_id, modifiers) {
    if (!checkParameter(annotation_id.text, "annotation_id")) {return;}
    var params = {annotation_id: annotation_id.text};
    addParameter(modifiers, "author", params, "author", true);
    addParameter(modifiers, "body", params, "body", true);
    odsExecute ("bookmark.annotation.edit", params, "bookmark")
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-bookmark-annotation-claim",
  takes: {"annotation_id": noun_arb_text},
  modifiers: {"iri": noun_arb_text, "relation": noun_arb_text, "value": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmark-annotation-claim &lt;annotation_id&gt; iri &lt;iri&gt; relation &lt;relation&gt; value &lt;value&gt;",

  execute: function (annotation_id, modifiers) {
    if (!checkParameter(annotation_id.text, "annotation_id")) {return;}
    var params = {annotation_id: annotation_id.text};
    addParameter(modifiers, "iri", params, "claimIri", true);
    addParameter(modifiers, "relation", params, "claimRelation", true);
    addParameter(modifiers, "value", params, "claimValue", true);
    odsExecute ("bookmark.annotation.claim", params, "bookmark")
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-bookmark-annotation",
  takes: {"annotation_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmark-annotation &lt;annotation_id&gt;",

  execute: function (annotation_id) {
    if (!checkParameter(annotation_id.text, "annotation_id")) {return;}
    var params = {annotation_id: annotation_id.text};
    odsExecute ("bookmark.annotation.delete", params, "bookmark")
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-bookmark-comment-by-id",
  takes: {"comment_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-bookmark-comment-by-id &lt;comment_id&gt;",

  preview: function (previewBlock, comment_id) {
    if (!checkParameter(comment_id.text)) {return;}
    var params = {comment_id: comment_id.text};
    var res = odsExecute ("bookmark.comment.get", params, "bookmark", "preview")
    previewBlock.innerHTML = "<pre>" + xml_encode(res) + "</pre>";
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-bookmark-comment",
  takes: {"bookmark_id": noun_arb_text},
  modifiers: {"title": noun_arb_text, "body": noun_arb_text, "author": noun_arb_text, "authorMail": noun_arb_text, "authorUrl": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmark-comment &lt;bookmark_id&gt; title &lt;title&gt; body &lt;body&gt; author &lt;author&gt; authorMail &lt;authorMail&gt; authorUrl &lt;authorUrl&gt;",

  execute: function (bookmark_id, modifiers) {
    if (!checkParameter(bookmark_id.text, "bookmark_id")) {return;}
    var params = {bookmark_id: bookmark_id.text};
    addParameter(modifiers, "title", params, "title", true);
    addParameter(modifiers, "body", params, "text", true);
    addParameter(modifiers, "author", params, "name", true);
    addParameter(modifiers, "authorMail", params, "email", true);
    addParameter(modifiers, "authorUrl", params, "url", true);
    odsExecute ("bookmark.comment.new", params, "bookmark")
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-bookmark-comment",
  takes: {"comment_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmark-comment &lt;comment_id&gt;",

  execute: function (comment_id) {
    if (!checkParameter(comment_id.text, "comment_id")) {return;}
    var params = {comment_id: comment_id.text};
    odsExecute ("bookmark.comment.delete", params, "bookmark")
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-bookmark-publication",
  takes: {"instance_id": noun_arb_text},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "destinationType": noun_arb_text, "destination": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "folderPath": noun_arb_text, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmark-publication &lt;instance_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [destinationType &lt;destinationType&gt;] destination &lt;destination&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [folderPath &lt;folderPath&gt;] [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",

  execute: function (instance_id) {
    if (!checkParameter(instance_id.text, "instance_id")) {return;}
    var params = {instance_id: instance_id.text};
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
    odsExecute ("bookmark.publication.new", params, "bookmark")
  }
});


CmdUtils.CreateCommand({
  name: "ods-update-bookmark-publication",
  takes: {"publication_id": noun_arb_text},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "destinationType": noun_arb_text, "destination": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "folderPath": noun_arb_text, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-bookmark-publication &lt;publication_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [destinationType &lt;destinationType&gt;] destination &lt;destination&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [folderPath &lt;folderPath&gt;] [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",

  execute: function (publication_id) {
    if (!checkParameter(publication_id.text, "publication_id")) {return;}
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
    odsExecute ("bookmark.publication.edit", params, "bookmark")
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-bookmark-publication",
  takes: {"publication_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmark-publication &lt;publication_id&gt;",

  execute: function (publication_id) {
    if (!checkParameter(publication_id.text, "publication_id")) {return;}
    var params = {publication_id: publication_id.text};
    odsExecute ("bookmark.publication.delete", params, "bookmark")
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-bookmark-subscription",
  takes: {"instance_id": noun_arb_text},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "sourceType": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "folderPath": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmark-subscription &lt;instance_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [sourceType &lt;sourceType&gt;] source &lt;source&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [folderPath &lt;folderPath&gt;] [tags &lt;tags&gt;]",

  execute: function (instance_id) {
    if (!checkParameter(instance_id.text, "instance_id")) {return;}
    var params = {instance_id: instance_id.text};
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
    odsExecute ("bookmark.subscription.new", params, "bookmark")
  }
});

CmdUtils.CreateCommand({
  name: "ods-update-bookmark-subscription",
  takes: {"subscription_id": noun_arb_text},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "sourceType": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "folderPath": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-bookmark-subscription &lt;subscription_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [sourceType &lt;sourceType&gt;] source &lt;source&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [folderPath &lt;folderPath&gt;] [tags &lt;tags&gt;]",

  execute: function (subscription_id) {
    if (!checkParameter(subscription_id.text, "subscription_id")) {return;}
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
    odsExecute ("bookmark.subscription.edit", params, "bookmark")
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-bookmark-subscription",
  takes: {"subscription_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmark-subscription &lt;subscription_id&gt;",

  execute: function (subscription_id) {
    if (!checkParameter(subscription_id.text, "subscription_id")) {return;}
    var params = {subscription_id: subscription_id.text};
    odsExecute ("bookmark.subscription.delete", params, "bookmark")
  }
});

CmdUtils.CreateCommand({
  name: "ods-set-bookmark-options",
  takes: {"instance_id": noun_arb_text},
  modifiers: {"options": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-set-bookmark-options &lt;instance_id&gt; options &lt;options&gt;",

  execute: function (instance_id, modifiers) {
    if (!checkParameter(instance_id.text, "instance_id")) {return;}
    var params = {instance_id: instance_id.text};
    addParameter(modifiers, "options", params, "options");
    odsExecute ("bookmark.options.set", params, "bookmark")
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-bookmark-options",
  takes: {"instance_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-bookmark-options &lt;instance_id&gt;",

  preview: function (previewBlock, instance_id) {
    if (!checkParameter(instance_id.text)) {return;}
    var params = {instance_id: instance_id.text};
    var res = odsExecute ("bookmark.options.get", params, "bookmark", "preview")
    previewBlock.innerHTML = "<pre>" + xml_encode(res) + "</pre>";
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
    if (!checkParameter(oauth.text, "calendar instance OAuth")) {return;}
    ODS.setOAuth("calendar", oauth.text);
    displayMessage("Your ODS Calendar instance OAuth has been set.");
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-calendar-by-id",
  takes: {"event_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-calendar-by-id &lt;event_id&gt;",

  preview: function (previewBlock, event_id) {
    if (!checkParameter(event_id.text)) {return;}
    var params = {event_id: event_id.text};
    var res = odsExecute ("calendar.get", params, "calendar", "preview");
    previewBlock.innerHTML = "<pre>" + xml_encode(res) + "</pre>";
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-calendar-event",
  takes: {"instance_id": noun_arb_text},
  modifiers: {"subject": noun_arb_text, "description": noun_arb_text, "location": noun_arb_text, "attendees": noun_arb_text, "privacy": noun_arb_text, "tags": noun_arb_text, "event": noun_arb_text, "eventStart": noun_arb_text, "eventEnd": noun_arb_text, "eRepeat": noun_arb_text, "eRepeatParam1": noun_arb_text, "eRepeatParam2": noun_arb_text, "eRepeatParam3": noun_arb_text, "eRepeatUntil": noun_type_date, "eReminder": noun_arb_text, "notes": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-event &lt;instance_id&gt; subject &lt;subject&gt; [description &lt;description&gt;] [location &lt;location&gt;] [attendees &lt;attendees&gt;] [privacy &lt;privacy&gt;] [tags &lt;tags&gt;] [event &lt;event&gt;] eventStart &lt;eventStart&gt; eventEnd &lt;eventEnd&gt; [eRepeat &lt;eRepeat&gt;] [eRepeatParam1 &lt;eRepeatParam1&gt;] [eRepeatParam2 &lt;eRepeatParam2&gt;] [eRepeatParam3 &lt;eRepeatParam3&gt;] [eRepeatUntil &lt;eRepeatUntil&gt;] [eReminder &lt;eReminder&gt;] [notes &lt;notes&gt;]",

  execute: function (instance_id, modifiers) {
    if (!checkParameter(instance_id.text, "instance_id")) {return;}
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
    odsExecute ("calendar.event.new", params, "calendar")
    displayMessage("Calendar event was created.");
  }
});

CmdUtils.CreateCommand({
  name: "ods-update-calendar-event",
  takes: {"event_id": noun_arb_text},
  modifiers: {"subject": noun_arb_text, "description": noun_arb_text, "location": noun_arb_text, "attendees": noun_arb_text, "privacy": noun_arb_text, "tags": noun_arb_text, "event": noun_arb_text, "eventStart": noun_arb_text, "eventEnd": noun_arb_text, "eRepeat": noun_arb_text, "eRepeatParam1": noun_arb_text, "eRepeatParam2": noun_arb_text, "eRepeatParam3": noun_arb_text, "eRepeatUntil": noun_type_date, "eReminder": noun_arb_text, "notes": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-calendar-event &lt;event_id&gt; subject &lt;subject&gt; [description &lt;description&gt;] [location &lt;location&gt;] [attendees &lt;attendees&gt;] [privacy &lt;privacy&gt;] [tags &lt;tags&gt;] [event &lt;event&gt;] eventStart &lt;eventStart&gt; eventEnd &lt;eventEnd&gt; [eRepeat &lt;eRepeat&gt;] [eRepeatParam1 &lt;eRepeatParam1&gt;] [eRepeatParam2 &lt;eRepeatParam2&gt;] [eRepeatParam3 &lt;eRepeatParam3&gt;] [eRepeatUntil &lt;eRepeatUntil&gt;] [eReminder &lt;eReminder&gt;] [notes &lt;notes&gt;]",

  execute: function (event_id, modifiers) {
    if (!checkParameter(event_id.text, "event_id")) {return;}
    var params = {event_id: event_id.text};
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
    odsExecute ("calendar.event.edit", params, "calendar")
    displayMessage("Calendar event was updated.");
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-calendar-task",
  takes: {"instance_id": noun_arb_text},
  modifiers: {"subject": noun_arb_text, "description": noun_arb_text, "attendees": noun_arb_text, "privacy": noun_arb_text, "tags": noun_arb_text, "eventStart": noun_type_date, "eventEnd": noun_type_date, "priority": noun_arb_text, "status": noun_arb_text, "complete": noun_arb_text, "completed": noun_type_date, "note": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-task &lt;instance_id&gt; subject &lt;subject&gt; [description &lt;description&gt;] [attendees &lt;attendees&gt;] [privacy &lt;privacy&gt;] [tags &lt;tags&gt;] eventStart &lt;eventStart&gt; eventEnd &lt;eventEnd&gt; [priority &lt;priority&gt;] [status &lt;status&gt;] [complete &lt;complete&gt;] [completed &lt;completed&gt;] [notes &lt;notes&gt;]",

  execute: function (instance_id, modifiers) {
    if (!checkParameter(instance_id.text, "instance_id")) {return;}
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
    odsExecute ("calendar.task.new", params, "calendar")
    displayMessage("Calendar task was created.");
  }
});

CmdUtils.CreateCommand({
  name: "ods-update-calendar-task",
  takes: {"event_id": noun_arb_text},
  modifiers: {"subject": noun_arb_text, "description": noun_arb_text, "attendees": noun_arb_text, "privacy": noun_arb_text, "tags": noun_arb_text, "eventStart": noun_type_date, "eventEnd": noun_type_date, "priority": noun_arb_text, "status": noun_arb_text, "complete": noun_arb_text, "completed": noun_type_date, "note": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-calendar-task &lt;event_id&gt; subject &lt;subject&gt; [description &lt;description&gt;] [attendees &lt;attendees&gt;] [privacy &lt;privacy&gt;] [tags &lt;tags&gt;] eventStart &lt;eventStart&gt; eventEnd &lt;eventEnd&gt; [priority &lt;priority&gt;] [status &lt;status&gt;] [complete &lt;complete&gt;] [completed &lt;completed&gt;] [notes &lt;notes&gt;]",

  execute: function (event_id, modifiers) {
    if (!checkParameter(event_id.text, "event_id")) {return;}
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
    odsExecute ("calendar.task.edit", params, "calendar")
    displayMessage("Calendar task was updated.");
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-calendar-by-id",
  takes: {"event_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-calendar-by-id &lt;event_id&gt;",

  execute: function (event_id) {
    if (!checkParameter(event_id.text, "event_id")) {return;}
    var params = {event_id: event_id.text};
    odsExecute ("calendar.delete", params, "calendar")
    displayMessage("calendar event/task was deleted.");
  }
});

CmdUtils.CreateCommand({
  name: "ods-export-calendar",
  takes: {"instance_id": noun_arb_text},
  modifiers: {"events": noun_arb_text, "tasks": noun_arb_text, "periodFrom": noun_type_date, "periodTo": noun_type_date, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-export-calendar &lt;instance_id&gt; [events &lt;events&gt;] [tasks &lt;tasks&gt;] [periodFrom &lt;periodFrom&gt;] [periodTo &lt;periodTo&gt;] [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",

  preview: function (previewBlock, instance_id, modifiers) {
    if (!checkParameter(instance_id.text)) {return;}
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "events", params, "events");
    addParameter(modifiers, "tasks", params, "tasks");
    addParameter(modifiers, "periodFrom", params, "periodFrom");
    addParameter(modifiers, "periodTo", params, "periodTo");
    addParameter(modifiers, "tagsInclude", params, "tagsInclude");
    addParameter(modifiers, "tagsExclude", params, "tagsExclude");
    var res = odsExecute ("calendar.export", params, "calendar", "preview")
    previewBlock.innerHTML = "<pre>" + xml_encode(res) + "</pre>";
        },
});

CmdUtils.CreateCommand({
  name: "ods-import-calendar",
  takes: {"instance_id": noun_arb_text},
  modifiers: {"source": noun_arb_text, "sourceType": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "events": noun_arb_text, "tasks": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-import-calendar &lt;instance_id&gt; source &lt;source&gt; sourceType &lt;WebDAV|URL&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [events &lt;events&gt;] [tasks &lt;tasks&gt;] [tags &lt;tags&gt;]",

  execute: function (instance_id, modifiers) {
    if (!checkParameter(instance_id.text, "instance_id")) {return;}
    var params = {inst_id: instance_id.text};
    addParameter(modifiers, "source", params, "source", true);
    addParameter(modifiers, "sourceType", params, "sourceType", true);
    addParameter(modifiers, "userName", params, "userName");
    addParameter(modifiers, "userPassword", params, "userPassword");
    addParameter(modifiers, "events", params, "events");
    addParameter(modifiers, "tasks", params, "tasks");
    addParameter(modifiers, "tags", params, "tags");
    odsExecute ("calendar.import", params, "calendar")
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-calendar-annotation-by-id",
  takes: {"annotation_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-calendar-annotation-by-id &lt;annotation_id&gt;",

  preview: function (annotation_id, modifiers) {
    if (!checkParameter(annotation_id.text)) {return;}
    var params = {annotation_id: annotation_id.text};
    var res = odsExecute ("calendar.annotation.get", params, "calendar", "preview")
    previewBlock.innerHTML = "<pre>" + xml_encode(res) + "</pre>";
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-calendar-annotation",
  takes: {"event_id": noun_arb_text},
  modifiers: {"author": noun_arb_text, "body": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-annotation &lt;event_id&gt; author &lt;author&gt; body &lt;body&gt;",

  execute: function (event_id, modifiers) {
    if (!checkParameter(event_id.text, "event_id")) {return;}
    var params = {event_id: event_id.text};
    addParameter(modifiers, "author", params, "author", true);
    addParameter(modifiers, "body", params, "body", true);
    odsExecute ("calendar.annotation.new", params, "calendar")
  }
});

CmdUtils.CreateCommand({
  name: "ods-update-calendar-annotation",
  takes: {"annotation_id": noun_arb_text},
  modifiers: {"author": noun_arb_text, "body": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-calendar-annotation &lt;annotation_id&gt; author &lt;author&gt; body &lt;body&gt;",

  execute: function (annotation_id, modifiers) {
    if (!checkParameter(annotation_id.text, "annotation_id")) {return;}
    var params = {annotation_id: annotation_id.text};
    addParameter(modifiers, "author", params, "author", true);
    addParameter(modifiers, "body", params, "body", true);
    odsExecute ("calendar.annotation.edit", params, "calendar")
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-calendar-annotation-claim",
  takes: {"annotation_id": noun_arb_text},
  modifiers: {"iri": noun_arb_text, "relation": noun_arb_text, "value": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-annotation-claim &lt;annotation_id&gt; iri &lt;iri&gt; relation &lt;relation&gt; value &lt;value&gt;",

  execute: function (annotation_id, modifiers) {
    if (!checkParameter(annotation_id.text, "annotation_id")) {return;}
    var params = {annotation_id: annotation_id.text};
    addParameter(modifiers, "iri", params, "claimIri", true);
    addParameter(modifiers, "relation", params, "claimRelation", true);
    addParameter(modifiers, "value", params, "claimValue", true);
    odsExecute ("calendar.annotation.claim", params, "calendar")
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-calendar-annotation",
  takes: {"annotation_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-calendar-annotation &lt;annotation_id&gt;",

  execute: function (annotation_id) {
    if (!checkParameter(annotation_id.text, "annotation_id")) {return;}
    var params = {annotation_id: annotation_id.text};
    odsExecute ("calendar.annotation.delete", params, "calendar")
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-calendar-comment-by-id",
  takes: {"comment_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-calendar-comment-by-id &lt;comment_id&gt;",

  preview: function (previewBlock, comment_id) {
    if (!checkParameter(comment_id.text)) {return;}
    var params = {comment_id: comment_id.text};
    var res = odsExecute ("calendar.comment.get", params, "calendar", "preview")
    previewBlock.innerHTML = "<pre>" + xml_encode(res) + "</pre>";
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-calendar-comment",
  takes: {"event_id": noun_arb_text},
  modifiers: {"title": noun_arb_text, "body": noun_arb_text, "author": noun_arb_text, "authorMail": noun_arb_text, "authorUrl": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-comment &lt;event_id&gt; title &lt;title&gt; body &lt;body&gt; author &lt;author&gt; authorMail &lt;authorMail&gt; authorUrl &lt;authorUrl&gt;",

  execute: function (event_id, modifiers) {
    if (!checkParameter(event_id.text, "event_id")) {return;}
    var params = {event_id: event_id.text};
    addParameter(modifiers, "title", params, "title", true);
    addParameter(modifiers, "body", params, "text", true);
    addParameter(modifiers, "author", params, "name", true);
    addParameter(modifiers, "authorMail", params, "email", true);
    addParameter(modifiers, "authorUrl", params, "url", true);
    odsExecute ("calendar.comment.new", params, "calendar")
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-calendar-comment",
  takes: {"comment_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-calendar-comment &lt;comment_id&gt;",

  execute: function (comment_id) {
    if (!checkParameter(comment_id.text, "comment_id")) {return;}
    var params = {comment_id: comment_id.text};
    odsExecute ("calendar.comment.delete", params, "calendar")
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-calendar-publication",
  takes: {"instance_id": noun_arb_text},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "destinationType": noun_arb_text, "destination": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "events": noun_arb_text, "tasks": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-publication &lt;instance_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [destinationType &lt;destinationType&gt;] destination &lt;destination&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [events &lt;events&gt;] [tasks &lt;tasks&gt;]",

  execute: function (instance_id) {
    if (!checkParameter(instance_id.text, "instance_id")) {return;}
    var params = {instance_id: instance_id.text};
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
    odsExecute ("calendar.publication.new", params, "calendar")
  }
});


CmdUtils.CreateCommand({
  name: "ods-update-calendar-publication",
  takes: {"publication_id": noun_arb_text},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "destinationType": noun_arb_text, "destination": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "events": noun_arb_text, "tasks": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-calendar-publication &lt;publication_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [destinationType &lt;destinationType&gt;] destination &lt;destination&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [events &lt;events&gt;] [tasks &lt;tasks&gt;]",

  execute: function (publication_id) {
    if (!checkParameter(publication_id.text, "publication_id")) {return;}
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
    odsExecute ("calendar.publication.edit", params, "calendar")
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-calendar-publication",
  takes: {"publication_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-calendar-publication &lt;publication_id&gt;",

  execute: function (publication_id) {
    if (!checkParameter(publication_id.text, "publication_id")) {return;}
    var params = {publication_id: publication_id.text};
    odsExecute ("calendar.publication.delete", params, "calendar")
  }
});

CmdUtils.CreateCommand({
  name: "ods-create-calendar-subscription",
  takes: {"instance_id": noun_arb_text},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "sourceType": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "folderPath": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-subscription &lt;instance_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [sourceType &lt;sourceType&gt;] source &lt;source&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [folderPath &lt;folderPath&gt;] [tags &lt;tags&gt;]",

  execute: function (instance_id) {
    if (!checkParameter(instance_id.text, "instance_id")) {return;}
    var params = {instance_id: instance_id.text};
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
    odsExecute ("calendar.subscription.new", params, "calendar")
  }
});

CmdUtils.CreateCommand({
  name: "ods-update-calendar-subscription",
  takes: {"subscription_id": noun_arb_text},
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "sourceType": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "events": noun_arb_text, "tasks": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-calendar-subscription &lt;subscription_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|dayly&gt;] [updateFreq &lt;updateFreq&gt;] [sourceType &lt;sourceType&gt;] source &lt;source&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [events &lt;events&gt;] [tasks &lt;tasks&gt;]",

  execute: function (subscription_id) {
    if (!checkParameter(subscription_id.text, "subscription_id")) {return;}
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
    odsExecute ("calendar.subscription.edit", params, "calendar")
  }
});

CmdUtils.CreateCommand({
  name: "ods-delete-calendar-subscription",
  takes: {"subscription_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-calendar-subscription &lt;subscription_id&gt;",

  execute: function (subscription_id) {
    if (!checkParameter(subscription_id.text, "subscription_id")) {return;}
    var params = {subscription_id: subscription_id.text};
    odsExecute ("calendar.subscription.delete", params, "calendar")
  }
});

CmdUtils.CreateCommand({
  name: "ods-set-calendar-options",
  takes: {"instance_id": noun_arb_text},
  modifiers: {"options": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-set-calendar-options &lt;instance_id&gt; options &lt;options&gt;",

  execute: function (instance_id, modifiers) {
    if (!checkParameter(instance_id.text, "instance_id")) {return;}
    var params = {instance_id: instance_id.text};
    addParameter(modifiers, "options", params, "options");
    odsExecute ("calendar.options.set", params, "calendar")
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-calendar-options",
  takes: {"instance_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-calendar-options &lt;instance_id&gt;",

  preview: function (previewBlock, instance_id) {
    if (!checkParameter(instance_id.text)) {return;}
    var params = {instance_id: instance_id.text};
    var res = odsExecute ("calendar.options.get", params, "calendar", "preview")
    previewBlock.innerHTML = "<pre>" + xml_encode(res) + "</pre>";
  }
});
