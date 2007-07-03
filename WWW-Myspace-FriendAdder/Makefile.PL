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
        'WWW::Myspace'          => 0.67,
        'Test::More'            => 0,
        'Config::General'       => 0, # FriendAdder.pm
        'DateTime'              => 0, # FriendAdder.pm
        'IO::Prompt'            => 0, # FriendAdder.pm 
        'List::Compare'         => 0, # FriendAdder.pm
        'Math::Round'           => 0, # FriendAdder.pm
        'Params::Validate'      => 0, # FriendAdder.pm
        'Scalar::Util'          => 0, # FriendAdder.pm

    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'WWW-Myspace-FriendAdder-*' },
);
