#!/usr/bin/env bash

export PATH=~/.pyenv/shims:~/.pyenv/bin:"$PATH"


~/src/darts/bin/genSite2016-2017.pl --file data/Austerlitz_seizoen_2019-2020.xlsx --updatesite

python ~/src/darts/bin/sva_darts_init.py
python ~/src/darts/bin/sva_darts_calc.py
python ~/src/darts/bin/sva_darts_gen_json.py
