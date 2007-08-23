function showTab(tab, tabs)
{
  for (var i = 1; i <= tabs; i++) {
    var div = document.getElementById(i);
    if (div != null) {
      var divTab = document.getElementById('tab_'+i);
      if (i == tab) {
        var divNo = document.getElementById('tabNo');
        divNo.value = tab;
        div.style.visibility = 'visible';
        div.style.display = 'block';
        if (divTab != null) {
          divTab.className = "tab activeTab";
          divTab.blur();
        };
      } else {
        div.style.visibility = 'hidden';
        div.style.display = 'none';
        if (divTab != null)
          divTab.className = "tab";
      }
    }
  }
}

function initTab(tabs, defaultNo)
{
  var divNo = document.getElementById('tabNo');
  var tab = defaultNo;
  if (divNo != null) {
    var divTab = document.getElementById('tab_'+divNo.value);
    if (divTab != null)
      tab = divNo.value;
  }
  showTab(tab, tabs);
}

function deliciousToggle(obj) {
  if (obj.checked) {
    OAT.Dom.show("delicious1");
    OAT.Dom.show("delicious2");
    OAT.Dom.show("delicious3");
    OAT.Dom.show("delicious4");
  } else {
    OAT.Dom.hide("delicious1");
    OAT.Dom.hide("delicious2");
    OAT.Dom.hide("delicious3");
    OAT.Dom.hide("delicious4");
  }
}

function webmailToggle(obj) {
  if (obj.checked) {
    OAT.Dom.show("webmail1");
  } else {
    OAT.Dom.hide("webmail1");
  }
}