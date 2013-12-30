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
    my %option = (
        if_not_exists => 1,
        @_,
    );

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
