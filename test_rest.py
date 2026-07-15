import requests
import json

url = "https://tbhxbfunyhbrctzfpkwf.supabase.co/rest/v1/ios_waitlist"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRiaHhiZnVueWhicmN0emZwa3dmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzOTc0ODksImV4cCI6MjA4ODk3MzQ4OX0.9XH6DYYFqsX3Tdf7DEpgX65A5nNGYQDfBI_yjie_WOo",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRiaHhiZnVueWhicmN0emZwa3dmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMzOTc0ODksImV4cCI6MjA4ODk3MzQ4OX0.9XH6DYYFqsX3Tdf7DEpgX65A5nNGYQDfBI_yjie_WOo",
    "Content-Type": "application/json",
    "Prefer": "return=minimal"
}

data = {
    "email": "test_rest@djorssi.com"
}

resp = requests.post(url, headers=headers, json=data)
print("Status Code:", resp.status_code)
print("Response Text:", resp.text)
