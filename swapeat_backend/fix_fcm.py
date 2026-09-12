import os
import re

routes_dir = r'c:\Users\Delstaford\swapeat\swapeat_backend\routes'
changed_files = 0
for root, dirs, files in os.walk(routes_dir):
    for f in files:
        if f.endswith('.py'):
            path = os.path.join(root, f)
            with open(path, 'r', encoding='utf-8') as file:
                content = file.read()
            
            pattern = re.compile(r'(notification\s*=\s*messaging\.Notification\([^)]+\)\s*,)')
            
            replacement = r'\1\n                    android=messaging.AndroidConfig(priority=\'high\', notification=messaging.AndroidNotification(sound=\'default\')),\n                    apns=messaging.APNSConfig(payload=messaging.APNSPayload(aps=messaging.Aps(content_available=True, sound=\'default\'))),'
            
            new_content = pattern.sub(replacement, content)
            
            if new_content != content:
                with open(path, 'w', encoding='utf-8') as file:
                    file.write(new_content)
                changed_files += 1
                print(f'Updated {f}')

print(f'Total files updated: {changed_files}')
