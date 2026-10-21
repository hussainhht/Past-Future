"""Short production pause-navigation regression. Uses the existing flow runner's checks."""
import subprocess
from run_game_flow_tests import PROJECT, godot_binary, verify, run_peers

result = subprocess.run(
    [godot_binary(), "--headless", "--path", str(PROJECT),
     "--script", "res://tests/demo_navigation.gd"],
    capture_output=True, text=True, timeout=120,
)
verify(result.stdout + result.stderr, result.returncode,
       "DEMO NAVIGATION: PASS", "pause navigation")
run_peers(godot_binary(), "demo")
