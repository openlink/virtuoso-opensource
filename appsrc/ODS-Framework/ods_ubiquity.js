/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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


function odsDisplayMessage(ex)
{
  if (typeof ex == "string") {
    displayMessage(ex);
  } else {
    displayMessage("An exception occurred in the script. Error name: " + ex.name + ". Error message: " + ex.message);
  }
}

function odsPreview(previewBlock, cmd, cmdName, cmdParams, cmdApplication, previewMode)
{
  var res = odsExecute(cmdName, cmdParams, cmdApplication, "preview");
  if (!res)
  {
    previewBlock.innerHTML = (cmd.description)? cmd.description: cmd.help;
  } else {
  if (previewMode == 'image')
  {
    previewBlock.innerHTML = '<img src="' + res + '" />';
  } else {
  previewBlock.innerHTML = "<pre>" + xml_encode(res) + "</pre>";
}
}
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
  if (logMode)
  {
    CmdUtils.log(res);
    CmdUtils.log(cmdName + " - end");
  }
  if (showMode)
  {
    if (res && (res.indexOf("<failed>") == 0)) {res = null;}
  } else {
    displayMessage(res);
  }
  return res;
}

function checkParameter(parameter, parameterLabel)
{
  if (!parameter || parameter.length < 1)
  {
    if (parameterLabel) {throw "Please, enter a value for '" + parameterLabel + "'";}
    throw "Bad parameter";
  }
}

function addParameter(args, argName, argLabel, parameters, parameterName, argCheck)
{
  var arg = args[argName];
  if (argCheck)
  {
    if (!arg) {throw "Please, enter a value for '" + (argLabel)?argLabel:argName + "'";}
    checkParameter(arg.text, (argLabel)?argLabel:argName);
  }
  if (arg && arg.text)
  {
    var S = args[argName].text.toString();
    if (S.length > 0)
      parameters[parameterName] = args[argName].text;
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

////////////////////////////////////
///// ODS common commands //////////
////////////////////////////////////

CmdUtils.CreateCommand({
  names: ["ods-log-enable"],
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
  names: ["ods-log-disable"],
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
  names: ["ods-host"],
  arguments: [{role: "object", label: 'ODS Host URL', nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS server url - host and port",
  help: "Type ods-host http://myopenlink.net/ods",
  execute: function(args) {
    try {
      checkParameter(args.object.text, 'ODS Host URL');
      ODS.setServer(args.object.text);
    displayMessage("Your ODS host URL has been set to " + ODS.getServer());
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-oauth-host"],
  arguments: [{role: "object", label: 'ODS OAuth Host URL', nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS OAuth server url",
  help: "Type ods-api-host http://myopenlink.net/OAuth",
  execute: function(args) {
    try {
      checkParameter(args.object.text, 'ODS OAuth Host URL');
      ODS.setOAuthServer(args.object.text);
    displayMessage("Your ODS OAuth host has been set to " + ODS.getOAuthServer());
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-set-mode"],
  arguments: [{role: "object", label: "ODS API Mode", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS API mode - sid or oauth",
  help: "Type ods-set-mode <sid|oauth&gt;",
  execute: function(args) {
    try {
      checkParameter(args.object.text, 'ODS API Mode');
      ODS.setMode(args.object.text);
      displayMessage("Your ODS API Mode has been set to " + ODS.getMode());
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-set-sid"],
  arguments: [{role: "object", label: "ODS API sid", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS session ID",
  help: "Type ods-set-sid <sid value&gt;",
  execute: function(args) {
    try {
      checkParameter(args.object.text, "ODS API sid");
      ODS.setSid(args.object.text);
      displayMessage("Your ODS new SID has been set to " + ODS.getSid());
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-authenticate-user"],
  arguments: [
              {role: "object", label: "username", nountype: noun_arb_text},
              {role: "instrument", label: "password", nountype: noun_arb_text}
             ],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-authenticate-user &lt;username&gt; with &lt;password&gt;",
  execute: function(args) {
    try {
      var params = {};
      addParameter(args, "object", "user's name", params, "user_name", true);
      addParameter(args, "instrument", "user's password", params, "password_hash", true);
      params["password_hash"] = Utils.computeCryptoHash ('SHA1', params["user_name"] + params["password_hash"]);
      var result = odsExecute("user.authenticate", params, "", false, true);
      if (sid)
      {
        ODS.setSid(result.sid);
    ODS.setMode('sid');
      displayMessage("You were authenticated. Your ODS session ID has been set to " + ODS.getSid());
      }
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-params"],
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
  names: ["ods-set-oauth"],
  arguments: [{role: "object", label: "OAuth", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS OAuth. Get your OAuth at " + ODS.getServer() + "/oauth_sid.vsp",
  help: "Type ods-set-oauth &lt;OAuth&gt;. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  execute: function(args) {
    try {
      checkParameter(args.object.text, "ODS OAuth");
      ODS.setOAuth("", args.object.text);
    displayMessage("Your ODS OAuth has been set.");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
    }
});

CmdUtils.CreateCommand({
  names: ["ods-get-uri-info"],
  arguments: [{role: "object", label: "URI", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-uri-info &lt;URI&gt;",
  execute: function (args) {
    try {
      checkParameter(args.object.text, "Object URI");
    var windowManager = Components.classes["@mozilla.org/appshell/window-mediator;1"].getService(Components.interfaces.nsIWindowMediator);
    var browserWindow = windowManager.getMostRecentWindow("navigator:browser");
    var browser = browserWindow.getBrowser();
      var new_tab = browser.addTab(args.object.text);
    new_tab.control.selectedIndex = new_tab.control.childNodes.length-1;
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

////////////////////////////////////
///// ods users ////////////////////
////////////////////////////////////
CmdUtils.CreateCommand({
  names: ["ods-get-user"],
  arguments: [{role: "object", label: "userName", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-user &lt;username&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "user's name", params, "name", true);
      odsPreview(previewBlock, this, "user.get", params);
    } catch (ex) {
    }
  },
});

CmdUtils.CreateCommand({
  names: ["ods-create-user"],
  arguments: [{role: "object", label: "userName", nountype: noun_arb_text}],
  modifiers: {"password": noun_arb_text, "email": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-user &lt;username&gt; password &lt;password&gt; email &lt;email&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "name", true);
      addParameter(args, "password", null, params, "password", true);
      addParameter(args, "email", null, params, "email", true);
      odsExecute("user.register", params, "", false, true);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-user"],
  arguments: [{role: "object", label: "userName", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-user &lt;username&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "user's name", params, "name", true);
    odsExecute ("user.delete", params)
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-enable-user"],
  arguments: [{role: "object", label: "userName", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-enable-user &lt;username&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "user's name", params, "name", true);
      odsExecute("user.enable", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-disable-user"],
  arguments: [{role: "object", label: "userName", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-disable-user &lt;username&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "user's name", params, "name", true);
      odsExecute("user.disable", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-user-topicOfInterest"],
  arguments: [{role: "object", label: "topicURI", nountype: noun_arb_text}],
  modifiers: {"label": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-topicOfInterest &lt;topicURI&gt; label &lt;topicLabel&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "topicURI", true);
      addParameter(args, "label", null, params, "topicLabel");
      odsExecute("user.topicOfInterest.new", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-user-topicOfInterest"],
  arguments: [{role: "object", label: "topicURI", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-topicOfInterest &lt;topicURI&gt;",
    execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "topicURI", true);
      odsExecute("user.topicOfInterest.delete", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-user-thingOfInterest"],
  arguments: [{role: "object", label: "thingURI", nountype: noun_arb_text}],
  modifiers: {"label": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-thingOfInterest &lt;thingURI&gt; label &lt;thingLabel&gt;",
    execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "thingURI", true);
      addParameter(args, "label", null, params, "thingLabel");
      odsExecute("user.thingOfInterest.new", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-user-thingOfInterest"],
  arguments: [{role: "object", label: "thingURI", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-thingOfInterest &lt;thingURI&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "thingURI", true);
      odsExecute("user.thingOfInterest.delete", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-user-annotation"],
  arguments: [{role: "object", label: "iri", nountype: noun_arb_text}],
  modifiers: {"has": noun_arb_text, "with": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-user-annotation &lt;iri&gt; has &lt;relation&gt; with &lt;value&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "iri", true);
      addParameter(args, "has", null, params, "claimRelation", true);
      addParameter(args, "with", null, params, "claimValue", true);
      odsExecute("user.annotation.new", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-user-annotation"],
  arguments: [{role: "object", label: "iri", nountype: noun_arb_text}],
  modifiers: {"has": noun_arb_text, "with": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-user-annotation &lt;iri&gt; has &lt;relation&gt; with &lt;value&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "iri", true);
      addParameter(args, "has", null, params, "claimRelation", true);
      addParameter(args, "with", null, params, "claimValue", true);
      odsExecute("user.annotation.delete", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-user-bioevent"],
  arguments: [{role: "object", label: "bioEvent", nountype: noun_arb_text}],
  modifiers: {"on": noun_arb_text, "in": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-user-bioevent &lt;bioEvent&gt; on &lt;onDate&gt; in &lt;inPlace&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "event", true);
      addParameter(args, "on", null, params, "date", true);
      addParameter(args, "in", null, params, "place");
      odsExecute("user.bioEvents.new", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-user-bioevent"],
  arguments: [{role: "object", label: "bioEvent", nountype: noun_arb_text}],
  modifiers: {"on": noun_arb_text, "in": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-user-bioevent &lt;bioEvent&gt; on &lt;onDate&gt; in &lt;inPlace&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "event", true);
      addParameter(args, "on", null, params, "date");
      addParameter(args, "in", null, params, "place");
      odsExecute("user.bioEvents.delete", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-user-offer"],
  arguments: [{role: "object", label: "offerName", nountype: noun_arb_text}],
  modifiers: {"comment": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-user-offer &lt;offerName&gt; comment &lt;offerComment&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "offerName", true);
      addParameter(args, "comment", null, params, "offerComment");
      odsExecute("user.offer.new", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-user-offer"],
  arguments: [{role: "object", label: "offerName", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-user-offer &lt;offerName&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "offerName", true);
      odsExecute("user.offer.delete", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-user-offer-property"],
  arguments: [{role: "object", label: "offerName", nountype: noun_arb_text}],
  modifiers: {"property": noun_arb_text, "value": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-user-offer-property &lt;offerName&gt; property &lt;offerProperty&gt; value &lt;offerPropertyValue&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "offerName", true);
      addParameter(args, "property", null, params, "offerProperty", true);
      addParameter(args, "value", null, params, "offerPropertyValue");
      odsExecute("user.offer.property.new", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-user-offer-property"],
  arguments: [{role: "object", label: "offerName", nountype: noun_arb_text}],
  modifiers: {"property": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-user-offer-property &lt;offerName&gt; property &lt;offerProperty&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "offerName", true);
      addParameter(args, "property", null, params, "offerProperty", true);
      odsExecute("user.offer.property.delete", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-user-wish"],
  arguments: [{role: "object", label: "wishName", nountype: noun_arb_text}],
  modifiers: {"comment": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-user-wish &lt;wishName&gt; comment &lt;wishComment&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "wishName", true);
      addParameter(args, "comment", null, params, "wishComment");
      odsExecute("user.wish.new", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-user-wish"],
  arguments: [{role: "object", label: "wishName", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-user-wish &lt;wishName&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "wishName", true);
      odsExecute("user.wish.delete", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-user-wish-property"],
  arguments: [{role: "object", label: "wishName", nountype: noun_arb_text}],
  modifiers: {"property": noun_arb_text, "value": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-user-wish-property &lt;wishName&gt; property &lt;wishProperty&gt; value &lt;wishPropertyValue&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "wishName", true);
      addParameter(args, "property", null, params, "wishProperty", true);
      addParameter(args, "value", null, params, "wishPropertyValue");
      odsExecute("user.wish.property.new", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-user-wish-property"],
  arguments: [{role: "object", label: "wishName", nountype: noun_arb_text}],
  modifiers: {"property": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-user-wish-property &lt;wishName&gt; property &lt;wishProperty&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "wishName", true);
      addParameter(args, "property", null, params, "wishProperty", true);
      odsExecute("user.wish.property.delete", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

////////////////////////////////////
///// ods instances ////////////////
////////////////////////////////////
CmdUtils.CreateCommand({
  names: ["ods-get-instance-id"],
  arguments: [{role: "object", label: "instanceName", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-instance-id &lt;instanceName&gt;",
    execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "instance name", params, "instanceName", true);
      odsExecute("instance.get.id", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-freeze-instance"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-freeze-instance &lt;instance_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      odsExecute("instance.freeze", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-unfreeze-instance"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-unfreeze-instance &lt;instance_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "instance ID", params, "inst_id", true);
      odsExecute("instance.unfreeze", params);
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

////////////////////////////////////
///// ods briefcase ////////////////
////////////////////////////////////
CmdUtils.CreateCommand({
  names: ["ods-set-briefcase-oauth"],
  arguments: [{role: "object", label: "oauth", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS briefcase OAuth. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  help: "Type ods-set-briefcase-oauth &lt;oauth&gt;. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  execute: function(args) {
    try {
      checkParameter(args.object.text, "Briefcase Instance OAuth");
      ODS.setOAuth("briefcase", args.object.text);
    displayMessage("Your ODS briefcase instance OAuth has been set.");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-briefcase-resource-info-by-path"],
  arguments: [{role: "object", label: "path", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Get your ODS briefcase resource content",
  help: "Type ods-get-briefcase-resource-info-by-path &lt;path&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Resource Path", params, "path", true);
      odsPreview(previewBlock, this, "briefcase.resource.get", params, "briefcase");
    } catch (ex) {
    }
  },
});

CmdUtils.CreateCommand({
  names: ["ods-store-briefcase-resource"],
  arguments: [
              {role: "object", label: "path", nountype: noun_arb_text},
              {role: "instrument", label: "content", nountype: noun_arb_text}
             ],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Store content on resource path",
  help: "Type ods-store-briefcase-resource &lt;path&gt; with &lt;content&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Resource Path", params, "path", true);
      addParameter(args, "instrument", "Content", params, "content");
      odsExecute("briefcase.resource.store", params, "briefcase");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-briefcase-resource"],
  arguments: [{role: "object", label: "path", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Get your ODS briefcase resource content",
  help: "Type ods-delete-briefcase-resource &lt;path&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Resource Path", params, "path", true);
      odsExecute("briefcase.resource.delete", params, "briefcase");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-briefcase-collection"],
  arguments: [{role: "object", label: "path", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Create ODS briefcase collection (folder)",
  help: "Type ods-create-briefcase-collection &lt;path&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Collection Path", params, "path", true);
      odsExecute("briefcase.collection.create", params, "briefcase");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-briefcase-collection"],
  arguments: [{role: "object", label: "path", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Delete existing ODS Briefcase collection (folder)",
  help: "Type ods-delete-briefcase-collection &lt;path&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Collection Path", params, "path", true);
      odsExecute("briefcase.collection.delete", params, "briefcase");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-copy-briefcase"],
  arguments: [
              {role: "object", label: "path", nountype: noun_arb_text},
              {role: "goal", label: "toPath", nountype: noun_arb_text},
              {role: "instrument", label: "overwrite", nountype: noun_type_integer}
             ],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Copy existing ODS Briefcase collection (folder)",
  help: "Type ods-copy-briefcase &lt;fromPath&gt; to &lt;toPath&gt; [with &lt;overwrite flag&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Source Path", params, "from_path", true);
      addParameter(args, "goal", "Destination Path", params, "to_path", true);
      addParameter(args, "instrument", "Overwride Flag", params, "overwrite");
      odsExecute("briefcase.copy", params, "briefcase");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-move-briefcase"],
  arguments: [
              {role: "object", label: "path", nountype: noun_arb_text},
              {role: "goal", label: "toPath", nountype: noun_arb_text}
             ],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Copy existing ODS Briefcase collection (folder)",
  help: "Type ods-move-briefcase &lt;fromPath&gt; to &lt;toPath&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Source Path", params, "from_path", true);
      addParameter(args, "goal", "Destination Path", params, "to_path", true);
      odsExecute("briefcase.move", params, "briefcase");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-set-briefcase-property"],
  arguments: [{role: "object", label: "path", nountype: noun_arb_text}],
  modifiers: {"property": noun_arb_text, "with": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set property to existing ODS Briefcase collection/resource",
  help: "Type ods-set-briefcase-property &lt;path&gt; property &lt;property_name&gt; with &lt;value&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "path", true);
      addParameter(args, "property", null, params, "property", true);
      addParameter(args, "with", null, params, "value", true);
      odsExecute("briefcase.property.set", params, "briefcase");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-briefcase-property"],
  arguments: [{role: "object", label: "path", nountype: noun_arb_text}],
  modifiers: {"property": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Get property from existing ODS Briefcase collection/resource",
  help: "Type ods-get-briefcase-property &lt;path&gt; property &lt;property_name&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "path", true);
      addParameter(args, "property", null, params, "property", true);
      odsPreview(previewBlock, this, "briefcase.property.get", params, "briefcase");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-briefcase-property"],
  arguments: [{role: "object", label: "path", nountype: noun_arb_text}],
  modifiers: {"property": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Delete property from existing ODS Briefcase collection/resource",
  help: "Type ods-delete-briefcase-property &lt;path&gt; property &lt;property_name&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "path", true);
      addParameter(args, "property", null, params, "property", true);
      odsExecute("briefcase.property.remove", params, "briefcase");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-set-briefcase-options"],
  arguments: [
              {role: "object", label: "instance_id", nountype: noun_type_id},
              {role: "instrument", label: "options", nountype: noun_arb_text}
             ],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Update instance options/parameteres",
  help: "Type ods-set-briefcase-options &lt;instance_id&gt; with &lt;options&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Instcane ID", params, "inst_id", true);
      addParameter(args, "instrument", "Options", params, "options");
      odsExecute("briefcase.options.set", params, "briefcase");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-briefcase-options"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Show instance options/parameteres",
  help: "Type ods-get-briefcase-options &lt;instance_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Instance ID", params, "inst_id", true);
      odsPreview(previewBlock, this, "briefcase.options.get", params, "briefcase");
    } catch (ex) {
    }
  }
});

////////////////////////////////////
///// ods bookmark /////////////////
////////////////////////////////////
CmdUtils.CreateCommand({
  names: ["ods-set-bookmark-oauth"],
  arguments: [{role: "object", label: "oauth", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS bookmark OAuth. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  help: "Type ods-set-bookmark-oauth &lt;oauth&gt;. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  execute: function (args) {
    try {
      checkParameter(args.object.text, "Bookmark Instance OAuth");
      ODS.setOAuth("bookmark", args.object.text);
    displayMessage("Your ODS bookmark instance OAuth has been set.");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-bookmark-by-id"],
  arguments: [{role: "object", label: "bookmark_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-bookmark-by-id &lt;bookmark_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Bookmark ID", params, "bookmark_id", true);
      odsPreview(previewBlock, this, "bookmark.get", params, "bookmark");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-bookmark"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"title": noun_arb_text, "url": noun_arb_text, "description": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmark &lt;instance_id&gt; title &lt;title&gt; url &lt;url&gt; [description &lt;description&gt;] [tags &lt;tags&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "title", null, params, "name", true);
      addParameter(args, "url", null, params, "uri", true);
      addParameter(args, "description", null, params, "description");
      addParameter(args, "tags", null, params, "tags");
      odsExecute("bookmark.new", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-update-bookmark"],
  arguments: [{role: "object", label: "bookmark_id", nountype: noun_type_id}],
  modifiers: {"title": noun_arb_text, "url": noun_arb_text, "description": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-bookmark &lt;bookmark_id&gt; title &lt;title&gt; url &lt;url&gt; [description &lt;description&gt;] [tags &lt;tags&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "bookmark_id", true);
      addParameter(args, "title", null, params, "name", true);
      addParameter(args, "url", null, params, "uri", true);
      addParameter(args, "description", null, params, "description");
      addParameter(args, "tags", null, params, "tags");
      odsExecute("bookmark.edit", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
    }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-bookmark-by-id"],
  arguments: [{role: "object", label: "bookmark_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmark-by-id &lt;bookmark_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Bookmark ID", params, "bookmark_id", true);
      odsExecute("bookmark.delete", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-bookmarks-folder"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"path": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmarks-folder &lt;instance_id&gt; path &lt;path&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "path", null, params, "path", true);
      odsExecute("bookmark.folder.new", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-bookmarks-folder"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"path": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmarks-folder &lt;instance_id&gt; path &lt;path&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "path", null, params, "path", true);
      odsExecute("bookmark.folder.delete", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-export-bookmarks"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"exportType": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-export-bookmarks &lt;instance_id&gt; [exportType &lt;Netscape|XBEL&gt;]",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "exportType", null, params, "contentType");
      odsPreview(previewBlock, this, "bookmark.export", params, "bookmark");
    } catch (ex) {
    }
        },
});

CmdUtils.CreateCommand({
  names: ["ods-import-bookmarks"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"source": noun_arb_text, "sourceType": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-import-bookmarks &lt;instance_id&gt; source &lt;source&gt; sourceType &lt;WebDAV|URL&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "source", null, params, "source", true);
      addParameter(args, "sourceType", null, params, "sourceType", true);
      odsExecute("bookmark.import", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-bookmark-annotation-by-id"],
  arguments: [{role: "object", label: "annotation_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-bookmark-annotation-by-id &lt;annotation_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Annotation ID", params, "annotation_id", true);
      odsPreview(previewBlock, this, "bookmark.annotation.get", params, "bookmark");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-bookmark-annotation"],
  arguments: [{role: "object", label: "bookmark_id", nountype: noun_type_id}],
  modifiers: {"author": noun_arb_text, "body": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmark-annotation &lt;bookmark_id&gt; author &lt;author&gt; body &lt;body&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "bookmark_id", true);
      addParameter(args, "author", null, params, "author", true);
      addParameter(args, "body", null, params, "body", true);
      odsExecute("bookmark.annotation.new", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-bookmark-annotation-claim"],
  arguments: [{role: "object", label: "annotation_id", nountype: noun_type_id}],
  modifiers: {"iri": noun_arb_text, "relation": noun_arb_text, "value": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmark-annotation-claim &lt;annotation_id&gt; iri &lt;iri&gt; relation &lt;relation&gt; value &lt;value&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "annotation_id", true);
      addParameter(args, "iri", null, params, "claimIri", true);
      addParameter(args, "relation", null, params, "claimRelation", true);
      addParameter(args, "value", null, params, "claimValue", true);
      odsExecute("bookmark.annotation.claim", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-bookmark-annotation"],
  arguments: [{role: "object", label: "annotation_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmark-annotation &lt;annotation_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Annotation ID", params, "annotation_id", true);
      odsExecute("bookmark.annotation.delete", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-bookmark-comment-by-id"],
  arguments: [{role: "object", label: "comment_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-bookmark-comment-by-id &lt;comment_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Comment ID", params, "comment_id", true);
      odsPreview(previewBlock, this, "bookmark.comment.get", params, "bookmark");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-bookmark-comment"],
  arguments: [{role: "object", label: "bookmark_id", nountype: noun_type_id}],
  modifiers: {"title": noun_arb_text, "body": noun_arb_text, "author": noun_arb_text, "authorMail": noun_arb_text, "authorUrl": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmark-comment &lt;bookmark_id&gt; title &lt;title&gt; body &lt;body&gt; author &lt;author&gt; authorMail &lt;authorMail&gt; authorUrl [&lt;authorUrl&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "bookmark_id", true);
      addParameter(args, "title", null, params, "title", true);
      addParameter(args, "body", null, params, "text", true);
      addParameter(args, "author", null, params, "name", true);
      addParameter(args, "authorMail", null, params, "email", true);
      addParameter(args, "authorUrl", null, params, "url");
      odsExecute("bookmark.comment.new", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-bookmark-comment"],
  arguments: [{role: "object", label: "comment_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmark-comment &lt;comment_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Comment ID", params, "comment_id", true);
      odsExecute("bookmark.comment.delete", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-bookmarks-publication"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "destinationType": noun_arb_text, "destination": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "folderPath": noun_arb_text, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmarks-publication &lt;instance_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|daily&gt;] [updateFreq &lt;updateFreq&gt;] [destinationType &lt;WebDAV|URL&gt;] destination &lt;destination&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [folderPath &lt;folderPath&gt;] [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "updateType", null, params, "updateType");
      addParameter(args, "updatePeriod", null, params, "updatePeriod");
      addParameter(args, "updateFreq", null, params, "updateFreq");
      addParameter(args, "destinationType", null, params, "destinationType");
      addParameter(args, "destination", null, params, "destination", true);
      addParameter(args, "userName", null, params, "userName");
      addParameter(args, "userPassword", null, params, "userPassword");
      addParameter(args, "folderPath", null, params, "folderPath");
      addParameter(args, "tagsInclude", null, params, "tagsInclude");
      addParameter(args, "tagsExclude", null, params, "tagsExclude");
      odsExecute("bookmark.publication.new", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-update-bookmarks-publication"],
  arguments: [{role: "object", label: "publication_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "destinationType": noun_arb_text, "destination": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "folderPath": noun_arb_text, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-bookmarks-publication &lt;publication_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|daily&gt;] [updateFreq &lt;updateFreq&gt;] [destinationType &lt;destinationType&gt;] destination &lt;destination&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [folderPath &lt;folderPath&gt;] [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "publication_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "updateType", null, params, "updateType");
      addParameter(args, "updatePeriod", null, params, "updatePeriod");
      addParameter(args, "updateFreq", null, params, "updateFreq");
      addParameter(args, "destinationType", null, params, "destinationType");
      addParameter(args, "destination", null, params, "destination", true);
      addParameter(args, "userName", null, params, "userName");
      addParameter(args, "userPassword", null, params, "userPassword");
      addParameter(args, "folderPath", null, params, "folderPath");
      addParameter(args, "tagsInclude", null, params, "tagsInclude");
      addParameter(args, "tagsExclude", null, params, "tagsExclude");
      odsExecute("bookmark.publication.edit", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-bookmarks-publication"],
  arguments: [{role: "object", label: "publication_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-bookmarks-publication &lt;publication_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "publication_id", true);
      odsPreview(previewBlock, this, "bookmark.publication.get", params, "bookmark");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-sync-bookmarks-publication"],
  arguments: [{role: "object", label: "publication_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-sync-bookmarks-publication &lt;publication_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "publication_id", true);
      odsExecute("bookmark.publication.sync", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-bookmarks-publication"],
  arguments: [{role: "object", label: "publication_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmarks-publication &lt;publication_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "publication_id", true);
      odsExecute("bookmark.publication.delete", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-bookmarks-subscription"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "sourceType": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "folderPath": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-bookmarks-subscription &lt;instance_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|daily&gt;] [updateFreq &lt;updateFreq&gt;] [sourceType &lt;sourceType&gt;] source &lt;source&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [folderPath &lt;folderPath&gt;] [tags &lt;tags&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "updateType", null, params, "updateType");
      addParameter(args, "updatePeriod", null, params, "updatePeriod");
      addParameter(args, "updateFreq", null, params, "updateFreq");
      addParameter(args, "sourceType", null, params, "sourceType");
      addParameter(args, "source", null, params, "source", true);
      addParameter(args, "userName", null, params, "userName");
      addParameter(args, "userPassword", null, params, "userPassword");
      addParameter(args, "folderPath", null, params, "folderPath");
      addParameter(args, "tags", null, params, "tags");
      odsExecute("bookmark.subscription.new", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-update-bookmarks-subscription"],
  arguments: [{role: "object", label: "subscription_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "sourceType": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "folderPath": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-bookmarks-subscription &lt;subscription_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|daily&gt;] [updateFreq &lt;updateFreq&gt;] [sourceType &lt;sourceType&gt;] source &lt;source&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [folderPath &lt;folderPath&gt;] [tags &lt;tags&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "subscription_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "updateType", null, params, "updateType");
      addParameter(args, "updatePeriod", null, params, "updatePeriod");
      addParameter(args, "updateFreq", null, params, "updateFreq");
      addParameter(args, "sourceType", null, params, "sourceType");
      addParameter(args, "source", null, params, "source", true);
      addParameter(args, "userName", null, params, "userName");
      addParameter(args, "userPassword", null, params, "userPassword");
      addParameter(args, "folderPath", null, params, "folderPath");
      addParameter(args, "tags", null, params, "tags");
      odsExecute("bookmark.subscription.edit", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-bookmarks-subscription"],
  arguments: [{role: "object", label: "subscription_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-bookmarks-subscription &lt;subscription_id&gt;",
  preview: function (previewBlockargs) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "subscription_id", true);
      odsPreview(previewBlock, this, "bookmark.subscription.get", params, "bookmark");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-sync-bookmarks-subscription"],
  arguments: [{role: "object", label: "subscription_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-sync-bookmarks-subscription &lt;subscription_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "subscription_id", true);
      odsExecute("bookmark.subscription.sync", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-bookmarks-subscription"],
  arguments: [{role: "object", label: "subscription_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-bookmarks-subscription &lt;subscription_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "subscription_id", true);
      odsExecute("bookmark.subscription.delete", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-set-bookmarks-options"],
  arguments: [
              {role: "object", label: "instance_id", nountype: noun_type_id},
              {role: "instrument", label: "options", nountype: noun_arb_text}
             ],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Update instance options/parameteres",
  help: "Type ods-set-bookmarks-options &lt;instance_id&gt; with &lt;options&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Instcane ID", params, "inst_id", true);
      addParameter(args, "instrument", "Options", params, "options");
      odsExecute("bookmark.options.set", params, "bookmark");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-bookmarks-options"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Show instance options/parameteres",
  help: "Type ods-get-bookmarks-options &lt;instance_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Instance ID", params, "inst_id", true);
      odsPreview(previewBlock, this, "bookmark.options.get", params, "bookmark");
    } catch (ex) {
    }
  }
});

////////////////////////////////////
///// ODS Calendar /////////////////
////////////////////////////////////
CmdUtils.CreateCommand({
  names: ["ods-set-calendar-oauth"],
  arguments: [{role: "object", label: "oauth", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS Calendar OAuth. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  help: "Type ods-set-calendar-oauth &lt;oauth&gt;. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  execute: function (args) {
    try {
      checkParameter(args.object.text, "calendar instance OAuth");
      ODS.setOAuth("calendar", args.object.text);
    displayMessage("Your ODS Calendar instance OAuth has been set.");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-calendar-item-by-id"],
  arguments: [{role: "object", label: "event_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-calendar-item-by-id &lt;event_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "event_id", true);
      odsPreview(previewBlock, this, "calendar.get", params, "calendar");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-calendar-event"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"subject": noun_arb_text, "description": noun_arb_text, "location": noun_arb_text, "attendees": noun_arb_text, "privacy": noun_arb_text, "tags": noun_arb_text, "event": noun_arb_text, "eventStart": noun_arb_text, "eventEnd": noun_arb_text, "eRepeat": noun_arb_text, "eRepeatParam1": noun_arb_text, "eRepeatParam2": noun_arb_text, "eRepeatParam3": noun_arb_text, "eRepeatUntil": noun_arb_text, "eReminder": noun_arb_text, "notes": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-event &lt;instance_id&gt; subject &lt;subject&gt; [description &lt;description&gt;] [location &lt;location&gt;] [attendees &lt;attendees&gt;] [privacy &lt;privacy&gt;] [tags &lt;tags&gt;] [event &lt;event&gt;] eventStart &lt;eventStart&gt; eventEnd &lt;eventEnd&gt; [eRepeat &lt;eRepeat&gt;] [eRepeatParam1 &lt;eRepeatParam1&gt;] [eRepeatParam2 &lt;eRepeatParam2&gt;] [eRepeatParam3 &lt;eRepeatParam3&gt;] [eRepeatUntil &lt;eRepeatUntil&gt;] [eReminder &lt;eReminder&gt;] [notes &lt;notes&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "subject", null, params, "subject", true);
      addParameter(args, "description", null, params, "description");
      addParameter(args, "location", null, params, "location");
      addParameter(args, "attendees", null, params, "attendees");
      addParameter(args, "privacy", null, params, "privacy");
      addParameter(args, "tags", null, params, "tags");
      addParameter(args, "event", null, params, "event");
      addParameter(args, "eventStart", null, params, "eventStart", true);
      addParameter(args, "eventEnd", null, params, "eventEnd", true);
      addParameter(args, "eRepeat", null, params, "eRepeat");
      addParameter(args, "eRepeatParam1", null, params, "eRepeatParam1");
      addParameter(args, "eRepeatParam2", null, params, "eRepeatParam2");
      addParameter(args, "eRepeatParam3", null, params, "eRepeatParam3");
      addParameter(args, "eRepeatUntil ", null, params, "eRepeatUntil ");
      addParameter(args, "eReminder", null, params, "eReminder");
      addParameter(args, "notes", null, params, "notes");
      odsExecute("calendar.event.new", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-update-calendar-event"],
  arguments: [{role: "object", label: "event_id", nountype: noun_type_id}],
  modifiers: {"subject": noun_arb_text, "description": noun_arb_text, "location": noun_arb_text, "attendees": noun_arb_text, "privacy": noun_arb_text, "tags": noun_arb_text, "event": noun_arb_text, "eventStart": noun_arb_text, "eventEnd": noun_arb_text, "eRepeat": noun_arb_text, "eRepeatParam1": noun_arb_text, "eRepeatParam2": noun_arb_text, "eRepeatParam3": noun_arb_text, "eRepeatUntil": noun_arb_text, "eReminder": noun_arb_text, "notes": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-calendar-event &lt;event_id&gt; subject &lt;subject&gt; [description &lt;description&gt;] [location &lt;location&gt;] [attendees &lt;attendees&gt;] [privacy &lt;privacy&gt;] [tags &lt;tags&gt;] [event &lt;event&gt;] eventStart &lt;eventStart&gt; eventEnd &lt;eventEnd&gt; [eRepeat &lt;eRepeat&gt;] [eRepeatParam1 &lt;eRepeatParam1&gt;] [eRepeatParam2 &lt;eRepeatParam2&gt;] [eRepeatParam3 &lt;eRepeatParam3&gt;] [eRepeatUntil &lt;eRepeatUntil&gt;] [eReminder &lt;eReminder&gt;] [notes &lt;notes&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "event_id", true);
      addParameter(args, "subject", null, params, "subject", true);
      addParameter(args, "description", null, params, "description");
      addParameter(args, "location", null, params, "location");
      addParameter(args, "attendees", null, params, "attendees");
      addParameter(args, "privacy", null, params, "privacy");
      addParameter(args, "tags", null, params, "tags");
      addParameter(args, "event", null, params, "event");
      addParameter(args, "eventStart", null, params, "eventStart", true);
      addParameter(args, "eventEnd", null, params, "eventEnd", true);
      addParameter(args, "eRepeat", null, params, "eRepeat");
      addParameter(args, "eRepeatParam1", null, params, "eRepeatParam1");
      addParameter(args, "eRepeatParam2", null, params, "eRepeatParam2");
      addParameter(args, "eRepeatParam3", null, params, "eRepeatParam3");
      addParameter(args, "eRepeatUntil ", null, params, "eRepeatUntil ");
      addParameter(args, "eReminder", null, params, "eReminder");
      addParameter(args, "notes", null, params, "notes");
      odsExecute("calendar.event.edit", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-calendar-task"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"subject": noun_arb_text, "description": noun_arb_text, "attendees": noun_arb_text, "privacy": noun_arb_text, "tags": noun_arb_text, "eventStart": noun_arb_text, "eventEnd": noun_arb_text, "priority": noun_arb_text, "status": noun_arb_text, "complete": noun_arb_text, "completedDate": noun_arb_text, "note": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-task &lt;instance_id&gt; subject &lt;subject&gt; [description &lt;description&gt;] [attendees &lt;attendees&gt;] [privacy &lt;privacy&gt;] [tags &lt;tags&gt;] eventStart &lt;eventStart&gt; eventEnd &lt;eventEnd&gt; [priority &lt;priority&gt;] [status &lt;status&gt;] [complete &lt;complete&gt;] [completedDate &lt;completedDate&gt;] [notes &lt;notes&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "subject", null, params, "subject", true);
      addParameter(args, "description", null, params, "description");
      addParameter(args, "attendees", null, params, "attendees");
      addParameter(args, "privacy", null, params, "privacy");
      addParameter(args, "tags", null, params, "tags");
      addParameter(args, "eventStart", null, params, "eventStart", true);
      addParameter(args, "eventEnd", null, params, "eventEnd", true);
      addParameter(args, "priority", null, params, "priority");
      addParameter(args, "status", null, params, "status");
      addParameter(args, "complete", null, params, "complete");
      addParameter(args, "completedDate", null, params, "completed");
      addParameter(args, "notes", null, params, "notes");
      odsExecute("calendar.task.new", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-update-calendar-task"],
  arguments: [{role: "object", label: "event_id", nountype: noun_type_id}],
  modifiers: {"subject": noun_arb_text, "description": noun_arb_text, "attendees": noun_arb_text, "privacy": noun_arb_text, "tags": noun_arb_text, "eventStart": noun_arb_text, "eventEnd": noun_arb_text, "priority": noun_arb_text, "status": noun_arb_text, "complete": noun_arb_text, "completedDate": noun_arb_text, "note": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-calendar-task &lt;event_id&gt; subject &lt;subject&gt; [description &lt;description&gt;] [attendees &lt;attendees&gt;] [privacy &lt;privacy&gt;] [tags &lt;tags&gt;] eventStart &lt;eventStart&gt; eventEnd &lt;eventEnd&gt; [priority &lt;priority&gt;] [status &lt;status&gt;] [complete &lt;complete&gt;] [completedDate &lt;completedDate&gt;] [notes &lt;notes&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "event_id", true);
      addParameter(args, "subject", null, params, "subject", true);
      addParameter(args, "description", null, params, "description");
      addParameter(args, "attendees", null, params, "attendees");
      addParameter(args, "privacy", null, params, "privacy");
      addParameter(args, "tags", null, params, "tags");
      addParameter(args, "eventStart", null, params, "eventStart", true);
      addParameter(args, "eventEnd", null, params, "eventEnd", true);
      addParameter(args, "priority", null, params, "priority");
      addParameter(args, "status", null, params, "status");
      addParameter(args, "complete", null, params, "complete");
      addParameter(args, "completedDate", null, params, "completed");
      addParameter(args, "notes", null, params, "notes");
      odsExecute("calendar.task.edit", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-calendar-item-by-id"],
  arguments: [{role: "object", label: "event_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-calendar-item-by-id &lt;event_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "event_id", true);
      odsExecute("calendar.delete", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-export-calendar"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"events": noun_arb_text, "tasks": noun_arb_text, "periodFrom": noun_arb_text, "periodTo": noun_arb_text, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-export-calendar &lt;instance_id&gt; [events &lt;0|1&gt;] [tasks &lt;0|1&gt;] [periodFrom &lt;periodFrom&gt;] [periodTo &lt;periodTo&gt;] [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "events", null, params, "events");
      addParameter(args, "tasks", null, params, "tasks");
      addParameter(args, "periodFrom", null, params, "periodFrom");
      addParameter(args, "periodTo", null, params, "periodTo");
      addParameter(args, "tagsInclude", null, params, "tagsInclude");
      addParameter(args, "tagsExclude", null, params, "tagsExclude");
      odsPreview(previewBlock, this, "calendar.export", params, "calendar");
    } catch (ex) {
    }
        },
});

CmdUtils.CreateCommand({
  names: ["ods-import-calendar"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"source": noun_arb_text, "sourceType": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "events": noun_arb_text, "tasks": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-import-calendar &lt;instance_id&gt; source &lt;source&gt; sourceType &lt;WebDAV|URL&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [events &lt;0|1&gt;] [tasks &lt;0|1&gt;] [tags &lt;tags&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "source", null, params, "source", true);
      addParameter(args, "sourceType", null, params, "sourceType", true);
      addParameter(args, "userName", null, params, "userName");
      addParameter(args, "userPassword", null, params, "userPassword");
      addParameter(args, "events", null, params, "events");
      addParameter(args, "tasks", null, params, "tasks");
      addParameter(args, "tags", null, params, "tags");
      odsExecute("calendar.import", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-calendar-annotation-by-id"],
  arguments: [{role: "object", label: "annotation_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-calendar-annotation-by-id &lt;annotation_id&gt;",

  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Annotation ID", params, "annotation_id", true);
      odsPreview(previewBlock, this, "calendar.annotation.get", params, "calendar");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-calendar-annotation"],
  arguments: [{role: "object", label: "event_id", nountype: noun_type_id}],
  modifiers: {"author": noun_arb_text, "body": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-annotation &lt;event_id&gt; author &lt;author&gt; body &lt;body&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "event_id", true);
      addParameter(args, "author", null, params, "author", true);
      addParameter(args, "body", null, params, "body", true);
      odsExecute("calendar.annotation.new", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-calendar-annotation-claim"],
  arguments: [{role: "object", label: "annotation_id", nountype: noun_type_id}],
  modifiers: {"iri": noun_arb_text, "relation": noun_arb_text, "value": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-annotation-claim &lt;annotation_id&gt; iri &lt;iri&gt; relation &lt;relation&gt; value &lt;value&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "annotation_id", true);
      addParameter(args, "iri", null, params, "claimIri", true);
      addParameter(args, "relation", null, params, "claimRelation", true);
      addParameter(args, "value", null, params, "claimValue", true);
      odsExecute("calendar.annotation.claim", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-calendar-annotation"],
  arguments: [{role: "object", label: "annotation_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-calendar-annotation &lt;annotation_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Annotation ID", params, "annotation_id", true);
      odsExecute("calendar.annotation.delete", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-calendar-comment-by-id"],
  arguments: [{role: "object", label: "comment_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-calendar-comment-by-id &lt;comment_id&gt;",

  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Comment ID", params, "comment_id", true);
      odsPreview(previewBlock, this, "calendar.comment.get", params, "calendar");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-calendar-comment"],
  arguments: [{role: "object", label: "event_id", nountype: noun_type_id}],
  modifiers: {"title": noun_arb_text, "body": noun_arb_text, "author": noun_arb_text, "authorMail": noun_arb_text, "authorUrl": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-comment &lt;event_id&gt; title &lt;title&gt; body &lt;body&gt; author &lt;author&gt; authorMail &lt;authorMail&gt; [authorUrl &lt;authorUrl&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "event_id", true);
      addParameter(args, "title", null, params, "title", true);
      addParameter(args, "body", null, params, "text", true);
      addParameter(args, "author", null, params, "name", true);
      addParameter(args, "authorMail", null, params, "email", true);
      addParameter(args, "authorUrl", null, params, "url");
      odsExecute("calendar.comment.new", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-calendar-comment"],
  arguments: [{role: "object", label: "comment_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-calendar-comment &lt;comment_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Comment ID", params, "comment_id", true);
      odsExecute("calendar.comment.delete", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-calendar-publication"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "destinationType": noun_arb_text, "destination": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "events": noun_arb_text, "tasks": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-publication &lt;instance_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|daily&gt;] [updateFreq &lt;updateFreq&gt;] [destinationType &lt;destinationType&gt;] destination &lt;destination&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [events &lt;0|1&gt;] [tasks &lt;0|1&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "updateType", null, params, "updateType");
      addParameter(args, "updatePeriod", null, params, "updatePeriod");
      addParameter(args, "updateFreq", null, params, "updateFreq");
      addParameter(args, "destinationType", null, params, "destinationType");
      addParameter(args, "destination", null, params, "destination", true);
      addParameter(args, "userName", null, params, "userName");
      addParameter(args, "userPassword", null, params, "userPassword");
      addParameter(args, "events", null, params, "events");
      addParameter(args, "tasks", null, params, "tasks");
      odsExecute("calendar.publication.new", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});


CmdUtils.CreateCommand({
  names: ["ods-update-calendar-publication"],
  arguments: [{role: "object", label: "publication_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "destinationType": noun_arb_text, "destination": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "events": noun_arb_text, "tasks": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-calendar-publication &lt;publication_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|daily&gt;] [updateFreq &lt;updateFreq&gt;] [destinationType &lt;destinationType&gt;] destination &lt;destination&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [events &lt;0|1&gt;] [tasks &lt;0|1&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "publication_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "updateType", null, params, "updateType");
      addParameter(args, "updatePeriod", null, params, "updatePeriod");
      addParameter(args, "updateFreq", null, params, "updateFreq");
      addParameter(args, "destinationType", null, params, "destinationType");
      addParameter(args, "destination", null, params, "destination", true);
      addParameter(args, "userName", null, params, "userName");
      addParameter(args, "userPassword", null, params, "userPassword");
      addParameter(args, "events", null, params, "events");
      addParameter(args, "tasks", null, params, "tasks");
      odsExecute("calendar.publication.edit", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-calendar-publication"],
  arguments: [{role: "object", label: "publication_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-calendar-publication &lt;publication_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "publication_id", true);
      odsPreview(previewBlock, this, "calendar.publication.get", params, "calendar");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-sync-calendar-publication"],
  arguments: [{role: "object", label: "publication_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-sync-calendar-publication &lt;publication_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "publication_id", true);
      odsExecute("calendar.publication.sync", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-calendar-publication"],
  arguments: [{role: "object", label: "publication_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-calendar-publication &lt;publication_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "publication_id", true);
      odsExecute("calendar.publication.delete", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-calendar-subscription"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "sourceType": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "events": noun_arb_text, "tasks": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-subscription &lt;instance_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|daily&gt;] [updateFreq &lt;updateFreq&gt;] [sourceType &lt;sourceType&gt;] source &lt;source&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [events &lt;0|1&gt;] [tasks &lt;0|1&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "updateType", null, params, "updateType");
      addParameter(args, "updatePeriod", null, params, "updatePeriod");
      addParameter(args, "updateFreq", null, params, "updateFreq");
      addParameter(args, "sourceType", null, params, "sourceType");
      addParameter(args, "source", null, params, "source", true);
      addParameter(args, "userName", null, params, "userName");
      addParameter(args, "userPassword", null, params, "userPassword");
      addParameter(args, "events", null, params, "events");
      addParameter(args, "tasks", null, params, "tasks");
      odsExecute("calendar.subscription.new", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-update-calendar-subscription"],
  arguments: [{role: "object", label: "subscription_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "sourceType": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "events": noun_arb_text, "tasks": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-calendar-subscription &lt;subscription_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|daily&gt;] [updateFreq &lt;updateFreq&gt;] [sourceType &lt;sourceType&gt;] source &lt;source&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [events &lt;0|1&gt;] [tasks &lt;0|1&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "subscription_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "updateType", null, params, "updateType");
      addParameter(args, "updatePeriod", null, params, "updatePeriod");
      addParameter(args, "updateFreq", null, params, "updateFreq");
      addParameter(args, "sourceType", null, params, "sourceType");
      addParameter(args, "source", null, params, "source", true);
      addParameter(args, "userName", null, params, "userName");
      addParameter(args, "userPassword", null, params, "userPassword");
      addParameter(args, "events", null, params, "events");
      addParameter(args, "tasks", null, params, "tasks");
      odsExecute("calendar.subscription.edit", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-calendar-subscription"],
  arguments: [{role: "object", label: "subscription_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-calendar-subscription &lt;subscription_id&gt;",
  preview: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "subscription_id", true);
      odsPreview(previewBlock, this, "calendar.subscription.get", params, "calendar");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-sync-calendar-subscription"],
  arguments: [{role: "object", label: "subscription_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-sync-calendar-subscription &lt;subscription_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "subscription_id", true);
      odsExecute("calendar.subscription.sync", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-calendar-subscription"],
  arguments: [{role: "object", label: "subscription_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-calendar-subscription &lt;subscription_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "subscription_id", true);
      odsExecute("calendar.subscription.delete", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-calendar-upstream"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-calendar-upstream &lt;instance_id&gt; name &lt;name&gt; source &lt;source&gt; userName &lt;userName&gt; userPassword &lt;userPassword&gt; [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "source", null, params, "source", true);
      addParameter(args, "userName", null, params, "userName", true);
      addParameter(args, "userPassword", null, params, "userPassword", true);
      addParameter(args, "tagsInclude", null, params, "tagsInclude");
      addParameter(args, "tagsExclude", null, params, "tagsExclude");
      odsExecute("calendar.upstream.new", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-update-calendar-upstream"],
  arguments: [{role: "object", label: "upstream_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-calendar-upstream &lt;upstream_id&gt; name &lt;name&gt; source &lt;source&gt; userName &lt;userName&gt; userPassword &lt;userPassword&gt; [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "upstream_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "source", null, params, "source", true);
      addParameter(args, "userName", null, params, "userName", true);
      addParameter(args, "userPassword", null, params, "userPassword", true);
      addParameter(args, "tagsInclude", null, params, "tagsInclude");
      addParameter(args, "tagsExclude", null, params, "tagsExclude");
      odsExecute("calendar.upstream.edit", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-calendar-upstream"],
  arguments: [{role: "object", label: "upstream_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-calendar-upstream &lt;upstream_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "upstream_id", true);
      odsExecute("calendar.upstream.delete", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-set-calendar-options"],
  arguments: [
              {role: "object", label: "instance_id", nountype: noun_type_id},
              {role: "instrument", label: "options", nountype: noun_arb_text}
             ],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Update instance options/parameteres",
  help: "Type ods-set-calendar-options &lt;instance_id&gt; with &lt;options&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Instcane ID", params, "inst_id", true);
      addParameter(args, "instrument", "Options", params, "options");
      odsExecute("calendar.options.set", params, "calendar");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-calendar-options"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Show instance options/parameteres",
  help: "Type ods-get-calendar-options &lt;instance_id&gt;",

  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Instance ID", params, "inst_id", true);
      odsPreview(previewBlock, this, "calendar.options.get", params, "calendar");
    } catch (ex) {
    }
  }
});

////////////////////////////////////
///// ODS AddressBook /////////////////
////////////////////////////////////

CmdUtils.CreateCommand({
  names: ["ods-set-addressbook-oauth"],
  arguments: [{role: "object", label: "oauth", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS AddressBook OAuth. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  help: "Type ods-set-addressbook-oauth &lt;oauth&gt;. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  execute: function (args) {
    try {
      checkParameter(args.object.text, "addressbook instance OAuth");
      ODS.setOAuth("addressbook", args.object.text);
    displayMessage("Your ODS AddressBook instance OAuth has been set.");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-search-addressbook-contacts"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"keywords": noun_arb_text, "tags": noun_arb_text, "category": noun_arb_text, "maxResults": noun_type_integer},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-search-addressbook-contacts &lt;instance_id&gt; keywords &lt;keywords&gt; tags &lt;tags&gt; category &lt;category&gt; maxResults &lt;maxResults&gt;",

  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "keywords", null, params, "keywords");
      addParameter(args, "tags", null, params, "tags");
      addParameter(args, "category", null, params, "category");
      addParameter(args, "maxResults", null, params, "maxResults");
      odsPreview(previewBlock, this, "addressbook.search", params, "addressbook");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-addressbook-contact-by-id"],
  arguments: [{role: "object", label: "contact_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-addressbook-contact-by-id &lt;contact_id&gt;",

  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "contact_id", true);
      odsPreview(previewBlock, this, "addressbook.get", params, "addressbook");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-addressbook-contact"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "title": noun_arb_text, "fName": noun_arb_text, "mName": noun_arb_text, "lName": noun_arb_text, "fullName": noun_arb_text, "gender": noun_arb_text, "birthday": noun_arb_text, "iri": noun_arb_text, "foaf": noun_arb_text, "mail": noun_arb_text, "web": noun_arb_text, "icq": noun_arb_text, "skype": noun_arb_text, "aim": noun_arb_text, "yahoo": noun_arb_text, "msn": noun_arb_text, "hCountry": noun_arb_text, "hState": noun_arb_text, "hCity": noun_arb_text, "hCode": noun_arb_text, "hAddress1": noun_arb_text, "hAddress2": noun_arb_text, "hTzone": noun_arb_text, "hLat": noun_arb_text, "hLng": noun_arb_text, "hPhone": noun_arb_text, "hMobile": noun_arb_text, "hFax": noun_arb_text, "hMail": noun_arb_text, "hWeb": noun_arb_text, "bCountry": noun_arb_text, "bState": noun_arb_text, "bCity": noun_arb_text, "bCode": noun_arb_text, "bAddress1": noun_arb_text, "bAddress2": noun_arb_text, "bTzone": noun_arb_text, "bLat": noun_arb_text, "bLng": noun_arb_text, "bPhone": noun_arb_text, "bMobile": noun_arb_text, "bFax": noun_arb_text, "bIndustry": noun_arb_text, "bOrganization": noun_arb_text, "bDepartment": noun_arb_text, "bJob": noun_arb_text, "bMail": noun_arb_text, "bWeb": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-addressbook-contact &lt;instance_id&gt; name &lt;name&gt; [title &lt;title&gt;] [fName &lt;fName&gt;] [mName &lt;mName&gt;] [lName &lt;lName&gt;] [fullName &lt;fullName&gt;] [gender &lt;gender&gt;] [birthday &lt;birthday&gt;] [iri &lt;iri&gt;] [foaf &lt;foaf&gt;] [mail &lt;mail&gt;] [web &lt;web&gt;] [icq &lt;icq&gt;] [skype &lt;skype&gt;] [aim &lt;aim&gt;] [yahoo &lt;yahoo&gt;] [msn &lt;msn&gt;] [hCountry &lt;hCountry&gt;] [hState &lt;hState&gt;] [hCity &lt;hCity&gt;] [hCode &lt;hCode&gt;] [hAddress1 &lt;hAddress1&gt;] [hAddress2 &lt;hAddress2&gt;] [hTzone &lt;hTzone&gt;] [hLat &lt;hLat&gt;] [hLng &lt;hLng&gt;] [hPhone &lt;hPhone&gt;] [hMobile &lt;hMobile&gt;] [hFax &lt;hFax&gt;] [hMail &lt;hMail&gt;] [hWeb &lt;hWeb&gt;] [bCountry &lt;bCountry&gt;] [bState &lt;bState&gt;] [bCity &lt;bCity&gt;] [bCode &lt;bCode&gt;] [bAddress1 &lt;bAddress1&gt;] [bAddress2 &lt;bAddress2&gt;] [bTzone &lt;bTzone&gt;] [bLat &lt;bLat&gt;] [bLng &lt;bLng&gt;] [bPhone &lt;bPhone&gt;] [bMobile &lt;bMobile&gt;] [bFax &lt;bFax&gt;] [bIndustry &lt;bIndustry&gt;] [bOrganization &lt;bOrganization&gt;] [bDepartment &lt;bDepartment&gt;] [bJob &lt;bJob&gt;] [bMail &lt;bMail&gt;] [bWeb &lt;bWeb&gt;] [tags &lt;tags&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args,"title", params,"title");
      addParameter(args,"fName", params,"fName");
      addParameter(args,"mName", params,"mName");
      addParameter(args,"lName", params,"lName");
      addParameter(args,"fullName", params,"fullName");
      addParameter(args,"gender", params,"gender");
      addParameter(args,"birthday", params,"birthday");
      addParameter(args,"iri", params,"iri");
      addParameter(args,"foaf", params,"foaf");
      addParameter(args,"mail", params,"mail");
      addParameter(args,"web", params,"web");
      addParameter(args,"icq", params,"icq");
      addParameter(args,"skype", params,"skype");
      addParameter(args,"aim", params,"aim");
      addParameter(args,"yahoo", params,"yahoo");
      addParameter(args,"msn", params,"msn");
      addParameter(args,"hCountry", params,"hCountry");
      addParameter(args,"hState", params,"hState");
      addParameter(args,"hCity", params,"hCity");
      addParameter(args,"hCode", params,"hCode");
      addParameter(args,"hAddress1", params,"hAddress1");
      addParameter(args,"hAddress2", params,"hAddress2");
      addParameter(args,"hTzone", params,"hTzone");
      addParameter(args,"hLat", params,"hLat");
      addParameter(args,"hLng", params,"hLng");
      addParameter(args,"hPhone", params,"hPhone");
      addParameter(args,"hMobile", params,"hMobile");
      addParameter(args,"hFax", params,"hFax");
      addParameter(args,"hMail", params,"hMail");
      addParameter(args,"hWeb", params,"hWeb");
      addParameter(args,"bCountry", params,"bCountry");
      addParameter(args,"bState", params,"bState");
      addParameter(args,"bCity", params,"bCity");
      addParameter(args,"bCode", params,"bCode");
      addParameter(args,"bAddress1", params,"bAddress1");
      addParameter(args,"bAddress2", params,"bAddress2");
      addParameter(args,"bTzone", params,"bTzone");
      addParameter(args,"bLat", params,"bLat");
      addParameter(args,"bLng", params,"bLng");
      addParameter(args,"bPhone", params,"bPhone");
      addParameter(args,"bMobile", params,"bMobile");
      addParameter(args,"bFax", params,"bFax");
      addParameter(args,"bIndustry", params,"bIndustry");
      addParameter(args,"bOrganization", params,"bOrganization");
      addParameter(args,"bDepartment", params,"bDepartment");
      addParameter(args,"bJob", params,"bJob");
      addParameter(args,"bMail", params,"bMail");
      addParameter(args,"bWeb", params,"bWeb");
      addParameter(args,"tags", params,"tags");
      odsExecute("addressbook.new", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-update-addressbook-contact"],
  arguments: [{role: "object", label: "contact_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "title": noun_arb_text, "fName": noun_arb_text, "mName": noun_arb_text, "lName": noun_arb_text, "fullName": noun_arb_text, "gender": noun_arb_text, "birthday": noun_arb_text, "iri": noun_arb_text, "foaf": noun_arb_text, "mail": noun_arb_text, "web": noun_arb_text, "icq": noun_arb_text, "skype": noun_arb_text, "aim": noun_arb_text, "yahoo": noun_arb_text, "msn": noun_arb_text, "hCountry": noun_arb_text, "hState": noun_arb_text, "hCity": noun_arb_text, "hCode": noun_arb_text, "hAddress1": noun_arb_text, "hAddress2": noun_arb_text, "hTzone": noun_arb_text, "hLat": noun_arb_text, "hLng": noun_arb_text, "hPhone": noun_arb_text, "hMobile": noun_arb_text, "hFax": noun_arb_text, "hMail": noun_arb_text, "hWeb": noun_arb_text, "bCountry": noun_arb_text, "bState": noun_arb_text, "bCity": noun_arb_text, "bCode": noun_arb_text, "bAddress1": noun_arb_text, "bAddress2": noun_arb_text, "bTzone": noun_arb_text, "bLat": noun_arb_text, "bLng": noun_arb_text, "bPhone": noun_arb_text, "bMobile": noun_arb_text, "bFax": noun_arb_text, "bIndustry": noun_arb_text, "bOrganization": noun_arb_text, "bDepartment": noun_arb_text, "bJob": noun_arb_text, "bMail": noun_arb_text, "bWeb": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-addressbook-contact &lt;contact_id&gt; name &lt;name&gt; [title &lt;title&gt;] [fName &lt;fName&gt;] [mName &lt;mName&gt;] [lName &lt;lName&gt;] [fullName &lt;fullName&gt;] [gender &lt;gender&gt;] [birthday &lt;birthday&gt;] [iri &lt;iri&gt;] [foaf &lt;foaf&gt;] [mail &lt;mail&gt;] [web &lt;web&gt;] [icq &lt;icq&gt;] [skype &lt;skype&gt;] [aim &lt;aim&gt;] [yahoo &lt;yahoo&gt;] [msn &lt;msn&gt;] [hCountry &lt;hCountry&gt;] [hState &lt;hState&gt;] [hCity &lt;hCity&gt;] [hCode &lt;hCode&gt;] [hAddress1 &lt;hAddress1&gt;] [hAddress2 &lt;hAddress2&gt;] [hTzone &lt;hTzone&gt;] [hLat &lt;hLat&gt;] [hLng &lt;hLng&gt;] [hPhone &lt;hPhone&gt;] [hMobile &lt;hMobile&gt;] [hFax &lt;hFax&gt;] [hMail &lt;hMail&gt;] [hWeb &lt;hWeb&gt;] [bCountry &lt;bCountry&gt;] [bState &lt;bState&gt;] [bCity &lt;bCity&gt;] [bCode &lt;bCode&gt;] [bAddress1 &lt;bAddress1&gt;] [bAddress2 &lt;bAddress2&gt;] [bTzone &lt;bTzone&gt;] [bLat &lt;bLat&gt;] [bLng &lt;bLng&gt;] [bPhone &lt;bPhone&gt;] [bMobile &lt;bMobile&gt;] [bFax &lt;bFax&gt;] [bIndustry &lt;bIndustry&gt;] [bOrganization &lt;bOrganization&gt;] [bDepartment &lt;bDepartment&gt;] [bJob &lt;bJob&gt;] [bMail &lt;bMail&gt;] [bWeb &lt;bWeb&gt;] [tags &lt;tags&gt;]",
execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "contact_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args,"title", params,"title");
      addParameter(args,"fName", params,"fName");
      addParameter(args,"mName", params,"mName");
      addParameter(args,"lName", params,"lName");
      addParameter(args,"fullName", params,"fullName");
      addParameter(args,"gender", params,"gender");
      addParameter(args,"birthday", params,"birthday");
      addParameter(args,"iri", params,"iri");
      addParameter(args,"foaf", params,"foaf");
      addParameter(args,"mail", params,"mail");
      addParameter(args,"web", params,"web");
      addParameter(args,"icq", params,"icq");
      addParameter(args,"skype", params,"skype");
      addParameter(args,"aim", params,"aim");
      addParameter(args,"yahoo", params,"yahoo");
      addParameter(args,"msn", params,"msn");
      addParameter(args,"hCountry", params,"hCountry");
      addParameter(args,"hState", params,"hState");
      addParameter(args,"hCity", params,"hCity");
      addParameter(args,"hCode", params,"hCode");
      addParameter(args,"hAddress1", params,"hAddress1");
      addParameter(args,"hAddress2", params,"hAddress2");
      addParameter(args,"hTzone", params,"hTzone");
      addParameter(args,"hLat", params,"hLat");
      addParameter(args,"hLng", params,"hLng");
      addParameter(args,"hPhone", params,"hPhone");
      addParameter(args,"hMobile", params,"hMobile");
      addParameter(args,"hFax", params,"hFax");
      addParameter(args,"hMail", params,"hMail");
      addParameter(args,"hWeb", params,"hWeb");
      addParameter(args,"bCountry", params,"bCountry");
      addParameter(args,"bState", params,"bState");
      addParameter(args,"bCity", params,"bCity");
      addParameter(args,"bCode", params,"bCode");
      addParameter(args,"bAddress1", params,"bAddress1");
      addParameter(args,"bAddress2", params,"bAddress2");
      addParameter(args,"bTzone", params,"bTzone");
      addParameter(args,"bLat", params,"bLat");
      addParameter(args,"bLng", params,"bLng");
      addParameter(args,"bPhone", params,"bPhone");
      addParameter(args,"bMobile", params,"bMobile");
      addParameter(args,"bFax", params,"bFax");
      addParameter(args,"bIndustry", params,"bIndustry");
      addParameter(args,"bOrganization", params,"bOrganization");
      addParameter(args,"bDepartment", params,"bDepartment");
      addParameter(args,"bJob", params,"bJob");
      addParameter(args,"bMail", params,"bMail");
      addParameter(args,"bWeb", params,"bWeb");
      addParameter(args,"tags", params,"tags");
      odsExecute("addressbook.edit", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-addressbook-contact-by-id"],
  arguments: [{role: "object", label: "contact_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-addressbook-contact-by-id &lt;contact_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "contact_id", true);
      odsExecute("addressbook.delete", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-addressbook-contact-relationship"],
  arguments: [{role: "object", label: "relationship", nountype: noun_arb_text}],
  modifiers: {"with": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-addressbook-contact-relationship &lt;relationship&gt; with &lt;contact&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "relationship", true);
      addParameter(args, "with", null, params, "contact", true);
      odsExecute("addressbook.relationship.new", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-addressbook-contact-relationship"],
  arguments: [{role: "object", label: "relationship", nountype: noun_arb_text}],
  modifiers: {"with": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-addressbook-contact-relationship &lt;relationship&gt; with &lt;contact&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "relationship", true);
      addParameter(args, "with", null, params, "contact", true);
      odsExecute("addressbook.relationship.delete", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-export-addressbook"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"contentType": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-export-addressbook &lt;instance_id&gt; [contentType &lt;vcard|foaf|csv&gt;]",

  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "contentType", null, params, "contentType");
      odsPreview(previewBlock, this, "addressbook.export", params, "addressbook");
    } catch (ex) {
    }
  },
});

CmdUtils.CreateCommand({
  names: ["ods-import-addressbook"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"source": noun_arb_text, "sourceType": noun_arb_text, "contentType": noun_arb_text, "tags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-import-addressbook &lt;instance_id&gt; source &lt;source&gt; [sourceType &lt;WebDAV|URL&gt;] [contentType &lt;contentType&gt;] [tags &lt;tags&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "source", null, params, "source", true);
      addParameter(args, "sourceType", null, params, "sourceType");
      addParameter(args, "contentType", null, params, "contentType");
      addParameter(args, "tags", null, params, "tags");
      odsExecute("addressbook.import", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-addressbook-annotation-by-id"],
  arguments: [{role: "object", label: "annotation_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-addressbook-annotation-by-id &lt;annotation_id&gt;",

  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Annotation ID", params, "annotation_id", true);
      odsPreview(previewBlock, this, "addressbook.annotation.get", params, "addressbook");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-addressbook-annotation"],
  arguments: [{role: "object", label: "contact_id", nountype: noun_type_id}],
  modifiers: {"author": noun_arb_text, "body": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-addressbook-annotation &lt;contact_id&gt; author &lt;author&gt; body &lt;body&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "contact_id", true);
      addParameter(args, "author", null, params, "author", true);
      addParameter(args, "body", null, params, "body", true);
      odsExecute("addressbook.annotation.new", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-addressbook-annotation-claim"],
  arguments: [{role: "object", label: "annotation_id", nountype: noun_type_id}],
  modifiers: {"iri": noun_arb_text, "relation": noun_arb_text, "value": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-addressbook-annotation-claim &lt;annotation_id&gt; iri &lt;iri&gt; relation &lt;relation&gt; value &lt;value&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "annotation_id", true);
      addParameter(args, "iri", null, params, "claimIri", true);
      addParameter(args, "relation", null, params, "claimRelation", true);
      addParameter(args, "value", null, params, "claimValue", true);
      odsExecute("addressbook.annotation.claim", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-addressbook-annotation"],
  arguments: [{role: "object", label: "annotation_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-addressbook-annotation &lt;annotation_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Annotation ID", params, "annotation_id", true);
      odsExecute("addressbook.annotation.delete", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-addressbook-comment-by-id"],
  arguments: [{role: "object", label: "comment_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-addressbook-comment-by-id &lt;comment_id&gt;",

  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Comment ID", params, "comment_id", true);
      odsPreview(previewBlock, this, "addressbook.comment.get", params, "addressbook");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-addressbook-comment"],
  arguments: [{role: "object", label: "contact_id", nountype: noun_type_id}],
  modifiers: {"title": noun_arb_text, "body": noun_arb_text, "author": noun_arb_text, "authorMail": noun_arb_text, "authorUrl": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-addressbook-comment &lt;contact_id&gt; title &lt;title&gt; body &lt;body&gt; author &lt;author&gt; authorMail &lt;authorMail&gt; [authorUrl &lt;authorUrl&gt;]",
execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "contact_id", true);
      addParameter(args, "title", null, params, "title", true);
      addParameter(args, "body", null, params, "text", true);
      addParameter(args, "author", null, params, "name", true);
      addParameter(args, "authorMail", null, params, "email", true);
      addParameter(args, "authorUrl", null, params, "url");
      odsExecute("addressbook.comment.new", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-addressbook-comment"],
  arguments: [{role: "object", label: "comment_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-addressbook-comment &lt;comment_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Comment ID", params, "comment_id", true);
      odsExecute("addressbook.comment.delete", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-addressbook-publication"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "destinationType": noun_arb_text, "destination": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-addressbook-publication &lt;instance_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|daily&gt;] [updateFreq &lt;updateFreq&gt;] [destinationType &lt;destinationType&gt;] destination &lt;destination&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "updateType", null, params, "updateType");
      addParameter(args, "updatePeriod", null, params, "updatePeriod");
      addParameter(args, "updateFreq", null, params, "updateFreq");
      addParameter(args, "destinationType", null, params, "destinationType");
      addParameter(args, "destination", null, params, "destination", true);
      addParameter(args, "userName", null, params, "userName");
      addParameter(args, "userPassword", null, params, "userPassword");
      addParameter(args, "tagsInclude", null, params, "tagsInclude");
      addParameter(args, "tagsExclude", null, params, "tagsExclude");
      odsExecute("addressbook.publication.new", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});


CmdUtils.CreateCommand({
  names: ["ods-update-addressbook-publication"],
  arguments: [{role: "object", label: "publication_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "destinationType": noun_arb_text, "destination": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-addressbook-publication &lt;publication_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|daily&gt;] [updateFreq &lt;updateFreq&gt;] [destinationType &lt;destinationType&gt;] destination &lt;destination&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "publication_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "updateType", null, params, "updateType");
      addParameter(args, "updatePeriod", null, params, "updatePeriod");
      addParameter(args, "updateFreq", null, params, "updateFreq");
      addParameter(args, "destinationType", null, params, "destinationType");
      addParameter(args, "destination", null, params, "destination", true);
      addParameter(args, "userName", null, params, "userName");
      addParameter(args, "userPassword", null, params, "userPassword");
      addParameter(args, "tagsInclude", null, params, "tagsInclude");
      addParameter(args, "tagsExclude", null, params, "tagsExclude");
      odsExecute("addressbook.publication.edit", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-addressbook-publication"],
  arguments: [{role: "object", label: "publication_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-addressbook-publication &lt;publication_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "publication_id", true);
      odsPreview(previewBlock, this, "addressbook.publication.get", params, "addressbook");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-sync-addressbook-publication"],
  arguments: [{role: "object", label: "publication_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-addressbook-publication &lt;publication_id&gt;",
  execute: function (publication_id) {
    try {
      var params = {};
      addParameter(args, "object", "Publication ID", params, "publication_id", true);
      odsExecute("addressbook.publication.sync", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-addressbook-publication"],
  arguments: [{role: "object", label: "publication_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-addressbook-publication &lt;publication_id&gt;",
  execute: function (publication_id) {
    try {
      var params = {};
      addParameter(args, "object", "Publication ID", params, "publication_id", true);
      odsExecute("addressbook.publication.delete", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-addressbook-subscription"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "sourceType": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-addressbook-subscription &lt;instance_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|daily&gt;] [updateFreq &lt;updateFreq&gt;] [sourceType &lt;sourceType&gt;] source &lt;source&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "updateType", null, params, "updateType");
      addParameter(args, "updatePeriod", null, params, "updatePeriod");
      addParameter(args, "updateFreq", null, params, "updateFreq");
      addParameter(args, "sourceType", null, params, "sourceType");
      addParameter(args, "source", null, params, "source", true);
      addParameter(args, "userName", null, params, "userName");
      addParameter(args, "userPassword", null, params, "userPassword");
      addParameter(args, "tagsInclude", null, params, "tagsInclude");
      addParameter(args, "tagsExclude", null, params, "tagsExclude");
      odsExecute("addressbook.subscription.new", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-update-addressbook-subscription"],
  arguments: [{role: "object", label: "subscription_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "updateType": noun_arb_text, "updatePeriod": noun_arb_text, "updateFreq": noun_arb_text, "sourceType": noun_arb_text, "source": noun_arb_text, "userName": noun_arb_text, "userPassword": noun_arb_text, "tagsInclude": noun_arb_text, "tagsExclude": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-addressbook-subscription &lt;subscription_id&gt; name &lt;name&gt; [updateType &lt;updateType&gt;] [updatePeriod &lt;hourly|daily&gt;] [updateFreq &lt;updateFreq&gt;] [sourceType &lt;sourceType&gt;] source &lt;source&gt; [userName &lt;userName&gt;] [userPassword &lt;userPassword&gt;] [tagsInclude &lt;tagsInclude&gt;] [tagsExclude &lt;tagsExclude&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "subscription_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "updateType", null, params, "updateType");
      addParameter(args, "updatePeriod", null, params, "updatePeriod");
      addParameter(args, "updateFreq", null, params, "updateFreq");
      addParameter(args, "sourceType", null, params, "sourceType");
      addParameter(args, "source", null, params, "source", true);
      addParameter(args, "userName", null, params, "userName");
      addParameter(args, "userPassword", null, params, "userPassword");
      addParameter(args, "tagsInclude", null, params, "tagsInclude");
      addParameter(args, "tagsExclude", null, params, "tagsExclude");
      odsExecute("addressbook.subscription.edit", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-addressbook-subscription"],
  arguments: [{role: "object", label: "subscription_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software",
  email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-addressbook-subscription &lt;subscription_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Subscription ID", params, "subscription_id", true);
      odsPreview(previewBlock, this, "addressbook.subscription.get", params, "addressbook");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-sync-addressbook-subscription"],
  arguments: [{role: "object", label: "subscription_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software",
  email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-sync-addressbook-subscription &lt;subscription_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Subscription ID", params, "subscription_id", true);
      odsExecute("addressbook.subscription.sync", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-addressbook-subscription"],
  arguments: [{role: "object", label: "subscription_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software",
  email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-addressbook-subscription &lt;subscription_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "subscription_id", true);
      odsExecute("addressbook.subscription.delete", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-set-addressbook-options"],
  arguments: [
              {role: "object", label: "instance_id", nountype: noun_type_id},
              {role: "instrument", label: "options", nountype: noun_arb_text}
             ],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Update instance options/parameteres",
  help: "Type ods-set-addressbook-options &lt;instance_id&gt; with &lt;options&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Instcane ID", params, "inst_id", true);
      addParameter(args, "instrument", "Options", params, "options");
      odsExecute("addressbook.options.set", params, "addressbook");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-addressbook-options"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Show instance options/parameteres",
  help: "Type ods-get-addressbook-options &lt;instance_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Instance ID", params, "inst_id", true);
      odsPreview(previewBlock, this, "addressbook.options.get", params, "addressbook");
    } catch (ex) {
    }
  }
});

////////////////////////////////////
///// ods polls /////////////////
////////////////////////////////////

CmdUtils.CreateCommand({
  names: ["ods-set-poll-oauth"],
  arguments: [{role: "object", label: "oauth", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS poll OAuth. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  help: "Type ods-set-poll-oauth &lt;oauth&gt;. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  execute: function (args) {
    try {
      checkParameter(args.object.text, "Poll Instance OAuth");
      ODS.setOAuth("poll", args.object.text);
    displayMessage("Your ODS poll instance OAuth has been set.");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-poll-by-id"],
  arguments: [{role: "object", label: "poll_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-poll-by-id &lt;poll_id&gt;",

  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Poll ID", params, "poll_id", true);
      odsPreview(previewBlock, this, "poll.get", params, "poll");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-poll"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "description": noun_arb_text, "tags": noun_arb_text, "multi_vote": noun_arb_text, "vote_result": noun_arb_text, "vote_result_before": noun_arb_text, "vote_result_opened": noun_arb_text, "dateStart": noun_arb_text, "dateEnd": noun_arb_text, "mode": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-poll &lt;instance_id&gt; name &lt;name&gt; [description &lt;description&gt;] [tags &lt;tags&gt;] [multi_vote &lt;0|1&gt;] [vote_result &lt;0|1&gt;] [vote_result_before &lt;0|1&gt;] [vote_result_opened &lt;0|1&gt;] [dateStart &lt;dateStart&gt;] [dateEnd &lt;dateEnd&gt;] [mode &lt;mode&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "description", null, params, "description");
      addParameter(args, "tags", null, params, "tags");
      addParameter(args, "multi_vote", null, params, "multi_vote");
      addParameter(args, "vote_result", null, params, "vote_result");
      addParameter(args, "vote_result_before", null, params, "vote_result_before");
      addParameter(args, "vote_result_opened", null, params, "vote_result_opened");
      addParameter(args, "dateStart", null, params, "date_start");
      addParameter(args, "dateEnd", null, params, "date_end");
      addParameter(args, "mode", null, params, "mode");
      odsExecute("poll.new", params, "poll");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-update-poll"],
  arguments: [{role: "object", label: "poll_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "description": noun_arb_text, "tags": noun_arb_text, "multi_vote": noun_arb_text, "vote_result": noun_arb_text, "vote_result_before": noun_arb_text, "vote_result_opened": noun_arb_text, "dateStart": noun_arb_text, "dateEnd": noun_arb_text, "mode": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-poll &lt;poll_id&gt; name &lt;name&gt; [description &lt;description&gt;] [tags &lt;tags&gt;] [multi_vote &lt;0|1&gt;] [vote_result &lt;0|1&gt;] [vote_result_before &lt;0|1&gt;] [vote_result_opened &lt;0|1&gt;] [dateStart &lt;dateStart&gt;] [dateEnd &lt;dateEnd&gt;] [mode &lt;mode&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "poll_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "description", null, params, "description");
      addParameter(args, "tags", null, params, "tags");
      addParameter(args, "multi_vote", null, params, "multi_vote");
      addParameter(args, "vote_result", null, params, "vote_result");
      addParameter(args, "vote_result_before", null, params, "vote_result_before");
      addParameter(args, "vote_result_opened", null, params, "vote_result_opened");
      addParameter(args, "dateStart", null, params, "date_start");
      addParameter(args, "dateEnd", null, params, "date_end");
      addParameter(args, "mode", null, params, "mode");
      odsExecute("poll.edit", params, "poll");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-poll-by-id"],
  arguments: [{role: "object", label: "poll_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-poll-by-id &lt;poll_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Poll ID", params, "poll_id", true);
      odsExecute("poll.delete", params, "poll");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-poll-question"],
  arguments: [{role: "object", label: "poll_id", nountype: noun_type_id}],
  modifiers: {"questionNo": noun_type_integer, "text": noun_arb_text, "description": noun_arb_text, "required": noun_arb_text, "type": noun_arb_text, "answer": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-poll-question &lt;poll_id&gt; questionNo &lt;questionNo&gt; text &lt;text&gt; [description &lt;description&gt;] [required &lt;required&gt;] [type &lt;type&gt;] [answer &lt;answer&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "poll_id", true);
      addParameter(args, "questionNo", null, params, "questionNo", true);
      addParameter(args, "text", null, params, "text", true);
      addParameter(args, "description", null, params, "description");
      addParameter(args, "required", null, params, "required");
      addParameter(args, "type", null, params, "type");
      addParameter(args, "answer", null, params, "answer", true);
      odsExecute("poll.question.new", params, "poll");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-poll-question"],
  arguments: [{role: "object", label: "poll_id", nountype: noun_type_id}],
  modifiers: {"questionNo": noun_type_integer},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-poll-question &lt;poll_id&gt; questionNo &lt;questionNo&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "poll_id", true);
      addParameter(args, "questionNo", null, params, "questionNo", true);
      odsExecute("poll.question.delete", params, "poll");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-activate-poll"],
  arguments: [{role: "object", label: "poll_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-activate-poll &lt;poll_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Poll ID", params, "poll_id", true);
      odsExecute("poll.activate", params, "poll");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-close-poll"],
  arguments: [{role: "object", label: "poll_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-close-poll &lt;poll_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Poll ID", params, "poll_id", true);
      odsExecute("poll.close", params, "poll");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-clear-poll"],
  arguments: [{role: "object", label: "poll_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-clear-poll &lt;poll_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Poll ID", params, "poll_id", true);
      odsExecute("poll.clear", params, "poll");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-vote-poll"],
  arguments: [{role: "object", label: "poll_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-vote-poll &lt;poll_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Poll ID", params, "poll_id", true);
      odsExecute("poll.vote", params, "poll");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-poll-vote-answer"],
  arguments: [{role: "object", label: "vote_id", nountype: noun_type_id}],
  modifiers: {"questionNo": noun_type_integer, "answerNo": noun_type_integer, "value": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-poll-vote-answer &lt;vote_id&gt; questionNo &lt;questionNo&gt; answerNo &lt;answerNo&gt; value &lt;value&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "vote_id", true);
      addParameter(args, "questionNo", null, params, "questionNo", true);
      addParameter(args, "answerNo", null, params, "answerNo", true);
      addParameter(args, "value", null, params, "value", true);
      odsExecute("poll.vote.answer", params, "poll");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-result-poll"],
  arguments: [{role: "object", label: "poll_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-result-poll &lt;poll_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Poll ID", params, "poll_id", true);
      odsPreview(previewBlock, this, "poll.result", params, "poll");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-poll-comment-by-id"],
  arguments: [{role: "object", label: "comment_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-poll-comment-by-id &lt;comment_id&gt;",

  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Comment ID", params, "comment_id", true);
      odsPreview(previewBlock, this, "poll.comment.get", params, "poll");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-poll-comment"],
  arguments: [{role: "object", label: "poll_id", nountype: noun_type_id}],
  modifiers: {"title": noun_arb_text, "body": noun_arb_text, "author": noun_arb_text, "authorMail": noun_arb_text, "authorUrl": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-poll-comment &lt;poll_id&gt; title &lt;title&gt; body &lt;body&gt; author &lt;author&gt; authorMail &lt;authorMail&gt; [authorUrl &lt;authorUrl&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "poll_id", true);
      addParameter(args, "title", null, params, "title", true);
      addParameter(args, "body", null, params, "text", true);
      addParameter(args, "author", null, params, "name", true);
      addParameter(args, "authorMail", null, params, "email", true);
      addParameter(args, "authorUrl", null, params, "url");
      odsExecute("poll.comment.new", params, "poll");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-poll-comment"],
  arguments: [{role: "object", label: "comment_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-poll-comment &lt;comment_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Comment ID", params, "comment_id", true);
      odsExecute("poll.comment.delete", params, "poll");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-set-polls-options"],
  arguments: [
              {role: "object", label: "instance_id", nountype: noun_type_id},
              {role: "instrument", label: "options", nountype: noun_arb_text}
             ],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Update instance options/parameteres",
  help: "Type ods-set-polls-options &lt;instance_id&gt; with &lt;options&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Instcane ID", params, "inst_id", true);
      addParameter(args, "instrument", "Options", params, "options");
      odsExecute("poll.options.set", params, "poll");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-polls-options"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Show instance options/parameteres",
  help: "Type ods-get-polls-options &lt;instance_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Instance ID", params, "inst_id", true);
      odsPreview(previewBlock, this, "poll.options.get", params, "poll");
    } catch (ex) {
    }
  }
});

////////////////////////////////////
///// ods weblog /////////////////
////////////////////////////////////
CmdUtils.CreateCommand({
  names: ["ods-set-weblog-oauth"],
  arguments: [{role: "object", label: "oauth", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS weblog OAuth. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  help: "Type ods-set-weblog-oauth &lt;oauth&gt;. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  execute: function (args) {
    try {
      checkParameter(args.object.text, "Weblog Instance OAuth");
      ODS.setOAuth("weblog", args.object.text);
    displayMessage("Your ODS Weblog instance OAuth has been set.");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-weblog-by-id"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-weblog-by-id &lt;instance_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Instance ID", params, "inst_id", true);
      odsPreview(previewBlock, this, "weblog.get", params, "weblog");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-weblog-post-by-id"],
  arguments: [{role: "object", label: "post_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-weblog-post-by-id &lt;post_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "post_id", true);
      odsPreview(previewBlock, this, "weblog.post.get", params, "weblog");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-weblog-post"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"title": noun_arb_text, "description": noun_arb_text, "categories": noun_arb_text, "dateCreated": noun_arb_text, "enclosure": noun_arb_text, "source": noun_arb_text, "link": noun_arb_text, "author": noun_arb_text, "comments": noun_arb_text, "allowComments": noun_arb_text, "allowPings": noun_arb_text, "convertBreaks": noun_arb_text, "excerpt": noun_arb_text, "pingUrls": noun_arb_text, "textMore": noun_arb_text, "keywords": noun_arb_text, "publish": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-weblog-post &lt;instance_id&gt; title &lt;title&gt; description &lt;description&gt; [categories &lt;categories&gt;] [dateCreated &lt;dateCreated&gt;] [enclosure &lt;enclosure&gt;] [source &lt;source&gt;] [link &lt;link&gt;] [author &lt;author&gt;] [comments &lt;comments&gt;] [allowComments &lt;allowComments&gt;] [allowPings &lt;allowPings&gt;] [convertBreaks &lt;convertBreaks&gt;] [excerpt &lt;excerpt&gt;] [pingUrls &lt;pingUrls&gt;] [textMore &lt;textMore&gt;] [keywords &lt;keywords&gt;] [publish &lt;publish&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "title", null, params, "title", true);
      addParameter(args, "description", null, params, "description", true);
      addParameter(args, "categories", null, params, "categories");
      addParameter(args, "dateCreated", null, params, "date_created");
      addParameter(args, "enclosure", null, params, "enclosure");
      addParameter(args, "source", null, params, "source");
      addParameter(args, "link", null, params, "link");
      addParameter(args, "comments", null, params, "comments");
      addParameter(args, "allowComments", null, params, "allow_comments");
      addParameter(args, "allowPings", null, params, "allow_pings");
      addParameter(args, "convertBreaks", null, params, "convert_breaks");
      addParameter(args, "excerpt", null, params, "excerpt");
      addParameter(args, "pingUrls", null, params, "tb_ping_urls");
      addParameter(args, "textMore", null, params, "text_more");
      addParameter(args, "keywords", null, params, "keywords");
      addParameter(args, "publish", null, params, "publish");
      odsExecute("weblog.post.new", params, "weblog");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-update-weblog-post"],
  arguments: [{role: "object", label: "post_id", nountype: noun_type_id}],
  modifiers: {"title": noun_arb_text, "description": noun_arb_text, "categories": noun_arb_text, "dateCreated": noun_arb_text, "enclosure": noun_arb_text, "source": noun_arb_text, "link": noun_arb_text, "author": noun_arb_text, "comments": noun_arb_text, "allowComments": noun_arb_text, "allowPings": noun_arb_text, "convertBreaks": noun_arb_text, "excerpt": noun_arb_text, "pingUrls": noun_arb_text, "textMore": noun_arb_text, "keywords": noun_arb_text, "publish": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-weblog-post &lt;post_id&gt; title &lt;title&gt; description &lt;description&gt; [categories &lt;categories&gt;] [dateCreated &lt;dateCreated&gt;] [enclosure &lt;enclosure&gt;] [source &lt;source&gt;] [link &lt;link&gt;] [author &lt;author&gt;] [comments &lt;comments&gt;] [allowComments &lt;allowComments&gt;] [allowPings &lt;allowPings&gt;] [convertBreaks &lt;convertBreaks&gt;] [excerpt &lt;excerpt&gt;] [pingUrls &lt;pingUrls&gt;] [textMore &lt;textMore&gt;] [keywords &lt;keywords&gt;] [publish &lt;publish&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "post_id", true);
      addParameter(args, "title", null, params, "title", true);
      addParameter(args, "description", null, params, "description", true);
      addParameter(args, "categories", null, params, "categories");
      addParameter(args, "dateCreated", null, params, "date_created");
      addParameter(args, "enclosure", null, params, "enclosure");
      addParameter(args, "source", null, params, "source");
      addParameter(args, "link", null, params, "link");
      addParameter(args, "comments", null, params, "comments");
      addParameter(args, "allowComments", null, params, "allow_comments");
      addParameter(args, "allowPings", null, params, "allow_pings");
      addParameter(args, "convertBreaks", null, params, "convert_breaks");
      addParameter(args, "excerpt", null, params, "excerpt");
      addParameter(args, "pingUrls", null, params, "tb_ping_urls");
      addParameter(args, "textMore", null, params, "text_more");
      addParameter(args, "keywords", null, params, "keywords");
      addParameter(args, "publish", null, params, "publish");
      odsExecute("weblog.post.edit", params, "weblog");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-weblog-post-by-id"],
  arguments: [{role: "object", label: "post_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-weblog-post-by-id &lt;post_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "post_id", true);
      odsExecute("weblog.post.delete", params, "weblog");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-weblog-comment-by-id"],
  arguments: [{role: "object", label: "post_id", nountype: noun_type_id}],
  modifiers: {"comment_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-weblog-comment-by-id &lt;post_id&gt; comment_id &lt;comment_id&gt;",

  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "post_id", true);
      addParameter(args, "comment_id", null, params, "comment_id", true);
      odsPreview(previewBlock, this, "weblog.comment.get", params, "weblog");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-weblog-comment"],
  arguments: [{role: "object", label: "post_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "text": noun_arb_text, "author": noun_arb_text, "authorMail": noun_arb_text, "authorUrl": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-weblog-comment &lt;post_id&gt; name &lt;name&gt; text &lt;text&gt; author &lt;author&gt; authorMail &lt;authorMail&gt; authorUrl &lt;authorUrl&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "post_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "text", null, params, "text", true);
      addParameter(args, "author", null, params, "title", true);
      addParameter(args, "authorMail", null, params, "email", true);
      addParameter(args, "authorUrl", null, params, "url", true);
      odsExecute("weblog.comment.new", params, "weblog");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-approve-weblog-comment"],
  arguments: [{role: "object", label: "post_id", nountype: noun_type_id}],
  modifiers: {"comment_id": noun_type_id, "flag": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-approve-weblog-comment &lt;post_id&gt; comment_id &lt;comment_id&gt; flag &lt;-1|0|1&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "post_id", true);
      addParameter(args, "comment_id", null, params, "comment_id", true);
      addParameter(args, "flag", null, params, "flag", true);
      odsExecute("weblog.comment.approve", params, "weblog");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-weblog-comment"],
  arguments: [{role: "object", label: "post_id", nountype: noun_type_id}],
  modifiers: {"comment_id": noun_type_id},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-weblog-comment post_id comment_id &lt;comment_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "post_id", true);
      addParameter(args, "comment_id", null, params, "comment_id", true);
      odsExecute("weblog.comment.delete", params, "weblog");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-set-weblog-options"],
  arguments: [
              {role: "object", label: "instance_id", nountype: noun_type_id},
              {role: "instrument", label: "options", nountype: noun_arb_text}
             ],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Update instance options/parameteres",
  help: "Type ods-set-weblog-options &lt;instance_id&gt; with &lt;options&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Instcane ID", params, "inst_id", true);
      addParameter(args, "instrument", "Options", params, "options");
      odsExecute("weblog.options.set", params, "weblog");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-weblog-options"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Show instance options/parameteres",
  help: "Type ods-get-weblog-options &lt;instance_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Instance ID", params, "inst_id", true);
      odsPreview(previewBlock, this, "weblog.options.get", params, "weblog");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-set-weblog-upstreaming"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"targetRpcUrl": noun_arb_text, "targetBlogId": noun_arb_text, "targetProtocolId": noun_arb_text, "targetUserName": noun_arb_text, "targetPassword": noun_arb_text, "aclAllow": noun_arb_text, "aclDeny": noun_arb_text, "syncInterval": noun_arb_text, "keepRemote": noun_arb_text, "maxRetries": noun_arb_text, "maxRetransmits": noun_arb_text, "initializeLog": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-set-weblog-upstreaming &lt;instance_id&gt; targetRpcUrl &lt;targetRpcUrl&gt; targetBlogId &lt;targetBlogId&gt; targetProtocolId &lt;targetProtocolId&gt; targetUserName &lt;targetUserName&gt; targetPassword &lt;targetPassword&gt; [aclAllow &lt;aclAllow&gt;] [aclDeny &lt;aclDeny&gt;] [syncInterval &lt;syncInterval&gt;] [keepRemote &lt;keepRemote&gt;] [maxRetries &lt;maxRetries&gt;] [maxRetransmits &lt;maxRetransmits&gt;] [initializeLog &lt;initializeLog&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "targetRpcUrl", null, params, "target_rpc_url", true);
      addParameter(args, "targetBlogId", null, params, "target_blog_id", true);
      addParameter(args, "targetProtocolId", null, params, "target_protocol_id", true);
      addParameter(args, "targetUserName", null, params, "target_uname", true);
      addParameter(args, "targetPassword", null, params, "target_password", true);
      addParameter(args, "aclAllow", null, params, "acl_allow");
      addParameter(args, "aclDeny", null, params, "acl_deny");
      addParameter(args, "syncInterval", null, params, "sync_interval");
      addParameter(args, "keepRemote", null, params, "keep_remote");
      addParameter(args, "maxRetries", null, params, "max_retries");
      addParameter(args, "maxRetransmits", null, params, "max_retransmits");
      addParameter(args, "initializeLog", null, params, "initialize_log");
      odsExecute("weblog.upstreaming.set", params, "weblog");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-weblog-upstreaming"],
  arguments: [{role: "object", label: "job_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-weblog-upstreaming &lt;job_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "job_id", true);
      odsExecute("weblog.upstreaming.get", params, "weblog");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-weblog-upstreaming"],
  arguments: [{role: "object", label: "job_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-weblog-upstreaming &lt;job_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "job_id", true);
      odsExecute("weblog.upstreaming.remove", params, "weblog");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-set-weblog-tagging"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"flag": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-set-weblog-tagging &lt;instance_id&gt; flag &lt;0|1&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "flag", null, params, "flag", true);
      odsExecute("weblog.tagging.set", params, "weblog");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-retag-weblog-tagging"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"keepExistingTags": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-retag-weblog-tagging &lt;instance_id&gt; keepExistingTags &lt;0|1&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "keepExistingTags", null, params, "keep_existing_tags", true);
      odsExecute("weblog.tagging.retag", params, "weblog");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

////////////////////////////////////
///// ods discussion /////////////////
////////////////////////////////////
CmdUtils.CreateCommand({
  names: ["ods-set-discussion-oauth"],
  arguments: [{role: "object", label: "oauth", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS Discussion OAuth. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  help: "Type ods-set-discussion-oauth &lt;oauth&gt;. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  execute: function (args) {
    try {
      checkParameter(args.object.text, "Discussion Instance OAuth");
      ODS.setOAuth("discussion", args.object.text);
    displayMessage("Your ODS Discussion instance OAuth has been set.");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-discussion-groups"],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-discussion-groups",
  preview: function (previewBlock) {
    var params = {};
    odsPreview(previewBlock, this, "discussion.groups.get", params, "discussion");
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-discussion-group-by-id"],
  arguments: [{role: "object", label: "group_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-discussion-group-by-id &lt;group_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "group_id", true);
      odsPreview(previewBlock, this, "discussion.group.get", params, "discussion");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-discussion-group"],
  arguments: [{role: "object", label: "name", nountype: noun_arb_text}],
  modifiers: {"description": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-discussion-group &lt;name&gt; description &lt;description&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "name", true);
      addParameter(args, "description", null, params, "description", true);
      odsExecute("discussion.group.new", params, "discussion");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-discussion-group-by-id"],
  arguments: [{role: "object", label: "group_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-discussion-group-by-id &lt;group_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "group_id", true);
      odsExecute("discussion.group.remove", params, "discussion");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-discussion-feed"],
  arguments: [{role: "object", label: "group_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-discussion-feed &lt;group_id&gt; name &lt;name&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "group_id", true);
      addParameter(args, "name", null, params, "name", true);
      odsExecute("discussion.feed.new", params, "discussion");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-discussion-feed-by-id"],
  arguments: [{role: "object", label: "feed_id", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-discussion-feed-by-id &lt;feed_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "feed_id", true);
      odsExecute("discussion.feed.remove", params, "discussion");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-discussion-message-by-id"],
  arguments: [{role: "object", label: "message_id", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-discussion-message-by-id &lt;message_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Message ID", params, "message_id", true);
      odsPreview(previewBlock, this, "discussion.message.get", params, "discussion");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-discussion-message"],
  arguments: [{role: "object", label: "group_id", nountype: noun_type_id}],
  modifiers: {"subject": noun_arb_text, "body": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-discussion-message &lt;group_id&gt; subject &lt;subject&gt; body &lt;body&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "group_id", true);
      addParameter(args, "subject", null, params, "subject", true);
      addParameter(args, "body", null, params, "body", true);
      odsExecute("discussion.message.new", params, "discussion");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-discussion-comment-by-id"],
  arguments: [{role: "object", label: "comment_id", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-discussion-comment-by-id &lt;comment_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Comment ID", params, "comment_id", true);
      odsPreview(previewBlock, this, "discussion.comment.get", params, "discussion");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-discussion-comment"],
  arguments: [{role: "object", label: "parent_id", nountype: noun_arb_text}],
  modifiers: {"subject": noun_arb_text, "body": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-discussion-comment &lt;parent_id&gt; subject &lt;subject&gt; body &lt;body&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "parent_id", true);
      addParameter(args, "subject", null, params, "subject", true);
      addParameter(args, "body", null, params, "body", true);
      odsExecute("discussion.comment.new", params, "discussion");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

////////////////////////////////////
///// ods feeds ////////////////////
////////////////////////////////////
CmdUtils.CreateCommand({
  names: ["ods-set-feeds-oauth"],
  arguments: [{role: "object", label: "oauth", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS FeedsManager OAuth. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  help: "Type ods-set-feeds-oauth &lt;oauth&gt;. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  execute: function (args) {
    try {
      checkParameter(args.object.text, "ODS FeedsManager instance OAuth");
      ODS.setOAuth("feeds", args.object.text);
      displayMessage("Your ODS FeedsManager instance OAuth has been set.");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-feed-by-id"],
  arguments: [{role: "object", label: "feed_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-feed-by-id &lt;feed_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Feed ID", params, "feed_id", true);
      odsPreview(previewBlock, this, "feeds.get", params, "feeds");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-subscribe-feed"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"uri": noun_arb_text, "name": noun_arb_text, "homeUri": noun_arb_text, "tags": noun_arb_text, "folder_id": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-subscribe-feed &lt;instance_id&gt; uri &lt;uri&gt; [name &lt;name&gt;] [homeUri &lt;homeUri&gt;] [tags &lt;tags&gt;] [folder_id &lt;folder_id&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "uri", null, params, "uri", true);
      addParameter(args, "name", null, params, "name");
      addParameter(args, "homeUri", null, params, "homeUri");
      addParameter(args, "tags", null, params, "tags");
      addParameter(args, "folder_id", null, params, "folder_id");
      odsExecute("feeds.subscribe", params, "feeds");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-unsubscribe-feed"],
  arguments: [{role: "object", label: "feed_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-unsubscribe-feed &lt;feed_id&gt;",
  execute: function (feed_id) {
    try {
      checkParameter(feed_id.text, "feed_id");
      var params = {feed_id: feed_id.text};
      odsExecute("feeds.unsubscribe", params, "feeds");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-refresh-feed"],
  arguments: [{role: "object", label: "feed_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-refresh-feed &lt;feed_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Feed ID", params, "feed_id", true);
      odsExecute("feeds.refresh", params, "feeds");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-subscribe-feeds-blog"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "api": noun_arb_text, "uri": noun_arb_text, "port": noun_arb_text, "endpoint": noun_arb_text, "user": noun_arb_text, "password": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-subscribe-feeds-blog &lt;instance_id&gt; name &lt;name&gt; api &lt;api&gt; uri &lt;uri&gt; port &lt;port&gt; endpoint &lt;endpoint&gt; user &lt;user&gt; password &lt;password&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "api", null, params, "api");
      addParameter(args, "uri", null, params, "uri", true);
      addParameter(args, "port", null, params, "port");
      addParameter(args, "endpoint", null, params, "endpoint");
      addParameter(args, "user", null, params, "user", true);
      addParameter(args, "password", null, params, "password", true);
      odsExecute("feeds.blog.subscribe", params, "feeds");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-unsubscribe-feeds-blog"],
  arguments: [{role: "object", label: "blog_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-unsubscribe-feeds-blog &lt;blog_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Blog ID", params, "blog_id", true);
      odsExecute("feeds.blog.unsubscribe", params, "feeds");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-refresh-feeds-blog"],
  arguments: [{role: "object", label: "blog_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-refresh-feeds-blog &lt;blog_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Blog ID", params, "blog_id", true);
      odsExecute("feeds.blog.refresh", params, "feeds");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-feeds-folder"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"path": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-feeds-folder &lt;instance_id&gt; path &lt;path&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "path", null, params, "path", true);
      odsExecute("feeds.folder.new", params, "feeds");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-feeds-folder"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"path": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-feeds-folder &lt;instance_id&gt; path &lt;path&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "path", null, params, "path", true);
      odsExecute("feeds.folder.delete", params, "feeds");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-feed-annotation-by-id"],
  arguments: [{role: "object", label: "annotation_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-feed-annotation-by-id &lt;annotation_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Annotation ID", params, "annotation_id", true);
      odsPreview(previewBlock, this, "feeds.annotation.get", params, "feeds");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-feed-item-annotation"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"item_id": noun_type_id, "author": noun_arb_text, "body": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-feed-item-annotation instance_id item_id &lt;item_id&gt; author &lt;author&gt; body &lt;body&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "item_id", null, params, "item_id", true);
      addParameter(args, "author", null, params, "author", true);
      addParameter(args, "body", null, params, "body", true);
      odsExecute("feeds.annotation.new", params, "feeds");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-feed-item-annotation-claim"],
  arguments: [{role: "object", label: "annotation_id", nountype: noun_type_id}],
  modifiers: {"iri": noun_arb_text, "relation": noun_arb_text, "value": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-feed-item-annotation-claim &lt;annotation_id&gt; iri &lt;iri&gt; relation &lt;relation&gt; value &lt;value&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "annotation_id", true);
      addParameter(args, "iri", null, params, "claimIri", true);
      addParameter(args, "relation", null, params, "claimRelation", true);
      addParameter(args, "value", null, params, "claimValue", true);
      odsExecute("feeds.annotation.claim", params, "feeds");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-feed-item-annotation"],
  arguments: [{role: "object", label: "annotation_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-feed-item-annotation &lt;annotation_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Annotation ID", params, "annotation_id", true);
      odsExecute("feeds.annotation.delete", params, "feeds");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-feed-item-comment-by-id"],
  arguments: [{role: "object", label: "comment_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-feed-item-comment-by-id &lt;comment_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Comment ID", params, "comment_id", true);
      odsPreview(previewBlock, this, "feeds.comment.get", params, "feeds");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-feed-item-comment"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"item_id": noun_type_id, "title": noun_arb_text, "body": noun_arb_text, "author": noun_arb_text, "authorMail": noun_arb_text, "authorUrl": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-feed-item-comment instance_id item_id &lt;item_id&gt; title &lt;title&gt; body &lt;body&gt; author &lt;author&gt; authorMail &lt;authorMail&gt; authorUrl [&lt;authorUrl&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "item_id", null, params, "item_id", true);
      addParameter(args, "title", null, params, "title", true);
      addParameter(args, "body", null, params, "text", true);
      addParameter(args, "author", null, params, "name", true);
      addParameter(args, "authorMail", null, params, "email", true);
      addParameter(args, "authorUrl", null, params, "url");
      odsExecute("feeds.comment.new", params, "feeds");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-feed-item-comment"],
  arguments: [{role: "object", label: "comment_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-feed-item-comment &lt;comment_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Comment ID", params, "comment_id", true);
      odsExecute("feeds.comment.delete", params, "feeds");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-set-feeds-options"],
  arguments: [
              {role: "object", label: "instance_id", nountype: noun_type_id},
              {role: "instrument", label: "options", nountype: noun_arb_text}
             ],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Update instance options/parameteres",
  help: "Type ods-set-feeds-options &lt;instance_id&gt; with &lt;options&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Instcane ID", params, "inst_id", true);
      addParameter(args, "instrument", "Options", params, "options");
      odsExecute("feeds.options.set", params, "feeds");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-feeds-options"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Show instance options/parameteres",
  help: "Type ods-get-feeds-options &lt;instance_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Instance ID", params, "inst_id", true);
      odsPreview(previewBlock, this, "feeds.options.get", params, "feeds");
    } catch (ex) {
    }
  }
});

////////////////////////////////////
///// ods photo ////////////////////
////////////////////////////////////
CmdUtils.CreateCommand({
  names: ["ods-set-photo-oauth"],
  arguments: [{role: "object", label: "oauth", nountype: noun_arb_text}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS Gallery OAuth. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  help: "Type ods-set-photo-oauth &lt;oauth&gt;. Get your oauth at " + ODS.getServer() + "/oauth_sid.vsp",
  execute: function (args) {
    try {
      checkParameter(args.object.text, "ODS Gallery instance OAuth");
      ODS.setOAuth("photo", args.object.text);
      displayMessage("Your ODS Gallery instance OAuth has been set.");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-photo-album"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "description": noun_arb_text, "startDate": noun_arb_text, "endDate": noun_arb_text, "visibility": noun_arb_text, "geoLocation": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-photo-album instance_id name &lt;name&gt; [description &lt;description&gt;] [startDate &lt;startDate&gt;] [endDate &lt;endDate&gt;] [visibility &lt;visibility&gt;] [geoLocation &lt;geoLocation&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "description", null, params, "description");
      addParameter(args, "startDate", null, params, "startDate");
      addParameter(args, "endDate", null, params, "endDate");
      addParameter(args, "visibility", null, params, "visibility");
      addParameter(args, "geoLocation", null, params, "geoLocation");
      odsExecute("photo.album.new", params, "photo");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-update-photo-album"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text, "new_name": noun_arb_text, "description": noun_arb_text, "startDate": noun_arb_text, "endDate": noun_arb_text, "visibility": noun_arb_text, "geoLocation": noun_arb_text, "obsolete": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-photo-album instance_id name &lt;name&gt; [new_name &lt;new_name&gt;] [description &lt;description&gt;] [startDate &lt;startDate&gt;] [endDate &lt;endDate&gt;] [visibility &lt;visibility&gt;] [geoLocation &lt;geoLocation&gt;] [obsolete &lt;obsolete&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "new_name", null, params, "new_name");
      addParameter(args, "description", null, params, "description");
      addParameter(args, "startDate", null, params, "startDate");
      addParameter(args, "endDate", null, params, "endDate");
      addParameter(args, "visibility", null, params, "visibility");
      addParameter(args, "geoLocation", null, params, "geoLocation");
      addParameter(args, "obsolete", null, params, "obsolete");
      odsExecute("photo.album.update", params, "photo");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-photo-album"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"name": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-photo-album instance_id name &lt;name&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "name", null, params, "name", true);
      odsExecute("photo.album.delete", params, "photo");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-photo-image"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"album": noun_arb_text, "name": noun_arb_text, "description": noun_arb_text, "visibility": noun_arb_text, "sourceUrl": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-photo-image instance_id album &lt;album&gt; name &lt;name&gt; [description &lt;description&gt;] [visibility &lt;visibility&gt;] sourceUrl &lt;sourceUrl&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "album", null, params, "album", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "description", null, params, "description");
      addParameter(args, "visibility", null, params, "visibility");
      addParameter(args, "sourceUrl", null, params, "sourceUrl", true);
      odsExecute("photo.image.newUrl", params, "photo");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-photo-image"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"album": noun_arb_text, "name": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-photo-image instance_id album &lt;album&gt; name &lt;name&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "album", null, params, "album", true);
      addParameter(args, "name", null, params, "name", true);
      params["outputFormat"] = "base64";
      odsPreview(previewBlock, this, "photo.image.get", params, "photo", "image");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-update-photo-image"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"album": noun_arb_text, "name": noun_arb_text, "new_name": noun_arb_text, "description": noun_arb_text, "visibility": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-update-photo-image instance_id album &lt;album&gt; name &lt;name&gt; [new_name &lt;new_name&gt;] [description &lt;description&gt;] [visibility &lt;visibility&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "album", null, params, "album", true);
      addParameter(args, "name", null, params, "name", true);
      addParameter(args, "new_name", null, params, "new_name");
      addParameter(args, "description", null, params, "description");
      addParameter(args, "visibility", null, params, "visibility");
      odsExecute("photo.image.update", params, "photo");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-photo-image"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"album": noun_arb_text, "name": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-photo-image instance_id album &lt;album&gt; name &lt;name&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "album", null, params, "album", true);
      addParameter(args, "name", null, params, "name", true);
      odsExecute("photo.image.delete", params, "photo");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-photo-image-comment-by-id"],
  arguments: [{role: "object", label: "comment_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-photo-image-comment-by-id &lt;comment_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Comment ID", params, "comment_id", true);
      odsPreview(previewBlock, this, "photo.comment.get", params, "photo");
    } catch (ex) {
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-create-photo-image-comment"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"album": noun_arb_text, "image": noun_arb_text, "text": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-create-photo-image-comment instance_id album &lt;album&gt; image &lt;image&gt; text &lt;text&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "album", null, params, "album", true);
      addParameter(args, "image", null, params, "image", true);
      addParameter(args, "text", null, params, "text", true);
      odsExecute("photo.comment.new", params, "photo");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-delete-photo-image-comment"],
  arguments: [{role: "object", label: "comment_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-delete-photo-image-comment &lt;comment_id&gt;",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", "Comment ID", params, "comment_id", true);
      odsExecute("photo.comment.delete", params, "photo");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-set-photo-options"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  modifiers: {"ahow_map": noun_type_integer, "show_timeline": noun_type_integer, "discussion_enable": noun_type_integer, "discussion_init": noun_type_integer, "albums_per_page": noun_type_integer},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Update instance options/parameteres",
  help: "Type ods-set-photo-options &lt;instance_id&gt; [show_map &lt;show_map&gt;] [show_timeline &lt;show_timeline&gt;] [discussion_enable &lt;discussion_enable&gt;] [discussion_init &lt;discussion_init&gt;] [albums_per_page &lt;albums_per_page&gt;]",
  execute: function (args) {
    try {
      var params = {};
      addParameter(args, "object", null, params, "inst_id", true);
      addParameter(args, "show_map", null, params, "show_map");
      addParameter(args, "show_timeline", null, params, "show_timeline");
      addParameter(args, "discussion_enable", null, params, "discussion_enable");
      addParameter(args, "discussion_init", null, params, "discussion_init");
      addParameter(args, "albums_per_page", null, params, "albums_per_page");
      odsExecute("photo.options.set", params, "photo");
    } catch (ex) {
      odsDisplayMessage(ex);
    }
  }
});

CmdUtils.CreateCommand({
  names: ["ods-get-photo-options"],
  arguments: [{role: "object", label: "instance_id", nountype: noun_type_id}],
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: {name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Show instance options/parameteres",
  help: "Type ods-get-photo-options &lt;instance_id&gt;",
  preview: function (previewBlock, args) {
    try {
      var params = {};
      addParameter(args, "object", "Instance ID", params, "inst_id", true);
      odsPreview(previewBlock, this, "photo.options.get", params, "photo");
    } catch (ex) {
    }
  }
});
