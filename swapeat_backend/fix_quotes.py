import os

routes_dir = r'c:\Users\Delstaford\swapeat\swapeat_backend\routes'
changed = 0
for root, dirs, files in os.walk(routes_dir):
    for f in files:
        if f.endswith('.py'):
            path = os.path.join(root, f)
            with open(path, 'r', encoding='utf-8') as file:
                content = file.read()
            
            # The previous script injected literally \' which needs to be '
            new_content = content.replace(r"\'", "'")
            
            if new_content != content:
                with open(path, 'w', encoding='utf-8') as file:
                    file.write(new_content)
                changed += 1
                print(f'Fixed syntax in {f}')
print(f'Total {changed} files fixed.')
