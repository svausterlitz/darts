#!/usr/bin/env bash

export PATH=~/.pyenv/shims:~/.pyenv/bin:"$PATH"

python ~/src/dartsense/bin/sva_darts_init.py
python ~/src/dartsense/bin/sva_darts_calc.py
python ~/src/dartsense/bin/sva_darts_gen_json.py
