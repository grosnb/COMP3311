#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import re
import psycopg2

from helpers import filter_subjects

def main():
    if len(sys.argv) != 2:
        print("Usage: ./q4.py <filter_expr>")
        sys.exit(1)

    filter_expr = sys.argv[1]

    conn = psycopg2.connect(dbname="mymyunsw")

    cur = conn.cursor()
    try:
        # tuples of: (code, title, uoc, career)
        subjects = filter_subjects(conn, filter_expr)
    except Exception as e:
        print(str(e))
        exit(1)

    if not subjects:
        print("There are no subjects that match the conditions")
    else:
        print(f"{'Code':<10}{'Title':<55}{'UoC':>5}{'Career':>10}")
        for s in subjects:
            title = s[1]
            if len(title) > 55:
                title = title[:52] + "..."
            print(f"{s[0]:<10}{title:<55}{s[2]:>5}{s[3]:>10}")

    cur.close()
    conn.close()

if __name__ == "__main__":
    main()