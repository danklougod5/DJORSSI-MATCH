import json
with open('jobs_dump.json') as f:
    jobs = json.load(f)
for j in jobs:
    tags = j.get('tags') or []
    if 'Informatique' in tags:
        print(j['job_title'], tags)
