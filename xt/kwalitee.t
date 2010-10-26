use strict;
use warnings;
use Test::More;

eval { require Test::Kwalitee; Test::Kwalitee->import(); 1 } or do {
    plan skip_all => 'Test::Kwalitee not installed; skipping';
};
