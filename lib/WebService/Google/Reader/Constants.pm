package WebService::Google::Reader::Constants;

use strict;
use warnings;
use parent qw(Exporter);

our @EXPORT = do {
    no strict 'refs';
    grep /^NS_|_PATH$/, keys %{__PACKAGE__.'::'}
};

use constant LOGIN_PATH => '/accounts/ClientLogin';
use constant READER_PATH => '/reader';
use constant TOKEN_PATH => READER_PATH.'/api/0/token';

use constant ATOM_PATH => READER_PATH.'/atom';
use constant ATOM_PUBLIC_PATH => READER_PATH.'/public/atom';
use constant API_PATH => READER_PATH.'/api/0';
use constant PING_PATH => READER_PATH.'/ping';
use constant EXPORT_SUBS_PATH => READER_PATH.'/subscriptions/export';

use constant EDIT_ENTRY_TAG_PATH => API_PATH.'/edit-tag';
use constant EDIT_MARK_READ_PATH => API_PATH.'/mark-all-as-read';
use constant EDIT_PREF_PATH => API_PATH.'/preference/set';
use constant EDIT_SUB_PATH => API_PATH.'/subscription/edit';
use constant EDIT_SUB_PREFS_PATH => API_PATH.'/preference/stream/set';
use constant EDIT_TAG_DISABLE_PATH => API_PATH.'/disable-tag';
use constant EDIT_TAG_SHARE_PATH => API_PATH.'/tag/edit';

use constant LIST_COUNTS_PATH => API_PATH.'/unread-count?all=true';
use constant LIST_PREFS_PATH => API_PATH.'/preference/list';
use constant LIST_SUBS_PATH => API_PATH.'/subscription/list';
use constant LIST_SUB_PREFS_PATH => API_PATH.'/preference/stream/list';
use constant LIST_TAGS_PATH => API_PATH.'/tag/list';
use constant LIST_USER_INFO_PATH => READER_PATH.'/user-info';

use constant STREAM_ITEM_IDS_PATH => API_PATH.'/stream/items/ids';
use constant SEARCH_ITEM_IDS_PATH => API_PATH.'/search/items/ids';
use constant STREAM_ITEMS_CONTENTS_PATH => API_PATH.'/stream/items/contents';

use constant NS_GOOGLE_READER =>
    'http://www.google.com/schemas/reader/atom/';


1;

__END__

=head1 NAME

WebService::Google::Reader::Constants

=head1 DESCRIPTION

All constants are defined here and exported to the caller's namespace.

=cut
