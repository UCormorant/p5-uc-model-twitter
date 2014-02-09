use t::Util;
use Test::More;
use Test::More::Hooks;
use Test::Exception;
use Test::Mock::Guard;
use Scope::Guard qw(scope_guard);
use Capture::Tiny qw(capture_merged);
use File::Basename qw(basename);

use Uc::Model::Twitter::Crawler;

sub local_term (&@) {
    my $block = shift;
    local *STDIN;
    local *STDOUT;
    local *STDERR;
    local(@ARGV) = @_;
    capture_merged {
        Uc::Model::Twitter::Crawler->new( configure_encoding => 1 );
        $block->(@ARGV);
    };
}

plan tests => 1;

subtest 'ucrawl-tweet' => sub {
    my $class;
    my $script_file = basename($0);

    before { $class = Uc::Model::Twitter::Crawler->new(); };
    after  { undef $class; };

    plan tests => 2;

    subtest('$class->can' => sub {
        plan tests => 8;
        isa_ok $class, 'Uc::Model::Twitter::Crawler', '$class';

        can_ok $class, $_ for qw(
            conf
            user
            fav
            mention
            status

            run
            crawl
        );
    }) or return; # stop test unless all method can be called

    subtest 'run' => sub {
        plan tests => 7;
        isa_ok $class, 'Uc::Model::Twitter::Crawler', '$class';

        subtest 'no commnad' => sub {
            plan tests => 4;

            my (@args, $output);

            @args = ();
            $output = local_term { $class->run(@_); } @args;
            like $output, qr/^Usage: $script_file/, 'show help';
            like $output, qr/--version/, 'help text says about -v option';

            @args = qw(-v);
            $output = local_term { $class->run(@_); } @args;
            like $output, qr/@{[$class->VERSION]}/, '-v shows version';

            @args = qw(--version);
            $output = local_term { $class->run(@_); } @args;
            like $output, qr/@{[$class->VERSION]}/, '--version shows version';
        };

        subtest 'command conf' => sub {
            TODO: { local $TODO = 'later';
            plan qw(no_plan); pass;

            my (@args, $output);

            @args = ();
            $output = local_term { $class->run(@_); } @args;
            }
        };

        subtest 'command user' => sub {
            TODO: { local $TODO = 'later';
            plan qw(no_plan); pass;

            my (@args, $output);

            @args = ();
            $output = local_term { $class->run(@_); } @args;
            }
        };

        subtest 'command fav' => sub {
            TODO: { local $TODO = 'later';
            plan qw(no_plan); pass;

            my (@args, $output);

            @args = ();
            $output = local_term { $class->run(@_); } @args;
            }
        };

        subtest 'command mention' => sub {
            TODO: { local $TODO = 'later';
            plan qw(no_plan); pass;

            my (@args, $output);

            @args = ();
            $output = local_term { $class->run(@_); } @args;
            }
        };

        subtest 'command status' => sub {
            TODO: { local $TODO = 'later';
            plan qw(no_plan); pass;

            my (@args, $output);

            @args = ();
            $output = local_term { $class->run(@_); } @args;
            }
        };
    };
};

done_testing;
