#!/usr/bin/env perl
use strict;
use warnings;
use WebService::Google::Reader;

my $query = shift or die "missing query";
my @feeds = @ARGV;

my $reader = WebService::Google::Reader->new(
    host     => 'www.inoreader.com',
    username => $ENV{GOOGLE_USERNAME},
    password => $ENV{GOOGLE_PASSWORD},
);

my $feed = $reader->search($query, feed => \@feeds, count => 50)
    or die $reader->error;

do {
    for my $entry ($feed->entries) {
        print $entry->title, "\n";
        print $entry->link->href, "\n" if $entry->link and $entry->link->href;
    }

    sleep 1;
} while ($reader->more($feed));
