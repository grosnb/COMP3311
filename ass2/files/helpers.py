# COMP3311 21T3 Ass2 ... Python helper functions
# add here any functions to share between Python scripts 
# you must submit this even if you add nothing

import queue
import re
from pyparsing import (Word, alphanums, infix_notation, one_of, opAssoc,
    quotedString, removeQuotes)

################################################################################
### MARK: QUESTION 1
################################################################################

# Returns a list of faculties represented by tuples:
#   (faculty_code, faculty_name)
def get_faculties(db):
    cur = db.cursor()
    qry = """
    SELECT      o.code, o.name
    FROM        Orgunits o
    WHERE       o.utype = 'faculty'
    ORDER BY    o.name
    """
    l = []
    cur.execute(qry)
    for tup in cur.fetchall():
        l.append(tup)
    cur.close()
    return l


# Recursively gets all children of a faculty
def get_faculty_children(db, faculty_code):
    cur = db.cursor()
    qry = """
    SELECT  *
    FROM    org_unit_children_codes(%s)
    """
    q = queue.Queue()
    l = []
    q.put(faculty_code)
    l.append(faculty_code)

    while not q.empty():
        cur.execute(qry,[q.get()])
        for code in cur.fetchone()[0] or []:
            q.put(code)
            l.append(code)
    cur.close()
    return l


# Get all schools that have the faculty as a parent
def get_faculty_schools(db, faculty_code):
    faculty_children_codes = get_faculty_children(db, faculty_code)
    
    cur = db.cursor()
    qry = """
    SELECT  *
    FROM    schools_with_parent_code(%s)
    """

    cur.execute(qry, [faculty_code])
    info = cur.fetchone()[0] or []
    cur.close()
    return info

# Get all staff belonging to faculty (itself or its children)
def get_faculty_staff(db, faculty_code):
    faculty_children_codes = get_faculty_children(db, faculty_code)

    cur = db.cursor()
    qry = """
    SELECT  *
    FROM    subject_ids_from_org_units(%s)
    """
    cur.execute(qry, [faculty_children_codes])
    
    subjects = cur.fetchone()[0] or []

    qry = """
    SELECT  *
    FROM    course_convenors_from_subjects(%s)
    """
    cur.execute(qry, [subjects])
    info = cur.fetchone()[0] or []
    cur.close()
    return info

# Get all staff belonging to faculty (itself or its children)
def get_faculty_staff(db, faculty_code):
    faculty_children_codes = get_faculty_children(db, faculty_code)

    cur = db.cursor()
    qry = """
    SELECT  *
    FROM    subject_ids_from_org_units(%s)
    """
    cur.execute(qry, [faculty_children_codes])
    
    subjects = cur.fetchone()[0] or []

    qry = """
    SELECT  *
    FROM    course_convenors_from_subjects(%s)
    """
    cur.execute(qry, [subjects])
    info = cur.fetchone()[0] or []
    cur.close()
    return info

################################################################################
### MARK: QUESTION 2
################################################################################

def get_longest_run_string(db, subject_code):
    cur = db.cursor()

    # Retrieves subject title
    qry = """
    SELECT      s.title
    FROM        Subjects s
    WHERE       s.code = %s
    """
    cur.execute(qry, [subject_code])
    subject_title_tup = cur.fetchone()
    # If subject_code is invalid
    if not subject_title_tup:
        return f"Subject {subject_code} not found."
    subject_title = subject_title_tup[0]

    # Retrieves all courses associated with subject
    # Returns in ascending order by starting date
    qry = """
    SELECT      c.id, t.code
    FROM        courses_from_subject_code(%s) c
                JOIN Terms t ON c.term = t.id
    GROUP BY    c.id, t.code, t.starting
    ORDER BY    t.starting
    """
    cur.execute(qry, [subject_code])
    course_ids = cur.fetchall() or []

    # Returns avg marks associated with enrolments for each course
    qry = """
    SELECT  ROUND(AVG(e.mark), 2)
    FROM    enrolments_from_course(%s) e
    WHERE   e.mark IS NOT NULL
    """
    avg_tuples = []
    for course in course_ids:
        cur.execute(qry, [course[0]])
        avg = cur.fetchone()[0]
        if avg:
            # avg tuple: (avg mark, term code)
            avg_tuples.append((avg, course[1]))
    
    # Finds the longest sequence of strictly increasing avg marks
    max_sequence = []
    curr_sequence = []
    for avg_tuple in avg_tuples:
        avg = avg_tuple[0]
        if not curr_sequence or avg > curr_sequence[-1][0]:
            curr_sequence.append(avg_tuple)
        else:
            if len(curr_sequence) >= len(max_sequence):
                max_sequence = curr_sequence
            curr_sequence = [avg_tuple]
    if len(curr_sequence) >= len(max_sequence):
        max_sequence = curr_sequence

    # Returns a string representing the longest run
    cur.close()
    if len(max_sequence) < 2:
        return f"No increasing run found for {subject_code}."
    else:
        run = f"{subject_code} ({subject_title}):\n"
        run += f"{max_sequence[0][1]}({max_sequence[0][0]})"
        for course in max_sequence[1:]:
            run += f" -> {course[1]}({course[0]})"
        return run

################################################################################
### MARK: QUESTION 3
################################################################################

def get_student_courses(db, student_id):
    cur = db.cursor()
    qry = """
    SELECT      code, term, title, mark, grade, uoc
    FROM        courses_from_student(%s)
    """
    cur.execute(qry, [student_id])
    return cur.fetchall()

def course_formatter(course_tup):
    xuoc_list = ["A", "B", "C", "D", "HD", "DN", "CR", "PS", "XE", "T", "SY", "EC", "RC"]
    fail_list = ["AF", "FL", "UF", "E", "F"]
    unrs_list = ["AS", "AW", "PW", "NA", "RD", "NF", "NC", "LE", "PE", "WD", "WJ"]
    
    # Unpack course_tup
    (course_code, course_term, course_title, course_mark, course_grade,
        course_uoc) = course_tup

    # f"{CourseCode} {Term} {SubjectTitle:<40s}{Mark:>3} {Grade:>2s}  {UOC:2d}uoc"
    course_info = f"{course_code} {course_term} {course_title[:40]:<40s}"
    course_info += f"{course_mark or '-':>3} {course_grade or '-':>2s}"

    if course_grade in xuoc_list:
        course_info += f"  {course_uoc:2d}uoc"
    elif course_grade in fail_list:
        course_info += f"   fail"
    elif course_grade in unrs_list:
        course_info += f"   unrs"

    return course_info

def get_wam_summary(db, student_id):
    cur = db.cursor()
    qry = """
    SELECT      achieved_uoc, wam
    FROM        wam_from_student(%s)
    """
    cur.execute(qry, [student_id])
    return cur.fetchone()

def person_information(db, zid):
    cur = db.cursor()

    # Try to find staff with zid
    qry = """
    SELECT  p.family_name, p.given_names
    FROM    People p
            JOIN Staff s ON p.id = s.id
    WHERE   p.zid = %s
    """
    cur.execute(qry, [zid])
    staff_tup = cur.fetchone()
    # zid belongs to staff
    if staff_tup:
        return f"{zid} {staff_tup[0]}, {staff_tup[1]} is a staff member, and not a student."

    # Try to find student with zid
    qry = """
    SELECT  p.id, p.family_name, p.given_names, c.name, s.status
    FROM    People p
            JOIN Students s ON p.id = s.id
            JOIN Countries c ON p.origin = c.id
    WHERE   p.zid = %s
    """
    cur.execute(qry, [zid])
    student_tup = cur.fetchone()
    # zid does not belong to student (or staff)
    if not student_tup:
        return f"No one has the zID {zid}."

    # Unpack student tup
    (student_db_id, family_name, given_names, origin, status) = student_tup
    
    # zID FamilyName, GivenNames (Domestic/International student from Country)
    student_info = f"{zid} {family_name}, {given_names}"
    status_str = "Domestic"
    if status != 'AUS' and status != 'AUSPR':
        status_str = f"International"
    student_info += f" ({status_str} student from {origin})"

    # Try to find latest program enrolment
    qry = """
    SELECT      p_e.id, p.code, p.name
    FROM        Program_enrolments p_e
                JOIN Programs p ON p_e.program = p.id
                JOIN Terms t ON p_e.term = t.id
    WHERE       p_e.student = %s
    GROUP BY    p_e.id, p.code, p.name, t.starting
    ORDER BY    p_e.id DESC, t.starting DESC
    LIMIT       1
    """
    cur.execute(qry, [student_db_id])
    program_tup = cur.fetchone()
    if not program_tup:
        # Spec states that students are enrolled in one program at any given time
        return f"No program_enrolment found: assumption invalid"

    # Unpack program tup
    (program_enrolment_id, program_code, program_name) = program_tup

    # Try to find streams related to program_enrolment
    qry = """
    SELECT      s.code
    FROM        Stream_enrolments s_e
                JOIN Streams s ON s_e.stream = s.id
    WHERE       s_e.part_of = %s
    GROUP BY    s.code
    ORDER BY    s.code
    """
    cur.execute(qry, [program_enrolment_id])
    streams = cur.fetchall()
    if not streams:
        # Spec states that students are enrolled in one or more streams at any given time
        return f"No stream_enrolments found: assumption invalid"

    streams_str = f"{streams[0][0]}"
    if len(streams) > 1:
        for stream_tup in streams[1:-1]:
            streams_str += f", {stream_tup[0]}"
        streams_str += f" and {streams[-1][0]}"

    # ProgramCode1 ProgramName1 (StreamCode1 and StreamCode2 and ... and StreamCodeN)
    student_info += f"\n{program_code} {program_name} ({streams_str})"

    # Find all courses enrolled by student_db_id
    courses = get_student_courses(db, student_db_id)

    for course_tup in courses:
        student_info += f"\n{course_formatter(course_tup)}"

    wam_summary = get_wam_summary(db, student_db_id)
    if not wam_summary:
        return f"Error fetching wam summary"
    (uoc, wam) = wam_summary
    if wam:
        student_info += f"\nTotal achieved UOC = {uoc}, WAM = {wam:0.3f}"
    else:
        student_info += f"\nTotal achieved UOC = {uoc}, Can't compute WAM"

    return student_info

################################################################################
### MARK: QUESTION 4 
################################################################################

# Transform array of parsed tokens into SQL WHERE condition
def transform(expr, numerical_ops, key):
    sql_cond = "("
    for item in expr:
        if not isinstance(item, str):
            sql_cond += transform(item, numerical_ops, key)
        elif item == "||":
            sql_cond += " OR "
        elif item == "&&":
            sql_cond += " AND "
        elif item == "!":
            sql_cond += " NOT "
        elif key == "uoc":
            if item in numerical_ops:
                sql_cond += f"{key}{item}"
            else:
                sql_cond += f"{item}"
        elif key in ["career", "title", "code"]:
            if item in numerical_ops:
                raise Exception(f"Error: The \"{key}\" expression is not evaluable")
            sql_cond += f"LOWER(CAST({key} AS TEXT)) LIKE '%{item.lower()}%'"
    sql_cond += ")"
    return sql_cond

def check_consecutive_num_ops(tokens):
    operand = tokens[0][1][0]
    if operand in ["=", ">", "<", ">=", "<=", "!=", "<>"]:
        raise Exception("Error: Consecutive numerical operators are not allowed")
    return tokens

def parse_individual_expr(expr, key):
    # Expression parsing priority top-to-bottom
    word = Word(alphanums) | quotedString.setParseAction(removeQuotes)
    numerical_ops = ["=", ">", "<", ">=", "<=", "!=", "<>"]
    parser = infix_notation(word,
        [
            (one_of(numerical_ops), 1, opAssoc.RIGHT, check_consecutive_num_ops),
            ("!", 1, opAssoc.RIGHT),
            ("&&", 2, opAssoc.LEFT),
            ("||", 2, opAssoc.LEFT),
        ]
    )
    try:
        res = parser.parseString(expr, parseAll=True)
        return transform(res, numerical_ops, key)
    except Exception:
        raise Exception(f"Error: The \"{key}\" expression is not evaluable")

# Takes in a filter expression of the form:
#   '<field>:<condition>;<field_2><cond_2>;...'
# 
# Returns a list of tuples where each tuple is:
#   (field, plpgsql condition)
def parse_conditions(expr):
    if len(expr) == 0:
        raise Exception('Error: No filter conditions provided')

    # Split expression into array of conditions
    conditions = re.split(r'\s*;\s*', expr)

    sql_condition = ""
    for condition in conditions:
        condition_split = re.split(r'\s*:\s*', condition, 1)
        if len(condition_split) < 2:
            raise Exception(f'Error: missing a ":" in "{condition}"')
        (field, condition) = condition_split

        field_match = re.search(r'^\s*(\S+)\s*', field)
        if field_match is None:
            raise Exception(f'Error: The field "{field}" cannot be evaluated')
        field = field_match.group(1)

        if field not in ["code", "title", "career", "uoc"]:
            raise Exception(f'Error: Unknown field "{field}"')

        if len(sql_condition) > 0:
            sql_condition += " AND "
        sql_condition += parse_individual_expr(condition, field)

    return sql_condition

def filter_subjects(db, conditions):
    cur = db.cursor()
    sql_where_qry = parse_conditions(conditions)
    qry = f"""
    SELECT      code, title, uoc, career
    FROM        Subjects
    WHERE       {sql_where_qry}
    """
    cur.execute(qry)
    results = cur.fetchall()
    return results

################################################################################
### MARK: QUESTION 5
################################################################################

def get_program(db, code, student):
    cur = db.cursor()
    qry = None
    arg = None
    if code:
        qry = """
        SELECT      *
        FROM        Programs
        WHERE       code = %s
        """
        arg = code
    else:
        qry = """
        SELECT      p.*
        FROM        Programs p
                    JOIN Program_enrolments p_e ON p.id = p_e.program
        WHERE       p_e.student = %s
        ORDER BY    p_e.id DESC, p_e.term DESC
        LIMIT       1
        """
        arg = student

    cur.execute(qry,[arg])
    info = cur.fetchone()
    cur.close()
    if not info:
        return None
    else:
        return info

def get_scode_from_pcode(db, pcode):
    cur = db.cursor()
    qry = """
    SELECT      *
    FROM        stream_from_program(%s)
    """
    cur.execute(qry, [pcode])
    return re.split(r',', cur.fetchone()[0])[0]

def is_valid_stream(db, scode, pcode):
    cur = db.cursor()
    qry = """
    SELECT      *
    FROM        stream_from_program(%s)
    """
    cur.execute(qry, [pcode])
    return scode in cur.fetchone()[0]


def get_stream(db, code):
    cur = db.cursor()
    cur.execute("select * from Streams where code = %s",[code])
    info = cur.fetchone()
    cur.close()
    if not info:
        return None
    else:
        return info

def get_student(db, zid):
    cur = db.cursor()
    qry = """
    select  p.*
    from    People p
            join Students s on s.id = p.id
    where   p.zid = %s
    """
    cur.execute(qry,[zid])
    info = cur.fetchone()
    cur.close()
    if not info:
        return None
    else:
        return info

def get_requirements_helper(db, code, rtype):
    cur = db.cursor()
    qry = None
    if len(code) == 6:
        qry = """
        SELECT      *
        FROM        get_stream_requirements(%s, %s)
        """
    elif len(code) == 4:
        qry = """
        SELECT      *
        FROM        get_prog_requirements(%s, %s)
        """
    cur.execute(qry, [code, rtype])
    return cur.fetchall()

def parse_acadobjs(acadobjs):
    return re.split(r',', acadobjs)

def get_requirements(db, scode, pcode):
    cur = db.cursor()
    all_reqs = []
    for rtype in ['core', 'elective', 'gened', 'free']:
        for code in [scode, pcode]:
            # req_tuples: (id, name, rtype, min_req, max_req, acadobjs,
            # for_stream, for_program)
            req_tuples = get_requirements_helper(db, code, rtype)
            if len(req_tuples) == 0:
                continue
            tuples_list = list(map(lambda tup: [tup[0], tup[1], tup[2],
                tup[3] or tup[4], parse_acadobjs(tup[5])], req_tuples))
            all_reqs.extend(tuples_list)
    return all_reqs
    
def find_match(acadobj, code):
    if acadobj.startswith('GEN') or acadobj.startswith('FREE'):
        return code
    pattern = re.escape(acadobj).replace(r'\#', '.').replace(r'\{','') \
                .replace(r'\}', '').replace(';', '|') + '|'
    return re.search(pattern, code).group()

def get_course_uoc(db, course_code):
    cur = db.cursor()
    qry = """
    SELECT  s.uoc
    FROM    Subjects s
    WHERE   s.code = %s
    """
    cur.execute(qry, [course_code])
    return cur.fetchone()[0]

def get_course_name(db, course_code):
    cur = db.cursor()
    qry = """
    SELECT  s.title
    FROM    Subjects s
    WHERE   s.code = %s
    """
    cur.execute(qry, [course_code])
    return cur.fetchone()[0]