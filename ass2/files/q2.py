#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import psycopg2

from helpers import get_longest_run_string

def main():
    if len(sys.argv) != 2:
        print("Usage: ./q2.py <SubjectCode>")
        sys.exit(1)
    subject_code = sys.argv[1]

    conn = psycopg2.connect(dbname="mymyunsw")
    cur = conn.cursor()

    longest_run = get_longest_run_string(conn, subject_code)

    print(f"{longest_run}")

    cur.close()
    conn.close()

if __name__ == "__main__":
    main()