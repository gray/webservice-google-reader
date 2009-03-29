package WebService::Google::Reader::Feed;

use strict;
use warnings;
use base qw(XML::Atom::Feed Class::Accessor::Fast);

use WebService::Google::Reader::Constants qw(NS_GOOGLE_READER);

__PACKAGE__->mk_accessors(qw(continuation count ids request));

sub new {
    my ($class, %params) = @_;
    return bless \%params, $class;
}

sub init {
    my $self = shift;

    $self->SUPER::init(@_);

    my $continuation = $self->get(NS_GOOGLE_READER, 'continuation');
    $self->continuation($continuation) if defined $continuation;

    return $self;
}

sub XML::Atom::Entry::stream_id {
    my ($self) = @_;

    my $stream_id;
    my $source = XML::Atom::Util::first($self->elem, $self->ns, 'source');
    if ($source) {
        $stream_id = $source->getAttribute('gr:stream-id');
        if ($] >= 5.008) {
            require Encode;
            Encode::_utf8_off($stream_id) unless $XML::Atom::ForceUnicode;
        }
    }
    return $stream_id;
};

1;

__END__

=head1 NAME

WebService::Google::Reader::Feed

=head1 DESCRIPTION

Subclass of C<XML::Atom::Feed>.

=head1 METHODS

=over

=item $feed = WebService::Google::Reader::Feed->B<new>(%params)

=item $feed->B<init>(%params)

=item $string = $feed->B<continuation>

Returns the continuation string, if any is present.

=back

=head1 SEE ALSO

L<XML::Atom::Feed>

=cut
