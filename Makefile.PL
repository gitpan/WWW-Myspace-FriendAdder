use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'WWW::Myspace::FriendAdder',
    AUTHOR              => 'Olaf Alders <olaf@wundersolutions.com>',
    VERSION_FROM        => 'lib/WWW/Myspace/FriendAdder.pm',
    ABSTRACT_FROM       => 'lib/WWW/Myspace/FriendAdder.pm',
    PL_FILES            => {},
    EXE_FILES         => [qw(
                                scripts/add_friends
                              )],
    PREREQ_PM => {
        'WWW::Myspace'          => 0.72,
        'Test::More'            => 0,
        'Config::General'       => 0,
        'DateTime'              => 0,
        'IO::Prompt'            => 0, 
        'List::Compare'         => 0,
        'Math::Round'           => 0,
        'Params::Validate'      => 0,
        'Scalar::Util'          => 0,
        'Term::ProgressBar'     => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'WWW-Myspace-FriendAdder-*' },
);
