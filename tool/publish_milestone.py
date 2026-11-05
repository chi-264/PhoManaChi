#!/usr/bin/env python3
"""Publish prepared APK/manifest together, keeping incomplete releases in draft."""
import argparse
import json
import os
from pathlib import Path
import subprocess
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from prepare_update import REPOSITORY, assert_increasing, build_manifest, inspect_apk


def github_json(path):
    token = os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN')
    headers = {'Accept': 'application/vnd.github+json', 'User-Agent': 'PhoManaChi-Release'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    with urlopen(Request('https://api.github.com/' + path, headers=headers), timeout=30) as response:
        return json.load(response)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, default=Path('build/milestone-release'))
    args = parser.parse_args()
    if os.environ.get('GITHUB_REPOSITORY', REPOSITORY) != REPOSITORY:
        raise ValueError('The updater points to ' + REPOSITORY + '; do not publish this feed from a different repository.')
    repo = github_json('repos/' + REPOSITORY)
    if repo['private']:
        raise ValueError('The selected public release feed requires a public repository. Repository visibility will not be changed by this script.')
    manifest = json.loads((args.directory / 'update.json').read_text())
    apk = args.directory / 'phomanachi.apk'
    rebuilt = build_manifest(apk, inspect_apk(apk), manifest['title'], manifest['notes'])
    if rebuilt != manifest:
        raise ValueError('Prepared manifest does not match the signed APK; regenerate the release assets.')
    try:
        previous = github_json('repos/' + REPOSITORY + '/releases/latest')
    except HTTPError as error:
        if error.code != 404:
            raise
        previous = None
    if previous:
        asset = next((item for item in previous['assets'] if item['name'] == 'update.json'), None)
        if asset:
            # Public asset requests deliberately do not forward the API token to the CDN.
            url = asset['browser_download_url']
            if not url.startswith('https://github.com/' + REPOSITORY + '/releases/download/'):
                raise ValueError('Previous updater metadata is outside the expected repository.')
            with urlopen(url, timeout=30) as response:
                payload = response.read(65537)
                if len(payload) > 65536:
                    raise ValueError('Previous updater metadata is too large.')
                prior = json.loads(payload)
            assert_increasing(manifest['version_code'], prior['version_code'])
    tag = 'v' + manifest['version_name']
    target = os.environ.get('GITHUB_SHA')
    create = ['gh', 'release', 'create', tag, '--repo', REPOSITORY, '--draft', '--title', manifest['title'], '--notes-file', str(args.directory / 'release-notes.md')]
    if target:
        create += ['--target', target]
    subprocess.run(create, check=True)
    subprocess.run(['gh', 'release', 'upload', tag, '--repo', REPOSITORY, *[str(args.directory / name) for name in ['phomanachi.apk', 'update.json', 'phomanachi.apk.sha256']]], check=True)
    subprocess.run(['gh', 'release', 'edit', tag, '--repo', REPOSITORY, '--draft=false', '--latest'], check=True)
    print('Published ' + tag + ' with its verified APK and updater metadata.')


if __name__ == '__main__':
    main()
