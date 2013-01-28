package Uc::Model::Twitter::Util::MySQL;

use 5.014;
use warnings;
use utf8;
use parent 'Exporter';

our @EXPORT = qw(
    create_table_mysql
    drop_table_mysql
);

our %SQL = (
    status        => q{
CREATE TABLE `status` (
  `id`                      bigint unsigned NOT NULL,
  `created_at`              datetime        NOT NULL DEFAULT '0000-00-00 00:00:00',
  `user_id`                 bigint unsigned NOT NULL DEFAULT '0',
  `profile_id`              varchar(32)     NOT NULL DEFAULT '',
  `text`                    text            NOT NULL,
  `source`                  text            ,
  `in_reply_to_status_id`   bigint unsigned DEFAULT NULL,
  `in_reply_to_user_id`     bigint unsigned DEFAULT NULL,
  `in_reply_to_screen_name` tinytext        ,
  `retweeted_status_id`     bigint unsigned DEFAULT NULL,
  `protected`               boolean         DEFAULT NULL,
  `truncated`               boolean         DEFAULT NULL,
  `statuses_count`          int unsigned    DEFAULT NULL,
  `favourites_count`        int unsigned    DEFAULT NULL,
  `friends_count`           int unsigned    DEFAULT NULL,
  `followers_count`         int unsigned    DEFAULT NULL,
  `listed_count`            int unsigned    DEFAULT NULL,
  PRIMARY KEY (`id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
/*!50500 PARTITION BY RANGE  COLUMNS(created_at)
(PARTITION p2007_1 VALUES LESS THAN ('2007-04-01') ENGINE = InnoDB,
 PARTITION p2007_2 VALUES LESS THAN ('2007-07-01') ENGINE = InnoDB,
 PARTITION p2007_3 VALUES LESS THAN ('2007-10-01') ENGINE = InnoDB,
 PARTITION p2007_4 VALUES LESS THAN ('2008-01-01') ENGINE = InnoDB,
 PARTITION p2008_1 VALUES LESS THAN ('2008-04-01') ENGINE = InnoDB,
 PARTITION p2008_2 VALUES LESS THAN ('2008-07-01') ENGINE = InnoDB,
 PARTITION p2008_3 VALUES LESS THAN ('2008-10-01') ENGINE = InnoDB,
 PARTITION p2008_4 VALUES LESS THAN ('2009-01-01') ENGINE = InnoDB,
 PARTITION p2009_1 VALUES LESS THAN ('2009-04-01') ENGINE = InnoDB,
 PARTITION p2009_2 VALUES LESS THAN ('2009-07-01') ENGINE = InnoDB,
 PARTITION p2009_3 VALUES LESS THAN ('2009-10-01') ENGINE = InnoDB,
 PARTITION p2009_4 VALUES LESS THAN ('2010-01-01') ENGINE = InnoDB,
 PARTITION p2010_1 VALUES LESS THAN ('2010-04-01') ENGINE = InnoDB,
 PARTITION p2010_2 VALUES LESS THAN ('2010-07-01') ENGINE = InnoDB,
 PARTITION p2010_3 VALUES LESS THAN ('2010-10-01') ENGINE = InnoDB,
 PARTITION p2010_4 VALUES LESS THAN ('2011-01-01') ENGINE = InnoDB,
 PARTITION p2011_1 VALUES LESS THAN ('2011-04-01') ENGINE = InnoDB,
 PARTITION p2011_2 VALUES LESS THAN ('2011-07-01') ENGINE = InnoDB,
 PARTITION p2011_3 VALUES LESS THAN ('2011-10-01') ENGINE = InnoDB,
 PARTITION p2011_4 VALUES LESS THAN ('2012-01-01') ENGINE = InnoDB,
 PARTITION p2012_1 VALUES LESS THAN ('2012-04-01') ENGINE = InnoDB,
 PARTITION p2012_2 VALUES LESS THAN ('2012-07-01') ENGINE = InnoDB,
 PARTITION p2012_3 VALUES LESS THAN ('2012-10-01') ENGINE = InnoDB,
 PARTITION p2012_4 VALUES LESS THAN ('2013-01-01') ENGINE = InnoDB,
 PARTITION p2013_1 VALUES LESS THAN ('2013-04-01') ENGINE = InnoDB,
 PARTITION p2013_2 VALUES LESS THAN ('2013-07-01') ENGINE = InnoDB,
 PARTITION p2013_3 VALUES LESS THAN ('2013-10-01') ENGINE = InnoDB,
 PARTITION p2013_4 VALUES LESS THAN ('2014-01-01') ENGINE = InnoDB,
 PARTITION platest VALUES LESS THAN (MAXVALUE) ENGINE = InnoDB) */
    },
    user          => q{
CREATE TABLE `user` (
  `id`                                 bigint unsigned NOT NULL,
  `profile_id`                         varchar(32)     NOT NULL,
  `screen_name`                        tinytext        NOT NULL,
  `name`                               tinytext        NOT NULL,
  `location`                           tinytext        NOT NULL,
  `url`                                tinytext        NOT NULL,
  `description`                        text            NOT NULL,
  `lang`                               tinytext        NOT NULL,
  `time_zone`                          tinytext        NOT NULL,
  `utc_offset`                         mediumint       NOT NULL DEFAULT '0',
  `profile_image_url`                  text            NOT NULL,
  `profile_image_url_https`            text            NOT NULL,
  `profile_background_image_url`       text            NOT NULL,
  `profile_background_image_url_https` text            NOT NULL,
  `profile_banner_url`                 text            NOT NULL,
  `profile_text_color`                 varchar(8)      NOT NULL DEFAULT '',
  `profile_link_color`                 varchar(8)      NOT NULL DEFAULT '',
  `profile_background_color`           varchar(8)      NOT NULL DEFAULT '',
  `profile_sidebar_fill_color`         varchar(8)      NOT NULL DEFAULT '',
  `protected`                          boolean         NOT NULL DEFAULT '0',
  `geo_enabled`                        boolean         NOT NULL DEFAULT '0',
  `verified`                           boolean         NOT NULL DEFAULT '0',
  `is_translator`                      boolean         NOT NULL DEFAULT '0',
  `contributors_enabled`               boolean         NOT NULL DEFAULT '0',
  `default_profile`                    boolean         NOT NULL DEFAULT '0',
  `default_profile_image`              boolean         NOT NULL DEFAULT '0',
  `profile_use_background_image`       boolean         NOT NULL DEFAULT '0',
  `profile_background_tile`            boolean         NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`,`profile_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    },
    remark        => q{
CREATE TABLE `remark` (
  `id`        bigint unsigned NOT NULL,
  `user_id`   bigint unsigned NOT NULL,
  `favorited` boolean         NOT NULL DEFAULT '0',
  `retweeted` boolean         NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`,`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    },
    profile_image => q{
CREATE TABLE `profile_image` (
  `url`   text       NOT NULL,
  `image` mediumblob NOT NULL,
  PRIMARY KEY (`url`(100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    },
);

sub create_table_mysql {
    my $class = shift;
    my %option = @_;
    my %sql = %SQL;
    if ($option{if_not_exists}) {
        my $dbh = $class->dbh;
        my $sth = $dbh->prepare(q{SHOW TABLES}); $sth->execute();
        my @defined_table = grep { defined $sql{$_} } map { $_->[0] } @{$sth->fetchall_arrayref};
        delete $sql{$_} for @defined_table;
    }
    else {
        drop_table_mysql($class);
    }

    for my $table (keys %sql) {
        $class->execute($sql{$table});
    }
}

sub drop_table_mysql {
    shift->execute(sprintf q{DROP TABLE IF EXISTS %s}, join ', ', scalar @_ ? @_ : keys %SQL);
}

1; # Magic true value required at end of module
__END__

=head1 NAME

Uc::Model::Twitter::Util::MySQL - [One line description of module's purpose here]


=head1 VERSION

This document describes Uc::Model::Twitter::Util::MySQL


=head1 SYNOPSIS

    use Uc::Model::Twitter::Util::MySQL;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
Uc::Model::Twitter::Util::MySQL requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-uc-twetter-schema@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

U=Cormorant  C<< <u@chimata.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2012, U=Cormorant C<< <u@chimata.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
