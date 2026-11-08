#!/usr/bin/env python3
"""Check the finite projection against its authoritative manifest and nginx maps."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--manifest', type=Path, required=True)
parser.add_argument('--module-result', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
projection = json.loads((root / 'data/blog-legacy-routes.json').read_bytes())
raw = args.manifest.read_bytes()
manifest = json.loads(raw)
assert projection['schema'] == 1
assert projection['source_manifest_sha256'] == hashlib.sha256(raw).hexdigest()
assert projection['aliases'] == manifest['legacy_aliases']
assert len(projection['aliases']) == 540
assert Counter(row['kind'] for row in projection['aliases']) == {
    'post-query': 125, 'old-slug': 5, 'attachment-query': 144,
    'attachment-permalink': 144, 'author-query': 6, 'category-query': 9,
    'comment-reply-query': 107,
}
assert len({row['source'] for row in projection['aliases']}) == 540
result = json.loads(args.module_result.read_bytes())
assert result['projection'] == projection
# Consume the actual generated map entries. This is a regex/value unit check,
# not a substitute for the post-review real nginx response fixture.
maps = result['maps']
redirect_block = maps.split('map $request_uri $blog_legacy_redirect {', 1)[1].split('}', 1)[0]
pairs = []
decoder = json.JSONDecoder()
for line in redirect_block.splitlines():
    line = line.strip()
    if not line or line.startswith('default '):
        continue
    key, offset = decoder.raw_decode(line)
    target, tail = decoder.raw_decode(line[offset:].lstrip())
    assert key.startswith('~^') and key.endswith('$')
    assert target.startswith('https://blog.vpsfree.cz/') and '?' not in target
    pairs.append((re.compile(key[1:]), target))
assert len(pairs) == 541

def redirect(uri):
    matches = [target for pattern, target in pairs if pattern.fullmatch(uri)]
    assert len(matches) <= 1, uri
    return matches[0] if matches else None

for row in projection['aliases']:
    target = 'https://blog.vpsfree.cz' + row['target']
    assert redirect(row['source']) == target
    assert not target.startswith('https://blog.vpsfree.cz//')
assert redirect('/?feed=rss2') == 'https://blog.vpsfree.cz/feed/'
assert redirect('/centos-7-template-jsme-prohlasili-za-stable/?replytocom=3').endswith('#comment-3')
reject_block = maps.split('map $args $blog_legacy_identity_query {', 1)[1].split('}', 1)[0]
line = next(line.strip() for line in reject_block.splitlines() if line.strip().startswith('"'))
key, offset = decoder.raw_decode(line)
assert key.startswith('~*') and line[offset:].strip() == '1;'
reserved = re.compile(key[2:], re.I)
for uri in ['/?p=999999', '/?p=', '/?p', '/?p=8&p=15', '/?p=8&x=1',
            '/?x=1&p=8', '/?P=8', '/?attachment_id=invalid', '/?author=0',
            '/?cat=999', '/?replytocom=999', '/?feed=atom',
            '/centos-7-template-jsme-prohlasili-za-stable/?replytocom=3&x=1']:
    assert redirect(uri) is None and reserved.search(uri.partition('?')[2]), uri
for uri in ['/?utm_source=example', '/?%70=8', '/?other=author',
            '/?redirect=https://example.invalid/', '/feed/']:
    assert redirect(uri) is None and not reserved.search(uri.partition('?')[2]), uri
for uri in ['/?p=8&redirect=https://example.invalid/', '/?P=8',
            '//example.invalid/?p=8', '/?attachment_id=4%0d%0aLocation:evil']:
    assert redirect(uri) is None, uri
assert 'return 301 $blog_legacy_redirect;' in result['redirectRules']
assert 'return 404;' in result['redirectRules']
print('Passed: exact 540-alias projection, fixed destinations, feed/fragments, '
      'query stripping/rejection and encoded-key non-inference')
