package WWW::Myspace::FriendAdder;

use WWW::Myspace::MyBase -Base;
use WWW::Myspace;
 
use Carp;
use Config::General;
use Data::Dumper;
use IO::Prompt;
use List::Compare;
use Math::Round qw(nearest);
use Term::ProgressBar;

=head1 NAME

WWW::Myspace::FriendAdder - Interactively add friends to your Myspace
account

=head1 VERSION

Version 0.15

=cut

our $VERSION = '0.15';

BEGIN {
    my $require = '0.72';
    # get a minimum version of Myspace.pm to prevent wonkiness
    if ( $WWW::Myspace::VERSION < $require ) {
        croak "we need at least version $require of WWW::Myspace  Yours: $WWW::Myspace::VERSION";
    }
}

=head1 WARNING

March 2007: Using L<WWW::Myspace> for commenting, messaging, or adding
friends will probably get your Myspace account deleted or disabled.

=head1 SYNOPSIS

This module gives you a little more flexibility when adding friends to
your Myspace account. It is interactive and will occasionally prompt you
for input.  You'll have the most success when using it at the command
line, but you do have the option of suppressing its reporting and
interactive nature if you want to run it from a cgi script or if you
just find it annoying.  Hey, you've got your reasons, right? This module
is an extension of Grant Grueninger's handy L<WWW::Myspace> module.

    use WWW::Myspace;
    use WWW::Myspace::FriendAdder;

    my $myspace = WWW::Myspace->new();

    my $adder = WWW::Myspace::FriendAdder->new( $myspace );

    my @friend_ids = ('List', 'of', 'friend', 'ids');

    $adder->send_friend_requests( @friend_ids );

By default, this  routine will try to add as many friends as possible
until it it reaches max_count, which defaults to 50, but can be set to
any number of your choosing.  See below. When Myspace prompts you for
user input, the routine will pause and allow you as much time as you
need to fill out the Myspace form.  Once you have done so, you may
prompt the script to continue or to exit. Upon its exit, the script will
report on its success and/or failure.

=cut

my %default_params = (
    config_file         => 0,
    config_file_format  => { default => 'YAML' },
    db                  => { default => 0 },
    exclude_my_friends  => { default => 0 },
    exclude_logged_adds => { default => 0 },
    firefox             => { optional => 1 },
    interactive         => { default => 1 }, # try to be silent
    last_login          => { default => 0 },
    max_count           => { default => 50 },
    message_on_captcha  => { default => 0 },
    myspace             => 0,
    profile_type        => 0,
    random_sleep        => { default => 0 },
    sleep               => { default => 10 },
    sleep_on_captcha    => { default => 0 },
    time_zone           => 0,
);

field 'myspace';

const default_options => \%default_params;

=head1 CONSTRUCTOR AND STARTUP

=head2 new()

Initialize and return a new WWW::Myspace::FriendAdder object.
$myspace is a L<WWW::Myspace> object.

Example

    use WWW::Myspace;

    use WWW::Myspace::FriendAdder;
    
    # see WWW::Myspace docs for more info on user/pass usage
    my $myspace = WWW::Myspace->new(); 

    my $adder = WWW::Myspace::FriendAdder->new( $myspace );
    
    # or pass some startup parameters
    my %startup_params = (
        exclude_my_friends  => 1, 
        max_count           => 25, 
        config_file         => '/path/to/config_file.cfg',
    );
    
    my $adder = WWW::Myspace::FriendAdder->new( 
        $myspace,
        \%startup_params, 
    );

    # find all of Shania Twain's friends 
    # (hey, you've got your reasons...)
    my @friend_ids = $myspace->friends_from_profile('13866406');
    
    # now, ask Shania's friends to be your friends
    $adder->send_friend_requests( @friend_ids);

Optional Parameters

=over 4

=item * C<< config_file => $value >>
 
If you prefer to keep your startup parameters in a file, pass a valid
filename to new.
 
Your startup file may contain any of the parameters that can be passed
to new() (except the $myspace object).  Your config file will be used to
set the default parameters for startup.  Any other parameters which you
also pass to new() will override the corresponding values in the config
file.  So, if you have a default setting for exclude_my_friends in your
config file but also pass exclude_my_friends directly to new(), the
config file value will be overriden.  The default behaviour is not to
look for a config file.  Default file format is L<YAML>.
 
    my $adder = WWW::Myspace::FriendAdder->( 
        $myspace, 
        { config_file => '/path/to/adder_config.cfg', }, 
    );

=item * C<< config_file_format => [YAML|CFG] >>

If you have chosen to use a configuration file, you may state explicitly
which format you are using.  You may choose between L<YAML> and
L<Config::General>.  If you choose not to pass this parameter, it will
default to L<YAML>.

=item * C<< exclude_my_friends => [0|1] >>

You can only perform a set number of friend requests per day.  I don't
know what that number is. At this point, it's more than 200,   It could
be as many as 300.  If you know, let me know. I can't tell you for sure,
so don't go crazy and try 1,000 requests in an hour. A failed request is
a wasted interaction, and there's really no point in trying to add
people who are already on your friends list.  It just makes you look
like someone who has no clue. So, if you want to get the most out of
your bandwidth and CPU, set this value to be true.  Currently this info
is not cached, so your friend ids will have to be looked up every time
you run the script.  However, if you have successfully called 
get_data_object() (see below) your friends list will be retrieved via SQL. 
This is a BIG time saver if you have more than just a few friends.


=item * C<< firefox => ["/path/to/firefox/bin +options"] >>

"interactive" (see below) must be switched on for the "firefox" 
parameter to be enabled.  Previously, the preferred method for
dealing with CAPTCHA requests was to print out the URL to the terminal.
You'd then copy/paste the URL into your web browser, fill out the 
CAPTCHA request and then prompt the script to continue.  Things just
got (marginally) easier.  I have only tested this on my Ubuntu (Edgy)
machine, but it works really well.  It's a bit of a hack, but really
most of this module is just that.

In order for this to run smoothly, fire up your Firefox browser *before*
running your FriendAdder script.  Log in to your Myspage page and then
fire up the script in a terminal.  Now, when the CAPTCHA request
appears, the CAPTCHA URL will automatically be loaded by Firefox.  Just
switch over to Firefox, fill out the CAPTCHA request and then prompt the
script to continue.  It cuts out one step in the process, but I've found 
it to be very handy.  

For example, in your script:

=over 4

Create your $myspace object like this:

# Enter *exactly* the same UserAgent as the browser you'll be using

my $user_agent = 'Mozilla/5.0...';

my $myspace = WWW::Myspace->new ( 
    auto_login   => 0, 
    account_name => 'your@email.com', 
    password     => 'seekrit', 
);

$myspace->mech_params({ agent => $user_agent, });

$myspace->_new_mech;

$myspace->site_login;

# set up your startup params

my %params = ( 
    ... # whatever your params would otherwise be
    firefox => "/usr/bin/firefox -new-tab ",
);

# create a new FriendAdder object

my $adder = WWW::Myspace::FriendAdder->new($myspace, \%params);

=back

The advantage of doing things this way is that your $myspace UserAgent
and your browser's reported UserAgent will be identical.  You can now
let the script run in a terminal window and come back to it every so 
often to deal with a CAPTCHA request. 

Note that I've passed the "new-tab" option to the binary.  This tells
Firefox to (naturally) open a new tab in an existing browser instance.
You can try other options if you like.  Just make sure you're already
logged in via your browser or you'll be kicked to a login page rather 
than the CAPTCHA page and that sort of defeats the whole purpose of 
the exercise.

If you get  this to work on a non-Linux platform, please let me know 
how to do it so I can add it to the docs. 


=item * C<< interactive => [0|1] >>

This module is at its most powerful when you are able to interact with
it.  If you don't feel like interacting, set this to 0.  Default is on.

=item * C<< last_login => days >>

It doesn't always make sense to send an add request to someone who
hasn't logged in to their account in ages.  last_login is a value, in
days, which will force FriendAdder to skip anyone who hasn't logged in
over the last last_login days.  So, passing last_login => 60 will mean
that you don't waste add requests on folks who haven't logged in over
the last 2 months.  They've probably moved on to something better by
now...

This parameter defaults to 0, which is off.  Keep in mind that if you're
using Data.pm this could add the overhead of an extra page load for each
attempted friend request.  If you want to keep your Myspace calls to a
minimum, you'll want to keep this disabled.

=item * C<< max_count => $value >>

Set this to any positive integer and FriendAdder will stop friend
requests when it reaches this upper limit.  Default is 50.

=item * C<< profile_type => [ 'band' | 'personal' | 'all' ] >>

Set this to band if you only want to add bands.  Set it to personal if
you only want to add personal pages.  Defaults to "all" (adds any profile). 

=item * C<< random_sleep => [0|1] >>

Want your script to feel more human?  Set I<random_sleep> to 1 and
send_friend_requests() will take random breaks between add requests
using Perl's built-in rand() function.  The upper limit of the random
number will be set by the I<sleep> option (see below).  Default is off.

=item * C<< sleep => $seconds >>

Myspace's network connectivity is wonky at the best of times.  Best not
to send a request every 0.1 seconds.  Set this to any positive number
and send_friend_requests() will sleep for this many seconds between add
requests.  If you enable I<random_sleep> (see above), this number will
be the upper limit of the random sleep time.  Default is 10.

=item * C<< sleep_on_captcha => $seconds >>

CAPTCHAs will go away if you wait long enough.  If you're running a cron or a 
background process, you may want to let the script sleep and then check back 
in.  A suggested time would be just over 12 hours or something greater than
33,200 seconds.  You should note that this *will* kick in *before* the firefox 
param is checked, so if you're not sure you'd like to wait several hours when 
you hit CAPTCHA, this is not for you. Default is off.  

=back

=cut


=head2 send_friend_requests( @friend_ids )

This method is the main force behind this module.  Pass it a list of
friend_ids and it will try to add them to your friends.  This method is
really just a wrapper around $myspace->send_friend_requests()  It adds
interactivity and advanced reporting to the L<WWW::Myspace> method.  You'll
get most of the info that you need printed to your terminal when you run
your script from the command line.  But, the script will also return a
hash reference which you can use to create your own reports.  The hash
is keyed on response codes returned by L<WWW::Myspace>.  The value of each
key is a list of friend ids which returned with that status code.

    my $report = $adder->send_friend_requests( @friend_ids );
    
    # when run at the command line, you may see something like this:
    
    $ perl add.pl 

    Beginning to process the ids...
    1)      9395579:        Failed, this person is already your friend.
(FF)
                            Sleeping for 4.95 seconds...
    2)      9373522:        Passed! Verification string received. (P)
                            Sleeping for 2.43 seconds...
    3)      9315640:        Failed, you already have a pending friend
request
                            for this person (FP)
                            Sleeping for 5.71 seconds...
    4)      9277516:        Passed! Verification string received. (P)
                            Sleeping for 1.78 seconds...
    5)      9269809:        Passed! Verification string received. (P) 
    
    Max attempts (5) reached. Exiting nicely...
    
    Final status report...
    
    ######################
    5 successful adds
    1 Failed, this person is already your friend. (FF)
    1 Failed, you already have a pending friend request for this person
(FP)
    3 Passed! Verification string received. (P)

    # %report may look something like this...
    my %{$report} = (
        'FF' => [
                    '9395579'
                ],
        'FP' => [
                    '9315640'
                ],
        'P' => [
                   '9373522',
                   '9277516',
                   '9269809'
                 ],
        );



=cut

sub send_friend_requests {

    # Check for WWW::Myspace object
    croak "Must set a valid myspace object in ".
          "WWW::Myspace::FriendAdder before\n".
          "calling send_friend_requests method" 
         unless ( $self->myspace);

    my @potential_friends = @_;

    my $adds     = 0; # successful add requests
    my $captcha  = 0; # message_on_captcha attempts
    my $continue = 1; # break loop?
    my $count    = 0; # ids processed
    
    my @unique_ids  = (); # friends who are safe to contact
    my %codes       = (); # status messages, keyed on codes
    my %code_report = (); # final report data, keyed on codes
    
    # experimental database support
    if ( $self->{'db'} && !$self->{'loader'} ) {
        $self->get_data_object();                
    }
    
    my $my_friend_id = $self->{'myspace'}->my_friend_id;
    
    if ( $self->{'exclude_my_friends'} ) {

        my $start_time = time();
        
        # if we have database access, use our own friends list
        if ( $self->{'data'} ) {
        
            $self->_report("Checking friend ids in database...\n");
                        
            my $account_id = $self->{'data'}->get_account();
            
            foreach my $friend_id ( @potential_friends ) {

                # first see if this is already a friend
                my $current_friend = 
                    WWW::Myspace::Data::FriendToAccount->retrieve(
                        friend_id  => $friend_id,
                        account_id => $account_id,
                );
                
                if ( $current_friend ) {
                    next;
                }
                
                # see if an attempt has already been made
                my $logged = WWW::Myspace::Data::PostLog->search_where(
                    account_id => [ $account_id ],
                    friend_id => [ $friend_id ],
                    result_code => [ 
                        'P',    'FA',   'FB', 
                        'FF',   'FP',   'FI', 
                    ],
                );
                
                unless ( $logged ) {
                    push (@unique_ids, $friend_id);
                }
            }
             
        }
        
        else {
        
            # no database access -- get everything from myspace
            
            $self->_report("Getting friend ids from Myspace...\n");
            my @current_friends = $self->myspace->get_friends;
        
            $self->_report( "List finished.  Tossing out matches...\n");
            
            # accelerated means that no sorting takes place
            my $lc = List::Compare->new(
                {
                    lists => [ \@current_friends, \@potential_friends],
                    accelerated => 1,
                }
            );
    
            @unique_ids = $lc->get_complement;
        
        }
       
        # assemble some stats
        my $future      = @potential_friends;
        my $unique      = @unique_ids;
        my $shared      = $future - $unique;
        my $finish_time = time();
        my $total_time  = $finish_time - $start_time;
    
        $self->_report("$total_time seconds to exclude duplicates.\n");
        $self->_report("$future ids supplied by you.\n");
        $self->_report("$shared friends excluded.\n");
        $self->_report("$unique unique ids.\n");
            
        @potential_friends = @unique_ids;

    }

    # no need to report if no matches found
    if ( @potential_friends ) {
        $self->_report("Beginning to process the ids...\n");
    }
    else {
        $self->_report("No ids to process.  No report will display.\n");
    }
    
    my $skipped = 0;
    
    FRIEND:
    foreach my $id (@potential_friends) {
        
        ++$count;
        
        if ( $self->{'data'} ) {
            unless ( $self->{'data'}->is_cached( $id ) ) {
                $self->{'data'}->cache_friend( $id );
            }
        }
        
        # throw out unwanted profiles
        if ( $self->{'profile_type'} ) {
            
            my $skip_profile = undef;
        
            if (    $self->{'profile_type'} eq 'band'
                && !$self->is_band( $id  ) )
            {
                $skip_profile = 'personal';
            }
            
            elsif ( $self->{'profile_type'} eq 'personal'
                &&  $self->is_band( $id  ) )
            {
                $skip_profile = 'band';
            }        
        
            if ( $skip_profile ) {
        
                $self->_report("$count)\t$id\tSkipping ");
                $self->_report("$skip_profile page.");
                
                # sleep only if the data was not pulled from the cache
                if ( $self->{'data'} ) {
                
                    my $last_id = $self->{'data'}->get_last_lookup_id;
                    
                    if ( $last_id && $last_id == $id ) {
                        $self->_sleep_now();
                    }
                    else {
                        $self->_report(" From cache. Continuing.\n");
                    }
                }
                else {
                    $self->_sleep_now();
                }
                ++$skipped;
                next FRIEND;
            }
        }
        
        if ( $self->{'last_login'} && 
             $self->myspace->last_login( $id ) &&
             $self->myspace->last_login < time - $self->{'last_login'} * 86400 ) {
             
             my $days = int( (time() - $self->myspace->last_login) / 86400);
             $self->_report("$count)\t$id\tSkipping ");
             $self->_report("\tLast login $days days ago.");
             $self->_sleep_now();
             next FRIEND;
        }
        
        # send requests individually
        my ( $status_code, $status ) =
            $self->myspace->send_friend_request( $id );
            
        ++$adds if ( $status_code eq 'P' );

        # if there's a db connection and the person is already
        # listed as a friend, we need to make sure they have
        # been added to the table
        if ( $self->{'data'} && $status_code eq 'FF' ) {
            $self->{'data'}->update_friend( $id );        
        }
	if ( $status_code eq 'F' ) {

            #open ("TEST", ">test.html");
            #    my $mech = $self->{'myspace'}->mech;
            #    print TEST $mech->content;
            #close ("TEST");

            #`$self->{'firefox'} test.html`;

        }
        
        elsif ( $status_code eq 'FC' ) {

            if ( $self->{'message_on_captcha'} ) {

                # You can reset the CAPTCHA just by sending a message
                # try sending a test message before reporting a problem
                my $send_to_id = 48449904;

                if ( $self->{'message_on_captcha'} > 1 ) {
                    $send_to_id = $self->{'message_on_captcha'};
                }

                $self->myspace->send_message( 
                    $send_to_id, 
                    'Hello',
                    'Just saying hi!', 
                    0, 
                );

                ( $status_code, $status ) =
                  $self->myspace->add_to_friends($id);
                ++$adds if ( $status_code eq 'P' );
                ++$captcha;

                $self->_report("message_on_captcha attempt...\n");

            }
            
            if ( $status_code eq 'FC' && $self->{'sleep_on_captcha'} ) {
                
                # sleep for the given number of seconds here
                if ( $self->{'interactive'} ) {
                    
                    $self->_report("sleep_on_captcha attempt...\n"); 
                    
                    my $progress = Term::ProgressBar->new({
                        name  => 'sleep_on_captcha',
                        count => $self->{'sleep_on_captcha'},
                        ETA   => 'linear',
                    });

                    # display progress bar...
                    foreach ( 1 .. $self->{'sleep_on_captcha'} ) {
                        sleep 1;
                        $progress->update( $_ );
                    }
                }
                else {
                    sleep $self->{'sleep_on_captcha'};
                }
                
                ($status_code, $status) = $self->myspace->add_to_friends($id);
                ++$adds if ( $status_code eq 'P' );
                ++$captcha;

            }

            if ( $status_code eq 'FC' && $self->{'interactive'} ) {

                if ( $self->{'firefox'} ) {

                    print 'Please fill out the CAPTCHA response using the ';
                    print 'page that has been opened in your Firefox browser';
                    print "\n\n";
                    
                    `$self->{'firefox'} "http://collect.myspace.com/index.cfm?fuseaction=invite.addfriend_verify&friendID=$id"`;
                }
                else {

                    print 'CAPTCHA response.  Please fill in the form at ';
                    print "the following url before continuing:\n\n";
                    print 'http://collect.myspace.com/index.cfm?fuseaction';
                    print "=invite.addfriend_verify&friendID=$id\n\n";

                }

                $continue = prompt "Continue? (y/n) ", -onechar, -yn;

                if ($continue) {

                    print "Continuing...\n";
               	    ( $status_code, $status ) = $self->myspace->add_to_friends($id);

                    # if the CAPTCHA response was correct, an "FP" will be returned
                    ++$adds if ( $status_code eq 'P' || $status_code eq 'FP' );

                }

                else {
                    print "Exiting nicely.  Wait for the report...\n";
                    last;
                }

            }

            elsif ( $self->{'interactive'} ) {
                $continue = undef;
                $self->_report("Exiting nicely...");
                last;
            }

        }

        push ( @{ $code_report{$status_code} }, $id );

        # build hash of status codes for final report
        $codes{$status_code} = $status;
        $self->_report("$count)\t$id:\t$status ($status_code) ");
        
        if ( $self->{'data'} ) {
            
            my $account_id = $self->{'data'}->get_account();
            
            # create or update the entry in post_log
            my $friend_obj = WWW::Myspace::Data::PostLog->find_or_create(
                { 
                post_type  => 'A', 
                account_id => $account_id, 
                friend_id  => $id 
                }
            );
            
            my $date_stamp = $self->{'data'}->date_stamp( 
                    { time_zone => $self->{'time_zone'}, } 
            );
            
            # set an update time
            $friend_obj->last_post( $date_stamp );            
            $friend_obj->result_code( $status_code );
            $friend_obj->update;
            
            $self->_report( "added to log ");
            
        }
        
        # if there is still an FC status, 
        # it will have to be dealt with manually
        
        if ( $status_code eq 'FC' ) {

            # if reporting is disabled, we'll just have to exit 
            # silently here
            unless ( $self->{'interactive'} ) {
                last;
            }

            else {

                print 'CAPTCHA response.  Please fill in the form at ';
                print "the following url before continuing:\n\n";
                print 'http://collect.myspace.com/index.cfm?fuseaction';
                print "=invite.addfriend_verify&friendID=$id\n\n";
                
                $continue = prompt "Continue? (y/n) ", -onechar, -yn;

                if ($continue) {
                    print "Continuing...\n";
                }
                else {
                    print "Exiting nicely.  Wait for the report...\n";
                    last;
                }
            }
        }

        if ( $adds >= $self->{'max_count'} ) {
            $continue = undef;
            $self->_report("\n\nMax attempts ($self->{'max_count'}) ");
            $self->_report("reached. Exiting nicely...\n\n");
            last;
        }
        
        if ( $status_code eq 'FE' ) {
            $self->_report("\n\nDaily usage exceeded. Exiting...\n\n");
            $continue = undef;
            last;
        }

        # don't sleep if we're just going to print the report
        if ($continue) {
            $self->_sleep_now();
        }

    }

    if ( $self->{'interactive'} && @potential_friends ) {

        print "Final status report...\n\n######################\n";
        
        if ($captcha) {
            print "$captcha 'message on captcha' attempts\n";
        }
        
        if ($skipped) {
            print "$skipped profiles skipped\n";
        }

        foreach my $response_code ( keys %code_report ) {

            my $results = @{ $code_report{$response_code} };

            print "$results $codes{$response_code} ($response_code)\n";

        }

    }

    return \%code_report;
}

=head2 add_to_friends( @friend_ids)

Convenience method - same as send_friend_requests.

=cut

sub add_to_friends {

    $self->send_friend_requests( @_ );
    
}

=head2 is_band()

If a L<WWW::Myspace::Data> object exists, returns the value of $data->is_band 
Otherwise, returns the value of $myspace->is_band

=cut


sub is_band {

    my $friend_id = shift;
    
    if ( $self->{'data'} ) {
        return $self->{'data'}->is_band( $friend_id );
    }
    else {
        return $self->myspace->is_band( $friend_id );
    }
    
}

=head2 return_params( )

Useful for testing whether your params have been set as expected.

    my $param_ref = $adder->return_params();

=cut

sub return_params {

    my %params = ( );
    
    foreach my $key ( keys %{ $self->default_options } ) {
        $params{$key} = $self->{$key};
    }
    
    return \%params;

}

=head2 get_data_object( )

Returns a valid L<WWW::Myspace::Data> object if one can be initialized by
the WWW::Myspace::FriendAdder object.  This method will croak if no
object can be created. This is a handy shortcut if you're using
WWW::Myspace::Data in conjunction with FriendAdder.pm but don't want  to
go to the trouble of creating the L<WWW::Myspace::Data> object yourself.  Just
remember to install L<WWW::Myspace::Data> first.

    my $data = $adder->get_data_object();
    if ( $data ) {
        my @friends = $data->friends_from_profile(...);
    }

=cut

sub get_data_object {

    unless ( $self->{'data'} ) { 
        
        require WWW::Myspace::Data;
        
        my $data = WWW::Myspace::Data->new( 
            $self->{myspace}, 
            { 
                db        => $self->{'db'}, 
                time_zone => $self->{'time_zone'}, 
            }
        );
        
        $self->{'data'} = $data;
        
        # check to see if we can access the db
        $self->{'loader'} = $data->loader();
    
        unless ( $self->{'loader'} ) {
            croak ( "no database access" );
        }
    
    }
        
    return $self->{'data'};
    
}

=head2 _report( )

Internal method.  If the interactive switch is on, this will print.  If
it's not, well you can probably guess.

=cut

sub _report {

    if ( $self->{'interactive'} ) {
        print @_;
    }
}

=head2 _sleep_now( )

Internal method that handles sleeping between requests.

=cut

sub _sleep_now {

    my $sleep_now = $self->{'sleep'};

    if ( $self->{'random_sleep'} ) {
        $sleep_now = int( rand( $self->{'sleep'} ) );
    }

    $self->_report("\n\t\t\t");
    $self->_report("Sleeping for $sleep_now seconds...\n");
    sleep $sleep_now;
    
}

=head2 _die_pretty( )

Internal method that deletes the Myspace object from $self and then
prints $self via Data::Dumper.  The Myspace object is so big, that when
you get it out of the way it can be easier to debug set parameters.

    $adder->_die_pretty;

=cut

sub _die_pretty {
 
     delete $self->{'myspace'};
     die Dumper(\$self);
}


=head1 AUTHOR

Olaf Alders, C<< <olaf at wundersolutions.com> >> inspired by the
excellent code of Grant Grueninger

=head1 BUGS

Please report any bugs or feature requests to
C<bug-www-myspace-friendadder at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Myspace-FriendAdder>.
I will be notified, and then you'll automatically be notified of
progress on your bug as I make changes.

=head1 NOTES

This module has been stable for some time.  Myspace, however, is not.  I've 
written this code to suit my own needs.  If it does not suit all of yours, 
patches are very welcome.

=head1 HOW TO SUBMIT A PATCH

Please see the HOW TO SUBMIT A PATCH section of L<WWW::Myspace> for a quick
set of instructions on how to get your patch included in a coming 
distribution.

=head1 TO DO

Right now the adder won't deal with FU CAPTCHA pages.  That's fine for my 
purposes, so if you need that functionality, please open a ticket.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Myspace::FriendAdder

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Myspace-FriendAdder>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Myspace-FriendAdder>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Myspace-FriendAdder>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Myspace-FriendAdder>

=back

=head1 ACKNOWLEDGEMENTS

Many thanks to Grant Grueninger for giving birth to L<WWW::Myspace> and for
his help and advice in the development of this module.  

Thanks to Jason A. Ramsey (jason AT eramsey.org) for his contribution of the  
sleep_on_captcha code:
L<http://rt.cpan.org/Ticket/Display.html?id=19808>

=head1 COPYRIGHT & LICENSE

Copyright 2006-2007 Olaf Alders, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut


1;    # End of WWW::Myspace::FriendAdder
