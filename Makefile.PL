use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

my @prereq;
unless ( eval { require IO::Socket::SSL; 1 } ) {
    push @prereq, 'Crypt::SSLeay' => 0;
}

my %conf = (
    NAME          => 'WebService::Google::Reader',
    AUTHOR        => 'gray <gray@cpan.org>',
    LICENSE       => 'perl',
    VERSION_FROM  => 'lib/WebService/Google/Reader.pm',
    ABSTRACT_FROM => 'lib/WebService/Google/Reader.pm',
    PREREQ_PM     => {
        'Class::Accessor::Fast' => 0,
        'JSON'                  => 0,
        'LWP::UserAgent'        => 0,
        'Test::More'            => 0,
        'URI'                   => 0,
        'URI::Escape'           => 0,
        'URI::QueryParam'       => 0,
        'XML::Atom'             => 0,
        @prereq
    },
    META_MERGE    => {
        resources  => {
            repository => 'http://github.com/gray/webservice-google-reader',
        },
        recommends => {
            'JSON::XS' => 2.0,
        },
    },
    dist          => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean         => { FILES => 'WebService-Google-Reader-*' },
);

unless (eval { ExtUtils::MakeMaker->VERSION(6.46) }) {
    delete $conf{META_MERGE};
}

WriteMakefile(%conf);
