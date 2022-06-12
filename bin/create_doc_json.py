#!/usr/bin/env python

import pandas as pd
import numpy as np
import sys
import os

"""
script om de (oude) excelbestanden om te zetten naar een bruikbaar json-formaat
"""


def parse_excel(filename):
    df = pd.read_excel(filename)
    print(df.size)


def main(argv):
    datadir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "data"))
    directory = os.scandir(datadir)
    for file in directory:
        filename = file.path
        # filename = os.fsdecode(file)
        if filename.endswith(".xlsx"):
            parse_excel(filename)
        # elif filename.endswith(".csv"):
        #     print("csv", filename)


if __name__ == "__main__":
    main(sys.argv[1:])
