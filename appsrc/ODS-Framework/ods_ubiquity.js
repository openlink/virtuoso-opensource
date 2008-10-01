ODS = {
        setServer: function(serverUrl)
        {
          var serverName = 'ods_server';
          if (!Application.prefs.has(serverName))
          {
            Application.prefs.setValue(serverName, serverUrl);
          }
          else
          {
            var new_pref = Application.prefs.get(serverName);
            new_pref.value = serverUrl;
          }
        },

        getServer: function()
        {
          var serverName = 'ods_server';
          if (!Application.prefs.has(serverName))
          {
            return "http://myopenlink.net/";
          }
          else
          {
            return Application.prefs.get(serverName).value;
          }
        },

        getOAuthServer: function()
        {
          return ODS.getServer() + 'OAuth/';
        },

        setSid: function(app, sid)
        {
          var sidName = ODS.getSidName(app);
          if (!Application.prefs.has(sidName))
          {
            Application.prefs.setValue(sidName, sid);
          }
          else
          {
            var new_pref = Application.prefs.get(sidName);
            new_pref.value = sid;
          }
        },

        getSid: function(app)
        {
          return Application.prefs.get(ODS.getSidName(app)).value;
        },

        getSidName: function(app)
        {
          return "ODS_"+app+"_api_sid";
        },
      };

////////////////////////////////////
///// ods-controller //////////////
////////////////////////////////////

CmdUtils.CreateCommand({
  name: "ods-server",
  takes: {"server-url": noun_arb_text},
  homepage: "http://demo.openlinksw.com/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS server url",
  help: "Type ods-server http://myopenlink.net/",

  execute: function(serverUrl) {
    if (serverUrl.text.length < 1)
    {
      displayMessage("Please, enter your ODS server");
      return;
    }

    ODS.setServer(serverUrl.text);

    displayMessage("Your server url has been set to " + ODS.getServer());
  }
});

CmdUtils.CreateCommand({
  name: "ods-bookmark-get",
  takes: {"bookmark_id": noun_arb_text},
  homepage: "http://demo.openlinksw.com/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  help: "Type ods-bookmark <bookmark_id>",

  execute: function (bookmark_id) {
    var sid = ODS.getSid("bookmark");

    var consumer_key = jQuery.ajax({
      type: "GET",
      url: ODS.getOAuthServer() + "get_consumer_key",
      data: {"sid": sid},
      error: function(msg) {
          displayMessage("ODS Controller error - coomand not executed");
        },
      async: false
      }).responseText;

    var params = {
      meth: "GET",
      url: ODS.getServer() + "ods/api/bookmark.get",
      params: "bookmark_id="+encodeURIComponent(bookmark_id.text),
      consumer_key: consumer_key,
      sid: sid};

    var apiURL = jQuery.ajax({
      type: "GET",
      url: ODS.getOAuthServer() + "sign_request",
      data: params,
      error: function(msg) {
          displayMessage("ODS Controller error - coomand not executed");
        },
      async: false
      }).responseText;

    var res = jQuery.ajax({
      type: "GET",
      url: apiURL,
      async: false
      }).responseText;

    displayMessage(res);
    // CmdUtils.log('res: ' + res);
  }
});

CmdUtils.CreateCommand({
  name: "ods-bookmark-sid",
  takes: {"sid": noun_arb_text},
  homepage: "http://demo.openlinksw.com/ods/",
  icon: "http://www.openlinksw.com/favicon.ico",
  author: { name: "OpenLink Software", email: "ods@openlinksw.com"},
  license: "MPL",
  description: "Set your ODS bookmark sid. Get your sid at " + ODS.getOAuthServer() + "oauth_sid.vsp",
  help: "Type ods-bookmark-sid <sid>. Get your sid at " + ODS.getOAuthServer(),

  execute: function(sid) {
    if (sid.text.length < 1)
    {
      displayMessage("Please, enter your sid");
      return;
    }

    ODS.setSid("bookmark", sid.text);
    displayMessage("Your sid has been set.");
  }
});