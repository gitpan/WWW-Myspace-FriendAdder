#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'WWW::Myspace::FriendAdder' );
}

diag( "Testing WWW::Myspace::FriendAdder $WWW::Myspace::FriendAdder::VERSION, Perl $], $^X" );
