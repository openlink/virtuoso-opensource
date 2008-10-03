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

////////////////////////////////////
///// ods-controller //////////////
////////////////////////////////////

CmdUtils.CreateCommand({
  name: "ods-host",
  takes: {"host-url": noun_arb_text},
  homepage: "http://myopenlink.net/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS server url",
  help: "Type ods-host http://myopenlink.net/ods",

  execute: function(hostUrl) {
    if (hostUrl.text.length < 1)
    {
      displayMessage("Please, enter your ODS host URL");
      return;
    }

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
  description: "Set your ODS server url",
  help: "Type ods-api-host http://myopenlink.net/OAuth",

  execute: function(hostUrl) {
    if (hostUrl.text.length < 1)
    {
      displayMessage("Please, enter your ODS OAuth host URL");
      return;
    }

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
  description: "Set your ODS API mode sid or OAuth authentication",
  help: "Type ods-set-mode <sid|oauth>",

  execute: function(mode) {
    if (mode.text.length < 1)
    {
      displayMessage("Please, enter your mode type - sid or OAuth authentication");
      return;
    }

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
  help: "Type ods-set-sid <sid value>",

  execute: function(sid) {
    if (sid.text.length < 1)
    {
      displayMessage("Please, enter your session ID");
      return;
    }

    ODS.setSid(sid.text);
    displayMessage("Your ODS session ID has been set to " + ODS.getSid());
  }
});

CmdUtils.CreateCommand({
  name: "ods-set-bookmark-oauth",
  takes: {"oauth": noun_arb_text},
  homepage: "http://demo.openlinksw.com/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS bookmark oauth. Get your oauth at " + ODS.getOAuthServer() + "/oauth_oauth.vsp",
  help: "Type ods-bookmark-oauth <oauth>. Get your oauth at " + ODS.getOAuthServer(),

  execute: function(oauth) {
    if (oauth.text.length < 1)
    {
      displayMessage("Please, enter your bookmark instance OAuth");
      return;
    }

    ODS.setOAuth("bookmark", oauth.text);
    displayMessage("Your your bookmark instance OAuth has been set.");
  }
});

CmdUtils.CreateCommand({
  name: "ods-get-bookmark-by-id",
  takes: {"bookmark_id": noun_arb_text},
  homepage: "http://demo.openlinksw.com/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-get-bookmark-by-id <bookmark_id>",

  preview: function (previewBlock, bookmark_id) {
    var res = odsExecute ("bookmark.get", {bookmark_id: bookmark_id.text}, "bookmark");
    CmdUtils.log('res: ' + res);
    previewBlock.innerHTML = "<pre>" + xml_encode(res) + "</pre>";
  },

  execute: function (bookmark_id) {
    odsExecute ("bookmark.get", {bookmark_id: bookmark_id.text}, "bookmark", "execute")
  }
});

function odsExecute (cmdName, cmdParams, cmdApplication, cmdMode)
{
  var res = '';

  if (ODS.getMode() == 'oauth')
  {
    var oauth = ODS.getOAuth(cmdApplication);

    var consumer_key = jQuery.ajax({
      type: "GET",
      url: ODS.getOAuthServer() + "/get_consumer_key",
      data: {"oauth": oauth},
      error: function(msg) {
          if (cmdMode)
          displayMessage("ODS Controller error - coomand not executed");
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
      oauth: oauth};

    var apiURL = jQuery.ajax({
      type: "GET",
      url: ODS.getOAuthServer() + "/sign_request",
      data: params,
      error: function(msg) {
          if (cmdMode)
          displayMessage("ODS Controller error - coomand not executed");
        },
      async: false
      }).responseText;

    res = jQuery.ajax({
      type: "GET",
      url: apiURL,
      async: false
      }).responseText;
  }
  if (ODS.getMode() == 'sid')
  {
    cmdParams.sid = ODS.getSid();
    cmdParams.realm = "wa";

    var res = jQuery.ajax({
      type: "GET",
      url: ODS.getServer() + "/api/" + cmdName,
      data: cmdParams,
      error: function(msg) {
          if (cmdMode)
            displayMessage("ODS Controller error - coomand not executed");
        },
      async: false
      }).responseText;
  }
    // CmdUtils.log('res: ' + res);
  if (cmdMode)
    displayMessage(res);
  return res;
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
