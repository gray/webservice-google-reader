#!/usr/bin/env perl
use strict;
use warnings;
use Time::HiRes qw(sleep);
use WebService::Google::Reader;

my $reader = WebService::Google::Reader->new(
    host     => 'www.inoreader.com',
    username => $ENV{GOOGLE_USERNAME},
    password => $ENV{GOOGLE_PASSWORD},
);

# This above account should be subscribed to this feed.
# Example: http://sfbay.craigslist.org/search/sss?query=shiny&format=rss
my $url = '';

my $feed = $reader->feed(
    $url, count => 100, order => 'asc', exclude => { state => 'read' }
);

$|= 1;

my ($total, $expired) = (0, 0);
my @dead;
{
    for my $entry ($feed->entries) {
        printf "%s total, %s dead\r", ++$total, $expired;
        next unless $entry->link and $entry->link->href;
        my $res = $reader->ua->get(
            $entry->link->href,
            user_agent => 'Google Reader dead post marker/0.01'
        );
        next unless $res->is_success;
        next unless $res->decoded_content =~ m[
            <h2>this\ posting\ has\ (?:
                expired\. |
                been\ deleted\ by\ its\ author\. |
                been\ <a[^>]+>flagged</a>\ for\ removal
            )</h2>
        ]ix;
        printf "%s total, %s dead\r", $total, ++$expired;
        push @dead, $entry;
    }
    continue { sleep 0.25 }

    redo if $reader->more($feed);
}

$reader->mark_read_entry(\@dead);
