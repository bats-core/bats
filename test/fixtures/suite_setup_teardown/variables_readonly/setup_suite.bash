setup_suite() {
  local variable writable=
  for variable in ${VARIABLES_TO_REASSIGN?}; do
    if (eval "$variable=changed") 2>/dev/null; then
      echo "$variable is writable" >&2
      writable=1
    fi
  done
  [[ ! $writable ]]
}
