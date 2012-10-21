use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Uc::Twitter::Schema',
    AUTHOR              => 'U=Cormorant <u@chimata.org>',
    VERSION_FROM        => 'lib/Uc/Twitter/Schema.pm',
    ABSTRACT_FROM       => 'lib/Uc/Twitter/Schema.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'version'    => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Uc-Twitter-Schema-*' },
);
