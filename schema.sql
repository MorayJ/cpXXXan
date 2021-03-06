-- cpxxxan database

CREATE TABLE cache (
    `key`   VARCHAR(32),
    `value` VARCHAR(32),
    PRIMARY KEY (`key`)
) ENGINE = 'InnoDB';

CREATE TABLE modules (
    module          VARCHAR(256),
    modversion      VARCHAR(24),
    normmodversion  VARCHAR(24),
    dist            VARCHAR(256),
    distversion     VARCHAR(24)
) ENGINE = 'InnoDB';
CREATE INDEX modules_distdistversion on modules(dist, distversion);

CREATE TABLE dists (
    dist        VARCHAR(256),
    distversion VARCHAR(24),
    file        VARCHAR(256),
    filetimestamp DATETIME
) ENGINE = 'InnoDB';
CREATE INDEX dists_filetimestamp ON dists(filetimestamp);

CREATE TABLE passes (
    dist            VARCHAR(256),
    distversion     VARCHAR(24),
    normdistversion VARCHAR(24),
    perl            VARCHAR(8),
    osname          VARCHAR(16)
) ENGINE = 'InnoDB';
CREATE INDEX pass_normdistversion ON passes(normdistversion);
CREATE INDEX pass_dist            ON passes(dist);
CREATE INDEX pass_distversion     ON passes(distversion);
CREATE INDEX pass_perl            ON passes(perl);
CREATE INDEX pass_osname          ON passes(osname);

CREATE UNIQUE INDEX passes_uniq_dist_distversion_perl_osname ON passes (dist, distversion, perl, osname);

CREATE UNIQUE INDEX dists_idx ON dists(dist, distversion);
CREATE UNIQUE INDEX modules_idx ON modules(module, modversion, dist, distversion);
CREATE UNIQUE INDEX files_idx ON dists(file);

-- cpantesters database

CREATE TABLE `cpanstats` (
  `id` int(11) NOT NULL,
  `guid` varchar(32) DEFAULT NULL,
  `state` varchar(16) DEFAULT NULL,
  `dist` varchar(128) DEFAULT NULL,
  `version` varchar(32) DEFAULT NULL,
  `perl` varchar(32) DEFAULT NULL,
  `platform` varchar(32) DEFAULT NULL,
  `osname` varchar(64) DEFAULT NULL,
  `osvers` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
