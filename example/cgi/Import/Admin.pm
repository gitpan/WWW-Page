package Import::Admin;

use utf8;

use XML::LibXML;
use Import::Datasource;

my $MAX = 50;

sub import
{
	my $class = shift;
	
	my $this = {};
	
	return bless $this, $class;
}

sub addNew
{
	my $this = shift;	
	my $page = shift;
	my $node = shift;
	my $args = shift;

	if ($page->param ('submit') && $page->param ('title') && $page->param ('ContentField'))
	{
		my $message_id = $this->addMessage ($page);
		$this->tieKeywords ($page, $message_id);
		
		print "Location: http://$ENV{'SERVER_NAME'}/adm/preview/$message_id/\n\n";
		exit;
	}

	return $node;
}

sub keywordList
{
	my $this = shift;
	my $page = shift;
	my $node = shift;
	my $args = shift;
	my $dbh = $Import::Datasource::handler;

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

sub editMessage
{
	my $this = shift;
	my $page = shift;
	my $node = shift;
	my $args = shift;
	my $dbh = $Import::Datasource::handler;

	my ($message_id) = $page->param ('message_id') =~ /(\d+)/;

	if ($message_id)
	{
		if ($page->param ('submit') && $page->param ('title') && $page->param ('ContentField'))
		{
			$this->updateMessage ($page, $message_id);
			$this->tieKeywords ($page, $message_id);
		}
		
		my $sth = $dbh->prepare (
				"select
					uri, 
					title, 
					content, 
					is_published, 
					site_id, 
					dayofmonth(date), 
					month(date), 
					year(date), 
					hour(date), 
					minute(date), 
					name, 
					dayofmonth(modified), 
					month(modified), 
					year(modified), 
					hour(modified), 
					minute(modified)
				from 
					message 
				left join
					editor 
				on	
					message.editor_id = editor.id
				where
					message.id = $message_id");
		$sth->execute();
		my ($uri, $title, $content, $is_published, $site_id, $day, $month, $year, $hour, $minute, $editor_name, $modified_day, $modified_month, $modified_year, $modified_hour, $modified_minute) = $sth->fetchrow_array();
		$sth->finish();
		
		my $titleNode = $page->{'xml'}->createElement ('title');
		$titleNode->appendText ($title);
		$titleNode->setAttribute ('uri', $uri); 
		$titleNode->setAttribute ('site_id', $site_id); 
		$titleNode->setAttribute ('is_published', $is_published);
		$titleNode->setAttribute ('day', $day);
		$titleNode->setAttribute ('month', $month);
		$titleNode->setAttribute ('year', $year);
		$titleNode->setAttribute ('hour', $hour);
		$titleNode->setAttribute ('minute', $minute);
		$node->appendChild ($titleNode);

		my $modifiedNode = $page->{'xml'}->createElement ('modified');
		$modifiedNode->setAttribute ('day', $modified_day);
		$modifiedNode->setAttribute ('month', $modified_month);
		$modifiedNode->setAttribute ('year', $modified_year);
		$modifiedNode->setAttribute ('hour', sprintf ("%02i", $modified_hour));
		$modifiedNode->setAttribute ('minute', sprintf ("%02i", $modified_minute));
		$modifiedNode->appendText ($editor_name);
		$node->appendChild ($modifiedNode);

		my $contentNode = $page->{'xml'}->createElement ('content');
		$contentNode->appendText ($content);
		$node->appendChild ($contentNode);


		my $keywords = $page->{'xml'}->createElement ('keywords');
		$node->appendChild ($keywords);

		$sth = $dbh->prepare ("select keyword, uri from keywords join keyword2message on keywords.id = keyword2message.keyword_id where message_id = $message_id order by keyword2message.id");
		$sth->execute();
		while (my ($keyword, $keyword_uri) = $sth->fetchrow_array())
		{
			my $item = $page->{'xml'}->createElement ('item');
			$item->appendText ($keyword);
			$item->setAttribute ('uri', $keyword_uri);
			$keywords->appendChild ($item)
		}
		$sth->finish();
	}

	return $node;
}

sub messageList
{
	my $this = shift;
	my $page = shift;
	my $node = shift;
	my $args = shift;
	my $dbh = $Import::Datasource::handler;

	my $sth = $dbh->prepare ("select id, dayofmonth(date), month(date), year(date), hour(date), minute(date), date <= now(), title, is_published, site_id from message order by date desc, id desc");
	$sth->execute();
	while (my ($id, $day, $month, $year, $hour, $minute, $is_visible, $title, $is_published, $site_id) = $sth->fetchrow_array())
	{
		my $item = $page->{'xml'}->createElement ('item');
		$item->setAttribute ('id', $id);
		$item->setAttribute ('day', $day);
		$item->setAttribute ('month', $month);
		$item->setAttribute ('year', $year);
		$item->setAttribute ('hour', $hour);
		$item->setAttribute ('minute', $minute);
		$item->setAttribute ('is_visible', $is_visible);
		$item->setAttribute ('is_published', $is_published);
		$item->setAttribute ('site_id', $site_id);
		$item->appendText ($title);
		$node->appendChild ($item);
	}
	$sth->finish();

	return $node;
}

sub addMessage
{
	my $this = shift;
	my $page = shift;
	my $dbh = $Import::Datasource::handler;

	my $uri = $page->param ('uri');
	$uri = random_uri() unless $uri;

	my ($site_id) = $page->param ('site_id') =~ m{(\d)};
	$site_id = 1 unless $site_id;

	my $editorID = getEditorID();

	$dbh->do (
			"insert into message (title, content, uri, is_published, date, site_id, editor_id, modified) values (" .
			$dbh->quote ($page->param ('title')) . ", " .
			$dbh->quote ($page->param ('ContentField')). ", " .
			$dbh->quote ($uri). ", " .
			"0, now(), $site_id, " . 
			"$editorID, now())"
	);

	my $sth = $dbh->prepare ("select last_insert_id() from message");
	$sth->execute();
	my ($message_id) = $sth->fetchrow_array();
	$sth->finish();

	updateDictionary ($message_id, $page->param ('title') . ' ' . $page->param ('ContentField'));

	return $message_id;
}

sub updateMessage
{
	my $this = shift;
	my $page = shift;
	my $message_id = shift;
	my $dbh = $Import::Datasource::handler;

	my $is_published = defined $page->param ('is_published') ? 1 : 0;

	my $uri = $page->param ('uri');
	$uri = random_uri() unless $uri;

	my ($site_id) = $page->param ('site_id') =~ m{(\d)};
	$site_id = 1 unless $site_id;

	my ($day) = $page->param ('day') =~ m{(\d+)};
	my ($month) = $page->param ('month') =~ m{(\d+)};
	my ($year) = $page->param ('year') =~ m{(\d+)};
	my ($hour) = $page->param ('hour') =~ m{(\d+)};
	my ($minute) = $page->param ('minute') =~ m{(\d+)};

	my $editorID = getEditorID();

	$dbh->do (
			"update message " .
			"set title = " . $dbh->quote ($page->param ('title')) . ", ".
			"content = " . $dbh->quote ($page->param ('ContentField')) . ", ".
			"uri = " . $dbh->quote ($uri) . ", ".
			"is_published = $is_published, ".
			"site_id = $site_id, ".
			"date = '${year}-${month}-${day} ${hour}:${minute}', ".
			"editor_id = $editorID, ".
			"modified = now() ".
			"where id = $message_id");
		
	updateDictionary ($message_id, $page->param ('title') . ' ' . $page->param ('ContentField'));

	return $message_id;
}

sub tieKeywords
{
	my $this = shift;
	my $page = shift;
	my $message_id = shift;
	my $dbh = $Import::Datasource::handler;

	my @keywords = split /\s*,\s*/, $page->param ('keywords');
	return unless @keywords;

	$dbh->do ("delete from keyword2message where message_id = $message_id");
	foreach my $keyword (@keywords)
	{
		$keyword =~ s{^\s+}{};
		$keyword =~ s{\s+$}{};
		$keyword =~ s{"}{\\\"}g;   #"

		my $sth = $dbh->prepare ("select count(*) from keywords where uri=\"$keyword\"");
		$sth->execute();
		my ($count) = $sth->fetchrow_array();
		$sth->finish();

		unless ($count)
		{
			my $uri = $keyword;
			$dbh->do ("insert into keywords (keyword, uri) values (\"$keyword\", \"$uri\")");
		}

		$sth = $dbh->prepare ("select id from keywords where uri=\"$keyword\"");
		$sth->execute();
		my ($keyword_id) = $sth->fetchrow_array();
		$sth->finish();	

		$dbh->do ("insert into keyword2message (keyword_id, message_id) values ($keyword_id, $message_id)");
	}
}

sub editorList
{
	my $this = shift;
	my $page = shift;
	my $node = shift;
	my $args = shift;
	my $dbh = $Import::Datasource::handler;

	my $sth = $dbh->prepare ("select id, login, email, name, active from editor");
	$sth->execute();
	while (my ($id, $login, $email, $name, $active) = $sth->fetchrow_array())
	{
		my $item = $page->{'xml'}->createElement ('item');
		$item->setAttribute ('id', $id);
		$item->setAttribute ('login', $login);
		$item->setAttribute ('email', $email);
		$item->setAttribute ('active', $active);
		$item->appendText ($name);
		$node->appendChild ($item);
	}
	$sth->finish();

	return $node;
}

sub editorListUpdate
{
	my $this = shift;
	my $page = shift;
	my $node = shift;
	my $args = shift;
	my $dbh = $Import::Datasource::handler;

	return $node if ($ENV{'REDIRECT_REMOTE_USER'} ne 'main');

	if ($page->param ('submit'))
	{
		$this->updateEditor (0, $page) if $page->param ("login0") && testEditor (0, $page, $node);
		for (my $c = 2; ; $c++)
		{
			if ($page->param ("login$c") && $page->param ("email$c"))
			{
				$this->updateEditor ($c, $page) if $this->testEditor ($c, $page, $node);
			}
			else
			{
				last;
			}
		}
	}

	$this->clearPasswordFile();

	return $node;
}

sub testEditor
{
	my $this = shift;
	my $id = shift;
	my $page = shift;
	my $node = shift;
	my $dbh = $Import::Datasource::handler;

	my $sth = $dbh->prepare ("select count(*) from editor where id != 1 and id != $id and login = " . $dbh->quote ($page->param ("login$id")));
	$sth->execute();
	my ($count) = $sth->fetchrow_array();
	$sth->finish();

	if ($count)
	{
		my $error = $page->{'xml'}->createElement ('error');
		$error->appendText ("Duplicate login $id " . $page->param ("login$id"));
		$node->appendChild ($error);
	}

	return !$count;
}

sub updateEditor
{
	my $this = shift;
	my $id = shift;
	my $page = shift;

	my $dbh = $Import::Datasource::handler;

	my $sth = $dbh->prepare ("select count(*) from editor where id = $id");
	$sth->execute();
	my ($count) = $sth->fetchrow_array();
	$sth->finish();

	my $login = $page->param ("login$id");
	$login =~ s{[^a-z0-9.@_-]+}{}gi;

	my $active = $page->param ("active$id") ? 1 : 0;
	unless ($count)
	{			
		$dbh->do ("insert into editor (login, email, name, active) values (" .
			$dbh->quote ($login) . ", " .
			$dbh->quote ($page->param ("email$id")) . ", " .
			$dbh->quote ($page->param ("name$id")) . ", " .
			$active . ")");
		generatePassword ($login, $page->param ("email$id"));
	}
	else
	{
		# user list assumed to be short

		my $sth = $dbh->prepare ("select login, email from editor where id = $id");
		$sth->execute();
		my ($oldlogin, $oldemail) = $sth->fetchrow_array(); 
		$sth->finish();
		if ($oldlogin ne $page->param ("login$id") || $oldemail ne $page->param ("email$id"))
		{
			generatePassword ($login, $page->param ("email$id"));
		}

		$dbh->do ("update editor set " .
			"login = " . $dbh->quote ($login) . ", " .
			"email = " . $dbh->quote ($page->param ("email$id")) . ", " .
			"name = " . $dbh->quote ($page->param ("name$id")) . ", " .
			"active = $active where id = $id");
	}
}

sub getEditorID
{
	return 1;
}

sub random_uri
{
	my $length = shift || 20;

	my @chars = ('a'..'z', '0'..'9');
	my $uri = join ('', @chars[map{rand @chars}(1..$length)]);
	return $uri;
}

sub updateDictionary
{
	my ($message_id, $content) = @_;
	
	my $dbh = $Import::Datasource::handler;

	my $sth = $dbh->prepare ("select word_id from word2message where message_id = $message_id");
	$sth->execute();
	my @word_id = ();
	while (my ($word_id) = $sth->fetchrow_array())
	{
		push @word_id, $word_id;
	}
	$sth->finish();

	$dbh->do ("update word set frequency = frequency - 1 where id in (" . (join ', ', @word_id) . ")")
		if scalar @word_id;
	$dbh->do ("delete from word2message where message_id = $message_id");
	$dbh->do ("delete from word where frequency = 0");

	$content =~ s{</?[^>]+>}{ }gms;
	$content = lc $content;
	my @word = $content =~ m{([\w\d]+)}gm;

	my %word = ();
	foreach my $w (@word)
	{
		$word{$w}++;
	}

	my %word_id = ();
	$sth = $dbh->prepare ("select id, word from word where word in (" . (join ', ', map {"'$_'"} keys %word) . ")")
		if scalar keys %word;

	$sth->execute();
	while (my ($id, $w) = $sth->fetchrow_array())
	{
		$dbh->do ("update word set frequency = frequency + $word{$w} where word = '$w'")
			if $word{$w};

		$word_id{$id} = 1;
		delete $word{$w};
	}
	$sth->finish();

	foreach my $w (keys %word)
	{
		next if length $w <= 3 || isstopword ($w);

		$dbh->do ("insert into word (word, frequency) values ('$w', $word{$w})");

		$sth = $dbh->prepare ("select last_insert_id() from word");
		$sth->execute();
		my ($id) = $sth->fetchrow_array();
		$sth->finish();

		$word_id{$id} = 1;
	}

	$dbh->do ("insert into word2message (word_id, message_id) values " .  (join ', ', map "($_, $message_id)", keys %word_id))
		if scalar keys %word_id;
}

sub isstopword
{
	my $word = shift;

	return $word =~ m{^(?:able|about|above|according|accordingly|across|actually|after|afterwards|again|against|all|allow|allows|almost|alone|along|already|also|although|always|among|amongst|another|anybody|anyhow|anyone|anything|anyway|anyways|anywhere|apart|appear|appreciate|appropriate|aren|around|aside|asking|associated|available|away|awfully|became|because|become|becomes|becoming|been|before|beforehand|behind|being|believe|below|beside|besides|best|better|between|beyond|both|brief|mon|came|can|cannot|cant|cause|causes|certain|certainly|changes|clearly|come|comes|concerning|consequently|consider|considering|contain|containing|contains|corresponding|could|couldn|course|currently|definitely|described|despite|didn|different|does|doesn|doing|done|down|downwards|during|each|eight|either|else|elsewhere|enough|entirely|especially|even|ever|every|everybody|everyone|everything|everywhere|exactly|example|except|few|fifth|first|five|followed|following|follows|former|formerly|forth|four|from|further|furthermore|gets|getting|given|gives|goes|going|gone|gotten|greetings|hadn|happens|hardly|hasn|have|haven|having|he|hello|help|hence|here|here|hereafter|hereby|herein|hereupon|hers|herself|himself|hither|hopefully|howbeit|however|i|i|if|ignored|immediate|inasmuch|indeed|indicate|indicated|indicates|inner|insofar|instead|into|inward|it|it|itself|just|keep|keeps|kept|know|knows|known|last|lately|later|latter|latterly|least|less|lest|let|like|liked|likely|little|look|looking|looks|mainly|many|maybe|mean|meanwhile|merely|might|more|moreover|most|mostly|much|must|myself|name|namely|near|nearly|necessary|need|needs|neither|never|nevertheless|next|nine|nobody|none|noone|normally|nothing|novel|nowhere|obviously|often|ok|okay|once|ones|only|onto|other|others|otherwise|ought|ours|ourselves|outside|over|overall|particular|particularly|perhaps|placed|please|plus|possible|presumably|probably|provides|quite|rather|re|really|reasonably|regarding|regardless|regards|relatively|respectively|right|said|same|say|saying|says|second|secondly|seeing|seem|seemed|seeming|seems|seen|self|selves|sensible|sent|serious|seriously|seven|several|shall|should|shouldn|since|some|somebody|somehow|someone|something|sometime|sometimes|somewhat|somewhere|soon|sorry|specified|specify|specifying|still|such|sure|take|taken|tell|tends|than|thank|thanks|thanx|that|that|thats|their|theirs|them|themselves|then|thence|there|there|thereafter|thereby|therefore|therein|theres|thereupon|these|they|they|they|they|they|think|third|this|thorough|thoroughly|those|though|three|through|throughout|thru|thus|together|took|toward|towards|tried|tries|truly|trying|twice|under|unfortunately|unless|unlikely|until|unto|upon|used|useful|uses|using|usually|value|various|very|viz|want|wants|was|wasn|we|we|welcome|well|went|were|weren|what|what|whatever|when|whence|whenever|where|where|whereafter|whereas|whereby|wherein|whereupon|wherever|whether|which|while|whither|who|whoever|whole|whom|whose|will|willing|wish|with|within|without|wonder|would|would|wouldn|yet|you|you|your|yours|yourself|yourselves|zero)$};
}

1;
