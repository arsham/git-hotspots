#!/bin/sh

# Git hooks export repository and authoring variables. The validation ladder
# creates nested fixture repositories with deterministic authors and commit
# hashes, so clear the parent Git context before running commands that may
# invoke git in those fixtures.
git_hotspots_clear_git_hook_env() {
  case ${GIT_CONFIG_COUNT:-0} in
    ''|*[!0123456789]*) config_count=0 ;;
    *) config_count=${GIT_CONFIG_COUNT:-0} ;;
  esac

  i=0
  while [ "$i" -lt "$config_count" ]; do
    unset "GIT_CONFIG_KEY_$i" "GIT_CONFIG_VALUE_$i"
    i=$((i + 1))
  done

  unset GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS
  unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_AUTHOR_DATE
  unset GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_COMMITTER_DATE
  unset $(git rev-parse --local-env-vars)
}
