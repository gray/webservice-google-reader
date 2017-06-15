package WebService::Google::Reader::Feed;

use strict;
use warnings;
use parent qw(XML::Atom::Feed);

use WebService::Google::Reader::Constants qw(NS_GOOGLE_READER);

use Class::Tiny qw(continuation count _ids _request);


sub new {
    my ($class, %params) = @_;
    my $self = bless \%params, $class;

    $self->count(40) unless $self->count and 0 < $self->count;
    if (my $req = $self->_request) {
        $req->uri->query_param(n => $self->count);
    }

    return $self;
}


sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    # TODO: bail if the continuation identifier hasn't changed.
    my $continuation = $self->get(NS_GOOGLE_READER, 'continuation');
    $self->continuation($continuation) if defined $continuation;

    return $self;
}


# XML::Atom::Feed::entries() returns undef when there are no entries,
# instead of an empty list, but only when using XML::LibXML.
sub entries {
    my $self = shift;
    return @{[ $self->SUPER::entries(@_) ]};
}


1;

__END__

=head1 NAME

WebService::Google::Reader::Feed

=head1 DESCRIPTION

Subclass of C<XML::Atom::Feed>.

=head1 METHODS

=head2 new

    $feed = WebService::Google::Reader::Feed->B<new>(%params)

=head2 init

    $feed->B<init>(%params)

=head2 continuation

    $string = $feed->B<continuation>

Returns the continuation string, if any is present.

=head2 count

The number of entries per fetch: defaults to 40.

=head2 entries

Override the method from C<XML::Atom::Feed> to work around a bug.

=head1 SEE ALSO

L<XML::Atom::Feed>

=cut
