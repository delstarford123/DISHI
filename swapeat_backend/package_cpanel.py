import os
import zipfile

def create_cpanel_zip():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    output_zip = os.path.join(base_dir, "dishi_backend_cpanel.zip")
    
    # Explicit files and folders to include
    include_files = [
        "app.py",
        "passenger_wsgi.py",
        "requirements.txt",
        ".env",
        "ServiceAccountKey.json",
        "ProductionCertificate.cer",
        "diagnose.py",
    ]
    
    include_dirs = [
        "routes",
        "templates",
        "static",
        "utils",
    ]
    
    print(f"Creating cPanel deployment archive at: {output_zip}")
    with zipfile.ZipFile(output_zip, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for file_name in include_files:
            file_path = os.path.join(base_dir, file_name)
            if os.path.exists(file_path):
                zipf.write(file_path, arcname=file_name)
                print(f"  + Added file: {file_name}")
            else:
                print(f"  ! Missing file: {file_name}")
                
        for dir_name in include_dirs:
            dir_path = os.path.join(base_dir, dir_name)
            if os.path.exists(dir_path):
                for root, dirs, files in os.walk(dir_path):
                    # Filter out __pycache__
                    if "__pycache__" in root:
                        continue
                    for file in files:
                        if file.endswith('.pyc') or file.endswith('.pyo'):
                            continue
                        full_path = os.path.join(root, file)
                        rel_path = os.path.relpath(full_path, base_dir)
                        zipf.write(full_path, arcname=rel_path)
                print(f"  + Added folder: {dir_name}/")

    size_mb = os.path.getsize(output_zip) / (1024 * 1024)
    print(f"\nDone! Archive created: {output_zip} ({size_mb:.2f} MB)")

if __name__ == "__main__":
    create_cpanel_zip()
