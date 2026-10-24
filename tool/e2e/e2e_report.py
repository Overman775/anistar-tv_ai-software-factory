"""Write structured reports for Flutter host and native E2E test runs."""

import argparse
import datetime
import json
import xml.etree.ElementTree as ET
from pathlib import Path


SCHEMA_VERSION = 2


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def duration_seconds(started_at, finished_at):
    try:
        return max(0, (datetime.datetime.fromisoformat(finished_at) -
                       datetime.datetime.fromisoformat(started_at)).total_seconds())
    except ValueError:
        return None


def read_records(event_file):
    records = {}
    if not event_file.exists():
        return records, ['Flutter JSONL event report was not created.'], False
    try:
        lines = event_file.read_text(encoding='utf-8').splitlines()
    except UnicodeDecodeError:
        return records, ['Flutter JSONL event report is not valid UTF-8.'], False
    issues = []
    stream_complete = False
    final_done_seen = False
    for line_number, line in enumerate(lines, 1):
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except ValueError:
            issues.append(f'Malformed Flutter JSONL at line {line_number}.')
            continue
        if not isinstance(event, dict):
            issues.append(f'Invalid Flutter JSONL event at line {line_number}.')
            continue
        if final_done_seen:
            issues.append(f'Flutter JSONL contains an event after final done at line {line_number}.')
            continue
        if event.get('type') == 'testStart' and isinstance(event.get('test'), dict):
            test = event['test']
            test_id = test.get('id')
            name = test.get('name')
            if test_id is not None and isinstance(name, str):
                records[test_id] = {
                    'name': name,
                    'start': event.get('time', 0),
                    'done': False,
                    'hidden': test.get('hidden', False),
                    'messages': [],
                }
        elif event.get('type') == 'error' and event.get('testID') in records:
            record = records[event['testID']]
            record['messages'].append(
                str(event.get('error', '')) + '\n' + str(event.get('stackTrace', '')),
            )
            # The test protocol requires a hidden setup/loading test that
            # later fails to become visible in the final result.
            record['hidden'] = False
            record['skipped'] = False
        elif event.get('type') == 'testDone' and event.get('testID') in records:
            record = records[event['testID']]
            record.update(
                done=True,
                result=event.get('result'),
                skipped=event.get('skipped', False),
                hidden=event.get('hidden', False),
                end=event.get('time', 0),
            )
            if record['messages']:
                record['hidden'] = False
                record['skipped'] = False
        elif event.get('type') == 'done':
            final_done_seen = True
            success = event.get('success')
            if success is True:
                stream_complete = True
            elif success is False:
                stream_complete = True
                issues.append('Flutter JSONL final done event reported failure.')
            else:
                issues.append('Flutter JSONL final done event must contain a boolean success value.')
    if not final_done_seen:
        issues.append('Flutter JSONL did not contain a final done event.')
    return records, issues, stream_complete


def add_cases(suite, records, classname):
    for record in records.values():
        if record['hidden'] and record.get('result') == 'success' and not record['messages']:
            continue
        case = ET.SubElement(
            suite,
            'testcase',
            name=record['name'],
            classname=classname,
            time=str(max(0, record.get('end', record['start']) - record['start']) / 1000),
        )
        if not record['done']:
            ET.SubElement(case, 'error', message='Test did not complete').text = '\n'.join(record['messages'])
        elif record['messages'] and record.get('result') == 'success':
            ET.SubElement(case, 'error', message='Flutter emitted a test error').text = '\n'.join(record['messages'])
        elif record.get('result') != 'success':
            tag = 'failure' if record.get('result') == 'failure' else 'error'
            ET.SubElement(case, tag, message='Flutter test failed').text = '\n'.join(record['messages'])
        elif record.get('skipped'):
            ET.SubElement(case, 'skipped')


def counts_for(suite):
    return {
        'tests': len(suite),
        'failures': sum(case.find('failure') is not None for case in suite),
        'errors': sum(case.find('error') is not None for case in suite),
        'skipped': sum(case.find('skipped') is not None for case in suite),
    }


def completed_names(records):
    return [
        record['name'] for record in records.values()
        if record.get('done') and not record.get('hidden', False) and not record.get('skipped', False)
    ]


def skipped_names(records):
    return [
        record['name'] for record in records.values()
        if record.get('done') and not record.get('hidden', False) and record.get('skipped', False)
    ]


def finalize_suite(suite, *, exit_code, phase, validation_message=None):
    existing_errors = any(case.find('failure') is not None or case.find('error') is not None for case in suite)
    if exit_code == 0 and existing_errors:
        exit_code = 1
        phase = 'report-validation'
    if exit_code and not existing_errors:
        case = ET.SubElement(suite, 'testcase', name=phase, classname=suite.get('name', 'anistar'))
        message = validation_message or f'Test runner exited {exit_code} during {phase}; see runner.log.'
        ET.SubElement(case, 'error', message=message).text = message
    counts = counts_for(suite)
    for key, value in counts.items():
        suite.set(key, str(value))
    return exit_code, phase, counts


def write_json(directory, summary, suite):
    (directory / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    ET.ElementTree(suite).write(directory / 'junit.xml', encoding='utf-8', xml_declaration=True)


def base_summary(*, suite, scope, selector, seed, exit_code, phase, started_at, finished_at, counts, records,
                 artifacts, event_stream_issues, event_stream_complete):
    completed = completed_names(records)
    skipped = skipped_names(records)
    return {
        'schema_version': SCHEMA_VERSION,
        'suite': suite,
        'scope': scope,
        'selector': selector,
        'seed': seed,
        'exit_code': exit_code,
        'status': 'passed' if exit_code == 0 else 'failed',
        'phase': phase,
        'started_at': started_at,
        'finished_at': finished_at,
        'duration_seconds': duration_seconds(started_at, finished_at),
        'completed_tests': completed,
        'completed_test_count': len(completed),
        'skipped_tests': skipped,
        'skipped_test_count': len(skipped),
        'passed': max(0, len(completed) - counts['failures'] - counts['errors']),
        'event_stream_complete': event_stream_complete,
        'event_stream_issues': event_stream_issues,
        **counts,
        'artifacts': artifacts,
    }


def write_run_report(directory, *, platform, mode, seed, device, avd, exit_code, phase, started_at,
                     requested_avd='', scope='full', selector=()):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    records, stream_issues, stream_complete = read_records(directory / 'flutter-events.jsonl')
    suite = ET.Element('testsuite', name=f'anistar.{platform}.{mode}', timestamp=started_at)
    add_cases(suite, records, f'anistar.{platform}')
    native_tests = sum(
        record['done'] and not record.get('hidden', False) and not record.get('skipped', False)
        for record in records.values()
    )
    validation_message = None
    if exit_code == 0 and stream_issues:
        exit_code = 1
        phase = 'report-validation'
        validation_message = ' '.join(stream_issues)
    elif exit_code == 0 and native_tests == 0:
        exit_code = 1
        phase = 'report-validation'
        validation_message = 'Flutter reported no completed non-skipped native tests; inspect flutter-events.jsonl and flutter.log.'
    exit_code, phase, counts = finalize_suite(
        suite,
        exit_code=exit_code,
        phase=phase,
        validation_message=validation_message or f'E2E runner exited {exit_code} during {phase}; see runner.log and flutter.log.',
    )
    finished_at = now()
    summary = base_summary(
        suite=f'e2e:{platform}', scope=scope, selector=list(selector), seed=seed,
        exit_code=exit_code, phase=phase, started_at=started_at, finished_at=finished_at,
        counts=counts, records=records,
        artifacts={'runner_log': 'runner.log', 'flutter_log': 'flutter.log', 'events': 'flutter-events.jsonl'},
        event_stream_issues=stream_issues, event_stream_complete=stream_complete,
    )
    summary.update({
        'platform': platform, 'mode': mode, 'device': device or None, 'avd': avd or None,
        'requested_avd': requested_avd or None, 'native_tests': native_tests,
    })
    write_json(directory, summary, suite)
    return summary


def write_host_report(directory, *, suite_name, scope, selector, seed, exit_code, phase, started_at):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    records, stream_issues, stream_complete = read_records(directory / 'flutter-events.jsonl')
    suite = ET.Element('testsuite', name=f'anistar.host.{suite_name}', timestamp=started_at)
    add_cases(suite, records, 'anistar.host')
    validation_message = None
    if exit_code == 0 and stream_issues:
        exit_code = 1
        phase = 'report-validation'
        validation_message = ' '.join(stream_issues)
    elif exit_code == 0 and not completed_names(records):
        exit_code = 1
        phase = 'report-validation'
        validation_message = 'Flutter reported no completed visible tests; inspect flutter-events.jsonl and flutter.log.'
    exit_code, phase, counts = finalize_suite(
        suite,
        exit_code=exit_code,
        phase=phase,
        validation_message=validation_message or f'Host test runner exited {exit_code} during {phase}; see flutter.log.',
    )
    summary = base_summary(
        suite=suite_name, scope=scope, selector=list(selector), seed=seed,
        exit_code=exit_code, phase=phase, started_at=started_at, finished_at=now(),
        counts=counts, records=records,
        artifacts={'flutter_log': 'flutter.log', 'events': 'flutter-events.jsonl'},
        event_stream_issues=stream_issues, event_stream_complete=stream_complete,
    )
    write_json(directory, summary, suite)
    return summary


def write_stage_report(directory, *, suite_name, scope, selector, seed, exit_code, phase, started_at):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    finished_at = now()
    (directory / 'events.jsonl').write_text(
        json.dumps({'type': 'stageDone', 'suite': suite_name, 'exit_code': exit_code, 'phase': phase,
                    'started_at': started_at, 'finished_at': finished_at}) + '\n',
    )
    summary = {
        'schema_version': SCHEMA_VERSION,
        'suite': suite_name,
        'scope': scope,
        'selector': list(selector),
        'seed': seed,
        'exit_code': exit_code,
        'status': 'passed' if exit_code == 0 else 'failed',
        'phase': phase,
        'started_at': started_at,
        'finished_at': finished_at,
        'duration_seconds': duration_seconds(started_at, finished_at),
        'artifacts': {'log': 'stage.log', 'events': 'events.jsonl'},
    }
    (directory / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    return summary


def write_aggregate(directory, children):
    directory = Path(directory)
    root = ET.Element('testsuites', name='anistar.mobile-and-tv')
    summaries = []
    for child in children:
        child = Path(child)
        try:
            summary = json.loads((child / 'summary.json').read_text(encoding='utf-8'))
            junit = ET.parse(child / 'junit.xml').getroot()
        except (OSError, ValueError, ET.ParseError) as error:
            raise ValueError(
                f'Cannot aggregate E2E child report {child}: expected valid summary.json and junit.xml.',
            ) from error
        required = ('exit_code', 'status', 'native_tests', 'errors', 'failures', 'tests')
        if not isinstance(summary, dict) or any(key not in summary for key in required):
            raise ValueError(
                f'Cannot aggregate E2E child report {child}: summary.json is incomplete.',
            )
        summaries.append(summary)
        root.append(junit)
    summary = {
        'schema_version': SCHEMA_VERSION,
        'scope': 'full' if all(item.get('scope', 'full') == 'full' for item in summaries) else 'filtered',
        'status': 'passed' if all(
            item['exit_code'] == 0 and item['status'] == 'passed' and item.get('native_tests', 0) > 0
            and item['errors'] == 0 and item['failures'] == 0 and item.get('scope', 'full') == 'full'
            for item in summaries
        ) else 'failed',
        'runs': summaries,
    }
    for key in ('tests', 'failures', 'errors', 'skipped'):
        root.set(key, str(sum(item[key] for item in summaries)))
    (directory / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    ET.ElementTree(root).write(directory / 'junit.xml', encoding='utf-8', xml_declaration=True)
    return summary


def selectors_from_arguments(args, parser):
    selectors_json = args.pop('selectors_json')
    selectors = args['selector']
    if selectors_json is None:
        return
    if selectors:
        parser.error('Use either --selector or --selectors-json, not both.')
    try:
        parsed = json.loads(selectors_json)
    except json.JSONDecodeError:
        parser.error('--selectors-json must contain a JSON array.')
    if not isinstance(parsed, list) or any(not isinstance(item, str) for item in parsed):
        parser.error('--selectors-json must contain only string values.')
    args['selector'] = parsed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    run = commands.add_parser('run')
    run.add_argument('--directory', required=True)
    run.add_argument('--platform', choices=('tv', 'mobile'), required=True)
    run.add_argument('--mode', required=True)
    run.add_argument('--seed', type=int, required=True)
    run.add_argument('--device', default='')
    run.add_argument('--avd', default='')
    run.add_argument('--requested-avd', default='')
    run.add_argument('--scope', choices=('full', 'filtered'), default='full')
    run.add_argument('--selector', action='append', default=[])
    run.add_argument('--selectors-json')
    run.add_argument('--exit-code', type=int, required=True)
    run.add_argument('--phase', required=True)
    run.add_argument('--started-at', required=True)
    host = commands.add_parser('host')
    host.add_argument('--directory', required=True)
    host.add_argument('--suite', required=True)
    host.add_argument('--scope', choices=('full', 'filtered'), required=True)
    host.add_argument('--selector', action='append', default=[])
    host.add_argument('--selectors-json')
    host.add_argument('--seed', type=int, required=True)
    host.add_argument('--exit-code', type=int, required=True)
    host.add_argument('--phase', required=True)
    host.add_argument('--started-at', required=True)
    stage = commands.add_parser('stage')
    stage.add_argument('--directory', required=True)
    stage.add_argument('--suite', required=True)
    stage.add_argument('--scope', choices=('full', 'filtered'), default='full')
    stage.add_argument('--selector', action='append', default=[])
    stage.add_argument('--selectors-json')
    stage.add_argument('--seed', type=int, required=True)
    stage.add_argument('--exit-code', type=int, required=True)
    stage.add_argument('--phase', required=True)
    stage.add_argument('--started-at', required=True)
    aggregate = commands.add_parser('aggregate')
    aggregate.add_argument('--directory', required=True)
    aggregate.add_argument('children', nargs='+')
    args = vars(parser.parse_args())
    command = args.pop('command')
    if command in ('run', 'host', 'stage'):
        selectors_from_arguments(args, parser)
    if command == 'run':
        directory = args.pop('directory')
        raise SystemExit(write_run_report(directory, **args)['exit_code'])
    if command == 'host':
        directory = args.pop('directory')
        raise SystemExit(write_host_report(directory, suite_name=args.pop('suite'), **args)['exit_code'])
    if command == 'stage':
        directory = args.pop('directory')
        write_stage_report(directory, suite_name=args.pop('suite'), **args)
        # The stage exit code is report data. The shell runner owns the
        # command's exit status after it prints the concise failure summary.
        return
    try:
        summary = write_aggregate(args['directory'], args['children'])
    except ValueError as error:
        parser.error(str(error))
    raise SystemExit(0 if summary['status'] == 'passed' else 1)


if __name__ == '__main__':
    main()
