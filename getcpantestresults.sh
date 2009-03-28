#!/bin/sh
wget -q -O db/cpanstatsdatabase.gz http://devel.cpantesters.org/cpanstats.db.gz
gzip -dc db/cpanstatsdatabase.gz > db/cpanstatsdatabase

