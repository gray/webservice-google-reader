#!/usr/bin/env perl
use strict;
use warnings;
use WebService::Google::Reader;

my $continue = shift;

my $reader = WebService::Google::Reader->new(
    username => $ENV{GOOGLE_USERNAME},
    password => $ENV{GOOGLE_PASSWORD},
);

my $feed = $reader->unread(count => 50) or die $reader->error;

do {
    for my $entry ($feed->entries) {
        print $entry->title, "\n";
        print $entry->link->href, "\n"
            if $entry->link and $entry->link->href;
    }

    $reader->mark_read_entry($feed->entries) or die $reader->error;

    exit unless $continue;

    sleep 1;
} while $reader->more($feed);
