
function fctVadConfigVspx_loadHndlr(event)
{
  document.getElementById('form1').addEventListener('submit', validateForm);
}

function validateForm(v)
{
  var errMsg = null;
  var timeoutMin = document.getElementById('timeoutMin').value.trim();
  var timeoutMax = document.getElementById('timeoutMax').value.trim();

  if (!timeoutMin || !timeoutMax)
    errMsg = "Minimum/maximum timeout cannot be empty";
  else if (!/^[0-9]+$/.test(timeoutMin) || !/^[0-9]+$/.test(timeoutMax))
    errMsg = "Minimum/maximum timeout must be a positive integer";

  if (errMsg)
  {
    alert(errMsg);
    v.preventDefault();
    return false;
  }

  timeoutMin = parseInt(timeoutMin);
  timeoutMax = parseInt(timeoutMax);
  if (isNaN(timeoutMin) || isNaN(timeoutMax))
    errMsg = 'Minimum/maximum timeout is not an integer';
  else if (timeoutMin < 1) 
    errMsg = "Minimum timeout must be >= 1";
  else if (timeoutMax < 1000)
    errMsg = "Maximum timeout must be >= 1000";
  else if (timeoutMin >= timeoutMax)
    errMsg = "Minimum timeout must be < maximum timeout";

  if (errMsg)
  {
    alert(errMsg);
    v.preventDefault();
    return false;
  }

  return true;
}

window.addEventListener("load", fctVadConfigVspx_loadHndlr, false);
