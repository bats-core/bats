check_ifs() {
  if [[ "$IFS" != $' \t\n' ]]; then
    echo "${FUNCNAME[*]}"
    echo "${BASH_SOURCE[*]}"
    hexdump -c <<<"$IFS"
    exit 1
  fi >&2
}
