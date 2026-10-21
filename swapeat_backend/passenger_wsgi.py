import sys
import os
import traceback

# ─── 1. FORCE DISK LOGGING ───────────────────────────────────────────────────
# This file will be created right inside your project directory on HostPinnacle
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_FILE = os.path.join(BASE_DIR, "debug_log.txt")

def write_log(message):
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"{message}\n")
    except Exception:
        pass

write_log("\n" + "=" * 50)
write_log("DISHI WSGI INITIALIZATION TRIGGERED")
write_log(f"Python: {sys.version}")
write_log(f"Executable: {sys.executable}")
write_log(f"Directory: {BASE_DIR}")

# ─── 2. CONFIGURE PATHS ──────────────────────────────────────────────────────
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)
os.chdir(BASE_DIR)

# ─── 3. ATTEMPT TO LOAD APP ──────────────────────────────────────────────────
startup_error = None
try:
    write_log("Importing app.py...")
    from app import app as _flask_app
    write_log("SUCCESS: app.py loaded without errors!")
except Exception:
    startup_error = traceback.format_exc()
    write_log(f"FATAL STARTUP ERROR:\n{startup_error}")

# ─── 4. WSGI ENTRY POINT (ALWAYS RETURNS 200 TO BYPASS LITESPEED 500) ────────
def application(environ, start_response):
    write_log(f"Request: {environ.get('REQUEST_METHOD')} {environ.get('PATH_INFO')}")
    
    # If startup failed, display the exact traceback in the browser
    if startup_error:
        start_response('200 OK', [('Content-Type', 'text/html; charset=utf-8')])
        html = f"""
        <html>
        <body style="font-family:sans-serif; background:#0d1117; color:#f0f6fc; padding:30px;">
            <h1 style="color:#f85149;">DISHI Startup Import Error</h1>
            <p>Your Python app crashed during startup on HostPinnacle with the following error:</p>
            <pre style="background:#161b22; padding:15px; border-radius:8px; border:1px solid #30363d; color:#ff7b72; overflow-x:auto;">{startup_error}</pre>
            <p>Directory: <code>{BASE_DIR}</code></p>
            <p>Python: <code>{sys.executable}</code></p>
        </body>
        </html>
        """
        return [html.encode('utf-8')]

    # If startup succeeded, handle the request
    try:
        return _flask_app(environ, start_response)
    except Exception:
        req_err = traceback.format_exc()
        write_log(f"RUNTIME REQUEST ERROR:\n{req_err}")
        start_response('200 OK', [('Content-Type', 'text/html; charset=utf-8')])
        html = f"""
        <html>
        <body style="font-family:sans-serif; background:#0d1117; color:#f0f6fc; padding:30px;">
            <h1 style="color:#f85149;">DISHI Request Runtime Error</h1>
            <p>An error occurred while rendering the page:</p>
            <pre style="background:#161b22; padding:15px; border-radius:8px; border:1px solid #30363d; color:#ff7b72; overflow-x:auto;">{req_err}</pre>
        </body>
        </html>
        """
        return [html.encode('utf-8')]

# Expose 'app' alias so cPanel works with either Entry Point name
app = application
