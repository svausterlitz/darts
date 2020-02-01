#!/usr/bin/env bash

export PATH=~/.pyenv/shims:~/.pyenv/bin:"$PATH"

python ~/src/darts/bin/sva_darts_init.py
python ~/src/darts/bin/sva_darts_calc.py
python ~/src/darts/bin/sva_darts_gen_json.py
