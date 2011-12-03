package WebService::Google::Reader;

use strict;
use warnings;
use parent qw(Class::Accessor::Fast);

use HTTP::Request::Common qw(GET POST);
use LWP::UserAgent;
use JSON;
use URI;
use URI::Escape;
use URI::QueryParam;

use WebService::Google::Reader::Constants;
use WebService::Google::Reader::Feed;
use WebService::Google::Reader::ListElement;

our $VERSION = '0.21';
$VERSION = eval $VERSION;

__PACKAGE__->mk_accessors(qw(
    auth compress error password response scheme token ua username
));

sub new {
    my ($class, %params) = @_;

    my $self = bless { %params }, $class;

    my $ua = $params{ua};
    unless (ref $ua and $ua->isa(q(LWP::UserAgent))) {
        $ua = LWP::UserAgent->new(
            agent => __PACKAGE__.'/'.$VERSION,
        );
        $self->ua($ua);
    }

    $self->compress(1);
    $self->debug(0);
    for my $accessor (qw( compress debug )) {
        $self->$accessor($params{$accessor}) if exists $params{$accessor};
    }

    $ua->default_header(accept_encoding => 'gzip,deflate')
        if $self->compress;

    $self->scheme($params{secure} || $params{https} ? 'https' : 'http');

    return $self;
}

sub debug {
    my ($self, $val) = @_;
    return $self->{debug} unless 2 == @_;

    my $ua = $self->ua;
    if ($val) {
        my $dump_sub = sub { $_[0]->dump(maxlength => 0); return };
        $ua->set_my_handler(request_send  => $dump_sub);
        $ua->set_my_handler(response_done => $dump_sub);
    }
    else {
        $ua->set_my_handler(request_send  => undef);
        $ua->set_my_handler(response_done => undef);
    }

    return $self->{debug} = $val;
}

## Feeds

sub feed  { shift->_feed(feed  => shift, @_) }
sub tag   { shift->_feed(tag   => shift, @_) }
sub state { shift->_feed(state => shift, @_) }

sub shared  { shift->state(broadcast => @_) }
sub starred { shift->state(starred   => @_) }
sub liked   { shift->state(like      => @_) }
sub unread  {
    shift->state(
        'reading-list', exclude => { state => 'read' }, @_
    );
}

sub search {
    my ($self, $query, %params) = @_;

    $self->_login or return;
    $self->_token or return;

    my $uri = URI->new(SEARCH_ITEM_IDS_URL);

    my %fields = (num => $params{results} || 1000);

    my @types = grep { exists $params{$_} } qw(feed state tag);
    for my $type (@types) {
        push @{$fields{s}}, _encode_type($type, $params{$type});
    }

    $uri->query_form({ q => $query, %fields, output => 'json' });

    my $req = HTTP::Request->new(GET => $uri);
    my $res = $self->_request($req) or return;

    my @ids = do {
        my $ref = eval { from_json($res->decoded_content) } or do {
            $self->error("Failed to parse JSON response: $@");
            return;
        };
        map { $_->{id} } @{$ref->{results}};
    };
    return unless @ids;
    if (my $order = $params{order} || $params{sort}) {
        @ids = reverse @ids if 'asc' eq $order;
    }

    my $feed = (__PACKAGE__.'::Feed')->new(
        request => $req, ids => \@ids, count => $params{count} || 40,
    );
    return $self->more($feed);
}

sub more {
    my ($self, $feed) = @_;

    my $req;
    if (defined $feed->ids) {
        my @ids = splice @{$feed->ids}, 0, $feed->count;
        return unless @ids;

        my $uri = URI->new(STREAM_ITEMS_CONTENTS_URL);
        $req = POST $uri, [ output => 'atom', map { (i => $_) } @ids ];
    }
    elsif ($feed->elem) {
        return unless defined $feed->continuation;
        return if $feed->entries < $feed->count;
        $req = $feed->request;
        my $prev_continuation = $req->uri->query_param('c') || '';
        return if $feed->continuation eq $prev_continuation;
        $req->uri->query_param(c => $feed->continuation);
    }
    elsif ($req = $feed->request) {
        # Initial request.
    }
    else { return }

    my $res = $self->_request($req) or return;

    $feed->init(Stream => $res->decoded_content(ref => 1)) or return;
    return $feed;
}

*previous = *previous = *next = *next = \&more;

## Lists

sub tags        { $_[0]->_list(LIST_TAGS_URL) }
sub feeds       { $_[0]->_list(LIST_SUBS_URL) }
sub preferences { $_[0]->_list(LIST_PREFS_URL) }
sub counts      { $_[0]->_list(LIST_COUNTS_URL) }
sub userinfo    { $_[0]->_list(LIST_USER_INFO_URL) }

## Edit tags

sub edit_tag        { shift->_edit_tag(tag   => @_) }
sub edit_state      { shift->_edit_tag(state => @_) }
sub share_tag       { shift->edit_tag(_listify(\@_), share   => 1) }
sub unshare_tag     { shift->edit_tag(_listify(\@_), unshare => 1) }
sub share_state     { shift->edit_state(_listify(\@_), share   => 1) }
sub unshare_state   { shift->edit_state(_listify(\@_), unshare => 1) }
sub delete_tag      { shift->edit_tag(_listify(\@_), delete => 1) }
sub mark_read_tag   { shift->mark_read(tag   => _listify(\@_)) }
sub mark_read_state { shift->mark_read(state => _listify(\@_)) }

sub rename_feed_tag {
    my ($self, $old, $new) = @_;

    my @tagged;
    my @feeds = $self->feeds or return;

    # Get the list of subs which are associated with the tag to be renamed.
    FEED:
    for my $feed (@feeds) {
        for my $cat ($self->categories) {
            for my $o ('ARRAY' eq ref $old ? @$old : ($old)) {
                if ($o eq $cat->label or $o eq $cat->id) {
                    push @tagged, $feed->id;
                    next FEED;
                }
            }
        }
    }

    $_ = [ _encode_type(tag => $_) ] for ($old, $new);

    return $self->edit_feed(\@tagged, tag => $new, untag => $old);
}

sub rename_entry_tag {
    my ($self, $old, $new) = @_;

    for my $o ('ARRAY' eq ref $old ? @$old : ($old)) {
        my $feed = $self->tag($o) or return;
        do {
            $self->edit_entry(
                [ $feed->entries ], tag => $new, untag => $old
            ) or return;
        } while ($self->feed($feed));
    }

    return 1;
}

sub rename_tag {
    my $self = shift;
    return unless $self->rename_tag_feed(@_);
    return unless $self->rename_tag_entry(@_);
    return $self->delete_tags(shift);
}

## Edit feeds

sub edit_feed {
    my ($self, $sub, %params) = @_;

    $self->_login or return;
    $self->_token or return;

    my $url = EDIT_SUB_URL;

    my %fields;
    for my $s ('ARRAY' eq ref $sub ? @$sub : ($sub)) {
        if (__PACKAGE__.'::Feed' eq ref $s) {
            my $id = $s->id or next;
            $id =~ s[^(?:user|webfeed|tag:google\.com,2005:reader/)][];
            $id =~ s[\?.*][];
            push @{$fields{s}}, $id;
        }
        else {
            push @{$fields{s}}, _encode_type(feed => $s);
        }
    }
    return 1 unless @{$fields{s} || []};

    if (defined(my $title = $params{title})) {
        $fields{t} = $title;
    }

    if (grep { exists $params{$_} } qw(subscribe add)) {
        $fields{ac} = 'subscribe';
    }
    elsif (grep { exists $params{$_} } qw(unsubscribe remove)) {
        $fields{ac} = 'unsubscribe';
    }
    else {
        $fields{ac} = 'edit';
    }

    # Add a tag or state.
    for my $t (qw(tag state)) {
        next unless exists $params{$t};
        defined(my $p = $params{$t}) or next;
        for my $a ('ARRAY' eq ref $p ? @$p : ($p)) {
            push @{$fields{a}}, _encode_type($t => $a);
        }
    }
    # Remove a tag or state.
    for my $t (qw(untag unstate)) {
        next unless exists $params{$t};
        defined(my $p = $params{$t}) or next;
        for my $d ('ARRAY' eq ref $p ? @$p : ($p)) {
            push @{$fields{r}}, _encode_type(substr($t, 2) => $d);
        }
    }

    return $self->_edit($url, %fields);
}

sub tag_feed       { shift->edit_feed(shift, tag     => \@_) }
sub untag_feed     { shift->edit_feed(shift, untag   => \@_) }
sub state_feed     { shift->edit_feed(shift, state   => \@_) }
sub unstate_feed   { shift->edit_feed(shift, unstate => \@_) }
sub subscribe      { shift->edit_feed(_listify(\@_), subscribe   => 1) }
sub unsubscribe    { shift->edit_feed(_listify(\@_), unsubscribe => 1) }
sub mark_read_feed { shift->mark_read(feed => _listify(\@_)) }
sub rename_feed    { $_[0]->edit_feed($_[1], title => $_[2]) }

## Edit entries

sub edit_entry {
    my ($self, $entry, %params) = @_;
    return unless $entry;

    $self->_login or return;
    $self->_token or return;

    my %fields = (ac => 'edit');
    for my $e ('ARRAY' eq ref $entry ? @$entry : ($entry)) {
        my $source = $e->source or next;
        my $stream_id = $source->get_attr('gr:stream-id') or next;
        push @{$fields{i}}, $e->id;
        push @{$fields{s}}, $stream_id;
    }
    return 1 unless @{$fields{i} || []};

    my $url = EDIT_ENTRY_TAG_URL;

    # Add a tag or state.
    for my $t (qw(tag state)) {
        next unless exists $params{$t};
        defined(my $p = $params{$t}) or next;
        for my $a ('ARRAY' eq ref $p ? @$p : ($p)) {
            push @{$fields{a}}, _encode_type($t => $a);
        }
    }
    # Remove a tag or state.
    for my $t (qw(untag unstate)) {
        next unless exists $params{$t};
        defined(my $p = $params{$t}) or next;
        for my $d ('ARRAY' eq ref $p ? @$p : ($p)) {
            push @{$fields{r}}, _encode_type(substr($t, 2) => $d);
        }
    }

    return $self->_edit($url, %fields);
}

sub tag_entry     { shift->edit_entry(shift, tag     => \@_) }
sub untag_entry   { shift->edit_entry(shift, untag   => \@_) }
sub state_entry   { shift->edit_entry(shift, state   => \@_) }
sub unstate_entry { shift->edit_entry(shift, unstate => \@_) }
sub share_entry   { shift->edit_entry(_listify(\@_), state   => 'broadcast') }
sub unshare_entry { shift->edit_entry(_listify(\@_), unstate => 'broadcast') }
sub star_entry    { shift->edit_entry(_listify(\@_), state   => 'starred') }
sub unstar_entry  { shift->edit_entry(_listify(\@_), unstate => 'starred') }
sub mark_read_entry { shift->edit_entry(_listify(\@_), state   => 'read') }
sub like_entry      { shift->edit_entry(_listify(\@_), state   => 'like') }
sub unlike_entry    { shift->edit_entry(_listify(\@_), unstate => 'like') }

# Create some aliases.
for (qw(star unstar like unlike)) {
    no strict 'refs';
    *$_ = \&{$_.'_entry'};
}

## Miscellaneous

sub mark_read {
    my ($self, %params) = @_;

    $self->_login or return;
    $self->_token or return;

    my %fields;
    my @types = grep { exists $params{$_} } qw(feed state tag);
    for my $type (@types) {
        push @{$fields{s}}, _encode_type($type, $params{$type});
    }

    return $self->_edit(EDIT_MARK_READ_URL, %fields);
}

sub edit_preference {
    my ($self, $key, $val) = @_;

    $self->_login or return;
    $self->_token or return;

    return $self->_edit(EDIT_PREF_URL, k => $key, v => $val);
}

sub opml {
    my ($self) = @_;

    $self->_login or return;

    my $res = $self->_request(GET(EXPORT_SUBS_URL)) or return;

    return $res->decoded_content;
}

sub ping {
    my ($self) = @_;
    my $res = $self->_request(GET(PING_URL)) or return;

    return 1 if 'OK' eq $res->decoded_content;

    $self->error('Ping failed: '. $res->decoded_content);
    return;
}

## Private interface

sub _request {
    my ($self, $req, $count) = @_;

    return if $count and 3 <= $count;

    # Assume all POST requests are secure.
    if ('POST' eq $req->method) {
        $req->uri->scheme('https');
    }
    elsif ('GET' eq $req->method and 'https' ne $req->uri->scheme) {
        $req->uri->scheme($self->scheme);
    }

    $req->uri->query_param(ck => time * 1000);
    $req->uri->query_param(client => $self->ua->agent);

    $req->header(authorization => 'GoogleLogin auth=' . $self->auth)
        if $self->auth;

    my $res = $self->ua->request($req);
    $self->response($res);
    if ($res->is_error) {
        # Need fresh tokens.
        if (401 == $res->code and $res->message =~ /^Token /) {
            print "Stale Auth token- retrying\n" if $self->debug;
            $self->_login(1) or return;
            return $self->_request($req, ++$count);
        }
        elsif ($res->header('X-Reader-Google-Bad-Token')) {
            print "Stale T token- retrying\n" if $self->debug;
            $self->_token(1) or return;

            # Replace the T token in the url-encoded content.
            my $uri = URI->new;
            $uri->query($req->content);
            $uri->query_param(T => $self->token);
            $req->content($uri->query);

            return $self->_request($req, ++$count);
        }

        $self->error(join ' - ',
            'Request failed', $res->status_line, $res->header('title')
        );
        return;
    }

    # Reset the error from previous requests.
    $self->error(undef);

    return $res;
}

sub _login {
    my ($self, $force) = @_;

    return 1 if $self->_public;
    return 1 if $self->auth and not $force;

    my $uri = URI->new(LOGIN_URL);
    $uri->query_form(
        service => 'reader',
        Email   => $self->username,
        Passwd  => $self->password,
        source  => $self->ua->agent,
    );
    my $res = $self->_request(POST($uri)) or return;

    my $content = $res->decoded_content;
    my ($auth) = $content =~ m[ ^Auth=(.*)$ ]mx;
    unless ($auth) {
        $self->error('Failed to find Auth token');
        return;
    }
    $self->auth($auth);

    return 1;
}

sub _token {
    my ($self, $force) = @_;

    return 1 if $self->token and not $force;

    $self->_login($force) or return;

    my $uri = URI->new(TOKEN_URL);
    $uri->scheme('https');
    my $res = $self->_request(GET($uri)) or return;

    return $self->token($res->decoded_content);
}

sub _public {
    return not $_[0]->username or not $_[0]->password;
}

sub _encode_type {
    my ($type, $val, $escape) = @_;

    my @paths;
    if    ('feed'  eq $type) { @paths = _encode_feed($val, $escape) }
    elsif ('tag'   eq $type) { @paths = _encode_tag($val) }
    elsif ('state' eq $type) { @paths = _encode_state($val) }
    elsif ('entry' eq $type) { @paths = _encode_entry($val) }
    else                     { return }

    return wantarray ? @paths : shift @paths;
}

sub _encode_feed {
    my ($feed, $escape) = @_;

    my @paths;
    for my $f ('ARRAY' eq ref $feed ? @$feed : ($feed)) {
        my $path = ($escape ? uri_escape($f) : $f);
        $path = "feed/$path"
            if 'user/' ne substr $f, 0, 5 and 'feed/' ne substr $f, 0, 5;
        push @paths, $path;
    }

    return @paths;
}

sub _encode_tag {
    my ($tag) = @_;

    my @paths;
    for my $t ('ARRAY' eq ref $tag ? @$tag : ($tag)) {
        my $path = $t;
        if ($t !~ m[ ^user/(?:-|\d{20})/ ]x) {
            $path = "user/-/label/$t"
        }
        push @paths, $path;
    }

    return @paths;
}

sub _encode_state {
    my ($state) = @_;

    my @paths;
    for my $s ('ARRAY' eq ref $state ? @$state : ($state)) {
        my $path = $s;
        if ($s !~ m[ ^user/(?:-|\d{20})/ ]x) {
            $path = "user/-/state/com.google/$s";
        }
        push @paths, $path;
    }

    return @paths;
}

sub _encode_entry {
    my ($entry) = @_;

    my @paths;
    for my $e ('ARRAY' eq ref $entry ? @$entry : ($entry)) {
        my $path = $e;
        if ('tag:google.com,2005:reader/item/' ne substr $e, 0, 32) {
            $path = "tag:google.com,2005:reader/item/$e";
        }
        push @paths, $path;
    }

    return @paths;
}

sub _feed {
    my ($self, $type, $val, %params) = @_;
    return unless $val;

    $self->_login or return;

    my $path = $self->_public ? ATOM_PUBLIC_URL : ATOM_URL;
    my $uri = URI->new($path . '/' . _encode_type($type, $val, 1));

    my %fields;
    if (my $count = $params{count}) {
        $fields{n} = $count;
    }
    if (my $start_time = $params{start_time}) {
        $fields{ot} = $start_time;
    }
    if (my $order = $params{order} || $params{sort} || 'desc') {
        # m = magic/auto; not really sure what that is
        $fields{r} = 'desc' eq $order ? 'n' :
                     'asc'  eq $order ? 'o' : $order;
    }
    if (defined(my $continuation = $params{continuation})) {
        $fields{c} = $continuation;
    }
    if (my $ex = $params{exclude}) {
        for my $x ('ARRAY' eq ref $ex ? @$ex : ($ex)) {
            while (my ($xtype, $exclude) = each %$x) {
                push @{$fields{xt}}, _encode_type($xtype, $exclude);
            }
        }
    }

    $uri->query_form(\%fields);

    my $feed = (__PACKAGE__.'::Feed')->new(request => GET($uri), %params);
    return $self->more($feed);
}

sub _list {
    my ($self, $url) = @_;

    $self->_login or return;

    my $uri = URI->new($url);
    $uri->query_form({ $uri->query_form, output => 'json' });

    my $res = $self->_request(GET($uri)) or return;

    my $ref = eval { from_json($res->decoded_content) } or do {
        $self->error("Failed to parse JSON response: $@");
        return;
    };

    # Remove an unecessary level of indirection.
    my $aref = (grep { 'ARRAY' eq ref } values %$ref)[0] || [];

    for my $ref (@$aref) {
        $ref = (__PACKAGE__.'::ListElement')->new($ref)
    }

    return @$aref
}

sub _edit {
    my ($self, $url, %fields) = @_;
    my $uri = URI->new($url);
    my $req = POST($uri, [ %fields, T => $self->token ]);
    my $res = $self->_request($req) or return;

    return 1 if 'OK' eq $res->decoded_content;

    # TODO: is there a standard error format which can be reliably parsed?
    $self->error('Edit failed: '. $res->decoded_content);
    return;
}

sub _edit_tag {
    my ($self, $type, $tag, %params) = @_;
    return unless $tag;

    $self->_login or return;
    $self->_token or return;

    my %fields = (s => [ _encode_type($type => $tag) ]);
    return 1 unless @{$fields{s}};

    my $url;
    if (grep { exists $params{$_} } qw(share public)) {
        $url = EDIT_TAG_SHARE_URL;
        $fields{pub} = 'true';
    }
    elsif (grep { exists $params{$_} } qw(unshare private)) {
        $url = EDIT_TAG_SHARE_URL;
        $fields{pub} = 'false';
    }
    elsif (grep { exists $params{$_} } qw(disable delete)) {
        $url = EDIT_TAG_DISABLE_URL;
        $fields{ac} = 'disable-tags';
    }
    else {
        $self->error('Unknown action');
        return;
    }

    return $self->_edit($url, %fields);
}

sub _states {
    return qw(
        read kept-unread fresh starred broadcast reading-list
        tracking-body-link-used tracking-emailed tracking-item-link-used
        tracking-kept-unread like
    );
}

sub _listify {
    my ($aref) = @_;
    return (1 == @$aref and 'ARRAY' eq ref $aref->[0]) ? @$aref : $aref;
}


1;

__END__

=head1 NAME

WebService::Google::Reader - Perl interface to Google Reader

=head1 SYNOPSIS

    use WebService::Google::Reader;

    my $reader = WebService::Google::Reader->new(
        username => $user,
        password => $pass,
    );

    my $feed = $reader->unread(count => 100);
    my @entries = $feed->entries;

    # Fetch past entries.
    while ($reader->more($feed)) {
        my @entries = $feed->entries;
    }

=head1 DESCRIPTION

The C<WebService::Google::Reader> module provides an interface to the
Google Reader service through the unofficial (as-yet unpublished) API.

=head1 METHODS

=over

=item $reader = WebService::Google::Reader->B<new>

Creates a new WebService::Google::Reader object. The following named
parameters are accepted:

=over

=item B<username> and B<password>

Required for accessing any personalized or account-related functionality
(reading-list, editing, etc.).

=item B<https> / B<secure>

Use https scheme for all requests, even when not required.

=item B<ua>

An optional useragent object.

=item B<debug>

Enable debugging. Default: 0. This will dump the headers and content for
both requests and responses.

=item B<compress>

Disable compression. Default: 1. This is useful when debugging is enabled
and you want to read the response content.

=back

=item $error = $reader->B<error>

Returns the error string, if any.

=item $response = $reader->B<response>

Returns an L<HTTP::Response> object for the last submitted request. Can be
used to determine the details of an error.

=back

=head2 Feed generators

The following methods request an ATOM feed and return a subclass of
C<XML::Atom::Feed>. These methods accept the following optional named
parameters:

=over

=over

=item B<order> / B<sort>

The sort order of the entries: B<desc> (default) or B<asc> in time. When
ordering by B<asc>, Google only returns entries within 30 days, whereas the
default order has no limitation.

=item B<start_time>

Request entries only newer than this time (represented as a unix
timestamp).

=item B<exclude>(feed => $feed|[@feeds], tag => $tag|[@tags])

Accepts a hash reference to one or more of feed / tag / state. Each of
which is a scalar or array reference.

=back

=back

=over

=item B<feed>($feed)

Accepts a single feed url.

=item B<tag>($tag)

Accepts a single tag name. See L</TAGS>

=item B<state>($state)

Accepts a single state name. See L</STATES>.

=item B<shared>

Shortcut for B<state>('broadcast').

=item B<starred>

Shortcut for B<state>('starred').

=item B<unread>

Shortcut for B<state>('reading-list', exclude => { state => 'read' })

=item B<liked>

Shortcut for B<state>('like').

=back

=over

=item B<search>($query, %params)

Accepts a query string and the following named parameters:

=over

=item B<feed> / B<state> / B<tag>

One or more (as a array reference) feed / state / tag to search. The
default is to search all feed subscriptions.

=item B<results>

The total number of search results: defaults to 1000.

=item B<count>

The number of entries per fetch: defaults to 40.

=item B<order> / B<sort>

The sort order of the entries: B<desc> (default) or B<asc> in time.

=back

=item B<more> / B<previous> / B<next>

A feed generator only returns B<$count> entries. If more are available,
calling this method will return a feed with the next B<$count> entries.

=back

=head2 List generators

The following methods return an object of type
C<WebService::Google::Reader::ListElement>.

=over

=item B<counts>

Returns a list of subscriptions and a count of unread entries. Also listed
are any tags or states which have positive unread counts. The following
accessors are provided: id, count. The maximum count reported is 1000.

=item B<feeds>

Returns the list of user subscriptions. The following accessors are
provided: id, title, categories, firstitemmsec. categories is a reference
to a list of C<ListElement>s providing accessors: id, label.

=item B<preferences>

Returns the list of preference settings. The following accessors are
provided: id, value.

=item B<tags>

Returns the list of user-created tags. The following accessors are
provided: id, shared.

=item B<userinfo>

Returns the list of user information. The following accessors are provided:
isBloggerUser, userId, userEmail.

=back

=head2 Edit feeds

The following methods are used to edit feed subscriptions.

=over

=item B<edit_feed>($feed|[@feeds], %params)

Requires a feed url or Feed object, or a reference to a list of them.
The following named parameters are accepted:

=over

=item B<subscribe> / B<unsubscribe>

Flag indicating whether the target feeds should be added or removed from
the user's subscriptions.

=item B<title>

Accepts a title to associate with the feed. This probaby wouldn't make
sense to use when there are multiple feeds. (Maybe later will consider
allowing a list here and zipping the feed and title lists).

=item B<tag> / B<state> / B<untag> / B<unstate>

Accepts a tag / state or a reference to a list of tags / states for which
to associate / unassociate the target feeds.

=back

=item B<tag_feed>($feed|[@feeds], @tags)

=item B<untag_feed>($feed|[@feeds], @tags)

=item B<state_feed>($feed|[@feeds], @states)

=item B<unstate_feed>($feed|[@feeds], @states)

Associate / unassociate a list of tags / states from a feed / feeds.

=item B<subscribe>(@feeds|[@feeds])

=item B<unsubscribe>(@feeds|[@feeds])

Subscribe or unsubscribe from a list of feeds.

=item B<rename_feed>($feed|[@feeds], $title)

Renames a feed to the given title.

=item B<mark_read_feed>(@feeds|[@feeds])

Marks the feeds as read.

=back

=head2 Edit tags / states

The following methods are used to edit tags and states.

=over

=item B<edit_tag>($tag|[@tags], %params)

=item B<edit_state>($state|[@states], %params)

Accepts the following parameters.

=over

=item B<share> / B<public>

Make the given tags / states public.

=item B<unshare> / B<private>

Make the given tags / states private.

=item B<disable> / B<delete>

Only tags (and not states) can be disabled.

=back

=item B<share_tag>(@tags|[@tags])

=item B<unshare_tag>(@tags|[@tags])

=item B<share_state>(@states|[@states])

=item B<unshare_state>(@states|[@states])

Associate / unassociate the 'broadcast' state with the given tags / states.

=item B<delete_tag>(@tags|[@tags])

Delete the given tags.

=item B<rename_feed_tag>($oldtag|[@oldtags], $newtag|[@newtags]

Renames the tags associated with any feeds.

=item B<rename_entry_tag>($oldtag|[@oldtags], $newtag|[@newtags]

Renames the tags associated with any individual entries.

=item B<rename_tag>($oldtag|[@oldtags], $newtag|[@newtags]

Calls B<rename_feed_tag> and B<rename_entry_tag>, and finally
B<delete_tag>.

=item B<mark_read_tag>(@tags|[@tags])

=item B<mark_read_state>(@states|[@states])

Marks all entries as read for the given tags / states.

=back

=head2 Edit entries

The following methods are used to edit individual entries.

=over

=item B<edit_entry>($entry|[@entries], %params)

=over

=item B<tag> / B<state> / B<untag> / B<unstate>

Associate / unassociate the entries with the given tags / states.

=back

=item B<tag_entry>($entry|[@entries], @tags)

=item B<untag_entry>($entry|[@entries], @tags)

=item B<state_entry>($entry|[@entries], @tags)

=item B<unstate_entry>($entry|[@entries], @tags)

Associate / unassociate the entries with the given tags / states.

=item B<share_entry>(@entries|[@entries])

=item B<unshare_entry>(@entries|[@entries])

Marks all the given entries as "broadcast".

=item B<star>(@entries|[@entries])

=item B<star_entry>(@entries|[@entries])

=item B<unstar>(@entries|[@entries])

=item B<unstar_entry>(@entries|[@entries])

Marks / unmarks all the given entries as "starred".

=item B<mark_read_entry>(@entries|[@entries])

Marks all the given entries as "read".

=item B<like>(@entries|[@entries])

=item B<like_entry>(@entries|[@entries])

=item B<unlike>(@entries|[@entries])

=item B<unlike_entry>(@entries|[@entries])

Marks / unmarks all the given entries as "liked".

=back

=head2 Miscellaneous

These are a list of other useful methods.

=over

=item B<edit_preference>($key, $value)

Sets the given preference name to the given value.

=item B<mark_read>(feed => $feed|[@feeds], state => $state|[@states],
                    tag => $tag|[@tags])

=item B<opml>

Exports feed subscriptions as OPML.

=item B<ping>

Returns true / false on success / failure. Unsure of when this needs to be
used.

=back

=head2 Private methods

The following private methods may be of use to others.

=over

=item B<_login>

This is automatically called from within methods that require
authorization.  An optional parameter is accepted which when true, will
force a login even if a previous login was successful. The end result of
a successful login is to set the auth token.

=item B<_request>

Given an C<HTTP::Request>, this will perform the request and if the
response indicates a bad (expired) token, it will request another token
before performing the request again. Returns an C<HTTP::Response> on
success, false on failure (check B<error>).

=item B<_token>

This is automatically called from within methods that require a user token.
If successful, the token is available via the B<token> accessor.

=item B<_states>

Returns a list of all the known states. See L</STATES>.

=back

=head1 TAGS

The following characters are not allowed: "E<lt>E<gt>?&/\^

=head1 STATES

These are tags in a Google-specific namespace. The following are all the
known used states.

=over

=item read

Entries which have been read.

=item kept-unread

Entries which have been read, but marked unread.

=item fresh

New entries from reading-list.

=item starred

Entries which have been starred.

=item broadcast

Entries which have been shared and made publicly available.

=item reading-list

Entries from all subscriptions.

=item tracking-body-link-used

Entries for which a link in the body has been clicked.

=item tracking-emailed

Entries which have been mailed.

=item tracking-item-link-used

Entries for which the title link has been clicked.

=item tracking-kept-unread

Entries which have been kept unread.
(Not sure how this differs from "kept-unread").

=back

=head1 SEE ALSO

L<XML::Atom::Feed>

L<https://groups.google.com/group/fougrapi/>

L<http://code.google.com/p/pyrfeed/wiki/GoogleReaderAPI>

=head1 REQUESTS AND BUGS

Please report any bugs or feature requests to
L<http://rt.cpan.org/Public/Bug/Report.html?Queue=WebService-Google-Reader>.
I will be notified, and then you'll automatically be notified of progress
on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WebService::Google::Reader

You can also look for information at:

=over

=item * GitHub Source Repository

L<http://github.com/gray/webservice-google-reader>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WebService-Google-Reader>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WebService-Google-Reader>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/Public/Dist/Display.html?Dist=WebService-Google-Reader>

=item * Search CPAN

L<http://search.cpan.org/dist/WebService-Google-Reader/>

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007-2011 gray <gray at cpan.org>, all rights reserved.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR

gray, <gray at cpan.org>

=cut
