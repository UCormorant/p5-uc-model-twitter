use strict;
use Test::More;
eval q{
    use Test::Perl::Critic 1.02 -exclude => [qw/
        Subroutines::ProhibitSubroutinePrototypes
        Subroutines::ProhibitExplicitReturnUndef
        TestingAndDebugging::RequireUseStrict
        TestingAndDebugging::ProhibitNoStrict
        ControlStructures::ProhibitMutatingListFunctions
        InputOutput::ProhibitInteractiveTest
    /]
};
plan skip_all => "Test::Perl::Critic 1.02+ is not installed" if $@;
all_critic_ok('lib');
