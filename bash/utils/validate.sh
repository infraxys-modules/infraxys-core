#
# Bash validation functions
#
# @author jeroen-manders
#

VALIDATE_EXPORTED_FUNCTION_NAMES="check_required_argument check_required_arguments check_required_variable check_required_variables check_required_file"

# usage: one argument required: check_required_argument "my_function" "argument1"
#        one of two arguments required: check_required_argument "my_function" "argument1" "argument2"
function check_required_argument() {
  local calling_function_name="$1"
  local argument_name="$2"
  local argument_name2=""
  [[ $# -gt 2 ]] && argument_name2="$3"
  if [ -z "${!argument_name}" ]; then
    if [ -n "$argument_name2" ]; then
      if [ -z "${!argument_name2}" ]; then
        log_error "Argument '$argument_name' or '$argument_name2' is required for '$calling_function_name'."
        exit 1
      fi
    else
      log_error "Argument '$argument_name' is required for function '$calling_function_name'."
      exit 1
    fi
  fi
}

function check_required_arguments() {
  local calling_function_name="$1"
  while true; do
    shift
    [[ $# -gt 0 ]] || break
    local argument_name="$1"
    if [ -z "$argument_name" ]; then
      break
    fi
    check_required_argument "$calling_function_name" "$argument_name"
  done
}

function check_required_variable() {
  local this_function_name="check_required_variable" variable_name default_value="" or_variable_name=""
  import_args "$@"
  check_required_arguments "$this_function_name" variable_name
  if [ -n "$or_variable_name" -a -n "$default_value" ]; then
    log_error "Arguments 'or_variable_name' and 'default_value' can't be specified at the same time. Function: $function_name."
    exit 1
  fi
  if [ -z "${!variable_name}" ]; then
    if [ -n "$or_variable_name" ]; then
      if [ -z "${!or_variable_name}" ]; then
        log_error "Variable '$variable_name' or variable '$or_variable_name' is required. Function: $function_name."
        exit 1
      fi
    else
      if [ -z "$default_value" ]; then
        log_error "Required variable '$variable_name' is not set and no default value is specified. Function: $function_name."
        exit 1
      else
        log_debug "Variable '$variable_name' is not set, using default value."
      fi
    fi
  fi
}

function check_required_variables() {
  while true; do
    [[ $# == 0 ]] && break
    local variable_name="$1"
    if [ -z "$variable_name" ]; then
      continue
    fi
    check_required_variable --variable_name "$variable_name"
    shift
  done
}

function check_required_file() {
  local function_name="check_required_file" filename
  import_args "$@"
  check_required_variable --variable_name "filename"
  if [ ! -f "$filename" ]; then
    log_error "Required file is missing: '$filename'"
    exit 1
  fi
}
