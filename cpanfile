requires 'perl', '5.014';
requires 'experimental', '0.006';
requires 'namespace::clean', '0.24';
requires 'Teng';
requires 'Teng::Plugin::DBIC::ResultSet'; # not on CPAN
requires 'DateTime::Format::HTTP';
requires 'DateTime::Format::MySQL';

# for ucrawl-tweet
requires 'Encode::Locale', '1.03';
requires 'File::HomeDir', '1.00';
requires 'Net::OAuth', '0.26';
requires 'Net::Twitter::Lite', '0.12006';
requires 'Smart::Options', '0.053';
requires 'Term::ReadKey', '2.31';
requires 'TOML', '0.92';

on test => sub {
    requires 'Test::More', '0.98';
    requires 'Test::More::Hooks', '0.12';
    requires 'Test::Exception', '0.32';
    requires 'DBD::SQLite';

    recommends 'Test::mysqld', '0.17';
};
