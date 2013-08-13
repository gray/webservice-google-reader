#!/usr/bin/env perl
use strict;
use warnings;
use WebService::Google::Reader;

# Not sure if preferences should be reset. That would require
# storing the list of prefs and their defaults.

my $reader = WebService::Google::Reader->new(
    host     => 'www.inoreader.com',
    username => $ENV{GOOGLE_USERNAME},
    password => $ENV{GOOGLE_PASSWORD},
);

# Unsubscribe from all feeds.
my @feeds = $reader->feeds;
die $reader->error if $reader->error;
$reader->unsubscribe(@feeds) or die $reader->error;
printf "Removed %d feeds\n", scalar @feeds;

# Delete all tags.
my @tags = $reader->tags;
die $reader->error if $reader->error;
$reader->delete_tag(@tags) or die $reader->error;
printf "Deleted %d tags\n", scalar @tags;

# Remove all states from any entries.
for my $state ($reader->_states) {
    my $feed = $reader->state($state, count => 500) or next;

    do {
        $reader->unstate_entry([ $feed->entries ], $reader->_states)
            or die $reader->error;
        if (my $count = scalar $feed->entries) {
            printf "Removed state '%s' from %d entries\n", $state, $count;
        }
        sleep 1;
    } while ($reader->more($feed));
}
