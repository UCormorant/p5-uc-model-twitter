requires 'DateTime::Format::HTTP';
requires 'DateTime::Format::MySQL';
requires 'Teng';
requires 'Teng::Plugin::DBIC::ResultSet';
requires 'perl', '5.014';

on build => sub {
    requires 'ExtUtils::MakeMaker', '6.59';
    requires 'Test::More', '0.98';
};
