Please note that the files in this directory should have
disabled CVS keyword expansion.

In other words they should have sticky -ko option that
prevents the substitution of strings like $Id $ or
$Date $ when the file is checked out.

This is because these files come from other CVS-es and they should be
saved in the server exactly as they were there.
Versions in that files refers to original CVS-es, not to our own.
