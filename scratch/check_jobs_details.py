import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'scraper', 'src')))
from core.db_client import SupabaseClient

try:
    db = SupabaseClient()
    
    # List of job IDs fetched by the device
    device_job_ids = [
        "5b195c72-28e6-41e6-81d5-5d3aa5ff4f7b",
        "14518a2a-5ad7-41a6-b0d4-4c8e7741adc6",
        "c008d677-79bb-4c8f-9618-79290a757883",
        "ec092614-0ca3-4c5d-90da-5d1e9950a1ce",
        "a2a510dc-b45a-4e29-9278-e5514a38fa2d",
        "d1fb005c-c9b5-4629-b5b1-2081f57f5ecb",
        "9b2707d2-983b-426a-b040-5a92cbb8da17",
        "825e991d-f93f-4cd9-a6a3-0fec2608f616",
        "3a0c9024-f36b-4327-999f-c78c2604ce20",
        "fdedccb3-607a-4a01-9483-c4af7aa826ff",
        "a6522bde-71e7-4d85-930a-9dbb22a4b96e",
        "362a7658-a61b-44cf-bddb-94092c7efae3",
        "e0e58efe-4388-4b0c-9ccc-632f1f5a7d7d",
        "816044d3-de17-4d1f-a534-0647b9ad59c5",
        "74d7256f-63f2-4ad3-844b-f6fd80785fa0",
        "08a3a729-7e33-469b-9c5c-0adf3215e5f0",
        "954d23c0-ae48-4629-abe5-c2801450bf4d",
        "574c3f19-960d-4596-ab10-70319fd2918b",
        "70eeb866-390d-447f-8301-89e24b81c939",
        "8c878fea-3e75-4297-8308-0a08eea205f2",
        "88f5bb66-2abd-4c80-bd09-2415730db645",
        "f9953b23-c4ee-409c-b823-8b4395b118e3",
        "04928f5b-fd79-4c2a-981e-99b518d68452",
        "795998a2-5c7b-4c6c-9af6-65804b4681e6",
        "8c95c15f-e465-4a51-811e-9231d3313d80",
        "7f2705f8-f53f-40b8-a37c-09fb5e39fb65",
        "ea48d29c-86bc-47fb-a7ec-a155e73cdfd8",
        "94b2df6b-7856-4928-9aa3-9c88135111cd",
        "81049ed5-cca1-4d11-8caa-13e75c7c312a",
        "f17e8ea3-1afb-4b98-aef9-4f6886f32c51",
        "e740cd0b-4aea-478f-84ec-ff7fe6bce261",
        "299838da-0bbb-44ff-ab20-14ae9a9eafd1",
        "f90ac795-5b0f-4fe1-9f2a-93145f776acd",
        "ae267f01-432d-494b-9b8e-244bacf21215",
        "e7b05f31-ffa7-4b2d-ac6f-3bb57130d3bd",
        "f579ac6f-4028-44f9-9a02-ffb8d78d47ea",
        "2fb00dbe-a4fe-4b4a-bb00-3cad5c70b84c",
        "2dff0623-148b-4f9c-ae82-12d5b71579f5",
        "24965795-dbfe-4dba-b686-b4ac829d3ecb",
        "3f967285-542e-4d3f-bbac-201d133f9a6c",
        "ceda9328-c1f8-4665-8456-ba8633336c0b",
        "1c9e3557-2398-4895-bb24-fc3837709928",
        "992a6c90-849b-4478-91e2-162caeda3a21",
        "2e438f83-1be9-423d-9adb-0dd508ef2fa1",
        "4ddb6092-1366-4949-9721-764e99bf4c47",
        "c063fcb8-1abb-4cf3-a367-47fbaa387c2f",
        "416db792-a837-4a49-a1d7-268fea12aad7",
        "2ab76e76-ae8e-46d5-94ad-c30bc2ddcfd6",
        "2f7f05a6-2f1f-4a43-8166-279a9e32c964",
        "17a0a49b-ee04-4de8-b3ba-731197363e10"
    ]
    
    # Query details of these 50 jobs
    res = db.supabase.table('jobs').select('id, job_title, tags, description').in_('id', device_job_ids).execute()
    jobs = res.data
    
    print(f"Loaded {len(jobs)} jobs details out of 50.")
    
    anglais_mentions = []
    for job in jobs:
        title = job.get('job_title', '').lower()
        desc = job.get('description', '').lower()
        tags = [t.lower() for t in (job.get('tags') or [])]
        
        # Check if contains 'anglais'
        if 'anglais' in title or 'anglais' in desc or 'anglais' in tags:
            anglais_mentions.append(job)
            
    print(f"Jobs containing 'anglais': {len(anglais_mentions)}")
    for j in anglais_mentions:
        print(f"- ID: {j['id']} | Title: {j['job_title']} | Tags: {j['tags']}")
        # check if it matched in description
        has_tag = 'anglais' in [t.lower() for t in (j.get('tags') or [])]
        has_title = 'anglais' in j['job_title'].lower()
        has_desc = 'anglais' in j['description'].lower()
        print(f"  Matches: tag={has_tag}, title={has_title}, description={has_desc}")
        
except Exception as e:
    print("Error:", e)
