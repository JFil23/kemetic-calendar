#!/usr/bin/env python3
"""Generate hꜣw voice auditions; uses Python's standard library only.

Preview eight requests without credentials or network access:
  python3 scripts/generate_voice_auditions.py --plan
Generate WAV files using OPENAI_API_KEY or a local key file:
  python3 scripts/generate_voice_auditions.py --key-file /absolute/path/to/key
A key file may contain a raw key or an OPENAI_API_KEY=... assignment.
Outputs are auditions, not approved pronunciation or app assets.
Docs: https://developers.openai.com/api/docs/guides/text-to-speech
"""

import argparse
from datetime import datetime, timezone
import hashlib
import io
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.request
import wave

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / 'config/voice_auditions.v1.json'
ENDPOINT = 'https://api.openai.com/v1/audio/speech'
MAX_AUDIO_BYTES = 8 * 1024 * 1024


def digest(data):
    return hashlib.sha256(data).hexdigest()


def requests_from_config(config):
    requests = []
    ids = set()
    for item in config['candidates']:
        name = item['id']
        if not re.fullmatch(r'[a-z0-9][a-z0-9_-]*', name) or name in ids:
            raise ValueError('Candidate IDs must be unique safe filenames.')
        ids.add(name)
        payload = {
            'model': config['model'],
            'voice': item['voice'],
            'input': config['text'],
            'instructions': config['direction'] + '\n\n' + item['direction'],
            'response_format': 'wav',
            'speed': config['speed'],
        }
        requests.append((name, payload))
    return requests


def read_key(key_file):
    if key_file:
        content = Path(key_file).expanduser().read_text().strip()
        assignments = re.findall(
            r'^\s*(?:export\s+)?OPENAI_API_KEY\s*=\s*(.*?)\s*$',
            content, re.MULTILINE,
        )
        key = assignments[0].strip().strip('\"\'') if assignments else content
    else:
        key = os.environ.get('OPENAI_API_KEY', '').strip()
    if not key:
        raise ValueError('OPENAI_API_KEY is not configured. Use --key-file with a local credential file.')
    if not key.startswith('sk-') or any(c.isspace() for c in key):
        raise ValueError('The credential must be an OpenAI API key, raw or in an OPENAI_API_KEY assignment.')
    return key


def inspect_wav(data):
    if len(data) < 44 or data[:4] != b'RIFF' or data[8:12] != b'WAVE':
        raise ValueError('The API response is not WAV audio; no audio file was saved.')
    with wave.open(io.BytesIO(data), 'rb') as audio:
        channels, width, rate = audio.getnchannels(), audio.getsampwidth(), audio.getframerate()
        frames = audio.readframes(audio.getnframes())
    # Streaming WAV headers may use a placeholder frame count. Measure actual data.
    if not channels or not width or not rate or len(frames) % (channels * width):
        raise ValueError('The WAV response has invalid PCM framing.')
    duration = len(frames) / (channels * width * rate)
    if duration < 0.5 or not any(frames):
        raise ValueError('The WAV response is empty or too short for an audition.')
    return {'duration_seconds': round(duration, 3), 'sample_rate': rate, 'channels': channels}


class NoRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Never forward the credential to a redirected endpoint.
        return None


def fetch_audio(payload_bytes, key):
    request = urllib.request.Request(ENDPOINT, data=payload_bytes, headers={
        'Authorization': 'Bearer ' + key,
        'Content-Type': 'application/json',
        'Accept': 'audio/wav',
    }, method='POST')
    opener = urllib.request.build_opener(NoRedirects)
    try:
        with opener.open(request, timeout=90) as response:
            data = response.read(MAX_AUDIO_BYTES + 1)
            request_id = response.headers.get('x-request-id')
    except urllib.error.HTTPError as error:
        # Do not log response bodies or headers, which could contain sensitive data.
        hints = {
            401: 'The API key was rejected.',
            403: 'The project does not have access to this request.',
            429: 'Check API quota, billing, and rate limits.',
        }
        raise ValueError(f'OpenAI HTTP {error.code}. ' + hints.get(error.code, 'The speech request failed.')) from None
    except (urllib.error.URLError, TimeoutError, OSError):
        raise ValueError('Speech request failed or timed out. No automatic retry was made; check usage before retrying.') from None
    if len(data) > MAX_AUDIO_BYTES:
        raise ValueError('The audition response exceeded the 8 MiB limit.')
    return data, request_id


def write_json(path, value):
    temporary = path.with_suffix(path.suffix + '.part')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    temporary.replace(path)


def generate(name, payload, output, key):
    payload_bytes = json.dumps(payload, ensure_ascii=False, sort_keys=True).encode()
    request_sha = digest(payload_bytes)
    audio_path = output / (name + '.wav')
    receipt_path = output / (name + '.json')
    if audio_path.exists() or receipt_path.exists():
        if not audio_path.is_file() or not receipt_path.is_file():
            raise ValueError(f'{name}: incomplete prior output. Preserve it and use a new --output directory.')
        receipt = json.loads(receipt_path.read_text())
        data = audio_path.read_bytes()
        if receipt.get('request_sha256') != request_sha or receipt.get('audio_sha256') != digest(data):
            raise ValueError(f'{name}: existing output does not match. Use a new --output directory.')
        inspect_wav(data)
        print(f'{name}: keeping verified existing WAV', flush=True)
        return receipt
    print(f'{name}: generating with {payload["voice"]}...', flush=True)
    data, request_id = fetch_audio(payload_bytes, key)
    properties = inspect_wav(data)
    temporary = audio_path.with_suffix('.wav.part')
    temporary.write_bytes(data)
    temporary.replace(audio_path)
    receipt = {
        'candidate': name,
        'file': audio_path.name,
        'generated_at_utc': datetime.now(timezone.utc).isoformat(),
        'provider': 'OpenAI',
        'ai_generated': True,
        'listening_review': 'pending',
        'pronunciation_review': 'pending',
        'request_id': request_id,
        'request': payload,
        'request_sha256': request_sha,
        'audio_sha256': digest(data),
        **properties,
    }
    write_json(receipt_path, receipt)
    print(f'{name}: saved {properties["duration_seconds"]}s WAV', flush=True)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--plan', action='store_true', help='Print requests; no credential, network, or file writes.')
    parser.add_argument('--key-file', type=Path, help='Local API-key file; the key is never printed or saved in output.')
    parser.add_argument('--config', type=Path, default=CONFIG, help='Audition configuration; defaults to the original round.')
    parser.add_argument('--output', type=Path, default=ROOT / 'artifacts/voice_auditions/openai-round-01')
    parser.add_argument('--only', help='Generate only one candidate ID from the plan.')
    args = parser.parse_args()
    config = json.loads(args.config.expanduser().read_text())
    requests = requests_from_config(config)
    if args.only:
        requests = [(name, payload) for name, payload in requests if name == args.only]
        if not requests:
            raise ValueError('Unknown candidate ID. Run --plan to see the candidate IDs.')
    if args.plan:
        print(json.dumps([{'id': name, 'request': payload} for name, payload in requests], ensure_ascii=False, indent=2))
        return
    key = read_key(args.key_file)
    output = args.output.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    # Lock concurrent invocations to avoid duplicate paid requests and overwritten output.
    lock = output / '.generation.lock'
    try:
        lock_fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        raise ValueError('This output directory is locked by another run. Confirm it has stopped before clearing the lock.') from None
    try:
        os.close(lock_fd)
        for name, payload in requests:
            generate(name, payload, output, key)
    finally:
        lock.unlink()
    print(f'Audio saved in {output}. Voice and pronunciation approval still require listening.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, wave.Error) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print('Interrupted. Completed clips are preserved; no automatic retry was made.', file=sys.stderr)
        sys.exit(130)
