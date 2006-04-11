# -*- Perl -*-
# This is a chunk.pl library file

package docbook;

use XML::DOM;

sub init {
    return 1;
}

sub applies {
    my $doc = shift;
    my $node = shift;
    my $parent = shift;

    return 0 if $node->getNodeType() != ELEMENT_NODE;
    return 0 if $node->getTagName() ne 'pre';
    return 0 if ($node->getAttribute('class') ne 'literallayout'
		 && $node->getAttribute('class') ne 'address');
    return 1;
}

sub apply {
    my $doc = shift;
    my $node = shift;
    my $parent = shift;

    # node is pre and class is either literallayout or address

    &fixup_content($doc, $node);

    my $div = $doc->createElement('div');
    $div->setAttribute('class', $node->getAttribute('class'));

    my $child = $node->getFirstChild();
    while ($child) {
	my $next = $child->getNextSibling();
	$node->removeChild($child);
	$div->appendChild($child);
	$child = $next;
    }

    $parent->insertBefore($div, $node);
    $parent->removeChild($node);
}

sub fixup_content {
    my $doc = shift;
    my $node = shift;
    my $child = $node->getFirstChild();

    while ($child) {
	my $next = $child->getNextSibling();

	if ($child->getNodeType() == ELEMENT_NODE) {
	    &fixup_content($doc, $child);
	} elsif ($child->getNodeType() == TEXT_NODE) {
	    my @lines = split(/\n/, $child->toString());

	    while (@lines) {
		local $_ = shift @lines;

		if (/^\s+/) {
		    my $spaces = $&;
		    $_ = $';

		    for (my $count = 0; $count < length($spaces); $count++) {
			my $nbsp = $doc->createEntityReference('nbsp');
			$node->insertBefore($nbsp, $child);
		    }
		}

		while (/^(\S+)(\s*)/) {
		    my $text = $1;
		    my $spaces = $2;
		    $_ = $';

		    # fixup the entity refs...
		    while ($text =~ /&(\S+);/) {
			if ($` ne '') {
			    my $textnode = $doc->createTextNode($`);
			    $node->insertBefore($textnode, $child);
			}

			my $ent = $doc->createEntityReference($1);
			$node->insertBefore($ent, $child);

			$text = $';
		    }

		    if ($text ne '') {
			my $textnode = $doc->createTextNode($text);
			$node->insertBefore($textnode, $child);
		    }

		    for (my $count = 0; $count < length($spaces); $count++) {
			my $nbsp = $doc->createEntityReference('nbsp');
			$node->insertBefore($nbsp, $child);
		    }
		}

		if (@lines) {
		    my $br = $doc->createElement('br');
		    $node->insertBefore($br, $child);
		    my $nl = $doc->createTextNode("\n");
		    $node->insertBefore($nl, $child);
		}
	    }

	    $node->removeChild($child);
	} else {
	    print "Unexpected node type: ", $child->getNodeType(), "\n";
	}

	$child = $next;
    }
}

'docbook';

