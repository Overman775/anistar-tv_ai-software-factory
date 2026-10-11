"""Write dependency-free E2E summary/JUnit reports, including preflight failures."""

import argparse
import datetime
import json
import xml.etree.ElementTree as ET
from pathlib import Path


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def write_run_report(directory, *, platform, mode, seed, device, avd, exit_code, phase, started_at, requested_avd=''):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    records = {}
    event_file = directory / 'flutter-events.jsonl'
    if event_file.exists():
        for line in event_file.read_text(errors='replace').splitlines():
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if event.get('type') == 'testStart':
                test = event['test']
                records[test['id']] = {
                    'name': test['name'], 'start': event.get('time', 0), 'done': False,
                    'hidden': test.get('hidden', False), 'messages': [],
                }
            elif event.get('type') == 'error' and event.get('testID') in records:
                records[event['testID']]['messages'].append(
                    str(event.get('error', '')) + '\n' + str(event.get('stackTrace', '')),
                )
            elif event.get('type') == 'testDone' and event.get('testID') in records:
                records[event['testID']].update(
                    done=True, result=event.get('result'), skipped=event.get('skipped', False),
                    hidden=event.get('hidden', False), end=event.get('time', 0),
                )
    suite = ET.Element('testsuite', name=f'anistar.{platform}.{mode}', timestamp=started_at)
    for record in records.values():
        if record['hidden'] and record.get('result') == 'success':
            continue
        case = ET.SubElement(
            suite, 'testcase', name=record['name'], classname=f'anistar.{platform}',
            time=str(max(0, record.get('end', record['start']) - record['start']) / 1000),
        )
        if record.get('skipped'):
            ET.SubElement(case, 'skipped')
        elif not record['done']:
            ET.SubElement(case, 'error', message='Test did not complete').text = '\n'.join(record['messages'])
        elif record['messages'] and record.get('result') == 'success':
            ET.SubElement(case, 'error', message='Flutter emitted a test error').text = '\n'.join(record['messages'])
        elif record.get('result') != 'success':
            tag = 'failure' if record.get('result') == 'failure' else 'error'
            ET.SubElement(case, tag, message='Flutter test failed').text = '\n'.join(record['messages'])
    native_tests = sum(record['done'] and not record['hidden'] and not record.get('skipped') for record in records.values())
    existing_errors = any(case.find('failure') is not None or case.find('error') is not None for case in suite)
    validation_message = None
    if exit_code == 0 and native_tests == 0:
        exit_code = 1
        phase = 'report-validation'
        validation_message = 'Flutter reported no completed non-skipped native tests; inspect flutter-events.jsonl and flutter.log.'
    elif exit_code == 0 and existing_errors:
        exit_code = 1
        phase = 'report-validation'
    if exit_code and not existing_errors:
        case = ET.SubElement(suite, 'testcase', name=phase, classname=f'anistar.{platform}')
        message = validation_message or f'E2E runner exited {exit_code} during {phase}; see runner.log and flutter.log.'
        ET.SubElement(case, 'error', message=message).text = message
    counts = {
        'tests': len(suite),
        'failures': sum(case.find('failure') is not None for case in suite),
        'errors': sum(case.find('error') is not None for case in suite),
        'skipped': sum(case.find('skipped') is not None for case in suite),
    }
    for key, value in counts.items():
        suite.set(key, str(value))
    summary = {
        'schema_version': 1, 'platform': platform, 'mode': mode, 'seed': seed,
        'device': device or None, 'avd': avd or None, 'exit_code': exit_code,
        'requested_avd': requested_avd or None, 'native_tests': native_tests,
        'status': 'passed' if exit_code == 0 else 'failed', 'phase': phase,
        'started_at': started_at, 'finished_at': now(), **counts,
    }
    (directory / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    ET.ElementTree(suite).write(directory / 'junit.xml', encoding='utf-8', xml_declaration=True)
    return summary


def write_aggregate(directory, children):
    directory = Path(directory)
    root = ET.Element('testsuites', name='anistar.mobile-and-tv')
    summaries = []
    for child in children:
        child = Path(child)
        summaries.append(json.loads((child / 'summary.json').read_text()))
        root.append(ET.parse(child / 'junit.xml').getroot())
    summary = {
        'schema_version': 1,
        'status': 'passed' if all(
            item['exit_code'] == 0 and item['status'] == 'passed' and item.get('native_tests', 0) > 0
            and item['errors'] == 0 and item['failures'] == 0
            for item in summaries
        ) else 'failed',
        'runs': summaries,
    }
    for key in ('tests', 'failures', 'errors', 'skipped'):
        root.set(key, str(sum(item[key] for item in summaries)))
    (directory / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    ET.ElementTree(root).write(directory / 'junit.xml', encoding='utf-8', xml_declaration=True)


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
    run.add_argument('--exit-code', type=int, required=True)
    run.add_argument('--phase', required=True)
    run.add_argument('--started-at', required=True)
    aggregate = commands.add_parser('aggregate')
    aggregate.add_argument('--directory', required=True)
    aggregate.add_argument('children', nargs='+')
    args = vars(parser.parse_args())
    if args.pop('command') == 'run':
        directory = args.pop('directory')
        raise SystemExit(write_run_report(directory, **args)['exit_code'])
    else:
        write_aggregate(args['directory'], args['children'])


if __name__ == '__main__':
    main()
