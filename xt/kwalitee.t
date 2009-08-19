use strict;
use warnings;
use Test::More;

eval { require Test::Kwalitee; Test::Kwalitee->import() };
if ($@) {
    plan skip_all => 'Test::Kwalitee not installed; skipping';
}
