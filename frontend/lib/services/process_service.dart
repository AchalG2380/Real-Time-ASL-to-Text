import 'dart:io';
import 'dart:convert';

/// Manages the lifecycle of the `combined_asl_live.py` Python subprocess.
/// The process opens its own OpenCV camera window and WebSocket server.
class ProcessService {
  Process? _process;
  bool _intentionallyStopped = false;

  // Public status
  bool isRunning = false;
  String statusMessage = 'Not started';
  int? processPid;

  // Optional callback so AppState can rebuild when status changes
  void Function()? onStatusChange;

  // ── Project root detection ────────────────────────────────────────────────
  /// During `flutter run`, Directory.current == the `frontend/` folder.
  /// The Python script lives one level up in the project root.
  static String get _projectRoot {
    // Try sibling of current working directory first (flutter run)
    final cwdParent = Directory.current.parent;
    if (File('${cwdParent.path}\\combined_asl_live.py').existsSync()) {
      return cwdParent.path;
    }
    // Try current directory (in case cwd is already at root)
    if (File('${Directory.current.path}\\combined_asl_live.py').existsSync()) {
      return Directory.current.path;
    }
    // Walk up from the executable (for built releases)
    Directory dir = File(Platform.resolvedExecutable).parent;
    for (int i = 0; i < 8; i++) {
      if (File('${dir.path}\\combined_asl_live.py').existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    // Hard-coded fallback for this machine
    return r'e:\Acro\Git\Real-Time-ASL-to-Text';
  }

  // ── Start ────────────────────────────────────────────────────────────────
  Future<bool> startAslEngine() async {
    if (_process != null) return true;
    _intentionallyStopped = false;

    final root = _projectRoot;
    final pythonExe = '$root\\.venv\\Scripts\\python.exe';
    final script = '$root\\combined_asl_live.py';

    if (!File(pythonExe).existsSync()) {
      _setStatus(false, 'Python venv not found at $pythonExe');
      return false;
    }
    if (!File(script).existsSync()) {
      _setStatus(false, 'Script not found at $script');
      return false;
    }

    print('[ProcessService] Starting: $pythonExe $script');
    _setStatus(false, 'Starting engine...');

    try {
      _process = await Process.start(
        pythonExe,
        [script],
        workingDirectory: root,
        environment: {
          ...Platform.environment,
          'TF_CPP_MIN_LOG_LEVEL': '3',
          'TF_ENABLE_ONEDNN_OPTS': '0',
        },
      );

      processPid = _process!.pid;
      _setStatus(true, 'ASL engine running (pid=$processPid)');

      // Pipe stdout → Flutter debug console
      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => print('[ASL] $line'));

      // Pipe stderr → Flutter debug console
      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => print('[ASL ERR] $line'));

      // Handle unexpected exit
      _process!.exitCode.then((code) {
        print('[ProcessService] Process exited (code=$code)');
        _process = null;
        processPid = null;
        if (!_intentionallyStopped) {
          _setStatus(false, 'Engine stopped (exit $code)');
        } else {
          _setStatus(false, 'Engine stopped');
        }
      });

      return true;
    } catch (e) {
      print('[ProcessService] Failed to start: $e');
      _process = null;
      _setStatus(false, 'Failed to start: $e');
      return false;
    }
  }

  // ── Stop ─────────────────────────────────────────────────────────────────
  void stop() {
    _intentionallyStopped = true;
    _process?.kill();
    _process = null;
    processPid = null;
    _setStatus(false, 'Engine stopped');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _setStatus(bool running, String msg) {
    isRunning = running;
    statusMessage = msg;
    onStatusChange?.call();
  }
}
