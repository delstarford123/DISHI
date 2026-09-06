import os
import re

directories = ['lib']
file_extensions = ['.dart']

def replace_in_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as file:
        content = file.read()

    # We want to replace 'Swapeat' and 'SWAPEAT' with 'DISHI'
    # But NOT 'swapeatId' or 'swapeatCode' or 'swapeat_offline'
    # Regex: replace 'Swapeat' and 'SWAPEAT' if they are NOT followed by 'Id', 'Code', 'App', etc?
    # Actually, the user asked to change it everywhere users see it.
    # So replacing 'SwapeatApp' with 'DishiApp' is fine but 'swapeatCode' shouldn't be touched.
    # Let's specifically do:
    new_content = content.replace('SWAPEAT', 'DISHI')
    new_content = new_content.replace('SwapEat', 'DISHI')
    new_content = new_content.replace('Swapeat', 'DISHI')
    new_content = new_content.replace('swapeat_alerts', 'dishi_alerts')
    
    # Revert specific internal keys if they got renamed (though we didn't touch lowercase 'swapeat')
    # wait, SwapeatApp -> DISHIApp is fine.
    
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as file:
            file.write(new_content)
        print(f"Updated {filepath}")

for d in directories:
    for root, dirs, files in os.walk(d):
        for f in files:
            if any(f.endswith(ext) for ext in file_extensions):
                replace_in_file(os.path.join(root, f))
