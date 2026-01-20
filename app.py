import subprocess
import os
import json
from datetime import datetime
from collections import defaultdict
from flask import Flask, render_template_string, request

app = Flask(__name__)

# Paths to the skill scripts
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SKILLS_DIR = os.path.join(BASE_DIR, ".agent/skills/slurm-master/scripts")

HEALTH_SCRIPT = os.path.join(SKILLS_DIR, "check_cluster.sh")
STORAGE_SCRIPT = os.path.join(SKILLS_DIR, "check_storage.sh")
USAGE_SCRIPT = os.path.join(SKILLS_DIR, "check_usage.sh")

TRANSLATIONS = {
    'en': {
        'title': 'Slurm Admin Console',
        'subtitle': 'Real-time Cluster Monitoring',
        'refresh': 'Refresh All',
        'granularity': 'Granularity:',
        'daily': 'Daily',
        'hourly': 'Hourly',
        'minutely': 'Minutely',
        'insights': 'Cluster Usage Insights',
        'health': 'Cluster Health',
        'storage': 'Storage Status',
        'activity': 'User Activity Ranking',
        'jobs_label': 'Jobs Completed',
        'cpu_label': 'CPU Seconds',
        'no_history': 'No job history found.',
        'cpu_axis': 'CPU Sec',
        'storage_timeline': 'Storage Status Timeline (Daily)',
        'storage_label': 'Disk Usage %'
    },
    'zh': {
        'title': 'Slurm 管理控制台',
        'subtitle': '实时集群监控',
        'refresh': '全部刷新',
        'granularity': '统计粒度:',
        'daily': '按天',
        'hourly': '按小时',
        'minutely': '按分钟',
        'insights': '集群使用情况看板',
        'health': '集群健康状态',
        'storage': '存储状态',
        'activity': '用户活跃度排名',
        'jobs_label': '已完成作业数',
        'cpu_label': 'CPU 耗时 (秒)',
        'no_history': '暂无作业历史数据。',
        'cpu_axis': 'CPU 秒',
        'storage_timeline': '存储状态趋势图 (日视图)',
        'storage_label': '磁盘使用率 %'
    },
    'de': {
        'title': 'Slurm Admin-Konsole',
        'subtitle': 'Echtzeit-Cluster-Überwachung',
        'refresh': 'Alles Aktualisieren',
        'granularity': 'Granularität:',
        'daily': 'Täglich',
        'hourly': 'Stündlich',
        'minutely': 'Minütlich',
        'insights': 'Cluster-Nutzung Einblicke',
        'health': 'Cluster-Zustand',
        'storage': 'Speicherstatus',
        'activity': 'Benutzer-Aktivitätsranking',
        'jobs_label': 'Abgeschlossene Jobs',
        'cpu_label': 'CPU-Sekunden',
        'no_history': 'Keine Jobhistorie gefunden.',
        'cpu_axis': 'CPU Sek',
        'storage_timeline': 'Speicherstatus-Zeitplan (Täglich)',
        'storage_label': 'Festplattennutzung %'
    },
    'nl': {
        'title': 'Slurm Beheerconsole',
        'subtitle': 'Real-time Cluster Monitoring',
        'refresh': 'Alles Vernieuwen',
        'granularity': 'Granulariteit:',
        'daily': 'Dagelijks',
        'hourly': 'Uurlijks',
        'minutely': 'Minuutlijks',
        'insights': 'Clustergebruik Inzichten',
        'health': 'Cluster Gezondheid',
        'storage': 'Opslagstatus',
        'activity': 'Gebruikersactiviteit Ranglijst',
        'jobs_label': 'Voltooide Jobs',
        'cpu_label': 'CPU Seconden',
        'no_history': 'Geen jobgeschiedenis gevonden.',
        'cpu_axis': 'CPU Sec',
        'storage_timeline': 'Opslagstatus Tijdlijn (Dagelijks)',
        'storage_label': 'Opslaggebruik %'
    }
}

def run_script(path):
    try:
        result = subprocess.run(['bash', path], capture_output=True, text=True)
        return result.stdout if result.returncode == 0 else result.stderr
    except Exception as e:
        return str(e)

def get_timeseries_data(freq='hour'):
    try:
        start_time = "today"
        if freq == 'day':
            start_time = "2026-01-01" 
            
        cmd = ["docker", "exec", "slurmctld", "sacct", "-a", "--format=Start,End,CPUTimeRAW", "--noheader", "--parsable2", "-S", start_time]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            return {"labels": [], "jobs": [], "cpu": []}

        stats_jobs = defaultdict(int)
        stats_cpu = defaultdict(int)
        
        if freq == 'day':
            format_str = "%Y-%m-%d"
        elif freq == 'hour':
            format_str = "%H:00"
        else: # minute
            format_str = "%H:%M"
        
        for line in result.stdout.strip().split('\n'):
            if not line: continue
            parts = line.split('|')
            if len(parts) < 3: continue
            
            end_str, cpu_str = parts[1], parts[2]
            if end_str == "Unknown" or end_str == "None": continue
                
            try:
                dt = datetime.fromisoformat(end_str)
                key = dt.strftime(format_str)
                stats_jobs[key] += 1
                stats_cpu[key] += int(cpu_str)
            except:
                continue

        sorted_keys = sorted(stats_jobs.keys())
        return {
            "labels": sorted_keys,
            "jobs": [stats_jobs[k] for k in sorted_keys],
            "cpu": [stats_cpu[k] for k in sorted_keys]
        }
    except Exception as e:
        print(f"Error fetching timeseries: {e}")
        return {"labels": [], "jobs": [], "cpu": []}

def get_storage_timeseries_data():
    HISTORY_FILE = 'data/storage_history.json'
    
    # Try to get the latest real usage point
    try:
        cmd = ["docker", "exec", "slurmctld", "df", "/", "--output=pcent"]
        result = subprocess.run(cmd, capture_output=True, text=True)
        current_usage = 50.0
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            if len(lines) > 1:
                current_usage = float(lines[1].strip().replace('%', ''))
                
        # Record it (simplified version of the sync script)
        history = []
        if os.path.exists(HISTORY_FILE):
            with open(HISTORY_FILE, 'r') as f:
                history = json.load(f)
        
        today = datetime.now().strftime("%Y-%m-%d")
        updated = False
        for entry in history:
            if entry['date'] == today:
                entry['usage'] = current_usage
                updated = True
                break
        if not updated:
            history.append({'date': today, 'usage': current_usage})
            
        history = history[-30:]
        with open(HISTORY_FILE, 'w') as f:
            json.dump(history, f, indent=2)
            
        return {
            "labels": [e['date'] for e in history],
            "usage": [e['usage'] for e in history]
        }
    except Exception as e:
        print(f"Error fetching real storage data: {e}")
        # Fallback to simulated data if cluster is down
        return {"labels": [datetime.now().strftime("%Y-%m-%d")], "usage": [0]}

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="{{ lang }}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ t.title }}</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        :root {
            --bg: #0f172a;
            --card-bg: #1e293b;
            --accent: #38bdf8;
            --text: #f8fafc;
            --muted: #94a3b8;
        }
        body {
            font-family: 'Inter', system-ui, -apple-system, sans-serif;
            background-color: var(--bg);
            color: var(--text);
            margin: 0;
            padding: 2rem;
            display: flex;
            flex-direction: column;
            gap: 2rem;
            align-items: center;
        }
        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            width: 100%;
            max-width: 1400px;
        }
        .controls { display: flex; gap: 0.5rem; align-items: center; }
        h1 { color: var(--accent); margin: 0; }
        .dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(600px, 1fr));
            gap: 2rem;
            width: 100%;
            max-width: 1400px;
        }
        .card {
            background: var(--card-bg);
            padding: 1.5rem;
            border-radius: 1rem;
            box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
            border: 1px solid rgba(255, 255, 255, 0.05);
            overflow-x: auto;
        }
        .card-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 1rem;
        }
        .card h2 {
            margin: 0;
            font-size: 1.25rem;
            border-bottom: 2px solid var(--accent);
            padding-bottom: 0.25rem;
        }
        pre {
            background: #000;
            padding: 1rem;
            border-radius: 0.5rem;
            font-size: 0.9rem;
            line-height: 1.4;
            color: #10b981;
            margin: 0;
        }
        .chart-container {
            height: 350px;
            width: 100%;
        }
        .btn {
            background: rgba(255,255,255,0.05);
            color: var(--text);
            border: 1px solid rgba(255,255,255,0.1);
            padding: 0.4rem 0.8rem;
            border-radius: 0.5rem;
            cursor: pointer;
            font-size: 0.8rem;
            transition: all 0.2s;
            text-decoration: none;
        }
        .btn:hover { background: rgba(255,255,255,0.1); }
        .btn.active {
            background: var(--accent);
            color: var(--bg);
            border-color: var(--accent);
            font-weight: bold;
        }
        .lang-btn {
            background: transparent;
            color: var(--muted);
            border: 1px solid var(--muted);
            padding: 0.2rem 0.6rem;
            border-radius: 0.3rem;
            font-size: 0.75rem;
            text-decoration: none;
        }
        .lang-btn.active {
            color: var(--accent);
            border-color: var(--accent);
        }
        .refresh-btn {
            background: #10b981;
            color: white;
            border: none;
            padding: 0.5rem 1rem;
            border-radius: 0.5rem;
            cursor: pointer;
        }
    </style>
</head>
<body>
    <header>
        <div>
            <h1>{{ t.title }}</h1>
            <p style="color: var(--muted); margin: 0.25rem 0 0 0;">{{ t.subtitle }}</p>
            <div class="controls" style="margin-top: 0.5rem;">
                <a href="/?lang=en&freq={{ freq }}" class="lang-btn {{ 'active' if lang == 'en' else '' }}">EN</a>
                <a href="/?lang=zh&freq={{ freq }}" class="lang-btn {{ 'active' if lang == 'zh' else '' }}">中文</a>
                <a href="/?lang=de&freq={{ freq }}" class="lang-btn {{ 'active' if lang == 'de' else '' }}">DE</a>
                <a href="/?lang=nl&freq={{ freq }}" class="lang-btn {{ 'active' if lang == 'nl' else '' }}">NL</a>
            </div>
        </div>
        <div class="controls">
            <button class="refresh-btn" onclick="window.location.reload()">{{ t.refresh }}</button>
        </div>
    </header>
    
    <div class="dashboard">
        <div class="card" style="grid-column: 1 / -1;">
            <div class="card-header">
                <h2>{{ t.insights }}</h2>
                <div class="controls">
                    <span style="font-size: 0.8rem; color: var(--muted);">{{ t.granularity }}</span>
                    <a href="/?freq=day&lang={{ lang }}" class="btn {{ 'active' if freq == 'day' else '' }}">{{ t.daily }}</a>
                    <a href="/?freq=hour&lang={{ lang }}" class="btn {{ 'active' if freq == 'hour' else '' }}">{{ t.hourly }}</a>
                    <a href="/?freq=minute&lang={{ lang }}" class="btn {{ 'active' if freq == 'minute' else '' }}">{{ t.minutely }}</a>
                </div>
            </div>
            <div class="chart-container">
                <canvas id="usageChart"></canvas>
            </div>
        </div>

        <div class="card" style="grid-column: 1 / -1;">
            <div class="card-header">
                <h2>{{ t.storage_timeline }}</h2>
            </div>
            <div class="chart-container" style="height: 250px;">
                <canvas id="storageTimelineChart"></canvas>
            </div>
        </div>

        <div class="card">
            <h2>{{ t.health }}</h2>
            <pre>{{ health_output }}</pre>
        </div>
        <div class="card">
            <h2>{{ t.storage }}</h2>
            <pre>{{ storage_output }}</pre>
        </div>
        <div class="card" style="grid-column: 1 / -1;">
            <h2>{{ t.activity }}</h2>
            <pre>{{ usage_output }}</pre>
        </div>
    </div>

    <script>
        const tsData = {{ ts_data | tojson | safe }};
        if (tsData.labels.length === 0) {
            document.getElementById('usageChart').parentElement.innerHTML = '<div style="display:flex; height:100%; align-items:center; justify-content:center; color:#94a3b8;">{{ t.no_history }}</div>';
        } else {
            const ctx = document.getElementById('usageChart').getContext('2d');
            new Chart(ctx, {
                type: 'line',
                data: {
                    labels: tsData.labels,
                    datasets: [
                        {
                            label: '{{ t.jobs_label }}',
                            data: tsData.jobs,
                            borderColor: '#38bdf8',
                            backgroundColor: 'rgba(56, 189, 248, 0.2)',
                            fill: true,
                            tension: 0.3,
                            yAxisID: 'yJobs',
                            pointRadius: {{ '3' if freq == 'day' else '2' if freq == 'hour' else '1' }}
                        },
                        {
                            label: '{{ t.cpu_label }}',
                            data: tsData.cpu,
                            borderColor: '#10b981',
                            fill: false,
                            tension: 0.3,
                            yAxisID: 'yCPU',
                            pointRadius: {{ '3' if freq == 'day' else '2' if freq == 'hour' else '1' }}
                        }
                    ]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    interaction: { mode: 'index', intersect: false },
                    scales: {
                        x: { ticks: { color: '#94a3b8', maxRotation: 45, minRotation: 45 }, grid: { display: false } },
                        yJobs: { type: 'linear', display: true, position: 'left', title: { display: true, text: '{{ t.jobs_label }}', color: '#38bdf8' }, ticks: { color: '#94a3b8' }, grid: { color: 'rgba(255,255,255,0.05)' } },
                        yCPU: { type: 'linear', display: true, position: 'right', title: { display: true, text: '{{ t.cpu_axis }}', color: '#10b981' }, ticks: { color: '#94a3b8' }, grid: { drawOnChartArea: false } }
                    },
                    plugins: { legend: { labels: { color: '#f8fafc' } } }
                }
            });
        }

        // Storage Timeline Chart
        const storageData = {{ storage_ts | tojson | safe }};
        const sCtx = document.getElementById('storageTimelineChart').getContext('2d');
        new Chart(sCtx, {
            type: 'line',
            data: {
                labels: storageData.labels,
                datasets: [{
                    label: '{{ t.storage_label }}',
                    data: storageData.usage,
                    borderColor: '#f59e0b',
                    backgroundColor: 'rgba(245, 158, 11, 0.1)',
                    fill: true,
                    tension: 0.4,
                    pointRadius: 3
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    x: { ticks: { color: '#94a3b8' }, grid: { display: false } },
                    y: { 
                        min: 0, max: 100,
                        ticks: { color: '#94a3b8', callback: value => value + '%' }, 
                        grid: { color: 'rgba(255,255,255,0.05)' } 
                    }
                },
                plugins: { legend: { display: false } }
            }
        });
    </script>
</body>
</html>
"""

@app.route('/')
def home():
    freq = request.args.get('freq', 'hour')
    lang = request.args.get('lang', 'en')
    if lang not in TRANSLATIONS: lang = 'en'
    
    t = TRANSLATIONS[lang]
    health = run_script(HEALTH_SCRIPT)
    storage = run_script(STORAGE_SCRIPT)
    usage = run_script(USAGE_SCRIPT)
    ts_data = get_timeseries_data(freq)
    storage_ts = get_storage_timeseries_data()
    
    return render_template_string(HTML_TEMPLATE, 
                                health_output=health, 
                                storage_output=storage, 
                                usage_output=usage,
                                ts_data=ts_data,
                                storage_ts=storage_ts,
                                freq=freq,
                                lang=lang,
                                t=t)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
