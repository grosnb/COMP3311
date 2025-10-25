#!/usr/bin/env python3
import sys
import re
import psycopg2
from helpers import (get_student, get_program, get_stream, get_scode_from_pcode,
    is_valid_stream, get_requirements, get_student_courses, find_match,
    course_formatter, get_course_uoc, get_wam_summary, get_course_name)

def main():
    argc = len(sys.argv)
    if argc < 2:
      print(f"Usage: {sys.argv[0]} zID [Program Stream]")
      exit(1)
    zid = sys.argv[1]
    if zid[0] == 'z':
        zid = zid[1:8]
    digits = re.compile("^\d{7}$")
    if not digits.match(zid):
        print("Invalid zID")
        exit(1)

    prog_code = None
    strm_code = None

    if argc >= 3:
        prog_code = sys.argv[2]
    if argc >= 4:
        strm_code = sys.argv[3]

    conn = psycopg2.connect("dbname=mymyunsw")
    cur = conn.cursor()
    
    # (id, zid, family_name, given_names, full_name, origin)
    stu_info = get_student(conn,zid)
    if not stu_info:
        print(f"Invalid student id {zid}")
        exit(1)

    # prog_info: (id, code, name)
    prog_info = get_program(conn, prog_code, stu_info[0])
    if not prog_info:
        print(f"Invalid program code {prog_code}")
        exit(1)

    # strm_info: (id, code, name)
    strm_info = None
    if not strm_code:
        strm_code = get_scode_from_pcode(conn, prog_info[1])
        
    strm_info = get_stream(conn, strm_code)    
    if not strm_info:
        print(f"Invalid stream code {strm_code}")
        exit(1)

    # zID FamilyName, GivenNames
    print(f"{stu_info[1]} {stu_info[2]}, {stu_info[3]}")
    # ProgramCode StreamCode ProgramName
    print(f"{prog_info[1]} {strm_info[1]} {prog_info[2]}")

    if argc >= 4 and not is_valid_stream(conn, strm_info[1], prog_info[1]):
        print(f"{strm_code} is not a stream in {prog_code}")
        exit(1)

    # course tups: (code, term, title, mark, grade, uoc)
    courses = get_student_courses(conn, stu_info[0])

    # req tups: (id, name, rtype, req, acadobjs)
    reqs = get_requirements(conn, strm_info[1], prog_info[1])
    stream_uoc = 0
    for course in courses:
        course_code = course[0]
        c_uoc = get_course_uoc(conn, course_code)
        course_req = None
        acadobj_remove = None
        course_info = course_formatter(course)
        if 'uoc' not in course_info:
            print(course_info)
            continue
        for req in reqs:
            if req[3] == 0:
                continue
            acadobjs = req[4]
            for obj_code in acadobjs:
                match = find_match(obj_code, course_code)
                if match:
                    course_req = req[1]
                    acadobj_remove = obj_code
                    break
            if course_req:
                if '#' not in acadobj_remove:
                    req[4].remove(acadobj_remove)
                if req[3]:
                    req[3] -= c_uoc
                stream_uoc += c_uoc
                break
        if not course_req:
            course_info = re.sub(r'\duoc', '0uoc', course_info)
            course_req = "Could not be allocated"
        course_info += f"  {course_req}"
        print(course_info)
    
    wam = get_wam_summary(conn, stu_info[0])
    if not wam:
        print(f"Error fetching wam summary")
    if wam[1]:
        print(f"UOC done for this program and stream = {stream_uoc}, WAM = {wam[1]:0.3f}")
    else:
        print(f"UOC done for this program and stream = {stream_uoc}, Can't compute WAM")

    grad_flag = True
    for req in reqs:
        if len(req[4]) == 0 or req[3] == 0:
            continue
        grad_flag = False
        needed_uoc = req[3] or 0
        missing_objs = ""
        if req[2] == 'core':
            for acadobj in req[4]:
                obj_codes = re.escape(acadobj).replace(r'\{', '').replace(r'\}', '').split(';')
                needed_uoc += get_course_uoc(conn, obj_codes[0])
                missing_objs += f"\n- {obj_codes[0]} {get_course_name(conn, obj_codes[0])}"
                for obj_code in obj_codes[1:]:
                    missing_objs += f"\n  or {obj_code} {get_course_name(conn, obj_code)}"

        print(f"Need {needed_uoc} more UOC for {req[1]}{missing_objs}")
    
    if grad_flag:
        print("Eligible to graduate")
            

    cur.close()
    conn.close()
if __name__ == "__main__":
    main()




