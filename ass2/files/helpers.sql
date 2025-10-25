-- COMP3311 25T2 Ass2 ... extra database definitions
-- add any views or functions you need into this file
-- note: it must load without error into a freshly created MyMyUNSW database
-- you must submit this even if you add nothing to it

-- `psql mymyunsw -f helpers.sql`

--------------------------------------------------------------------------------
-- Returns rows of courses from subjects with given code
--------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS courses_from_subject(INTEGER[]);
CREATE OR REPLACE FUNCTION courses_from_subject(
  ids INTEGER[]
)
RETURNS SETOF Courses AS $$
DECLARE
BEGIN
  RETURN  QUERY
  SELECT  *
  FROM    Courses c
  WHERE   c.subject = ANY(ids);
END;
$$ LANGUAGE plpgsql;


--------------------------------------------------------------------------------
-- Returns rows of Orgunits which belong to the Orgunit with given code
--------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS org_unit_children(VARCHAR(10));
CREATE OR REPLACE FUNCTION org_unit_children(
  org_code VARCHAR(10)
)
RETURNS SETOF Orgunits AS $$
DECLARE
  faculty_id INTEGER;
BEGIN
  SELECT  o.id INTO faculty_id
  FROM    Orgunits o
  WHERE   o.code = org_code;

  RETURN  QUERY
  SELECT  *
  FROM    Orgunits o
  WHERE   o.parent = faculty_id;
END;
$$ LANGUAGE plpgsql;


--------------------------------------------------------------------------------
-- Returns codes of Orgunits which belong to the Orgunit with given code
--------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS org_unit_children_codes(VARCHAR(10));
CREATE OR REPLACE FUNCTION org_unit_children_codes(
  org_code VARCHAR(10)
)
RETURNS VARCHAR(10)[] AS $$
DECLARE
  children_codes VARCHAR(10)[];
BEGIN
  SELECT  ARRAY_AGG(DISTINCT c.code) INTO children_codes
  FROM    org_unit_children(org_code) c;

  RETURN children_codes;
END;
$$ LANGUAGE plpgsql;


--------------------------------------------------------------------------------
-- Returns subject ids which belong to the org units with given ids
--------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS subject_ids_from_org_units(INTEGER[]);
CREATE OR REPLACE FUNCTION subject_ids_from_org_units(
  ids INTEGER[]
)
RETURNS INTEGER[] AS $$
DECLARE
  subject_ids INTEGER[];
BEGIN
  SELECT  ARRAY_AGG(DISTINCT s.id) INTO subject_ids
  FROM    Subjects s
  WHERE   s.owner = ANY(ids);

  RETURN subject_ids;
END;
$$ LANGUAGE plpgsql;


--------------------------------------------------------------------------------
-- Returns subject ids which belong to the org units with given codes
--------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS subject_ids_from_org_units(VARCHAR(10)[]);
CREATE OR REPLACE FUNCTION subject_ids_from_org_units(
  org_codes VARCHAR(10)[]
)
RETURNS INTEGER[] AS $$
DECLARE
  subject_ids INTEGER[];
  faculty_ids INTEGER[];
BEGIN
  SELECT  ARRAY_AGG(DISTINCT o.id) INTO faculty_ids
  FROM    Orgunits o
  WHERE   o.code = ANY(org_codes);

  SELECT  ARRAY_AGG(DISTINCT s.id) INTO subject_ids
  FROM    Subjects s
  WHERE   s.owner = ANY(faculty_ids);

  RETURN subject_ids;
END;
$$ LANGUAGE plpgsql;


--------------------------------------------------------------------------------
-- Returns rows of courses from subjects with given code
--------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS courses_from_subject_code(VARCHAR(8));
CREATE OR REPLACE FUNCTION courses_from_subject_code(
  subject_code VARCHAR(8)
)
RETURNS SETOF Courses AS $$
DECLARE
  subject_id INTEGER;
BEGIN
  SELECT  s.id INTO subject_id
  FROM    Subjects s
  WHERE   s.code = subject_code;

  RETURN  QUERY
  SELECT  *
  FROM    Courses c
  WHERE   c.subject = subject_id;
END;
$$ LANGUAGE plpgsql;


--------------------------------------------------------------------------------
-- Returns course convenors from subjects with given ids
--------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS course_convenors_from_subjects(INTEGER[]);
CREATE OR REPLACE FUNCTION course_convenors_from_subjects(
  ids INTEGER[]
)
RETURNS INTEGER[] AS $$
DECLARE
  convenors INTEGER[];
BEGIN
  SELECT  ARRAY_AGG(DISTINCT c.convenor) INTO convenors
  FROM    courses_from_subject(ids) c
  WHERE   c.convenor IS NOT NULL;

  RETURN convenors;
END;
$$ LANGUAGE plpgsql;


--------------------------------------------------------------------------------
-- Returns the school ids whose parent matches the given code
--------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS schools_with_parent_code(VARCHAR(10));
CREATE OR REPLACE FUNCTION schools_with_parent_code(
  org_code VARCHAR(10)
)
RETURNS VARCHAR(10)[] AS $$
DECLARE
  schools VARCHAR(10)[];
  faculty_id INTEGER;
BEGIN
  SELECT  o.id INTO faculty_id
  FROM    Orgunits o
  WHERE   o.code = org_code;

  SELECT  ARRAY_AGG(DISTINCT o.id) INTO schools
  FROM    Orgunits o
  WHERE   o.parent = faculty_id;

  RETURN schools;
END;
$$ LANGUAGE plpgsql;


--------------------------------------------------------------------------------
-- Returns rows of enrolments from course
--------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS enrolments_from_course(INTEGER);
CREATE OR REPLACE FUNCTION enrolments_from_course(
  course_id INTEGER
)
RETURNS SETOF Course_enrolments AS $$
BEGIN
  RETURN  QUERY
  SELECT  *
  FROM    Course_enrolments c
  WHERE   c.course = course_id;
END;
$$ LANGUAGE plpgsql;


--------------------------------------------------------------------------------
-- Returns information for a student's enrolled courses
--------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS courses_from_student(INTEGER);
CREATE OR REPLACE FUNCTION courses_from_student(
  student_id INTEGER
)
RETURNS TABLE(
  code SUBJECTCODE,
  term TERMCODE,
  title TEXT,
  mark INTEGER,
  grade GRADETYPE,
  uoc INTEGER
) AS $$
BEGIN
  RETURN    QUERY
  SELECT    s.code, t.code, s.title, c_e.mark, c_e.grade, s.uoc
  FROM      Course_enrolments c_e
            JOIN Courses c ON c_e.course = c.id
            JOIN Subjects s ON c.subject = s.id
            JOIN Terms t ON c.term = t.id
  WHERE     c_e.student = student_id
  GROUP BY  s.code, t.code, s.title, c_e.mark, c_e.grade, s.uoc, t.starting
  ORDER BY  t.starting, t.code;
END;
$$ LANGUAGE plpgsql;


--------------------------------------------------------------------------------
-- Returns wam information for student
--------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS wam_from_student(INTEGER);
CREATE OR REPLACE FUNCTION wam_from_student(
  student_id INTEGER
)
RETURNS TABLE(
  achieved_uoc INTEGER,
  wam FLOAT
) AS $$
DECLARE
  uoc_grades GRADETYPE[] := '{"A", "A+", "A-", "B", "B+", "B-", "C", "C+", "C-",
    "D", "D+", "D-", "HD", "DN", "CR", "PS", "XE", "SY", "EC", "RC", "RS", "EM"}';
  wam_grades GRADETYPE[] := '{"HD", "DN", "CR", "PS", "AF", "FL", "UF", "E", "E+", "E-",
    "F"}';
  achieved_uoc INTEGER;
  wam FLOAT;
BEGIN
  SELECT  COALESCE(SUM(c.uoc), 0) INTO achieved_uoc
  FROM    courses_from_student(student_id) c
  WHERE   c.grade = ANY(uoc_grades);

  SELECT  ROUND(SUM(COALESCE(c.mark, 0) * c.uoc)::NUMERIC / SUM(c.uoc), 3) INTO wam
  FROM    courses_from_student(student_id) c
  WHERE   c.grade = ANY(wam_grades);

  RETURN  QUERY SELECT achieved_uoc, wam;
END;
$$ LANGUAGE plpgsql;


--------------------------------------------------------------------------------
-- Returns stream codes for a given program code
--------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS stream_from_program(CHAR(4));
CREATE OR REPLACE FUNCTION stream_from_program(
  program_code CHAR(4)
)
RETURNS TEXT AS $$
DECLARE
  program_id INTEGER;
  stream_codes TEXT;
BEGIN
  SELECT      p.id INTO program_id
  FROM        Programs p
  WHERE       p.code = program_code;

  SELECT      acadobjs INTO stream_codes
  FROM        Requirements r
  WHERE       r.for_program = program_id
              AND r.rtype = 'stream'
  ORDER BY    r.id ASC
  LIMIT       1;

  RETURN stream_codes;
END;
$$ LANGUAGE plpgsql;


--------------------------------------------------------------------------------
-- Returns requirements of rtype belonging to program
--------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS get_prog_requirements(CHAR(4), TEXT);
CREATE OR REPLACE FUNCTION get_prog_requirements(
  program_code CHAR(4),
  req_type TEXT
)
RETURNS SETOF Requirements AS $$
BEGIN
  RETURN    QUERY
  SELECT    r.*
  FROM      Requirements r
            JOIN Programs p ON r.for_program = p.id
  WHERE     p.code = program_code
            AND CAST(r.rtype AS TEXT) = req_type
  ORDER BY  r.id;
END;
$$ LANGUAGE plpgsql;


--------------------------------------------------------------------------------
-- Returns requirements of rtype belonging to stream
--------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS get_stream_requirements(CHAR(6), TEXT);
CREATE OR REPLACE FUNCTION get_stream_requirements(
  stream_code CHAR(6),
  req_type TEXT
)
RETURNS SETOF Requirements AS $$
BEGIN
  RETURN    QUERY
  SELECT    r.*
  FROM      Requirements r
            JOIN Streams s ON r.for_stream = s.id
  WHERE     s.code = stream_code
            AND CAST(r.rtype AS TEXT) = req_type
  ORDER BY  r.id;
END;
$$ LANGUAGE plpgsql;