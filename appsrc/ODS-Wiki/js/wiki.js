function showTab(tab, tabs)
{
  var divNo = $('tabNo');
  if (divNo.value != tab)
    checkPageLeave (document.forms['common_setting'], tab);

  for (var i = 1; i <= tabs; i++)
  {
    var div = document.getElementById(i);
    if (div != null)
    {
      var divTab = document.getElementById('tab_'+i);
      if (i == tab)
      {
        divNo.value = tab;
        div.style.visibility = 'visible';
        div.style.display = 'block';
        if (divTab != null)
        {
          divTab.className = "tab activeTab";
          divTab.blur();
        }
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
  if (divNo != null)
  {
    var divTab = document.getElementById('tab_'+divNo.value);
    if (divTab != null)
      tab = divNo.value;
  }
  showTab(tab, tabs);
}

function deliciousToggle(obj)
{
  if (obj.checked)
  {
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

function webmailToggle(obj)
{
  if (obj.checked)
  {
    OAT.Dom.show("webmail1");
  } else {
    OAT.Dom.hide("webmail1");
  }
}

var sflag = false;

function checkPageLeave (form, tab)
{
  var dirty = false;
  var ret = true;
  var btn = 'save'+ $v('tabNo');
  var i;

  if (sflag == true || btn == null || btn == '' || form.__submit_func.value != '' || form.__event_initiator.value != '')
    return true;
  if (!(form.elements[btn]))
    return true;
  if (form.elements[btn].disabled)
    return true;

  for (i = 0; i < form.elements.length; i++)
  {
    if (form.elements[i] != null)
    {
      var ctrl = form.elements[i];
      if (OAT.Dom.isClass(ctrl, btn))
      {
        if (ctrl.type.indexOf ('select') != -1)
        {
          var j, selections = 0;
      	  for (j = 0; j < ctrl.length; j ++)
     	    {
            var opt = ctrl.options[j];
    	      if (opt.defaultSelected == true)
    	      {
      		    selections ++;
      		  }
            if (opt.defaultSelected != opt.selected)
            {
              dirty = true;
            }
          }
      	  if (selections == 0 && ctrl.selectedIndex == 0)
      	  {
      	    dirty = false;
      	  }
      	  if (dirty == true)
      	  {
      	    break;
      	  }
        }
        else if ((ctrl.type.indexOf ('text') != -1 || ctrl.type == 'password') && ctrl.defaultValue != ctrl.value)
        {
          dirty = true;
         	break;
        }
        else if ((ctrl.type == 'checkbox' || ctrl.type == 'radio') && ctrl.defaultChecked != ctrl.checked)
        {
          dirty = true;
          break;
        }
      }
    }
  }

  if (dirty == true)
  {
    ret = confirm ('You are about to leave the page, but there is changed data which is not saved.\r\nDo you wish to save changes ?');
    if (ret == true)
    {
      if (tab)
        $('tabNo').value = tab;
      form.__submit_func.value = '__submit__';
      form.__submit_func.name = btn;
      form.submit ();
    } else {
      for (i = 0; i < form.elements.length; i++)
      {
        if (form.elements[i] != null)
        {
          var ctrl = form.elements[i];
          if (OAT.Dom.isClass(ctrl, btn))
          {
            if (ctrl.type.indexOf ('select') != -1)
            {
              var j, selections = 0;
          	  for (j = 0; j < ctrl.length; j ++)
         	    {
                var opt = ctrl.options[j];
                opt.selected != opt.defaultSelected;
                ctrl.selectedIndex = j;
              }
            }
            else if ((ctrl.type.indexOf ('text') != -1 || ctrl.type == 'password'))
            {
              ctrl.value = ctrl.defaultValue;
            }
            else if ((ctrl.type == 'checkbox' || ctrl.type == 'radio'))
            {
              ctrl.checked = ctrl.defaultChecked;
            }
          }
        }
      }
    }
  }
  return ret;
}
