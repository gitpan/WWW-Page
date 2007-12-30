package WWW::Page;

use vars qw ($VERSION);
$VERSION = '1.0';

use XML::LibXML;
use XML::LibXSLT;

sub new {
	my $class = shift;
	my $args = shift;

	my $this = {
		charset			=> $args->{'charset'} || 'UTF-8',
		content_type	=> $args->{'content-type'} || 'text/html',
		content         => '',
		source          => $args->{'source'} || $ENV{'PATH_TRANSLATED'},
		script_filename => $args->{'script-filename'} || $ENV{'SCRIPT_FILENAME'},
		document_root   => $args->{'document-root'} || $ENV{'DOCUMENT_ROOT'},
		xslt_root       => $args->{'xslt-root'} || "$ENV{'DOCUMENT_ROOT'}/xsl",
		request_uri     => $args->{'request-uri'} || $ENV{'REQUEST_URI'},
		xml             => undef,
		xsl             => undef,
		code            => undef,
	};

	$this->{'header'} = {'Content-Type' => "$this->{'content_type'}; charset=$this->{'charset'}"},

	bless $this, $class;

	$this->{'param'} = _read_params();
	$this->parse();

	return $this;
}

sub as_string {
    my $this = shift;
    
    return $this->header() . $this->content();
}

sub parse {
	my $this = shift;

	$this->readSource();
	$this->appendInfo();

	$this->importCode();
	$this->executeCode();

	$this->readXSL();
	$this->transformXML();
}

sub readSource {
	my $this = shift;
	
	my $xmlParser = new XML::LibXML();
	$this->{'xml'} = $xmlParser->parse_file($this->{'source'});
}

sub appendInfo {
	my $this = shift;

	my @manifest = $this->{'xml'}->findnodes('/page/manifest');
	if (@manifest) {
		my $manifest = $manifest[0];
		$manifest->appendTextChild('uri', $this->{'request_uri'});
		$manifest->appendTextChild('year', 1900 + (localtime time)[5]);
	}
}

sub importCode {
	my $this = shift;

	my ($base) = $this->{'script_filename'} =~ m{^(.*)/[^/]+$};
    unshift @INC, $base;

	my @imports = $this->{'xml'}->findnodes('/page/@import');
	if (@imports) {
		my $module = $imports[0]->firstChild->data;      
		my $pm = $module;
        $pm =~ s{::}{/}g;
        $pm .= '.pm';
        require "$base/$pm";
        $this->{'code'} = $module->import();
	}
}

sub readXSL {
	my $this = shift;

	return if defined $this->param('viewxml');

	my $base = $this->{'xslt_root'};
	my @transforms = $this->{xml}->findnodes('/page/@transform');
	if (@transforms) {
		my $xslFile = $transforms[0]->firstChild->data;
		my $xslParser = new XML::LibXSLT();
		$this->{'xsl'} = $xslParser->parse_stylesheet_file("$base/$xslFile");
	}
	else {
		$this->{'header'}->{'Content-Type'} = 'text/xml';
	}
}

sub executeCode {
	my $this = shift;
    
    my $context = new XML::LibXML::XPathContext;
    $context->registerNs('page', 'urn:www-page');

	my @codeNodes = $context->findnodes('/page//page:*', $this->{'xml'});
	foreach my $codeNode (@codeNodes) {
		my $nodeName = $codeNode->nodeName();
        $nodeName =~ s/^.*://;
        my $function = $nodeName;
        $function =~ s/-(\w)?/defined $1 ? uc $1 : '_'/ge;
        
		my @attributes = $codeNode->getAttributes();
		my %arguments = ();        
		foreach my $attribute (@attributes){
            $arguments{$attribute->nodeName()} = $attribute->value();
		}
        
		my $newNode = new XML::LibXML::Element($nodeName);
		$newNode = $this->{'code'}->$function($this, $newNode, \%arguments);
		$codeNode->replaceNode ($newNode);
	}
}

sub transformXML {
	my $this = shift;

	$this->{'content'} = ($this->{'xsl'} && !defined $this->param('viewxml'))
		?
		$this->{'xsl'}->output_string($this->{'xsl'}->transform($this->{'xml'}))
		:
		$this->{'xml'}->toString();
}

sub header {
	my $this = shift;

	my $ret = '';
	foreach my $key (keys %{$this->{'header'}}){
		my $value = $this->{'header'}->{$key};
		$ret .= "$key: $value\n";
	}

	return "$ret\n";
}

sub content {
	my $this = shift;

	return $this->{'content'};
}

sub param {
	my $this = shift;
	my $name = shift;
	
	return $this->{'param'}->{$name};
}

sub _read_params {
	my $params = '';

	my %param = ();
	if ($ENV{CONTENT_TYPE} =~ m/multipart\/form-data/){
		# parse_multipart();
		# to get uploaded files you should use either some kind of CGI module or future version of WWW::Page :-)
	}
	else {
		my $buf;
		my $BUFLEN = 4096;
		while (my $bytes = sysread STDIN, $buf, $BUFLEN) {
			if ($bytes == $BUFLEN) {
				$params .= $buf;
			}
			else {
				$params .= substr $buf, 0, $bytes;
			}
		}
	}

	$params .= '&' . $ENV{QUERY_STRING};
	foreach (split /&/, $params) {
	   my ($name, $value) = (m/(.*)=(.*)/);
	   if ($name =~ /\S/) {
		   $param{$name} = _urldecode($value);
	   }
	}

	return \%param;
}

sub _urldecode {
	my $val = shift;

	# Known limitation: currently does not support Unicode query strings. Use future versions.

	$val =~ s/\+/ /g;
	$val =~ s/%([0-9A-H]{2})/pack('C',hex($1))/ge;
	
	return $val;
}

1;

=head1 NAME

WWW::Page - XSLT-based and XML-configured web-site engine.

=head1 SYNOPSIS

Main CGI script

    use WWW::Page;
    use encoding 'utf-8';

    my $page = new WWW::Page ({
        'xslt-root'       => "$ENV{'DOCUMENT_ROOT'}/../data/xsl",
    });

    print $page->as_string();

XML-configuration of a page

    <?xml version="1.0" encoding="UTF-8"?>
    <page
        import="Import::Client"
        transform="view.xsl"
        xmlns:page="urn:www-page">
    
        <manifest>
            <title>WWW::Page Web-Site</title>
            <locale>en-gb</locale>
            <page:keyword-list/>
        </manifest>
    
        <content>
            <page:month-calendar/>
        </content>
    </page>

Parts of imported controller script
    
    package Import::Client;
    use utf8;
    use XML::LibXML;

    sub keywordList
    {
        my $this = shift;
        my $page = shift;
        my $node = shift;
        my $args = shift;
    
        my $sth = $dbh->prepare ("select keyword, uri from keywords order by keyword");
        $sth->execute();
        while (my ($keyword, $uri) = $sth->fetchrow_array())
        {
            my $item = $page->{'xml'}->createElement ('item');
            $item->appendText ($keyword);
            $item->setAttribute ('uri', $uri);
            $node->appendChild ($item);
        }
    
        return $node;
    }
    
=head1 ABSTRACT

WWW::Page makes web-site built on XSLT technology easy to start.

=head1 DESCRIPTION

This distributive contains 'example' folder with a copy of a web-site built on WWW::Page.

=head1 EXAMPLE

Example of how to use WWW::Page module for creating XSLT-based web-site.

This example is a demonstration of how to create a blog with tagging, search and month-calendar.

Enroll your http://localhost/ (or whatever) and ensure the following:

1. document root is beeing pointed to example/www;
2. allow .htaccess for example/www;
3. point script aliases to example/cgi;
4. create database 'blog' and update its credentials at example/cgi/Import/Datasource.pm.

Database scheme is in example/data/scheme.sql, sample data are in example/data/example-data.sql.

Use http://localhost/ to view the web-site, and http://localhost/adm/ to add or edit messages.

Future versions of WWW::Page will have more detailed description.

=head2 Known limitations

GET and POST parser cannot accept uploaded files and Unicode-encoded strings.

Example does allow only one editor user; only latin symbols may be in keyword list.

=head1 AUTHOR

Andrew Shitov, <andy@shitov.ru>

=head1 COPYRIGHT AND LICENCE

WWW::Page module is a free software.
You may resistribute and (or) modify it under the same terms as Perl.

=cut
