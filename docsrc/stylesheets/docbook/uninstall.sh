#!/bin/bash
mydir=$(cd -P $(dirname $0) && pwd -P)
$mydir/install.sh \
  --uninstall \
  --catalogManager=/etc/xml/resolver/CatalogManager.properties \
  --dotEmacs='' \
  $@
