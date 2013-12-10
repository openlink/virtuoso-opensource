function fbAsyncInit() {
  var fbInitiated = false;
  FB.init({
    appId  : regData.facebookApiID,
    status : true, // check login status
    cookie : true, // enable cookies to allow the server to access the session
    xfbml  : true, // parse XFBML
    oauth  : true,
    authResponse: true
  });

  var fbStatusChange = function(response) {
    fbInitiated = true;
    fbShowTabs();
    if (response.status === 'connected') {
      fbShowData();
    } else if (response.status === 'not_authorized') {
      fbShowData();
    } else {
      fbHideData();
    }
  }

  // run once with current status and whenever the status changes
  FB.getLoginStatus(fbStatusChange, true);
  if (!fbInitiated) {
    fbHideTabs();
    fbHideData();
  }

  FB.Event.subscribe('auth.statusChange', fbStatusChange);
};

function fbShowTabs() {
  if (regData.loginFacebookEnable)
    OAT.Dom.show("lf_tab_2");

  if (regData.facebookEnable)
    OAT.Dom.show("rf_tab_2");
}

function fbHideTabs() {
  OAT.Dom.hide("lf_tab_2");
  OAT.Dom.hide("rf_tab_2");
}

function fbShowData() {
  fbHideData();
  var x = function(response) {
    facebookData = response;
    var lfLabel = $('lf_facebookData');
    var rfLabel = $('rf_facebookData');
    if (lfLabel || rfLabel) {
      if (lfLabel) {
        lfLabel.innerHTML = '<img src="https://graph.facebook.com/' + response.id + '/picture" style="margin-right:5px"/>' + response.name;
        if (lfTab.selectedIndex == 2)
          $('lf_login').disabled = false;
      }
      if (rfLabel) {
        rfLabel.innerHTML = '<img src="https://graph.facebook.com/' + response.id + '/picture" style="margin-right:5px"/>' + response.name;
        if (rfTab.selectedIndex == 2)
          $('rf_signup').disabled = false;

        var tbl = $('rf_table_2');
        addProfileRowInput(tbl, 'Login Name', 'rf_uid_2', {value: (response.name).replace(' ', ''), width: '150px'});
        addProfileRowInput(tbl, 'E-Mail', 'rf_email_2', {value: response.email, width: '300px'});
        rfCheckUpdate(2);
      }
    }
  }
  FB.api('/me', x);
}

function fbHideData() {
  facebookData = null;
  var label = $('lf_facebookData');
  if (label) {
    label.innerHTML = '';
    if (lfTab.selectedIndex == 2)
      $('lf_login').disabled = true;
  }
  var label = $('rf_facebookData');
  if (label) {
    label.innerHTML = '';
    if (rfTab.selectedIndex == 2)
      $('rf_signup').disabled = true;

    OAT.Dom.unlink('tr_rf_uid_2');
    OAT.Dom.unlink('tr_rf_email_2');
  }
}

