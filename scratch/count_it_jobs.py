import json

with open('/Users/mac/DJORSSI-MATCH/jobs_dump.json', 'r') as f:
    jobs = json.load(f)

it_jobs = []
for job in jobs:
    title = (job.get('job_title') or '').lower()
    description = (job.get('description') or '').lower()
    tags = [t.lower() for t in (job.get('tags') or [])]
    
    if 'informatique' in title or 'informatique' in tags or ' it ' in title or ' it ' in description or 'it' in tags:
        it_jobs.append(job)
    elif 'développeur' in title or 'developer' in title or 'web' in title:
        it_jobs.append(job)

print(f"Nombre total de jobs: {len(jobs)}")
print(f"Nombre de jobs Informatique/IT trouvés: {len(it_jobs)}")
for job in it_jobs:
    print(f"- {job.get('job_title')} (ID: {job.get('id')})")
