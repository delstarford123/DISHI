import os
import re

templates_dir = r"c:\Users\Delstaford\swapeat\swapeat_backend\templates"
files_to_update = ["donate.html", "harambee.html", "event.html"]

input_wrap_regex = re.compile(
    r"\.input-wrap\s*\{.*?\n(?:.*?\n)*?\s*\}", re.MULTILINE
)
input_focus_regex = re.compile(
    r"\.input-wrap:focus-within\s*\{.*?\n(?:.*?\n)*?\s*\}", re.MULTILINE
)
btn_regex = re.compile(
    r"\.btn(?:-fund|-submit|-primary)?\s*\{.*?\n(?:.*?\n)*?\s*\}", re.MULTILINE
)
btn_hover_regex = re.compile(
    r"\.btn(?:-fund|-submit|-primary)?:hover:not\(:disabled\)\s*\{.*?\n(?:.*?\n)*?\s*\}", re.MULTILINE
)

new_input_wrap = """        .input-wrap {
            display: flex; align-items: center;
            background: #F8FAFC;
            border: 2px solid #94A3B8; /* Thicker, darker border */
            border-radius: var(--radius-sm);
            overflow: hidden;
            transition: border-color 0.25s, box-shadow 0.25s, background 0.25s;
        }"""

new_input_focus = """        .input-wrap:focus-within {
            border-color: var(--blue);
            box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.25);
            background: #ffffff;
        }"""

new_btn = """        .btn-fund, .btn-submit, .btn-primary, .btn {
            width: 100%; margin-top: 8px;
            background: linear-gradient(135deg, #1E40AF 0%, #0F172A 100%); /* Dark Blue gradient */
            color: #fff; border: none;
            padding: 16px; border-radius: var(--radius-sm);
            font-size: 15px; font-weight: 700;
            cursor: pointer; position: relative; overflow: hidden;
            box-shadow: 0 8px 24px rgba(30, 64, 175, 0.4);
            transition: all 0.25s ease;
            display: flex; align-items: center; justify-content: center; gap: 8px;
        }"""

new_btn_hover = """        .btn-fund:hover:not(:disabled), .btn-submit:hover:not(:disabled), .btn-primary:hover:not(:disabled), .btn:hover:not(:disabled) {
            transform: translateY(-2px);
            box-shadow: 0 12px 32px rgba(30, 64, 175, 0.6);
        }"""

for filename in files_to_update:
    filepath = os.path.join(templates_dir, filename)
    if not os.path.exists(filepath):
        continue
    
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # Replace .input-wrap
    content = input_wrap_regex.sub(new_input_wrap, content, count=1)
    
    # Replace .input-wrap:focus-within
    content = input_focus_regex.sub(new_input_focus, content, count=1)

    # Note: Regex matching the exact button classes in the files
    # Replacing all variations of buttons
    
    # Actually it's safer to just do a string replacement for the background gradient
    content = re.sub(r"background:\s*linear-gradient\([^;]+var\(--green\)[^;]+\);", r"background: linear-gradient(135deg, #1E40AF 0%, #0F172A 100%);", content)
    content = re.sub(r"box-shadow:\s*0\s+8px\s+24px\s+var\(--green-glow\);", r"box-shadow: 0 8px 24px rgba(30, 64, 175, 0.4);", content)
    content = re.sub(r"box-shadow:\s*0\s+12px\s+32px\s+rgba\(67,176,42,0\.4\);", r"box-shadow: 0 12px 32px rgba(30, 64, 175, 0.6);", content)
    content = re.sub(r"background:\s*#fff;\s*\n\s*border:\s*1px\s*solid\s*var\(--border\);", r"background: #F8FAFC;\n            border: 2px solid #94A3B8;", content)
    
    # Specific input-wrap fixes if regex fails
    # Let's just do it manually for absolute precision
    
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)

print("Updated CSS in templates.")
