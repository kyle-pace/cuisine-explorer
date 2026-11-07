import json, glob, os
out = {}
for f in sorted(glob.glob('/home/claude/cuisine-explorer/research/.work/part*.json')):
    out.update(json.load(open(f)))
todo = [t['id'] for t in json.load(open('/home/claude/cuisine-explorer/research/todo-americas.json'))]
for t in json.load(open('/home/claude/cuisine-explorer/research/todo2-americas.json')):
    if t['id'] not in todo: todo.append(t['id'])
bad = [k for k in out if k not in todo]
assert not bad, bad
ordered = {k: out[k] for k in todo if k in out}
for k,v in ordered.items():
    for s in v.get('sites',[]):
        assert s['type'] in ('blog','youtube','site','magazine'), s
        assert '—' not in s['note'], s
    for c in v.get('cookbooks',[]):
        assert '—' not in c['note'], c
json.dump(ordered, open('/home/claude/cuisine-explorer/research/suggestions-americas.json','w'), indent=2, ensure_ascii=False)
print(len(ordered), 'cuisines;', sum(1 for v in ordered.values() if v.get('sites')), 'with sites;', sum(1 for v in ordered.values() if v.get('cookbooks')), 'with cookbooks')
