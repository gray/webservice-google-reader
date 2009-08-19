use strict;
use warnings;
use Test::More;

eval "use Test::Pod 1.00";
if ($@) {
    plan skip_all => 'Test::Pod 1.00 required for testing POD';
}

all_pod_files_ok();
