import 'dart:async';

class PhoenixTimer {
  void Function() _callback;
  Timer timer;
  List<int> reconnectAfterMs = const [1000, 2000, 5000, 10000];
  var tries = 0;

  PhoenixTimer(this._callback);

  void scheduleTimeout() {
     clearTimeout();
     timer = new Timer(timeoutDuration(), _performTask);
  }

  void _performTask() {
    _callback();
    scheduleTimeout();
  }

  Duration timeoutDuration() {
    final reconnectLength = reconnectAfterMs.length - 1;
    tries++;
    final index = tries > reconnectLength ? reconnectLength : tries;
    return new Duration(milliseconds: reconnectAfterMs[index]);
  }

  void clearTimeout() {
    timer?.cancel();
  }

  void reset() {
    tries = 0;
    clearTimeout();
  }

}