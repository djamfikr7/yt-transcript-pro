import requests
import json
import time

print("=" * 60)
print("TESTING BACKEND API")
print("=" * 60)

# Test 1: Health Check
print("\n[1] Testing Health Check...")
try:
    r = requests.get('http://localhost:8000/health')
    print(f"✅ Status: {r.status_code}")
    print(f"   Response: {r.json()}")
except Exception as e:
    print(f"❌ Error: {e}")

# Test 2: Get Projects List
print("\n[2] Getting Projects List...")
try:
    r = requests.get('http://localhost:8000/projects')
    print(f"✅ Status: {r.status_code}")
    projects = r.json()
    print(f"   Total projects: {len(projects)}")
    for p in projects:
        print(f"   - ID {p['id']}: {p.get('title', 'Processing...')} ({p['status']})")
except Exception as e:
    print(f"❌ Error: {e}")

# Test 3: Create New Project
print("\n[3] Creating New Project...")
try:
    test_url = 'https://www.youtube.com/watch?v=jNQXAC9IVRw'  # Short "Me at the zoo" video
    r = requests.post(
        'http://localhost:8000/projects',
        headers={'Content-Type': 'application/json'},
        data=json.dumps({'url': test_url})
    )
    print(f"✅ Status: {r.status_code}")
    project = r.json()
    print(f"   Created Project ID: {project['id']}")
    print(f"   URL: {project['url']}")
    print(f"   Status: {project['status']}")
    new_project_id = project['id']
    
    # Wait and check status
    print("\n[4] Waiting for processing (10 seconds)...")
    time.sleep(10)
    
    r = requests.get(f'http://localhost:8000/projects/{new_project_id}')
    updated = r.json()
    print(f"   Updated Status: {updated['status']}")
    if updated.get('title'):
        print(f"   Title: {updated['title']}")
    
except Exception as e:
    print(f"❌ Error: {e}")

print("\n" + "=" * 60)
print("TEST COMPLETE")
print("=" * 60)
