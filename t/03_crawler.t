use t::Util;
use Test::More;
use Test::More::Hooks;
use Test::Exception;
use Scope::Guard qw(scope_guard);

use Uc::Model::Twitter::Crawler;

plan tests => 1;

subtest "ucrawl-tweet" => sub {
    my $class;
    before { $class = Uc::Model::Twitter::Crawler->new(); };
    after  { undef $class; };

    plan tests => 1;

    subtest("\$class->can" => sub {
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

};

done_testing;
