def analyze_braces(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    depth = 0
    in_string = False
    in_comment = False
    string_char = ''
    
    for i, line in enumerate(lines):
        # We'll just do a simple count for {, } ignoring comments for a quick check.
        # But a more robust check:
        # Actually, let's just count { and } simply
        open_b = line.count('{')
        close_b = line.count('}')
        depth += (open_b - close_b)
        if depth == 0 and open_b > 0 or depth == 0 and close_b > 0:
            print(f"Depth hit 0 at line {i+1}: {line.strip()}")
            # Break after hitting 0 the first time to show the problem
            # return

analyze_braces('lib/features/housing/presentation/merchant_housing_dashboard.dart')
