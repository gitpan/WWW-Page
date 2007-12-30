#!/usr/bin/perl

use WWW::Page;
use encoding 'utf-8';

my $page = new WWW::Page ({
	'xslt-root'       => "$ENV{'DOCUMENT_ROOT'}/../data/xsl",
});

print $page->as_string();
