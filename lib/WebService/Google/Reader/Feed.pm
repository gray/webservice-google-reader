package WebService::Google::Reader::Feed;

use strict;
use warnings;
use parent qw(XML::Atom::Feed Class::Accessor::Fast);

use WebService::Google::Reader::Constants qw(NS_GOOGLE_READER);

__PACKAGE__->mk_accessors(qw(continuation count ids request));

sub new {
    my ($class, %params) = @_;
    $params{count} ||= 20;
    return bless \%params, $class;
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
    my @entries = $self->SUPER::entries(@_);
    return @entries ? @entries : ();
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

=head2 entries

Fixes bug in C<XML::Atom::Feed::entries()>.

=head1 SEE ALSO

L<XML::Atom::Feed>

=cut
