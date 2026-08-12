import yaml, sys

with open('.github/workflows/m3-c5-infra-cd.yml', 'r', encoding='utf-8') as f:
    content = f.read()

try:
    data = yaml.safe_load(content)
    print('YAML is syntactically valid')
    print('Top-level keys:', list(data.keys()))
    if 'jobs' in data:
        for job_name, job in data['jobs'].items():
            steps = job.get('steps', [])
            print('Job:', job_name, '- steps:', len(steps))
            for s in steps:
                print('  step:', s.get('name', '(unnamed)'))
except yaml.YAMLError as e:
    print('YAML ERROR:', e)
    sys.exit(1)
