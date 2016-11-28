# please note:
#   for the moment only single quotes are supported
#       right: 'This is a "quoted text"'
#       wrong: "This is a \"quoted text\""
#
#  always use single quotes
#       right 'type' 'expr' 'value'
#       wrong "type" "expr" 4

# 1 value is the type
# 2 value is the width
MAX_WIDTH='T','15'
MAX_WIDTH='D','30'

MATCH 'B' '*DATE *'       '%1, SAMPLE="99-99-9999"'
MATCH 'B' '*INT*'         '%1, SAMPLE="9"'

# i will change the width of a field
#       max
MATCH 'B','*DATE *','%1, SAMPLE="99-99-9999"'
# i will add attributes
# i will set the widget type
