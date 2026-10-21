"""Run Level 02 rules, real-scene/transition checks, and two actual ENet peers.
GODOT_BIN selects the Godot executable. Logs are printed on failure.
"""
from pathlib import Path
import argparse,os,shutil,socket,subprocess,tempfile,time
ROOT=Path(__file__).resolve().parents[1]
GODOT=os.environ.get('GODOT_BIN') or shutil.which('godot')
if not GODOT:raise SystemExit('Set GODOT_BIN to Godot 4.x.')

def verify(result,output,marker):
    # macOS's restricted certificate read is unrelated to the game.
    errors=[line for line in output.splitlines() if ('SCRIPT ERROR:' in line or line.startswith('ERROR:')) and 'ret != noErr' not in line]
    if result!=0 or marker not in output or errors:
        print(output)
        raise RuntimeError(f'{marker} failed (exit {result}; errors {errors})')
    print(marker)

def single(script,marker,folder):
    result=subprocess.run([GODOT,'--headless','--path',str(ROOT),'--script','res://tests/'+script,'--log-file',str(folder/(script+'.log'))],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=90)
    verify(result.returncode,result.stdout,marker)

def lan(folder):
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:
        sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
    processes=[];handles=[]
    try:
        for role in ['host','client']:
            handle=(folder/(role+'.txt')).open('w+');handles.append(handle)
            cmd=[GODOT,'--headless','--path',str(ROOT),'--script','res://tests/maintenance_peer.gd','--log-file',str(folder/(role+'.log')),'--',role,str(port)]
            processes.append(subprocess.Popen(cmd,cwd=ROOT,stdout=handle,stderr=subprocess.STDOUT,text=True))
            if role=='host':time.sleep(.4)
        for role,process,handle in zip(['host','client'],processes,handles):
            try:code=process.wait(timeout=55)
            except subprocess.TimeoutExpired:
                process.kill();process.wait();handle.seek(0);print(handle.read());raise
            handle.flush();handle.seek(0);verify(code,handle.read(),f'MAINTENANCE LAN {role}: PASS')
    finally:
        for process in processes:
            if process.poll() is None:process.kill();process.wait()
        for handle in handles:handle.close()

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--lan-only',action='store_true');p.add_argument('--skip-lan',action='store_true');args=p.parse_args()
    with tempfile.TemporaryDirectory(prefix='past-future-level02-') as temp:
        folder=Path(temp)
        if not args.lan_only:
            single('maintenance_rules.gd','MAINTENANCE RULES: PASS',folder)
            single('maintenance_corridor.gd','MAINTENANCE SCENE: PASS',folder)
            single('text_layout.gd','TEXT LAYOUT: PASS',folder)
        if not args.skip_lan:lan(folder)
    print('LEVEL 02: ALL REQUESTED CHECKS PASSED')
