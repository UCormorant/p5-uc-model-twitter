requires 'perl', '5.014';
requires 'Teng';
requires 'Teng::Plugin::DBIC::ResultSet';
requires 'DateTime::Format::HTTP';
requires 'DateTime::Format::MySQL';

on test => sub {
    requires 'Test::More', '0.98';
    requires 'Clone';
    requires 'DBD::SQLite';

    recommends 'Test::mysqld';
};
