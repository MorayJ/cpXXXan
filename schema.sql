CREATE TABLE modules (
    module          VARCHAR(256),
    modversion      VARCHAR(24),
    normmodversion  VARCHAR(24),
    dist            VARCHAR(256),
    distversion     VARCHAR(24)
) ENGINE = 'InnoDB';
CREATE        INDEX modules_distdistversion on modules(dist, distversion);

CREATE TABLE dists (
    dist        VARCHAR(256),
    distversion VARCHAR(24),
    file        VARCHAR(256)
) ENGINE = 'InnoDB';

CREATE TABLE passes (
    dist            VARCHAR(256),
    distversion     VARCHAR(24),
    normdistversion VARCHAR(24),
    perl            VARCHAR(8),
    osname          VARCHAR(16)
) ENGINE = 'InnoDB';

CREATE        INDEX pass_normdistversion ON passes(normdistversion);
CREATE        INDEX pass_dist            ON passes(dist);
CREATE        INDEX pass_distversion     ON passes(distversion);
CREATE        INDEX pass_perl            ON passes(perl);
CREATE        INDEX pass_osname          ON passes(osname);

CREATE UNIQUE INDEX passes_uniq_dist_distversion_perl_osname ON passes (dist, distversion, perl, osname);

CREATE UNIQUE INDEX dists_idx ON dists(dist, distversion);
CREATE UNIQUE INDEX modules_idx ON modules(module, modversion, dist, distversion);
CREATE UNIQUE INDEX files_idx ON dists(file);
