#!/bin/bash
mydir=$(cd -P $(dirname $0) && pwd -P)
$mydir/install.sh --test
