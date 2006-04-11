<?php

function sanep ($str) {

  if(ereg("^select", strtolower($str)))
    $doingAselect=True;

  if(ereg("^(create|delete|drop)", strtolower($str)))
    $doingWrite=True;

  if(ereg("\S+\.(\S*)\.\S+", strtolower($str)))
    $exceedingContext=True;

  if(!$doingAselect && !$doingWrite && !ereg("^update ", strtolower($str)))
    $doingUnknown=True;

  if(ereg("^select .*from.*,.*,", strtolower($str)))
    $tooManyTables=True;

  return ($exceedingContext || $doingWrite || 
	  $tooManyTables || $doingUnknown) ? False : True;
}


?>
