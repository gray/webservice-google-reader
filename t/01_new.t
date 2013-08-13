use strict;
use warnings;
use Test::More tests => 3;
use WebService::Google::Reader;

{
    my $reader = WebService::Google::Reader->new(host => 'www.inoreader.com');
    isa_ok($reader, 'WebService::Google::Reader', 'Reader->new()');
}

{
    my @methods = qw(
        auth error password scheme token ua username

        feed tag state shared starred unread search more previous

        tags feeds preferences counts userinfo

        edit_feed tag_feed untag_feed state_feed unstate_feed subscribe
        unsubscribe rename_feed mark_read_feed

        edit_tag edit_state share_tag unshare_tag share_state unshare_state
        delete_tag mark_read_tag mark_read_state rename_feed_tag
        rename_entry_tag rename_tag

        edit_entry tag_entry untag_entry state_entry unstate_entry
        share_entry unshare_entry star star_entry unstar unstar_entry
        mark_read_entry

        edit_preference opml ping mark_read

        _login _token _request _public _states _encode_type _encode_feed
        _encode_tag _encode_state _encode_entry _feed _list _edit _edit_tag
    );
    can_ok('WebService::Google::Reader', @methods);
}

{
    my @methods = qw(
        continuation count ids request
    );
    can_ok('WebService::Google::Reader::Feed', @methods);
}
