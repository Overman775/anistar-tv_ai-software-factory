#!/usr/bin/env bash
# One quiet runner for host test, analyzer, DCM and Python quality stages.
set -euo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"

action=${1:-}
[[ -n $action ]] || { echo 'Usage: quality_runner.sh <stage|test> [arguments]' >&2; exit 64; }
shift
sdk_dir=${ANISTAR_FLUTTER_SDK:-$project_root/.fvm/flutter_sdk}
seed=${ANISTAR_TEST_SEED:-20261010}
[[ $seed =~ ^[0-9]+$ ]] || { echo 'ANISTAR_TEST_SEED must be a non-negative integer.' >&2; exit 64; }

timestamp() {
  python3 -c 'import datetime; print(datetime.datetime.now(datetime.timezone.utc).isoformat())'
}

create_run_directory() {
  local suite=$1
  local scope=$2
  mkdir -p build/quality
  mktemp -d "$project_root/build/quality/$suite-$scope-seed-$seed.XXXXXX"
}

report_stage() {
  local directory=$1
  local suite=$2
  local scope=$3
  local exit_code=$4
  local phase=$5
  local started_at=$6
  shift 6
  local args=(python3 tool/e2e/e2e_report.py stage --directory "$directory" --suite "$suite" \
    --scope "$scope" --seed "$seed" --exit-code "$exit_code" --phase "$phase" --started-at "$started_at")
  local selector
  for selector in "$@"; do args+=("--selector=$selector"); done
  "${args[@]}"
}

print_result() {
  local directory=$1
  local suite=$2
  local exit_code=$3
  local log_file=$4
  local label
  label=$(python3 - "$directory/summary.json" <<'PY'
import json
import sys
summary = json.load(open(sys.argv[1]))
print(f"scope={summary['scope']} completed={summary.get('completed_test_count', 0)} "
      f"passed={summary.get('passed', 0)} failures={summary.get('failures', 0)} "
      f"errors={summary.get('errors', 0)}")
PY
)
  if [[ $exit_code == 0 ]]; then
    echo "OK suite=$suite $label report=$directory"
    return
  fi
  echo "FAIL suite=$suite $label report=$directory log=$log_file" >&2
  [[ ! -f $log_file ]] || tail -n 80 "$log_file" >&2
}

prepare() {
  local directory
  directory=$(create_run_directory prepare full)
  local started_at
  started_at=$(timestamp)
  local exit_code=0
  set +e
  "$sdk_dir/bin/flutter" --no-version-check --version --machine 2>&1 | "$sdk_dir/bin/dart" tool/quality/verify_sdk.dart > "$directory/stage.log" 2>&1
  pipeline_status=("${PIPESTATUS[@]}")
  if [[ ${pipeline_status[0]} != 0 || ${pipeline_status[1]} != 0 ]]; then
    exit_code=1
  fi
  if [[ $exit_code == 0 ]]; then
    "$sdk_dir/bin/flutter" --no-version-check pub get --enforce-lockfile >> "$directory/stage.log" 2>&1
    exit_code=$?
  fi
  if [[ $exit_code == 0 ]]; then
    sources=$(find lib infrastructure test integration_test tool/quality \
      -type d \( -name build -o -name .dart_tool \) -prune -o \
      -type f -name '*.dart' ! -name '*.g.dart' ! -name '*.gen.dart' \
      ! -name '*.freezed.dart' ! -name generated_plugin_registrant.dart -print)
    [[ -n $sources ]] || { echo 'No maintained Dart sources found.' >> "$directory/stage.log"; exit_code=1; }
  fi
  set -e
  report_stage "$directory" prepare full "$exit_code" prepare "$started_at"
  print_result "$directory" prepare "$exit_code" "$directory/stage.log"
  return "$exit_code"
}

run_stage() {
  local suite=$1
  shift
  local directory
  directory=$(create_run_directory "$suite" full)
  local started_at
  started_at=$(timestamp)
  local exit_code=0
  set +e
  "$@" > "$directory/stage.log" 2>&1
  exit_code=$?
  set -e
  report_stage "$directory" "$suite" full "$exit_code" "$suite" "$started_at"
  print_result "$directory" "$suite" "$exit_code" "$directory/stage.log"
  return "$exit_code"
}

run_host_tests() {
  local suite=$1
  local prepare_requested=$2
  local update_goldens=$3
  shift 3
  local selectors=("$@")
  local selector_count=$#
  local structured_selectors=${ANISTAR_TEST_SELECTORS_JSON:-}
  if [[ -n $structured_selectors && $selector_count != 0 ]]; then
    echo 'Use either normal selector arguments or ANISTAR_TEST_SELECTORS_JSON, not both.' >&2
    return 64
  fi
  if [[ -n $structured_selectors ]]; then
    python3 tool/quality/selector_args.py --profile host validate || return $?
  fi
  local scope=full
  [[ $selector_count == 0 && -z $structured_selectors ]] || scope=filtered
  if [[ $prepare_requested == 1 ]]; then prepare; fi
  local directory
  directory=$(create_run_directory "$suite" "$scope")
  local started_at
  started_at=$(timestamp)
  local command=("$sdk_dir/bin/flutter" --no-version-check test --no-pub)
  if [[ $suite == unit ]]; then
    command+=(--exclude-tags=golden --concurrency=4 --coverage
      --coverage-package=anistar_tv --coverage-package=core --coverage-package=networking
      --coverage-package=storage --coverage-package=app_logging --coverage-package=anistar
      --coverage-package=ui_kit)
  else
    command+=(--tags=golden --concurrency=1)
    [[ $update_goldens == 0 ]] || command+=(--update-goldens)
  fi
  command+=(--test-randomize-ordering-seed="$seed" --reporter=failures-only
    --file-reporter="json:$directory/flutter-events.jsonl")
  if [[ $selector_count != 0 ]]; then command+=("${selectors[@]}"); fi
  local exit_code=0
  set +e
  if [[ -n $structured_selectors ]]; then
    python3 tool/quality/selector_args.py --profile host exec -- "${command[@]}" > "$directory/flutter.log" 2>&1
  else
    "${command[@]}" > "$directory/flutter.log" 2>&1
  fi
  exit_code=$?
  set -e
  local report_code=0
  local report_args=(python3 tool/e2e/e2e_report.py host --directory "$directory" --suite "$suite" \
    --scope "$scope" --seed "$seed" --exit-code "$exit_code" --phase flutter-tests --started-at "$started_at")
  local selector
  if [[ -n $structured_selectors ]]; then
    report_args+=("--selectors-json" "$structured_selectors")
  elif [[ $selector_count != 0 ]]; then
    for selector in "${selectors[@]}"; do report_args+=("--selector=$selector"); done
  fi
  set +e
  "${report_args[@]}"
  report_code=$?
  set -e
  [[ $exit_code != 0 || $report_code == 0 ]] || exit_code=$report_code
  print_result "$directory" "$suite" "$exit_code" "$directory/flutter.log"
  return "$exit_code"
}

run_gate() {
  local gate=${1:-}
  if [[ ( $gate == check || $gate == check:flutter ) && -n ${ANISTAR_TEST_SELECTORS_JSON:-} ]]; then
    echo 'check gates run full suites; ANISTAR_TEST_SELECTORS_JSON is only supported by public test profiles.' >&2
    return 64
  fi
  case $gate in
    analyze|format|format-check|dcm)
      prepare
      bash "$project_root/scripts/quality_runner.sh" "$gate"
      ;;
    tooling)
      run_stage tooling bash scripts/with_python.sh bash scripts/test_tooling.sh
      ;;
    check|check:flutter)
      prepare
      bash "$project_root/scripts/quality_runner.sh" format-check
      bash "$project_root/scripts/quality_runner.sh" analyze
      if [[ $gate == check ]]; then bash "$project_root/scripts/quality_runner.sh" dcm; fi
      run_host_tests unit 0 0
      run_host_tests goldens 0 0
      if [[ $gate == check ]]; then
        run_stage tooling bash scripts/with_python.sh bash scripts/test_tooling.sh
        run_stage version bash scripts/with_python.sh python3 tool/version/app_version.py check
      fi
      ;;
    *)
      echo "Unknown quality gate: $gate" >&2
      return 64
      ;;
  esac
}

parse_host_selectors() {
  selectors=()
  selector_count=0
  while [[ $# -gt 0 ]]; do
    case $1 in
      --prepare)
        prepare_requested=1
        ;;
      --plain-name|--name)
        [[ $# -ge 2 && -n ${2:-} ]] || { echo "Missing value for $1." >&2; return 64; }
        selectors+=("$1" "$2")
        selector_count=$((selector_count + 2))
        shift
        ;;
      --plain-name=*|--name=*)
        [[ ${1#*=} ]] || { echo "Missing value for ${1%%=*}." >&2; return 64; }
        selectors+=("$1")
        selector_count=$((selector_count + 1))
        ;;
      --update-goldens)
        echo 'Use test:goldens:update for an explicit baseline update.' >&2
        return 64
        ;;
      --*)
        echo "Unsupported Flutter test option: $1. Use a test path, --plain-name, or --name." >&2
        return 64
        ;;
      *)
        [[ $1 == *.dart ]] || {
          echo "Ambiguous selector fragment: $1. Use ANISTAR_TEST_SELECTORS_JSON for selectors containing spaces or shell metacharacters." >&2
          return 64
        }
        selectors+=("$1")
        selector_count=$((selector_count + 1))
        ;;
    esac
    shift
  done
}

case $action in
  format)
    run_stage format bash -euo pipefail -c '
      find lib infrastructure test integration_test tool/quality \
        -type d \( -name build -o -name .dart_tool \) -prune -o \
        -type f -name "*.dart" ! -name "*.g.dart" ! -name "*.gen.dart" \
        ! -name "*.freezed.dart" ! -name generated_plugin_registrant.dart -print0 |
        xargs -0 "${ANISTAR_FLUTTER_SDK:-$PWD/.fvm/flutter_sdk}/bin/dart" format
    '
    ;;
  format-check)
    run_stage format-check bash -euo pipefail -c '
      find lib infrastructure test integration_test tool/quality \
        -type d \( -name build -o -name .dart_tool \) -prune -o \
        -type f -name "*.dart" ! -name "*.g.dart" ! -name "*.gen.dart" \
        ! -name "*.freezed.dart" ! -name generated_plugin_registrant.dart -print0 |
        xargs -0 "${ANISTAR_FLUTTER_SDK:-$PWD/.fvm/flutter_sdk}/bin/dart" format --output=none --set-exit-if-changed
    '
    ;;
  analyze)
    run_stage analyze "$sdk_dir/bin/flutter" --no-version-check analyze --no-pub --fatal-infos --no-congratulate --no-preamble
    ;;
  dcm)
    run_stage dcm dcm analyze lib infrastructure test integration_test tool/quality \
      --sdk-path "$sdk_dir/bin/cache/dart-sdk" --fatal-style --fatal-warnings --no-analytics --concise --no-congratulate
    ;;
  tooling)
    run_stage tooling bash scripts/with_python.sh bash scripts/test_tooling.sh
    ;;
  prepare)
    prepare
    ;;
  gate)
    run_gate "${1:-}"
    ;;
  test|test-update)
    suite=${1:-}
    [[ $suite == unit || $suite == goldens ]] || { echo 'Usage: quality_runner.sh test <unit|goldens> [--prepare] [test paths, --plain-name, --name]' >&2; exit 64; }
    [[ $action != test-update || $suite == goldens ]] || { echo 'Only golden tests can update baselines.' >&2; exit 64; }
    shift
    prepare_requested=0
    update_goldens=0
    [[ $action != test-update ]] || update_goldens=1
    parse_host_selectors "$@"
    if [[ $selector_count == 0 ]]; then
      run_host_tests "$suite" "$prepare_requested" "$update_goldens"
    else
      run_host_tests "$suite" "$prepare_requested" "$update_goldens" "${selectors[@]}"
    fi
    ;;
  *)
    echo "Unknown quality stage: $action" >&2
    exit 64
    ;;
esac
