<?php
  $PID=$_GET['id'];
  $action=$_GET['sa'];
  $URL1=$_GET['url'];
  $MT=$_GET['mt'];

  $handle=odbc_connect ("LocalVirtuosoTutorialRQS3", "demo", "demo");

  if(!$handle)
  {
    print "<p>Failure to connect to DSN [$DSN]: <br />";
    odbc_errormsg();
  }
  else
  {
    if ($action=='init')
    {
      $resultset=odbc_exec ($handle, "DB.DBA.rq_s_3_workerasync('$PID','$URL1','$MT')");
      echo odbc_result ($resultset, 1);
    }
    else if ($action=='state')
    {
      $resultset=odbc_exec ($handle, 'commit work');
      $resultset=odbc_exec ($handle, "DB.DBA.rq_s_3_workeriso()");

      $query="select Demo..rq_s_3_workerlog ('$PID')";
      $resultset=odbc_exec ($handle, "$query");
      echo odbc_result ($resultset, 1);
    };
    odbc_close($handle);
  };
?>
