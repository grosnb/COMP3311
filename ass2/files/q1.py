#!/usr/bin/env python3
import sys
import psycopg2

from helpers import get_faculties, get_faculty_schools, get_faculty_staff

def main():
    conn = psycopg2.connect(dbname="mymyunsw")
    cur = conn.cursor()

    # List of tuples: (faculty_code, faculty_name)
    faculties = get_faculties(conn)
    
    print(f"Faculty                                 #Schools #Staff")
    for faculty in faculties:
        schools = get_faculty_schools(conn, faculty[0])
        staff = get_faculty_staff(conn, faculty[0])
        print(f"{faculty[1]:<40}{len(schools):>8}{len(staff):>7}")

    cur.close()
    conn.close()

if __name__ == "__main__":
    main()