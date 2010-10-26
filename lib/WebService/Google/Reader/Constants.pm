package WebService::Google::Reader::Constants;

use strict;
use warnings;
use parent qw(Exporter);

our @EXPORT = do {
    no strict 'refs';
    ( qw(NS_GOOGLE_READER), grep(/_URL$/, keys %{__PACKAGE__.'::'}), )
};

use constant LOGIN_URL => 'https://www.google.com/accounts/ClientLogin';
use constant READER_URL => 'http://www.google.com/reader';
use constant TOKEN_URL => READER_URL.'/api/0/token';

use constant ATOM_URL => READER_URL.'/atom/';
use constant ATOM_PUBLIC_URL => READER_URL.'/public/atom/';
use constant API_URL => READER_URL.'/api/0';
use constant PING_URL => READER_URL.'/ping';
use constant EXPORT_SUBS_URL => READER_URL.'/subscriptions/export';

use constant EDIT_ENTRY_TAG_URL => API_URL.'/edit-tag';
use constant EDIT_MARK_READ_URL => API_URL.'/mark-all-as-read';
use constant EDIT_PREF_URL => API_URL.'/preference/set';
use constant EDIT_SUB_URL => API_URL.'/subscription/edit';
use constant EDIT_SUB_PREFS_URL => API_URL.'/preference/stream/set';
use constant EDIT_TAG_DISABLE_URL => API_URL.'/disable-tag';
use constant EDIT_TAG_SHARE_URL => API_URL.'/tag/edit';

use constant LIST_COUNTS_URL => API_URL.'/unread-count?all=true';
use constant LIST_PREFS_URL => API_URL.'/preference/list';
use constant LIST_SUBS_URL => API_URL.'/subscription/list';
use constant LIST_SUB_PREFS_URL => API_URL.'/preference/stream/list';
use constant LIST_TAGS_URL => API_URL.'/tag/list';
use constant LIST_USER_INFO_URL => READER_URL.'/user-info';

use constant STREAM_ITEM_IDS_URL => API_URL.'/stream/items/ids';
use constant SEARCH_ITEM_IDS_URL => API_URL.'/search/items/ids';
use constant STREAM_FEED_CONTENTS_URL => API_URL.'/stream/contents';
# Deprecated in favor of STREAM_FEED_CONTENTS_URL?
use constant STREAM_ITEM_CONTENTS_URL => API_URL.'/stream/items/contents';

use constant NS_GOOGLE_READER =>
    'http://www.google.com/schemas/reader/atom/';


1;

__END__

=head1 NAME

WebService::Google::Reader::Constants

=head1 DESCRIPTION

All constants are defined here and exported to the caller's namespace.

=cut
