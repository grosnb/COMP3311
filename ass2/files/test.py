from pyparsing import Word, alphanums, infix_notation, one_of, opAssoc, quotedString, removeQuotes
import re

# Transform array of parsed tokens into SQL WHERE condition
def transform(expr, numerical_ops, key):
    val = "("
    for item in expr:
        # If array
        if not isinstance(item, str):
            val += transform(item, numerical_ops, key)
        elif item == "||":
            val += " OR "
        elif item == "&&":
            val += " AND "
        elif item == "!":
            val += " NOT "
        elif key == "uoc":
            if item in numerical_ops:
                val += f"{key}{item}"
            else:
                val += f"{item}"
        elif key in ["career", "title", "code"]:
            if item in numerical_ops:
                return("PROBLEM")
            val += f"{key} LIKE '%{item}%'"
    val += ")"
    return val

def parse_individual_expr(expr, key):
    # Expression parsing priority top-to-bottom
    word = Word(alphanums) | quotedString.setParseAction(removeQuotes)
    numerical_ops = ["=", ">", "<", ">=", "<=", "!=", "<>"]
    parser = infix_notation(word,
        [
            (one_of(numerical_ops), 1, opAssoc.RIGHT),
            ("!", 1, opAssoc.RIGHT),
            ("&&", 2, opAssoc.LEFT),
            ("||", 2, opAssoc.LEFT),
        ]
    )
    try:
        res = parser.parseString(expr)
        return transform(res, numerical_ops, key)
    except Exception:
        raise Exception(f"Error: The \"{key}\" expression is not evaluable")

def parse_conditions(expr):
    if len(expr) == 0:
        raise Exception('Error: No filter conditions provided')

    # Split expression into array of conditions
    conditions = re.split(r'\s*;\s*', expr)

    sql_condition = ""
    for condition in conditions:
        field_match = re.search(r'^\s*(\S+)\s*:', condition)
        if field_match is None:
            raise Exception('Error: No filter conditions provided')
        field = field_match.group(1)

        condition_split = re.split(r'\s*:\s*', condition, 1)
        if len(condition_split) < 2:
            raise Exception(f'Error: missing a ":" in "{condition}"')

        condition = condition_split[1]
        if len(sql_condition) > 0:
            sql_condition += " AND "
        sql_condition += parse_individual_expr(condition, field)

    return conditions

# expr = """
# uoc:>=6 && <12;
# career:!('PG');
# title:'math' && !(' 1A' || 'Comp');
# code:'10' && ('2' || '3' || '4')
# """

# print(parse_conditions(expr))

print(parse_individual_expr("!('PG')", 'career'))

