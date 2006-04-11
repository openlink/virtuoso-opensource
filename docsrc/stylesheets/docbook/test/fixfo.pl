# -*- Perl -*-

$file = shift @ARGV;

open (F, $file);
read (F, $_, -s $file);
close (F);

open (F, ">$file");

print F "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
print F "<!DOCTYPE fo:root PUBLIC \"-//Norman Walsh//DTD XSL FO V0.1//EN\"\n";
print F "                  \"../dtds/fo/fo.dtd\">\n";

print F $_;

close (F);

