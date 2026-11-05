#!/usr/bin/env python3
"""Build a bounded, versioned update manifest from an actual signed APK."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from urllib.parse import quote

REPOSITORY = 'chi-264/PhoManaChi'
PACKAGE = 'dev.phomanachi.phomanachi'
MAX_BYTES = 1024 ** 3


def build_manifest(apk, metadata, title, notes, tag=None):
    version = metadata['version_name']
    if not re.fullmatch(r'\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?', version):
        raise ValueError('APK version name must be a semantic release version.')
    expected_tag = 'v' + version
    if tag is not None and tag != expected_tag:
        raise ValueError('Git tag must match the APK version name: ' + expected_tag)
    if metadata['package_name'] != PACKAGE:
        raise ValueError('APK application ID does not match Phone Manager.')
    if not 0 < metadata['version_code'] <= 2_100_000_000:
        raise ValueError('Invalid APK version code.')
    if not 28 <= metadata['min_sdk'] <= 100:
        raise ValueError('Unexpected minimum Android SDK.')
    if not title.strip() or len(title) > 160 or len(notes) > 16000:
        raise ValueError('Milestone title/notes are missing or too long.')
    size = apk.stat().st_size
    if not 0 < size <= MAX_BYTES:
        raise ValueError('APK is empty or larger than 1 GiB.')
    with apk.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    return {
        'schema_version': 1, **metadata, 'title': title.strip(), 'notes': notes,
        'apk_url': f'https://github.com/{REPOSITORY}/releases/download/{quote(expected_tag, safe="")}/phomanachi.apk',
        'sha256': digest, 'size_bytes': size,
    }


def android_tool(name, sdk=None):
    configured = sdk or os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
    if not configured:
        local = Path('android/local.properties')
        if local.exists():
            match = re.search(r'^sdk\.dir=(.+)$', local.read_text(), re.M)
            if match:
                configured = match[1]
    if configured:
        candidates = list((Path(configured) / 'build-tools').glob('*/' + name))
        candidates.sort(key=lambda path: tuple(int(x) for x in re.findall(r'\d+', path.parent.name)))
        if candidates:
            return str(candidates[-1])
    found = shutil.which(name)
    if found:
        return found
    raise ValueError(f'Android build tool {name} was not found. Set ANDROID_HOME or pass --sdk.')


def inspect_apk(apk, sdk=None):
    subprocess.run([android_tool('apksigner', sdk), 'verify', '--min-sdk-version', '28', str(apk)], check=True, capture_output=True, text=True)
    text = subprocess.run([android_tool('aapt', sdk), 'dump', 'badging', str(apk)], check=True, capture_output=True, text=True).stdout
    package = re.search(r"^package: name='([^']+)' versionCode='(\d+)' versionName='([^']+)'", text, re.M)
    sdk_value = re.search(r"^sdkVersion:'(\d+)'", text, re.M)
    if not package or not sdk_value:
        raise ValueError('Could not read the signed APK identity/version/SDK.')
    return {'package_name': package[1], 'version_code': int(package[2]), 'version_name': package[3], 'min_sdk': int(sdk_value[1])}


def assert_increasing(new_code, previous_code):
    if previous_code is not None and new_code <= previous_code:
        raise ValueError('Every milestone must increase the Android version code beyond the latest published updater release.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apk', required=True, type=Path)
    parser.add_argument('--output', type=Path, default=Path('build/milestone-release'))
    parser.add_argument('--sdk')
    parser.add_argument('--title', default='')
    parser.add_argument('--notes-file', type=Path)
    parser.add_argument('--tag')
    args = parser.parse_args()
    metadata = inspect_apk(args.apk, args.sdk)
    notes_file = args.notes_file or Path('release-notes') / (metadata['version_name'] + '.md')
    notes = notes_file.read_text(encoding='utf-8').strip()
    tag = args.tag
    if os.environ.get('GITHUB_REF', '').startswith('refs/tags/'):
        tag = os.environ['GITHUB_REF_NAME']
    manifest = build_manifest(args.apk, metadata, args.title or 'Phone Manager ' + metadata['version_name'], notes, tag)
    args.output.mkdir(parents=True, exist_ok=True)
    target = args.output / 'phomanachi.apk'
    if args.apk.resolve() != target.resolve():
        shutil.copyfile(args.apk, target)
    (args.output / 'update.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    (args.output / 'phomanachi.apk.sha256').write_text(manifest['sha256'] + '  phomanachi.apk\n')
    (args.output / 'release-notes.md').write_text(notes + '\n', encoding='utf-8')
    print(f'Prepared v{metadata["version_name"]} / build {metadata["version_code"]}: {args.output}')


if __name__ == '__main__':
    main()
